#!/usr/bin/env node

const http = require('http');

const API_BASE = process.env.API_BASE || 'http://localhost:3000';

/**
 * Make an HTTP request
 */
function request(method, path, body = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, API_BASE);
    const options = {
      method,
      headers: {
        'Content-Type': 'application/json',
      },
    };

    const req = http.request(url, options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          resolve(data);
        }
      });
    });

    req.on('error', reject);

    if (body) {
      req.write(JSON.stringify(body));
    }

    req.end();
  });
}

/**
 * List all users
 */
async function listUsers() {
  try {
    const result = await request('GET', '/api/v1/users');

    if (!result.success) {
      console.error('Error fetching users:', result.error);
      return;
    }

    console.log('Users:');
    result.users.forEach(user => {
      console.log(`  ${user.id} - ${user.email || 'N/A'}`);
    });
  } catch (err) {
    console.error('Error fetching users:', err.message);
    console.log('\nMake sure the API server is running: npm run api');
  }
}

/**
 * List all markets
 */
async function listMarkets(userId) {
  const result = await request('GET', '/api/v1/markets');

  if (!result.success) {
    console.error('Error fetching markets:', result.error);
    return;
  }

  console.log(`Markets (for user ${userId}):`);
  result.markets.forEach(market => {
    console.log(`  ${market.id} - ${market.base_symbol}/${market.quote_symbol}`);
  });
}

/**
 * Get order book
 */
async function getOrderBook(marketId) {
  const result = await request('GET', `/api/v1/markets/${marketId}/orderbook?depth=10`);

  if (!result.success) {
    throw new Error(`Failed to get order book: ${result.error}`);
  }

  return result;
}

/**
 * Place an order
 */
async function placeOrder(userId, marketId, side, price, amount) {
  const result = await request('POST', '/api/v1/orders', {
    userId,
    marketId,
    side,
    price,
    amount,
  });

  return result;
}

/**
 * Generate a random trade based on the order book
 */
function generateTrade(orderBook) {
  const { bids, asks } = orderBook;

  // If no bids or asks, create a simple order
  if (bids.length === 0 && asks.length === 0) {
    return {
      side: Math.random() < 0.5 ? 'buy' : 'sell',
      price: Math.round(90000 + Math.random() * 4000), // Random price around 90k-94k
      amount: parseFloat((0.1 + Math.random() * 0.9).toFixed(8)), // 0.1 to 1.0 BTC
      shouldCross: false,
    };
  }

  const side = Math.random() < 0.5 ? 'buy' : 'sell';
  const shouldCross = Math.random() < 0.5; // 50% chance to cross

  let price, amount;

  if (side === 'buy') {
    // Buying
    if (asks.length > 0 && shouldCross) {
      // Cross the spread - buy at or above best ask
      const bestAsk = parseFloat(asks[0].price);
      const spread = bids.length > 0 ? bestAsk - parseFloat(bids[0].price) : bestAsk * 0.001;
      price = Math.round(bestAsk + (Math.random() * spread));
    } else if (bids.length > 0) {
      // Don't cross - buy below best ask
      const bestBid = parseFloat(bids[0].price);
      const range = bestBid * 0.002; // Within 0.2% of best bid
      price = Math.round(bestBid - (Math.random() * range));
    } else {
      // No bids, use ask as reference
      const bestAsk = parseFloat(asks[0].price);
      price = Math.round(bestAsk - (bestAsk * 0.001));
    }
  } else {
    // Selling
    if (bids.length > 0 && shouldCross) {
      // Cross the spread - sell at or below best bid
      const bestBid = parseFloat(bids[0].price);
      const spread = asks.length > 0 ? parseFloat(asks[0].price) - bestBid : bestBid * 0.001;
      price = Math.round(bestBid - (Math.random() * spread));
    } else if (asks.length > 0) {
      // Don't cross - sell above best bid
      const bestAsk = parseFloat(asks[0].price);
      const range = bestAsk * 0.002; // Within 0.2% of best ask
      price = Math.round(bestAsk + (Math.random() * range));
    } else {
      // No asks, use bid as reference
      const bestBid = parseFloat(bids[0].price);
      price = Math.round(bestBid + (bestBid * 0.001));
    }
  }

  // Generate realistic amount (must be whole numbers due to lot_size)
  // Most trades are small (1-2), some medium (2-5), rare large (5-10)
  const rand = Math.random();
  if (rand < 0.7) {
    // 70% small trades (1-2 BTC)
    amount = Math.floor(1 + Math.random() * 2);
  } else if (rand < 0.95) {
    // 25% medium trades (2-5 BTC)
    amount = Math.floor(2 + Math.random() * 4);
  } else {
    // 5% large trades (5-10 BTC)
    amount = Math.floor(5 + Math.random() * 6);
  }
  amount = parseFloat(amount.toFixed(1)); // Ensure it's a clean number

  return { side, price, amount, shouldCross };
}

/**
 * Format number with commas
 */
function formatNumber(num) {
  return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

/**
 * Run load testing loop
 */
async function runLoadTest(userId, marketId) {
  console.log(`Starting load test for user ${userId} on market ${marketId}`);
  console.log('Press Ctrl+C to stop\n');

  let tradeCount = 0;
  let fillCount = 0;
  let totalFilled = 0;
  let orderBook = null;
  let orderBookFetchCount = 0;

  // Fetch order book initially
  try {
    orderBook = await getOrderBook(marketId);
    orderBookFetchCount++;
  } catch (err) {
    console.error('Error fetching initial order book:', err.message);
    return;
  }

  while (true) {
    try {
      // Refetch order book every 10 trades
      if (tradeCount > 0 && tradeCount % 10 === 0) {
        orderBook = await getOrderBook(marketId);
        orderBookFetchCount++;
      }

      // Generate trade
      const trade = generateTrade(orderBook);

      // Place order
      const startTime = Date.now();
      const result = await placeOrder(userId, marketId, trade.side, trade.price, trade.amount);
      const duration = Date.now() - startTime;

      tradeCount++;

      if (result.success) {
        const fills = result.fills.length;
        const filled = result.summary.totalFilled;
        const offered = result.offer ? result.offer.amount : 0;

        if (fills > 0) {
          fillCount++;
          totalFilled += filled;
        }

        // Print single line summary
        const status = fills > 0 ? 'FILLED' : 'POSTED';
        const fillInfo = fills > 0 ? `${fills}x fills, ${filled.toFixed(8)} filled` : `${offered.toFixed(8)} posted`;
        const bookIndicator = (tradeCount % 10 === 0) ? ' [BOOK]' : '';
        console.log(
          `[${tradeCount}] ${status} ${trade.side.toUpperCase()} ${trade.amount.toFixed(8)} @ ${formatNumber(trade.price)} | ` +
          `${fillInfo} | ${duration}ms | fills: ${fillCount}/${tradeCount} (${((fillCount/tradeCount)*100).toFixed(1)}%)${bookIndicator}`
        );
      } else {
        // Show detailed error information
        const errorDetail = result.details ? ` (${result.details})` : '';
        console.log(
          `[${tradeCount}] ERROR ${trade.side.toUpperCase()} ${trade.amount.toFixed(8)} @ ${formatNumber(trade.price)} | ` +
          `${result.error}${errorDetail} | ${duration}ms`
        );
      }

      // Small delay to avoid overwhelming the server
      await new Promise(resolve => setTimeout(resolve, 100));

    } catch (err) {
      console.error('Error in load test loop:', err.message);
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
  }
}

/**
 * Run parallel load testing
 */
async function runParallelLoadTest(userId, marketId, parallelCount) {
  console.log(`Starting parallel load test with ${parallelCount} concurrent workers`);
  console.log(`User: ${userId}, Market: ${marketId}`);
  console.log('Press Ctrl+C to stop\n');

  // Shared statistics
  const stats = {
    totalOrders: 0,
    totalFills: 0,
    totalFilled: 0,
    totalLatency: 0,
    prices: [],
    errors: 0,
    lastErrors: [],
    intervalOrders: 0,
    intervalFills: 0,
    intervalLatency: 0,
    intervalPrices: [],
    startTime: Date.now(),
  };

  let running = true;

  // Handle Ctrl+C
  process.on('SIGINT', () => {
    running = false;
    console.log('\n\nStopping...\n');
  });

  // Fetch order book once
  let orderBook;
  try {
    orderBook = await getOrderBook(marketId);
  } catch (err) {
    console.error('Error fetching order book:', err.message);
    return;
  }

  // Worker function
  async function worker(workerId) {
    let workerTrades = 0;

    while (running) {
      try {
        // Refetch order book every 3 trades (more frequent in parallel mode)
        if (workerTrades > 0 && workerTrades % 3 === 0) {
          orderBook = await getOrderBook(marketId);
        }

        // Generate trade
        const trade = generateTrade(orderBook);

        // Place order
        const startTime = Date.now();
        const result = await placeOrder(userId, marketId, trade.side, trade.price, trade.amount);
        const duration = Date.now() - startTime;

        workerTrades++;
        stats.totalOrders++;
        stats.intervalOrders++;
        stats.totalLatency += duration;
        stats.intervalLatency += duration;
        stats.prices.push(trade.price);
        stats.intervalPrices.push(trade.price);

        if (result.success) {
          if (result.fills.length > 0) {
            stats.totalFills++;
            stats.intervalFills++;
            stats.totalFilled += result.summary.totalFilled;
          }
        } else {
          stats.errors++;
          const errorMsg = `[Worker ${workerId}] ERROR: ${result.error}${result.details ? ' (' + result.details + ')' : ''}`;
          stats.lastErrors.push(errorMsg);
          console.error(errorMsg);
        }

        // Small delay
        await new Promise(resolve => setTimeout(resolve, 100));

      } catch (err) {
        stats.errors++;
        const errorMsg = `[Worker ${workerId}] EXCEPTION: ${err.message}`;
        stats.lastErrors.push(errorMsg);
        console.error(errorMsg);
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
    }
  }

  // Start workers
  const workers = [];
  for (let i = 0; i < parallelCount; i++) {
    workers.push(worker(i + 1));
  }

  // Stats printer
  const statsInterval = setInterval(() => {
    if (stats.intervalOrders === 0) {
      console.log('Waiting for orders...');
      return;
    }

    const avgLatency = stats.intervalLatency / stats.intervalOrders;
    const avgPrice = stats.intervalPrices.reduce((a, b) => a + b, 0) / stats.intervalPrices.length;
    const fillRate = ((stats.intervalFills / stats.intervalOrders) * 100).toFixed(1);
    const throughput = (stats.intervalOrders / 5).toFixed(1);

    console.log(
      `Orders: ${stats.intervalOrders.toString().padStart(4)} | ` +
      `Fills: ${fillRate.padStart(5)}% | ` +
      `Avg Price: ${formatNumber(Math.round(avgPrice)).padStart(15)} | ` +
      `Avg Latency: ${Math.round(avgLatency).toString().padStart(4)}ms | ` +
      `Throughput: ${throughput.padStart(6)} orders/sec`
    );

    // Reset interval stats
    stats.intervalOrders = 0;
    stats.intervalFills = 0;
    stats.intervalLatency = 0;
    stats.intervalPrices = [];
  }, 5000);

  // Wait for workers or Ctrl+C
  await Promise.race([
    Promise.all(workers),
    new Promise(resolve => {
      const checkInterval = setInterval(() => {
        if (!running) {
          clearInterval(checkInterval);
          resolve();
        }
      }, 100);
    })
  ]);

  clearInterval(statsInterval);

  // Print final statistics
  const totalTime = (Date.now() - stats.startTime) / 1000;
  const avgLatency = stats.totalOrders > 0 ? stats.totalLatency / stats.totalOrders : 0;
  const avgPrice = stats.prices.length > 0 ? stats.prices.reduce((a, b) => a + b, 0) / stats.prices.length : 0;
  const fillRate = stats.totalOrders > 0 ? ((stats.totalFills / stats.totalOrders) * 100).toFixed(1) : 0;
  const throughput = (stats.totalOrders / totalTime).toFixed(1);

  console.log('\n' + '='.repeat(80));
  console.log('FINAL STATISTICS');
  console.log('='.repeat(80));
  console.log(`Total Runtime:        ${totalTime.toFixed(1)}s`);
  console.log(`Total Orders:         ${stats.totalOrders}`);
  console.log(`Total Fills:          ${stats.totalFills} (${fillRate}%)`);
  console.log(`Total Filled Amount:  ${stats.totalFilled.toFixed(8)}`);
  console.log(`Average Price:        ${formatNumber(Math.round(avgPrice))}`);
  console.log(`Average Latency:      ${Math.round(avgLatency)}ms`);
  console.log(`Overall Throughput:   ${throughput} orders/sec`);
  console.log(`Errors:               ${stats.errors}`);
  console.log('='.repeat(80));
}

/**
 * Main
 */
async function main() {
  const args = process.argv.slice(2);

  // Parse -p parameter
  let parallelCount = null;
  let filteredArgs = [];

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '-p' && i + 1 < args.length) {
      parallelCount = parseInt(args[i + 1]);
      i++; // Skip the next argument
    } else {
      filteredArgs.push(args[i]);
    }
  }

  if (filteredArgs.length === 0) {
    // List users
    await listUsers();
  } else if (filteredArgs.length === 1) {
    // List markets for user
    await listMarkets(filteredArgs[0]);
  } else if (filteredArgs.length === 2) {
    // Run load test
    if (parallelCount !== null && parallelCount > 0) {
      await runParallelLoadTest(filteredArgs[0], filteredArgs[1], parallelCount);
    } else {
      await runLoadTest(filteredArgs[0], filteredArgs[1]);
    }
  } else {
    console.error('Usage:');
    console.error('  node load-test-client.js                              # List users');
    console.error('  node load-test-client.js <user-id>                    # List markets');
    console.error('  node load-test-client.js <user-id> <market-id>        # Run load test');
    console.error('  node load-test-client.js -p <N> <user-id> <market-id> # Run with N parallel workers');
    process.exit(1);
  }
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
