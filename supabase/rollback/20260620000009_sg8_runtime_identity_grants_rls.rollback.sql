-- ============================================================================
-- NOXUND · ROLLBACK — SG-8 Runtime Identity, Grants & RLS (DATA-SG8-001 estágio 3 · U3A-GRANTS)
-- ----------------------------------------------------------------------------
-- Reverte 20260620000009_sg8_runtime_identity_grants_rls.sql POR COMPLETO, restaurando EXATAMENTE
-- o baseline da 0008 (as 4 tabelas voltam ao estado "RLS habilitada, zero policies, service_role
-- com seus grants default, anon/authenticated/PUBLIC negados").
--
-- LOCAL: fora de supabase/migrations/ DE PROPÓSITO (o Supabase CLI aplica migrations/ como forward).
--        Rodar manualmente (service-role/admin) só para reverter esta unidade.
--
-- ADITIVA ⇒ reversível sem perda de contrato: só remove role + grants + policies que ESTA unidade
--   criou, e RE-CONCEDE ao service_role exatamente o baseline que ESTA unidade revogou. NÃO toca
--   tabelas/enums/triggers/colunas da 0008 nem de qualquer Fase.
--
-- ORDEM (contrato da unidade):
--   [1] remover as 9 policies dedicadas;
--   [2] revogar TODOS os grants dedicados (função, tabela+coluna, schema, database);
--   [3] COMPROVAR ausência de ownership e memberships (escala se houver);
--   [4] remover a role sg8_compute_writer;
--   [5] restaurar SÓ os grants de baseline da 0008 que foram comprovadamente revogados (service_role).
--
-- BASELINE NÃO PRESUMIDO: o baseline pós-0008 do service_role é o conjunto de default privileges do
--   Supabase, CAPTURADO EM RUNTIME de uma tabela-irmã intocada no MESMO schema/contexto de criação —
--   public.report_runs, que NENHUMA migration 0001–0008 concede/revoga para service_role (só
--   anon/authenticated/PUBLIC são mexidos). anon/authenticated/PUBLIC já eram negados pela 0008 ⇒
--   nada a restaurar para eles; authenticator nunca teve grant SG-8 (default privileges miram
--   anon/authenticated/service_role) ⇒ nada a restaurar.
--
-- ATIVAÇÃO FUTURA (registro operacional): esta unidade é DESIGN-ONLY e a role nasce NOLOGIN/sem
--   sessão. Um rollback FUTURO, DEPOIS de ativação (LOGIN concedido out-of-band), exige PRIMEIRO:
--     (i) ALTER ROLE sg8_compute_writer NOLOGIN;
--     (ii) drenagem/encerramento controlado das sessões da role;
--     (iii) só então executar este rollback.
--   Esta migration design-only NÃO encerra sessões nem executa ALTER ROLE LOGIN/NOLOGIN operacional.
--
-- STATUS: AUTORADO, NÃO APLICADO (DESIGN-ONLY). DoD Database: "migration aplica e reverte".
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- [1] Remover as 9 policies dedicadas (TO sg8_compute_writer). RLS permanece HABILITADA (0008).
-- ----------------------------------------------------------------------------
drop policy if exists sg8_sessions_writer_select              on public.sg8_sessions;
drop policy if exists sg8_sessions_writer_insert              on public.sg8_sessions;
drop policy if exists sg8_sessions_writer_update              on public.sg8_sessions;
drop policy if exists sg8_resolution_snapshots_writer_select  on public.sg8_resolution_snapshots;
drop policy if exists sg8_resolution_snapshots_writer_insert  on public.sg8_resolution_snapshots;
drop policy if exists sg8_round_executions_writer_select      on public.sg8_round_executions;
drop policy if exists sg8_round_executions_writer_insert      on public.sg8_round_executions;
drop policy if exists sg8_round_report_evidence_writer_select on public.sg8_round_report_evidence;
drop policy if exists sg8_round_report_evidence_writer_insert on public.sg8_round_report_evidence;

-- ----------------------------------------------------------------------------
-- [2] Revogar TODOS os grants dedicados da role (função, tabela+coluna, schema, database).
--     Necessário ANTES do DROP ROLE: privilégios concedidos são dependências que bloqueiam o drop.
--     Re-descobre a MESMA função de default do §3 da migration para revogar EXECUTE (e a USAGE de
--     schema não-padrão, se concedida).
-- ----------------------------------------------------------------------------
do $$
declare v_func regprocedure; v_nsp text; v_attnum smallint;
begin
  if to_regrole('sg8_compute_writer') is null then
    return;  -- role já ausente ⇒ nada a revogar
  end if;

  -- Função de default (EXECUTE) + eventual USAGE de schema não-padrão.
  select attnum into v_attnum from pg_attribute
   where attrelid = 'public.sg8_round_report_evidence'::regclass and attname = 'id' and not attisdropped;
  select dep.refobjid::regprocedure into v_func
    from pg_attrdef ad
    join pg_depend dep
      on dep.classid = 'pg_attrdef'::regclass and dep.objid = ad.oid and dep.refclassid = 'pg_proc'::regclass
   where ad.adrelid = 'public.sg8_round_report_evidence'::regclass and ad.adnum = v_attnum
   limit 1;
  -- fallback p/ built-in PINADO (pg_catalog.gen_random_uuid não gera pg_depend): parse do texto.
  if v_func is null then
    select to_regprocedure(pg_get_expr(ad.adbin, ad.adrelid)) into v_func
      from pg_attrdef ad
     where ad.adrelid = 'public.sg8_round_report_evidence'::regclass and ad.adnum = v_attnum;
  end if;
  if v_func is not null then
    execute format('revoke execute on function %s from sg8_compute_writer', v_func::text);
    select n.nspname into v_nsp from pg_proc p join pg_namespace n on n.oid = p.pronamespace where p.oid = v_func::oid;
    if v_nsp not in ('pg_catalog', 'public') then
      execute format('revoke usage on schema %I from sg8_compute_writer', v_nsp);
    end if;
  end if;

  -- COLUNA — INSERT (espelha exatamente os grants do §2d da migration).
  revoke insert (id, source_collection_run_id, comparison_contract_version)
    on public.sg8_sessions from sg8_compute_writer;
  revoke insert (id, sg8_session_id, source_collection_run_id, resolver_version, resolver_hash, fact_count, content_hash)
    on public.sg8_resolution_snapshots from sg8_compute_writer;
  revoke insert (id, sg8_session_id, round_number, source_collection_run_id, resolution_snapshot_id,
                 compute_engine_name, compute_engine_version, compute_manifest_hash)
    on public.sg8_round_executions from sg8_compute_writer;
  revoke insert (round_execution_id, sg8_session_id, report_id, canonical_digest)
    on public.sg8_round_report_evidence from sg8_compute_writer;

  -- COLUNA — UPDATE (§2e).
  revoke update (status, report_id_1, report_id_2, terminal_at, verdict_reason)
    on public.sg8_sessions from sg8_compute_writer;

  -- TABELA — SELECT (§2c). REVOKE ALL como backstop de qualquer resíduo (idempotente).
  revoke select on table
    public.sg8_sessions, public.sg8_resolution_snapshots,
    public.sg8_round_executions, public.sg8_round_report_evidence
    from sg8_compute_writer;
  revoke all privileges on table
    public.sg8_sessions, public.sg8_resolution_snapshots,
    public.sg8_round_executions, public.sg8_round_report_evidence
    from sg8_compute_writer;

  -- Schema + database.
  revoke usage on schema public from sg8_compute_writer;
  execute format('revoke connect on database %I from sg8_compute_writer', current_database());
end $$;

-- ----------------------------------------------------------------------------
-- [3] COMPROVAR ausência de ownership e memberships ANTES do drop (escala se houver).
-- ----------------------------------------------------------------------------
do $$
declare v_oid oid; n int;
begin
  select oid into v_oid from pg_roles where rolname = 'sg8_compute_writer';
  if v_oid is null then return; end if;
  select (select count(*) from pg_class     where relowner = v_oid)
       + (select count(*) from pg_type      where typowner = v_oid)
       + (select count(*) from pg_proc      where proowner = v_oid)
       + (select count(*) from pg_namespace where nspowner = v_oid)
    into n;
  if n <> 0 then
    raise exception 'ROLLBACK/abort: sg8_compute_writer possui % objeto(s) — recusando drop (reatribuir/dropar owned primeiro)', n;
  end if;
  select count(*) into n from pg_auth_members where member = v_oid or roleid = v_oid;
  if n <> 0 then
    raise exception 'ROLLBACK/abort: sg8_compute_writer tem % aresta(s) de membership — recusando drop', n;
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- [4] Remover a role (agora sem dependências).
-- ----------------------------------------------------------------------------
drop role if exists sg8_compute_writer;

-- ----------------------------------------------------------------------------
-- [5] Restaurar SÓ o baseline do service_role que a 0009 revogou. Capturado em RUNTIME da
--     tabela-irmã intocada public.report_runs (mesmo schema/criador; default privileges idênticos;
--     nunca revogada/concedida p/ service_role). Restaura verbo-a-verbo — sem presumir "ALL".
--     anon/authenticated/PUBLIC: nada a restaurar (já negados pela 0008). authenticator: idem.
-- ----------------------------------------------------------------------------
do $$
declare verb text; tbl text; n_base int := 0;
begin
  foreach verb in array array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER'] loop
    if has_table_privilege('service_role', 'public.report_runs', verb) then
      n_base := n_base + 1;
      foreach tbl in array array['sg8_sessions','sg8_resolution_snapshots','sg8_round_executions','sg8_round_report_evidence'] loop
        execute format('grant %s on table public.%I to service_role', verb, tbl);
      end loop;
    end if;
  end loop;
  if n_base = 0 then
    raise exception 'ROLLBACK/baseline: service_role tem ZERO privilégio na tabela-irmã report_runs — captura de baseline insegura; escalar (não deixar as tabelas SG-8 com baseline desconhecido de service_role)';
  end if;
end $$;

commit;
