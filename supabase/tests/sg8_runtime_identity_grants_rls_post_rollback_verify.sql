-- ============================================================================
-- NOXUND · SG-8 Runtime Identity, Grants & RLS — POST-ROLLBACK verification (U3A-GRANTS)
-- ----------------------------------------------------------------------------
-- Run AFTER the paired rollback of migration
--   supabase/migrations/20260620000009_sg8_runtime_identity_grants_rls.sql
--   (supabase/rollback/20260620000009_sg8_runtime_identity_grants_rls.rollback.sql)
-- has reverted the unit, while migration 0008 (and 0001–0006) remain applied.
--
-- NATURE: PURELY READ-ONLY — catálogo + has_*_privilege. ZERO escrita. Prova TRÊS coisas:
--   §1 AUSÊNCIA — a role sg8_compute_writer sumiu; as 9 policies dedicadas sumiram; as 4 tabelas
--      voltaram a ter ZERO policies; RLS continua HABILITADA (estado 0008); nenhum objeto residual
--      da 0009 (varredura por nome e por role inexistente).
--   §2 BASELINE RESTAURADO — o service_role tem, em CADA tabela SG-8, EXATAMENTE os mesmos verbos
--      que na tabela-irmã intocada public.report_runs (o baseline da 0008, capturado em runtime,
--      não presumido). anon/authenticated/authenticator/PUBLIC continuam NEGADOS (default-deny 0008).
--   §3 CONTRATOS 0008 INTACTOS — 4 tabelas + enum (7) + 3 funções + 8 triggers + CHECKs-chave
--      (FSM/terminalidade, contrato de comparação, manifesto, proveniência) presentes e não tocados.
--
-- CONTRACT: todo mismatch RAISES → `psql -v ON_ERROR_STOP=1` sai não-zero, falha o CI.
-- Scope: este arquivo NÃO modifica migration, rollback, post-apply verify ou workflow.
-- ============================================================================

\set ON_ERROR_STOP on

\echo '== sg8 runtime identity · §1 post-rollback ABSENCE =='

-- §1.a — role ausente
do $$
begin
  if to_regrole('sg8_compute_writer') is not null then
    raise exception 'ROLLBACK/role: sg8_compute_writer ainda presente';
  end if;
end $$;

-- §1.b — as 9 policies dedicadas ausentes E zero policies nas 4 tabelas (volta ao estado 0008)
do $$
declare leftover text; n int; tbl text;
begin
  select string_agg(policyname, ', ') into leftover from pg_policies
   where schemaname='public' and policyname in (
     'sg8_sessions_writer_select','sg8_sessions_writer_insert','sg8_sessions_writer_update',
     'sg8_resolution_snapshots_writer_select','sg8_resolution_snapshots_writer_insert',
     'sg8_round_executions_writer_select','sg8_round_executions_writer_insert',
     'sg8_round_report_evidence_writer_select','sg8_round_report_evidence_writer_insert');
  if leftover is not null then raise exception 'ROLLBACK/policy: policy(s) residual(is) da 0009: %', leftover; end if;

  foreach tbl in array array['sg8_sessions','sg8_resolution_snapshots','sg8_round_executions','sg8_round_report_evidence'] loop
    select count(*) into n from pg_policies where schemaname='public' and tablename=tbl;
    if n <> 0 then raise exception 'ROLLBACK/policy: % deve ter ZERO policies (estado 0008), achou %', tbl, n; end if;
    -- RLS continua habilitada (a 0009 não a alterou; o rollback não a desabilita)
    if not exists (select 1 from pg_class where relnamespace='public'::regnamespace and relname=tbl and relrowsecurity) then
      raise exception 'ROLLBACK/rls: RLS deveria continuar HABILITADA em % (estado 0008)', tbl;
    end if;
  end loop;

  -- varredura genérica: nenhuma policy '%writer%' nas 4 tabelas
  select string_agg(policyname, ', ') into leftover from pg_policies
   where schemaname='public'
     and tablename in ('sg8_sessions','sg8_resolution_snapshots','sg8_round_executions','sg8_round_report_evidence')
     and policyname like '%writer%';
  if leftover is not null then raise exception 'ROLLBACK/sweep: policy(s) writer residual(is): %', leftover; end if;
end $$;

\echo '== sg8 runtime identity · §2 baseline restored (service_role == report_runs) =='

do $$
declare verb text; tbl text; n_base int := 0; base boolean; got boolean;
begin
  foreach verb in array array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER'] loop
    base := has_table_privilege('service_role','public.report_runs', verb);
    if base then n_base := n_base + 1; end if;
    foreach tbl in array array['sg8_sessions','sg8_resolution_snapshots','sg8_round_executions','sg8_round_report_evidence'] loop
      got := has_table_privilege('service_role', ('public.'||tbl)::regclass, verb);
      if got <> base then
        raise exception 'ROLLBACK/baseline: service_role % em % = % != baseline (report_runs) = %', verb, tbl, got, base;
      end if;
    end loop;
  end loop;
  if n_base = 0 then
    raise exception 'ROLLBACK/baseline: baseline de report_runs para service_role está VAZIO — captura suspeita, escalar';
  end if;

  -- anon/authenticated/authenticator/PUBLIC continuam NEGADOS (default-deny 0008 preservado)
  foreach tbl in array array['sg8_sessions','sg8_resolution_snapshots','sg8_round_executions','sg8_round_report_evidence'] loop
    foreach verb in array array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER'] loop
      if to_regrole('anon') is not null and has_table_privilege('anon', ('public.'||tbl)::regclass, verb) then
        raise exception 'ROLLBACK/deny: anon recuperou % em %', verb, tbl; end if;
      if to_regrole('authenticated') is not null and has_table_privilege('authenticated', ('public.'||tbl)::regclass, verb) then
        raise exception 'ROLLBACK/deny: authenticated recuperou % em %', verb, tbl; end if;
      if to_regrole('authenticator') is not null and has_table_privilege('authenticator', ('public.'||tbl)::regclass, verb) then
        raise exception 'ROLLBACK/deny: authenticator recuperou % em %', verb, tbl; end if;
    end loop;
    if exists (select 1 from pg_class c, aclexplode(c.relacl) a
       where c.oid=('public.'||tbl)::regclass and a.grantee=0) then
      raise exception 'ROLLBACK/deny: PUBLIC tem concessão direta em %', tbl; end if;
  end loop;
end $$;

\echo '== sg8 runtime identity · §3 0008 contracts intact =='

do $$
declare n int; missing text;
begin
  foreach missing in array array['sg8_sessions','sg8_resolution_snapshots','sg8_round_executions','sg8_round_report_evidence'] loop
    if not exists (select 1 from pg_class where relnamespace='public'::regnamespace and relname=missing) then
      raise exception 'ROLLBACK/0008: tabela % ausente', missing;
    end if;
  end loop;
  select count(*) into n from pg_enum e join pg_type t on t.oid=e.enumtypid where t.typname='sg8_session_status';
  if n <> 7 then raise exception 'ROLLBACK/0008: sg8_session_status deve ter 7 rótulos, achou %', n; end if;
  select string_agg(want,', ') into missing from (values
    ('sg8_append_only_guard'),('sg8_sessions_guard'),('sg8_round_report_evidence_guard')) as t(want)
   where not exists (select 1 from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace where ns.nspname='public' and p.proname=t.want);
  if missing is not null then raise exception 'ROLLBACK/0008: função(ões) ausente(s): %', missing; end if;
  select string_agg(want,', ') into missing from (values
    ('sg8_sessions_guard'),('sg8_sessions_no_truncate'),
    ('sg8_resolution_snapshots_immutable'),('sg8_resolution_snapshots_no_truncate'),
    ('sg8_round_executions_immutable'),('sg8_round_executions_no_truncate'),
    ('sg8_round_report_evidence_guard'),('sg8_round_report_evidence_no_truncate')) as t(want)
   where not exists (select 1 from pg_trigger where not tgisinternal and tgname=t.want);
  if missing is not null then raise exception 'ROLLBACK/0008: trigger(s) ausente(s): %', missing; end if;
  select string_agg(want,', ') into missing from (values
    ('sg8_sessions_terminal_state_chk'),('sg8_sessions_comparison_contract_v1_chk'),
    ('sg8_round_executions_manifest_hash_format_chk'),('sg8_round_executions_compute_provenance_nonblank_chk')) as t(want)
   where not exists (select 1 from pg_constraint where contype='c' and conname=t.want);
  if missing is not null then raise exception 'ROLLBACK/0008: CHECK(s) ausente(s): %', missing; end if;
end $$;

\echo 'OK — sg8 runtime identity/grants/RLS POST-ROLLBACK verification PASSED (§1 absence + §2 baseline restored + §3 0008 intact).'
