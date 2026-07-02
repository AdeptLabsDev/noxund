## DEC-0019 — Resolução dos dois P1 do audit de determinismo (DATA-AUDIT-001): **self_channel RATIFICADO** em `channel-filter-v1` e **DC2-01 fail-closed** atribuído à **camada de coleta gated**

- **Data:** 2026-07-02
- **Status:** **Registrada — decisão de Product Lead.** Resolve os dois P1 que gateavam P5-REPRO-01 / 1º publish. **Não** altera tese, escopo travado, pesos §7, constantes do rubric, nem qualquer `rule_hash`/`rubric_hash` vivo.
- **Decisor:** Product Lead · registrada pelo Product Orchestrator · findings por `data_agent` (`DATA-AUDIT-001`), harness por `DATA-REPRO-001`
- **Área:** Metodologia (Channel Filter / Competition) · Coleta (integridade DC2-01) · Gate P5-REPRO-01
- **Relaciona:** DEC-0017 (ratificação v1 + item aberto `self_channel`), DEC-0018 (trilha gated de coleta), `DATA-AUDIT-001`, `DATA-REPRO-001`, PR #18

### Contexto
O audit adversarial de determinismo/conformidade (`DATA-AUDIT-001`) confirmou **zero fontes P0 de nondeterminismo** no pipeline determinístico e levantou **dois P1**, ambos decisões de governança antes de qualquer fix de código: (a) `self_channel` implementado e congelado no `rule_hash` mas formalmente **aberto** desde a DEC-0017; (b) fail-closed **DC2-01** sem dono definido (precondição do Channel Filter × camada de coleta).

### Decisão

**1. `self_channel` — RATIFICADO como parte de `channel-filter-v1`.** O canal do próprio artista é **excluído** da contagem de Competition. Confirma o comportamento já codificado e congelado no `rule_hash` atual → **zero mudança de código, `rule_hash` inalterado, golden digest do harness preservado** (`c8e33fe8…74ca8`). *Justificativa:* o artista não compete consigo mesmo; incluí-lo distorceria Competition. **Fecha** o item aberto "self_channel micro-open" da DEC-0017.

**2. DC2-01 fail-closed — DONO = camada de coleta gated.** O enforcement ocorre na **ingestão**: se `channels.list` não retornar um canal necessário à run, a run **aborta e exige recoleta como novo `run_id`**. O **Channel Filter permanece uma função determinística pura** sobre raw já coletado; a garantia "todo canal referenciado tem registro raw" é responsabilidade **upstream**. O fix lands **atrás do gate de coleta** (não-armado), delegável ao `data_agent` como design-only. A tolerância atual do filtro (`channel_filter.py:305`) passa a ser **by-design** dado o invariante upstream; endurecimento defensivo opcional é P2.

### Efeito no gate P5-REPRO-01 / PR #18
- Os dois P1 estão **resolvidos** (P1-a sem mudança de artefato; P1-b como decisão de dono + fix futuro atrás do gate, sem tocar a zona determinística nem o golden digest).
- **Bloqueador remanescente do merge do PR #18:** job de **CI dedicado** para `test_repro_harness.py` (DevOps — `data-engine-tests.yml` filtra só `test_entity_resolution.py`). Nenhuma mudança de código/rubric decorre desta DEC.

### Versões
- `channel-filter-v1` — **inalterado** (self_channel confirmado como parte da v1). **Sem** novo `rule_version`.
- **Sem** novo `rubric_version` / `opportunity_version`.

### Itens abertos / follow-ups (todos design-only)
- **DC2-01:** implementação fail-closed na camada de coleta gated (`data_agent`, atrás do gate).
- **P2s** do `DATA-AUDIT-001` (hardening/testes) + 3 OPEN questions.
- **Spec-refresh:** `DATA-CHANNEL-001` (self_channel explícito na regra), `DATA-CONST-001` (D-1: tabela `MAX_RUN_VIDEOS` 50→60), rótulo `MIN_SUBS` vs `MIN_SUBSCRIBERS` (D-2, cosmético, congelado).
- **DevOps:** job de CI do harness.

### Reversibilidade
Alta. Nada aplicado a schema; nenhuma coleta real; nenhuma constante alterada. Reverter `self_channel` ⇒ novo `channel-filter-v2` (nunca in-place). DC2-01 é aditivo atrás do gate.
