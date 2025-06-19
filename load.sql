\COPY agents FROM 'data/agents.csv' DELIMITER ',' CSV HEADER;
\COPY neighborhoods FROM 'data/neighborhoods.csv' DELIMITER ',' CSV HEADER;
\COPY buyers FROM 'data/buyers.csv' DELIMITER ',' CSV HEADER;
\COPY properties FROM 'data/properties.csv' DELIMITER ',' CSV HEADER;
\COPY sellers FROM 'data/sellers.csv' DELIMITER ',' CSV HEADER;
\COPY listings FROM 'data/listings.csv' DELIMITER ',' CSV HEADER;
\COPY schools FROM 'data/schools.csv' DELIMITER ',' CSV HEADER;
\COPY inspections FROM 'data/inspections.csv' DELIMITER ',' CSV HEADER;
\COPY mortgages FROM 'data/mortgages.csv' DELIMITER ',' CSV HEADER;
\COPY transactions FROM 'data/transactions.csv' DELIMITER ',' CSV HEADER;
\COPY favorites FROM 'data/favorites.csv' DELIMITER ',' CSV HEADER;

-- Auto‑sync all identity / serial sequences to max(id)+1
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT  pg_class.relname                   AS tbl,
                pg_attribute.attname              AS col,
                pg_get_serial_sequence(
                    quote_ident(pg_class.relname),
                    pg_attribute.attname)         AS seq
        FROM   pg_class
        JOIN   pg_attribute
               ON pg_attribute.attrelid = pg_class.oid
        WHERE  pg_class.relkind = 'r' -- regular table
          AND  pg_attribute.attidentity IN ('a','d') -- identity
          AND  pg_class.relnamespace = 'public'::regnamespace
    LOOP
        EXECUTE format('
            SELECT setval(%L,
                          COALESCE((SELECT MAX(%I) FROM %I), 0) + 1,
                          false)',
                       r.seq, r.col, r.tbl);
        RAISE NOTICE 'Sequence % set to next value for %.%',
                     r.seq, r.tbl, r.col;
    END LOOP;
END$$;
