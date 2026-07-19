## DEC-0023 — Ratificações residuais do `DATA-AUDIT-001` (OPEN-A/B/C), autorização do spec-refresh aditivo, classificação dos P2 e restrição de que o **primeiro compute real é a Round 1 do SG-8**

- **Data:** 2026-07-19
- **Status:** **Registrada — decisão de Product Lead.** Fecha o resíduo de governança do `DATA-AUDIT-001` (OPEN-A/B/C) e agenda o spec-refresh. **Não** altera código, `rule_version`/`rubric_version`/`opportunity_version`, `rule_hash`/`rubric_hash`/`opportunity_hash`, nem o golden digest. **Sem** apply, banco, secret, GCP ou compute. Autoriza apenas a unidade docs **U1**; **não** autoriza merge, U2, compute-live, entity-resolution, scoring ou SG-8.
- **Decisor:** Product Lead · registrada pelo Product Orchestrator
- **Área:** Metodologia (Scoring / Channel Filter / Opportunity) · governança de specs · sequenciamento pré-SG-8
- **Relaciona:** `DATA-AUDIT-001` (OPEN-A/B/C, P2-01/02/04/06), DEC-0017 (ratificações v1), DEC-0019 §2 (DC2-01 = coleta gated), DEC-0022 (Channel Filter reafirma DC2-01 fail-closed), DEC-0021 (RO-1), `DATA-REPRO-001` (golden digest `c8e33fe8…74ca8`), specs `DATA-CHANNEL-001` / `DATA-OPP-001` / `DATA-CONST-001` / `DATA-SCORING-001`

### Contexto

Com os dois P1 do `DATA-AUDIT-001` resolvidos (P1-02 `self_channel` ratificado em DEC-0017/DEC-0019 §1; P1-01/DC2-01 fail-closed em DEC-0019 §2 + DEC-0022), o resíduo do audit é **decisão/docs**: três OPEN questions (A/B/C) e a dívida de spec-refresh (P2-06). As OPEN-A/B tocam o que já está **congelado no `rubric_hash`** — precisam de ratificação escrita **antes** do compute-live congelar os números, mesmo que a leitura confirmada seja a do código. OPEN-C já foi resolvida na prática por duas decisões vivas e só faltava fechamento formal. Os P2 remanescentes (P2-01/02/04) são hardening/cobertura sobre comportamento já determinístico.

### Decisão

**D-A — OPEN-A ratificada.** O método de percentil autoritativo do rubric é **type-7 / interpolação linear inclusiva** (numpy `linear` / Excel `PERCENTILE.INC`), exatamente como já implementado (`scoring.py:103`, `:467-490`) e **congelado no `rubric_hash`**. Nomeia o método já vigente; **nenhuma mudança de valor, versão ou hash.**

**D-B — OPEN-B ratificada.** O conjunto de referência p90 (`V_REF`/`E_REF`) é formado **somente por artistas com valor de velocity/engajamento definido**. Um artista com sinal ausente (`NULL`) **não entra na âncora** e **nunca** é convertido em zero — mas **permanece no universo avaliado** (é pontuado; sua contribuição normalizada do componente é `0`, auditada). Confirma `scoring.py:745-751` (`_reference`) e o non-negotiable "NULL nunca vira 0". Sem mudança de valor/hash.

**D-C — OPEN-C fechada.** A propriedade do DC2-01 está resolvida: a **coleta gated garante e prova** a completude "todo canal referenciado tem `raw_youtube_channels`" (DEC-0019 §2, provada pelo §7); o **Channel Filter reafirma** a mesma pré-condição como última linha de defesa, fail-closed (DEC-0022). Nenhuma camada fica sem dono.

**D-D — Classificação dos P2.** `P2-01` (teste de input vazio no scoring), `P2-02` (`published_at > window_end` floorado a idade 1) e `P2-04` (fronteira de growth `+50%` sem teste) são **não bloqueantes estritos** para o compute do dataset atual (`f0485de6`): comportamentos já determinísticos e, no caso do dataset coletado em janela de 30d, sem entradas que os exercitem. São hardening/cobertura, **hash-neutros e digest-neutros**.

**D-E — Sequenciamento do hardening.** O hardening **U2** (guard de P2-02 + testes de P2-01/P2-04) **será executado antes do primeiro compute real**, como **unidade separada, após o merge de U1**. Não faz parte de U1.

**D-F — Autorização do spec-refresh.** Aprovado o registro desta DEC-0023 + **adendos aditivos** em `DATA-CHANNEL-001`, `DATA-OPP-001`, `DATA-CONST-001`, `DATA-SCORING-001`, **preservando integralmente o histórico** (anotar SUPERSEDED / adicionar adendo; nunca reescrever o corpo original). Cada adendo é **vinculado a uma decisão já existente** (DEC-0017 / DEC-0019 / DEC-0022 / esta DEC-0023); **nenhuma decisão nova é introduzida nos adendos.**

**Restrição futura (vinculante) — o primeiro compute real é a Round 1 canônica do SG-8/P5-REPRO-01.** Não haverá compute exploratório independente antes do SG-8. O primeiro compute sobre dados reais (`f0485de6`) **é** a **Round 1** canônica (entity-resolution 1ª passada resolution-only → Channel Filter → Scoring → Opportunity), imediatamente seguida da **Round 2** como **replay sem LLM**, provando byte-identidade (P5-REPRO-01). Qualquer execução que toque o banco permanece condicionada ao **RO-1** (DEC-0021): liveness + restore manual obrigatórios antes de qualquer ato sobre o banco.

### Alternativas consideradas

- **OPEN-A: trocar a variante de percentil** — rejeitada: forçaria novo `rubric_version` + novo golden digest sem ganho; type-7/inclusive é a leitura industry-default já congelada.
- **OPEN-B: incluir NULL como 0 na âncora** — rejeitada: violaria "NULL nunca vira 0" e distorceria a normalização (novo `rubric_hash`).
- **Reescrever o corpo das specs** — rejeitada: viola "decisões são histórico; sem reescrita retrospectiva". Adendo aditivo preserva a proposta original.
- **Compute exploratório antes do SG-8** — rejeitada: um compute "de teste" fora do gate quebraria a disciplina de reprodutibilidade e criaria números não rastreáveis a uma Round canônica.

### Justificativa

Ratificar por escrito o que já está congelado (A/B) fecha a lacuna "DEC e hash concordam" **antes** de o compute tornar os números públicos, sem tocar em nenhum valor. Fechar C elimina o único "dono ausente" do audit. Classificar os P2 como não bloqueantes mantém a etapa 100% design/docs e adia o único item de código (P2-02, zona de scoring) para uma unidade própria. A restrição SG-8-first alinha o primeiro compute ao non-negotiable de **reprodutibilidade** — nada de número que não nasça de uma Round canônica.

### Impacto

- **Escopo:** inalterado. Hotspot Report, vertical única, dois relatórios fixos.
- **Non-negotiables:** reforça rastreabilidade, reprodutibilidade e "NULL nunca vira 0".
- **Versões / hashes:** `rule_version`/`rubric_version`/`opportunity_version` inalterados; `rule_hash` `7a1e3c76…eaea7`, `rubric_hash` e golden digest `c8e33fe8…74ca8` **inalterados** (unidade docs-only).
- **Documentos (U1):** este registro + adendos aditivos nas quatro specs.
- **Código:** nenhum nesta etapa. P2-02/P2-01/P2-04 → **U2**, unidade separada pós-merge (D-E).
- **RO-1 (DEC-0021):** U1/U2 são repo-only (suíte stdlib/sintética, zero banco) → fora do gatilho. **U4 (compute) e U5 (SG-8) tocam o banco → exigem liveness + restore manual antes.**

### Reversibilidade

Alta. Docs-only; nenhum valor, versão, hash, código, schema, banco ou secret tocado. Reverter = remover o registro e os adendos; o histórico das specs permanece intacto por construção.

### Revisões necessárias

- [x] Product Lead (decidiu D-A…D-F + restrição SG-8-first)
- [ ] Data/AI Pipeline (obrigatória — metodologia)
- [ ] QA (obrigatória — conformância spec↔código↔decisão, sem drift)
- Security / DevOps / Database — n/a (docs-only; sem código, banco, secret, Environment, GCP, count guard)

### Follow-up

- **U1** (este PR): DEC-0023 + adendos. Merge **não autorizado** por esta decisão.
- **U2** (pós-merge de U1, GO separado): hardening hash-neutro (P2-02 guard + P2-01/P2-04 testes), antes do primeiro compute (D-E).
- **U4/U5** (GO próprio, sob RO-1): primeiro compute = SG-8 Round 1 + Round 2 replay sem LLM.
- **DC2-01 upstream** (abort na camada de coleta): permanece **design-only** (DEC-0019 §2), sem implementação nesta etapa.
