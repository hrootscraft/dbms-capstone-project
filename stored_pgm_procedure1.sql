-- A known buyer (already in buyers table) is buying a listed property, and you want to record the sale and mortgage in one go.
-- inserts transaction --> closes an active listing --> auto‑creates mortgage

CREATE OR REPLACE PROCEDURE create_sale(
        _buyer_id INT,  -- who is buying
        _property_id INT,   -- what they’re buying
        _amount FLOAT,  -- agreed sale price
        _interest FLOAT DEFAULT 4.5,    -- mortgage rate if omitted
        _term_years INT DEFAULT 30  -- amortisation period if omitted; if you pass only the first three arguments, it assumes a 4.5 % / 30‑year loan.
    ) LANGUAGE plpgsql AS $$
DECLARE v_tx_id INT;

BEGIN -- 1. insert transaction
INSERT INTO transactions (buyer_id, property_id, amount, date)
VALUES (_buyer_id, _property_id, _amount, CURRENT_DATE)
RETURNING transaction_id INTO v_tx_id;

-- 2. mark listing as sold
UPDATE listings
SET status = 'sold'
WHERE property_id = _property_id;

-- 3. auto‑generate a mortgage record
INSERT INTO mortgages (
        mortgage_id,
        buyer_id,
        property_id,
        loan_amount,
        interest_rate,
        term_years
    )
VALUES (
        v_tx_id,
        _buyer_id,
        _property_id,
        _amount * 0.8,
        _interest,
        _term_years
    );

-- COMMIT;
-- EXCEPTION
-- WHEN OTHERS THEN ROLLBACK;
-- RAISE;
-- END;

EXCEPTION
WHEN OTHERS THEN RAISE;
END;
$$;


CALL create_sale(135, 2, 402000); -- example call; row returned below (2,2,401575.22,859901.84)
-- pick a property that is (1) still “available,” (2) has never been sold, and (3) is priced at or below the chosen buyer’s budget.
-- SELECT  p.property_id,
--         l.listing_id,
--         p.price,
--         b.budget
-- FROM        buyers     b
-- JOIN        properties p  ON p.price <= b.budget -- within budget
-- JOIN        listings   l  USING (property_id)
-- LEFT  JOIN  transactions t USING (property_id)
-- WHERE       b.buyer_id = 135                     -- replace 135 with any buyer
--   AND       l.status   = 'available'             -- listing still open
--   AND       t.property_id IS NULL                -- property never sold
-- LIMIT 1;


-- verify the sale
SELECT * FROM transactions WHERE property_id = 2;
SELECT * FROM mortgages WHERE property_id = 2;
SELECT status FROM listings WHERE property_id = 2;