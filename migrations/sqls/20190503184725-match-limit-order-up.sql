-------------------------------------------------------------------
-- match_limit_order
--
-- Matches a limit order against offers in the book. Example usage:
-- SELECT match_limit_order((SELECT id FROM users WHERE email = 'user-a@example.com' AND obsolete = FALSE), (SELECT id FROM markets WHERE base_symbol = 'BTC' AND quote_symbol = 'USD' AND obsolete = FALSE), 'buy', 5010.0, 0.5, 'fills', 'offer');
-- SELECT match_limit_order((SELECT id FROM users WHERE email = 'user-a@example.com' AND obsolete = FALSE), (SELECT id FROM markets WHERE base_symbol = 'BTC' AND quote_symbol = 'USD' AND obsolete = FALSE), 'sell', 4993.0, 0.5, 'fills', 'offer');
--
-- Notes: Currently lots of copied code in this and no tests yet.
-- Cursors containing resulting fills and order are not yet implemented.
-------------------------------------------------------------------

CREATE OR REPLACE FUNCTION match_limit_order(_user_id UUID, _market_id UUID, _side buy_sell, _price NUMERIC, _volume NUMERIC, _fills REFCURSOR, _offer REFCURSOR)
  RETURNS SETOF REFCURSOR
  LANGUAGE plpgsql
AS $$
DECLARE
  match RECORD;
  remaining NUMERIC(32, 16);
  amount_taken NUMERIC(32, 16);
BEGIN
  CREATE TEMPORARY TABLE tmp_fills (
    fill_id UUID,
    price NUMERIC(32, 16),
    volume NUMERIC(32, 16)
  ) ON COMMIT DROP;
  RAISE NOTICE 'starting limit order';
  remaining := _volume;
  -- take any offers that cross
  IF _side = 'buy' THEN
    FOR match IN SELECT * FROM offers WHERE side = 'sell' AND price <= _price AND active = TRUE ORDER BY price ASC, created ASC LOOP
      RAISE NOTICE 'Found sell match %', match;
      IF remaining > 0 THEN
        IF remaining < match.unfilled THEN
          RAISE NOTICE '  remaining % < match.unfilled % = this offer is NOT completely filled by this order', remaining, match.unfilled;
          amount_taken := remaining;
          remaining := remaining - amount_taken;
          WITH fill AS (INSERT INTO fills (market_id, offer_id, maker_user_id, taker_user_id, price, volume) VALUES (_market_id, match.id, match.user_id, _user_id, match.price, amount_taken) RETURNING id, match.price, amount_taken) INSERT INTO tmp_fills SELECT * FROM fill;
          UPDATE offers SET unfilled = unfilled - amount_taken WHERE id = match.id;
	  IF remaining = 0 THEN
	    RAISE NOTICE '  order complete';
	  END IF;
        ELSE
          RAISE NOTICE '  remaining % >= match.filled % = this offer is completely filled by this order', remaining, match.unfilled;
          amount_taken := match.unfilled;
          remaining := remaining - amount_taken;
          WITH fill AS (INSERT INTO fills (market_id, offer_id, maker_user_id, taker_user_id, price, volume) VALUES (_market_id, match.id, match.user_id, _user_id, match.price, amount_taken) RETURNING id, match.price, amount_taken) INSERT INTO tmp_fills SELECT * FROM fill;
          UPDATE offers SET unfilled = unfilled - amount_taken, active = FALSE WHERE id = match.id;
          IF remaining = 0 THEN
            RAISE NOTICE '  order complete';
          END IF;
        END IF;
      END IF; -- if remaining > 0
    END LOOP;
  ELSE -- side is 'sell'
    FOR match IN SELECT * FROM offers WHERE side = 'buy' AND price >= _price AND active = TRUE ORDER BY price DESC, created ASC LOOP
      RAISE NOTICE 'Found buy match %', match;
      IF remaining > 0 THEN
        IF remaining <= match.unfilled THEN
          RAISE NOTICE '  remaining % < match.unfilled % = this offer isnt completely filled by this order', remaining, match.unfilled;
          amount_taken := remaining;
          remaining := remaining - amount_taken;
          WITH fill AS (INSERT INTO fills (market_id, offer_id, maker_user_id, taker_user_id, price, volume) VALUES (_market_id, match.id, match.user_id, _user_id, match.price, amount_taken) RETURNING id, match.price, amount_taken) INSERT INTO tmp_fills SELECT * FROM fill;
          UPDATE offers SET unfilled = unfilled - amount_taken WHERE id = match.id;
	  IF remaining = 0 THEN
	    RAISE NOTICE '  order complete';
	  END IF;
        ELSE
          RAISE NOTICE '  remaining % >= match.filled % = this offer is NOT completely filled by this order', remaining, match.unfilled;
          amount_taken := match.unfilled;
          remaining := remaining - amount_taken;
          WITH fill AS (INSERT INTO fills (market_id, offer_id, maker_user_id, taker_user_id, price, volume) VALUES (_market_id, match.id, match.user_id, _user_id, match.price, amount_taken) RETURNING id, match.price, amount_taken) INSERT INTO tmp_fills SELECT * FROM fill;
          UPDATE offers SET unfilled = unfilled - amount_taken, active = FALSE WHERE id = match.id;
          IF remaining = 0 THEN
            RAISE NOTICE '  order complete';
          END IF;
        END IF;

      END IF; -- if remaining > 0
    END LOOP;
  END IF;
  -- create an offer for whatever remains
  IF remaining > 0 THEN
    RAISE NOTICE 'INSERT INTO offers (user_id, market_id, side, price, volume) VALUES (%, %, %, %, %);', _user_id, _market_id, _side, _price, remaining;
    OPEN _offer FOR INSERT INTO offers (user_id, market_id, side, price, volume) VALUES (_user_id, _market_id, _side, _price, remaining) RETURNING price, volume;
  ELSE
    OPEN _offer FOR SELECT WHERE 1=2;
  END IF;
  RETURN NEXT _offer;
  -- return any fills
  OPEN _fills FOR SELECT * FROM tmp_fills;
  RETURN NEXT _fills;
END;
$$;
