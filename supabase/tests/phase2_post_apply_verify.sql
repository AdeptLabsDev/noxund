-- ============================================================================
-- NOXUND · Phase 2 — post-apply verification (Versionamento)
-- ----------------------------------------------------------------------------
-- Run by CI immediately after `supabase db push` applies
--   supabase/migrations/20260620000002_phase2_versioning.sql
-- (see .github/workflows/phase2-db-apply.yml). Parity with
--   supabase/tests/phase1_post_apply_verify.sql, per SEC-0007 §4.
--
-- WHY EMPIRICAL: the append-only guarantee on the *_versions tables must be
-- proven in the DB, not assumed (SEC-0007 §2 / SEC-0003 §2). A mutation by
-- `service_role` is blocked by EITHER the immutability trigger
-- (errcode restrict_violation) OR — when the environment grants service_role no
-- DML on these tables (the Fase 1 revoke pattern, approved in SEC-0004/0006) —
-- the grant layer (errcode insufficient_privilege). BOTH outcomes prove
-- append-only, so §5 accepts either errcode, in exact parity with
-- phase1_post_apply_verify.sql. The service_role grant state is
-- environment-dependent: asserting only restrict_violation produced a
-- false-negative on the first real run (apply OK; verify failed on UPDATE with
-- insufficient_privilege). Only a SUCCESSFUL mutation is a regression.
--
-- CONTRACT: every check RAISES on mismatch, so `psql -v ON_ERROR_STOP=1` exits
-- non-zero and fails the CI job. There is no silent pass.
--
-- SIDE EFFECTS: none persisted. The only writes are probe rows created inside
-- transactions that are ALWAYS rolled back.
--
-- Role: connects as the project `postgres` role (member of anon / authenticated
-- / service_role); switches role via set_config('role', ..., true) for §5.
-- ============================================================================

\set ON_ERROR_STOP on

\echo '== Phase 2 · §4 structural verification =='

-- 2 versioning tables ---------------------------------------------------------
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values ('rubric_versions'), ('outcome_weight_versions')) as t(want)
   where not exists (
     select 1 from information_schema.tables
      where table_schema = 'public' and table_name = t.want
   );
  if missing is not null then
    raise exception 'STRUCT/tables: missing versioning table(s): %', missing;
  end if;
end $$;

-- 4 immutability triggers (UPDATE/DELETE row + TRUNCATE statement, both tables)-
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values
      ('rubric_versions_no_update_delete'),
      ('rubric_versions_no_truncate'),
      ('outcome_weight_versions_no_update_delete'),
      ('outcome_weight_versions_no_truncate')
    ) as t(want)
   where not exists (
     select 1 from pg_trigger
      where not tgisinternal
        and tgname = t.want
        and tgrelid in ('public.rubric_versions'::regclass,
                        'public.outcome_weight_versions'::regclass)
   );
  if missing is not null then
    raise exception 'STRUCT/triggers: missing immutability trigger(s): %', missing;
  end if;
end $$;

-- shared trigger function with pinned search_path (parity w/ SEC-0007 §1) ------
do $$
declare cfg text[];
begin
  select proconfig into cfg
    from pg_proc
   where proname = 'versioning_row_immutable' and pronamespace = 'public'::regnamespace;
  if not found then
    raise exception 'STRUCT/function: public.versioning_row_immutable() not found';
  end if;
  if cfg is null or not exists (select 1 from unnest(cfg) c where c like 'search_path=%') then
    raise exception 'STRUCT/function: expected pinned search_path on versioning_row_immutable(), got %', cfg;
  end if;
end $$;

-- version-uniqueness constraints (reproducibility backbone, SEC-0007 §2) -------
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values
      ('rubric_versions_version_key'),
      ('rubric_versions_version_hash_key'),
      ('outcome_weight_versions_version_key'),
      ('outcome_weight_versions_version_hash_key')
    ) as t(want)
   where not exists (
     select 1 from pg_constraint where conname = t.want and contype = 'u'
   );
  if missing is not null then
    raise exception 'STRUCT/constraints: missing unique constraint(s): %', missing;
  end if;
end $$;

-- RLS enabled (default-deny) on both ------------------------------------------
do $$
declare bad text;
begin
  select string_agg(relname, ', ') into bad
    from pg_class
   where relnamespace = 'public'::regnamespace
     and relname in ('rubric_versions','outcome_weight_versions')
     and relrowsecurity = false;
  if bad is not null then
    raise exception 'STRUCT/rls: RLS not enabled on: %', bad;
  end if;
end $$;

\echo '== Phase 2 · §5 empirical verification =='

-- Immutability — TRUNCATE as service_role must be BLOCKED ----------------------
-- Blocked by the statement-level trigger (restrict_violation) OR by a missing
-- service_role TRUNCATE grant (insufficient_privilege) — both prove append-only.
-- Accept either; only a SUCCESSFUL truncate is a regression.
begin;
  do $$
  declare t text;
  begin
    perform set_config('role', 'service_role', true);
    foreach t in array array['rubric_versions','outcome_weight_versions'] loop
      begin
        execute format('truncate public.%I', t);
        raise exception 'EMPIRICAL/immutability: TRUNCATE as service_role SUCCEEDED on % (append-only regression)', t;
      exception
        when restrict_violation or insufficient_privilege then null;  -- blocked (trigger or grant) = expected
      end;
    end loop;
  end $$;
rollback;

-- Immutability — UPDATE/DELETE as service_role must be BLOCKED -----------------
-- Same dual-accept rationale: trigger (restrict_violation) OR missing grant
-- (insufficient_privilege). Row-level triggers need a target row, so we insert
-- probes inside a rolled-back tx (nothing persists).
begin;
  do $$
  declare t text;
  begin
    -- probes inserted as the connecting (postgres) role; INSERT is allowed
    foreach t in array array['rubric_versions','outcome_weight_versions'] loop
      execute format(
        'insert into public.%I (version, config_json, hash) values (%L, %L::jsonb, %L)',
        t, '__verify_probe__', '{}', '__probe__');
    end loop;

    perform set_config('role', 'service_role', true);

    foreach t in array array['rubric_versions','outcome_weight_versions'] loop
      begin
        execute format('update public.%I set hash = %L where version = %L', t, 'tamper', '__verify_probe__');
        raise exception 'EMPIRICAL/immutability: UPDATE as service_role SUCCEEDED on % (append-only regression)', t;
      exception
        when restrict_violation or insufficient_privilege then null;  -- blocked (trigger or grant) = expected
      end;
      begin
        execute format('delete from public.%I where version = %L', t, '__verify_probe__');
        raise exception 'EMPIRICAL/immutability: DELETE as service_role SUCCEEDED on % (append-only regression)', t;
      exception
        when restrict_violation or insufficient_privilege then null;  -- blocked (trigger or grant) = expected
      end;
    end loop;
  end $$;
rollback;

-- Default-deny — anon + authenticated have ZERO access (revoke honored) --------
-- Grants revoked -> a SELECT must raise insufficient_privilege (42501).
begin;
  do $$
  declare rol text; t text;
  begin
    foreach rol in array array['anon','authenticated'] loop
      foreach t in array array['rubric_versions','outcome_weight_versions'] loop
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

\echo 'OK — Phase 2 post-apply verification PASSED (§4 structural + §5 empirical).'
