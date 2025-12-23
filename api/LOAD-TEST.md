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
- Fetches the current order book
- Generates random but realistic trades
- 50% buy orders, 50% sell orders
- ~50% of trades cross the spread (result in fills)
- Trade sizes: mostly small (1-2 units), some medium (2-5), few large (5-10)
- Prints a single line summary for each trade
- Includes running statistics

**Example:**
```bash
node api/load-test-client.js 1a884fc0-a528-46db-a981-05669c98affc be153bd6-c5a8-4ad8-859f-8b72f7ab9a9d
```

Output:
```
Starting load test for user 1a884fc0-a528-46db-a981-05669c98affc on market be153bd6-c5a8-4ad8-859f-8b72f7ab9a9d
Press Ctrl+C to stop

[1] FILLED SELL 10.00000000 @ 4,997,723,114 | 1x fills, 1.12100000 filled | 17ms | fills: 1/1 (100.0%)
[2] FILLED SELL 2.00000000 @ 4,992,910,663 | 2x fills, 1.18500000 filled | 14ms | fills: 2/2 (100.0%)
[3] POSTED SELL 2.00000000 @ 4,996,773,901 | 2.00000000 posted | 11ms | fills: 2/3 (66.7%)
[4] POSTED BUY 2.00000000 @ 4,989,596,166 | 2.00000000 posted | 11ms | fills: 2/4 (50.0%)
...
```

### Output Format

Each trade shows:
- `[N]` - Trade number
- `FILLED` or `POSTED` - Whether the order crossed the spread
- `BUY`/`SELL` - Order side
- Amount and price
- Fill details or posted amount
- Latency in milliseconds
- Running fill ratio

## Running Multiple Clients

For proper load testing, run multiple clients simultaneously:

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
