# SEC-0008 — Security Audit (audit_secrets) · Pipeline de apply da Fase 2

- **Task:** `task_phase2_security_audit_apply_pipeline` · **Action:** `audit_secrets` · **Agent:** `security_agent`
- **Data:** 2026-06-24
- **Escopo:** **delta** da pipeline de apply da Fase 2 sobre a Fase 1 já endurecida (matrix #8). NÃO re-revisa o SQL da migration (SEC-0007 baixado) nem a metodologia (Data/AI #5 baixado).
- **Artefatos:** `.github/workflows/phase2-db-apply.yml`, `supabase/tests/phase2_post_apply_verify.sql`, `docs/infra/HANDOFF-phase2-apply-pipeline.md`.
- **Baseline de paridade:** `phase1-db-apply.yml` + `phase1_post_apply_verify.sql` + **SEC-0006** (audit sem bloqueio da pipeline da Fase 1).

---

## 0. Veredito

✅ **SEM BLOQUEIO.** A pipeline da Fase 2 é um clone fiel da Fase 1 endurecida; o verify satisfaz a condição do **SEC-0007 §4** (prova empírica de imutabilidade + default-deny) e é **mais estrito** que o da Fase 1. Gate de `audit_secrets` da pipeline (matrix #8) **BAIXADO**.

Gates restantes do `run_migration` são downstream/runtime (PR+merge sem push direto; gate humano + required reviewers). Veto da **Fase 9 (RLS Policies)** intacto (SEC-0001 §0).

---

## 1. Veredito por item (verificado, não assumido)

| Item | Veredito | Evidência (scan próprio) |
|---|---|---|
| **SHA-pin / zero tag mutável** | ✅ **PASSA** | grep de tag mutável em `.github` → **vazio**. 3 `uses:` SHA-pinados (L65, L68, L114) **byte-idênticos** aos SHAs que verifiquei na API do GitHub no SEC-0006: `actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5` (v4.3.1) e `supabase/setup-cli@ab058987d8d6c725971f6cf9d0b5c98467e30bd1` (v1.7.1). Correspondência SHA↔tag já estabelecida — sem re-fetch. |
| **URL de DB mascarada** | ✅ **PASSA** | `echo "::add-mask::${url}"` **antes** de gravar no `GITHUB_ENV` (L86-87, L136-137). Senha vem de `secrets.*` (auto-mask). |
| **`permissions: contents: read`** | ✅ **PASSA** | L31-32, top-level. `GITHUB_TOKEN` read-only. |
| **Service-key fora do CI (SEC-F19)** | ✅ **PASSA** | grep `SERVICE_ROLE_KEY`/`SERVICE_KEY` em `.github` → **vazio**. Imutabilidade provada em banco (`set role service_role`), não via key. |
| **Manual-only + `APPLY-PHASE2` + required reviewers** | ✅ **PASSA** | `workflow_dispatch` only (L23-29), job `guard` exige frase `APPLY-PHASE2` (L50), `environment: production-db` nos jobs `apply`/`verify` (L62, L111) → required reviewers DevOps+Security em runtime. `concurrency` evita applies paralelos. |
| **Zero secret no SQL/workflow/handoff** | ✅ **PASSA** | grep `sbp_`/`eyJ`/`-----BEGIN`/URL-com-credencial no workflow → **vazio**. Sem valores em handoff/verify. |
| **Nenhuma tabela de marketplace** | ✅ **PASSA** | Pipeline aplica só a migration da Fase 2 (2 `*_versions`) — fora de escopo de produto. |

---

## 2. Verify de paridade (SEC-0007 §4) — SATISFAZ, e com rigor extra

`supabase/tests/phase2_post_apply_verify.sql`, rodado pelo job `verify` com `psql -v ON_ERROR_STOP=1` (falha alto; sem silent pass).

- **§4 estrutural:** 2 tabelas; 4 triggers (`*_no_update_delete` + `*_no_truncate` nas duas); `versioning_row_immutable()` com `search_path` fixo; **4 unique constraints** (`version` + `(version,hash)`) — backbone de reprodutibilidade; RLS-on nas duas. ✅
- **§5 empírico — imutabilidade:** como `service_role`, `TRUNCATE` + `UPDATE` + `DELETE` nas duas tabelas devem levantar **`restrict_violation`** (L116-165). Sondas inseridas em transação **sempre revertida** → efeito colateral nulo. ✅
- **§5 empírico — default-deny:** como `anon`/`authenticated`, `select` deve levantar `insufficient_privilege` (42501) (L167-185). ✅

**Por que isto é mais forte que a Fase 1 (e correto):** a Fase 1 tolerava `restrict_violation OR insufficient_privilege`; a Fase 2 exige **só `restrict_violation`**. Como a migration revoga apenas de `anon`/`authenticated`, o `service_role` **retém** os grants de DML — então o **único** mecanismo que bloqueia truncate/update/delete é o **trigger**. Asserir o errcode do trigger especificamente prova o trigger; um catch mais largo mascararia um trigger ausente. É a verificação que SEC-0003 §2 / SEC-0007 §2 pedem: imutabilidade **abaixo** do service-role.

**Fail-closed confirmado:** se num ambiente o `service_role` não tiver o grant, o `truncate` levantaria `insufficient_privilege` — **não** capturado → o job falha (sinal a investigar). Erra para falhar, nunca para um falso "passou". Correto.

---

## 3. Controles herdados (confirmados, sem novo achado)

- **SEC-F18 (escopo do Environment):** a deployment branch rule (`= main`) e os required reviewers são do **Environment `production-db`**, não do workflow. Como a regra é por Environment, **este novo workflow é gated pelo mesmo controle** já confirmado em SEC-0006 — sem nova exposição. (Reconfirmável no 1º run: dispatch de branch ≠ `main` deve ser negado.)
- **SEC-F20 (rotação):** política inalterada (INFRA-0001 §5.2); a Fase 2 usa os mesmos 2 secrets já rotacionados. Gatilho de revogação de tokens de teste pós-apply permanece.
- **Pontos fortes da Fase 1 preservados:** apply atômico (`db push` forward-only; migration `begin/commit`), URL via session pooler, sem rollback/seed no forward.

---

## 4. Quadro de gates residual do `run_migration` (Fase 2)

| Gate | Estado |
|---|---|
| Security `review_rls` do SQL (matrix #3) — SEC-0007 | ✅ baixado |
| Data/AI #5 (fidelidade §7 + `rubric_hash`) | ✅ baixado (informado no payload) |
| Verify pós-apply de paridade (DevOps, matrix #8) | ✅ entregue + auditado aqui |
| **Security `audit_secrets` da pipeline (matrix #8)** | ✅ **BAIXADO — este doc (SEC-0008)** |
| PR revisado + mergeado na `main` (sem push direto, #12) | ⏳ próximo passo |
| Gate humano + required reviewers do apply | ⏳ em tempo de execução (gated) |
| Fase 9 — RLS Policies | ⛔ veto à parte de pé (SEC-0001 §0) |

**Como o apply abre:** todos os gates de revisão (Security #3 + #8, Data/AI #5) estão ✅. Restam o **merge por PR** (não push direto) e, no `run_migration` gated, o **gate humano + required reviewers** em runtime — onde eu, como reviewer, re-confirmo origem `main` (SEC-F18). Silêncio de Security ≠ aprovação.
