# DATA-AI-0001 — Data/AI Review · Proposta de Modelo de Dados do MVP

- **Revisor:** Data/AI Pipeline Agent (bloqueio por risco metodológico — matriz #4/#5)
- **Data:** 2026-06-20
- **Alvo:** `docs/database/` (`README.md`, `mvp-data-model.md`, `entity-relationship-notes.md`, `migration-plan.md`, `rls-review-notes.md`) + `DEC-0003` + `SEC-0001`
- **Natureza do alvo:** proposta documental, sem migration, sem schema Supabase e sem pipeline executado.

---

## 0. Veredito

**Aprovado por Data/AI para o modelo conceitual. Sem veto metodológico.**

Data/AI **ratifica `report_runs` unificado no MVP**. Não há workflow real de re-scoring dentro do MVP que exija `collection_runs` + `scoring_runs` agora, desde que a proveniência por célula seja ancorada em `artist_metrics` por `run_id` + `artist_id` + `rubric_hash`, e `report_items.artist_metric_id` aponte para a linha exata usada no snapshot publicado.

**Não abrir nova DEC para OD-DB-01.** O split continua apenas como evolução futura se um fluxo real de múltiplas tentativas/scorings simultâneos exigir isso.

---

## 1. Vereditos por OD

| OD | Veredito Data/AI | Motivo |
|---|---|---|
| **OD-DB-01** | ✅ **Ratificar `report_runs` unificado no MVP.** | O raw é imutável e fechado por `run_id`; o computed carrega `rubric_version`/`rubric_hash`; re-score do mesmo `run_id` sob novo `rubric_hash` recompõe `artist_metrics` sem recoletar e sem split. Chave lógica de `artist_metrics`: `(run_id, artist_id, rubric_hash)`. |
| **OD-DB-04** | ✅ **Manter `video_artist_mappings` como mapping canônico, não log de eventos.** | O pipeline precisa de uma resolução final por vídeo para joins, Signals e métricas. `method`, `needs_review`, `human_override` e `audit_events` cobrem auditoria. Histórico de tentativas pode virar `resolution_attempts` fora do MVP, se houver necessidade real. |
| **OD-DB-06** | ✅ **Ratificar `report_items.artist_metric_id`.** | É o ponteiro de proveniência que congela qual métrica justificou cada célula pública. Também reforça SEC-F03: produtor lê snapshot público; detalhe interno fica em `artist_metrics`. FK deve ser `ON DELETE RESTRICT`. |
| **OD-DB-07** | ✅ **Ratificar `artist_metrics.metrics_detail_json`.** | Necessário para auditoria por célula: vídeos aceitos/rejeitados e motivos, canais elegíveis, inputs dos componentes, top-N usado em velocity/Example e desempates. Campo interno, nunca exposto cru ao produtor. |

---

## 2. Workflow aprovado de re-scoring sem split

1. Selecionar o `run_id` existente e seu raw imutável em `raw_youtube_search_pages`, `raw_youtube_videos` e `raw_youtube_channels`.
2. Registrar nova linha em `rubric_versions` com novo `rubric_hash`.
3. Reprocessar deterministicamente `video_artist_mappings`, `channel_eligibility` e `artist_metrics` para o mesmo `run_id`, gravando o novo `rubric_hash`.
4. Em `artist_metrics`, gravar uma linha por `(run_id, artist_id, rubric_hash)` com `computed_from_video_ids` e `metrics_detail_json`.
5. Rebuildar o draft de `report_items` apontando `artist_metric_id` para a linha exata de `artist_metrics`.
6. Comparar o rebuild com o snapshot congelado quando o objetivo for teste de reprodutibilidade; se diferir sob o mesmo `run_id` + `rubric_hash`, é bug metodológico.

Linhas de `artist_metrics` já referenciadas por `report_items` publicados não devem ser apagadas; a FK `ON DELETE RESTRICT` preserva o rastro do snapshot.

---

## 3. Cadeia de auditoria aprovada

**Nenhum número público fica sem rastro até `raw_youtube_videos`.**

Para `score_display`, `tag`, `signals`, `velocity_display`, `competition_level` e `competition_channel_count`, a cadeia obrigatória é:

```txt
report_items.<numero_publico>
  └─ report_items.artist_metric_id
       └─ artist_metrics (rubric_hash, computed_from_video_ids, metrics_detail_json)
            └─ raw_youtube_videos (run_id, video_id)
```

Competition usa **canais distintos elegíveis**: `raw_youtube_videos.channel_id` + `channel_eligibility(run_id, channel_id)`.
Signals usa **vídeos válidos**: `computed_from_video_ids`.
Essas duas contagens não podem ser duplicadas nem inferidas uma da outra.

---

## 4. Separação raw/computed/snapshot

- **RAW:** `raw_youtube_*` é insert-only, protegido por trigger obrigatório (SEC-D03), e nunca contém dado derivado.
- **COMPUTED:** `video_artist_mappings`, `channel_eligibility`, `artist_metrics` são reconstruíveis por `run_id` + `rubric_hash`/`rule_version`.
- **SNAPSHOT:** `report_items` congela os valores publicados e aponta para a métrica usada via `artist_metric_id`.
- **PUBLIC VIEW:** produtor só vê campos públicos/sanitizados; `score_value`, `raw_score`, `selection_reason_json` cru e `metrics_detail_json` ficam admin/server-only, conforme SEC-F03.

Data/AI confirma que a separação está fechada e sem vazamento metodológico no desenho documental.

---

## 5. Handoff

**Resultado:** critério de aceite atendido para Data/AI. OD-DB-01/04/06/07 fechados por este review; sem contraproposta e sem nova DEC.

**Validação executada:** revisão documental na ordem do handoff §4; verificação da cadeia raw → computed → snapshot, do workflow de re-scoring e da regra Competition/Signals.

**Riscos restantes:** não há veto Data/AI. Mantêm-se fora deste review o veto de Security sobre Fase 9/endpoints/pré-prod (`SEC-0001`) e a revisão Backend sobre formato consumível/escrita atômica.

**Próximo passo:** Database pode usar estes vereditos na primeira migration aplicável. Backend ainda precisa revisar consumo de `report_items.artist_metric_id`, VIEW pública e escrita de eventos/payloads.
