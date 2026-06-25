# Handoff — `task_phase3_devops_apply_pipeline` · DevOps Agent

## 1. Identificação
- **Tarefa:** `task_phase3_devops_apply_pipeline` · **Action:** `define_pipeline` (não-sensível)
- **Owner agent:** DevOps / Infra (`devops_agent`)
- **Data:** 2026-06-25
- **Fase:** 3 — Runs + Artists (`20260620000003_phase3_runs_artists.sql`)
- **Alvo:** projeto Supabase `pwbkplzyzmortwjjpcbg` · região `us-east-1`

## 2. Objetivo
Autorar o workflow gated da Fase 3 espelhando a **postura endurecida da Fase 2**, trocando só
os deltas da Fase 3, para compor o **PR atômico (migration + pipeline)**. **Autorar apenas —
nada disparado**; `run_migration` segue gated.

## 3. Critério de aceite (do payload)
1. `phase3-db-apply.yml` espelha a Fase 2 (manual-only, `production-db`, SHA-pins, `contents: read`, sem service-role, URL mascarada).
2. `guard` exige `APPLY-PHASE3`; apply = `supabase db push` forward-only de `20260620000003`; `verify` roda `phase3_post_apply_verify.sql` fail-closed.
3. Não roda rollback nem seed; nenhum apply disparado.
4. Pronto para Security `audit_secrets` (matrix #8, delta).

## 4. Resultado
- [x] **Criado:** `.github/workflows/phase3-db-apply.yml`, **espelho exato** da Fase 2.
- [x] **Deltas (somente):** nome `Phase 3`; frase `APPLY-PHASE3` (guard); `concurrency.group: phase3-db-apply`; comentário do apply → migration `20260620000003_phase3_runs_artists.sql`; verify → `supabase/tests/phase3_post_apply_verify.sql`; nota explícita do **SEC-F18** (Environment nega dispatch de branch ≠ `main`).
- [x] **Hardening preservado (verificado):** `workflow_dispatch` only; `environment: production-db` (required reviewers DevOps+Security); **3 actions SHA-pinned** (checkout `34e1148…` v4.3.1, setup-cli `ab05898…` v1.7.1) / **zero tag mutável**; `permissions: contents: read`; URL via session pooler **mascarada** (`::add-mask::`); **service-role NÃO usada** (SEC-F19); `db push` forward-only atômico; `verify` com `ON_ERROR_STOP=1`.
- [x] **Forward-only:** não roda rollback nem o §7 seed. **Nenhum apply disparado.**

**Evidência de paridade:** `diff phase2-db-apply.yml phase3-db-apply.yml` → só os deltas acima.
**Higiene:** `grep` → 0 tag mutável · 3 SHA-pins · 0 service-role · 0 valor de secret.

## 5. Arquivos alterados
- `.github/workflows/phase3-db-apply.yml` — **criado** (workflow gated da Fase 3).

## 6. PR atômico da Fase 3 (migration + pipeline) — staging seletivo
O working tree carrega mudanças não-comitadas de outras tarefas. O PR da Fase 3 deve agrupar
**apenas** o conjunto da Fase 3 (DDL+verify já autorados por DB/Security + este workflow):
- `supabase/migrations/20260620000003_phase3_runs_artists.sql`
- `supabase/rollback/20260620000003_phase3_runs_artists.rollback.sql`
- `supabase/tests/phase3_post_apply_verify.sql`
- `.github/workflows/phase3-db-apply.yml`
- `docs/security/SEC-0009-phase3-runs-artists-ddl-review.md`, `docs/security/SEC-0010-phase3-verify-rereview.md`
- `docs/database/HANDOFF-phase3-runs-artists.md`, `docs/database/DATA-AI-REVIEW-phase3-runs-artists.md`
- este handoff

`git add` seletivo desse conjunto — **não** varrer mudanças de tarefas alheias. Sem push na `main` (rule #12).

## 7. Impacto no escopo
- **MVP travado?** Sim. Só pipeline; nada de schema/grant/RLS; stack inalterada.
- **Non-negotiable?** Reforça #10 (secrets) + supply chain (SHA-pin). Nenhum apply; zero secret em log/payload.
- **Não toquei:** migration/rollback/verify da Fase 3 (intactos); veto da Fase 9 (RLS) à parte.

## 8. Validação executada
- **Estrutural (grep + diff):** paridade confirmada; só deltas intencionais; wiring `APPLY-PHASE3`/`production-db`/`add-mask`/verify→SQL ok.
- **Apply:** **não executado** (constraint). Validação funcional do verify roda no 1º dispatch gated, pós-merge.

## 9. Revisões necessárias
- [ ] ⏳ **Security — `audit_secrets` (matrix #8, delta)** sobre a pipeline da Fase 3. Delta mínimo sobre a Fase 2 já endurecida (mesmos patterns). **Acionada** via `next_recommendation`.
- [x] **DevOps** — esta entrega (autor).

## 10. Quadro de gates residual do `run_migration` (Fase 3)
| Gate | Estado |
|---|---|
| Security #3 — DDL (SEC-0009) + verify re-review (SEC-0010) | ✅ baixado |
| Data/AI #5 | ✅ baixado |
| **Pipeline de apply gated (DevOps)** | ✅ **entregue aqui** |
| Security `audit_secrets` da pipeline (matrix #8, delta) | ⏳ recomendada — `next_recommendation` |
| Gate humano + required reviewers do apply | ⏳ em tempo de execução |
| Fase 9 — RLS Policies | ⛔ veto à parte de pé (SEC-0001 §0) — não tocado |

## 11. Próximos passos
1. **Security (`audit_secrets`):** revisão delta da pipeline da Fase 3 → baixar/condicionar.
2. **Merge do PR atômico** (branch + revisão; nunca push na `main`).
3. **Database (`run_migration`, gated):** dispara `phase3-db-apply.yml` → apply forward-only + verify §4/§5.

## 12. Open decisions / bloqueios
- **Nenhum bloqueio de DevOps.** Workflow pronto; gates restantes (Security delta, humano + reviewers) downstream e intactos; veto da Fase 9 fora do escopo.
