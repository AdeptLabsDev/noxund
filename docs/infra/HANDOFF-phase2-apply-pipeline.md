# Handoff — `task_phase2_devops_define_apply_pipeline` · DevOps Agent

## 1. Identificação
- **Tarefa:** `task_phase2_devops_define_apply_pipeline` · **Action:** `define_pipeline` (não-sensível)
- **Owner agent:** DevOps / Infra (`devops_agent`)
- **Data:** 2026-06-24
- **Prioridade:** P1 (high)
- **Fase:** 2 — Versionamento (`rubric_versions`, `outcome_weight_versions`)
- **Alvo:** projeto Supabase `pwbkplzyzmortwjjpcbg` · região `us-east-1`

## 2. Objetivo
Fechar a **paridade de pipeline da Fase 2** (matrix #8) que o `SEC-0007 §4` exige antes de
considerar o apply concluído: um verify pós-apply análogo ao da Fase 1 + um workflow de apply
gated espelhando o hardening já aprovado. **Nenhum apply** — o `run_migration` segue
gated/humano (decisão subsequente do Orchestrator). **Não toquei** a migration nem o rollback.

## 3. Critério de aceite (do payload)
1. `phase2_post_apply_verify.sql`: estrutura (2 tabelas, 4 triggers, RLS-on) **E** empírico (imutabilidade UPDATE+DELETE+TRUNCATE como `service_role` + zero acesso anon/authenticated), com `ON_ERROR_STOP=1`.
2. `phase2-db-apply.yml`: manual-only, frase `APPLY-PHASE2`, Environment `production-db` + required reviewers, actions SHA-pinadas (zero tag mutável), URL mascarada, push forward-only atômico, job verify executando o SQL.
3. Nenhum apply; nenhum secret em repo/payload/log (grep limpo).
4. Handoff com instruções de paridade + gate board residual.

## 4. Resultado
- [x] **Critério 1 — verify SQL.** `supabase/tests/phase2_post_apply_verify.sql`:
  - **§4 estrutural:** 2 tabelas; 4 triggers nomeados (`*_no_update_delete` + `*_no_truncate` nas duas); RLS-on nas duas. **Extra de rigor:** função `versioning_row_immutable()` com `search_path` fixo (paridade SEC-0007 §1) e os 4 unique constraints de `version`/`(version,hash)` — backbone de reprodutibilidade (SEC-0007 §2).
  - **§5 empírico:** `TRUNCATE` + `UPDATE` + `DELETE` como `service_role` nas duas tabelas → asserta **`restrict_violation`** (prova o **trigger**, não o grant — `service_role` bypassa RLS); `anon`/`authenticated` → `select` levanta `insufficient_privilege` (revoke honrado). Efeito colateral nulo: sondas em transação sempre revertida.
- [x] **Critério 2 — workflow.** `.github/workflows/phase2-db-apply.yml` espelha a Fase 1 endurecida: `workflow_dispatch` only, job `guard` com frase `APPLY-PHASE2`, `environment: production-db` (required reviewers DevOps+Security em runtime), **3 actions SHA-pinadas** (checkout `34e1148…` v4.3.1, setup-cli `ab05898…` v1.7.1), URL via session pooler **mascarada** (`::add-mask::`), `permissions: contents: read`, `supabase db push --db-url` (forward-only, atômico), job `verify` rodando o SQL com `ON_ERROR_STOP=1`. **Service-role key não usada** (SEC-F19).
- [x] **Critério 3 — limpeza.** Grep: 0 tag mutável; 3 SHA-pins; 0 valor de secret; 0 referência a `SERVICE_ROLE_KEY`. **Nenhum apply executado.**
- [x] **Critério 4 — este handoff.**

**Como verificar (paridade + higiene):**
`grep -nE 'uses:.*@(v[0-9]+|main|latest)' .github/workflows/phase2-db-apply.yml` → vazio ·
`grep -n 'APPLY-PHASE2' .github/workflows/phase2-db-apply.yml` → presente ·
o job `verify` aponta para `supabase/tests/phase2_post_apply_verify.sql`.

## 5. Arquivos alterados
- `supabase/tests/phase2_post_apply_verify.sql` — **criado**: verify §4+§5 da Fase 2.
- `.github/workflows/phase2-db-apply.yml` — **criado**: pipeline de apply gated da Fase 2.

(Migration e rollback **intocados**, conforme constraint.)

## 6. Diferenças vs. Fase 1 (paridade consciente)
- **Frase:** `APPLY-PHASE2` (não `APPLY-PHASE1`); `concurrency.group: phase2-db-apply`.
- **Objetos:** 2 tabelas / 4 triggers / função compartilhada `versioning_row_immutable()` (vs. 4 tabelas / `is_admin()` na Fase 1).
- **Imutabilidade — estrita:** asserta **só `restrict_violation`** (a Fase 1 tolerava `restrict_violation OR insufficient_privilege`). Aqui o payload e o SEC-0007 §2 exigem **provar o trigger**, pois `service_role` retém os grants (a migration revoga só de anon/authenticated). Catch mais largo mascararia trigger ausente.
- **`db push`:** aplica só o pendente (Fase 1 já está trackeada) = a migration da Fase 2.

## 7. Impacto no escopo
- **MVP travado?** Sim. Só pipeline/verify; nada de Fase 2-produto/marketplace; stack inalterada.
- **Non-negotiable?** Reforça #5 (Score versionado: append-only verificável em banco), #10 (secrets), supply chain (SHA-pin). **Nenhum apply**; zero secret no repo/log.
- **Pontos fortes preservados:** `contents: read`, manual-only + frase, required reviewers, URL mascarada, apply atômico.

## 8. Validação executada
- **Estrutural (grep):** 3 SHA-pins / 0 tag mutável / 0 secret / 0 service-key; wiring de `APPLY-PHASE2`, `production-db`, `add-mask`, verify→SQL confirmados.
- **Apply:** **não executado** (constraint). A validação funcional do verify roda no 1º dispatch gated, pós-merge + Environment.

## 9. Riscos
- **Privilégio de `service_role` para TRUNCATE:** a asserção estrita `restrict_violation` assume que `service_role` mantém o grant (default do Supabase; threat model do SEC-0007 §2). Se um ambiente não conceder o grant, o `truncate` levantaria `insufficient_privilege` e o verify falharia — sinal a investigar, não falso-positivo silencioso.
- **Drift de versão de actions:** SHA-pin congela; re-pinar conscientemente a cada bump.
- **Merge:** sem push direto na `main` (global rule #12) — PR + revisão.

## 10. Revisões necessárias
- [ ] ⏳ **Security — `audit_secrets` (matrix #8)** sobre esta pipeline de apply da Fase 2. SEC-0007 §4 já declarou que o verify "entra na revisão da pipeline de apply da Fase 2". Revisão de **delta** sobre a Fase 1 já aprovada (mesmos patterns endurecidos). **Acionada** via `next_recommendation`.
- [x] **DevOps** — esta entrega (autor).

## 11. Quadro de gates residual do `run_migration` (Fase 2)
| Gate | Estado |
|---|---|
| Security `review_rls` do SQL (matrix #3) — SEC-0007 | ✅ baixado |
| Data/AI #5 (fidelidade §7 + ownership do `rubric_hash`) | ⏳ pendente (**não é gate de DevOps**) |
| **Verify pós-apply de paridade (DevOps, matrix #8)** | ✅ **entregue aqui** |
| Security `audit_secrets` da pipeline (matrix #8) | ⏳ recomendada (delta) — `next_recommendation` |
| Gate humano + required reviewers do apply | ⏳ em tempo de execução (como na Fase 1) |
| Fase 9 — RLS Policies | ⛔ **veto à parte de pé** (SEC-0001 §0) — **não tocado aqui** |

## 12. Próximos passos
1. **Security (`audit_secrets`):** revisar a pipeline da Fase 2 (delta) → baixar/condicionar.
2. **Data/AI #5:** confirmar fidelidade ao §7 + `rubric_hash` (gate paralelo, não-DevOps).
3. **Merge do PR** (branch + revisão; nunca push na `main`).
4. **Database (`run_migration`, gated):** dispara `phase2-db-apply.yml` → apply + verify §4/§5.

## 13. Open decisions / bloqueios
- **Nenhum bloqueio de DevOps.** A paridade exigida está entregue. Os gates restantes
  (Data/AI #5, Security da pipeline, humano + reviewers) são downstream e **intactos**; o
  veto da Fase 9 permanece de pé e fora do escopo desta tarefa.
