## DEC-0022 — DC2-01 fail-closed: o Channel Filter passa a **reafirmar** a pré-condição de completude de canais como última linha de defesa (emenda ao DEC-0019 §2)

- **Data:** 2026-07-19
- **Status:** **Registrada — decisão de Product Lead.** **Emenda** o DEC-0019 §2 (não o revoga). **Não** altera tese, escopo travado, pesos §7, constantes do rubric, gates do Channel Filter, ordem de gates, allow-list de `reason_code`, nem qualquer `rule_hash`/`rubric_hash`/`opportunity_hash` vivo. **Sem** bump de `rule_version`. Autoriza preparação, commit e abertura do PR; **não** autoriza merge nem qualquer execução downstream (coleta real, compute-live, SG-8).
- **Decisor:** Product Lead · registrada pelo Product Orchestrator
- **Área:** Metodologia (Channel Filter / DC2-01) · contrato de fronteira da zona determinística · gate de reprodutibilidade P5-REPRO-01
- **Relaciona:** DEC-0019 (§2, DC2-01 dono = coleta gated + tolerância by-design), DEC-0017 (ratificação `channel-filter-v1`), `DATA-AUDIT-001` (P1-b / DC2-01), `DATA-REPRO-001` (harness + golden digest), `DATA-CHANNEL-001` (spec do filtro)

### Contexto

O DEC-0019 §2 resolveu o P1-b (`DATA-AUDIT-001` / DC2-01) atribuindo o **enforcement** da completude "todo canal referenciado na run tem registro raw" à **camada de coleta gated** (ingestão aborta e exige recoleta como novo `run_id` se `channels.list` não retornar um canal necessário). Naquele registro, a **tolerância** do Channel Filter — um `channel_id` no footprint de vídeos sem `ChannelRecord` correspondente sendo silenciosamente tratado como "sem sinal de título" e portanto elegível — foi declarada **by-design** dado o invariante upstream, com endurecimento defensivo classificado como **P2 opcional**.

A operação real é fail-closed em toda fronteira sensível (padrão do repositório). Deixar a última zona determinística **tolerar** uma violação de um invariante que a camada anterior promete garantir é uma assimetria: se a coleta gated algum dia regredisse (bug, recoleta parcial, reordenação de fases), o filtro produziria vereditos, Competition e Signals sobre um footprint incompleto **sem sinal**, e o número chegaria ao relatório com rastreabilidade rompida. O custo de fechar essa fresta é nulo para entradas completas (provado abaixo) e o benefício é uma defesa em profundidade barata sobre a métrica-produto.

### Decisão

**1. A coleta gated continua sendo a dona do enforcement de DC2-01.** Ela permanece responsável por **garantir** a completude "todo canal referenciado tem `raw_youtube_channels`" e por **prová-la** pelo §7 de cada closeout de coleta. Nada no DEC-0019 §2 quanto a ownership de ingestão é revogado.

**2. O Channel Filter passa a REAFIRMAR a mesma pré-condição como última linha de defesa.** Em `channel_filter.evaluate_run`, no boundary de entrada, todo `channel_id` presente no footprint de vídeos **deve** possuir um `ChannelRecord` correspondente. Na ausência de qualquer registro exigido, o filtro levanta `ContractViolation` **antes** de produzir qualquer veredito, Competition ou Signals. Um `ChannelRecord` com `title=None` **conta como presente** ("sem sinal" ≠ "sem registro").

**3. A tolerância do filtro deixa de ser by-design.** O comportamento tolerante descrito no DEC-0019 §2 (e o teste que o congelava) é **removido e invertido**: o caminho antes silencioso agora é uma violação de contrato explícita e testada (footprint incompleto total e parcial), com cobertura adicional do caminho completo GREEN.

**4. Preservação do histórico.** O DEC-0019 **não é reescrito**. Seu texto — incluindo a classificação original da tolerância como by-design e do hardening como P2 — permanece intacto como registro do que era verdade em 2026-07-02. Esta entrada é a emenda que supersede aquele ponto específico; a hierarquia decisória lê DEC-0019 §2 **através** do DEC-0022.

### Alternativas consideradas

- **Manter a tolerância by-design (status quo DEC-0019 §2)** — rejeitada: mantém a assimetria fail-open na última zona determinística sobre a métrica-produto; a defesa em profundidade custa ~0.
- **Novo `channel-filter-v2` com bump de `rule_version`** — rejeitada e **incorreta**: um bump de versão só se justifica quando muda **o que o filtro decide** (constante, gate, ordem, normalizador, allow-list). Aqui nada disso muda — muda apenas a **pré-condição de entrada** exigida. Bump de versão invalidaria `rule_hash` e golden digest sem nenhuma mudança de veredito, poluindo a proveniência.
- **Reescrever o DEC-0019** — rejeitada: viola o princípio "decisões são histórico; nada de reescrita retrospectiva".

### Justificativa

Endurecer uma pré-condição de contrato **não é** alterar um gate. Os dois gates ativos (`self_channel`, `run_domination`), sua ordem, as constantes (`MAX_RUN_VIDEOS_PER_CHANNEL = 60`), o normalizador e a allow-list de `reason_code` permanecem **bit-a-bit idênticos** — logo `rule_version` = `channel-filter-v1` e `rule_hash` inalterados. Para toda entrada **completa** (o único caso que a coleta gated pode produzir), a saída é **byte-idêntica**: um registro com `title=None` chama exatamente o mesmo `normalize_for_match(None)` que a ausência de registro chamava antes, então nenhum veredito, contagem, ranking ou rótulo muda. Alinha o filtro ao non-negotiable de **rastreabilidade total** (nenhum número público sem rastro até `raw_youtube_videos`/`raw_youtube_channels`) e à postura fail-closed do resto do pipeline.

### Impacto

- **Escopo:** inalterado. Continua Hotspot Report, vertical única, dois relatórios fixos.
- **Non-negotiables:** reforça rastreabilidade e reprodutibilidade; nenhum tocado negativamente. Score/Velocity/Signals/Competition seguem determinísticos e versionados.
- **Versões / hashes (antes → depois, provado no PR):**
  - `rule_version`: `channel-filter-v1` → `channel-filter-v1` (inalterado)
  - `rule_hash`: `7a1e3c76c4bd6b666939f0b1c84e257ea77e9d05c26dcfd2164e2f74cedeaea7` → idem (inalterado)
  - golden digest (P5-REPRO-01): `c8e33fe85034e2c406bb189249ff829d8928a5b085d192c73220afcb89674ca8` → idem (inalterado)
  - `rubric_version` / `opportunity_version`: inalterados
- **Código:** `services/data-engine/src/noxund_data_engine/channel_filter.py` (boundary fail-closed + docstrings). `pipeline.py` **não** muda (já repassa `channels` do snapshot).
- **Testes:** `test_channel_filter.py` — teste tolerante invertido para `ContractViolation` (total + parcial) + 1 teste do caminho GREEN completo; fixtures que dependiam indevidamente da tolerância recebem `ChannelRecord` title-less. `test_repro_harness.py` — fixtures completadas com `ChannelRow` title-less (golden digest inalterado).
- **CI (count guard):** `data-engine-tests.yml` 171 → 172 (channel-filter 18 → 19). Repro-harness segue 21. Mudança de count = revisão DevOps.
- **Documentos a atualizar:** este registro; follow-up de spec-refresh `DATA-CHANNEL-001` (self_channel + pré-condição fail-closed explícitos) segue como item design-only já listado no DEC-0019.
- **Tarefas afetadas:** encerra o item aberto "DC2-01 hardening (P2)" do `DATA-AUDIT-001` no lado do filtro.

### Reversibilidade

Alta. Nada aplicado a schema, banco, secrets, Environment ou GCP; nenhuma coleta real; nenhuma constante/gate/versão alterada. Reverter = remover a assertion de boundary e restaurar o teste tolerante; a coleta gated permanece como enforcement primário (o estado DEC-0019 §2). Como não houve bump de versão, a reversão também não mexe em `rule_hash`/golden digest.

### Revisões necessárias

- [x] Product Lead (autorizou preparação/commit/PR)
- [ ] Data/AI Pipeline (obrigatória)
- [ ] QA (obrigatória)
- [ ] DevOps (count guard 171 → 172)
- [ ] Security — n/a (read-only; sem secret/Environment/DB/rede)

### Follow-up

- Merge e execução downstream **não autorizados** por esta decisão — dependem de aprovação explícita separada.
- Spec-refresh `DATA-CHANNEL-001`: tornar explícita a pré-condição fail-closed (design-only, herdado do DEC-0019).
- Sem impacto no relógio de pausa RO-1 (DEC-0021) — nenhuma atividade de banco.
