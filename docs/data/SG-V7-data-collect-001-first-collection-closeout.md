# SG-V7 — DATA-COLLECT-001 First Collection Closeout · Freeze do `run_id` (A6)

## 1. Identificação

- **Documento:** closeout operacional do **SG-V7** (primeira coleta real da trilha de vídeo) + **freeze formal do `run_id` §7-passed** — o checkpoint **A6** do runbook de dispatch. **Não** autoriza SG-6, SG-8 nem qualquer dispatch.
- **Trilha:** `DATA-COLLECT-001` — coleta de vídeo upstream (`search.list → raw_youtube_search_pages`, `videos.list → raw_youtube_videos`).
- **Gate:** SG-V7 — dispatch humano multi-fator → collect → **§7 passa → `run_id` congelado**.
- **Owner do registro:** Product Orchestrator. **Execução integral do gate:** Product Lead (dispatch, A3, A4 — required reviewer do Environment). Agentes em modo **read-only** durante todo o ciclo.
- **Data:** 2026-07-15
- **Natureza:** DOCS-ONLY / RECORDS-ONLY — zero alteração de código, workflow, schema, marker, GCP, secrets, Supabase ou Environment. Zero dispatch. Runs falhos **preservados** (nunca re-executados).
- **Fontes vinculantes:** `docs/data/SG-V6-data-collect-001-pre-arm-attestation.md §11–§12`; `docs/security/SEC-0025-f1f-sentry-canary-closeout.md`; `docs/product/decisions/DEC-0020-od-v2-quota-alert-thresholds.md`; **PR #45** (fix de provisionamento psycopg, merge `07f58b4`); runs de Actions `29389945976`, `29444609139`, `29446423135`; `docs/security/SEC-0026-a7-key-rotation-closeout.md` (A7).

## 2. Veredito — freeze formal do `run_id`

✅ **SG-V7 COMPLETO.** A primeira coleta real da história do pipeline foi executada com sucesso em 2026-07-15, sob a cadeia humana integral (A1–A4), e o gate §7 de completude passou.

**`run_id` = `f0485de6-0d34-41cf-ab48-d46e483aa558` — CONGELADO, §7-PASSED.**

- **Run:** `29446423135` (`workflow_dispatch`, `main` @ `07f58b47e159a1ad7a1201f204fa6d32da8fa3f3`, 2026-07-15T19:56:53Z, conclusão `success`, 3/3 jobs verdes).
- **Veredito §7 (verbatim do log do verify):** `OK — Video Data §7 completeness gate PASSED (identity/30d, chain, stop, set-equality, one-row, verbatim, NULL!=0, SEC-F08, finalized).`
- **Semântica do freeze:** o snapshot é **imutável** (raw append-only; SEC-F08; triggers de imutabilidade). Qualquer correção futura = **novo `run_id`** via novo ciclo completo de autorização — nunca rollback, nunca edição. Este `run_id` é o **input estrutural do SG-6** (`youtube-collection`/002), que permanece **NO-GO** até ordem explícita do Product Lead.

⛔ **Este doc não autoriza nada downstream.** SG-6, SG-8/P5-REPRO-01 e publish seguem barrados (§8).

## 3. Histórico dos três runs (registro completo, falhas preservadas)

| # | Run | Data (UTC) | `head_sha` | Desfecho | Quota | Escrita no banco | Raio de dano |
|---|---|---|---|---|---|---|---|
| 1 | `29389945976` | 2026-07-15T04:50Z | `581f07d` | ❌ falha no collect | **0 unid** | **nenhuma** (sem `run_id`) | **zero** |
| 2 | `29444609139` | 2026-07-15T19:28Z | `07f58b4` | ❌ falha no collect | **0 unid** | **nenhuma** (sem `run_id`) | **zero** |
| 3 | `29446423135` | 2026-07-15T19:56Z | `07f58b4` | ✅ **success 3/3** | **1.210 unid** | INSERT-only, §7-passed | n/a |

Os runs #1 e #2 estão **preservados como evidência** (`run_attempt=1`, jamais re-executados — *Re-run jobs* proibido por decisão do Product Lead). Ambos falharam **pré-criação**: antes de qualquer chamada à YouTube API e antes de criar `run_id` — zero quota, zero linha em `report_runs`/`raw_*`, zero egress a `googleapis.com`. O verify §7 foi `skipped` fail-closed nos dois. A higiene de log segurou nos três runs (nenhuma key, `pageToken`, DSN ou URL com `?key=`).

### 3.1 Run #1 — `29389945976`: driver PostgreSQL não provisionado

- **Sintoma:** guard 3/3 GREEN; collect falhou em `_connect()`: `ModuleNotFoundError: No module named 'psycopg'` → `CollectionError: postgresql driver not provisioned` (`video_collection.py`).
- **Causa raiz:** lacuna de provisionamento no workflow — o job de collect não instalava driver Postgres; o CI nunca exercitava o import real (testes §8 usam `FakeConnection` por design; data-engine é stdlib pura por design, `dependencies = []`).
- **Correção:** **PR #45** (merge `07f58b4`, 2026-07-15T05:09:44Z) — pin único `services/data-engine/requirements-collect.txt` (`psycopg==3.3.4` com hashes sha256, `--require-hashes --only-binary`), steps *Provision PostgreSQL driver* + *Driver contract* em **ambos** os collect jobs (antes de qualquer segredo/DB/API), e job de CI independente `collection-driver-contract`. F-2' delta review: APPROVE. A eficácia foi **provada em produção no run #2** (ambos os steps GREEN).

### 3.2 Run #2 — `29444609139`: projeto Supabase auto-pausado

- **Sintoma:** guard 3/3 GREEN; provision + driver contract GREEN (fix do PR #45 provado); collect falhou em `psycopg.connect()`: pooler `aws-1-us-east-1` respondeu `FATAL: (ENOTFOUND) tenant/user postgres.pwbkplzyzmortwjjpcbg not found` nos 3 IPs do cluster.
- **Causa raiz:** **projeto Supabase auto-pausado por inatividade (free tier) desde 2026-07-11** — confirmado pelo Product Lead no dashboard. Corroboração read-only: DNS do projeto (`<ref>.supabase.co` e `db.<ref>.supabase.co`) em **NXDOMAIN** enquanto os clusters de pooler resolviam; vars de conexão **intocadas** desde o provisionamento (production-db 2026-06-21; youtube-collection 2026-07-05) e **provadas válidas** por 5 applies gated bem-sucedidos entre 2026-06-24 e 2026-06-29. Última atividade de banco pré-pause: 2026-06-29 (~16 dias idle).
- **Correção:** **restore manual do projeto pelo Product Lead** (dashboard, dentro da própria alçada) + verificação read-only credenciada (`select 1` GREEN; `report_runs`, `raw_youtube_search_pages`, `raw_youtube_videos` presentes) + corroboração de DNS resolvendo. **Nenhuma var, secret, código ou workflow alterado** — a correção foi 100% do lado da plataforma.
- **Lacuna de processo identificada e fechada:** a revalidação pré-dispatch da época não cobria *liveness* do projeto (não era detectável por repo/CI/Actions). O ciclo #3 já incluiu o check (§7 deste doc).

### 3.3 Run #3 — `29446423135`: sucesso ponta a ponta

Guard 3/3 GREEN (frases verbatim aceitas; backstop SEC-F18 `refs/heads/main`; preflight ARMED) → **A3** (Product Lead) → collect success → **A4** (Product Lead) → verify §7 **PASSED**. Métricas em §4.

## 4. Métricas e evidências da coleta (run `29446423135`)

| Métrica | Valor | Evidência |
|---|---|---|
| `run_id` | `f0485de6-0d34-41cf-ab48-d46e483aa558` | log: `run ... created (collecting)` 19:59:01Z |
| Vídeos coletados | **500** (alvo exato do PRD) | `run finalized count=500` |
| Razão de parada | `target_reached` (explicada, não exaustão/cap) | `search: stop=target_reached pages=12` |
| Páginas `search.list` | 12 | idem |
| Batches `videos.list` | 10 × 50 ids = 500, todos `batch persisted` | log do collect |
| Quota consumida | **1.210 unid** — aritmética exata: 12×100 + 10×1 | `run finalized ... quota=1210` |
| Retry surplus | **0** de 500 | zero linha de retry no log |
| WARN / ERROR | **zero** | log completo do collect |
| Duração do collect | ~46 s (19:59:01Z → 19:59:47Z) | timestamps do log |
| `run_id` → `$GITHUB_OUTPUT` | emitido (`Set output 'run_id'`) — **`F2'-N1` provado em produção** | log do job |
| Shape check do verify | `collect-produced run_id shape OK.` | log do verify |
| Veredito §7 | `OK — Video Data §7 completeness gate PASSED (identity/30d, chain, stop, set-equality, one-row, verbatim, NULL!=0, SEC-F08, finalized).` | log do verify (psql `ON_ERROR_STOP=1`) |
| Higiene de log | nenhuma key/`pageToken`/DSN/`?key=` — só as linhas permitidas pelo spec §8 | consistente com canary §8.3 (SEC-0025) |

## 5. Posição contra os thresholds de quota (DEC-0020)

```txt
1.010 nominal < 1.210 REAL < 1.500 alerta/run < 2.000 cap < 3.000 legada (30%) < 5.000 preventivo < 8.000 crítico < 10.000 quota
```

- **Per-run:** 1.210 unid — acima do nominal (~1.010) por 2 páginas extras de `search.list` para fechar 500 vídeos únicos (comportamento esperado), **abaixo** do alerta de anomalia (≥1.500) e do cap fail-closed (2.000). Zero retry surplus.
- **Diário:** 1.210 de 10.000 (**12,1%**) — abaixo inclusive da política legada de 30%. **Nenhum threshold cruzado; nenhum alerta esperado ou reportado.**

## 6. Cadeia humana — ledger A1–A8 do runbook SG-V7

| Checkpoint | Conteúdo | Estado |
|---|---|---|
| **A1** | GO de ciclo (Product Lead) — emitido para os ciclos #1, #2 e #3, cada um com revalidação pré-dispatch fresca | ✅ 3× |
| **A2** | Dispatch humano (`main` + `RUN-VIDEO-COLLECTION` + `I-UNDERSTAND-RAW-IS-IRREVERSIBLE`) | ✅ 3× (Product Lead) |
| **A3** | Aprovação do collect (required reviewer do Environment) | ✅ (runs #1, #2, #3) |
| **A4** | Aprovação do verify §7 (required reviewer do Environment) | ✅ (run #3; nos runs #1/#2 nunca alcançado — skipped fail-closed) |
| **A5** | Ciclo de re-dispatch pós-falha (retorno à decisão humana, sem re-run/re-dispatch automático) | ✅ 2× — honrado integralmente |
| **A6** | **Registro documental do freeze do `run_id`** | ✅ **= este documento** |
| **A7** | Rotação pós-run da `YOUTUBE_API_KEY` (staged) | ✅ GREEN — `SEC-0026` (E7a–E7f) |
| **A8** | Handoff do `run_id` congelado ao SG-6 (002) | ⛔ **NO-GO** — fronteira seguinte, ordem explícita pendente |

Agentes operaram em **read-only** durante todo o SG-V7: verificação pré-A3, relatório pré-A4, watch de transições e diagnóstico de falhas — zero dispatch, zero aprovação, zero mutação.

## 7. Registro de risco operacional (sem decisão de mitigação aqui)

- **RO-1 — Auto-pause do Supabase (free tier):** projetos pausam após ~7 dias de inatividade; o pause remove o DNS do projeto e o tenant do pooler, derrubando qualquer coleta futura no `connect()` (falha limpa, custo zero — mas falha). Materializou-se no run #2.
  - **Requisito vinculante para revalidações pré-dispatch futuras (novo):** incluir **check de liveness do projeto** — probe de DNS (`<ref>.supabase.co`) por agente (read-only, sem credencial) **+** verificação credenciada do Product Lead (`select 1` + presença de `report_runs`, `raw_youtube_search_pages`, `raw_youtube_videos`).
  - **Mitigação permanente (upgrade de plano vs. keep-alive agendado vs. restore manual como passo de runbook): OPEN DECISION — deliberadamente NÃO decidida neste PR**, por determinação do Product Lead.
- **Pendência separada (não corrigida aqui):** `INFRA-0001 §2.2`/`INFRA-0002 §2.2` documentam o host do session pooler como `aws-0-us-east-1.pooler.supabase.com`; o valor vivo — e provado por 5 applies e pela coleta do run #3 — é `aws-1-us-east-1.pooler.supabase.com`. Correção documental fica como **item separado**, por ordem própria do Product Lead.

## 8. Fronteiras e vetos (pós-closeout)

- **SG-6 (Channel Data / 002) → ⛔ NO-GO.** É a **próxima fronteira**: consumirá o `run_id` congelado `f0485de6-0d34-41cf-ab48-d46e483aa558` como input, sob novo ciclo humano completo. `youtube-collection` segue **ARMADO e OCIOSO** (0 runs).
- **SG-8 / P5-REPRO-01 → pré-publish.** Publish permanece **barrado**.
- **Rotação da key:** fechada como **A7** (`SEC-0026`); próximo deadline ≈ **2026-10-13** (90d da key nova).
- **Vetos de pé:** `0007`/producer_events **PARKED**; Fase 9/RLS **VETADA**; zero coleta nova sem novo ciclo A1–A4.

## 9. Restrições honradas / Intocados

- **Docs-only.** Nenhum código, workflow, schema, migration, marker, secret, GCP, Supabase ou Environment tocado por este registro.
- **Runs falhos preservados:** `29389945976` e `29444609139` intactos, `run_attempt=1`, nunca re-executados.
- **Zero valor sensível:** apenas nomes de secrets/vars e o project ref (não-secreto); nenhum valor, connection string ou credencial; nenhum screenshot.
- **Intocados:** `.github/workflows/*`, `.github/collection/*` (ambos markers presentes), `services/data-engine/*`, `supabase/*` (incl. `0007` PARKED untracked).

---

## Handoff (per `docs/agents/handoff-template.md`)

**Tarefa:** `task_sgv7_closeout_freeze_run_id` · **Owner:** Product Orchestrator (execução do gate: Product Lead) · **Data:** 2026-07-15 · **Prioridade:** P1

**Objetivo:** fechar o SG-V7 no registro — freeze formal do primeiro `run_id` §7-passed, histórico completo dos 3 runs (falhas preservadas com causa raiz e raio de dano zero), métricas da coleta e ledger da cadeia humana A1–A8.

**Resultado:** ✅ SG-V7 COMPLETO. `run_id f0485de6-0d34-41cf-ab48-d46e483aa558` congelado (500 vídeos, `target_reached`, 1.210 unid, §7 PASSED verbatim). Falhas #1 (psycopg → PR #45) e #2 (auto-pause → restore) documentadas e preservadas. A7 fechado em `SEC-0026`.

**Arquivos criados/alterados:** `docs/data/SG-V7-data-collect-001-first-collection-closeout.md` (este doc) · `docs/security/SEC-0026-a7-key-rotation-closeout.md` · `docs/data/SG-V6-data-collect-001-pre-arm-attestation.md` (adendo §12). **Nenhum outro arquivo tocado.**

**Impacto no escopo:** MVP travado mantido; zero toque em número, banco ou copy pública. A tese ganha o primeiro snapshot real, imutável e auditável.

**Próximos passos:** SG-6 (ordem explícita pendente) → SG-8/P5-REPRO-01 → publish. RO-1 (mitigação do auto-pause) = OPEN DECISION.

**Open decisions:** RO-1 (mitigação permanente do auto-pause); correção documental `aws-0`→`aws-1` (pendência separada).

---

## AgentResult

```json
{
  "task_id": "task_sgv7_closeout_freeze_run_id",
  "agent": "product_agent",
  "status": "completed",
  "summary": "SG-V7 COMPLETO e registrado (A6). run_id f0485de6-0d34-41cf-ab48-d46e483aa558 CONGELADO e par.7-PASSED — primeira coleta real da trilha DATA-COLLECT-001: 500 videos (target_reached), 12 paginas search.list + 10 batches videos.list, quota 1.210 unid (12x100+10x1 exato; 0 retry surplus; < 1.500 alerta < 2.000 cap; 12,1% do teto diario — nenhum threshold cruzado), ~46s, zero WARN/ERROR, higiene de log integra, run_id emitido via GITHUB_OUTPUT (F2'-N1 provado em producao). Tres runs documentados: #1 29389945976 (psycopg ausente — lacuna de provisionamento corrigida no PR #45, provada no run seguinte), #2 29444609139 (projeto Supabase auto-pausado desde 2026-07-11 — restore manual do Product Lead; vars intocadas e provadas validas), ambos falha pre-criacao com raio de dano ZERO (0 quota, 0 run_id, 0 escrita) e PRESERVADOS sem re-run; #3 29446423135 success 3/3. Cadeia humana integral A1-A4 + A5 (2 ciclos de re-dispatch com revalidacao fresca) honrada; agentes read-only. A7 rotacao fechada em SEC-0026. Riscos registrados sem decidir mitigacao: RO-1 auto-pause (liveness check agora requisito das revalidacoes futuras; mitigacao permanente = OPEN DECISION) + pendencia separada aws-0/aws-1 em INFRA-0001/0002. SG-6 NO-GO; publish barrado ate SG-8/P5-REPRO-01.",
  "artifacts": [
    {
      "type": "review",
      "path": "docs/data/SG-V7-data-collect-001-first-collection-closeout.md",
      "description": "Closeout SG-V7: freeze do run_id par.7-passed, historico dos 3 runs com causas-raiz e preservacao, metricas, posicao vs DEC-0020, ledger A1-A8, registro de riscos RO-1 e pendencia aws-0/aws-1."
    }
  ],
  "errors": [],
  "next_recommendation": {
    "target_agent": "product_agent",
    "action": "record_decision",
    "priority": "high",
    "reason": "SG-V7 fechado com run_id congelado. Proxima fronteira = SG-6 (youtube-collection/002) consumindo f0485de6-0d34-41cf-ab48-d46e483aa558 — NO-GO ate ordem explicita do Product Lead, sob novo ciclo humano completo. RO-1 (mitigacao do auto-pause) aguarda decisao do Product Lead em registro proprio."
  }
}
```
