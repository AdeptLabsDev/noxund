-- ATTACK B02 — artifact creates a temporary object and raises a NOTIFY.
-- Expected: valid DO; the fresh-connection-per-migration lifecycle discards the
-- temp object and any notification state so the NEXT migration is unaffected.
-- Carryover prevention is a property of the lifecycle, verified across two runs.
DO $b02$
BEGIN
    CREATE TEMP TABLE b02_tmp (i int) ON COMMIT DROP;
    PERFORM pg_catalog.pg_notify('noxund_b02', 'leak-attempt');
END
$b02$;
