# Load Test Client

A simple load testing client for the Order Matching Engine API.

## Prerequisites

Make sure the API server is running:

```bash
npm run api
```

## Usage

You can use either `npm run load-test` or directly call `node api/load-test-client.js`.

### 1. List Users

```bash
npm run load-test
# or
node api/load-test-client.js
```

Shows all active users with their IDs and email addresses.

### 2. List Markets

```bash
npm run load-test <user-id>
# or
node api/load-test-client.js <user-id>
```

Lists all available markets with their IDs.

**Example:**
```bash
node api/load-test-client.js 1a884fc0-a528-46db-a981-05669c98affc
```

Output:
```
Markets (for user 1a884fc0-a528-46db-a981-05669c98affc):
  be153bd6-c5a8-4ad8-859f-8b72f7ab9a9d - BTC/USD
  e9c89ad9-7318-4098-9fa2-585bd1c32cd5 - ETH/USD
```

### 3. Run Load Test

```bash
npm run load-test <user-id> <market-id>
# or
node api/load-test-client.js <user-id> <market-id>
```

Runs a continuous load test that:
- Fetches the current order book initially, then refetches every 10 trades
- Generates random but realistic trades based on the cached order book
- 50% buy orders, 50% sell orders
- ~50% of trades cross the spread (result in fills)
- Trade sizes: mostly small (1-2 units), some medium (2-5), few large (5-10)
- Prints a single line summary for each trade
- Shows `[BOOK]` indicator when the order book is refreshed
- Includes running statistics

**Example:**
```bash
node api/load-test-client.js 1a884fc0-a528-46db-a981-05669c98affc be153bd6-c5a8-4ad8-859f-8b72f7ab9a9d
```

Output:
```
Starting load test for user 1a884fc0-a528-46db-a981-05669c98affc on market be153bd6-c5a8-4ad8-859f-8b72f7ab9a9d
Press Ctrl+C to stop

[1] POSTED BUY 3.00000000 @ 4,986,850,099 | 3.00000000 posted | 9ms | fills: 0/1 (0.0%)
[2] POSTED BUY 2.00000000 @ 4,981,557,865 | 2.00000000 posted | 13ms | fills: 0/2 (0.0%)
...
[10] POSTED BUY 1.00000000 @ 4,985,993,369 | 1.00000000 posted | 14ms | fills: 4/10 (40.0%) [BOOK]
...
[20] FILLED SELL 2.00000000 @ 4,963,883,044 | 2x fills, 2.00000000 filled | 13ms | fills: 9/20 (45.0%) [BOOK]
...
```

### 4. Run Parallel Load Test

```bash
node api/load-test-client.js -p <workers> <user-id> <market-id>
```

Runs a parallel load test with multiple concurrent workers:
- Spawns N worker threads that independently place orders
- Workers share the same user and market
- Each worker fetches order book every 10 trades
- Prints aggregate statistics every 5 seconds
- Shows final summary statistics on Ctrl+C
- Individual worker errors are printed immediately

**Example:**
```bash
node api/load-test-client.js -p 3 1a884fc0-a528-46db-a981-05669c98affc be153bd6-c5a8-4ad8-859f-8b72f7ab9a9d
```

Output:
```
Starting parallel load test with 3 concurrent workers
User: 1a884fc0-a528-46db-a981-05669c98affc, Market: be153bd6-c5a8-4ad8-859f-8b72f7ab9a9d
Press Ctrl+C to stop

Orders:   87 | Fills:  45.6% | Avg Price:      91,234,567 | Avg Latency:   12ms | Throughput:   17.4 orders/sec
Orders:   94 | Fills:  48.9% | Avg Price:      90,987,654 | Avg Latency:   11ms | Throughput:   18.8 orders/sec
Orders:   91 | Fills:  46.2% | Avg Price:      91,456,789 | Avg Latency:   13ms | Throughput:   18.2 orders/sec
...
^C

Stopping...

================================================================================
FINAL STATISTICS
================================================================================
Total Runtime:        45.3s
Total Orders:         856
Total Fills:          402 (47.0%)
Total Filled Amount:  1234.56789012
Average Price:        91,123,456
Average Latency:      12ms
Overall Throughput:   18.9 orders/sec
Errors:               0
================================================================================
```

### Output Format

#### Single Worker Mode
Each trade shows:
- `[N]` - Trade number
- `FILLED` or `POSTED` - Whether the order crossed the spread
- `BUY`/`SELL` - Order side
- Amount and price
- Fill details or posted amount
- Latency in milliseconds
- Running fill ratio
- `[BOOK]` - Indicator shown every 10 trades when the order book is refreshed (optimization to reduce API calls)

#### Parallel Mode
Every 5 seconds, aggregate statistics show:
- Orders placed in the interval
- Fill rate (percentage of orders that resulted in fills)
- Average price across all orders
- Average latency
- Throughput (orders per second)

Final statistics include totals for the entire run.

## Running Multiple Clients

### Option 1: Parallel Mode (Recommended)

The easiest way to run multiple workers is using the `-p` parameter:

```bash
node api/load-test-client.js -p 5 <user-id> <market-id>
```

This spawns 5 concurrent workers in a single process with aggregate statistics.

### Option 2: Multiple Terminal Windows

For testing with different users, run separate clients in different terminals:

```bash
# Terminal 1
node api/load-test-client.js <user1-id> <market-id>

# Terminal 2
node api/load-test-client.js <user2-id> <market-id>

# Terminal 3
node api/load-test-client.js <user3-id> <market-id>

# etc...
```

Each client will independently generate trades, creating realistic market activity.

## Configuration

Set the API base URL via environment variable:

```bash
API_BASE=http://localhost:3000 node api/load-test-client.js <user-id> <market-id>
```

Default: `http://localhost:3000`

## Notes

- The client generates whole number amounts (1.0, 2.0, etc.) to comply with lot_size constraints
- Trades are generated based on the current order book state
- A small 100ms delay between trades prevents overwhelming the server
- Press Ctrl+C to stop the load test
- The same user can be on both sides of a trade (this is just for load testing)
