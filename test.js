const test = require('tape');
const async = require('async');

async.series([
    function(cb) {	
	console.log('*****************************');
	console.log('**** unit tests');
	console.log('*****************************');
	console.log();
	cb();
    },
    function(cb) {
	// unit tests here
	cb();
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
	console.log('done');
    });
