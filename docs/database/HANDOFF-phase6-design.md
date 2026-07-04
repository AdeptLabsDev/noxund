# Handoff — [DB] Fase 6 Design (producer_events · append-only) · Database Agent

> 🟡 **DESIGN-ONLY · BACKGROUND · HOLD em `design_complete_no_apply`.**
> DDL + verify + rollback **autorados, NÃO aplicados** (DEC-0013 pipeline-first). Revisões
> **Security / Data·AI / Backend DIFERIDAS** — não disparadas por esta tarefa. O apply gated
> (`run_migration`) só é sequenciado quando a captura de eventos virar gargalo, **após o 1º
> relatório publicado** (DEC-0013 §3). Esta autoria **não** toca o banco nem destrava a Fase 9.

## 1. Identificação
- **Tarefa:** `task_phase6_design_producer_events` · **Action:** `design_schema` (não-sensível; `priority: low`, `background`)
- **Owner agent:** Database (`database_agent`) · **Data:** 2026-06-28
- **Hold:** `design_complete_no_apply` — sem `change_db_schema`/`run_migration`; sem `define_rls_policy`.
- **Predecessoras (aplicadas):** Fase 1 (`producers`), Fase 3 (`artists`/`report_runs`), Fase 5 (`reports`/`report_items`/`artist_metrics`) — DEC-0008/0009/0010/0011/0012.
- **Fontes:** `04_Database_Event_Model.md` §8 (tabela + enum) / §13 (métrica→evento→query) · `01_MVP_Scope_PRD.md` §4/§8 · `migration-plan.md §Fase 6` · `mvp-backlog.md` Épico 4 [DB] · `DEC-0004` (RPC atômica — escrita) · `DEC-0013` (pipeline-first) · padrão append-only de `audit_events`/`rubric_versions`.

## 2. Objetivo
Autorar a tabela **`producer_events`** (append-only) que fecha o laço de validação **feedback → intenção (métrica-norte) → follow-up**, com proveniência total e auditabilidade da métrica-norte — mantendo o design amadurecendo em background sem roubar banda do caminho crítico (data-engine + P5-REPRO-01 → 1º publish).

## 3. Diff de schema (forward migration · `20260620000007_phase6_producer_events.sql`)
> **Ordenação:** renumerada `0006→0007` para a extensão aditiva `entity_resolution_candidates` (DEC-0014, ts `0006`) aplicar **à frente** desta Fase 6. Ambas ainda **NÃO aplicadas**; renumeração sem custo (arquivos untracked).
>
> **Untracked por design (C5 = doc-only):** o trio 0007 — `supabase/migrations/20260620000007_phase6_producer_events.sql`, `supabase/rollback/20260620000007_phase6_producer_events.rollback.sql` e `supabase/tests/phase6_post_apply_verify.sql` — permanece **intencionalmente untracked neste commit**; a cópia canônica vive no working tree e só entra no versionamento junto do apply gated (`phase6-db-apply.yml`, DEC-0013 §3). Não é omissão — é o parking pipeline-first.
```text
+ enum producer_event_type (14 labels — 04_ §8): application_submitted, application_approved,
    report_opened, report_switched, example_clicked, artist_marked_useful, artist_marked_not_useful,
    intent_to_produce_declared (NORTE), followup_sent, followup_confirmed_produced,
    followup_confirmed_not_produced, wtp_yes, wtp_no, wtp_maybe
+ table producer_events(
    id uuid pk, producer_id uuid NOT NULL, event_type producer_event_type NOT NULL,
    report_id uuid, report_item_id uuid, artist_id uuid, metadata jsonb, created_at timestamptz NOT NULL,
    FK producer_events_producer_fk    (producer_id)    → producers(id)    ON DELETE RESTRICT,
    FK producer_events_report_fk      (report_id)      → reports(id)      ON DELETE RESTRICT,
    FK producer_events_report_item_fk (report_item_id) → report_items(id) ON DELETE RESTRICT,
    FK producer_events_artist_fk      (artist_id)      → artists(id)      ON DELETE RESTRICT,
    CHECK producer_events_intent_context_chk  (intent ⇒ artist_id+report_id NOT NULL),
    CHECK producer_events_no_request_context  (SEC-F08: metadata sem config/request/headers/authorization/key))
+ index producer_events_producer_type_created_idx (producer_id, event_type, created_at)   -- funil + FK producers
+ index producer_events_type_producer_idx         (event_type, producer_id)               -- métrica-norte (distinct)
+ index producer_events_report_idx / _report_item_idx / _artist_idx                       -- RESTRICT + escopo
+ UNIQUE PARTIAL index producer_events_intent_dedup_uidx (producer_id, artist_id, report_id)
    WHERE event_type = 'intent_to_produce_declared'                                       -- dedup do NORTE
+ function producer_events_immutable()  search_path=''   -- raise p/ qualquer tg_op (row + statement)
+ trigger producer_events_no_update_delete (before update/delete, row)
+ trigger producer_events_no_truncate      (before truncate, statement)
+ enable row level security  +  revoke all from anon, authenticated   -- default-deny; ZERO policy
```
**Totais:** 1 tabela · 1 enum (14 labels) · 4 FK (todas RESTRICT) · 2 CHECK · 6 índices · 1 função · 2 triggers · RLS-on · 0 policy.

## 4. Decisões de modelagem (e por quê)
- **Append-only por TRIGGER abaixo do service_role (SEC-F16).** Como `audit_events`/`rubric_versions`: uma função única levanta exceção em qualquer `tg_op` (sem referenciar NEW/OLD → serve row **e** statement); dois triggers cobrem `UPDATE/DELETE` (row) e `TRUNCATE` (statement). RLS/grants não bastam — service_role bypassa RLS e mantém TRUNCATE. **INSERT é a única mutação válida.** Evento é log, não flag (04_ §1.3).
- **Proveniência por FK `ON DELETE RESTRICT`.** `producer_id`/`report_id`/`report_item_id`/`artist_id` → tabelas-âncora. Nenhuma linha referenciada por um evento pode ser apagada; via `report_item_id → report_items` a cadeia da Fase 5 leva o evento até `artist_metrics → artist_metric_videos → raw_youtube_videos`. (Difere de `applications`, que usa CASCADE: evento é log sagrado, não dado descartável.)
- **Opcionalidade fiel ao 04_ §8.** `report_id`/`report_item_id`/`artist_id` são **opcionais** (eventos como `wtp_*`/`application_submitted` não têm relatório). Exceção: **intent** exige `artist_id`+`report_id` (CHECK) — é declarado sobre um artista num relatório e é o grão da métrica-norte.
- **Métrica-norte auditável + dedup sem quebrar append-only.** `intent_to_produce_declared` é calculável por query (04_ §13). O **índice parcial único** `(producer_id, artist_id, report_id) WHERE event_type='intent…'` garante **um intent por (produtor, artista, relatório)**: re-declarar é `unique_violation` (no-op idempotente), **nunca** um UPDATE/DELETE. O CHECK de contexto garante que o grão é não-nulo (NULL não dedupa).
- **`metadata` storage-only + SEC-F08.** Detalhe de produto (ex.: superfície do clique), **nunca** envelope de transporte/secret — CHECK barra `config/request/headers/authorization/key` (espelha o raw da Fase 4). **PII:** a identidade do produtor vive em `producers` (server/admin-only) via `producer_id`; `metadata` não deve carregar PII — **sinalizado para Security (revisão diferida)**.
- **Default-deny (SEC-F13/F07).** RLS-on + `revoke` de anon/authenticated; **zero `create policy`/view**. A leitura do produtor (estado de UI deriva server-side — SEC-F07) e as policies admin/produtor ficam na **Fase 9** (vetada — SEC-0001 §0). Escrita legítima = service-role/RPC atômica (DEC-0004).
- **Zona determinística intacta.** Eventos são fatos de comportamento; **zero** número/Score/IA aqui. Sem tabela de marketplace/Fase 2.

## 5. Mapa métrica → query (04_ §13) habilitado
| Métrica | Query (eventos) | Suporte no schema |
|---|---|---|
| Intenção declarada (NORTE) | `count(distinct producer_id) where event_type='intent_to_produce_declared'` ÷ `… where 'report_opened'` | índice `(event_type, producer_id)`; dedup parcial único |
| Confirmação em follow-up | `count('followup_confirmed_produced')` ÷ `count('intent_to_produce_declared')` | enum + índices |
| WTP positivo | `count(distinct producer_id where 'wtp_yes')` ÷ `… com resposta WTP` | enum (`wtp_*`) |
| Utilidade HOT | `count(HOT marked useful)` ÷ `count(HOT viewed)` | `artist_marked_useful` + `report_item_id`→snapshot |

## 6. Verify §4/§5 (`phase6_post_apply_verify.sql`, fail-closed, 2 role-paths)
- **§4 estrutural:** tabela; enum com **14 labels** (+ presença do label-norte); colunas mandatórias; `producer_id`/`event_type`/`created_at` NOT NULL; função imutável `search_path`-pinned; **2 triggers**; **4 FK nomeadas**; **todas as FK RESTRICT**; **2 CHECK**; 6 índices; índice de dedup **UNIQUE + PARTIAL** (assert `indisunique` + `indpred not null`); RLS-on; **zero policies**.
- **§5 empírico (probes revertidos, `ON_ERROR_STOP=1`):** **append-only** (`UPDATE`/`DELETE`/`TRUNCATE` bloqueados nos 2 role-paths — `restrict_violation` como postgres; `restrict_violation` OR `insufficient_privilege` como service_role; `INSERT` permitido) · **proveniência** (`DELETE` de producer/report/report_item/artist referenciado → bloqueado) · **métrica-norte** (intent duplicado por (produtor,artista,relatório) → `unique_violation`; outro artista → aceito; intent sem artista/relatório → `check_violation`) · **SEC-F08** (metadata com envelope/secret → `check_violation`; metadata limpa → aceita) · **default-deny** (anon/authenticated → `insufficient_privilege`).

## 7. Rollback
`supabase/rollback/20260620000007_phase6_producer_events.rollback.sql` — declarado, **NÃO executado**: triggers → função → tabela → enum. Fora de `migrations/`. **Ressalva:** evento é log de validação; rollback só p/ ambiente sem evento real (design/teste / antes do 1º publish). `DROP TABLE` é DDL (não dispara o trigger de imutabilidade).

## 8. Fora de escopo desta tarefa (sequenciado adiante)
- **NÃO aplicar** (sem `change_db_schema`/`run_migration`; sem `phase6-db-apply.yml` agora).
- **NÃO autorar policies RLS executáveis** (`define_rls_policy`) — só `enable`+`revoke`.
- **RPC atômica evento+payload (DEC-0004)** e tabelas **`followups`/`wtp_responses`** — adjacentes, sequenciadas no ponto de captura, não neste design.
- **Endpoints de escrita de evento (Backend)** — fora do `database_agent`.

## 9. Revisões DIFERIDAS (até a captura virar gargalo — não disparadas agora)
- [ ] **Security & Privacy** (matrix #3) — RLS/imutabilidade/**PII do produtor**: confirmar `metadata` sem PII; política de leitura (SEC-F07) e exposição na Fase 9; SEC-F08 suficiente na camada de banco.
- [ ] **Data/AI** (matrix #4/#5) — auditabilidade da **métrica-norte** e do funil feedback→intenção→follow-up (04_ §13); dedup correto; eventos como fatos (não números).
- [ ] **Backend** — contrato de **escrita** de evento (RPC atômica DEC-0004; coerência `report_item↔report` no write-layer, já que `report_items` aplicado não expõe unique `(id, report_id)` para FK composta — ver §10).
- [x] **Database** — autor (este handoff).

## 10. Notas de integridade conhecidas (registradas, não-bloqueantes)
- **Coerência `event.report_id == report_item.report_id`** não é FK-enforçável sem alterar a Fase 5 (já aplicada/FROZEN — `report_items` não tem unique `(id, report_id)` alvo de FK composta). Decisão: as FKs garantem **existência + RESTRICT** de cada âncora; a **coerência** entre âncoras de um mesmo evento é responsabilidade da **RPC atômica de escrita (DEC-0004)** — registrado para o gate de Backend. Não se altera tabela aplicada por conveniência.
- **PII:** nenhuma coluna de PII nova; identidade via `producer_id` (FK a `producers`, server/admin-only). `metadata` é detalhe de produto sob SEC-F08. Decisão final de privacidade → Security (diferida).

## 11. Impacto no escopo / não-negociáveis
- **MVP travado?** Sim. 1 tabela de eventos (04_ §8); **zero** marketplace/Fase 2 (04_ §12).
- **Não-negociáveis honrados:** **append-only** (trigger abaixo do service_role), **proveniência** RESTRICT até o snapshot/raw, **métrica-norte auditável + dedupada**, **default-deny** + **zero policy** (Fase 9 intacta), **PII sinalizada**, **número de código nunca de IA** (eventos = fatos).

## 12. Próximos passos / `next_recommendation`
1. **HOLD** em `design_complete_no_apply` (esta tarefa termina aqui; nenhuma revisão disparada).
2. Quando a **captura de eventos virar gargalo** (pós 1º publish — DEC-0013 §3): disparar as revisões §9 (Security/Data·AI/Backend); depois a **task gated separada** de `run_migration` (`phase6-db-apply.yml`, `APPLY-PHASE6`, Environment `production-db`, dispatch de `main`/SEC-F18; verify fail-closed), espelhando Fases 1–5.
3. Adjacentes em seguida: **RPC atômica DEC-0004** + `followups`/`wtp_responses` no ponto de captura.
- **Vetos de pé:** Fase 9 — RLS Policies + VIEW pública (SEC-0001 §0). Esta autoria **não** os destrava.
