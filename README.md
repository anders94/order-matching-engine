# order-matching-engine

This is an order matching engine implemented within PostgreSQL stored procedutes. A lightweight Node.js based
server is used to interact with the engine. Database migrations are handled by `db-migrate` and `should` is
used as a framework for tests. PostgreSQL `NOTIFY` is used to push notifications of trading activity via a
websocket server.

This is in its _very early stages_ and is _not currently functional_.

## Prerequisites

* PostgreSQL: version 11 or greater (with stored procedures support)
* Node.js (with `npm`)

## Setup

Install node packages:
```
npm install
```

Install `db-migrate`:
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

Bring database schema to the current version: (run all migrations that haven't yet been run. This defaults to the dev environment)
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
dm-migrate up:test
```

and remove it with:
```
dm-migrate down:test
```
