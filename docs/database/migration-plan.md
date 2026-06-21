# Migration Plan — NOXUND MVP (ordem recomendada)

**Status:** plano. **Nenhuma migration criada nesta etapa.** Sem schema real no Supabase.
Quando implementar: cada migration é versionada, com **rollback**, e passa por **Database + Security review** (`agent-review-matrix.md` #3). Raw nunca recebe rota de `UPDATE`.

Ordem pensada para respeitar dependências de FK e o princípio raw→computed→snapshot.

---

## Fase 1 — Core Identity / Access
**Tabelas:** `producers`, `applications`, **`admin_users`** (SEC-D02), **`audit_events`** (SEC-0002 §3 — **antecipada da Fase 8**: aprovação de produtor e grant/revoke de admin exigem trilha imutável desde a 1ª operação).
**Por quê primeiro:** sem dependências; habilita o approval gate e `/apply`.
**DDL autorado (não aplicado):** `supabase/migrations/20260620000001_phase1_core_identity_access.sql` · rollback em `supabase/rollback/20260620000001_phase1_core_identity_access.rollback.sql`.
**Inclui:**
- `producers.auth_user_id uuid unique` → `auth.users(id)` **`ON DELETE SET NULL`** (SEC-D01); **sem** coluna de senha/hash (SEC-F12).
- `admin_users` + helper `is_admin()` `SECURITY DEFINER` **+ `SET search_path = ''` fixo + `STABLE` + referência qualificada** (SEC-D02 + **SEC-F15**); admin nunca derivado de `user_metadata`.
- `audit_events` + **trigger `BEFORE UPDATE/DELETE` obrigatório** (SEC-D03) + default-deny; policy de leitura admin fica na Fase 9.
- enums de status; unicidade `lower(email)`; índice parcial de aplicação aberta.
- **RLS:** `ENABLE ROW LEVEL SECURITY` nas 4 tabelas + **default-deny**; **zero `GRANT`/policy a `anon`/`authenticated`** (SEC-F13/F02); `revoke all` explícito sobre os defaults do Supabase.
- **Bootstrap do 1º admin** por service-role + `audit_events(action='admin.bootstrap')`, **sem auto-promoção** (SEC-0002 §5.5) — template comentado no SQL, não executado.
- **`/apply` whitelist (SEC-F02 — Backend):** `anon` zero-grant; escrita por handler service-role com whitelist; `status` forçado server-side. (Contrato de handler é do Backend; o schema não facilita mass-assignment.)
**Critério (backlog [DB] Schema base):** aplicação pode ser enviada e aprovada; FKs e enums corretos; aplicante não seta `status`/`reviewed_by`/`approved_at`/`auth_user_id`; `audit_events` imutável; `is_admin()` blindado.
**Revisão:** Database + Security. **Gate de `run_migration` (SEC-0002 §5):** Security re-revisa o **SQL concreto** contra as 6 condições antes de qualquer apply; veto de apply mantido até lá.
**Rollback:** declarado e reversível (arquivo de rollback acima); ordem respeita FKs (filhos→pais, objetos→tipos).

## Fase 2 — Versionamento
**Tabelas:** `rubric_versions`, `outcome_weight_versions`.
**Por quê antes de computed:** `artist_metrics`/`report_runs` referenciam `rubric_version` + `rubric_hash`.
**Inclui:** unicidade de `version`; `hash` determinístico.
**Revisão:** Data/AI (semântica do rubric — matriz #5 se mudar pesos).

## Fase 3 — Reports/Artists (esqueleto) + Runs
**Tabelas:** `report_runs` (unificado no MVP — OD-DB-01 ratificado por Data/AI), `artists`, `artist_aliases`.
**Por quê aqui:** `run_id` e `artist_id` são âncoras de quase tudo a seguir.
**Nota:** `reports`/`report_items` só na Fase 5 (dependem de computed).
**Revisão:** Data/AI/PO já ratificaram OD-DB-01 no desenho; migration ainda passa por Database + Security quando houver DDL real.

## Fase 4 — Raw YouTube Snapshots (imutável)
**Tabelas:** `raw_youtube_search_pages`, `raw_youtube_videos`, `raw_youtube_channels`.
**Inclui:** unicidade lógica `(run_id, video_id)` / `(run_id, channel_id)`; **trigger `BEFORE UPDATE/DELETE` obrigatório** (SEC-D03) — grants/RLS não bastam porque `service_role` faz bypass de RLS (SEC-F01); scrub de contexto de request no payload (SEC-F08, sem key vazada).
**Critério (backlog [DB] Tabelas raw):** recoleta cria novo `run_id`; nenhuma rota de update em raw; trigger barra UPDATE/DELETE até via service-role.
**Revisão:** Database + Data/AI (imutabilidade do raw — matriz #4); Security (trigger SEC-D03).
**Rollback:** drop só admissível se a run for descartável; em prod, raw não se apaga.

## Fase 5 — Computed Metrics + Resolução + Relatório
**Tabelas:** `video_artist_mappings`, `channel_eligibility`, `artist_metrics`, depois `reports`, `report_items`.
**Por quê esta ordem interna:** mappings/eligibility → metrics → report_items (congelado no publish).
**Inclui:** `(run_id, artist_id, rubric_hash)` único em metrics; `artist_metrics.metrics_detail_json` (OD-DB-07); `report_items.artist_metric_id` (OD-DB-06); `selection_reason_json`; FKs `ON DELETE RESTRICT` para não perder proveniência.
**Critério (backlog [DB] computed + relatório):** computed recalculável a partir do raw; relatório reconstruível por `run_id` + `rubric_version`/`rubric_hash`; eventos são log.
**Revisão:** Data/AI ratificou raw/computed e OD-DB-06/07 no desenho; migration ainda passa por Database, e Backend valida consumo de `artist_metric_id` nos endpoints.

## Fase 6 — Producer Outcomes (eventos)
**Tabelas:** `producer_events`.
**Inclui:** enum de `event_type` (canônico `04_...` §8); índices `(producer_id, event_type, created_at)`; **append-only** (sem UPDATE/DELETE).
**Critério:** toda interação gera evento; nenhuma flag booleana de estado.
**Revisão:** Database (schema/eventos — matriz #2), Backend (escrita), Product Orchestrator (OD-DB-02/05).

## Fase 7 — Follow-ups + WTP
**Tabelas:** `followups`, `wtp_responses`.
**Por quê depois dos eventos:** `followups.producer_event_id` referencia o evento de intenção.
**Inclui:** índice `followups(status, due_at)` p/ cron; escrita atômica evento+payload no WTP.
**Critério:** intenção gera follow-up pendente; WTP persiste resposta + evento.
**Revisão:** Backend, Database; Security (cron protegido — OD-04).

## Fase 8 — Audit Events ⟶ **movida para a Fase 1**
**Status:** `audit_events` foi **antecipada para a Fase 1** por decisão do Security (SEC-0002 §3) — aprovação de produtor e grant/revoke de admin precisam de trilha imutável desde a 1ª operação. A tabela + `ENABLE RLS` + default-deny + trigger de imutabilidade (SEC-D03) já entram na Fase 1.
**Resta para a Fase 9 (não aqui):** a **policy de leitura admin** de `audit_events` (não há leitura de auditoria no fluxo da Fase 1).
**Critério (herdado):** ações sensíveis (aprovação, publicação, overrides, grant/revoke de admin) registradas e imutáveis — coberto pela Fase 1.

## Fase 9 — RLS Policies
**Não é tabela:** políticas RLS para todas as tabelas acima.
**Por quê por último:** policies dependem de todas as tabelas e roles existirem; é onde Security tem **veto** (mantido — SEC-0001 §0).
**Gate de entrada (bloqueante, SEC-0001):** esta fase **não abre** sem o re-review do Security e sem o desenho incorporar:
- **SEC-F01** — authz de propriedade/role **em código** em todo caminho service-role (`session.producer_id === payload.producer_id`; admin por `is_admin()`). RLS só protege `anon`/`authenticated`.
- **SEC-F02** — `/apply`: `anon` zero-grant + whitelist + `status` forçado no servidor.
- **SEC-F03** — leitura de produtor em `report_items` por **VIEW pública**; `score_value`/`raw_score`/json interno nunca ao produtor.
- **SEC-F13** — RLS habilitada + **default-deny em TODAS** as tabelas (inclusive internas só-service-role).
- **SEC-F14** — publicação e transições de status só admin + `audit_events`; draft nunca legível por produtor; leitura de relatório exige `published` **E** produtor `approved`.
- **SEC-F07** — default-deny na leitura de `producer_events`/`wtp_responses` pelo produtor (estado de UI deriva server-side).
**Inclui:** isolamento por produtor (`auth_user_id = auth.uid()`), leitura de relatórios publicados só por aprovados, admin/service-role para sensíveis, `is_admin()` nas policies de admin.
**Critério:** RLS testada; produtor só vê o que pode; admin por `admin_users`/`is_admin()`. **Nada de RLS/auth real entra em `main` sem re-review do Security** (silêncio ≠ aprovação).
**Revisão:** **Security (veto) + Database** (matriz #3). Detalhe das recomendações em `rls-review-notes.md`.

---

## Regras transversais para toda migration

1. **Reversível:** toda migration aplica e reverte (DoD do Database Agent). Migration destrutiva só com revisão acordada.
2. **Raw sagrado:** nenhuma migration introduz rota de `UPDATE`/`DELETE` em tabela RAW — e a imutabilidade é garantida por **trigger** (SEC-D03), não só grants/RLS (service-role faz bypass — SEC-F01).
3. **Snapshot congelado:** nenhuma migration altera `report_items` de relatório `published`.
4. **Sem Fase 2:** nenhuma migration cria tabela de marketplace (`04_...` §12) — gatilho de bloqueio do Product Orchestrator.
5. **Seeds:** apenas dados fake de desenvolvimento; nunca dados reais de produtor (`supabase/README.md`).
6. **Cada migration carrega** no handoff: diff de schema, impacto raw/computed, plano de rollback (contrato do Database Agent).

---

## Dependências externas que destravam fases

| Fase | Depende de (OPEN DECISION / outro agente) |
|---|---|
| 1 | OD-02 (Auth: Supabase Auth) → `producers.auth_user_id`; SEC-0002 §5 (re-review do SQL antes do apply); inclui `audit_events` (antecipada) |
| 3 | OD-DB-01 fechado: `report_runs` unificado no MVP (DEC-0003 + DATA-AI-0001) |
| 5 | OD-DB-06/07 fechados para Data/AI → `artist_metric_id`, `metrics_detail_json`; Backend valida consumo em endpoints |
| 7 | OD-03 (Email), OD-04 (Cron) → `followups.channel` e processamento de due |
| 8 | — (`audit_events` movida para a Fase 1 por SEC-0002 §3; resta só a policy de leitura admin na Fase 9) |
| 9 | **Re-review do Security (veto)** + SEC-F01/F02/F03/F13/F14 no desenho; Auth + `admin_users` existentes |

> **Pré-condição global (SEC-0001 + DEC-0003 + DATA-AI-0001):** Data/AI fechou raw/computed, reprodutibilidade sem split e OD-DB-04/06/07 no desenho. Nenhuma migration abre sem as mitigações de **Security** no desenho; Fase 1 só abre após **OD-02 (Auth) confirmada** e revisão **Database + Security**.
