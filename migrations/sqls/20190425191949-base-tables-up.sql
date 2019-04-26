-- --------------------------------------------------------
-- -- Table: Users
-- --------------------------------------------------------

CREATE TABLE users (
  id                 UUID            NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  email              VARCHAR(128)    NOT NULL UNIQUE,
  encrypted_password VARCHAR(128)    NOT NULL,
  attributes         JSON            NOT NULL DEFAULT '{}'::JSON,
  obsolete           BOOLEAN         NOT NULL DEFAULT FALSE,
  CONSTRAINT pk_users_email PRIMARY KEY (email)
) WITH (OIDS=FALSE);

CREATE INDEX idx_users_email ON users USING btree (email);

-- INSERT INTO users (email, encrypted_password) VALUES ('a@b.com', crypt('something-secure', gen_salt('bf')));
-- SELECT id FROM users WHERE email = 'a@b.com' AND password = crypt('something-secure', password);
-- SELECT id FROM users WHERE email = 'a@b.com' AND password = crypt('something-incorrect', password);

-- --------------------------------------------------------
-- -- Table: Currencies
-- --------------------------------------------------------

CREATE TABLE currencies (
  symbol             VARCHAR(8)      NOT NULL,
  significant_digits INT             NOT NULL,
  attributes         JSON            NOT NULL DEFAULT '{}'::JSON,
  obsolete           BOOLEAN         NOT NULL DEFAULT FALSE,
  CONSTRAINT pk_currencies_symbol PRIMARY KEY (symbol)
) WITH (OIDS=FALSE);

CREATE INDEX idx_currencies_symbol ON currencies USING btree (symbol);

-- INSERT INTO currencies
--   (symbol, significant_digits, attributes)
-- VALUES
--   ('USD', 2, '{"description": "United States Dollar"}'::JSON),
--   ('BTC', 8, '{"description": "Bitcoin"}'::JSON),
--   ('ETH', 16, '{"description": "Ethereum"}'::JSON);

-- --------------------------------------------------------
-- -- Table: Markets
-- --------------------------------------------------------

CREATE TABLE markets (
  id                 UUID            NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  base_symbol        VARCHAR(8)      NOT NULL REFERENCES currencies(symbol) ON DELETE RESTRICT,
  quote_symbol       VARCHAR(8)      NOT NULL REFERENCES currencies(symbol) ON DELETE RESTRICT,
  attributes         JSON            NOT NULL DEFAULT '{}'::JSON,
  obsolete           BOOLEAN         NOT NULL DEFAULT FALSE,
  CONSTRAINT pk_markets_base_symbol_quote_symbol PRIMARY KEY (base_symbol, quote_symbol)
) WITH (OIDS=FALSE);

CREATE INDEX idx_markets_base_symbol_quote_symbol ON markets USING btree (base_symbol, quote_symbol);

-- INSERT INTO markets
--   (base_symbol, quote_symbol)
-- VALUES
--   ('BTC', 'USD'),
--   ('ETH', 'USD');

-- --------------------------------------------------------
-- -- Table: Offers
-- --------------------------------------------------------

CREATE TABLE offers (
  id                 UUID            NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  user_id            UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  market_id          UUID            NOT NULL REFERENCES markets(id) ON DELETE RESTRICT,
  side               buy_sell        NOT NULL,
  price              NUMERIC(32, 16) NOT NULL CHECK (price > 0),
  volume             NUMERIC(32, 16) NOT NULL CHECK (volume > 0),
  unfilled           NUMERIC(32, 16) NOT NULL CHECK (unfilled = volume),
  active             BOOLEAN         NOT NULL DEFAULT TRUE CHECK (unfilled = volume)
) WITH (OIDS=FALSE);

CREATE INDEX idx_offers_market_id_side ON offers USING btree (market_id, side);
