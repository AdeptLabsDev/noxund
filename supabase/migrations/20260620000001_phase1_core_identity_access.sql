-- ============================================================================
-- NOXUND · Migration — Fase 1: Core Identity / Access
-- ----------------------------------------------------------------------------
-- Tabelas: producers, applications, admin_users, audit_events
-- (audit_events ANTECIPADA da Fase 8 → Fase 1 por decisão do Security, SEC-0002 §3:
--  aprovação de produtor e grant/revoke de admin exigem trilha imutável desde a 1ª operação.)
--
-- Fontes vinculantes:
--   docs/security/SEC-0002-phase1-access-migration-review.md  (§5 condições de DDL, SEC-F15, §3 audit_events)
--   docs/security/SEC-0001-mvp-data-model-review.md            (SEC-D01/D02/D03, SEC-F12/F13/F02)
--   docs/database/mvp-data-model.md                            (campos por tabela)
--   docs/database/migration-plan.md                            (ordem de fases)
--   DEC-0005 (Auth = Supabase, OD-02 fechada)
--
-- STATUS: AUTORADO, NÃO APLICADO. change_db_schema/run_migration seguem gated (aprovação humana)
--         e o Security re-revisa ESTE SQL (SEC-0002 §5) ANTES de qualquer apply.
-- Rollback reversível: supabase/rollback/20260620000001_phase1_core_identity_access.rollback.sql
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 0. Enums (guardados para idempotência segura)
-- ----------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'producer_status') then
    create type public.producer_status as enum ('pending', 'approved', 'rejected', 'blocked');
  end if;
  if not exists (select 1 from pg_type where typname = 'application_status') then
    create type public.application_status as enum ('submitted', 'under_review', 'approved', 'rejected');
  end if;
  if not exists (select 1 from pg_type where typname = 'audit_actor_type') then
    create type public.audit_actor_type as enum ('admin', 'system', 'pipeline');
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- 1. producers
--    SEC-D01: auth_user_id FK → auth.users(id) UNIQUE, ON DELETE SET NULL
--             (deletar o auth user NÃO apaga o produtor nem sua PII/histórico; CASCADE proibido).
--    SEC-F12: nenhuma coluna de senha/hash/token/secret — identidade no Supabase Auth.
-- ----------------------------------------------------------------------------
create table public.producers (
  id            uuid primary key default gen_random_uuid(),
  auth_user_id  uuid unique references auth.users (id) on delete set null,
  email         text not null,
  display_name  text not null,
  youtube_url   text not null,
  portfolio_url text,
  niche         text not null,
  status        public.producer_status not null default 'pending',
  created_at    timestamptz not null default now(),
  approved_at   timestamptz,
  -- approved_at só faz sentido quando aprovado
  constraint producers_approved_at_chk
    check (status <> 'approved' or approved_at is not null)
);

-- idempotência de /apply por email normalizado (case-insensitive)
create unique index producers_email_lower_uidx on public.producers (lower(email));

comment on table public.producers is
  'Produtor (beatmaker). PII (email, URLs) — acesso só server/admin. auth_user_id provisionado só na aprovação (SEC-D01).';

-- ----------------------------------------------------------------------------
-- 2. applications
--    reviewed_by → auth.users(id) ON DELETE SET NULL (preserva o registro se o admin sumir).
--    Aplicante NÃO pode setar status/reviewed_by/approved (forçado server-side; default 'submitted').
-- ----------------------------------------------------------------------------
create table public.applications (
  id                      uuid primary key default gen_random_uuid(),
  producer_id             uuid not null references public.producers (id) on delete cascade,
  decision_process_answer text not null,
  intent_answer           text not null,
  status                  public.application_status not null default 'submitted',
  reviewed_by             uuid references auth.users (id) on delete set null,
  review_notes            text,
  created_at              timestamptz not null default now(),
  reviewed_at             timestamptz
);

-- no máximo UMA aplicação aberta por produtor
create unique index applications_one_open_per_producer_uidx
  on public.applications (producer_id)
  where status in ('submitted', 'under_review');

comment on table public.applications is
  'Aplicação de acesso. status evolui submitted→under_review→approved|rejected; decisão registrada em audit_events.';

-- ----------------------------------------------------------------------------
-- 3. admin_users  (SEC-D02)
--    Fonte ÚNICA e controlada por service-role de quem é admin. NUNCA derivar de user_metadata.
--    revoked_at desativa sem apagar histórico.
-- ----------------------------------------------------------------------------
create table public.admin_users (
  id           uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null unique references auth.users (id) on delete cascade,
  granted_by   uuid references auth.users (id) on delete set null,
  created_at   timestamptz not null default now(),
  revoked_at   timestamptz
);

comment on table public.admin_users is
  'Controle de segurança (SEC-D02). Lastreia is_admin(). Grant/revoke só por service-role + audit_events.';

-- ----------------------------------------------------------------------------
-- 4. audit_events  (SEC-0002 §3 — antecipada à Fase 1)
--    Append-only. actor_id é VALOR (sem FK) para sobreviver à deleção do auth user e
--    preservar "quem fez". Polimórfico por (entity_table, entity_id).
-- ----------------------------------------------------------------------------
create table public.audit_events (
  id           uuid primary key default gen_random_uuid(),
  actor_type   public.audit_actor_type not null,
  actor_id     uuid,                 -- auth user quando actor_type='admin'; null para system/pipeline
  action       text not null,        -- ex.: 'application.approved', 'admin.bootstrap', 'admin.granted'
  entity_table text not null,
  entity_id    uuid,
  before_json  jsonb,
  after_json   jsonb,
  reason       text,
  created_at   timestamptz not null default now()
);

create index audit_events_entity_idx  on public.audit_events (entity_table, entity_id);
create index audit_events_created_idx on public.audit_events (created_at);

comment on table public.audit_events is
  'Log append-only de ações sensíveis/overrides (SEC-D03). Imutável por trigger (UPDATE + DELETE + TRUNCATE) — service_role bypassa RLS e mantém TRUNCATE (SEC-F01/SEC-F16).';

-- ----------------------------------------------------------------------------
-- 5. Imutabilidade de audit_events por TRIGGER  (SEC-D03)
--    Grants/RLS não bastam: service_role faz bypass de RLS (SEC-F01) E mantém TRUNCATE.
--    Dois triggers barram UPDATE/DELETE (row-level) e TRUNCATE (statement-level), inclusive
--    via service-role (abaixo do bypass). Fecha SEC-F16 (SEC-0003 §2).
-- ----------------------------------------------------------------------------
create or replace function public.audit_events_immutable()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'audit_events is append-only: % is not permitted', tg_op
    using errcode = 'restrict_violation';
end;
$$;

create trigger audit_events_no_update_delete
  before update or delete on public.audit_events
  for each row execute function public.audit_events_immutable();

-- TRUNCATE é evento separado no Postgres e NÃO dispara trigger row-level: exige um trigger
-- statement-level. Reaproveita a mesma função (levanta exceção p/ qualquer tg_op; não
-- referencia NEW/OLD). Sem isto, service_role poderia TRUNCATE e apagar todo o log (SEC-F16).
create trigger audit_events_no_truncate
  before truncate on public.audit_events
  for each statement execute function public.audit_events_immutable();

-- ----------------------------------------------------------------------------
-- 6. is_admin()  (SEC-D02 + SEC-F15)
--    SECURITY DEFINER + search_path FIXO ('') + STABLE + referência QUALIFICADA a admin_users.
--    Fecha SEC-F15 (sequestro de resolução de nome em SECURITY DEFINER).
-- ----------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1
    from public.admin_users as a
    where a.auth_user_id = (select auth.uid())
      and a.revoked_at is null
  );
$$;

comment on function public.is_admin() is
  'SEC-D02/SEC-F15: raiz da autorização admin. SECURITY DEFINER + search_path fixo. Usado pelas policies da Fase 9.';

-- least privilege na função: zero a anon; execução só por authenticated/service_role
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 7. RLS: ENABLE + default-deny em TODAS as tabelas (SEC-F13)
--    Policies completas só na Fase 9. Caminhos legítimos da Fase 1 são service-role
--    (bypassa RLS), então default-deny não trava nada necessário.
-- ----------------------------------------------------------------------------
alter table public.producers    enable row level security;
alter table public.applications enable row level security;
alter table public.admin_users  enable row level security;
alter table public.audit_events enable row level security;

-- ----------------------------------------------------------------------------
-- 8. Zero grant a anon/authenticated (SEC-F02/F13)
--    A migration NÃO emite nenhum GRANT permissivo; revoga explicitamente (defesa em
--    profundidade sobre os defaults do Supabase). Re-grants seletivos vêm na Fase 9 com policies.
-- ----------------------------------------------------------------------------
revoke all on table public.producers    from anon, authenticated;
revoke all on table public.applications from anon, authenticated;
revoke all on table public.admin_users  from anon, authenticated;
revoke all on table public.audit_events from anon, authenticated;

commit;

-- ============================================================================
-- BOOTSTRAP DO 1º ADMIN  (SEC-0002 §5.5 — NÃO faz parte do forward migration)
-- ----------------------------------------------------------------------------
-- Sem auto-promoção: rodar MANUALMENTE por service-role, com um auth.users.id REAL,
-- numa transação que também grava audit_events. Template (NÃO executado aqui):
--
--   begin;
--     insert into public.admin_users (auth_user_id, granted_by)
--     values ('<REAL_AUTH_UUID>', null);
--     insert into public.audit_events (actor_type, actor_id, action, entity_table, entity_id, reason)
--     values ('system', null, 'admin.bootstrap', 'admin_users',
--             (select id from public.admin_users where auth_user_id = '<REAL_AUTH_UUID>'),
--             'Bootstrap do primeiro admin por service-role.');
--   commit;
--
-- Seeds de desenvolvimento: apenas dados fake (supabase/README.md). Nunca dados reais de produtor.
-- ============================================================================
