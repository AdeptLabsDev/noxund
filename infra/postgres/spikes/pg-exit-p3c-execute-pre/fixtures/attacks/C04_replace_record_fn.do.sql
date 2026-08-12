-- ATTACK C04 — artifact attempts to replace the authoritative append function.
-- Expected: SQLSTATE 42501 — drop/alter is inherent to the owner (noxund_ledger)
-- and cannot be granted; noxund_owner/reset-migrator cannot CREATE OR REPLACE it
-- -> runner ROLLBACK.
DO $c04$
BEGIN
    EXECUTE $ddl$
        CREATE OR REPLACE FUNCTION noxund_migration_meta.record_migration(text, text, text)
        RETURNS noxund_migration_meta.migration_record
        LANGUAGE sql AS 'SELECT NULL::noxund_migration_meta.migration_record'
    $ddl$;
END
$c04$;
