## DEC-0008 — Fechamento do gate board do apply da Fase 1 (`run_migration` aplicado e verificado)

- **Data:** 2026-06-24
- **Status:** **Registrada — fato consumado.** Apply executado e verificado em CI; `task_phase1_run_migration_apply` transiciona `blocked` → `completed`.
- **Decisor:** Product Lead (executou o apply em CI, aprovou como required reviewer) · registrada pelo Product Orchestrator
- **Área:** Schema / Segurança / Processo de gate
- **Relaciona:** DEC-0006 (gate humano), DEC-0007 (gates adicionais), SEC-0004 (veto SQL baixado), SEC-0006 (re-audit sem bloqueio), INFRA-0001 (ambiente credenciado), `HANDOFF-phase1-apply-closeout.md` (evidência canônica)

### Contexto
Os cinco gates do `run_migration` (DEC-0007) foram satisfeitos **na ordem correta**: SEC-0004
(veto técnico do SQL) baixado → DEC-0006 (aprovação humana, escopada a `20260620000001`) →
SEC-0006 (re-audit `audit_secrets` **sem bloqueio**, 2026-06-21, **antes** do merge) → PR revisado
e mergeado na `main` sem push direto → required reviewers do Environment `production-db`. Com o
ambiente credenciado (INFRA-0001) montado, o apply ocorreu **via CI, não no laptop**, resolvendo o
bloqueio `MISSING_CREDENTIALED_CONNECTION` que mantinha a tarefa `blocked`.

### Decisão (o que se registra)
1. **A migration da Fase 1 está aplicada e verificada em produção** (`pwbkplzyzmortwjjpcbg` /
   `us-east-1`): `supabase/migrations/20260620000001_phase1_core_identity_access.sql`, forward-only,
   atômica. **Identidade/acesso/auditoria da Fase 1 está live.**
2. **O gate board do `run_migration` está integralmente fechado** (tabela abaixo). A tarefa
   `task_phase1_run_migration_apply` é `completed`, com evidência canônica em
   `HANDOFF-phase1-apply-closeout.md` e ratificação do `database_agent`.
3. **Nenhum gate downstream foi destravado por este apply.** Em especial, o **veto da Fase 9 —
   RLS Policies (SEC-0001 §0)** permanece de pé.

### Evidência de registro
| Item | Evidência |
|---|---|
| Run do pipeline | `phase1-db-apply.yml` → https://github.com/AdeptLabsDev/noxund/actions/runs/27956757153 (origem `main`) |
| Jobs | `guard` (`APPLY-PHASE1`) · `apply` (`supabase db push`, forward-only) · `verify` — todos **success** |
| Verificação | `phase1_post_apply_verify.sql` com `ON_ERROR_STOP=1` → `OK — Phase 1 post-apply verification PASSED (§4 structural + §5 empirical).` |
| Aprovação em runtime | required reviewer **AdeptLabsDev** (encarna DevOps+Security), origem `main` (reconfirma SEC-F18 no 1º run) |
| Ratificação | `database_agent` (`status=completed`, evidência repo-side verificada diretamente; run de CI como evidência de registro) |

### Gate board final do `run_migration`
| Gate | Fonte | Estado |
|---|---|---|
| Veto técnico do Security (SQL) | SEC-0004 | ✅ baixado |
| Aprovação humana da migration | DEC-0006 | ✅ concedida |
| `audit_secrets` sem bloqueio | DEC-0007 (a) → SEC-0006 | ✅ fechado |
| PR revisado + mergeado na `main` | DEC-0007 (b) | ✅ fechado |
| Required reviewers em CI | INFRA-0001 §3 | ✅ fechado (run de `main`, reviewer aprovou) |
| Conexão credenciada | INFRA-0001 | ✅ `MISSING_CREDENTIALED_CONNECTION` resolvido |

### Impacto
- **Escopo:** nenhum desvio. 4 tabelas de identidade/acesso/auditoria; **zero** tabela de marketplace/Fase 2.
- **Non-negotiables:** preservados e **provados em banco** no run — raw imutável (`audit_events`
  append-only; `service_role` bloqueado em truncate/update/delete — SEC-F16); default-deny
  (`anon`/`authenticated` sem acesso — SEC-F02/F13); `is_admin()` blindado (SEC-F15). "Sem push
  direto na `main`" honrado (merge por PR). Secrets fora de repo/log/payload.

### Reversibilidade
Alta no nível de schema: `supabase/rollback/20260620000001_phase1_core_identity_access.rollback.sql`
permanece como rede de segurança **declarada e não executada**. O bootstrap do 1º admin **não**
faz parte deste apply.

### Follow-ups (registrados — não bloqueiam)
1. **SEC-F18 residual (belt-and-suspenders):** executar o **teste negativo** — `workflow_dispatch`
   de uma branch **≠ `main`** deve ser **NEGADO** ao acessar o Environment (o run positivo já veio
   de `main`).
2. **SEC-F20:** tokens de teste **revogados** pós-apply (atestado). Gatilho permanente em INFRA-0001 §5.2.

### Sequenciamento (próximo)
1. **Fundação seguinte — Fase 2 (Versionamento):** `rubric_versions` / `outcome_weight_versions`
   na ordem do `migration-plan.md`. Owner `database_agent`; revisão **Database + Security** (matrix #3).
2. **Sob veto, não sequenciar:** Fase 9 — RLS Policies (SEC-0001 §0) até o review dedicado do Security.
