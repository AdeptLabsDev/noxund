## DEC-0025 — SG-8 provider-independent: remoção integral do acoplamento a LLM (pipeline autoritativo determinístico)

- **Data:** 2026-07-25
- **Status:** **Registrada. Decisão canônica do Product Lead.** GO para a unidade **U3A-DECOUPLE** (design-only, sem apply remoto). Emenda **vinculante** ao contrato de design do SG-8.
- **Decisor:** Product Lead · autorado/registrado pelo Product Orchestrator
- **Área:** Metodologia (fronteira determinística × generativa) / Reprodutibilidade (P5-REPRO-01) / Schema (aditivo, pré-apply) / Integridade de Dados / Segurança (superfície de credenciais)
- **Supera explicitamente:** `DATA-SG8-001-sg8-design-contract.md` **§5.3** e **§R** nas partes LLM-specific · **Q-3/Q-5** nas partes relativas a provider/modelo · **DEC-0024 item 4** ("Fronteira LLM Q-3/§5.3").
- **Relaciona:** `20260620000008_sg8_reconciliation_session.sql` (schema emendado na origem) · `sg8_runner.py` / `postgres_sg8.py` / `sg8_coordinator.py` · `entity_resolution.py` (port opcional, mantido isolado) · DEC-0023 (1º compute = SG-8) · DEC-0021 (RO-1) · U3A-0 (arquitetura de credenciais — partes LLM anuladas).

### Contexto
A direção anterior modelava uma **proveniência de LLM obrigatória** na Round 1 do SG-8 (`sg8_round_executions.llm_provider/llm_model/llm_model_version/llm_prompt_hash/llm_params_json/llm_adapter_version` + CHECKs `provenance_by_round_chk`/`prompt_hash_format_chk`) e assumia um provider/modelo pinado (Q-3/Q-5). O Product Lead **revogou** essa direção: a NOXUND **não será dependente de LLM, modelo remoto ou qualquer provider externo**. O SG-8 **estágio 3** (schema `0008`) ainda **não foi aplicado remotamente** — há janela limpa para corrigir a semântica **na origem**, sem carregar dívida para produção.

### Decisão (o que se registra)

**1. Pipeline autoritativo integralmente determinístico.** Round 1 determinística; Round 2 como **replay determinístico**; resolução **inequívoca por regras**; **casos ambíguos → revisão humana** (`llm=None`). **Nenhuma IA** gera score, número, digest ou veredito. **Nenhum provider externo** no caminho crítico; **nenhuma chamada de rede** externa. A **ausência** de LLM **nunca** bloqueia `passed`.

**2. Assistência por modelo é feature separada e não-autoritativa.** Qualquer futura assistência por modelo exige **nova decisão**, será **não-autoritativa** e **desligada por padrão**, e **não é pré-modelada** nesta unidade. **Proibido** nesta unidade: campos `ext_llm_*`, `engine_kind='llm_assisted'`, provider/model/prompt "antecipados", Environment/secret/workflow de provider, API key, dependência de inferência externa.

**3. Schema provider-independent (emenda in-place da `0008`, pré-apply).** Removidas as 6 colunas `llm_*` de `sg8_round_executions`; **sem** colunas `ext_llm_*`. Substituídas por **proveniência mínima de computação determinística**:
- `compute_engine_name text NOT NULL`; `compute_engine_version text NOT NULL`; `compute_manifest_hash text NOT NULL`; `compute_adapter_version text NOT NULL`; `compute_params_json jsonb NULL`.
- Nenhum campo duplica coluna autoritativa existente: o `resolver_version`/`resolver_hash`/`content_hash` do **snapshot** identificam o conjunto de fatos congelado (DADOS); o `compute_manifest_hash` identifica o **CÓDIGO/CONFIG** versionado que determina o resultado (escopo distinto).

**4. Definição canônica do `compute_manifest_hash`.** SHA-256 (64 hex minúsculo) da serialização **canônica** (chaves ordenadas, compacta, UTF-8) dos artefatos + configuração versionados que **realmente determinam** o resultado: `pipeline_version`, `resolver_version`, `rule_version`+`rule_hash`, `rubric_version`+`rubric_hash`, `opportunity_version`+`opportunity_hash`. **Não** inclui credenciais, timestamps, UUIDs de execução ou dados instáveis. Builder canônico versionado: `sg8_coordinator.canonical_compute_manifest`; o adapter valida **formato** (nunca deriva); o schema é o backstop (`sg8_round_executions_manifest_hash_format_chk`).

**5. Proveniência simétrica nas 2 rodadas.** Round 1 e Round 2 **ambas** persistem proveniência de computação completa (mesmo `compute_engine_name`/`version`/`manifest_hash`/`adapter_version`). **Elimina** a semântica anterior "Round 2 sem proveniência (zero-LLM)".

**6. PASS gate reforçado.** `passed` exige: mesmo `source_collection_run_id`; mesmo snapshot; relatórios correspondentes; evidências R1/R2 correspondentes; **digests R1==R2**; **e `compute_manifest_hash` R1==R2**. **Divergência de manifesto impede `passed` MESMO se os digests coincidirem** (motor/artefatos/config diferentes ⇒ resultado não reproduzível de fato). Elegibilidade de publish continua derivando exclusivamente de `sg8_sessions.status='passed'` (DD-1).

**7. Port opcional preservado e isolado.** O `LLMCandidateExtractor` de `entity_resolution.py` (fallback textual, não-autoritativo, que já degrada para revisão humana com `llm=None`) **permanece isolado**: **não** é importado nem usado pelo SG-8, **não** aparece no contrato SG-8, **não** é necessário para testes ou runtime. Esta unidade **não** o remove.

### Invariantes preservados
Lifecycle/FSM; snapshot congelado; duas rodadas; evidência realmente produzida por cada rodada; digest determinístico; PASS gate; append-only; **golden digest inalterado** (proveniência é FORA do payload — DD-2); replay ×2; adapters driver-free; integração local hermética; ausência de schema remoto.

### Artefatos (PR — design-only, NÃO aplicado)
- `supabase/migrations/20260620000008_sg8_reconciliation_session.sql` (emendada na origem) + `supabase/tests/sg8_reconciliation_session_post_apply_verify.sql` (colunas/CHECKs novos, ausência das 6 `llm_*`, manifesto sha256, proveniência simétrica, PASS-gate manifesto divergente). Rollback + post-rollback verify **inalterados** (name/sweep-based — demonstrado por inspeção).
- `services/data-engine/src/noxund_data_engine/{sg8_runner,postgres_sg8,sg8_coordinator}.py` (provider-neutral) + testes unitários + E2E reescritos; count guard reancorado (`data-engine-tests.yml`).
- Emenda no topo de `DATA-SG8-001` + marcador de supersessão em §5.3.

### Fronteira e não-goals
Design-only. **NÃO** autoriza: migration `0009`, role/grants, RLS runtime writer, Environment, secrets, provider/modelo, workflow live, banco remoto, compute real, Phase 6, remoção do stash, apply remoto ou merge.

### Revisões obrigatórias antes de qualquer apply
**Database · Data Integrity · Data/AI Pipeline · QA · Security · DevOps** (rodada read-only) + **um** dispatch do harness hermético contra o SHA exato (E2E local 6/6 ×2). Apply remoto segue GO próprio, gated.
