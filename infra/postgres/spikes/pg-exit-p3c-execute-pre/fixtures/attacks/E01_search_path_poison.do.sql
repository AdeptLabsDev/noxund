-- ATTACK E01 — artifact poisons search_path before the runner's ledger call.
-- Expected: no effect. record_migration() pins its own
-- search_path = pg_catalog, noxund_migration_meta, pg_temp and fully qualifies
-- every reference; and the runner reasserts a safe search_path at step 15.
DO $e01$
BEGIN
    SET search_path = pg_temp, public;
    CREATE TABLE noxund_app_spike.e01_marker (i int);
END
$e01$;
