# Handoff — [DB] Fase 3 `run_migration` (Apply) · Database Agent

> **✅ RESOLVIDO (2026-06-25) — este `needs_review` foi superado.** A migration foi **aplicada e
> verificada em CI** (Environment `production-db`), resolvendo a espera pelo gate humano. Evidência
> canônica e status `completed` em **`HANDOFF-phase3-apply-closeout.md`** (run `28234275173`, jobs
> `guard`/`apply`/`verify` = success; reviewer AdeptLabsDev; origem `main`). O conteúdo abaixo é
> mantido como **registro histórico** do estado pré-apply — não é mais o estado atual.

## 1. Identificação
- **Tarefa:** `task_phase3_run_migration_apply` · **Action:** `run_migration` (sensível/gated)
- **Owner agent:** Database (`database_agent`)
- **Data:** 2026-06-25
- **Alvo:** projeto `pwbkplzyzmortwjjpcbg` · **migration** `supabase/migrations/20260620000003_phase3_runs_artists.sql` (forward-only, atômica).

## 2. Atestado de prontidão (verificado por mim, repo-side)
- ✅ **Migration** Fase 3 presente e **atômica** (`begin/commit`); única pendente (Fases 1–2 já trackeadas).
- ✅ **DDL aprovado** (SEC-0009) e **Data/AI #5 baixado** (`DATA-AI-REVIEW-phase3-runs-artists.md`).
- ✅ **Verify** `supabase/tests/phase3_post_apply_verify.sql` com **SEC-F21/F22 corrigidos** (errcode-parity `restrict_violation OR insufficient_privilege` nos 3 blocos + probe positivo de freeze grant-holder), em paridade com Fases 1–2.
- ✅ **Workflow** `.github/workflows/phase3-db-apply.yml`: manual-only, frase **`APPLY-PHASE3`**, `environment: production-db` (required reviewers DevOps+Security), branch ≠ `main` **negado** (SEC-F18), **forward-only** (`supabase db push`), actions **SHA-pinned**, verify `phase3_post_apply_verify.sql` com `ON_ERROR_STOP=1` (fail-closed).

## 3. Por que NÃO retorno `completed` agora
- O **apply é o gate humano**: um humano dispara o workflow **de `main`**, digita `APPLY-PHASE3`, e os **required reviewers** aprovam o Environment. Um agente **não** executa esse gate.
- Deste sandbox **não há** `gh`/`supabase`/rede/credenciais — não disparo CI nem aprovo deployment.
- O payload não traz um run concluído. `completed` sem evidência é proibido (onboarding §5) — **não forjo** "PASSED".

## 4. Runbook de dispatch (humano + DevOps/Security)
1. GitHub Actions → **Run workflow** de `phase3-db-apply.yml` com **branch = `main`** (SEC-F18).
2. Input `confirm` = **`APPLY-PHASE3`** (job `guard`).
3. **Required reviewers** (DevOps+Security) aprovam o deployment do Environment `production-db`.
4. `apply` roda `supabase db push` (forward-only, atômico — aplica só a Fase 3 pendente); `verify` roda o SQL §4/§5 fail-closed.

## 5. Evidência a capturar (para o closeout)
- URL do run (jobs `guard`/`apply`/`verify` todos **success**).
- Linha final do verify: **`OK — Phase 3 post-apply verification PASSED (§4 structural + §5 empirical).`**
- Reviewer que aprovou + **origem = `main`**.

## 6. Escopo / não-negociáveis
- **Forward-only.** Rollback (`supabase/rollback/20260620000003_…`) é rede de segurança — **não** aplicar.
- **Raw imutável preservada:** `report_runs` âncora (identidade de coleta congelada + DELETE/TRUNCATE bloqueados) é provada pelo verify §5.
- **Nenhum gate downstream destravado.** Em especial, o **veto da Fase 9 (RLS Policies, SEC-0001 §0) permanece de pé**.
- Zero secret em repo/log/payload.

## 7. Próximo
Concluído o run com sucesso, o `database_agent` emite o **closeout evidenciado** (record-only) transicionando a tarefa para `completed` — como nas Fases 1–2. Depois, **Fase 4** (raw `raw_youtube_*`) na ordem do `migration-plan.md`.
