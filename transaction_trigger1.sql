-- ▸ creates audit table, trigger function, trigger
-- ▸ writes progress to transaction_trigger.txt  (overwrite)


\o transaction_trigger1.txt 
-- start fresh log
\qecho '==== Trigger 1 – schema objects ===='
\timing on
\set ON_ERROR_STOP on

-- 1. purpose: keep an immutable record only when a sale (transaction) succeeds | Audit table
CREATE TABLE IF NOT EXISTS transaction_audit (
    id          SERIAL PRIMARY KEY,             -- auto‑increment surrogate
    tx_id       INT,                            -- FK to transactions.transaction_id
    note        TEXT,                           -- free‑form message
    logged_at   TIMESTAMPTZ DEFAULT NOW()       -- time the trigger fired
);

-- 2. trigger function that writes to the audit table; 
-- fires after each successful insert into transactions, 
-- NEW is the freshly inserted row.
-- Because it’s AFTER INSERT, it never fires if the containing transaction is rolled back.
CREATE OR REPLACE FUNCTION trg_log_transaction()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO transaction_audit (tx_id, note)
    VALUES (NEW.transaction_id, format('Sale recorded for property %s', NEW.property_id));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Attach TRIGGER to the transactions table
DROP TRIGGER IF EXISTS trg_trans_audit ON transactions;

CREATE TRIGGER trg_trans_audit
AFTER INSERT ON transactions
FOR EACH ROW
EXECUTE FUNCTION trg_log_transaction();

\qecho '---- Trigger 1 objects created ----'
\o