# docs/database — Proposta de Modelo de Dados (MVP)

**Status:** proposta técnica. **Sem migrations. Sem schema real no Supabase. Sem código de app.**
**Owner agent:** Database Agent · **Co-owner de RLS:** Security & Privacy Agent.
**Fonte de verdade:** `context/04_Database_Event_Model.md` (modelo) + `context/03_Data_AI_Agents_Methodology.md` (métricas) + `context/02_Stack_Infra_Architecture.md` §8–§9 (raw/computed/segurança).

Esta pasta é **documentação de proposta**, não implementação. Nenhum SQL final, nenhuma policy RLS final, nenhuma conexão Supabase é criada aqui. O objetivo é fechar o modelo conceitual antes de escrever migrations.

---

## Arquivos

Os cinco primeiros arquivos são a proposta técnica lida na ordem do handoff §4; os demais registram handoffs/reviews.

| Arquivo | Função |
|---|---|
| `README.md` | Este índice. Status, princípios, mapa de nomes, status de revisão. |
| `mvp-data-model.md` | Documentação tabela a tabela (Purpose / Key fields / Relationships / Immutability / Notes / Open questions). |
| `entity-relationship-notes.md` | Diagrama ER, classes de imutabilidade e cadeias de proveniência raw→computed→snapshot. |
| `migration-plan.md` | Ordem recomendada de implementação futura (9 fases: 8 de tabelas + RLS). |
| `rls-review-notes.md` | Recomendações iniciais de RLS/segurança para o Security Agent revisar. |
| `HANDOFF-mvp-data-model.md` | Handoff da proposta do Database Agent e status das revisões cruzadas. |
| `DATA-AI-REVIEW-mvp-data-model.md` | Veredito do Data/AI sobre raw/computed, reprodutibilidade e OD-DB-01/04/06/07. |

---

## Princípios de modelagem (inegociáveis)

Herdados de `04_...` §1, `03_...` §11–§12 e `02_...` §8:

1. **Raw é imutável** — nunca recebe `UPDATE`/`DELETE`. Recoleta gera novo snapshot/run.
2. **Computed é reconstruível** — métricas/score/linhas são recalculáveis a partir do raw.
3. **Report snapshot é congelado** — não muda após publicado, mesmo com dados novos.
4. **Producer outcomes são eventos append-only** — log, nunca flags booleanas mutáveis.
5. **Score aponta para `rubric_version` + `rubric_hash`** — toda métrica é versionada.
6. **Report item aponta para os dados que o justificam** — Score, Signals, Velocity, Competition e Example são rastreáveis.
7. **Todo dado derivado é rastreável até o raw** (ou fonte equivalente) — sem número público sem rastro.
8. **Sem tabelas de marketplace/Fase 2** (`04_...` §12): `beats`, `orders`, `payouts`, `licenses`, `carts`, etc.

---

## Mapa de nomes — pedido da tarefa ↔ canônico (`04_...`)

A tarefa lista nomes-alvo. `04_Database_Event_Model.md` é a fonte de verdade e já fixa nomes usados por Backend, Data/AI e backlog. **Mantemos os nomes de `04_` como canônicos** e registramos as diferenças como decisão aberta (ver `mvp-data-model.md` → Open decisions).

| Nome pedido na tarefa | Tabela canônica (`04_...`) | Observação |
|---|---|---|
| `producer_applications` | `applications` | Mesmo conceito. |
| `producers` | `producers` | Igual. |
| `reports` | `reports` | Igual. |
| `report_items` | `report_items` | Igual. |
| `artists` | `artists` (+ `artist_aliases`) | `04_` separa nome canônico de aliases. |
| `youtube_collection_runs` | `report_runs` | OD-DB-01 fechado: unificado no MVP; split só via nova DEC futura. |
| `youtube_video_snapshots` | `raw_youtube_videos` | Mesmo conceito (snapshot bruto por `run_id`). |
| `youtube_channel_snapshots` | `raw_youtube_channels` | Mesmo conceito. |
| `artist_resolution_events` | `video_artist_mappings` | `04_` modela como mapeamento por vídeo, com `method` + `needs_review`. |
| `artist_computed_metrics` | `artist_metrics` | Igual em semântica. |
| `rubric_versions` | `rubric_versions` (+ `outcome_weight_versions`) | Igual. |
| `producer_outcomes` | `producer_events` | Mesma tabela append-only. Ver OD-DB-02. |
| `followups` | `followups` | Igual. |
| `audit_events` | **(novo)** `audit_events` | Não existe em `04_`. Aprovado em DEC-0003 (condicionado à RLS do Security). Ver OD-DB-03. |
| — | **(novo)** `admin_users` | Controle de segurança decidido pelo Security (SEC-D02): fonte de admin + `is_admin()`. Não é marketplace. |

Além das 13 da tarefa, o modelo inclui de `04_`: `raw_youtube_search_pages`, `channel_eligibility`, `wtp_responses`, `outcome_weight_versions`. **Total: 20 tabelas** (19 de modelo + `admin_users` de segurança).

---

## Cobertura dos 15 requisitos da tarefa

| # | Requisito | Tabela(s) |
|---|---|---|
| 1 | Produtores aprovados manualmente | `producers`, `applications`, `audit_events` |
| 2 | Aplicações de acesso | `applications` |
| 3 | Relatórios fixos | `reports` |
| 4 | Itens do relatório | `report_items` |
| 5 | Artistas | `artists`, `artist_aliases` |
| 6 | Vídeos usados como evidência | `raw_youtube_videos`, `report_items.example_video_id` |
| 7 | Raw snapshots da YouTube Data API | `raw_youtube_search_pages`, `raw_youtube_videos`, `raw_youtube_channels` |
| 8 | Métricas computadas | `artist_metrics`, `channel_eligibility`, `video_artist_mappings` |
| 9 | Versionamento do rubric | `rubric_versions`, `outcome_weight_versions` |
| 10 | Eventos de produtor | `producer_events` |
| 11 | Feedback útil/não útil | `producer_events` (`artist_marked_useful` / `_not_useful`) |
| 12 | Intenção "vou produzir beat" | `producer_events` (`intent_to_produce_declared`) |
| 13 | Follow-up 10–14 dias | `followups`, `producer_events` (`followup_*`) |
| 14 | WTP | `wtp_responses`, `producer_events` (`wtp_*`) |
| 15 | Auditoria/proveniência | cadeia `run_id` + `artist_metric_id` + `rubric_hash` + `computed_from_video_ids` + `metrics_detail_json` + `selection_reason_json` + `audit_events` |

---

## Status de revisão

Esta proposta **exige revisão** antes de virar migration (ver `mvp-data-model.md` → seção final):

- ✅ Product Orchestrator Agent — OD-DB-02/03/05 resolvidos, OD-DB-01 mantido unificado no MVP; zero Fase 2 verificado. Ver `docs/product/decisions/DEC-0003-mvp-data-model-review.md`.
- ⚠️ Security & Privacy Agent — **aprovação condicional; veto mantido sobre Fase 9 (RLS), migrations/endpoints de acesso e gate de pré-produção.** Decisões fechadas (OD-DB-08 → `auth_user_id` FK; role admin → `admin_users` + `is_admin()`; trigger de imutabilidade obrigatório em raw/audit) e condições em `docs/security/SEC-0001-mvp-data-model-review.md`.
- ✅ Data/AI Pipeline Agent — raw/computed, proveniência por célula e reprodutibilidade aprovadas; OD-DB-01/04/06/07 fechados em `docs/database/DATA-AI-REVIEW-mvp-data-model.md`.
- ⏳ Backend/Next API Agent — formato consumível por endpoints e eventos.

Nenhuma revisão pode ser "assumida como ok" (`agent-review-matrix.md`).
