## DEC-0012 — Fechamento do gate board do apply da Fase 5 (`run_migration` aplicado e verificado — Computed Metrics + Resolução + Relatório)

- **Data:** 2026-06-28
- **Status:** **Registrada — fato consumado.** Apply executado e verificado em CI; `task_phase5_run_migration` transiciona `needs_review` → `completed`.
- **Decisor:** Product Lead (disparou o apply em CI de `main`, aprovou como required reviewer) · registrada pelo Product Orchestrator
- **Área:** Schema / Segurança / Metodologia (computed↔raw, reprodutibilidade) / Imutabilidade do publicado / Processo de gate
- **Relaciona:** SEC-0014 (`review_rls` do DDL+verify — matrix #3), DATA-AI-0005 (veto metodológico) → DATA-AI-0006 (re-veto) → **DATA-AI-0007** (aprovação no re-review pré-apply, `validate_reproducibility` — matrix #4/#5), SEC-0015 (`audit_secrets` da pipeline — matrix #8), `HANDOFF-phase5-design.md` (desenho + sequência de gates), `BE-0002-phase5-report-items-consumption-contract.md` (consumo de `artist_metric_id`), DEC-0011 (precedente Fase 4 — lição errcode-parity SEC-F21 embutida antes do apply), DEC-0009 (precedente Fase 3 — lição SEC-F21/F22), DEC-0010 (precedente Fase 2 — convenção closeout+DEC), DEC-0008 (precedente Fase 1), `migration-plan.md` §Fase 5

### Contexto
Os gates do `run_migration` da Fase 5 foram satisfeitos **na ordem correta**: DDL + verify revisados pelo Security (**SEC-0014** — `review_rls`, sem bloqueio) → Data/AI #4/#5 (**veto** em **DATA-AI-0005**, **re-veto** em **DATA-AI-0006**, e **aprovação** em **DATA-AI-0007** — `validate_reproducibility`: computed recalculável a partir do raw, congelamento do publicado e replay por chave natural; achados **DATA-RR-F5-03A/05A/06A/01A fechados**) → pipeline de apply auditada (**SEC-0015** — `audit_secrets`, espelho da Fase 1–4 endurecida) → required reviewers do Environment `production-db`, dispatch **de `main`** (SEC-F18). A lição errcode-parity das Fases 3/4 (`restrict_violation OR insufficient_privilege` no caminho `service_role` — SEC-F21 — e probe positivo de freeze grant-holder — SEC-F22) já estava **embutida no `verify` antes do apply**, sem hotfix. Com isso, o apply ocorreu **via CI**, forward-only e atômico.

### Decisão (o que se registra)
1. **A migration da Fase 5 está aplicada e verificada em produção** (`pwbkplzyzmortwjjpcbg`): `supabase/migrations/20260620000005_phase5_computed_metrics_reports.sql`, forward-only, atômica (`begin` L76 … `commit` L666; **zero** drop/truncate/`delete from`). Estão **live** as **6 tabelas** que fecham a cadeia raw→computed→snapshot: `video_artist_mappings`, `channel_eligibility`, `artist_metrics`, `artist_metric_videos`, `reports`, `report_items`.
2. **O gate board do `run_migration` Fase 5 está integralmente fechado** (tabela abaixo). A tarefa `task_phase5_run_migration` é `completed`, com evidência canônica no run de CI `28311371393`. **Pendente record-only (não-bloqueante):** o closeout `HANDOFF-phase5-apply-closeout.md` do `database_agent` (ratificação repo-side linha-a-linha), para completar a convenção closeout+DEC das Fases 1–4 — delegado a seguir.
3. **A trilha de apply segue íntegra e consistente:** **Fase 1 (DEC-0008) → Fase 2 (DEC-0010) → Fase 3 (DEC-0009) → Fase 4 (DEC-0011) → Fase 5 (DEC-0012)** — toda a fundação de schema (identidade → versionamento → runs/artistas → raw → computed/relatório) aplicada e verificada.
4. **Nenhum gate downstream foi destravado por este apply.** Em especial, o **veto da Fase 9 — RLS Policies + VIEW pública (SEC-0001 §0)** permanece de pé: `grep "create policy"` na migration → as únicas 2 ocorrências são **comentário** (L65/L645, "ZERO create policy"); **zero** `CREATE POLICY` executável e **zero** `CREATE VIEW`. Apenas `enable row level security` (×6) + `revoke` (×6) — default-deny puro.

### Evidência de registro
| Item | Evidência |
|---|---|
| Run do pipeline | `phase5-db-apply.yml` → https://github.com/AdeptLabsDev/noxund/actions/runs/28311371393 (origem `main`) |
| Jobs | `guard` (`APPLY-PHASE5`) · `apply` (`supabase db push`, forward-only) · `verify` — todos **success** |
| Verificação | `phase5_post_apply_verify.sql` com `ON_ERROR_STOP=1` → `OK — Phase 5 post-apply verification PASSED (§4 structural + §5 empirical).` |
| Aprovação em runtime | required reviewer **AdeptLabsDev** (encarna DevOps+Security), origem `main` (reconfirma SEC-F18), rollback de produção **não** executado |
| Verificação repo-side (Orchestrator) | `origin/main` (PR #6, merge `6d842b1`) contém migration/verify/rollback/workflow; migration atômica (`begin` L76 / `commit` L666); zero policy/view executável; 6× `enable rls` + 6× `revoke`; linha final do verify confere **verbatim** com o output do run |

### Gate board final do `run_migration` Fase 5
| Gate | Fonte | Estado |
|---|---|---|
| `review_rls` do DDL + verify (matrix #3) | SEC-0014 | ✅ liberado, sem bloqueio |
| Data/AI #4/#5 — computed↔raw + reprodutibilidade (`validate_reproducibility`) | DATA-AI-0005 (veto) → DATA-AI-0006 (re-veto) → **DATA-AI-0007 (aprovado)** | ✅ veto **baixado** após 2 rodadas; F5-03A/05A/06A/01A fechados |
| `audit_secrets` da pipeline (matrix #8) | SEC-0015 | ✅ sem bloqueio (espelho da pipeline endurecida) |
| Required reviewers em CI (origem `main`, SEC-F18) | run `28311371393` | ✅ AdeptLabsDev |
| Apply forward-only + verify §4/§5 fail-closed | run `28311371393` | ✅ guard·apply·verify success |

### Impacto
- **Escopo:** nenhum desvio. 6 tabelas COMPUTED/relatório (`04_…`); **zero** tabela de marketplace/Fase 2-produto.
- **Non-negotiables — provados em banco no run (§5 empírico, nos 2 caminhos de role), conforme DATA-AI-0007:**
  - **publicado congelado (DATA-RR-F5-03A / F5-01A)** — `artist_metric_videos_published_guard` valida OLD em UPDATE/DELETE e NEW em INSERT/UPDATE; mover input de metric não-publicada para publicada **falha** nos caminhos `postgres` (grant-holder) e `service_role`; mover `report_items` draft→published também é bloqueado no caminho `service_role`, com a **paridade de errcode** do projeto (`restrict_violation` OR `insufficient_privilege` — SEC-F21);
  - **evidência estrutural (DATA-RR-F5-05A)** — `NULL`, `{}` e seção ausente **rejeitados**; fixture completo **aceito**; evidência da metric publicada fica **congelada** (zero fórmula/generated column/CHECK de faixa numérica — DDL storage-only);
  - **reprodutibilidade por chave natural (DATA-RR-F5-06A)** — `versions` exige rubric/resolver/rule versions não-vazios; `overrides[]` preserva `run_id` + `video_id`/`channel_id`, permitindo replay sem depender de UUID mutável; `unique(run_id, artist_id, rubric_hash)` preservado em `artist_metrics`;
  - **proveniência até o raw** — 16 FK **todas `ON DELETE RESTRICT`** (rubric + linhagem até raw); `report_items → artists` com FK única;
  - **freeze condicional, não global** — `mappings`/`eligibility` com **zero** triggers; `metrics`/junction só com guards condicionais da linhagem publicada (sem freeze global das 3 COMPUTED);
  - **default-deny** — RLS-on + revoke nas 6; zero policy executável;
  - **zona determinística intacta** — IA restrita a Entity Resolution; Score, Velocity, Signals, Competition, ranking e Example continuam **determinísticos** (código), nunca gerados por LLM.

### Reversibilidade
Schema reversível em declaração: `supabase/rollback/20260620000005_phase5_computed_metrics_reports.rollback.sql` permanece como rede de segurança **declarada e não executada**. **Publicado é FROZEN:** em produção o rollback **não é admissível** — a cadeia computada (`artist_metric_videos`) é a **trilha de proveniência**; rollback só vale para run(s) descartável(is) (HANDOFF-phase5-design §8). `rollback_producao` = **NÃO executado** (confirma a evidência).

### Carry-forward (não-bloqueante — registrado, não é gate deste apply)
- **P5-REPRO-01** (a prova canônica de reprodutibilidade em 2 rodadas) é **gate do `services/data-engine` antes do pipeline/primeiro publish — NÃO deste migration apply** (DATA-AI-0007 §3, HANDOFF §12). Antes do 1º publish, Data/AI + Backend/DevOps entregam teste + fixture + comando CI fail-closed que rode 2 rodadas sobre o mesmo raw/rubric/resolver+rule versions/decisões replayable, ordene por report/rank/artista e compare byte-a-byte os campos de negócio e evidências (excluindo só UUIDs e timestamps operacionais). Qualquer divergência = bug metodológico bloqueante. Reentra como critério de aceite da fase de pipeline/publish.

### Sequenciamento (próximo)
1. **Closeout record-only (`database_agent`):** emitir `HANDOFF-phase5-apply-closeout.md` (ratificação repo-side linha-a-linha do run `28311371393`), fechando a convenção closeout+DEC. **Não** reaplica, **não** roda rollback, **não** toca o publicado.
2. **Consumo (`backend_agent`):** o contrato **BE-0002** (`report_items.artist_metric_id`) está pronto para os endpoints da fase de produto; coleta real e cálculo determinístico do Score entram pelas fases de pipeline (Data/AI + Backend + DevOps).
3. **Antes do 1º publish:** **P5-REPRO-01** como gate fail-closed do `data-engine` (acima).
4. **Sob veto, não sequenciar:** Fase 9 — RLS Policies + VIEW pública (SEC-0001 §0). Este apply **não** o destrava.
