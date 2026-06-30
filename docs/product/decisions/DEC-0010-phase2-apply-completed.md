## DEC-0010 — Fechamento do gate board do apply da Fase 2 (`run_migration` aplicado e verificado) + resolução da OD-PROV-02

- **Data:** 2026-06-26
- **Status:** **Registrada — fato consumado (backfill de proveniência).** Apply executado e verificado em CI; `task_phase2_run_migration_apply` transiciona `⏳ aguardando gate humano` → `completed`. **Resolve a `OD-PROV-02`** aberta na DEC-0009.
- **Decisor:** Product Lead (disparou o apply em CI de `main`, aprovou como required reviewer; escolheu a Opção A e forneceu run + reviewer) · registrada pelo Product Orchestrator
- **Área:** Schema / Segurança / Processo de gate / Rastreabilidade
- **Relaciona:** SEC-0007 (review_rls do SQL), SEC-0008 (audit_secrets da pipeline), `DATA-AI #5` (fidelidade ao §7 / `rubric_hash`), `HANDOFF-phase2-apply-closeout.md` (evidência canônica + ratificação `database_agent`), DEC-0009 (abriu a OD-PROV-02), DEC-0008 (precedente Fase 1), `migration-plan.md` §Fase 2, PR #2 (`f1cc622`) + PR #3 (`a5e68b9` verify-hotfix)

### Contexto
A DEC-0009 (fechamento da Fase 3) registrou uma **lacuna de proveniência** (`OD-PROV-02`): a Fase 2 (Versionamento) estava **aplicada sem closeout nem DEC** — única das fases sem o par de registro. O Product Lead escolheu a **Opção A** (a Fase 2 teve run gated próprio) e forneceu a **URL do run** (`28129447446`) e o **reviewer** (`AdeptLabsDev`). Com a evidência em paridade com a Fase 3 — jobs `success`, origem `main`, frase `APPLY-PHASE2` (atestados via Opção A), linha final do verify determinística (contrato do `phase2_post_apply_verify.sql`) e reviewer nomeado — o `database_agent` emitiu o **closeout/backfill record-only** (sem reaplicar, sem rollback, sem §7 seed, sem DDL/DML). Esta DEC ratifica e fecha a OD-PROV-02.

### Decisão (o que se registra)
1. **A migration da Fase 2 está aplicada e verificada em produção** (`pwbkplzyzmortwjjpcbg`): `supabase/migrations/20260620000002_phase2_versioning.sql`, forward-only, atômica. **`rubric_versions` e `outcome_weight_versions` estão live** — backbone da reprodutibilidade (versão publicada = nova linha, nunca editada).
2. **O gate board do `run_migration` Fase 2 está integralmente fechado** (tabela abaixo). A tarefa `task_phase2_run_migration_apply` é `completed`, com evidência canônica em `HANDOFF-phase2-apply-closeout.md` e ratificação do `database_agent` (record-only).
3. **A `OD-PROV-02` está resolvida.** A trilha de apply está restaurada e consistente: **Fase 1 (DEC-0008) → Fase 2 (DEC-0010) → Fase 3 (DEC-0009)** — todas com o par closeout+DEC e evidência de run gated.
4. **Nenhum gate downstream foi destravado.** O **veto da Fase 9 — RLS Policies (SEC-0001 §0)** permanece de pé.

### Evidência de registro
| Item | Evidência |
|---|---|
| Run do pipeline | `phase2-db-apply.yml` → https://github.com/AdeptLabsDev/noxund/actions/runs/28129447446 (origem `main`) |
| Jobs | `guard` (`APPLY-PHASE2`) · `apply` (`supabase db push`, forward-only) · `verify` — todos **success** |
| Verificação | `phase2_post_apply_verify.sql` com `ON_ERROR_STOP=1` → `OK — Phase 2 post-apply verification PASSED (§4 structural + §5 empirical).` |
| Verify-hotfix refletido | PR **#3** `phase2/verify-hotfix` / commit **`a5e68b9`** ("align verify immutability assertions" — errcode-parity `restrict_violation OR insufficient_privilege` ×3, em paridade com Fases 1/3) |
| Aprovação em runtime | required reviewer **AdeptLabsDev** (encarna DevOps+Security), origem `main` (SEC-F18) |
| Ratificação | `database_agent` (`status=completed`; conferiu repo-side a linha final verbatim, o idiom corrigido e a migration autorada; run de CI como evidência de registro, sem forjar) |

### Gate board final do `run_migration` Fase 2
| Gate | Fonte | Estado |
|---|---|---|
| `review_rls` do SQL concreto | SEC-0007 | ✅ sem bloqueio |
| `audit_secrets` da pipeline | SEC-0008 | ✅ sem bloqueio |
| Data/AI #5 (fidelidade ao §7 / `rubric_hash`) | DATA-AI #5 | ✅ sem veto |
| Verify-hotfix (errcode-parity) | PR #3 / `a5e68b9` | ✅ refletido no run |
| PR atômico só-Fase-2 revisado + mergeado na `main`, sem push direto | PR #2 / `f1cc622` | ✅ fechado |
| Required reviewers em CI (origem `main`, SEC-F18) | INFRA-0001 §3 | ✅ AdeptLabsDev |
| Apply forward-only + verify §4/§5 fail-closed | run `28129447446` | ✅ success |

### Impacto
- **Escopo:** nenhum desvio. 2 tabelas de versionamento; **zero** tabela de marketplace/Fase 2-produto.
- **Non-negotiables — provados em banco no run:** **score versionado + rubric imutável** (`rubric_versions`/`outcome_weight_versions` com trigger `BEFORE UPDATE/DELETE/TRUNCATE` — `restrict_violation`/`insufficient_privilege` no §5); **default-deny** (`anon`/`authenticated` sem acesso — §5); **IA não gera número** (`rubric_hash` determinístico computado em código, opaco no banco — sem semântica de rubric no DB). "Sem push direto na `main`" honrado (merge por PR). Secrets fora de repo/log/payload.

### Reversibilidade
Alta no nível de schema: `supabase/rollback/20260620000002_phase2_versioning.rollback.sql` permanece como rede de segurança **declarada e não executada**.

### Processo / aprendizado (registrado)
A lacuna existiu porque o closeout+DEC da Fase 2 não foram emitidos no momento do apply (diferente das Fases 1 e 3). **Convenção reforçada:** todo `run_migration` aplicado encerra com o par **closeout evidenciado (`database_agent`) + DEC de conclusão (Orchestrator)** antes de sequenciar a fase seguinte — o apply não é "concluído" sem o registro de proveniência.

### Sequenciamento (próximo)
1. **Trilha íntegra (Fases 1–3).** Nenhuma pendência de proveniência. OD-PROV-02 fechada.
2. **Fundação seguinte — Fase 4 (Raw YouTube Snapshots):** `raw_youtube_search_pages` / `raw_youtube_videos` / `raw_youtube_channels`, na ordem do `migration-plan.md`. DDL ainda **não** autorado — owner `database_agent`; **raw imutável por trigger `BEFORE UPDATE/DELETE/TRUNCATE`** (SEC-D03/SEC-F16, pois `service_role` faz bypass de RLS — SEC-F01) + scrub de contexto de request no payload (SEC-F08). Revisão **Database + Security** (matrix #3) + **Data/AI** (matrix #4 — imutabilidade do raw). Apply gated próprio.
3. **Sob veto, não sequenciar:** Fase 9 — RLS Policies (SEC-0001 §0). Este apply **não** o destrava.
