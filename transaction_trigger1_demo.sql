-- ▸ runs success + failure demo
-- ▸ APPENDS output to transaction_trigger.txt


\o | tee -a transaction_trigger1.txt
-- append using tee
\qecho '==== Trigger 1 – demo run ===='
\set ON_ERROR_STOP on


-- DEMO PROCEDURE that sometimes FAILS on purpose
CREATE OR REPLACE PROCEDURE demo_sale_maybe_fail(
    _buyer_id    INT,
    _property_id INT,
    _amount      FLOAT,
    _make_it_fail BOOLEAN DEFAULT FALSE -- pass TRUE to trigger failure
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_tx_id INT;
BEGIN
    -- step 1: insert into transactions  (this will fire the trigger)
    INSERT INTO transactions (buyer_id, property_id, amount, date)
    VALUES (_buyer_id, _property_id, _amount, CURRENT_DATE)
    RETURNING transaction_id INTO v_tx_id;

    -- OPTIONAL failure step
    IF _make_it_fail THEN
        -- duplicate PK on purpose → raises unique‑violation error
        INSERT INTO mortgages (mortgage_id, buyer_id, property_id,
                               loan_amount, interest_rate, term_years)
        VALUES (v_tx_id, _buyer_id, _property_id,  _amount*0.8, 4.5, 30);
        INSERT INTO mortgages (mortgage_id, buyer_id, property_id,
                               loan_amount, interest_rate, term_years)
        VALUES (v_tx_id, _buyer_id, _property_id,  _amount*0.8, 4.5, 30);  -- <-- duplicate
    ELSE
        -- normal mortgage insert
        INSERT INTO mortgages (mortgage_id, buyer_id, property_id,
                               loan_amount, interest_rate, term_years)
        VALUES (v_tx_id, _buyer_id, _property_id,  _amount*0.8, 4.5, 30);
    END IF;
END;
$$;



TRUNCATE transaction_audit; -- clear the audit table for demo purposes
\qecho '-- audit table truncated --'

\qecho '-- Successful sale (should commit) --'
CALL demo_sale_maybe_fail(77, 950, 615000); -- successful sale

\qecho '-- Audit after success --'
SELECT * FROM transaction_audit ORDER BY id DESC LIMIT 1; -- screenshot shows one audit row

\qecho '-- Failing sale (duplicate key expected) --'
\set ON_ERROR_STOP off          
-- allow script to continue after error
\set VERBOSITY terse
CALL demo_sale_maybe_fail(77, 950, 615000, TRUE); -- failing sale; Expect: ERROR:  duplicate key value violates unique constraint "mortgages_pkey"
\set VERBOSITY default
\set ON_ERROR_STOP on           
-- strict mode back on


\qecho '-- Audit after failure (should be unchanged) --'
SELECT * FROM transaction_audit ORDER BY id DESC LIMIT 2; -- screenshot shows STILL only the first audit row (nothing new added)

\qecho '---- Trigger 1 demo complete ----'
\o


