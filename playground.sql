-- EXPLAIN ANALYZE
-- SELECT p.property_id,
--        p.address,
--        COUNT(f.property_id) AS favorite_cnt
-- FROM   properties p
-- LEFT   JOIN favorites f USING (property_id)
-- GROUP  BY p.property_id, p.address
-- ORDER  BY favorite_cnt DESC, p.property_id;
-- CREATE INDEX IF NOT EXISTS idx_fav_property ON favorites (property_id);
-- ANALYZE favorites;
-- EXPLAIN ANALYZE
-- SELECT p.property_id,
--        p.address,
--        COUNT(f.property_id) AS favorite_cnt
-- FROM   properties p
-- LEFT   JOIN favorites f USING (property_id)
-- GROUP  BY p.property_id, p.address
-- ORDER  BY favorite_cnt DESC, p.property_id;

-- EXPLAIN ANALYZE
-- SELECT n.name,
--        COUNT(*)                       AS listing_cnt,
--        AVG(p.price)::NUMERIC(10,2)    AS avg_price
-- FROM   neighborhoods n
-- JOIN   properties    p USING (neighborhood_id)
-- GROUP  BY n.name
-- HAVING AVG(p.price) > 500000
-- ORDER  BY avg_price DESC;
-- CREATE INDEX IF NOT EXISTS idx_prop_neigh_price
--     ON properties (neighborhood_id)
--     INCLUDE (price);
-- ANALYZE properties;
-- EXPLAIN ANALYZE
-- SELECT n.name,
--        COUNT(*)                       AS listing_cnt,
--        AVG(p.price)::NUMERIC(10,2)    AS avg_price
-- FROM   neighborhoods n
-- JOIN   properties    p USING (neighborhood_id)
-- GROUP  BY n.name
-- HAVING AVG(p.price) > 500000
-- ORDER  BY avg_price DESC;

-- EXPLAIN ANALYZE
-- SELECT transaction_id,
--        buyer_id,
--        amount,
--        date
-- FROM   transactions
-- WHERE  date >= CURRENT_DATE - INTERVAL '30 days'
--   AND  amount > 400000
-- ORDER  BY date DESC;
-- CREATE INDEX IF NOT EXISTS idx_tx_date_amount
--     ON transactions (date DESC, amount)
--     WHERE amount > 400000;     -- partial keeps index small / selective
-- ANALYZE transactions;
-- EXPLAIN ANALYZE
-- SELECT transaction_id,
--        buyer_id,
--        amount,
--        date
-- FROM   transactions
-- WHERE  date >= CURRENT_DATE - INTERVAL '30 days'
--   AND  amount > 400000
-- ORDER  BY date DESC;

SELECT  p.property_id,
        l.listing_id,
        p.price,
        b.budget
FROM        buyers     b
JOIN        properties p  ON p.price <= b.budget        -- within budget
JOIN        listings   l  USING (property_id)
LEFT  JOIN  transactions t USING (property_id)
WHERE       b.buyer_id = 135                    -- replace 135 with any buyer
  AND       l.status   = 'available'            -- listing still open
  AND       t.property_id IS NULL               -- property never sold
LIMIT 1;