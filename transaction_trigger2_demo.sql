-- ▸ success + failure demo for “one active listing”
-- ▸ APPENDS output to transaction_trigger2.txt


\o | tee -a transaction_trigger2.txt
\qecho '==== Trigger 2 – demo run ===='
\set ON_ERROR_STOP on

-- clean slate for the demo: pick a property whose only listing(s) are already sold
\qecho '-- Selecting demo property with no active listings --'

SELECT p.property_id
INTO   TEMP TABLE demo_prop
FROM   properties p
LEFT   JOIN listings l USING (property_id)
GROUP  BY p.property_id
HAVING COUNT(*) FILTER (WHERE l.status = 'available') = 0 -- no active
LIMIT 1; -- suppose it returns 1798

\qecho '-- Property chosen --'
SELECT * FROM demo_prop;

-- Insert first active listing  — should succeed
\qecho '-- First active listing (should succeed) --'
INSERT INTO listings (property_id, listing_date, status)
SELECT property_id, CURRENT_DATE, 'available' FROM demo_prop;


-- Attempt to add *second* active listing  — should FAIL
\qecho '-- Second active listing (should fail) --'
\set ON_ERROR_STOP off         
-- allow script to continue after error
\set VERBOSITY terse
INSERT INTO listings (property_id, listing_date, status)
SELECT property_id, CURRENT_DATE+1, 'available' FROM demo_prop; -- triggers exception
\set VERBOSITY default
\set ON_ERROR_STOP on          
-- turn strict mode back on


-- Show that only one listing exists (rollback worked)
\qecho '-- Verify only one active listing exists --'
SELECT COUNT(*) AS active_cnt
FROM   listings
WHERE  property_id = (SELECT property_id FROM demo_prop)
  AND  status='available';

\qecho '---- Trigger 2 demo complete ----'
\o
