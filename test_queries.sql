-- run queries & write each result to its own file under ./output/

\! mkdir -p output
\timing on
\set ON_ERROR_STOP on



-- 1. INSERT: Add a newly surveyed neighborhood before marketing listings there.
\o output/query01.txt
\qecho '–– 1. INSERT neighborhood'

INSERT INTO neighborhoods (
        neighborhood_id,
        name,
        school_rating,
        air_quality_index,
        crime_float
    )
VALUES (3101, 'Riverbend Gardens', 9, 42.7, 3.8);

\qecho '–– 1. VERIFY'
-- 1. Check if the neighborhood was added successfully.
SELECT * FROM neighborhoods WHERE neighborhood_id = 3101; 
\o



-- 2. UPDATE: Run a limited‑time promotion (3 % discount) to boost demand in a sluggish price band.
\o output/query02.txt
\qecho '–– 2. UPDATE prices (3 % discount)'

UPDATE properties
SET price = price * 0.97
WHERE neighborhood_id = 12
    AND price BETWEEN 400000 AND 600000;

\qecho '–– 2. VERIFY'
-- 2. Check if the prices were updated correctly.
SELECT * FROM properties WHERE neighborhood_id = 12;
\o



-- 3. DELETE: House‑clean the listings table by purging stale sold records.
\o output/query03.txt
\qecho '–– 3. DELETE stale sold listings'

DELETE FROM listings
WHERE status = 'sold'
    AND listing_date < CURRENT_DATE - INTERVAL '18 months';

\qecho '–– 3. VERIFY'
-- 3. Check if the listings were deleted correctly.
SELECT *
FROM listings
WHERE status = 'sold'
    AND listing_date < CURRENT_DATE - INTERVAL '18 months';
\o



-- 4. mutitable JOIN, ORDER BY, LIMIT: Show the 10 most expensive family‑sized homes in good‑school areas
\o output/query04.txt

SELECT p.property_id,
    p.address,
    p.price,
    n.name AS neighborhood,
    a.name AS agent
FROM properties p
    JOIN neighborhoods n USING (neighborhood_id)
    JOIN agents a USING (agent_id)
WHERE n.school_rating >= 8
    AND p.bedrooms >= 3
ORDER BY p.price DESC
LIMIT 10;
\o



-- 5. GROUP BY, aggregate, HAVING: Show only the expensive neighborhoods ( avg price > $500 k ), plus how many listings each has.
\o output/query05.txt

SELECT n.name,
    COUNT(*) AS listing_cnt,
    AVG(p.price)::NUMERIC(10, 2) AS avg_price
FROM neighborhoods n
    JOIN properties p USING (neighborhood_id)
GROUP BY n.name
HAVING AVG(p.price) > 500000
ORDER BY avg_price DESC;
\o



-- 6. CTE window: Dashboard giving a league‑table of neighborhood price levels meaning show every neighborhood, ranked by its average sale price
\o output/query06.txt

WITH avg_price AS (
    SELECT neighborhood_id,
        AVG(price) AS neighborhood_avg
    FROM properties
    GROUP BY neighborhood_id
)
SELECT n.name,
    ROUND(neighborhood_avg::numeric, 0) AS avg_price,
    RANK() OVER (
        ORDER BY neighborhood_avg DESC
    ) AS price_rank
FROM avg_price ap
    JOIN neighborhoods n USING (neighborhood_id);
\o



-- 7. scalar sub-query: Identify high‑budget buyers for concierge‑level service.
\o output/query07.txt

SELECT buyer_id,
    name,
    budget
FROM buyers
WHERE budget > (
        SELECT AVG(price)
        FROM properties
    );
\o



-- 8. correlated sub-query: Find undervalued homes within each neighborhood.
\o output/query08.txt

SELECT property_id,
    address,
    price
FROM properties p
WHERE price < (
        SELECT AVG(price)
        FROM properties
        WHERE neighborhood_id = p.neighborhood_id
    );
\o 



-- 9. DISTINCT ON (implicit window-like pattern): Fetch the single most expensive property per neighborhood.
\o output/query09.txt

SELECT DISTINCT ON (neighborhood_id) property_id,
    neighborhood_id,
    price
FROM properties
ORDER BY neighborhood_id,
    price DESC;
\o 



-- 10. LEFT JOIN, aggregate: “Most‑liked” listings—useful for marketing highlights.
\o output/query10.txt

SELECT p.property_id,
    address,
    COUNT(f.property_id) AS favorite_cnt
FROM properties p
    LEFT JOIN favorites f USING (property_id)
GROUP BY p.property_id,
    address
ORDER BY favorite_cnt DESC,
    p.property_id
LIMIT 15;
\o 



-- 11. anti-join pattern: Agents who don’t have any property that’s actively listed.
\o output/query11.txt

SELECT DISTINCT a.agent_id,
    a.name
FROM agents a
    LEFT JOIN properties p ON p.agent_id = a.agent_id
    LEFT JOIN listings l ON l.property_id = p.property_id
    AND l.status = 'available'
WHERE l.listing_id IS NULL
ORDER BY a.agent_id;
\o 



-- 12. paired EXISTS and NOT EXISTS: Leads pipeline - buyers who inspected properties but haven’t purchased yet.
\o output/query12.txt

SELECT b.buyer_id,
    b.name
FROM buyers b
WHERE EXISTS (
        SELECT 1
        FROM inspections i
        WHERE i.buyer_id = b.buyer_id
    )
    AND NOT EXISTS (
        SELECT 1
        FROM transactions t
        WHERE t.buyer_id = b.buyer_id
    );
\o 



-- 13. Analytics CTE: Generates a month‑by‑month sales report that includes each month’s total revenue and its percentage growth versus the previous month.
\o output/query13.txt

WITH monthly AS (
    SELECT date_trunc('month', date)::DATE AS month,
        SUM(amount) AS total_sales
    FROM transactions
    GROUP BY 1
),
mo_growth AS (
    SELECT month,
        total_sales,
        LAG(total_sales) OVER (
            ORDER BY month
        ) AS prev_month,
        ROUND(
            (
                (
                    total_sales - LAG(total_sales) OVER (
                        ORDER BY month
                    )
                ) / NULLIF(
                    LAG(total_sales) OVER (
                        ORDER BY month
                    ),
                    0
                ) * 100
            )::numeric,
            2
        ) AS pct_change
    FROM monthly
)
SELECT *
FROM mo_growth
ORDER BY month;
\o 



-- 14. List every mortgage (sale) for one property
-- See all mortgages on a property, whether or not a sale row exists
\o output/query14.txt

SELECT m.mortgage_id,
    m.property_id,
    m.buyer_id,
    m.loan_amount,
    m.interest_rate,
    m.term_years,
    t.amount AS sale_price,
    t.date AS sale_date
FROM mortgages m
    LEFT JOIN transactions t ON t.buyer_id = m.buyer_id
    AND t.property_id = m.property_id
WHERE m.property_id = 950
ORDER BY COALESCE(t.date, CURRENT_DATE);

-- find all properties with 2 + mortgages, show the busiest first
-- SELECT property_id,
--        COUNT(*) AS mortgage_cnt
-- FROM   mortgages
-- GROUP  BY property_id
-- HAVING COUNT(*) > 1
-- ORDER  BY mortgage_cnt DESC, property_id
-- LIMIT 10;   

\o 

          
