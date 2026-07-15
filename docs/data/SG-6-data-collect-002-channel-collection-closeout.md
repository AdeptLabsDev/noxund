# SG-6 — DATA-COLLECT-002 Channel Collection Closeout (Channel Data / 002)

## 1. Identificação

- **Documento:** closeout operacional do **SG-6** — primeira coleta de Channel Data da trilha `DATA-COLLECT-002`, consumindo o `run_id` de vídeo congelado e §7-passed do SG-V7. **Não** autoriza Channel Filter, scoring, SG-8 ou publish.
- **Trilha:** `DATA-COLLECT-002` — `channels.list → raw_youtube_channels`, run reusado (nunca criado aqui).
- **Gate:** SG-6 — dispatch humano multi-fator do `youtube-collection.yml` → collect → **§7 (set-equality channels↔videos) passa**.
- **Owner do registro:** Product Orchestrator. **Execução integral do gate:** Product Lead (C1+H0 credenciado, C2 dispatch, C3, C4). Agentes em modo **read-only** durante todo o ciclo.
- **Data:** 2026-07-15
- **Natureza:** DOCS-ONLY / RECORDS-ONLY — zero alteração de código, workflow, schema, marker, GCP, secrets, Supabase ou Environment.
- **Fontes vinculantes:** `docs/data/DATA-COLLECT-002-channel-data-collection-spec.md §5–§7`; `docs/infra/RUNBOOK-channel-data-collection.md`; `docs/data/SG-V7-data-collect-001-first-collection-closeout.md` (A6 — freeze do `run_id`); `docs/security/SEC-0026-a7-key-rotation-closeout.md` (A7); run de Actions `29452277396`.

## 2. Veredito

✅ **SG-6 COMPLETO.** Run **`29452277396`** (`workflow_dispatch`, `main` @ `fb2a836`, dispatch 2026-07-15T21:32Z, conclusão 23:36Z) — **success 3/3 jobs** (guard, collect, verify §7).

**O dataset do run `f0485de6-0d34-41cf-ab48-d46e483aa558` está COMPLETO e duplo-§7-passed: 500 vídeos + 146 canais.**

**Veredito §7 do canal (verbatim do log do verify):**
> `OK — Channel Data §7 completeness gate PASSED (set-equality, one-row, verbatim, NULL!=0, SEC-F08).`

⛔ **Este doc não autoriza nada downstream.** Channel Filter, scoring, relatório, SG-8 e publish permanecem atrás de ordens próprias (§8).

## 3. Cadeia humana — C1–C4 e H0

| Checkpoint | Conteúdo | Estado |
|---|---|---|
| **C1 + H0** | GO + revalidação pré-dispatch **9/9 GREEN**, incluindo os atos credenciados do Product Lead: identity check do run (`status='collecting'`, `collected_video_count=500`, `youtube_quota_used=1210`, exatamente 1 linha; 500 vídeos; **146 canais distintos**; `raw_youtube_channels=0`) e **reexecução read-only do verify §7 de vídeo ao vivo** (`OK — Video Data §7 completeness gate PASSED`) | ✅ |
| **C2** | Dispatch humano com os 3 inputs literais: `RUN-CHANNEL-COLLECTION` · `f0485de6-0d34-41cf-ab48-d46e483aa558` · `I-UNDERSTAND-RAW-IS-IRREVERSIBLE`; guard 3/3 (frases verbatim, shape UUID, SEC-F18 `refs/heads/main`, preflight ARMED com os 4 artefatos) | ✅ |
| **C3** | Aprovação do collect (required reviewer do Environment `youtube-collection`) | ✅ |
| **C4** | Aprovação do verify §7 — precedida de relatório pré-C4 do Orchestrator (telemetria, higiene, anomalias: nenhuma) | ✅ |
| **C5** | Tratamento de falha | **não acionado** — zero falhas no ciclo |

O aceite consciente do Product Lead ao contrato de whole-run invalidation (registrado no GO de C1) **não precisou ser exercido**: o caminho de falha nunca executou.

## 4. Métricas e evidências da coleta (run `29452277396`)

| Métrica | Valor | Evidência |
|---|---|---|
| `run_id` (reusado, nunca criado) | `f0485de6-0d34-41cf-ab48-d46e483aa558` | guard (`RUN_ID:` verbatim) + collector (`run … complete (146 channels)`) |
| Canais persistidos | **146** — exatamente os 146 `channel_id` distintos do snapshot de vídeo | log + §7 set-equality |
| Batches | **3** (50 + 50 + 46), todos `batch collected` | log do collect |
| Quota consumida | **3 unidades** (3 × `channels.list` @ 1 unid; ledger do dia ≈ 1.214 de 10.000) | aritmética por chamada |
| Duração da coleta | ~1,2 s | timestamps do log |
| Retry / WARN / ERROR / omissões | **zero** — `assert_complete(requested, collected)` passou 146/146 in-process (um canal omitido/DC2-01 teria falhado o job) | log completo inspecionado |
| Higiene de log | ✅ 0 padrões de key (`?key=`/`AIzaSy…`), 0 `pageToken`, 0 DSN em claro (2 hits de scan inspecionados linha a linha = ecos de código-fonte do script: template de URL com nomes de variáveis + comentário) | scan dedicado |
| Driver | `driver contract OK — psycopg 3.3.4 (pinned, hash-verified)` — **o fix do PR #45 está agora provado em AMBAS as pipelines** (001 no run `29446423135`; 002 neste run) | log do collect |
| Escrita | INSERT-only em `raw_youtube_channels`, 1 linha/canal, chave `(run_id, channel_id)`, trigger-imutável | §7 one-row + schema |

## 5. Estado do contrato — `report_runs.status='collecting'` é o esperado

`report_runs.status` permaneceu **`'collecting'`** do início ao fim — e este é o **estado correto do contrato atual**: o finalize do vídeo escreve apenas contadores (`collected_video_count`, `youtube_quota_used`); a coleta de canais não transiciona status; `'processed'` pertence a fase posterior do enum (`created → collecting → processed → published`, com `failed` terminal). **O sucesso da coleta é determinado pelos gates §7 (vídeo e canal, ambos PASSED) e pela ausência de `'failed'`** — o único gravador de `'failed'` é o caminho de falha do collector, que nunca executou neste ciclo.

## 6. Rotação da key — nova rotação NÃO exigida após o SG-6

Registro explícito: **não foi exigida nova rotação da `YOUTUBE_API_KEY` após o run do SG-6.** Fundamentos: a key havia sido **rotacionada horas antes** no mesmo dia (A7, `SEC-0026`, E7a–E7f GREEN); **não houve exposição** no run (higiene de log verificada, header-only); o consumo foi de **3 unidades**. O relógio vigente permanece: deadline ≈ **2026-10-13** (≤90d) + gatilhos extraordinários (`SEC-0023 §8`, F1'-d).

## 7. Decisões abertas registradas (nenhuma decidida aqui)

- **H2 — OPEN DECISION pós-SG-6 (Product Lead):** refinar a semântica de falha do collector de canais (distinguir falha de completude — que marca `'failed'` — de falha transitória/pré-coleta — que falharia o job **sem** invalidar o run compartilhado, com registro possível via `audit_events`, zero schema). Exige emenda de código + `DATA-COLLECT-002 §6` + revisões Data/AI + Database + Security. A revisão pré-C1 que originou esta OD está registrada em conversa (2026-07-15); o contrato atual permanece vigente e foi honrado neste ciclo.
- Permanecem abertas, **fora deste PR**: mitigação permanente do RO-1 (auto-pause); correção documental `aws-0`/`aws-1` (INFRA-0001/0002).

## 8. Fronteiras e vetos (pós-closeout)

- **SG-8 / P5-REPRO-01 → próxima fronteira OBRIGATÓRIA antes de qualquer publish.** Nenhum número deste dataset chega a produtor sem o harness de reprodutibilidade passar.
- **Channel Filter / scoring / relatório → downstream por ordem própria** do Product Lead — não preparados nem autorizados aqui.
- **Vetos de pé:** `0007`/producer_events **PARKED**; Fase 9/RLS **VETADA**; zero coleta nova sem novo ciclo humano completo; ambas as pipelines de volta ao estado **ARMED & OCIOSO**.

## 9. Restrições honradas / Intocados

- **Docs-only.** Nenhum código, workflow, schema, migration, marker, secret, GCP, Supabase ou Environment tocado.
- **Sem correção aws-0/aws-1, sem mitigação RO-1, sem mudança H2** — explicitamente excluídos por ordem.
- **Zero valor sensível:** apenas nomes de secrets/vars e o project ref; nenhum valor, connection string ou credencial.
- **Runs preservados:** todos os runs de coleta do dia intactos (`run_attempt=1`), incluindo as duas falhas limpas do SG-V7.

---

## Handoff (per `docs/agents/handoff-template.md`)

**Tarefa:** `task_sg6_closeout_channel_collection` · **Owner:** Product Orchestrator (execução do gate: Product Lead) · **Data:** 2026-07-15 · **Prioridade:** P1

**Objetivo:** fechar o SG-6 no registro — primeira coleta de Channel Data, dataset completo duplo-§7-passed, cadeia humana C1–C4 + H0, estado do contrato e decisões abertas.

**Resultado:** ✅ SG-6 COMPLETO. Run `29452277396` success 3/3; 146 canais para o run `f0485de6` (3 batches 50/50/46, 3 unid, zero anomalias); §7 do canal PASSED verbatim; PR #45 provado nas duas pipelines; `status='collecting'` confirmado como estado esperado; rotação adicional não exigida (A7 horas antes, zero exposição, 3 unid).

**Arquivos criados/alterados:** `docs/data/SG-6-data-collect-002-channel-collection-closeout.md` (este doc). **Nenhum outro arquivo tocado.**

**Impacto no escopo:** MVP travado mantido. O dataset da vertical está completo e auditável — pré-condição de todo o downstream determinístico (Channel Filter → scoring → Hotspot Report).

**Próximos passos:** SG-8/P5-REPRO-01 antes de qualquer publish; Channel Filter/scoring por ordem própria; ODs abertas (H2, RO-1, aws-docs) aguardam decisão do Product Lead.

**Open decisions:** H2 (registrada em §7); RO-1 e aws-0/aws-1 (pré-existentes, inalteradas).

---

## AgentResult

```json
{
  "task_id": "task_sg6_closeout_channel_collection",
  "agent": "product_agent",
  "status": "completed",
  "summary": "SG-6 COMPLETO e registrado. Run 29452277396 (workflow_dispatch @ fb2a836) success 3/3: primeira coleta de Channel Data da trilha DATA-COLLECT-002, consumindo o run_id congelado f0485de6-0d34-41cf-ab48-d46e483aa558 (nunca criando run). Dataset agora COMPLETO e duplo-par.7-passed: 500 videos + 146 canais. Coleta: 3 batches (50/50/46), 3 unidades de quota (channels.list 1/chamada; ledger do dia ~1.214/10k), ~1,2s, zero retry/WARN/ERROR/omissao (assert_complete 146/146 in-process), higiene de log integra (0 key/pageToken/DSN; 2 hits de scan = ecos de codigo-fonte, inspecionados), driver contract OK psycopg 3.3.4 — fix do PR #45 provado em AMBAS as pipelines. Veredito par.7 verbatim: 'OK — Channel Data par.7 completeness gate PASSED (set-equality, one-row, verbatim, NULL!=0, SEC-F08).' Cadeia humana integral: C1+H0 9/9 GREEN (identity check credenciado + re-execucao ao vivo do verify par.7 de video), C2 com 3 inputs literais, C3/C4 aprovacoes de Environment; agentes read-only; C5 nunca acionado. report_runs.status='collecting' do inicio ao fim = estado ESPERADO do contrato (finalize escreve contadores; 'processed' e fase posterior; sucesso = gates par.7 + ausencia de 'failed'). Rotacao adicional NAO exigida pos-SG-6 (key rotacionada horas antes via A7/SEC-0026, zero exposicao, 3 unidades). H2 registrada como OPEN DECISION pos-SG-6. Proxima fronteira obrigatoria pre-publish = SG-8/P5-REPRO-01. Excluidos por ordem: aws-0/aws-1, RO-1, mudanca H2, Channel Filter/scoring/SG-8/publish.",
  "artifacts": [
    {
      "type": "review",
      "path": "docs/data/SG-6-data-collect-002-channel-collection-closeout.md",
      "description": "Closeout SG-6: dataset completo duplo-par.7-passed (500 videos + 146 canais), metricas da coleta, cadeia C1-C4 + H0, estado do contrato, rotacao nao exigida, ODs abertas, fronteira SG-8."
    }
  ],
  "errors": [],
  "next_recommendation": {
    "target_agent": "product_agent",
    "action": "record_decision",
    "priority": "high",
    "reason": "Dataset da vertical completo e auditavel. Fronteira obrigatoria antes de qualquer publish = SG-8/P5-REPRO-01; Channel Filter/scoring sao downstream por ordem propria do Product Lead. ODs abertas aguardando decisao: H2 (semantica de falha), RO-1 (auto-pause), correcao docs aws-0/aws-1."
  }
}
```
