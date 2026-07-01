# RUNBOOK — Channel Data Collection (`channels.list → raw_youtube_channels`)

- **Track:** Passo 4 — coleta **gated** de Channel Data (DEC-0017 item 7)
- **Owner operacional:** DevOps/Infra (`devops_agent`) · co-gates Security + Database + Data/AI
- **Data:** 2026-07-01
- **Estado:** **DESIGN/RUNBOOK-ONLY — não autoriza coleta real.** Zero API, zero secret, zero pipeline execution, zero DB write, zero publish, zero git.
- **Operacionaliza:** `docs/data/DATA-COLLECT-002-channel-data-collection-spec.md` (contrato de dados) — estende `docs/data/DATA-COLLECT-001-youtube-collection-spec.md` (precedente Search + Video Data).
- **Espelha (pipeline):** `.github/workflows/entity-db-apply.yml` (precedente gated: `workflow_dispatch` + frase de confirmação + Environment `production-db` + required reviewers + SEC-F18 dispatch-de-`main`).
- **Schema alvo (JÁ APLICADO, zero ALTER):** `public.raw_youtube_channels` — `supabase/migrations/20260620000004_phase4_raw_youtube_snapshots.sql` L128–146 + triggers de imutabilidade L165–170 + RLS/revoke L179/186.
- **Autorização:** DEC-0017 item 7 autoriza **desenhar** esta trilha; **NÃO** autoriza rodar coleta real, usar API key/secret sem pipeline aprovado, publicar antes de **P5-REPRO-01**, tocar **Fase 9/RLS Policies**, ou destravar **`0007`/producer_events**. Estes permanecem gates fail-closed intransponíveis.

---

## 0. O que este documento é (e o que NÃO é)

É o **runbook operacional** da sub-coleta de Channel Data: como um operador humano, **quando todos os gates da §11 estiverem verdes**, dispararia a coleta `channels.list → raw_youtube_channels` para os canais já surgidos no snapshot de ~500 vídeos de uma run. Ele descreve o **fluxo, o mapa de campos, a contabilidade de quota, o tratamento fail-closed DC2-01, o desenho do pipeline gated e o checklist de gate**.

**NÃO** é autorização de execução. **NÃO** contém valores de secret (só nomes). **NÃO** aplica migration (o schema já está vivo; **zero ALTER**). **NÃO** roda nada. A primeira chamada real a `channels.list` só é permitida depois que **todo** o checklist da §11 estiver verde e um humano disparar o run gated com aprovação dos required reviewers.

---

## 1. Posição no ciclo de vida da run (mesma `run_id`, sub-fase encadeada)

Channel Data **não cria `run_id` novo**. É a **sub-fase final** da **mesma** run de `DATA-COLLECT-001`: o `run_id` é exatamente o `report_runs.id` que ancora `raw_youtube_search_pages` e `raw_youtube_videos` (`DATA-COLLECT-002 §2.1`). Isso é obrigatório porque:

- a FK de `channel_eligibility` é composta `(run_id, channel_id) → raw_youtube_channels` (`ON DELETE RESTRICT`); e
- `raw_youtube_videos.channel_id` precisa casar com `raw_youtube_channels.channel_id` **sob a mesma `run_id`** (proveniência forte).

```txt
report_runs (status: created → collecting)
   └─ Stage A — search.list  → raw_youtube_search_pages   (DATA-COLLECT-001 §3)
   └─ Stage B — videos.list  → raw_youtube_videos          (DATA-COLLECT-001 §4)
        └─ GATE de vídeos (DATA-COLLECT-001 §7)  ── pré-condição, INALTERADO
             └─ Stage C — channels.list → raw_youtube_channels   (ESTA coleta, DATA-COLLECT-002 §3)
                  └─ GATE de canais (DATA-COLLECT-002 §7)  ── set-equality canais↔vídeos
                       └─ run pronta para Channel Filter (Fase 5)
```

- **Recoleta = NOVO `run_id` para a run inteira** (Search + Video + Channel), nunca recoleta isolada de canais sobre uma `run_id` existente. Não existe "atualizar canais"; existe nova run (`DATA-COLLECT-002 §2.1`, §5, §6).
- **Sequência operacional (DC2-04, ratificado nesta trilha):** um **único dispatch gated** roda a run inteira sob uma `run_id`, com Channel Data como sub-fase C chained após o gate de vídeos. A alternativa (job separado consumindo a `run_id` de uma coleta de vídeos anterior) fica registrada como OQ-3 (§13) para ratificação Product Orchestrator + DevOps; este runbook assume o modelo de sub-fase única.

**Invariante de não-expansão:** Channel Data **só adiciona metadados** de canais que o pipeline já surfou. Não muda `keyword`, janela, volume, vertical, paginação de Search nem descobre canais sem vídeo na run. Qualquer tentativa nesse sentido é **Stop Condition** (`DATA-COLLECT-002 §1`).

---

## 2. Pré-condições (fail-closed antes de qualquer chamada)

Stage C **não inicia** enquanto **todas** abaixo não forem verdadeiras:

1. Gate de vídeos de `DATA-COLLECT-001 §7` **passou** para a run — vetor `(run_id, video_id)` congelado, sem falha terminal.
2. `report_runs.status` **não** é `failed`; a run está `collecting` (não promovida a `processed`/`published`).
3. `collected_video_count` já refletindo a finalização íntegra de vídeos (o gate de vídeos gravou o total real).
4. Todos os gates da §11 (checklist) verdes — inclusive `configure_env` da `YOUTUBE_API_KEY` e testes do job §8 do spec verdes.

Sobre uma run `failed`, `created` ou ainda `collecting`/inconsistente no estágio de vídeos, Channel Data **não roda**. Silêncio de um gate **não** é aprovação.

---

## 3. Derivação determinística do conjunto de canais

```text
ChannelsToCollect(run) = { c : ∃ v ∈ raw_youtube_videos(run_id = run) ∧ v.channel_id = c }
```

- `raw_youtube_videos.channel_id` é `text NOT NULL` → conjunto **bem-definido e finito**.
- Cardinalidade: `1 ≤ |ChannelsToCollect| ≤ collected_video_count ≤ 500`.
- Derivação barata via índice `raw_youtube_videos_run_channel_idx (run_id, channel_id)` (migration Fase 4, L117–118).
- **Ordem determinística:** vetor de canais distintos por **primeira ocorrência** no vetor canônico de vídeos da run (`DATA-COLLECT-001 §3.2`). A ordem **não** altera o conjunto coletado (idêntico em qualquer ordenação); serve para lotes/replay determinísticos.
- **Nenhum** canal fora desse conjunto entra; **nenhum** canal do conjunto pode ser silenciosamente omitido (§8/§9 do runbook).

---

## 4. Contrato de request `channels.list`

### 4.1 Request canônica (por lote)

```text
GET https://www.googleapis.com/youtube/v3/channels
part=snippet,statistics
id=<até 50 channel_id do lote, separados por vírgula, na ordem do vetor §3>
# key: NÃO no payload persistido/logado. Injetada server-side (§8 / DATA-COLLECT-002 §8).
# Preferir header  X-Goog-Api-Key: <valor>  ao query param ?key=<valor>  (hardening SEC-0016 §4 / OQ-6)
```

- `part=snippet,statistics` é o **mínimo** que cobre os campos do Channel Filter: `snippet.title`, `statistics.videoCount`, `statistics.subscriberCount`, `statistics.viewCount`. **Não** adicionar `contentDetails`, `brandingSettings`, `topicDetails`, `localizations`, `status` — omissão deliberada (minimização de payload e de superfície SEC-F23).
- **Não usar `fields`:** o body completo do recurso por canal é preservado verbatim em `raw_json`.
- `id` não pode ser fabricado, normalizado para canais fora de `ChannelsToCollect(run)` nem deduplicado de forma que esconda divergência.

### 4.2 Lotes

- Vetor ordenado de `channel_id` distintos (§3), particionado sequencialmente em lotes de **≤ 50 ids**, sem reordenar (limite de `channels.list`; espelha `videos.list`, `DATA-COLLECT-001 §4.1`).
- Extrair **somente o body** da resposta (nunca o envelope axios/fetch). Indexar `body.items[]` por `item.id`; não depender da ordem de retorno.

### 4.3 Validação do lote (antes de persistir) — `DATA-COLLECT-002 §3.3`

- cada `channel_id` solicitado aparece **exatamente uma vez** em `body.items[]`;
- **nenhum** item não solicitado aparece;
- `item.id`, `item.snippet.title` e `item.statistics` coerentes com a linha projetada;
- estatística ausente/oculta permanece **`NULL`**, nunca zero fabricado;
- cada contador presente é **string decimal válida** que cabe em `bigint` (overflow = falha de validação, não truncamento);
- `hiddenSubscriberCount = true ⇒ subscriber_count = NULL` (não zero), flag preservado verbatim no `raw_json`.
- `channel_id` solicitado **ausente** do `body.items[]` → **DC2-01** (§8), condição de parada da sub-fase.

---

## 5. Mapa de campos → `raw_youtube_channels` (shape aplicado — NULL ≠ 0)

> Colunas verbatim do SQL aplicado (Fase 4, L128–146). **Zero ALTER.** O coletor **INSERT-only**.

| Coluna aplicada | Origem (`channels.list` item) | Conversão | Semântica de NULL |
|---|---|---|---|
| `id` | — (`gen_random_uuid()`) | banco gera | nunca nulo; coletor não fornece |
| `run_id` | UUID da **mesma** run (§1) | — | nunca nulo (FK → `report_runs`, `ON DELETE RESTRICT`) |
| `channel_id` | `item.id` | string verbatim | nunca nulo |
| `title` | `item.snippet.title` | string verbatim | ausente = sem sinal de título |
| `upload_count` | `item.statistics.videoCount` | string decimal → `bigint` exato | **ausente ⇒ NULL** (nunca 0). `videoCount` = vídeos **públicos** do canal |
| `subscriber_count` | `item.statistics.subscriberCount` | string decimal → `bigint` exato | **ausente/oculto (`hiddenSubscriberCount=true`) ⇒ NULL** (nunca 0) |
| `view_count` | `item.statistics.viewCount` | string decimal → `bigint` exato | **ausente ⇒ NULL** (nunca 0) |
| `raw_json` | objeto `item` **completo e inalterado** (`kind = youtube#channel`) | extraído do body, verbatim | `NOT NULL`; preserva `snippet.publishedAt`, `thumbnails`, `hiddenSubscriberCount`, etc. |
| `fetched_at` | instante UTC do recebimento do body do lote | UTC no recebimento | `NOT NULL`; é o `collected_at` canônico |

- **`raw_json` é a verdade última**; as 4 projeções (`title`/`upload_count`/`subscriber_count`/`view_count`) são conveniência de leitura.
- `videoCount = 0` **legítimo** (canal real sem uploads públicos) → `upload_count = 0` (zero **real** da API, não fabricado). Distinguir `0` (presente) de `NULL` (ausente) é mandatório.
- `snippet.publishedAt` (idade do canal): preservado no `raw_json`, **sem coluna projetada**; `channel-filter-v1` **não** usa idade como gate → não projeta, não bloqueia. Gate de idade futuro = migration **aditiva** + nova `rule_version` (`OPEN-DC2-03`).

---

## 6. Contabilidade de quota

| Chamada | Custo (YouTube Data API v3, documentado) | Nº chamadas/run | Quota |
|---|---|---|---|
| `search.list` (existente) | 100 unidades/página | ~10 páginas até 500 ids | ~1000 (dominante) |
| `videos.list` (existente) | 1 unidade/chamada | `ceil(≤500/50) ≤ 10` | ≤ 10 |
| **`channels.list` (ESTA coleta)** | **1 unidade/chamada** (`snippet`,`statistics` não somam custo extra) | `ceil(\|ChannelsToCollect\|/50) ≤ 10` | **≤ 10** |

- **Delta de quota desta coleta:** **≤ ~10 unidades/run** (limite superior; canais distintos ≤ vídeos ≤ 500). ~1% do custo da run e ~0,1% da quota diária default (10.000 unidades/dia/projeto).
- Channel Data **não consome unidade de `search.list`** e **não altera** quantos vídeos são coletados.
- O consumo apurado/estimado pelo adaptador soma em `report_runs.youtube_quota_used`, inclusive em falha quando conhecido. Esse contador **não** contém request, key nem payload e **não** converte falha em sucesso (`DATA-COLLECT-002 §2.4/§3.4`).
- **Recomendação operacional (OQ-7):** restringir a `YOUTUBE_API_KEY` à YouTube Data API v3 no console GCP + alerta de quota; a coleta é barata, mas a key é credencial **portadora de custo** (abuso = queima de quota/billing).

---

## 7. Persistência: append-only, idempotência, atomicidade

- `raw_youtube_channels` é **insert-only** e **imutável por trigger** (Fase 4, L165–170): proibidos `UPDATE`, `DELETE`, `TRUNCATE`, `UPSERT ... DO UPDATE` — **inclusive abaixo do `service_role`** (bypass de RLS, SEC-F01). Os triggers ficam abaixo do `service_role`, no banco.
- **Chave de idempotência imposta pelo schema:** `raw_youtube_channels_run_channel_uidx (run_id, channel_id)` único → **uma** linha por canal por run.
- Cada lote (≤ 50 canais) persiste em **uma transação** atômica (`DATA-COLLECT-002 §5`).
- **Retomada:** linha já existente para `(run_id, channel_id)` é **lida/reutilizada**, nunca re-requisitada nem sobrescrita. Zero existentes ⇒ chamada permitida; todas existentes ⇒ reutiliza raw; existência **parcial** de um lote determinístico ⇒ violação de atomicidade ⇒ run `failed`.
- `unique_violation` **nunca** engolida com `DO NOTHING`: divergência ou origem não explicada **falha explicitamente**.
- **Papel de escrita (OQ-2):** `raw_youtube_channels` é RLS-on + `revoke` de anon/authenticated + **sem policies** (Fase 9 vetada). Só um papel que **bypassa RLS** insere: o **owner `postgres`** (via `SUPABASE_DB_PASSWORD`/session pooler — não há `FORCE ROW LEVEL SECURITY`, então o owner ignora RLS; é como os verify scripts operam) **ou** o `service_role`. **Recomendado: caminho `postgres`/DB-password**, consistente com **SEC-F19** (service-role key permanece fora do CI). `INSERT` é o único DML permitido; `UPDATE/DELETE/TRUNCATE` já barrados no banco.

---

## 8. DC2-01 — canal deletado/suspenso → **fail-closed** (sem tombstone)

**Cenário:** um canal presente em `raw_youtube_videos(run)` é deletado/suspenso/encerrado **entre** Video Data e Channel Data. `channels.list` **omite** o `channel_id` do `body.items[]`.

**Handling obrigatório (DEC-0017 item 6; `DATA-COLLECT-002 §9`):**

1. **NÃO fabricar linha raw.** Não há `item` no body ⇒ `raw_json` (`NOT NULL`) só teria valor inventado; fabricar é proibido (raw é cópia verbatim).
2. **NÃO descartar silenciosamente os vídeos do canal.** Encolheria o denominador de Signals/Competition (`DATA-CHANNEL-001 §8.1`).
3. **Falhar o gate §7** (set-equality canais↔vídeos não fecha) → `report_runs.status = 'failed'` para a run inteira.
4. **Recoleta = novo `run_id`** (run inteira: Search + Video + Channel). As linhas raw já confirmadas ficam como **run parcial falha** (evidência imutável), nunca snapshot elegível.
5. **SEM tombstone agora.** A tabela aplicada não tem coluna de "ausente/deletado" e `raw_json` é `NOT NULL`. Política de tombstone seria migration **aditiva e gated** (coluna `is_present`/`collection_status`) — fora desta trilha (`OPEN-DC2-01`, ratificado como fail-closed pela Database em `docs/database/HANDOFF-channel-data-collection-review.md`).

> **Por que fail-closed é a decisão certa agora:** um canal que some entre os dois estágios torna a run **irreprodutível na fonte** (o raw do canal não existe mais para congelar). Deixar a run avançar produziria elegibilidade/Competition sobre um denominador furado — viola o non-negotiable "nada de número falso". Abortar + novo `run_id` é honesto e mantém **zero schema delta**.

---

## 9. Gate de completude do snapshot de canais (`DATA-COLLECT-002 §7`)

Antes de a run ser declarada **pronta para o Channel Filter**, **todas** as condições passam no mesmo ciclo de finalização:

- [ ] gate de vídeos de `DATA-COLLECT-001 §7` já passou (vetor `(run_id, video_id)` congelado; run não `failed`);
- [ ] `ChannelsToCollect(run)` reconstruído deterministicamente dos `channel_id` distintos de `raw_youtube_videos(run)` (§3);
- [ ] **set-equality dura:** `set(raw_youtube_channels.channel_id WHERE run_id=run) == set(raw_youtube_videos.channel_id WHERE run_id=run)` — **sem faltas e sem extras**;
- [ ] uma única linha por canal (índice `(run_id, channel_id)`);
- [ ] cada projeção coincide com seu `raw_json`; estatística ausente/oculta permanece `NULL`;
- [ ] `raw_json` e `fetched_at` não nulos; `raw_json` **sem** chaves de envelope de request (CHECK `raw_youtube_channels_no_request_context` satisfeito, SEC-F08);
- [ ] todo `channel_id` solicitado retornou item (nenhum omitido sem decisão registrada — DC2-01/§8);
- [ ] run não está `failed`.

Falta de canal ⇒ Channel Filter não grava veredito (FK) ⇒ **fail-closed** (§8). Extra ⇒ canal sem vídeo violando a não-expansão. O estágio de Channel Filter **repete** este preflight; não confia só no status do processo anterior.

**Não há rollback.** O raw é append-only/imutável: uma run ruim **não** é revertida — suas linhas ficam como evidência de run falha e a correção é **novo `run_id`**. O "verify" aqui é este gate de completude (pré-Channel-Filter/pré-publish), **não** um gatilho de rollback como nas migrations.

---

## 10. Pipeline gated (desenho — espelha `entity-db-apply.yml`)

> **Este runbook descreve o pipeline; NÃO autora o YAML** (fora de `docs/`; é tarefa DevOps `define_pipeline` futura, atrás dos gates da §11). Ver o desenho completo em `docs/infra/HANDOFF-gated-channel-data-collection.md`.

**Espinha herdada de `entity-db-apply.yml` (precedente gated):**

- `on: workflow_dispatch` **único** — zero `push`, zero `schedule` (cron é Fase 2). Frase de confirmação obrigatória (ex.: `RUN-CHANNEL-COLLECTION`).
- Job `guard` (valida a frase) → `collect` (`needs: guard`, `environment: <gated>`) → `verify` (`needs: collect`, gate §7).
- Actions de terceiros **SHA-pinadas** (SEC-F17); `permissions: contents: read`; `concurrency` group dedicado, `cancel-in-progress: false`.
- **Required reviewers** do Environment = **DevOps + Security** (matrix #8) — aprovação humana em tempo de execução.
- **SEC-F18:** Environment restrito a **`main`** (deployment branch rule) **antes** de qualquer secret — bloqueia dispatch de branch modificada.
- URL de conexão mascarada (`::add-mask::`), service-role key **não** usada (SEC-F19).

**Delta vs. os applies anteriores (a NOVA superfície de risco):**

| Dimensão | Applies anteriores (phase1–5, entity) | **Channel Data collection (NOVO)** |
|---|---|---|
| Operação | DDL idempotente (`supabase db push`) | **executa job de coleta**: egress externo + INSERT de dado de negócio |
| Secret | só Supabase (`SUPABASE_DB_PASSWORD`, `SUPABASE_ACCESS_TOKEN`) | **+ `YOUTUBE_API_KEY`** — classe de credencial nova, **portadora de custo**, viaja no request |
| Egress de rede | só Supabase (DB do projeto) | **+ `googleapis.com`** (primeiro egress a API de terceiro real) |
| Dado escrito | objetos de schema | **dado de negócio coletado**, em tabela imutável |
| Reversibilidade | rollback SQL disponível | **NENHUMA** — raw append-only; correção = novo `run_id` |
| "Verify" | assere estrutura exata esperada | gate de completude §7 (dado externo é não-determinístico) |

**Decisão de Environment (OQ-1) — recomendação:** **NÃO** reusar `production-db` (misturaria raios de explosão: daria ao job de coleta o `SUPABASE_ACCESS_TOKEN` com direito de push de migration que ele não precisa, e daria aos jobs de migration a `YOUTUBE_API_KEY` que eles não precisam). **Criar Environment dedicado `youtube-collection`** com **least-privilege**: `YOUTUBE_API_KEY` + conexão DB que **INSERTa** nas raw tables mas **não** faz push de migration (sem `SUPABASE_ACCESS_TOKEN`), `main`-only, mesmos required reviewers (DevOps + Security). Provisionamento via `configure_env` (sensível/gated, evidência out-of-band — precedente `INFRA-0001`).

---

## 11. CHECKLIST DE GATE — quem assina o quê, **em ordem** (fail-closed)

**Nenhuma chamada real a `channels.list` antes de TODOS os itens verdes.** Silêncio ≠ aprovação. Poder de veto: Security, Data/AI, QA.

| # | Gate | Responsável (assina) | Estado esperado antes do LIVE |
|---|---|---|---|
| **G0** | **Pré-requisito de vídeos:** pipeline gated de `DATA-COLLECT-001` existe; SEC-F23 de vídeos fechado (residuais SEC-0016 §5 verdes); gate de vídeos §7 passou para a run | Data/AI + Security + DevOps | ⏳ pré-live |
| **G1** | **Ratificações de design landadas:** DEC-0017 item 7 (trilha autorizada); `DATA-COLLECT-002` revisado; **este runbook** + **SEC-0019** + nota Database aprovados | Product Orchestrator | ⏳ |
| **G2** | **Security `audit_secrets` do dado (SEC-0019):** SEC-F23/PII pública em `raw_json` (OPEN-DC2-02) ratificada; CHECK anti-secret confirmado; handling da `YOUTUBE_API_KEY` + higiene de log aprovados | **Security (bloqueante)** | ⏳ |
| **G3** | **Database review:** zero ALTER ratificado; FK composta/imutabilidade; DC2-01 fail-closed confirmado (OPEN-DC2-01) | **Database (bloqueante)** | ⏳ |
| **G4** | **DevOps `define_pipeline`:** workflow gated autorado (dispatch + frase + Environment + required reviewers + SEC-F18 main-only + SHA-pin) → **Security `audit_secrets` do pipeline** (matrix #8; **desvio de template**: NOVO secret/Environment + egress) | DevOps → Security | ⏳ |
| **G5** | **DevOps `configure_env` (SENSÍVEL/gated):** Environment `youtube-collection` provisionado — `YOUTUBE_API_KEY` + conexão DB least-privilege (sem token de migration); `main`-only **antes** dos secrets (SEC-F18); required reviewers; política de rotação/revogação + restrição da key (OQ-7). **Evidência out-of-band exigida** | **DevOps + Security (sensível/humano-gated)** | ⏳ |
| **G6** | **Testes do job verdes (`DATA-COLLECT-002 §8.1–§8.6`):** (1) spy body-vs-envelope; (2) payload limpo aceito / top-level `config/request/headers/authorization/key` rejeitado (CHECK+scrub); (3) canary secret ausente de logs/Sentry — inclui `title`/`description` de canal, Authorization, query string, body; (4) erro de quota/entre lotes → run `failed`/inelegível; (5) retry/restart não duplica/sobrescreve; (6) **canal omitido → sem linha fabricada + gate §7 falha explícita (DC2-01)** | Data/AI + Security | ⏳ pré-live |
| **G7** | **Dispatch humano + frase de confirmação + required reviewers aprovam** em tempo de execução | Humano (Product Lead) + DevOps + Security | ⏳ execução |
| **G8** | **Gate pós-run de completude de canais §7** (set-equality, 1 linha/canal, NULL≠0, CHECK satisfeito, `raw_json`/`fetched_at` não nulos). Falha ⇒ run `failed` ⇒ novo `run_id` | Data/AI | ⏳ pós-run |
| **G9** | **P5-REPRO-01** — gate bloqueante **antes do 1º publish** (não é parte da coleta; a coleta é **pré-condição** do replay) | Data/AI + Product Orchestrator | ⛔ bloqueia publish |

**Vetos intransponíveis (nunca bypassados):** **Fase 9 / RLS Policies** (raw permanece default-deny: RLS-on + revoke, zero policy/zero view); **`0007`/producer_events PARKED**; publish antes de **P5-REPRO-01**.

---

## 12. Observabilidade e higiene de log (`DATA-COLLECT-002 §8`)

- **Permitido em log/Sentry:** `run_id`, estágio (`channel_data`), endpoint nominal (`channels.list`), ordinal do lote, classe do status HTTP, tentativa, código de erro, contador de quota quando disponível.
- **Proibido em log/Sentry:** API key, `Authorization`, URL com query string (`?key=`), request/response body, `title`/`description` de canal, lista de `channel_id` em massa, objeto de config.
- **Sentry:** o scrubber default captura URL/request/breadcrumbs — deve ser **desligado/redatado** para o teste de canary (G6.3) fechar verde. Preferir header `X-Goog-Api-Key` ao `?key=` (URL logável é mais fácil de vazar).
- Mensagem externa de erro **sanitizada**; detalhe técnico sensível não entra em `report_runs` nem no `AgentResult`.

---

## 13. OPEN QUESTIONS (decisão humana antes da execução do Passo 4)

| ID | Tema | Recomendação | Decisor |
|---|---|---|---|
| **OQ-1** | Topologia de Environment: dedicado `youtube-collection` vs. reuso de `production-db` | **Dedicado** (least-privilege; não misturar token de migration com a API key) | DevOps + Security + Product Lead |
| **OQ-2** | Papel de escrita nas raw tables (RLS-on, sem policy) | **`postgres`/DB-password** (owner bypassa RLS; SEC-F19 mantém service-role fora do CI). Confirmar ausência de `FORCE RLS` | Database + Security |
| **OQ-3** | Topologia do workflow / DC2-04: run única (search+videos+channels sob 1 `run_id`) vs. jobs separados | **Run única** (sub-fase C chained) | Product Orchestrator + DevOps |
| **OQ-4** | SEC-F23 / OPEN-DC2-02: conteúdo público de canal em `raw_json` (title/description/customUrl/thumbnails) | Aceitável (coerente com `raw_youtube_videos.raw_json`; não é secret) — Security ratifica em **SEC-0019** | Security |
| **OQ-5** | OPEN-DC2-01: fail-closed agora vs. tombstone aditivo futuro | **Fail-closed** (zero schema delta) — Database ratifica | Database + Data/AI |
| **OQ-6** | Transporte da key: header `X-Goog-Api-Key` vs. `?key=` | **Header** (menos vazável; SEC-0016 §4) | Security + DevOps |
| **OQ-7** | Rotação + restrição da `YOUTUBE_API_KEY` (restringir à YouTube Data API v3, alerta de quota) | Definir gatilhos de rotação (pós-run, troca de pessoal, ≤90d, suspeita de leak) + restrição de API | Security + DevOps |

---

## 14. Fora do escopo / Stop Conditions

- coleta real, consumo de quota, criação de número de produto;
- mudança de keyword/janela/volume/vertical/paginação de Search; descoberta de canal sem vídeo na run;
- ALTER/migration, `description`/`customUrl`/idade em coluna projetada, parts além de `snippet,statistics`;
- **`0007`/producer_events (PARKED)**; **Fase 9 / RLS Policies (VETADA)**; publish antes de **P5-REPRO-01**;
- autoria do YAML do workflow (tarefa DevOps `define_pipeline` futura, atrás da §11);
- provisionamento real de secret/Environment (tarefa `configure_env` sensível/gated, atrás da §11).

**Stop Conditions:** qualquer tentativa de usar Channel Data para mudar parâmetros da coleta de vídeos; mutar raw de canal; fabricar linha para canal omitido; persistir secret/envelope em raw ou log; rodar sobre run `failed`/incompleta; pedir a um modelo gerar qualquer número/elegibilidade; bypassar qualquer gate da §11. Em qualquer uma: **parar** e devolver `needs_review`/`OPEN DECISION`.
