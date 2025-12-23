const db = require('../utils/db');
const { fromBaseUnits } = require('../utils/conversion');

/**
 * Get fills (trade history)
 */
async function getFills(req, res) {
  try {
    const { userId, marketId, offerId } = req.query;

    let query = `
      SELECT f.id, f.created, f.market_id, f.offer_id, f.maker_user_id, f.taker_user_id, f.price, f.amount,
             a.base_unit_scale
      FROM fills f
      JOIN markets m ON f.market_id = m.id
      JOIN assets a ON m.base_symbol = a.symbol
      WHERE 1=1
    `;
    const params = [];

    // Filter by user (either as maker or taker)
    if (userId) {
      params.push(userId);
      query += ` AND (f.maker_user_id = $${params.length} OR f.taker_user_id = $${params.length})`;
    }

    // Filter by market
    if (marketId) {
      params.push(marketId);
      query += ` AND f.market_id = $${params.length}`;
    }

    // Filter by offer
    if (offerId) {
      params.push(offerId);
      query += ` AND f.offer_id = $${params.length}`;
    }

    query += ' ORDER BY f.created DESC LIMIT 100';

    const result = await db.query(query, params);

    const fills = result.rows.map(fill => {
      const amount = fromBaseUnits(parseInt(fill.amount), fill.base_unit_scale);
      return {
        id: fill.id,
        created: fill.created,
        marketId: fill.market_id,
        offerId: fill.offer_id,
        makerUserId: fill.maker_user_id,
        takerUserId: fill.taker_user_id,
        price: fill.price,
        amount,
        total: fill.price * amount,
      };
    });

    res.json({
      success: true,
      fills,
    });
  } catch (err) {
    console.error('Error fetching fills:', err);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch fills',
    });
  }
}

/**
 * Get fills for a specific order
 */
async function getOrderFills(req, res) {
  try {
    const { orderId } = req.params;

    const result = await db.query(
      `SELECT f.id, f.created, f.market_id, f.offer_id, f.maker_user_id, f.taker_user_id, f.price, f.amount,
              a.base_unit_scale
       FROM fills f
       JOIN markets m ON f.market_id = m.id
       JOIN assets a ON m.base_symbol = a.symbol
       WHERE f.offer_id = $1
       ORDER BY f.created DESC`,
      [orderId]
    );

    const fills = result.rows.map(fill => {
      const amount = fromBaseUnits(parseInt(fill.amount), fill.base_unit_scale);
      return {
        id: fill.id,
        created: fill.created,
        marketId: fill.market_id,
        offerId: fill.offer_id,
        makerUserId: fill.maker_user_id,
        takerUserId: fill.taker_user_id,
        price: fill.price,
        amount,
        total: fill.price * amount,
      };
    });

    res.json({
      success: true,
      fills,
    });
  } catch (err) {
    console.error('Error fetching order fills:', err);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch order fills',
    });
  }
}

module.exports = {
  getFills,
  getOrderFills,
};
