# Integer-Based Precision System Migration Plan

## Problem Statement

The current order matching system uses `NUMERIC(32,16)` for all prices and amounts, providing exact decimal arithmetic. However, when calculating totals using `price × amount`, there's a potential for fractional residues that can never fully be consumed due to decimal representation limits.

**Goal:** Eliminate all floating-point/decimal precision issues by using pure integer arithmetic, where all values represent the smallest indivisible units of assets.

## Current System Analysis

### Database Schema
- **Prices:** `NUMERIC(32,16)` - 32 total digits, 16 decimal places
- **Amounts:** `NUMERIC(32,16)`
- **Assets:** Have `significant_digits` field (USD=2, BTC=8, ETH=18)
- **Markets:** No lot size concept currently

### Key Observations
1. System does NOT calculate `quote_value = price × amount` in current implementation
2. Fees are stored separately, not calculated from price × amount
3. All matching logic runs in PostgreSQL stored procedures
4. Uses exact decimal arithmetic (not floating-point), but still has fractional precision

## Precision Analysis

### Asset Base Units
Real-world cryptocurrencies use integer base units:
- **USDC:** 1,000,000 units per dollar (6 decimals)
- **BTC:** 100,000,000 satoshis per BTC (8 decimals)
- **ETH:** 1,000,000,000,000,000,000 wei per ETH (18 decimals)

### Price Representation Challenge

**Core insight:** Price precision is determined by the lot size used for quoting.

**Formula:** `total_quote_units = (price × amount) / lot_size`

Where:
- `price` = quote asset units per `lot_size` base asset units
- `amount` = base asset units
- `lot_size` = how many base asset units the price refers to

### Precision Examples

#### Scenario 1: BTC/USD at $50,000/BTC with lot_size = 100,000,000 (1 BTC)

- `price = 50,000,000,000` (50 billion micro-USD per BTC)
- Minimum price increment: 1 micro-USD per BTC = **$0.000001 per BTC**
- Granularity: 0.000002% ✅ Excellent precision

#### Scenario 2: BTC/USD at $0.10/BTC with lot_size = 100,000,000 (1 BTC)

- `price = 100,000` (100k micro-USD per BTC)
- Minimum price increment: 1 micro-USD per BTC = **$0.000001 per BTC**
- Granularity: 0.001% ✅ Still good precision

#### Scenario 3: BTC/USD at $0.10/BTC with lot_size = 1,000 (0.00001 BTC)

- 1000 sats at $0.10/BTC = $0.000001 = 1 micro-USD
- `price = 1`
- Minimum price increment: 1 micro-USD per 1000 sats = **$0.10 per BTC**
- Granularity: 100% price jumps ❌ Too coarse
- Can only have prices: $0.10, $0.20, $0.30...

**Conclusion:** Smaller lot sizes reduce price precision at low prices.

#### Scenario 4: BTC/USD at $0.000001/BTC (extreme crash) with lot_size = 1 (1 satoshi)

- 1 sat = $0.00000000001 = 0.00001 micro-USD
- **Cannot represent as integer!** ❌

**Conclusion:** At extreme low prices, lot_size must be increased (more base units per lot) to keep prices representable as integers, even though it restricts minimum order sizes.

## Fractional Lot Size Consideration

### Proposed Enhancement
Add numerator/denominator for lot size to decouple order size granularity from price precision:

```sql
lot_size_num BIGINT    -- Orders must be multiples of this
lot_size_denom BIGINT  -- Adds price precision scaling
```

**Formula:** `total_quote = (price × amount) / (lot_size_num × lot_size_denom)`

### Analysis

**Benefits:**
- Decouple minimum order size from price precision
- Add arbitrary price precision without changing order size requirements
- Market-specific tuning

**Trade-offs:**
- Adds complexity
- Still doesn't eliminate fundamental integer arithmetic constraints at extreme prices
- Marginal benefit for realistic price ranges

### Decision: Start Simple

**Recommendation:** Use single integer `lot_size`, add fractional later only if needed.

**Rationale:**
- Simpler implementation
- Adequate for realistic price ranges with proper lot_size selection
- Can add fractional lot_size in future if edge cases emerge
- Markets can adjust lot_size if precision becomes inadequate

## Data Type Selection: NUMERIC vs BIGINT

### BIGINT Limitations
- Max value: 9,223,372,036,854,775,807 (≈ 9.2 × 10^18)
- Overflow risk with `price × amount` intermediate calculations
- Would require casting to NUMERIC for multiplication anyway

### NUMERIC with Scale=0 Advantages
✅ **Arbitrary precision** - No overflow concerns
✅ **Still exact integer arithmetic** - Scale of 0 means no decimals
✅ **Simpler code** - No casting needed for intermediate calculations
✅ **PostgreSQL optimized** - Still very performant
✅ **Validation** - Can use `CHECK (scale(value) = 0)` to enforce integers

**Decision:** Use `NUMERIC` with scale validation for all integer values.

## Implementation Plan

### Phase 1: Schema Changes

**File:** `migrations/sqls/20190425191949-base-tables-up.sql`

#### 1.1 Update `assets` table
```sql
CREATE TABLE assets (
  symbol             VARCHAR(8)      NOT NULL,
  created            TIMESTAMP       NOT NULL DEFAULT now(),
  base_unit_scale    NUMERIC         NOT NULL,  -- e.g., 1000000 for USDC, 100000000 for BTC
  attributes         JSON            NOT NULL DEFAULT '{}'::JSON,
  obsolete           BOOLEAN         NOT NULL DEFAULT FALSE,
  CONSTRAINT pk_assets_symbol PRIMARY KEY (symbol),
  CHECK (base_unit_scale > 0)
);
```

**Changes:**
- Remove `significant_digits`
- Add `base_unit_scale` (10^decimals for the asset)

#### 1.2 Update `markets` table
```sql
CREATE TABLE markets (
  id                 UUID            NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  created            TIMESTAMP       NOT NULL DEFAULT now(),
  base_symbol        VARCHAR(8)      NOT NULL REFERENCES assets(symbol),
  quote_symbol       VARCHAR(8)      NOT NULL REFERENCES assets(symbol),
  lot_size           NUMERIC         NOT NULL,
  attributes         JSON            NOT NULL DEFAULT '{}'::JSON,
  obsolete           BOOLEAN         NOT NULL DEFAULT FALSE,
  CONSTRAINT pk_markets_base_symbol_quote_symbol PRIMARY KEY (base_symbol, quote_symbol),
  CHECK (lot_size > 0)
);
```

**Changes:**
- Add `lot_size` column

#### 1.3 Update `offers` table
```sql
CREATE TABLE offers (
  id                 UUID            NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  created            TIMESTAMP       NOT NULL DEFAULT now(),
  user_id            UUID            NOT NULL REFERENCES users(id),
  market_id          UUID            NOT NULL REFERENCES markets(id),
  side               buy_sell        NOT NULL,
  price              NUMERIC         NOT NULL CHECK (price > 0 AND scale(price) = 0),
  amount             NUMERIC         NOT NULL CHECK (amount > 0 AND scale(amount) = 0),
  unfilled           NUMERIC         NOT NULL CHECK (unfilled >= 0 AND unfilled <= amount AND scale(unfilled) = 0),
  active             BOOLEAN         NOT NULL DEFAULT TRUE,
  PRIMARY KEY (market_id, side, price, created, id)
);
```

**Changes:**
- Change `NUMERIC(32,16)` → `NUMERIC`
- Add `scale(column) = 0` checks to enforce integers

#### 1.4 Update `fills` table
```sql
CREATE TABLE fills (
  id                 UUID            NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  created            TIMESTAMP       NOT NULL DEFAULT now(),
  market_id          UUID            NOT NULL REFERENCES markets(id),
  offer_id           UUID            NOT NULL REFERENCES offers(id),
  maker_user_id      UUID            NOT NULL REFERENCES users(id),
  taker_user_id      UUID            NOT NULL REFERENCES users(id),
  price              NUMERIC         NOT NULL CHECK (price > 0 AND scale(price) = 0),
  amount             NUMERIC         NOT NULL CHECK (amount > 0 AND scale(amount) = 0),
  maker_fee          NUMERIC         NOT NULL DEFAULT 0 CHECK (maker_fee >= 0 AND scale(maker_fee) = 0),
  taker_fee          NUMERIC         NOT NULL DEFAULT 0 CHECK (taker_fee >= 0 AND scale(taker_fee) = 0),
  PRIMARY KEY (id)
);
```

**Changes:**
- Change `NUMERIC(32,16)` → `NUMERIC`
- Add `scale(column) = 0` checks

### Phase 2: Update Matching Function

**File:** `migrations/sqls/20190503184725-match-limit-order-up.sql`

```sql
CREATE OR REPLACE FUNCTION match_limit_order(
  _user_id UUID,
  _market_id UUID,
  _side buy_sell,
  _price NUMERIC,
  _amount NUMERIC,
  _fills REFCURSOR,
  _offer REFCURSOR
)
  RETURNS SETOF REFCURSOR
  LANGUAGE plpgsql
AS $function$
DECLARE
  match              RECORD;
  amount_remaining   NUMERIC;
  amount_taken       NUMERIC;
  lot_size           NUMERIC;
BEGIN
  -- Validate inputs are integers
  IF scale(_price) != 0 OR scale(_amount) != 0 THEN
    RAISE EXCEPTION 'Price and amount must be integers (scale=0)';
  END IF;

  -- Fetch market's lot_size
  SELECT m.lot_size INTO lot_size
  FROM markets m
  WHERE m.id = _market_id;

  -- Validate amount is multiple of lot_size
  IF _amount % lot_size != 0 THEN
    RAISE EXCEPTION 'Amount must be a multiple of lot_size (%)' , lot_size;
  END IF;

  amount_remaining := _amount;

  -- [Rest of matching logic remains unchanged]
  -- The FOR loop, amount calculations, etc. stay the same

END;
$function$;
```

**Changes:**
- Remove `NUMERIC(32,16)` precision specifications → `NUMERIC`
- Add validation for integer values (scale=0)
- Add validation for lot_size multiples
- Fetch and use lot_size from markets table

**Note:** The actual matching loop logic (amount subtraction, offer updates) remains unchanged.

### Phase 3: Update Triggers

**File:** `migrations/sqls/20190426003357-populate-unfilled-up.sql`

No changes needed - trigger assigns `NEW.unfilled := NEW.amount`, which works with NUMERIC.

**File:** `migrations/sqls/20190429160347-block-crosses-up.sql`

```sql
CREATE OR REPLACE FUNCTION block_crosses()
  RETURNS trigger AS $function$
BEGIN
  IF NEW.side = 'buy' AND NEW.price >= (
    SELECT price
    FROM offers
    WHERE market_id = NEW.market_id
      AND side = 'sell'
      AND unfilled > 0
      AND active = TRUE
    ORDER BY price ASC
    LIMIT 1
  ) THEN
    RAISE EXCEPTION 'This order would result in a crossed book.';
    RETURN NULL;
  ELSIF NEW.side = 'sell' AND NEW.price <= (
    SELECT price
    FROM offers
    WHERE market_id = NEW.market_id
      AND side = 'buy'
      AND unfilled > 0
      AND active = TRUE
    ORDER BY price DESC
    LIMIT 1
  ) THEN
    RAISE EXCEPTION 'This order would result in a crossed book.';
    RETURN NULL;
  END IF;
  RETURN NEW;
END;
$function$
LANGUAGE plpgsql;
```

**Changes:**
- Change `0.0` → `0` literals (cosmetic)

### Phase 4: Update Test Data

**File:** `migrations/test-data/sqls/20190429141424-initial-test-data-up.sql`

#### 4.1 Assets with base_unit_scale
```sql
INSERT INTO assets (symbol, base_unit_scale, attributes)
VALUES
  ('USD', 1000000, '{"description": "USDC with 6 decimals"}'),
  ('BTC', 100000000, '{"description": "Bitcoin with 8 decimals"}'),
  ('ETH', 1000000000000000000, '{"description": "Ethereum with 18 decimals"}');
```

#### 4.2 Markets with lot_size
```sql
INSERT INTO markets (base_symbol, quote_symbol, lot_size)
VALUES
  ('BTC', 'USD', 100000000),              -- Price quotes per 1 BTC
  ('ETH', 'USD', 1000000000000000000);    -- Price quotes per 1 ETH
```

**Interpretation:**
- BTC/USD: `price` = micro-USD per 100,000,000 satoshis (per 1 BTC)
- ETH/USD: `price` = micro-USD per 10^18 wei (per 1 ETH)

#### 4.3 User balances (integer base units)
```sql
INSERT INTO balances (user_id, asset, available, locked)
VALUES
  -- Alice
  (alice.id, 'USD', 100000000000, 0),      -- 100,000 USD
  (alice.id, 'BTC', 0, 0),
  (alice.id, 'ETH', 0, 0),
  -- Bob
  (bob.id, 'USD', 0, 0),
  (bob.id, 'BTC', 1000000000, 0),          -- 10 BTC
  (bob.id, 'ETH', 1000000000000000000, 0); -- 1 ETH
```

#### 4.4 Sample orders (integer values)
```sql
-- Bob sells 0.816 BTC at $5001.50/BTC
INSERT INTO offers (user_id, market_id, side, price, amount)
SELECT
  bob.id,
  m.id,
  'sell',
  5001500000,   -- $5001.50/BTC = 5,001,500,000 micro-USD per BTC
  81600000      -- 0.816 BTC = 81,600,000 satoshis
FROM (SELECT id FROM users WHERE email = 'bob@example.com') bob
CROSS JOIN (SELECT id FROM markets WHERE base_symbol = 'BTC' AND quote_symbol = 'USD') m;

-- Alice buys 0.816 BTC at $5001.50/BTC
INSERT INTO offers (user_id, market_id, side, price, amount)
SELECT
  alice.id,
  m.id,
  'buy',
  5001500000,
  81600000
FROM (SELECT id FROM users WHERE email = 'alice@example.com') alice
CROSS JOIN (SELECT id FROM markets WHERE base_symbol = 'BTC' AND quote_symbol = 'USD') m;
```

### Phase 5: Update Tests

**File:** `test.js`

Update assertions for integer values:

```javascript
// OLD
assert(fill.price === 5001.5)
assert(fill.amount === 0.816)

// NEW
assert(fill.price === 5001500000)  // $5001.50/BTC in micro-USD per BTC
assert(fill.amount === 81600000)   // 0.816 BTC in satoshis
```

Add validation tests:
- Orders with non-integer values should fail
- Orders with amounts not divisible by lot_size should fail
- Verify exact division: `(price × amount) / lot_size` produces integer result
- Verify no precision loss in total calculations

## Summary of File Changes

| File | Changes |
|------|---------|
| `base-tables-up.sql` | • `NUMERIC(32,16)` → `NUMERIC`<br>• Add `scale(col) = 0` checks<br>• Add `lot_size` to markets<br>• Add `base_unit_scale` to assets<br>• Remove `significant_digits` |
| `match-limit-order-up.sql` | • Update parameter/variable types<br>• Add lot_size validation<br>• Add integer validation |
| `block-crosses-up.sql` | • Change decimal literals to integers |
| `populate-unfilled-up.sql` | • No changes needed |
| `initial-test-data-up.sql` | • Convert all values to integers<br>• Set base_unit_scale for assets<br>• Set lot_size for markets |
| `test.js` | • Update assertions for integers<br>• Add validation tests |

## Example Calculations

### Market Configuration
- **Market:** BTC/USD
- **lot_size:** 100,000,000 (1 BTC)
- **BTC base_unit_scale:** 100,000,000 (8 decimals)
- **USD base_unit_scale:** 1,000,000 (6 decimals)

### Order Example
**Buy 0.816 BTC at $5001.50/BTC**

**Input values:**
- `amount = 81,600,000` satoshis (0.816 BTC)
- `price = 5,001,500,000` micro-USD per BTC ($5001.50)

**Validation:**
```sql
-- Is amount a multiple of lot_size?
81,600,000 % 100,000,000 = 81,600,000  -- NOT a multiple!
```

**Issue:** This order would be rejected because 0.816 BTC is not a multiple of lot_size (1 BTC).

**Valid alternative:** Adjust lot_size to smaller value (e.g., 10,000 sats) or require amounts to be whole BTCs.

### Corrected Example
**Market with lot_size = 10,000 (0.0001 BTC minimum)**

**Buy 0.816 BTC at $5001.50/BTC**
- `amount = 81,600,000` satoshis
- `price = 50015` micro-USD per 10,000 sats

**Validation:**
```sql
81,600,000 % 10,000 = 0  -- Valid!
```

**Total calculation:**
```sql
total_quote = (50015 × 81,600,000) / 10,000
            = 4,081,224,000,000 / 10,000
            = 408,122,400,000 micro-USD
            = $408,122.40
```

Wait, that's wrong. Let me recalculate:
- 0.816 BTC at $5001.50/BTC = $4,081.224

Let me recalculate the price with lot_size = 10,000:
- 10,000 sats = 0.0001 BTC
- At $5001.50/BTC: 0.0001 BTC = $0.50015 = 500,150 micro-USD
- `price = 500150`

**Total calculation:**
```sql
total_quote = (500150 × 81,600,000) / 10,000
            = 40,812,240,000,000 / 10,000
            = 4,081,224,000,000 micro-USD
            = $4,081,224.00
```

Still wrong. Let me recalculate more carefully:
- 0.816 BTC × $5001.50/BTC = $4081.224

With lot_size = 10,000 sats per lot:
- `price` = micro-USD per 10,000 sats
- 10,000 sats at $5001.50/BTC = 0.0001 BTC × $5001.50 = $0.500150 = 500,150 micro-USD
- `price = 500150`
- `amount = 81,600,000` sats
- `total = (500150 × 81,600,000) / 10,000 = 4,081,224,000 micro-USD = $4,081.224` ✅

**Perfect!** Exact integer division with no remainder.

## Benefits of Integer System

✅ **Zero precision loss** - All arithmetic is exact integer operations
✅ **Guaranteed exact division** - `(price × amount) / lot_size` always yields integer
✅ **No dust** - Amounts must be multiples of lot_size
✅ **Performance** - Integer operations faster than NUMERIC with decimals
✅ **Deterministic** - No rounding ambiguity
✅ **Arbitrary precision** - NUMERIC handles any size integer
✅ **Standard practice** - Matches how blockchains actually work

## Future Enhancements

### Fractional Lot Size (if needed)
If price precision at extreme prices becomes an issue:

```sql
ALTER TABLE markets ADD COLUMN lot_size_num NUMERIC NOT NULL DEFAULT 1;
ALTER TABLE markets ADD COLUMN lot_size_denom NUMERIC NOT NULL DEFAULT 1;
ALTER TABLE markets RENAME COLUMN lot_size TO lot_size_legacy;
```

Formula: `total_quote = (price × amount) / (lot_size_num × lot_size_denom)`

This would allow decoupling order size granularity from price precision.

### Dynamic Lot Size Adjustment
Markets could support automatic lot_size adjustment based on price levels:
- High prices: Larger lot_size (e.g., 1 BTC)
- Low prices: Smaller lot_size (e.g., 0.0001 BTC)

This would require application-level logic to manage lot_size changes.

## Deployment Notes

- All deployments assumed fresh (no migration from existing data)
- No backward compatibility concerns
- All SQL files modified in place
- Test data reflects new integer-based system
- Application layer must handle conversion between user-facing decimals and integer base units

## Validation Checklist

- [ ] All NUMERIC columns have scale=0 checks
- [ ] lot_size added to all markets
- [ ] base_unit_scale added to all assets
- [ ] All test data uses integer values
- [ ] Orders validated as lot_size multiples
- [ ] Matching function validates integer inputs
- [ ] Tests verify exact division in calculations
- [ ] No decimal literals in SQL (use 0 instead of 0.0)
