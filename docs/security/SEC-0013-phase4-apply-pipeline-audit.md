# SEC-0013 — Security Audit (audit_secrets) · Pipeline de apply da Fase 4

- **Task:** `task_phase4_security_audit_secrets` · **Action:** `audit_secrets` · **Agent:** `security_agent`
- **Data:** 2026-06-26
- **Artefato:** `.github/workflows/phase4-db-apply.yml` · **Handoff DevOps:** `docs/infra/HANDOFF-phase4-apply-pipeline.md`
- **Baseline de paridade:** `phase3-db-apply.yml` (+ **SEC-0011**) e `phase2-db-apply.yml` (+ **SEC-0008**). Verify (`phase4_post_apply_verify.sql`) já liberado em **SEC-0012** (Security #3).
- **Mandato:** matrix #8 (Deploy/ambiente → DevOps + Security). Revisão de **delta** sobre pipeline já endurecida/aprovada. Gate de veto. Silêncio ≠ aprovação.
- **Status:** NENHUM apply. `run_migration` segue gated (humano + required reviewers).

---

## 0. Veredito

✅ **SEM BLOQUEIO.** A pipeline da Fase 4 é um **espelho byte-idêntico** da Fase 3 endurecida no que toca à superfície de segurança; o `diff` inteiro cai em **quatro categorias cosméticas/de escopo esperadas** — frase `APPLY-PHASE4`, `concurrency.group`, comentários/objetos da migration, e o verify-target. **Zero regressão de hardening, zero vetor novo, zero secret em repo/payload/log.** Gate `audit_secrets` (matrix #8) **BAIXADO**.

*(Veto da **Fase 9 — RLS Policies** intacto e fora de escopo, SEC-0001 §0. Esta pipeline não o toca.)*

---

## 1. Condições de veto — confirmadas por scan próprio

| # | Ponto de veto | Veredito | Evidência (scan próprio, não preflight) |
|---|---|---|---|
| 1 | **Supply-chain SEC-F17:** 3 actions SHA-pinadas, zero tag mutável | ✅ | `grep -E 'uses:.*@(v[0-9]+\|main\|master\|latest)'` → **vazio**. As 3 `uses:` são `actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5` (v4.3.1, L78/L128) e `supabase/setup-cli@ab058987d8d6c725971f6cf9d0b5c98467e30bd1` (v1.7.1, L81) — **SHAs byte-idênticos** aos que verifiquei na API do GitHub em SEC-0006 e re-confirmei em SEC-0008/0011. O `diff` não toca **nenhuma** linha `uses:` → pin inalterado. |
| 2 | **Secrets hygiene:** URL mascarada; secrets só do Environment; nada em repo/log; service-role NÃO usada (SEC-F19) | ✅ | `::add-mask::${url}` antes de qualquer uso e antes do `GITHUB_ENV` (L99, L150). Todos os secrets por indireção `${{ secrets.SUPABASE_DB_PASSWORD / SUPABASE_ACCESS_TOKEN }}` + `vars.*`, lidos do Environment `production-db`. `grep` de `service[_-]?role`/`SUPABASE_SERVICE` → **vazio** (SEC-F19). `grep` de literal (`eyJ`/`AIza`/`sb_secret`/`sbp_`/`password=`/`postgresql://` literal) → **vazio**. Senha URL-encoded via `jq @uri` (não logada). |
| 3 | **Superfície de execução:** `workflow_dispatch` only + frase + `contents:read`; Environment nos jobs apply+verify; branch main-only (SEC-F18) | ✅ | `on:` = **só** `workflow_dispatch` (L36-37; zero `push`/`schedule`/`pull_request`). Job `guard` aborta (`exit 1`) se `confirm != APPLY-PHASE4` (L63-66). `permissions: contents: read` no topo (L44-45; sem `write` em lugar algum). `environment: production-db` nos jobs **apply** (L75) e **verify** (L125) → required reviewers DevOps+Security em runtime. **SEC-F18 (dispatch de branch ≠ `main` negado):** controle **herdado** do Environment `production-db` (deployment-branch rule = `main`), confirmado em SEC-0006 — não é provável a partir do YAML, mas o workflow o documenta (L10-12) e eu o re-confirmo no 1º run como required reviewer. |
| 4 | **Wiring do verify:** aponta para `phase4_post_apply_verify.sql` com `ON_ERROR_STOP=1` (fail-closed), casando com o SQL liberado por Security #3 | ✅ | Job `verify` (L121-158): `psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/phase4_post_apply_verify.sql` (L157-158). Aponta para o arquivo exato **liberado por mim em SEC-0012**. Qualquer asserção falha → exit ≠ 0 → job (e run) falha. Sem passe silencioso. |

---

## 2. Delta vs Fase 3 (SEC-0011) — `diff` integral, só o esperado

O `diff phase3-db-apply.yml → phase4-db-apply.yml` produz **exclusivamente**:

1. **Frase:** `APPLY-PHASE3` → `APPLY-PHASE4` (description L40 + guard L63).
2. **Concurrency:** `group: phase3-db-apply` → `phase4-db-apply` (L48). `cancel-in-progress: false` inalterado (não interrompe apply em curso).
3. **Comentários/objetos:** cabeçalho reescrito para descrever os objetos da Fase 4 (3 tabelas raw, 2 funções, 6 triggers, 3 CHECKs SEC-F08, 3 FKs→report_runs) e a lição DEC-0009 no verify; reforço do SEC-F19/F01/SEC-D03 e do "raw SAGRADO ⇒ sem rollback no apply" (L14-34, L108-117). Nomes de job "Phase 3"→"Phase 4". **Documentação — não muda comportamento.**
4. **Verify-target:** `phase3_…` → `phase4_post_apply_verify.sql` (L158).

**Inalterado (a superfície de hardening inteira):** SHA-pins, `permissions: contents: read`, máscara de URL, ausência de service-role, `workflow_dispatch`-only, `guard` com frase, `environment: production-db` (apply+verify), `db push` atômico forward-only do pendente, sem rollback no caminho de apply. **Nenhum secret novo, nenhuma `var`/`secret`/`env` adicionada** (mesmos `SUPABASE_DB_PASSWORD`/`SUPABASE_ACCESS_TOKEN` + `SUPABASE_DB_HOST/PORT/USER` + o `SUPABASE_PROJECT_REF` não-secreto). **Nenhum vetor novo.**

Observação de paridade (idêntica às Fases 1–3, sem objeção): `supabase/setup-cli` mantém `with: version: latest` — é a versão **da CLI**, não a tag da action (a action está SHA-pinada). Aceito como nas auditorias anteriores.

---

## 3. Quadro de gates do `run_migration` (Fase 4)

| Gate | Estado |
|---|---|
| Security `review_rls` do SQL + verify (matrix #3) | ✅ baixado (SEC-0012) |
| Data/AI #4 (imutabilidade do raw / reprodutibilidade) | ✅ baixado |
| Pipeline de apply gated de paridade (DevOps, matrix #8) | ✅ entregue (HANDOFF-phase4-apply-pipeline) |
| **Security `audit_secrets` da pipeline (matrix #8)** | ✅ **BAIXADO — este doc (SEC-0013)** |
| PR revisado + merge na `main` (sem push direto, #12) | ⏳ próximo passo |
| Gate humano + required reviewers em CI | ⏳ runtime (origem `main` re-confirma SEC-F18) |
| **SEC-F23** — scrub autoritativo + log hygiene no pipeline de coleta | ⏳ carry-forward não-bloqueante (gate de **coleta**, não de apply) — SEC-0012 §1 |
| Fase 9 — RLS Policies | ⛔ veto à parte (SEC-0001 §0) |

**Como o apply abre:** todos os gates de revisão de Security (#3 + #8) e Data/AI (#4) estão ✅. Restam o **merge por PR** (sem push direto na `main`) e, no `run_migration` gated, o **gate humano + required reviewers** em runtime — onde, como required reviewer, re-confirmo origem `main` (SEC-F18). Nenhum secret exposto; nenhuma regressão de hardening. Silêncio de Security ≠ aprovação — este doc é a liberação explícita.
