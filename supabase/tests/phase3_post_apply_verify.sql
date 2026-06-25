-- ============================================================================
-- NOXUND · Phase 3 — post-apply verification (Runs + Artists)
-- ----------------------------------------------------------------------------
-- Run by CI immediately after `supabase db push` applies
--   supabase/migrations/20260620000003_phase3_runs_artists.sql
-- Parity with supabase/tests/phase1_/phase2_post_apply_verify.sql.
--
-- WHY EMPIRICAL: report_runs is the raw-provenance ANCHOR. service_role bypasses
-- RLS and holds DML grants, so the "identity frozen + never deleted" guarantee can
-- only be proven by the TRIGGERS firing. We assert that path (restrict_violation),
-- AND assert a benign STATE update (status) still works — the freeze is column-scoped.
--
-- CONTRACT: every check RAISES on mismatch, so `psql -v ON_ERROR_STOP=1` exits
-- non-zero and fails the CI job. There is no silent pass.
-- SIDE EFFECTS: none persisted — all probe writes live in rolled-back transactions.
-- Role: connects as project `postgres` (member of anon/authenticated/service_role).
-- ============================================================================

\set ON_ERROR_STOP on

\echo '== Phase 3 · §4 structural verification =='

-- 3 tables --------------------------------------------------------------------
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values ('report_runs'), ('artists'), ('artist_aliases')) as t(want)
   where not exists (
     select 1 from information_schema.tables
      where table_schema = 'public' and table_name = t.want
   );
  if missing is not null then
    raise exception 'STRUCT/tables: missing Phase 3 table(s): %', missing;
  end if;
end $$;

-- 2 enums ---------------------------------------------------------------------
do $$
declare n int;
begin
  select count(*) into n
    from pg_type
   where typname in ('report_run_status', 'artist_alias_source');
  if n <> 2 then
    raise exception 'STRUCT/enums: expected 2 enums, found %', n;
  end if;
end $$;

-- 2 provenance-guard triggers on report_runs ----------------------------------
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values ('report_runs_row_guard'), ('report_runs_no_truncate')) as t(want)
   where not exists (
     select 1 from pg_trigger
      where tgrelid = 'public.report_runs'::regclass
        and not tgisinternal
        and tgname = t.want
   );
  if missing is not null then
    raise exception 'STRUCT/triggers: missing report_runs guard trigger(s): %', missing;
  end if;
end $$;

-- guard functions with pinned search_path -------------------------------------
do $$
declare want text; cfg text[];
begin
  foreach want in array array['report_runs_row_guard', 'report_runs_no_truncate'] loop
    select proconfig into cfg
      from pg_proc
     where proname = want and pronamespace = 'public'::regnamespace;
    if not found then
      raise exception 'STRUCT/function: public.%() not found', want;
    end if;
    if cfg is null or not exists (select 1 from unnest(cfg) c where c like 'search_path=%') then
      raise exception 'STRUCT/function: expected pinned search_path on %(), got %', want, cfg;
    end if;
  end loop;
end $$;

-- dedupe unique indexes + FK --------------------------------------------------
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values ('artists_canonical_name_lower_uidx'), ('artist_aliases_alias_lower_uidx')) as t(want)
   where not exists (
     select 1 from pg_indexes where schemaname = 'public' and indexname = t.want
   );
  if missing is not null then
    raise exception 'STRUCT/indexes: missing dedupe unique index(es): %', missing;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conname = 'artist_aliases_artist_id_fkey'
       and conrelid = 'public.artist_aliases'::regclass
       and contype = 'f'
  ) then
    raise exception 'STRUCT/fk: artist_aliases.artist_id FK to artists not found';
  end if;
end $$;

-- RLS enabled (default-deny) on all 3 -----------------------------------------
do $$
declare bad text;
begin
  select string_agg(relname, ', ') into bad
    from pg_class
   where relnamespace = 'public'::regnamespace
     and relname in ('report_runs', 'artists', 'artist_aliases')
     and relrowsecurity = false;
  if bad is not null then
    raise exception 'STRUCT/rls: RLS not enabled on: %', bad;
  end if;
end $$;

\echo '== Phase 3 · §5 empirical verification =='

-- Provenance — TRUNCATE report_runs as service_role must be blocked (trigger or grant)
begin;
  do $$
  begin
    perform set_config('role', 'service_role', true);
    begin
      truncate public.report_runs;
      raise exception 'EMPIRICAL/provenance: TRUNCATE report_runs as service_role SUCCEEDED (anchor regression)';
    exception
      when restrict_violation or insufficient_privilege then null;  -- blocked (trigger or grant) = expected
    end;
  end $$;
rollback;

-- Provenance — identity-UPDATE + DELETE must be blocked; a benign STATE update (status)
-- must SUCCEED (freeze is column-scoped). We prove the freeze on BOTH role paths:
--   • as postgres (grant-holder): only the TRIGGER can block -> restrict_violation specifically;
--   • as service_role (bypasses RLS): blocked by trigger or grant -> either errcode.
begin;
  insert into public.report_runs (window_start, window_end)
  values (now() - interval '30 days', now());

  do $$
  begin
    -- benign STATE update as the connecting (postgres) role: must PASS the guard
    update public.report_runs set status = 'collecting';

    -- POSITIVE freeze proof (SEC-F22): identity UPDATE as postgres (grant-holder) is blocked
    -- by the TRIGGER itself — proves the freeze is enforced, not merely a missing grant.
    begin
      update public.report_runs set keyword = 'tamper';
      raise exception 'EMPIRICAL/provenance: identity UPDATE (keyword) as grant-holder SUCCEEDED (freeze regression)';
    exception
      when restrict_violation then null;  -- expected: blocked by trigger (grant-holder path)
    end;

    perform set_config('role', 'service_role', true);

    begin
      update public.report_runs set keyword = 'tamper2';
      raise exception 'EMPIRICAL/provenance: identity UPDATE (keyword) as service_role SUCCEEDED (freeze regression)';
    exception
      when restrict_violation or insufficient_privilege then null;  -- blocked (trigger or grant) = expected
    end;

    begin
      delete from public.report_runs;
      raise exception 'EMPIRICAL/provenance: DELETE report_runs as service_role SUCCEEDED (anchor regression)';
    exception
      when restrict_violation or insufficient_privilege then null;  -- blocked (trigger or grant) = expected
    end;
  end $$;
rollback;

-- Default-deny — anon + authenticated have ZERO access to the 3 internal tables ----
begin;
  do $$
  declare rol text; t text;
  begin
    foreach rol in array array['anon', 'authenticated'] loop
      foreach t in array array['report_runs', 'artists', 'artist_aliases'] loop
        begin
          perform set_config('role', rol, true);
          execute format('select 1 from public.%I limit 1', t);
          raise exception 'EMPIRICAL/default-deny: role % could query public.% (expected permission denied)', rol, t;
        exception
          when insufficient_privilege then null;  -- expected: 42501
        end;
      end loop;
    end loop;
  end $$;
rollback;

\echo 'OK — Phase 3 post-apply verification PASSED (§4 structural + §5 empirical).'
