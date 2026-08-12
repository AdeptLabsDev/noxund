-- ATTACK C05 — artifact attempts to CREATE an object in the ledger schema.
-- Expected: SQLSTATE 42501 — no CREATE privilege in noxund_migration_meta for
-- migrator/owner -> runner ROLLBACK.
DO $c05$
BEGIN
    CREATE TABLE noxund_migration_meta.evil_c05 (i int);
END
$c05$;
