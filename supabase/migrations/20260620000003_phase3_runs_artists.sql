-- ============================================================================
-- NOXUND · Migration — Fase 3: Runs + Artists (esqueleto)
-- ----------------------------------------------------------------------------
-- Tabelas: report_runs, artists, artist_aliases
-- run_id e artist_id são âncoras de quase tudo a seguir (raw Fase 4, computed Fase 5).
-- Esta fase cria SÓ o esqueleto de runs + identidade de artista.
--
-- Fontes vinculantes:
--   docs/database/migration-plan.md §Fase 3
--   context/04_Database_Event_Model.md §4 (report_runs) / §5 (artists, artist_aliases)
--   context/00_Product_Lead_Decision_Log.md §3 (vertical travada: 'chicago drill type beat' / 'Chicago Drill', janela 30d)
--   docs/database/mvp-data-model.md · DATA-AI-0001 (rubric_hash por-métrica em artist_metrics; OD-DB-01 unificado)
--   padrão de RLS/imutabilidade/atomicidade das Fases 1–2
--
-- HARD CONSTRAINTS:
--   • Raw imutável PRESERVADA: report_runs é a ÂNCORA de proveniência do raw — sua identidade
--     de coleta (keyword/vertical/janela) é congelada após criação e a linha NUNCA é apagada
--     (recoleta = novo run_id). Trigger garante isso ABAIXO do service_role (SEC-F01/SEC-F16).
--   • Zero tabela de marketplace/Fase 2-produto. Zero secret em repo/log/payload.
--   • Identidade/dedupe de artista ⇒ revisão Data/AI (matrix #5).
--
-- STATUS: AUTORADO, NÃO APLICADO. change_db_schema/run_migration seguem gated (humano +
--         required reviewers em CI), como nas Fases 1–2. Security re-revisa ESTE SQL (matrix #3).
-- Rollback: supabase/rollback/20260620000003_phase3_runs_artists.rollback.sql
-- Verify:   supabase/tests/phase3_post_apply_verify.sql (paridade §4/§5 com Fases 1–2)
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 0. Enums (guardados para idempotência segura)
-- ----------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'report_run_status') then
    create type public.report_run_status as enum ('created', 'collecting', 'processed', 'published', 'failed');
  end if;
  if not exists (select 1 from pg_type where typname = 'artist_alias_source') then
    create type public.artist_alias_source as enum ('regex', 'llm_assisted', 'human');
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- 1. report_runs  (ÂNCORA de proveniência; OD-DB-01 unificado)
--    STATE p/ status + contadores. Identidade de coleta (keyword/vertical/janela)
--    é IMUTÁVEL após criação. rubric_version/rubric_hash = ponteiro do rubric do
--    relatório PUBLICADO (nullable, set no publish); o rubric POR-SCORING vive em
--    artist_metrics (Fase 5, chave (run_id, artist_id, rubric_hash) — DATA-AI-0001).
-- ----------------------------------------------------------------------------
create table public.report_runs (
  id                    uuid primary key default gen_random_uuid(),   -- o run_id
  keyword               text not null default 'chicago drill type beat',  -- travada (§3)
  vertical              text not null default 'Chicago Drill',            -- travada (§3)
  window_start          timestamptz not null,
  window_end            timestamptz not null,
  target_video_count    int not null default 500,
  collected_video_count int,
  youtube_quota_used    int,
  status                public.report_run_status not null default 'created',
  rubric_version        text,   -- rubric do relatório publicado (nullable até publish)
  rubric_hash           text,
  created_at            timestamptz not null default now(),
  constraint report_runs_window_chk check (window_end >= window_start)
);

comment on table public.report_runs is
  'Âncora de proveniência (run_id). STATE (status/contadores); identidade de coleta congelada; recoleta = novo run_id.';

-- ----------------------------------------------------------------------------
-- 2. artists  (identidade canônica; STATE leve — correção/merge humano via audit_events)
-- ----------------------------------------------------------------------------
create table public.artists (
  id             uuid primary key default gen_random_uuid(),
  canonical_name text not null,
  created_at     timestamptz not null default now()
);

-- dedupe: um artista por nome canônico (conflito → revisão humana). [identidade ⇒ Data/AI #5]
create unique index artists_canonical_name_lower_uidx on public.artists (lower(canonical_name));

comment on table public.artists is
  'Identidade canônica do artista-alvo. Dedupe via artist_aliases; merge humano registrado em audit_events.';

-- ----------------------------------------------------------------------------
-- 3. artist_aliases  (variações → artista canônico; append-only por convenção)
-- ----------------------------------------------------------------------------
create table public.artist_aliases (
  id         uuid primary key default gen_random_uuid(),
  artist_id  uuid not null references public.artists (id) on delete cascade,
  alias      text not null,
  source     public.artist_alias_source not null,
  created_at timestamptz not null default now()
);

-- alias único global: evita dois artistas reivindicando o mesmo alias (conflito → revisão). [Data/AI #5]
create unique index artist_aliases_alias_lower_uidx on public.artist_aliases (lower(alias));
create index artist_aliases_artist_id_idx on public.artist_aliases (artist_id);

comment on table public.artist_aliases is
  'Variações de nome → artista canônico (source: regex/llm_assisted/human). Correções humanas adicionam linha + audit_events.';

-- ----------------------------------------------------------------------------
-- 4. Integridade de report_runs (proveniência do raw)
--    Congela identidade de coleta; bloqueia DELETE/TRUNCATE (linha-âncora nunca some).
--    NÃO congela status/contadores (STATE) nem rubric_* (Data/AI define o re-publish).
--    Duas funções: row-level (update/delete) e statement-level (truncate). search_path fixo.
-- ----------------------------------------------------------------------------
create or replace function public.report_runs_row_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'report_runs é âncora de proveniência — DELETE não permitido (recoleta = novo run_id)'
      using errcode = 'restrict_violation';
  end if;
  -- UPDATE: identidade de coleta é imutável após criação
  if new.keyword      is distinct from old.keyword
     or new.vertical  is distinct from old.vertical
     or new.window_start is distinct from old.window_start
     or new.window_end   is distinct from old.window_end then
    raise exception 'report_runs: identidade de coleta (keyword/vertical/janela) é imutável após criação'
      using errcode = 'restrict_violation';
  end if;
  return new;
end;
$$;

create trigger report_runs_row_guard
  before update or delete on public.report_runs
  for each row execute function public.report_runs_row_guard();

create or replace function public.report_runs_no_truncate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'report_runs é âncora de proveniência — TRUNCATE não permitido'
    using errcode = 'restrict_violation';
end;
$$;

create trigger report_runs_no_truncate
  before truncate on public.report_runs
  for each statement execute function public.report_runs_no_truncate();

-- ----------------------------------------------------------------------------
-- 5. RLS: ENABLE + default-deny (SEC-F13). Policies (server/admin-only) na Fase 9.
--    As 3 são internas — produtor nunca lê estas tabelas direto (vê report_items, Fase 5).
-- ----------------------------------------------------------------------------
alter table public.report_runs    enable row level security;
alter table public.artists        enable row level security;
alter table public.artist_aliases enable row level security;

-- ----------------------------------------------------------------------------
-- 6. Zero grant a anon/authenticated (SEC-F02/F13): revoke explícito sobre os defaults.
-- ----------------------------------------------------------------------------
revoke all on table public.report_runs    from anon, authenticated;
revoke all on table public.artists         from anon, authenticated;
revoke all on table public.artist_aliases  from anon, authenticated;

commit;
