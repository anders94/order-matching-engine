ALTER TABLE offers ADD CONSTRAINT offers_check_unfilled CHECK (unfilled <= volume);
