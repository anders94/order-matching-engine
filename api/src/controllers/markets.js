const db = require('../utils/db');

/**
 * Get all active markets
 */
async function getMarkets(req, res) {
  try {
    const result = await db.query(
      'SELECT id, base_symbol, quote_symbol, created FROM markets WHERE obsolete = FALSE ORDER BY base_symbol, quote_symbol'
    );

    res.json({
      success: true,
      markets: result.rows,
    });
  } catch (err) {
    console.error('Error fetching markets:', err);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch markets',
    });
  }
}

/**
 * Get a specific market by ID
 */
async function getMarket(req, res) {
  try {
    const { marketId } = req.params;

    const result = await db.query(
      'SELECT id, base_symbol, quote_symbol, created FROM markets WHERE id = $1 AND obsolete = FALSE',
      [marketId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Market not found',
      });
    }

    res.json({
      success: true,
      market: result.rows[0],
    });
  } catch (err) {
    console.error('Error fetching market:', err);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch market',
    });
  }
}

/**
 * Get market by symbol pair (e.g., BTC-USD)
 */
async function getMarketBySymbol(req, res) {
  try {
    const { baseSymbol, quoteSymbol } = req.params;

    const result = await db.query(
      'SELECT id, base_symbol, quote_symbol, created FROM markets WHERE base_symbol = $1 AND quote_symbol = $2 AND obsolete = FALSE',
      [baseSymbol.toUpperCase(), quoteSymbol.toUpperCase()]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Market not found',
      });
    }

    res.json({
      success: true,
      market: result.rows[0],
    });
  } catch (err) {
    console.error('Error fetching market:', err);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch market',
    });
  }
}

module.exports = {
  getMarkets,
  getMarket,
  getMarketBySymbol,
};
