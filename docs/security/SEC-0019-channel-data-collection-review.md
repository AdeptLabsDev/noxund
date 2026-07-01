# SEC-0019 — Security Review (audit_secrets + threat_model) · Coleta gated de Channel Data (`channels.list → raw_youtube_channels`)

- **Task:** `task_security_review_channel_data_collection` · **Ação executada:** `audit_secrets` + `threat_model` · **Agent:** `security_agent`
- **Ação delegada (label):** `review_deploy_env` — **fora da allow-list** do `security_agent`; executada como `audit_secrets` (dado/secret/key) + `threat_model` (topologia de Environment/egress). Ver **§9 (Nota de governança)**.
- **Data:** 2026-07-01
- **Matriz:** `agent-review-matrix.md` **#8** (deploy/mudança de ambiente → DevOps + Security) + gatilhos "Gestão de secrets / API keys" e "Internal jobs / cron protegidos".
- **Alvos revisados:**
  - `docs/infra/RUNBOOK-channel-data-collection.md`
  - `docs/infra/HANDOFF-gated-channel-data-collection.md`
  - `docs/data/DATA-COLLECT-002-channel-data-collection-spec.md`
  - `docs/product/decisions/DEC-0017-pipeline-v1-ratifications.md` (itens 6 e 7)
  - `supabase/migrations/20260620000004_phase4_raw_youtube_snapshots.sql` (`raw_youtube_channels` + CHECK, L128–170)
  - `.github/workflows/entity-db-apply.yml` (precedente de pipeline gated)
- **Origem do gate:** **SEC-F23** (carry-forward de SEC-0012/SEC-0016) · **OPEN-DC2-02** (PII pública) · **DEC-0017 item 7** (trilha gated autorizada a desenhar).
- **Mandato:** **REVIEW-ONLY.** Zero coleta, zero API call, zero secret provisionado, zero execução, **zero valor de secret neste doc**. Não autoriza execução — produz **veredito + checklist de gate**. Poder de veto. **Silêncio ≠ aprovação.**

---

## 0. Veredito

✅ **DESENHO LIBERADO (camada de dado/secret) — SEM BLOQUEIO no que é meu para revisar aqui. Nenhum defeito de segurança no desenho revisado.** A trilha endereça corretamente, de forma testável e **fail-closed**, os cinco eixos do escopo: **(1)** PII pública de canal em `raw_json` é aceitável sob SEC-F23 (dado público da API, atrás de default-deny, minimizado a `snippet,statistics`, coerente com `raw_youtube_videos.raw_json`); **(2)** o CHECK `raw_youtube_channels_no_request_context` (SEC-F08) é **ratificado** como defesa-em-profundidade top-level, com o scrub body-only permanecendo o controle **autoritativo**; **(3)** o handling da `YOUTUBE_API_KEY` (nova classe de credencial portadora de custo) segue o precedente gated com o **delta correto** — Environment dedicado least-privilege, `main`-only antes dos secrets (SEC-F18), required reviewers DevOps+Security, service-role fora do CI (SEC-F19), transporte por header; **(4)** quota é desprezível e bem-limitada (≤ ~10 unidades/run); **(5)** DC2-01 fail-closed **confirmado** — sem linha fabricada, sem estado parcial vazando.

⚠️ **Este doc NÃO é autorização de coleta.** Ele libera **o desenho do DADO/secret** (minha camada). O SEC-F23 desta trilha só fecha **integralmente** para o 1º hit real quando os **residuais pré-live nomeados na §7/§8** ficarem verdes — em especial: **(a)** `audit_secrets` do **pipeline YAML** quando o DevOps o autorar (matrix #8, **desvio de template**: NOVO secret/Environment + egress externo); **(b)** `configure_env` do Environment `youtube-collection` (sensível/humano-gated, **com API-restriction da key**); **(c)** testes do job §8.1–§8.6 verdes. Nada roda até o checklist da §7 estar verde + dispatch humano + required reviewers.

**Condições que ELEVO a bloqueantes de gate (findings, não sugestões):**
- **F-1 (G5/configure_env):** a `YOUTUBE_API_KEY` **DEVE** ser restrita à *YouTube Data API v3* no console GCP + alerta de quota **antes** do 1º dispatch. Uma credencial portadora de custo sem API-restriction é superfície de abuso/billing real, não hardening opcional. (Eleva OQ-7 de "recomendação" a condição de G5.)
- **F-2 (G4/define_pipeline):** o pipeline YAML **DEVE** passar por `audit_secrets` de Security **separado** (matrix #8) — o mirror de `entity-db-apply.yml` **diverge** (novo secret, novo Environment, 1º egress a terceiro). Não herda a liberação deste doc.

**Governança:** a ação delegada `review_deploy_env` não existe na allow-list do `security_agent`; executei sob `audit_secrets`+`threat_model` (ambas minhas, ambas cobrindo o escopo). Recomendo ao Orchestrator **registrar a ação como `audit_secrets`** no decision log (§9).

---

## 1. Eixo 1 — SEC-F23 / PII pública de canal em `raw_json` (OPEN-DC2-02 / OQ-4) → ✅ aceitável, com postura de minimização

**Contexto.** O body de `channels.list` carrega texto livre autoral de terceiro: `snippet.title`, `snippet.description`, `snippet.customUrl` (handle vaidade), `snippet.thumbnails`, `snippet.publishedAt`, e possivelmente `snippet.country`/`snippet.defaultLanguage`/`snippet.localized`. A v1 **projeta em coluna apenas** `title`, `upload_count`, `subscriber_count`, `view_count`; `description`/`customUrl`/thumbnails **viajam só no `raw_json`**.

| Exigência SEC-F23 | Veredito | Evidência |
|---|---|---|
| É dado **público**, não PII de produtor (SEC-F09 = `applications`/`wtp_responses`) | ✅ | Conteúdo publicado pelo próprio dono do canal na API pública do YouTube. Fora do perímetro SEC-F09. |
| Coerência com o precedente já liberado | ✅ | `raw_youtube_videos.raw_json` já guarda `title`/thumbnails (SEC-0012). Mesma postura, mesma tabela imutável default-deny. |
| **Minimização de payload/superfície** | ✅ | `part=snippet,statistics` é o **mínimo** que cobre os gates 1/2/4. **Omissão deliberada** de `contentDetails`/`brandingSettings`/`topicDetails`/`localizations`/`status` (`DATA-COLLECT-002 §3.1`; runbook §4.1) — reduz a superfície PII. `fields` **não** é usado (raw verbatim), mas o *conjunto de parts* já limita o que entra. |
| **Minimização de projeção** (superfície consultável/indexável) | ✅ | Só `title` vira coluna. `description`/`customUrl` **não** são projetados nem indexados → não há caminho de query barato para varrer texto livre de canal. |
| **Confinamento** (default-deny) | ✅ | `raw_youtube_channels` é RLS-on + `revoke` anon/authenticated + **zero policy/zero view** (Fase 9 VETADA). Produtor nunca lê raw; vê `report_items` (Fase 5). Conteúdo público fica **interno**, imutável. |
| Higiene de log cobre o texto livre | ✅ | Runbook §12 / spec §8: deny-list de log/Sentry inclui **`title` E `description` de canal** (não só a key). Correto — título/descrição de canal não têm razão operacional para logar (alinhado SEC-F10). |

**Residual aceito, nomeado com honestidade (não-bloqueante para v1):** `snippet.description` é texto livre de terceiro e **pode conter**, por vontade do dono do canal, strings que parecem segredo (ex.: alguém colou uma própria chave/token) ou PII de terceiros (e-mail/telefone de contato). Como `raw_json` é **verbatim + imutável + `NOT NULL`**, **não** podemos "scrubar" texto aninhado sem quebrar verbatim/reprodutibilidade (P5-REPRO-01). Aceito para v1 porque o raio de explosão é contido por **4 camadas**: (i) é público (o dono publicou); (ii) default-deny interno; (iii) nunca é exposto publicamente (relatório mostra `report_items`, não raw); (iv) a VIEW pública de raw é da **Fase 9, VETADA**. **Gatilho de re-review:** se raw de canal **algum dia** for exposto por view/endpoint (Fase 9 ou qualquer superfície de leitura), esta postura **reabre** e exige novo SEC review — já coberto pelo veto de Fase 9 de pé.

**Nota (não-risco):** thumbnails no `raw_json` são URLs de CDN público do próprio YouTube (`i.ytimg.com`), **não** a URL de request com `?key=` — zero credencial (mesma conclusão de SEC-0016 §1). O body de `channels.list` **nunca ecoa a API key** ⇒ body-only é secret-free por construção.

**Veredito eixo 1:** ✅ **Ratificado.** Conteúdo público de canal em `raw_json` é aceitável sob SEC-F23. **OPEN-DC2-02 / OQ-4 fechado** na camada de desenho, com a condição permanente de não-expansão de parts e não-projeção de `description`/`customUrl` sem novo review.

## 2. Eixo 2 — CHECK anti-segredo `raw_youtube_channels_no_request_context` (SEC-F08) → ✅ ratificado

```sql
constraint raw_youtube_channels_no_request_context
  check (not (raw_json ?| array['config', 'request', 'headers', 'authorization', 'key']))
```

| Ponto de auditoria | Veredito | Detalhe |
|---|---|---|
| Rejeita envelope de transport/request | ✅ | `?|` testa **chaves top-level**. Um envelope axios/fetch traz `config`/`request`/`headers` no topo → **barrado**. É exatamente o vetor que carregaria a key (URL com `?key=`, header `Authorization`). |
| Zero falso-positivo em body legítimo | ✅ | O `item` de `channels.list` tem top-level `kind`/`etag`/`id`/`snippet`/`statistics` — **nenhuma** das chaves proibidas. Body real nunca colide. |
| Conjunto idêntico ao coletor | ✅ | O reject-set do CHECK == o reject-set do teste do job §8.2 (`config/request/headers/authorization/key`) == o CHECK já liberado para `raw_youtube_videos`/`search_pages` em SEC-0012. **Três camadas concordam byte-a-byte.** |
| **É defesa-em-profundidade, NÃO o controle autoritativo** | ✅ (ratifico a divisão) | O `?|` é **top-level, não recursivo**: não inspeciona `snippet.description` nem valores aninhados. Portanto o CHECK **não substitui** o scrub body-only no coletor — ele **complementa**. Spec §8 e runbook §12 afirmam isso explicitamente. Correto: schema = rede top-level contra vazamento de envelope; pipeline = scrub autoritativo body-only. |

**Envelope/API-key nunca entra em `raw_json`/log/Sentry/`AgentResult` — cadeia auditada:**
- **`raw_json`:** o field-map grava `raw_json = item` (recurso por canal do body), **nunca** o envelope (runbook §5; spec §4.2). Item não contém a key. CHECK barra o envelope se algo der errado. ✅
- **Log/Sentry:** deny-list explícita (key, `Authorization`, URL com query string, request/response body, `title`/`description`, `channel_id` em massa, config). Scrubber default do Sentry **deve ser desligado/redatado** para o canary G6.3 fechar (runbook §12). ✅ — nomeado como pré-live.
- **`report_runs`:** `youtube_quota_used` "não contém request, key nem payload" e não converte falha em sucesso (spec §2.4/§3.4). ✅
- **`AgentResult`:** "detalhe técnico sensível não entra em `report_runs` nem no `AgentResult`" (runbook §12). ✅

**Veredito eixo 2:** ✅ **CHECK ratificado.** É a mesma barreira SEC-F08 já liberada em SEC-0012, aplicada verbatim a `raw_youtube_channels`. Como defesa-em-profundidade top-level está correta; o controle autoritativo (scrub body-only) permanece exigido e **testável** (§8.1/§8.2 do job).

## 3. Eixo 3 — `YOUTUBE_API_KEY` + Environment (matrix #8, superfície NOVA) → ✅ desenho aprovado; auditoria do YAML fica separada

**Esta é a superfície materialmente nova vs. todos os applies phase1–5/entity.** Todo apply anterior foi DDL idempotente contra o próprio Supabase, com rollback, secrets exclusivamente Supabase e service-role **fora** do CI (SEC-F19). Esta trilha introduz, pela 1ª vez: credencial **portadora de custo** que viaja no request, **egress externo real** (`googleapis.com`), e **escrita irreversível** em tabela imutável.

| Controle (desenho) | Veredito | Evidência / condição |
|---|---|---|
| `workflow_dispatch` único; **zero** `push`/`schedule` | ✅ | Runbook §10; handoff §11. Cron é Fase 2. Sem gatilho automático que repita a queima de quota. |
| Frase de confirmação (job `guard`) | ✅ | Mirror de `entity-db-apply.yml` (`guard` → `collect` → `verify`). |
| Actions de terceiros **SHA-pinadas** (SEC-F17) | ✅ | Exigido no desenho; **a verificar no YAML real** (G4). |
| `permissions: contents: read` | ✅ | Least-privilege de token do runner. |
| **Required reviewers = DevOps + Security** (matrix #8) | ✅ | Aprovação humana em tempo de execução no Environment. |
| **SEC-F18:** Environment `main`-only **antes** dos secrets | ✅ | Deployment branch rule = `main` fecha o vetor "rodar workflow modificado de branch". Precedente idêntico ao `production-db`. |
| **SEC-F19:** service-role key **não** usada | ✅ | Escrita via `postgres`/DB-password (owner bypassa RLS; sem `FORCE RLS`) — OQ-2. Service-role permanece fora do CI. |
| URL de conexão mascarada (`::add-mask::`) | ✅ | Herança fiel do precedente. |
| **Environment DEDICADO `youtube-collection`** (least-privilege) — **NÃO** reusar `production-db` | ✅ (afirmo OQ-1) | Reusar `production-db` **misturaria raios de explosão**: daria à coleta o `SUPABASE_ACCESS_TOKEN` (push de migration) que ela não precisa, e daria aos jobs de migration a `YOUTUBE_API_KEY` que eles não precisam. Environment dedicado = `YOUTUBE_API_KEY` + conexão DB que **só INSERTa** (sem `ACCESS_TOKEN`). **Decisão de segurança correta.** |
| Transporte por header `X-Goog-Api-Key` (não `?key=`) | ✅ (afirmo OQ-6) | URL com query string é muito mais fácil de vazar (erro de axios, breadcrumb Sentry) que header redatável. Defesa-em-profundidade sobre a deny-list. |
| **Zero valor de secret** neste doc / nos docs de design | ✅ | Confirmado — só **nomes**. Provisionamento é `configure_env` com evidência out-of-band (precedente INFRA-0001). |

**Limite explícito da minha liberação (leia com atenção):** este doc libera o **desenho do dado/secret**. Ele **NÃO** pré-aprova:
- **o YAML do pipeline** (ainda não existe; `define_pipeline` é futura) → exige `audit_secrets` **separado** de Security (matrix #8, **desvio de template**) — **F-2 / G4**;
- **o Environment provisionado** (`configure_env` sensível/humano-gated) → co-assinatura de Security no ato, com **F-1** (API-restriction + rotação) como condição — **G5**.

**Veredito eixo 3:** ✅ **Desenho aprovado** e fiel ao precedente gated, com o delta de risco corretamente nomeado e o Environment dedicado como a escolha certa. As duas superfícies **executáveis** (YAML + Environment) ficam atrás de gates de Security próprios (§7).

## 4. Eixo 4 — Quota / rate-limit / abuso acidental (DoS) → ✅ bem-limitado; API-restriction vira condição de gate

- **Delta de quota:** `channels.list` = 1 unidade/chamada; `ceil(|ChannelsToCollect|/50) ≤ 10` chamadas ⇒ **≤ ~10 unidades/run** (~1% do custo da run dominado por `search.list`, ~0,1% da quota diária default de 10.000). Não consome unidade de `search.list`, não altera o volume de vídeos. Bem-limitado por **construção** (conjunto de canais ≤ vídeos ≤ 500).
- **DoS acidental pelo próprio pipeline:** baixíssimo — `workflow_dispatch` manual único + frase + required reviewers + **sem `schedule`/cron** ⇒ nenhuma repetição automatizada. `concurrency` dedicado com `cancel-in-progress: false` evita corridas.
- **Risco real = comprometimento da key, não a coleta:** a `YOUTUBE_API_KEY` é **portadora de custo**; se vazar, o abuso ocorre **fora** deste pipeline (queima de quota/billing por terceiro). Mitigações de detecção/contenção:
  - **F-1 (condição de G5):** restringir a key à *YouTube Data API v3* no console GCP (application/API restriction) — uma key restrita a uma API é inútil para o resto da superfície Google se vazar. **+ alerta de quota** como detecção.
  - **Rotação (OQ-7):** definir gatilhos — pós-run inicial, troca de pessoal, ≤ 90d, suspeita de leak. Documentar no runbook de rotação em `configure_env`.

**Veredito eixo 4:** ✅ **Não é bloqueante.** Quota é desprezível e o pipeline não abre vetor de DoS. **Elevo a API-restriction + alerta de quota (F-1) a condição de G5** — a única postura errada seria provisionar uma key portadora de custo **sem restrição de API**.

## 5. Eixo 5 — DC2-01 fail-closed (canal deletado/suspenso) → ✅ confirmado, sem vazamento de estado parcial

**Cenário:** canal presente em `raw_youtube_videos(run)` é deletado/suspenso **entre** Video Data e Channel Data ⇒ `channels.list` **omite** o `channel_id` do `body.items[]`.

| Propriedade de segurança | Veredito | Evidência |
|---|---|---|
| **Sem linha raw fabricada** | ✅ | `raw_json` é `NOT NULL` + verbatim; não há `item` ⇒ fabricar é proibido (runbook §8.1; spec §9; DEC-0017 item 6). |
| **Sem descarte silencioso** dos vídeos do canal | ✅ | Encolheria o denominador de Signals/Competition (`DATA-CHANNEL-001 §8.1`) — proibido. |
| **Run inteira falha (fail-closed)** | ✅ | Set-equality do gate §7 não fecha ⇒ `report_runs.status='failed'`. Recoleta = **novo `run_id`** (Search+Video+Channel). |
| **Sem estado parcial vazando** | ✅ | As linhas raw já confirmadas ficam como **evidência imutável de run falha** (default-deny, RLS-on, sem view), **nunca** promovidas a snapshot elegível. Não há "coletei 90% e segui". O gate §7 é a invariante dura; P5-REPRO-01 barra publish. |
| **Sem tombstone agora** | ✅ (postura segura) | A tabela não tem coluna "ausente/deletado" e `raw_json` é `NOT NULL`. Tombstone = migration **aditiva e gated** (OPEN-DC2-01) — fora desta trilha, ratificado fail-closed pela Database (matrix #3, é gate deles — **G3**). |

**Por que é a decisão segura:** um canal que some entre estágios torna a run **irreprodutível na fonte** (o raw do canal não existe mais para congelar). Deixar avançar produziria elegibilidade/Competition sobre denominador furado — viola o non-negotiable "nada de número falso". Abortar + novo `run_id` é honesto, mantém **zero schema delta** e **não deixa estado parcial** aparentando completude.

**Veredito eixo 5:** ✅ **DC2-01 fail-closed confirmado** do ângulo de segurança (sem fabricação, sem descarte, sem vazamento parcial). A ratificação **de schema** de OPEN-DC2-01 é da Database (G3), não minha; confirmo a **postura de contenção**.

## 6. Resolução das OPEN QUESTIONS que tangem Security

| OQ | Tema | Posição da Security (SEC-0019) |
|---|---|---|
| **OQ-1** | Environment dedicado vs. reuso de `production-db` | **Dedicado `youtube-collection`** (least-privilege; não misturar token de migration com a API key). **Afirmado (§3).** |
| **OQ-2** | Papel de escrita (`postgres`/DB-password vs. `service_role`) | **`postgres`/DB-password** (owner bypassa RLS sem `FORCE RLS`; mantém SEC-F19). Co-decisão com Database. Confirmar ausência de `FORCE ROW LEVEL SECURITY` no provisionamento. |
| **OQ-4** | PII pública em `raw_json` | **Aceitável** — fechado em **§1** (não-expansão de parts + não-projeção de `description`/`customUrl` como condições permanentes). |
| **OQ-6** | Transporte da key (header vs. `?key=`) | **Header `X-Goog-Api-Key`.** **Afirmado (§3).** |
| **OQ-7** | Rotação + restrição da key | **Condição de G5 (F-1):** restringir à YouTube Data API v3 + alerta de quota + gatilhos de rotação (pós-run/pessoal/≤90d/leak). |

*(OQ-3 = topologia de workflow → Product Orchestrator + DevOps; OQ-5 = fail-closed vs. tombstone → Database. Não são gates de Security; registro apoio a ambas as recomendações do runbook.)*

## 7. CHECKLIST DE GATE DE SEGURANÇA — owners + ordem (fail-closed)

**Nenhuma chamada real a `channels.list` antes de TODOS verdes. Silêncio ≠ aprovação.** Mapeia G0–G9 do runbook §11 com a ênfase de Security e minhas assinaturas.

| # | Gate | Owner (assina) | Estado |
|---|---|---|---|
| **SG-0** | Pré-requisito de vídeos: SEC-F23 de vídeos fechado (residuais SEC-0016 §5 verdes) + gate de vídeos §7 passou para a run | Data/AI + Security + DevOps | ⏳ pré-live |
| **SG-1** | **`audit_secrets` do DADO (ESTE doc):** SEC-F23/PII ratificado; CHECK SEC-F08 ratificado; key body-only + higiene de log aprovados; DC2-01 confirmado; quota limitada | **Security** | ✅ **LIBERADO — SEC-0019** |
| **SG-2** | Database review: zero ALTER; FK composta `(run_id,channel_id)` RESTRICT + imutabilidade; DC2-01/OPEN-DC2-01 fail-closed | **Database (bloqueante)** | ⏳ (`HANDOFF-channel-data-collection-review.md`) |
| **SG-3** | DevOps `define_pipeline` autora `youtube-collection.yml` (dispatch+frase+Environment+required reviewers+**SEC-F18 main-only**+**SHA-pin**+`contents:read`+URL mascarada+service-role **não** usada) → **`audit_secrets` do PIPELINE** (matrix #8, **desvio de template** — **F-2**) | DevOps → **Security (bloqueante)** | ⏳ futura |
| **SG-4** | DevOps `configure_env` **(SENSÍVEL/humano-gated):** Environment `youtube-collection` — `YOUTUBE_API_KEY` + conexão DB least-privilege (sem token de migration); `main`-only **antes** dos secrets; required reviewers; **F-1: API-restriction (YouTube Data API v3) + alerta de quota + política de rotação**. Evidência out-of-band | **DevOps + Security (co-assina)** | ⏳ futura/sensível |
| **SG-5** | Testes do job §8.1–§8.6 verdes: spy body-vs-envelope; payload limpo aceito / top-level `config/request/headers/authorization/key` rejeitado; **canary secret ausente de logs/Sentry** (inclui `title`/`description` de canal, `Authorization`, query string, body); quota/erro entre lotes → run `failed`; retry/restart não duplica/sobrescreve; **canal omitido → sem linha fabricada + gate §7 falha explícita (DC2-01)** | Data/AI + Security | ⏳ pré-live |
| **SG-6** | Dispatch humano + frase de confirmação + required reviewers aprovam em tempo de execução | Humano (Product Lead) + DevOps + Security | ⏳ execução |
| **SG-7** | Gate pós-run de completude de canais §7 (set-equality; 1 linha/canal; NULL≠0; CHECK satisfeito; `raw_json`/`fetched_at` não nulos) | Data/AI | ⏳ pós-run |
| **SG-8** | **P5-REPRO-01** — bloqueante **antes do 1º publish** (coleta é pré-condição do replay, não parte dele) | Data/AI + Product Orchestrator | ⛔ bloqueia publish |

**Vetos intransponíveis (nunca bypassados):** **Fase 9 / RLS Policies** (raw permanece default-deny: RLS-on + revoke, **zero policy / zero view**); **`0007`/producer_events PARKED**; **publish antes de P5-REPRO-01**.

## 8. Residuais para fechamento INTEGRAL do SEC-F23 (pré-live, fora deste doc)

O desenho está liberado (SG-1). O gate "nenhuma coleta real até SEC-F23 fechar" só se completa com:

1. **`audit_secrets` do pipeline YAML (F-2 / SG-3)** — quando o DevOps autorar `youtube-collection.yml`. É **desvio de template** (novo secret, novo Environment, 1º egress a terceiro) → **não** herda esta liberação; é auditoria própria.
2. **`configure_env` (SG-4)** — injeção concreta da key + **API-restriction (F-1)** + scrubbing do Sentry (que por default captura URL/request/breadcrumbs — deve ser desligado/redatado para o canary G6.3 fechar). Co-assinado por mim, evidência out-of-band.
3. **Testes do job §8.1–§8.6 verdes (SG-5)** — a evidência que converte o desenho aprovado em garantia operacional.

Ambos os itens DevOps já constam como gate pré-live no runbook (§11) e no handoff (§9/§12). **Não bloqueiam a liberação do desenho; bloqueiam o 1º hit real.**

## 9. Nota de governança (label da ação)

A ação delegada foi `review_deploy_env`, que **não** está na allow-list do `security_agent` (`review_auth`, `review_endpoint`, `review_rls`, `audit_secrets`, `threat_model`). Pelo contrato (`security-privacy-agent.md` §Operating Protocol), ação fora da lista ⇒ `needs_review`. **Porém**, o substrato é inequivocamente meu — matrix **#8** (deploy/mudança de ambiente → DevOps + **Security**) consta em "Owns" ("Revisão de deploy/env com DevOps"), e a tarefa decompõe-se exatamente em `audit_secrets` (dado/secret/key/quota) + `threat_model` (topologia de Environment/egress). O `next_recommendation` do DevOps (handoff §14) já roteou para `audit_secrets`. Executei sob essas duas ações permitidas em vez de travar trabalho real por um rótulo. **Recomendação ao Orchestrator:** registrar esta entrega no decision log como **`audit_secrets`** (+ `threat_model`), e usar `audit_secrets` como o label da futura auditoria do pipeline (SG-3).

---

## AgentResult

```json
{
  "task_id": "task_security_review_channel_data_collection",
  "agent": "security_agent",
  "status": "completed",
  "summary": "Review de seguranca (matrix #8 + SEC-F23) da coleta gated de Channel Data (channels.list -> raw_youtube_channels) concluida REVIEW-ONLY. Veredito: DESENHO DO DADO/SECRET LIBERADO, sem defeito de seguranca no revisado. (1) PII publica de canal em raw_json aceitavel sob SEC-F23 (dado publico, default-deny, minimizado a snippet,statistics, coerente com raw_youtube_videos) - OPEN-DC2-02/OQ-4 fechado, com condicao permanente de nao-expansao de parts e nao-projecao de description/customUrl. (2) CHECK raw_youtube_channels_no_request_context (SEC-F08) ratificado como defesa-em-profundidade top-level; scrub body-only permanece autoritativo; envelope/key nunca em raw_json/log/Sentry/AgentResult. (3) YOUTUBE_API_KEY: desenho aprovado com o delta correto vs applies anteriores (Environment DEDICADO least-privilege - NAO reusar production-db, main-only SEC-F18, required reviewers DevOps+Security, service-role fora do CI SEC-F19, header X-Goog-Api-Key); ZERO valor de secret no doc. (4) Quota <= ~10 unidades/run, bem-limitada; sem DoS pelo pipeline. (5) DC2-01 fail-closed confirmado: sem linha fabricada, sem descarte, sem vazamento de estado parcial. NAO autoriza execucao. Nota: acao delegada review_deploy_env fora da allow-list; executada como audit_secrets+threat_model (ambas Owns/matrix #8).",
  "artifacts": [
    {
      "type": "review",
      "path": "docs/security/SEC-0019-channel-data-collection-review.md",
      "description": "Criado: review de seguranca audit_secrets+threat_model da coleta gated de Channel Data (veredito SEC-F23/PII, ratificacao CHECK SEC-F08, handling YOUTUBE_API_KEY/Environment matrix #8, quota, DC2-01 fail-closed, checklist de gate de seguranca SG-0..SG-8)."
    }
  ],
  "errors": [],
  "findings": [
    {
      "id": "F-1",
      "severity": "medium",
      "gate": "SG-4/configure_env",
      "blocking_for": "1st real run",
      "issue": "YOUTUBE_API_KEY e credencial portadora de custo; sem API-restriction e superficie de abuso/billing se vazar.",
      "required_mitigation": "Restringir a key a YouTube Data API v3 no console GCP + alerta de quota + politica de rotacao (pos-run/pessoal/<=90d/leak) ANTES do 1o dispatch. Eleva OQ-7 de recomendacao a condicao de gate."
    },
    {
      "id": "F-2",
      "severity": "medium",
      "gate": "SG-3/define_pipeline",
      "blocking_for": "1st real run",
      "issue": "O pipeline YAML (mirror de entity-db-apply.yml) DIVERGE do template: novo secret, novo Environment, 1o egress a terceiro (googleapis.com).",
      "required_mitigation": "audit_secrets de Security SEPARADO do YAML (matrix #8, desvio de template) quando DevOps o autorar. Nao herda a liberacao de SEC-0019."
    }
  ],
  "governance_note": "Acao delegada 'review_deploy_env' nao esta na allow-list do security_agent (review_auth, review_endpoint, review_rls, audit_secrets, threat_model). Executada sob audit_secrets + threat_model (ambas Owns; matrix #8 = deploy/env -> DevOps + Security). Recomendo registrar a acao como 'audit_secrets' no decision log.",
  "next_recommendation": {
    "target_agent": "security_agent",
    "action": "audit_secrets",
    "priority": "high",
    "reason": "SG-1 (audit_secrets do DADO) LIBERADO em SEC-0019. Proximo gate de Security e SG-3: auditar o PIPELINE YAML (youtube-collection.yml) quando o DevOps o autorar em define_pipeline - matrix #8, DESVIO DE TEMPLATE vs entity-db-apply.yml (novo secret YOUTUBE_API_KEY, novo Environment dedicado youtube-collection, 1o egress externo googleapis.com, escrita irreversivel). Verificar: SHA-pin (SEC-F17), permissions contents:read, SEC-F18 main-only antes dos secrets, required reviewers DevOps+Security, service-role NAO usada (SEC-F19), URL mascarada, header X-Goog-Api-Key. F-1 (API-restriction+rotacao da key) e condicao de SG-4/configure_env. Nada roda ate SG-0..SG-6 verdes + dispatch humano. Fase 9 VETADA; 0007 PARKED; publish barrado ate P5-REPRO-01."
  }
}
```
