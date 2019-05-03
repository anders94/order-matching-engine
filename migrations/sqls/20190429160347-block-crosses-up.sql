--
-- block crosses in the offers table
--

CREATE OR REPLACE FUNCTION block_crosses()
RETURNS trigger AS $function$
BEGIN
  IF NEW.side = 'buy' AND NEW.price >= (SELECT price FROM offers WHERE market_id = NEW.market_id AND side = 'sell' AND unfilled > 0.0 AND active = TRUE ORDER BY price ASC LIMIT 1) THEN
    RAISE EXCEPTION 'This order would result in a crossed book.';
    RETURN NULL;
  ELSIF NEW.side = 'sell' AND NEW.price <= (SELECT price FROM offers WHERE market_id = NEW.market_id AND side = 'buy' AND unfilled > 0.0 AND active = TRUE ORDER BY price DESC LIMIT 1) THEN
    RAISE EXCEPTION 'This order would result in a crossed book.';
    RETURN NULL;
  END IF;
  RETURN NEW;
END;
$function$ LANGUAGE plpgsql;

CREATE TRIGGER tr_offer_block_crosses BEFORE INSERT OR UPDATE ON offers FOR EACH ROW EXECUTE PROCEDURE block_crosses();
