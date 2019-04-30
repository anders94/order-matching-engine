const fs = require('fs');
const test = require('tape');
const async = require('async');
const { Client } = require('pg');

let config;
let client;

async.series([
    function(cb) {
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
	client = new Client({database: config.test.database, user: config.test.user, password: config.test.password});
	client.connect(cb);
    },
    function(cb) {	
	console.log('*****************************');
	console.log('**** unit tests');
	console.log('*****************************');
	console.log();
	cb();
    },
    function(cb) {
	client.query('SELECT $1::text as message', ['Hello world!'], (err, res) => {
		console.log(err ? err.stack : res.rows[0].message);
		cb(err);
	    });
	// unit tests here
    },
    function(cb) {
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
