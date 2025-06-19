-- Moves all properties from a departing agent to a replacement agent,
-- then deletes the old agent record (only if zero listings are still “available”)

CREATE OR REPLACE PROCEDURE reassign_and_remove_agent(
    _old_agent INT,
    _new_agent INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_leftover INT;
BEGIN
    -- make sure the replacement exists
    IF NOT EXISTS (SELECT 1 FROM agents WHERE agent_id = _new_agent) THEN
        RAISE EXCEPTION 'Replacement agent % does not exist', _new_agent;
    END IF;

    -- reassign properties
    UPDATE properties
    SET    agent_id = _new_agent
    WHERE  agent_id = _old_agent;

    -- check whether any active listings still reference the old agent
    SELECT COUNT(*)
    INTO   v_leftover
    FROM   listings l
    JOIN   properties p USING (property_id)
    WHERE  l.status = 'available'
      AND  p.agent_id = _old_agent;

    IF v_leftover > 0 THEN
        RAISE EXCEPTION 'Cannot delete agent % — % active listing(s) remain',
                        _old_agent, v_leftover;
    END IF;

    DELETE FROM agents WHERE agent_id = _old_agent;
    RAISE NOTICE 'Agent % removed; properties moved to agent %', _old_agent, _new_agent;

END;
$$;

CALL reassign_and_remove_agent(17, 42);


-- verify the reassignment and removal
SELECT (
        SELECT COUNT(*)
        FROM agents
        WHERE agent_id = 17
    ) AS agent_17_rows,
    (
        SELECT COUNT(*)
        FROM properties
        WHERE agent_id = 42
    ) AS props_now_with_42,
    (
        SELECT COUNT(*)
        FROM listings l
            JOIN properties p USING (property_id)
        WHERE l.status = 'available'
            AND p.agent_id = 17
    ) AS leftover_active;

SELECT *
FROM properties
WHERE agent_id = 42
ORDER BY property_id
LIMIT 20