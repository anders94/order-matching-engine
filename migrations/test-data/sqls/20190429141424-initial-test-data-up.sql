-- create test users

INSERT INTO users
  (email, encrypted_password)
VALUES
  ('user-a@example.com', crypt('7kjik02bdct27enfbeywifdnd', gen_salt('bf'))),
  ('user-b@example.com', crypt('b7dhd82udghr6538dtu48ehf8', gen_salt('bf'))),
  ('user-c@example.com', crypt('hjs02ye37wjdh36qidne72b2f', gen_salt('bf'))),
  ('user-d@example.com', crypt('m92ywnc84twgf9492hd647ywh', gen_salt('bf')));

-- add assets

INSERT INTO assets
  (symbol, base_unit_scale, attributes)
VALUES
  ('USD', 1000000, '{"description": "USDC with 6 decimals"}'::JSON),
  ('BTC', 100000000, '{"description": "Bitcoin with 8 decimals"}'::JSON),
  ('ETH', 1000000000000000000, '{"description": "Ethereum with 18 decimals"}'::JSON);

-- add some markets

INSERT INTO markets
  (base_symbol, quote_symbol, lot_size)
VALUES
  ('BTC', 'USD', 100000000),
  ('ETH', 'USD', 1000000000000000000);

-- add a bunch of offers
-- Note: prices are in micro-USD per BTC (USD base_unit_scale = 1000000)
--       amounts are in satoshis (BTC base_unit_scale = 100000000)

INSERT INTO offers
  (user_id, market_id, side, price, amount)
VALUES
  ((SELECT id FROM users WHERE email='user-a@example.com'), (SELECT id FROM markets WHERE base_symbol='BTC' and quote_symbol='USD'), 'buy', 4990000000, 121300000),
  ((SELECT id FROM users WHERE email='user-a@example.com'), (SELECT id FROM markets WHERE base_symbol='BTC' and quote_symbol='USD'), 'buy', 4995000000, 90200000),
  ((SELECT id FROM users WHERE email='user-b@example.com'), (SELECT id FROM markets WHERE base_symbol='BTC' and quote_symbol='USD'), 'buy', 4995000000, 28300000),
  ((SELECT id FROM users WHERE email='user-b@example.com'), (SELECT id FROM markets WHERE base_symbol='BTC' and quote_symbol='USD'), 'buy', 4999500000, 112100000),

  ((SELECT id FROM users WHERE email='user-c@example.com'), (SELECT id FROM markets WHERE base_symbol='BTC' and quote_symbol='USD'), 'sell', 5001000000, 81600000),
  ((SELECT id FROM users WHERE email='user-d@example.com'), (SELECT id FROM markets WHERE base_symbol='BTC' and quote_symbol='USD'), 'sell', 5005000000, 137500000),
  ((SELECT id FROM users WHERE email='user-d@example.com'), (SELECT id FROM markets WHERE base_symbol='BTC' and quote_symbol='USD'), 'sell', 5010000000, 92300000);
