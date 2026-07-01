# DATA-COLLECT-001 — Contrato de coleta YouTube (Search + Video Data)

- **Tarefa:** `task_dataengine_define_collection_spec`
- **Owner:** Data/AI Pipeline Agent (`data_agent`)
- **Ação:** `define_collection_spec`
- **Versão do contrato:** `DATA-COLLECT-001/v1`
- **Data:** 2026-06-28
- **Estado:** pronto para revisão; **não autoriza coleta real**
- **Caminho crítico:** data-engine + P5-REPRO-01 → 1º relatório → publish → convite → eventos
- **Fontes vinculantes:** `context/03_Data_AI_Agents_Methodology.md` §§3–4, 11–13; `context/NOXUND_Hotspot_Arquitetura_de_Agentes.md` A.2; `context/04_Database_Event_Model.md` §4; `docs/product/mvp-backlog.md` Épico 5; `docs/product/decisions/DEC-0013-sequencing-pipeline-first.md`; `docs/security/SEC-0012-phase4-raw-snapshots-ddl-review.md` (SEC-F23); `docs/database/DATA-AI-0007-phase5-approval.md` §3.

## 1. Escopo e invariantes travados

Este contrato cobre somente os Agentes 1 e 2: `search.list` paginado e `videos.list` em lotes. Não bate na API, não gera métricas, não muda schema e não autoriza publish.

| Parâmetro | Valor vinculante | Regra |
|---|---|---|
| `keyword` / `q` | `chicago drill type beat` | Literal exato, sem trim, aspas, expansão, sinônimo ou termo adicional. |
| `window_days` | `30` | `window_end` é capturado uma vez; `window_start = window_end - 30 days`. Os mesmos bounds UTC são usados em todas as páginas. |
| `target_video_count` | `500` (alvo aproximado) | Coletar no máximo os primeiros 500 `video_id` únicos em ordem estável. Menos só é aceitável por esgotamento natural da fonte, nunca por erro/quota. |
| `vertical` | `Chicago Drill` | Uma única vertical. |
| fonte | YouTube Data API v3 | `search.list` e `videos.list`; nenhuma fonte alternativa ou scraping. |

Qualquer mudança de keyword, janela, volume, vertical ou fonte é **Stop Condition**: não implementar, marcar `OPEN DECISION` e escalar ao Product Lead via Product Orchestrator.

## 2. Modelo de `run_id` e ciclo de vida

1. Gerar um UUID novo antes da primeira chamada externa. Esse UUID é `report_runs.id` e o `run_id` comum de Search e Video Data.
2. Criar `report_runs` com:
   - `keyword = 'chicago drill type beat'`;
   - `vertical = 'Chicago Drill'`;
   - `window_end =` instante UTC capturado uma única vez;
   - `window_start = window_end - interval '30 days'`;
   - `target_video_count = 500`;
   - `collected_video_count = NULL` até a finalização íntegra;
   - `status = 'created'`.
3. Mudar para `status = 'collecting'` imediatamente antes da primeira chamada à API. A identidade da coleta (`keyword`, `vertical`, `window_start`, `window_end`) permanece imutável.
4. `raw_youtube_search_pages.fetched_at` e `raw_youtube_videos.fetched_at` são o `collected_at` canônico exigido pelo contrato. O coletor os fornece em UTC no recebimento do body; não usa um único timestamp inventado para a run inteira.
5. `youtube_quota_used` registra o consumo apurado/estimado pelo adaptador, inclusive em falha quando conhecido. Esse contador não contém request, key ou payload e não converte falha em sucesso.
6. A coleta só é considerada completa quando o gate do §7 passa e `collected_video_count` é gravado em uma finalização única. O coletor não promove a run para `processed` ou `published`; esses estados pertencem às etapas posteriores.
7. Run terminal `failed`, run já finalizada ou qualquer recoleta nunca reutiliza `run_id`. Uma nova tentativa de coleta gera outro UUID e outro snapshot.

Exemplo de referência, sem criar uma run real:

```json
{
  "run_id": "<uuid-v4-novo>",
  "collection_spec_version": "DATA-COLLECT-001/v1",
  "keyword": "chicago drill type beat",
  "vertical": "Chicago Drill",
  "window_start": "<window_end UTC menos 30 dias>",
  "window_end": "<instante UTC fixado antes da primeira request>",
  "target_video_count": 500
}
```

## 3. Agente 1 — contrato de `search.list`

### 3.1 Request canônica

Cada request usa os mesmos parâmetros, exceto `pageToken`:

```text
part=snippet
q=chicago drill type beat
type=video
order=relevance
maxResults=50
publishedAfter=<report_runs.window_start em RFC 3339 UTC>
publishedBefore=<report_runs.window_end em RFC 3339 UTC>
pageToken=<ausente na primeira página; depois, nextPageToken verbatim da página anterior>
```

- `order=relevance` torna explícita a ordenação usada pela paginação; não altera a query travada.
- Não usar `fields`: o body completo da resposta deve ser preservado.
- Não adicionar `regionCode`, `relevanceLanguage`, `topicId`, `safeSearch` ou filtros `video*`; a omissão faz parte da v1.
- Não anexar a API key a nenhum objeto que será persistido ou logado.
- `pageToken` não pode ser fabricado, normalizado, pulado nem reutilizado fora da cadeia retornada pela API.

### 3.2 Paginação e seleção determinísticas

1. A primeira página usa `page_token = NULL`.
2. Persistir o body recebido antes de avançar. O `nextPageToken` usado na página seguinte deve ser exatamente o valor do body anterior.
3. Falhar se houver ciclo/repetição de token, token esperado ausente no encadeamento ou divergência entre o token solicitado e o token auditado.
4. Derivar candidatos na ordem `(page_ordinal, item_ordinal)` do body bruto.
5. Aceitar apenas `item.id.videoId` não vazio. Deduplicar por `video_id`, preservando a primeira ocorrência.
6. Parar quando houver 500 IDs únicos ou quando uma resposta válida não trouxer `nextPageToken`.
7. Se a fonte terminar antes de 500, finalizar como `source_exhausted` na evidência operacional e submeter o volume real à revisão Product Orchestrator + Data/AI. Não ampliar janela/query e não mascarar como erro.

### 3.3 Escrita raw

Para cada página, executar apenas `INSERT` em `raw_youtube_search_pages`:

| Coluna | Origem |
|---|---|
| `run_id` | UUID da run |
| `page_token` | token usado na request; `NULL` na primeira página |
| `response_json` | body JSON completo da resposta, verbatim; nunca envelope HTTP/SDK |
| `fetched_at` | instante UTC em que o body foi recebido |

O body preserva `items`, `pageInfo`, `nextPageToken` e demais campos enviados pelo YouTube. Query e bounds ficam auditáveis em `report_runs`; o token de entrada fica na linha; o token de saída fica no body.

## 4. Agente 2 — contrato de `videos.list`

### 4.1 Construção dos lotes

- Usar exatamente o vetor ordenado de IDs únicos produzido no §3.
- Particionar sequencialmente em lotes de até 50 IDs, sem reordenar.
- Request canônica: `part=statistics,snippet` e `id=<IDs do lote>`.
- Extrair somente o body da resposta do cliente HTTP/SDK.
- Indexar `body.items[]` por `item.id`; não depender da ordem de retorno da API.

### 4.2 Validação do lote

Antes de persistir, verificar que:

- cada ID solicitado aparece exatamente uma vez;
- nenhum item não solicitado aparece;
- `item.id`, `item.snippet.channelId`, `item.snippet.title` e `item.snippet.publishedAt` são coerentes com a linha projetada;
- estatística ausente permanece `NULL`, nunca zero fabricado;
- contador presente é uma string decimal válida e cabe em `bigint`.

ID ausente (vídeo removido/privado entre Search e Video Data), duplicado, inválido ou inesperado torna a run `failed`. O coletor não descarta o vídeo silenciosamente nem reduz o denominador.

### 4.3 Escrita raw

Cada lote é persistido em uma transação de banco. Para cada `body.items[]`, executar apenas `INSERT` em `raw_youtube_videos`:

| Coluna | Origem |
|---|---|
| `run_id` | UUID da run |
| `video_id` | `item.id` |
| `channel_id` | `item.snippet.channelId` |
| `title` | `item.snippet.title` |
| `published_at` | `item.snippet.publishedAt` |
| `views` | `item.statistics.viewCount`, convertido exatamente; `NULL` se ausente |
| `likes` | `item.statistics.likeCount`, convertido exatamente; `NULL` se ausente |
| `comments` | `item.statistics.commentCount`, convertido exatamente; `NULL` se ausente |
| `raw_json` | o objeto `item` completo e inalterado extraído do body (`kind = youtube#video`) |
| `fetched_at` | instante UTC em que o body do lote foi recebido |

`raw_json` não é a projeção normalizada e não é o envelope de transporte: é o recurso bruto por vídeo retornado dentro do body. Thumbnails e URL derivável permanecem nele; não criam escrita computed nesta etapa.

## 5. Contrato append-only e idempotência dentro da run

- As duas tabelas raw são insert-only. Proibidos: `UPDATE`, `DELETE`, `TRUNCATE`, `UPSERT ... DO UPDATE` e qualquer correção in-place.
- Chaves de idempotência já impostas pelo schema:
  - página: `(run_id, coalesce(page_token, ''))`;
  - vídeo: `(run_id, video_id)`.
- Cada página é gravada atomicamente; cada lote de até 50 vídeos também.
- Em retomada de processo ainda `collecting`, uma página já existente é lida e reutilizada como fonte da continuação; ela não é requisitada novamente nem sobrescrita.
- Para um lote determinístico, zero linhas existentes permite a chamada; todas as linhas existentes permitem reutilizar o raw; existência parcial é violação de atomicidade e falha a run.
- `unique_violation` nunca é engolida com `DO NOTHING`: o coletor compara a chave esperada ao raw existente. Divergência ou origem não explicada falha explicitamente.
- Depois que a run recebe `status = 'failed'` ou conclui o gate, qualquer nova coleta usa novo `run_id`.

## 6. Fail-closed em quota, API, persistência e processo

Qualquer erro não recuperado em request, quota, validação de body, paginação, conversão, transação ou finalização causa:

1. retorno de erro estruturado pelo job;
2. `report_runs.status = 'failed'`;
3. nenhum `collected_video_count` que aparente completude;
4. bloqueio absoluto de Entity Resolution, scoring, relatório e publish para a run;
5. preservação de linhas raw já confirmadas, se houver, porque são evidência imutável — elas formam uma **run parcial falha**, nunca um snapshot elegível;
6. nova execução de coleta com novo `run_id`.

Retries transitórios podem ocorrer somente antes de declarar a falha terminal, segundo política versionada do job. Uma resposta já persistida é reutilizada, não refeita. Esgotamento de retry ou quota é falha explícita; não existe sucesso degradado.

Crash com `status = 'collecting'` e `collected_video_count = NULL` não é sucesso. A retomada só pode seguir as regras idempotentes do §5; caso não consiga provar consistência, deve marcar `failed`.

## 7. Gate de completude do snapshot

Antes de preencher `collected_video_count` e entregar a run ao próximo agente, todas as condições abaixo devem passar no mesmo ciclo de finalização:

- identidade da run igual aos quatro parâmetros travados e janela exatamente de 30 dias;
- cadeia começa em `page_token = NULL`, segue cada `nextPageToken` verbatim e não contém ciclo;
- parada explicada por `target_reached` ou `source_exhausted`, nunca por erro;
- vetor de IDs reconstruído deterministicamente dos raw search bodies;
- conjunto `(run_id, video_id)` em `raw_youtube_videos` exatamente igual ao vetor selecionado (sem faltas nem extras);
- uma única linha por página/token e por vídeo, conforme os índices únicos;
- cada projeção de vídeo coincide com seu `raw_json`; ausência de estatística continua `NULL`;
- `response_json`, `raw_json` e `fetched_at` não nulos e sem envelope de request;
- `collected_video_count = count(distinct video_id)` e nunca excede 500;
- run não está `failed`.

Somente após essas verificações o job grava o total real. O próximo estágio deve repetir esse preflight; não confia apenas no status do processo anterior.

## 8. Segurança — gate SEC-F23 antes da coleta real

O `data_agent` não define política de secrets e não recebe a key no `TaskCommand`.

- `YOUTUBE_API_KEY` é injetada no job server-side por mecanismo aprovado por Security/DevOps; nunca é argumento de CLI, campo de banco, payload de tarefa ou variável `NEXT_PUBLIC_*`.
- Persistir somente o body (`response.data`/equivalente). Nunca persistir cliente, request, URL, headers, config, stack trace ou envelope axios/fetch.
- Os CHECKs SEC-F08 do schema são defesa adicional, não substituem o scrub no coletor.
- Logs/Sentry permitidos: `run_id`, estágio, endpoint nominal, ordinal da página/lote, classe do status HTTP, tentativa, código de erro e contador de quota quando disponível.
- Logs/Sentry proibidos: API key, Authorization, URL com query string, request/response body, título, `pageToken`, IDs em massa e objeto de config.
- Mensagem externa de erro é sanitizada; detalhe técnico sensível não entra em `report_runs` nem no `AgentResult`.

Testes obrigatórios do job antes de live:

1. spy do adaptador de persistência comprova que ele recebe o body, não o envelope;
2. payload limpo é aceito e payload com chaves top-level `config`, `request`, `headers`, `authorization` ou `key` é rejeitado;
3. captura de logs/Sentry com canary secret comprova ausência do canary, Authorization, query string, body e page token;
4. erro de quota e erro entre lotes deixam a run `failed` e inelegível;
5. retry/restart não duplica nem sobrescreve raw.

**Gate:** Security (`audit_secrets`) + DevOps devem revisar secret injection e higiene de logs antes da primeira chamada real. Silêncio não é aprovação.

## 9. Pré-condição para P5-REPRO-01

Esta coleta congela o que foi observado; ela não promete que uma nova chamada futura ao YouTube retornará a mesma ordenação ou estatística. Reprodutibilidade significa reprocessar o **mesmo raw**.

Uma run que passa o §7 fornece ao P5-REPRO-01:

- query e bounds imutáveis em `report_runs`;
- cadeia completa de tokens e bodies de Search em `raw_youtube_search_pages`;
- recursos de vídeo verbatim e timestamps em `raw_youtube_videos`;
- conjunto de IDs reconstruível em ordem estável;
- `run_id` único que ancora computed, versions e decisões replayable.

P5-REPRO-01 permanece gate bloqueante: duas execuções sobre o mesmo `run_id`, rubric, resolver/rule versions e decisões replayable devem produzir células de negócio/evidência idênticas byte a byte, excluindo apenas UUIDs e timestamps operacionais. Qualquer divergência é bug metodológico e bloqueia o primeiro publish.

## 10. Revisões e Stop Conditions

| Gate | Estado desta entrega |
|---|---|
| Data/AI — contrato de raw, determinismo e replay | concluído nesta spec |
| Product Orchestrator — coleta dos ~500 / parâmetros e paginação | pendente antes da coleta real |
| Security — SEC-F23, `YOUTUBE_API_KEY`, body-only e log hygiene | pendente antes da coleta real |
| DevOps — job interno, secret injection, Sentry e operação controlada | pendente antes da coleta real |
| P5-REPRO-01 | pendente e bloqueante antes do 1º publish |

Stop Conditions: mudança de parâmetro/fonte; tentativa de mutar raw; run parcial alcançando downstream; secret/envelope em persistência ou log; falha de replay. Em qualquer uma, parar e devolver `needs_review`/`OPEN DECISION` conforme a causa.

## 11. Fora do escopo

- coleta real, consumo de quota ou criação de número;
- Channel Data (`channels.list`), Entity Resolution, filtros, scoring e relatório;
- multi-keyword, multi-vertical, data lake contínuo ou qualquer feature de Fase 2;
- migration, policy de secret, endpoint, deploy ou publish.
