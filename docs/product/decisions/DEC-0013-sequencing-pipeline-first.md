## DEC-0013 — Reordenação de sprint: pipeline-first (data-engine + P5-REPRO-01 → 1º relatório → publish); Fase 6 (`producer_events`) em background

- **Data:** 2026-06-28
- **Status:** **Registrada — decisão de Product Lead.** Reprioriza o sprint; **não** altera tese, escopo travado nem non-negotiables.
- **Decisor:** Product Lead · registrada pelo Product Orchestrator
- **Área:** Sequenciamento / Prioridade de sprint / Caminho crítico de validação da tese
- **Relaciona:** DEC-0012 (apply Fase 5 completed — cadeia raw→computed→snapshot live), DATA-AI-0007 §3 (P5-REPRO-01 = gate do data-engine antes do 1º publish), `03_Data_AI_Agents_Methodology.md`, `data-ai-pipeline-agent.md` (owner `data_agent`), `mvp-backlog.md` Épico 5, `migration-plan.md` §Fase 6

### Contexto
Com Fases 1–5 aplicadas e verificadas (DEC-0008/0010/0009/0011/0012), a fundação de schema raw→computed→snapshot está **live**. O Product Lead avaliou o fork de sequenciamento e decidiu **não continuar apenas empilhando fundação de schema** se isso atrasar a validação da tese. O caminho crítico do MVP não é schema — é **medir comportamento real do produtor**, o que exige **ligar o pipeline e publicar o 1º relatório**.

### Decisão (o que se registra)
1. **Prioridade reordenada para pipeline-first.** Caminho crítico: **`data-engine` + P5-REPRO-01 → 1º relatório → publish → convite → captura de eventos**. O Épico 5 (Data Pipeline) é o foco do sprint atual.
2. **P5-REPRO-01 vira gate operacional bloqueante antes do 1º publish.** Nenhum relatório é publicado sem a prova canônica de 2 rodadas (mesmo raw + rubric + resolver/rule versions + decisões replayable ⇒ relatório idêntico byte-a-byte nas células de negócio/evidência, excluindo só UUIDs e timestamps operacionais). Divergência = bug metodológico bloqueante (DATA-AI-0007 §3; Stop Condition do `data_agent`).
3. **Fase 6 (`producer_events`) mantida em background, não-bloqueante.** Continua como **design-only** (sem apply, sem consumir banda de revisão SEC/Data/AI/Backend do caminho crítico), **parada em "design completo"** até a captura de eventos virar o próximo gargalo real — i.e., **após** um relatório publicado, quando for preciso capturar convite/abertura/clique/resposta ou outro evento de validação. O apply gated da Fase 6 só é sequenciado nesse ponto.
4. **Nenhuma mudança de escopo/tese/non-negotiable.** Keyword `chicago drill type beat`, janela 30d, ~500 vídeos/`run_id`, rubric travado, IA só em Entity Resolution, determinismo e rastreabilidade até `raw_youtube_videos` permanecem **inalterados**. Mudança em qualquer um = escalation/`OPEN DECISION`. Fase 9 (RLS Policies + VIEW pública, SEC-0001 §0) segue **vetada**.

### Impacto no backlog (`mvp-backlog.md`)
- **Promovido ao sprint atual (P0, ordem):** Épico 5 — `[DATA] Search (coleta)` → `[DATA] Video Data` → `[DATA] Entity Resolution` → `[DATA] Channel Filter` → `[DATA] Popularity Scoring` → `[DATA] Opportunity` → `[DATA] Teste de reprodutibilidade (P5-REPRO-01)`; depois publish (admin endpoint, Backend) e convite (Marketing).
- **Diferido para background:** a parte `producer_events` de `[DB] Tabelas de relatório + eventos + follow-up + WTP` (Fase 6) — design segue, apply aguarda o gargalo de captura.
- **Inalterados:** demais P0 (auth/approval gate, Report UI, follow-up, WTP) seguem como pré-requisitos do loop completo, sequenciados após o 1º relatório.

### Reversibilidade
Alta. É decisão de ordem, não de schema/dados. Pode ser reordenada a qualquer momento sem retrabalho destrutivo; a fundação já aplicada (Fases 1–5) sustenta qualquer ordem.

### Sequenciamento (próximo)
1. **`delegate_task` → `data_agent` (`define_collection_spec`)** — formalizar o contrato de coleta dos ~500 (params travados), raw append-only por `run_id`, quota e SEC-F23 (scrub de payload) sinalizado para Security quando a coleta real ligar.
2. Em sequência: `define_entity_resolution` → `define_scoring_methodology` → `compute_score_dry_run` → **`validate_reproducibility` (P5-REPRO-01, fail-closed)**.
3. **Publish** (admin endpoint — Backend/Security) só **após** P5-REPRO-01 verde.
4. **Fase 6 `producer_events`:** design em background; apply gated quando a captura virar gargalo.
