-- CASE F01 — ACCEPTED TM-A LIMITATION (not a REJECT by itself).
-- A fresh noxund_migrator session calls record_migration() DIRECTLY, with no
-- artifact executed. Run outside the runner (e.g. via psql/PQexecParams) as
-- noxund_migrator.
--
-- Expected under TM-A: this MAY commit one structurally valid row if head,
-- predecessor and uniqueness checks pass. That is the documented, accepted
-- trusted-principal limitation. It is a REJECT ONLY if it can violate linearity,
-- create two rows in one top-level tx, mutate history, bypass ownership, or make
-- head and history disagree — see F02/F03, which MUST fail.
BEGIN ISOLATION LEVEL READ COMMITTED;
    SELECT current_ordinal, current_version, current_checksum
      FROM noxund_migration_meta.current_state();  -- read head to supply a valid predecessor
    -- Caller supplies version/checksum/prev matching the current head.
    SELECT ordinal, version, top_xid::text, backend_pid
      FROM noxund_migration_meta.record_migration(
               :'direct_version', :'direct_checksum', :'direct_prev');
COMMIT;
