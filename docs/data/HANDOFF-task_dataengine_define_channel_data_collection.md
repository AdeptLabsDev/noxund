# Handoff — task_define_channel_data_collection · Channel Data collection (channels.list → raw_youtube_channels)

## 1. Identificação

- **Tarefa:** `task_define_channel_data_collection` (delegada via `delegate_task: define_collection_spec`, prioridade high)
- **Owner agent:** Data/AI Pipeline (`data_agent`)
- **Ação:** `define_collection_spec` *(ação publicada na allow-list do `data_agent` — sem gap de governança)*
- **Data:** 2026-06-30
- **Prioridade:** P0 / high
- **Resultado do agente:** `completed` (DESIGN-only) — com OPEN QUESTIONS registradas para antes de qualquer execução live
- **Decisão de origem:** DEC-0013 (pipeline-first); resolve `OPEN-DATA-CHANNEL-01` (de `DATA-CHANNEL-001`)

## 2. Objetivo

Formalizar, sem executar a API, o **contrato de coleta de Channel Data** (`channels.list`) que popula `raw_youtube_channels` para os canais **já surgidos** no snapshot de ~500 vídeos de uma run — desbloqueando o Channel Filter (Agente 4), cuja FK `(run_id, channel_id) → raw_youtube_channels` hoje impede qualquer veredito e cujos gates `insufficient_history` (gate 2) e `low_channel_signal` (gate 4) são inavaliáveis sem estes campos. Nenhum dado real, número, secret, migration ou IA faz parte desta ação.

## 3. Critério de aceite (recebido do Orchestrator)

- conjunto de canais = `channel_id` **distintos** dos ~500 vídeos da run (de `raw_youtube_videos(run_id)`); 1 sub-coleta `channels.list` em lotes ≤ 50; mapear para `raw_youtube_channels (run_id, channel_id)`;
- request exata (`channels.list`, parts/fields), batching, custo de quota vs. orçamento de vídeos, **sem mudar** keyword/janela/volume;
- field mapping API → coluna honrando NULL ≠ 0 que o Channel Filter exige;
- raw append-only/imutável por `run_id`; recoleta = novo `run_id`; proveniência `(run_id, channel_id)`;
- SEC-F23 (scrub de payload, body-only) + Security/quota review + aprovação humana sinalizados antes de live;
- edge cases (canal deletado/oculto, `hiddenSubscriberCount`, contadores ausentes), stop conditions e OPEN QUESTIONS;
- escopo negativo: design-only; `0007` parked; Fase 9 vetada.

## 4. Resultado

- [x] Critério de aceite atendido **no nível de design** (execução live depende de `OPEN-DC2-01/02` + gates Security/DevOps).
- [x] Demonstrável (como verificar): ler `docs/data/DATA-COLLECT-002-channel-data-collection-spec.md` §§1–13; confrontar o field map (§4) com `raw_youtube_channels` aplicado (migration Fase 4, L124–146) e os gates 2/4 com `DATA-CHANNEL-001 §5.2`. Nenhum comando/coleta/migration/API foi executado.

| Critério | Veredito |
|---|---|
| conjunto = canais distintos dos vídeos da run; `channels.list` em lotes ≤ 50 → `raw_youtube_channels` | ✅ §2.3 (`ChannelsToCollect(run)`) + §3.2 (batching ≤ 50) |
| request exata + parts + quota, **sem mudar** keyword/janela/volume | ✅ §3.1 (`part=snippet,statistics`) + §3.4 (≤ 10 unidades/run) + §1 (invariante de não-expansão) |
| field mapping honrando NULL ≠ 0 | ✅ §4.2 (mapa coluna↔campo) + §4.3 (gates 2/4) + §9 (bordas) |
| raw append-only/imutável; recoleta = novo `run_id`; proveniência `(run_id, channel_id)` | ✅ §5 (insert-only, trigger imutável, unique key, FK natural) + §2.1 (mesma run; recoleta = nova run) |
| SEC-F23 + review humano antes de live | ✅ §8 (body-only, scrub, log hygiene, 6 testes) + §12 (gates pendentes) |
| edge cases + stop conditions + OPEN QUESTIONS | ✅ §9 (bordas) + §12 (stop conditions) + §11 (5 OPEN QUESTIONS) |
| design-only; `0007` parked; Fase 9 vetada | ✅ §13 (escopo negativo) |

Não é honesto marcar tudo pronto para LIVE: a omissão de canais deletados (`OPEN-DC2-01`), a confirmação de PII pública em `raw_json` (`OPEN-DC2-02`) e os gates Security/DevOps dependem de decisão. O **design** está completo.

## 5. Arquivos alterados

- `docs/data/DATA-COLLECT-002-channel-data-collection-spec.md` — **criado**: contrato de coleta de Channel Data (seleção determinística dos canais, request `channels.list`, batching/quota, field map → `raw_youtube_channels`, append-only/idempotência, fail-closed, gate de completude, SEC-F23, bordas, replay, OPEN QUESTIONS, escopo negativo).
- `docs/data/HANDOFF-task_dataengine_define_channel_data_collection.md` — **criado**: este handoff de governança.

Nenhum arquivo de schema, migration, serviço, workflow ou configuração foi alterado. **Nenhuma migration foi aplicada; nenhuma conexão de banco/API foi aberta.**

## 6. Impacto no escopo

- **Mantém o MVP travado?** Sim. Channel Data é **algorítmica** (cópia verbatim do body); IA continua exclusiva da Entity Resolution. Volume de vídeos (~500), keyword (`chicago drill type beat`), janela (30d) e paginação de Search permanecem **intactos** — Channel Data só adiciona metadados de canais já surfados (invariante de não-expansão, §1).
- **Toca algum non-negotiable?** Apenas para **preservá-los**: raw imutável/append-only, computed reconstruível, NULL ≠ 0, default-deny (RLS-on + revoke, zero policy/view), `0007` parked, Fase 9 vetada, secrets via Security. Todos mantidos como gates.
- **Toca número/banco/auth/copy pública?** Não gera número, não muda schema/auth/copy. Define **escrita** sobre a tabela `raw_youtube_channels` **já aplicada** (Fase 4) → por isso aciona **Data/AI** (alimenta Competition/Signals via Channel Filter) e **Security/DevOps** (nova chamada de API + secret + payload). **Zero** delta de schema proposto para a v1.

## 7. Validação executada

- Conferência com `DATA-COLLECT-001` (§§1–11): herdadas as convenções de raw append-only por `run_id`, payload verbatim/body-only, quota accounting, fail-closed e `pageToken`/batching; confirmado que §11 daquela spec põe `channels.list` fora do escopo — gap que ESTA spec fecha **sem** alterar Search/Video Data.
- Conferência com `DATA-CHANNEL-001` (§§3.1, 5.2, 8.1, 8.3): os 4 campos exigidos (`title`, `upload_count`, `subscriber_count`, `view_count`) e a semântica NULL ≠ 0 dos gates 2/4 são exatamente os preenchidos; `OPEN-DATA-CHANNEL-01` referenciado como o bloqueio resolvido.
- Conferência com o shape **aplicado** de `raw_youtube_channels` (migration Fase 4, L124–146 + triggers L165–170 + RLS/revoke L177–186): colunas, `bigint` para contadores, `raw_json NOT NULL`, CHECK SEC-F08, unique `(run_id, channel_id)` — usados **sem** propor migration. Confirmado que **não há** coluna `published_at` → idade de canal fica em `raw_json` e não é gate da v1 (`OPEN-DC2-03`).
- Conferência com `channel_eligibility` (migration Fase 5, L228–245): FK composta `(run_id, channel_id) → raw_youtube_channels ON DELETE RESTRICT` é a razão da invariante de igualdade de conjuntos (§7).
- Conferência com `NOXUND_Hotspot_Arquitetura_de_Agentes.md` A.2 (Agente 4: `channels.list (statistics)`), `03_..._Methodology.md` §§3–4/6, SEC-0012 (SEC-F23/F08), `scope-guardrails` (Data/AI Review para coleta/Competition; Security para API key/logs), DEC-0012 (apply Fase 5 consumado), DEC-0013 (pipeline-first).

Não foram executados: coleta real, chamadas `channels.list`, queries de banco, migration, testes de engine ou P5-REPRO-01 — esta ação produz somente o contrato de design.

## 8. Riscos

- **Canal deletado/suspenso omitido pela API (médio):** sem item, `raw_json NOT NULL` impede linha verbatim; default **fail-closed** (run não fica pronta; recoleta = novo `run_id`). Mitigação/decisão: `OPEN-DC2-01` (Database + Data/AI) — tombstone exigiria migration aditiva, fora desta spec.
- **PII/conteúdo público em `raw_json` (baixo):** `title/description/customUrl/thumbnails` viajam verbatim (como em `raw_youtube_videos`). Mitigação: v1 projeta só `title`; `OPEN-DC2-02` (Security confirma postura SEC-F23 sobre dado público).
- **NULL tratado como zero (mitigado):** §4.2/§9 forçam `NULL` para estatística ausente/oculta (`hiddenSubscriberCount`); `videoCount=0` real é distinguido de ausência; gates 2/4 não disparam em `NULL`.
- **Expansão de escopo via coleta (mitigado):** invariante de não-expansão (§1) + gate de igualdade de conjuntos (§7) impedem descobrir canal sem vídeo na run ou mudar volume/janela.
- **Secret/envelope em raw ou log (mitigado):** §8 body-only + scrub + CHECK SEC-F08 + 6 testes obrigatórios; gate Security/DevOps antes de live.

## 9. Revisões necessárias

- [x] **Data/AI Review** — contrato de raw de canal, determinismo, NULL ≠ 0 e mapeamento dos gates 2/4 definidos pelo owner; nenhum número gerado.
- [ ] **Product Orchestrator** — ratificar a sub-coleta na **mesma run** (`OPEN-DC2-04`) e a não-expansão do snapshot; obrigatório antes de live (coleta toca Competition/Signals).
- [ ] **Security Review** — SEC-F23/SEC-F08, `YOUTUBE_API_KEY` (server-side), body-only, log hygiene e PII pública em `raw_json` (`OPEN-DC2-02`); pendente antes de live.
- [ ] **DevOps Review** — job interno/secret injection/Sentry e encadeamento ao gate de vídeos de `DATA-COLLECT-001 §7`; pendente antes de live.
- [ ] **Database/Data Integrity** — `OPEN-DC2-01` (tombstone vs fail-closed); confirmar **zero** delta de schema necessário para a v1.
- [ ] **P5-REPRO-01 (Data/AI + Backend/DevOps/QA)** — após implementação: pré-condição do replay; bloqueia o 1º publish, não a aprovação desta spec.

> **Nota de governança (espelha `entity-db-apply`):** o **APPLY futuro** ligado a este nó (a coleta real `channels.list`, ou eventual coluna de tombstone) exige **pipeline gated + aprovação humana + revisões Security/Database/Data-AI**. **Este estágio de design NÃO o exige e NÃO o faz** — `raw_youtube_channels` já está aplicado (Fase 4) e nenhuma migration nova é proposta. **Silêncio de revisor não equivale a aprovação.**

## 10. Próximos passos

1. Product Orchestrator revisar/aceitar este handoff e decidir as OPEN QUESTIONS §11 da spec — sem alterar keyword/janela/volume.
2. Orchestrator delegar `security_agent: audit_secrets` (SEC-F23/quota) + DevOps para o job `channels.list` **antes** de qualquer coleta real, coordenado com o gate já pendente de Search/Video Data.
3. Database decidir `OPEN-DC2-01` (fail-closed recomendado, zero delta; tombstone = migration aditiva gated, se desejado).
4. Em paralelo (DEC-0013, pipeline-first), seguir para o **design de Popularity Scoring** (`data_agent: define_scoring_methodology`) — não bloqueado por esta coleta.
5. Implementar o job de Channel Data no `services/data-engine` (com fixtures), depois ligar coleta → Channel Filter (`channel-filter-v1`) → Scoring → Opportunity → **P5-REPRO-01** (bloqueante antes do 1º publish).

## 11. Open decisions / bloqueios

- **OPEN-DC2-01** *(bloqueante p/ LIVE, não p/ design)*: canal deletado/suspenso omitido por `channels.list` — fail-closed (recomendado) vs tombstone (migration aditiva). Database + Data/AI.
- **OPEN-DC2-02**: PII/conteúdo público de canal em `raw_json` sob SEC-F23 — Security confirmar postura.
- **OPEN-DC2-03**: `snippet.publishedAt` (idade do canal) sem coluna projetada; não usado por `channel-filter-v1` — não bloqueia; futuro gate = migration aditiva + nova `rule_version`.
- **OPEN-DC2-04**: sub-coleta como fase da **mesma run** (`run_id` compartilhado) pré-condicionada ao gate de vídeos — Orchestrator + DevOps ratificar.
- **OPEN-DC2-05** *(herdada — `OPEN-DATA-CHANNEL-02`)*: constantes `{ MIN_PUBLIC_UPLOADS, MIN_SUBSCRIBERS, MIN_CHANNEL_VIEWS }` consumidoras destes campos — fora do escopo desta coleta; Data/AI Review no Channel Filter.

---

```json
{
  "task_id": "task_define_channel_data_collection",
  "agent": "data_agent",
  "status": "completed",
  "summary": "Channel Data collection (DATA-COLLECT-002/v1) definida em DESIGN-only: extensao de DATA-COLLECT-001 que coleta channels.list (part=snippet,statistics) em lotes <=50 para os channel_id DISTINTOS dos ~500 videos da run (de raw_youtube_videos), mapeando para o shape ja aplicado de raw_youtube_channels SEM nenhuma migration. Field map honra NULL != 0: snippet.title->title, statistics.videoCount->upload_count, statistics.subscriberCount->subscriber_count (hiddenSubscriberCount => NULL), statistics.viewCount->view_count. Resolve OPEN-DATA-CHANNEL-01: preenche a FK (run_id,channel_id) de channel_eligibility e supre os gates 2 (insufficient_history/upload_count) e 4 (low_channel_signal/subscriber+view) do Channel Filter. Quota delta <= ~10 unidades/run (1 unidade por channels.list), keyword/janela/volume/paginacao de Search INALTERADOS. Raw append-only/imutavel, recoleta = novo run_id, proveniencia (run_id,channel_id), gate de igualdade de conjuntos canais<->videos, fail-closed, SEC-F23 body-only. Nenhum apply/migration/codigo/coleta/API/IA/numero executado. OPEN-DC2-01 (canal deletado omitido) bloqueia LIVE, nao o design.",
  "artifacts": [
    { "type": "spec", "path": "docs/data/DATA-COLLECT-002-channel-data-collection-spec.md", "description": "Criado: contrato de coleta de Channel Data (selecao determinística dos canais, request channels.list, batching/quota, field map -> raw_youtube_channels, append-only/idempotencia, fail-closed, gate de completude, SEC-F23, bordas, replay, OPEN QUESTIONS, escopo negativo)." },
    { "type": "handoff", "path": "docs/data/HANDOFF-task_dataengine_define_channel_data_collection.md", "description": "Criado: handoff de governanca desta tarefa (design-only, nada executado)." }
  ],
  "errors": [],
  "next_recommendation": {
    "target_agent": "security_agent",
    "action": "audit_secrets",
    "priority": "high",
    "reason": "Channel Data introduz uma nova chamada de API (channels.list) com YOUTUBE_API_KEY e payload publico em raw_json; antes de qualquer coleta real, Security deve fechar SEC-F23/SEC-F08 (body-only, log hygiene, OPEN-DC2-02) e quota, em conjunto com o gate ja pendente de Search/Video Data. Em paralelo (DEC-0013, pipeline-first), data_agent:define_scoring_methodology nao esta bloqueado por esta coleta."
  }
}
```
