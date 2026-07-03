# Handoff — [DB] Fase 2 `run_migration` (Apply) · Database Agent

> **✅ RESOLVIDO (2026-06-25, backfill) — este `⏳ aguardando gate humano` foi superado.** A
> migration foi **aplicada e verificada em CI** (Environment `production-db`). Evidência canônica e
> status `completed` em **`HANDOFF-phase2-apply-closeout.md`** (run `28129447446`, jobs
> `guard`/`apply`/`verify` = success; reviewer AdeptLabsDev; origem `main`; verify-hotfix PR #3 /
> `a5e68b9`). Fecha **OD-PROV-02** (lacuna de proveniência da DEC-0009). O conteúdo abaixo é mantido
> como **registro histórico** do estado pré-apply — não é mais o estado atual.

## 1. Identificação
- **Tarefa:** `task_phase2_run_migration_apply` · **Action:** `run_migration` (sensível/gated)
- **Owner agent:** Database (`database_agent`)
- **Data:** 2026-06-24
- **Alvo:** projeto `pwbkplzyzmortwjjpcbg` · **migration** `supabase/migrations/20260620000002_phase2_versioning.sql` (forward-only, atômica).

## 2. Atestado de prontidão (verificado por mim, repo-side)
- ✅ **Migration** presente e **atômica** (`begin/commit`); é a única pendente (Fase 1 já trackeada).
- ✅ **Workflow** `.github/workflows/phase2-db-apply.yml`: manual-only, frase `APPLY-PHASE2`, `environment: production-db` (required reviewers DevOps+Security), **forward-only** (`supabase db push`), **não** roda rollback nem o seed §7, actions SHA-pinned, URL mascarada, service-role **não** usado (SEC-F19).
- ✅ **Verify** `supabase/tests/phase2_post_apply_verify.sql` (`psql -v ON_ERROR_STOP=1`, fail-closed) — **bate exatamente** com o que autorei:
  - §4: 2 tabelas; 4 triggers (`rubric_versions_no_update_delete/_no_truncate`, `outcome_weight_versions_no_update_delete/_no_truncate`); função `versioning_row_immutable()` com `search_path` pinado; 4 unique (`*_version_key`, `*_version_hash_key`); RLS-on nas 2.
  - §5: `truncate/update/delete` como `service_role` → **`restrict_violation`** (prova o trigger abaixo do bypass); `anon`/`authenticated` → **`insufficient_privilege`**; probes sempre revertidos.
- ✅ **Gate docs** citados existem: `SEC-0007` (review_rls do SQL), `SEC-0008` (audit_secrets da pipeline).

## 3. Por que NÃO retorno `completed` agora
- O **apply é o gate humano**: um humano dispara o workflow **a partir de `main`**, digita `APPLY-PHASE2`, e os **required reviewers** (DevOps+Security) aprovam o Environment. Um agente **não** executa esse gate.
- Deste sandbox **não há** `gh`/`supabase`/rede/credenciais — não disparo CI nem aprovo deployment.
- Este payload traz `evidence_to_capture` (a capturar), **não** um run concluído. `completed` sem evidência é proibido (onboarding §5) — **não forjo** "PASSED".

## 4. Runbook de dispatch (humano + DevOps/Security)
1. No GitHub Actions, **Run workflow** de `phase2-db-apply.yml` com **branch = `main`** (SEC-F18: dispatch de branch ≠ main deve ser **negado** pelo Environment).
2. Input `confirm` = **`APPLY-PHASE2`** (job `guard`).
3. **Required reviewers** (DevOps+Security) aprovam o deployment do Environment `production-db` (gate humano em runtime).
4. `apply` roda `supabase db push` (forward-only, atômico); `verify` roda o SQL §4/§5 fail-closed.

## 5. Evidência a capturar (para o closeout)
- URL do run (jobs `guard`/`apply`/`verify` todos **success**).
- Linha final do verify: **`OK — Phase 2 post-apply verification PASSED (§4 structural + §5 empirical).`**
- Reviewer que aprovou + **origem = `main`**.

## 6. Escopo / não-negociáveis
- **Forward-only.** Rollback (`supabase/rollback/20260620000002_…`) é rede de segurança — **não** aplicar. Seed §7 — **não** rodar (passo Data/AI, fora de escopo).
- **Nenhum gate downstream destravado.** Em especial, o **veto da Fase 9 (RLS Policies, SEC-0001 §0) permanece de pé**.
- Zero secret em repo/log/payload; service-role não usado no apply (SEC-F19).

## 7. Próximo
Concluído o run com sucesso, o `database_agent` emite o **closeout evidenciado** (record-only) transicionando a tarefa para `completed` — como na Fase 1. Depois, **Fase 3** (`report_runs`, `artists`, `artist_aliases`) na ordem do `migration-plan.md`.
