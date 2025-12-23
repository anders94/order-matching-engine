const db = require('../utils/db');
const { fromBaseUnits } = require('../utils/conversion');

/**
 * Get order book for a specific market
 */
async function getOrderBook(req, res) {
  try {
    const { marketId } = req.params;
    const depth = parseInt(req.query.depth) || 20;

    // Get market and base asset scale
    const marketResult = await db.query(
      `SELECT m.base_symbol, a.base_unit_scale
       FROM markets m
       JOIN assets a ON m.base_symbol = a.symbol
       WHERE m.id = $1 AND m.obsolete = FALSE`,
      [marketId]
    );

    if (marketResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Market not found',
      });
    }

    const baseUnitScale = marketResult.rows[0].base_unit_scale;

    // Get bids (buy orders) - highest price first
    const bidsResult = await db.query(
      `SELECT price, SUM(unfilled) as amount
       FROM offers
       WHERE market_id = $1 AND side = 'buy' AND active = TRUE
       GROUP BY price
       ORDER BY price DESC
       LIMIT $2`,
      [marketId, depth]
    );

    // Get asks (sell orders) - lowest price first
    const asksResult = await db.query(
      `SELECT price, SUM(unfilled) as amount
       FROM offers
       WHERE market_id = $1 AND side = 'sell' AND active = TRUE
       GROUP BY price
       ORDER BY price ASC
       LIMIT $2`,
      [marketId, depth]
    );

    // Convert amounts from base units to asset units
    const bids = bidsResult.rows.map(row => {
      const amount = fromBaseUnits(parseInt(row.amount), baseUnitScale);
      return {
        price: row.price,
        amount,
        total: amount * row.price,
      };
    });

    const asks = asksResult.rows.map(row => {
      const amount = fromBaseUnits(parseInt(row.amount), baseUnitScale);
      return {
        price: row.price,
        amount,
        total: amount * row.price,
      };
    });

    // Calculate spread
    let spread = null;
    if (bids.length > 0 && asks.length > 0) {
      spread = asks[0].price - bids[0].price;
    }

    res.json({
      success: true,
      marketId,
      bids,
      asks,
      spread,
    });
  } catch (err) {
    console.error('Error fetching order book:', err);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch order book',
    });
  }
}

module.exports = {
  getOrderBook,
};
