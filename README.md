# order-matching-engine

This order matching engine is implemented within PostgreSQL as stored procedutes. Database migrations are
handled by `db-migrate` and `tape` is used for tests.

This is in its *early stages* and is *not currently functional*.

## Why?

Isn't an in-memory matching engine going to be faster? Probably, but there are other tradeoffs. Initially I simply wanted to see if this was possible. It turns out it is not only possible but fairly robust and, critically, a much simpler architecture. That’s mostly because everything that is easiest implemented as a singleton is implemented in the database. This design allows order submissions from a number of connected clients while guaranteeing time ordered transactions and transactional integrity.

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
export ADMIN_PASSWORD="super-secret-password"` # this password is only used in the next step to create the databases
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

Run the tests:
```
npm test
```

## Run

Run server:
```
npm start
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
