-- ============================================================================
-- NOXUND · Migration — Fase 2: Versionamento (rubric + outcome weights)
-- ----------------------------------------------------------------------------
-- Tabelas: rubric_versions, outcome_weight_versions
-- Pré-requisito de computed: artist_metrics/report_runs (Fase 5) referenciam
-- rubric_version + rubric_hash. Esta fase cria SÓ a estrutura de versionamento.
--
-- Fontes vinculantes:
--   docs/database/migration-plan.md §Fase 2 (version único; hash determinístico)
--   context/00_Product_Lead_Decision_Log.md §7 (rubric MVP: componentes + pesos — PERSISTIR, não redecidir)
--   context/04_Database_Event_Model.md §11 (rubric_versions / outcome_weight_versions)
--   docs/database/mvp-data-model.md (campos) · padrão de RLS/imutabilidade da Fase 1
--
-- HARD CONSTRAINTS (do payload):
--   • NÃO alterar rubric/pesos nem o cálculo do Score — só estrutura de versionamento.
--     Qualquer mudança de rubric/Score ⇒ ESCALAR ao Orchestrator, não decidir aqui.
--   • rubric_hash é DETERMINÍSTICO e computado pelo data-engine (Data/AI) sobre a
--     serialização canônica do config_json. O Database NÃO fabrica hash nem gera número.
--   • Zero tabela de marketplace/Fase 2-produto. Zero secret em repo/log/payload.
--
-- STATUS: AUTORADO, NÃO APLICADO. change_db_schema/run_migration seguem gated
--         (humano + required reviewers), como na Fase 1. Security re-revisa ESTE SQL
--         (matrix #3) e Data/AI valida a fidelidade ao §7 (matrix #5) antes de qualquer apply.
-- Rollback: supabase/rollback/20260620000002_phase2_versioning.rollback.sql
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 1. rubric_versions
--    Versão imutável da fórmula de Score (§7). Base da reprodutibilidade: um relatório
--    congelado deve sempre recompor o mesmo Score sob o mesmo (version, hash).
--    config_json é OPACO ao banco (sem encodar semântica do rubric — evita drift).
-- ----------------------------------------------------------------------------
create table public.rubric_versions (
  id           uuid primary key default gen_random_uuid(),
  version      text not null,            -- ex.: 'score_rubric_2026_06_v1'
  config_json  jsonb not null,           -- componentes + pesos + normalização (do §7); opaco aqui
  hash         text not null,            -- rubric_hash DETERMINÍSTICO (computado pelo data-engine; NÃO fabricado aqui)
  active_from  timestamptz not null default now(),
  created_at   timestamptz not null default now(),
  constraint rubric_versions_version_key unique (version),
  -- alvo da FK futura por (rubric_version, rubric_hash) — Fase 5 (artist_metrics/report_runs).
  -- Postgres exige unique sobre EXATAMENTE as colunas referenciadas.
  constraint rubric_versions_version_hash_key unique (version, hash)
);

comment on table public.rubric_versions is
  'Versão imutável do rubric de Score (§7). Append-only: nova versão = nova linha. Interno (config_json nunca vai ao produtor).';

-- ----------------------------------------------------------------------------
-- 2. outcome_weight_versions
--    Mesma disciplina (version único + hash determinístico). Pesos para ANÁLISE futura
--    de producer_outcomes — nunca alteram Score nem exibição (04_ §11). Pode ficar vazia
--    no MVP; existe para evitar pesos hardcoded em eventos.
-- ----------------------------------------------------------------------------
create table public.outcome_weight_versions (
  id           uuid primary key default gen_random_uuid(),
  version      text not null,            -- ex.: 'outcome_weights_v1'
  config_json  jsonb not null,           -- pesos de análise; opaco aqui
  hash         text not null,            -- hash determinístico (computado fora do banco)
  created_at   timestamptz not null default now(),
  constraint outcome_weight_versions_version_key unique (version),
  constraint outcome_weight_versions_version_hash_key unique (version, hash)
);

comment on table public.outcome_weight_versions is
  'Versão imutável de pesos de outcome para análise futura (04_ §11). Append-only; não toca Score/exibição.';

-- ----------------------------------------------------------------------------
-- 3. Imutabilidade das versões publicadas
--    Editar uma versão in-place quebraria a auditoria de relatórios já congelados.
--    Princípio SEC-0003 §2: toda tabela append-only/imutável precisa do guard
--    UPDATE + DELETE + TRUNCATE (não só UPDATE/DELETE). Reaproveita uma função única
--    (levanta exceção p/ qualquer tg_op; não referencia NEW/OLD → serve row + statement).
--    [Decisão de integridade do Database — Security ratifica no re-review matrix #3.]
-- ----------------------------------------------------------------------------
create or replace function public.versioning_row_immutable()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception '% é versionada/append-only: % não é permitido — crie uma nova versão (nova linha)', tg_table_name, tg_op
    using errcode = 'restrict_violation';
end;
$$;

create trigger rubric_versions_no_update_delete
  before update or delete on public.rubric_versions
  for each row execute function public.versioning_row_immutable();
create trigger rubric_versions_no_truncate
  before truncate on public.rubric_versions
  for each statement execute function public.versioning_row_immutable();

create trigger outcome_weight_versions_no_update_delete
  before update or delete on public.outcome_weight_versions
  for each row execute function public.versioning_row_immutable();
create trigger outcome_weight_versions_no_truncate
  before truncate on public.outcome_weight_versions
  for each statement execute function public.versioning_row_immutable();

-- ----------------------------------------------------------------------------
-- 4. RLS: ENABLE + default-deny (SEC-F13). Policies (server/admin-only) ficam na Fase 9.
--    config_json/hash são INTERNOS — o produtor vê só 'X/100' + tooltip conceitual (§7),
--    nunca a fórmula. Escrita das versões é service-role/Data-AI (bypassa RLS).
-- ----------------------------------------------------------------------------
alter table public.rubric_versions          enable row level security;
alter table public.outcome_weight_versions  enable row level security;

-- ----------------------------------------------------------------------------
-- 5. Zero grant a anon/authenticated (SEC-F02/F13): revoke explícito sobre os defaults.
-- ----------------------------------------------------------------------------
revoke all on table public.rubric_versions         from anon, authenticated;
revoke all on table public.outcome_weight_versions from anon, authenticated;

commit;

-- ============================================================================
-- SEED TEMPLATE — rubric MVP (00_Product_Lead_Decision_Log.md §7) — NÃO executado aqui
-- ----------------------------------------------------------------------------
-- PERSISTE a decisão §7 SEM redecidir pesos. O `hash` é o rubric_hash DETERMINÍSTICO,
-- computado pelo data-engine (Data/AI) sobre a serialização canônica do config_json —
-- NÃO é fabricado pelo Database. Inserir coordenado com Data/AI (owner do rubric_hash):
--
--   insert into public.rubric_versions (version, config_json, hash, active_from)
--   values (
--     'score_rubric_2026_06_v1',
--     jsonb_build_object(
--       'components', jsonb_build_array(
--         jsonb_build_object('key','velocity_normalized',          'weight', 0.40, 'measures','views/dia do artista relativo à amostra de 500'),
--         jsonb_build_object('key','signals',                      'weight', 0.25, 'measures','vídeos válidos na janela, com penalização de excesso'),
--         jsonb_build_object('key','engagement_recency_weighted',  'weight', 0.20, 'measures','(likes+comments)/views, peso maior p/ vídeos recentes'),
--         jsonb_build_object('key','channel_diversity',            'weight', 0.15, 'measures','canais distintos validando a demanda')
--       ),
--       'weights_sum', 1.00,
--       'source', '00_Product_Lead_Decision_Log.md §7'
--     ),
--     '<rubric_hash computado deterministicamente pelo data-engine>',   -- NÃO fabricar
--     now()
--   );
--
-- Pesos do §7 (40/25/20/15) reproduzidos verbatim — qualquer alteração ⇒ ESCALAR ao Orchestrator.
-- ============================================================================
