# Handoff — task_define_popularity_scoring · Popularity Scoring (Score determinístico)

## 1. Identificação

- **Tarefa:** `task_define_popularity_scoring` (delegada via `delegate_task: define_scoring_methodology`, prioridade high)
- **Owner agent:** Data/AI Pipeline (`data_agent`)
- **Ação:** `define_scoring_methodology` *(consta na allow-list publicada do `data_agent`)*
- **Data:** 2026-06-30
- **Prioridade:** P0 / high
- **Resultado do agente:** `completed` (DESIGN-only) — com OPEN QUESTIONS registradas para antes de qualquer compute-live
- **Decisão de origem:** DEC-0013 (pipeline-first); cadeia DATA-COLLECT-001 → DATA-ENTITY-001 → DATA-CHANNEL-001 → **DATA-SCORING-001**

## 2. Objetivo

Formalizar, sem executar, a metodologia **determinística, versionada e reproduzível** do Agente 5 (Popularity Scoring): transformar `ValidVideos`/Signals/Competition (de `DATA-CHANNEL-001`) + estatísticas brutas de vídeo no **Score `X/100` por artista por run**, gravado em `artist_metrics`, com `rubric_version` + `rubric_hash` em toda computação e rastreabilidade até `raw_youtube_videos`. Nenhum dado real, número, secret, migration ou IA faz parte desta ação.

## 3. Critério de aceite (do backlog)

`docs/product/mvp-backlog.md` — `[DATA] Popularity Scoring Agent (determinístico)`:
> **Objetivo:** calcular Score e componentes por código.
> **Descrição:** rubric 40/25/20/15; normalização sobre a amostra; grava componentes + `rubric_hash` + `computed_from_video_ids`.
> **Critério de aceite:** mesmo input ⇒ mesmo output; Score nunca editável à mão.
> **Risco:** Score arbitrário/irreprodutível.

## 4. Resultado

- [x] Critério de aceite atendido **no nível de design** (o compute-live depende de OPEN-DATA-SCORING-01/02 + OPEN-DATA-CHANNEL-01).
- [x] Demonstrável (como verificar): ler `docs/data/DATA-SCORING-001-popularity-scoring-spec.md` §§5–8; confrontar o shape com `artist_metrics` aplicado (migration Fase 5, L259–294), a FK `(rubric_version, rubric_hash) → rubric_versions` (L274–276) e o validador `artist_metrics_detail_complete` (L108–161). Nenhum comando/coleta/migration/cálculo foi executado.

| Critério | Veredito |
|---|---|
| rubric **40/25/20/15** (Velocity/Signals/Engajamento/Diversidade) | ✅ persistido verbatim do §7 (`score_rubric_2026_06_v1`); pesos **travados, não redecididos** — §5.3–5.6 |
| normalização **sobre a amostra** | ✅ sample-relative sobre os artistas pontuados da run, valores de referência congelados em `metrics_detail_json.normalization` — §5.7 (curva exata = OPEN-DATA-SCORING-02) |
| grava **componentes** | ✅ `signals`, `velocity_median_per_day`, `engagement_score`, `channel_diversity_count/score`, `raw_score`, `final_score` mapeados ao shape aplicado — §4 |
| grava **`rubric_hash`** (+ `rubric_version`) | ✅ par em `artist_metrics` (FK composta → `rubric_versions`) **e** em `metrics_detail_json.versions` (F5-06A); `rubric_hash = sha256(canonical_json(config))` computado em código — §5.1 |
| `computed_from_video_ids` (proveniência) | ✅ realizado como `artist_metric_videos` (FK composta → raw, F5-04) + `videos.accepted[]` no JSON — §3.4/§7 |
| **mesmo input ⇒ mesmo output** | ✅ função pura (sem rede/LLM/relógio; tempo = `window_end`), aritmética decimal exata, arredondamento congelado, referência da run congelada → P5-REPRO-01 — §6 |
| **Score nunca editável à mão** | ✅ Score só por código; override humano só upstream, congelado em `overrides[]` (F5-06A); guard F5-03 torna métrica publicada inviolável — §6 |
| Velocity = **mediana** de views/dia | ✅ mediana determinística com desempate estável (`vel`, `video_id`); razão: PRD §5.5 — §5.3 |

Não é honesto marcar tudo como pronto para compute-live: as **constantes/curvas de normalização** (que governam um número público) e a **coleta de canal** (herdada de OPEN-DATA-CHANNEL-01) dependem de decisão (§11). O **design** está completo.

## 5. Arquivos alterados

- `docs/data/DATA-SCORING-001-popularity-scoring-spec.md` — **criado**: spec de design do Popularity Scoring (rubric versionado, fórmula determinística dos 4 componentes, normalização sample-relative, determinismo/replay, fronteira Scoring↔Opportunity, OPEN QUESTIONS, escopo negativo).
- `docs/data/HANDOFF-task_dataengine_define_popularity_scoring.md` — **criado**: este handoff de governança.

Nenhum arquivo de schema, migration, serviço, workflow ou configuração foi alterado. Nenhuma migration foi aplicada; nenhuma conexão de banco foi aberta; nenhum número foi computado.

## 6. Impacto no escopo

- **Mantém o MVP travado?** Sim. Scoring permanece **CODE determinístico**; IA continua exclusiva do Entity Resolution. Pesos 40/25/20/15 preservados sem redecidir.
- **Toca algum non-negotiable?** Apenas para **preservá-los**: zero número por IA, raw imutável, computed reconstruível/versionado, `rubric_version`+`rubric_hash` em toda computação, default-deny, `0007` parked, Fase 9 vetada, keyword/janela/volume intactos. Todos mantidos como gates.
- **Toca número/banco/auth/copy pública?** **Não computa número**, não muda schema/auth/copy. Define a **metodologia** que produz o **Score público** (`X/100`) e o **contrato de escrita** sobre `artist_metrics`/`rubric_versions` já aplicados → por isso aciona **Data/AI + Product Lead** (rubric governa número público). Nenhuma alteração de keyword/janela/volume/fonte/pesos.

## 7. Validação executada

- Conferência com `03_Data_AI_Agents_Methodology.md` §1 (IA nunca produz número), §7 (componentes + pesos 40/25/20/15 — persistidos verbatim), §8 (HOT>90 / Score exibido>83 são do Opportunity), §10 (auditoria por célula de Score/Velocity/Signals/Competition), §11–12 (raw/computed + reprodutibilidade), §13–15 (sem data lake/exposure/ML) — todos preservados.
- Conferência com `01_MVP_Scope_PRD.md` §5.3 (Score X/100, só >83), §5.5 (Velocity = mediana de views/dia — razão da mediana) — refletidos.
- Conferência com o shape **aplicado** de `artist_metrics` (Fase 5, L259–294): colunas dos 4 componentes + `raw_score`/`final_score` + `rubric_version`/`rubric_hash`, FK composta → `rubric_versions`, unique `(run_id, artist_id, rubric_hash)`, CHECK estrutural `artist_metrics_detail_complete` — usados sem propor ALTER. Confirmado: **DDL é storage-only, zero CHECK de faixa/threshold de número**.
- Conferência com `rubric_versions` (Fase 2, L35–46 + seed template L119–144): `(version, hash)` único como alvo da FK; `rubric_version='score_rubric_2026_06_v1'` e os pesos 40/25/20/15 do seed reproduzidos; `hash` determinístico computado pelo data-engine, nunca fabricado.
- Conferência com `DATA-CHANNEL-001` §6 (consome `ValidVideos`/Signals/Competition **sem redefinir**; herda a invariante de não-duplicação) e §7 (continuação da ordem de replay).
- Conferência com `DATA-COLLECT-001` §4.3 (`views`/`likes`/`comments`/`published_at` disponíveis no raw) e §2 (`window_end` como âncora temporal).
- Conferência com `scope-guardrails` (Data/AI Review para rubric/pesos/Score) e `data-ai-pipeline-agent.md` (`define_scoring_methodology` na allow-list; não-negociável de número).

Não foram executados: cálculo sobre dados reais, coleta, queries de banco, migration, testes de engine ou P5-REPRO-01 — esta ação produz somente o contrato de design.

## 8. Riscos

- **Constantes/curvas não ratificadas (alto):** as funções de normalização e suas constantes governam o **número público**; congelar errado distorce Score/HOT/exibição. Mitigação: OPEN-DATA-SCORING-01/02 (sign-off Product Lead + Data/AI) antes de `…v1` definitivo e de compute-live.
- **Coleta de canal pendente (alto, herdado):** sem `raw_youtube_channels` (OPEN-DATA-CHANNEL-01), não há `channel_eligibility` → não há `ValidVideos` → Scoring não roda live. Mitigação: OPEN-DATA-SCORING-05; **não bloqueia o design** (DEC-0013).
- **Não-determinismo numérico (mitigado):** decimal de precisão fixa + arredondamento congelado + desempates por chave estável + tempo = `window_end` → byte-idêntico; coberto por P5-REPRO-01 (bloqueante antes do 1º publish).
- **NULL como zero (mitigado):** §9.2 — estatística ausente nunca vira zero; vídeo sai do componente, auditado em `metrics_detail_json`.
- **Score arbitrário/editável (mitigado):** Score só por código; override só upstream e congelado; guard F5-03 protege linhagem publicada.
- **Fronteira Scoring↔Opportunity confusa (mitigado):** §8 isola HOT/exibição/ranking/Competition-label/Example como **OUT** (Agente 6).

## 9. Revisões necessárias

- [x] **Data/AI Review** — metodologia determinística, rubric versionado e fronteira definidos pelo owner; nenhum número gerado.
- [ ] **Product Orchestrator + Product Lead** — ratificar OPEN-DATA-SCORING-01 (constantes) e OPEN-DATA-SCORING-02/03 (curvas de normalização + arredondamento); confirmar OPEN-DATA-SCORING-04 (referência = a run, sem baseline histórico). Governam número público.
- [ ] **QA / P5-REPRO-01** — após implementação: duas rodadas sobre o mesmo `run_id` + mesmas versões, todas as células de `artist_metrics` byte-idênticas, zero não-determinismo. Bloqueante antes do 1º publish.
- [ ] **Database/Data Integrity** — confirmar que **nenhum** delta de schema é necessário para `score_rubric_2026_06_v1` (shape aplicado já suporta); coordenar com Data/AI a inserção futura de `rubric_versions` (version+hash) — append-only, gated.
- [ ] **Security** — sem impacto direto; `metrics_detail_json` permanece interno (SEC-F03), exposição pública só por VIEW na Fase 9 (fora deste escopo).

> **Nota de governança (espelha `entity-db-apply`):** o **compute-live e o INSERT de `rubric_versions`** ligados a este nó exigem **ratificação humana das constantes/curvas + Data/AI + Product Lead**, e dependem da coleta de canal (OPEN-DATA-CHANNEL-01). **Este estágio de design NÃO os exige e NÃO os faz** — `artist_metrics`/`rubric_versions` já estão aplicados (Fase 5/Fase 2) e nenhuma migration nova é proposta. Silêncio de revisor não equivale a aprovação.

## 10. Próximos passos

1. Product Orchestrator/Product Lead revisar/aceitar este handoff e decidir as OPEN QUESTIONS §11 (especialmente constantes e curvas de normalização).
2. Seguir, na cadeia pipeline-first (DEC-0013), para o **design de Opportunity** (`data_agent: define_opportunity_methodology`) — ranking, HOT(>90), Score exibido(>83), Competition Low/Med/High, Example determinístico, `selection_reason_json` — consumindo `final_score`/componentes deste nó.
3. Implementar `score_rubric_2026_06_v1` no `services/data-engine` (com fixtures, decimal exato), computar `rubric_hash`, e coordenar com Database o INSERT append-only em `rubric_versions` (version+hash).
4. Quando OPEN-DATA-CHANNEL-01 (Channel Data) avançar: ligar Channel Filter → Scoring → Opportunity → **P5-REPRO-01** (bloqueante antes do 1º publish).

## 11. Open decisions / bloqueios

- **OPEN-DATA-SCORING-01** *(bloqueante p/ compute-live)*: valores finais das constantes `{ AGE_FLOOR_DAYS, P_VEL, SIGNALS_SAT_CAP, LAMBDA_REC, P_ENG, DIVERSITY_TARGET }` — governam número público → Product Lead + Data/AI.
- **OPEN-DATA-SCORING-02** *(bloqueante p/ compute-live)*: forma exata das curvas de normalização (percentil-âncora vs min-max vs percentile-rank; ln-saturante; recência exponencial vs linear) — Data/AI propõe, Product Lead ratifica.
- **OPEN-DATA-SCORING-03**: regra de arredondamento de `final_score` (half-up vs half-even) — afeta bordas (cruza HOT/exibição) → congelar no `rubric_hash`.
- **OPEN-DATA-SCORING-04**: confirmar referência de normalização = artistas pontuados da run (sem baseline histórico/data lake no MVP) → Data/AI.
- **OPEN-DATA-SCORING-05** *(herdado, downstream de DATA-CHANNEL-001)*: `channel_eligibility` depende de `raw_youtube_channels` não coletado (OPEN-DATA-CHANNEL-01) → bloqueia compute-live, **não** o design.

---

```json
{
  "task_id": "task_define_popularity_scoring",
  "agent": "data_agent",
  "status": "completed",
  "summary": "Popularity Scoring (score_rubric_2026_06_v1) definido em DESIGN-only: rubric versionado 40/25/20/15 (Velocity mediana de views/dia normalizada sample-relative; Signals saturante; Engajamento ponderado por recencia; Diversidade de canais saturante) combinando em raw_score 0-100 -> final_score X/100 com arredondamento congelado. rubric_version + rubric_hash=sha256(canonical_json(config)) em toda artist_metrics (FK composta -> rubric_versions) e em metrics_detail_json.versions (F5-06A); proveniencia ate raw_youtube_videos via artist_metric_videos + videos.accepted. Determinismo: funcao pura, tempo = window_end (nao relogio), decimal exato, referencia da run congelada -> P5-REPRO-01. HOT(>90)/Score exibido(>83)/ranking/Competition-label/Example sao OUT (Agente 6 Opportunity). artist_metrics/rubric_versions ja aplicados (Fase 5/Fase 2); nenhum apply/migration/codigo/coleta/IA/numero executado. Signals/Competition consumidos de DATA-CHANNEL-001 sem redefinir. Pesos travados (nao redecididos). OPEN-DATA-SCORING-01/02 (constantes + curvas de normalizacao) bloqueiam compute-live, nao o design.",
  "artifacts": [
    { "type": "spec", "path": "docs/data/DATA-SCORING-001-popularity-scoring-spec.md", "description": "Criado: spec de design do Popularity Scoring (rubric versionado, formula determinística dos 4 componentes, normalizacao sample-relative, determinismo/replay, fronteira Scoring<->Opportunity, OPEN QUESTIONS, escopo negativo)." },
    { "type": "handoff", "path": "docs/data/HANDOFF-task_dataengine_define_popularity_scoring.md", "description": "Criado: handoff de governanca desta tarefa (design-only, nada executado)." }
  ],
  "errors": [],
  "next_recommendation": {
    "target_agent": "data_agent",
    "action": "define_opportunity_methodology",
    "priority": "high",
    "reason": "Scoring definido; o proximo no da cadeia pipeline-first (DEC-0013) e o design determinístico do Opportunity (Agente 6): ranking, HOT se final_score>90, Score exibido se >83, Competition Low/Med/High, Example (top-3 velocity -> mais recente -> maior views) com selection_reason_json -> reports/report_items, consumindo final_score/componentes deste nó. Antes de qualquer compute-live, Product Lead + Data/AI devem ratificar OPEN-DATA-SCORING-01/02 (constantes e curvas de normalizacao, que governam o numero publico)."
  }
}
```
