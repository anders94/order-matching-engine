DELETE FROM offers WHERE user_id = (SELECT id FROM users WHERE email='user-a@example.com') AND market_id = (SELECT id FROM markets WHERE base_symbol='BTC' and quote_symbol='USD') AND side ='buy' AND price = 4990.0 AND volume = 1.213;
DELETE FROM offers WHERE user_id = (SELECT id FROM users WHERE email='user-a@example.com') AND market_id = (SELECT id FROM markets WHERE base_symbol='BTC' and quote_symbol='USD') AND side ='buy' AND price = 4995.0 AND volume = 0.902;
DELETE FROM offers WHERE user_id = (SELECT id FROM users WHERE email='user-b@example.com') AND market_id = (SELECT id FROM markets WHERE base_symbol='BTC' and quote_symbol='USD') AND side ='buy' AND price = 4995.0 AND volume = 0.283;
DELETE FROM offers WHERE user_id = (SELECT id FROM users WHERE email='user-b@example.com') AND market_id = (SELECT id FROM markets WHERE base_symbol='BTC' and quote_symbol='USD') AND side ='buy' AND price = 4999.5 AND volume = 1.121;

DELETE FROM offers WHERE user_id = (SELECT id FROM users WHERE email='user-c@example.com') AND market_id = (SELECT id FROM markets WHERE base_symbol='BTC' and quote_symbol='USD') AND side ='sell' AND price = 5001.0 AND volume = 0.816;
DELETE FROM offers WHERE user_id = (SELECT id FROM users WHERE email='user-d@example.com') AND market_id = (SELECT id FROM markets WHERE base_symbol='BTC' and quote_symbol='USD') AND side ='sell' AND price = 5005.0 AND volume = 1.375;
DELETE FROM offers WHERE user_id = (SELECT id FROM users WHERE email='user-d@example.com') AND market_id = (SELECT id FROM markets WHERE base_symbol='BTC' and quote_symbol='USD') AND side ='sell' AND price = 5010.0 AND volume = 0.923;

DELETE FROM markets WHERE base_symbol = 'BTC' AND quote_symbol = 'USD';
DELETE FROM markets WHERE base_symbol = 'ETH' AND quote_symbol = 'USD';

DELETE FROM currencies WHERE symbol = 'USD' AND significant_digits = 2;
DELETE FROM currencies WHERE symbol = 'BTC' AND significant_digits = 8;
DELETE FROM currencies WHERE symbol = 'ETH' AND significant_digits = 16;

DELETE FROM users WHERE email = 'user-a@example.com';
DELETE FROM users WHERE email = 'user-b@example.com';
DELETE FROM users WHERE email = 'user-c@example.com';
DELETE FROM users WHERE email = 'user-d@example.com';
