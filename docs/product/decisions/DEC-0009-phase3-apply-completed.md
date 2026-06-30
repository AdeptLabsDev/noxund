## DEC-0009 — Fechamento do gate board do apply da Fase 3 (`run_migration` aplicado e verificado)

- **Data:** 2026-06-26
- **Status:** **Registrada — fato consumado.** Apply executado e verificado em CI; `task_phase3_run_migration_apply` transiciona `needs_review` → `completed`.
- **Decisor:** Product Lead (disparou o apply em CI de `main`, aprovou como required reviewer) · registrada pelo Product Orchestrator
- **Área:** Schema / Segurança / Processo de gate
- **Relaciona:** SEC-0009 (veto técnico do DDL baixado), SEC-0010 (re-review do verify — SEC-F21/F22), SEC-0011 (audit da pipeline de apply), `DATA-AI-REVIEW-phase3-runs-artists.md` (Data/AI #5), `HANDOFF-phase3-apply-pipeline.md` (DevOps), `HANDOFF-phase3-apply-closeout.md` (evidência canônica + ratificação `database_agent`), DEC-0008 (precedente — Fase 1), `migration-plan.md` §Fase 3

### Contexto
Os gates do `run_migration` da Fase 3 foram satisfeitos **na ordem correta**: SEC-0009 (veto técnico do DDL) baixado → Data/AI #5 (`DATA-AI-REVIEW-phase3-runs-artists.md` — identidade/dedupe de artista + placement de `rubric_*` em `report_runs` vs `artist_metrics`) → verify com **SEC-F21** (errcode-parity `restrict_violation OR insufficient_privilege`) e **SEC-F22** (probe positivo de freeze grant-holder) corrigidos e re-revisados (SEC-0010) → PR atômico só-Fase-3 revisado e mergeado na `main` **sem push direto** → required reviewers do Environment `production-db` (DevOps+Security), dispatch **de `main`** (SEC-F18). Com isso, o apply ocorreu **via CI**, forward-only e atômico.

### Decisão (o que se registra)
1. **A migration da Fase 3 está aplicada e verificada em produção** (`pwbkplzyzmortwjjpcbg`): `supabase/migrations/20260620000003_phase3_runs_artists.sql`, forward-only, atômica. **`report_runs` (âncora de proveniência por `run_id`), `artists` e `artist_aliases` estão live.**
2. **O gate board do `run_migration` Fase 3 está integralmente fechado** (tabela abaixo). A tarefa `task_phase3_run_migration_apply` é `completed`, com evidência canônica em `HANDOFF-phase3-apply-closeout.md` e ratificação do `database_agent` (`status=completed`, record-only — sem reaplicar, sem rollback, sem §7 seed, sem DDL/DML novo).
3. **Nenhum gate downstream foi destravado por este apply.** Em especial, o **veto da Fase 9 — RLS Policies (SEC-0001 §0)** permanece de pé.

### Evidência de registro
| Item | Evidência |
|---|---|
| Run do pipeline | `phase3-db-apply.yml` → https://github.com/AdeptLabsDev/noxund/actions/runs/28234275173 (origem `main`) |
| Jobs | `guard` (`APPLY-PHASE3`) · `apply` (`supabase db push`, forward-only) · `verify` — todos **success** |
| Verificação | `phase3_post_apply_verify.sql` com `ON_ERROR_STOP=1` → `OK — Phase 3 post-apply verification PASSED (§4 structural + §5 empirical).` |
| Aprovação em runtime | required reviewer **AdeptLabsDev** (encarna DevOps+Security), origem `main` (reconfirma SEC-F18) |
| Ratificação | `database_agent` (`status=completed`; conferiu repo-side que a linha final do verify bate **verbatim** e que a migration é a autorada; run de CI como evidência de registro, sem forjar) |

### Gate board final do `run_migration` Fase 3
| Gate | Fonte | Estado |
|---|---|---|
| Veto técnico do Security (DDL) | SEC-0009 | ✅ baixado |
| Data/AI #5 (identidade/dedupe + placement `rubric_*`) | `DATA-AI-REVIEW-phase3-runs-artists.md` | ✅ baixado |
| Verify corrigido (errcode-parity + freeze grant-holder) | SEC-F21 / SEC-F22 → SEC-0010 | ✅ resolvidos + re-review |
| PR atômico revisado + mergeado na `main`, sem push direto | — | ✅ fechado |
| Required reviewers em CI (origem `main`, SEC-F18) | INFRA-0001 §3 / SEC-0011 | ✅ AdeptLabsDev aprovou |
| Apply forward-only + verify §4/§5 fail-closed | run `28234275173` | ✅ success |

### Impacto
- **Escopo:** nenhum desvio. 3 tabelas de runs/identidade de artista; **zero** tabela de marketplace/Fase 2-produto.
- **Non-negotiables — provados em banco no run:** **raw imutável** (âncora `report_runs` indeletável e com identidade de coleta congelada — `TRUNCATE`/`DELETE`/`UPDATE keyword` bloqueados via `restrict_violation`/`insufficient_privilege` — SEC-F21; freeze por-coluna também provado como grant-holder — SEC-F22; `UPDATE status` benigno passa); **default-deny** (`anon`/`authenticated` sem acesso às 3 — SEC-F02/F13); **proveniência por `run_id`**. "Sem push direto na `main`" honrado (merge por PR). Secrets fora de repo/log/payload.

### Reversibilidade
Alta no nível de schema: `supabase/rollback/20260620000003_phase3_runs_artists.rollback.sql` permanece como rede de segurança **declarada e não executada**.

### ⚠️ Lacuna de proveniência registrada — Fase 2 (escalada → ✅ RESOLVIDA na DEC-0010)
Ao espelhar o padrão das Fases 1–3, o Orchestrator identificou que a **Fase 2 (Versionamento) não possuía closeout evidenciado nem DEC de conclusão**: existia apenas `HANDOFF-phase2-apply.md` (pré-apply, status `⏳ aguardando gate humano`). A Fase 2 estava **aplicada** (o run da Fase 3 assumiu "Fases 1–2 já trackeadas" e passou; commits `phase2/versioning-apply` + `phase2/verify-hotfix`), mas **sem o registro de proveniência** que as Fases 1 e 3 têm. Foi **escalado como `OD-PROV-02`** (rastreabilidade total — Mission).
> **✅ Resolvida (2026-06-26):** Product Lead escolheu a Opção A e forneceu o run gated da Fase 2 (`28129447446`, origem `main`, `APPLY-PHASE2`, reviewer `AdeptLabsDev`). `database_agent` emitiu `HANDOFF-phase2-apply-closeout.md` (backfill record-only) e o Orchestrator registrou **`DEC-0010`** fechando o gate board da Fase 2. **Trilha íntegra: Fase 1 (DEC-0008) → Fase 2 (DEC-0010) → Fase 3 (DEC-0009).**

### Sequenciamento (próximo)
1. **Reparo da trilha da Fase 2** (prioridade — ver `escalate` associado): com a URL do run gated da Fase 2, `database_agent` emite `HANDOFF-phase2-apply-closeout.md` e o Orchestrator registra o DEC correspondente.
2. **Fundação seguinte — Fase 4 (Raw YouTube Snapshots):** `raw_youtube_search_pages` / `raw_youtube_videos` / `raw_youtube_channels` na ordem do `migration-plan.md`. DDL ainda **não** autorado — owner `database_agent`; **raw imutável por trigger `BEFORE UPDATE/DELETE/TRUNCATE`** (SEC-D03/SEC-F16, pois `service_role` faz bypass de RLS — SEC-F01) + scrub de contexto de request no payload (SEC-F08). Revisão **Database + Security** (matrix #3) + **Data/AI** (matrix #4 — imutabilidade do raw).
3. **Sob veto, não sequenciar:** Fase 9 — RLS Policies (SEC-0001 §0) até o review dedicado do Security. Este apply **não** o destrava.
