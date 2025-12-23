const { Pool } = require('pg');

const pool = new Pool({
  user: process.env.DB_USER || 'ome',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'ome_dev',
  password: process.env.DB_PASSWORD || '',
  port: process.env.DB_PORT || 5432,
});

pool.on('error', (err) => {
  console.error('Unexpected error on idle client', err);
  process.exit(-1);
});

module.exports = {
  query: (text, params) => pool.query(text, params),
  getClient: () => pool.connect(),
  pool,
};
