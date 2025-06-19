-- Single‑row summary of a buyer’s favourites, inspections, and spend

CREATE OR REPLACE FUNCTION fn_buyer_activity_summary(_bid INT) RETURNS TABLE(
        favourite_cnt INT,
        inspection_cnt INT,
        total_purchased NUMERIC,
        last_inspection DATE,
        last_purchase DATE
    ) AS $$
SELECT 
    (SELECT COUNT(*) FROM favorites WHERE buyer_id = _bid),
    (SELECT COUNT(*) FROM inspections WHERE buyer_id = _bid),
    (SELECT SUM(amount) FROM transactions WHERE buyer_id = _bid),
    (SELECT MAX(date) FROM inspections WHERE buyer_id = _bid),
    (SELECT MAX(date) FROM transactions WHERE buyer_id = _bid) 
$$ LANGUAGE SQL STABLE;


SELECT * FROM fn_buyer_activity_summary(1883); -- example