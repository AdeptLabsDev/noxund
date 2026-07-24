-- ============================================================================
-- NOXUND · entity_resolution_candidates — POST-ROLLBACK verification (DEC-0014 · harness self-test)
-- ----------------------------------------------------------------------------
-- Run AFTER the paired rollback of migration
--   supabase/migrations/20260620000006_entity_resolution_candidates.sql
--   (supabase/rollback/20260620000006_entity_resolution_candidates.rollback.sql)
-- has reverted the unit, while migrations 0001–0005 remain applied. It is the
-- post-rollback counterpart of entity_resolution_candidates_post_apply_verify.sql,
-- authored to let the hermetic harness (.github/workflows/migrations-local-verify.yml)
-- exercise the full apply→verify→rollback→POST-ROLLBACK verify→reapply→verify cycle
-- against a KNOWN-GOOD, leaf migration (0006) — the QA-N1 self-test.
--
-- NATURE: PURELY READ-ONLY — catalog inspection only. ZERO writes (no INSERT/UPDATE/
-- DELETE/DDL, not even in rolled-back probes). It proves TWO things:
--   §1 ABSENCE — every object created EXCLUSIVELY by migration 0006 is gone (exact
--      parity with what the migration creates and the rollback drops), checked both
--      by explicit name AND by a generic `entity_resolution_candidates%` sweep that
--      would catch ANY stray relation/constraint/trigger/function of the unit.
--   §2 PRIOR CONTRACTS — the objects 0006 depends on / reuses remain present and
--      structurally unchanged (reused enum, prior enums with their exact label sets,
--      and the prior tables/columns 0006 references).
--
-- OBJECTS CREATED BY 0006 (must ALL be absent post-rollback):
--   type  public.entity_candidate_status (enum: pending/approved/rejected)
--   table public.entity_resolution_candidates  — and everything that drops WITH it:
--     constraints: entity_resolution_candidates_pkey,
--                  entity_resolution_candidates_run_id_fkey (→ report_runs),
--                  entity_resolution_candidates_artist_id_fkey (→ artists),
--                  entity_resolution_candidates_raw_video_fk (→ raw_youtube_videos),
--                  entity_resolution_candidates_llm_prompt_chk,
--                  entity_resolution_candidates_reviewed_at_chk,
--                  entity_resolution_candidates_resolver_version_nonblank_chk,
--                  entity_resolution_candidates_prompt_version_nonblank_chk
--     indexes:     entity_resolution_candidates_pkey (PK index),
--                  entity_resolution_candidates_pending_uidx,
--                  entity_resolution_candidates_pending_queue_idx,
--                  entity_resolution_candidates_run_status_idx,
--                  entity_resolution_candidates_artist_idx
--     (RLS + comment + grants drop WITH the table; 0006 creates ZERO triggers/functions.)
--
-- CONTRACT: every mismatch RAISES → `psql -v ON_ERROR_STOP=1` exits non-zero, failing CI.
-- Scope: this file does NOT modify the migration, rollback, post-apply verify or workflow.
-- ============================================================================

\set ON_ERROR_STOP on

\echo '== entity_resolution_candidates · §1 post-rollback ABSENCE verification =='

-- §1.a — table absent -----------------------------------------------------------
do $$
begin
  if exists (select 1 from information_schema.tables
     where table_schema = 'public' and table_name = 'entity_resolution_candidates') then
    raise exception 'ROLLBACK/table: public.entity_resolution_candidates still present';
  end if;
end $$;

-- §1.b — new enum type absent ---------------------------------------------------
do $$
begin
  if exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
     where n.nspname = 'public' and t.typname = 'entity_candidate_status') then
    raise exception 'ROLLBACK/enum: public.entity_candidate_status still present';
  end if;
end $$;

-- §1.c — every NAMED index the migration created is absent (explicit parity) -----
do $$
declare leftover text;
begin
  select string_agg(want, ', ') into leftover
    from (values
      ('entity_resolution_candidates_pkey'),
      ('entity_resolution_candidates_pending_uidx'),
      ('entity_resolution_candidates_pending_queue_idx'),
      ('entity_resolution_candidates_run_status_idx'),
      ('entity_resolution_candidates_artist_idx')
    ) as t(want)
   where exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relname = t.want);
  if leftover is not null then raise exception 'ROLLBACK/indexes: residual index(es): %', leftover; end if;
end $$;

-- §1.d — every constraint the migration created is absent (explicit parity) ------
--   named CHECKs + named composite FK + auto-named PK/FKs.
do $$
declare leftover text;
begin
  select string_agg(want, ', ') into leftover
    from (values
      ('entity_resolution_candidates_pkey'),
      ('entity_resolution_candidates_run_id_fkey'),
      ('entity_resolution_candidates_artist_id_fkey'),
      ('entity_resolution_candidates_raw_video_fk'),
      ('entity_resolution_candidates_llm_prompt_chk'),
      ('entity_resolution_candidates_reviewed_at_chk'),
      ('entity_resolution_candidates_resolver_version_nonblank_chk'),
      ('entity_resolution_candidates_prompt_version_nonblank_chk')
    ) as t(want)
   where exists (select 1 from pg_constraint where conname = t.want);
  if leftover is not null then raise exception 'ROLLBACK/constraints: residual constraint(s): %', leftover; end if;
end $$;

-- §1.e — GENERIC sweep: NO relation/constraint/trigger/function/type of the unit --
--   Catches ANY stray object named entity_resolution_candidates* that an incomplete
--   rollback might leave behind — beyond the explicitly enumerated ones above.
do $$
declare leftover text;
begin
  -- relations (table/index/sequence/view/matview) in public
  select string_agg(c.relname || '(' || c.relkind::text || ')', ', ') into leftover
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relname like 'entity_resolution_candidates%';
  if leftover is not null then raise exception 'ROLLBACK/sweep-relation: residual relation(s): %', leftover; end if;

  -- constraints (any schema/relation)
  select string_agg(conname, ', ') into leftover
    from pg_constraint where conname like 'entity_resolution_candidates%';
  if leftover is not null then raise exception 'ROLLBACK/sweep-constraint: residual constraint(s): %', leftover; end if;

  -- user triggers (0006 creates none — assert none linger)
  select string_agg(tgname, ', ') into leftover
    from pg_trigger where not tgisinternal and tgname like 'entity_resolution_candidates%';
  if leftover is not null then raise exception 'ROLLBACK/sweep-trigger: residual trigger(s): %', leftover; end if;

  -- functions in public (0006 creates none — assert none linger)
  select string_agg(p.proname, ', ') into leftover
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname like 'entity_resolution_candidates%';
  if leftover is not null then raise exception 'ROLLBACK/sweep-function: residual function(s): %', leftover; end if;

  -- enum type by prefix (belt-and-suspenders with §1.b)
  select string_agg(t.typname, ', ') into leftover
    from pg_type t join pg_namespace n on n.oid = t.typnamespace
   where n.nspname = 'public' and t.typname like 'entity_candidate_status%';
  if leftover is not null then raise exception 'ROLLBACK/sweep-type: residual type(s): %', leftover; end if;
end $$;

\echo '== entity_resolution_candidates · §2 PRIOR-CONTRACT integrity verification =='

-- §2.a — reused enum public.video_artist_method present with its EXACT 4 labels ---
--   The rollback must NEVER drop/alter it (it belongs to Fase 5, only reused by 0006).
do $$
declare got text;
begin
  if not exists (select 1 from pg_type where typname = 'video_artist_method') then
    raise exception 'PRIOR/enum: video_artist_method (reused by 0006) MISSING — rollback over-reached?';
  end if;
  select string_agg(e.enumlabel, ',' order by e.enumsortorder) into got
    from pg_enum e join pg_type t on t.oid = e.enumtypid where t.typname = 'video_artist_method';
  if got is distinct from 'regex,llm_assisted,human_override,unknown' then
    raise exception 'PRIOR/enum: video_artist_method labels changed — expected regex,llm_assisted,human_override,unknown; got %', got;
  end if;
end $$;

-- §2.b — prior enum public.report_run_status present with its EXACT 5 labels ------
do $$
declare got text;
begin
  if not exists (select 1 from pg_type where typname = 'report_run_status') then
    raise exception 'PRIOR/enum: report_run_status MISSING';
  end if;
  select string_agg(e.enumlabel, ',' order by e.enumsortorder) into got
    from pg_enum e join pg_type t on t.oid = e.enumtypid where t.typname = 'report_run_status';
  if got is distinct from 'created,collecting,processed,published,failed' then
    raise exception 'PRIOR/enum: report_run_status labels changed — expected created,collecting,processed,published,failed; got %', got;
  end if;
end $$;

-- §2.c — prior tables 0006 depends on / that must survive the rollback are present -
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values ('report_runs'), ('artists'), ('raw_youtube_videos'),
                 ('video_artist_mappings'), ('artist_metrics'), ('reports'), ('report_items')) as t(want)
   where not exists (select 1 from information_schema.tables
     where table_schema = 'public' and table_name = t.want);
  if missing is not null then raise exception 'PRIOR/tables: missing prior table(s): %', missing; end if;
end $$;

-- §2.d — spot structural integrity: key columns of prior contracts still present --
--   Detects gross structural damage to prior objects (undue ALTER). NOT exhaustive
--   by design — targets the FK-target and user-mandated columns.
do $$
declare missing text;
begin
  select string_agg(t.tbl || '.' || t.col, ', ') into missing from (values
    ('report_runs','id'), ('report_runs','status'),
    ('artists','id'),
    ('raw_youtube_videos','run_id'), ('raw_youtube_videos','video_id'),
    ('video_artist_mappings','run_id'), ('video_artist_mappings','video_id'), ('video_artist_mappings','artist_id'),
    ('artist_metrics','run_id'), ('artist_metrics','rubric_hash'), ('artist_metrics','final_score'),
    ('reports','id'), ('reports','run_id'), ('reports','status'),
    ('report_items','report_id'), ('report_items','artist_metric_id')
  ) as t(tbl, col)
   where not exists (select 1 from information_schema.columns
     where table_schema = 'public' and table_name = t.tbl and column_name = t.col);
  if missing is not null then raise exception 'PRIOR/columns: prior-contract column(s) missing (undue structural change?): %', missing; end if;
end $$;

\echo 'OK — entity_resolution_candidates POST-ROLLBACK verification PASSED (§1 absence + §2 prior-contract integrity).'
