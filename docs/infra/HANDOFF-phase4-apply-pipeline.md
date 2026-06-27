# Handoff — `task_phase4_devops_define_apply_pipeline` · DevOps Agent

## 1. Identificação
- **Tarefa:** `task_phase4_devops_define_apply_pipeline` · **Action:** `define_pipeline` (não-sensível)
- **Owner agent:** DevOps / Infra (`devops_agent`)
- **Data:** 2026-06-26
- **Prioridade:** P1 (high)
- **Fase:** 4 — Raw YouTube Snapshots (`raw_youtube_search_pages`, `raw_youtube_videos`, `raw_youtube_channels`)
- **Alvo:** projeto Supabase `pwbkplzyzmortwjjpcbg` · região `us-east-1`
- **Predecessoras liberadas:** Security #3 (`review_rls`) + Data/AI #4 (`validate_reproducibility`) — ambos os gates de veto da Fase 4 retornaram `completed`/liberado.

## 2. Objetivo
Autorar a **pipeline de apply GATED da Fase 4** (`phase4-db-apply.yml`), espelhando integralmente o
hardening já aprovado das Fases 1–3. **Nenhum apply** — o `run_migration` segue gated/humano
(decisão subsequente do Orchestrator). **Não toquei** a migration, o rollback nem o verify
(já autorados/liberados pela Database e ratificados por Security #3 / Data-AI #4).

## 3. Critério de aceite (do payload)
1. `workflow_dispatch` only (manual); job `guard` com frase `APPLY-PHASE4`; `concurrency.group: phase4-db-apply`.
2. `environment: production-db` (required reviewers DevOps+Security em runtime).
3. Actions SHA-pinadas (zero tag mutável); `permissions: contents: read`.
4. DB URL via session pooler **mascarada** (`::add-mask::`); push forward-only atômico (`supabase db push --db-url`).
5. Service-role key **não** usada (SEC-F19).
6. Job `verify` executando `supabase/tests/phase4_post_apply_verify.sql` com `ON_ERROR_STOP=1`.
7. Higiene: grep limpo — 0 tag mutável, SHA-pins presentes, 0 valor de secret, 0 referência a `SERVICE_ROLE_KEY`.

## 4. Resultado
- [x] **Critério 1 — manual-only + frase + concurrency.** `on: workflow_dispatch` apenas (zero `push`/`schedule`); job `guard` aborta com `exit 1` se `inputs.confirm != "APPLY-PHASE4"`; `concurrency.group: phase4-db-apply`, `cancel-in-progress: false`.
- [x] **Critério 2 — Environment.** Jobs `apply` e `verify` em `environment: production-db` → required reviewers (DevOps+Security, matrix #8) aprovam **em tempo de execução**; a deployment-branch rule do Environment nega secrets a dispatch fora da `main` (SEC-F18).
- [x] **Critério 3 — SHA-pins + permissions.** **3 actions SHA-pinadas** (checkout `34e1148…` v4.3.1 ×2, setup-cli `ab05898…` v1.7.1); `permissions: contents: read` no topo (sem `write` em lugar nenhum).
- [x] **Critério 4 — URL mascarada + push atômico.** URL construída via session pooler (IPv4-safe nos runners), senha URL-encoded (`jq @uri`), `echo "::add-mask::${url}"` antes de qualquer uso; apply = `supabase db push --db-url "$SUPABASE_DB_URL"` (migration `begin/commit` ⇒ atômica; erro ⇒ exit ≠ 0 ⇒ job falha, sem estado parcial). Forward-only: **não** roda rollback.
- [x] **Critério 5 — SEC-F19.** Service-role key não referenciada. A imutabilidade do raw é provada **no banco** (`set role service_role`), abaixo do service_role — grants/RLS sozinhos não bastam (SEC-F01/SEC-D03).
- [x] **Critério 6 — verify.** Job `verify` instala `postgresql-client`, reconstrói a URL mascarada e roda `psql … -v ON_ERROR_STOP=1 -f supabase/tests/phase4_post_apply_verify.sql` (fail-closed). Wiring confere com o SQL liberado por Security #3 / Data-AI #4.
- [x] **Critério 7 — higiene.** Grep evidenciado em §8.

**Como verificar (paridade + higiene):**
`grep -nE 'uses:.*@(v[0-9]+|main|master|latest)' .github/workflows/phase4-db-apply.yml` → vazio ·
`grep -n 'APPLY-PHASE4' .github/workflows/phase4-db-apply.yml` → presente (description + guard) ·
o job `verify` aponta para `supabase/tests/phase4_post_apply_verify.sql`.

## 5. Arquivos alterados
- `.github/workflows/phase4-db-apply.yml` — **criado**: pipeline de apply gated da Fase 4.

**Intocados (constraint):** `supabase/migrations/20260620000004_phase4_raw_youtube_snapshots.sql`,
`supabase/rollback/20260620000004_phase4_raw_youtube_snapshots.rollback.sql`,
`supabase/tests/phase4_post_apply_verify.sql`. `git status` confirma só o workflow novo.

## 6. Diferenças vs. Fase 3 (paridade consciente)
- **Frase:** `APPLY-PHASE4` (não `APPLY-PHASE3`); `concurrency.group: phase4-db-apply`.
- **Objetos aplicados:** **3 tabelas raw** + **2 funções** de imutabilidade compartilhadas (`raw_youtube_immutable`/`raw_youtube_no_truncate`) + **6 triggers** (2/tabela: `before update or delete` row · `before truncate` statement) + **3 CHECKs SEC-F08** (`*_no_request_context`) + **3 FKs → report_runs** (`on delete restrict`). (Fase 3: `report_runs`/`artists`/`artist_aliases`.)
- **Verify (delta DEC-0009 já embutido pela Database):** caminho **grant-holder** (postgres) asserta **`restrict_violation`** (prova o trigger, não a ausência de grant — SEC-F22); caminho **service_role** asserta **`restrict_violation` OR `insufficient_privilege`** (SEC-F21). Mais o SEC-F08 empírico (corpo limpo ACEITO / envelope de request REJEITADO) e default-deny anon/authenticated. **Eu não autorei o SQL — apenas o wiring fail-closed casa com ele.**
- **`db push`:** aplica só o pendente (Fases 1–3 já trackeadas) = a migration da Fase 4.
- **Rollback:** **nunca** no caminho de apply — raw é SAGRADO (HANDOFF-phase4-design §8: rollback só admissível para run descartável/pré-coleta).

## 7. Impacto no escopo
- **MVP travado?** Sim. Só pipeline de apply; nada de Fase 2-produto/marketplace; stack inalterada.
- **Non-negotiable?** Reforça: **raw imutável** (apply abaixo do service_role provado no verify), **proveniência** (`run_id`/FK→report_runs), **secrets fora de repo/log/payload** (URL mascarada, SEC-F08 no schema, SEC-F19), supply chain (SHA-pin). **Nenhum apply**; zero secret no repo/log.
- **Pontos fortes preservados:** `contents: read`, manual-only + frase, required reviewers, URL mascarada, apply atômico forward-only, verify fail-closed.

## 8. Validação executada
- **Estrutural (grep, evidenciado):**
  - SHA-pins presentes: `actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5` (×2), `supabase/setup-cli@ab058987d8d6c725971f6cf9d0b5c98467e30bd1` → **3 pins**.
  - Tag mutável (`@v*`/`@main`/`@master`/`@latest` em `uses:`): **0 matches**.
  - `SERVICE_ROLE_KEY`/`service_role_key`/`SUPABASE_SERVICE`: **0 matches**.
  - Valor literal de secret (`eyJ…`, URL postgres literal, `AIza…`, `sb_secret`, senha inline): **0 matches** — só indireções `${{ secrets.* }}`.
  - Wiring confirmado: `APPLY-PHASE4` (description + guard), `environment: production-db` (apply+verify), `::add-mask::`, `db push --db-url`, verify→`phase4_post_apply_verify.sql`, `ON_ERROR_STOP=1`.
- **Apply:** **não executado** (constraint). A validação funcional do verify roda no 1º dispatch gated, pós-merge + Environment.

> Nota de paridade: `supabase/setup-cli` mantém `version: latest` (versão **da CLI**, não tag de action — a action em si está SHA-pinada), idêntico às Fases 1–3.

## 9. Riscos
- **Imutabilidade raw nos 2 caminhos de role:** o verify (autorado pela Database, liberado por Security #3) já assume `service_role` retém grant (caminho service_role tolera `restrict_violation OR insufficient_privilege`; grant-holder exige `restrict_violation` estrito). Se um ambiente divergir do default Supabase, o verify sinaliza — não falso-positivo silencioso.
- **Drift de versão de actions:** SHA-pin congela; re-pinar conscientemente a cada bump (mesmas SHAs das Fases 1–3 — re-pin coordenado).
- **Merge:** sem push direto na `main` (global rule #12) — PR + revisão.

## 10. Revisões necessárias
- [ ] ⏳ **Security — `audit_secrets` (matrix #8)** sobre esta pipeline de apply da Fase 4. Revisão de **delta** sobre as Fases 1–3 já aprovadas (mesmos patterns endurecidos; só muda frase/concurrency/objetos/verify-target). **Acionada** via `next_recommendation`.
- [x] **DevOps** — esta entrega (autor).

## 11. Quadro de gates residual do `run_migration` (Fase 4)
| Gate | Estado |
|---|---|
| Security `review_rls` do SQL (matrix #3) — SEC-0012 | ✅ baixado |
| Data/AI #4 (imutabilidade do raw / reprodutibilidade) | ✅ baixado |
| **Pipeline de apply gated de paridade (DevOps, matrix #8)** | ✅ **entregue aqui** |
| Security `audit_secrets` da pipeline (matrix #8) | ⏳ recomendada (delta) — `next_recommendation` |
| Gate humano + required reviewers do apply | ⏳ em tempo de execução (como nas Fases 1–3) |
| Fase 9 — RLS Policies | ⛔ **veto à parte de pé** (SEC-0001 §0) — **não tocado aqui** |

## 12. Próximos passos
1. **Security (`audit_secrets`):** revisar a pipeline da Fase 4 (delta vs. Fases 1–3) → baixar/condicionar.
2. **Merge do PR** (branch + revisão; nunca push na `main`).
3. **Database (`run_migration`, gated):** dispara `phase4-db-apply.yml` → digita `APPLY-PHASE4` → required reviewers aprovam → apply atômico + verify §4/§5 fail-closed.
4. Segue **Fase 5** (computed + resolução + relatório) na ordem do `migration-plan.md`.

## 13. Open decisions / bloqueios
- **Nenhum bloqueio de DevOps.** A paridade exigida está entregue. Os gates restantes
  (Security `audit_secrets` da pipeline, humano + reviewers) são downstream e **intactos**;
  o veto da Fase 9 permanece de pé e fora do escopo desta tarefa.

---

### `next_recommendation` (AgentResult)
```json
{
  "status": "completed",
  "next_recommendation": {
    "target_agent": "security_agent",
    "action": "audit_secrets",
    "priority": "high",
    "reason": "Matrix #8 (Deploy/ambiente -> DevOps+Security): pipeline de apply gated da Fase 4 autorada (phase4-db-apply.yml), espelhando o hardening aprovado das Fases 1-3. Revisão de delta de secrets/supply-chain destrava o gate humano do run_migration. Apply segue barrado.",
    "evidence": {
      "file": ".github/workflows/phase4-db-apply.yml",
      "hygiene": "3 SHA-pins; 0 tag mutavel; 0 valor de secret; 0 SERVICE_ROLE_KEY",
      "parity": "workflow_dispatch only + APPLY-PHASE4 + production-db + URL mascarada + push atomico forward-only + verify->phase4_post_apply_verify.sql (ON_ERROR_STOP=1)",
      "untouched": ["migration", "rollback", "verify"]
    }
  }
}
```
