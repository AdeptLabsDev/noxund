# Handoff — U3A-GRANTS · SG-8 runtime identity, grants & RLS (migration 0009, design-only)

## 1. Identificação
- **Tarefa:** U3A-GRANTS (DATA-SG8-001 estágio 3 · runtime identity)
- **Owner agent:** Database (autor) — co-revisão obrigatória: Data Integrity · Data/AI Pipeline · QA · Security · DevOps
- **Data:** 2026-07-26
- **Prioridade:** P1

## 2. Objetivo
Autorar (design-only, sem apply/merge) a migration **0009**: a identidade de runtime dedicada `sg8_compute_writer`, seus grants mínimos por coluna, RLS dedicada e a revogação total do `service_role`/identidades amplas sobre as 4 tabelas SG-8 da 0008.

## 3. Critério de aceite (do backlog / decisão)
DEC-0026: identidade canônica única `sg8_compute_writer` (trancada, NOLOGIN, sem senha, zero membership/ownership, falha se identidade externa homônima divergir); grants mínimos exatos (CONNECT/USAGE/SELECT + INSERT por coluna + UPDATE só nas 5 de sessions; `comparison_contract_version` INSERT-only; sem DELETE/TRUNCATE/REFERENCES/TRIGGER/DDL/sequence/parents); 9 policies RLS `TO sg8_compute_writer` role-wide; revogação de `service_role`/`anon`/`authenticated`/`authenticator`/`PUBLIC` verificada por privilégio **efetivo**; default UUID descoberto (não presumido) + EXECUTE exato; rollback restaura baseline capturado de `report_runs`; verifies apply/rollback; harness dispatch.

## 4. Resultado
- [x] Critério de aceite atendido (autoria completa; validação executável pendente do dispatch CI)
- [x] Demonstrável: dispatch `migrations-local-verify.yml` contra o SHA do head da branch com os 4 paths da 0009 (ciclo apply→post-apply→rollback→post-rollback→reapply→post-apply→teardown).
- Migration cria role (create-or-adopt-if-exact), grants por coluna, descobre o default UUID e concede EXECUTE nele, cria 9 policies, revoga as identidades amplas e **auto-verifica** o isolamento efetivo do `service_role` (aborta se `has_table_privilege` ainda for verdadeiro).

## 5. Arquivos alterados
- `supabase/migrations/20260620000009_sg8_runtime_identity_grants_rls.sql` — role + grants + UUID EXECUTE + 9 policies + revokes + auto-verify de isolamento.
- `supabase/rollback/20260620000009_sg8_runtime_identity_grants_rls.rollback.sql` — policies→grants→prova zero ownership/membership→drop role→restauração do baseline (`report_runs`).
- `supabase/tests/sg8_runtime_identity_grants_rls_post_apply_verify.sql` — §A identidade · §B matriz de grants · §C 9 policies · §D isolamento efetivo + honestidade do admin · §E comportamento sob `SET ROLE` · §F 0008 GREEN.
- `supabase/tests/sg8_runtime_identity_grants_rls_post_rollback_verify.sql` — ausência da 0009 · baseline restaurado (== `report_runs`) · 0008 intacto.
- `docs/product/decisions/DEC-0026-sg8-runtime-identity-grants-rls.md` — decisão + matriz de grants.

## 6. Impacto no escopo
- Mantém o MVP travado? **Sim** — infra de segurança do gate SG-8; sem feature nova de produto.
- Toca non-negotiable? **Segurança/RLS/menor-privilégio** (reforça) e **rastreabilidade** (superfície de escrita auditável). Nenhum número/IA tocado (DEC-0025 preservada).
- Toca número/banco/auth? **Banco + auth (grants/RLS/role)** → exige revisão Database + Security + Data Integrity + QA + DevOps + Data/AI.

## 7. Validação executada
- **Autoria + revisão estática** dos 4 SQL contra `postgres_sg8.py` (matriz de colunas), contra a 0008 (objetos/triggers) e contra o comportamento de default privileges do Supabase (baseline de `service_role`).
- **Executável (pendente):** um dispatch do harness hermético. Sem Docker/Supabase local nesta máquina; a captura empírica do baseline e a resolução exata de `gen_random_uuid()` acontecem no ciclo de CI (o harness é hermético, loopback-only, sem secrets).

## 8. Riscos
- **Baseline de `service_role`:** capturado em runtime de `report_runs` (irmã intocada — grep confirma que nenhuma migration 0001–0008 mexe em `service_role`). Se um futuro migration passar a revogar `service_role` de `report_runs`, revisitar a âncora. Mitigado: o rollback aborta se o baseline capturado for vazio.
- **Idempotência do harness (role cluster-global):** `supabase db reset` reaplica sobre a role já criada por `supabase start`; a lógica create-or-adopt-if-exact cobre isso e recusa qualquer divergência.
- **Ativação futura:** a role é NOLOGIN/sem senha; o rollback operacional pós-ativação exige NOLOGIN + drenagem de sessões antes (documentado).

## 9. Revisões necessárias
- [x] Data/AI Review (o writer do compute SG-8)
- [x] Security Review (role/grants/RLS/revogação/isolamento efetivo)
- [x] Database/Data Integrity Review (migration/rollback/append-only/baseline)
- [x] QA Review (verifies apply/rollback; ciclo do harness)
- [x] DevOps Review (dispatch hermético; sem remoto/secret)
- [ ] Product Lead — GO de apply remoto (fora desta unidade)

## 10. Próximos passos
- Estabilizar head → dispatch único do harness contra o SHA exato → coletar run.
- Após GREEN + 6 pareceres: a próxima unidade (runner/compute real) permanece **BLOQUEADA** sob RO-1 até GO próprio; apply remoto de 0008/0009 é decisão separada e gated.

## 11. Open decisions / bloqueios
- **Nenhum OPEN DECISION.** Bloqueios de fronteira (ativação LOGIN, senha, Environment, secrets, apply remoto, compute real, Phase 6, remoção do stash, merge) permanecem **fora de escopo** por DEC-0026.
