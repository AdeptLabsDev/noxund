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
--   • O default UUID de sg8_round_report_evidence.id é DESCOBERTO no catálogo (não presumido). A 0009
--     NÃO altera a ACL dessa função (DEC-0026-R4/B): a escrita do default depende do EXECUTE de PUBLIC
--     (grantee OID 0) — dependência PROVADA fail-closed, jamais um grant dedicado. Se PUBLIC EXECUTE
--     faltar, a migration FALHA (sem elevar privilégio); nunca se usa supabase_admin/superuser.
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
-- 1. IDENTIDADE — `sg8_compute_writer` CREATE-ONLY (a 0009 é a ÚNICA proprietária do lifecycle).
--    Regra vinculante (DEC-0026 corretivo): criar SOMENTE quando a role estiver COMPROVADAMENTE
--    AUSENTE. Se JÁ EXISTIR no cluster, o apply FALHA — sem comparar atributos, sem adotar, sem
--    modificar, sem CREATE ROLE IF NOT EXISTS nem qualquer caminho silencioso.
--    Justificativa: roles são CLUSTER-GLOBAL e o rollback REMOVE a role; a migration não pode
--    remover uma identidade que não criou. Logo não pode tolerar/adotar uma preexistente.
--    (O harness aplica a unidade no boot via `supabase start`; o passo [1.5] roda ESTE rollback
--    para limpar a role cluster-global antes do `db reset`, de modo que o create-only aplique limpo.)
--    Nasce inerte/trancada, NOLOGIN e SEM senha — ativação é out-of-band, nunca aqui.
-- ----------------------------------------------------------------------------
do $$
begin
  if to_regrole('sg8_compute_writer') is not null then
    raise exception 'SG-8 0009: sg8_compute_writer JÁ EXISTE no cluster — a 0009 é a única proprietária do lifecycle; recusando adotar/modificar (roles são cluster-global e o rollback remove a role: a migration não pode remover uma identidade que não criou). Dropar a role preexistente out-of-band e reaplicar.';
  end if;
  create role sg8_compute_writer
    nologin nosuperuser nocreatedb nocreaterole noinherit noreplication nobypassrls;
end $$;

-- ----------------------------------------------------------------------------
-- 1b. PRECONDITION FAIL-CLOSED — baseline REAL de service_role. FONTE DE VERDADE = o ESTADO REAL DOS
--     OBJETOS (as 4 tabelas-alvo), lido do catálogo de cada uma: owner; ACL DIRETA (relacl); grantor;
--     privilégio EFETIVO; memberships de service_role; RLS. (DEC-0026-R4/C.) ABORTA — sem normalizar —
--     se: service_role for OWNER; RLS off; EFETIVO != DIRETO (algum verbo viria de membership/PUBLIC);
--     as 4 tabelas DIVERGIREM entre si (basta UMA divergir). `pg_default_acl` do owner entra SÓ como
--     evidência AUXILIAR e como MECANISMO DE RECONSTRUÇÃO do rollback — corroborado igual aqui (gate de
--     reversibilidade), NUNCA como substituto do estado real. Reporta tudo, por tabela (não report_runs).
-- ----------------------------------------------------------------------------
do $$
declare
  tbl text; v_owner oid; v_owner_name text; v_rls boolean;
  v_direct text[]; v_effective text[]; v_ref text[]; v_first text[] := null; v_grantor text;
  v_members text;
begin
  -- MEMBERSHIPS de service_role (evidência): quais roles ele integra — nenhuma deve dar verbo às SG-8
  -- (o EFETIVO==DIRETO por tabela é a PROVA disso; esta lista é o registro humano exigido por R4/C).
  select string_agg(r.rolname, ',' order by r.rolname) into v_members
    from pg_auth_members m join pg_roles r on r.oid = m.roleid
   where to_regrole('service_role') is not null and m.member = 'service_role'::regrole;

  -- AUXILIAR (mecanismo de reconstrução do rollback; NÃO é a fonte de verdade): default privileges p/
  -- service_role em tabelas public — UNIÃO entre os grantor roles (robusto à identidade do defaclrole:
  -- não presume que defaclrole == owner). Read-only; NÃO report_runs. Corroborado == estado real abaixo.
  select coalesce(array_agg(distinct a.privilege_type order by a.privilege_type), array[]::text[])
    into v_ref
    from pg_default_acl da, aclexplode(da.defaclacl) a
   where da.defaclnamespace = 'public'::regnamespace and da.defaclobjtype = 'r'
     and a.grantee = 'service_role'::regrole;

  foreach tbl in array array['sg8_sessions','sg8_resolution_snapshots','sg8_round_executions','sg8_round_report_evidence'] loop
    select relowner, relrowsecurity into v_owner, v_rls from pg_class where oid = ('public.'||tbl)::regclass;
    v_owner_name := v_owner::regrole::text;

    if to_regrole('service_role') is not null and v_owner = 'service_role'::regrole then
      raise exception '0009 PRECONDITION: service_role é OWNER de % — baseline inválido', tbl;
    end if;
    if not v_rls then
      raise exception '0009 PRECONDITION: RLS deveria estar HABILITADA em % (contrato 0008)', tbl;
    end if;

    -- ESTADO REAL DO OBJETO (fonte de verdade): ACL direta (relacl) + efetivo + grantor.
    select coalesce(array_agg(distinct a.privilege_type order by a.privilege_type), array[]::text[])
      into v_direct
      from pg_class c, aclexplode(c.relacl) a
     where c.oid = ('public.'||tbl)::regclass and a.grantee = 'service_role'::regrole;
    select coalesce(array_agg(v order by v), array[]::text[]) into v_effective
      from unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) v
     where has_table_privilege('service_role', ('public.'||tbl)::regclass, v);
    select string_agg(distinct a.grantor::regrole::text, ',') into v_grantor
      from pg_class c, aclexplode(c.relacl) a
     where c.oid = ('public.'||tbl)::regclass and a.grantee = 'service_role'::regrole;

    raise notice '0009 BASELINE %: owner=% rls=% direct=% effective=% grantor=% memberships(service_role)=[%] aux(default_acl)=%',
      tbl, v_owner_name, v_rls, v_direct, v_effective, coalesce(v_grantor, '<none>'), coalesce(v_members, ''), v_ref;

    -- AUTORIDADE 1 (estado real) — EFETIVO == DIRETO ⇒ nenhum verbo vem de membership/PUBLIC (o que se
    -- revoga é DIRETO, não herdado).
    if v_effective is distinct from v_direct then
      raise exception '0009 PRECONDITION: em % o EFETIVO de service_role (%) difere da ACL DIRETA (%) — caminho por membership/PUBLIC; abortando', tbl, v_effective, v_direct;
    end if;
    -- AUTORIDADE 2 (estado real) — as 4 tabelas têm baseline REAL IDÊNTICO. Basta UMA divergir p/ abortar.
    if v_first is null then v_first := v_direct;
    elsif v_direct is distinct from v_first then
      raise exception '0009 PRECONDITION: baseline REAL de % (%) diverge das demais tabelas SG-8 (%) — abortando (não normalizar)', tbl, v_direct, v_first;
    end if;
    -- CORROBORAÇÃO/REVERSIBILIDADE (auxiliar) — o estado real bate com o mecanismo que o rollback usa
    -- para RECONSTRUIR o baseline; se divergisse, o rollback não teria como restaurar com segurança.
    if v_direct is distinct from v_ref then
      raise exception '0009 PRECONDITION: baseline REAL de % (%) != mecanismo de reconstrução do rollback (pg_default_acl=%) — reversibilidade não garantida; abortando (investigar)', tbl, v_direct, v_ref;
    end if;
  end loop;

  raise notice '0009 PRECONDITION OK: baseline REAL de service_role IDÊNTICO nas 4 tabelas-alvo = % (não-owner; direto==efetivo, sem membership; RLS on; corroborado pelo mecanismo de reconstrução).', coalesce(v_first, array[]::text[]);
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
--                                 logo NÃO recebe INSERT (a escrita do default apoia-se no EXECUTE de
--                                 PUBLIC — dependência PROVADA no §3, sem tocar a ACL da função).
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
-- 3. DEPENDÊNCIA DO DEFAULT UUID — CHECK READ-ONLY (a 0009 NÃO altera a ACL da função). DEC-0026-R4/B:
--    o grant direto de EXECUTE em pg_catalog.gen_random_uuid() foi REVOGADO como exigência — o runner
--    canônico é NÃO-superuser/NÃO-owner do built-in PINADO e não tem grant option (o grant emitia
--    `WARNING: no privileges were granted` e nunca materializava; a capacidade real da role SEMPRE veio
--    do EXECUTE de PUBLIC). Esta unidade, portanto, NÃO toca a ACL da função — apenas PROVA a dependência,
--    fail-closed. Confirma: (i) a regprocedure EXATA do default de sg8_round_report_evidence.id; (ii) que
--    resolve para pg_catalog.gen_random_uuid() SEM shadowing por search_path; (iii) que EXECUTE vem de
--    PUBLIC (grantee OID 0) e que NÃO há grant direto p/ sg8_compute_writer; (iv) FALHA se PUBLIC EXECUTE
--    faltar — sem elevar privilégio, sem supabase_admin (aí escala-se unidade separada p/ UUID da app).
--    Registro honesto: esta é uma DEPENDÊNCIA DE PUBLIC — NÃO um grant dedicado nem isolamento exclusivo.
-- ----------------------------------------------------------------------------
do $$
declare
  v_func regprocedure; v_nsp text; v_proname text; v_attnum smallint;
  v_pub_exec boolean; v_direct_writer int; v_unqual regprocedure;
begin
  select attnum into v_attnum from pg_attribute
   where attrelid = 'public.sg8_round_report_evidence'::regclass and attname = 'id' and not attisdropped;

  -- descoberta: pg_depend (funções de extensão, ex. pgcrypto extensions.gen_random_uuid — geram dep) e
  -- fallback pelo TEXTO do default (built-in PINADO pg_catalog.gen_random_uuid não registra pg_depend).
  select dep.refobjid::regprocedure into v_func
    from pg_attrdef ad
    join pg_depend dep
      on dep.classid = 'pg_attrdef'::regclass and dep.objid = ad.oid and dep.refclassid = 'pg_proc'::regclass
   where ad.adrelid = 'public.sg8_round_report_evidence'::regclass and ad.adnum = v_attnum
   limit 1;
  if v_func is null then
    select to_regprocedure(pg_get_expr(ad.adbin, ad.adrelid)) into v_func
      from pg_attrdef ad
     where ad.adrelid = 'public.sg8_round_report_evidence'::regclass and ad.adnum = v_attnum;
  end if;
  if v_func is null then
    raise exception 'SG-8 0009: sg8_round_report_evidence.id — default não resolvido para uma função (esperado gen_random_uuid())';
  end if;

  select n.nspname, p.proname into v_nsp, v_proname
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace where p.oid = v_func::oid;

  -- (ii) é gen_random_uuid() e SEM shadowing: a resolução SEM qualificação (via search_path) aterrissa
  --      na MESMA função (nenhum public.gen_random_uuid() etc. a intercepta).
  if v_proname <> 'gen_random_uuid' then
    raise exception 'SG-8 0009: default de evidence.id resolve para %.% — esperado gen_random_uuid()', v_nsp, v_proname;
  end if;
  v_unqual := to_regprocedure('gen_random_uuid()');
  if v_unqual is distinct from v_func then
    raise exception 'SG-8 0009: SHADOWING por search_path — gen_random_uuid() sem qualificação resolve p/ % != default % (esperado a mesma pg_catalog)', v_unqual, v_func;
  end if;

  -- (iii) autorização vem de PUBLIC (grantee 0); NENHUM grant direto p/ writer. aclexplode(NULL) não
  --       retorna linhas ⇒ coalesce p/ acldefault revela a entrada IMPLÍCITA de PUBLIC do built-in.
  select bool_or(a.grantee = 0 and a.privilege_type = 'EXECUTE') into v_pub_exec
    from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f'::"char", p.proowner))) a
   where p.oid = v_func::oid;
  select count(*) into v_direct_writer
    from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f'::"char", p.proowner))) a
   where p.oid = v_func::oid and to_regrole('sg8_compute_writer') is not null
     and a.grantee = 'sg8_compute_writer'::regrole and a.privilege_type = 'EXECUTE';

  raise notice 'SG-8 0009: default de evidence.id = % (schema %); PUBLIC EXECUTE=%, grant direto p/ writer=% (esperado 0 — dependência é de PUBLIC, ACL intocada).',
    v_func::text, v_nsp, v_pub_exec, v_direct_writer;

  -- (iv) fail-closed se PUBLIC EXECUTE ausente. NÃO conceder, NÃO elevar, NÃO supabase_admin.
  if not coalesce(v_pub_exec, false) then
    raise exception 'SG-8 0009: PUBLIC NÃO tem EXECUTE em % — a escrita de evidence.id (default UUID) não é autorizável sem elevar privilégio; ABORTANDO. Escalar unidade separada p/ default por UUID fornecido pela aplicação (fora de escopo desta unidade).', v_func::text;
  end if;
  if v_direct_writer <> 0 then
    raise exception 'SG-8 0009: há grant DIRETO de EXECUTE p/ sg8_compute_writer em % — esta unidade NÃO deve tocar a ACL da função (dependência é de PUBLIC); ABORTANDO', v_func::text;
  end if;
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
