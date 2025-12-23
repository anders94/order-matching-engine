const db = require('../utils/db');

/**
 * Get all active users
 */
async function getUsers(req, res) {
  try {
    const result = await db.query(
      'SELECT id, email, created FROM users WHERE obsolete = FALSE ORDER BY email'
    );

    res.json({
      success: true,
      users: result.rows,
    });
  } catch (err) {
    console.error('Error fetching users:', err);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch users',
    });
  }
}

/**
 * Get a specific user by ID
 */
async function getUser(req, res) {
  try {
    const { userId } = req.params;

    const result = await db.query(
      'SELECT id, email, created FROM users WHERE id = $1 AND obsolete = FALSE',
      [userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'User not found',
      });
    }

    res.json({
      success: true,
      user: result.rows[0],
    });
  } catch (err) {
    console.error('Error fetching user:', err);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch user',
    });
  }
}

module.exports = {
  getUsers,
  getUser,
};
