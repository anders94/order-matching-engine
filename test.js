const fs = require('fs');
const test = require('tape');
const async = require('async');
const { Client } = require('pg');
const DBMigrate = require('db-migrate');

let dbmigrate;
let config;
let client;

async.series([
    function(cb) {
	// reset then migrate the test database
	dbmigrate = DBMigrate.getInstance(true, {env: 'test'});
	dbmigrate.reset('test-data').then(function() {
	    dbmigrate.reset().then(function() {
		dbmigrate.up().then(function() {
		    dbmigrate.up('test-data').then(function() {
			cb();
		    });
		});
	    });
	});
    },
    function(cb) {
	// read the database configuration
	let data = fs.readFileSync('database.json');
	let e;
	try {
	    config = JSON.parse(data);
	}
	catch(_e) {
	    e = _e;
	}
	finally {
	    cb(e);
	}
    },
    function(cb) {
	// replace all ENV properties with the value from the environment
	Object.keys(config.test).forEach(function(key) {
	    if (config.test[key].ENV)
		config.test[key] = process.env[config.test[key].ENV];
	});
	cb();
    },
    function(cb) {
	// connect to the test database
	client = new Client({host: config.test.host,
			     database: config.test.database,
			     user: config.test.user,
			     password: config.test.password});
	client.connect(cb);
    },
    function(cb) {	
	console.log();
	console.log('*****************************');
	console.log('**** unit tests');
	console.log('*****************************');
	console.log();
	cb();
    },
    function(cb) {
	test('Should have a users table', function (t) {
	    client.query('SELECT 1 FROM information_schema.tables WHERE table_schema = $1 AND table_name = $2;', ['public', 'users'], (err, res) => {
		t.equal(1, res.rows.length);
		t.end(err);
		cb(err);
	    });
	});
    },
    function(cb) {
	test('Should have a currencies table', function (t) {
	    client.query('SELECT 1 FROM information_schema.tables WHERE table_schema = $1 AND table_name = $2;', ['public', 'currencies'], (err, res) => {
		t.equal(1, res.rows.length);
		t.end(err);
		cb(err);
	    });
	});
    },
    function(cb) {
	test('Should have a markets table', function (t) {
	    client.query('SELECT 1 FROM information_schema.tables WHERE table_schema = $1 AND table_name = $2;', ['public', 'markets'], (err, res) => {
		t.equal(1, res.rows.length);
		t.end(err);
		cb(err);
	    });
	});
    },
    function(cb) {
	test('Should have an offers table', function (t) {
	    client.query('SELECT 1 FROM information_schema.tables WHERE table_schema = $1 AND table_name = $2;', ['public', 'offers'], (err, res) => {
		t.equal(1, res.rows.length);
		t.end(err);
		cb(err);
	    });
	});
    },
    function(cb) {
	test('Should have 7 test offers', function (t) {
	    client.query('SELECT * FROM offers WHERE active = TRUE;', [], (err, res) => {
		t.equal(7, res.rows.length);
		t.end();
		cb(err);
	    });
	});
    },
    function(cb) {
	test('Should not be able to INSERT crossd offers', function (t) {
	    client.query('INSERT INTO offers (user_id, market_id, side, price, volume) VALUES ((SELECT id FROM users WHERE email=$1), (SELECT id FROM markets WHERE base_symbol=$2 and quote_symbol=$3), $4, $5, $6);', ['user-a@example.com', 'BTC', 'USD', 'sell', 2000.0, 1.0], (err, res) => {
		t.equal(0, res.rowCount);
		client.query('INSERT INTO offers (user_id, market_id, side, price, volume) VALUES ((SELECT id FROM users WHERE email=$1), (SELECT id FROM markets WHERE base_symbol=$2 and quote_symbol=$3), $4, $5, $6);', ['user-a@example.com', 'BTC', 'USD', 'buy', 6000.0, 1.0], (err, res) => {
		    t.equal(0, res.rowCount);
		    t.end();
		    cb();
		});
	    });
	});
    },
    function(cb) {
	console.log();
	console.log('*****************************');
	console.log('**** integration tests');
	console.log('*****************************');
	console.log();
	cb();
    },
    function(cb) {
	// integration tests go here
	cb();
    }],
    function(err) {
	if (err) console.error(err);
	client.end();
	console.log('done');
    });
