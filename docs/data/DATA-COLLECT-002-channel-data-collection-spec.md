# DATA-COLLECT-002 — Contrato de coleta YouTube (Channel Data)

- **Tarefa:** `task_define_channel_data_collection`
- **Owner:** Data/AI Pipeline Agent (`data_agent`)
- **Ação:** `define_collection_spec` *(ação publicada na allow-list do `data_agent` — `data-ai-pipeline-agent.md` §Operating Protocol)*
- **Versão do contrato:** `DATA-COLLECT-002/v1`
- **Data:** 2026-06-30
- **Estado:** pronto para revisão; **não autoriza coleta real**
- **Natureza:** DESIGN/define-only. Zero coleta, zero API, zero número gerado, zero LLM, zero migration, zero secret, zero rede.
- **Posição:** **extensão** de `DATA-COLLECT-001` (Agentes 1–2). Adiciona a sub-coleta `channels.list` (insumo do Agente 4 — Channel Filter). **Não altera** keyword, janela, volume, paginação nem a fonte do snapshot de ~500 vídeos.
- **Bloqueio que resolve:** `OPEN-DATA-CHANNEL-01` (de `DATA-CHANNEL-001` §8.3) — `channel_eligibility` tem FK obrigatória `(run_id, channel_id) → raw_youtube_channels ON DELETE RESTRICT`, mas `raw_youtube_channels` **nunca é populado** (`DATA-COLLECT-001` §11 põe `channels.list` fora do escopo). Sem esta coleta, **nenhum veredito de elegibilidade pode ser inserido** e os gates 2 (`insufficient_history`) e 4 (`low_channel_signal`) do Channel Filter ficam inavaliáveis.
- **Fontes vinculantes:** `docs/data/DATA-COLLECT-001-youtube-collection-spec.md` (contrato de Search + Video Data que ESTA spec estende; §§1–11); `docs/data/DATA-CHANNEL-001-channel-filter-spec.md` (consumidor; §§3.1, 5.2, 8.1, 8.3 / `OPEN-DATA-CHANNEL-01`); `supabase/migrations/20260620000004_phase4_raw_youtube_snapshots.sql` (`raw_youtube_channels` aplicado, L124–146 + triggers/RLS L165–186); `supabase/migrations/20260620000005_phase5_computed_metrics_reports.sql` (`channel_eligibility` L228–245); `context/03_Data_AI_Agents_Methodology.md` §§3–4, 6, 11–13; `context/NOXUND_Hotspot_Arquitetura_de_Agentes.md` A.2 (Agente 4); `docs/security/SEC-0012-phase4-raw-snapshots-ddl-review.md` (SEC-F23/SEC-F08); `docs/product/scope-guardrails.md`; `docs/product/decisions/DEC-0013-sequencing-pipeline-first.md`; `docs/product/decisions/DEC-0012-phase5-apply-completed.md`.

---

## 1. Escopo, posição e invariantes travados

Este contrato cobre **somente** a sub-coleta de **Channel Data** (`channels.list`) que preenche `raw_youtube_channels` para os canais **já surgidos** no snapshot de vídeos de uma run. Não bate na API, não gera métricas, não muda schema e não autoriza publish. Ele **não** redefine Search/Video Data: roda **depois** do gate de completude de vídeos de `DATA-COLLECT-001 §7`, sobre o conjunto de vídeos já congelado, **sem coletar um único vídeo a mais**.

| Parâmetro | Valor vinculante | Regra |
|---|---|---|
| `keyword` / `q` | `chicago drill type beat` | **Inalterado** — herdado da run de `DATA-COLLECT-001`. Channel Data **não** emite Search nem altera a query. |
| `window_days` | `30` | **Inalterado** — herdado de `report_runs`. Channel Data não tem janela própria; só descreve canais já observados. |
| `target_video_count` | `500` (alvo aproximado) | **Inalterado** — o volume de vídeos é o de `DATA-COLLECT-001`. Channel Data não amplia, não reduz e não reordena o snapshot de vídeos. |
| `vertical` | `Chicago Drill` | **Inalterado**. |
| conjunto de canais | **derivado** dos vídeos da run | `channel_id` distintos de `raw_youtube_videos(run_id)` — **nenhuma descoberta nova de canal**. |
| fonte | YouTube Data API v3 → `channels.list` | parts `snippet,statistics`; em lotes ≤ 50 ids; nenhuma fonte alternativa ou scraping. |

Qualquer tentativa de usar Channel Data para mudar keyword, janela, volume, vertical, paginação de Search ou de descobrir canais que **não** aparecem em `raw_youtube_videos(run)` é **Stop Condition**: não implementar, marcar `OPEN DECISION` e escalar ao Product Lead via Product Orchestrator. Channel Data **só adiciona metadados** de canais que o pipeline já surfou.

**Invariante de não-expansão (central):** `|canais coletados|` é função do snapshot de vídeos congelado; Channel Data não pode aumentá-lo, surgir um canal sem vídeo na run, nem alterar `collected_video_count`.

## 2. Seleção determinística dos canais e modelo de `run_id`

### 2.1 Mesma run, sub-fase de coleta (não há novo `run_id`)

Channel Data **não cria `run_id` novo**. Ela é a sub-fase final da **mesma** run de `DATA-COLLECT-001`: o `run_id` é exatamente o `report_runs.id` que ancora `raw_youtube_search_pages` e `raw_youtube_videos`. Isso é obrigatório porque a FK de `channel_eligibility` é composta `(run_id, channel_id)` e o `raw_youtube_videos.channel_id` precisa casar com `raw_youtube_channels.channel_id` **sob o mesmo `run_id`** (proveniência forte, `DATA-CHANNEL-001 §3.4`).

- **Recoleta = novo `run_id` para a run inteira** (Search + Video Data + Channel Data), nunca recoleta isolada de canais sobre um `run_id` existente (espelha `DATA-COLLECT-001 §2.7` e a imutabilidade do raw). Não existe "atualizar canais" de uma run; existe nova run.
- A identidade da coleta (`keyword`, `vertical`, `window_start`, `window_end`) permanece imutável; Channel Data **não a toca**.

### 2.2 Pré-condição: snapshot de vídeos completo

A sub-fase de canais **só pode iniciar** quando o **gate de completude de `DATA-COLLECT-001 §7` passou** para a run (vetor de `(run_id, video_id)` congelado, sem falha terminal). Sobre uma run `failed` ou ainda `collecting`/inconsistente, Channel Data **não roda** (fail-closed). O gate de vídeos de `DATA-COLLECT-001` permanece **inalterado**; esta spec apenas o **encadeia** como pré-condição e adiciona um gate próprio de canais (§7).

### 2.3 Conjunto-alvo de canais (determinístico, derivado do raw de vídeos)

```text
ChannelsToCollect(run) = { c : ∃ v ∈ raw_youtube_videos(run_id = run) ∧ v.channel_id = c }
```

- `raw_youtube_videos.channel_id` é `text NOT NULL` (cada vídeo tem exatamente um canal). Logo o conjunto é **bem-definido e finito**.
- Cardinalidade: `1 ≤ |ChannelsToCollect| ≤ collected_video_count ≤ 500`. O índice `raw_youtube_videos_run_channel_idx (run_id, channel_id)` (migration Fase 4, L117–118) torna a derivação um varredura barata.
- **Ordem determinística de processamento:** o vetor de canais distintos é derivado por **primeira ocorrência** no vetor canônico de vídeos da run (mesma ordem estável de `DATA-COLLECT-001 §3.2`). A ordem **não** altera o conjunto coletado (idêntico em qualquer ordenação); serve só para lotes/replay determinísticos.
- **Nenhum canal fora desse conjunto** entra na coleta; nenhum canal do conjunto pode ser silenciosamente omitido (ver §7/§9).

### 2.4 Exemplo de referência (sem criar run/coleta real)

```json
{
  "run_id": "<uuid-v4 da MESMA run de DATA-COLLECT-001>",
  "collection_spec_version": "DATA-COLLECT-002/v1",
  "phase": "channel_data",
  "depends_on": "DATA-COLLECT-001/v1 §7 gate passed",
  "channels_source": "distinct raw_youtube_videos(run_id).channel_id",
  "channels_target_count": "<= collected_video_count (<= 500)",
  "keyword": "chicago drill type beat",
  "window_unchanged": true,
  "video_volume_unchanged": true
}
```

`report_runs.youtube_quota_used` continua sendo o contador apurado/estimado pelo adaptador (`DATA-COLLECT-001 §2.5`); ele passa a **somar também** as chamadas `channels.list` (§3.4). O contador não contém request, key nem payload e não converte falha em sucesso.

## 3. Agente 4 (sub-coleta) — contrato de `channels.list`

### 3.1 Request canônica

Cada request usa os mesmos parâmetros, exceto `id`:

```text
part=snippet,statistics
id=<até 50 channel_id do lote, separados por vírgula, na ordem do vetor>
```

- `part=snippet,statistics` é o **mínimo** que cobre os campos exigidos pelo Channel Filter (§4): `snippet.title`, `statistics.videoCount`, `statistics.subscriberCount`, `statistics.viewCount`. **Não** adicionar `contentDetails`, `brandingSettings`, `topicDetails`, `localizations` ou `status` — a omissão faz parte da v1 (minimização de payload e de superfície SEC-F23).
- **Não usar `fields`:** o body completo da resposta (recurso por canal) deve ser preservado verbatim em `raw_json`.
- Não anexar a API key a nenhum objeto que será persistido ou logado (a key é injetada server-side; §8).
- `id` não pode ser fabricado, normalizado para canais fora de `ChannelsToCollect(run)` nem deduplicado de forma que esconda divergência (o conjunto já é distinto por construção; §2.3).

### 3.2 Construção dos lotes

- Usar exatamente o vetor ordenado de `channel_id` distintos produzido no §2.3.
- Particionar sequencialmente em lotes de **até 50 ids**, sem reordenar (limite de `channels.list`; espelha o batching de `videos.list`, `DATA-COLLECT-001 §4.1`).
- Extrair somente o **body** da resposta do cliente HTTP/SDK (nunca o envelope axios/fetch).
- Indexar `body.items[]` por `item.id`; **não** depender da ordem de retorno da API.

### 3.3 Validação do lote (antes de persistir)

Espelha `DATA-COLLECT-001 §4.2`. Verificar que:

- cada `channel_id` solicitado aparece **exatamente uma vez** em `body.items[]`;
- **nenhum** item não solicitado aparece;
- `item.id`, `item.snippet.title` e o bloco `item.statistics` são coerentes com a linha projetada;
- estatística ausente/oculta permanece **`NULL`**, nunca zero fabricado (§4.2);
- cada contador presente é uma **string decimal válida** que cabe em `bigint`;
- `hiddenSubscriberCount = true` ⇒ `subscriber_count = NULL` (não zero), e o flag fica preservado verbatim no `raw_json` (§9).

`channel_id` solicitado **ausente** do `body.items[]` (canal deletado/suspenso/encerrado entre Video Data e Channel Data) é tratado em **§7/§9** como condição de parada da sub-fase — o coletor **não** fabrica linha raw (o body não traz item; `raw_json` é `NOT NULL` e deve ser verbatim) e **não** descarta silenciosamente os vídeos do canal (encolheria o denominador de Signals/Competition, `DATA-CHANNEL-001 §8.1`).

### 3.4 Quota e relação com o orçamento de vídeos

Channel Data é **barata e aditiva**; não muda o orçamento de Search/Video Data:

| Chamada | Custo de leitura (YouTube Data API v3, documentado) | Nº de chamadas na run | Quota |
|---|---|---|---|
| `search.list` (existente) | 100 unidades/página | ~N páginas até 500 ids | dominante |
| `videos.list` (existente) | 1 unidade/chamada | `ceil(≤500 / 50) ≤ 10` | pequena |
| **`channels.list` (esta spec)** | **1 unidade/chamada** (parts `snippet`,`statistics` **não** somam custo extra em `channels.list`) | `ceil(|ChannelsToCollect| / 50) ≤ ceil(500/50) = 10` | **≤ 10 unidades** |

- **Delta de quota:** **no máximo ~10 unidades** por run (limite superior; canais distintos ≤ vídeos ≤ 500). É uma fração desprezível do custo de `search.list`.
- O número exato é **apurado/estimado pelo adaptador** e somado em `report_runs.youtube_quota_used` (`DATA-COLLECT-001 §2.5`); esta spec **não** inventa um valor cravado — descreve o **modelo de custo documentado da API** (custo externo verificável, não número de produto gerado por modelo).
- Channel Data **não consome nenhuma unidade de `search.list`** e **não altera** quantos vídeos são coletados.

## 4. Field mapping `channels.list` → `raw_youtube_channels` (shape aplicado, ratificado)

> `raw_youtube_channels` **já está vivo/verificado** (migration Fase 4 — `20260620000004_phase4_raw_youtube_snapshots.sql`, L124–146; DEC-0011/DEC-0012). Esta seção **documenta o shape autoritativo aplicado** e o **contrato de escrita** sobre ele. **Nenhum ALTER, nenhuma migration nova** é proposta. Deltas eventuais (publishedAt/age) estão isolados em §11 como OPEN QUESTIONS.

### 4.1 Colunas aplicadas (verbatim do SQL aplicado)

```sql
create table public.raw_youtube_channels (
  id               uuid primary key default gen_random_uuid(),
  run_id           uuid not null references public.report_runs (id) on delete restrict,
  channel_id       text not null,
  title            text,
  upload_count     bigint,
  subscriber_count bigint,
  view_count       bigint,
  raw_json         jsonb not null,
  fetched_at       timestamptz not null default now(),
  constraint raw_youtube_channels_no_request_context
    check (not (raw_json ?| array['config', 'request', 'headers', 'authorization', 'key']))
);
create unique index raw_youtube_channels_run_channel_uidx
  on public.raw_youtube_channels (run_id, channel_id);
-- + trigger BEFORE UPDATE/DELETE (imutável) + BEFORE TRUNCATE; RLS enable + revoke anon/authenticated.
```

### 4.2 Mapa campo da API → coluna (honrando NULL ≠ 0)

| Coluna aplicada | Origem (`channels.list` item) | Conversão | Nulo (semântica que o Channel Filter exige) |
|---|---|---|---|
| `run_id` | UUID da **mesma** run (§2.1) | — | nunca nulo (FK → `report_runs`) |
| `channel_id` | `item.id` | string verbatim | nunca nulo |
| `title` | `item.snippet.title` | string verbatim | ausente = sem sinal de título (gate 1 `self_channel` não asserta) |
| `upload_count` | `item.statistics.videoCount` | string decimal → `bigint` exato | **ausente ⇒ `NULL`** (nunca 0). `videoCount` = contagem de **vídeos públicos** do canal — semântica exata de `MIN_PUBLIC_UPLOADS` |
| `subscriber_count` | `item.statistics.subscriberCount` | string decimal → `bigint` exato | **ausente/oculto (`hiddenSubscriberCount=true`) ⇒ `NULL`** (nunca 0) |
| `view_count` | `item.statistics.viewCount` | string decimal → `bigint` exato | **ausente ⇒ `NULL`** (nunca 0) |
| `raw_json` | o objeto `item` **completo e inalterado** (`kind = youtube#channel`) | extraído do body, verbatim | `NOT NULL`; preserva `snippet.publishedAt`, `snippet.thumbnails`, `hiddenSubscriberCount`, etc. |
| `fetched_at` | instante UTC em que o body do lote foi recebido | UTC no recebimento | `NOT NULL`; é o `collected_at` canônico (não usar um timestamp inventado para a run) |

- `id` é gerado pelo banco (`gen_random_uuid()`); o coletor não o fornece.
- **`raw_json` é o recurso bruto por canal**, não a projeção normalizada e não o envelope de transporte. Os quatro campos projetados (`title`, `upload_count`, `subscriber_count`, `view_count`) são **conveniência de leitura**; a verdade última é o `raw_json` (mesma postura de `raw_youtube_videos.raw_json`).
- **`snippet.publishedAt` (data de criação / "idade do canal"):** preservado em `raw_json` verbatim, mas **não há coluna projetada** na tabela aplicada e o **`channel-filter-v1` não usa idade de canal** como gate (gates são `self_channel`/`title`, `insufficient_history`/`upload_count`, `spam_burst`/run-local, `low_channel_signal`/`subscriber+view`). Portanto **não é projetado e não bloqueia** esta coleta. Um eventual gate de idade futuro seria migration **aditiva** + nova `rule_version` (§11, `OPEN-DC2-03`).

### 4.3 Como isto satisfaz os gates 2 e 4 do Channel Filter

`DATA-CHANNEL-001 §5.2` exige sinais de canal que **só** podem vir de `raw_youtube_channels`:

| Gate (`DATA-CHANNEL-001 §5.2`) | Sinal exigido | Coluna preenchida por esta spec | Condição de inelegibilidade |
|---|---|---|---|
| **Gate 1 — `self_channel`** | `title` | `title` ← `snippet.title` | `normalize_channel(title)` = nome/alias canônico do artista |
| **Gate 2 — `insufficient_history`** | `upload_count` | `upload_count` ← `statistics.videoCount` | `upload_count IS NOT NULL` **e** `< MIN_PUBLIC_UPLOADS` |
| **Gate 4 — `low_channel_signal`** | `subscriber_count` **e** `view_count` | `subscriber_count` ← `statistics.subscriberCount`; `view_count` ← `statistics.viewCount` | ambos `IS NOT NULL` **e** abaixo dos pisos (`MIN_SUBSCRIBERS`/`MIN_CHANNEL_VIEWS`) |

- **NULL nunca vira zero.** Um canal que oculta `subscriberCount` (`hiddenSubscriberCount=true`) ou omite `viewCount`/`videoCount` chega ao Channel Filter com a coluna correspondente em `NULL`; os gates 2/4 **não disparam** (`DATA-CHANNEL-001 §3.1`, §5.2). Esta coleta é a **garantia upstream** dessa semântica: não fabricar 0 onde a API não deu número.
- **Gate 3 — `spam_burst`** é run-local (deriva de `raw_youtube_videos`) e não depende desta coleta — mas a **escrita** do veredito ainda exige a linha raw do canal (FK). Por isso esta coleta é pré-condição de **todo** veredito, inclusive o de `spam_burst`.

## 5. Append-only, idempotência e proveniência

- `raw_youtube_channels` é **insert-only** e **imutável por trigger** (Fase 4, L165–170): proibidos `UPDATE`, `DELETE`, `TRUNCATE`, `UPSERT ... DO UPDATE` e qualquer correção in-place — inclusive abaixo do `service_role` (que faz bypass de RLS, SEC-F01).
- **Chave de idempotência imposta pelo schema:** `(run_id, channel_id)` único (`raw_youtube_channels_run_channel_uidx`). Exatamente **uma** linha por canal por run.
- Cada lote (≤ 50 canais) é persistido em uma **transação** (atômica), espelhando `DATA-COLLECT-001 §4.3/§5`.
- **Retomada de sub-fase ainda em andamento:** uma linha já existente para `(run_id, channel_id)` é **lida e reutilizada**, nunca requisitada de novo nem sobrescrita. Para um lote determinístico: zero linhas existentes permite a chamada; todas existentes permitem reutilizar o raw; existência parcial é violação de atomicidade e **falha** a run.
- `unique_violation` **nunca** é engolida com `DO NOTHING`: o coletor compara a chave esperada ao raw existente; divergência ou origem não explicada **falha explicitamente** (espelha `DATA-COLLECT-001 §5`).
- **Proveniência forte:** toda linha ancora em `(run_id, channel_id)`; como `raw_youtube_videos(run_id, channel_id)` também usa essa chave natural, Channel Filter/Competition/Signals permanecem **reconstruíveis até o raw** sem depender de UUID mutável (`DATA-CHANNEL-001 §3.4`).
- Depois que a run recebe `status='failed'` ou conclui os gates, qualquer nova coleta (de qualquer sub-fase) usa **novo `run_id`**.

## 6. Fail-closed em quota, API, persistência e processo

Espelha `DATA-COLLECT-001 §6`. Qualquer erro não recuperado em request, quota, validação de body, conversão, transação ou finalização da sub-fase de canais causa:

1. retorno de erro estruturado pelo job;
2. `report_runs.status = 'failed'` (a run **inteira**, não só os canais);
3. **nenhum** estado que aparente "snapshot completo para Channel Filter";
4. bloqueio absoluto de Channel Filter, scoring, relatório e publish para a run;
5. preservação das linhas raw já confirmadas (vídeos e quaisquer canais), porque são evidência imutável — formam uma **run parcial falha**, nunca um snapshot elegível;
6. nova execução **com novo `run_id`**.

Retries transitórios podem ocorrer somente antes de declarar a falha terminal, segundo política versionada do job. Resposta já persistida é **reutilizada, não refeita**. Esgotamento de retry/quota é falha explícita; **não existe sucesso degradado** (ex.: "coletei 90% dos canais e segui"). Crash com a sub-fase de canais incompleta **não é sucesso**: a retomada só pode seguir as regras idempotentes do §5; sem prova de consistência → `failed`.

## 7. Gate de completude do snapshot de canais

Gate **adicional** ao de `DATA-COLLECT-001 §7` (que permanece inalterado e é pré-condição, §2.2). Antes de a run ser declarada **pronta para o Channel Filter**, todas as condições abaixo devem passar no mesmo ciclo de finalização:

- gate de vídeos de `DATA-COLLECT-001 §7` já passou (vetor `(run_id, video_id)` congelado; run não `failed`);
- `ChannelsToCollect(run)` reconstruído deterministicamente dos `channel_id` distintos de `raw_youtube_videos(run)` (§2.3);
- conjunto `(run_id, channel_id)` em `raw_youtube_channels` **exatamente igual** a `ChannelsToCollect(run)` — **sem faltas e sem extras**;
- uma única linha por canal (índice `(run_id, channel_id)`);
- cada projeção de canal coincide com seu `raw_json`; estatística ausente/oculta permanece `NULL`;
- `raw_json` e `fetched_at` não nulos; `raw_json` sem chaves de envelope de request (CHECK SEC-F08 satisfeito);
- todo `channel_id` solicitado retornou item (nenhum canal omitido sem decisão registrada — §9);
- run não está `failed`.

**Igualdade de conjuntos é a invariante dura:** `set(raw_youtube_channels.channel_id WHERE run_id=run) == set(raw_youtube_videos.channel_id WHERE run_id=run)`. Falta de canal ⇒ Channel Filter não consegue gravar veredito (FK) ⇒ **fail-closed** (§9). Extra ⇒ canal sem vídeo na run violando a invariante de não-expansão (§1). O estágio de Channel Filter deve **repetir esse preflight**; não confia apenas no status do processo anterior.

## 8. Segurança — gate SEC-F23/SEC-F08 antes da coleta real

O `data_agent` não define política de secrets e não recebe a key no `TaskCommand` (espelha `DATA-COLLECT-001 §8`).

- `YOUTUBE_API_KEY` é injetada no job **server-side** por mecanismo aprovado por Security/DevOps; nunca é argumento de CLI, campo de banco, payload de tarefa ou variável `NEXT_PUBLIC_*`.
- Persistir **somente** o body (recurso de canal). Nunca persistir cliente, request, URL com `?key=`, headers, `Authorization`, config, stack trace ou envelope axios/fetch.
- O CHECK `raw_youtube_channels_no_request_context` (rejeita topo `config/request/headers/authorization/key`) é **defesa adicional** (SEC-F08), **não** substitui o scrub no coletor. Body legítimo de `channels.list` nunca tem essas chaves no topo → zero falso-positivo.
- **PII de canal:** o body de `channels.list` pode conter texto livre (`snippet.title`, `snippet.description`, `snippet.customUrl`, thumbnails). A v1 **não** projeta `description`/`customUrl` em coluna (só `title`, exigido pelo gate 1) — mas eles **viajam no `raw_json`**. Isso é coerente com `raw_youtube_videos.raw_json` (que já guarda `title`/thumbnails). Confirmar com Security que o conteúdo público de canal em `raw_json` é aceitável sob SEC-F23 (não é secret; é dado público da API) — registrado em `OPEN-DC2-02`.
- **Logs/Sentry permitidos:** `run_id`, estágio (`channel_data`), endpoint nominal (`channels.list`), ordinal do lote, classe do status HTTP, tentativa, código de erro e contador de quota quando disponível.
- **Logs/Sentry proibidos:** API key, `Authorization`, URL com query string, request/response body, `title`/`description` de canal, lista de `channel_id` em massa e objeto de config.

Testes obrigatórios do job antes de live (espelham `DATA-COLLECT-001 §8`):

1. spy do adaptador de persistência comprova que ele recebe o **body**, não o envelope;
2. payload limpo é aceito; payload com chaves top-level `config`/`request`/`headers`/`authorization`/`key` é **rejeitado** (CHECK + scrub);
3. captura de logs/Sentry com canary secret comprova ausência do canary, `Authorization`, query string, body e títulos de canal;
4. erro de quota e erro entre lotes deixam a run `failed` e inelegível;
5. retry/restart **não duplica nem sobrescreve** raw de canal;
6. canal omitido pela API (deletado/suspenso) **não** gera linha fabricada e **falha** o gate §7 de forma explícita.

**Gate:** Security (`audit_secrets`, SEC-F23/quota) + DevOps devem revisar secret injection e higiene de logs **antes** da primeira chamada `channels.list` real. **Silêncio não é aprovação.**

## 9. Casos de borda

- **Canal deletado/suspenso/encerrado entre Video Data e Channel Data** → `channels.list` **omite** o `channel_id`. Não há item ⇒ `raw_json NOT NULL` impede inserir linha verbatim; fabricar linha é proibido. **Default fail-closed:** o gate §7 não fecha; a run não fica pronta para Channel Filter; nova run (novo `run_id`) é a via de correção. Política alternativa (tombstone documentado) é `OPEN-DC2-01` (precisa Database + Data/AI — a tabela aplicada não tem coluna de "ausente/deletado" e `raw_json` é `NOT NULL`). **Não** descartar os vídeos do canal silenciosamente (`DATA-CHANNEL-001 §8.1`).
- **`hiddenSubscriberCount = true`** → `subscriber_count = NULL` (não 0); flag preservado em `raw_json`. Gate 4 do Channel Filter **não dispara** por falta de sinal (NULL ≠ pequeno).
- **`statistics` parcial** (ex.: `viewCount` presente, `subscriberCount` ausente) → cada coluna ausente vira `NULL` independentemente; nunca 0 fabricado. Gate 4 exige **ambos** presentes e baixos para disparar; um `NULL` desarma o gate.
- **`videoCount = 0` legítimo** (canal real sem uploads públicos) → `upload_count = 0` (zero **real** da API, não fabricado). Gate 2 pode disparar `insufficient_history` se `0 < MIN_PUBLIC_UPLOADS`. Distinguir `0` (presente) de `NULL` (ausente) é mandatório.
- **Contador acima de `int32`** (canais grandes: `viewCount`/`subscriberCount`) → coluna é `bigint`; converter exato; overflow é falha de validação (§3.3), não truncamento silencioso.
- **Mesmo `channel_id` em ≥ 2 vídeos da run** (caso comum) → entra **uma vez** em `ChannelsToCollect` (distinct); uma linha em `raw_youtube_channels`. O footprint multi-vídeo do canal é do Channel Filter (Competition conta canal 1×, `DATA-CHANNEL-001 §6.2`), não desta coleta.
- **Item não solicitado / duplicado no body** → violação de validação (§3.3) ⇒ run `failed`.

## 10. Reprodutibilidade e pré-condição para P5-REPRO-01

Esta coleta **congela** o que foi observado dos canais no instante da run; não promete que uma chamada futura ao YouTube retorne os mesmos contadores. Reprodutibilidade = **reprocessar o mesmo raw**.

Uma run que passa o §7 fornece ao Channel Filter (`DATA-CHANNEL-001 §7`) e ao P5-REPRO-01:

- recurso de canal **verbatim** por `(run_id, channel_id)` em `raw_youtube_channels`, com `fetched_at`;
- igualdade de conjuntos canais↔vídeos garantida (§7), base da FK `channel_eligibility → raw_youtube_channels`;
- sinais `title`/`upload_count`/`subscriber_count`/`view_count` que tornam os gates 1/2/4 **funções puras do raw** (sem rede, sem LLM, sem relógio) → `channel-filter-v1` é byte-reprodutível (`DATA-CHANNEL-001 §7.1`).

P5-REPRO-01 permanece **gate bloqueante antes do 1º publish**: duas execuções sobre o mesmo `run_id` + mesmas `resolver_version`/`rule_version` + mesmas decisões replayable devem produzir elegibilidade/Signals/Competition **byte-idênticos** (excluindo só UUIDs e timestamps operacionais). Esta coleta é **pré-condição** desse replay, não parte dele.

## 11. OPEN QUESTIONS (para Orchestrator / Database / Security / Data-AI antes de qualquer apply/live)

| ID | Tema | Impacto | Encaminhamento |
|---|---|---|---|
| **OPEN-DC2-01** *(bloqueante p/ LIVE)* | **Canal deletado/suspenso omitido por `channels.list`**: a tabela aplicada não tem coluna de "ausente/deletado" e `raw_json` é `NOT NULL`; não dá para registrar tombstone verbatim. | Sem política, a run **falha-fecha** sempre que um canal some entre Video Data e Channel Data — pode bloquear runs legítimas. | **Decisão Database + Data/AI:** (a) manter fail-closed (recoleta = novo `run_id`) — recomendado, zero schema delta; ou (b) política de tombstone exigiria migration **aditiva e gated** (coluna `is_present`/`collection_status`), fora desta spec. Esta spec **não** ALTERa. |
| **OPEN-DC2-02** | **PII/conteúdo público de canal em `raw_json`** (`snippet.title/description/customUrl/thumbnails`). | Postura SEC-F23 sobre dado público armazenado verbatim. | **Security review:** confirmar que conteúdo público da API em `raw_json` é aceitável (coerente com `raw_youtube_videos.raw_json`); confirmar que a v1 projeta só `title` em coluna. Não é secret. |
| **OPEN-DC2-03** | **`snippet.publishedAt` (idade do canal)** não tem coluna projetada; `channel-filter-v1` **não** usa idade como gate. | Se um gate de idade for desejado no futuro, falta coluna. | **Não bloqueia** (campo vive no `raw_json`). Futuro gate de idade = migration **aditiva** + nova `rule_version` (Data/AI + Database). |
| **OPEN-DC2-04** | **Sequência operacional do gate de canais** vs. o gate de vídeos de `DATA-COLLECT-001 §7` (sub-fase única na mesma run vs. job separado encadeado). | Orquestração/operação do job; não muda o contrato de dados. | **Product Orchestrator + DevOps:** ratificar que Channel Data é sub-fase da **mesma run** (`run_id` compartilhado), pré-condicionada ao gate de vídeos. Esta spec assume isso (§2). |
| **OPEN-DC2-05** *(herdada)* | **Constantes** `{ MIN_PUBLIC_UPLOADS, MIN_SUBSCRIBERS, MIN_CHANNEL_VIEWS }` do `channel-filter-v1` (consumidoras destes campos). | Governam Competition → Data/AI Review. | É a `OPEN-DATA-CHANNEL-02` de `DATA-CHANNEL-001`; **fora do escopo desta coleta** — só registrada porque estes campos as alimentam. |

## 12. Revisões e Stop Conditions

| Gate | Estado desta entrega |
|---|---|
| Data/AI — contrato de raw de canal, determinismo, NULL≠0, replay | concluído nesta spec |
| Product Orchestrator — sequência da sub-coleta na run / não-expansão do snapshot | pendente antes da coleta real |
| Security — SEC-F23/SEC-F08, `YOUTUBE_API_KEY`, body-only, log hygiene, PII pública (`OPEN-DC2-02`) | pendente antes da coleta real |
| DevOps — job interno, secret injection, Sentry, encadeamento ao gate de vídeos | pendente antes da coleta real |
| Database — `OPEN-DC2-01` (tombstone vs fail-closed); confirmar **zero** delta de schema p/ v1 | pendente |
| P5-REPRO-01 | pendente e bloqueante antes do 1º publish |

**Stop Conditions:** tentativa de usar Channel Data para mudar keyword/janela/volume/paginação; descobrir canal sem vídeo na run; mutar raw de canal; fabricar linha para canal omitido; persistir secret/envelope em raw ou log; rodar sobre run `failed`/incompleta; pedir à IA gerar qualquer número/elegibilidade. Em qualquer uma: **parar** e devolver `needs_review`/`OPEN DECISION` conforme a causa.

## 13. Fora do escopo

- coleta real, consumo de quota ou criação de número de produto;
- Search/Video Data (cobertos por `DATA-COLLECT-001`), Entity Resolution, regra de elegibilidade (`channel-filter-v1`, coberta por `DATA-CHANNEL-001`), scoring, Opportunity, relatório;
- **qualquer** mudança de keyword/janela/volume/vertical/paginação ou descoberta de canal novo;
- coleta de parts além de `snippet,statistics`; `description`/`customUrl`/idade em coluna projetada; multi-keyword, multi-vertical, data lake contínuo ou qualquer feature de Fase 2;
- migration/ALTER, policy de secret, endpoint, deploy ou publish;
- **Migration `0007` / `producer_events`: PARKED** (DEC-0013) — fora desta cadeia;
- **Fase 9 (RLS Policies + VIEW pública, SEC-0001 §0): VETADA** — `raw_youtube_channels` permanece default-deny (RLS-on + revoke, **zero policy/zero view**), exatamente como aplicado;
- **Zero IA / zero número gerado por modelo.** Todo campo coletado é cópia verbatim do body da API; toda elegibilidade derivada dele é determinística (Channel Filter).
