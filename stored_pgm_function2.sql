-- KPI snapshot per agent (set‑returning function)

CREATE OR REPLACE FUNCTION fn_agent_kpis(_aid INT) RETURNS TABLE(
        active_listings INT,
        sold_listings INT,
        total_properties INT,
        total_sales_value NUMERIC,
        avg_sale_amount NUMERIC,
        last_sale_date DATE
    ) AS $$
SELECT COUNT(*) FILTER (
        WHERE l.status = 'available'
    ) AS active_listings,
    COUNT(*) FILTER (
        WHERE l.status = 'sold'
    ) AS sold_listings,
    COUNT(*) AS total_properties,
    SUM(t.amount) AS total_sales_value,
    AVG(t.amount) AS avg_sale_amount,
    MAX(t.date) AS last_sale_date
FROM properties p
    LEFT JOIN listings l USING (property_id)
    LEFT JOIN transactions t USING (property_id)
WHERE p.agent_id = _aid;
$$ LANGUAGE SQL STABLE;


SELECT * FROM fn_agent_kpis(42); -- example
