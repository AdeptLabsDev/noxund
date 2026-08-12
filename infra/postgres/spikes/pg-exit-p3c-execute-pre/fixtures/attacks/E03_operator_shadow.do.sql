-- ATTACK E03 — artifact plants a pg_temp operator/function to shadow resolution
-- used by the ledger function.
-- Expected: no effect. The ledger function's fixed search_path (pg_catalog
-- first, pg_temp last) plus fully-qualified references make the shadow
-- unreachable during record_migration().
DO $e03$
BEGIN
    EXECUTE $ddl$
        CREATE FUNCTION pg_temp.pg_current_xact_id() RETURNS xid8
        LANGUAGE sql VOLATILE AS 'SELECT ''0''::xid8'
    $ddl$;
END
$e03$;
