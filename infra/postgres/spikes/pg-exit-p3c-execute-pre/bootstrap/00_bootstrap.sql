-- ============================================================================
-- PG-EXIT-P3C-EXECUTE-PRE — trusted bootstrap (SINGLE TRANSACTION)
-- ----------------------------------------------------------------------------
-- IMPLEMENTED, NOT EXECUTED. Applied by the future gate as the image bootstrap
-- superuser over the internal network. TM-A: this bootstrap is TRUSTED.
--
-- LOGIN role passwords are injected as psql variables (:migrator_password,
-- :app_password) sourced from ephemeral files at run time — NEVER literals here.
--
-- Default-privilege correctness (binding note): every ledger-owned object is
-- created while the effective creator role IS noxund_ledger (via SET ROLE), so
-- `ALTER DEFAULT PRIVILEGES FOR ROLE noxund_ledger` matches the actual creator.
-- The app schema is likewise created while the effective creator is noxund_owner.
-- ============================================================================
\set ON_ERROR_STOP on

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. ROLE GRAPH  (created by the bootstrap superuser)
--    Only membership edge: noxund_owner -> noxund_migrator.
-- ----------------------------------------------------------------------------
CREATE ROLE noxund_owner
    WITH NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;

CREATE ROLE noxund_ledger
    WITH NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;

CREATE ROLE noxund_migrator
    WITH LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS
    PASSWORD :'migrator_password';

-- Representative runtime roles (used only to verify they have NO ledger access).
CREATE ROLE noxund_app
    WITH LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS
    PASSWORD :'app_password';

CREATE ROLE sg8_compute_writer
    WITH NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;

-- The ONLY permitted membership edge.
GRANT noxund_owner TO noxund_migrator;
-- noxund_ledger is granted to NO ONE.
-- noxund_owner is a member of nothing. Runtime roles are members of nothing.

-- Database-level PUBLIC hardening (defense-in-depth).
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- ----------------------------------------------------------------------------
-- 2. LEDGER SCHEMA — owned by noxund_ledger
-- ----------------------------------------------------------------------------
CREATE SCHEMA noxund_migration_meta AUTHORIZATION noxund_ledger;
REVOKE ALL ON SCHEMA noxund_migration_meta FROM PUBLIC;

-- Default privileges for the ACTUAL creator role (noxund_ledger): future
-- functions/tables created by it grant nothing to PUBLIC.
ALTER DEFAULT PRIVILEGES FOR ROLE noxund_ledger IN SCHEMA noxund_migration_meta
    REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE noxund_ledger IN SCHEMA noxund_migration_meta
    REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE noxund_ledger IN SCHEMA noxund_migration_meta
    REVOKE ALL ON SEQUENCES FROM PUBLIC;

-- ----------------------------------------------------------------------------
-- 3. LEDGER OBJECTS — created AS noxund_ledger so it owns them and the default
--    privileges above apply.
-- ----------------------------------------------------------------------------
SET ROLE noxund_ledger;

-- 3a. Return type for the append function.
CREATE TYPE noxund_migration_meta.migration_record AS (
    ordinal     bigint,
    version     text,
    top_xid     xid8,
    backend_pid integer,
    recorded_at timestamptz
);

-- 3b. Singleton authoritative head (tip + ordinal). Seeded once, here.
CREATE TABLE noxund_migration_meta.migration_head (
    only_one         boolean PRIMARY KEY DEFAULT true CHECK (only_one),
    current_ordinal  bigint  NOT NULL DEFAULT 0,
    current_version  text,
    current_checksum text
);
INSERT INTO noxund_migration_meta.migration_head (only_one) VALUES (true);

-- 3c. Append-only history.
CREATE TABLE noxund_migration_meta.migration_history (
    ordinal          bigint      NOT NULL,
    version          text        NOT NULL,
    checksum         text        NOT NULL,
    prev_version     text,                       -- NULL only for the root (ordinal 1)
    top_xid          xid8        NOT NULL,        -- function-derived, top-level (even in a subtx)
    backend_pid      integer     NOT NULL,        -- function-derived
    session_identity name        NOT NULL,        -- session_user at insert (audit)
    definer_identity name        NOT NULL,        -- current_user inside the SECURITY DEFINER fn = the OWNER
    recorded_at      timestamptz NOT NULL,        -- EVIDENCE ONLY; never the authoritative head
    CONSTRAINT mh_ordinal_key  UNIQUE (ordinal),
    CONSTRAINT mh_version_key  UNIQUE (version),
    CONSTRAINT mh_top_xid_key  UNIQUE (top_xid),                         -- <= 1 row per top-level tx
    CONSTRAINT mh_prev_key     UNIQUE NULLS NOT DISTINCT (prev_version), -- <= 1 child per predecessor + single root
    CONSTRAINT mh_checksum_chk CHECK (checksum ~ '^[0-9a-f]{64}$'),
    CONSTRAINT mh_ordinal_pos  CHECK (ordinal >= 1)
);

-- 3d. Authoritative append function.
CREATE FUNCTION noxund_migration_meta.record_migration(
        p_version      text,
        p_checksum     text,
        p_prev_version text)
    RETURNS noxund_migration_meta.migration_record
    LANGUAGE plpgsql
    SECURITY DEFINER
    VOLATILE
    PARALLEL UNSAFE
    SET search_path = pg_catalog, noxund_migration_meta, pg_temp
AS $fn$
DECLARE
    v_head    noxund_migration_meta.migration_head;
    v_ordinal bigint;
    v_result  noxund_migration_meta.migration_record;
BEGIN
    -- (1) TM-A principal check. Defense-in-depth / audit ONLY: it cannot
    --     distinguish the trusted runner from artifact-issued SQL of the same
    --     principal. It is NOT the trust boundary.
    IF session_user <> 'noxund_migrator' THEN
        RAISE EXCEPTION USING ERRCODE = '42501',
            MESSAGE = 'ledger append not permitted for principal ' || quote_literal(session_user::text);
    END IF;

    -- (2) input validation (data validation, not a SQL parser)
    IF p_version IS NULL OR p_version !~ '^[0-9A-Za-z._-]{1,128}$' THEN
        RAISE EXCEPTION USING ERRCODE = '22004', MESSAGE = 'null or malformed version';
    END IF;
    IF p_checksum IS NULL OR p_checksum !~ '^[0-9a-f]{64}$' THEN
        RAISE EXCEPTION USING ERRCODE = '22004', MESSAGE = 'null or malformed checksum';
    END IF;

    -- (3) internal lock timeout
    SET LOCAL lock_timeout = '3s';

    -- (4) canonical serialization: lock the singleton head row
    SELECT h.* INTO v_head
      FROM noxund_migration_meta.migration_head AS h
     WHERE h.only_one
       FOR UPDATE;

    -- (5) predecessor vs the LOCKED authoritative head (never recorded_at)
    IF v_head.current_version IS DISTINCT FROM p_prev_version THEN
        RAISE EXCEPTION USING ERRCODE = 'P0001',
            MESSAGE = 'prev_version does not match current head';
    END IF;

    -- (6) ordinal derived from the locked head (no sequence)
    v_ordinal := v_head.current_ordinal + 1;

    -- (7,8) insert EXACTLY ONE row; xid/pid/identities/time derived internally.
    --       No ON CONFLICT — any uniqueness conflict must raise.
    INSERT INTO noxund_migration_meta.migration_history AS mh
        (ordinal, version, checksum, prev_version, top_xid, backend_pid,
         session_identity, definer_identity, recorded_at)
    VALUES
        (v_ordinal, p_version, p_checksum, p_prev_version,
         pg_catalog.pg_current_xact_id(), pg_catalog.pg_backend_pid(),
         session_user, current_user, pg_catalog.clock_timestamp())
    RETURNING mh.ordinal, mh.version, mh.top_xid, mh.backend_pid, mh.recorded_at
        INTO v_result;

    -- (9) advance the singleton head in the same transaction
    UPDATE noxund_migration_meta.migration_head AS h
       SET current_ordinal  = v_ordinal,
           current_version  = p_version,
           current_checksum = p_checksum
     WHERE h.only_one;

    -- (10) return the committed-candidate record
    RETURN v_result;
END
$fn$;

-- 3e. Read-only accessors (no mutation, no row lock, no arbitrary query).
CREATE FUNCTION noxund_migration_meta.current_state()
    RETURNS noxund_migration_meta.migration_head
    LANGUAGE sql
    SECURITY DEFINER
    STABLE
    PARALLEL SAFE
    SET search_path = pg_catalog, noxund_migration_meta, pg_temp
AS $$
    SELECT h.* FROM noxund_migration_meta.migration_head AS h WHERE h.only_one
$$;

CREATE FUNCTION noxund_migration_meta.row_for_current_xact()
    RETURNS SETOF noxund_migration_meta.migration_history
    LANGUAGE sql
    SECURITY DEFINER
    STABLE
    PARALLEL SAFE
    SET search_path = pg_catalog, noxund_migration_meta, pg_temp
AS $$
    SELECT mh.* FROM noxund_migration_meta.migration_history AS mh
     WHERE mh.top_xid = pg_catalog.pg_current_xact_id()
$$;

RESET ROLE;   -- back to the bootstrap superuser

-- ----------------------------------------------------------------------------
-- 4. ACLs — explicit least privilege. Any privilege not granted is denied.
--    (Belt-and-suspenders: default EXECUTE-to-PUBLIC on functions is removed
--     even though the ALTER DEFAULT PRIVILEGES above already prevents it.)
-- ----------------------------------------------------------------------------
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA noxund_migration_meta FROM PUBLIC;

-- Custom + automatic composite types: USAGE is granted to PUBLIC by default.
-- Inventory: explicit composite (migration_record) + table row types
-- (migration_head, migration_history) which are the accessor/return types.
REVOKE USAGE ON TYPE noxund_migration_meta.migration_record  FROM PUBLIC;
REVOKE USAGE ON TYPE noxund_migration_meta.migration_head    FROM PUBLIC;
REVOKE USAGE ON TYPE noxund_migration_meta.migration_history FROM PUBLIC;

-- Minimum grants to the trusted runner principal (noxund_migrator) ONLY.
GRANT USAGE ON SCHEMA noxund_migration_meta TO noxund_migrator;   -- no CREATE
GRANT USAGE ON TYPE noxund_migration_meta.migration_record  TO noxund_migrator;
GRANT USAGE ON TYPE noxund_migration_meta.migration_head    TO noxund_migrator;
GRANT USAGE ON TYPE noxund_migration_meta.migration_history TO noxund_migrator;
GRANT EXECUTE ON FUNCTION noxund_migration_meta.record_migration(text,text,text) TO noxund_migrator;
GRANT EXECUTE ON FUNCTION noxund_migration_meta.current_state()                  TO noxund_migrator;
GRANT EXECUTE ON FUNCTION noxund_migration_meta.row_for_current_xact()           TO noxund_migrator;

-- NOTHING to noxund_owner, noxund_app, sg8_compute_writer on the ledger.
-- NO table-level DML to anyone (only the SECURITY DEFINER functions touch them).
-- NO CREATE in the ledger schema to anyone (only the owner has it inherently).

-- ----------------------------------------------------------------------------
-- 5. APPLICATION SCHEMA — owned by noxund_owner (migrations run via SET ROLE).
-- ----------------------------------------------------------------------------
CREATE SCHEMA noxund_app_spike AUTHORIZATION noxund_owner;
REVOKE ALL ON SCHEMA noxund_app_spike FROM PUBLIC;
-- Runtime read role example (no ledger access anywhere).
GRANT USAGE ON SCHEMA noxund_app_spike TO noxund_app;
ALTER DEFAULT PRIVILEGES FOR ROLE noxund_owner IN SCHEMA noxund_app_spike
    GRANT SELECT ON TABLES TO noxund_app;
-- noxund_migrator has NO direct DDL here; it uses SET LOCAL ROLE noxund_owner.

COMMIT;
