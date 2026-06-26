# SEC-0011 — Security Audit (audit_secrets) · Pipeline de apply da Fase 3

- **Task:** `task_phase3_security_audit_secrets_pipeline` · **Action:** `audit_secrets` · **Agent:** `security_agent`
- **Data:** 2026-06-25
- **Artefato:** `.github/workflows/phase3-db-apply.yml`
- **Baseline:** `phase2-db-apply.yml` + **SEC-0008** (audit sem bloqueio da pipeline da Fase 2). Verify já auditado em **SEC-0010**.
- **Mandato:** matrix #8 (delta de pipeline de apply). Gate de veto.

---

## 0. Veredito

✅ **SEM BLOQUEIO.** A pipeline da Fase 3 é um espelho fiel da Fase 2 endurecida; o delta é cosmético + uma **melhoria** (nota SEC-F18 explícita no cabeçalho). Nenhum vetor novo. Gate `audit_secrets` (matrix #8) **BAIXADO**.

*(Veto da **Fase 9 — RLS Policies** intacto, SEC-0001 §0.)*

---

## 1. Itens confirmados (scan próprio, não preflight)

| Item | Veredito | Evidência |
|---|---|---|
| SHA-pin / zero tag mutável | ✅ | grep de tag mutável em `.github` → **vazio**. `actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5` (v4.3.1, L68/L118) e `supabase/setup-cli@ab058987d8d6c725971f6cf9d0b5c98467e30bd1` (v1.7.1, L71) — **byte-idênticos** aos SHAs que verifiquei na API do GitHub em SEC-0006. |
| `permissions: contents: read` | ✅ | L34-35. |
| Manual-only + `APPLY-PHASE3` + Environment | ✅ | `workflow_dispatch` only (L26-32); job `guard` exige `APPLY-PHASE3` (L53); `environment: production-db` (L65, L115) → required reviewers. `concurrency` evita applies paralelos. |
| Service-role fora do CI (SEC-F19) | ✅ | grep `SERVICE_ROLE_KEY`/`SERVICE_KEY` no workflow → **vazio**. |
| URL de DB mascarada | ✅ | `::add-mask::${url}` antes do `GITHUB_ENV` (L89-90, L140-141). |
| Zero secret no workflow | ✅ | grep `sbp_`/`eyJ`/`-----BEGIN`/URL-com-credencial → **vazio**. |
| SEC-F18 (dispatch de branch ≠ `main` negado) | ✅ herdado | Controle do **Environment `production-db`** (deployment branch rule = `main`), confirmado em SEC-0006 — vale para qualquer workflow que referencie o Environment. A Fase 3 agora **documenta** isso no cabeçalho (L10-12). Re-confirmável no 1º run (sou required reviewer). Sem nova exposição. |
| Verify apontado | ✅ | job `verify` → `phase3_post_apply_verify.sql` (L148), já aprovado em SEC-0010. |

---

## 2. Delta vs Fase 2 (SEC-0008) — só o esperado

`name: Phase 3` (L1); frase `APPLY-PHASE3` (L30, L53); `concurrency.group: phase3-db-apply` (L38); nomes de job "… Phase 3"; `verify` → `phase3_post_apply_verify.sql` (L148); **adição**: comentário SEC-F18 explícito (L10-12). Hardening (SHA-pin, `contents: read`, máscara de URL, sem service-key, apply atômico forward-only, `db push` só do pendente) **inalterado**. **Nenhum vetor novo.**

---

## 3. Quadro de gates do `run_migration` (Fase 3)

| Gate | Estado |
|---|---|
| Security `review_rls` (DDL + verify, matrix #3) | ✅ baixado (SEC-0009 + SEC-0010) |
| Data/AI #5 (identidade/dedupe + `rubric_*`) | ✅ baixado (DATA-AI-0003) |
| **Security `audit_secrets` da pipeline (matrix #8)** | ✅ **BAIXADO — este doc (SEC-0011)** |
| PR atômico revisado + merge na `main` (sem push direto, #12) | ⏳ próximo passo |
| Gate humano + required reviewers em CI | ⏳ runtime (origem `main` re-confirma SEC-F18) |
| Fase 9 — RLS Policies | ⛔ veto à parte (SEC-0001 §0) |

**Como o apply abre:** todos os gates de revisão (Security #3 + #8, Data/AI #5) ✅. Restam o **merge por PR** (sem push direto) e, no `run_migration` gated, o **gate humano + required reviewers** em runtime. Silêncio de Security ≠ aprovação.
