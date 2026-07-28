-- ============================================================================
-- NOXUND · SG-8 Remote Promotion — R0 PREFLIGHT (READ-ONLY · anterior à 0008)
-- ----------------------------------------------------------------------------
-- DIAGNÓSTICO READ-ONLY do banco de PRODUÇÃO antes de qualquer apply da SG-8.
-- Executado por um único dispatch gated (Environment production-db) sob GO R0.
-- ESTE ARQUIVO NÃO APLICA NADA, NÃO CRIA/ALTERA/DROPA nada, NÃO toca o ledger.
--
-- FRONTEIRA READ-ONLY (vinculante): tudo roda em UMA sessão e UM snapshot —
--   BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY; SET LOCAL <timeouts>;
--   prova transaction_read_only='on'; qualquer escrita FALHA; termina em ROLLBACK.
--
-- IDENTIDADE DO EXECUTOR: roda com a MESMA identidade que o production-db usará
--   nos gates futuros (NÃO uma role read-only distinta) — R0 precisa diagnosticar
--   as CAPACIDADES REAIS do executor (§2). As capacidades são apenas RELATADAS,
--   NUNCA usadas nesta unidade.
--
-- ESTADO ESPERADO (pré-0008): as migrations 0008 e 0009 AUSENTES do ledger; os
--   objetos SG-8 (4 tabelas, enum, 3 guard functions, triggers, policies, a UNIQUE
--   reports_id_run_key, a role sg8_compute_writer) TODOS AUSENTES; PostgreSQL major
--   == 15; gen_random_uuid() em pg_catalog, sem shadowing, PUBLIC EXECUTE presente.
--   R0 NÃO espera que as tabelas da 0008 existam (é anterior à 0008).
--
-- VEREDITO: GREEN (ambiente exatamente compatível E objetos ausentes) ou RED
--   (divergência concreta). NUNCA "GREEN com observações" para preconditions.
--   Objeto SG-8 PARCIAL ⇒ RED + inventário completo; NÃO remover, NÃO normalizar.
--
-- PARÂMETROS (-v): expected_ref, expected_host — a identidade esperada do
--   production-db. O sentinel LOCAL desliga SOMENTE a checagem de identidade
--   remota (usado apenas no teste local descartável; o remoto passa o ref real).
--
-- SAÍDA: relatório humano sanitizado + BLOCO CANÔNICO determinístico (marcadores
--   R0-CANON) — sem connection string, senha, tokens ou valores de secret; sem
--   campos voláteis (pid/now/ip/porta ficam FORA do bloco canônico → digest estável).
--
-- Fontes: supabase/migrations/20260620000008_sg8_reconciliation_session.sql,
--         supabase/migrations/20260620000009_sg8_runtime_identity_grants_rls.sql,
--         docs/data/DATA-SG8-001-R0-preflight-report-format.md
-- ============================================================================

\set ON_ERROR_STOP on
\pset pager off
\timing off

-- Defaults dos parâmetros de identidade quando o caller não os fornece.
\if :{?expected_ref}
\else
  \set expected_ref 'LOCAL'
\endif
\if :{?expected_host}
\else
  \set expected_host 'LOCAL'
\endif

begin isolation level repeatable read read only;
set local statement_timeout = '30s';
set local lock_timeout = '5s';
set local idle_in_transaction_session_timeout = '60s';

-- ----------------------------------------------------------------------------
-- [0] PROVA DA FRONTEIRA READ-ONLY (fail-closed antes de qualquer inventário).
-- ----------------------------------------------------------------------------
do $$
begin
  if current_setting('transaction_read_only') <> 'on' then
    raise exception 'R0-FATAL: transaction_read_only=% (esperado on) — recusando prosseguir', current_setting('transaction_read_only');
  end if;
  raise notice 'R0 boundary: transaction_read_only=on';
end $$;

-- Qualquer ESCRITA deve falhar (CREATE é proibido em txn READ ONLY → SQLSTATE 25006).
-- Se a escrita SUCEDER, a fronteira está quebrada ⇒ RED FATAL (erro não capturado).
do $$
begin
  begin
    execute 'create temporary table _r0_write_probe (x int)';
    raise exception 'R0-FATAL: uma escrita (CREATE) SUCEDEU em txn READ ONLY — fronteira NÃO enforçada';
  exception
    when read_only_sql_transaction then
      raise notice 'R0 boundary: escrita rejeitada (SQLSTATE 25006) — fronteira enforçada';
  end;
end $$;

-- ----------------------------------------------------------------------------
-- [1] IDENTIDADE DO AMBIENTE (relatório humano). Sem secrets.
-- ----------------------------------------------------------------------------
\echo '== R0 §1 · Identidade do ambiente =='
select
  current_database()                                             as database,
  current_user                                                  as current_user,
  session_user                                                  as session_user,
  case when position('.' in current_user) > 0
       then split_part(current_user, '.', 2) else '<sem-ref-no-user>' end as observed_project_ref,
  :'expected_ref'                                               as expected_project_ref,
  :'expected_host'                                              as expected_hostname,
  host(coalesce(inet_server_addr(), '0.0.0.0'::inet))          as observed_server_ip,
  inet_server_port()                                           as observed_server_port,
  version()                                                    as pg_version_full,
  (current_setting('server_version_num')::int / 10000)         as pg_major,
  current_setting('search_path')                              as search_path;

\echo '== R0 §1 · Extensões relevantes =='
select e.extname, e.extversion, n.nspname as schema
  from pg_extension e join pg_namespace n on n.oid = e.extnamespace
 where e.extname in ('pgcrypto','uuid-ossp','pgsodium','supabase_vault','pg_stat_statements','pgjwt')
 order by e.extname;

-- ----------------------------------------------------------------------------
-- [2] CAPACIDADES REAIS DO EXECUTOR (apenas RELATADAS — NUNCA usadas em R0).
--     Segmentadas por gate futuro (R1/0008, R3/0009, R7/ALTER ROLE).
-- ----------------------------------------------------------------------------
\echo '== R0 §2 · Capacidades do executor (report-only; segmentadas por gate futuro) =='
select
  r.rolname,
  r.rolsuper, r.rolcreatedb, r.rolcreaterole, r.rolcanlogin, r.rolbypassrls, r.rolreplication,
  has_database_privilege(r.rolname, current_database(), 'CREATE')  as db_create,
  has_schema_privilege(r.rolname, 'public', 'USAGE')              as public_usage,
  has_schema_privilege(r.rolname, 'public', 'CREATE')             as public_create
  from pg_roles r where r.rolname = current_user;

\echo '   R1/0008 exige: CREATE no schema public (tabelas/enum/funcs/triggers) + owner das novas tabelas.'
\echo '   R3/0009 exige: CREATEROLE (criar sg8_compute_writer) + GRANT/REVOKE + CREATE POLICY nas tabelas 0008.'
\echo '   R7/ALTER ROLE exige (FUTURO, out-of-band): CREATEROLE|SUPERUSER p/ ALTER ROLE ... LOGIN PASSWORD.'

-- ----------------------------------------------------------------------------
-- [3] LEDGER REMOTO — inventário SEM presumir colunas. NÃO inserir/reparar/alterar.
-- ----------------------------------------------------------------------------
\echo '== R0 §3 · Ledger: existência / owner / RLS =='
select
  to_regclass('supabase_migrations.schema_migrations')                        as ledger_regclass,
  (to_regclass('supabase_migrations.schema_migrations') is not null)          as ledger_present,
  (select c.relowner::regrole::text from pg_class c
     where c.oid = to_regclass('supabase_migrations.schema_migrations'))       as ledger_owner,
  (select c.relrowsecurity from pg_class c
     where c.oid = to_regclass('supabase_migrations.schema_migrations'))       as ledger_rls;

\echo '== R0 §3 · Ledger: colunas (nome, tipo, nullability, default) =='
select a.attnum, a.attname,
       format_type(a.atttypid, a.atttypmod)              as data_type,
       (not a.attnotnull)                                as is_nullable,
       pg_get_expr(ad.adbin, ad.adrelid)                 as column_default
  from pg_attribute a
  left join pg_attrdef ad on ad.adrelid = a.attrelid and ad.adnum = a.attnum
 where a.attrelid = to_regclass('supabase_migrations.schema_migrations')
   and a.attnum > 0 and not a.attisdropped
 order by a.attnum;

\echo '== R0 §3 · Ledger: constraints =='
select conname, contype, pg_get_constraintdef(oid) as definition
  from pg_constraint
 where conrelid = to_regclass('supabase_migrations.schema_migrations')
 order by conname;

\echo '== R0 §3 · Ledger: indexes =='
select indexrelid::regclass::text as index_name, indisunique, indisprimary
  from pg_index where indrelid = to_regclass('supabase_migrations.schema_migrations')
 order by index_name;

\echo '== R0 §3 · Ledger: grants (relacl) =='
select coalesce(array_to_string(
         (select array_agg(distinct (a.grantee::regrole::text || ':' || a.privilege_type) order by (a.grantee::regrole::text || ':' || a.privilege_type))
            from pg_class c, aclexplode(c.relacl) a
           where c.oid = to_regclass('supabase_migrations.schema_migrations')), ', '),
       '<default/none>') as ledger_grants;

\echo '== R0 §3 · Ledger: CONTEÚDO COMPLETO ordenado (versões aplicadas) =='
select version,
       (version in ('20260620000008','20260620000009')) as is_sg8_target
  from supabase_migrations.schema_migrations
 order by version;

-- Bloco MÁQUINA (única sessão): versões do ledger, uma por linha, para o runner
-- comparar com o checkout (prefixo compatível / nada faltando / nada desconhecido /
-- nada pendente fora de {0008,0009}). NÃO altera o ledger.
\echo 'R0-LEDGER-START'
\pset format unaligned
\pset tuples_only on
select version from supabase_migrations.schema_migrations order by version;
\pset tuples_only off
\pset format aligned
\echo 'R0-LEDGER-END'

-- ----------------------------------------------------------------------------
-- [4] AUSÊNCIA DOS OBJETOS SG-8 — escopo EXATO (schema public + nomes exatos).
--     NÃO usar apenas contagem global por prefixo. Objeto PARCIAL ⇒ RED + inventário.
-- ----------------------------------------------------------------------------
\echo '== R0 §4 · Objetos SG-8 esperados AUSENTES (por nome exato, schema public) =='
select
  to_regclass('public.sg8_sessions')              as t_sessions,
  to_regclass('public.sg8_resolution_snapshots')  as t_snapshots,
  to_regclass('public.sg8_round_executions')      as t_rounds,
  to_regclass('public.sg8_round_report_evidence') as t_evidence,
  (select oid::regtype::text from pg_type t join pg_namespace n on n.oid=t.typnamespace
     where n.nspname='public' and t.typname='sg8_session_status')                 as enum_status,
  to_regprocedure('public.sg8_append_only_guard()')                               as fn_append_only,
  to_regprocedure('public.sg8_sessions_guard()')                                  as fn_sessions_guard,
  to_regprocedure('public.sg8_round_report_evidence_guard()')                     as fn_evidence_guard,
  (select count(*) from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace
     where n.nspname='public' and c.relname like 'sg8\_%')                        as sg8_policies,
  (select count(*) from pg_trigger tg join pg_class c on c.oid=tg.tgrelid join pg_namespace n on n.oid=c.relnamespace
     where n.nspname='public' and tg.tgname like 'sg8\_%' and not tg.tgisinternal) as sg8_triggers,
  (select 1 from pg_constraint where conname='reports_id_run_key'
     and conrelid = to_regclass('public.reports'))                                as reports_id_run_key,
  to_regrole('sg8_compute_writer')                                                as role_writer;

-- Inventário de QUALQUER objeto SG-8 parcial (deve retornar ZERO linhas em pré-0008).
\echo '== R0 §4 · Inventário de resíduos SG-8 (esperado: ZERO linhas) =='
select 'relation' as kind, n.nspname||'.'||c.relname as name, c.relkind::text as detail
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relname like 'sg8\_%'
union all
select 'type', n.nspname||'.'||t.typname, t.typtype::text
  from pg_type t join pg_namespace n on n.oid=t.typnamespace
 where n.nspname='public' and t.typname like 'sg8\_%'
union all
select 'routine', n.nspname||'.'||p.proname, pg_get_function_identity_arguments(p.oid)
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname like 'sg8\_%'
union all
select 'role', r.rolname, 'cluster-global'
  from pg_roles r where r.rolname = 'sg8_compute_writer'
 order by kind, name;

-- ----------------------------------------------------------------------------
-- [5] UUID — gen_random_uuid() de pg_catalog: existência, owner, shadowing, PUBLIC EXECUTE.
--     R0 NÃO alega ter provado o DEFAULT da 0008 (a tabela evidence ainda não existe) —
--     essa prova é POSTERIOR (R2/R2.5). Aqui só a função e sua ACL. Nada é alterado.
-- ----------------------------------------------------------------------------
\echo '== R0 §5 · gen_random_uuid() (função + ACL; NÃO prova o default da 0008) =='
select
  to_regprocedure('pg_catalog.gen_random_uuid()')                               as builtin_regproc,
  (to_regprocedure('pg_catalog.gen_random_uuid()') is not null)                 as builtin_present,
  (select p.oid from pg_proc p where p.oid = to_regprocedure('pg_catalog.gen_random_uuid()')::oid) as builtin_oid,
  (select p.proowner::regrole::text from pg_proc p
     where p.oid = to_regprocedure('pg_catalog.gen_random_uuid()')::oid)        as builtin_owner,
  to_regprocedure('gen_random_uuid()')                                          as unqualified_resolves_to,
  (to_regprocedure('gen_random_uuid()') = to_regprocedure('pg_catalog.gen_random_uuid()')) as no_shadowing,
  (select bool_or(a.grantee = 0 and a.privilege_type = 'EXECUTE')
     from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f'::"char", p.proowner))) a
    where p.oid = to_regprocedure('pg_catalog.gen_random_uuid()')::oid)         as public_execute,
  (select case when p.proacl is null then 'implicit-default-acl' else 'explicit-proacl' end
     from pg_proc p where p.oid = to_regprocedure('pg_catalog.gen_random_uuid()')::oid) as acl_origin;

-- ----------------------------------------------------------------------------
-- [6] BLOCO CANÔNICO (determinístico) — chaves ordenadas, SEM voláteis (pid/now/ip/porta
--     e version-string ficam de fora). O workflow calcula sha256 deste bloco + as checagens
--     de ledger-set (lado do runner) para o digest final. Também emite R0_VERDICT (DB-side).
-- ----------------------------------------------------------------------------
\echo 'R0-CANON-START'
\pset format unaligned
\pset tuples_only on
with facts as (
  select
    (current_setting('server_version_num')::int / 10000)                        as pg_major,
    (to_regclass('supabase_migrations.schema_migrations') is not null)          as ledger_present,
    coalesce((select bool_and(version <> '20260620000008') from supabase_migrations.schema_migrations), true) as v0008_absent,
    coalesce((select bool_and(version <> '20260620000009') from supabase_migrations.schema_migrations), true) as v0009_absent,
    (to_regclass('public.sg8_sessions') is null
       and to_regclass('public.sg8_resolution_snapshots') is null
       and to_regclass('public.sg8_round_executions') is null
       and to_regclass('public.sg8_round_report_evidence') is null)             as tables_absent,
    (not exists (select 1 from pg_type t join pg_namespace n on n.oid=t.typnamespace
        where n.nspname='public' and t.typname='sg8_session_status'))           as enum_absent,
    (to_regprocedure('public.sg8_append_only_guard()') is null
       and to_regprocedure('public.sg8_sessions_guard()') is null
       and to_regprocedure('public.sg8_round_report_evidence_guard()') is null) as funcs_absent,
    (not exists (select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
        where n.nspname='public' and c.relname like 'sg8\_%'))                  as relations_absent,
    (not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
        where n.nspname='public' and p.proname like 'sg8\_%'))                  as routines_absent,
    (not exists (select 1 from pg_constraint where conname='reports_id_run_key'
        and conrelid = to_regclass('public.reports')))                          as reports_constraint_absent,
    (to_regrole('sg8_compute_writer') is null)                                  as writer_absent,
    (to_regprocedure('pg_catalog.gen_random_uuid()') is not null)               as uuid_present,
    (to_regprocedure('gen_random_uuid()') = to_regprocedure('pg_catalog.gen_random_uuid()')) as uuid_no_shadowing,
    coalesce((select bool_or(a.grantee = 0 and a.privilege_type = 'EXECUTE')
       from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f'::"char", p.proowner))) a
      where p.oid = to_regprocedure('pg_catalog.gen_random_uuid()')::oid), false) as uuid_public_execute,
    case when :'expected_ref' = 'LOCAL' then true
         when position('.' in current_user) > 0
           then split_part(current_user, '.', 2) = :'expected_ref'
         else false end                                                          as env_ref_ok,
    (:'expected_ref' = 'LOCAL')                                                  as local_mode
), kv as (
  select 'acl_uuid_public_execute' as k, uuid_public_execute::text as v from facts
  union all select 'enum_absent',                 enum_absent::text            from facts
  union all select 'env_ref_ok',                  env_ref_ok::text             from facts
  union all select 'funcs_absent',                funcs_absent::text           from facts
  union all select 'ledger_present',              ledger_present::text         from facts
  union all select 'local_mode',                  local_mode::text             from facts
  union all select 'pg_major',                    pg_major::text               from facts
  union all select 'pg_major_ok',                 (pg_major = 15)::text        from facts
  union all select 'relations_absent',            relations_absent::text       from facts
  union all select 'reports_constraint_absent',   reports_constraint_absent::text from facts
  union all select 'routines_absent',             routines_absent::text        from facts
  union all select 'tables_absent',               tables_absent::text          from facts
  union all select 'uuid_no_shadowing',           uuid_no_shadowing::text      from facts
  union all select 'uuid_present',                uuid_present::text           from facts
  union all select 'v0008_absent',                v0008_absent::text           from facts
  union all select 'v0009_absent',                v0009_absent::text           from facts
  union all select 'writer_absent',               writer_absent::text          from facts
)
select k || '=' || v as canon_line from kv order by k;
\pset tuples_only off
\pset format aligned
\echo 'R0-CANON-END'

-- VEREDITO DB-side (o runner combina com as checagens de ledger-set antes do GREEN final).
\echo '== R0 · VEREDITO (DB-side) =='
select case when (
       (current_setting('server_version_num')::int / 10000) = 15
   and to_regclass('supabase_migrations.schema_migrations') is not null
   and coalesce((select bool_and(version <> '20260620000008') from supabase_migrations.schema_migrations), true)
   and coalesce((select bool_and(version <> '20260620000009') from supabase_migrations.schema_migrations), true)
   and to_regclass('public.sg8_sessions') is null
   and to_regclass('public.sg8_resolution_snapshots') is null
   and to_regclass('public.sg8_round_executions') is null
   and to_regclass('public.sg8_round_report_evidence') is null
   and not exists (select 1 from pg_type t join pg_namespace n on n.oid=t.typnamespace where n.nspname='public' and t.typname='sg8_session_status')
   and not exists (select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname like 'sg8\_%')
   and not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname like 'sg8\_%')
   and not exists (select 1 from pg_constraint where conname='reports_id_run_key' and conrelid = to_regclass('public.reports'))
   and to_regrole('sg8_compute_writer') is null
   and to_regprocedure('pg_catalog.gen_random_uuid()') is not null
   and (to_regprocedure('gen_random_uuid()') = to_regprocedure('pg_catalog.gen_random_uuid()'))
   and coalesce((select bool_or(a.grantee = 0 and a.privilege_type = 'EXECUTE')
          from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f'::"char", p.proowner))) a
         where p.oid = to_regprocedure('pg_catalog.gen_random_uuid()')::oid), false)
   and (:'expected_ref' = 'LOCAL'
        or (position('.' in current_user) > 0 and split_part(current_user, '.', 2) = :'expected_ref'))
     ) then 'R0_VERDICT=GREEN' else 'R0_VERDICT=RED' end as db_side_verdict;

rollback;
