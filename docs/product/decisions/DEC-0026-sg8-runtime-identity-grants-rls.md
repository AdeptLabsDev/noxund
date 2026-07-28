## DEC-0026 — SG-8 runtime identity: role dedicada `sg8_compute_writer`, grants mínimos por coluna e RLS dedicada (design-only)

- **Data:** 2026-07-26
- **Status:** **Registrada. Decisão canônica do Product Lead.** GO **exclusivo** para a unidade **U3A-GRANTS** — autoria design-only da migration **0009** de identidade, grants e RLS do runtime SG-8. **Sem apply remoto, sem merge, sem Environment/secret.**
- **Decisor:** Product Lead · autorado/registrado pelo Product Orchestrator
- **Área:** Segurança (superfície de escrita/menor-privilégio) / Banco (grants + RLS, aditivo, pré-apply) / Integridade de Dados / Data-AI Pipeline (o writer do compute SG-8) / DevOps (harness de validação local)
- **Relaciona:** `20260620000008_sg8_reconciliation_session.sql` (as 4 tabelas + RLS habilitada + triggers/FSM/PASS gate) · `services/data-engine/src/noxund_data_engine/postgres_sg8.py` (`PostgresSg8Store` — as colunas exatas escritas/lidas) · DEC-0025 (decoupling de LLM; a §"Fronteira" da DEC-0025 vetava a 0009 — esta decisão a **destrava** especificamente para U3A-GRANTS) · DEC-0021 (RO-1).

### Contexto
A 0008 modelou as 4 tabelas SG-8 com RLS **habilitada** e **zero policies**, revogando `anon`/`authenticated`/`PUBLIC` mas **preservando** o grant default do `service_role`. Naquela unidade, o `service_role` era o escritor provisório. A direção agora muda: o compute SG-8 (futuro serviço `sg8-compute`, distinto do `production-db`) terá uma **identidade de runtime dedicada e de menor privilégio**, e o `service_role` — uma credencial ampla, com `BYPASSRLS` — **deixa de ter qualquer acesso** às tabelas SG-8. A 0008 ainda **não foi aplicada** remotamente: há janela limpa para nascer com a superfície de escrita correta.

### Decisão (o que se registra)

**1. Identidade canônica única.** A identidade de escrita SG-8 é **exclusivamente** `sg8_compute_writer`. `service_role` **não** é candidata a writer e **não** pode permanecer com acesso às tabelas SG-8.

**2. Role trancada (design-only, NOLOGIN, sem senha).** `sg8_compute_writer` nasce `NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS`, **zero memberships**, **zero ownership**, **sem senha**. Ativação (LOGIN + senha) é **out-of-band**, num estágio futuro, **nunca** nesta migration. Se uma role homônima **preexistir** e não corresponder **exatamente** ao contrato, a migration **falha** — jamais adota/modifica silenciosamente uma identidade externa.

**3. Grants mínimos e exatos** (matriz completa em §Matriz abaixo): `CONNECT` só no database atual; `USAGE` (não `CREATE`) no schema public; `SELECT` nas 4 tabelas; **INSERT coluna-a-coluna** só nas colunas efetivamente escritas pelo `PostgresSg8Store`; **UPDATE só em `sg8_sessions`** e só em `{status, report_id_1, report_id_2, terminal_at, verdict_reason}`. `comparison_contract_version` tem **apenas INSERT** (nunca UPDATE — imutável). **Nada** de DELETE/TRUNCATE/REFERENCES/TRIGGER, UPDATE em tabela append-only, DDL, sequence (não há sequence: PKs são `gen_random_uuid()`), nem acesso a `reports`/`report_runs`/`rubric_versions` ou outros pipelines.

**4. RLS dedicada, acesso role-wide.** 9 policies **separadas por tabela e operação**, **exclusivamente `TO sg8_compute_writer`**, `USING/WITH CHECK = true` — a policy concede acesso **global às linhas SG-8** para a identidade dedicada (não por sessão/tenant). Os invariantes de estado/conteúdo **não** são duplicados na policy: continuam nos **grants por coluna** e nos **triggers/CHECKs da 0008** (FSM, terminalidade, PASS gate, append-only). Sem policy de DELETE; UPDATE só em `sg8_sessions`.

**5. Revogação das identidades amplas, verificada por privilégio EFETIVO.** `service_role`, `anon`, `authenticated`, `authenticator`, `PUBLIC` perdem todos os verbos nas 4 tabelas. Para `service_role`, o isolamento é comprovado por `has_table_privilege` (não só ACL textual): se restar acesso por ownership/membership/qualquer caminho, a **migration aborta** (fail-closed). Não se alega isolamento enquanto `has_table_privilege` retornar verdadeiro.

**6. Default UUID descoberto, não presumido.** A função exata que respalda o default de `sg8_round_report_evidence.id` (a única tabela cujo `id` o adapter **não** escreve) é descoberta no catálogo (`pg_attrdef`+`pg_depend`) e a role recebe `EXECUTE` **só** nela — sem depender silenciosamente de `PUBLIC EXECUTE`. Se a função morar em schema não-`public`/`pg_catalog`, concede-se também `USAGE` nesse schema (descoberta contraditória comprovada, mínima). O adapter e a estratégia de IDs **não** mudam nesta unidade.

**7. Baseline do rollback capturado, não presumido.** O rollback restaura **exatamente** o baseline pós-0008 do `service_role`, capturado em **runtime** da tabela-irmã intocada `public.report_runs` (mesmo schema/criador; nenhuma migration 0001–0008 concede/revoga `service_role` — só `anon`/`authenticated`/`PUBLIC`). Ordem do rollback: policies → grants (função/tabela/coluna/schema/database) → prova de zero ownership/memberships → drop role → restauração do baseline.

**8. Zero provider/LLM.** Coerente com DEC-0025: nada de provider, modelo, prompt, secret, Environment ou rede externa. `sg8_compute_writer` é apenas a fronteira de menor-privilégio do compute determinístico.

### Matriz de grants (por tabela · verbo · coluna)

| Tabela | SELECT | INSERT (colunas) | UPDATE (colunas) |
|---|---|---|---|
| `sg8_sessions` | ✔ (tabela) | `id`, `source_collection_run_id`, `comparison_contract_version` | `status`, `report_id_1`, `report_id_2`, `terminal_at`, `verdict_reason` |
| `sg8_resolution_snapshots` | ✔ (tabela) | `id`, `sg8_session_id`, `source_collection_run_id`, `resolver_version`, `resolver_hash`, `fact_count`, `content_hash` | — (append-only) |
| `sg8_round_executions` | ✔ (tabela) | `id`, `sg8_session_id`, `round_number`, `source_collection_run_id`, `resolution_snapshot_id`, `compute_engine_name`, `compute_engine_version`, `compute_manifest_hash` | — (append-only) |
| `sg8_round_report_evidence` | ✔ (tabela) | `round_execution_id`, `sg8_session_id`, `report_id`, `canonical_digest` — **`id` NÃO** (usa default `gen_random_uuid()` → só `EXECUTE`) | — (append-only) |

Notas: `comparison_contract_version` = **INSERT-only** (nunca UPDATE). `sg8_round_report_evidence.id` = **sem INSERT** (default UUID sob a role, via `EXECUTE` §6). Fonte da matriz: `postgres_sg8.py` `_INSERT_SESSION`/`_INSERT_SNAPSHOT`/`_INSERT_ROUND`/`_INSERT_EVIDENCE` + `_SET_STATUS`/`_BIND_REPORTS`/`_MARK_TERMINAL`.

### Policies (9)

`sg8_sessions_writer_{select,insert,update}` · `sg8_resolution_snapshots_writer_{select,insert}` · `sg8_round_executions_writer_{select,insert}` · `sg8_round_report_evidence_writer_{select,insert}`. Todas `TO sg8_compute_writer`; `SELECT/UPDATE` com `USING (true)`, `INSERT/UPDATE` com `WITH CHECK (true)`. Sem DELETE. Globalidade documentada: acesso role-wide às linhas SG-8 para a identidade dedicada.

### Rollback operacional (registro)
Esta unidade é design-only e a role nasce NOLOGIN/sem sessão. Um rollback **futuro, após ativação** (LOGIN out-of-band), exige **primeiro**: (i) `ALTER ROLE sg8_compute_writer NOLOGIN`; (ii) drenagem/encerramento controlado das sessões; (iii) só então o rollback. Esta migration **não** encerra sessões nem executa `ALTER ROLE LOGIN/NOLOGIN` operacional.

### Separação de bancos (registro)
`production-db` (o projeto Supabase existente) versus **futuro** `sg8-compute` (o serviço determinístico que escreverá SG-8). `sg8_compute_writer` é a fronteira de menor-privilégio entre eles: uma identidade dedicada, sem acesso aos parents (`reports`/`report_runs`/`rubric_versions`), sem BYPASSRLS, sem senha até ativação out-of-band.

### Artefatos (PR — design-only, NÃO aplicado)
- `supabase/migrations/20260620000009_sg8_runtime_identity_grants_rls.sql`
- `supabase/rollback/20260620000009_sg8_runtime_identity_grants_rls.rollback.sql`
- `supabase/tests/sg8_runtime_identity_grants_rls_post_apply_verify.sql`
- `supabase/tests/sg8_runtime_identity_grants_rls_post_rollback_verify.sql`
- `docs/product/decisions/DEC-0026-…` (este) + handoff `docs/agents/handoffs/HANDOFF-U3A-GRANTS.md`

### Fronteira e não-goals
Design-only. **NÃO** autoriza: ativação LOGIN, criação de senha, Environment, secrets, apply remoto (0008 **ou** 0009), workflow runtime, compute real, Phase 6, remoção do stash, ou merge. Fora de escopo desta unidade.

### Revisões obrigatórias antes de qualquer apply
**Database · Data Integrity · Data/AI Pipeline · QA · Security · DevOps** (rodada read-only, analisando **privilégio efetivo**, não só SQL textual) + **um** dispatch do harness hermético `migrations-local-verify.yml` contra o SHA exato, agora com os **quatro paths da 0009** (ciclo apply → post-apply → rollback → post-rollback → reapply → post-apply → teardown). Apply remoto segue GO próprio, gated.
