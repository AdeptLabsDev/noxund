-- ============================================================================
-- NOXUND · Migration — Fase 6: producer_events (append-only)
-- ----------------------------------------------------------------------------
-- Tabela: producer_events — LOG imutável do comportamento real do produtor.
-- Fecha o laço de validação: feedback → intenção (MÉTRICA-NORTE) → follow-up.
-- "Eventos são log, não flags mutáveis" (04_ §1.3 / §8). Nenhum número de IA aqui:
-- são FATOS de comportamento; a zona determinística (Score) permanece intocada.
--
-- DESIGN-ONLY / BACKGROUND (DEC-0013 pipeline-first): AUTORADO, **NÃO APLICADO**.
-- Para em design_complete_no_apply. O apply gated (run_migration via phase6-db-apply.yml,
-- APPLY-PHASE6, Environment production-db, dispatch de `main`/SEC-F18) só é sequenciado
-- quando a captura de eventos virar gargalo — após o 1º relatório publicado (DEC-0013 §3).
--
-- Fontes vinculantes:
--   context/04_Database_Event_Model.md §8 (producer_events + enum) · §13 (métrica→evento→query)
--   context/01_MVP_Scope_PRD.md §4 (feedback/intenção/WTP) · §8 (métricas)
--   docs/database/migration-plan.md §Fase 6 · docs/product/mvp-backlog.md Épico 4 [DB]
--   DEC-0004 (RPC atômica evento+payload — camada de ESCRITA, fora deste DDL) · DEC-0013
--   padrão append-only de audit_events (Fase 1) e rubric_versions (Fase 2); SEC-D03/F16/F08/F13
--
-- HARD CONSTRAINTS (non-negotiables do payload):
--   • APPEND-ONLY / IMUTÁVEL: zero UPDATE/DELETE/TRUNCATE — guard por TRIGGER abaixo do
--     service_role (SEC-F16/F22). Evento é log puro; sem coluna/flag mutável de estado.
--   • PROVENIÊNCIA TOTAL: FK ON DELETE RESTRICT → producers/reports/report_items/artists.
--     Todo evento rastreável até o snapshot que o originou e, via report_items, até
--     raw_youtube_videos (cadeia da Fase 5). Nenhuma linha referenciada some.
--   • MÉTRICA-NORTE auditável: intent_to_produce_declared calculável por query (04_ §13) e
--     DEDUP por (producer_id, artist_id, report_id) — partial unique index — SEM quebrar o
--     caráter append-only (rejeita fato duplicado; nunca muta/apaga).
--   • DEFAULT-DENY: enable RLS + revoke; ZERO create policy / ZERO view executável
--     (Fase 9 vetada — SEC-0001 §0). event_type via ENUM (padrão Fases 1–5).
--   • PII/PRIVACIDADE: identidade do produtor via FK producer_id (server/admin-only); metadata
--     com CHECK SEC-F08 (sem envelope de request/secret). Detalhe de PII → Security (diferido).
--   • Número de código, nunca de IA: producer_events são fatos; zero cálculo/semântica de Score.
--   • Zero tabela de marketplace/Fase 2.
--
-- STATUS: AUTORADO, NÃO APLICADO. Revisões DIFERIDAS (até a captura virar gargalo):
--   Security & Privacy (matrix #3 — RLS/imutabilidade/PII), Data/AI (matrix #4/#5 —
--   auditabilidade da métrica-norte e do funil), Backend (contrato de escrita de evento).
-- Rollback: supabase/rollback/20260620000007_phase6_producer_events.rollback.sql
-- Verify:   supabase/tests/phase6_post_apply_verify.sql (paridade §4/§5 com Fases 1–5)
-- ORDENAÇÃO: renumerada 0006→0007 para a extensão aditiva entity_resolution_candidates
--            (DEC-0014, ts 0006) aplicar À FRENTE desta Fase 6 — ambas ainda NÃO aplicadas.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 0. Enum de event_type (canônico — 04_ §8). Cobre TODO o modelo de eventos do MVP
--    (não só o subconjunto em foco): aplicação, abertura/toggle, clique, feedback,
--    intenção (norte), follow-up e WTP. Guardado para idempotência segura.
-- ----------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'producer_event_type') then
    create type public.producer_event_type as enum (
      'application_submitted',
      'application_approved',
      'report_opened',
      'report_switched',
      'example_clicked',
      'artist_marked_useful',
      'artist_marked_not_useful',
      'intent_to_produce_declared',          -- MÉTRICA-NORTE (04_ §13) / kill-criteria
      'followup_sent',
      'followup_confirmed_produced',
      'followup_confirmed_not_produced',
      'wtp_yes',
      'wtp_no',
      'wtp_maybe'
    );
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- 1. producer_events  (APPEND-ONLY — log de comportamento real)
--    producer_id NOT NULL (todo evento tem dono). report_id/report_item_id/artist_id
--    OPCIONAIS (04_ §8) mas, quando presentes, referenciais com RESTRICT (proveniência).
--    metadata jsonb OPCIONAL (detalhes do evento); CHECK SEC-F08 barra envelope de request/secret.
--    FKs NOMEADAS (lição F5-07) p/ o verify identificar por nome.
-- ----------------------------------------------------------------------------
create table public.producer_events (
  id              uuid primary key default gen_random_uuid(),
  producer_id     uuid not null,
  event_type      public.producer_event_type not null,
  report_id       uuid,                      -- contexto do snapshot (opcional)
  report_item_id  uuid,                      -- linha do ranking (opcional) → cadeia até raw (Fase 5)
  artist_id       uuid,                      -- artista-alvo (opcional; obrigatório p/ intent — CHECK)
  metadata        jsonb,                     -- detalhes do evento (sem PII/secret — SEC-F08)
  created_at      timestamptz not null default now(),
  -- proveniência forte: nenhuma âncora referenciada por um evento pode ser apagada.
  constraint producer_events_producer_fk
    foreign key (producer_id)    references public.producers (id)     on delete restrict,
  constraint producer_events_report_fk
    foreign key (report_id)      references public.reports (id)       on delete restrict,
  constraint producer_events_report_item_fk
    foreign key (report_item_id) references public.report_items (id)  on delete restrict,
  constraint producer_events_artist_fk
    foreign key (artist_id)      references public.artists (id)       on delete restrict,
  -- MÉTRICA-NORTE: a intenção precisa do contexto (artista + relatório) para ser auditável e
  -- dedupável por (producer, artist, report). Garante o grão não-nulo do índice parcial abaixo.
  constraint producer_events_intent_context_chk
    check (event_type <> 'intent_to_produce_declared'
           or (artist_id is not null and report_id is not null)),
  -- SEC-F08: metadata é detalhe de produto, NUNCA envelope de transporte/secret.
  constraint producer_events_no_request_context
    check (metadata is null
           or not (metadata ?| array['config', 'request', 'headers', 'authorization', 'key']))
);

-- índice canônico do funil por produtor (migration-plan §Fase 6) + suporta o RESTRICT de producers.
create index producer_events_producer_type_created_idx
  on public.producer_events (producer_id, event_type, created_at);
-- métrica-norte e denominadores (04_ §13): count(distinct producer_id) por event_type.
create index producer_events_type_producer_idx
  on public.producer_events (event_type, producer_id);
-- suporte ao RESTRICT (delete-check do pai) + consultas por escopo.
create index producer_events_report_idx       on public.producer_events (report_id);
create index producer_events_report_item_idx  on public.producer_events (report_item_id);
create index producer_events_artist_idx       on public.producer_events (artist_id);

-- DEDUP do evento-norte SEM quebrar append-only: um único intent por (produtor, artista, relatório).
-- Índice PARCIAL único; o CHECK acima garante que as 3 colunas são não-nulas p/ intent (NULLs
-- não dedupam). Re-declarar intenção é no-op idempotente (unique_violation), nunca um UPDATE/DELETE.
create unique index producer_events_intent_dedup_uidx
  on public.producer_events (producer_id, artist_id, report_id)
  where event_type = 'intent_to_produce_declared';

comment on table public.producer_events is
  'APPEND-ONLY (04_ §8). Log de comportamento real do produtor; sem flag mutável. Proveniência por FK RESTRICT até producers/reports/report_items/artists (e até raw via Fase 5). Métrica-norte = intent_to_produce_declared (04_ §13), dedupada por (producer, artist, report).';

-- ----------------------------------------------------------------------------
-- 2. Imutabilidade (SEC-D03/F16) — append-only abaixo do service_role.
--    Grants/RLS não bastam: service_role bypassa RLS (SEC-F01) E mantém TRUNCATE. Uma função
--    única (levanta exceção p/ qualquer tg_op; não referencia NEW/OLD → serve row + statement),
--    espelhando audit_events (Fase 1) e rubric_versions (Fase 2). search_path fixo (higiene).
--    INSERT permanece permitido (append) — é a ÚNICA mutação válida.
-- ----------------------------------------------------------------------------
create or replace function public.producer_events_immutable()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'producer_events é append-only (log de comportamento real): % não é permitido — registre um novo evento', tg_op
    using errcode = 'restrict_violation';
end;
$$;

create trigger producer_events_no_update_delete
  before update or delete on public.producer_events
  for each row execute function public.producer_events_immutable();
create trigger producer_events_no_truncate
  before truncate on public.producer_events
  for each statement execute function public.producer_events_immutable();

-- ----------------------------------------------------------------------------
-- 3. RLS: ENABLE + default-deny (SEC-F13/F07). ZERO create policy — a leitura do produtor
--    (estado de UI deriva server-side) e as policies admin/produtor ficam na Fase 9, sob veto
--    do Security (SEC-0001 §0). Esta migration NÃO destrava nada.
-- ----------------------------------------------------------------------------
alter table public.producer_events enable row level security;

-- ----------------------------------------------------------------------------
-- 4. Zero grant a anon/authenticated (SEC-F02/F07/F13): revoke explícito sobre os defaults.
--    Escrita legítima é service-role/RPC atômica (DEC-0004); leitura é server/admin (Fase 9).
-- ----------------------------------------------------------------------------
revoke all on table public.producer_events from anon, authenticated;

commit;
