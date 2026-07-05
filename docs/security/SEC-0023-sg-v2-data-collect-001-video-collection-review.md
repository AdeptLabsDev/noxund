# SEC-0023 — Security Review (audit_secrets) · SG-V2 · Coleta de vídeo upstream DATA-COLLECT-001 (`search.list → raw_youtube_search_pages`, `videos.list → raw_youtube_videos`)

- **Task:** `task_security_review_sg_v2_video_collection` · **Ação executada:** `audit_secrets` (dado/secret/key/quota) · **Agent:** `security_agent`
- **Data:** 2026-07-05
- **Gate:** **SG-V2** da trilha `DATA-COLLECT-001` (video track) — `HANDOFF-data-collect-001-video-track.md §7.1` + `SG-V1-...-product-ratification.md §8`.
- **Matriz:** `agent-review-matrix.md` **#8** (deploy/mudança de ambiente → DevOps + Security) + gatilhos "Gestão de secrets / API keys" e "Segurança de logs".
- **Alvos revisados (leitura, zero mutação):**
  - `docs/data/HANDOFF-data-collect-001-video-track.md`
  - `docs/data/SG-V1-data-collect-001-product-ratification.md`
  - `docs/data/DATA-COLLECT-001-youtube-collection-spec.md` (§2 run_id, §3 search.list, §4 videos.list, §5 append-only, §6 fail-closed, §7 gate, §8 SEC-F23)
  - `docs/product/decisions/DEC-0018-gated-channel-data-collection-track.md` (template de gate + F-1)
- **Precedentes que este doc herda e re-escopa:** `SEC-0016` (audit_secrets do spec 001, SEC-F23 fechado na camada de desenho) · `SEC-0012` (CHECK SEC-F08 no schema Fase 4, já vivo) · `SEC-0019` (F-1/F-2 do 002) · `SEC-0021`/`SEC-0022` (F-1 fechado por atestação + Environment `youtube-collection` provisionado — mas **escopado ao caminho de ~10 unid do canal**).
- **Mandato:** **REVIEW/DESIGN-ONLY.** Zero código, zero workflow, zero migration, zero teste, zero verify SQL, zero API, zero secret, zero dispatch, zero coleta, **zero valor de secret neste doc**. Poder de veto. **Silêncio ≠ aprovação.** Não autoriza execução — produz **veredito + tabela de controles + checklist F-1' + recomendação OD-V1/OD-V2**.

---

## 0. Veredito

✅ **SG-V2 (revisão/design) → GO. Desenho de segurança da coleta de vídeo LIBERADO na minha camada. Nenhum defeito de segurança de desenho.** A trilha de vídeo herda um desenho **já auditado e correto** (SEC-0016 fechou SEC-F23 no nível de contrato; SEC-0012 deixou o CHECK SEC-F08 **vivo** no schema Fase 4) e não introduz novo defeito de desenho. Os seis eixos do meu escopo fecham de forma testável e **fail-closed**: **(1)** SEC-F23 do body de vídeo (`title`/stats) — dado público, default-deny, body-only autoritativo; **(2)** SEC-F08 anti-envelope — CHECK top-level já vivo + scrub body-only; **(3)** proibição de `pageToken`/`title`/query-URL/body em log; **(4)** injeção server-only da `YOUTUBE_API_KEY` por todos os canais; **(5)** re-escopo **F-1'** da quota de vídeo (~1010 unid/run vs. ~10 do canal); **(6)** topologia de Environment (OD-V1).

⚠️ **Este doc NÃO autoriza coleta, dispatch, arm nem provisionamento.** Ele libera **o desenho** para avançar SG-V3 (Database) e, depois, SG-V4/SG-V5 (código inerte/offline) **em paralelo**. O delta materialmente novo vs. o 002 — a quota **~100× mais pesada** do `search.list` — é re-escopado aqui como **condição de execução (F-1', SG-V6/SG-V7)**, não como bloqueio de desenho.

**Condições que ELEVO a bloqueantes de gate (findings, não sugestões):**

- **F-1' (quota de vídeo · SG-V6 `configure_env` / SG-V7 dispatch · blocking do 1º run real):** o Environment/pipeline **DEVE** impor, antes do 1º dispatch de vídeo — **cap de quota por-run**, **budget de retry versionado** (com `quotaExceeded`/`dailyLimitExceeded` **nunca** retentados), **alerta de quota re-confirmado para o perfil de ~1010 unid** (o alerta atual foi calibrado para os ~10 unid do canal) e **API-restriction re-confirmada** (YouTube Data API v3, **mesma** key, sem key nova). Re-escopo do F-1 do DEC-0018 para o caminho pesado. Thresholds exatos = **OD-V2** (escalar ao Product Lead).
- **F-2' (audit_secrets do YAML de vídeo · SG-V6 `define_pipeline` · blocking do 1º run real):** o workflow de vídeo é **arquivo novo** com **semântica de criação de run** (gera UUID, escreve `report_runs`; **sem** `run_id` de input) e egress mais pesado → exige `audit_secrets` de Security **SEPARADO deste doc** (matrix #8, desvio de template). **Não herda** SEC-0016 nem esta liberação. Espelha o F-2 do DEC-0018.

**Recomendação OD-V1 (Environment):** **REUTILIZAR o Environment `youtube-collection`** já provisionado/co-assinado (SEC-0022), com **workflow de vídeo SEPARADO** (arm marker próprio, frase de confirmação própria, SHA-pins próprios, F-2' próprio). **Não** provisionar um 2º Environment — isso apenas **duplicaria** a key portadora de custo (§3).
**Recomendação OD-V2 (F-1'):** cap por-run **hard ≈ 2.000 unid** (nominal ~1010), retry **≤ 2/chamada** em classes transitórias com `quota*` **terminal**, surplus de retry **≤ ~500 unid/run**, alerta per-run **> 1.500 unid** + alertas GCP diários **50% / 80%** de 10k re-confirmados para o perfil de vídeo (§4/§8). São **floors/postura**; os números finais são decisão do Product Lead.

---

## 1. Eixo 1 — SEC-F23 / body de vídeo (`title`, stats, `raw_json`) → ✅ aceitável, minimização preservada

**Contexto.** `videos.list` com `part=statistics,snippet` (§4.1) traz, por item: `snippet.title`, `snippet.channelId`, `snippet.publishedAt`, `snippet.description`, `snippet.thumbnails`, `snippet.tags?`, e `statistics.{viewCount,likeCount,commentCount}`. A v1 **projeta em coluna** só `video_id/channel_id/title/published_at/views/likes/comments`; `description`/thumbnails/tags **viajam só no `raw_json`** (§4.3).

| Exigência SEC-F23 | Veredito | Evidência |
|---|---|---|
| É dado **público**, não PII de produtor (SEC-F09 = `applications`/`wtp_responses`) | ✅ | Conteúdo publicado pelo próprio criador na API pública do YouTube. Fora do perímetro SEC-F09. |
| Coerência com o precedente já liberado | ✅ | Mesma postura de `raw_youtube_videos.raw_json` liberada em SEC-0012/SEC-0016 e do canal em SEC-0019 §1. Mesma tabela imutável default-deny. |
| **Minimização de parts** | ✅ | `part=statistics,snippet` é o mínimo que cobre o gate §7. **Omissão deliberada** de `contentDetails`/`topicDetails`/`localizations`/`status`/`player`/`liveStreamingDetails` (§3.1/§4.1). `fields` **não** é usado (raw verbatim), mas o conjunto de parts limita a superfície. |
| **Minimização de projeção** (superfície consultável) | ✅ | Só `title` (+ stats) vira coluna. `description`/thumbnails/tags **não** são projetados nem indexados → sem caminho de query barato para varrer texto livre. |
| **Confinamento** (default-deny) | ✅ | `raw_youtube_videos` é RLS-on + `revoke` anon/authenticated + **zero policy/zero view** (Fase 9 VETADA, SEC-0012 §3). Produtor nunca lê raw; vê `report_items` (Fase 5). |
| `NULL≠0` estrutural nas stats | ✅ | §4.2: "estatística ausente permanece `NULL`, nunca zero fabricado". Impede número falso (non-negotiable). |
| Higiene de log cobre o texto livre | ✅ | §8 deny-list inclui **`title`** e request/response body → `description`/tags nunca têm razão operacional para logar (SEC-F10). |

**Residual aceito, nomeado com honestidade (não-bloqueante para v1):** `snippet.title`/`snippet.description` são texto livre de terceiro e **podem conter**, por vontade do criador, strings que parecem segredo (ex.: alguém colou a própria chave/token na descrição) ou PII de terceiros. Como `raw_json` é **verbatim + imutável + `NOT NULL`**, **não** scrubamos texto aninhado sem quebrar verbatim/reprodutibilidade (P5-REPRO-01). Aceito para v1 porque o raio de explosão é contido por **4 camadas**: (i) é público (o criador publicou); (ii) default-deny interno; (iii) nunca exposto publicamente (relatório mostra `report_items`, não raw); (iv) a VIEW pública de raw é da **Fase 9, VETADA**. **Gatilho de re-review:** se raw de vídeo **algum dia** for exposto por view/endpoint → esta postura reabre (já coberto pelo veto de Fase 9). *Idêntico ao residual aceito em SEC-0019 §1 para canal — coerência mantida.*

**Nota (não-risco):** thumbnails no `raw_json` são URLs de CDN público do YouTube (`i.ytimg.com`), **não** a URL de request com `?key=` — zero credencial. O body de `videos.list`/`search.list` **nunca ecoa a API key** ⇒ body-only é secret-free por construção (mesma conclusão SEC-0016 §1 / SEC-0019 §1).

**Veredito eixo 1:** ✅ **Ratificado** para o body de vídeo. SEC-F23 aceitável, com a condição permanente de não-expansão de parts e não-projeção de `description`/tags sem novo review.

## 2. Eixo 2 — SEC-F08 anti-envelope (`raw_youtube_search_pages` + `raw_youtube_videos`) → ✅ ratificado (CHECK já vivo)

Os dois CHECKs `*_no_request_context` já estão **aplicados** no schema Fase 4 (SEC-0012, L118–133) e liberados:

```sql
check (not (response_json ?| array['config','request','headers','authorization','key']))  -- search_pages
check (not (raw_json      ?| array['config','request','headers','authorization','key']))  -- videos
```

| Ponto de auditoria | Veredito | Detalhe |
|---|---|---|
| Rejeita envelope de transport/request | ✅ | `?|` testa **chaves top-level**. Envelope axios/fetch traz `config`/`request`/`headers` no topo → **barrado**. É o vetor que carregaria a key (URL `?key=`, header `Authorization`). |
| Zero falso-positivo no body de **search** | ✅ | Top-level de `search.list` = `{kind, etag, nextPageToken?, prevPageToken?, pageInfo, items}` — **nenhuma** chave proibida. `nextPageToken` é **saída legítima**, persistida verbatim no body (§3.3); é dado, não envelope. |
| Zero falso-positivo no body de **video item** | ✅ | Top-level do `item` = `{kind, etag, id, snippet, statistics}` — nenhuma chave proibida. |
| Conjunto idêntico coletor ↔ schema ↔ teste | ✅ | O reject-set do CHECK == o do teste §8.2 == o já liberado em SEC-0012. Três camadas concordam byte-a-byte. |
| Defesa-em-profundidade, **não** o autoritativo | ✅ | `?|` é top-level, não recursivo: não inspeciona `snippet.description`. O **scrub body-only** no coletor permanece o controle **autoritativo** (§8: "Os CHECKs SEC-F08 do schema são defesa adicional, não substituem o scrub"). Correto. |

**Veredito eixo 2:** ✅ **Ratificado.** Mesma barreira SEC-F08 de SEC-0012, aplicada aos dois raws de vídeo. Nenhum ALTER exigido (é gate de confirmação da Database no SG-V3, não meu apply).

## 3. Eixo 3 — `YOUTUBE_API_KEY` + Environment (OD-V1, matrix #8) → ✅ desenho aprovado; **reutilizar** Environment, YAML separado

**A key é a mesma — inevitável.** `search.list` e `videos.list` vivem no **mesmo projeto Google** que `channels.list`. Qualquer topologia de Environment usa a **mesma** `YOUTUBE_API_KEY`.

| Controle (desenho, herdado de SEC-0019/0022) | Veredito | Condição no track de vídeo |
|---|---|---|
| Injeção server-only; nunca CLI/banco/payload/`NEXT_PUBLIC_*`/`AgentResult` | ✅ | §8 do spec cobre **todos** os canais. Re-afirmado em SEC-0016 §2. |
| Transporte por header `X-Goog-Api-Key` (não `?key=`) | ✅ | Herança de SEC-0016 §4 / SEC-0019 §3. URL com query é mais fácil de vazar; header é redatável. |
| `main`-only antes dos secrets (SEC-F18) | ✅ | Provisionado e verificado por API em SEC-0022 §1. |
| Required reviewers (gate humano em runtime) | ✅ | `required_reviewer = User:AdeptLabsDev` (SEC-0022 §1). NOTE de reviewer único abaixo. |
| **Sem `SUPABASE_ACCESS_TOKEN`** (incapaz de `db push`) | ✅ | SEC-0022 §1. O track de vídeo **não** precisa dele. |
| **Sem `SUPABASE_SERVICE_ROLE_KEY`** (SEC-F19) | ✅ | Escrita via owner `postgres`/DB-password. Vale para o novo path de `report_runs` (STATE) também — o **row-guard** (Database SG-V3) é quem restringe, sem novo grant. |
| Actions SHA-pinadas (SEC-F17) | ⏳ | A verificar no **YAML de vídeo** (F-2', SG-V6). |
| `permissions: contents: read` | ⏳ | A verificar no YAML de vídeo (F-2'). |

### 3.1 OD-V1 — recomendação: **REUTILIZAR o Environment, SEPARAR o workflow**

**Recomendo REUSO do Environment `youtube-collection`** (o mesmo, dedicado, least-privilege, já co-assinado em SEC-0022) para o estágio de vídeo, com **workflow de vídeo em arquivo separado**. Fundamentos de segurança:

1. **Um 2º Environment DUPLICA a key portadora de custo.** Como a `YOUTUBE_API_KEY` é a **mesma** (mesmo projeto Google), um Environment dedicado guardaria **outra cópia** do mesmo segredo → **mais** cópias para vazar e rotacionar, não menos. Least-privilege é minimizar cópias de segredo — reuso é a escolha **menor-superfície**.
2. **A postura de segurança já provisionada é exatamente a que o vídeo precisa:** `main`-only (SEC-F18), required reviewers, **sem** ACCESS_TOKEN, **sem** service-role, path DB least-privilege. Herdar > re-derivar (evita drift entre dois Environments).
3. **A separação que importa é no WORKFLOW, não no Environment.** Isolamento significativo — gatilho, frase de confirmação, **arm marker próprio**, SHA-pins, semântica de criação de run, `audit_secrets` próprio (F-2') — vive na camada de workflow. Um workflow de vídeo separado apontando para o **mesmo** Environment já entrega esse isolamento; duplicar o Environment não adiciona isolamento real, só cópias de secret.
4. **Reviewer único (SEC-0022 §4):** sem teams no GitHub, "DevOps" e "Security" são a mesma identidade `AdeptLabsDev`. Um 2º Environment **não** cria separação de deveres real — ela é por papel/agente no runtime, não por identidade. Logo o reuso não perde nada nesse eixo.

**Caveat honesto (liga OD-V1 a OD-V2):** reuso ⇒ **key/quota compartilhada** com o 002. Um retry storm do `search.list` (100 unid/página) pode esgotar a quota diária e **inanir** o 002 (e vice-versa). **Um Environment dedicado NÃO corrige isso** — a quota é do projeto/key, não do Environment. O que corrige é o **cap+alerta+concurrency do F-1' (OD-V2)**. Portanto: reuso é correto; o risco de quota compartilhada é endereçado em OD-V2, e o cap/alerta deve ser **project-aware**, não só per-run.

**Veredito eixo 3:** ✅ **Desenho aprovado.** OD-V1 → **reuso do Environment + workflow separado**. Decisão de design escalada ao Product Lead via Security/DevOps (é OPEN DECISION; não bloqueia SG-V2/SG-V3).

## 4. Eixo 4 (delta central) — F-1' · re-escopo de quota/custo do `search.list` → ⚠️ condição de gate (F-1')

**O delta materialmente novo vs. todo o 002.** O 002 (canal) foi atestado para **~10 unid/run** (SEC-0019 §4 / SEC-0022 §2). O caminho de vídeo é **~100× mais pesado por página**:

| Chamada | Custo unit. | Nº chamadas (nominal) | Subtotal |
|---|---|---|---|
| `search.list` (`part=snippet`, `maxResults=50`) | **100 unid** | ~10 páginas (500 ÷ 50) | ~1.000 |
| `videos.list` (`part=statistics,snippet`, lote 50) | **1 unid** | ~10 lotes | ~10 |
| **Total nominal / run** | | | **~1.010 unid (~10% da quota diária default de 10k)** |

**Risco (R1 do handoff).** `search.list` a 100 unid/chamada: um retry storm ou re-dispatch queima quota/billing rápido e pode **estourar o teto diário de 10k no meio da run** → fail-closed → run falha → quota desperdiçada → (com key compartilhada) inanição do 002. O erro de gate seria confundir **erro transitório** (5xx/rede — retry limitado) com **erro de quota** (`quotaExceeded`/`dailyLimitExceeded` — **nunca** retentar; retentar quota-error só queima mais).

**F-1' — controles exigidos (postura vinculante; números = OD-V2, escalar):**

1. **Cap de quota por-run (hard budget):** teto rígido por run, bem abaixo da quota diária. **Recomendo ≈ 2.000 unid** (~2× nominal, ~20% de 10k). Se `report_runs.youtube_quota_used` (contador já no schema, §2.5) projetar ultrapassar o cap → **fail-closed** (§6), sem `collected_video_count` de completude. Bounda o blast-radius de uma run a ≤ ~20% da quota diária.
2. **Budget de retry versionado (§6):** o spec já exige política versionada; F-1' fixa números:
   - `search.list`/`videos.list`: **≤ 2 retries transitórios/chamada** (3 tentativas), backoff exponencial, **só** em classe retryável (5xx, erro de rede, 429 rate-limit **com** backoff).
   - `quotaExceeded`/`dailyLimitExceeded`/`rateLimitExceeded` pós-budget = **terminal fail-closed**, **nunca** retentado (distinção quota≠transitório é o núcleo do F-1').
   - **Surplus de retry por-run ≤ ~500 unid** (≈5 páginas extras de search) antes de declarar falha terminal — impede o retry storm de caminhar silenciosamente até o teto diário.
3. **Alerta de quota (2 níveis):**
   - **Per-run:** alertar se uma única run exceder **~1.500 unid** (nominal +50%) — sinal de paginação/retry anômalos.
   - **GCP diário (F-1 carry, RE-CONFIRMAR):** o alerta configurado em SEC-0022 foi calibrado para o perfil de ~10 unid do canal. **F-1' exige re-confirmar** o alerta da YouTube Data API v3 para o perfil de **~1010 unid** — recomendo disparar em **50% (5k) e 80% (8k)** da quota diária, **antes** da exaustão, não depois. Como vídeo é ~100× mais pesado, 1–2 runs + retries num dia podem se aproximar do teto.
4. **API-restriction (RE-CONFIRMAR):** a **mesma** key já está restrita à *YouTube Data API v3* (SEC-0022 §2, por atestação out-of-band). **Nenhuma key nova.** F-1' re-confirma que a restrição e a rotação (≤90d / pós-run / troca de pessoal / suspeita de leak) seguem válidas para o uso mais pesado. Item de **atestação** (não repo-verificável), como em SEC-0022 §2. IP-restriction segue **N/A** (runners GitHub sem IP estático) — residual aceito de SEC-0021 §4, compensado por API-restriction + alerta + rotação.
5. **Concurrency:** o workflow de vídeo com `concurrency` próprio + `cancel-in-progress: false` (como o 002). Como key/quota é compartilhada com 002 (OD-V1 reuso), avaliar em `configure_env` um gate quota-aware entre 001 e 002 para não correrem pesado+leve simultaneamente rumo ao teto diário — residual de DevOps, nomeado.

**Veredito eixo 4:** ⚠️ **F-1' é condição de gate (SG-V6/SG-V7), não bloqueio de desenho.** A quota bem-limitada por construção (≤500 vídeos ⇒ ≤~10 páginas), mas o custo/página de 100 unid exige cap + retry budget + alerta re-calibrado + API-restriction re-confirmada **antes** do 1º dispatch. Thresholds exatos = **OD-V2**.

## 5. Eixo 5 — Higiene de log / `pageToken` proibido → ✅ desenho correto; Sentry-scrub é residual de DevOps

| Item | Veredito | Evidência |
|---|---|---|
| **Allow-list (§8)** | ✅ | `run_id`, estágio, endpoint nominal, ordinal de página/lote, classe HTTP, tentativa, código de erro, contador de quota — identificadores/métricas operacionais não-sensíveis. |
| **Deny-list (§8)** inclui **`pageToken`** | ✅ | `pageToken` é superfície de correção **e** de segurança: verbatim, na coluna `page_token` e no `nextPageToken` do body (dado), mas **proibido em log/Sentry**. Deny-list também barra API key, `Authorization`, **URL com query string**, request/response body, **`title`**, IDs em massa, config. |
| **Prova fail-closed (§8 teste 3)** | ✅ (design) | Canary secret comprova ausência do canary, `Authorization`, query string, body **e page token** em logs/Sentry. Gold-standard SEC-F10/SEC-F23. É teste de SG-V5 (código), não deste doc. |
| **`youtube_quota_used` sem vazar** | ✅ | §2.5: "não contém request, key ou payload e não converte falha em sucesso". |
| **Erro externo sanitizado** | ✅ | §6/§8: falha estruturada, detalhe técnico sensível não entra em `report_runs` nem `AgentResult`. |

**Residual (pré-live, DevOps, SG-V6):** o Sentry por default captura URL/params/breadcrumbs — o scrubber **deve ser desligado/redatado** para o canary §8.3 fechar verde (mesma condição de SEC-0016 §5 / SEC-0019 §8). Nomeado como pré-live no `configure_env`; não bloqueia desenho.

**Veredito eixo 5:** ✅ **Desenho de higiene correto.** `pageToken`/`title`/query-URL/body proibidos em log por deny-list + canary. Scrub do Sentry é residual de DevOps (SG-V6).

## 6. Eixo 6 — path novo de `report_runs` (STATE) → ✅ sem novo segredo/grant; row-guard é a trava (Database)

001 é o **1º path de CI que muta STATE de `report_runs`** (`created→collecting`; finalização única grava `collected_video_count`), diferente do 002 que só **reusa** o `run_id`. Ângulo de segurança:

- **Sem novo secret/grant:** a escrita usa o **mesmo** owner `postgres`/DB-password do Environment reusado; **nenhum** ACCESS_TOKEN, **nenhum** service-role (SEC-F19 preservado). Não abro superfície de credencial nova.
- **A trava é o `report_runs_row_guard`** (schema Fase 3): permite UPDATE de status/contador, **congela** identidade de coleta (keyword/vertical/janela), bloqueia DELETE/TRUNCATE. **Atomicidade** da finalização (`collecting → collected_video_count`) e a impossibilidade de crash `collecting`+`NULL` parecer completo são **gate da Database (SG-V3)**, não meu — confirmo apenas que **não exige novo privilégio** e que fail-closed (§6) impede snapshot elegível a partir de run parcial.

**Veredito eixo 6:** ✅ Do meu ângulo (secret/grant), o path de STATE **não** abre superfície nova. Atomicidade → Database SG-V3.

## 7. Tabela SG-V2 — controles de Security (veredito ponto a ponto)

| # | Controle de Security | Fonte | Estado |
|---|---|---|---|
| **SV2-01** | SEC-F23 body de vídeo (`title`/stats/`raw_json`) — público, minimizado, default-deny, `NULL≠0` | spec §4; SEC-0016 §1 | ✅ **ratificado** (§1) |
| **SV2-02** | SEC-F08 anti-envelope — CHECK top-level **já vivo** nos 2 raws + scrub body-only autoritativo | schema Fase 4; SEC-0012 | ✅ **ratificado** (§2) |
| **SV2-03** | Scrub **body-only** autoritativo no coletor (envelope/URL/headers/key nunca persistidos) | spec §3.3/§4.3/§8 | ✅ **desenho ok**; prova = teste §8.1 (SG-V5) |
| **SV2-04** | `YOUTUBE_API_KEY` server-only, todos os canais fechados; header `X-Goog-Api-Key` | spec §8; SEC-0016 §2 | ✅ **aprovado** (§3) |
| **SV2-05** | **`pageToken` proibido em log/Sentry** (+ `title`, query-URL, body, IDs em massa) | spec §8 | ✅ **desenho ok**; canary §8.3 (SG-V5) + Sentry-scrub (SG-V6) |
| **SV2-06** | Higiene de log: API key / DB password / connection string / query URL / `raw_json` / `title` / payload body — todos negados | spec §8; SEC-0016 §3 | ✅ **ratificado** (§5) |
| **SV2-07** | Environment least-privilege — sem ACCESS_TOKEN, sem service-role, `main`-only (SEC-F18) | SEC-0022 §1 | ✅ **herdado** (reuso, §3.1) |
| **SV2-08** | **OD-V1** — reuso vs. dedicado | handoff G7 | ✅ **recomendo REUSO + YAML separado** (§3.1) |
| **SV2-09** | **F-1'** — cap por-run + retry budget + alerta re-calibrado + API-restriction re-confirmada | handoff G6/R1 | ⚠️ **condição de gate** (§4) — **OD-V2** |
| **SV2-10** | path novo de STATE em `report_runs` — sem novo secret/grant | spec §2/§6 | ✅ **sem superfície nova** (§6); atomicidade → Database SG-V3 |
| **SV2-11** | **F-2'** — audit_secrets SEPARADO do YAML de vídeo (não herda este doc) | DEC-0018 F-2 | ⚠️ **gate futuro** (SG-V6) |
| **SV2-12** | Fail-closed sem vazamento de estado parcial (run parcial ≠ snapshot elegível) | spec §6/§7 | ✅ **confirmado** (§6) |

## 8. Checklist F-1' (pré-dispatch · SG-V6/SG-V7 · fail-closed)

**Nenhuma chamada real a `search.list`/`videos.list` antes de TODOS verdes.** Itens repo-verificáveis vs. atestação out-of-band marcados.

| # | Condição F-1' | Owner | Verificação | Estado |
|---|---|---|---|---|
| **F1'-a** | **Cap de quota por-run** (hard budget; recomendo ≈2.000 unid) imposto no job/pipeline; ultrapassagem projetada → fail-closed | Data/AI + DevOps | repo (código/YAML) | ⏳ SG-V5/V6 |
| **F1'-b** | **Retry ≤ 2/chamada** em classe transitória; `quotaExceeded`/`dailyLimitExceeded` **terminal, nunca retentado**; surplus ≤ ~500 unid/run | Data/AI | repo + teste §8.4 | ⏳ SG-V5 |
| **F1'-c** | **Alerta per-run** (> ~1.500 unid) + **alertas GCP diários** (50%/80% de 10k) **RE-CONFIRMADOS para o perfil ~1010** (não o de ~10 do canal) | DevOps + Security (co-sign) | atestação out-of-band | ⏳ SG-V6 |
| **F1'-d** | **API-restriction** da **mesma** key = *YouTube Data API v3* re-confirmada; **sem key nova**; rotação (≤90d/pós-run/pessoal/leak) válida | Security (atesta) | atestação out-of-band | ⏳ SG-V6 |
| **F1'-e** | **Concurrency** próprio do workflow de vídeo (`cancel-in-progress: false`) + avaliar gate quota-aware 001↔002 (key compartilhada) | DevOps | repo (YAML) | ⏳ SG-V6 |
| **F1'-f** | **Sentry-scrub** desligado/redatado (URL/params/breadcrumbs) p/ canary §8.3 fechar | DevOps + Security | atestação + teste | ⏳ SG-V6 |
| **F1'-g** | **F-2'** — audit_secrets SEPARADO do YAML de vídeo (SHA-pin SEC-F17, `contents:read`, SEC-F18, header `X-Goog-Api-Key`, service-role não usada) | Security (bloqueante) | repo (YAML) | ⏳ SG-V6 |

*IP-restriction permanece **N/A** (runners sem IP estático) — residual aceito de SEC-0021 §4, compensado por F1'-c/d.*

## 9. Riscos residuais

| # | Risco residual | Severidade | Mitigação / postura |
|---|---|---|---|
| **RR-1** | **Key/quota compartilhada com 002** (inevitável: mesmo projeto Google). Retry storm de 001 pode inanir 002. | Média | **Environment dedicado NÃO corrige** (quota é do projeto). Corrigido por F-1' cap+alerta **project-aware** + concurrency (OD-V2, §4/F1'-e). |
| **RR-2** | **IP-restriction N/A** (runners GitHub sem IP estático) | Baixa | Carry-forward aceito (SEC-0021 §4); compensado por API-restriction + alerta + rotação (F1'-c/d). |
| **RR-3** | **Texto livre em `title`/`description`** pode conter secret colado/PII de 3º; `raw_json` verbatim/imutável não scrubável | Baixa | Aceito v1; contido por 4 camadas (público / default-deny / nunca exposto / Fase 9 VETADA). Re-review se raw exposto (§1). |
| **RR-4** | **Sentry default** captura URL/params/breadcrumbs (pode vazar `pageToken`/query-URL) | Média | Scrubber desligado/redatado + canary §8.3 (F1'-f). Pré-live DevOps. |
| **RR-5** | **Reviewer único** `AdeptLabsDev` encarna DevOps+Security (sem teams) | Baixa (NOTE) | Separação por papel/agente; gate humano multi-fator re-aplicado a cada collect/verify (SEC-0022 §4). Evolui se surgir 2º colaborador/team. |
| **RR-6** | **Re-dispatch/duplicação** sob falha parcial re-consome quota pesada | Média | Idempotência §5 (índices únicos já vivos) + retomada só reusa raw persistido; teste §8.5 (SG-V5). Cap F-1' limita o custo por tentativa. |
| **RR-7** | **`configure_env` = ato sensível/humano**; provisionamento errado do cap/alerta anula F-1' | Média | Co-sign de Security no `configure_env` (SG-V6), evidência out-of-band, como SEC-0021/0022. |

## 10. GO / NO-GO de Security

- **SG-V2 (audit_secrets, revisão/design) → ✅ GO.** Desenho de segurança da coleta de vídeo liberado na minha camada; nenhum defeito de desenho. SEC-F23 (SEC-0016) e SEC-F08 (SEC-0012, vivo) já cobrem o essencial; os deltas de vídeo (F-1' quota, OD-V1/OD-V2, F-2') estão **nomeados e re-escopados** como condições de execução, não bloqueios de desenho.
- **Avançar SG-V3 (Database) e, em paralelo, SG-V4/SG-V5 (código inerte/offline) → ✅ GO para revisão/design.** Nenhum toca API/secret/pipeline. **Este GO não autoriza coleta, dispatch, arm nem provisionamento.**
- **F-1' (quota) e F-2' (YAML separado) → condições BLOQUEANTES do 1º run real** (SG-V6/SG-V7), não do desenho. OD-V2 (thresholds) escalado ao Product Lead.
- **SG-6 (Channel Data / 002) → ⛔ NO-GO (inalterado).** Não existe `run_id` de vídeo congelado e §7-passed. A próxima etapa elegível é SG-V3, nunca SG-6.
- **`youtube-collection` / 002 → segue ARMADO e OCIOSO** (`.armed` em `main`, `TOTAL_RUNS=0`), **intocado**.
- **Vetos de pé (não tocados):** Fase 9 / RLS Policies **VETADA**; `0007`/producer_events **PARKED**; publish barrado até **P5-REPRO-01 (SG-8)**.

## 11. Próximos passos seguros

1. **Registrar** OD-V1 (recomendo **reuso do Environment + workflow separado**) e OD-V2 (F-1': cap/retry/threshold) e **escalar os números exatos ao Product Lead** via Security/DevOps (design/review-only).
2. **Abrir SG-V3** (Database: re-ratificação zero-ALTER + atomicidade da finalização + path de UPDATE de status/contador) — em paralelo, sem tocar API/secret/pipeline.
3. Só então **SG-V4/SG-V5** (collector Agente 1+2 inerte/offline + 5 testes §8 + verify §7 SQL) — zero egress.
4. **SG-V6:** DevOps autora o **workflow de vídeo disarmed** (semântica de criação de run) → **F-2' audit_secrets SEPARADO** (Security) + `configure_env` com **F-1'** (cap/retry/alerta re-calibrado/API-restriction re-confirmada), co-assinado por Security.
5. **SG-V7:** dispatch humano do `main` + frase de confirmação + ack de irreversibilidade + required reviewers → collect → **§7 passa → `run_id` congelado**. **NO-GO agora.**
6. **SG-8 / P5-REPRO-01** antes de qualquer publish.

## 12. Restrições honradas / Intocados

- **Docs-only / review-only.** Nenhum collector, workflow, migration, teste, verify SQL, secret, GCP, Supabase, dispatch, deployment ou coleta tocado. **Nada implementado.**
- **Intocados:** `.github/workflows/youtube-collection.yml`; `.github/collection/youtube-collection.armed`; `services/data-engine/*`; `supabase/migrations/*` (schema vivo, **zero ALTER**); `supabase/tests/*`; `20260620000007_phase6_producer_events.*` (**PARKED**).
- **Zero valor sensível.** Cita apenas **nomes** de secrets/vars (`YOUTUBE_API_KEY`, `SUPABASE_DB_PASSWORD`) — nenhum valor, token, URL com query string, senha, connection string ou credencial. Nenhum screenshot.
- **Governança:** ação executada = `audit_secrets` (dentro da allow-list do `security_agent`) + threat-model de topologia de Environment (Owns / matrix #8). Sem ação fora da allow-list; sem `needs_review`.

---

## AgentResult

*Envelope canônico `@noxund/orchestrator` (`core/result-schema.ts`) — exatamente os 7 campos que o Orchestrator consome; findings/ODs/governança vivem no corpo do doc (§4/§7/§9/§10), não como chaves fora do schema. `status=completed` (revisão com evidência); F-1'/F-2' são condições pré-execução, não `errors`. Ação recomendada = verbo real registrado do agente-alvo.*

```json
{
  "task_id": "task_security_review_sg_v2_video_collection",
  "agent": "security_agent",
  "status": "completed",
  "summary": "SG-V2 (audit_secrets, REVIEW/DESIGN-ONLY) da coleta de video upstream DATA-COLLECT-001 (search.list -> raw_youtube_search_pages; videos.list -> raw_youtube_videos) concluida com evidencia. VEREDITO: GO para revisao/design; desenho de seguranca LIBERADO na camada de dado/secret, sem defeito de desenho. Herda SEC-0016 (SEC-F23 fechado no contrato) e SEC-0012 (CHECK SEC-F08 vivo no schema Fase 4). Controles: (1) SEC-F23 body de video (title/stats/raw_json) aceitavel - publico, minimizado a snippet,statistics, default-deny, NULL!=0; residual de texto-livre aceito v1 (4 camadas). (2) SEC-F08 anti-envelope ratificado nos 2 raws (CHECK top-level ja aplicado; scrub body-only autoritativo). (3) pageToken/title/query-URL/body proibidos em log (deny-list + canary); Sentry-scrub = residual DevOps. (4) YOUTUBE_API_KEY server-only, header X-Goog-Api-Key, Environment least-privilege sem ACCESS_TOKEN/service-role, main-only SEC-F18 (herdado SEC-0022). (5) path novo de STATE em report_runs nao abre secret/grant novo; atomicidade e gate da Database (SG-V3). RECOMENDACOES DE OPEN DECISIONS (escaladas ao Product Lead): OD-V1 = REUSO do Environment youtube-collection + workflow de video SEPARADO (2o Environment so DUPLICA a key portadora de custo - mesma key, mesmo projeto Google; isolamento real e no workflow/arm). OD-V2 = floors de F-1'. FINDINGS ELEVADOS A CONDICAO DO 1o RUN REAL (nao bloqueiam desenho): F-1' (quota) - search.list ~100 unid/pagina => ~1010 unid/run (~100x o canal de ~10); exigir cap por-run ~2000 (fail-closed), retry <=2/chamada com quotaExceeded/dailyLimitExceeded TERMINAL (nunca retentado), surplus <=~500 unid/run, alerta per-run >~1500 + alertas GCP 50%/80% de 10k RE-CONFIRMADOS para o perfil ~1010, API-restriction da MESMA key re-confirmada; F-2' (SG-V6) - audit_secrets SEPARADO do YAML de video (semantica de criacao de run + egress mais pesado), nao herda SEC-0016/SEC-0023. Governanca: acao dentro da allow-list (audit_secrets + threat_model de topologia; matrix #8); reviewer unico AdeptLabsDev encarna DevOps+Security (sem teams) - NOTE nao-bloqueante (SEC-0022 §4). NAO autoriza coleta/dispatch/arm/provisionamento. SG-6/002 NO-GO inalterado; youtube-collection ARMADO e OCIOSO intocado. Fase 9 VETADA; 0007 PARKED; publish barrado ate P5-REPRO-01. PAYLOAD ESTRUTURADO CONSUMIVEL (controls/findings/open_decisions/quota_model/f1_prime_checklist/residual_risks/gate_state, ids estaveis) em artifacts[0] = docs/security/SEC-0023-sg-v2-structured-result.md; revisao humana em artifacts[1].",
  "artifacts": [
    {
      "type": "structured_result",
      "path": "docs/security/SEC-0023-sg-v2-structured-result.md",
      "description": "PAYLOAD ESTRUTURADO CONSUMIVEL (schema noxund.security.structured_result/v1, bloco json unico com chaves/ids estaveis): review, verdict, controls[SV2-01..12], findings[F-1',F-2'], open_decisions[OD-V1,OD-V2] com recommendation/rationale, quota_model (numeros ~1010 + caps recomendados), f1_prime_checklist[F1'-a..g], residual_risks[RR-1..7], gate_state (SG-V0..SG-V8 + SG-6/002 + vetos), inherited_precedents, safe_next_steps, governance, constraints_honored. Este e o artifact que o Orchestrator/agentes downstream consomem deterministicamente. Zero valor de secret."
    },
    {
      "type": "review",
      "path": "docs/security/SEC-0023-sg-v2-data-collect-001-video-collection-review.md",
      "description": "Revisao em prosa para humano (rationale por eixo, evidencia, tabelas): SG-V2 audit_secrets da coleta de video DATA-COLLECT-001. Espelha o structured_result. Zero valor de secret."
    }
  ],
  "errors": [],
  "next_recommendation": {
    "target_agent": "product_agent",
    "action": "record_decision",
    "priority": "high",
    "reason": "SG-V2 (audit_secrets do DADO/secret/quota) LIBERADO em SEC-0023 (status completed). Orchestrator deve: (1) registrar o veredito SG-V2 GO no decision log; (2) escalar ao Product Lead as OPEN DECISIONS OD-V1 (recomendacao: reuso do Environment youtube-collection + workflow separado) e OD-V2 (floors de F-1': cap ~2000/retry<=2 com quota* terminal/alertas re-confirmados/API-restriction) - sao pre-condicao de EXECUCAO (SG-V7), nao de design; (3) abrir SG-V3 = Database re-ratifica ZERO ALTER (report_runs + raw_youtube_search_pages + raw_youtube_videos ja aplicados, Fase 3/4) e atesta atomicidade da finalizacao (collecting -> collected_video_count via report_runs_row_guard). NOTA: SG-V3 e CONFIRMACAO, nao migration - NAO mapeia para change_db_schema/run_migration (acoes sensiveis/mutantes do database_agent); nenhum ALTER e emitido. Em paralelo SG-V4/SG-V5 (collector inerte/offline + 5 testes §8 + verify §7) podem avancar - zero egress. F-1' (quota) e F-2' (audit_secrets do YAML) permanecem bloqueantes do 1o run real (SG-V6/SG-V7). Nada roda ate SG-V2..SG-V6 verdes + dispatch humano. SG-6/002 NO-GO inalterado; youtube-collection ARMADO e OCIOSO. Fase 9 VETADA; 0007 PARKED; publish barrado ate P5-REPRO-01."
  }
}
```
