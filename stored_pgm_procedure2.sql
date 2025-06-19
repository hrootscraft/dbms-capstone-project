-- Inserts a property and immediately lists it as “available”

CREATE OR REPLACE PROCEDURE add_property_with_listing(
    _address        VARCHAR,
    _price          FLOAT,
    _bedrooms       INT,
    _bathrooms      INT,
    _area_sqft      FLOAT,
    _agent_id       INT,
    _neigh_id       INT  DEFAULT NULL,
    _listing_date   DATE DEFAULT CURRENT_DATE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_property_id INT;
    v_listing_id  INT;
    v_neigh_id    INT;
BEGIN
    -- 0. validate agent exists
    IF NOT EXISTS (SELECT 1 FROM agents WHERE agent_id = _agent_id) THEN
        RAISE EXCEPTION 'Agent % does not exist', _agent_id;
    END IF;

    -- 1. resolve neighborhood
    IF _neigh_id IS NOT NULL THEN          -- explicit
        IF NOT EXISTS (
            SELECT 1 FROM neighborhoods WHERE neighborhood_id = _neigh_id
        ) THEN
            RAISE EXCEPTION 'Neighborhood % does not exist', _neigh_id;
        END IF;
        v_neigh_id := _neigh_id;
    ELSE                                   -- auto-detect
        SELECT n.neighborhood_id
        INTO   v_neigh_id
        FROM   neighborhoods n
        WHERE  _address ILIKE '%' || n.name || '%'
        LIMIT  1;            -- v_neigh_id stays NULL if no match
    END IF;

    -- 2. insert property
    INSERT INTO properties (address, price, bedrooms, bathrooms, area_sqft, agent_id, neighborhood_id)
    VALUES (_address, _price, _bedrooms, _bathrooms, _area_sqft, _agent_id, v_neigh_id)
    RETURNING property_id INTO v_property_id;

    -- 3. create its first listing
    INSERT INTO listings (property_id, listing_date, status)
    VALUES (v_property_id, _listing_date, 'available')
    RETURNING listing_id INTO v_listing_id;

    -- 4. success message
    RAISE NOTICE
      'Property % (neigh %) and listing % successfully created',
      v_property_id, v_neigh_id, v_listing_id;

EXCEPTION
    WHEN OTHERS THEN
        -- rollback is automatic because the CALL is a single SQL statement
        RAISE; -- re-throw to caller with original message
END;
$$;


-- example call: Explicit neighborhood
\set last_address '15 Bayview Rd, Harbour Heights'
CALL add_property_with_listing(
  :'last_address', 610000, 3, 2, 1800, 42, 8
);

\qecho '-- Verify that the new property + listing exist --'
-- 1. look the row up by its address (unique per demo)
SELECT p.property_id,
       p.price,
       p.bedrooms,
       p.bathrooms,
       n.name AS neighborhood,
       l.listing_id,
       l.status,
       l.listing_date
FROM   properties   p
JOIN   listings     l USING (property_id)
LEFT   JOIN neighborhoods n USING (neighborhood_id)
WHERE  p.address = :'last_address';          -- see the \set below

-- 2. show delta counts so the log makes the change obvious
SELECT 
  (SELECT COUNT(*) FROM properties) AS total_properties,
  (SELECT COUNT(*) FROM listings)   AS total_listings;
-- ----------------------------------------------------------


-- example call: Let it auto-detect neighborhood; If “Wallaceside Village” exists in neighborhoods.name, that ID is used; otherwise neighborhood_id is stored as NULL.
\set last_address '99 Maple Lane, Wallaceside Village, Springfield'
CALL add_property_with_listing(
    :'last_address', 450000, 2, 1, 1200, 19
);

\qecho '-- Verify that the new property + listing exist --'
-- 1. look the row up by its address (unique per demo)
SELECT p.property_id,
       p.price,
       p.bedrooms,
       p.bathrooms,
       n.name AS neighborhood,
       l.listing_id,
       l.status,
       l.listing_date
FROM   properties   p
JOIN   listings     l USING (property_id)
LEFT   JOIN neighborhoods n USING (neighborhood_id)
WHERE  p.address = :'last_address';          -- see the \set below

-- 2. show delta counts so the log makes the change obvious
SELECT 
  (SELECT COUNT(*) FROM properties) AS total_properties,
  (SELECT COUNT(*) FROM listings)   AS total_listings;
-- ----------------------------------------------------------
