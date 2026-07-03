# SEC-0016 — Security Audit (audit_secrets) · Contrato de coleta DATA-COLLECT-001 (SEC-F23)

- **Task:** `task_collection_spec_audit_secrets_sec_f23` · **Action:** `audit_secrets` · **Agent:** `security_agent`
- **Data:** 2026-06-28
- **Alvo:** `docs/data/DATA-COLLECT-001-youtube-collection-spec.md` · `docs/data/HANDOFF-task_dataengine_define_collection_spec.md`
- **Defesa de schema correlata:** CHECK `*_no_request_context` (SEC-F08) em `supabase/migrations/20260620000004_phase4_raw_youtube_snapshots.sql` (já liberado em SEC-0012).
- **Origem do gate:** **SEC-F23** (carry-forward que abri em SEC-0012 §1/§3) · cross-refs DATA-AI-0007 §3, DEC-0013.
- **Mandato:** `audit_secrets` — desenho de secrets/payload do contrato de coleta. **Gate BLOQUEANTE da 1ª coleta real.** Poder de veto. Silêncio ≠ aprovação.

---

## 0. Veredito

✅ **LIBERADO — SEM BLOQUEIO no contrato. SEC-F23 fechado na camada de desenho.** O contrato DATA-COLLECT-001 endereça os **três** pilares do SEC-F23 de forma correta, testável e fail-closed: **(1) body-only scrub** autoritativo no coletor (com o CHECK SEC-F08 como defesa-em-profundidade, não substituto); **(2) injeção da `YOUTUBE_API_KEY`** server-only, com proibição explícita em **todo** canal de vazamento (repo/log/payload/CLI/`NEXT_PUBLIC_*`/banco/`AgentResult`/`report_runs`); **(3) higiene de log** por allow/deny-list explícita + **teste de canary secret**. Nenhuma correção exigida no spec.

**Ressalva de fechamento (honesta, não-bloqueante para o spec):** o SEC-F23 só fica **integralmente** fechado para a 1ª coleta real quando **(a)** os testes obrigatórios §8.1–§8.5 rodarem **verdes** na implementação do job e **(b)** o DevOps fechar o mecanismo concreto de injeção + scrubbing do Sentry. Isso **não** é defeito do contrato — o próprio spec eleva ambos a gate pré-live (§8/§10). Libero o que é meu (o desenho); nomeio o residual de implementação/DevOps como a parte restante do mesmo gate. **Nenhum hit real na API até esses dois residuais fecharem.**

---

## 1. Pilar 1 — body-only scrub → ✅ (autoritativo no coletor + alinhado ao SEC-F08)

| Exigência SEC-F23 | Veredito | Evidência no spec |
|---|---|---|
| Persistir **só o body** da resposta | ✅ | §3.3: `response_json` = "body JSON completo… verbatim; nunca envelope HTTP/SDK". §4.1: "Extrair somente o body". §4.3: `raw_json` = objeto `item` do body, "não é o envelope de transporte". §8: "Persistir somente o body (`response.data`/equivalente)". |
| Rejeitar envelope request/config/headers/key | ✅ | §8: "Nunca persistir cliente, request, URL, headers, config, stack trace ou envelope axios/fetch." |
| Scrub **autoritativo no coletor** (CHECK é defesa adicional, não substituto) | ✅ | §8: "Os CHECKs SEC-F08 do schema são defesa adicional, não substituem o scrub no coletor." **Exatamente a divisão que exigi em SEC-F23**: schema = defesa-em-profundidade top-level; pipeline = scrub autoritativo. |
| Alinhamento byte-a-byte ao CHECK SEC-F08 | ✅ | §8 teste 2 rejeita top-level `config`/`request`/`headers`/`authorization`/`key` — **conjunto idêntico** ao `?| array['config','request','headers','authorization','key']` da migration Fase 4. As duas camadas batem. |
| Verificável | ✅ | §8 teste 1: spy do adaptador comprova que recebe **body, não envelope**. §7: gate de completude exige "`response_json`/`raw_json`… sem envelope de request". |

Nota (não-risco): §4.3 preserva thumbnails/URL **do próprio YouTube** (CDN público `i.ytimg.com`) no `raw_json` — não é a URL de request com `?key=`; zero credencial. O body do YouTube nunca ecoa a API key ⇒ body-only é secret-free por construção.

## 2. Pilar 2 — injeção da `YOUTUBE_API_KEY` → ✅ (server-only, todos os canais fechados)

| Canal de vazamento | Veredito | Evidência |
|---|---|---|
| Repo / bundle | ✅ | Key nunca no spec; §8: injetada server-side por mecanismo aprovado por Security/DevOps; nunca `NEXT_PUBLIC_*`. |
| Payload de tarefa / `TaskCommand` | ✅ | §8: "O `data_agent` não define política de secrets e **não recebe a key no `TaskCommand`**" (consistente com regra global #6 — nunca pedir secret em payload). |
| CLI / banco | ✅ | §8: "nunca é argumento de CLI, campo de banco". |
| URL persistida/logada | ✅ | §3.1: "Não anexar a API key a nenhum objeto que será persistido ou logado." §8 proíbe "URL com query string" em log (a key viaja em `?key=` na YouTube Data API v3). |
| Stack trace / erro estruturado | ✅ | §8: nunca persistir "stack trace… envelope axios/fetch"; "detalhe técnico sensível não entra em `report_runs` nem no `AgentResult`". §2.5: `youtube_quota_used` "não contém request, key ou payload". |

Cobertura **completa** dos canais. Reforça SEC-F12 (sem material de credencial em tabelas/`NEXT_PUBLIC_`).

## 3. Pilar 3 — higiene de log (zero secret + zero PII) → ✅

- **Allow-list (§8):** `run_id`, estágio, endpoint nominal, ordinal de página/lote, classe de status HTTP, tentativa, código de erro, contador de quota — todos identificadores/métricas operacionais não-sensíveis. ✅
- **Deny-list (§8):** API key, Authorization, **URL com query string**, request/response body, **título**, `pageToken`, **IDs em massa**, objeto de config. ✅ Cobre secret **e** o vetor de PII/conteúdo (título é metadado público de criador, mas sem razão operacional para logar — corretamente proibido; alinhado a SEC-F10).
- **Prova fail-closed (§8 teste 3):** captura de logs/Sentry com **canary secret** comprova ausência do canary, Authorization, query string, body e page token. ✅ É o método gold-standard para provar não-vazamento — exatamente o que SEC-F10/SEC-F23 pedem.
- **Erro/quota sem vazar credencial (§6/§8):** falha é estruturada e fail-closed; mensagem externa sanitizada. ✅

Sobre PII: este caminho toca **metadado público do YouTube** (títulos/canais), não PII de produtor (SEC-F09 é `applications`/`wtp_responses`, fora daqui); o raw é default-deny interno (SEC-0012). Sem nova superfície de PII; logs ainda assim escrubam título/body.

## 4. Recomendação de hardening (NÃO-bloqueante)

**Preferir o header `X-Goog-Api-Key` ao parâmetro de query `?key=`.** Uma URL com query string é muito mais facilmente capturada por engano (logger de erro de axios, breadcrumb default do Sentry, traço de exceção) do que um header redatável. O contrato já **força o resultado** correto por outras vias (deny-list de "URL com query string" + teste 3 de canary), então isto é **defesa-em-profundidade**, não condição. Registro como melhoria de engenharia a considerar na implementação do job.

## 5. Residual para fechamento INTEGRAL do SEC-F23 (pré-live, fora do spec)

O desenho está liberado; o gate "nenhuma coleta real até SEC-F23 fechar" só se completa com:

1. **Implementação + testes verdes (§8.1–§8.5):** spy body-vs-envelope; aceite de payload limpo / rejeição de top-level `config/request/headers/authorization/key`; canary secret ausente de logs/Sentry; quota/erro deixam a run `failed`/inelegível; retry/restart não duplica raw. **Estes testes são a evidência que converte o desenho aprovado em garantia operacional.**
2. **DevOps (matrix #8, gate à parte):** mecanismo concreto de injeção da key (provável `configure_env` — **sensível/humano-gated**) + configuração do scrubber do Sentry (que por default captura URL/request — deve ser desligado/redatado para o teste 3 fechar verde). Coordenado comigo.

Ambos já constam como gate pré-live no spec (§8/§10) e no handoff (§9). **Não bloqueiam a aprovação do contrato; bloqueiam o 1º hit real.**

## 6. Quadro do gate SEC-F23 (1ª coleta real)

| Componente do gate | Estado |
|---|---|
| **Desenho do contrato de coleta (body-only / key / log hygiene) — Security `audit_secrets`** | ✅ **LIBERADO — este doc (SEC-0016)** |
| Implementação do job + testes §8.1–§8.5 verdes | ⏳ pré-live (evidência converte desenho em garantia) |
| DevOps — injeção concreta da key (`configure_env`, sensível) + scrubbing do Sentry | ⏳ pré-live (matrix #8, gate à parte, coordenado) |
| Product Orchestrator — coleta dos ~500 / parâmetros / paginação | ⏳ pré-live (não é meu gate) |
| P5-REPRO-01 (prova de 2 rodadas) | ⏳ gate do 1º **publish**, não da coleta — fora daqui |
| Fase 9 — RLS Policies + VIEW pública de `report_items` (SEC-F03) | ⛔ veto à parte (SEC-0001 §0) — não tocado |

**Como o SEC-F23 cai por completo:** desenho liberado aqui → implementação roda os 5 testes verdes → DevOps fecha injeção + Sentry → só então o 1º hit real na API é permitido. Como required reviewer/owner de secrets, re-confirmo o teste 3 (canary) e a injeção antes do live. Silêncio de Security ≠ aprovação — este doc é a liberação explícita do desenho, **não** autorização de coleta.
