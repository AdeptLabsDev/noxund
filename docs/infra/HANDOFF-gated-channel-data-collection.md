# Handoff — `task_channel_data_collection_gated_pipeline_design` · DevOps/Infra Agent

## 1. Identificação
- **Tarefa:** `task_channel_data_collection_gated_pipeline_design` · **Action:** `define_pipeline` (design-only; **não** autora YAML nesta entrega)
- **Owner agent:** DevOps / Infra (`devops_agent`)
- **Data:** 2026-07-01
- **Prioridade:** P1 (high — caminho crítico do 1º relatório)
- **Escopo:** Passo 4 — trilha **gated** de coleta de Channel Data (DEC-0017 item 7). Coleta `channels.list → raw_youtube_channels` sobre os canais do snapshot de vídeos de uma run.
- **Alvo:** projeto Supabase `pwbkplzyzmortwjjpcbg` · região `us-east-1` · YouTube Data API v3 (`channels.list`).
- **Estado:** **DESIGN/RUNBOOK-ONLY** — zero coleta, zero API, zero secret, zero pipeline execution, zero DB write, zero publish, zero git.

## 2. Objetivo
Desenhar o **pipeline gated** e o **runbook operacional** da sub-coleta de Channel Data, espelhando o precedente `.github/workflows/entity-db-apply.yml`, e **nomear a nova superfície de risco** (secret `YOUTUBE_API_KEY` + egress externo + escrita irreversível em raw) que distingue esta trilha de todos os applies anteriores. **Nenhum apply, nenhuma coleta** — a execução real permanece atrás do checklist de gate (§9 do runbook / §12 deste handoff) e de aprovação humana.

## 3. Critério de aceite (do payload / DEC-0017 item 7)
1. Runbook `channels.list → raw_youtube_channels` (conjunto de canais determinístico, lotes ≤50, ≤~10 unidades/run, mesma `run_id` chained após o gate de vídeos, mapa de campos, quota, **DC2-01 fail-closed**, gate checklist).
2. Handoff DevOps com o **desenho do pipeline gated** (mirror de `entity-db-apply.yml`) + `next_recommendation` JSON, sinalizando o **NOVO** risk surface (secret/Environment) vs. applies anteriores.
3. Não rodar/aplicar/publicar; não tocar Fase 9/RLS; não destravar `0007`; não autora o YAML (fora de `docs/`).

## 4. Resultado
- [x] **Runbook entregue** — `docs/infra/RUNBOOK-channel-data-collection.md`: posição na run (mesma `run_id`, sub-fase C chained após `DATA-COLLECT-001 §7`; recoleta = novo `run_id`); conjunto determinístico de canais; request `channels.list` (`part=snippet,statistics`, lotes ≤50, sem `fields`, key fora do payload); mapa de campos → `raw_youtube_channels` (NULL≠0); quota (≤~10 un/run); append-only/idempotência; **DC2-01 fail-closed**; gate §7 (set-equality); pipeline gated; **checklist de gate ordenado**; higiene de log; OPEN QUESTIONS.
- [x] **Desenho do pipeline gated** — §11 deste handoff (mirror de `entity-db-apply.yml` + o delta de risco).
- [x] **`next_recommendation` JSON** — §14.
- [x] **NOVO risk surface nomeado** — §13.
- [x] **Constraints honradas** — sem execução/apply/publish; Fase 9 não tocada; `0007` não destravado; YAML não autorado (só desenhado em prosa, dentro de `docs/`).

**Como verificar (design-only):** os quatro docs vivem só em `docs/infra` + `docs/security` + `docs/database`; nenhum arquivo em `.github/`, `supabase/` ou `services/` foi criado/alterado; nenhum valor de secret aparece (só nomes).

## 5. Arquivos alterados (criados)
- `docs/infra/RUNBOOK-channel-data-collection.md` — runbook operacional.
- `docs/infra/HANDOFF-gated-channel-data-collection.md` — este handoff.
- `docs/security/SEC-0019-channel-data-collection-review.md` — review de segurança (SEC-F23/SEC-F08/secret/quota).
- `docs/database/HANDOFF-channel-data-collection-review.md` — nota Database (zero ALTER / FK / DC2-01).

**Intocados (constraint):** `.github/workflows/*` (o YAML de coleta é `define_pipeline` **futura**), `supabase/migrations/*` (schema já vivo, **zero ALTER**), `services/data-engine/*`, `docs/data/*`, `0007_phase6_producer_events.*` (**PARKED**).

## 6. Impacto no escopo
- **MVP travado?** Sim. Só design/runbook de coleta; nada de Fase 2/marketplace; stack inalterada. Keyword/janela/volume/paginação da coleta de vídeos **inalterados** (Channel Data só adiciona metadados de canais já surfados).
- **Non-negotiable?** Reforça: **IA nunca gera número** (coleta é cópia verbatim do body); **proveniência** até `raw_youtube_channels` (FK composta `(run_id, channel_id)` RESTRICT); **default-deny** (RLS + revoke, sem policy); **secrets fora de repo/log** (só nomes; scrub body-only; canary test); **fail-closed** (DC2-01, gate §7, quota/erro → run `failed`).
- **Toca número/banco/auth/copy pública?** Toca **secret/ambiente** (novo `YOUTUBE_API_KEY`) e **escrita em raw** → exige revisão **Security + Database + Data/AI** (matrix #4, #8, "Gestão de secrets/API keys", "Internal jobs protegidos"). Nenhuma copy pública.

## 7. Validação executada
- **Design/estático:** cross-check do runbook contra `DATA-COLLECT-002` (§§2–9), `DATA-COLLECT-001` (§7/§8 precedentes), o schema aplicado (Fase 4 L128–170) e o mirror `entity-db-apply.yml`. Mapa de campos batendo verbatim com o SQL aplicado; CHECK anti-secret e triggers de imutabilidade confirmados no SQL.
- **Execução:** **não executada** (constraint + design-only). Toda validação funcional (testes do job §8, preflight/verify §7, `configure_env`) roda **atrás** do checklist de gate, no 1º dispatch gated pós-aprovações.

## 8. Riscos
- **Novo secret portador de custo (`YOUTUBE_API_KEY`)** — ver §13. Mitigado por: Environment dedicado least-privilege, `main`-only (SEC-F18), body-only scrub + CHECK SEC-F08, canary test, header em vez de `?key=`, restrição de API + rotação.
- **Escrita irreversível** — raw é append-only/imutável; run ruim não reverte (correção = novo `run_id`). Mitigado por gate §7 pré-Channel-Filter e fail-closed em qualquer erro.
- **DC2-01** — canal deletado/suspenso entre estágios ⇒ fail-closed (§13).
- **PII pública em `raw_json`** — SEC-F23/OPEN-DC2-02, endereçado por SEC-0019.

## 9. Revisões necessárias
- [x] **DevOps** — esta entrega (autor do desenho + runbook).
- [ ] ⏳ **Security Review (`audit_secrets`) — BLOQUEANTE** (SEC-0019): SEC-F23/PII, CHECK SEC-F08, `YOUTUBE_API_KEY`, quota. **Acionada** via `next_recommendation`.
- [ ] ⏳ **Security `audit_secrets` do pipeline (matrix #8):** desvio de template vs. `entity-db-apply.yml` — **NOVO** secret/Environment + egress externo (quando o YAML for autorado em `define_pipeline`).
- [ ] ⏳ **Database/Data Integrity Review** (`docs/database/HANDOFF-channel-data-collection-review.md`): zero ALTER, FK composta/imutabilidade, DC2-01.
- [ ] ⏳ **Data/AI Review:** determinismo, NULL≠0, testes do job §8, DC2-01, pré-condição de replay.
- [ ] ⏳ **Product Orchestrator:** sequência de sub-fase única (DC2-04) + confirmação das OPEN QUESTIONS.

## 10. Próximos passos (desbloqueios)
1. **Security** baixa SEC-0019 (design do dado) e a auditoria do pipeline (matrix #8, quando autorado).
2. **Database** ratifica zero ALTER + DC2-01 fail-closed.
3. **DevOps `define_pipeline`** (futura): autora `.github/workflows/youtube-collection.yml` (mirror SHA-pinned de `entity-db-apply.yml`).
4. **DevOps `configure_env`** (sensível/gated): Environment `youtube-collection` (`YOUTUBE_API_KEY` + conexão DB least-privilege, `main`-only, required reviewers, rotação) — evidência out-of-band (precedente `INFRA-0001`).
5. **Data/AI** implementa o job + testes §8 verdes.
6. **Humano** dispara o run gated (frase + required reviewers) → gate §7 → run pronta para Channel Filter.
7. **P5-REPRO-01** bloqueia o 1º publish.

## 11. Desenho do pipeline gated (mirror de `entity-db-apply.yml`)

**Herança fiel do precedente gated** (mesma espinha de `entity-db-apply.yml` / `phase5-db-apply.yml`):

- `on: workflow_dispatch` **único** — **zero** `push`, **zero** `schedule` (cron é Fase 2). Input `confirm` obrigatório (frase, ex.: `RUN-CHANNEL-COLLECTION`); job `guard` aborta se a frase não bater.
- Jobs: `guard` (frase) → `collect` (`needs: guard`, `environment: youtube-collection`) → `verify` (`needs: collect`, `environment: youtube-collection`, roda o gate §7 de completude de canais).
- Actions de terceiros **SHA-pinadas** (SEC-F17), `permissions: contents: read`, `concurrency` group dedicado (`cancel-in-progress: false`).
- **Required reviewers** do Environment = **DevOps + Security** (matrix #8) — aprovação humana em tempo de execução.
- **SEC-F18:** deployment branch rule = **`main`**, configurada **antes** de qualquer secret — bloqueia dispatch de branch modificada acessando o secret.
- URL de conexão DB mascarada (`::add-mask::` + `jq @uri`), **service-role key NÃO usada** (SEC-F19).

**Onde o mirror DIVERGE — a razão de esta trilha exigir nova auditoria de secrets (matrix #8):**

| Dimensão | `entity-db-apply.yml` (e phase1–5) | **`youtube-collection.yml` (NOVO)** |
|---|---|---|
| Passo de execução | `supabase db push` (DDL idempotente) | **job de coleta** do data-engine: `channels.list` + INSERT em raw |
| Egress | só Supabase | **+ `googleapis.com`** (1º egress a API de terceiro real) |
| Secrets no Environment | `SUPABASE_DB_PASSWORD` + `SUPABASE_ACCESS_TOKEN` | **`YOUTUBE_API_KEY`** (nova classe) + conexão DB least-privilege **sem** `ACCESS_TOKEN` de migration |
| Preflight | "pending == {migration}" | pré-condições da run (gate de vídeos §7 passou; run não `failed`; `ChannelsToCollect` derivado) |
| "Verify" | assere estrutura DDL exata | gate de completude §7 (set-equality; dado externo é não-determinístico) |
| Rollback | SQL de rollback disponível | **nenhum** — raw append-only; correção = novo `run_id` |

**Decisão de Environment (recomendada):** **Environment dedicado `youtube-collection`** (não reusar `production-db`), least-privilege — a `YOUTUBE_API_KEY` e o token de push de migration **não** compartilham blast radius. Provisionamento via `configure_env` (sensível/gated), `main`-only antes dos secrets, required reviewers, política de rotação (precedente `INFRA-0001`). Detalhe e alternativas em OQ-1/OQ-2 do runbook.

## 12. Quadro de gates residual (coleta real de Channel Data)
| Gate | Estado |
|---|---|
| DEC-0017 item 7 — trilha gated autorizada a **desenhar** | ✅ |
| Runbook + desenho do pipeline (DevOps) | ✅ **entregue aqui** |
| Security `audit_secrets` do dado (SEC-0019: SEC-F23/SEC-F08/key/quota) | ⏳ recomendada — `next_recommendation` |
| Database — zero ALTER / FK / DC2-01 | ⏳ (`HANDOFF-channel-data-collection-review.md`) |
| DevOps `define_pipeline` — YAML `youtube-collection.yml` (mirror SHA-pinned) | ⏳ futura, atrás dos reviews |
| Security `audit_secrets` do pipeline (matrix #8 — desvio de template) | ⏳ futura |
| DevOps `configure_env` — Environment + `YOUTUBE_API_KEY` (sensível/gated, evidência) | ⏳ sensível/humano-gated |
| Testes do job §8.1–§8.6 verdes | ⏳ pré-live |
| Gate de vídeos §7 (`DATA-COLLECT-001`) passou p/ a run | ⏳ pré-condição |
| Dispatch humano + frase + required reviewers | ⏳ execução |
| Gate de canais §7 pós-run (set-equality) | ⏳ pós-run |
| **P5-REPRO-01** (antes do 1º publish) | ⛔ bloqueia publish |
| **Fase 9 / RLS Policies** | ⛔ **VETADA — não tocada** |
| **`0007`/producer_events** | ⛔ **PARKED — não destravado** |

## 13. NOVA superfície de risco (secret/Environment) vs. applies anteriores
Todo apply anterior (phase1–5, entity) era **DDL idempotente** contra o **próprio DB Supabase**, com rollback disponível e secrets **exclusivamente** Supabase — a service-role key deliberadamente **fora** do CI (SEC-F19). Esta trilha introduz, pela primeira vez:

1. **Uma credencial nova, portadora de custo (`YOUTUBE_API_KEY`).** Abuso = queima de quota/billing. Viaja no request (`?key=`/header) → exposta a vetores de log que os jobs de migration nunca tocaram (erro de axios, breadcrumb do Sentry). Mitigação: header `X-Goog-Api-Key`, scrub body-only + CHECK SEC-F08, canary test, restrição de API + rotação.
2. **Egress externo real** (`googleapis.com`) — 1ª saída de rede a API de terceiro em produção.
3. **Uma decisão de topologia de Environment.** `production-db` **não** tem a key. Adicioná-la lá **mistura** raios de explosão (token de migration + API key no mesmo Environment). Recomendação: **Environment dedicado `youtube-collection`** least-privilege, sem `SUPABASE_ACCESS_TOKEN`.
4. **Escrita irreversível** em tabela imutável — não há rollback; run ruim vira run falha e a correção é **novo `run_id`**.
5. **Conteúdo público (PII) em `raw_json`** (title/description/customUrl/thumbnails) — SEC-F23/OPEN-DC2-02, endereçado em SEC-0019.

Por isso a auditoria de secrets do pipeline (matrix #8) **não** é a revisão de delta mínima que foi `entity-db-apply.yml`: é uma superfície **materialmente nova**.

## 14. Open decisions / bloqueios
- **Nenhum bloqueio de DevOps para o design.** O desenho + runbook estão entregues; a execução segue atrás do checklist de gate (§11 do runbook) — intacto e fail-closed.
- **OPEN QUESTIONS para humano antes do LIVE** (detalhadas no runbook §13): OQ-1 (Environment dedicado vs. reuso), OQ-2 (papel de escrita `postgres` vs. `service_role`), OQ-3 (workflow de run única — DC2-04), OQ-4 (SEC-F23/OPEN-DC2-02), OQ-5 (DC2-01 fail-closed vs. tombstone), OQ-6 (header vs. `?key=`), OQ-7 (rotação/restrição da key).
- **`0007`/producer_events PARKED** e **Fase 9/RLS Policies VETADA** — não tocados; permanecem gates de pé.

---

### `next_recommendation` (AgentResult)
```json
{
  "status": "completed",
  "next_recommendation": {
    "target_agent": "security_agent",
    "action": "audit_secrets",
    "priority": "high",
    "reason": "Passo 4 (DEC-0017 item 7): runbook + desenho do pipeline GATED de coleta de Channel Data (channels.list -> raw_youtube_channels) entregues design-only, espelhando entity-db-apply.yml. Auditar o desenho do DADO (SEC-0019: SEC-F23/PII publica de canal em raw_json; CHECK anti-secret raw_youtube_channels_no_request_context/SEC-F08; handling da YOUTUBE_API_KEY body-only + higiene de log/canary; quota/custo). NOVA superficie vs applies anteriores: credencial portadora de custo (YOUTUBE_API_KEY, nunca antes no CI), egress externo googleapis.com, escrita IRREVERSIVEL em raw imutavel (sem rollback), Environment (recomendado dedicado youtube-collection least-privilege, NAO reusar production-db). DC2-01 fail-closed: canal deletado/suspenso omitido -> sem linha fabricada -> gate 7 falha -> novo run_id, SEM tombstone. Delta de quota <= ~10 unidades/run (~1% da run). Nada roda ate o checklist de gate verde + dispatch humano + required reviewers. Fase 9 nao tocada; 0007 parked; publish barrado ate P5-REPRO-01.",
    "evidence": {
      "runbook": "docs/infra/RUNBOOK-channel-data-collection.md",
      "handoff": "docs/infra/HANDOFF-gated-channel-data-collection.md",
      "sec_review": "docs/security/SEC-0019-channel-data-collection-review.md",
      "db_note": "docs/database/HANDOFF-channel-data-collection-review.md",
      "schema_applied": "supabase/migrations/20260620000004_phase4_raw_youtube_snapshots.sql L128-170 (zero ALTER)",
      "pipeline_precedent": ".github/workflows/entity-db-apply.yml (workflow_dispatch + confirm + production-db Environment + required reviewers + SEC-F18 main-only)",
      "new_risk_surface": "YOUTUBE_API_KEY (cost-bearing), external egress, irreversible raw write, dedicated Environment decision",
      "quota_delta": "<= ~10 units/run (channels.list, 1 unit/call, <=10 batches)",
      "fail_closed": "DC2-01 (no tombstone; new run_id) + gate 7 set-equality + quota/error -> run failed",
      "untouched": ["phase9_rls_policies_VETOED", "0007_producer_events_PARKED", "keyword/window/volume_UNCHANGED", "no_ALTER"]
    }
  }
}
```
