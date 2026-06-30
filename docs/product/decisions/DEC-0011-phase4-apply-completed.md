## DEC-0011 — Fechamento do gate board do apply da Fase 4 (`run_migration` aplicado e verificado — Raw YouTube Snapshots imutável)

- **Data:** 2026-06-27
- **Status:** **Registrada — fato consumado.** Apply executado e verificado em CI; `task_phase4_run_migration` transiciona `needs_review` → `completed`.
- **Decisor:** Product Lead (disparou o apply em CI de `main`, aprovou como required reviewer) · registrada pelo Product Orchestrator
- **Área:** Schema / Segurança / Imutabilidade do raw / Processo de gate
- **Relaciona:** SEC-0012 (`review_rls` do DDL+verify — matrix #3), DATA-AI-0004 (`validate_reproducibility` — matrix #4: imutabilidade/reprodutibilidade do raw), SEC-0013 (`audit_secrets` da pipeline — matrix #8), `HANDOFF-phase4-apply-closeout.md` (evidência canônica + ratificação `database_agent`), `HANDOFF-phase4-design.md` (desenho — banner de resolução aplicado), DEC-0009 (precedente Fase 3 — lição SEC-F21/F22 embutida antes do apply), DEC-0010 (precedente Fase 2 — convenção closeout+DEC), DEC-0008 (precedente Fase 1), `migration-plan.md` §Fase 4

### Contexto
Os gates do `run_migration` da Fase 4 foram satisfeitos **na ordem correta**: DDL + verify revisados pelo Security (**SEC-0012** — `review_rls`, sem bloqueio) → Data/AI #4 (**DATA-AI-0004** — `validate_reproducibility`: imutabilidade do raw e reprodutibilidade por `run_id`, sem veto metodológico) → pipeline de apply auditada (**SEC-0013** — `audit_secrets`, espelho da Fase 3 endurecida) → required reviewers do Environment `production-db`, dispatch **de `main`** (SEC-F18). A lição da Fase 3 (errcode-parity `restrict_violation OR insufficient_privilege` — SEC-F21 — e probe positivo de freeze grant-holder — SEC-F22) foi embutida no `verify` **antes** do apply, sem necessidade de hotfix. Com isso, o apply ocorreu **via CI**, forward-only e atômico.

### Decisão (o que se registra)
1. **A migration da Fase 4 está aplicada e verificada em produção** (`pwbkplzyzmortwjjpcbg`): `supabase/migrations/20260620000004_phase4_raw_youtube_snapshots.sql`, forward-only, atômica (`begin`…`commit`; **zero** drop/delete/truncate). **`raw_youtube_search_pages`, `raw_youtube_videos` e `raw_youtube_channels` estão live** — o substrato bruto e imutável de onde todo número público é rastreável.
2. **O gate board do `run_migration` Fase 4 está integralmente fechado** (tabela abaixo). A tarefa `task_phase4_run_migration` é `completed`, com evidência canônica em `HANDOFF-phase4-apply-closeout.md` e ratificação do `database_agent` (`status=completed`, record-only — sem reaplicar, sem rollback, sem DDL/DML novo, raw intocado).
3. **A trilha de apply segue íntegra e consistente:** **Fase 1 (DEC-0008) → Fase 2 (DEC-0010) → Fase 3 (DEC-0009) → Fase 4 (DEC-0011)** — todas com o par closeout+DEC e evidência de run gated (convenção reforçada na DEC-0010 honrada).
4. **Nenhum gate downstream foi destravado por este apply.** Em especial, o **veto da Fase 9 — RLS Policies (SEC-0001 §0)** permanece de pé (`grep "create policy"` na migration → NONE; apenas `enable row level security` + `revoke`, default-deny puro).

### Evidência de registro
| Item | Evidência |
|---|---|
| Run do pipeline | `phase4-db-apply.yml` → https://github.com/AdeptLabsDev/noxund/actions/runs/28277270507 (origem `main`) |
| Jobs | `guard` (`APPLY-PHASE4`) · `apply` (`supabase db push`, forward-only) · `verify` — todos **success** |
| Verificação | `phase4_post_apply_verify.sql` (L281) com `ON_ERROR_STOP=1` → `OK — Phase 4 post-apply verification PASSED (§4 structural + §5 empirical).` |
| Aprovação em runtime | required reviewer **AdeptLabsDev** (encarna DevOps+Security), origem `main` (reconfirma SEC-F18), rollback de produção **não** executado |
| Ratificação | `database_agent` (`status=completed`; conferiu repo-side que a linha final do verify bate **verbatim** e que a migration é a autorada; run de CI como evidência de registro, sem forjar) |

### Gate board final do `run_migration` Fase 4
| Gate | Fonte | Estado |
|---|---|---|
| `review_rls` do DDL + verify (matrix #3) | SEC-0012 | ✅ liberado, sem bloqueio |
| Data/AI #4 — imutabilidade/reprodutibilidade do raw (`validate_reproducibility`) | DATA-AI-0004 | ✅ aprovado, sem veto metodológico |
| `audit_secrets` da pipeline (matrix #8) | SEC-0013 | ✅ sem bloqueio (espelho da Fase 3 endurecida) |
| Required reviewers em CI (origem `main`, SEC-F18) | run `28277270507` | ✅ AdeptLabsDev |
| Apply forward-only + verify §4/§5 fail-closed | run `28277270507` | ✅ guard·apply·verify success |

### Impacto
- **Escopo:** nenhum desvio. 3 tabelas RAW (`04_…` §4); **zero** tabela de marketplace/Fase 2-produto (`04_…` §12).
- **Non-negotiables — provados em banco no run (§5 empírico, nos 2 caminhos de role):**
  - **raw imutável** — `UPDATE`/`DELETE`/`TRUNCATE` bloqueados **abaixo do `service_role`** pelo trigger (`restrict_violation`) e também como grant-holder `postgres` (prova de que a imutabilidade é o trigger, não a ausência de grant — SEC-F22); como `service_role`, bloqueado por trigger **OU** grant (`restrict_violation`/`insufficient_privilege` — SEC-F21, lição da Fase 3 embutida antes do apply);
  - **default-deny** — `anon`/`authenticated` → `insufficient_privilege` nas 3 (RLS-on, zero policy);
  - **proveniência por `run_id`** — unicidade lógica `(run_id, video_id)`/`(run_id, channel_id)`; 3 FK → `report_runs` `ON DELETE RESTRICT` (recoleta = novo `run_id`, raw nunca sobrescrito);
  - **secrets fora de repo/log/payload** — 3 CHECK SEC-F08: corpo de resposta limpo aceito, envelope de request (`config`/`request`/`key`) rejeitado (`check_violation`); SEC-0013 confirma pipeline limpa.

### Reversibilidade
Alta no nível de schema: `supabase/rollback/20260620000004_phase4_raw_youtube_snapshots.rollback.sql` permanece como rede de segurança **declarada e não executada**. **Raw sagrado:** em produção raw não se apaga; o rollback só é admissível para run(s) descartável(is).

### Carry-forward (não-bloqueante — registrado, não é gate deste apply)
- **SEC-F23 (de SEC-0012):** o scrub autoritativo do payload (extrair só o body) e a higiene de log (SEC-F08/F10) são gate de **pipeline** (Data/AI + Backend + DevOps) **quando a coleta real for ligada** — **não** de schema. O CHECK top-level já entregue é defesa-em-profundidade suficiente na camada de banco. Sem trava sobre este apply; reentra como critério de aceite das fases de coleta/handlers.

### Sequenciamento (próximo)
1. **Trilha íntegra (Fases 1–4).** Nenhuma pendência de proveniência.
2. **Fundação seguinte — Fase 5 (Computed Metrics + Resolução + Relatório):** `video_artist_mappings`, `channel_eligibility`, `artist_metrics`, depois `reports`, `report_items`, na ordem do `migration-plan.md` §Fase 5 (mappings/eligibility → metrics → report_items congelado no publish). Inclui `(run_id, artist_id, rubric_hash)` único em metrics; `metrics_detail_json` (OD-DB-07); `report_items.artist_metric_id` (OD-DB-06); `selection_reason_json`; FKs `ON DELETE RESTRICT`. DDL ainda **não** autorado — owner `database_agent`; FK futura por `(rubric_version, rubric_hash)` → `rubric_versions` (Fase 2). Revisão **Data/AI** (computed recalculável a partir do raw + reprodutibilidade do relatório) + **Database** (migration) + **Backend** (consumo de `artist_metric_id` nos endpoints). Apply gated próprio.
3. **Sob veto, não sequenciar:** Fase 9 — RLS Policies (SEC-0001 §0). Este apply **não** o destrava.
