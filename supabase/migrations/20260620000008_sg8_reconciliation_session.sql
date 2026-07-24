-- ============================================================================
-- NOXUND · Migration — SG-8 Reconciliation Session (Schema/Database · DATA-SG8-001 estágio 3)
-- ----------------------------------------------------------------------------
-- Persistência canônica do gate SG-8 (protocolo de 2 rodadas P5-REPRO-01): a SESSÃO,
-- o SNAPSHOT de resolução congelado (Q-1), as RODADAS (Round 1 / Round 2) e a EVIDÊNCIA
-- comparável por relatório. É a "unidade de schema futura" prometida pelo contrato
-- (DATA-SG8-001 §R.2 DD-5) — nasce de decisão registrada, com migration + verify + rollback
-- próprios, sob revisão Database + Data Integrity + Data/AI + QA + Security.
--
-- ESTE SCHEMA NÃO EXECUTA SG-8, não computa, não liga runner/LLM/banco real e não altera
-- a superfície canônica (canonical_report/pipeline_digest permanecem intocados). Ele apenas
-- MODELA o estado durável que o runner (estágio 2, sg8_runner.py) e a integração live
-- (estágio 3) irão gravar atrás das MESMAS ports.
--
-- Fontes vinculantes:
--   docs/data/DATA-SG8-001-sg8-design-contract.md
--     §1 (PASS/FAIL) · §2.1 taxonomia + D-1 (report run_id congelado) + D-10 (imutabilidade
--     entre rodadas) · §5.3 (proveniência LLM obrigatória, FORA do digest) · §6 (writes/
--     atomicidade/append-only) · §R.1 Q-1..Q-5 + §R.2 DD-1..DD-5
--   services/data-engine/src/noxund_data_engine/sg8_runner.py — Sg8State (os 7 marcos
--     duráveis: session_open, r1_awaiting_review, r1_resolved, r1_snapshot_frozen,
--     r1_computed, passed, failed) + InMemoryEvidenceStore (append-only por round_execution_id)
--   Product Lead — decisão de binding (2026-07-23): binding DIFERIDO por FK composta
--     (report_id_1/2 NULL até materialização na Round 1; NULL→valor uma única vez; imutável
--     após; composite FK ao mesmo source_collection_run_id; UNIQUE (id, run_id) aditiva em reports)
--   docs/database/README.md L74 (Relatórios fixos → reports) · phase5 (reports/report_runs)
--   padrão de enum-guard/RLS/imutabilidade/atomicidade das Fases 2–6
--
-- HARD CONSTRAINTS (non-negotiables):
--   • ADITIVA. Só CREATE de tabelas/enums/índices/funções/triggers NOVOS + UMA unique aditiva
--     em public.reports (id, run_id) — EXPLICITAMENTE autorizada pelo Product Lead (2026-07-23),
--     SEM alterar a semântica de reports (id já é PK; a unique só habilita a FK composta).
--     ZERO alteração em report_runs (contrato existente intacto): nenhuma coluna, enum ou trigger
--     de report_runs é tocada. ZERO alteração em qualquer outra tabela/enum aplicado.
--   • ESTADOS = os 7 marcos duráveis do runner (Sg8State). Nenhum estado novo inventado (contrato).
--   • ELEGIBILIDADE DE PUBLISH deriva EXCLUSIVAMENTE de sg8_sessions.status='passed' (DD-1).
--     ZERO acoplamento a report_runs.status; ZERO coluna computed_pending_repro em report_runs (Q-2).
--   • ESTADO SG-8 FORA DO PAYLOAD (DD-2): esta migration não cria nem altera canonical_report;
--     os digests vivem como EVIDÊNCIA à parte (sg8_round_report_evidence), nunca no digest.
--   • APPEND-ONLY + IMUTÁVEL (DD-4 · D-6 · D-10): snapshot congelado, rodadas concluídas e
--     evidências são append-only; nenhuma é sobrescrita. TERMINALIDADE (DD-3 · Q-4): sessão
--     passed/failed é imutável — nova tentativa exige nova sg8_session_id.
--   • ZERO IA gerando número: este schema só ARMAZENA identidades/hashes/digests computados
--     pelo código determinístico. Nenhum CHECK de faixa/threshold; nenhuma coluna calculada.
--   • DEFAULT-DENY: enable RLS + revoke em anon/authenticated nas 4 tabelas; ZERO create policy
--     (Fase 9 vetada). ZERO secret/credencial no schema — o secret/Environment sg8-compute (Q-5)
--     é estágio 3 (integração live), fora desta unidade.
--   • Atômica (begin/commit). Rollback e verify pareados (todos os objetos novos).
--
-- ORDENAÇÃO: ts 0008. O slot 0007 pertence a Phase 6 producer_events (PARKED, fora de main —
--   ver wip/phase6-producer-events-preservation); esta unidade toma 0008 para NÃO colidir com
--   0007 e NÃO reusá-la. Independente e aditiva; não depende de 0007.
--
-- STATUS: AUTORADO, NÃO APLICADO. change_db_schema/run_migration seguem gated (humano +
--   required reviewers em CI), como nas Fases 1–6. NENHUMA aplicação em banco compartilhado/live
--   autorizada. Revisões ANTES do apply: Database (autor) · Data Integrity · Data/AI Pipeline ·
--   QA · Security (grants/RLS/append-only + isolamento futuro do Environment sg8-compute).
-- Rollback: supabase/rollback/20260620000008_sg8_reconciliation_session.rollback.sql
-- Verify:   supabase/tests/sg8_reconciliation_session_post_apply_verify.sql (paridade §4/§5)
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 0. Enum de status da sessão SG-8 (guardado p/ idempotência). Os rótulos são EXATAMENTE
--    os 7 marcos duráveis de Sg8State (sg8_runner.py) — nenhum estado novo (contrato §escalada).
--    passed/failed são TERMINAIS.
-- ----------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'sg8_session_status') then
    create type public.sg8_session_status as enum (
      'session_open',        -- sessão aberta; sem relatórios materializados
      'r1_awaiting_review',  -- Round 1: itens needs_review BLOQUEIAM o downstream
      'r1_resolved',         -- Round 1: fila humana drenada; pronto p/ freeze
      'r1_snapshot_frozen',  -- Round 1: resolution_snapshot congelado (imutável)
      'r1_computed',         -- Round 1: compute concluído; os 2 relatórios materializados/vinculados
      'passed',              -- TERMINAL: Round 2 byte-idêntico (P5-REPRO-01 satisfeito)
      'failed'               -- TERMINAL: drift / gate bypass / colisão / snapshot incompleto
    );
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- 0b. UNIQUE aditiva em public.reports (id, run_id) — ALVO da FK composta de binding.
--     Autorizada pelo Product Lead (2026-07-23): id já é PK (unicidade trivial), a unique
--     só habilita a FK composta (report_id_N, source_collection_run_id) → reports(id, run_id),
--     que PROVA que cada relatório vinculado pertence à MESMA coleção-fonte. SEM alterar a
--     semântica de reports: nenhuma coluna/enum/trigger de reports é modificada.
--     Idempotência: guardada por nome de constraint.
-- ----------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'reports_id_run_key'
      and conrelid = 'public.reports'::regclass
  ) then
    alter table public.reports add constraint reports_id_run_key unique (id, run_id);
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- 1. sg8_sessions  (a SESSÃO canônica — âncora da tentativa SG-8; par Round 1 + Round 2)
--    id = sg8_session_id. source_collection_run_id = proveniência do dataset congelado
--    (report_runs; raw lido read-only por ambas as rodadas). report_id_1/2 = os DOIS
--    report run_id congelados (reports.id) — binding DIFERIDO (Product Lead 2026-07-23):
--    NULL até a Round 1 materializar os dois relatórios na MESMA transação; NULL→valor uma
--    única vez; imutável após (trigger). status = os 7 marcos do runner; passed/failed são
--    terminais e imutáveis. Estado SG-8 NUNCA entra no payload canônico (DD-2).
-- ----------------------------------------------------------------------------
create table public.sg8_sessions (
  id                       uuid primary key default gen_random_uuid(),          -- sg8_session_id
  source_collection_run_id uuid not null references public.report_runs (id) on delete restrict,
  report_id_1              uuid,   -- reports.id · Relatório 1 de 2 · NULL até materialização (Round 1)
  report_id_2              uuid,   -- reports.id · Relatório 2 de 2 · NULL até materialização (Round 1)
  status                   public.sg8_session_status not null default 'session_open',
  verdict_reason           text,   -- razão do veredicto (auditoria; operacional — FORA do digest)
  created_at               timestamptz not null default now(),
  terminal_at              timestamptz,  -- carimbo do estado terminal (passed/failed)

  -- alvo das FKs compostas de snapshot/rodadas: prende (sessão, coleção-fonte).
  constraint sg8_sessions_id_source_key unique (id, source_collection_run_id),

  -- binding: ambos NULL (pré-materialização) OU ambos preenchidos (pós-Round 1).
  constraint sg8_sessions_reports_both_or_neither_chk
    check ((report_id_1 is null) = (report_id_2 is null)),
  -- quando preenchidos, os dois relatórios são distintos.
  constraint sg8_sessions_reports_distinct_chk
    check (report_id_1 is null or report_id_1 <> report_id_2),
  -- a partir do 1º estado durável pós-materialização (r1_computed) e no PASS, os dois são
  -- OBRIGATÓRIOS (failed pode ocorrer antes da materialização — então não exige binding).
  constraint sg8_sessions_reports_required_post_compute_chk
    check (status not in ('r1_computed', 'passed') or report_id_1 is not null),
  -- TERMINALIDADE (hardening item 3): terminal (passed/failed) ⇒ terminal_at PRESENTE e
  -- verdict_reason PRESENTE e NÃO-BRANCO; não-terminal ⇒ terminal_at E verdict_reason NULOS.
  constraint sg8_sessions_terminal_state_chk
    check (
      case
        when status in ('passed', 'failed')
          then terminal_at is not null and verdict_reason is not null and btrim(verdict_reason) <> ''
        else terminal_at is null and verdict_reason is null
      end
    ),
  -- cada relatório vinculado pertence à MESMA coleção-fonte da sessão (binding correto por dataset).
  constraint sg8_sessions_report_1_source_fk
    foreign key (report_id_1, source_collection_run_id)
    references public.reports (id, run_id) on delete restrict,
  constraint sg8_sessions_report_2_source_fk
    foreign key (report_id_2, source_collection_run_id)
    references public.reports (id, run_id) on delete restrict
);

create index sg8_sessions_source_run_idx on public.sg8_sessions (source_collection_run_id);
create index sg8_sessions_status_idx     on public.sg8_sessions (status);

comment on table public.sg8_sessions is
  'SESSÃO SG-8 (âncora da tentativa; Round 1 + Round 2 sobre um source_collection_run_id). status = 7 marcos duráveis do runner; passed/failed terminais/imutáveis. report_id_1/2 (reports.id) por binding DIFERIDO: NULL→valor uma única vez na Round 1, imutável após. Elegibilidade de publish = status=passed (DD-1); estado SG-8 nunca entra no payload (DD-2).';

-- ----------------------------------------------------------------------------
-- 2. sg8_resolution_snapshots  (Q-1 — registro LEVE e dedicado; NÃO duplica os fatos)
--    Ponteiro imutável para o conjunto congelado de fatos de entity-resolution produzido na
--    Round 1 e RELIDO pela Round 2. Carrega só a IDENTIDADE + a PROVA (content_hash), nunca os
--    fatos (que vivem no modelo de entity-resolution já landado). No máximo UM por sessão.
-- ----------------------------------------------------------------------------
create table public.sg8_resolution_snapshots (
  id                       uuid primary key default gen_random_uuid(),          -- resolution_snapshot_id
  sg8_session_id           uuid not null references public.sg8_sessions (id) on delete restrict,
  source_collection_run_id uuid not null references public.report_runs (id) on delete restrict,
  resolver_version         text not null,   -- identidade do resolver (ex.: entity-resolver-v1)
  resolver_hash            text not null,   -- hash do resolver (prova de identidade determinística)
  fact_count               int  not null,   -- nº de fatos congelados (cardinalidade do conjunto)
  content_hash             text not null,   -- sha256 do conjunto canônico e ORDENADO de fatos
  frozen_at                timestamptz not null default now(),

  -- alvo da FK composta das rodadas (o snapshot pertence à sessão que o congelou).
  constraint sg8_resolution_snapshots_id_session_key unique (id, sg8_session_id),

  constraint sg8_resolution_snapshots_resolver_version_nonblank_chk check (btrim(resolver_version) <> ''),
  constraint sg8_resolution_snapshots_resolver_hash_nonblank_chk    check (btrim(resolver_hash)    <> ''),
  constraint sg8_resolution_snapshots_content_hash_nonblank_chk     check (btrim(content_hash)     <> ''),
  constraint sg8_resolution_snapshots_fact_count_chk               check (fact_count >= 0),
  -- coerência: o snapshot referencia a MESMA coleção-fonte da sessão.
  constraint sg8_resolution_snapshots_session_source_fk
    foreign key (sg8_session_id, source_collection_run_id)
    references public.sg8_sessions (id, source_collection_run_id) on delete restrict
);

-- no máximo UM snapshot congelado por sessão (o registro É o snapshot congelado).
create unique index sg8_resolution_snapshots_session_uidx
  on public.sg8_resolution_snapshots (sg8_session_id);

comment on table public.sg8_resolution_snapshots is
  'Q-1 · registro LEVE e imutável (append-only) do snapshot de resolução congelado da Round 1. NÃO duplica os fatos: guarda identidade do resolver (version+hash), fact_count, content_hash canônico e frozen_at. Máx. 1 por sessão; relido read-only pela Round 2.';

-- ----------------------------------------------------------------------------
-- 3. sg8_round_executions  (as RODADAS — round_execution_id; Round 1 e Round 2)
--    round_execution_id ≠ por rodada (identidade de EXECUÇÃO, nunca de dataset — §4.3). Uma
--    única Round 1 e uma única Round 2 por sessão. Round 2 reusa o MESMO source_collection_run_id
--    e o MESMO resolution_snapshot_id da Round 1 (garantido por FKs compostas: ambos amarrados
--    à sessão, e o snapshot é único por sessão). PROVENIÊNCIA OPERACIONAL da LLM (Round 1) vive
--    AQUI — FORA da superfície comparável (§3.2/§5.3); Round 2 é zero-LLM (CHECK).
-- ----------------------------------------------------------------------------
create table public.sg8_round_executions (
  id                       uuid primary key default gen_random_uuid(),          -- round_execution_id
  sg8_session_id           uuid not null references public.sg8_sessions (id) on delete restrict,
  round_number             smallint not null,   -- 1 = Round 1 (compute) · 2 = Round 2 (replay zero-LLM)
  source_collection_run_id uuid not null references public.report_runs (id) on delete restrict,
  resolution_snapshot_id   uuid not null references public.sg8_resolution_snapshots (id) on delete restrict,
  -- Proveniência LLM (§5.3) — SÓ Round 1; auditável; NUNCA entra no digest. Params opacos (jsonb).
  llm_provider             text,
  llm_model                text,    -- modelo EXATO (pinado por id, nunca alias "latest" — Q-5)
  llm_model_version        text,
  llm_prompt_hash          text,
  llm_params_json          jsonb,
  llm_adapter_version      text,
  created_at               timestamptz not null default now(),

  -- alvo da FK composta da evidência (a rodada pertence à sessão declarada).
  constraint sg8_round_executions_id_session_key unique (id, sg8_session_id),

  constraint sg8_round_executions_round_chk check (round_number in (1, 2)),
  -- uma única Round 1 e uma única Round 2 por sessão.
  constraint sg8_round_executions_session_round_key unique (sg8_session_id, round_number),
  -- coerência: a rodada referencia a MESMA coleção-fonte da sessão.
  constraint sg8_round_executions_session_source_fk
    foreign key (sg8_session_id, source_collection_run_id)
    references public.sg8_sessions (id, source_collection_run_id) on delete restrict,
  -- coerência: o snapshot pertence à MESMA sessão (Round 2 reusa o de Round 1 — único por sessão).
  constraint sg8_round_executions_snapshot_session_fk
    foreign key (resolution_snapshot_id, sg8_session_id)
    references public.sg8_resolution_snapshots (id, sg8_session_id) on delete restrict,
  -- Round 2 é ZERO-LLM: nenhum campo de proveniência LLM presente (null-safe via num_nonnulls).
  constraint sg8_round_executions_round2_zero_llm_chk
    check (
      round_number = 1
      or num_nonnulls(llm_provider, llm_model, llm_model_version,
                      llm_prompt_hash, llm_params_json, llm_adapter_version) = 0
    ),
  -- §5.3: proveniência LLM é ALL-OR-NOTHING e não-branca — ou 0 campos-núcleo, ou os 5
  -- completos (params é opcional). NOT NULL não bastaria; num_nonnulls torna o CHECK definido.
  constraint sg8_round_executions_llm_provenance_complete_chk
    check (
      num_nonnulls(llm_provider, llm_model, llm_model_version, llm_prompt_hash, llm_adapter_version) in (0, 5)
      and (llm_provider      is null or btrim(llm_provider)        <> '')
      and (llm_model         is null or btrim(llm_model)           <> '')
      and (llm_model_version is null or btrim(llm_model_version)   <> '')
      and (llm_prompt_hash   is null or btrim(llm_prompt_hash)     <> '')
      and (llm_adapter_version is null or btrim(llm_adapter_version) <> '')
    )
);

create index sg8_round_executions_session_idx  on public.sg8_round_executions (sg8_session_id);
create index sg8_round_executions_snapshot_idx on public.sg8_round_executions (resolution_snapshot_id);

comment on table public.sg8_round_executions is
  'RODADAS SG-8 (append-only/imutável). round_execution_id distinto por rodada (execução, nunca dataset — §4.3). UNIQUE (session, round) ⇒ 1 Round 1 + 1 Round 2. Round 2 reusa mesmo dataset+snapshot da Round 1 (FKs compostas). Proveniência LLM (§5.3) só Round 1, FORA do digest; Round 2 zero-LLM (CHECK).';

-- ----------------------------------------------------------------------------
-- 4. sg8_round_report_evidence  (a EVIDÊNCIA comparável — digest do payload canônico por
--    relatório por rodada). Particionada por round_execution_id (D-10): Round 1 e Round 2
--    gravam em espaços disjuntos; nenhuma sobrescreve a outra. Unicidade (round_execution_id,
--    report_id) ⇒ um digest por relatório por rodada, nunca sobrescrito. report_id deve ser
--    UM dos dois report_id congelados da sessão (trigger) — logo Round 2 reusa exatamente os
--    mesmos dois relatórios da Round 1. O digest é a superfície comparável (§3.4); o VEREDITO
--    (byte-idêntico ⇒ passed) é do runner, gravado em sg8_sessions.status.
-- ----------------------------------------------------------------------------
create table public.sg8_round_report_evidence (
  id                 uuid primary key default gen_random_uuid(),
  round_execution_id uuid not null references public.sg8_round_executions (id) on delete restrict,
  sg8_session_id     uuid not null,   -- desnormalizado p/ FK composta + checagem de pertencimento
  report_id          uuid not null,   -- reports.id · um dos 2 report run_id congelados da sessão
  canonical_digest   text not null,   -- sha256(canonical_json(report)) — a superfície comparável
  created_at         timestamptz not null default now(),

  constraint sg8_round_report_evidence_digest_nonblank_chk check (btrim(canonical_digest) <> ''),
  -- append-only: UM digest por (rodada, relatório); nunca sobrescrito (D-10 · §6.5).
  constraint sg8_round_report_evidence_round_report_key unique (round_execution_id, report_id),
  -- coerência: a evidência pertence à MESMA sessão do round_execution (dataset não divergível).
  constraint sg8_round_report_evidence_round_session_fk
    foreign key (round_execution_id, sg8_session_id)
    references public.sg8_round_executions (id, sg8_session_id) on delete restrict
);

create index sg8_round_report_evidence_session_idx on public.sg8_round_report_evidence (sg8_session_id);
create index sg8_round_report_evidence_report_idx  on public.sg8_round_report_evidence (report_id);

comment on table public.sg8_round_report_evidence is
  'EVIDÊNCIA comparável (append-only/imutável) por relatório por rodada. Particionada por round_execution_id (D-10); UNIQUE (round_execution_id, report_id) ⇒ nunca sobrescrita. report_id restrito aos 2 relatórios congelados da sessão (trigger) ⇒ Round 2 reusa exatamente os mesmos dois. Digest = superfície comparável (§3.4).';

-- ----------------------------------------------------------------------------
-- 5. Integridade por TRIGGER (abaixo do service_role — RLS/grants não bastam; SEC-D03/F01).
--    search_path fixo (''); referências qualificadas (public.*).
-- ----------------------------------------------------------------------------

-- 5a. Guard append-only GENÉRICO: levanta p/ qualquer UPDATE/DELETE/TRUNCATE. Não referencia
--     NEW/OLD ⇒ serve triggers row (update/delete) E statement (truncate). Reusado pelo snapshot,
--     rodadas e evidência (imutabilidade total) e pelo TRUNCATE da própria sessão.
create or replace function public.sg8_append_only_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception '% é append-only/imutável (SG-8, DD-4/D-10) — % não permitido (nada é sobrescrito)',
    tg_table_name, tg_op
    using errcode = 'restrict_violation';
end;
$$;

-- 5b. Guard da SESSÃO (hardening items 1/2/3/4). SECURITY DEFINER + search_path='' + refs
--     qualificadas (SEC-F15): o GATE DE PASS lê sg8_round_executions/evidence, que o escritor
--     legítimo (service_role) não necessariamente pode SELECT — o lookup (só por sg8_session_id)
--     roda como owner; sem SQL dinâmico ⇒ sem vetor de escalonamento. Cobre:
--       INSERT — a sessão NASCE limpa (item 1: session_open, sem binding, sem terminalidade/razão);
--       UPDATE — DELETE bloqueado; terminal imutável (sem reabertura); identidade/binding imutáveis;
--                MÁQUINA DE ESTADOS MONOTÔNICA (item 2: só o próximo avanço, ou failed de qualquer
--                não-terminal; sem saltos/regressões/no-op); GATE DE PASS (item 4);
--       terminalidade/razão (item 3) é garantida pelo CHECK sg8_sessions_terminal_state_chk.
create or replace function public.sg8_sessions_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  old_ord   int;  new_ord   int;
  v_n1      int;  v_n2      int;
  v_r1_exec uuid; v_r2_exec uuid;
  v_r1_src  uuid; v_r2_src  uuid;
  v_r1_snap uuid; v_r2_snap uuid;
  v_ev1     int;  v_ev2     int;
  v_pairs   int;  v_mism    int;
begin
  -- INSERT (item 1): sessão nasce em session_open, sem binding, sem terminalidade/razão.
  if tg_op = 'INSERT' then
    if new.status <> 'session_open' then
      raise exception 'sg8_sessions: nova sessão deve nascer em session_open (recebido status=%)', new.status
        using errcode = 'restrict_violation';
    end if;
    if new.report_id_1 is not null or new.report_id_2 is not null then
      raise exception 'sg8_sessions: nova sessão não pode nascer vinculada (report_id_1/2 devem ser NULL no nascimento)'
        using errcode = 'restrict_violation';
    end if;
    if new.terminal_at is not null or new.verdict_reason is not null then
      raise exception 'sg8_sessions: nova sessão não pode nascer terminal (terminal_at/verdict_reason devem ser NULL)'
        using errcode = 'restrict_violation';
    end if;
    return new;
  end if;

  if tg_op = 'DELETE' then
    raise exception 'sg8_sessions é âncora de tentativa SG-8 — DELETE não permitido (nova tentativa = nova sg8_session_id)'
      using errcode = 'restrict_violation';
  end if;

  -- ===== UPDATE =====
  -- TERMINALIDADE (DD-3 · Q-4): sessão terminal é totalmente imutável — sem reabertura.
  if old.status in ('passed', 'failed') then
    raise exception 'sg8_sessions: sessão terminal (%) é imutável — nova tentativa exige nova sg8_session_id', old.status
      using errcode = 'restrict_violation';
  end if;
  -- IDENTIDADE imutável.
  if new.source_collection_run_id is distinct from old.source_collection_run_id then
    raise exception 'sg8_sessions: source_collection_run_id é imutável'
      using errcode = 'restrict_violation';
  end if;
  if new.created_at is distinct from old.created_at then
    raise exception 'sg8_sessions: created_at é imutável'
      using errcode = 'restrict_violation';
  end if;
  -- BINDING imutável: só NULL→valor (uma única vez); nunca alterar/remover/substituir.
  if old.report_id_1 is not null and new.report_id_1 is distinct from old.report_id_1 then
    raise exception 'sg8_sessions: report_id_1 é imutável após o binding (NULL→valor uma única vez)'
      using errcode = 'restrict_violation';
  end if;
  if old.report_id_2 is not null and new.report_id_2 is distinct from old.report_id_2 then
    raise exception 'sg8_sessions: report_id_2 é imutável após o binding (NULL→valor uma única vez)'
      using errcode = 'restrict_violation';
  end if;

  -- MÁQUINA DE ESTADOS MONOTÔNICA (item 2) — os 7 marcos de Sg8State; NENHUM estado novo.
  --   Cadeia: session_open(0)→r1_awaiting_review(1)→r1_resolved(2)→r1_snapshot_frozen(3)→
  --           r1_computed(4)→passed(5). failed a partir de QUALQUER não-terminal.
  --   Só o próximo avanço (old_ord+1) OU failed; sem saltos, regressões, reabertura ou no-op.
  old_ord := case old.status
    when 'session_open' then 0 when 'r1_awaiting_review' then 1 when 'r1_resolved' then 2
    when 'r1_snapshot_frozen' then 3 when 'r1_computed' then 4 end;
  if new.status = 'failed' then
    null;  -- old é não-terminal aqui ⇒ failed permitido de qualquer estado
  elsif new.status = old.status then
    raise exception 'sg8_sessions: transição no-op não permitida em % (exige avanço monotônico ou failed)', old.status
      using errcode = 'restrict_violation';
  else
    new_ord := case new.status
      when 'session_open' then 0 when 'r1_awaiting_review' then 1 when 'r1_resolved' then 2
      when 'r1_snapshot_frozen' then 3 when 'r1_computed' then 4 when 'passed' then 5 end;
    if new_ord is distinct from old_ord + 1 then
      raise exception 'sg8_sessions: transição inválida %→% (salto/regressão proibido; só o próximo avanço ou failed)', old.status, new.status
        using errcode = 'restrict_violation';
    end if;
  end if;

  -- GATE DE PASS (item 4 · defesa-em-profundidade): passed só com PROVA COMPLETA do SG-8.
  --   Elegibilidade de publish continua derivando SÓ de status='passed' (DD-1); aqui o banco
  --   recusa gravar 'passed' sem: binding completo; exatamente 1 Round 1 + 1 Round 2; mesmo
  --   source_collection_run_id e mesmo resolution_snapshot_id nas 2 rodadas; exatamente 2
  --   evidências por rodada (uma por relatório congelado); emparelhamento por report_id; e
  --   canonical_digest R1 == R2 para cada relatório. Sem isso, transição negada.
  if new.status = 'passed' then
    if new.report_id_1 is null or new.report_id_2 is null then
      raise exception 'sg8_sessions PASS gate: binding dos 2 relatórios incompleto'
        using errcode = 'restrict_violation';
    end if;
    select count(*) filter (where round_number = 1), count(*) filter (where round_number = 2)
      into v_n1, v_n2 from public.sg8_round_executions where sg8_session_id = new.id;
    if v_n1 <> 1 or v_n2 <> 1 then
      raise exception 'sg8_sessions PASS gate: exige exatamente 1 Round 1 e 1 Round 2 (r1=%, r2=%)', v_n1, v_n2
        using errcode = 'restrict_violation';
    end if;
    select id, source_collection_run_id, resolution_snapshot_id into v_r1_exec, v_r1_src, v_r1_snap
      from public.sg8_round_executions where sg8_session_id = new.id and round_number = 1;
    select id, source_collection_run_id, resolution_snapshot_id into v_r2_exec, v_r2_src, v_r2_snap
      from public.sg8_round_executions where sg8_session_id = new.id and round_number = 2;
    if v_r1_src is distinct from v_r2_src then
      raise exception 'sg8_sessions PASS gate: rodadas em source_collection_run_id distintos'
        using errcode = 'restrict_violation';
    end if;
    if v_r1_snap is distinct from v_r2_snap then
      raise exception 'sg8_sessions PASS gate: rodadas em resolution_snapshot_id distintos'
        using errcode = 'restrict_violation';
    end if;
    select count(*) into v_ev1 from public.sg8_round_report_evidence where round_execution_id = v_r1_exec;
    select count(*) into v_ev2 from public.sg8_round_report_evidence where round_execution_id = v_r2_exec;
    if v_ev1 <> 2 or v_ev2 <> 2 then
      raise exception 'sg8_sessions PASS gate: exige exatamente 2 evidências por rodada (r1=%, r2=%)', v_ev1, v_ev2
        using errcode = 'restrict_violation';
    end if;
    if not (
         exists (select 1 from public.sg8_round_report_evidence where round_execution_id = v_r1_exec and report_id = new.report_id_1)
     and exists (select 1 from public.sg8_round_report_evidence where round_execution_id = v_r1_exec and report_id = new.report_id_2)
     and exists (select 1 from public.sg8_round_report_evidence where round_execution_id = v_r2_exec and report_id = new.report_id_1)
     and exists (select 1 from public.sg8_round_report_evidence where round_execution_id = v_r2_exec and report_id = new.report_id_2)) then
      raise exception 'sg8_sessions PASS gate: evidências não cobrem os 2 relatórios congelados em ambas as rodadas'
        using errcode = 'restrict_violation';
    end if;
    select count(*), count(*) filter (where a.canonical_digest is distinct from b.canonical_digest)
      into v_pairs, v_mism
      from public.sg8_round_report_evidence a
      join public.sg8_round_report_evidence b
        on b.round_execution_id = v_r2_exec and b.report_id = a.report_id
     where a.round_execution_id = v_r1_exec;
    if v_pairs <> 2 then
      raise exception 'sg8_sessions PASS gate: evidências R1/R2 não emparelham nos 2 relatórios (pares=%)', v_pairs
        using errcode = 'restrict_violation';
    end if;
    if v_mism <> 0 then
      raise exception 'sg8_sessions PASS gate: canonical_digest da Round 1 != Round 2 (drift) — PASS negado'
        using errcode = 'restrict_violation';
    end if;
  end if;

  return new;
end;
$$;

-- 5c. Guard da EVIDÊNCIA: append-only (bloqueia UPDATE/DELETE) e, no INSERT, valida que report_id
--     é UM dos dois relatórios congelados da sessão (⇒ Round 2 não cria/troca relatórios).
--     SECURITY DEFINER + search_path='' + refs qualificadas (padrão SEC-F15): o escritor legítimo
--     (service_role) não necessariamente detém SELECT em sg8_sessions; o lookup (só por id) roda
--     como owner. Sem SQL dinâmico nem entrada de usuário além do id ⇒ sem vetor de escalonamento.
create or replace function public.sg8_round_report_evidence_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  r1 uuid;
  r2 uuid;
begin
  if tg_op in ('UPDATE', 'DELETE') then
    raise exception 'sg8_round_report_evidence é append-only/imutável — % não permitido (nenhuma evidência é sobrescrita)', tg_op
      using errcode = 'restrict_violation';
  end if;
  -- INSERT: a sessão precisa já ter os DOIS relatórios vinculados, e report_id deve ser um deles.
  select report_id_1, report_id_2 into r1, r2
    from public.sg8_sessions where id = new.sg8_session_id;
  if r1 is null or r2 is null then
    raise exception 'sg8_round_report_evidence: sessão % sem binding dos 2 relatórios (materialização da Round 1 ausente)', new.sg8_session_id
      using errcode = 'restrict_violation';
  end if;
  if new.report_id <> r1 and new.report_id <> r2 then
    raise exception 'sg8_round_report_evidence: report_id % não pertence aos 2 relatórios congelados da sessão', new.report_id
      using errcode = 'restrict_violation';
  end if;
  return new;
end;
$$;

-- Triggers ---------------------------------------------------------------------
-- sessão: guard de INSERT (nascimento limpo) + update/delete (FSM/terminalidade/PASS gate) +
--         bloqueio de truncate.
create trigger sg8_sessions_guard
  before insert or update or delete on public.sg8_sessions
  for each row execute function public.sg8_sessions_guard();
create trigger sg8_sessions_no_truncate
  before truncate on public.sg8_sessions
  for each statement execute function public.sg8_append_only_guard();

-- snapshot: imutável (append-only) + no-truncate.
create trigger sg8_resolution_snapshots_immutable
  before update or delete on public.sg8_resolution_snapshots
  for each row execute function public.sg8_append_only_guard();
create trigger sg8_resolution_snapshots_no_truncate
  before truncate on public.sg8_resolution_snapshots
  for each statement execute function public.sg8_append_only_guard();

-- rodadas: imutável (append-only) + no-truncate.
create trigger sg8_round_executions_immutable
  before update or delete on public.sg8_round_executions
  for each row execute function public.sg8_append_only_guard();
create trigger sg8_round_executions_no_truncate
  before truncate on public.sg8_round_executions
  for each statement execute function public.sg8_append_only_guard();

-- evidência: guard de insert (pertencimento) + append-only (update/delete) + no-truncate.
create trigger sg8_round_report_evidence_guard
  before insert or update or delete on public.sg8_round_report_evidence
  for each row execute function public.sg8_round_report_evidence_guard();
create trigger sg8_round_report_evidence_no_truncate
  before truncate on public.sg8_round_report_evidence
  for each statement execute function public.sg8_append_only_guard();

-- ----------------------------------------------------------------------------
-- 6. RLS: ENABLE + default-deny (SEC-F13) nas 4 tabelas. ZERO create policy — leitura/escrita
--    são server/admin (runner + Product Lead no loop); policies eventuais ficam na Fase 9
--    (vetada — SEC-0001 §0). Esta migration NÃO destrava nada.
-- ----------------------------------------------------------------------------
alter table public.sg8_sessions               enable row level security;
alter table public.sg8_resolution_snapshots   enable row level security;
alter table public.sg8_round_executions        enable row level security;
alter table public.sg8_round_report_evidence   enable row level security;

-- ----------------------------------------------------------------------------
-- 7. Default-deny (hardening item 5 · SEC-F02/F13): revoke explícito de PUBLIC + anon +
--    authenticated sobre os defaults. service_role preserva seu grant default (acesso mínimo
--    necessário para a futura integração gated — estágio 3). ZERO create policy (Fase 9 vetada).
--    Isolamento do Environment sg8-compute (Q-5) é estágio 3 — nada de secret aqui.
-- ----------------------------------------------------------------------------
revoke all on table public.sg8_sessions              from public, anon, authenticated;
revoke all on table public.sg8_resolution_snapshots  from public, anon, authenticated;
revoke all on table public.sg8_round_executions      from public, anon, authenticated;
revoke all on table public.sg8_round_report_evidence from public, anon, authenticated;

commit;
