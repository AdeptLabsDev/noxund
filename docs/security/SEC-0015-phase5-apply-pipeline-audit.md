# SEC-0015 — Security Audit (audit_secrets) · Pipeline de apply da Fase 5

- **Task:** `task_phase5_security_audit_secrets` · **Action:** `audit_secrets` · **Agent:** `security_agent`
- **Data:** 2026-06-27
- **Artefato:** `.github/workflows/phase5-db-apply.yml` · **Handoff DevOps:** `docs/infra/HANDOFF-phase5-apply-pipeline.md`
- **Baseline de paridade:** `phase4-db-apply.yml` (+ **SEC-0013**). Verify (`phase5_post_apply_verify.sql`) + DDL já liberados em **SEC-0014** (Security #3).
- **Mandato:** matrix #8 (Deploy/ambiente → DevOps + Security). Revisão de **delta** sobre pipeline já endurecida/aprovada. Gate de veto. Silêncio ≠ aprovação.
- **Status:** NENHUM apply. Este gate destrava a task humano-gated de `run_migration` — **não** a executa.

---

## 0. Veredito

✅ **APROVADO — SEM BLOQUEIO.** A pipeline da Fase 5 é um **espelho byte-idêntico** da Fase 4 endurecida no que toca à superfície de secrets/supply-chain; o `diff` inteiro cai em **quatro categorias cosméticas/de escopo esperadas** — frase `APPLY-PHASE5`, `concurrency.group`, comentários/objetos do delta, e o verify-target. **Zero regressão de hardening, zero vetor novo, zero valor de secret em repo/log/arquivo versionado, nenhuma nova superfície de credencial.** Gate `audit_secrets` (matrix #8) **BAIXADO**. Este era o último gate de revisão antes do `run_migration` humano-gated.

*(Vetos de pé, à parte, intactos: **Fase 9 — RLS Policies + VIEW pública de `report_items`** (SEC-0001 §0). **P5-REPRO-01** é gate de publish/data-engine, fora deste apply.)*

---

## 1. Escopo da auditoria — confirmado por scan próprio

| Item | Veredito | Evidência (scan próprio, não preflight DevOps) |
|---|---|---|
| **Zero secret em repo/log/arquivo** | ✅ | Todos os secrets por indireção `${{ secrets.SUPABASE_DB_PASSWORD / SUPABASE_ACCESS_TOKEN }}` + `vars.SUPABASE_DB_{HOST,PORT,USER}`, lidos do Environment `production-db`. `grep` de literais (`eyJ`/`AIza`/`sbp_`/`sb_secret`/`password=`/`postgresql://` literal) → **vazio**. DB URL construída e **mascarada** (`::add-mask::${url}`, L108/L160) **antes** de ir ao `GITHUB_ENV`. Senha URL-encoded via `jq @uri` (L106/L158) — não logada. |
| **SEC-F19 — service-role NÃO usada** | ✅ | `grep` de `service[_-]?role[_-]?key`/`SUPABASE_SERVICE` → **vazio**. O freeze/inviolabilidade é provado no nível do DB (`set role service_role`, verify), **abaixo** dela — grants/RLS não bastam (SEC-D03/F01). |
| **SEC-F17 — supply-chain** | ✅ | 3 `uses:` SHA-pinadas: `actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5` (v4.3.1, L87/L138) + `supabase/setup-cli@ab058987d8d6c725971f6cf9d0b5c98467e30bd1` (v1.7.1, L90) — **SHAs byte-idênticas** às do phase4 (verificadas na API do GitHub em SEC-0006). `grep` de tag mutável (`@v*`/`@main`/`@master`/`@latest`) → **vazio**. O `diff` não toca **nenhuma** linha `uses:`. |
| **SEC-F18 — branch + reviewers** | ✅ | `environment: production-db` nos jobs **apply** (L84) e **verify** (L135) → required reviewers DevOps+Security em runtime. Restrição main-only é controle **herdado** do Environment (deployment-branch rule = `main`, confirmado em SEC-0006) — não provável a partir do YAML; documentado no cabeçalho (L10-12); re-confirmo no 1º run como required reviewer. |
| **Least-privilege + manual-only** | ✅ | `permissions: contents: read` (L53-54; sem `write`). `on:` = **só** `workflow_dispatch` (L45-46; zero `push`/`schedule`/`pull_request`). Job `guard` aborta (`exit 1`) se `confirm != APPLY-PHASE5` (L72-75). `concurrency` sem `cancel-in-progress` (`false`, L58) — não interrompe apply em curso. |
| **Wiring do verify** | ✅ | `psql … -v ON_ERROR_STOP=1 -f supabase/tests/phase5_post_apply_verify.sql` (L169-170) — o SQL **liberado por mim em SEC-0014**, fail-closed nos 2 role-paths (DEC-0009) com os probes F5-03A/05A/06A/01A. |

---

## 2. Delta vs Fase 4 (SEC-0013) — `diff` integral, só o esperado

O `diff phase4-db-apply.yml → phase5-db-apply.yml` produz **exclusivamente**:

1. **Frase:** `APPLY-PHASE4` → `APPLY-PHASE5` (description L49 + guard L72).
2. **Concurrency:** `group: phase4-db-apply` → `phase5-db-apply` (L57). `cancel-in-progress: false` inalterado.
3. **Comentários/objetos:** cabeçalho reescrito para descrever os objetos da Fase 5 (6 tabelas, 3 enums, 7 funções, 7 triggers, 16 FKs RESTRICT, 2 CHECKs de evidência + published_at, RLS/revoke nas 6, **zero policy/VIEW**) e os probes F5-03A/05A/06A/01A; nota "publicado é congelado ⇒ sem rollback"; nota NOT-IN-SCOPE P5-REPRO-01; comentário extra no passo de verify (L167-168). Nomes de job "Phase 4"→"Phase 5". **Documentação — não muda comportamento.**
4. **Verify-target:** `phase4_…` → `phase5_post_apply_verify.sql` (L170).

**Inalterado (a superfície de hardening inteira):** SHA-pins, `permissions: contents: read`, máscara de URL, ausência de service-role, `workflow_dispatch`-only, `guard` com frase, `environment: production-db` (apply+verify), `db push` atômico forward-only do pendente, sem rollback no caminho de apply. **Nenhum secret/`var`/`env` novo** — exatamente os mesmos `SUPABASE_DB_PASSWORD`/`SUPABASE_ACCESS_TOKEN` + `SUPABASE_DB_{HOST,PORT,USER}` + o `SUPABASE_PROJECT_REF` não-secreto (`grep` de indireções confirma o conjunto fechado). **Nenhuma nova superfície de secret/credencial.**

Observação de paridade (idêntica às Fases 1–4, sem objeção): `supabase/setup-cli` mantém `with: version: latest` — versão **da CLI**, não tag da action (a action está SHA-pinada). Aceito como nas auditorias anteriores.

---

## 3. Quadro de gates do `run_migration` (Fase 5)

| Gate | Estado |
|---|---|
| Data/AI #4/#5 (`validate_reproducibility` re-review) | ✅ baixado (AgentResult; backfill DATA-AI-0007 recomendado) |
| Security `review_rls` do SQL + verify (matrix #3) — SEC-0014 | ✅ baixado (APROVADO) |
| Backend — consumo de `artist_metric_id`/snapshot (BE-0002) | ✅ completed |
| Pipeline de apply gated de paridade (DevOps, matrix #8) | ✅ entregue (HANDOFF-phase5-apply-pipeline) |
| **Security `audit_secrets` da pipeline (matrix #8)** | ✅ **BAIXADO — este doc (SEC-0015)** |
| PR revisado + merge na `main` (sem push direto) | ⏳ próximo passo |
| **Gate humano + required reviewers do `run_migration`** | ⏳ runtime — **último passo, humano-gated** (origem `main` re-confirma SEC-F18) |
| Fase 9 — RLS Policies + VIEW pública de `report_items` (SEC-F03) | ⛔ veto à parte (SEC-0001 §0) — **não destravado aqui** |
| P5-REPRO-01 (prova de 2 rodadas) | ⏳ gate do data-engine/publish — fora deste apply |

**Como o apply abre:** todos os gates de revisão (Data/AI #4/#5, Security #3 + #8, Backend) estão ✅. Restam o **merge por PR** (sem push direto na `main`) e, no `run_migration` gated, o **gate humano + required reviewers** em runtime — onde, como required reviewer, re-confirmo origem `main` (SEC-F18). Nenhum secret exposto; nenhuma regressão de hardening. Silêncio de Security ≠ aprovação — este doc é a liberação explícita.
