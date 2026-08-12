-- ATTACK C01 — artifact RESETs ROLE to regain noxund_migrator, then attempts a
-- DIRECT INSERT into the authoritative ledger.
-- Expected: RESET ROLE succeeds (returns to session_user=noxund_migrator), but
-- noxund_migrator has NO direct DML on the ledger table -> SQLSTATE 42501
-- (insufficient_privilege) -> runner ROLLBACK. No forged row can commit.
DO $c01$
BEGIN
    RESET ROLE;
    INSERT INTO noxund_migration_meta.migration_history
        (ordinal, version, checksum, prev_version, top_xid, backend_pid,
         session_identity, definer_identity, recorded_at)
    VALUES (9999, 'FORGED', repeat('a', 64), NULL,
            pg_catalog.pg_current_xact_id(), pg_catalog.pg_backend_pid(),
            session_user, current_user, pg_catalog.clock_timestamp());
END
$c01$;
