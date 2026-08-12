-- ATTACK E02 — artifact plants a pg_temp Trojan shadowing clock_timestamp().
-- Expected: no effect. record_migration() calls pg_catalog.clock_timestamp()
-- fully qualified with pg_temp LAST in its search_path, so the Trojan is never
-- resolved; recorded_at reflects the real server clock.
DO $e02$
BEGIN
    EXECUTE $ddl$
        CREATE FUNCTION pg_temp.clock_timestamp() RETURNS timestamptz
        LANGUAGE sql IMMUTABLE AS 'SELECT ''1999-01-01 00:00:00+00''::timestamptz'
    $ddl$;
END
$e02$;
