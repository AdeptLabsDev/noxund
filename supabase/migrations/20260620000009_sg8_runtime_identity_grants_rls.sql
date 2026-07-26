-- ============================================================================
-- NOXUND · Migration — SG-8 Runtime Identity, Grants & RLS (DATA-SG8-001 estágio 3 · U3A-GRANTS)
-- ----------------------------------------------------------------------------
-- Cria a IDENTIDADE DE RUNTIME DEDICADA do compute SG-8 — a role `sg8_compute_writer` — e o
-- privilégio MÍNIMO E EXATO de que o `PostgresSg8Store` (services/data-engine/.../postgres_sg8.py)
-- precisa para persistir a sessão SG-8 nas 4 tabelas da 0008, mais policies RLS dedicadas TO essa
-- identidade. Simultaneamente REMOVE o acesso das identidades amplas do Supabase (service_role,
-- anon, authenticated, authenticator, PUBLIC) às tabelas SG-8: o SG-8 deixa de depender do
-- service_role e passa a ter uma superfície de escrita própria, auditável e isolada.
--
-- DECISÃO VINCULANTE (Product Lead · DEC-0026 · GO U3A-GRANTS):
--   • a identidade canônica de escrita SG-8 é EXCLUSIVAMENTE `sg8_compute_writer`;
--   • `service_role` NÃO é candidata a writer e NÃO pode permanecer com acesso às tabelas SG-8;
--   • as policies RLS são DEDICADAS `TO sg8_compute_writer`, com acesso ROLE-WIDE às linhas SG-8
--     (não por sessão/tenant) — os invariantes continuam nos GRANTS por coluna e nos triggers da 0008;
--   • NENHUM Environment, secret, senha, LOGIN ou apply remoto é autorizado por esta unidade.
--
-- DESIGN-ONLY: AUTORADO, NÃO APLICADO. Como as Fases 1–6 e a 0008, change_db_schema/run_migration
--   seguem gated (humano + required reviewers). NENHUMA aplicação em banco compartilhado/live.
--   A role nasce NOLOGIN e SEM senha; ativação (LOGIN + senha) é OUT-OF-BAND (estágio futuro),
--   NUNCA nesta migration.
--
-- SEPARAÇÃO DE BANCOS (registro): esta é a superfície de escrita do FUTURO serviço `sg8-compute`,
--   distinta do `production-db`. `sg8_compute_writer` é a fronteira de menor-privilégio entre eles.
--   NENHUM provider/LLM participa (DEC-0025): o caminho autoritativo é 100% determinístico.
--
-- HARD CONSTRAINTS (non-negotiables):
--   • ADITIVA sobre a 0008. Só cria role + grants + policies + revokes. ZERO DDL nas tabelas
--     (nenhuma coluna/constraint/trigger/enum é criada, alterada ou removida). ZERO acesso a
--     reports / report_runs / rubric_versions ou qualquer outro pipeline.
--   • A role é criada com contrato TRANCADO (NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT
--     NOREPLICATION NOBYPASSRLS, zero memberships, zero ownership, sem senha). Se uma role homônima
--     PREEXISTIR e NÃO corresponder EXATAMENTE a esse contrato, a migration FALHA — jamais adota nem
--     modifica silenciosamente uma identidade externa.
--   • INSERT é COLUNA-A-COLUNA, só nas colunas efetivamente escritas pelo PostgresSg8Store.
--     UPDATE só em sg8_sessions e só nas 5 colunas mutadas. `comparison_contract_version` tem
--     APENAS INSERT (nunca UPDATE — imutável por contrato). SEM DELETE/TRUNCATE/REFERENCES/TRIGGER,
--     SEM UPDATE nas tabelas append-only, SEM DDL, SEM privilégio de sequence (não há sequence: PKs
--     são gen_random_uuid()).
--   • O default UUID de sg8_round_report_evidence.id é DESCOBERTO no catálogo (não presumido) e a
--     role recebe EXECUTE SÓ nessa função exata — sem depender silenciosamente de PUBLIC EXECUTE.
--   • O revoke de service_role é validado por PRIVILÉGIO EFETIVO (has_table_privilege), não só ACL:
--     se sobrar acesso por ownership/membership/qualquer caminho, a migration ABORTA (fail-closed).
--   • Atômica (begin/commit). Rollback e verifies pareados (todos os objetos novos).
--
-- ORDENAÇÃO: ts 0009, imediatamente após a 0008 (identidade/grants/RLS do runtime que a 0008 modelou).
--   Depende da 0008 (as 4 tabelas + RLS já habilitada). Não colide com o slot 0007 (Phase 6 PARKED).
--
-- Fontes vinculantes:
--   supabase/migrations/20260620000008_sg8_reconciliation_session.sql (as 4 tabelas + RLS enable + triggers/FSM/PASS gate)
--   services/data-engine/src/noxund_data_engine/postgres_sg8.py (as EXATAS colunas escritas/lidas)
--   docs/product/decisions/DEC-0026-sg8-runtime-identity-grants-rls.md (a decisão que autoriza esta unidade)
--   docs/data/DATA-SG8-001-sg8-design-contract.md §6 (writes/append-only) · padrão de grants/RLS das Fases 1–6
--
-- Rollback: supabase/rollback/20260620000009_sg8_runtime_identity_grants_rls.rollback.sql
-- Verify:   supabase/tests/sg8_runtime_identity_grants_rls_post_apply_verify.sql
--           supabase/tests/sg8_runtime_identity_grants_rls_post_rollback_verify.sql
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 1. IDENTIDADE — `sg8_compute_writer` com contrato TRANCADO.
--    Criar do zero se ausente; se PREEXISTIR, ADOTAR SOMENTE se corresponder EXATAMENTE ao
--    contrato (idempotência do harness: `supabase db reset` re-aplica sobre uma role cluster-global
--    já criada). QUALQUER divergência ⇒ FALHA (não adota/modifica identidade externa).
--    NOLOGIN + SEM senha: ativação é out-of-band, nunca aqui.
-- ----------------------------------------------------------------------------
do $$
declare
  v_oid oid;
  v_canlogin boolean; v_super boolean; v_createdb boolean; v_createrole boolean;
  v_inherit boolean; v_replication boolean; v_bypassrls boolean; v_haspwd boolean;
  n int;
begin
  select oid into v_oid from pg_roles where rolname = 'sg8_compute_writer';

  if v_oid is null then
    -- Nasce inerte e trancada. Sem LOGIN, sem senha, sem herança, sem bypass de RLS.
    create role sg8_compute_writer
      nologin nosuperuser nocreatedb nocreaterole noinherit noreplication nobypassrls;
    select oid into v_oid from pg_roles where rolname = 'sg8_compute_writer';
  else
    -- ADOTAR SOMENTE SE EXATO. Atributos.
    select rolcanlogin, rolsuper, rolcreatedb, rolcreaterole, rolinherit, rolreplication, rolbypassrls
      into v_canlogin, v_super, v_createdb, v_createrole, v_inherit, v_replication, v_bypassrls
      from pg_roles where oid = v_oid;
    if v_canlogin or v_super or v_createdb or v_createrole or v_inherit or v_replication or v_bypassrls then
      raise exception
        'sg8_compute_writer PREEXISTE com atributos fora do contrato trancado (quero NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS): canlogin=% super=% createdb=% createrole=% inherit=% replication=% bypassrls=% — recusando adotar identidade externa',
        v_canlogin, v_super, v_createdb, v_createrole, v_inherit, v_replication, v_bypassrls;
    end if;
    -- Sem senha (LOGIN/senha só out-of-band).
    select (rolpassword is not null) into v_haspwd from pg_authid where oid = v_oid;
    if v_haspwd then
      raise exception 'sg8_compute_writer PREEXISTE COM senha — contrato exige nenhuma (LOGIN/senha só out-of-band, nunca nesta migration)';
    end if;
    -- Zero memberships (nem membro de nada, nem nada é membro dela).
    select count(*) into n from pg_auth_members where member = v_oid or roleid = v_oid;
    if n <> 0 then
      raise exception 'sg8_compute_writer PREEXISTE com % aresta(s) de membership — contrato exige zero', n;
    end if;
    -- Zero ownership de qualquer objeto (relação/tipo/função/schema).
    select (select count(*) from pg_class     where relowner = v_oid)
         + (select count(*) from pg_type      where typowner = v_oid)
         + (select count(*) from pg_proc      where proowner = v_oid)
         + (select count(*) from pg_namespace where nspowner = v_oid)
      into n;
    if n <> 0 then
      raise exception 'sg8_compute_writer PREEXISTE possuindo % objeto(s) — contrato exige zero ownership', n;
    end if;
    -- Contrato EXATO ⇒ adoção segura (identidade inerte, indistinguível de recém-criada). NÃO se
    -- executa ALTER ROLE aqui: a adoção só VERIFICA (nunca modifica uma identidade externa).
    raise notice 'SG-8 0009: sg8_compute_writer preexistente confere EXATAMENTE o contrato trancado — adotada (sem modificação).';
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- 2. GRANTS — mínimo e exato.
--    2a. CONNECT só no database atual (nunca hardcode 'postgres').
--    2b. USAGE no schema public.
--    2c. SELECT nas 4 tabelas SG-8 (o adapter LÊ as 4 para replay/comparação).
--    2d. INSERT COLUNA-A-COLUNA — só as colunas escritas pelo PostgresSg8Store.
--    2e. UPDATE só em sg8_sessions e só nas 5 colunas mutadas.
-- ----------------------------------------------------------------------------

-- 2a. CONNECT no database corrente.
do $$
begin
  execute format('grant connect on database %I to sg8_compute_writer', current_database());
end $$;

-- 2b. USAGE no schema public.
grant usage on schema public to sg8_compute_writer;

-- 2c. SELECT nas 4 tabelas.
grant select on table
  public.sg8_sessions,
  public.sg8_resolution_snapshots,
  public.sg8_round_executions,
  public.sg8_round_report_evidence
  to sg8_compute_writer;

-- 2d. INSERT por coluna — MATRIZ EXATA (espelha _INSERT_* de postgres_sg8.py):
--   sg8_sessions              ← _INSERT_SESSION  (id, source_collection_run_id, comparison_contract_version)
--   sg8_resolution_snapshots  ← _INSERT_SNAPSHOT (id, sg8_session_id, source_collection_run_id,
--                                                  resolver_version, resolver_hash, fact_count, content_hash)
--   sg8_round_executions      ← _INSERT_ROUND    (id, sg8_session_id, round_number, source_collection_run_id,
--                                                  resolution_snapshot_id, compute_engine_name,
--                                                  compute_engine_version, compute_manifest_hash)
--   sg8_round_report_evidence ← _INSERT_EVIDENCE (round_execution_id, sg8_session_id, report_id, canonical_digest)
--                               — `id` NÃO é escrito pelo adapter (usa o default gen_random_uuid());
--                                 logo NÃO recebe INSERT (a escrita depende SÓ do EXECUTE do §3).
grant insert (id, source_collection_run_id, comparison_contract_version)
  on public.sg8_sessions to sg8_compute_writer;

grant insert (id, sg8_session_id, source_collection_run_id,
              resolver_version, resolver_hash, fact_count, content_hash)
  on public.sg8_resolution_snapshots to sg8_compute_writer;

grant insert (id, sg8_session_id, round_number, source_collection_run_id, resolution_snapshot_id,
              compute_engine_name, compute_engine_version, compute_manifest_hash)
  on public.sg8_round_executions to sg8_compute_writer;

grant insert (round_execution_id, sg8_session_id, report_id, canonical_digest)
  on public.sg8_round_report_evidence to sg8_compute_writer;

-- 2e. UPDATE — SÓ sg8_sessions, SÓ as 5 colunas mutadas (união de _SET_STATUS / _BIND_REPORTS /
--     _MARK_TERMINAL): status, report_id_1, report_id_2, terminal_at, verdict_reason.
--     `comparison_contract_version` é DELIBERADAMENTE EXCLUÍDA (INSERT-only; imutável por contrato).
grant update (status, report_id_1, report_id_2, terminal_at, verdict_reason)
  on public.sg8_sessions to sg8_compute_writer;

-- ----------------------------------------------------------------------------
-- 3. DEFAULT UUID — descobrir a FUNÇÃO EXATA que respalda o default de
--    sg8_round_report_evidence.id (a ÚNICA tabela cujo `id` o adapter não escreve) e conceder
--    EXECUTE só nela. Nunca depender silenciosamente de PUBLIC EXECUTE. Se a função morar num
--    schema não-public/não-pg_catalog (ex.: extensions), conceder também USAGE nesse schema —
--    descoberta contraditória comprovada, mínima e documentada.
-- ----------------------------------------------------------------------------
do $$
declare
  v_func regprocedure;
  v_nsp  text;
  v_attnum smallint;
begin
  select attnum into v_attnum from pg_attribute
   where attrelid = 'public.sg8_round_report_evidence'::regclass and attname = 'id' and not attisdropped;

  -- (i) via pg_depend — preciso e sem ambiguidade de search_path. Cobre funções de EXTENSÃO
  --     (ex.: pgcrypto extensions.gen_random_uuid), que NÃO são pinadas e geram dependência.
  select dep.refobjid::regprocedure into v_func
    from pg_attrdef ad
    join pg_depend dep
      on dep.classid = 'pg_attrdef'::regclass
     and dep.objid   = ad.oid
     and dep.refclassid = 'pg_proc'::regclass
   where ad.adrelid = 'public.sg8_round_report_evidence'::regclass
     and ad.adnum   = v_attnum
   limit 1;

  -- (ii) fallback — PostgreSQL NÃO registra pg_depend para objetos de sistema PINADOS. O built-in
  --      pg_catalog.gen_random_uuid() (PG13+) é pinado ⇒ (i) retorna NULL. Resolvemos então a
  --      partir do TEXTO REAL do default (pg_get_expr → to_regprocedure), sem presumir o nome.
  if v_func is null then
    select to_regprocedure(pg_get_expr(ad.adbin, ad.adrelid)) into v_func
      from pg_attrdef ad
     where ad.adrelid = 'public.sg8_round_report_evidence'::regclass and ad.adnum = v_attnum;
  end if;

  if v_func is null then
    raise exception 'SG-8 0009: sg8_round_report_evidence.id — default não resolvido para uma função (esperado gen_random_uuid())';
  end if;

  select n.nspname into v_nsp
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where p.oid = v_func::oid;

  -- Identificação POSITIVA (registrada para o relatório/revisores).
  raise notice 'SG-8 0009: default de evidence.id resolve para % (schema %)', v_func::text, v_nsp;

  if v_nsp not in ('pg_catalog', 'public') then
    execute format('grant usage on schema %I to sg8_compute_writer', v_nsp);
  end if;
  execute format('grant execute on function %s to sg8_compute_writer', v_func::text);
end $$;

-- ----------------------------------------------------------------------------
-- 4. RLS — policies DEDICADAS `TO sg8_compute_writer`, separadas por tabela e operação.
--    RLS já foi HABILITADA pela 0008; aqui só CRIAMOS as policies dedicadas. Acesso ROLE-WIDE
--    (USING/WITH CHECK = true): a policy concede acesso GLOBAL às linhas SG-8 para a identidade
--    dedicada. Os invariantes de conteúdo/estado NÃO são duplicados na policy — permanecem nos
--    GRANTS por coluna e nos triggers/CHECKs da 0008 (FSM, terminalidade, PASS gate, append-only).
--    Sem policy de DELETE em nenhuma tabela. UPDATE só em sg8_sessions.
-- ----------------------------------------------------------------------------

-- sg8_sessions: SELECT + INSERT + UPDATE (a ÚNICA tabela com UPDATE de runtime).
create policy sg8_sessions_writer_select on public.sg8_sessions
  for select to sg8_compute_writer using (true);
create policy sg8_sessions_writer_insert on public.sg8_sessions
  for insert to sg8_compute_writer with check (true);
create policy sg8_sessions_writer_update on public.sg8_sessions
  for update to sg8_compute_writer using (true) with check (true);

-- sg8_resolution_snapshots: SELECT + INSERT (append-only ⇒ sem UPDATE/DELETE).
create policy sg8_resolution_snapshots_writer_select on public.sg8_resolution_snapshots
  for select to sg8_compute_writer using (true);
create policy sg8_resolution_snapshots_writer_insert on public.sg8_resolution_snapshots
  for insert to sg8_compute_writer with check (true);

-- sg8_round_executions: SELECT + INSERT (append-only ⇒ sem UPDATE/DELETE).
create policy sg8_round_executions_writer_select on public.sg8_round_executions
  for select to sg8_compute_writer using (true);
create policy sg8_round_executions_writer_insert on public.sg8_round_executions
  for insert to sg8_compute_writer with check (true);

-- sg8_round_report_evidence: SELECT + INSERT (append-only ⇒ sem UPDATE/DELETE).
create policy sg8_round_report_evidence_writer_select on public.sg8_round_report_evidence
  for select to sg8_compute_writer using (true);
create policy sg8_round_report_evidence_writer_insert on public.sg8_round_report_evidence
  for insert to sg8_compute_writer with check (true);

-- ----------------------------------------------------------------------------
-- 5. REVOGAÇÃO DAS IDENTIDADES AMPLAS — service_role, anon, authenticated, authenticator, PUBLIC
--    perdem QUALQUER verbo de tabela nas 4 tabelas SG-8. anon/authenticated/PUBLIC já foram negados
--    pela 0008 (revoke idempotente aqui); service_role e authenticator são negados AGORA. O SG-8
--    deixa de depender do service_role: sua superfície de escrita é EXCLUSIVAMENTE sg8_compute_writer.
-- ----------------------------------------------------------------------------
do $$
declare tbl text; grantee_name text; verb text;
begin
  foreach tbl in array array['sg8_sessions','sg8_resolution_snapshots','sg8_round_executions','sg8_round_report_evidence'] loop
    foreach grantee_name in array array['service_role','anon','authenticated','authenticator','public'] loop
      -- PUBLIC é pseudo-role (palavra-chave, nunca quote_ident); demais só se existirem.
      if grantee_name = 'public' then
        foreach verb in array array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER'] loop
          execute format('revoke %s on table public.%I from PUBLIC', verb, tbl);
        end loop;
      elsif to_regrole(grantee_name) is not null then
        foreach verb in array array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER'] loop
          execute format('revoke %s on table public.%I from %I', verb, tbl, grantee_name);
        end loop;
      end if;
    end loop;
  end loop;
end $$;

-- ----------------------------------------------------------------------------
-- 6. ISOLAMENTO EFETIVO (fail-closed) — PRIVILÉGIO EFETIVO, não só ACL textual. Se qualquer
--    identidade ampla ainda tiver QUALQUER verbo efetivo (grant direto, PUBLIC, membership ou
--    ownership) sobre uma tabela SG-8, a migration ABORTA e escala. Não se alega isolamento
--    enquanto has_table_privilege retornar verdadeiro.
-- ----------------------------------------------------------------------------
do $$
declare tbl text; rol text; verb text;
begin
  foreach tbl in array array['sg8_sessions','sg8_resolution_snapshots','sg8_round_executions','sg8_round_report_evidence'] loop
    foreach rol in array array['service_role','anon','authenticated','authenticator'] loop
      if to_regrole(rol) is not null then
        foreach verb in array array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER'] loop
          if has_table_privilege(rol, ('public.'||tbl)::regclass, verb) then
            raise exception '0009 SECURITY: role % ainda tem % EFETIVO em % após o revoke — recusando alegar isolamento (checar grant/PUBLIC/membership/ownership)', rol, verb, tbl;
          end if;
        end loop;
      end if;
    end loop;
    -- PUBLIC: nenhuma concessão direta no relacl.
    if exists (select 1 from pg_class c, aclexplode(c.relacl) a
       where c.oid = ('public.'||tbl)::regclass and a.grantee = 0) then
      raise exception '0009 SECURITY: PUBLIC ainda tem concessão direta em %', tbl;
    end if;
    -- service_role não pode ser dono da tabela (caminho de acesso implícito).
    if to_regrole('service_role') is not null
       and (select relowner from pg_class where oid = ('public.'||tbl)::regclass) = 'service_role'::regrole then
      raise exception '0009 SECURITY: service_role é OWNER de % — não pode', tbl;
    end if;
  end loop;
end $$;

commit;
