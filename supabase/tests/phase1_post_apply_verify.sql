-- ============================================================================
-- NOXUND · Phase 1 — post-apply verification
-- ----------------------------------------------------------------------------
-- Run by CI immediately after `supabase db push` (see
-- .github/workflows/phase1-db-apply.yml). Encodes:
--   docs/database/HANDOFF-phase1-apply.md §4 (structural)
--   docs/database/HANDOFF-phase1-apply.md §5 (empirical: immutability + default-deny)
--
-- CONTRACT: every check RAISES on mismatch, so `psql -v ON_ERROR_STOP=1` exits
-- non-zero and fails the CI job. There is no silent pass.
--
-- SIDE EFFECTS: none persisted. The only writes are a probe row created inside
-- a transaction that is ALWAYS rolled back. audit_events stays untouched.
--
-- Roles: connects as the project `postgres` role (a member of anon /
-- authenticated / service_role), which can `set role` to each for the
-- empirical checks below.
-- ============================================================================

\set ON_ERROR_STOP on

\echo '== Phase 1 · §4 structural verification =='

-- 4 core tables ---------------------------------------------------------------
do $$
declare n int;
begin
  select count(*) into n
    from information_schema.tables
   where table_schema = 'public'
     and table_name in ('producers','applications','admin_users','audit_events');
  if n <> 4 then
    raise exception 'STRUCT/tables: expected 4 core tables, found %', n;
  end if;
end $$;

-- 3 enums ---------------------------------------------------------------------
do $$
declare n int;
begin
  select count(*) into n
    from pg_type
   where typname in ('producer_status','application_status','audit_actor_type');
  if n <> 3 then
    raise exception 'STRUCT/enums: expected 3 enums, found %', n;
  end if;
end $$;

-- 2 immutability triggers on audit_events (SEC-D03 / SEC-F16) -----------------
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values ('audit_events_no_update_delete'), ('audit_events_no_truncate')) as t(want)
   where not exists (
     select 1 from pg_trigger
      where tgrelid = 'public.audit_events'::regclass
        and not tgisinternal
        and tgname = t.want
   );
  if missing is not null then
    raise exception 'STRUCT/triggers: missing immutability trigger(s) on audit_events: %', missing;
  end if;
end $$;

-- is_admin() hardened (SEC-F15): SECURITY DEFINER + pinned search_path --------
do $$
declare rec record;
begin
  select prosecdef, proconfig into rec
    from pg_proc
   where proname = 'is_admin' and pronamespace = 'public'::regnamespace;
  if not found then
    raise exception 'STRUCT/is_admin: function public.is_admin() not found';
  end if;
  if not rec.prosecdef then
    raise exception 'STRUCT/is_admin: expected SECURITY DEFINER (prosecdef=t)';
  end if;
  if rec.proconfig is null
     or not exists (select 1 from unnest(rec.proconfig) c where c like 'search_path=%') then
    raise exception 'STRUCT/is_admin: expected pinned search_path in proconfig, got %', rec.proconfig;
  end if;
end $$;

-- required indexes ------------------------------------------------------------
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values
      ('producers_email_lower_uidx'),
      ('applications_one_open_per_producer_uidx'),
      ('audit_events_entity_idx'),
      ('audit_events_created_idx')
    ) as t(want)
   where not exists (
     select 1 from pg_indexes
      where schemaname = 'public' and indexname = t.want
   );
  if missing is not null then
    raise exception 'STRUCT/indexes: missing required index(es): %', missing;
  end if;
end $$;

-- RLS enabled on all 4 (SEC-F13) ----------------------------------------------
do $$
declare bad text;
begin
  select string_agg(relname, ', ') into bad
    from pg_class
   where relnamespace = 'public'::regnamespace
     and relname in ('producers','applications','admin_users','audit_events')
     and relrowsecurity = false;
  if bad is not null then
    raise exception 'STRUCT/rls: RLS not enabled on: %', bad;
  end if;
end $$;

\echo '== Phase 1 · §5 empirical verification =='

-- Immutability — TRUNCATE as service_role must be blocked (SEC-F16) -----------
-- The statement-level trigger fires below the service_role bypass. We accept
-- either restrict_violation (trigger) or insufficient_privilege (no grant):
-- both mean "the audit log cannot be wiped by service_role".
begin;
  do $$
  begin
    set local role service_role;
    begin
      truncate public.audit_events;
      raise exception 'EMPIRICAL/immutability: TRUNCATE as service_role SUCCEEDED (SEC-F16 regression)';
    exception
      when restrict_violation or insufficient_privilege then null;  -- expected: blocked
    end;
  end $$;
rollback;

-- Immutability — UPDATE/DELETE as service_role must be blocked (SEC-F16) ------
-- Row-level trigger needs a target row, so we insert a probe inside a
-- transaction that is rolled back (nothing persists).
begin;
  insert into public.audit_events (actor_type, action, entity_table)
  values ('system', 'verify.probe', 'audit_events');

  do $$
  begin
    set local role service_role;

    begin
      update public.audit_events set reason = 'tamper' where action = 'verify.probe';
      raise exception 'EMPIRICAL/immutability: UPDATE as service_role SUCCEEDED (SEC-F16 regression)';
    exception
      when restrict_violation or insufficient_privilege then null;  -- expected
    end;

    begin
      delete from public.audit_events where action = 'verify.probe';
      raise exception 'EMPIRICAL/immutability: DELETE as service_role SUCCEEDED (SEC-F16 regression)';
    exception
      when restrict_violation or insufficient_privilege then null;  -- expected
    end;
  end $$;
rollback;

-- Default-deny — anon + authenticated have ZERO access (SEC-F02/F13) ----------
-- Grants are revoked, so a SELECT must raise insufficient_privilege (42501).
-- If a grant regression let the SELECT through (even 0 rows), we raise + fail.
begin;
  do $$
  declare rol text; tbl text;
  begin
    foreach rol in array array['anon','authenticated'] loop
      foreach tbl in array array['producers','applications','admin_users','audit_events'] loop
        begin
          execute format('set local role %I', rol);
          execute format('select 1 from public.%I limit 1', tbl);
          raise exception 'EMPIRICAL/default-deny: role % could query public.% (expected permission denied)', rol, tbl;
        exception
          when insufficient_privilege then null;  -- expected: 42501
        end;
      end loop;
    end loop;
  end $$;
rollback;

\echo 'OK — Phase 1 post-apply verification PASSED (§4 structural + §5 empirical).'
