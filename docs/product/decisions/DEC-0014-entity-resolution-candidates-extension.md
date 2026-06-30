## DEC-0014 — Resolução de OPEN-DATA-ENTITY-001: correção de escopo da Entity Resolution + extensão aditiva mínima (`entity_resolution_candidates`)

- **Data:** 2026-06-28
- **Status:** **Registrada.** Decisão de Product Lead (fila durável via extensão aditiva) + correção de engenharia do Product Orchestrator (escopo).
- **Decisor:** Product Lead (escolheu "tabela aditiva mínima") · correção de escopo pelo Product Orchestrator · registrada pelo Product Orchestrator
- **Área:** Metodologia (Entity Resolution / zona de IA) / Schema (extensão aditiva) / Reprodutibilidade / Integridade
- **Relaciona:** `DATA-ENTITY-001-entity-resolution-spec.md` + handoff (`needs_review`, OPEN-DATA-ENTITY-001), DEC-0013 (pipeline-first), DATA-AI-0007 (F5-05 `metrics_detail_json`, F5-06A overrides/versions), Fase 5 migration `20260620000005` (DDL `video_artist_mappings` L198–212), `agent-review-matrix.md`

### Contexto
Ao definir a metodologia de Entity Resolution (`define_entity_resolution`), o `data_agent` retornou `needs_review` com **OPEN-DATA-ENTITY-001**: a task pedia `confidence`, `rule_version`, evidence/override e fila durável tipada que o schema live de `video_artist_mappings` não oferece. O Orchestrator leu o DDL real e separou o que é gap genuíno do que foi má-especificação da própria task.

### Decisão (o que se registra)

**1. Correção de escopo (Product Orchestrator) — 3 dos 4 "gaps" se dissolvem:**
- **`confidence` numérico: REMOVIDO — é proibido.** Confiança numérica vinda da IA viola o non-negotiable "IA não gera número". O `data_agent` corretamente proibiu; a revisão é binária (`needs_review`).
- **`rule_version` no mapping: REMOVIDO (conflação).** `rule_version` pertence ao Channel Filter (`channel_eligibility`). O mapping já tem **`resolver_version NOT NULL`** — campo correto, usar o existente.
- **Coluna de evidence/override: NÃO criar.** Já há casa desenhada na Fase 5: **`audit_events`** (log de override humano, replayable por chave natural) + **`metrics_detail_json.overrides[]`** (fatos LLM/humanos congelados no scoring com `run_id+video_id`, F5-06A).
- **Consequência:** reprodutibilidade (P5-REPRO-01), anti-alucinação (guardrail de substring), versionamento (`resolver_version`) e replay por chave natural **já são satisfeitos pelo schema live**.

**2. Gap genuíno (Product Lead) — extensão aditiva mínima:** autorizar, via Database Agent, uma **nova tabela `entity_resolution_candidates`** (fila de candidatos pendentes da Entity Resolution). `artist_id NOT NULL` em `video_artist_mappings` impede segurar um candidato LLM **não-aprovado** sem poluir `artists`/`video_artist_mappings` com saída de IA não-revisada. A tabela de fila resolve isso mantendo a integridade das tabelas canônicas.

**3. Aditivo, não destrutivo:** a extensão **NÃO altera** `video_artist_mappings` nem qualquer tabela aplicada/congelada (princípio reafirmado pelo próprio `database_agent` na Fase 6: "não se altera tabela aplicada por conveniência"). É tabela nova, com apply **gated próprio**, precedido das revisões **Database + Security + Data/AI** (matrix).

**4. Estado da Entity Resolution:** a spec `DATA-ENTITY-001` permanece `needs_review` até o schema da fila landar; então o `data_agent` re-alinha a persistência e só depois implementa resolver/fixtures → Channel Filter → scoring → **P5-REPRO-01**.

**5. Non-negotiables intactos:** IA só em Entity Resolution e nunca para número; nome sempre substring do título; replay por chave natural sem rechamar LLM; rastreabilidade até `raw_youtube_videos`; Fase 9 (RLS Policies + VIEW) segue vetada (SEC-0001 §0).

### Impacto no caminho pipeline-first (DEC-0013)
Insere **1 migration aditiva pequena e de baixo risco** no caminho. **Não** serializa: o design da tabela + reviews rodam **em paralelo** à implementação do engine (que é o pólo longo). A reprodutibilidade não dependia dela; a tabela entrega **integridade/limpeza da fila** de revisão — coerente com o padrão world-class do produto. Não é "empilhar schema": é necessidade metodológica direta da única zona de IA.

### Sequenciamento (próximo)
1. **`delegate_task` → `database_agent` (`design_schema`)** — `entity_resolution_candidates` (aditiva; `artist_id` nullable; nome proposto; `resolver_version`/prompt version; `status` pending/approved/rejected; FK composta → raw; default-deny; zero policy/view). Design-only, não-gated.
2. **Reviews** Database + Security (RLS/PII) + Data/AI (replay/integridade) antes do apply.
3. **Apply gated próprio** (workflow dedicado, confirmação, Environment `production-db`, dispatch de `main`/SEC-F18) — human-approved.
4. **`data_agent`** re-alinha `DATA-ENTITY-001` ao schema final e retoma a implementação.
5. **Ordenação de migrations:** a `entity_resolution_candidates` deve aplicar **independente e à frente** da Fase 6 (`producer_events`, parada em design `20260620000006`, não aplicada/não commitada — renumerável sem custo).
