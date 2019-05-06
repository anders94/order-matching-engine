--
-- automatically populate 'unfilled' column with value from 'amount' column
--
-- Populating the 'unfilled' column shouldn't be the responsibility of the order submitter. This
-- also limits errors by overwriting whatever is passed in the INSERT.

CREATE OR REPLACE FUNCTION populate_unfilled() RETURNS trigger AS '
BEGIN
  NEW.unfilled := NEW.amount;
  RETURN NEW;
END;
' LANGUAGE plpgsql;

CREATE TRIGGER tr_offer_insert BEFORE INSERT ON offers FOR EACH ROW EXECUTE PROCEDURE populate_unfilled();
