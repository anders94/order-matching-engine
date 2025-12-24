const db = require('../utils/db');
const { toBaseUnits, fromBaseUnits } = require('../utils/conversion');

/**
 * Place a new limit order with retry logic for serialization errors
 */
async function placeOrder(req, res) {
  const maxRetries = 5;
  let attempt = 0;

  while (attempt < maxRetries) {
    const client = await db.getClient();

    try {
      const { userId, marketId, side, price, amount } = req.body;

      // Validate required fields (only on first attempt)
      if (attempt === 0) {
        if (!userId || !marketId || !side || price === undefined || amount === undefined) {
          client.release();
          return res.status(400).json({
            success: false,
            error: 'Missing required fields: userId, marketId, side, price, amount',
          });
        }

        // Validate side
        if (side !== 'buy' && side !== 'sell') {
          client.release();
          return res.status(400).json({
            success: false,
            error: 'Side must be either "buy" or "sell"',
          });
        }
      }

      // Get market and base asset scale
      const marketResult = await client.query(
        `SELECT m.base_symbol, a.base_unit_scale
         FROM markets m
         JOIN assets a ON m.base_symbol = a.symbol
         WHERE m.id = $1 AND m.obsolete = FALSE`,
        [marketId]
      );

      if (marketResult.rows.length === 0) {
        client.release();
        return res.status(404).json({
          success: false,
          error: 'Market not found',
        });
      }

      const baseUnitScale = marketResult.rows[0].base_unit_scale;

      // Convert float inputs to integers
      const priceInt = Math.round(price);
      const amountBaseUnits = toBaseUnits(amount, baseUnitScale);

      // Validate positive values (only on first attempt)
      if (attempt === 0 && (priceInt <= 0 || amountBaseUnits <= 0)) {
        client.release();
        return res.status(400).json({
          success: false,
          error: 'Price and amount must be positive values',
        });
      }

      // Start transaction with REPEATABLE READ isolation
      // This ensures consistent snapshot and prevents crossed book race conditions
      await client.query('BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ');

      // Call the match_limit_order stored procedure
      await client.query(
        `SELECT match_limit_order($1, $2, $3, $4, $5, 'fills', 'offer')`,
        [userId, marketId, side, priceInt, amountBaseUnits]
      );

      // Fetch fills cursor
      const fillsResult = await client.query('FETCH ALL IN "fills"');

      // Fetch offer cursor
      const offerResult = await client.query('FETCH ALL IN "offer"');

      // Commit transaction
      await client.query('COMMIT');

      // Format fills
      const fills = fillsResult.rows.map(fill => {
        const fillAmount = fromBaseUnits(parseInt(fill.amount), baseUnitScale);
        return {
          fillId: fill.fill_id,
          price: fill.price,
          amount: fillAmount,
          total: fill.price * fillAmount,
        };
      });

      // Format offer (if one was created)
      let offer = null;
      if (offerResult.rows.length > 0) {
        const offerRow = offerResult.rows[0];
        offer = {
          id: offerRow.id,
          side: offerRow.side,
          price: offerRow.price,
          amount: fromBaseUnits(parseInt(offerRow.amount), baseUnitScale),
        };
      }

      client.release();

      res.json({
        success: true,
        fills,
        offer,
        summary: {
          totalFills: fills.length,
          totalFilled: fills.reduce((sum, fill) => sum + fill.amount, 0),
          offerCreated: offer !== null,
        },
      });

      return; // Success - exit retry loop

    } catch (err) {
      await client.query('ROLLBACK');
      client.release();

      // Check if this is a serialization error
      if (err.code === '40001') { // serialization_failure
        attempt++;
        if (attempt < maxRetries) {
          console.log(`Serialization error, retrying (attempt ${attempt}/${maxRetries})`);
          // Small delay before retry
          await new Promise(resolve => setTimeout(resolve, 10 * attempt));
          continue;
        } else {
          console.error('Max retries reached for serialization error');
          return res.status(503).json({
            success: false,
            error: 'Service temporarily unavailable due to high concurrency',
            details: 'Please retry your request',
          });
        }
      }

      // Not a serialization error - return immediately
      console.error('Error placing order:', err);
      return res.status(500).json({
        success: false,
        error: 'Failed to place order',
        details: err.message,
      });
    }
  }
}

/**
 * Get order details by ID
 */
async function getOrder(req, res) {
  try {
    const { orderId } = req.params;

    const result = await db.query(
      `SELECT o.id, o.created, o.user_id, o.market_id, o.side, o.price, o.amount, o.unfilled, o.active,
              a.base_unit_scale
       FROM offers o
       JOIN markets m ON o.market_id = m.id
       JOIN assets a ON m.base_symbol = a.symbol
       WHERE o.id = $1`,
      [orderId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Order not found',
      });
    }

    const order = result.rows[0];
    const baseUnitScale = order.base_unit_scale;
    const filled = parseInt(order.amount) - parseInt(order.unfilled);

    res.json({
      success: true,
      order: {
        id: order.id,
        created: order.created,
        userId: order.user_id,
        marketId: order.market_id,
        side: order.side,
        price: order.price,
        amount: fromBaseUnits(parseInt(order.amount), baseUnitScale),
        unfilled: fromBaseUnits(parseInt(order.unfilled), baseUnitScale),
        filled: fromBaseUnits(filled, baseUnitScale),
        active: order.active,
        status: order.active ? 'active' : 'inactive',
      },
    });
  } catch (err) {
    console.error('Error fetching order:', err);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch order',
    });
  }
}

/**
 * Get user's orders
 */
async function getOrders(req, res) {
  try {
    const { userId, marketId, status } = req.query;

    if (!userId) {
      return res.status(400).json({
        success: false,
        error: 'userId query parameter is required',
      });
    }

    let query = `
      SELECT o.id, o.created, o.user_id, o.market_id, o.side, o.price, o.amount, o.unfilled, o.active,
             a.base_unit_scale
      FROM offers o
      JOIN markets m ON o.market_id = m.id
      JOIN assets a ON m.base_symbol = a.symbol
      WHERE o.user_id = $1
    `;
    const params = [userId];

    if (marketId) {
      params.push(marketId);
      query += ` AND o.market_id = $${params.length}`;
    }

    if (status === 'active') {
      query += ' AND o.active = TRUE';
    } else if (status === 'inactive') {
      query += ' AND o.active = FALSE';
    }

    query += ' ORDER BY o.created DESC';

    const result = await db.query(query, params);

    const orders = result.rows.map(order => {
      const baseUnitScale = order.base_unit_scale;
      const filled = parseInt(order.amount) - parseInt(order.unfilled);
      return {
        id: order.id,
        created: order.created,
        userId: order.user_id,
        marketId: order.market_id,
        side: order.side,
        price: order.price,
        amount: fromBaseUnits(parseInt(order.amount), baseUnitScale),
        unfilled: fromBaseUnits(parseInt(order.unfilled), baseUnitScale),
        filled: fromBaseUnits(filled, baseUnitScale),
        active: order.active,
        status: order.active ? 'active' : 'inactive',
      };
    });

    res.json({
      success: true,
      orders,
    });
  } catch (err) {
    console.error('Error fetching orders:', err);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch orders',
    });
  }
}

module.exports = {
  placeOrder,
  getOrder,
  getOrders,
};
