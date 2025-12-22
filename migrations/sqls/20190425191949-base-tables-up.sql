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
-- -- Table: Assets
-- --------------------------------------------------------

CREATE TABLE assets (
  symbol             VARCHAR(8)      NOT NULL,
  created            TIMESTAMP       NOT NULL DEFAULT now(),
  base_unit_scale    NUMERIC         NOT NULL CHECK (base_unit_scale > 0 AND scale(base_unit_scale) = 0),
  attributes         JSON            NOT NULL DEFAULT '{}'::JSON,
  obsolete           BOOLEAN         NOT NULL DEFAULT FALSE,
  CONSTRAINT pk_assets_symbol PRIMARY KEY (symbol)
) WITH (OIDS=FALSE);

CREATE INDEX idx_assets_symbol ON assets USING btree (symbol);

-- --------------------------------------------------------
-- -- Table: Markets
-- --------------------------------------------------------

CREATE TABLE markets (
  id                 UUID            NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  created            TIMESTAMP       NOT NULL DEFAULT now(),
  base_symbol        VARCHAR(8)      NOT NULL REFERENCES assets(symbol) ON DELETE RESTRICT,
  quote_symbol       VARCHAR(8)      NOT NULL REFERENCES assets(symbol) ON DELETE RESTRICT,
  lot_size           NUMERIC         NOT NULL CHECK (lot_size > 0 AND scale(lot_size) = 0),
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
  price              NUMERIC         NOT NULL CHECK (price > 0 AND scale(price) = 0),
  amount             NUMERIC         NOT NULL CHECK (amount > 0 AND scale(amount) = 0),
  unfilled           NUMERIC         NOT NULL CHECK (unfilled >= 0 AND unfilled <= amount AND scale(unfilled) = 0),
  active             BOOLEAN         NOT NULL DEFAULT TRUE
) WITH (OIDS=FALSE);

CREATE INDEX idx_offers_price_created ON offers USING btree (price, created);
CREATE INDEX idx_offers_active ON offers USING btree (active);

-- --------------------------------------------------------
-- -- Table: Fills
-- --------------------------------------------------------
--
-- Having the taker_user_id (which is a copy of the user_id from the offer table) and the price here
-- (which is also copied from the offer table) is useful so most data you might select against is in
-- the fills table and potentially allows completed offers to be pruned if the constraints are relaxed.
-- Example:
-- SELECT * FROM fills WHERE maker_user_id = $1 OR taker_user_id = $1 ORDER BY created DESC LIMIT 100;

CREATE TABLE fills (
  id                 UUID            NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  created            TIMESTAMP       NOT NULL DEFAULT now(),
  market_id          UUID            NOT NULL REFERENCES markets(id) ON DELETE RESTRICT,
  offer_id           UUID            NOT NULL REFERENCES offers(id) ON DELETE RESTRICT,
  maker_user_id      UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  taker_user_id      UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  price              NUMERIC         NOT NULL CHECK (price > 0 AND scale(price) = 0),
  amount             NUMERIC         NOT NULL CHECK (amount > 0 AND scale(amount) = 0),
  maker_fee          NUMERIC         NOT NULL DEFAULT 0 CHECK (maker_fee >= 0 AND scale(maker_fee) = 0),
  taker_fee          NUMERIC         NOT NULL DEFAULT 0 CHECK (taker_fee >= 0 AND scale(taker_fee) = 0)
) WITH (OIDS=FALSE);

CREATE INDEX idx_offers_market_id_created_maker_user_id_taker_user_id ON fills USING btree (market_id, created, maker_user_id, taker_user_id);
