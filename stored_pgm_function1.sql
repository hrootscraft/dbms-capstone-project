-- Function to get neighborhood statistics, including the number of properties, average price, minimum and maximum price, and average school rating.

CREATE OR REPLACE FUNCTION get_neighborhood_stats(_nid INT) RETURNS TABLE(
        property_cnt INT,
        avg_price NUMERIC,
        min_price NUMERIC,
        max_price NUMERIC,
        avg_school NUMERIC
    ) AS $$
SELECT COUNT(p.*),
    AVG(p.price),
    MIN(p.price),
    MAX(p.price),
    AVG(n.school_rating)
FROM properties p
    JOIN neighborhoods n USING (neighborhood_id)
WHERE n.neighborhood_id = _nid;
$$ LANGUAGE SQL STABLE;


SELECT * FROM get_neighborhood_stats(12); -- example