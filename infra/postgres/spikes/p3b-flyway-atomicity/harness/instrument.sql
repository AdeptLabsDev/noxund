-- =============================================================================
-- P3B fatal instrumentation. Installed by the HARNESS (bootstrap superuser) AFTER
-- V1 + LP-0 are green and BEFORE the V2 migrate. Two probes, both writing to the
-- server log via RAISE LOG — a durable, rollback-proof channel (LOG >= WARNING),
-- which is precisely why it survives the SIGKILL/rollback.
--
--   * event trigger  -> logs PID/XID of the V2 CREATE TABLE (fires inside V2's tx)
--   * BEFORE INSERT  -> logs PID/XID of the V2 history row, then BLOCKS on an
--                       advisory lock the controller session already holds, giving
--                       a deterministic kill window (no race).
--
-- Superuser is used ONLY for instrumentation. No migration runs as superuser.
-- =============================================================================

-- ---- DDL probe: capture the CREATE TABLE transaction identity ----
CREATE OR REPLACE FUNCTION public.p3b_log_v2_ddl() RETURNS event_trigger
LANGUAGE plpgsql AS $$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM pg_event_trigger_ddl_commands() LOOP
    IF r.object_identity = 'spike.flyway_atomicity_gap_probe' THEN
      RAISE LOG 'P3B_FATAL ddl object=% pid=% xid=%',
        r.object_identity, pg_backend_pid(), txid_current();
    END IF;
  END LOOP;
END
$$;

CREATE EVENT TRIGGER p3b_v2_ddl ON ddl_command_end WHEN TAG IN ('CREATE TABLE')
  EXECUTE FUNCTION public.p3b_log_v2_ddl();

-- ---- history probe: capture the INSERT transaction identity, then block ----
CREATE OR REPLACE FUNCTION public.p3b_block_on_v2_history() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.version = '2' THEN
    RAISE LOG 'P3B_FATAL history version=% pid=% xid=%',
      NEW.version, pg_backend_pid(), txid_current();
    -- Transaction-level advisory lock: blocks because the controller session holds
    -- the same key at session level. Released implicitly if this tx is killed.
    PERFORM pg_advisory_xact_lock(902001);
  END IF;
  RETURN NEW;
END
$$;

-- Trigger function execution needs no privilege check on the inserting role, but
-- grant EXECUTE to PUBLIC as belt-and-suspenders.
GRANT EXECUTE ON FUNCTION public.p3b_block_on_v2_history() TO PUBLIC;

CREATE TRIGGER p3b_block_v2 BEFORE INSERT ON public.flyway_schema_history
  FOR EACH ROW EXECUTE FUNCTION public.p3b_block_on_v2_history();
