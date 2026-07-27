-- ============================================================================
-- NOXUND · ROLLBACK — SG-8 Runtime Identity, Grants & RLS (DATA-SG8-001 estágio 3 · U3A-GRANTS)
-- ----------------------------------------------------------------------------
-- Reverte 20260620000009_sg8_runtime_identity_grants_rls.sql POR COMPLETO, restaurando EXATAMENTE
-- o baseline pós-0008 de CADA UMA das quatro tabelas-alvo (RLS habilitada, zero policies, service_role
-- com seus grants default, anon/authenticated/PUBLIC negados) e devolvendo a ACL da função UUID ao
-- default. A 0009 é a ÚNICA proprietária de sg8_compute_writer (create-only), então o rollback pode e
-- deve DROPAR a role que a 0009 criou.
--
-- LOCAL: fora de supabase/migrations/ DE PROPÓSITO (o Supabase CLI aplica migrations/ como forward).
--        Rodar manualmente (admin) só para reverter esta unidade. O harness hermético também roda ESTE
--        arquivo no passo [1.5] (limpar a role cluster-global que `supabase start` cria, antes do
--        `db reset`, para o create-only da 0009 aplicar limpo).
--
-- ADITIVA ⇒ reversível sem perda de contrato: só remove role + grants + policies que ESTA unidade
--   criou, e RE-CONCEDE ao service_role EXATAMENTE o baseline que ESTA unidade revogou. NÃO toca
--   tabelas/enums/triggers/colunas da 0008 nem de qualquer Fase.
--
-- ORDEM (contrato da unidade):
--   [1] remover as 9 policies dedicadas;
--   [2] revogar TODOS os grants dedicados (tabela+coluna, schema, database); a ACL da função UUID NÃO
--       é tocada (dependência de PUBLIC — a 0009 nunca a alterou; permanece byte-equivalente ao baseline);
--   [3] COMPROVAR ausência de ownership e memberships (escala se houver);
--   [4] remover a role sg8_compute_writer;
--   [5] restaurar SÓ os grants de baseline da 0008 que foram comprovadamente revogados (service_role),
--       por tabela, verbo a verbo.
--
-- BASELINE NÃO PRESUMIDO, SEM report_runs (DEC-0026-R4/C): a FONTE DE VERDADE é o ESTADO REAL das quatro
--   tabelas-alvo — a precondition fail-closed da 0009 PROVOU, no apply, que a ACL DIRETA real de service_role
--   é IDÊNTICA nas quatro e bate, verbo a verbo, com o mecanismo de reconstrução (pg_default_acl do defaclrole
--   == OWNER/criador — as default privileges que EFETIVAMENTE se aplicaram às SG-8, p.ex. {REFERENCES,TRIGGER,
--   TRUNCATE}). Logo reconstruir pelo mecanismo == restaurar o baseline REAL comprovado. pg_default_acl é
--   auxiliar/mecanismo, nunca substituto do estado real. report_runs NÃO é usada (nem fonte, nem prova).
--
-- ATIVAÇÃO FUTURA (registro operacional): esta unidade é DESIGN-ONLY e a role nasce NOLOGIN/sem
--   sessão. Um rollback FUTURO, DEPOIS de ativação (LOGIN out-of-band), exige PRIMEIRO:
--     (i) ALTER ROLE sg8_compute_writer NOLOGIN; (ii) drenagem/encerramento controlado das sessões;
--     (iii) só então executar este rollback. Esta migration design-only NÃO encerra sessões nem
--     executa ALTER ROLE LOGIN/NOLOGIN operacional.
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
-- [2] Revogar TODOS os grants dedicados da role (tabela+coluna, schema, database).
--     Necessário ANTES do DROP ROLE: privilégios concedidos são dependências que bloqueiam o drop.
--     NOTA (DEC-0026-R4/B): a 0009 NÃO concede mais EXECUTE na função UUID (a escrita apoia-se no
--     EXECUTE de PUBLIC). Logo NÃO há ACL de função a reverter aqui — a ACL de gen_random_uuid()
--     permanece BYTE-EQUIVALENTE ao baseline (intocada no apply e no rollback).
-- ----------------------------------------------------------------------------
do $$
begin
  if to_regrole('sg8_compute_writer') is null then
    return;  -- role já ausente ⇒ nada a revogar
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
-- [4] Remover a role (agora sem dependências). A 0009 a criou (create-only) ⇒ o rollback a remove.
-- ----------------------------------------------------------------------------
drop role if exists sg8_compute_writer;

-- ----------------------------------------------------------------------------
-- [5] Restaurar SÓ o baseline do service_role que a 0009 revogou, POR TABELA e VERBO a VERBO. O baseline
--     é DERIVADO das default privileges (pg_default_acl do defaclrole==OWNER) — a MESMA referência que a
--     precondition fail-closed da 0009 provou bater, verbo a verbo, com a ACL DIRETA REAL das 4 tabelas
--     (fonte de verdade). Sem report_runs. anon/authenticated/PUBLIC/authenticator: nada a restaurar (0008).
-- ----------------------------------------------------------------------------
do $$
declare v_ref text[]; verb text; tbl text;
begin
  if to_regrole('service_role') is null then return; end if;
  -- baseline (mesmo mecanismo/consulta da precondition da 0009, corroborada lá == estado real das 4
  -- tabelas): default privileges p/ service_role em public do defaclrole == OWNER/criador (as que se
  -- aplicaram às SG-8). Filtra por defaclrole=owner (NÃO união entre grantors, que superestima).
  select coalesce(array_agg(distinct a.privilege_type order by a.privilege_type), array[]::text[])
    into v_ref
    from pg_default_acl da, aclexplode(da.defaclacl) a
   where da.defaclnamespace = 'public'::regnamespace and da.defaclobjtype = 'r'
     and da.defaclrole = (select relowner from pg_class where oid = 'public.sg8_sessions'::regclass)
     and a.grantee = 'service_role'::regrole;

  foreach tbl in array array['sg8_sessions','sg8_resolution_snapshots','sg8_round_executions','sg8_round_report_evidence'] loop
    foreach verb in array v_ref loop
      execute format('grant %s on table public.%I to service_role', verb, tbl);
    end loop;
  end loop;
  raise notice '0009 ROLLBACK: baseline de service_role restaurado nas 4 tabelas-alvo, verbo a verbo = %', v_ref;
end $$;

commit;
