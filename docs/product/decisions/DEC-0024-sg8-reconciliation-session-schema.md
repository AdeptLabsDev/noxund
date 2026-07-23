## DEC-0024 — Unidade de Schema/Database do SG-8 (`sg8_sessions` + snapshot + rodadas + evidência) + binding diferido dos report_run_id

- **Data:** 2026-07-23
- **Status:** **Registrada.** GO do Product Lead para a 1ª unidade do estágio 3 (Schema/Database), limitada a preparação + abertura de PR. **NÃO aplicada** (nenhuma migration/rollback/verify executada em banco compartilhado ou live). Decisão de binding físico tomada pelo Product Lead (2026-07-23).
- **Decisor:** Product Lead (GO da unidade + decisão de binding) · autorado pelo Database (Product Orchestrator) · registrado pelo Product Orchestrator
- **Área:** Schema (aditivo) / Reprodutibilidade (P5-REPRO-01) / Integridade de Dados / Metodologia (fronteira LLM) / Segurança (grants/RLS/append-only)
- **Relaciona:** `DATA-SG8-001-sg8-design-contract.md` (§2.1/D-1/D-10 · §5.3 · §6 · §R.1 Q-1…Q-5 · §R.2 DD-1…DD-5 · §9 estágio 3) · `sg8_runner.py` (Sg8State — 7 marcos duráveis) · Fase 5 `20260620000005` (`reports`/`report_runs`) · DEC-0017 (ratificações v1) · DEC-0021 (RO-1) · DEC-0023 (1º compute = SG-8) · `agent-review-matrix.md`

### Contexto
O contrato de design SG-8 (DATA-SG8-001) foi ratificado docs-only e reconciliou Q-1…Q-5, deixando à unidade de schema do **estágio 3** (DD-5) a materialização de: a **sessão** canônica, o **snapshot de resolução** leve (Q-1), as **rodadas** (Round 1/Round 2) e a **evidência** comparável por relatório. Ao preparar o schema, o Orchestrator identificou **uma decisão não coberta** por Q-1…Q-5 nem pelo contrato: o **binding físico dos dois `report_run_id` congelados** — o pipeline atual sobrecarrega `run_id` como identidade de relatório **e** chave de proveniência do raw, o que só reconcilia com 1 relatório por coleta; o SG-8 **desacopla** (um `source_collection_run_id`, dois `report_run_id` distintos sobre o mesmo dataset). Escalado ao Product Lead (não decidido silenciosamente).

### Decisão (o que se registra)

**1. Binding DIFERIDO por FK composta (Product Lead, 2026-07-23).** Interpretar D-1 como *"os dois relatórios tornam-se congelados/imutáveis quando materializados na Round 1"* — **não** *"devem existir no SESSION_OPEN"*. Concretamente em `sg8_sessions`:
- colunas `report_id_1` / `report_id_2` (referenciam `reports.id`; **não** confundir com `source_collection_run_id`), **começam NULL**;
- CHECK **ambos NULL ou ambos preenchidos**; CHECK **distintos** quando preenchidos; **obrigatórios** a partir de `r1_computed`/`passed`;
- a Round 1 cria os dois `reports` e faz o binding **na mesma transação**; transição **NULL → valor uma única vez**, **imutável** depois (sem alterar/remover/substituir); **PASS/FAIL** tornam tudo terminal e imutável;
- FKs compostas `(report_id_N, source_collection_run_id) → reports(id, run_id)` provam pertencimento à **mesma coleção-fonte**; para habilitá-las, **UNIQUE (id, run_id) aditiva em `reports`** — autorizada explicitamente, **sem alterar a semântica** de `reports` (`id` já é PK).

**2. Estados = os 7 marcos duráveis do runner.** O enum `sg8_session_status` usa **exatamente** os estados de `Sg8State` (`session_open`, `r1_awaiting_review`, `r1_resolved`, `r1_snapshot_frozen`, `r1_computed`, `passed`, `failed`) — **nenhum estado novo** (contrato/escalada). `passed`/`failed` terminais.

**3. Reconciliação Q-1/Q-2 no schema.** Q-1: `sg8_resolution_snapshots` é registro **leve e imutável** (não duplica fatos): `resolver_version`+`resolver_hash`, `fact_count`, `content_hash` canônico, `frozen_at`; **máx. 1 por sessão**. Q-2/DD-1: **elegibilidade de publish deriva só de `sg8_sessions.status='passed'`** — **zero** acoplamento a `report_runs.status`, **zero** coluna nova em `report_runs`.

**4. Fronteira LLM (Q-3/§5.3) fora do digest.** Proveniência LLM (provider, modelo **exato** pinado, `model_version`, `prompt_hash`, `params`, `adapter_version`) vive em `sg8_round_executions` (Round 1), **all-or-nothing** (CHECK null-safe); **Round 2 é zero-LLM** (CHECK). Nunca entra na superfície comparável (DD-2). **Zero secret/credencial** no schema (Q-5 é estágio 3).

**5. Append-only + terminalidade (DD-3/DD-4/D-10).** Snapshot, rodadas e evidências são **append-only e imutáveis** por trigger (abaixo do service_role, SEC-D03/F01); evidência particionada por `round_execution_id` e única por `(round_execution_id, report_id)` — nunca sobrescrita; sessão terminal não reabre. **Round 2 reusa exatamente os mesmos dois relatórios** (trigger de pertencimento) — não cria nem troca IDs.

**6. Aditivo, não destrutivo.** Só CREATE de objetos novos + a UNIQUE aditiva em `reports`. **`report_runs` permanece intacta** (o verify prova: enum de 5 rótulos inalterado, zero coluna/trigger SG-8). Default-deny (RLS enable + revoke; zero policy — Fase 9 vetada).

### Artefatos (PR — design-only, NÃO aplicado)
- `supabase/migrations/20260620000008_sg8_reconciliation_session.sql` (migration aditiva; ID `0008` — evita a `0007` PARKED de Phase 6);
- `supabase/rollback/20260620000008_sg8_reconciliation_session.rollback.sql` (rollback pareado, incl. `reports_id_run_key`);
- `supabase/tests/sg8_reconciliation_session_post_apply_verify.sql` (verify read-only: §4 estrutural + §5 empírico, incl. as 7 provas de lifecycle exigidas).

### Fronteira e não-goals (§9)
Esta unidade autoriza **apenas** preparação + PR do schema (estágio 3, parte 1). **NÃO** autoriza: merge, apply de SQL, banco compartilhado/live, adapters live, alteração do runner offline, credencial/provider/Environment/secret sg8-compute, workflow, leitura do dataset real, compute-live ou execução SG-8. `0007`/`producer_events` permanece **PARKED**; publish barrado até PASS.

### Revisões obrigatórias antes de qualquer apply
**Database** · **Data Integrity** · **Data/AI Pipeline** · **QA** · **Security** (grants/RLS/append-only + isolamento futuro do Environment `sg8-compute`). Apply seguirá gated próprio (humano + required reviewers), como nas Fases 1–6.

---

### Adendo aditivo — Hardening do schema (2026-07-24, design-only, NÃO aplicado)

Endurecimento da unidade (mesma migration `20260620000008`, ainda **design-only, sem apply/merge**), registrado aditivamente — não altera as decisões acima:

1. **Máquina de estados enforced no banco.** Além de armazenar os 7 marcos de `Sg8State`, o trigger da sessão passa a impor a **transição monotônica**: a sessão **nasce** obrigatoriamente em `session_open` (sem binding, sem terminalidade/razão); só o **próximo avanço** da cadeia `session_open→r1_awaiting_review→r1_resolved→r1_snapshot_frozen→r1_computed→passed` é aceito; **`failed`** é permitido a partir de qualquer estado não-terminal; **saltos, regressões, no-op e reabertura** são rejeitados; `passed`/`failed` continuam terminais e imutáveis. **Nenhum estado novo** é criado (paridade com o runner offline e DATA-SG8-001).

2. **Terminalidade com razão obrigatória.** CHECK consolidado: `passed`/`failed` exigem `terminal_at` **e** `verdict_reason` não-vazio/não-branco; estados não-terminais exigem ambos **NULOS**.

3. **Gate de PASS como defesa-em-profundidade.** O banco recusa gravar `status='passed'` sem **prova completa e consistente**: binding dos 2 relatórios; exatamente 1 Round 1 + 1 Round 2; ambas no mesmo `source_collection_run_id` e no mesmo `resolution_snapshot_id`; exatamente 2 evidências por rodada (uma por relatório congelado); evidências R1/R2 emparelhadas por `report_id`; e `canonical_digest` da Round 1 **idêntico** ao da Round 2 para cada relatório. **Elegibilidade de publish continua derivando EXCLUSIVAMENTE de `sg8_sessions.status='passed'`** (DD-1) — o gate apenas garante que esse `passed` só existe quando a reprodutibilidade foi provada.

4. **Default-deny reforçado.** `revoke all` agora inclui **PUBLIC** (além de `anon`/`authenticated`); `service_role` preserva o acesso mínimo para a futura integração gated; **zero policy** (Fase 9 vetada). O verify inspeciona ACLs e prova negação de SELECT/INSERT/UPDATE/DELETE para PUBLIC/anon/authenticated.

5. **Paridade apply/rollback/verifies.** Post-apply verify expandido (prova empírica de nascimento-limpo, FSM, terminalidade, gate de PASS e default-deny read/write, mantendo GREEN as invariantes anteriores). Novo **post-rollback verify** (`supabase/tests/sg8_reconciliation_session_post_rollback_verify.sql`, read-only/fail-closed): ausência das 4 tabelas + enum + 3 funções + `reports_id_run_key` + todo objeto `sg8_*`; `reports`/`report_runs` e seus contratos anteriores intactos. Rollback permanece pareado (dropa todos os objetos do apply). Habilita o self-test do harness hermético `migrations-local-verify.yml` (INFRA-0003) com os 4 paths do SG-8.

6. **Ordenação sem reserva de Phase 6.** Reafirma a política do `DEC-0024-ADDENDUM-migration-ordering-policy.md`: a migration SG-8 é `20260620000008`; a sequência canônica de `main` é `0001…0006`+`0008`; o `0007` é **vão intencional, não reserva**; a Phase 6 `0007` (WIP) **não faz parte** de `main` e **não é dependência nem reserva** desta unidade — se promovida, será re-revisada e renumerada.

**Fronteira do hardening:** continua **design-only** — sem apply local/remoto, sem dispatch de workflow, sem adapters live, Environment, secrets, workflow SG-8, credencial LLM, alteração do runner offline ou Phase 6. **Não autoriza merge nem execução de SQL.**
