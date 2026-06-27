-- ============================================================================
-- NOXUND · Migration — Fase 4: Raw YouTube Snapshots (imutável)
-- ----------------------------------------------------------------------------
-- Tabelas: raw_youtube_search_pages, raw_youtube_videos, raw_youtube_channels
-- O RAW é a FONTE ÚLTIMA de todo número exibido (02_ §8). O computed (Fase 5) é
-- RECONSTRUÍVEL a partir daqui; o raw, NUNCA. Ancorado em report_runs (Fase 3):
-- recoleta = NOVO run_id — jamais update/overwrite de linha raw.
--
-- Fontes vinculantes:
--   docs/database/migration-plan.md §Fase 4
--   context/04_Database_Event_Model.md §4 (raw snapshots)
--   docs/database/mvp-data-model.md · Grupo C (raw_youtube_*) + §"Separação Raw/Computed/Snapshot"
--   docs/security/SEC-0001-mvp-data-model-review.md ·
--     SEC-D03 (trigger de imutabilidade OBRIGATÓRIO em raw), SEC-F01 (service_role bypassa RLS),
--     SEC-F08 (scrub de contexto de request / nenhum secret no payload), SEC-F13 (default-deny)
--   padrão de RLS/imutabilidade/atomicidade das Fases 1–3
--
-- HARD CONSTRAINTS:
--   • RAW SAGRADO: nenhuma rota de UPDATE/DELETE. Imutabilidade por TRIGGER
--     BEFORE UPDATE/DELETE (row) + BEFORE TRUNCATE (statement) — porque o service_role faz
--     BYPASS de RLS (SEC-F01); grants/RLS NÃO bastam (SEC-D03/SEC-F16). Trigger fica ABAIXO
--     do service_role, no banco.
--   • Unicidade lógica: (run_id, video_id) e (run_id, channel_id); página por (run_id, page_token).
--   • SEC-F08: o payload guarda só o CORPO da resposta (verbatim). Contexto de request
--     (URL com ?key=, headers de Authorization, envelope axios/fetch) é REJEITADO por CHECK —
--     nenhuma API key/secret persiste no raw. O schema não oferece coluna para isso.
--   • FK por run_id → report_runs (proveniência da Fase 3); ON DELETE RESTRICT.
--   • Zero tabela de marketplace/Fase 2. Zero secret em repo/log/payload.
--
-- STATUS: AUTORADO, NÃO APLICADO. change_db_schema/run_migration seguem gated (humano +
--         required reviewers em CI), como nas Fases 1–3. Security re-revisa ESTE SQL (matrix #3);
--         Data/AI revisa a imutabilidade do raw (matrix #4).
-- Rollback: supabase/rollback/20260620000004_phase4_raw_youtube_snapshots.rollback.sql
-- Verify:   supabase/tests/phase4_post_apply_verify.sql (paridade §4/§5 com Fases 1–3)
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 0. Guards de imutabilidade do RAW (compartilhados pelas 3 tabelas)
--    O raw é TOTALMENTE imutável: qualquer UPDATE/DELETE/TRUNCATE é barrado,
--    inclusive abaixo do service_role (que faz bypass de RLS — SEC-F01).
--    DRY: uma função row-level (update/delete) e uma statement-level (truncate),
--    reusadas pelas 3 tabelas. search_path fixo (higiene; usam só tg_op/built-ins).
-- ----------------------------------------------------------------------------
create or replace function public.raw_youtube_immutable()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'raw snapshot é imutável — % não permitido (recoleta = novo run_id)', tg_op
    using errcode = 'restrict_violation';
end;
$$;

create or replace function public.raw_youtube_no_truncate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'raw snapshot é imutável — TRUNCATE não permitido'
    using errcode = 'restrict_violation';
end;
$$;

-- ----------------------------------------------------------------------------
-- 1. raw_youtube_search_pages — payload bruto de cada página de search.list
--    Reconstrói exatamente quais vídeos a busca retornou (page_token + total).
-- ----------------------------------------------------------------------------
create table public.raw_youtube_search_pages (
  id            uuid primary key default gen_random_uuid(),
  run_id        uuid not null references public.report_runs (id) on delete restrict,
  page_token    text,                          -- null = 1ª página
  response_json jsonb not null,                -- CORPO da resposta, verbatim
  fetched_at    timestamptz not null default now(),
  -- SEC-F08: rejeita envelope de transport/request (axios/fetch) que carregaria a key.
  -- Corpo legítimo do YouTube nunca tem estas chaves no topo → zero falso-positivo.
  constraint raw_youtube_search_pages_no_request_context
    check (not (response_json ?| array['config', 'request', 'headers', 'authorization', 'key']))
);

-- chave lógica de página: uma linha por (run, page_token); 1ª página (null) = slot único.
create unique index raw_youtube_search_pages_run_page_uidx
  on public.raw_youtube_search_pages (run_id, coalesce(page_token, ''));

comment on table public.raw_youtube_search_pages is
  'RAW (insert-only, imutável por trigger). Página bruta de search.list por run. Recoleta = novo run_id.';

-- ----------------------------------------------------------------------------
-- 2. raw_youtube_videos — snapshot bruto de cada vídeo (fonte última do número)
--    Contadores em bigint: viewCount de vídeos virais excede int32 → int32 daria
--    erro de overflow no insert e corromperia "a fonte última de todo número".
--    Nullable: stats podem estar ocultas (ausente ≠ zero). raw_json é a verdade.
-- ----------------------------------------------------------------------------
create table public.raw_youtube_videos (
  id           uuid primary key default gen_random_uuid(),
  run_id       uuid not null references public.report_runs (id) on delete restrict,
  video_id     text not null,
  channel_id   text not null,
  title        text,
  published_at timestamptz,
  views        bigint,
  likes        bigint,
  comments     bigint,
  raw_json     jsonb not null,                 -- payload completo, verbatim
  fetched_at   timestamptz not null default now(),
  constraint raw_youtube_videos_no_request_context
    check (not (raw_json ?| array['config', 'request', 'headers', 'authorization', 'key']))
);

-- unicidade lógica: um snapshot por (run, video). Mesmo video em outra run = novo snapshot.
create unique index raw_youtube_videos_run_video_uidx
  on public.raw_youtube_videos (run_id, video_id);
-- join vídeo→canal (Fase 5: elegibilidade/Competition).
create index raw_youtube_videos_run_channel_idx
  on public.raw_youtube_videos (run_id, channel_id);

comment on table public.raw_youtube_videos is
  'RAW (insert-only, imutável por trigger). Snapshot bruto por vídeo. Unicidade lógica (run_id, video_id).';

-- ----------------------------------------------------------------------------
-- 3. raw_youtube_channels — snapshot bruto de canais (Channel Filter / Competition)
--    subscriber/view em bigint (view_count de canais grandes excede int32).
--    Nulos = ausente, não zero (canal pode ocultar stats).
-- ----------------------------------------------------------------------------
create table public.raw_youtube_channels (
  id               uuid primary key default gen_random_uuid(),
  run_id           uuid not null references public.report_runs (id) on delete restrict,
  channel_id       text not null,
  title            text,
  upload_count     bigint,
  subscriber_count bigint,
  view_count       bigint,
  raw_json         jsonb not null,
  fetched_at       timestamptz not null default now(),
  constraint raw_youtube_channels_no_request_context
    check (not (raw_json ?| array['config', 'request', 'headers', 'authorization', 'key']))
);

create unique index raw_youtube_channels_run_channel_uidx
  on public.raw_youtube_channels (run_id, channel_id);

comment on table public.raw_youtube_channels is
  'RAW (insert-only, imutável por trigger). Snapshot bruto por canal. Unicidade lógica (run_id, channel_id).';

-- ----------------------------------------------------------------------------
-- 4. Triggers de imutabilidade nas 3 tabelas (row: update/delete · statement: truncate)
-- ----------------------------------------------------------------------------
create trigger raw_youtube_search_pages_immutable
  before update or delete on public.raw_youtube_search_pages
  for each row execute function public.raw_youtube_immutable();
create trigger raw_youtube_search_pages_no_truncate
  before truncate on public.raw_youtube_search_pages
  for each statement execute function public.raw_youtube_no_truncate();

create trigger raw_youtube_videos_immutable
  before update or delete on public.raw_youtube_videos
  for each row execute function public.raw_youtube_immutable();
create trigger raw_youtube_videos_no_truncate
  before truncate on public.raw_youtube_videos
  for each statement execute function public.raw_youtube_no_truncate();

create trigger raw_youtube_channels_immutable
  before update or delete on public.raw_youtube_channels
  for each row execute function public.raw_youtube_immutable();
create trigger raw_youtube_channels_no_truncate
  before truncate on public.raw_youtube_channels
  for each statement execute function public.raw_youtube_no_truncate();

-- ----------------------------------------------------------------------------
-- 5. RLS: ENABLE + default-deny (SEC-F13). Sem policies — raw é INTERNO
--    (produtor nunca lê raw; vê report_items na Fase 5). Policies eventuais
--    (admin/server) ficam para a Fase 9 — esta migration NÃO as introduz.
-- ----------------------------------------------------------------------------
alter table public.raw_youtube_search_pages enable row level security;
alter table public.raw_youtube_videos       enable row level security;
alter table public.raw_youtube_channels     enable row level security;

-- ----------------------------------------------------------------------------
-- 6. Zero grant a anon/authenticated (SEC-F02/F13): revoke explícito sobre os defaults.
-- ----------------------------------------------------------------------------
revoke all on table public.raw_youtube_search_pages from anon, authenticated;
revoke all on table public.raw_youtube_videos       from anon, authenticated;
revoke all on table public.raw_youtube_channels     from anon, authenticated;

commit;
