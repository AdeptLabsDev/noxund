-- ============================================================================
-- NOXUND · SG-8 Runtime Identity, Grants & RLS — POST-APPLY verification (U3A-GRANTS)
-- ----------------------------------------------------------------------------
-- Run by CI immediately after the canonical sequence applies
--   supabase/migrations/20260620000009_sg8_runtime_identity_grants_rls.sql
-- (a 0008 já aplicada). Paridade com os post-apply verifies das Fases 1–5 + 0008.
--
-- DESIGN-ONLY: autorado, NÃO aplicado. Exercita CATÁLOGO + COMPORTAMENTO REAL sob
--   `SET LOCAL ROLE sg8_compute_writer` (via set_config('role',…,true)) — não o runner.
--
-- NATUREZA:
--   §A  identidade: atributos EXATOS da role (NOLOGIN, NOBYPASSRLS, NOSUPERUSER, NOCREATEDB,
--       NOCREATEROLE, NOINHERIT, NOREPLICATION), SEM senha, zero memberships, zero ownership.
--   §B  matriz de grants (has_table/column/function/schema/database_privilege): SELECT nas 4;
--       INSERT SÓ nas colunas autorizadas (por tabela); UPDATE SÓ nas 5 de sg8_sessions;
--       comparison_contract_version SÓ INSERT (nunca UPDATE); evidence.id NÃO recebe INSERT;
--       EXECUTE no default UUID exato; CONNECT no db; USAGE (não CREATE) no schema public;
--       ZERO DELETE/TRUNCATE/REFERENCES/TRIGGER; ZERO UPDATE nas append-only; ZERO sequence.
--   §C  policies EXATAS: 9 policies, por tabela/operação, TODAS e SOMENTE TO sg8_compute_writer,
--       USING/WITH CHECK = true; sem DELETE; UPDATE só em sg8_sessions.
--   §D  isolamento das identidades amplas por PRIVILÉGIO EFETIVO (has_table_privilege): service_role,
--       anon, authenticated, authenticator, PUBLIC = ZERO; owner/admin NÃO é descrito como bloqueado.
--   §E  comportamento sob a role: SELECT nas 4; INSERT só nas colunas autorizadas; UPDATE só nas 5;
--       comparison_contract_version não atualizável; FSM/trigger decidem a legalidade (transição
--       inválida → restrict_violation; passed/failed válidos NÃO bloqueados pela policy); default
--       UUID funciona; UPDATE/DELETE append-only, DELETE/TRUNCATE/DDL e acesso aos parents negados.
--   §F  contratos da 0008 continuam GREEN (estrutura + o walk de PASS de §E prova FSM/PASS gate/append-only).
--
-- CONTRACT: todo check RAISES on mismatch → `psql -v ON_ERROR_STOP=1` sai não-zero, falha o CI.
-- SIDE EFFECTS: nenhum persistido — toda escrita de probe vive em transação revertida.
-- Role de conexão: `postgres` (superuser/session_user; membro implícito de tudo; pode SET ROLE).
-- ============================================================================

\set ON_ERROR_STOP on

\echo '== sg8 runtime identity · §A role identity =='

-- A role existe com o contrato TRANCADO, sem senha, sem membership, sem ownership.
do $$
declare
  r record; n int;
begin
  select oid, rolcanlogin, rolsuper, rolcreatedb, rolcreaterole, rolinherit, rolreplication, rolbypassrls
    into r from pg_roles where rolname = 'sg8_compute_writer';
  if r.oid is null then raise exception 'A/identity: role sg8_compute_writer AUSENTE'; end if;
  if r.rolcanlogin    then raise exception 'A/identity: role deve ser NOLOGIN';        end if;
  if r.rolsuper       then raise exception 'A/identity: role deve ser NOSUPERUSER';    end if;
  if r.rolcreatedb    then raise exception 'A/identity: role deve ser NOCREATEDB';     end if;
  if r.rolcreaterole  then raise exception 'A/identity: role deve ser NOCREATEROLE';   end if;
  if r.rolinherit     then raise exception 'A/identity: role deve ser NOINHERIT';      end if;
  if r.rolreplication then raise exception 'A/identity: role deve ser NOREPLICATION';  end if;
  if r.rolbypassrls   then raise exception 'A/identity: role deve ser NOBYPASSRLS';    end if;

  if (select rolpassword is not null from pg_authid where oid = r.oid) then
    raise exception 'A/identity: role NÃO pode ter senha (ativação é out-of-band)';
  end if;

  select count(*) into n from pg_auth_members where member = r.oid or roleid = r.oid;
  if n <> 0 then raise exception 'A/identity: role deve ter ZERO memberships, achou %', n; end if;

  select (select count(*) from pg_class     where relowner = r.oid)
       + (select count(*) from pg_type      where typowner = r.oid)
       + (select count(*) from pg_proc      where proowner = r.oid)
       + (select count(*) from pg_namespace where nspowner = r.oid) into n;
  if n <> 0 then raise exception 'A/identity: role deve ter ZERO ownership, achou % objeto(s)', n; end if;
end $$;

\echo '== sg8 runtime identity · §B grant matrix =='

-- CONNECT no database atual; USAGE (não CREATE) no schema public.
do $$
begin
  if not has_database_privilege('sg8_compute_writer', current_database(), 'CONNECT') then
    raise exception 'B/db: writer sem CONNECT no database atual';
  end if;
  if not has_schema_privilege('sg8_compute_writer', 'public', 'USAGE') then
    raise exception 'B/schema: writer sem USAGE em public';
  end if;
  if has_schema_privilege('sg8_compute_writer', 'public', 'CREATE') then
    raise exception 'B/schema: writer NÃO deveria ter CREATE em public';
  end if;
end $$;

-- SELECT nas 4 tabelas; DELETE/TRUNCATE/REFERENCES/TRIGGER NEGADOS nas 4;
-- table-level INSERT/UPDATE NÃO existem (só coluna); UPDATE table-level negado nas append-only.
do $$
declare tbl text;
begin
  foreach tbl in array array['sg8_sessions','sg8_resolution_snapshots','sg8_round_executions','sg8_round_report_evidence'] loop
    if not has_table_privilege('sg8_compute_writer', ('public.'||tbl)::regclass, 'SELECT') then
      raise exception 'B/select: writer sem SELECT em %', tbl;
    end if;
    if has_table_privilege('sg8_compute_writer', ('public.'||tbl)::regclass, 'DELETE') then
      raise exception 'B/deny: writer NÃO deveria ter DELETE em %', tbl;
    end if;
    if has_table_privilege('sg8_compute_writer', ('public.'||tbl)::regclass, 'TRUNCATE') then
      raise exception 'B/deny: writer NÃO deveria ter TRUNCATE em %', tbl;
    end if;
    if has_table_privilege('sg8_compute_writer', ('public.'||tbl)::regclass, 'REFERENCES') then
      raise exception 'B/deny: writer NÃO deveria ter REFERENCES em %', tbl;
    end if;
    if has_table_privilege('sg8_compute_writer', ('public.'||tbl)::regclass, 'TRIGGER') then
      raise exception 'B/deny: writer NÃO deveria ter TRIGGER em %', tbl;
    end if;
  end loop;
  -- UPDATE table-level negado nas 3 append-only (writer não tem UPDATE algum nelas).
  foreach tbl in array array['sg8_resolution_snapshots','sg8_round_executions','sg8_round_report_evidence'] loop
    if has_table_privilege('sg8_compute_writer', ('public.'||tbl)::regclass, 'UPDATE') then
      raise exception 'B/deny: writer NÃO deveria ter UPDATE em % (append-only)', tbl;
    end if;
  end loop;
end $$;

-- INSERT por coluna — MATRIZ EXATA. Autorizadas = true; qualquer outra coluna = false.
do $$
declare
  c text;
  -- (tabela, coluna) autorizadas a INSERT (espelham postgres_sg8._INSERT_*)
  granted text[][] := array[
    ['sg8_sessions','id'],['sg8_sessions','source_collection_run_id'],['sg8_sessions','comparison_contract_version'],
    ['sg8_resolution_snapshots','id'],['sg8_resolution_snapshots','sg8_session_id'],['sg8_resolution_snapshots','source_collection_run_id'],
    ['sg8_resolution_snapshots','resolver_version'],['sg8_resolution_snapshots','resolver_hash'],['sg8_resolution_snapshots','fact_count'],['sg8_resolution_snapshots','content_hash'],
    ['sg8_round_executions','id'],['sg8_round_executions','sg8_session_id'],['sg8_round_executions','round_number'],['sg8_round_executions','source_collection_run_id'],
    ['sg8_round_executions','resolution_snapshot_id'],['sg8_round_executions','compute_engine_name'],['sg8_round_executions','compute_engine_version'],['sg8_round_executions','compute_manifest_hash'],
    ['sg8_round_report_evidence','round_execution_id'],['sg8_round_report_evidence','sg8_session_id'],['sg8_round_report_evidence','report_id'],['sg8_round_report_evidence','canonical_digest']
  ];
  -- colunas que NÃO podem ter INSERT (amostra crítica, incluindo evidence.id e sessions.status)
  denied text[][] := array[
    ['sg8_sessions','status'],['sg8_sessions','report_id_1'],['sg8_sessions','report_id_2'],
    ['sg8_sessions','verdict_reason'],['sg8_sessions','terminal_at'],['sg8_sessions','created_at'],
    ['sg8_round_report_evidence','id'],['sg8_round_report_evidence','created_at'],
    ['sg8_resolution_snapshots','frozen_at'],['sg8_round_executions','created_at']
  ];
  i int;
begin
  for i in 1 .. array_length(granted,1) loop
    if not has_column_privilege('sg8_compute_writer', ('public.'||granted[i][1])::regclass, granted[i][2], 'INSERT') then
      raise exception 'B/insert-col: writer DEVERIA ter INSERT em %.%', granted[i][1], granted[i][2];
    end if;
  end loop;
  for i in 1 .. array_length(denied,1) loop
    if has_column_privilege('sg8_compute_writer', ('public.'||denied[i][1])::regclass, denied[i][2], 'INSERT') then
      raise exception 'B/insert-col: writer NÃO deveria ter INSERT em %.%', denied[i][1], denied[i][2];
    end if;
  end loop;
end $$;

-- UPDATE por coluna — SÓ sg8_sessions {status, report_id_1, report_id_2, terminal_at, verdict_reason}.
-- comparison_contract_version e as demais colunas de sessions = NEGADAS; qualquer coluna das outras
-- 3 tabelas = NEGADA.
do $$
declare
  c text;
  upd_granted text[] := array['status','report_id_1','report_id_2','terminal_at','verdict_reason'];
  upd_denied  text[] := array['comparison_contract_version','id','source_collection_run_id','created_at'];
begin
  foreach c in array upd_granted loop
    if not has_column_privilege('sg8_compute_writer', 'public.sg8_sessions'::regclass, c, 'UPDATE') then
      raise exception 'B/update-col: writer DEVERIA ter UPDATE em sg8_sessions.%', c;
    end if;
  end loop;
  foreach c in array upd_denied loop
    if has_column_privilege('sg8_compute_writer', 'public.sg8_sessions'::regclass, c, 'UPDATE') then
      raise exception 'B/update-col: writer NÃO deveria ter UPDATE em sg8_sessions.% (comparison_contract_version é INSERT-only/imutável)', c;
    end if;
  end loop;
  -- nenhuma coluna das 3 append-only pode ter UPDATE.
  if has_column_privilege('sg8_compute_writer', 'public.sg8_resolution_snapshots'::regclass, 'content_hash', 'UPDATE')
   or has_column_privilege('sg8_compute_writer', 'public.sg8_round_executions'::regclass, 'compute_manifest_hash', 'UPDATE')
   or has_column_privilege('sg8_compute_writer', 'public.sg8_round_report_evidence'::regclass, 'canonical_digest', 'UPDATE') then
    raise exception 'B/update-col: writer NÃO deveria ter UPDATE em coluna de tabela append-only';
  end if;
end $$;

-- EXECUTE no default UUID EXATO de evidence.id (descoberto no catálogo, não presumido).
do $$
declare v_func regprocedure; v_attnum smallint;
begin
  select attnum into v_attnum from pg_attribute
   where attrelid = 'public.sg8_round_report_evidence'::regclass and attname = 'id' and not attisdropped;
  select dep.refobjid::regprocedure into v_func
    from pg_attrdef ad join pg_depend dep
      on dep.classid='pg_attrdef'::regclass and dep.objid=ad.oid and dep.refclassid='pg_proc'::regclass
   where ad.adrelid='public.sg8_round_report_evidence'::regclass and ad.adnum=v_attnum limit 1;
  if v_func is null then  -- built-in pinado (sem pg_depend): resolve pelo texto do default
    select to_regprocedure(pg_get_expr(ad.adbin, ad.adrelid)) into v_func
      from pg_attrdef ad where ad.adrelid='public.sg8_round_report_evidence'::regclass and ad.adnum=v_attnum;
  end if;
  if v_func is null then raise exception 'B/uuid: default de evidence.id sem função'; end if;
  if not has_function_privilege('sg8_compute_writer', v_func::oid, 'EXECUTE') then
    raise exception 'B/uuid: writer sem EXECUTE em % (default UUID de evidence.id)', v_func::text;
  end if;
  raise notice 'B/uuid: EXECUTE confirmado em % para sg8_compute_writer', v_func::text;
end $$;

-- ZERO privilégio de sequence (as PKs são gen_random_uuid(); não há sequence SG-8). O LOOP garante
-- que has_sequence_privilege só é chamado sobre relkind='S' reais — um predicado combinado num
-- único SELECT poderia ser reordenado pelo planner e avaliar a função sobre uma TABELA ('X is not
-- a sequence'). Varre TODAS as sequences de public: o writer não deve ter privilégio em nenhuma.
do $$
declare r record;
begin
  for r in select c.oid, c.relname from pg_class c
            where c.relkind = 'S' and c.relnamespace = 'public'::regnamespace loop
    if has_sequence_privilege('sg8_compute_writer', r.oid, 'USAGE')
    or has_sequence_privilege('sg8_compute_writer', r.oid, 'SELECT')
    or has_sequence_privilege('sg8_compute_writer', r.oid, 'UPDATE') then
      raise exception 'B/sequence: writer tem privilégio na sequence % (esperado zero)', r.relname;
    end if;
  end loop;
end $$;

\echo '== sg8 runtime identity · §C policies (exact) =='

do $$
declare
  n int; bad text;
begin
  -- exatamente 9 policies nas 4 tabelas, TODAS TO {sg8_compute_writer}.
  select count(*) into n from pg_policies
   where schemaname='public' and tablename in
     ('sg8_sessions','sg8_resolution_snapshots','sg8_round_executions','sg8_round_report_evidence');
  if n <> 9 then raise exception 'C/policies: esperado 9 policies nas 4 tabelas, achou %', n; end if;

  -- toda policy é EXCLUSIVAMENTE TO sg8_compute_writer.
  select string_agg(policyname, ', ') into bad from pg_policies
   where schemaname='public'
     and tablename in ('sg8_sessions','sg8_resolution_snapshots','sg8_round_executions','sg8_round_report_evidence')
     and roles <> array['sg8_compute_writer']::name[];
  if bad is not null then raise exception 'C/policies: policy(s) com roles != {sg8_compute_writer}: %', bad; end if;

  -- nenhuma policy de DELETE/ALL.
  select string_agg(policyname, ', ') into bad from pg_policies
   where schemaname='public'
     and tablename in ('sg8_sessions','sg8_resolution_snapshots','sg8_round_executions','sg8_round_report_evidence')
     and cmd not in ('SELECT','INSERT','UPDATE');
  if bad is not null then raise exception 'C/policies: policy(s) de comando proibido (DELETE/ALL): %', bad; end if;

  -- contagem por tabela: sessions=3 (S/I/U); as outras 3 tabelas=2 (S/I).
  select string_agg(tablename||'='||c::text, ', ') into bad from (
    select tablename, count(*) c from pg_policies
     where schemaname='public'
       and tablename in ('sg8_sessions','sg8_resolution_snapshots','sg8_round_executions','sg8_round_report_evidence')
     group by tablename
  ) q where not (
    (tablename='sg8_sessions' and c=3) or
    (tablename in ('sg8_resolution_snapshots','sg8_round_executions','sg8_round_report_evidence') and c=2)
  );
  if bad is not null then raise exception 'C/policies: contagem por tabela inesperada: %', bad; end if;
end $$;

-- nomes/comando/quals EXATOS por policy.
do $$
declare
  spec text[][] := array[
    -- policyname, tablename, cmd, qual, with_check   (NULL representado por '')
    ['sg8_sessions_writer_select','sg8_sessions','SELECT','true',''],
    ['sg8_sessions_writer_insert','sg8_sessions','INSERT','','true'],
    ['sg8_sessions_writer_update','sg8_sessions','UPDATE','true','true'],
    ['sg8_resolution_snapshots_writer_select','sg8_resolution_snapshots','SELECT','true',''],
    ['sg8_resolution_snapshots_writer_insert','sg8_resolution_snapshots','INSERT','','true'],
    ['sg8_round_executions_writer_select','sg8_round_executions','SELECT','true',''],
    ['sg8_round_executions_writer_insert','sg8_round_executions','INSERT','','true'],
    ['sg8_round_report_evidence_writer_select','sg8_round_report_evidence','SELECT','true',''],
    ['sg8_round_report_evidence_writer_insert','sg8_round_report_evidence','INSERT','','true']
  ];
  i int; r record;
begin
  for i in 1 .. array_length(spec,1) loop
    select cmd, coalesce(qual,'') qual, coalesce(with_check,'') with_check, roles
      into r from pg_policies
     where schemaname='public' and tablename=spec[i][2] and policyname=spec[i][1];
    if not found then raise exception 'C/policy: ausente %.%', spec[i][2], spec[i][1]; end if;
    if r.cmd <> spec[i][3] then raise exception 'C/policy %: cmd % != %', spec[i][1], r.cmd, spec[i][3]; end if;
    if r.qual <> spec[i][4] then raise exception 'C/policy %: qual "%" != "%"', spec[i][1], r.qual, spec[i][4]; end if;
    if r.with_check <> spec[i][5] then raise exception 'C/policy %: with_check "%" != "%"', spec[i][1], r.with_check, spec[i][5]; end if;
    if r.roles <> array['sg8_compute_writer']::name[] then raise exception 'C/policy %: roles != {sg8_compute_writer}', spec[i][1]; end if;
  end loop;
end $$;

\echo '== sg8 runtime identity · §D broad-identity isolation (effective) + admin honesty =='

do $$
declare tbl text; rol text; verb text;
begin
  foreach tbl in array array['sg8_sessions','sg8_resolution_snapshots','sg8_round_executions','sg8_round_report_evidence'] loop
    -- identidades amplas: ZERO privilégio efetivo (grant/PUBLIC/membership/ownership).
    foreach rol in array array['service_role','anon','authenticated','authenticator'] loop
      if to_regrole(rol) is not null then
        foreach verb in array array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER'] loop
          if has_table_privilege(rol, ('public.'||tbl)::regclass, verb) then
            raise exception 'D/isolation: role % ainda tem % EFETIVO em %', rol, verb, tbl;
          end if;
        end loop;
      end if;
    end loop;
    -- PUBLIC sem concessão direta.
    if exists (select 1 from pg_class c, aclexplode(c.relacl) a
       where c.oid = ('public.'||tbl)::regclass and a.grantee = 0) then
      raise exception 'D/isolation: PUBLIC tem concessão direta em %', tbl;
    end if;
    -- service_role não é dono.
    if to_regrole('service_role') is not null
       and (select relowner from pg_class where oid=('public.'||tbl)::regclass) = 'service_role'::regrole then
      raise exception 'D/isolation: service_role é OWNER de %', tbl;
    end if;
    -- HONESTIDADE: o owner/admin NÃO é (nem é descrito como) bloqueado — segue com acesso pleno.
    if not has_table_privilege(
         (select relowner from pg_class where oid=('public.'||tbl)::regclass)::regrole::text,
         ('public.'||tbl)::regclass, 'SELECT') then
      raise exception 'D/honesty: o OWNER de % deveria manter acesso (isolamento é do service_role/anon/…, não do admin)', tbl;
    end if;
    if not has_table_privilege('postgres', ('public.'||tbl)::regclass, 'SELECT') then
      raise exception 'D/honesty: superuser postgres deveria manter SELECT em %', tbl;
    end if;
  end loop;
end $$;

\echo '== sg8 runtime identity · §E behavior under SET ROLE sg8_compute_writer =='

-- E1 — SELECT funcional nas 4 tabelas sob a role.
begin;
  do $$
  declare tbl text;
  begin
    -- membership transitória (revertida no rollback do bloco) só para habilitar o SET ROLE de
    -- TESTE: no stack Supabase o `postgres` NÃO é superuser e não é membro da role dedicada
    -- (contrato: zero memberships). §A já provou zero memberships no estado commitado; este grant
    -- vive só nesta transação revertida. postgres tem CREATEROLE ⇒ pode administrar role não-superuser.
    execute format('grant sg8_compute_writer to %I', current_user);
    perform set_config('role','sg8_compute_writer', true);
    foreach tbl in array array['sg8_sessions','sg8_resolution_snapshots','sg8_round_executions','sg8_round_report_evidence'] loop
      execute format('select 1 from public.%I limit 1', tbl);   -- não deve levantar
    end loop;
    perform set_config('role','postgres', true);
  end $$;
rollback;

-- E2 — INSERT autorizado funciona (status default) + INSERT nomeando coluna NÃO autorizada falha.
begin;
  do $$
  declare v_src uuid; v_sess uuid := gen_random_uuid(); v_st text;
  begin
    insert into public.report_runs (window_start, window_end) values (now()-interval '30 days', now()) returning id into v_src;
    -- membership transitória (revertida no rollback do bloco) só para habilitar o SET ROLE de
    -- TESTE: no stack Supabase o `postgres` NÃO é superuser e não é membro da role dedicada
    -- (contrato: zero memberships). §A já provou zero memberships no estado commitado; este grant
    -- vive só nesta transação revertida. postgres tem CREATEROLE ⇒ pode administrar role não-superuser.
    execute format('grant sg8_compute_writer to %I', current_user);
    perform set_config('role','sg8_compute_writer', true);

    -- autorizado: (id, source, contract) → status assume 'session_open'
    insert into public.sg8_sessions (id, source_collection_run_id, comparison_contract_version)
      values (v_sess, v_src, 'sg8-pass-v1');
    select status into v_st from public.sg8_sessions where id = v_sess;
    if v_st <> 'session_open' then raise exception 'E2: status default != session_open (got %)', v_st; end if;

    -- não autorizado: nomear `status` no INSERT → insufficient_privilege (sem INSERT nessa coluna)
    begin
      insert into public.sg8_sessions (id, source_collection_run_id, comparison_contract_version, status)
        values (gen_random_uuid(), v_src, 'sg8-pass-v1', 'r1_resolved');
      raise exception 'E2: INSERT nomeando coluna não autorizada (status) ACEITO';
    exception when insufficient_privilege then null; end;

    perform set_config('role','postgres', true);
  end $$;
rollback;

-- E3 — UPDATE só nas 5 colunas; comparison_contract_version NÃO atualizável; FSM/trigger decidem
--      (transição inválida → restrict_violation; failed válido NÃO bloqueado pela policy).
begin;
  do $$
  declare v_src uuid; v_sess uuid := gen_random_uuid();
  begin
    insert into public.report_runs (window_start, window_end) values (now()-interval '30 days', now()) returning id into v_src;
    -- membership transitória (revertida no rollback do bloco) só para habilitar o SET ROLE de
    -- TESTE: no stack Supabase o `postgres` NÃO é superuser e não é membro da role dedicada
    -- (contrato: zero memberships). §A já provou zero memberships no estado commitado; este grant
    -- vive só nesta transação revertida. postgres tem CREATEROLE ⇒ pode administrar role não-superuser.
    execute format('grant sg8_compute_writer to %I', current_user);
    perform set_config('role','sg8_compute_writer', true);
    insert into public.sg8_sessions (id, source_collection_run_id, comparison_contract_version)
      values (v_sess, v_src, 'sg8-pass-v1');

    -- UPDATE autorizado (status) — avanço válido de 1 passo.
    update public.sg8_sessions set status='r1_awaiting_review' where id=v_sess;

    -- FSM/trigger DECIDEM a legalidade (não a policy): salto inválido → restrict_violation.
    begin
      update public.sg8_sessions set status='r1_computed' where id=v_sess;  -- salto
      raise exception 'E3: transição inválida ACEITA (policy não deve permitir bypass da FSM)';
    exception when restrict_violation then null; end;

    -- comparison_contract_version NÃO atualizável (sem privilégio de coluna) → insufficient_privilege.
    begin
      update public.sg8_sessions set comparison_contract_version='sg8-pass-v2' where id=v_sess;
      raise exception 'E3: UPDATE de comparison_contract_version ACEITO';
    exception when insufficient_privilege then null; end;

    -- failed de estado não-terminal é VÁLIDO e NÃO é bloqueado pela policy (usa as 3 colunas autorizadas).
    update public.sg8_sessions set status='failed', terminal_at=now(), verdict_reason='aborted mid-flow' where id=v_sess;

    perform set_config('role','postgres', true);
  end $$;
rollback;

-- E4 — negativas sem fixtures (privilégio é checado no plano): UPDATE/DELETE append-only, DELETE,
--      TRUNCATE, DDL e acesso aos parents — todos negados à role.
begin;
  do $$
  begin
    -- membership transitória (revertida no rollback do bloco) só para habilitar o SET ROLE de
    -- TESTE: no stack Supabase o `postgres` NÃO é superuser e não é membro da role dedicada
    -- (contrato: zero memberships). §A já provou zero memberships no estado commitado; este grant
    -- vive só nesta transação revertida. postgres tem CREATEROLE ⇒ pode administrar role não-superuser.
    execute format('grant sg8_compute_writer to %I', current_user);
    perform set_config('role','sg8_compute_writer', true);

    -- UPDATE nas append-only → insufficient_privilege
    begin update public.sg8_resolution_snapshots set content_hash='x' where false;
      raise exception 'E4: UPDATE em snapshot ACEITO'; exception when insufficient_privilege then null; end;
    begin update public.sg8_round_executions set compute_manifest_hash='x' where false;
      raise exception 'E4: UPDATE em round ACEITO'; exception when insufficient_privilege then null; end;
    begin update public.sg8_round_report_evidence set canonical_digest='x' where false;
      raise exception 'E4: UPDATE em evidence ACEITO'; exception when insufficient_privilege then null; end;

    -- DELETE em qualquer SG-8 → insufficient_privilege
    begin delete from public.sg8_sessions where false;
      raise exception 'E4: DELETE em sessions ACEITO'; exception when insufficient_privilege then null; end;
    begin delete from public.sg8_round_report_evidence where false;
      raise exception 'E4: DELETE em evidence ACEITO'; exception when insufficient_privilege then null; end;

    -- TRUNCATE → insufficient_privilege
    begin truncate public.sg8_sessions;
      raise exception 'E4: TRUNCATE ACEITO'; exception when insufficient_privilege then null; end;

    -- DDL (não é owner) → insufficient_privilege
    begin execute 'alter table public.sg8_sessions add column zzz_probe int';
      raise exception 'E4: DDL (ALTER) ACEITO'; exception when insufficient_privilege then null; end;

    -- acesso aos PARENTS → insufficient_privilege (SELECT negado em reports/report_runs/rubric_versions)
    begin execute 'select 1 from public.reports limit 1';
      raise exception 'E4: SELECT em reports ACEITO'; exception when insufficient_privilege then null; end;
    begin execute 'select 1 from public.report_runs limit 1';
      raise exception 'E4: SELECT em report_runs ACEITO'; exception when insufficient_privilege then null; end;
    begin execute 'select 1 from public.rubric_versions limit 1';
      raise exception 'E4: SELECT em rubric_versions ACEITO'; exception when insufficient_privilege then null; end;

    perform set_config('role','postgres', true);
  end $$;
rollback;

-- E5 — WALK COMPLETO até `passed` sob a role: prova que a policy NÃO bloqueia a transição terminal
--      válida (FSM/PASS gate decidem) E que o default UUID de evidence funciona sob a role. Todos os
--      ids que o adapter fornece explicitamente são gerados como postgres (o único uso de UUID sob a
--      role é o DEFAULT de evidence.id — o teste real).
begin;
  do $$
  declare
    v_src uuid; v_rep1 uuid; v_rep2 uuid;
    v_sess uuid := gen_random_uuid(); v_snap uuid := gen_random_uuid();
    v_r1 uuid := gen_random_uuid(); v_r2 uuid := gen_random_uuid();
    v_final text; v_evid int;
    c_mh constant text := 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
  begin
    -- parents como postgres
    insert into public.rubric_versions (version, config_json, hash) values ('sg8-vr','{}'::jsonb,'h');
    insert into public.report_runs (window_start, window_end) values (now()-interval '30 days', now()) returning id into v_src;
    insert into public.reports (run_id, title, rubric_version, rubric_hash) values (v_src,'R1','sg8-vr','h') returning id into v_rep1;
    insert into public.reports (run_id, title, rubric_version, rubric_hash) values (v_src,'R2','sg8-vr','h') returning id into v_rep2;

    -- daqui em diante, TUDO como sg8_compute_writer
    -- membership transitória (revertida no rollback do bloco) só para habilitar o SET ROLE de
    -- TESTE: no stack Supabase o `postgres` NÃO é superuser e não é membro da role dedicada
    -- (contrato: zero memberships). §A já provou zero memberships no estado commitado; este grant
    -- vive só nesta transação revertida. postgres tem CREATEROLE ⇒ pode administrar role não-superuser.
    execute format('grant sg8_compute_writer to %I', current_user);
    perform set_config('role','sg8_compute_writer', true);

    insert into public.sg8_sessions (id, source_collection_run_id, comparison_contract_version)
      values (v_sess, v_src, 'sg8-pass-v1');
    update public.sg8_sessions set status='r1_awaiting_review' where id=v_sess;
    update public.sg8_sessions set status='r1_resolved'        where id=v_sess;
    update public.sg8_sessions set status='r1_snapshot_frozen' where id=v_sess;
    insert into public.sg8_resolution_snapshots
      (id, sg8_session_id, source_collection_run_id, resolver_version, resolver_hash, fact_count, content_hash)
      values (v_snap, v_sess, v_src, 'entity-resolver-v1','rhash',500,'chash');
    update public.sg8_sessions set report_id_1=v_rep1, report_id_2=v_rep2, status='r1_computed' where id=v_sess;
    insert into public.sg8_round_executions
      (id, sg8_session_id, round_number, source_collection_run_id, resolution_snapshot_id,
       compute_engine_name, compute_engine_version, compute_manifest_hash)
      values (v_r1, v_sess, 1, v_src, v_snap, 'noxund-pipeline','pipeline-wiring-2026_06_v1', c_mh);
    insert into public.sg8_round_executions
      (id, sg8_session_id, round_number, source_collection_run_id, resolution_snapshot_id,
       compute_engine_name, compute_engine_version, compute_manifest_hash)
      values (v_r2, v_sess, 2, v_src, v_snap, 'noxund-pipeline','pipeline-wiring-2026_06_v1', c_mh);
    -- EVIDÊNCIA: adapter NÃO fornece id → default gen_random_uuid() sob a role (prova EXECUTE do §3).
    insert into public.sg8_round_report_evidence (round_execution_id, sg8_session_id, report_id, canonical_digest) values (v_r1, v_sess, v_rep1, 'DIG-A');
    insert into public.sg8_round_report_evidence (round_execution_id, sg8_session_id, report_id, canonical_digest) values (v_r1, v_sess, v_rep2, 'DIG-B');
    insert into public.sg8_round_report_evidence (round_execution_id, sg8_session_id, report_id, canonical_digest) values (v_r2, v_sess, v_rep1, 'DIG-A');
    insert into public.sg8_round_report_evidence (round_execution_id, sg8_session_id, report_id, canonical_digest) values (v_r2, v_sess, v_rep2, 'DIG-B');

    -- prova que o default UUID gerou 4 ids válidos (não-nulos) sob a role
    select count(*) into v_evid from public.sg8_round_report_evidence where sg8_session_id=v_sess and id is not null;
    if v_evid <> 4 then raise exception 'E5: default UUID não preencheu evidence.id sob a role (achou % de 4)', v_evid; end if;

    -- transição terminal VÁLIDA para passed → NÃO bloqueada pela policy (FSM/PASS gate aprovam)
    update public.sg8_sessions set status='passed', terminal_at=now(), verdict_reason='byte-identical R1==R2' where id=v_sess;

    select status into v_final from public.sg8_sessions where id=v_sess;
    if v_final <> 'passed' then raise exception 'E5: writer não conseguiu PASS válido (got %)', v_final; end if;

    perform set_config('role','postgres', true);
  end $$;
rollback;

\echo '== sg8 runtime identity · §F 0008 contracts still GREEN =='

-- Estrutura da 0008 intacta (a 0009 é aditiva; NÃO toca tabelas/enum/triggers/FSM).
do $$
declare n int; missing text;
begin
  -- 4 tabelas + RLS habilitada
  foreach missing in array array['sg8_sessions','sg8_resolution_snapshots','sg8_round_executions','sg8_round_report_evidence'] loop
    if not exists (select 1 from pg_class where relnamespace='public'::regnamespace and relname=missing and relrowsecurity) then
      raise exception 'F/0008: tabela % ausente ou RLS desabilitada', missing;
    end if;
  end loop;
  -- enum de 7 rótulos
  select count(*) into n from pg_enum e join pg_type t on t.oid=e.enumtypid where t.typname='sg8_session_status';
  if n <> 7 then raise exception 'F/0008: sg8_session_status deve ter 7 rótulos, achou %', n; end if;
  -- 3 funções de integridade
  select string_agg(want,', ') into missing from (values
    ('sg8_append_only_guard'),('sg8_sessions_guard'),('sg8_round_report_evidence_guard')) as t(want)
   where not exists (select 1 from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace where ns.nspname='public' and p.proname=t.want);
  if missing is not null then raise exception 'F/0008: função(ões) de integridade ausente(s): %', missing; end if;
  -- 8 triggers (guards + no-truncate)
  select string_agg(want,', ') into missing from (values
    ('sg8_sessions_guard'),('sg8_sessions_no_truncate'),
    ('sg8_resolution_snapshots_immutable'),('sg8_resolution_snapshots_no_truncate'),
    ('sg8_round_executions_immutable'),('sg8_round_executions_no_truncate'),
    ('sg8_round_report_evidence_guard'),('sg8_round_report_evidence_no_truncate')) as t(want)
   where not exists (select 1 from pg_trigger where not tgisinternal and tgname=t.want);
  if missing is not null then raise exception 'F/0008: trigger(s) ausente(s): %', missing; end if;
  -- CHECKs-chave (PASS gate / manifesto / contrato de comparação) presentes
  select string_agg(want,', ') into missing from (values
    ('sg8_sessions_terminal_state_chk'),('sg8_sessions_comparison_contract_v1_chk'),
    ('sg8_round_executions_manifest_hash_format_chk'),('sg8_round_executions_compute_provenance_nonblank_chk')) as t(want)
   where not exists (select 1 from pg_constraint where contype='c' and conname=t.want);
  if missing is not null then raise exception 'F/0008: CHECK(s) ausente(s): %', missing; end if;
end $$;
-- Nota: FSM, PASS gate, append-only e o contrato de comparação foram exercitados FUNCIONALMENTE
--       em §E (walk completo até passed + transição inválida rejeitada) sob a role dedicada.

\echo 'OK — sg8 runtime identity/grants/RLS post-apply verification PASSED (§A identity + §B grants + §C policies + §D isolation + §E behavior + §F 0008-green).'
