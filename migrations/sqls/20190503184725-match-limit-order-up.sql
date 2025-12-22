
-------------------------------------------------------------------
-- match_limit_order
--
-- Matches a limit order against offers in the book. Example usage:
-- SELECT match_limit_order((SELECT id FROM users WHERE email = 'user-a@example.com' AND obsolete = FALSE), (SELECT id FROM markets WHERE base_symbol = 'BTC' AND quote_symbol = 'USD' AND obsolete = FALSE), 'buy', 5010000000, 50000000, 'fills', 'offer');
-- SELECT match_limit_order((SELECT id FROM users WHERE email = 'user-a@example.com' AND obsolete = FALSE), (SELECT id FROM markets WHERE base_symbol = 'BTC' AND quote_symbol = 'USD' AND obsolete = FALSE), 'sell', 4993000000, 50000000, 'fills', 'offer');
--
-- Notes: Price and amount must be integers (scale=0). Amount must be a multiple of the market's lot_size.
-- Example: For BTC/USD with lot_size=100000000 (1 BTC), price is in micro-USD per BTC, amount is in satoshis.
-------------------------------------------------------------------

CREATE OR REPLACE FUNCTION match_limit_order(_user_id UUID, _market_id UUID, _side buy_sell, _price NUMERIC, _amount NUMERIC, _fills REFCURSOR, _offer REFCURSOR)
  RETURNS SETOF REFCURSOR
  LANGUAGE plpgsql
AS $$
DECLARE
  match RECORD;
  amount_taken NUMERIC;
  amount_remaining NUMERIC;
  lot_size NUMERIC;
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

  CREATE TEMPORARY TABLE tmp_fills (
    fill_id UUID,
    price NUMERIC,
    amount NUMERIC
  ) ON COMMIT DROP;
  CREATE TEMPORARY TABLE tmp_offer (
    offer_id UUID,
    side buy_sell,
    price NUMERIC,
    amount NUMERIC
  ) ON COMMIT DROP;

  amount_remaining := _amount;

  -- take any offers that cross
  IF _side = 'buy' THEN
    FOR match IN SELECT * FROM offers WHERE market_id = _market_id AND side = 'sell' AND price <= _price AND active = TRUE ORDER BY price ASC, created ASC LOOP
      -- RAISE NOTICE 'Found sell match %', match;
      IF amount_remaining > 0 THEN
        IF amount_remaining < match.unfilled THEN
          -- RAISE NOTICE '  amount_remaining % < match.unfilled % = this offer is NOT completely filled by this order', amount_remaining, match.unfilled;
          amount_taken := amount_remaining;
          amount_remaining := amount_remaining - amount_taken;
          WITH fill AS (INSERT INTO fills (market_id, offer_id, maker_user_id, taker_user_id, price, amount) VALUES (_market_id, match.id, match.user_id, _user_id, match.price, amount_taken) RETURNING id, match.price, amount_taken) INSERT INTO tmp_fills SELECT * FROM fill;
          UPDATE offers SET unfilled = unfilled - amount_taken WHERE id = match.id;
	  IF amount_remaining = 0 THEN
	    -- RAISE NOTICE '  order complete';
            EXIT; -- exit loop
          END IF;
        ELSE
          -- RAISE NOTICE '  amount_remaining % >= match.unfilled % = this offer is completely filled by this order', amount_remaining, match.unfilled;
          amount_taken := match.unfilled;
          amount_remaining := amount_remaining - amount_taken;
          WITH fill AS (INSERT INTO fills (market_id, offer_id, maker_user_id, taker_user_id, price, amount) VALUES (_market_id, match.id, match.user_id, _user_id, match.price, amount_taken) RETURNING id, match.price, amount_taken) INSERT INTO tmp_fills SELECT * FROM fill;
          UPDATE offers SET unfilled = unfilled - amount_taken, active = FALSE WHERE id = match.id;
          IF amount_remaining = 0 THEN
            -- RAISE NOTICE '  order complete';
            EXIT; -- exit loop
          END IF;
        END IF;
      END IF; -- if amount_remaining > 0
    END LOOP;
  ELSE -- side is 'sell'
    FOR match IN SELECT * FROM offers WHERE market_id = _market_id AND side = 'buy' AND price >= _price AND active = TRUE ORDER BY price DESC, created ASC LOOP
      -- RAISE NOTICE 'Found buy match %', match;
      IF amount_remaining > 0 THEN
        IF amount_remaining < match.unfilled THEN
          -- RAISE NOTICE '  amount_remaining % < match.unfilled % = this offer isnt completely filled by this order', amount_remaining, match.unfilled;
          amount_taken := amount_remaining;
          amount_remaining := amount_remaining - amount_taken;
          WITH fill AS (INSERT INTO fills (market_id, offer_id, maker_user_id, taker_user_id, price, amount) VALUES (_market_id, match.id, match.user_id, _user_id, match.price, amount_taken) RETURNING id, match.price, amount_taken) INSERT INTO tmp_fills SELECT * FROM fill;
          UPDATE offers SET unfilled = unfilled - amount_taken WHERE id = match.id;
	  IF amount_remaining = 0 THEN
	    -- RAISE NOTICE '  order complete';
            EXIT; -- exit loop
	  END IF;
        ELSE
          -- RAISE NOTICE '  amount_remaining % >= match.unfilled % = this offer is NOT completely filled by this order', amount_remaining, match.unfilled;
          amount_taken := match.unfilled;
          amount_remaining := amount_remaining - amount_taken;
          WITH fill AS (INSERT INTO fills (market_id, offer_id, maker_user_id, taker_user_id, price, amount) VALUES (_market_id, match.id, match.user_id, _user_id, match.price, amount_taken) RETURNING id, match.price, amount_taken) INSERT INTO tmp_fills SELECT * FROM fill;
          UPDATE offers SET unfilled = unfilled - amount_taken, active = FALSE WHERE id = match.id;
          IF amount_remaining = 0 THEN
            -- RAISE NOTICE '  order complete';
            EXIT; -- exit loop
          END IF;
        END IF;
      END IF; -- if amount_remaining > 0
    END LOOP;
  END IF;

  -- create an offer for whatever remains
  IF amount_remaining > 0 THEN
    -- RAISE NOTICE 'INSERT INTO offers (user_id, market_id, side, price, amount) VALUES (%, %, %, %, %);', _user_id, _market_id, _side, _price, amount_remaining;
    WITH offer AS (INSERT INTO offers (user_id, market_id, side, price, amount) VALUES (_user_id, _market_id, _side, _price, amount_remaining) RETURNING id, side, price, amount) INSERT INTO tmp_offer SELECT * FROM offer;
  END IF;

  -- return results
  OPEN _fills FOR SELECT * FROM tmp_fills;
  RETURN NEXT _fills;

  OPEN _offer FOR SELECT * FROM tmp_offer;
  RETURN NEXT _offer;

END;
$$;
