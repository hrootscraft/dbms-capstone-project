-- Most real‑estate models store the neighbourhood on the property itself:
-- 1 . add the column + FK
ALTER TABLE properties
ADD COLUMN neighborhood_id INT,
    ADD CONSTRAINT fk_property_neigh FOREIGN KEY (neighborhood_id) REFERENCES neighborhoods(neighborhood_id) ON DELETE
SET NULL;
-- 2 . populate the column if you already know the mapping
UPDATE properties
SET neighborhood_id = n.neighborhood_id
FROM neighborhoods n
WHERE properties.address ILIKE '%' || n.name || '%';