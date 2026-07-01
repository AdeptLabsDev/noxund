# Handoff — task_define_channel_filter · Channel Filter (elegibilidade + canais distintos)

## 1. Identificação

- **Tarefa:** `task_define_channel_filter` (delegada via `delegate_task: define_channel_filter`, prioridade high)
- **Owner agent:** Data/AI Pipeline (`data_agent`)
- **Ação:** `define_channel_filter` *(ver OPEN-DATA-CHANNEL-04 — ação ainda não está na allow-list publicada)*
- **Data:** 2026-06-30
- **Prioridade:** P0 / high
- **Resultado do agente:** `completed` (DESIGN-only) — com OPEN QUESTIONS registradas para antes de qualquer execução live
- **Decisão de origem:** DEC-0013 (pipeline-first)

## 2. Objetivo

Formalizar, sem executar, a metodologia **determinística e versionada** do Agente 4 (Channel Filter): decidir elegibilidade de canal (com motivo + `rule_version`), contar canais distintos por artista (Competition) e selecionar vídeos válidos (Signals) **sem duplicar** os dois conceitos, tudo rastreável até `raw_youtube_videos`/`raw_youtube_channels`. Nenhum dado real, número, secret, migration ou IA faz parte desta ação.

## 3. Critério de aceite (do backlog)

`docs/product/mvp-backlog.md` — `[DATA] Channel Filter Agent`:
> **Objetivo:** elegibilidade + canais distintos.
> **Descrição:** heurística numérica de spam/histórico; grava `channel_eligibility` + contagem distinta por artista.
> **Critério de aceite:** elegibilidade com motivo + `rule_version`; canais distintos alimentam Competition, vídeos válidos alimentam Signals (sem duplicar).
> **Risco:** Competition duplicar Signals.

## 4. Resultado

- [x] Critério de aceite atendido **no nível de design** (a execução live depende de OPEN-DATA-CHANNEL-01/02).
- [x] Demonstrável (como verificar): ler `docs/data/DATA-CHANNEL-001-channel-filter-spec.md` §§4–7; confrontar o shape com `channel_eligibility` aplicado (migration Fase 5, L228–245) e o validador `artist_metrics_detail_complete` (L108–161). Nenhum comando/coleta/migration foi executado.

| Critério | Veredito |
|---|---|
| heurística numérica de spam/histórico | ✅ regra `channel-filter-v1` com 4 gates ordenados (`self_channel`, `insufficient_history`, `spam_burst`, `low_channel_signal`) — §5.2 |
| grava `channel_eligibility` | ✅ shape aplicado ratificado + contrato de escrita (§4); **nenhum** ALTER/apply proposto |
| elegibilidade com **motivo** (machine-readable enum + humano) | ✅ allow-list fechada de `reason_code` (§5.3); coluna `reason` usada como valor codificado; frase humana derivada de `(reason_code, rule_version)` |
| **`rule_version`** que produziu a elegibilidade | ✅ `channel-filter-v1` em `channel_eligibility.rule_version` (NOT NULL live) + `rule_hash` congelado na evidência (§5.5) |
| canais distintos alimentam **Competition**, vídeos válidos alimentam **Signals**, **sem duplicar** | ✅ contrato de dedup formal (§6): conjunto único `ValidVideos`, contagem por `channel_id` × por `video_id`, remoção atômica, aterrissagem em `metrics_detail_json` (F5-06A) |
| rastreabilidade até o raw / nenhum número gerado por IA | ✅ FK composta `(run_id, channel_id) → raw_youtube_channels`; zero IA; zero número de modelo |

Não é honesto marcar tudo como pronto para LIVE: a coleta de canal (`raw_youtube_channels`) e as constantes de threshold dependem de decisão (OPEN QUESTIONS §11). O **design** está completo.

## 5. Arquivos alterados

- `docs/data/DATA-CHANNEL-001-channel-filter-spec.md` — **criado**: spec de design do Channel Filter (regra versionada, taxonomia de motivo, contrato de dedup, replay, OPEN QUESTIONS, escopo negativo).
- `docs/data/HANDOFF-task_dataengine_define_channel_filter.md` — **criado**: este handoff de governança.

Nenhum arquivo de schema, migration, serviço, workflow ou configuração foi alterado. Nenhuma migration foi aplicada; nenhuma conexão de banco foi aberta.

## 6. Impacto no escopo

- **Mantém o MVP travado?** Sim. Channel Filter permanece **CODE determinístico**; IA continua exclusiva da Entity Resolution.
- **Toca algum non-negotiable?** Apenas para **preservá-los**: zona determinística (zero número por IA), raw imutável, computed reconstruível/versionado, default-deny, `0007` parked, Fase 9 vetada, keyword/janela/volume intactos. Todos mantidos como gates.
- **Toca número/banco/auth/copy pública?** Não gera número, não muda schema/auth/copy. Define **consumo/escrita** sobre a tabela `channel_eligibility` já aplicada e sobre o raw vivo → por isso aciona **Data/AI** (elegibilidade afeta Competition) e levanta um **gap de coleta** (Security/DevOps no futuro, via Channel Data). Nenhuma alteração de keyword/janela/volume/fonte.

## 7. Validação executada

- Conferência com `03_Data_AI_Agents_Methodology.md` §6 (critérios de elegibilidade), §8 (Competition por canais distintos), §10 (auditoria por célula), §16 (revisão humana) — preservados.
- Conferência com o shape **aplicado** de `channel_eligibility` (Fase 5, L228–245): colunas, FK composta `ON DELETE RESTRICT`, unique `(run_id, channel_id)`, `rule_version NOT NULL`, RLS-on + revoke, **zero trigger** — usados sem propor migration.
- Conferência com o validador `artist_metrics_detail_complete` (Fase 5, L108–161): `videos.accepted/rejected`, `competition.eligible_channel_ids/count`, `versions.rule_version`, `overrides[].channel_id` — confirmam que o contrato de dedup e os overrides de canal aterrissam no shape **já exigido** pelo CHECK.
- Conferência com `DATA-ENTITY-001` (§§6.2, 8, 13): só mappings `needs_review=false` entram; overrides congelam em `metrics_detail_json.overrides[]`; sequência pipeline-first (Channel Filter consome mappings finais, alimenta Competition/Signals sem duplicar).
- Conferência com `DATA-COLLECT-001` (§11): `channels.list` está **fora** daquela coleta → gap registrado como OPEN-DATA-CHANNEL-01.
- Conferência com `DEC-0012` (apply Fase 5 consumado), `DEC-0013` (pipeline-first), `scope-guardrails` (Data/AI Review para mudança de Competition/Signals).

Não foram executados: regra sobre dados reais, coleta, queries de banco, migration, testes de engine ou P5-REPRO-01 — esta ação produz somente o contrato de design.

## 8. Riscos

- **Gap de coleta (alto):** sem `raw_youtube_channels` populado, o Channel Filter **não roda live** (FK) e os gates de `upload_count`/`subscriber_count` ficam inavaliáveis. Mitigação: OPEN-DATA-CHANNEL-01 (contrato de Channel Data gated) — não bloqueia o design de Scoring.
- **Thresholds não ratificados (médio):** valores de `channel-filter-v1` são propostos; congelar errado distorce Competition. Mitigação: OPEN-DATA-CHANNEL-02 (sign-off Product Orchestrator + Data/AI).
- **Dupla contagem Competition×Signals (mitigado):** contrato de dedup do §6 (fonte única `ValidVideos`, grãos ortogonais, remoção atômica, asserção de coerência em P5) elimina o risco do backlog.
- **NULL como zero (mitigado):** gates 2/4 não disparam em `NULL`; estatística ausente nunca vira zero fabricado.
- **Override humano fora de auditoria (mitigado):** override só via `reviewed_by_human` + `audit_events` append-only + congelamento em `overrides[]`; humano nunca edita número.

## 9. Revisões necessárias

- [x] **Data/AI Review** — metodologia determinística, taxonomia de motivo e contrato de dedup definidos pelo owner; nenhum número gerado.
- [ ] **Product Orchestrator** — ratificar OPEN-DATA-CHANNEL-02 (thresholds) e OPEN-DATA-CHANNEL-04 (nome da ação); decidir sequência da coleta de canal (OPEN-DATA-CHANNEL-01).
- [ ] **Database/Data Integrity** — OPEN-DATA-CHANNEL-03 (`reason` text codificado vs enum aditivo) e OPEN-DATA-CHANNEL-05 (`rule_hash`); confirmar que **nenhum** delta de schema é necessário para `channel-filter-v1`.
- [ ] **Security + DevOps** — somente **se/quando** OPEN-DATA-CHANNEL-01 (Channel Data, `channels.list`) avançar: SEC-F23/body-only/log hygiene + secret injection, como em Search/Video Data.
- [ ] **QA / P5-REPRO-01** — após implementação: duas rodadas, elegibilidade/Signals/Competition byte-idênticos, zero não-determinismo.

> **Nota de governança (espelha `entity-db-apply`):** o **APPLY futuro** ligado a este nó (coleta de canal, ou eventual enum de `reason`) exige **pipeline gated + aprovação humana + revisões Security/Database/Data-AI**. **Este estágio de design NÃO o exige e NÃO o faz** — a tabela `channel_eligibility` já está aplicada (DEC-0012) e nenhuma migration nova é proposta. Silêncio de revisor não equivale a aprovação.

## 10. Próximos passos

1. Product Orchestrator revisar/aceitar este handoff e decidir as OPEN QUESTIONS §11.
2. Em paralelo (DEC-0013, pipeline-first), seguir para o **design de Popularity Scoring** (`data_agent: define_scoring_methodology`) — não bloqueado pelo gap de coleta de canal.
3. Quando OPEN-DATA-CHANNEL-01 avançar: especificar o contrato de Channel Data (`channels.list`) e seus gates Security/DevOps **antes** de qualquer Channel Filter live.
4. Implementar a regra `channel-filter-v1` no `services/data-engine` (com fixtures), depois ligar Channel Filter → Scoring → Opportunity → **P5-REPRO-01** (bloqueante antes do 1º publish).

## 11. Open decisions / bloqueios

- **OPEN-DATA-CHANNEL-01** *(bloqueante p/ LIVE, não p/ design)*: `raw_youtube_channels` não é populado por `DATA-COLLECT-001`; FK obrigatória impede vereditos e gates 2/4 ficam inavaliáveis → precisa de contrato de **Channel Data** (`channels.list`) gated.
- **OPEN-DATA-CHANNEL-02**: valores das constantes de threshold de `channel-filter-v1` (mudam Competition → Data/AI Review).
- **OPEN-DATA-CHANNEL-03**: representação de `reason` (`text` codificado vs enum aditivo futuro) — Database.
- **OPEN-DATA-CHANNEL-04** *(menor)*: ação `define_channel_filter` ausente da allow-list publicada do `data_agent` — Orchestrator ratificar.
- **OPEN-DATA-CHANNEL-05**: persistência de `rule_hash` (em `metrics_detail_json.versions` vs coluna futura) — Database/Data-AI.

---

```json
{
  "task_id": "task_define_channel_filter",
  "agent": "data_agent",
  "status": "completed",
  "summary": "Channel Filter (channel-filter-v1) definido em DESIGN-only: regra determinística e versionada de elegibilidade (4 gates: self_channel/insufficient_history/spam_burst/low_channel_signal) com reason_code de allow-list fechada + rule_version; contrato de dedup formal (conjunto único ValidVideos -> Signals por video_id, Competition por channel_id distinto, remoção atomica, aterrissagem em metrics_detail_json/F5-06A). channel_eligibility ja esta aplicado (DEC-0012); nenhum apply/migration/codigo/coleta/IA/numero foi executado. OPEN-DATA-CHANNEL-01 (raw_youtube_channels nao coletado) bloqueia LIVE, nao o design.",
  "artifacts": [
    { "type": "spec", "path": "docs/data/DATA-CHANNEL-001-channel-filter-spec.md", "description": "Criado: spec de design do Channel Filter (regra versionada, taxonomia de motivo, contrato de dedup Competition/Signals, replay, OPEN QUESTIONS, escopo negativo)." },
    { "type": "handoff", "path": "docs/data/HANDOFF-task_dataengine_define_channel_filter.md", "description": "Criado: handoff de governança desta tarefa (design-only, nada executado)." }
  ],
  "errors": [],
  "next_recommendation": {
    "target_agent": "data_agent",
    "action": "define_scoring_methodology",
    "priority": "high",
    "reason": "Channel Filter definido; o proximo no da cadeia pipeline-first (DEC-0013) e o design determinístico do Popularity Scoring (rubric 40/25/20/15) consumindo elegibilidade + Signals/Competition sem duplicar, rumo a P5-REPRO-01."
  }
}
```
