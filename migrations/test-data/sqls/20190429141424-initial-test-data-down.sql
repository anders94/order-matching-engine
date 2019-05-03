DELETE FROM fills WHERE maker_user_id IN (SELECT id FROM users WHERE email LIKE 'user-%@example.com') OR taker_user_id IN (SELECT id FROM users WHERE email LIKE 'user-%@example.com');

DELETE FROM offers WHERE user_id = (SELECT id FROM users WHERE email='user-a@example.com') AND market_id = (SELECT id FROM markets WHERE base_symbol='BTC' and quote_symbol='USD');
DELETE FROM offers WHERE user_id = (SELECT id FROM users WHERE email='user-b@example.com') AND market_id = (SELECT id FROM markets WHERE base_symbol='BTC' and quote_symbol='USD');
DELETE FROM offers WHERE user_id = (SELECT id FROM users WHERE email='user-c@example.com') AND market_id = (SELECT id FROM markets WHERE base_symbol='BTC' and quote_symbol='USD');
DELETE FROM offers WHERE user_id = (SELECT id FROM users WHERE email='user-d@example.com') AND market_id = (SELECT id FROM markets WHERE base_symbol='BTC' and quote_symbol='USD');

DELETE FROM markets WHERE base_symbol = 'BTC' AND quote_symbol = 'USD';
DELETE FROM markets WHERE base_symbol = 'ETH' AND quote_symbol = 'USD';

DELETE FROM currencies WHERE symbol = 'USD' AND significant_digits = 2;
DELETE FROM currencies WHERE symbol = 'BTC' AND significant_digits = 8;
DELETE FROM currencies WHERE symbol = 'ETH' AND significant_digits = 16;

DELETE FROM users WHERE email = 'user-a@example.com';
DELETE FROM users WHERE email = 'user-b@example.com';
DELETE FROM users WHERE email = 'user-c@example.com';
DELETE FROM users WHERE email = 'user-d@example.com';
