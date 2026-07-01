# Handoff — `task_devops_define_channel_collection_pipeline` · DevOps/Infra Agent

## 1. Identificação
- **Tarefa:** `task_devops_define_channel_collection_pipeline` · **Action:** `define_pipeline`
- **Owner agent:** DevOps / Infra (`devops_agent`)
- **Data:** 2026-07-01
- **Prioridade:** P1 (high — caminho crítico do 1º relatório)
- **Gate atendido:** **SG-3** (DEC-0018 / SEC-0019) — autora `youtube-collection.yml` gated.
- **Estado:** **DESIGN-ONLY — pipeline autorado e DESARMADO.** Zero coleta, zero API, zero secret provisionado, zero execução, zero DB write. Landar este YAML na `main` **não** coleta nada (fail-closed por construção, §4).
- **Alvo:** projeto Supabase `pwbkplzyzmortwjjpcbg` · YouTube Data API v3 (`channels.list`) · Environment (novo, a provisionar) `youtube-collection`.

## 2. Objetivo
Autorar o workflow **gated** `.github/workflows/youtube-collection.yml` para a sub-coleta de Channel Data (`channels.list → raw_youtube_channels`), espelhando o precedente `.github/workflows/entity-db-apply.yml` e **nomeando o desvio de template** que dispara a auditoria de secrets separada (F-2). Nenhuma execução; nenhum secret real; a coleta permanece atrás do checklist SG-0..SG-6 + dispatch humano.

## 3. Critério de aceite (do payload) → resultado
| Critério | Estado | Evidência (arquivo) |
|---|---|---|
| `workflow_dispatch`-only (zero `push`/`schedule`) + frase de confirmação (SG-6) | ✅ | `on: workflow_dispatch` único; input `confirm = RUN-CHANNEL-COLLECTION` validado no `guard`. |
| Environment dedicado least-privilege + required reviewers | ✅ | `environment: youtube-collection` nos jobs `collect`/`verify`; sem `SUPABASE_ACCESS_TOKEN` (não faz `db push`). |
| SEC-F18 origem `main`-only | ✅ | **Backstop no `guard`** (`github.ref == refs/heads/main`) **+** deployment branch rule do Environment (SG-4). |
| Actions SHA-pinadas (SEC-F17); `permissions: contents: read`; zero write | ✅ | `checkout@34e1148…` (v4.3.1), `setup-python@0b93645…` (v5.3.0); `permissions: contents: read`. |
| `YOUTUBE_API_KEY` só via Environment; header `X-Goog-Api-Key`; URL mascarada; ZERO valor de secret no YAML | ✅ | `secrets.YOUTUBE_API_KEY` env-only; `::add-mask::` na DB URL; comentário fixa header/never `?key=`; só **nomes** de secret. |
| Alinhado ao runbook (SG-0..SG-8) + DC2-01 fail-closed | ✅ | Job `verify` roda o gate §7 (set-equality); comentários mapeiam DC2-01 → run `failed` → novo `run_id`, sem tombstone. |
| NÃO executar; NÃO provisionar secret real | ✅ | Pipeline **desarmado** (§4); nenhum arquivo em Environment/secret criado; `configure_env` é SG-4 futura. |

## 4. Controle fail-closed que faz "landar ≠ coletar" (o mais importante)
O `guard` roda **fora** de qualquer Environment/secret e **aborta todo dispatch** até que **duas** condições, independentes e todas fail-closed, sejam verdadeiras:

1. **Marcador de arm explícito** `/.github/collection/youtube-collection.armed` **committado** — a **ausência** é o estado desarmado. É committado por DevOps **só** depois de SG-0..SG-5 verdes **e** o Environment provisionado (SG-4: required reviewers + `main`-only). Eu **não** criei este marcador nesta entrega (armá-lo seria execução).
2. **Collector + testes §8 presentes** (`services/data-engine/src/noxund_data_engine/channel_collection.py` + `tests/test_channel_collection.py`) e o **gate §7** (`supabase/tests/channel_data_post_collection_verify.sql`) — entregáveis de SG-5, hoje ausentes.

**Por que no `guard` (sem Environment):** um Environment **novo** referenciado antes do SG-4 é **auto-criado pelo GitHub SEM protection rules** (sem required reviewers, sem branch rule). Colocar o gate duro no `guard` (que não toca Environment) garante o fail-closed **independente** desse footgun. O `guard` também revalida SEC-F18 (`ref == main`) no nível do YAML, sem depender da branch rule existir.

## 5. Arquivos alterados (criados)
- `.github/workflows/youtube-collection.yml` — workflow gated (guard → collect → verify), **desarmado**.
- `docs/infra/HANDOFF-youtube-collection-pipeline.md` — este handoff.

**Intocados (constraint):** nenhum secret/Environment provisionado; `.github/collection/youtube-collection.armed` **não** criado (arm é SG-4); `services/data-engine/*` inalterado (collector é SG-5); `supabase/migrations/*` (zero ALTER); `0007`/producer_events (**PARKED**); Fase 9/RLS (**VETADA**).

## 6. Desvio de template vs. `entity-db-apply.yml` (a razão do F-2)
| Dimensão | `entity-db-apply.yml` (precedente) | **`youtube-collection.yml` (NOVO)** |
|---|---|---|
| Passo de execução | `supabase db push` (DDL idempotente) | **job de coleta** do data-engine: `channels.list` + INSERT em raw |
| Egress | só Supabase | **+ `googleapis.com`** (1º egress a API de terceiro) |
| Secrets no Environment | `SUPABASE_DB_PASSWORD` + `SUPABASE_ACCESS_TOKEN` | **`YOUTUBE_API_KEY`** (nova classe, portadora de custo) + DB conn least-privilege **sem** `ACCESS_TOKEN` |
| Environment | reusa `production-db` (já provisionado) | **novo `youtube-collection`** (não reusar — não misturar blast radius; OQ-1) |
| "Verify" | assere estrutura DDL exata | gate de completude §7 (set-equality; dado externo não-determinístico) |
| Rollback | SQL de rollback disponível | **nenhum** — raw append-only; correção = novo `run_id` |

Por isso o YAML **não** herda a liberação de SEC-0019 (SG-1); exige `audit_secrets` **próprio** (F-2 / SG-3).

## 7. Revisões necessárias
- [x] **DevOps** — esta entrega (autor do YAML gated, desarmado).
- [ ] ⏳ **Security `audit_secrets` do PIPELINE (F-2 / SG-3) — BLOQUEANTE.** Verificar: SHA-pin (SEC-F17), `contents:read`, SEC-F18 `main`-only backstop + branch rule, required reviewers DevOps+Security, service-role **não** usada (SEC-F19), URL mascarada, header `X-Goog-Api-Key` / never `?key=`, ZERO valor de secret, arm fail-closed. **Acionada** via `next_recommendation`.

## 8. Próximos passos (gate residual — nada roda até verde + dispatch humano)
1. **Security `audit_secrets` do YAML** (F-2 / SG-3) — este handoff + o `.yml`.
2. **DevOps `configure_env`** (SG-4, SENSÍVEL/humano-gated): provisiona `youtube-collection` — `YOUTUBE_API_KEY` + DB conn least-privilege (sem token de migration), `main`-only **antes** dos secrets, required reviewers, **F-1** (API-restriction YouTube Data API v3 + alerta de quota + rotação). Evidência out-of-band (precedente `INFRA-0001`). **Só então** committar o marcador de arm.
3. **Data/AI (SG-5):** collector `channel_collection.py` + testes §8.1–§8.6 + `channel_data_post_collection_verify.sql` (gate §7).
4. **Humano (SG-6):** dispatch de `main` + frase + acknowledge + required reviewers.
5. **Gate §7 pós-run (SG-7)** → run pronta para Channel Filter. **P5-REPRO-01 (SG-8)** antes do 1º publish.

## 9. Open decisions / bloqueios
- **Nenhum bloqueio de DevOps para o design.** O YAML está autorado e inerte; a execução segue atrás do checklist (SG-0..SG-6) — intacto e fail-closed.
- **F-1** (API-restriction/rotação da key) permanece condição de **SG-4/`configure_env`** (não desta entrega).
- **`0007` PARKED** e **Fase 9/RLS VETADA** — não tocados.
