-- ▸ trigger that enforces a key business rule: “At most one active (available) listing per property.” 
-- If someone tries to create a second available listing, the trigger raises an exception → the entire transaction aborts.
-- ▸ writes progress to transaction_trigger2.txt  (overwrite)


\o transaction_trigger2.txt
\qecho '==== Trigger 2 – schema objects ===='
\timing on
\set ON_ERROR_STOP on

CREATE OR REPLACE FUNCTION trg_one_active_listing()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- run check only when the new row is marked 'available'
    IF NEW.status = 'available' THEN
        IF EXISTS (
            SELECT 1
            FROM   listings
            WHERE  property_id = NEW.property_id
              AND  status      = 'available'
              -- exclude self in case of BEFORE UPDATE
              AND  listing_id <> COALESCE(NEW.listing_id, -1)
        ) THEN
            RAISE EXCEPTION
              'Property % already has an active listing; cannot add another',
              NEW.property_id;
        END IF;
    END IF;

    RETURN NEW;   -- allow insert/update to proceed
END;
$$;

-- attach TRIGGER to listings table
DROP TRIGGER IF EXISTS trg_one_active_listing ON listings;

CREATE TRIGGER trg_one_active_listing
BEFORE INSERT OR UPDATE ON listings
FOR EACH ROW
EXECUTE FUNCTION trg_one_active_listing();

\qecho '---- Trigger 2 objects created ----'
\o