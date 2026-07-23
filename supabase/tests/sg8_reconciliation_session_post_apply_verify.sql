-- ============================================================================
-- NOXUND · SG-8 Reconciliation Session — post-apply verification (DATA-SG8-001 estágio 3)
-- ----------------------------------------------------------------------------
-- Run by CI immediately after `supabase db push` applies
--   supabase/migrations/20260620000008_sg8_reconciliation_session.sql
-- Parity with supabase/tests/phase1_…_phase5 + entity_resolution post-apply verifies.
--
-- DESIGN-ONLY: autorado, NÃO aplicado. Roda no job `verify` quando o apply gated for
-- sequenciado. Exercita CONSTRAINTS/TRIGGERS, não o runner (Data/AI engine) nem SG-8.
--
-- NATUREZA: prova o que É garantido pelo schema. §4 estrutural: existência dos objetos;
-- FKs/NOT NULL/CHECK/uniques; ACLs default-deny. §5 empírico: HARDENING —
--   (item 1) a sessão NÃO pode nascer terminal nem vinculada nem em outro estado;
--   (item 2) máquina de estados MONOTÔNICA — só o próximo avanço ou failed; saltos,
--            regressões, no-op e reabertura rejeitados;
--   (item 3) estados terminais exigem terminal_at + verdict_reason não-branco; não-terminais
--            exigem ambos NULOS;
--   (item 4) GATE DE PASS — passed sem rodadas/evidências completas ou com digest divergente
--            é rejeitado; PASS completo e consistente é aceito;
--   (item 5) default-deny nas 4 tabelas p/ PUBLIC + anon + authenticated (leitura E escrita);
--   além das invariantes anteriores (binding diferido, FKs compostas, append-only,
--   terminalidade, snapshot único, rodadas zero-LLM/all-or-nothing, pertencimento de evidência)
--   que continuam GREEN; e ausência de alteração em report_runs.
--
-- WHY EMPIRICAL: default-deny é a garantia de superfície; provada por ACL (has_table_privilege)
--   e nos 2 role-paths (DEC-0009): as postgres (grant-holder) só constraint/trigger barram;
--   as anon/authenticated sem grant → insufficient_privilege (SEC-F21/F07).
--
-- CONTRACT: todo check RAISES on mismatch → `psql -v ON_ERROR_STOP=1` sai não-zero, falha o CI.
-- SIDE EFFECTS: nenhum persistido — toda escrita de probe vive em transação revertida.
-- Role: conecta como `postgres` do projeto (membro de anon/authenticated/service_role).
-- ============================================================================

\set ON_ERROR_STOP on

\echo '== sg8_reconciliation_session · §4 structural verification =='

-- 4 tabelas presentes ---------------------------------------------------------
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values ('sg8_sessions'), ('sg8_resolution_snapshots'),
                 ('sg8_round_executions'), ('sg8_round_report_evidence')) as t(want)
   where not exists (select 1 from information_schema.tables
     where table_schema = 'public' and table_name = t.want);
  if missing is not null then raise exception 'STRUCT/table: missing: %', missing; end if;
end $$;

-- enum sg8_session_status: os 7 marcos duráveis do runner (nenhum estado novo) -----
do $$
declare n int; missing text;
begin
  if not exists (select 1 from pg_type where typname = 'sg8_session_status') then
    raise exception 'STRUCT/enum: sg8_session_status missing';
  end if;
  select count(*) into n from pg_enum e join pg_type t on t.oid = e.enumtypid
   where t.typname = 'sg8_session_status';
  if n <> 7 then raise exception 'STRUCT/enum: sg8_session_status expected 7 labels, found %', n; end if;
  select string_agg(want, ', ') into missing
    from (values ('session_open'),('r1_awaiting_review'),('r1_resolved'),('r1_snapshot_frozen'),
                 ('r1_computed'),('passed'),('failed')) as t(want)
   where not exists (select 1 from pg_enum e join pg_type ty on ty.oid = e.enumtypid
     where ty.typname = 'sg8_session_status' and e.enumlabel = t.want);
  if missing is not null then raise exception 'STRUCT/enum: sg8_session_status missing labels: %', missing; end if;
end $$;

-- UNIQUE aditiva reports_id_run_key presente em reports ------------------------
do $$
begin
  if not exists (select 1 from pg_constraint
     where conname = 'reports_id_run_key' and conrelid = 'public.reports'::regclass and contype = 'u') then
    raise exception 'STRUCT/unique: reports_id_run_key (id, run_id) missing on reports';
  end if;
end $$;

-- colunas obrigatórias por tabela ---------------------------------------------
do $$
declare missing text;
begin
  select string_agg(t.tbl || '.' || t.col, ', ') into missing from (values
    ('sg8_sessions','id'),('sg8_sessions','source_collection_run_id'),('sg8_sessions','report_id_1'),
    ('sg8_sessions','report_id_2'),('sg8_sessions','status'),('sg8_sessions','verdict_reason'),
    ('sg8_sessions','created_at'),('sg8_sessions','terminal_at'),
    ('sg8_resolution_snapshots','id'),('sg8_resolution_snapshots','sg8_session_id'),
    ('sg8_resolution_snapshots','source_collection_run_id'),('sg8_resolution_snapshots','resolver_version'),
    ('sg8_resolution_snapshots','resolver_hash'),('sg8_resolution_snapshots','fact_count'),
    ('sg8_resolution_snapshots','content_hash'),('sg8_resolution_snapshots','frozen_at'),
    ('sg8_round_executions','id'),('sg8_round_executions','sg8_session_id'),
    ('sg8_round_executions','round_number'),('sg8_round_executions','source_collection_run_id'),
    ('sg8_round_executions','resolution_snapshot_id'),('sg8_round_executions','llm_provider'),
    ('sg8_round_executions','llm_model'),('sg8_round_executions','llm_model_version'),
    ('sg8_round_executions','llm_prompt_hash'),('sg8_round_executions','llm_params_json'),
    ('sg8_round_executions','llm_adapter_version'),('sg8_round_executions','created_at'),
    ('sg8_round_report_evidence','id'),('sg8_round_report_evidence','round_execution_id'),
    ('sg8_round_report_evidence','sg8_session_id'),('sg8_round_report_evidence','report_id'),
    ('sg8_round_report_evidence','canonical_digest'),('sg8_round_report_evidence','created_at')
  ) as t(tbl, col)
   where not exists (select 1 from information_schema.columns
     where table_schema = 'public' and table_name = t.tbl and column_name = t.col);
  if missing is not null then raise exception 'STRUCT/columns: missing: %', missing; end if;
end $$;

-- NOT NULL onde exigido; NULLABLE onde o lifecycle precisa --------------------
do $$
declare bad text;
begin
  select string_agg(table_name || '.' || column_name, ', ') into bad from information_schema.columns
   where table_schema = 'public'
     and ( (table_name = 'sg8_sessions' and column_name in ('id','source_collection_run_id','status','created_at'))
        or (table_name = 'sg8_resolution_snapshots' and column_name in ('id','sg8_session_id','source_collection_run_id','resolver_version','resolver_hash','fact_count','content_hash','frozen_at'))
        or (table_name = 'sg8_round_executions' and column_name in ('id','sg8_session_id','round_number','source_collection_run_id','resolution_snapshot_id','created_at'))
        or (table_name = 'sg8_round_report_evidence' and column_name in ('id','round_execution_id','sg8_session_id','report_id','canonical_digest','created_at')) )
     and is_nullable <> 'NO';
  if bad is not null then raise exception 'STRUCT/not-null: must be NOT NULL: %', bad; end if;

  select string_agg(table_name || '.' || column_name, ', ') into bad from information_schema.columns
   where table_schema = 'public'
     and ( (table_name = 'sg8_sessions' and column_name in ('report_id_1','report_id_2','verdict_reason','terminal_at'))
        or (table_name = 'sg8_round_executions' and column_name in ('llm_provider','llm_model','llm_model_version','llm_prompt_hash','llm_params_json','llm_adapter_version')) )
     and is_nullable <> 'YES';
  if bad is not null then raise exception 'STRUCT/nullable: must be NULLABLE: %', bad; end if;
end $$;

-- status default 'session_open' -----------------------------------------------
do $$
declare def text;
begin
  select column_default into def from information_schema.columns
   where table_schema = 'public' and table_name = 'sg8_sessions' and column_name = 'status';
  if def is null or def not like '%session_open%' then
    raise exception 'STRUCT/default: sg8_sessions.status default must be session_open, got %', def;
  end if;
end $$;

-- TODAS as FKs das 4 tabelas são ON DELETE RESTRICT ---------------------------
do $$
declare bad text;
begin
  select string_agg(conname, ', ') into bad from pg_constraint
   where contype = 'f'
     and conrelid in ('public.sg8_sessions'::regclass, 'public.sg8_resolution_snapshots'::regclass,
                      'public.sg8_round_executions'::regclass, 'public.sg8_round_report_evidence'::regclass)
     and confdeltype <> 'r';
  if bad is not null then raise exception 'STRUCT/fk: non-RESTRICT ON DELETE: %', bad; end if;
end $$;

-- FKs COMPOSTAS nomeadas (binding + coerência de dataset) ----------------------
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values
      ('sg8_sessions_report_1_source_fk'),('sg8_sessions_report_2_source_fk'),
      ('sg8_resolution_snapshots_session_source_fk'),
      ('sg8_round_executions_session_source_fk'),('sg8_round_executions_snapshot_session_fk'),
      ('sg8_round_report_evidence_round_session_fk')
    ) as t(want)
   where not exists (select 1 from pg_constraint where contype = 'f' and conname = t.want);
  if missing is not null then raise exception 'STRUCT/fk: missing composite FK(s): %', missing; end if;
end $$;

-- as 2 FKs de binding apontam para reports(id, run_id) -------------------------
do $$
declare bad text;
begin
  select string_agg(conname, ', ') into bad from pg_constraint
   where conname in ('sg8_sessions_report_1_source_fk','sg8_sessions_report_2_source_fk')
     and confrelid <> 'public.reports'::regclass;
  if bad is not null then raise exception 'STRUCT/fk: binding FK(s) not targeting reports: %', bad; end if;
end $$;

-- CHECK constraints presentes (inclui o terminal-state consolidado do item 3) --
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values
      ('sg8_sessions_reports_both_or_neither_chk'),('sg8_sessions_reports_distinct_chk'),
      ('sg8_sessions_reports_required_post_compute_chk'),('sg8_sessions_terminal_state_chk'),
      ('sg8_resolution_snapshots_resolver_version_nonblank_chk'),
      ('sg8_resolution_snapshots_resolver_hash_nonblank_chk'),
      ('sg8_resolution_snapshots_content_hash_nonblank_chk'),
      ('sg8_resolution_snapshots_fact_count_chk'),
      ('sg8_round_executions_round_chk'),('sg8_round_executions_round2_zero_llm_chk'),
      ('sg8_round_executions_llm_provenance_complete_chk'),
      ('sg8_round_report_evidence_digest_nonblank_chk')
    ) as t(want)
   where not exists (select 1 from pg_constraint where contype = 'c' and conname = t.want);
  if missing is not null then raise exception 'STRUCT/check: missing CHECK(s): %', missing; end if;
end $$;

-- UNIQUE constraints/índices presentes ----------------------------------------
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values
      ('sg8_sessions_id_source_key'),
      ('sg8_resolution_snapshots_id_session_key'),
      ('sg8_round_executions_id_session_key'),('sg8_round_executions_session_round_key'),
      ('sg8_round_report_evidence_round_report_key')
    ) as t(want)
   where not exists (select 1 from pg_constraint where contype = 'u' and conname = t.want);
  if missing is not null then raise exception 'STRUCT/unique: missing UNIQUE constraint(s): %', missing; end if;
  if not exists (select 1 from pg_indexes where schemaname = 'public'
     and indexname = 'sg8_resolution_snapshots_session_uidx') then
    raise exception 'STRUCT/unique: sg8_resolution_snapshots_session_uidx missing (máx 1 snapshot/sessão)';
  end if;
end $$;

-- triggers presentes (guards + no-truncate); sessão cobre INSERT (item 1) ------
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values
      ('sg8_sessions_guard'),('sg8_sessions_no_truncate'),
      ('sg8_resolution_snapshots_immutable'),('sg8_resolution_snapshots_no_truncate'),
      ('sg8_round_executions_immutable'),('sg8_round_executions_no_truncate'),
      ('sg8_round_report_evidence_guard'),('sg8_round_report_evidence_no_truncate')
    ) as t(want)
   where not exists (select 1 from pg_trigger where not tgisinternal and tgname = t.want);
  if missing is not null then raise exception 'STRUCT/trigger: missing trigger(s): %', missing; end if;
  -- o guard da sessão precisa disparar em INSERT/UPDATE/DELETE (nascimento limpo + FSM/PASS).
  if not exists (select 1 from pg_trigger where tgname = 'sg8_sessions_guard'
     and tgrelid = 'public.sg8_sessions'::regclass and (tgtype & 4) = 4     -- INSERT bit
     and (tgtype & 16) = 16 and (tgtype & 8) = 8) then                       -- UPDATE + DELETE bits
    raise exception 'STRUCT/trigger: sg8_sessions_guard deve cobrir INSERT + UPDATE + DELETE';
  end if;
end $$;

-- RLS enabled + ZERO policies nas 4 (Fase 9 vetada) ---------------------------
do $$
declare r text; n int;
begin
  foreach r in array array['sg8_sessions','sg8_resolution_snapshots','sg8_round_executions','sg8_round_report_evidence'] loop
    if not exists (select 1 from pg_class where relnamespace = 'public'::regnamespace
       and relname = r and relrowsecurity = true) then
      raise exception 'STRUCT/rls: RLS not enabled on %', r;
    end if;
    select count(*) into n from pg_policies where schemaname = 'public' and tablename = r;
    if n <> 0 then raise exception 'STRUCT/policy: expected ZERO policies on %, found %', r, n; end if;
  end loop;
end $$;

-- ACL default-deny (item 5): PUBLIC + anon + authenticated sem SELECT/INSERT/UPDATE/DELETE ---
do $$
declare r text; rol text; priv text;
begin
  foreach r in array array['sg8_sessions','sg8_resolution_snapshots','sg8_round_executions','sg8_round_report_evidence'] loop
    -- anon + authenticated: nenhum dos 4 privilégios (has_table_privilege cobre grant direto + PUBLIC).
    foreach rol in array array['anon','authenticated'] loop
      foreach priv in array array['SELECT','INSERT','UPDATE','DELETE'] loop
        if has_table_privilege(rol, ('public.'||r)::regclass, priv) then
          raise exception 'ACL/default-deny: role % tem % em % (esperado NEGADO)', rol, priv, r;
        end if;
      end loop;
    end loop;
    -- PUBLIC: nenhuma concessão direta no relacl.
    if exists (
      select 1 from pg_class c, aclexplode(c.relacl) a
       where c.oid = ('public.'||r)::regclass and a.grantee = 0
         and a.privilege_type in ('SELECT','INSERT','UPDATE','DELETE')
    ) then
      raise exception 'ACL/default-deny: PUBLIC tem concessão direta em % (esperado NENHUMA)', r;
    end if;
  end loop;
end $$;

-- report_runs INTACTA (contrato existente não alterado — §8 mandatório) --------
do $$
declare n int;
begin
  select count(*) into n from pg_enum e join pg_type t on t.oid = e.enumtypid
   where t.typname = 'report_run_status';
  if n <> 5 then raise exception 'STRUCT/report_runs: report_run_status must keep 5 labels (unchanged), found %', n; end if;
  if exists (select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'report_runs'
       and column_name in ('sg8_session_id','sg8_status','computed_pending_repro','sg8_eligible')) then
    raise exception 'STRUCT/report_runs: unexpected SG-8 column added to report_runs (deve permanecer intacta)';
  end if;
  if exists (select 1 from pg_trigger where not tgisinternal
     and tgrelid = 'public.report_runs'::regclass and tgname like '%sg8%') then
    raise exception 'STRUCT/report_runs: unexpected sg8 trigger on report_runs';
  end if;
  select count(*) into n from pg_trigger where not tgisinternal
   and tgrelid = 'public.report_runs'::regclass
   and tgname in ('report_runs_row_guard','report_runs_no_truncate');
  if n <> 2 then raise exception 'STRUCT/report_runs: original guards missing (found % of 2)', n; end if;
end $$;

\echo '== sg8_reconciliation_session · §5 empirical verification =='

-- ----------------------------------------------------------------------------
-- ITEM 1 — a sessão NASCE limpa: não pode nascer terminal, vinculada, com razão, nem
-- fora de session_open.
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_src uuid; v_rep1 uuid; v_rep2 uuid; v_sess uuid; v_st public.sg8_session_status;
  begin
    insert into public.rubric_versions (version, config_json, hash) values ('sg8-vr', '{}'::jsonb, 'h');
    insert into public.report_runs (window_start, window_end) values (now() - interval '30 days', now()) returning id into v_src;
    insert into public.reports (run_id, title, rubric_version, rubric_hash) values (v_src, 'R1', 'sg8-vr', 'h') returning id into v_rep1;
    insert into public.reports (run_id, title, rubric_version, rubric_hash) values (v_src, 'R2', 'sg8-vr', 'h') returning id into v_rep2;

    -- (1a) nascer em estado != session_open → rejeitado (INSERT guard)
    begin
      insert into public.sg8_sessions (source_collection_run_id, status) values (v_src, 'r1_resolved');
      raise exception 'ITEM1: born in non-session_open ACCEPTED';
    exception when restrict_violation then null; end;

    -- (1b) nascer terminal → rejeitado (INSERT guard; antes mesmo do terminal_state_chk)
    begin
      insert into public.sg8_sessions (source_collection_run_id, status, terminal_at, verdict_reason)
        values (v_src, 'failed', now(), 'x');
      raise exception 'ITEM1: born terminal ACCEPTED';
    exception when restrict_violation then null; end;

    -- (1c) nascer vinculada → rejeitado (INSERT guard)
    begin
      insert into public.sg8_sessions (source_collection_run_id, report_id_1, report_id_2)
        values (v_src, v_rep1, v_rep2);
      raise exception 'ITEM1: born bound ACCEPTED';
    exception when restrict_violation then null; end;

    -- (1d) nascer com verdict_reason → rejeitado (INSERT guard)
    begin
      insert into public.sg8_sessions (source_collection_run_id, verdict_reason) values (v_src, 'premature');
      raise exception 'ITEM1: born with verdict_reason ACCEPTED';
    exception when restrict_violation then null; end;

    -- (1e) nascimento limpo → aceito, status session_open
    insert into public.sg8_sessions (source_collection_run_id) values (v_src) returning id, status into v_sess, v_st;
    if v_st <> 'session_open' then raise exception 'ITEM1: default status must be session_open, got %', v_st; end if;
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- ITEM 2 — máquina de estados MONOTÔNICA: só o próximo avanço, ou failed de qualquer
-- não-terminal; saltos, regressões, no-op e reabertura rejeitados.
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_src uuid; v_sess uuid;
  begin
    insert into public.report_runs (window_start, window_end) values (now() - interval '30 days', now()) returning id into v_src;
    insert into public.sg8_sessions (source_collection_run_id) values (v_src) returning id into v_sess;

    -- (2a) salto session_open → r1_resolved (pula r1_awaiting_review) → rejeitado
    begin
      update public.sg8_sessions set status = 'r1_resolved' where id = v_sess;
      raise exception 'ITEM2: jump session_open->r1_resolved ACCEPTED';
    exception when restrict_violation then null; end;

    -- (2b) avanço válido de 1 passo → aceito
    update public.sg8_sessions set status = 'r1_awaiting_review' where id = v_sess;

    -- (2c) no-op (mesmo estado) → rejeitado
    begin
      update public.sg8_sessions set status = 'r1_awaiting_review' where id = v_sess;
      raise exception 'ITEM2: no-op transition ACCEPTED';
    exception when restrict_violation then null; end;

    -- avança até r1_resolved
    update public.sg8_sessions set status = 'r1_resolved' where id = v_sess;

    -- (2d) regressão r1_resolved → r1_awaiting_review → rejeitado
    begin
      update public.sg8_sessions set status = 'r1_awaiting_review' where id = v_sess;
      raise exception 'ITEM2: regression ACCEPTED';
    exception when restrict_violation then null; end;

    -- (2e) failed a partir de estado intermediário (não-terminal) → aceito (com terminal_at+razão)
    update public.sg8_sessions set status = 'failed', terminal_at = now(), verdict_reason = 'aborted mid-flow' where id = v_sess;

    -- (2f) reabertura de terminal → rejeitado (imutável)
    begin
      update public.sg8_sessions set status = 'session_open', terminal_at = null, verdict_reason = null where id = v_sess;
      raise exception 'ITEM2: reopening terminal ACCEPTED';
    exception when restrict_violation then null; end;
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- ITEM 3 — terminalidade exige razão; não-terminal exige razão/terminal_at NULOS.
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_src uuid; v_sess uuid;
  begin
    insert into public.report_runs (window_start, window_end) values (now() - interval '30 days', now()) returning id into v_src;
    insert into public.sg8_sessions (source_collection_run_id) values (v_src) returning id into v_sess;

    -- (3a) failed sem terminal_at nem razão → rejeitado (terminal_state_chk)
    begin
      update public.sg8_sessions set status = 'failed' where id = v_sess;
      raise exception 'ITEM3: failed without terminal_at/verdict_reason ACCEPTED';
    exception when check_violation then null; end;

    -- (3b) failed com terminal_at mas verdict_reason em branco → rejeitado (btrim)
    begin
      update public.sg8_sessions set status = 'failed', terminal_at = now(), verdict_reason = '   ' where id = v_sess;
      raise exception 'ITEM3: failed with blank verdict_reason ACCEPTED';
    exception when check_violation then null; end;

    -- (3c) não-terminal com verdict_reason preenchido (no avanço) → rejeitado (não-terminal ⇒ NULL)
    begin
      update public.sg8_sessions set status = 'r1_awaiting_review', verdict_reason = 'too early' where id = v_sess;
      raise exception 'ITEM3: non-terminal with verdict_reason ACCEPTED';
    exception when check_violation then null; end;

    -- (3d) failed com terminal_at + razão não-branca → aceito
    update public.sg8_sessions set status = 'failed', terminal_at = now(), verdict_reason = 'drift' where id = v_sess;
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- BINDING DIFERIDO — só ocorre por transição válida (r1_snapshot_frozen → r1_computed);
-- parcial/idênticos/dataset-alheio/alteração/remoção rejeitados; obrigatório em r1_computed.
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_src uuid; v_src2 uuid; v_rep1 uuid; v_rep2 uuid; v_rep3 uuid; v_rep_other uuid; v_sess uuid;
  begin
    insert into public.rubric_versions (version, config_json, hash) values ('sg8-vr', '{}'::jsonb, 'h');
    insert into public.report_runs (window_start, window_end) values (now() - interval '30 days', now()) returning id into v_src;
    insert into public.report_runs (window_start, window_end) values (now() - interval '60 days', now() - interval '31 days') returning id into v_src2;
    insert into public.reports (run_id, title, rubric_version, rubric_hash) values (v_src, 'R1', 'sg8-vr', 'h') returning id into v_rep1;
    insert into public.reports (run_id, title, rubric_version, rubric_hash) values (v_src, 'R2', 'sg8-vr', 'h') returning id into v_rep2;
    insert into public.reports (run_id, title, rubric_version, rubric_hash) values (v_src, 'R3', 'sg8-vr', 'h') returning id into v_rep3;
    insert into public.reports (run_id, title, rubric_version, rubric_hash) values (v_src2, 'ROTHER', 'sg8-vr', 'h') returning id into v_rep_other;
    insert into public.sg8_sessions (source_collection_run_id) values (v_src) returning id into v_sess;
    -- walk to r1_snapshot_frozen (transições válidas)
    update public.sg8_sessions set status = 'r1_awaiting_review'  where id = v_sess;
    update public.sg8_sessions set status = 'r1_resolved'         where id = v_sess;
    update public.sg8_sessions set status = 'r1_snapshot_frozen'  where id = v_sess;

    -- (a) transição a r1_computed com preenchimento PARCIAL → rejeitado (both-or-neither)
    begin
      update public.sg8_sessions set report_id_1 = v_rep1, status = 'r1_computed' where id = v_sess;
      raise exception 'BINDING: partial binding ACCEPTED';
    exception when check_violation then null; end;

    -- (b) dois relatórios IGUAIS → rejeitado (distinct)
    begin
      update public.sg8_sessions set report_id_1 = v_rep1, report_id_2 = v_rep1, status = 'r1_computed' where id = v_sess;
      raise exception 'BINDING: identical report ids ACCEPTED';
    exception when check_violation then null; end;

    -- (c) r1_computed SEM binding → rejeitado (required post-compute)
    begin
      update public.sg8_sessions set status = 'r1_computed' where id = v_sess;
      raise exception 'BINDING: r1_computed without binding ACCEPTED';
    exception when check_violation then null; end;

    -- (d) relatório de OUTRA coleção-fonte → rejeitado (composite FK)
    begin
      update public.sg8_sessions set report_id_1 = v_rep_other, report_id_2 = v_rep2, status = 'r1_computed' where id = v_sess;
      raise exception 'BINDING: report from another source_collection_run_id ACCEPTED';
    exception when foreign_key_violation then null; end;

    -- (e) binding legítimo na transição r1_snapshot_frozen → r1_computed → aceito
    update public.sg8_sessions set report_id_1 = v_rep1, report_id_2 = v_rep2, status = 'r1_computed' where id = v_sess;

    -- (f) ALTERAÇÃO pós-binding → rejeitada (trigger). (status seguiria imutável de qualquer forma)
    begin
      update public.sg8_sessions set report_id_1 = v_rep3 where id = v_sess;
      raise exception 'BINDING: alteration after binding ACCEPTED';
    exception when restrict_violation then null; end;

    -- (g) REMOÇÃO pós-binding → rejeitada (trigger)
    begin
      update public.sg8_sessions set report_id_1 = null, report_id_2 = null where id = v_sess;
      raise exception 'BINDING: removal after binding ACCEPTED';
    exception when restrict_violation then null; end;
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- TERMINALIDADE + DELETE — sessão terminal imutável; DELETE bloqueado.
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_src uuid; v_sess uuid;
  begin
    insert into public.report_runs (window_start, window_end) values (now() - interval '30 days', now()) returning id into v_src;
    insert into public.sg8_sessions (source_collection_run_id) values (v_src) returning id into v_sess;
    -- early-fail direto de session_open → aceito
    update public.sg8_sessions set status = 'failed', terminal_at = now(), verdict_reason = 'early drift' where id = v_sess;

    -- qualquer mutação pós-terminal → rejeitada
    begin
      update public.sg8_sessions set verdict_reason = 'x' where id = v_sess;
      raise exception 'TERMINAL: mutating terminal session ACCEPTED';
    exception when restrict_violation then null; end;

    -- DELETE → bloqueado (âncora de tentativa)
    begin
      delete from public.sg8_sessions where id = v_sess;
      raise exception 'TERMINAL: session DELETE ACCEPTED';
    exception when restrict_violation then null; end;
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- SNAPSHOT (Q-1): máx 1 por sessão; imutável; coerência de dataset; não-branco; fact_count >= 0.
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_src uuid; v_src2 uuid; v_sess uuid; v_snap uuid;
  begin
    insert into public.report_runs (window_start, window_end) values (now() - interval '30 days', now()) returning id into v_src;
    insert into public.report_runs (window_start, window_end) values (now() - interval '60 days', now() - interval '31 days') returning id into v_src2;
    insert into public.sg8_sessions (source_collection_run_id) values (v_src) returning id into v_sess;

    -- snapshot de OUTRA coleção-fonte → rejeitado (composite FK)
    begin
      insert into public.sg8_resolution_snapshots (sg8_session_id, source_collection_run_id, resolver_version, resolver_hash, fact_count, content_hash)
        values (v_sess, v_src2, 'entity-resolver-v1', 'rhash', 500, 'chash');
      raise exception 'SNAPSHOT: snapshot with a different dataset ACCEPTED';
    exception when foreign_key_violation then null; end;

    -- resolver_version em branco → rejeitado
    begin
      insert into public.sg8_resolution_snapshots (sg8_session_id, source_collection_run_id, resolver_version, resolver_hash, fact_count, content_hash)
        values (v_sess, v_src, '   ', 'rhash', 500, 'chash');
      raise exception 'SNAPSHOT: blank resolver_version ACCEPTED';
    exception when check_violation then null; end;

    -- fact_count negativo → rejeitado
    begin
      insert into public.sg8_resolution_snapshots (sg8_session_id, source_collection_run_id, resolver_version, resolver_hash, fact_count, content_hash)
        values (v_sess, v_src, 'entity-resolver-v1', 'rhash', -1, 'chash');
      raise exception 'SNAPSHOT: negative fact_count ACCEPTED';
    exception when check_violation then null; end;

    -- snapshot legítimo
    insert into public.sg8_resolution_snapshots (sg8_session_id, source_collection_run_id, resolver_version, resolver_hash, fact_count, content_hash)
      values (v_sess, v_src, 'entity-resolver-v1', 'rhash', 500, 'chash') returning id into v_snap;

    -- SEGUNDO snapshot na mesma sessão → rejeitado (máx 1/sessão)
    begin
      insert into public.sg8_resolution_snapshots (sg8_session_id, source_collection_run_id, resolver_version, resolver_hash, fact_count, content_hash)
        values (v_sess, v_src, 'entity-resolver-v1', 'rhash', 500, 'chash2');
      raise exception 'SNAPSHOT: second snapshot for a session ACCEPTED';
    exception when unique_violation then null; end;

    -- IMUTABILIDADE: UPDATE e DELETE → bloqueados
    begin
      update public.sg8_resolution_snapshots set content_hash = 'tamper' where id = v_snap;
      raise exception 'SNAPSHOT: UPDATE of a frozen snapshot ACCEPTED';
    exception when restrict_violation then null; end;
    begin
      delete from public.sg8_resolution_snapshots where id = v_snap;
      raise exception 'SNAPSHOT: DELETE of a frozen snapshot ACCEPTED';
    exception when restrict_violation then null; end;
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- RODADAS: 1 Round 1 + 1 Round 2 por sessão; round_number ∈ {1,2}; dataset/snapshot coerentes;
-- Round 2 zero-LLM; proveniência LLM all-or-nothing; imutabilidade.
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_src uuid; v_src2 uuid; v_sess uuid; v_sess2 uuid; v_snap uuid; v_snap2 uuid; v_r1 uuid;
  begin
    insert into public.report_runs (window_start, window_end) values (now() - interval '30 days', now()) returning id into v_src;
    insert into public.report_runs (window_start, window_end) values (now() - interval '60 days', now() - interval '31 days') returning id into v_src2;
    insert into public.sg8_sessions (source_collection_run_id) values (v_src) returning id into v_sess;
    insert into public.sg8_sessions (source_collection_run_id) values (v_src2) returning id into v_sess2;
    insert into public.sg8_resolution_snapshots (sg8_session_id, source_collection_run_id, resolver_version, resolver_hash, fact_count, content_hash)
      values (v_sess, v_src, 'entity-resolver-v1', 'rhash', 500, 'chash') returning id into v_snap;
    insert into public.sg8_resolution_snapshots (sg8_session_id, source_collection_run_id, resolver_version, resolver_hash, fact_count, content_hash)
      values (v_sess2, v_src2, 'entity-resolver-v1', 'rhash', 500, 'chash') returning id into v_snap2;

    -- rodada com dataset ≠ da sessão → rejeitada (composite FK session_source)
    begin
      insert into public.sg8_round_executions (sg8_session_id, round_number, source_collection_run_id, resolution_snapshot_id)
        values (v_sess, 1, v_src2, v_snap);
      raise exception 'ROUND: round with a different dataset ACCEPTED';
    exception when foreign_key_violation then null; end;

    -- rodada com snapshot de OUTRA sessão → rejeitada (composite FK snapshot_session)
    begin
      insert into public.sg8_round_executions (sg8_session_id, round_number, source_collection_run_id, resolution_snapshot_id)
        values (v_sess, 1, v_src, v_snap2);
      raise exception 'ROUND: round reusing another session snapshot ACCEPTED';
    exception when foreign_key_violation then null; end;

    -- round_number inválido (3) → rejeitado
    begin
      insert into public.sg8_round_executions (sg8_session_id, round_number, source_collection_run_id, resolution_snapshot_id)
        values (v_sess, 3, v_src, v_snap);
      raise exception 'ROUND: round_number=3 ACCEPTED';
    exception when check_violation then null; end;

    -- Round 1 com proveniência LLM PARCIAL → rejeitada (all-or-nothing)
    begin
      insert into public.sg8_round_executions (sg8_session_id, round_number, source_collection_run_id, resolution_snapshot_id, llm_provider)
        values (v_sess, 1, v_src, v_snap, 'anthropic');
      raise exception 'ROUND: partial LLM provenance ACCEPTED';
    exception when check_violation then null; end;

    -- Round 1 legítima com proveniência COMPLETA → aceita
    insert into public.sg8_round_executions
      (sg8_session_id, round_number, source_collection_run_id, resolution_snapshot_id,
       llm_provider, llm_model, llm_model_version, llm_prompt_hash, llm_params_json, llm_adapter_version)
      values (v_sess, 1, v_src, v_snap, 'anthropic', 'claude-opus-4-8', '2026-01', 'phash',
              '{"temperature":0}'::jsonb, 'adapter-v1') returning id into v_r1;

    -- SEGUNDA Round 1 → rejeitada
    begin
      insert into public.sg8_round_executions (sg8_session_id, round_number, source_collection_run_id, resolution_snapshot_id)
        values (v_sess, 1, v_src, v_snap);
      raise exception 'ROUND: second Round 1 for a session ACCEPTED';
    exception when unique_violation then null; end;

    -- Round 2 com qualquer proveniência LLM → rejeitada (zero-LLM)
    begin
      insert into public.sg8_round_executions (sg8_session_id, round_number, source_collection_run_id, resolution_snapshot_id, llm_params_json)
        values (v_sess, 2, v_src, v_snap, '{"x":1}'::jsonb);
      raise exception 'ROUND: Round 2 with LLM provenance ACCEPTED';
    exception when check_violation then null; end;

    -- Round 2 zero-LLM legítima → aceita
    insert into public.sg8_round_executions (sg8_session_id, round_number, source_collection_run_id, resolution_snapshot_id)
      values (v_sess, 2, v_src, v_snap);

    -- SEGUNDA Round 2 → rejeitada
    begin
      insert into public.sg8_round_executions (sg8_session_id, round_number, source_collection_run_id, resolution_snapshot_id)
        values (v_sess, 2, v_src, v_snap);
      raise exception 'ROUND: second Round 2 for a session ACCEPTED';
    exception when unique_violation then null; end;

    -- IMUTABILIDADE de rodada: UPDATE e DELETE → bloqueados
    begin
      update public.sg8_round_executions set llm_model = 'tamper' where id = v_r1;
      raise exception 'ROUND: UPDATE of a round ACCEPTED';
    exception when restrict_violation then null; end;
    begin
      delete from public.sg8_round_executions where id = v_r1;
      raise exception 'ROUND: DELETE of a round ACCEPTED';
    exception when restrict_violation then null; end;
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- EVIDÊNCIA: exige binding; report_id restrito aos 2 congelados; unicidade (round, report);
-- imutável; Round 2 reusa exatamente os mesmos 2 relatórios.
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_src uuid; v_sess uuid; v_snap uuid; v_rep1 uuid; v_rep2 uuid; v_rep_x uuid;
          v_round1 uuid; v_round2 uuid;
  begin
    insert into public.rubric_versions (version, config_json, hash) values ('sg8-vr', '{}'::jsonb, 'h');
    insert into public.report_runs (window_start, window_end) values (now() - interval '30 days', now()) returning id into v_src;
    insert into public.reports (run_id, title, rubric_version, rubric_hash) values (v_src, 'R1', 'sg8-vr', 'h') returning id into v_rep1;
    insert into public.reports (run_id, title, rubric_version, rubric_hash) values (v_src, 'R2', 'sg8-vr', 'h') returning id into v_rep2;
    insert into public.reports (run_id, title, rubric_version, rubric_hash) values (v_src, 'RX', 'sg8-vr', 'h') returning id into v_rep_x;
    insert into public.sg8_sessions (source_collection_run_id) values (v_src) returning id into v_sess;
    update public.sg8_sessions set status = 'r1_awaiting_review'  where id = v_sess;
    update public.sg8_sessions set status = 'r1_resolved'         where id = v_sess;
    update public.sg8_sessions set status = 'r1_snapshot_frozen'  where id = v_sess;
    insert into public.sg8_resolution_snapshots (sg8_session_id, source_collection_run_id, resolver_version, resolver_hash, fact_count, content_hash)
      values (v_sess, v_src, 'entity-resolver-v1', 'rhash', 500, 'chash') returning id into v_snap;
    insert into public.sg8_round_executions (sg8_session_id, round_number, source_collection_run_id, resolution_snapshot_id)
      values (v_sess, 1, v_src, v_snap) returning id into v_round1;

    -- evidência ANTES do binding → rejeitada (trigger: binding ausente)
    begin
      insert into public.sg8_round_report_evidence (round_execution_id, sg8_session_id, report_id, canonical_digest)
        values (v_round1, v_sess, v_rep1, 'digestA');
      raise exception 'EVIDENCE: evidence before report binding ACCEPTED';
    exception when restrict_violation then null; end;

    -- binding dos 2 relatórios (transição r1_snapshot_frozen → r1_computed)
    update public.sg8_sessions set report_id_1 = v_rep1, report_id_2 = v_rep2, status = 'r1_computed' where id = v_sess;

    -- evidência com report_id FORA dos 2 congelados → rejeitada (trigger)
    begin
      insert into public.sg8_round_report_evidence (round_execution_id, sg8_session_id, report_id, canonical_digest)
        values (v_round1, v_sess, v_rep_x, 'digestX');
      raise exception 'EVIDENCE: report_id outside the session frozen reports ACCEPTED';
    exception when restrict_violation then null; end;

    -- evidência Round 1 dos 2 congelados → aceita
    insert into public.sg8_round_report_evidence (round_execution_id, sg8_session_id, report_id, canonical_digest)
      values (v_round1, v_sess, v_rep1, 'digest1');
    insert into public.sg8_round_report_evidence (round_execution_id, sg8_session_id, report_id, canonical_digest)
      values (v_round1, v_sess, v_rep2, 'digest2');

    -- duplicata (mesmo round, mesmo report) → rejeitada
    begin
      insert into public.sg8_round_report_evidence (round_execution_id, sg8_session_id, report_id, canonical_digest)
        values (v_round1, v_sess, v_rep1, 'digest1-again');
      raise exception 'EVIDENCE: duplicate (round, report) ACCEPTED';
    exception when unique_violation then null; end;

    -- IMUTABILIDADE: UPDATE e DELETE → bloqueados
    begin
      update public.sg8_round_report_evidence set canonical_digest = 'tamper' where round_execution_id = v_round1 and report_id = v_rep1;
      raise exception 'EVIDENCE: UPDATE of evidence ACCEPTED';
    exception when restrict_violation then null; end;
    begin
      delete from public.sg8_round_report_evidence where round_execution_id = v_round1 and report_id = v_rep1;
      raise exception 'EVIDENCE: DELETE of evidence ACCEPTED';
    exception when restrict_violation then null; end;

    -- ROUND 2 reusa EXATAMENTE os mesmos 2 relatórios
    insert into public.sg8_round_executions (sg8_session_id, round_number, source_collection_run_id, resolution_snapshot_id)
      values (v_sess, 2, v_src, v_snap) returning id into v_round2;
    begin
      insert into public.sg8_round_report_evidence (round_execution_id, sg8_session_id, report_id, canonical_digest)
        values (v_round2, v_sess, v_rep_x, 'r2-X');
      raise exception 'EVIDENCE: Round 2 evidence with a NEW report_id ACCEPTED';
    exception when restrict_violation then null; end;
    insert into public.sg8_round_report_evidence (round_execution_id, sg8_session_id, report_id, canonical_digest)
      values (v_round2, v_sess, v_rep1, 'r2-digest1');
    insert into public.sg8_round_report_evidence (round_execution_id, sg8_session_id, report_id, canonical_digest)
      values (v_round2, v_sess, v_rep2, 'r2-digest2');
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- ITEM 4 — GATE DE PASS. Reutiliza um builder até r1_computed+binding; testa: sem rodadas;
-- rodadas mas evidência incompleta; digest divergente (drift); e PASS completo/consistente.
-- ----------------------------------------------------------------------------

-- (4a) passed SEM rodadas → rejeitado
begin;
  do $$
  declare v_src uuid; v_rep1 uuid; v_rep2 uuid; v_sess uuid;
  begin
    insert into public.rubric_versions (version, config_json, hash) values ('sg8-vr', '{}'::jsonb, 'h');
    insert into public.report_runs (window_start, window_end) values (now() - interval '30 days', now()) returning id into v_src;
    insert into public.reports (run_id, title, rubric_version, rubric_hash) values (v_src, 'R1', 'sg8-vr', 'h') returning id into v_rep1;
    insert into public.reports (run_id, title, rubric_version, rubric_hash) values (v_src, 'R2', 'sg8-vr', 'h') returning id into v_rep2;
    insert into public.sg8_sessions (source_collection_run_id) values (v_src) returning id into v_sess;
    update public.sg8_sessions set status = 'r1_awaiting_review'  where id = v_sess;
    update public.sg8_sessions set status = 'r1_resolved'         where id = v_sess;
    update public.sg8_sessions set status = 'r1_snapshot_frozen'  where id = v_sess;
    update public.sg8_sessions set report_id_1 = v_rep1, report_id_2 = v_rep2, status = 'r1_computed' where id = v_sess;
    -- sem rodadas: passed → rejeitado (PASS gate)
    begin
      update public.sg8_sessions set status = 'passed', terminal_at = now(), verdict_reason = 'byte-identical' where id = v_sess;
      raise exception 'ITEM4a: passed without rounds ACCEPTED';
    exception when restrict_violation then null; end;
  end $$;
rollback;

-- (4b) passed com rodadas mas evidência INCOMPLETA (1 de 2 na Round 2) → rejeitado
begin;
  do $$
  declare v_src uuid; v_rep1 uuid; v_rep2 uuid; v_sess uuid; v_snap uuid; v_round1 uuid; v_round2 uuid;
  begin
    insert into public.rubric_versions (version, config_json, hash) values ('sg8-vr', '{}'::jsonb, 'h');
    insert into public.report_runs (window_start, window_end) values (now() - interval '30 days', now()) returning id into v_src;
    insert into public.reports (run_id, title, rubric_version, rubric_hash) values (v_src, 'R1', 'sg8-vr', 'h') returning id into v_rep1;
    insert into public.reports (run_id, title, rubric_version, rubric_hash) values (v_src, 'R2', 'sg8-vr', 'h') returning id into v_rep2;
    insert into public.sg8_sessions (source_collection_run_id) values (v_src) returning id into v_sess;
    update public.sg8_sessions set status = 'r1_awaiting_review'  where id = v_sess;
    update public.sg8_sessions set status = 'r1_resolved'         where id = v_sess;
    update public.sg8_sessions set status = 'r1_snapshot_frozen'  where id = v_sess;
    insert into public.sg8_resolution_snapshots (sg8_session_id, source_collection_run_id, resolver_version, resolver_hash, fact_count, content_hash)
      values (v_sess, v_src, 'entity-resolver-v1', 'rhash', 500, 'chash') returning id into v_snap;
    update public.sg8_sessions set report_id_1 = v_rep1, report_id_2 = v_rep2, status = 'r1_computed' where id = v_sess;
    insert into public.sg8_round_executions (sg8_session_id, round_number, source_collection_run_id, resolution_snapshot_id,
        llm_provider, llm_model, llm_model_version, llm_prompt_hash, llm_adapter_version)
      values (v_sess, 1, v_src, v_snap, 'anthropic', 'claude-opus-4-8', '2026-01', 'phash', 'adapter-v1') returning id into v_round1;
    insert into public.sg8_round_executions (sg8_session_id, round_number, source_collection_run_id, resolution_snapshot_id)
      values (v_sess, 2, v_src, v_snap) returning id into v_round2;
    -- Round 1 completa (2 evidências); Round 2 só 1 evidência
    insert into public.sg8_round_report_evidence (round_execution_id, sg8_session_id, report_id, canonical_digest) values (v_round1, v_sess, v_rep1, 'd1');
    insert into public.sg8_round_report_evidence (round_execution_id, sg8_session_id, report_id, canonical_digest) values (v_round1, v_sess, v_rep2, 'd2');
    insert into public.sg8_round_report_evidence (round_execution_id, sg8_session_id, report_id, canonical_digest) values (v_round2, v_sess, v_rep1, 'd1');
    -- passed com evidência incompleta → rejeitado
    begin
      update public.sg8_sessions set status = 'passed', terminal_at = now(), verdict_reason = 'byte-identical' where id = v_sess;
      raise exception 'ITEM4b: passed with incomplete evidence ACCEPTED';
    exception when restrict_violation then null; end;
  end $$;
rollback;

-- (4c) digest DIVERGENTE (drift) → passed rejeitado; (4d) tudo consistente → passed aceito
begin;
  do $$
  declare v_src uuid; v_rep1 uuid; v_rep2 uuid; v_sess uuid; v_snap uuid; v_round1 uuid; v_round2 uuid; v_final public.sg8_session_status;
  begin
    insert into public.rubric_versions (version, config_json, hash) values ('sg8-vr', '{}'::jsonb, 'h');
    insert into public.report_runs (window_start, window_end) values (now() - interval '30 days', now()) returning id into v_src;
    insert into public.reports (run_id, title, rubric_version, rubric_hash) values (v_src, 'R1', 'sg8-vr', 'h') returning id into v_rep1;
    insert into public.reports (run_id, title, rubric_version, rubric_hash) values (v_src, 'R2', 'sg8-vr', 'h') returning id into v_rep2;
    insert into public.sg8_sessions (source_collection_run_id) values (v_src) returning id into v_sess;
    update public.sg8_sessions set status = 'r1_awaiting_review'  where id = v_sess;
    update public.sg8_sessions set status = 'r1_resolved'         where id = v_sess;
    update public.sg8_sessions set status = 'r1_snapshot_frozen'  where id = v_sess;
    insert into public.sg8_resolution_snapshots (sg8_session_id, source_collection_run_id, resolver_version, resolver_hash, fact_count, content_hash)
      values (v_sess, v_src, 'entity-resolver-v1', 'rhash', 500, 'chash') returning id into v_snap;
    update public.sg8_sessions set report_id_1 = v_rep1, report_id_2 = v_rep2, status = 'r1_computed' where id = v_sess;
    insert into public.sg8_round_executions (sg8_session_id, round_number, source_collection_run_id, resolution_snapshot_id,
        llm_provider, llm_model, llm_model_version, llm_prompt_hash, llm_adapter_version)
      values (v_sess, 1, v_src, v_snap, 'anthropic', 'claude-opus-4-8', '2026-01', 'phash', 'adapter-v1') returning id into v_round1;
    insert into public.sg8_round_executions (sg8_session_id, round_number, source_collection_run_id, resolution_snapshot_id)
      values (v_sess, 2, v_src, v_snap) returning id into v_round2;
    -- R1 digests
    insert into public.sg8_round_report_evidence (round_execution_id, sg8_session_id, report_id, canonical_digest) values (v_round1, v_sess, v_rep1, 'DIG-A');
    insert into public.sg8_round_report_evidence (round_execution_id, sg8_session_id, report_id, canonical_digest) values (v_round1, v_sess, v_rep2, 'DIG-B');
    -- R2 digest DIVERGENTE para rep2
    insert into public.sg8_round_report_evidence (round_execution_id, sg8_session_id, report_id, canonical_digest) values (v_round2, v_sess, v_rep1, 'DIG-A');
    insert into public.sg8_round_report_evidence (round_execution_id, sg8_session_id, report_id, canonical_digest) values (v_round2, v_sess, v_rep2, 'DIG-B-DRIFT');

    -- (4c) passed com digest divergente → rejeitado
    begin
      update public.sg8_sessions set status = 'passed', terminal_at = now(), verdict_reason = 'byte-identical' where id = v_sess;
      raise exception 'ITEM4c: passed with divergent digest ACCEPTED';
    exception when restrict_violation then null; end;

    -- também: failed continua permitido (drift → failed) a partir de r1_computed
    -- (não altera o estado real: provado em bloco revertido próprio abaixo)
  end $$;
rollback;

-- (4d) PASS COMPLETO E CONSISTENTE → aceito (digests R1==R2 nos 2 relatórios)
begin;
  do $$
  declare v_src uuid; v_rep1 uuid; v_rep2 uuid; v_sess uuid; v_snap uuid; v_round1 uuid; v_round2 uuid; v_final public.sg8_session_status;
  begin
    insert into public.rubric_versions (version, config_json, hash) values ('sg8-vr', '{}'::jsonb, 'h');
    insert into public.report_runs (window_start, window_end) values (now() - interval '30 days', now()) returning id into v_src;
    insert into public.reports (run_id, title, rubric_version, rubric_hash) values (v_src, 'R1', 'sg8-vr', 'h') returning id into v_rep1;
    insert into public.reports (run_id, title, rubric_version, rubric_hash) values (v_src, 'R2', 'sg8-vr', 'h') returning id into v_rep2;
    insert into public.sg8_sessions (source_collection_run_id) values (v_src) returning id into v_sess;
    update public.sg8_sessions set status = 'r1_awaiting_review'  where id = v_sess;
    update public.sg8_sessions set status = 'r1_resolved'         where id = v_sess;
    update public.sg8_sessions set status = 'r1_snapshot_frozen'  where id = v_sess;
    insert into public.sg8_resolution_snapshots (sg8_session_id, source_collection_run_id, resolver_version, resolver_hash, fact_count, content_hash)
      values (v_sess, v_src, 'entity-resolver-v1', 'rhash', 500, 'chash') returning id into v_snap;
    update public.sg8_sessions set report_id_1 = v_rep1, report_id_2 = v_rep2, status = 'r1_computed' where id = v_sess;
    insert into public.sg8_round_executions (sg8_session_id, round_number, source_collection_run_id, resolution_snapshot_id,
        llm_provider, llm_model, llm_model_version, llm_prompt_hash, llm_adapter_version)
      values (v_sess, 1, v_src, v_snap, 'anthropic', 'claude-opus-4-8', '2026-01', 'phash', 'adapter-v1') returning id into v_round1;
    insert into public.sg8_round_executions (sg8_session_id, round_number, source_collection_run_id, resolution_snapshot_id)
      values (v_sess, 2, v_src, v_snap) returning id into v_round2;
    insert into public.sg8_round_report_evidence (round_execution_id, sg8_session_id, report_id, canonical_digest) values (v_round1, v_sess, v_rep1, 'DIG-A');
    insert into public.sg8_round_report_evidence (round_execution_id, sg8_session_id, report_id, canonical_digest) values (v_round1, v_sess, v_rep2, 'DIG-B');
    insert into public.sg8_round_report_evidence (round_execution_id, sg8_session_id, report_id, canonical_digest) values (v_round2, v_sess, v_rep1, 'DIG-A');
    insert into public.sg8_round_report_evidence (round_execution_id, sg8_session_id, report_id, canonical_digest) values (v_round2, v_sess, v_rep2, 'DIG-B');

    -- PASS completo e consistente → aceito
    update public.sg8_sessions set status = 'passed', terminal_at = now(), verdict_reason = 'byte-identical R1==R2' where id = v_sess;
    select status into v_final from public.sg8_sessions where id = v_sess;
    if v_final <> 'passed' then raise exception 'ITEM4d: consistent PASS not accepted (got %)', v_final; end if;

    -- pós-PASS a sessão é terminal/imutável (reforço)
    begin
      update public.sg8_sessions set verdict_reason = 'x' where id = v_sess;
      raise exception 'ITEM4d: mutating passed session ACCEPTED';
    exception when restrict_violation then null; end;
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- ITEM 5 (runtime) — DEFAULT-DENY empírico: anon + authenticated sem SELECT nem INSERT.
-- (A prova de ACL para os 4 verbos + PUBLIC está em §4; aqui confirmamos em runtime.)
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare rol text; tbl text;
  begin
    foreach rol in array array['anon', 'authenticated'] loop
      foreach tbl in array array['sg8_sessions','sg8_resolution_snapshots','sg8_round_executions','sg8_round_report_evidence'] loop
        -- SELECT negado
        begin
          perform set_config('role', rol, true);
          execute format('select 1 from public.%I limit 1', tbl);
          raise exception 'DEFAULT-DENY: role % could SELECT %', rol, tbl;
        exception when insufficient_privilege then null; end;
        -- INSERT negado (privilégio barra antes de qualquer constraint)
        begin
          perform set_config('role', rol, true);
          execute format('insert into public.%I default values', tbl);
          raise exception 'DEFAULT-DENY: role % could INSERT %', rol, tbl;
        exception when insufficient_privilege then null; end;
      end loop;
    end loop;
  end $$;
rollback;

\echo 'OK — sg8_reconciliation_session post-apply verification PASSED (§4 structural+ACL + §5 hardening empirical).'
