const express = require('express');
const router = express.Router();

const usersController = require('../controllers/users');
const marketsController = require('../controllers/markets');
const orderbookController = require('../controllers/orderbook');
const ordersController = require('../controllers/orders');
const fillsController = require('../controllers/fills');

// Users routes
router.get('/users', usersController.getUsers);
router.get('/users/:userId', usersController.getUser);

// Markets routes
router.get('/markets', marketsController.getMarkets);
router.get('/markets/:marketId/orderbook', orderbookController.getOrderBook);
router.get('/markets/:baseSymbol/:quoteSymbol', marketsController.getMarketBySymbol);
router.get('/markets/:marketId', marketsController.getMarket);

// Orders routes
router.post('/orders', ordersController.placeOrder);
router.get('/orders', ordersController.getOrders);
router.get('/orders/:orderId', ordersController.getOrder);

// Fills routes
router.get('/fills', fillsController.getFills);
router.get('/orders/:orderId/fills', fillsController.getOrderFills);

module.exports = router;
