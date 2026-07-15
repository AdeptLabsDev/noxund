# SEC-0025 — Closeout `F1'-f` · ausência estrutural de telemetria + canary §8.3 · trilha de vídeo `DATA-COLLECT-001`

- **Task:** `task_close_f1f_sentry_canary` · **Action:** `audit_secrets` (closeout do item pré-live F1'-f) · **Agents:** `devops_agent` + `security_agent` (co-sign, matrix #8) · **Compilado por:** Product Orchestrator
- **Data:** 2026-07-15
- **Gate:** fecha **`F1'-f`** (`SEC-0023 §8`) — o item pré-live que condicionava o **1º dispatch real (SG-V7)**; era o último item aberto do checklist F-1'.
- **Fontes vinculantes:** `SEC-0023 §5/§8` (RR-4, definição de F1'-f) · `DATA-COLLECT-001-youtube-collection-spec.md §8` (higiene de log; teste obrigatório #3 = canary) · `SEC-0024` (closeout F1'-c/d) · `SG-V6-...-pre-arm-attestation.md §10–§11` · run de CI `29385668057`.
- **Mandato:** RECORDS/AUDIT-ONLY, docs-only. Baseado em audit read-only (repo + API GitHub) e numa execução de evidência **autorizada pelo Product Lead** (run de CI de testes — read-only, zero egress). **Zero valor de secret, zero screenshot, zero log extenso.** Este doc não altera código/testes/workflows/marker/Sentry/GCP/secrets/Environment e **não autoriza dispatch**.

---

## 0. Veredito

✅ **`F1'-f` → GREEN (co-sign DevOps + Security).** O risco que o F1'-f mitigava (RR-4: Sentry capturando URL/params/breadcrumbs) é **estruturalmente ausente** do runtime de coleta, e a higiene do único sink real de log está **provada por canary §8.3 verde no `main` vigente**, com evidência fresca e datada.

⛔ **Este doc NÃO autoriza SG-V7.** Com F1'-f fechado, o checklist F-1' está **integralmente GREEN** e a única fronteira antes da primeira coleta real é o **dispatch humano multi-fator do SG-V7** — decisão exclusiva do Product Lead, fora deste registro.

## 1. Ausência estrutural de telemetria no caminho de coleta (repo-verificável)

| Fato | Evidência |
|---|---|
| Data-engine é **stdlib pura**: `dependencies = []`; **zero `sentry-sdk`**, zero import de telemetria; logging = módulo `logging` da stdlib | `services/data-engine/pyproject.toml`; grep no serviço (única menção a Sentry é regra de higiene no README) |
| `video-collection.yml` **não referencia Sentry** e **não injeta `SENTRY_DSN`** em nenhum job | grep no YAML |
| Environment `youtube-collection` contém **somente** os 2 secrets e 3 vars conhecidos — **sem DSN** (secrets não-referenciados não entram no env do job) | API GitHub (metadados; nomes apenas), verificado 2026-07-14 |

**Declaração explícita (exigida pelo Product Lead):** **não houve "scrub" nem desativação de Sentry** — não havia o que desligar ou redatar, porque **Sentry não integra este runtime**. O F1'-f foi redigido (`SEC-0023 §5`, RR-4) sob a hipótese de um SDK presente; o audit provou a hipótese falsa. O fechamento é por **atestação de ausência + prova de higiene do sink real (canary §8.3)** — postura igual ou mais forte que a prevista: a superfície inteira não existe.

## 2. Canary §8.3 — GREEN no `main` vigente, evidência fresca

- **SHA testado:** `main@13c225828f3f4030f8cc7c5ac25e1b33d0357754` (HEAD vigente; contém collector/testes idênticos desde PR #39 — PRs #40–#43 tocaram só YAML/docs/marker).
- **Run:** **`29385668057`** — `data-engine-tests.yml`, evento **`workflow_dispatch`** (execução de evidência autorizada pelo Product Lead, 2026-07-15T03:05Z), conclusão **success**.
- **Contagem (count guard fail-closed):** `Ran 171 tests ... OK` **nas duas tentativas** (171/171 ×2, determinismo; 39 testes de video-collection inclusos) + repro harness 21/21 ×2 + golden digest.
- **Testes do canary visíveis passando nas duas tentativas:** `test_video_collection.Canary.test_key_header_only_never_leaks_to_url_body_or_logs` e `test_video_collection.Canary.test_page_token_never_reaches_the_logs`. O único output de log emitido por eles foi a linha permitida pelo spec §8 (`stop=source_exhausted pages=N` — estágio, classe de parada, ordinal); nenhuma key, token, URL ou body. Cobertura adicional: teste do caminho de falha nega o leak-set completo (canary, `pageToken`, DSN de banco, título, channel id, `raw_json`).

## 3. Seis confirmações negativas do canary (exigidas pelo Product Lead)

O canary §8.3 é teste unitário offline com fakes in-memory (`RoutingOpener`/`FakeSearchApi`/`FakeVideosApi`/`FakeConnection`):

1. **Não chama a YouTube Data API** — zero socket/egress (suite completa em ~0,25 s, incompatível com I/O de rede);
2. **Não consome quota** — nenhuma request real existe;
3. **Não cria `run_id`** — nenhum acesso a `report_runs`;
4. **Não escreve em `raw_youtube_search_pages`, `raw_youtube_videos` ou qualquer tabela** — sem conexão de banco real;
5. **Não utiliza nem contorna o SG-V7** — roda no `data-engine-tests.yml` (workflow de testes: `contents: read`, **zero secrets, zero Environment, zero DB, zero pip install**), caminho distinto do `video-collection.yml`; inputs, acknowledgement e required reviewer do SG-V7 intocados;
6. **Não expõe secrets/payloads/URLs sensíveis ao Sentry** — em dois níveis: não existe Sentry no processo (§1) e o canary prova a higiene do único sink real (§2).

## 4. Cláusula anti-drift (vinculante)

**Qualquer introdução futura de telemetria no caminho de coleta — SDK, DSN, wrapper de logging externo ou agente de observabilidade, em `services/data-engine`, nos workflows de coleta ou no Environment — REABRE `F1'-f` e exige novo `audit_secrets` de Security (matrix #8) antes de qualquer dispatch subsequente.** A ausência é o controle; sua quebra silenciosa é o risco que esta cláusula fecha.

## 5. Escopo explícito — placeholders da stack web

`SENTRY_DSN` e `NEXT_PUBLIC_SENTRY_DSN` em `.env.example` são placeholders **vazios** da stack web (Next.js) e estão **explicitamente fora do escopo deste closeout** enquanto a stack web **não compartilhar processo** com a coleta (hoje não compartilha: a coleta roda em job de Actions com runtime stdlib próprio). Se algum dia compartilharem processo, aplica-se a cláusula do §4.

## 6. Estado consolidado do F-1' — COMPLETO

| # | Condição | Estado | Base |
|---|---|---|---|
| `F1'-a` | Cap por-run 2.000 fail-closed | ✅ GREEN | código (PR #38) |
| `F1'-b` | Retry ≤ 2; `quota*` terminal; surplus ≤ 500 | ✅ GREEN | código + testes §8.4 (PR #38) |
| `F1'-c` | Alertas OD-V2 no GCP + quota 10k | ✅ GREEN | `SEC-0024 §1` (atestação E5a) |
| `F1'-d` | API-restriction + inventário + rotação | ✅ GREEN | `SEC-0024 §3` (atestações E5b/c/d) |
| `F1'-e` | Concurrency próprio | ✅ GREEN | YAML (PR #40) |
| **`F1'-f`** | Telemetria ausente + canary §8.3 | ✅ **GREEN — fechado aqui** | §1–§3 |
| `F1'-g` | F-2' audit_secrets do YAML | ✅ GREEN | PR #40 (+ `F2'-N1`, PR #39) |

## 7. Fronteira humana restante (NÃO tocada aqui)

- **SG-V7 — a única fronteira antes da primeira coleta real:** dispatch humano de `main` + `RUN-VIDEO-COLLECTION` + `I-UNDERSTAND-RAW-IS-IRREVERSIBLE` + aprovação do required reviewer do Environment. **NO-GO até ordem explícita do Product Lead.**
- **SG-6 (002):** NO-GO até existir `run_id` de vídeo §7-passed. `youtube-collection` segue ARMADO e OCIOSO (0 runs).
- **Vetos de pé:** `0007` PARKED; Fase 9/RLS VETADA; publish barrado até SG-8/P5-REPRO-01. Rotação da key ≈ 2026-10-03 + pós-run relevante.

---

## Handoff (per `docs/agents/handoff-template.md`)

**Tarefa:** `task_close_f1f_sentry_canary` · **Owners:** DevOps + Security (compilado pelo Product Orchestrator) · **Data:** 2026-07-15 · **Prioridade:** P1

**Objetivo:** fechar F1'-f — último item aberto do F-1' — por atestação de ausência de telemetria + canary §8.3 com evidência fresca no `main` vigente.

**Resultado:** ✅ **GREEN (co-sign).** Ausência estrutural verificada em três camadas (deps/YAML/Environment); canary verde ×2 no run `29385668057` sobre `13c2258`; seis confirmações negativas registradas; cláusula anti-drift vinculante; placeholders web fora de escopo.

**Arquivos criados/alterados:** `docs/security/SEC-0025-f1f-sentry-canary-closeout.md` (este doc) · `docs/data/SG-V6-data-collect-001-pre-arm-attestation.md` (adendo §11). **Nenhum outro arquivo tocado.**

**Intocados (constraint):** código, testes, workflows, `.armed`, Sentry, GCP, secrets, Environment, migrations (`0007` PARKED). Zero merge/dispatch/coleta/canary novo.

**Impacto no escopo:** MVP travado mantido; fecha condição de segurança pré-live sem tocar número, banco ou copy pública.

**Próximos passos:** SG-V7 é a única fronteira restante — dispatch humano multi-fator, decisão do Product Lead. Nada roda até lá.

**Open decisions:** nenhuma nova.

---

## AgentResult

```json
{
  "task_id": "task_close_f1f_sentry_canary",
  "agent": "security_agent",
  "status": "completed",
  "summary": "F1'-f GREEN (co-sign DevOps+Security). Ausencia estrutural de telemetria no caminho de coleta verificada em 3 camadas: data-engine stdlib pura (dependencies=[], zero sentry-sdk/import), video-collection.yml sem referencia a Sentry/DSN, Environment sem DSN (2 secrets + 3 vars conhecidos). Declaracao explicita: NAO houve scrub/desativacao de Sentry — Sentry nao integra este runtime; fechamento por atestacao de ausencia + canary par.8.3. Canary GREEN no main@13c225828f3f4030f8cc7c5ac25e1b33d0357754 via run 29385668057 (workflow_dispatch, 2026-07-15, success): 171/171 testes OK em DUAS tentativas (count guard fail-closed; 39 video-collection) + harness 21/21 x2; os dois testes Canary de video visiveis passando nas duas tentativas, unico log emitido = linha permitida pelo spec par.8. Seis confirmacoes negativas: sem YouTube API real, sem quota, sem run_id, sem escrita em raw_*/qualquer tabela, sem uso/bypass do SG-V7 (workflow de testes: contents:read, zero secrets/Environment/DB), sem exposicao ao Sentry. Clausula anti-drift vinculante: qualquer telemetria futura no caminho de coleta REABRE F1'-f + novo audit_secrets. Placeholders web SENTRY_DSN/NEXT_PUBLIC_SENTRY_DSN explicitamente fora de escopo enquanto nao compartilharem processo com a coleta. F-1' agora COMPLETO (a..g GREEN). Unica fronteira antes da 1a coleta real = SG-V7 humano multi-fator — NO-GO ate ordem explicita. Docs-only: zero valor sensivel; codigo/testes/workflows/marker/Sentry/GCP/secrets/Environment intocados.",
  "artifacts": [
    {
      "type": "review",
      "path": "docs/security/SEC-0025-f1f-sentry-canary-closeout.md",
      "description": "Closeout F1'-f: atestacao de ausencia de telemetria + canary par.8.3 com evidencia fresca (run 29385668057 @ 13c2258), seis confirmacoes negativas, clausula anti-drift, escopo web excluido."
    }
  ],
  "errors": [],
  "cosign_verdict": "approve",
  "notes": [
    "F1'-f fechado por ausencia estrutural, nao por configuracao: nao havia Sentry a scrubar — postura mais forte que a prevista em SEC-0023 RR-4.",
    "Evidencia fresca datada do proprio main vigente (13c2258), nao reaproveitada de SHA antigo."
  ],
  "next_recommendation": {
    "target_agent": "product_agent",
    "action": "record_decision",
    "priority": "high",
    "reason": "Checklist F-1' integralmente GREEN (a..g). A trilha DATA-COLLECT-001 esta ARMADA, OCIOSA e sem pendencia tecnica pre-live. A unica fronteira antes da primeira coleta real e o SG-V7: dispatch humano de main + RUN-VIDEO-COLLECTION + I-UNDERSTAND-RAW-IS-IRREVERSIBLE + required reviewer do Environment — decisao exclusiva do Product Lead, NO-GO ate ordem explicita. SG-6 depende do run_id par.7-passed desse dispatch. Publish segue barrado ate SG-8/P5-REPRO-01."
  }
}
```
