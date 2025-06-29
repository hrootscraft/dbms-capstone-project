\set ON_ERROR_STOP on
\timing on -- show wall‑clock time

/*
  Query 1  –  “Top family homes” (Q4 in test_queries.sql)
  Joins properties ▸ neighborhoods ▸ agents, 
  filters on bedrooms and school_rating, 
  sorts by price.
*/
\echo ========== Q1 BASELINE ==========
EXPLAIN ANALYZE
SELECT p.property_id,
    p.address,
    p.price,
    n.name AS neighborhood,
    a.name AS agent
FROM properties   p
JOIN neighborhoods n USING (neighborhood_id)
JOIN agents a USING (agent_id)
WHERE  n.school_rating >= 8 AND  p.bedrooms >= 3
ORDER BY p.price DESC
LIMIT 10;

\echo ========== Q1 INDEXES ==========
-- 1.  neighbourhoods: only rows that meet the ≥ 8 predicate are ever used
CREATE INDEX IF NOT EXISTS idx_neigh_rating8
ON neighborhoods (neighborhood_id) -- covers the JOIN
WHERE school_rating >= 8; -- partial → smaller

-- 2.  properties: cover filter + sort in one B‑tree, but only when beds ≥ 3
CREATE INDEX IF NOT EXISTS idx_prop_bed3_price
ON properties (price DESC) -- supports ORDER BY
INCLUDE (address, neighborhood_id, agent_id) -- join columns
WHERE bedrooms >= 3; -- partial predicate

ANALYZE neighborhoods;
ANALYZE properties;

\echo ========== Q1 IMPROVED ==========
EXPLAIN ANALYZE
SELECT p.property_id,
    p.address,
    p.price,
    n.name AS neighborhood,
    a.name AS agent
FROM properties p
JOIN neighborhoods n USING (neighborhood_id)
JOIN agents a USING (agent_id)
WHERE n.school_rating >= 8 AND p.bedrooms >= 3
ORDER BY p.price DESC
LIMIT 10;



/* 
  Query 2  –  “Expensive neighborhoods” (Q5 in test_queries.sql)
  GROUP BY + HAVING, needs fast price look‑up per neighborhood.
*/
\echo ========== Q2 BASELINE ==========
EXPLAIN ANALYZE
SELECT n.name,
    COUNT(*) AS listing_cnt,
    AVG(p.price)::NUMERIC(10,2) AS avg_price
FROM neighborhoods n
JOIN properties p USING (neighborhood_id)
GROUP BY n.name
HAVING AVG(p.price) > 500000
ORDER BY avg_price DESC;

\echo ========== Q2 INDEX ==========
-- Covering index to accelerate group aggregate
CREATE INDEX IF NOT EXISTS idx_prop_neigh_price ON properties (neighborhood_id, price);

ANALYZE properties;

\echo ========== Q2 IMPROVED ==========
EXPLAIN ANALYZE
SELECT n.name,
    COUNT(*) AS listing_cnt,
    AVG(p.price)::NUMERIC(10,2) AS avg_price
FROM neighborhoods n
JOIN properties p USING (neighborhood_id)
GROUP BY n.name
HAVING AVG(p.price) > 500000
ORDER BY avg_price DESC;



/*
  Query 3  –  “Idle agents” (Q11 in test_queries.sql)
  Anti‑join pattern: agents with zero available listings.
*/
\echo ========== Q3 BASELINE ==========
EXPLAIN ANALYZE
SELECT DISTINCT a.agent_id, a.name
FROM agents a
LEFT JOIN properties p ON p.agent_id = a.agent_id
LEFT JOIN listings l ON l.property_id = p.property_id AND l.status = 'available'
WHERE l.listing_id IS NULL
ORDER BY a.agent_id;

\echo ========== Q3 INDEXES ==========
-- 1.  FK side of the first join
CREATE INDEX IF NOT EXISTS idx_prop_agent ON properties (agent_id);

-- 2.  Partial index only on the small subset of rows with status='available'
CREATE INDEX IF NOT EXISTS idx_listings_available
ON listings (property_id)
WHERE status = 'available';

ANALYZE properties;
ANALYZE listings;

\echo ========== Q3 IMPROVED ==========
EXPLAIN ANALYZE
SELECT DISTINCT a.agent_id, a.name
FROM agents a
LEFT JOIN properties p ON p.agent_id = a.agent_id
LEFT JOIN listings l ON l.property_id = p.property_id AND l.status = 'available'
WHERE l.listing_id IS NULL
ORDER BY a.agent_id;
