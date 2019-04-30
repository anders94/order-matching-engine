-- --------------------------------------------------------
-- -- Table: Users
-- --------------------------------------------------------

CREATE TABLE users (
  id                 UUID            NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  created            TIMESTAMP       NOT NULL DEFAULT now(),
  email              VARCHAR(128)    NOT NULL UNIQUE,
  encrypted_password VARCHAR(128)    NOT NULL,
  attributes         JSON            NOT NULL DEFAULT '{}'::JSON,
  obsolete           BOOLEAN         NOT NULL DEFAULT FALSE,
  CONSTRAINT pk_users_email PRIMARY KEY (email)
) WITH (OIDS=FALSE);

CREATE INDEX idx_users_email ON users USING btree (email);

-- Example usage:
--
-- INSERT INTO users (email, encrypted_password) VALUES ('a@b.com', crypt('something-secure', gen_salt('bf')));
-- SELECT id FROM users WHERE email = 'a@b.com' AND password = crypt('something-secure', password);
-- SELECT id FROM users WHERE email = 'a@b.com' AND password = crypt('something-incorrect', password);

-- --------------------------------------------------------
-- -- Table: Currencies
-- --------------------------------------------------------

CREATE TABLE currencies (
  symbol             VARCHAR(8)      NOT NULL,
  created            TIMESTAMP       NOT NULL DEFAULT now(),
  significant_digits INT             NOT NULL,
  attributes         JSON            NOT NULL DEFAULT '{}'::JSON,
  obsolete           BOOLEAN         NOT NULL DEFAULT FALSE,
  CONSTRAINT pk_currencies_symbol PRIMARY KEY (symbol)
) WITH (OIDS=FALSE);

CREATE INDEX idx_currencies_symbol ON currencies USING btree (symbol);

-- --------------------------------------------------------
-- -- Table: Markets
-- --------------------------------------------------------

CREATE TABLE markets (
  id                 UUID            NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  created            TIMESTAMP       NOT NULL DEFAULT now(),
  base_symbol        VARCHAR(8)      NOT NULL REFERENCES currencies(symbol) ON DELETE RESTRICT,
  quote_symbol       VARCHAR(8)      NOT NULL REFERENCES currencies(symbol) ON DELETE RESTRICT,
  attributes         JSON            NOT NULL DEFAULT '{}'::JSON,
  obsolete           BOOLEAN         NOT NULL DEFAULT FALSE,
  CONSTRAINT pk_markets_base_symbol_quote_symbol PRIMARY KEY (base_symbol, quote_symbol)
) WITH (OIDS=FALSE);

CREATE INDEX idx_markets_base_symbol_quote_symbol ON markets USING btree (base_symbol, quote_symbol);

-- --------------------------------------------------------
-- -- Table: Offers
-- --------------------------------------------------------

CREATE TABLE offers (
  id                 UUID            NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  created            TIMESTAMP       NOT NULL DEFAULT now(),
  user_id            UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  market_id          UUID            NOT NULL REFERENCES markets(id) ON DELETE RESTRICT,
  side               buy_sell        NOT NULL,
  price              NUMERIC(32, 16) NOT NULL CHECK (price > 0),
  volume             NUMERIC(32, 16) NOT NULL CHECK (volume > 0),
  unfilled           NUMERIC(32, 16) NOT NULL CHECK (unfilled <= volume),
  active             BOOLEAN         NOT NULL DEFAULT TRUE
) WITH (OIDS=FALSE);

CREATE INDEX idx_offers_market_id_side ON offers USING btree (market_id, side);

-- --------------------------------------------------------
-- -- Table: Fills
-- --------------------------------------------------------
--
-- There will be 2 fills for every exchange - the maker's fill which will have an offer_id
-- and the taker's fill which won't because their order was not an open offer at that point.

CREATE TABLE fills (
  id                 UUID            NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  created            TIMESTAMP       NOT NULL DEFAULT now(),
  user_id            UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  market_id          UUID            NOT NULL REFERENCES markets(id) ON DELETE RESTRICT,
  offer_id           UUID            REFERENCES offers(id) ON DELETE RESTRICT, -- NULL for the taker
  side               buy_sell        NOT NULL,
  price              NUMERIC(32, 16) NOT NULL CHECK (price > 0),
  volume             NUMERIC(32, 16) NOT NULL CHECK (volume > 0),
  fee                NUMERIC(32, 16) NOT NULL DEFAULT 0.0
) WITH (OIDS=FALSE);

CREATE INDEX idx_offers_user_id_market_id ON fills USING btree (user_id, market_id);
