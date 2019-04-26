-- --------------------------------------------------------
-- -- Setup
-- --------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TYPE buy_sell AS ENUM ('buy', 'sell');
