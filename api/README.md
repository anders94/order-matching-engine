# Order Matching Engine API

A RESTful API for the PostgreSQL-based order matching engine.

## Starting the API

```bash
npm run api
```

Or with environment variables:

```bash
DB_USER=ome DB_NAME=ome_dev npm run api
```

The API will start on port 3000 by default (configurable via `PORT` environment variable).

## Environment Variables

- `PORT` - API server port (default: 3000)
- `DB_USER` - PostgreSQL user (default: ome)
- `DB_HOST` - PostgreSQL host (default: localhost)
- `DB_NAME` - PostgreSQL database name (default: ome_dev)
- `DB_PASSWORD` - PostgreSQL password (default: empty)
- `DB_PORT` - PostgreSQL port (default: 5432)

## API Endpoints

### Markets

#### GET /api/v1/markets
List all active markets.

**Response:**
```json
{
  "success": true,
  "markets": [
    {
      "id": "uuid",
      "base_symbol": "BTC",
      "quote_symbol": "USD",
      "created": "2019-05-03T19:11:42.537Z"
    }
  ]
}
```

#### GET /api/v1/markets/:marketId
Get a specific market by ID.

#### GET /api/v1/markets/:baseSymbol/:quoteSymbol
Get a market by symbol pair (e.g., `/api/v1/markets/BTC/USD`).

### Order Book

#### GET /api/v1/markets/:marketId/orderbook
Get the order book for a specific market.

**Query Parameters:**
- `depth` - Number of price levels to return (default: 20)

**Response:**
```json
{
  "success": true,
  "marketId": "uuid",
  "bids": [
    {
      "price": 89000,
      "amount": 1.121,
      "total": 99769
    }
  ],
  "asks": [
    {
      "price": 90100,
      "amount": 0.816,
      "total": 73521.6
    }
  ],
  "spread": 1100
}
```

### Orders

#### POST /api/v1/orders
Place a new limit order.

**Request Body:**
```json
{
  "userId": "uuid",
  "marketId": "uuid",
  "side": "buy",
  "price": 90100,
  "amount": 0.5
}
```

**Notes:**
- `side` must be either "buy" or "sell"
- `price` is in USD (will be converted to integer)
- `amount` is in BTC (will be converted to satoshis)

**Response:**
```json
{
  "success": true,
  "fills": [
    {
      "fillId": "uuid",
      "price": 90100,
      "amount": 0.5,
      "total": 45050
    }
  ],
  "offer": {
    "id": "uuid",
    "side": "buy",
    "price": 90100,
    "amount": 0.194
  },
  "summary": {
    "totalFills": 1,
    "totalFilled": 0.5,
    "offerCreated": true
  }
}
```

#### GET /api/v1/orders/:orderId
Get details of a specific order.

#### GET /api/v1/orders
Get a list of orders.

**Query Parameters:**
- `userId` - Filter by user ID (required)
- `marketId` - Filter by market ID (optional)
- `status` - Filter by status: "active" or "inactive" (optional)

### Fills

#### GET /api/v1/fills
Get fill history.

**Query Parameters:**
- `userId` - Filter by user ID (as maker or taker)
- `marketId` - Filter by market ID
- `offerId` - Filter by offer ID

**Response:**
```json
{
  "success": true,
  "fills": [
    {
      "id": "uuid",
      "created": "2019-05-03T19:12:22.096Z",
      "marketId": "uuid",
      "offerId": "uuid",
      "makerUserId": "uuid",
      "takerUserId": "uuid",
      "price": 90100,
      "amount": 0.5,
      "total": 45050
    }
  ]
}
```

#### GET /api/v1/orders/:orderId/fills
Get all fills for a specific order.

## Data Format

The API accepts floating point numbers for prices and amounts:
- **Prices**: USD values (e.g., 90100 for $90,100)
- **Amounts**: BTC values (e.g., 0.5 for 0.5 BTC)

Internally, the API converts:
- Amounts to satoshis (1 BTC = 100,000,000 satoshis)
- Prices to integers

Responses convert back to floating point for convenience.

## Error Handling

All error responses follow this format:

```json
{
  "success": false,
  "error": "Error message"
}
```

HTTP status codes:
- `200` - Success
- `400` - Bad request (validation error)
- `404` - Not found
- `500` - Internal server error
