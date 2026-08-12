-- ATTACK C03 — artifact attempts to REWRITE existing ledger history.
-- Expected: SQLSTATE 42501 — no UPDATE privilege for noxund_owner (or reset
-- noxund_migrator) on the ledger table -> runner ROLLBACK. History is immutable.
DO $c03$
BEGIN
    UPDATE noxund_migration_meta.migration_history
       SET checksum = repeat('b', 64)
     WHERE ordinal = 1;
END
$c03$;
