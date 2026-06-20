# Migration Plan — NOXUND MVP (ordem recomendada)

**Status:** plano. **Nenhuma migration criada nesta etapa.** Sem schema real no Supabase.
Quando implementar: cada migration é versionada, com **rollback**, e passa por **Database + Security review** (`agent-review-matrix.md` #3). Raw nunca recebe rota de `UPDATE`.

Ordem pensada para respeitar dependências de FK e o princípio raw→computed→snapshot.

---

## Fase 1 — Core Identity / Access
**Tabelas:** `producers`, `applications`.
**Por quê primeiro:** sem dependências; habilita o approval gate e `/apply`.
**Inclui:** enums de status; unicidade `lower(email)`; índice parcial de aplicação aberta.
**Critério (backlog [DB] Schema base):** aplicação pode ser enviada e aprovada; FKs e enums corretos.
**Revisão:** Database + Security (PII, identidade vs Supabase Auth — OD-DB-08).
**Rollback:** drop limpo (sem dependentes ainda).

## Fase 2 — Versionamento
**Tabelas:** `rubric_versions`, `outcome_weight_versions`.
**Por quê antes de computed:** `artist_metrics`/`report_runs` referenciam `rubric_version` + `rubric_hash`.
**Inclui:** unicidade de `version`; `hash` determinístico.
**Revisão:** Data/AI (semântica do rubric — matriz #5 se mudar pesos).

## Fase 3 — Reports/Artists (esqueleto) + Runs
**Tabelas:** `report_runs` (ou `collection_runs`+`scoring_runs` se OD-DB-01 aprovado), `artists`, `artist_aliases`.
**Por quê aqui:** `run_id` e `artist_id` são âncoras de quase tudo a seguir.
**Nota:** `reports`/`report_items` só na Fase 5 (dependem de computed).
**Revisão:** Data/AI (modelo de run e reprodutibilidade), Product Orchestrator (OD-DB-01).

## Fase 4 — Raw YouTube Snapshots (imutável)
**Tabelas:** `raw_youtube_search_pages`, `raw_youtube_videos`, `raw_youtube_channels`.
**Inclui:** unicidade lógica `(run_id, video_id)` / `(run_id, channel_id)`; **garantia de ausência de rota de UPDATE/DELETE** (grants/RLS/trigger).
**Critério (backlog [DB] Tabelas raw):** recoleta cria novo `run_id`; nenhuma rota de update em raw.
**Revisão:** Database + Data/AI (imutabilidade do raw — matriz #4).
**Rollback:** drop só admissível se a run for descartável; em prod, raw não se apaga.

## Fase 5 — Computed Metrics + Resolução + Relatório
**Tabelas:** `video_artist_mappings`, `channel_eligibility`, `artist_metrics`, depois `reports`, `report_items`.
**Por quê esta ordem interna:** mappings/eligibility → metrics → report_items (congelado no publish).
**Inclui:** `(run_id, artist_id)` único em metrics; `report_items.artist_metric_id` (OD-DB-06); `selection_reason_json`; FKs `ON DELETE RESTRICT` para não perder proveniência.
**Critério (backlog [DB] computed + relatório):** computed recalculável a partir do raw; relatório reconstruível por `run_id` + `rubric_version`; eventos são log.
**Revisão:** Data/AI (raw/computed, proveniência por célula — OD-DB-06/07), Database.

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

## Fase 8 — Audit Events
**Tabelas:** `audit_events` (se OD-DB-03 aprovado).
**Inclui:** append-only; polimórfico `(entity_table, entity_id)`; `before_json`/`after_json`.
**Critério:** ações sensíveis (aprovação, publicação, overrides) registradas.
**Revisão:** Security (acesso restrito — eventos sensíveis), Database.

## Fase 9 — RLS Policies
**Não é tabela:** políticas RLS para todas as tabelas acima.
**Por quê por último:** policies dependem de todas as tabelas e roles existirem; é onde Security tem **veto**.
**Inclui:** isolamento por produtor, leitura de relatórios publicados só por aprovados, admin/service-role para sensíveis, bloqueio de update em raw.
**Critério:** RLS testada; produtor só vê o que pode; admin separado por role.
**Revisão:** **Security + Database** (matriz #3). Detalhe das recomendações em `rls-review-notes.md`.

---

## Regras transversais para toda migration

1. **Reversível:** toda migration aplica e reverte (DoD do Database Agent). Migration destrutiva só com revisão acordada.
2. **Raw sagrado:** nenhuma migration introduz rota de `UPDATE`/`DELETE` em tabela RAW.
3. **Snapshot congelado:** nenhuma migration altera `report_items` de relatório `published`.
4. **Sem Fase 2:** nenhuma migration cria tabela de marketplace (`04_...` §12) — gatilho de bloqueio do Product Orchestrator.
5. **Seeds:** apenas dados fake de desenvolvimento; nunca dados reais de produtor (`supabase/README.md`).
6. **Cada migration carrega** no handoff: diff de schema, impacto raw/computed, plano de rollback (contrato do Database Agent).

---

## Dependências externas que destravam fases

| Fase | Depende de (OPEN DECISION / outro agente) |
|---|---|
| 1 | OD-02 (Auth: Supabase Auth) → identidade de `producers` |
| 3 | OD-DB-01 (split de runs) → forma de `report_runs` |
| 7 | OD-03 (Email), OD-04 (Cron) → `followups.channel` e processamento de due |
| 8 | OD-DB-03 (criar `audit_events`) |
| 9 | Auth + roles definidos (Security) |
