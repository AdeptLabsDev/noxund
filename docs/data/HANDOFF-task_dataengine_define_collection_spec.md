# Handoff — task_dataengine_define_collection_spec · contrato de coleta YouTube

## 1. Identificação

- **Tarefa:** `task_dataengine_define_collection_spec`
- **Owner agent:** Data/AI Pipeline (`data_agent`)
- **Ação:** `define_collection_spec`
- **Data:** 2026-06-28
- **Prioridade:** P0 / high
- **Decisão de origem:** DEC-0013 (pipeline-first)

## 2. Objetivo

Formalizar, sem executar a API, o contrato replayable e fail-closed dos Agentes 1 (Search) e 2 (Video Data) para uma única run Chicago Drill, preservando raw imutável e preparando o gate P5-REPRO-01.

## 3. Critérios de aceite recebidos

- ~500 vídeos com keyword, janela e volume travados; query e page tokens auditáveis por `run_id`.
- `raw_youtube_search_pages` e `raw_youtube_videos` append-only, payload verbatim e novo `run_id` em recoleta.
- snapshot replayable como pré-condição de P5-REPRO-01.
- quota/erro falham explicitamente, sem snapshot parcial silencioso.
- SEC-F23 (body-only e log hygiene) + key via Security sinalizados antes de live.
- handoff com modelo de `run_id`; nenhuma mudança nos parâmetros.
- revisão Product Orchestrator + Data/AI para a coleta dos 500.

## 4. Resultado

- [x] Contrato formal criado em `docs/data/DATA-COLLECT-001-youtube-collection-spec.md`.
- [x] `keyword = chicago drill type beat`, janela 30d, alvo 500 e vertical Chicago Drill preservados sem alteração.
- [x] Requests canônicas, janela UTC ancorada, cadeia de `pageToken` e seleção estável dos primeiros 500 IDs únicos definidas.
- [x] `videos.list(statistics,snippet)` particionado em lotes determinísticos de até 50.
- [x] Escrita insert-only, idempotência por chaves do schema e novo `run_id` em recoleta definidos.
- [x] Gate de completude impede uma run parcial/falha de chegar a Entity Resolution, scoring ou publish.
- [x] SEC-F23 e testes de body-only/log hygiene registrados como gate pré-live.
- [x] P5-REPRO-01 mantido como gate bloqueante antes do primeiro publish.

**Demonstrável:** conferir as seções 1–10 da spec e executar as checagens documentais do §7 deste handoff. Nenhuma coleta real foi feita e nenhum `run_id` concreto foi criado.

## 5. Arquivos alterados

- `docs/data/DATA-COLLECT-001-youtube-collection-spec.md` — criado: contrato formal de Search + Video Data.
- `docs/data/HANDOFF-task_dataengine_define_collection_spec.md` — criado: handoff de governança desta tarefa.

## 6. Impacto no escopo

- **Mantém o MVP travado:** sim.
- **Non-negotiables tocados:** raw imutável, determinismo, rastreabilidade, reprodutibilidade e secrets; todos foram preservados como gates.
- **Toca número/banco/auth/copy pública:** não gera número, não muda schema/auth/copy. Define consumo das tabelas raw live e por isso aciona Data/AI/Product Orchestrator; secret/log hygiene aciona Security/DevOps antes de live.
- **Alteração de keyword/janela/volume/fonte:** nenhuma.

## 7. Validação executada

- Conferência contra `03_Data_AI_Agents_Methodology.md` §§3–4, 11–13: Search, Video Data, raw imutável e replay preservados.
- Conferência contra `NOXUND_Hotspot_Arquitetura_de_Agentes.md` A.2: `search.list`, `videos.list` em lotes de 50 e payload bruto por vídeo preservados.
- Conferência contra o schema aplicado das Fases 3–4: nomes/colunas, chaves `(run_id, page_token)` e `(run_id, video_id)`, `fetched_at`, triggers e SEC-F08 usados sem propor migration.
- Conferência contra SEC-0012/SEC-F23: body-only e higiene de log elevados a gate pré-live.
- Conferência contra DEC-0013/DATA-AI-0007: P5-REPRO-01 segue bloqueante antes do publish.
- Busca textual pós-escrita deve confirmar todos os parâmetros travados e a ausência de credencial real.

Não foram executados testes de API, quota, integração ou P5-REPRO-01 porque esta ação produz somente o contrato.

## 8. Riscos

- O YouTube pode esgotar a fonte antes do alvo; a spec registra `source_exhausted` e exige revisão, sem mudar janela/query.
- Vídeo pode desaparecer entre Search e Video Data; a spec falha a run em vez de reduzir silenciosamente a amostra.
- Linhas raw parciais podem existir após falha; permanecem evidência imutável, mas `status = failed` e `collected_video_count = NULL` as tornam inelegíveis.
- O CHECK SEC-F08 é defesa em profundidade top-level; scrub autoritativo e redaction de logs ainda precisam ser implementados e aprovados no job.

## 9. Revisões necessárias

- [x] **Data/AI Review** — contrato produzido pelo owner, coerente com raw/replay e sem número gerado.
- [ ] **Product Orchestrator** — obrigatório para a coleta dos ~500 (parâmetros/paginação); pendente antes de live.
- [ ] **Security Review** — `audit_secrets` de SEC-F23, body-only, `YOUTUBE_API_KEY` e logs; pendente antes de live.
- [ ] **DevOps Review** — job interno/secret injection/Sentry; pendente antes de live.
- [ ] **P5-REPRO-01 (Data/AI + Backend/DevOps/QA)** — pendente; bloqueia o primeiro publish, não a aprovação desta spec.

Silêncio de revisor não equivale a aprovação.

## 10. Próximos passos

1. Product Orchestrator revisar/aceitar este handoff sem alterar os parâmetros travados.
2. Orchestrator delegar `security_agent:audit_secrets` para fechar SEC-F23 antes da coleta real e coordenar o job com DevOps.
3. Em paralelo ao gate pré-live, seguir DEC-0013: `data_agent:define_entity_resolution` → `define_scoring_methodology` → `compute_score_dry_run` → `validate_reproducibility`.
4. Só ligar a coleta após implementação testada do job e gates Product Orchestrator + Data/AI + Security/DevOps.

## 11. Open decisions / bloqueios

- **Open decisions:** nenhum; parâmetros e fonte não mudaram.
- **Bloqueios para coleta real:** Product Orchestrator review e SEC-F23/DevOps ainda pendentes.
- **Bloqueio para publish:** P5-REPRO-01 ainda pendente.
