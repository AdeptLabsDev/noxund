-- CASE F02 — REJECT probe: a direct principal cannot write TWO rows in one
-- top-level transaction. The second record_migration in the same tx must fail
-- on UNIQUE(top_xid) (SQLSTATE 23505) -> the whole tx aborts.
BEGIN ISOLATION LEVEL READ COMMITTED;
    SELECT record_migration_ok_1 FROM (
        SELECT (noxund_migration_meta.record_migration(:'v1', :'c1', :'prev')).ordinal
            AS record_migration_ok_1) s;
    -- Second append in the SAME top-level transaction: must raise 23505.
    SELECT (noxund_migration_meta.record_migration(:'v2', :'c2', :'v1')).ordinal;
COMMIT;
