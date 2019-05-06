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
  (symbol, significant_digits, attributes)
VALUES
  ('USD', 2, '{"description": "United States Dollar"}'::JSON),
  ('BTC', 8, '{"description": "Bitcoin"}'::JSON),
  ('ETH', 16, '{"description": "Ethereum"}'::JSON);

-- add some markets

INSERT INTO markets
  (base_symbol, quote_symbol)
VALUES
  ('BTC', 'USD'),
  ('ETH', 'USD');

-- add a bunch of offers

INSERT INTO offers
  (user_id, market_id, side, price, amount)
VALUES
  ((SELECT id FROM users WHERE email='user-a@example.com'), (SELECT id FROM markets WHERE base_symbol='BTC' and quote_symbol='USD'), 'buy', 4990.0, 1.213),
  ((SELECT id FROM users WHERE email='user-a@example.com'), (SELECT id FROM markets WHERE base_symbol='BTC' and quote_symbol='USD'), 'buy', 4995.0, 0.902),
  ((SELECT id FROM users WHERE email='user-b@example.com'), (SELECT id FROM markets WHERE base_symbol='BTC' and quote_symbol='USD'), 'buy', 4995.0, 0.283),
  ((SELECT id FROM users WHERE email='user-b@example.com'), (SELECT id FROM markets WHERE base_symbol='BTC' and quote_symbol='USD'), 'buy', 4999.5, 1.121),

  ((SELECT id FROM users WHERE email='user-c@example.com'), (SELECT id FROM markets WHERE base_symbol='BTC' and quote_symbol='USD'), 'sell', 5001.0, 0.816),
  ((SELECT id FROM users WHERE email='user-d@example.com'), (SELECT id FROM markets WHERE base_symbol='BTC' and quote_symbol='USD'), 'sell', 5005.0, 1.375),
  ((SELECT id FROM users WHERE email='user-d@example.com'), (SELECT id FROM markets WHERE base_symbol='BTC' and quote_symbol='USD'), 'sell', 5010.0, 0.923);
