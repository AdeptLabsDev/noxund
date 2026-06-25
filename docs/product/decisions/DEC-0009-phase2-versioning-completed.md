## DEC-0009 — Fechamento do gate board do apply da Fase 2 (Versionamento `run_migration` aplicado e verificado)

- **Data:** 2026-06-24
- **Status:** **Registrada — fato consumado.** Apply executado e verificado em CI; `task_phase2_run_migration_reapply_verify` transiciona `in-progress` → `completed`.
- **Decisor:** Product Lead (executou o apply e o re-run em CI, aprovou como required reviewer) · registrada pelo Product Orchestrator
- **Área:** Schema / Segurança / Processo de gate / Qualidade de verificação
- **Relaciona:** DEC-0008 (fechamento Fase 1, precedente), DEC-0007 (gates adicionais), SEC-0007 (review_rls do SQL — veto baixado), DATA-AI-REVIEW-phase2-versioning (Data/AI #5 — sem veto), SEC-0008 (audit_secrets da pipeline — sem bloqueio; **registro corrigido abaixo**), HANDOFF-phase2-versioning, HANDOFF-phase2-apply-pipeline, HANDOFF-phase2-verify-errcode-fix

### Contexto
Os gates de revisão da Fase 2 caíram na ordem correta — Security `review_rls` do SQL (SEC-0007) →
Data/AI #5 (fidelidade ao §7 + ownership do `rubric_hash`) → Security `audit_secrets` da pipeline de
apply (SEC-0008) → PR atômico só-Fase-2 revisado e mergeado na `main` (PR #2, sem push direto, #12).
O `run_migration` gated (`phase2-db-apply.yml`) aplicou a migration a partir de `main`, com gate humano
(frase `APPLY-PHASE2`) + required reviewers do Environment `production-db`.

**O primeiro run aplicou o schema com sucesso, mas o job `verify` falhou** — `permission denied for table
rubric_versions` (`insufficient_privilege`/42501) onde o script esperava `restrict_violation`. Diagnóstico:
**falso-negativo do verify, não defeito de schema.** A migration (paridade com a Fase 1, já aprovada em
SEC-0004/0006) **não concede DML a `service_role`**; logo a mutação é barrada no *grant layer*
(`insufficient_privilege`) antes de chegar ao trigger — o que **prova append-only tão bem quanto o
trigger**. O verify da Fase 2 havia estreitado para aceitar só `restrict_violation`, divergindo do verify
da Fase 1 (que aceita os dois errcodes deliberadamente). O hotfix (`a5e68b9` / PR #3, atômico só-verify)
restaurou a paridade — `restrict_violation OR insufficient_privilege` nos 3 blocos de imutabilidade §5 —
e o re-run gated passou verde (apply no-op, migration já trackeada; verify = checagem real).

### Decisão (o que se registra)
1. **A migration da Fase 2 está aplicada e verificada em produção** (`pwbkplzyzmortwjjpcbg` / `us-east-1`):
   `supabase/migrations/20260620000002_phase2_versioning.sql`, forward-only, atômica. **Versionamento de
   rubric e outcome weights está live** (`rubric_versions`, `outcome_weight_versions`), pré-requisito do
   computed (Fase 5 referencia `rubric_version` + `rubric_hash`).
2. **O gate board do `run_migration` da Fase 2 está integralmente fechado** (tabela abaixo). A tarefa
   `task_phase2_run_migration_reapply_verify` é `completed`, com evidência canônica no run de CI e ratificação
   do veredito de verify em banco.
3. **Nenhum gate downstream foi destravado por este apply.** Em especial, o **veto da Fase 9 — RLS Policies
   (SEC-0001 §0)** permanece de pé.
4. **Causa-raiz registrada (qualidade de verificação):** a falha do 1º verify foi **falso-negativo de
   teste**; o schema esteve correto o tempo todo. Lição: o estado de grant de `service_role` é dependente de
   ambiente — bloqueio por *grant* OU por *trigger* ambos comprovam imutabilidade; o verify deve aceitar os
   dois (paridade Fase 1). Documentado no script para não reincidir.

### Evidência de registro
| Item | Evidência |
|---|---|
| Run do pipeline | `phase2-db-apply.yml` → https://github.com/AdeptLabsDev/noxund/actions/runs/28129447446 (origem `main`) |
| Jobs | `guard` (`APPLY-PHASE2`) · `apply` (**no-op / up-to-date** — `20260620000002` já no histórico) · `verify` — todos **success** |
| Verificação | `phase2_post_apply_verify.sql` com `ON_ERROR_STOP=1` → `OK — Phase 2 post-apply verification PASSED (§4 structural + §5 empirical).` |
| Aprovação em runtime | required reviewer **AdeptLabsDev** (encarna DevOps+Security), origem `main` (re-confirma SEC-F18) |
| Hotfix do verify | `a5e68b9 fix(phase2): align verify immutability assertions` → `5db56ef` (Merge PR #3), atômico (2 arquivos) |

### Gate board final do `run_migration` (Fase 2)
| Gate | Fonte | Estado |
|---|---|---|
| Security `review_rls` do SQL (matrix #3) | SEC-0007 | ✅ baixado |
| Data/AI #5 (fidelidade §7 + `rubric_hash`) | DATA-AI-REVIEW-phase2-versioning | ✅ baixado |
| Security `audit_secrets` da pipeline (matrix #8) | SEC-0008 | ✅ baixado |
| Verify de paridade (§4 estrutural + §5 empírico) | `phase2_post_apply_verify.sql` (pós-hotfix) | ✅ verde em banco |
| PR atômico revisado + merge na `main` | PR #2 (migration+pipeline) · PR #3 (verify hotfix) | ✅ fechado |
| Gate humano + required reviewers em CI | INFRA-0001 §3 | ✅ fechado (run de `main`) |

### Impacto
- **Escopo:** nenhum desvio. 2 tabelas de versionamento; **zero** tabela de marketplace/Fase 2-produto.
- **Non-negotiables — preservados e provados em banco no run:**
  - **rubric imutável / append-only** — UPDATE+DELETE+TRUNCATE como `service_role` **bloqueados** (`restrict_violation` ou `insufficient_privilege`); `service_role` não consegue mutar nem limpar as `*_versions` (lição SEC-F16 propagada);
  - **default-deny** — `anon`/`authenticated` com **zero** acesso (`insufficient_privilege`);
  - **score versionado** — `unique(version)` + `unique(version, hash)` (alvo de FK da Fase 5);
  - **IA/DB não gera número** — `rubric_hash` determinístico, computado pelo **data-engine** (Data/AI), nunca fabricado no banco; `config_json` opaco;
  - **secrets fora de repo/log/payload**; "sem push direto na `main`" honrado (PRs #2/#3).

### Correção de registro — SEC-0008
O `audit_secrets` (SEC-0008) classificou o verify original como *"mais estrito que a Fase 1 / hardening"*.
**Essa leitura estava incorreta:** a estritez extra (aceitar só `restrict_violation`) era a **regressão de
paridade** que produziu o falso-negativo, não um endurecimento. O registro fica corrigido aqui; o verify
pós-hotfix está em paridade exata com o da Fase 1, que o Security já aprovara em SEC-0004/0006.

### Reversibilidade
Alta no nível de schema: `supabase/rollback/20260620000002_phase2_versioning.rollback.sql` permanece como
rede de segurança **declarada e não executada** (dropa os 4 triggers → função compartilhada → 2 tabelas;
`DROP TABLE` é DDL e não dispara os triggers de imutabilidade). O seed do rubric §7 **não** faz parte deste
apply (template comentado; INSERT real coordenado com Data/AI, owner do `rubric_hash`).

### Follow-ups (registrados — não bloqueiam)
1. **Seed do rubric §7:** quando autorado, é INSERT coordenado com Data/AI (persiste pesos 40/25/20/15
   verbatim; qualquer alteração de pesos ⇒ **escalar ao Orchestrator**). Exercitará empiricamente o caminho
   de escrita das versões.
2. **Higiene do working tree:** docs untracked acumulados de tarefas anteriores (handoffs Fase 1/2,
   SEC-0005/0006, DEC-0008, `.agents/`, `skills-lock.json`) seguem não-comitados — passar a limpo em PRs
   próprios, fora de qualquer PR de migration.

### Sequenciamento (próximo)
1. **Fundação seguinte — Fase 3:** `report_runs`, `artists`, `artist_aliases` na ordem do
   `migration-plan.md`. Owner `database_agent` (`plan_migration`, não-sensível; apply gated); revisão
   **Database + Security** (matrix #3) e Data/AI quando tocar identidade/dedupe de artista.
2. **Sob veto, não sequenciar:** Fase 9 — RLS Policies (SEC-0001 §0) até o review dedicado do Security.
