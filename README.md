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

Set environment variables for database passwords you intend to use:

* `DEV_PASSWORD`
* `TEST_PASSWORD`
* `PROD_PASSWORD`

Create the database user: (superuser permissions are necessary to add the pgcrypto extension but may be revoked later with `ALTER ROLE ome nosuperuser;`)
```
create user ome with password 'super-secret-password' superuser;
```

Create databases:
```
create database ome_dev;
create database ome_test;
create database ome_prod;
```

Or you could create them with `db-migrate` (doesn't seem to be working yet)
```
db-migrate db:create ome_dev -e dev
db-migrate db:create ome_test -e dev
db-migrate db:create ome_prod -e dev
```

Bring database schema to the current version: (run all migrations that haven't yet been run)
```
db-migrate up -e dev
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
