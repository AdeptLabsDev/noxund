-- CASE F03 — REJECT probe: even the trusted principal cannot MUTATE history
-- directly (no UPDATE/DELETE/TRUNCATE privilege on the ledger table).
-- Expected: SQLSTATE 42501 for each -> no history mutation is possible.
BEGIN;
    UPDATE noxund_migration_meta.migration_history SET checksum = repeat('c', 64) WHERE ordinal = 1;
    DELETE FROM noxund_migration_meta.migration_history WHERE ordinal = 1;
    TRUNCATE noxund_migration_meta.migration_history;
ROLLBACK;
