-- ============================================================================
-- NOXUND · Migration — entity_resolution_candidates (extensão ADITIVA · DEC-0014)
-- ----------------------------------------------------------------------------
-- Fila DURÁVEL de candidatos da Entity Resolution AINDA não aprovados — mantém a
-- saída de IA NÃO-revisada FORA das tabelas canônicas (artists / video_artist_mappings).
-- É staging / review queue: tabela MUTÁVEL por design (status pending→approved/rejected),
-- NÃO um snapshot congelado, NÃO append-only. A decisão humana e o override são logados
-- em audit_events (replay por chave natural run_id+video_id) e, no scoring, congelados em
-- artist_metrics.metrics_detail_json.overrides[] (F5-06A) — NÃO nesta tabela.
--
-- ADITIVO, NÃO DESTRUTIVO (DEC-0014 §3): ZERO ALTER de video_artist_mappings ou de qualquer
-- tabela aplicada/congelada (Fase 5). Só CREATE de tabela/enum/índices novos. Reusa o enum
-- public.video_artist_method (Fase 5) — não recria.
--
-- DESIGN-ONLY: AUTORADO, **NÃO APLICADO**. Roda em paralelo à implementação do engine
-- (caminho longo); a reprodutibilidade (P5-REPRO-01) não depende desta tabela — ela entrega
-- integridade/limpeza da FILA de revisão. Apply gated próprio (workflow dedicado, confirmação,
-- Environment production-db, dispatch de `main`/SEC-F18), após revisões Database+Security+Data/AI.
--
-- ORDENAÇÃO: ts 0006 — aplica À FRENTE da Fase 6 producer_events (renumerada 0006→0007).
--
-- Fontes vinculantes:
--   docs/product/decisions/DEC-0014-entity-resolution-candidates-extension.md
--   docs/data/DATA-ENTITY-001-entity-resolution-spec.md (§2 estado lógico · §6 fila · §7 projeção · §8 replay)
--   supabase/migrations/20260620000005_phase5_computed_metrics_reports.sql (video_artist_mappings L198–212; enum)
--   DATA-AI-0007 (F5-05 metrics_detail_json · F5-06A overrides/versions) · DEC-0013 (pipeline-first)
--
-- HARD CONSTRAINTS (non-negotiables do payload):
--   • DEFAULT-DENY: enable RLS + revoke; ZERO create policy / ZERO view executável (Fase 9 vetada — SEC-0001 §0).
--   • ZERO número / ZERO Score: é fila de NOMES (proposed_name STRING), nunca de métricas; IA não gera número.
--   • PROVENIÊNCIA: FK composta (run_id, video_id) → raw_youtube_videos ON DELETE RESTRICT — todo
--     candidato rastreável até o raw (igual ao mapping canônico). run_id → report_runs RESTRICT.
--   • PII MÍNIMA: nome de artista de título público; tratado sob default-deny. Sem coluna jsonb livre
--     (logo, sem vetor SEC-F08 nesta camada); proposed_name/review_notes são texto sob default-deny.
--   • MUTÁVEL por design: status transiciona; NÃO há trigger de imutabilidade (provar o que É garantido).
--   • Atômica (begin/commit); rollback declarado.
--
-- STATUS: AUTORADO, NÃO APLICADO. Revisões ANTES do apply: Database (autor), Security & Privacy
--         (matrix #3 — RLS/PII), Data/AI (matrix — integridade da fila + coerência com replay).
-- Rollback: supabase/rollback/20260620000006_entity_resolution_candidates.rollback.sql
-- Verify:   supabase/tests/entity_resolution_candidates_post_apply_verify.sql (§4/§5)
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 0. Enum NOVO de status da fila (guardado p/ idempotência). O enum de método
--    (public.video_artist_method) é REUSADO da Fase 5 — NÃO recriado aqui.
-- ----------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'entity_candidate_status') then
    create type public.entity_candidate_status as enum ('pending', 'approved', 'rejected');
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- 1. entity_resolution_candidates  (STAGING / review queue — MUTÁVEL)
--    proposed_name é STRING (span do título sustentado pelo guardrail §3 da spec), nunca um
--    artist_id. artist_id é NULLABLE: preenchido só quando/se resolvido a um artista existente
--    (regex §4.2 / aprovação humana); null para novo/desconhecido até a decisão — assim um
--    candidato não-aprovado NÃO cria linha em artists nem em video_artist_mappings.
-- ----------------------------------------------------------------------------
create table public.entity_resolution_candidates (
  id               uuid primary key default gen_random_uuid(),
  run_id           uuid not null references public.report_runs (id) on delete restrict,
  video_id         text not null,
  proposed_name    text not null,                          -- span do título (STRING; nunca artist_id)
  artist_id        uuid references public.artists (id) on delete restrict,  -- só se resolvido; null até aprovação
  method           public.video_artist_method not null,    -- enum REUSADO da Fase 5
  resolver_version text not null,                          -- determinística (entity-resolver-v1); nunca vazia
  prompt_version   text,                                   -- versão do prompt restrito (Agente 3) quando llm_assisted
  status           public.entity_candidate_status not null default 'pending',
  review_notes     text,                                   -- motivo humano legível (texto; sob default-deny)
  reviewed_at      timestamptz,                            -- set na decisão humana
  created_at       timestamptz not null default now(),
  -- proveniência forte: o vídeo do candidato existe no raw (run_id, video_id); raw é indeletável.
  constraint entity_resolution_candidates_raw_video_fk
    foreign key (run_id, video_id) references public.raw_youtube_videos (run_id, video_id) on delete restrict,
  -- replay/auditoria do fallback LLM exige a versão do prompt (determinismo do Agente 3).
  constraint entity_resolution_candidates_llm_prompt_chk
    check (method <> 'llm_assisted' or prompt_version is not null),
  -- candidato revisado (approved/rejected) carrega o carimbo da decisão (espelha reports_published_at_chk).
  constraint entity_resolution_candidates_reviewed_at_chk
    check (status = 'pending' or reviewed_at is not null),
  -- DATA-ENTITY-F01: NOT NULL garante PRESENÇA, não CONTEÚDO — '' / só-espaços passariam e
  -- quebrariam o determinismo/replay (versão não-rastreável). CHECK non-blank garante conteúdo.
  -- resolver_version é NOT NULL → btrim(...) é boolean definido (sem armadilha de CHECK-NULL).
  constraint entity_resolution_candidates_resolver_version_nonblank_chk
    check (btrim(resolver_version) <> ''),
  -- prompt_version é NULLABLE — PRESERVAR a nullabilidade (regex determinístico tem prompt null);
  -- só rejeitar string em branco quando PRESENTE. Coerente com llm_prompt_chk.
  constraint entity_resolution_candidates_prompt_version_nonblank_chk
    check (prompt_version is null or btrim(prompt_version) <> '')
);

-- FILA limpa: no máximo UM candidato PENDING por (run, vídeo). Índice PARCIAL único — não
-- bloqueia o histórico (approved/rejected coexistem); impede dois pendentes competindo pelo
-- mesmo vídeo e força resolver o atual antes de propor outro (mapping canônico já é unique
-- (run_id, video_id); aqui dedupamos só o CORRENTE, preservando a trilha de tentativas).
create unique index entity_resolution_candidates_pending_uidx
  on public.entity_resolution_candidates (run_id, video_id)
  where status = 'pending';

-- drenagem da fila (mais antigos primeiro) só sobre pendentes.
create index entity_resolution_candidates_pending_queue_idx
  on public.entity_resolution_candidates (created_at)
  where status = 'pending';

-- dashboards de revisão por run/estado (+ cobre o RESTRICT de report_runs — leading run_id).
create index entity_resolution_candidates_run_status_idx
  on public.entity_resolution_candidates (run_id, status);

-- lookup por artista resolvido (+ cobre o RESTRICT de artists). Parcial: a maioria é null até aprovar.
create index entity_resolution_candidates_artist_idx
  on public.entity_resolution_candidates (artist_id)
  where artist_id is not null;

comment on table public.entity_resolution_candidates is
  'STAGING/review queue (MUTÁVEL, DEC-0014) da Entity Resolution — candidatos pendentes mantidos FORA de artists/video_artist_mappings. proposed_name=string; artist_id nullable até aprovação. Proveniência por FK composta → raw. Decisão/override em audit_events; congelado no scoring em metrics_detail_json.overrides[]. SEM número, SEM freeze.';

-- ----------------------------------------------------------------------------
-- 2. RLS: ENABLE + default-deny (SEC-F13). ZERO create policy — escrita/leitura são
--    server/admin (resolver + tela de revisão); policies eventuais ficam na Fase 9 (vetada —
--    SEC-0001 §0). Esta migration NÃO destrava nada. (Tabela mutável: SEM trigger de imutabilidade.)
-- ----------------------------------------------------------------------------
alter table public.entity_resolution_candidates enable row level security;

-- ----------------------------------------------------------------------------
-- 3. Zero grant a anon/authenticated (SEC-F02/F13): revoke explícito sobre os defaults.
-- ----------------------------------------------------------------------------
revoke all on table public.entity_resolution_candidates from anon, authenticated;

commit;
