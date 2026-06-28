-- ============================================================================
-- NOXUND · Migration — Fase 5: Computed Metrics + Resolução + Relatório
-- ----------------------------------------------------------------------------
-- Tabelas (nesta ordem de FK): video_artist_mappings, channel_eligibility,
--   artist_metrics, artist_metric_videos, reports, report_items.
-- Fecha a cadeia raw → computed → snapshot. COMPUTED é RECONSTRUÍVEL a partir do
-- raw (Fase 4 live) por run_id + rubric_hash/rule_version/resolver_version; SNAPSHOT
-- (reports/report_items) é CONGELADO no publish. Relatório reconstruível por run_id +
-- (rubric_version, rubric_hash) + versões determinísticas dos inputs.
--
-- >>> CORREÇÃO PÓS-VETO DATA/AI (DATA-AI-0005 · DATA-F5-01..07) <<<
-- Esta revisão FECHA os 7 achados de integridade/reprodutibilidade do veto, SEM
-- regredir o que foi aprovado e SEM transformar as 3 tabelas COMPUTED em append-only:
--   F5-01 freeze do snapshot agora cobre INSERT/UPDATE/DELETE (valida pai de NEW e de OLD);
--   F5-02 coerência report→item→metric por FKs COMPOSTAS (mesmo run_id, artist_id,
--         rubric_version, rubric_hash) — o par de rubric é congelado no próprio report;
--   F5-03 freeze CONDICIONAL: artist_metrics referenciada por item publicado/archived é
--         inviolável (UPDATE/DELETE bloqueados); métrica não-publicada segue recompute-livre;
--   F5-04 proveniência REFERENCIAL até o raw: tabela normalizada artist_metric_videos
--         (inputs da métrica, FK composta → raw) e FK composta de report_items.example_video_id;
--   F5-05 evidência de auditoria OBRIGATÓRIA: metrics_detail_json e selection_reason_json NOT NULL;
--   F5-06 fecha o rebuild: channel_eligibility.rule_version NOT NULL +
--         video_artist_mappings.resolver_version NOT NULL (versões determinísticas pré-scoring);
--   F5-07 FK nomeada explicitamente report_items_artist_metric_fk (alinhada ao verify).
--
-- >>> 2ª ITERAÇÃO — CORREÇÃO PÓS RE-VETO (DATA-AI-0006 · DATA-RR-F5-03A/05A/06A/01A) <<<
-- Fecha os follow-on das próprias correções, de forma holística (anti-bypass):
--   F5-03A junction guard valida OLD (origem) E NEW (destino) SEPARADAMENTE — sem coalesce que
--         deixe OLD vencer: mover input de métrica não-publicada → publicada falha (restrict_violation).
--         artist_metrics guard ganha checagem defensiva de NEW. Provado nos 2 role-paths.
--   F5-05A {} não é auditoria: CHECK ESTRUTURAL (chaves obrigatórias não-vazias) via funções
--         IMMUTABLE artist_metrics_detail_complete()/report_item_reason_complete() — storage-only
--         (zero threshold/número). publish rejeita {}/seções ausentes; evidência congelada é imutável.
--   F5-06A o contrato de evidência carrega OBRIGATORIAMENTE versões efetivas
--         (rubric/resolver/rule) + overrides replayable preservando a chave natural
--         (run_id, video_id)/(run_id, channel_id) — não depende de tabela mutável nem só de audit_events.
--   F5-01A verify completa o 2º role-path do probe move draft→published.
--   FK count: removida a FK inline duplicada de report_items.artist_id (fica só a nomeada).
-- P5-REPRO-01 (prova canônica de 2 rodadas) é precondição do DATA-ENGINE/primeiro publish, NÃO
--   deste apply — registrada no handoff. Inserts SQL não substituem a prova do data-engine.
--
-- Fontes vinculantes:
--   docs/database/DATA-AI-0006-phase5-rereview.md (re-veto DATA-RR-F5-03A/05A/06A/01A)
--   docs/database/DATA-AI-REVIEW-phase5-computed-metrics-reports.md (DATA-AI-0005 — veto)
--   docs/database/migration-plan.md §Fase 5
--   context/04_Database_Event_Model.md §5/§6/§7 · context/03_…§5–§10 (metodologia)
--   docs/database/mvp-data-model.md · Grupos D/E + §"Separação Raw/Computed/Snapshot"
--   DATA-AI-0001 (chave (run_id, artist_id, rubric_hash); OD-DB-06/07) · DEC-0003/DEC-0009
--   docs/security/SEC-0001 · SEC-D03/F01/F16 (freeze por trigger abaixo do service_role),
--     SEC-F03 (exposição por-coluna → VIEW na Fase 9), SEC-F13 (default-deny), SEC-F15 (DEFINER)
--   padrão de RLS/imutabilidade/atomicidade das Fases 1–4
--
-- HARD CONSTRAINTS (do payload — PRESERVADAS sem regressão):
--   • Número sai de CÓDIGO determinístico, nunca de IA. O DDL é SÓ ARMAZENAMENTO:
--     zero CHECK de FAIXA/threshold de Score/Velocity/Signals/Competition, zero generated column,
--     zero trigger/expressão de cálculo. Os CHECKs de evidência (F5-05A) são ESTRUTURAIS —
--     presença/não-vazio de chaves obrigatórias — nunca validam valor/número/threshold.
--   • COMPUTED reconstruível: video_artist_mappings/channel_eligibility/artist_metrics
--     NÃO recebem freeze GLOBAL (recompute por run_id é legítimo). artist_metrics recebe
--     apenas um guard CONDICIONAL (só a linhagem JÁ PUBLICADA é inviolável — F5-03).
--   • SNAPSHOT congelado: reports/report_items são imutáveis APÓS publish — por TRIGGER
--     (abaixo do service_role; RLS/grants não bastam — SEC-D03/F01). draft é o working set.
--   • Unicidade (run_id, artist_id, rubric_hash) em artist_metrics (DATA-AI-0001).
--   • FK composta (rubric_version, rubric_hash) → rubric_versions (Fase 2, alvo declarado).
--   • RLS ENABLE + default-deny nas 6; ZERO create policy (Fase 9 sob veto SEC-0001 §0).
--   • Zero tabela de marketplace/Fase 2. Zero secret em repo/log/payload.
--
-- STATUS: AUTORADO, NÃO APLICADO. change_db_schema/run_migration seguem gated (humano +
--         required reviewers em CI), como nas Fases 1–4. Revisões ANTES do apply:
--         Data/AI re-review (matrix #4/#5 — validate_reproducibility), Security (matrix #3),
--         Database (autor), Backend (consumo de artist_metric_id).
-- Rollback: supabase/rollback/20260620000005_phase5_computed_metrics_reports.rollback.sql
-- Verify:   supabase/tests/phase5_post_apply_verify.sql (paridade §4/§5 com Fases 1–4)
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 0. Enums (guardados para idempotência segura)
-- ----------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'video_artist_method') then
    create type public.video_artist_method as enum ('regex', 'llm_assisted', 'human_override', 'unknown');
  end if;
  if not exists (select 1 from pg_type where typname = 'report_status') then
    create type public.report_status as enum ('draft', 'published', 'archived');
  end if;
  if not exists (select 1 from pg_type where typname = 'competition_level') then
    create type public.competition_level as enum ('Low', 'Medium', 'High');
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- 0b. Validadores ESTRUTURAIS de evidência (F5-05A/F5-06A) — IMMUTABLE, puros (só leem o
--     argumento jsonb; ZERO acesso a tabela; ZERO número/threshold). Definem o SHAPE MÍNIMO
--     da auditoria Data/AI (03_Data_AI + enumeração DATA-F5-05) e são usados em CHECK abaixo:
--     {} e seções ausentes são REJEITADOS no banco; o cálculo/valor continua 100% no data-engine.
--
--     NULL-safety: cada chave é checada por presença (`?`) antes do typeof, e jsonb_array_length
--     só é chamado após confirmar 'array'. Retorno é SEMPRE boolean definido (nunca NULL) — um
--     CHECK que avaliasse NULL passaria (NULL = satisfeito), então o validador retorna false
--     explicitamente em cada falha.
-- ----------------------------------------------------------------------------

-- metrics_detail_json (artist_metrics): reconstrói Score/Velocity/Signals/Competition/Example
-- + carrega as versões efetivas e overrides replayable com a chave natural (F5-06A).
create or replace function public.artist_metrics_detail_complete(detail jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
begin
  if detail is null or jsonb_typeof(detail) <> 'object' then return false; end if;

  -- componentes/pesos (não-vazio) + normalização
  if not (detail ? 'components') then return false; end if;
  if jsonb_typeof(detail -> 'components') not in ('object', 'array') then return false; end if;
  if detail -> 'components' in ('{}'::jsonb, '[]'::jsonb) then return false; end if;
  if not (detail ? 'normalization') then return false; end if;

  -- vídeos: aceitos (não-vazio) + rejeitados (presente; motivos vivem nos elementos)
  if not (detail ? 'videos') or jsonb_typeof(detail -> 'videos') <> 'object' then return false; end if;
  if not (detail -> 'videos' ? 'accepted')
     or jsonb_typeof(detail #> '{videos,accepted}') <> 'array' then return false; end if;
  if jsonb_array_length(detail #> '{videos,accepted}') < 1 then return false; end if;
  if not (detail -> 'videos' ? 'rejected')
     or jsonb_typeof(detail #> '{videos,rejected}') <> 'array' then return false; end if;

  -- velocity: inputs + mediana
  if not (detail ? 'velocity') or jsonb_typeof(detail -> 'velocity') <> 'object' then return false; end if;
  if not (detail -> 'velocity' ? 'inputs') or not (detail -> 'velocity' ? 'median') then return false; end if;

  -- competition: canais elegíveis (array) + contagem
  if not (detail ? 'competition') or jsonb_typeof(detail -> 'competition') <> 'object' then return false; end if;
  if not (detail -> 'competition' ? 'eligible_channel_ids')
     or jsonb_typeof(detail #> '{competition,eligible_channel_ids}') <> 'array' then return false; end if;
  if not (detail -> 'competition' ? 'count') then return false; end if;

  -- F5-06A: versões EFETIVAS não-vazias (rubric + resolver + rule) na própria evidência congelada
  if not (detail ? 'versions') or jsonb_typeof(detail -> 'versions') <> 'object' then return false; end if;
  if coalesce(detail #>> '{versions,rubric_version}',   '') = '' then return false; end if;
  if coalesce(detail #>> '{versions,rubric_hash}',      '') = '' then return false; end if;
  if coalesce(detail #>> '{versions,resolver_version}', '') = '' then return false; end if;
  if coalesce(detail #>> '{versions,rule_version}',     '') = '' then return false; end if;

  -- F5-06A: overrides replayable — array; CADA elemento preserva a chave natural
  -- (run_id + video_id|channel_id). Array vazio = "sem override humano" (válido).
  if not (detail ? 'overrides') or jsonb_typeof(detail -> 'overrides') <> 'array' then return false; end if;
  if exists (
    select 1 from jsonb_array_elements(detail -> 'overrides') o
     where not ((o ? 'run_id') and ((o ? 'video_id') or (o ? 'channel_id')))
  ) then return false; end if;

  return true;
end;
$$;

comment on function public.artist_metrics_detail_complete(jsonb) is
  'F5-05A/F5-06A. Validador ESTRUTURAL (IMMUTABLE, storage-only) do shape mínimo de metrics_detail_json: components/normalization, videos.accepted(≥1)/rejected, velocity.inputs/median, competition.eligible_channel_ids/count, versions(rubric/resolver/rule), overrides[].(run_id+video_id|channel_id). Não valida número/threshold.';

-- selection_reason_json (report_items): prova determinística da seleção do Example.
create or replace function public.report_item_reason_complete(reason jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
begin
  if reason is null or jsonb_typeof(reason) <> 'object' then return false; end if;
  -- candidatos (não-vazio)
  if not (reason ? 'candidates') or jsonb_typeof(reason -> 'candidates') <> 'array' then return false; end if;
  if jsonb_array_length(reason -> 'candidates') < 1 then return false; end if;
  -- shortlist ordenada / top-3 (não-vazio)
  if not (reason ? 'top3') or jsonb_typeof(reason -> 'top3') <> 'array' then return false; end if;
  if jsonb_array_length(reason -> 'top3') < 1 then return false; end if;
  -- regra de desempate + Example selecionado (com video_id não-vazio)
  if not (reason ? 'tiebreak') then return false; end if;
  if not (reason ? 'selected_example')
     or jsonb_typeof(reason -> 'selected_example') <> 'object' then return false; end if;
  if coalesce(reason #>> '{selected_example,video_id}', '') = '' then return false; end if;
  return true;
end;
$$;

comment on function public.report_item_reason_complete(jsonb) is
  'F5-05A. Validador ESTRUTURAL (IMMUTABLE, storage-only) do shape mínimo de selection_reason_json: candidates(≥1), top3(≥1), tiebreak, selected_example.video_id. Não valida número/threshold.';

-- ----------------------------------------------------------------------------
-- 1. video_artist_mappings  (COMPUTED — Entity Resolution canônica por vídeo)
--    Único ponto onde a IA pode atuar (method='llm_assisted'); número nunca sai daqui.
--    OD-DB-04: uma resolução final por (run_id, video_id). FK composta → raw (proveniência).
--    F5-06: resolver_version NOT NULL registra a VERSÃO determinística do resolver/regex
--           usada — input necessário para o rebuild "mesmo raw + mesmas versões". Overrides
--           humanos são replayable em audit_events (entity_table='video_artist_mappings').
-- ----------------------------------------------------------------------------
create table public.video_artist_mappings (
  id               uuid primary key default gen_random_uuid(),
  run_id           uuid not null references public.report_runs (id) on delete restrict,
  video_id         text not null,
  artist_id        uuid not null references public.artists (id) on delete restrict,
  extracted_name   text,
  method           public.video_artist_method not null,
  resolver_version text not null,                 -- F5-06: versão determinística do resolver/regex
  needs_review     boolean not null default false,
  review_notes     text,
  created_at       timestamptz not null default now(),
  -- proveniência forte: o vídeo mapeado existe no raw (run_id, video_id); raw é indeletável.
  constraint video_artist_mappings_raw_video_fk
    foreign key (run_id, video_id) references public.raw_youtube_videos (run_id, video_id) on delete restrict
);

create unique index video_artist_mappings_run_video_uidx
  on public.video_artist_mappings (run_id, video_id);   -- mapping canônico (OD-DB-04)
create index video_artist_mappings_run_artist_idx
  on public.video_artist_mappings (run_id, artist_id);

comment on table public.video_artist_mappings is
  'COMPUTED (reconstruível; SEM freeze global). Resolução vídeo→artista por (run_id, video_id) sob resolver_version. human_override registrado em audit_events. Sem número.';

-- ----------------------------------------------------------------------------
-- 2. channel_eligibility  (COMPUTED — veredito do Channel Filter por canal/run)
--    Alimenta Competition (canais distintos elegíveis). FK composta → raw (proveniência).
--    F5-06: rule_version NOT NULL — toda elegibilidade registra a versão da regra que a
--           produziu (input determinístico do rebuild). Override humano em audit_events.
-- ----------------------------------------------------------------------------
create table public.channel_eligibility (
  id                uuid primary key default gen_random_uuid(),
  run_id            uuid not null references public.report_runs (id) on delete restrict,
  channel_id        text not null,
  is_eligible       boolean not null,
  reason            text,
  rule_version      text not null,                -- F5-06: versão determinística da regra de filtro
  reviewed_by_human boolean not null default false,
  created_at        timestamptz not null default now(),
  constraint channel_eligibility_raw_channel_fk
    foreign key (run_id, channel_id) references public.raw_youtube_channels (run_id, channel_id) on delete restrict
);

create unique index channel_eligibility_run_channel_uidx
  on public.channel_eligibility (run_id, channel_id);   -- um veredito por (run, canal)

comment on table public.channel_eligibility is
  'COMPUTED (reconstruível por rule_version sobre o raw; SEM freeze global). Elegibilidade por (run_id, channel_id). Override humano marcado + audit_events.';

-- ----------------------------------------------------------------------------
-- 3. artist_metrics  (COMPUTED — coração do Score; reconstruível, aponta p/ raw+rubric)
--    DDL é SÓ ARMAZENAMENTO: as colunas guardam o resultado do código determinístico.
--    NÃO há CHECK de faixa/semântica (owner do cálculo/hash = Data/AI). Chave lógica
--    (run_id, artist_id, rubric_hash): re-score do mesmo raw sob novo rubric NÃO colide.
--    F5-05: metrics_detail_json NOT NULL — toda métrica carrega a evidência de auditoria
--           (componentes/pesos/normalização, vídeos aceitos/rejeitados, inputs de velocity,
--           canais elegíveis, candidatos/seleção do Example, versões/overrides efetivos).
--           DDL permanece storage-only: NÃO valida thresholds nem recalcula — só exige presença.
--    F5-02: chaves de identidade compostas (artist_metrics_identity_key / _id_run_key) servem
--           de ALVO de FK para report_items e artist_metric_videos (coerência declarativa).
-- ----------------------------------------------------------------------------
create table public.artist_metrics (
  id                       uuid primary key default gen_random_uuid(),
  run_id                   uuid not null references public.report_runs (id) on delete restrict,
  artist_id                uuid not null references public.artists (id) on delete restrict,
  signals                  int,
  velocity_median_per_day  numeric,
  engagement_score         numeric,
  channel_diversity_count  int,
  channel_diversity_score  numeric,
  raw_score                numeric,
  final_score              numeric,
  rubric_version           text not null,
  rubric_hash              text not null,
  metrics_detail_json      jsonb not null,               -- F5-05/OD-DB-07: auditoria por célula (interno; SEC-F03)
  created_at               timestamptz not null default now(),
  -- FK composta de reprodutibilidade: a versão+hash do rubric existe em rubric_versions (Fase 2).
  constraint artist_metrics_rubric_fk
    foreign key (rubric_version, rubric_hash) references public.rubric_versions (version, hash) on delete restrict,
  -- F5-02: alvo da FK de coerência de report_items (mesmo run/artista/rubric da métrica).
  constraint artist_metrics_identity_key unique (id, run_id, artist_id, rubric_version, rubric_hash),
  -- F5-04: alvo da FK de artist_metric_videos (input pertence ao MESMO run da métrica).
  constraint artist_metrics_id_run_key unique (id, run_id),
  -- F5-05A/F5-06A: evidência ESTRUTURALMENTE completa (NOT NULL não basta — {} é rejeitado).
  -- Storage-only: só presença/não-vazio de chaves; ZERO validação de número/threshold.
  constraint artist_metrics_detail_complete_chk
    check (public.artist_metrics_detail_complete(metrics_detail_json))
);

-- uma métrica por artista por run por rubric (DATA-AI-0001).
create unique index artist_metrics_run_artist_rubric_uidx
  on public.artist_metrics (run_id, artist_id, rubric_hash);
create index artist_metrics_artist_idx
  on public.artist_metrics (artist_id);

comment on table public.artist_metrics is
  'COMPUTED (reconstruível por run_id + rubric_hash; SEM freeze global — só guard CONDICIONAL da linhagem publicada). Score determinístico. Inputs em artist_metric_videos (FK→raw); auditoria em metrics_detail_json (nunca cru ao produtor — SEC-F03).';

-- ----------------------------------------------------------------------------
-- 4. artist_metric_videos  (COMPUTED/PROVENIÊNCIA — inputs normalizados da métrica)
--    F5-04: substitui o antigo computed_from_video_ids text[] (referência só lógica) por
--           proveniência REFERENCIAL: cada vídeo de input EXISTE no raw e pertence ao MESMO
--           run da métrica. Sem array sem FK; sem número sem rastro até raw_youtube_videos.
--    Reconstruível para métricas não-publicadas; CONGELADO quando a métrica já alimenta um
--    relatório publicado/archived (guard condicional abaixo — não é freeze global).
-- ----------------------------------------------------------------------------
create table public.artist_metric_videos (
  artist_metric_id uuid not null,
  run_id           uuid not null,
  video_id         text not null,
  created_at       timestamptz not null default now(),
  constraint artist_metric_videos_pk primary key (artist_metric_id, video_id),
  -- o input pertence ao MESMO run da métrica (id, run_id) — bloqueia atribuir vídeo de outro run.
  constraint artist_metric_videos_metric_fk
    foreign key (artist_metric_id, run_id) references public.artist_metrics (id, run_id) on delete restrict,
  -- o vídeo de input EXISTE no raw daquele run (proveniência forte; raw indeletável).
  constraint artist_metric_videos_raw_fk
    foreign key (run_id, video_id) references public.raw_youtube_videos (run_id, video_id) on delete restrict
);

-- (sem índice extra em artist_metric_id: o PK (artist_metric_id, video_id) já cobre o prefixo.)

comment on table public.artist_metric_videos is
  'COMPUTED/PROVENIÊNCIA (F5-04). Inputs de cada artist_metrics, referenciais até raw_youtube_videos no mesmo run. Reconstruível; inviolável quando a métrica está publicada (guard condicional).';

-- ----------------------------------------------------------------------------
-- 5. reports  (SNAPSHOT — um dos 2 relatórios fixos; congelado após published)
--    keyword/vertical travadas (default = vertical travada). published_at coerente
--    com status via CHECK. O freeze é por TRIGGER (abaixo do service_role).
--    F5-02: o report CONGELA seu par (rubric_version, rubric_hash) — NOT NULL + FK ao
--           rubric_versions — e expõe a identidade (reports_identity_key) como alvo da FK
--           composta de report_items, garantindo item↔report no mesmo run+rubric.
-- ----------------------------------------------------------------------------
create table public.reports (
  id             uuid primary key default gen_random_uuid(),
  run_id         uuid not null references public.report_runs (id) on delete restrict,
  title          text not null,
  vertical       text not null default 'Chicago Drill',
  keyword        text not null default 'chicago drill type beat',
  rubric_version text not null,                            -- F5-02: par de rubric congelado no report
  rubric_hash    text not null,
  status         public.report_status not null default 'draft',
  published_at   timestamptz,
  created_at     timestamptz not null default now(),
  constraint reports_published_at_chk check (status = 'draft' or published_at is not null),
  -- o rubric do report existe em rubric_versions (Fase 2) — todo relatório aponta rubric real.
  constraint reports_rubric_fk
    foreign key (rubric_version, rubric_hash) references public.rubric_versions (version, hash) on delete restrict,
  -- F5-02: alvo da FK de coerência de report_items (mesmo run+rubric do report).
  constraint reports_identity_key unique (id, run_id, rubric_version, rubric_hash)
);

create index reports_run_id_idx on public.reports (run_id);

comment on table public.reports is
  'SNAPSHOT. draft é o working set; após published o conteúdo + report_items congelam (trigger). Entra como draft; só draft→published→archived. Par de rubric congelado (F5-02).';

-- ----------------------------------------------------------------------------
-- 6. report_items  (SNAPSHOT — linha do ranking; ÚNICA superfície lida pelo produtor)
--    artist_metric_id (OD-DB-06): ponteiro de proveniência para a métrica congelada.
--    score_value/selection_reason_json são INTERNOS (SEC-F03) — exposição ao produtor
--    será por VIEW pública dedicada na Fase 9 (NÃO aqui). RLS-on + default-deny até lá.
--    F5-02: carrega (run_id, rubric_version, rubric_hash) e duas FKs COMPOSTAS que travam:
--           item↔report (mesmo run+rubric do report) e item↔metric (mesmo run+ARTISTA+rubric
--           da métrica). Logo artist_metric_id aponta para a métrica EXATA do snapshot.
--    F5-04: example_video_id ganha FK composta (run_id, example_video_id) → raw (MATCH SIMPLE:
--           opcional, mas quando presente PRECISA existir no raw daquele run).
--    F5-05: selection_reason_json NOT NULL — prova determinística da seleção do Example.
-- ----------------------------------------------------------------------------
create table public.report_items (
  id                        uuid primary key default gen_random_uuid(),
  report_id                 uuid not null,
  run_id                    uuid not null,                 -- F5-02/F5-04: coerência + FK do Example ao raw
  artist_id                 uuid not null,                 -- FK nomeada report_items_artist_fk (sem inline duplicada)
  artist_metric_id          uuid not null,
  rubric_version            text not null,                 -- F5-02: deve casar report E metric
  rubric_hash               text not null,
  rank                      int not null,
  title                     text,
  tag                       text,                          -- 'HOT' ou null (HOT se Score > 90)
  score_display             text,                          -- '92/100' (só se > 83) · público
  score_value               numeric,                       -- congelado interno · admin/server-only (SEC-F03)
  signals                   int,                           -- público
  velocity_display          text,                          -- público
  competition_level         public.competition_level,      -- público
  competition_channel_count int,                           -- público
  example_video_id          text,                          -- F5-04: FK composta → raw (opcional, validado)
  example_url               text,                          -- público
  selection_reason_json     jsonb not null,                -- F5-05: prova determinística · cru: admin/server-only (SEC-F03)
  created_at                timestamptz not null default now(),
  -- F5-02 (item↔report): mesmo run+rubric do report; também é a FK que prende report_id.
  constraint report_items_report_fk
    foreign key (report_id, run_id, rubric_version, rubric_hash)
    references public.reports (id, run_id, rubric_version, rubric_hash) on delete restrict,
  -- F5-02/F5-07 (item↔metric): NOMEADA. Trava run_id + artist_id + rubric_version + rubric_hash
  -- contra a identidade da métrica → artist_metric_id é a métrica EXATA, não "alguma métrica".
  constraint report_items_artist_metric_fk
    foreign key (artist_metric_id, run_id, artist_id, rubric_version, rubric_hash)
    references public.artist_metrics (id, run_id, artist_id, rubric_version, rubric_hash) on delete restrict,
  -- identidade direta do artista (ÚNICA FK de artist_id — sem inline duplicada; coerente com a
  -- métrica via FK composta acima). RESTRICT.
  constraint report_items_artist_fk
    foreign key (artist_id) references public.artists (id) on delete restrict,
  -- F5-04: o Example, quando presente, existe no raw daquele run (MATCH SIMPLE → null é livre).
  constraint report_items_example_raw_fk
    foreign key (run_id, example_video_id) references public.raw_youtube_videos (run_id, video_id) on delete restrict,
  -- F5-05A: prova de seleção do Example ESTRUTURALMENTE completa ({} rejeitado). Storage-only.
  constraint report_items_reason_complete_chk
    check (public.report_item_reason_complete(selection_reason_json))
);

create unique index report_items_report_rank_uidx     on public.report_items (report_id, rank);
create unique index report_items_report_artist_uidx   on public.report_items (report_id, artist_id);
create index        report_items_artist_metric_id_idx on public.report_items (artist_metric_id);

comment on table public.report_items is
  'SNAPSHOT congelado no publish. Cadeia REFERENCIAL: report_items → artist_metrics (mesmo run/artista/rubric, FK composta) → artist_metric_videos → raw. Colunas internas (score_value/json) nunca ao produtor cru — VIEW na Fase 9.';

-- ----------------------------------------------------------------------------
-- 7. Freeze do SNAPSHOT + guard CONDICIONAL da linhagem publicada — por TRIGGER,
--    abaixo do service_role. Princípio SEC-D03/F01: RLS/grants não bastam (service_role
--    bypassa RLS). search_path fixo; referências qualificadas (public.*).
--
--    DISTINÇÃO CENTRAL (preserva "computed reconstruível" + fecha o veto):
--    • reports/report_items  → SNAPSHOT: congelados APÓS publish (freeze por classe).
--    • artist_metrics / artist_metric_videos → COMPUTED: SEM freeze global; guard CONDICIONAL
--      bloqueia mutação SOMENTE quando a linha já alimenta relatório publicado/archived
--      (F5-03). Métrica/input não-publicados seguem livres para recompute.
--    • video_artist_mappings / channel_eligibility → COMPUTED: ZERO trigger (recompute livre).
-- ----------------------------------------------------------------------------

-- 7a. reports: entra como draft; congela após publish; única transição pós-publish é →archived.
create or replace function public.reports_snapshot_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    -- F5-01: a máquina de estados entra SEMPRE por draft (materialização do snapshot vem do UPDATE).
    if new.status <> 'draft' then
      raise exception 'reports: novo relatório deve entrar como draft (entrada da máquina de estados)'
        using errcode = 'restrict_violation';
    end if;
    return new;
  end if;
  if tg_op = 'DELETE' then
    if old.status in ('published', 'archived') then
      raise exception 'reports: relatório publicado é snapshot congelado — DELETE não permitido (status=%)', old.status
        using errcode = 'restrict_violation';
    end if;
    return old;  -- draft pode ser descartado/reconstruído
  end if;
  -- UPDATE
  if old.status = 'published' then
    -- única mutação permitida após publish: published → archived, sem tocar o conteúdo congelado
    if new.status = 'archived'
       and new.run_id         is not distinct from old.run_id
       and new.title          is not distinct from old.title
       and new.vertical       is not distinct from old.vertical
       and new.keyword        is not distinct from old.keyword
       and new.rubric_version is not distinct from old.rubric_version
       and new.rubric_hash    is not distinct from old.rubric_hash
       and new.published_at   is not distinct from old.published_at
       and new.created_at     is not distinct from old.created_at then
      return new;
    end if;
    raise exception 'reports: snapshot congelado após publish — só transição para archived sem alterar conteúdo'
      using errcode = 'restrict_violation';
  elsif old.status = 'archived' then
    raise exception 'reports: relatório archived é terminal/congelado — nenhuma alteração permitida'
      using errcode = 'restrict_violation';
  end if;
  -- old.status = 'draft': working set (inclui draft→published, que materializa o snapshot)
  return new;
end;
$$;

-- 7b. report_items: F5-01 — cobre INSERT/UPDATE/DELETE e valida o pai de NEW e o de OLD.
-- SECURITY DEFINER (+ search_path='' + refs qualificadas — padrão SEC-F15 do is_admin()):
-- o freeze depende de LER reports.status, mas o escritor legítimo é o service_role, que
-- neste projeto não detém SELECT em reports. INVOKER quebraria a escrita de draft válida.
-- DEFINER faz o lookup do pai rodar como owner → decisão de freeze correta p/ qualquer caller.
-- Sem SQL dinâmico nem entrada de usuário na query (só id) → sem vetor de escalonamento.
create or replace function public.report_items_snapshot_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  old_parent public.report_status;
  new_parent public.report_status;
begin
  -- F5-01: item de relatório JÁ congelado não pode ser alterado/removido (valida o pai de OLD).
  if tg_op in ('UPDATE', 'DELETE') then
    select status into old_parent from public.reports where id = old.report_id;
    if old_parent in ('published', 'archived') then
      raise exception 'report_items: item de relatório % é snapshot congelado — % não permitido', old_parent, tg_op
        using errcode = 'restrict_violation';
    end if;
  end if;
  -- F5-01: não se pode INSERIR nem MOVER item PARA relatório congelado (valida o pai de NEW).
  if tg_op in ('INSERT', 'UPDATE') then
    select status into new_parent from public.reports where id = new.report_id;
    if new_parent in ('published', 'archived') then
      raise exception 'report_items: % de item em relatório % não é permitido (snapshot congelado)', tg_op, new_parent
        using errcode = 'restrict_violation';
    end if;
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

-- 7c. artist_metrics: F5-03 — guard CONDICIONAL. Bloqueia UPDATE/DELETE SOMENTE se a métrica
-- já alimenta item de relatório publicado/archived (tamper na linhagem publicada). Métrica
-- não-publicada segue livre (recompute) → NÃO é freeze global. DEFINER pelo mesmo motivo (lê
-- report_items/reports, que o service_role não necessariamente lê).
create or replace function public.artist_metrics_published_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- UPDATE/DELETE: a PRÓPRIA métrica (OLD) é inviolável se publicada/archived.
  if exists (
    select 1
      from public.report_items ri
      join public.reports r on r.id = ri.report_id
     where ri.artist_metric_id = old.id
       and r.status in ('published', 'archived')
  ) then
    raise exception 'artist_metrics: métrica de relatório publicado é inviolável — % bloqueado (OLD)', tg_op
      using errcode = 'restrict_violation';
  end if;
  -- F5-03A (defesa OLD≠NEW): o id é PK imutável, mas validamos NEW separadamente para que
  -- nenhuma re-identificação aterrisse sobre a identidade de uma métrica publicada.
  if tg_op = 'UPDATE' and new.id <> old.id and exists (
    select 1
      from public.report_items ri
      join public.reports r on r.id = ri.report_id
     where ri.artist_metric_id = new.id
       and r.status in ('published', 'archived')
  ) then
    raise exception 'artist_metrics: re-identificação para métrica publicada não permitida — bloqueado (NEW)'
      using errcode = 'restrict_violation';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

-- 7d. artist_metric_videos: F5-03/F5-04 — guard CONDICIONAL do conjunto de inputs. Bloqueia
-- INSERT/UPDATE/DELETE SOMENTE quando a métrica dona já alimenta relatório publicado/archived
-- (o conjunto de inputs da linhagem publicada é inviolável). Inputs de métrica não-publicada
-- seguem livres (rebuild). DEFINER pelo mesmo motivo.
-- F5-03A: valida OLD (origem) E NEW (destino) SEPARADAMENTE. O coalesce(OLD,NEW) anterior
-- deixava OLD vencer no UPDATE → mover um input de métrica não-publicada para uma publicada
-- (trocando artist_metric_id) escapava à checagem do destino. Agora:
--   • UPDATE/DELETE: bloqueia se a métrica de OLD (origem) está publicada/archived;
--   • INSERT/UPDATE: bloqueia se a métrica de NEW (destino) está publicada/archived.
create or replace function public.artist_metric_videos_published_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- origem (OLD): input de métrica publicada não pode sair/mudar.
  if tg_op in ('UPDATE', 'DELETE') and exists (
    select 1
      from public.report_items ri
      join public.reports r on r.id = ri.report_id
     where ri.artist_metric_id = old.artist_metric_id
       and r.status in ('published', 'archived')
  ) then
    raise exception 'artist_metric_videos: input de métrica publicada é inviolável — % bloqueado (origem OLD)', tg_op
      using errcode = 'restrict_violation';
  end if;
  -- destino (NEW): não se pode vincular/mover input PARA métrica publicada.
  if tg_op in ('INSERT', 'UPDATE') and exists (
    select 1
      from public.report_items ri
      join public.reports r on r.id = ri.report_id
     where ri.artist_metric_id = new.artist_metric_id
       and r.status in ('published', 'archived')
  ) then
    raise exception 'artist_metric_videos: vincular input a métrica publicada não é permitido — % bloqueado (destino NEW)', tg_op
      using errcode = 'restrict_violation';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

-- 7e. TRUNCATE guard genérico (statement-level) — NÃO impede recompute por-linha; só barra o
-- wipe catastrófico de dados congelados. Reusado por objetos que guardam linhagem congelável.
-- reports/report_items: snapshot. artist_metric_videos: proveniência publicável (é folha — sem
-- FK que a referencie, então não herda a proteção transitiva de TRUNCATE). artist_metrics NÃO
-- precisa: é referenciada por report_items/artist_metric_videos (FK) → TRUNCATE exigiria CASCADE
-- que esbarra no no_truncate de report_items.
create or replace function public.report_snapshot_no_truncate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception '% guarda linhagem congelável — TRUNCATE não permitido', tg_table_name
    using errcode = 'restrict_violation';
end;
$$;

-- Triggers ---------------------------------------------------------------------
create trigger reports_snapshot_guard
  before insert or update or delete on public.reports
  for each row execute function public.reports_snapshot_guard();
create trigger reports_no_truncate
  before truncate on public.reports
  for each statement execute function public.report_snapshot_no_truncate();

create trigger report_items_snapshot_guard
  before insert or update or delete on public.report_items
  for each row execute function public.report_items_snapshot_guard();
create trigger report_items_no_truncate
  before truncate on public.report_items
  for each statement execute function public.report_snapshot_no_truncate();

create trigger artist_metrics_published_guard
  before update or delete on public.artist_metrics
  for each row execute function public.artist_metrics_published_guard();

create trigger artist_metric_videos_published_guard
  before insert or update or delete on public.artist_metric_videos
  for each row execute function public.artist_metric_videos_published_guard();
create trigger artist_metric_videos_no_truncate
  before truncate on public.artist_metric_videos
  for each statement execute function public.report_snapshot_no_truncate();

-- ----------------------------------------------------------------------------
-- 8. RLS: ENABLE + default-deny (SEC-F13) nas 6. ZERO create policy — report_items
--    é a ÚNICA superfície do produtor, mas a policy (+ VIEW pública SEC-F03) é da
--    Fase 9, sob veto do Security (SEC-0001 §0). Esta migration NÃO destrava nada.
-- ----------------------------------------------------------------------------
alter table public.video_artist_mappings enable row level security;
alter table public.channel_eligibility   enable row level security;
alter table public.artist_metrics         enable row level security;
alter table public.artist_metric_videos   enable row level security;
alter table public.reports                enable row level security;
alter table public.report_items           enable row level security;

-- ----------------------------------------------------------------------------
-- 9. Zero grant a anon/authenticated (SEC-F02/F13): revoke explícito sobre os defaults.
-- ----------------------------------------------------------------------------
revoke all on table public.video_artist_mappings from anon, authenticated;
revoke all on table public.channel_eligibility    from anon, authenticated;
revoke all on table public.artist_metrics         from anon, authenticated;
revoke all on table public.artist_metric_videos   from anon, authenticated;
revoke all on table public.reports                from anon, authenticated;
revoke all on table public.report_items           from anon, authenticated;

commit;
