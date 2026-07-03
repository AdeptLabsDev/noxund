# SEC-0018 — Security Audit (audit_secrets) · Pipeline gated entity-db-apply.yml (DEC-0014)

- **Task:** `task_entity_apply_workflow_security_audit` · **Action:** `audit_secrets` · **Agent:** `security_agent`
- **Data:** 2026-06-28
- **Artefato:** `.github/workflows/entity-db-apply.yml` · **Handoff DevOps:** `docs/infra/HANDOFF-entity-candidates-apply-pipeline.md`
- **Baseline de paridade/governança:** `phase5-db-apply.yml` (+ **SEC-0015**/**SEC-0014**). DDL/verify de 0006 já liberados em **SEC-0017**.
- **Mandato:** matrix #8 (Deploy/ambiente → DevOps + Security) + gatilho "internal jobs/cron protegidos". Revisão de **delta** + a lógica nova do **preflight**. Gate de veto. Silêncio ≠ aprovação.
- **Status:** NENHUM apply. O apply segue atrás do dispatch humano + required reviewers no Environment `production-db`.

---

## 0. Veredito

✅ **APROVADO — SEM BLOQUEIO.** O workflow é um **mirror fiel** da Fase 5 endurecida: toda a superfície de secrets/supply-chain é **byte-idêntica**, e o `diff` cai nas **quatro categorias esperadas** (frase, `concurrency.group`, comentários, verify-target) **+ um env não-secreto** (`EXPECTED_MIGRATION`) **+ um step novo de preflight**. **Zero secret novo, zero `configure_env`, zero regressão de hardening.** Auditei a lógica nova do **preflight fail-closed** linha a linha: as **duas camadas impedem de fato** aplicar 0007/qualquer migration ≠ 0006, **abortam fechado** em todo caso de divergência, e a direção perigosa (falso-PASS) está defendida. Gate `audit_secrets` (matrix #8) **BAIXADO**.

*(Veto da **Fase 9** segue de pé (SEC-0001 §0); **0007/producer_events** permanece PARKED e é **ativamente proibido** pelo preflight. Esta autoria não toca nem um nem outro.)*

---

## 1. Focus areas (secrets/supply-chain) — confirmados por scan próprio

| Foco | Veredito | Evidência |
|---|---|---|
| **Secrets hygiene** | ✅ | Secrets só por indireção do Environment `production-db` (conjunto **fechado**: `SUPABASE_DB_PASSWORD`/`SUPABASE_ACCESS_TOKEN` + `vars.SUPABASE_DB_{HOST,PORT,USER}`); `grep` de literais (`eyJ`/`AIza`/`sbp_`/`password=`/`postgresql://`) → **vazio**. URL mascarada (`::add-mask::`, 2×) antes do `GITHUB_ENV`; senha URL-encoded (`jq @uri`). `EXPECTED_MIGRATION='20260620000006'` é **não-secreto** (versão de migration). |
| **SEC-F17 supply-chain** | ✅ | 3 `uses:` SHA-pinadas (`checkout@34e1148…` ×2, `setup-cli@ab05898…`) — **mesmas SHAs** de phase4/5; `grep` de tag mutável → **vazio**; o `diff` não toca **nenhuma** linha `uses:`. |
| **SEC-F19 service-role** | ✅ | `grep` de `service[_-]?role`/`SUPABASE_SERVICE` → **vazio**. Default-deny provado no DB (`set role anon/authenticated`, verify), abaixo do service_role. |
| **SEC-F18 dispatch + reviewers** | ✅ | `on:` = **só** `workflow_dispatch` (sem `push`/`schedule`/`pull_request`); `environment: production-db` em **apply** (L94, que engloba o preflight) e **verify** (L190) → required reviewers DevOps+Security; restrição main-only **herdada** do Environment (deployment-branch rule), documentada (L10-12), re-confirmada por mim no 1º run. |
| **Least-privilege / manual-only** | ✅ | `permissions: contents: read` (sem `write`); `guard` aborta se `confirm != APPLY-ENTITY-CANDIDATES` (L82); `concurrency` sem `cancel-in-progress`. |

**Delta vs phase5 (diff integral):** `name`/comentários (documentação); frase `APPLY-ENTITY-CANDIDATES` (L56/L82); `concurrency.group: entity-db-apply` (L64); `EXPECTED_MIGRATION` (env não-secreto, L72); **step de preflight** (L127-170); verify-target `entity_resolution_candidates_post_apply_verify.sql` (L226). **Nenhum secret/`var`/permissão nova; nenhum gate relaxado; nenhum `on:push/schedule`.**

---

## 2. Preflight fail-closed — auditoria da lógica nova (o foco real)

O preflight roda **dentro do job `apply`** (logo, sob `production-db` + reviewers), **após** `link` e **antes** do `db push` real (L184). Duas camadas, ambas abortam `exit 1` **sem aplicar**:

### (A) Guarda de checkout (file-level, L138-158) → ✅ robusta
- Itera `supabase/migrations/*.sql` com `shopt -s nullglob` (glob vazio não vira literal).
- `ver="${base%%_*}"` extrai o prefixo de timestamp; `case ''|*[!0-9]*` **aborta** em nome não-numérico/vazio (não deixa filename malformado passar silencioso).
- `[[ "$ver" > "$EXPECTED_MIGRATION" ]]` — nomes são timestamps de **14 dígitos zero-padded** ⇒ comparação lexical == numérica ⇒ **qualquer** migration > 0006 (i.e. `…0007`) **aborta**. Pega 0007 vazando para `main`.
- `found_expected` deve ser 1 ⇒ **aborta** se 0006 ausente.
- **Resultado:** estruturalmente impede que 0007 esteja no checkout no momento do apply.

### (B) Guarda de verdade-remota (`db push --dry-run`, L160-170) → ✅ robusta e fail-closed
- `--dry-run` **nunca aplica**; captura o que o `db push` aplicaria.
- `pending="$(… | grep -oE '[0-9]{14}' | sort -u | …)"` e exige `pending == EXPECTED_MIGRATION` **exato**. Conjunto `{0005,0006}` (drift), `{0006,0007}`, ou **vazio** → **mismatch → aborta**.
- **Análise de falso-PASS (a direção perigosa):** para liberar errado, o dry-run teria de listar `20260620000006` e **omitir** qualquer outra pendente (ex.: 0007) — o que contradiz a função do `--dry-run` (ele enumera **todas** as pendentes). Com 0007 pendente, `…0007` apareceria → mismatch → aborta. **Defendido.**
- **Análise de falso-NEGATIVO/zero-match:** se o dry-run não traz nenhum token de 14 dígitos (nada pendente), `grep` sai 1 e, sob `set -euo pipefail`, o **job aborta fechado** (nenhum apply). Isto é o desfecho **seguro** — e só ocorre quando não há um 0006 legítimo a aplicar (logo, zero falso-negativo em apply legítimo, onde 0006 está pendente e casa).

### Defesa-em-profundidade (3 camadas, complementares)
1. **Disciplina de landing:** só 0006 entra em `main` (PR revisado, sem push direto); 0007 **parked/uncommitted** ⇒ ausente do checkout.
2. **(A)** pega "0007 entrou no `main`".
3. **(B)** pega "remoto fora do baseline esperado".
Qualquer divergência ⇒ **nenhum apply**. O `db push` real (L184) só roda depois das três passarem. **Robustez confirmada.**

> **Nota de precisão (não-bloqueante):** o handoff §6 descreve o zero-match do `grep` como "tolerante via `|| true` implícito" — o código **não** tem `|| true`; o comportamento real é **abortar fechado** no zero-match (`set -euo pipefail`). Isso é **mais conservador** que tolerar, portanto **correto/seguro**; registro só para alinhar a doc ao comportamento efetivo. Sem impacto no veredito.

### Higiene do preflight
Usa o mesmo `SUPABASE_ACCESS_TOKEN` (sem secret novo). `echo "$dry"` imprime **nomes/versões de migration** (não-sensíveis); a DB URL está mascarada e o token não é ecoado. **Zero vazamento** pelo preflight.

---

## 3. Quadro de gates do `run_migration` (0006)

| Gate | Estado |
|---|---|
| Database `design_schema` (0006 aditiva) | ✅ autorado |
| Security #3 `review_rls` (RLS/PII da fila) — SEC-0017 | ✅ baixado |
| Data/AI (integridade da fila / replay) | ✅ baixado |
| Pipeline gated dedicado (DevOps, matrix #8) | ✅ entregue |
| **Security `audit_secrets` / preflight (matrix #8)** | ✅ **BAIXADO — este doc (SEC-0018)** |
| Landing em `main`: PR revisado com **só 0006** (0007 excluído; sem push direto) | ⏳ próximo passo |
| **Gate humano + required reviewers do `run_migration`** | ⏳ runtime — dispatch + `APPLY-ENTITY-CANDIDATES` + preflight {0006} + reviewers (origem `main`/SEC-F18) |
| Apply de 0007/producer_events (Fase 6) | ⛔ **PARKED — preflight proíbe ativamente** |
| Fase 9 — RLS Policies + VIEW pública | ⛔ veto à parte (SEC-0001 §0) — não tocado |

**Como o apply abre:** todos os gates de revisão (Database, Security #3+#8, Data/AI) ✅. Restam o **landing de só-0006 em `main`** (sem push direto) e, no `run_migration` gated, o **dispatch humano + required reviewers** + o **preflight** provando escopo `{0006}` em runtime. Nenhum secret exposto; nenhuma regressão; 0007 ativamente barrado. Silêncio de Security ≠ aprovação — este doc é a liberação explícita.
