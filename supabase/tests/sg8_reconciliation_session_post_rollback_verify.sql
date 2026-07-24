-- ============================================================================
-- NOXUND · SG-8 Reconciliation Session — POST-ROLLBACK verification (DATA-SG8-001 estágio 3)
-- ----------------------------------------------------------------------------
-- Run AFTER the paired rollback of migration
--   supabase/migrations/20260620000008_sg8_reconciliation_session.sql
--   (supabase/rollback/20260620000008_sg8_reconciliation_session.rollback.sql)
-- has reverted the unit, while migrations 0001–0006 remain applied.
--
-- NATURE: PURELY READ-ONLY — catalog inspection only. ZERO writes. Proves TWO things:
--   §1 ABSENCE — every object created EXCLUSIVELY by migration 0008 is gone (the 4 tables,
--      the enum, the 3 integrity functions, and — dropped WITH the tables — every index/
--      constraint/trigger of the unit), PLUS the additive UNIQUE reports_id_run_key. Checked
--      by explicit name AND by a generic `sg8_%` / `sg8_session_status%` sweep that would catch
--      ANY stray object of the unit.
--   §2 PRIOR CONTRACTS — reports, report_runs and the contracts 0008 depends on remain intact:
--      reports keeps id (PK) + run_id + its prior constraints, WITHOUT reports_id_run_key;
--      report_runs is untouched (report_run_status keeps 5 labels; original guards present;
--      no SG-8 column/trigger/grant residue on preexisting objects).
--
-- CONTRACT: every mismatch RAISES → `psql -v ON_ERROR_STOP=1` exits non-zero, failing CI.
-- Scope: this file does NOT modify the migration, rollback, post-apply verify or workflow.
-- ============================================================================

\set ON_ERROR_STOP on

\echo '== sg8_reconciliation_session · §1 post-rollback ABSENCE verification =='

-- §1.a — as 4 tabelas SG-8 ausentes --------------------------------------------
do $$
declare leftover text;
begin
  select string_agg(want, ', ') into leftover
    from (values ('sg8_sessions'),('sg8_resolution_snapshots'),
                 ('sg8_round_executions'),('sg8_round_report_evidence')) as t(want)
   where exists (select 1 from information_schema.tables
     where table_schema = 'public' and table_name = t.want);
  if leftover is not null then raise exception 'ROLLBACK/tables: residual SG-8 table(s): %', leftover; end if;
end $$;

-- §1.b — o enum SG-8 ausente ---------------------------------------------------
do $$
begin
  if exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
     where n.nspname = 'public' and t.typname = 'sg8_session_status') then
    raise exception 'ROLLBACK/enum: public.sg8_session_status still present';
  end if;
end $$;

-- §1.c — as 3 funções de integridade da migration ausentes ---------------------
do $$
declare leftover text;
begin
  select string_agg(want, ', ') into leftover
    from (values ('sg8_append_only_guard'),('sg8_sessions_guard'),('sg8_round_report_evidence_guard')) as t(want)
   where exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = t.want);
  if leftover is not null then raise exception 'ROLLBACK/functions: residual SG-8 function(s): %', leftover; end if;
end $$;

-- §1.d — a UNIQUE aditiva reports_id_run_key ausente ---------------------------
do $$
begin
  if exists (select 1 from pg_constraint where conname = 'reports_id_run_key') then
    raise exception 'ROLLBACK/constraint: additive reports_id_run_key still present on reports';
  end if;
end $$;

-- §1.e — GENERIC sweep: nenhum objeto residual do unit (sg8_% / sg8_session_status%) ---
do $$
declare leftover text;
begin
  -- relações (tabela/índice/sequence/view) em public
  select string_agg(c.relname || '(' || c.relkind::text || ')', ', ') into leftover
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relname like 'sg8_%';
  if leftover is not null then raise exception 'ROLLBACK/sweep-relation: residual relation(s): %', leftover; end if;

  -- constraints (índices únicos, checks, FKs) com prefixo do unit
  select string_agg(conname, ', ') into leftover
    from pg_constraint where conname like 'sg8_%';
  if leftover is not null then raise exception 'ROLLBACK/sweep-constraint: residual constraint(s): %', leftover; end if;

  -- triggers (não-internos) do unit
  select string_agg(tgname, ', ') into leftover
    from pg_trigger where not tgisinternal and tgname like 'sg8_%';
  if leftover is not null then raise exception 'ROLLBACK/sweep-trigger: residual trigger(s): %', leftover; end if;

  -- funções do unit
  select string_agg(p.proname, ', ') into leftover
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname like 'sg8_%';
  if leftover is not null then raise exception 'ROLLBACK/sweep-function: residual function(s): %', leftover; end if;

  -- tipos do unit
  select string_agg(t.typname, ', ') into leftover
    from pg_type t join pg_namespace n on n.oid = t.typnamespace
   where n.nspname = 'public' and t.typname like 'sg8_%';
  if leftover is not null then raise exception 'ROLLBACK/sweep-type: residual type(s): %', leftover; end if;
end $$;

\echo '== sg8_reconciliation_session · §2 PRIOR-CONTRACT integrity verification =='

-- §2.a — reports intacta: id (PK) + run_id + colunas prévias; SEM reports_id_run_key ---
do $$
declare missing text;
begin
  if not exists (select 1 from information_schema.tables
     where table_schema = 'public' and table_name = 'reports') then
    raise exception 'PRIOR/reports: table MISSING';
  end if;
  select string_agg(want, ', ') into missing
    from (values ('id'),('run_id'),('title'),('vertical'),('keyword'),
                 ('rubric_version'),('rubric_hash'),('status'),('published_at'),('created_at')) as t(want)
   where not exists (select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'reports' and column_name = t.want);
  if missing is not null then raise exception 'PRIOR/reports: missing prior column(s): %', missing; end if;
  -- PK e constraints prévias de reports preservadas (NÃO tocadas pela migration/rollback SG-8)
  if not exists (select 1 from pg_constraint where conname = 'reports_pkey'
     and conrelid = 'public.reports'::regclass and contype = 'p') then
    raise exception 'PRIOR/reports: reports_pkey missing';
  end if;
  select string_agg(want, ', ') into missing
    from (values ('reports_rubric_fk'),('reports_identity_key')) as t(want)
   where not exists (select 1 from pg_constraint where conname = t.want
     and conrelid = 'public.reports'::regclass);
  if missing is not null then raise exception 'PRIOR/reports: missing prior constraint(s): %', missing; end if;
end $$;

-- §2.b — report_runs INTACTA: enum de 5 rótulos, guards originais, sem resíduo SG-8 ---
do $$
declare n int;
begin
  if not exists (select 1 from information_schema.tables
     where table_schema = 'public' and table_name = 'report_runs') then
    raise exception 'PRIOR/report_runs: table MISSING';
  end if;
  select count(*) into n from pg_enum e join pg_type t on t.oid = e.enumtypid
   where t.typname = 'report_run_status';
  if n <> 5 then raise exception 'PRIOR/report_runs: report_run_status must keep 5 labels, found %', n; end if;
  -- guards originais presentes
  select count(*) into n from pg_trigger where not tgisinternal
   and tgrelid = 'public.report_runs'::regclass
   and tgname in ('report_runs_row_guard','report_runs_no_truncate');
  if n <> 2 then raise exception 'PRIOR/report_runs: original guards missing (found % of 2)', n; end if;
  -- nenhuma coluna SG-8 residual
  if exists (select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'report_runs'
       and column_name in ('sg8_session_id','sg8_status','computed_pending_repro','sg8_eligible')) then
    raise exception 'PRIOR/report_runs: residual SG-8 column on report_runs';
  end if;
  -- nenhum trigger SG-8 residual
  if exists (select 1 from pg_trigger where not tgisinternal
     and tgrelid = 'public.report_runs'::regclass and tgname like '%sg8%') then
    raise exception 'PRIOR/report_runs: residual sg8 trigger on report_runs';
  end if;
end $$;

-- §2.c — nenhum grant/trigger SG-8 residual em objetos preexistentes (reports/report_runs) ---
do $$
declare leftover text;
begin
  if exists (select 1 from pg_trigger where not tgisinternal
     and tgrelid = 'public.reports'::regclass and tgname like '%sg8%') then
    raise exception 'PRIOR/reports: residual sg8 trigger on reports';
  end if;
  -- nenhum privilégio concedido a partir da migration SG-8 sobre reports/report_runs
  -- (a migration só ADICIONOU uma unique em reports, já provada ausente em §1.d; não concedeu grants).
  -- Sanidade: nenhuma coluna sg8_* em reports.
  if exists (select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'reports' and column_name like 'sg8_%') then
    raise exception 'PRIOR/reports: residual sg8 column on reports';
  end if;
end $$;

\echo 'OK — sg8_reconciliation_session POST-ROLLBACK verification PASSED (§1 absence + §2 prior-contract integrity).'
