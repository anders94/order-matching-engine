# order-matching-engine

This order matching engine is an exchange implemented within PostgreSQL as functions. Database migrations are handled by `db-migrate` and `tape` is used for tests.

This project is in its *early stages*.

## Why?

Isn't an in-memory matching engine going to be faster? Absolutely, but there are other tradeoffs. Initially I simply wanted to see if this was possible. It turns out it is not only possible but fairly robust and, critically, a much simpler architecture. On failure, you can get back to the latest state simply by replaying the transaction log. There is no ambiguity about differing flavors of matching application logic on multiple servers because the database has only one. This design guarentees transactional integrity while keeping critical infrastructure simple and easily recoverable.

## Performance

Commodity hardware (2.9 GHz Core i5) with over 25k offers supports roughly 200 transactions per second.

## Prerequisites

* PostgreSQL: version 11 or greater (with stored procedures support)
* Node.js (with `npm`)

## Setup

Install node packages:
```
npm install
```

Install `db-migrate` globally so migrations can be run from the command line:
```
npm install -g db-migrate
```

Create the database user: (superuser permissions are necessary to add the pgcrypto extension in the first migration but may be revoked later with `ALTER ROLE ome nosuperuser;`)
```
create user ome with password 'super-secret-password' superuser;
```

Edit `database.json` to taste.

Set environment variables for passwords you intend to use: (it might be handy to keep this in a file you source - git will ignore a file called `environment`)
```
export ADMIN_PASSWORD="super-secret-password" # this password is only used in the next step to create the databases
export DEV_PASSWORD="super-secret-password"
export TEST_PASSWORD="super-secret-password"
export PROD_PASSWORD="super-secret-password"
```

Create databases:
```
db-migrate db:create ome_dev -e bootstrap
db-migrate db:create ome_test -e bootstrap
db-migrate db:create ome_prod -e bootstrap
```

Bring database schema to the current version: (run all migrations that haven't yet been run) This defaults to the dev environment.
```
db-migrate up
```

## Test

Create the test schema:
```
db-migrate up -e test
```

Run the tests:
```
npm test
```

## Test Data

You can add a set of testing data with:
```
db-migrate up:test-data
```

and remove it with:
```
db-migrate down:test-data
```

## Try it

Reset the dev database with a bunch of test orders:
```
db-migrate down:test-data  # in case there is old data in there
db-migrate up:test-data
```

For the rest of this, you'll need to execute SQL directly:
```
psql ome_dev -U ome
```

See the current state of the book:
```
ome_dev=# SELECT side, price, amount, unfilled, amount - unfilled AS filled FROM offers WHERE market_id = (SELECT id FROM markets WHERE base_symbol = 'BTC' AND quote_symbol = 'USD') AND active = TRUE ORDER BY price;
 side |         price         |       amount       |      unfilled      |       filled       
------+-----------------------+--------------------+--------------------+--------------------
 buy  | 4990.0000000000000000 | 1.2130000000000000 | 1.2130000000000000 | 0.0000000000000000
 buy  | 4995.0000000000000000 | 0.9020000000000000 | 0.9020000000000000 | 0.0000000000000000
 buy  | 4995.0000000000000000 | 0.2830000000000000 | 0.2830000000000000 | 0.0000000000000000
 buy  | 4999.5000000000000000 | 1.1210000000000000 | 1.1210000000000000 | 0.0000000000000000
 sell | 5001.0000000000000000 | 0.8160000000000000 | 0.8160000000000000 | 0.0000000000000000
 sell | 5005.0000000000000000 | 1.3750000000000000 | 1.3750000000000000 | 0.0000000000000000
 sell | 5010.0000000000000000 | 0.9230000000000000 | 0.9230000000000000 | 0.0000000000000000
(7 rows)
```

Submit a limit order to buy 0.5 BTC at $5010.00:
```
ome_dev=# SELECT match_limit_order((SELECT id FROM users WHERE email = 'user-a@example.com' AND obsolete = FALSE), (SELECT id FROM markets WHERE base_symbol = 'BTC' AND quote_symbol = 'USD' AND obsolete = FALSE), 'buy', 5010.0, 0.5, 'fills', 'offer');
NOTICE:  starting limit order
NOTICE:  Found sell match (be53e94f-3aad-4955-8c4f-a0e21e5cc7f6,"2019-05-03 19:11:42.53733",e3fd6060-1de2-4ada-81e1-3ac538bb6a65,9b4719da-1bf3-4540-803d-e3d771793a3e,sell,5001.0000000000000000,0.8160000000000000,0.8160000000000000,t)
NOTICE:    amount_remaining 0.5000000000000000 < match.unfilled 0.8160000000000000 = this offer is NOT completely filled by this order
NOTICE:    order complete
NOTICE:  Found sell match (944fc03d-3dd7-49f6-9fca-585892c39b67,"2019-05-03 19:11:42.53733",f93b0c98-0d7b-4606-837f-9fb0a6503674,9b4719da-1bf3-4540-803d-e3d771793a3e,sell,5005.0000000000000000,1.3750000000000000,1.3750000000000000,t)
NOTICE:  Found sell match (08bcc46f-fb53-4c3d-8590-bff854fd37cc,"2019-05-03 19:11:42.53733",f93b0c98-0d7b-4606-837f-9fb0a6503674,9b4719da-1bf3-4540-803d-e3d771793a3e,sell,5010.0000000000000000,0.9230000000000000,0.9230000000000000,t)
 match_limit_order 
-------------------
(0 rows)
```

See the updated order book:
```
ome_dev=# SELECT side, price, amount, unfilled, amount - unfilled AS filled FROM offers WHERE market_id = (SELECT id FROM markets WHERE base_symbol = 'BTC' AND quote_symbol = 'USD') AND active = TRUE ORDER BY price;
 side |         price         |       amount       |      unfilled      |       filled       
------+-----------------------+--------------------+--------------------+--------------------
 buy  | 4990.0000000000000000 | 1.2130000000000000 | 1.2130000000000000 | 0.0000000000000000
 buy  | 4995.0000000000000000 | 0.9020000000000000 | 0.9020000000000000 | 0.0000000000000000
 buy  | 4995.0000000000000000 | 0.2830000000000000 | 0.2830000000000000 | 0.0000000000000000
 buy  | 4999.5000000000000000 | 1.1210000000000000 | 1.1210000000000000 | 0.0000000000000000
 sell | 5001.0000000000000000 | 0.8160000000000000 | 0.3160000000000000 | 0.5000000000000000
 sell | 5005.0000000000000000 | 1.3750000000000000 | 1.3750000000000000 | 0.0000000000000000
 sell | 5010.0000000000000000 | 0.9230000000000000 | 0.9230000000000000 | 0.0000000000000000
(7 rows)
```

See the fill:
```
ome_dev=# select created, market_id, offer_id, maker_user_id, taker_user_id, price, amount from fills;
          created           |              market_id               |               offer_id               |            maker_user_id             |            taker_user_id             |         price         |       amount       
----------------------------+--------------------------------------+--------------------------------------+--------------------------------------+--------------------------------------+-----------------------+--------------------
 2019-05-03 19:12:22.096189 | 9b4719da-1bf3-4540-803d-e3d771793a3e | be53e94f-3aad-4955-8c4f-a0e21e5cc7f6 | e3fd6060-1de2-4ada-81e1-3ac538bb6a65 | 047747c9-307d-47c6-9f99-07a3598e238b | 5001.0000000000000000 | 0.5000000000000000
(1 row)
```

Submit a limit order to sell 2.5 BTC at $4993.00:
```
ome_dev=# SELECT match_limit_order((SELECT id FROM users WHERE email = 'user-a@example.com' AND obsolete = FALSE), (SELECT id FROM markets WHERE base_symbol = 'BTC' AND quote_symbol = 'USD' AND obsolete = FALSE), 'sell', 4993.0, 2.5, 'fills', 'offer');
NOTICE:  starting limit order
NOTICE:  Found buy match (9aa784a7-9c2a-4e47-915c-414dc5ef94ba,"2019-05-03 19:11:42.53733",25c8a195-7936-4ac2-9d17-39348210dc87,9b4719da-1bf3-4540-803d-e3d771793a3e,buy,4999.5000000000000000,1.1210000000000000,1.1210000000000000,t)
NOTICE:    amount_remaining 2.5000000000000000 >= match.filled 1.1210000000000000 = this offer is NOT completely filled by this order
NOTICE:  Found buy match (f846ef7a-4cda-4395-bd50-52382269591d,"2019-05-03 19:11:42.53733",047747c9-307d-47c6-9f99-07a3598e238b,9b4719da-1bf3-4540-803d-e3d771793a3e,buy,4995.0000000000000000,0.9020000000000000,0.9020000000000000,t)
NOTICE:    amount_remaining 1.3790000000000000 >= match.filled 0.9020000000000000 = this offer is NOT completely filled by this order
NOTICE:  Found buy match (2be31a29-5f47-48b1-bd0e-e152c72db6de,"2019-05-03 19:11:42.53733",25c8a195-7936-4ac2-9d17-39348210dc87,9b4719da-1bf3-4540-803d-e3d771793a3e,buy,4995.0000000000000000,0.2830000000000000,0.2830000000000000,t)
NOTICE:    amount_remaining 0.4770000000000000 >= match.filled 0.2830000000000000 = this offer is NOT completely filled by this order
NOTICE:  INSERT INTO offers (user_id, market_id, side, price, amount) VALUES (047747c9-307d-47c6-9f99-07a3598e238b, 9b4719da-1bf3-4540-803d-e3d771793a3e, sell, 4993.0, 0.1940000000000000);
 match_limit_order 
-------------------
(0 rows)
```

See the resulting order book: (notice the new sell offer for 0.194 which is the unfilled remainder)
```
ome_dev=# SELECT side, price, amount, unfilled, amount - unfilled AS filled FROM offers WHERE market_id = (SELECT id FROM markets WHERE base_symbol = 'BTC' AND quote_symbol = 'USD') AND active = TRUE ORDER BY price;
 side |         price         |       amount       |      unfilled      |       filled       
------+-----------------------+--------------------+--------------------+--------------------
 buy  | 4990.0000000000000000 | 1.2130000000000000 | 1.2130000000000000 | 0.0000000000000000
 sell | 4993.0000000000000000 | 0.1940000000000000 | 0.1940000000000000 | 0.0000000000000000
 sell | 5001.0000000000000000 | 0.8160000000000000 | 0.3160000000000000 | 0.5000000000000000
 sell | 5005.0000000000000000 | 1.3750000000000000 | 1.3750000000000000 | 0.0000000000000000
 sell | 5010.0000000000000000 | 0.9230000000000000 | 0.9230000000000000 | 0.0000000000000000
(5 rows)
```

See all the fills: (we got more than one fill for this larger order)
```
ome_dev=# select created, market_id, offer_id, maker_user_id, taker_user_id, price, amount from fills;
          created           |              market_id               |               offer_id               |            maker_user_id             |            taker_user_id             |         price         |       amount       
----------------------------+--------------------------------------+--------------------------------------+--------------------------------------+--------------------------------------+-----------------------+--------------------
 2019-05-03 19:12:22.096189 | 9b4719da-1bf3-4540-803d-e3d771793a3e | be53e94f-3aad-4955-8c4f-a0e21e5cc7f6 | e3fd6060-1de2-4ada-81e1-3ac538bb6a65 | 047747c9-307d-47c6-9f99-07a3598e238b | 5001.0000000000000000 | 0.5000000000000000
 2019-05-03 19:13:15.470796 | 9b4719da-1bf3-4540-803d-e3d771793a3e | 9aa784a7-9c2a-4e47-915c-414dc5ef94ba | 25c8a195-7936-4ac2-9d17-39348210dc87 | 047747c9-307d-47c6-9f99-07a3598e238b | 4999.5000000000000000 | 1.1210000000000000
 2019-05-03 19:13:15.470796 | 9b4719da-1bf3-4540-803d-e3d771793a3e | f846ef7a-4cda-4395-bd50-52382269591d | 047747c9-307d-47c6-9f99-07a3598e238b | 047747c9-307d-47c6-9f99-07a3598e238b | 4995.0000000000000000 | 0.9020000000000000
 2019-05-03 19:13:15.470796 | 9b4719da-1bf3-4540-803d-e3d771793a3e | 2be31a29-5f47-48b1-bd0e-e152c72db6de | 25c8a195-7936-4ac2-9d17-39348210dc87 | 047747c9-307d-47c6-9f99-07a3598e238b | 4995.0000000000000000 | 0.2830000000000000
(4 rows)
```

The stored procedure returns 2 cursors which contain any fills the order had as well as the offer if one was created:
```
BEGIN;
  SELECT match_limit_order((SELECT id FROM users WHERE email = 'user-a@example.com' AND obsolete = FALSE), (SELECT id FROM markets WHERE base_symbol = 'BTC' AND quote_symbol = 'USD' AND obsolete = FALSE), 'buy', 5010.0, 5.0, 'fills', 'offer');
  FETCH ALL IN "fills";
  FETCH ALL IN "offer";
COMMIT;
```

Here's an example:
```
ome_dev=# BEGIN;
BEGIN
ome_dev=# SELECT match_limit_order((SELECT id FROM users WHERE email = 'user-a@example.com' AND obsolete = FALSE), (SELECT id FROM markets WHERE base_symbol = 'BTC' AND quote_symbol = 'USD' AND obsolete = FALSE), 'buy', 5010.0, 5.0, 'fills', 'offer');
NOTICE:  starting limit order
NOTICE:  Found sell match (3cf62411-8440-4591-aafa-b0ea9231f972,"2019-05-05 07:16:49.145293",bd8e7731-3b11-4a84-a92f-19a47bdf251d,b14ee127-161c-4e92-8942-ba73394f05ef,sell,5001.0000000000000000,0.8160000000000000,0.8160000000000000,t)
NOTICE:    amount_remaining 5.0000000000000000 >= match.filled 0.8160000000000000 = this offer is completely filled by this order
NOTICE:  Found sell match (ffde512f-b3d1-4953-aa7c-9be10866c17a,"2019-05-05 07:16:49.145293",e7c2f9bb-fd0c-440d-a237-15c502177add,b14ee127-161c-4e92-8942-ba73394f05ef,sell,5005.0000000000000000,1.3750000000000000,1.3750000000000000,t)
NOTICE:    amount_remaining 4.1840000000000000 >= match.filled 1.3750000000000000 = this offer is completely filled by this order
NOTICE:  Found sell match (0027f128-73e0-4d3a-81f4-091d8b6b06f9,"2019-05-05 07:16:49.145293",e7c2f9bb-fd0c-440d-a237-15c502177add,b14ee127-161c-4e92-8942-ba73394f05ef,sell,5010.0000000000000000,0.9230000000000000,0.9230000000000000,t)
NOTICE:    amount_remaining 2.8090000000000000 >= match.filled 0.9230000000000000 = this offer is completely filled by this order
NOTICE:  INSERT INTO offers (user_id, market_id, side, price, amount) VALUES (394d8efa-10da-45cf-ae76-e7bc75bcd772, b14ee127-161c-4e92-8942-ba73394f05ef, buy, 5010.0, 1.8860000000000000);
 match_limit_order 
-------------------
 offer
 fills
(2 rows)

ome_dev=# FETCH ALL IN "fills";
               fill_id                |         price         |       amount       
--------------------------------------+-----------------------+--------------------
 1f72a005-8056-414a-8809-746bcb8c0524 | 5001.0000000000000000 | 0.8160000000000000
 978f32b1-3853-4db7-befa-bc22f1b7c5f9 | 5005.0000000000000000 | 1.3750000000000000
 fff962e8-44a3-4191-b107-e9e14cbbca0e | 5010.0000000000000000 | 0.9230000000000000
(3 rows)

ome_dev=# FETCH ALL IN "offer";
                  id                  | side |         price         |       amount       
--------------------------------------+------+-----------------------+--------------------
 3d54ef06-5dcf-4d22-834b-3bf4b1b5628e | buy  | 5010.0000000000000000 | 1.8860000000000000
(1 row)

ome_dev=# COMMIT;
COMMIT
ome_dev=#
```

