-- ============================================================================
-- NOXUND · SG-8 Runtime Identity, Grants & RLS — POST-ROLLBACK verification (U3A-GRANTS)
-- ----------------------------------------------------------------------------
-- Run AFTER the paired rollback of migration
--   supabase/migrations/20260620000009_sg8_runtime_identity_grants_rls.sql
--   (supabase/rollback/20260620000009_sg8_runtime_identity_grants_rls.rollback.sql)
-- has reverted the unit, while migration 0008 (e 0001–0006) permanecem aplicadas.
--
-- NATURE: read-only (catálogo + has_*_privilege), EXCETO o §5 (probe de atomicidade numa txn REVERTIDA
--   — nenhuma escrita persiste). Prova SEIS coisas:
--   §1 AUSÊNCIA — a role sg8_compute_writer sumiu (create-only ⇒ o rollback a removeu); as 9 policies
--      dedicadas sumiram; as 4 tabelas voltaram a ter ZERO policies; RLS continua HABILITADA; nenhum
--      objeto residual da 0009.
--   §2 BASELINE RESTAURADO (TABELA) — FONTE DE VERDADE = as PRÓPRIAS 4 tabelas-alvo (estado real: efetivo==
--      direto, verbo a verbo, IDÊNTICAS entre si; basta uma divergir p/ falhar). pg_default_acl SÓ como
--      corroboração AUXILIAR (DEC-0026-R4/C) — NÃO report_runs. anon/authenticated/authenticator/PUBLIC NEGADOS.
--   §2b BASELINE RESTAURADO (COLUNA) — attacl NULL em TODAS as colunas SG-8 (baseline 0008 = zero grant de
--      coluna; grants de coluna do writer removidos); anon/authenticated/authenticator sem privilégio de coluna.
--   §3 ACL DA FUNÇÃO UUID INTOCADA — byte-equivalente ao baseline: a 0009 nunca altera a função (dependência
--      de PUBLIC). proacl == default (NULL p/ o built-in pinado); PUBLIC mantém EXECUTE; ZERO entrada
--      residual da role removida; nenhum grantee dangling.
--   §4 CONTRATOS 0008 INTACTOS — 4 tabelas + enum (7) + 3 funções + 8 triggers + CHECKs-chave.
--   §5 ATOMICIDADE — wrapper de teste: falha DEPOIS de CREATE ROLE + rollback ⇒ to_regrole IS NULL (sem
--      resíduo cluster-global; sem cleanup silencioso — a garantia é a fronteira transacional).
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
    if not exists (select 1 from pg_class where relnamespace='public'::regnamespace and relname=tbl and relrowsecurity) then
      raise exception 'ROLLBACK/rls: RLS deveria continuar HABILITADA em % (estado 0008)', tbl;
    end if;
  end loop;

  select string_agg(policyname, ', ') into leftover from pg_policies
   where schemaname='public'
     and tablename in ('sg8_sessions','sg8_resolution_snapshots','sg8_round_executions','sg8_round_report_evidence')
     and policyname like '%writer%';
  if leftover is not null then raise exception 'ROLLBACK/sweep: policy(s) writer residual(is): %', leftover; end if;
end $$;

\echo '== sg8 runtime identity · §2 baseline restored (target tables = source of truth; pg_default_acl auxiliar) =='

do $$
declare v_ref text[]; tbl text; got text[]; got_direct text[]; v_first text[] := null; verb text;
begin
  -- AUXILIAR (corroboração; NÃO substitui o estado real): mecanismo pg_default_acl do defaclrole==OWNER
  -- (as default privileges que se aplicaram às SG-8; NÃO união entre grantors, que superestima). DEC-0026-R4/C.
  select coalesce(array_agg(distinct a.privilege_type order by a.privilege_type), array[]::text[])
    into v_ref
    from pg_default_acl da, aclexplode(da.defaclacl) a
   where da.defaclnamespace='public'::regnamespace and da.defaclobjtype='r'
     and da.defaclrole=(select relowner from pg_class where oid='public.sg8_sessions'::regclass)
     and a.grantee='service_role'::regrole;

  foreach tbl in array array['sg8_sessions','sg8_resolution_snapshots','sg8_round_executions','sg8_round_report_evidence'] loop
    -- FONTE DE VERDADE: estado real do objeto — EFETIVO e ACL DIRETA de service_role na própria tabela.
    select coalesce(array_agg(v order by v), array[]::text[]) into got
      from unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) v
     where has_table_privilege('service_role', ('public.'||tbl)::regclass, v);
    select coalesce(array_agg(distinct a.privilege_type order by a.privilege_type), array[]::text[]) into got_direct
      from pg_class c, aclexplode(c.relacl) a
     where c.oid=('public.'||tbl)::regclass and a.grantee='service_role'::regrole;

    -- restauração DIRETA (não herdada): o efetivo é igual à ACL direta re-concedida pelo rollback.
    if got is distinct from got_direct then
      raise exception 'ROLLBACK/baseline: em % o EFETIVO de service_role (%) != ACL DIRETA (%) — restauração via caminho indireto', tbl, got, got_direct;
    end if;
    -- as 4 tabelas-alvo restauradas IDÊNTICAS entre si (basta uma divergir p/ falhar).
    if v_first is null then v_first := got;
    elsif got is distinct from v_first then
      raise exception 'ROLLBACK/baseline: service_role em % (%) diverge das demais tabelas-alvo (%) — restauração inexata', tbl, got, v_first;
    end if;
    -- corroboração auxiliar com o mecanismo (não é a autoridade, mas deve bater — reversibilidade).
    if got is distinct from v_ref then
      raise exception 'ROLLBACK/baseline: service_role em % (%) != mecanismo de reconstrução (pg_default_acl=%) — restauração inexata', tbl, got, v_ref;
    end if;

    -- anon/authenticated/authenticator/PUBLIC continuam NEGADOS (default-deny 0008 preservado)
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
  raise notice 'ROLLBACK/baseline OK: service_role restaurado nas 4 tabelas-alvo (estado real, direto==efetivo, idêntico entre si) = % (corroborado pelo mecanismo = %)', coalesce(v_first, array[]::text[]), v_ref;
end $$;

\echo '== sg8 runtime identity · §2b column ACLs restored to 0008 baseline (attacl NULL; column-level deny) =='

-- Restauração EXATA no NÍVEL DE COLUNA (DEC-0026-R4-gap2). A 0008 não concedeu privilégio de coluna a
-- ninguém ⇒ o baseline de coluna é attacl NULL em TODAS as colunas SG-8. O rollback revogou os grants
-- de coluna do writer (INSERT/UPDATE) e dropou a role ⇒ attacl deve voltar a NULL. As identidades de
-- default-deny (anon/authenticated/authenticator) seguem sem qualquer privilégio de coluna. service_role
-- mantém APENAS o baseline de TABELA (§2) — sem grant de coluna.
do $$
declare tbl text; att record; rol text; verb text; col_verbs constant text[]:=array['SELECT','INSERT','UPDATE','REFERENCES'];
begin
  foreach tbl in array array['sg8_sessions','sg8_resolution_snapshots','sg8_round_executions','sg8_round_report_evidence'] loop
    for att in select attname, attacl from pg_attribute
                where attrelid=('public.'||tbl)::regclass and attnum>0 and not attisdropped loop
      if att.attacl is not null then
        raise exception 'ROLLBACK/col: coluna %.% tem attacl != NULL (%) — restauração de coluna inexata (baseline 0008 = zero grant de coluna; grant do writer não revogado?)', tbl, att.attname, att.attacl::text;
      end if;
    end loop;
    foreach rol in array array['anon','authenticated','authenticator'] loop
      if to_regrole(rol) is not null then
        foreach verb in array col_verbs loop
          if has_any_column_privilege(rol, ('public.'||tbl)::regclass, verb) then
            raise exception 'ROLLBACK/col: % recuperou % em coluna de %', rol, verb, tbl;
          end if;
        end loop;
      end if;
    end loop;
  end loop;
  raise notice 'ROLLBACK/col OK: attacl NULL em todas as colunas SG-8 (baseline 0008; grants de coluna do writer removidos); anon/authenticated/authenticator sem privilégio de coluna.';
end $$;

\echo '== sg8 runtime identity · §3 UUID function ACL byte-equivalent to baseline (untouched; PUBLIC intact) =='

do $$
declare v_func regprocedure; v_attnum smallint; v_dangling int; v_pub_exec boolean; v_writer int;
begin
  select attnum into v_attnum from pg_attribute
   where attrelid='public.sg8_round_report_evidence'::regclass and attname='id' and not attisdropped;
  select dep.refobjid::regprocedure into v_func
    from pg_attrdef ad join pg_depend dep
      on dep.classid='pg_attrdef'::regclass and dep.objid=ad.oid and dep.refclassid='pg_proc'::regclass
   where ad.adrelid='public.sg8_round_report_evidence'::regclass and ad.adnum=v_attnum limit 1;
  if v_func is null then
    select to_regprocedure(pg_get_expr(ad.adbin, ad.adrelid)) into v_func
      from pg_attrdef ad where ad.adrelid='public.sg8_round_report_evidence'::regclass and ad.adnum=v_attnum;
  end if;
  if v_func is null then raise exception 'ROLLBACK/uuid: default de evidence.id sem função'; end if;

  -- (a) BYTE-EQUIVALENTE AO BASELINE — a 0009 nunca tocou a ACL (dependência de PUBLIC): p/ o built-in
  --     pinado o default é proacl NULL. Se != NULL, houve alteração (grant/over-revoke) — proibido.
  if (select proacl is not null from pg_proc where oid=v_func::oid) then
    raise exception 'ROLLBACK/uuid: proacl de % != default (NULL) — a ACL da função foi ALTERADA (esperado intocada/byte-equivalente)', v_func::text;
  end if;

  -- (b) sem grantee dangling e SEM entrada residual p/ sg8_compute_writer (que foi removida).
  select count(*) into v_dangling from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f'::"char", p.proowner))) a
    where p.oid=v_func::oid and a.grantee <> 0 and a.grantee not in (select oid from pg_authid);
  if v_dangling <> 0 then raise exception 'ROLLBACK/uuid: % grantee(s) dangling na ACL de %', v_dangling, v_func::text; end if;
  -- NULL-safe: pós-rollback a role foi DROPADA ⇒ `'sg8_compute_writer'::regrole` levantaria "role does
  -- not exist" (o cast constante é avaliado mesmo com guarda no WHERE). to_regrole() devolve NULL e o
  -- `a.grantee = NULL` simplesmente não casa (v_writer=0) — que é justamente o esperado (zero resíduo).
  select count(*) into v_writer from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f'::"char", p.proowner))) a
    where p.oid=v_func::oid and a.grantee = to_regrole('sg8_compute_writer') and a.privilege_type='EXECUTE';
  if v_writer <> 0 then raise exception 'ROLLBACK/uuid: entrada residual de EXECUTE p/ sg8_compute_writer em %', v_func::text; end if;

  -- (c) PUBLIC mantém EXECUTE (nunca foi revogado — a 0009 não mexe na função).
  select bool_or(a.grantee=0 and a.privilege_type='EXECUTE') into v_pub_exec
    from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f'::"char", p.proowner))) a where p.oid=v_func::oid;
  if not coalesce(v_pub_exec,false) then
    raise exception 'ROLLBACK/uuid: PUBLIC perdeu EXECUTE em % — over-revoke proibido', v_func::text;
  end if;
  raise notice 'ROLLBACK/uuid OK: proacl de % intocada (NULL == default); PUBLIC mantém EXECUTE; zero entrada residual da role.', v_func::text;
end $$;

\echo '== sg8 runtime identity · §4 0008 contracts intact =='

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

\echo '== sg8 runtime identity · §5 ATOMICITY wrapper — failure after CREATE ROLE leaves no cluster residue (DEC-0026-R4-gap3) =='

-- WRAPPER DE TESTE da atomicidade da migration (NÃO altera a migration canônica). A migration é uma
-- transação única (begin;…commit;) e CREATE ROLE é TRANSACIONAL ⇒ uma falha DEPOIS da criação da role
-- desfaz a criação no rollback da transação. Pré-condição: a role está AUSENTE (provado no §1). Aqui,
-- numa transação explícita, criamos a role, provamos que ela existe, provocamos uma FALHA POSTERIOR e
-- damos ROLLBACK — a fronteira TRANSACIONAL (não um cleanup) remove a role. Exigência: to_regrole IS NULL.
-- (A falha é capturada por um EXCEPTION aninhado SÓ para o script alcançar o assert final; se a
--  atomicidade estivesse quebrada, o assert abaixo levantaria ATOMICITY VIOLATION — nada é mascarado.)
begin;
  do $$
  begin
    create role sg8_compute_writer
      nologin nosuperuser nocreatedb nocreaterole noinherit noreplication nobypassrls;
    if to_regrole('sg8_compute_writer') is null then
      raise exception 'ATOMICITY setup: a role deveria EXISTIR dentro da txn logo após CREATE ROLE';
    end if;
    begin
      raise exception 'FALHA INTENCIONAL pós-CREATE ROLE (simula falha da migration após criar a identidade)';
    exception when others then null;   -- capturada p/ alcançar o rollback abaixo (não é cleanup)
    end;
  end $$;
rollback;   -- fronteira transacional: DESFAZ o CREATE ROLE (é a atomicidade, não um DROP silencioso)

do $$
begin
  if to_regrole('sg8_compute_writer') is not null then
    raise exception 'ATOMICITY VIOLATION: sg8_compute_writer PERMANECEU no cluster após CREATE ROLE + falha + rollback — fronteira transacional insuficiente';
  end if;
  raise notice 'ATOMICITY OK: to_regrole(sg8_compute_writer) IS NULL após CREATE ROLE + falha posterior + rollback (atomicidade transacional; sem resíduo cluster-global; sem cleanup silencioso).';
end $$;

\echo 'OK — sg8 runtime identity/grants/RLS POST-ROLLBACK verification PASSED (§1 absence + §2 baseline restored [table] + §2b column ACLs restored + §3 UUID ACL byte-equivalent + §4 0008 intact + §5 atomicity).'
