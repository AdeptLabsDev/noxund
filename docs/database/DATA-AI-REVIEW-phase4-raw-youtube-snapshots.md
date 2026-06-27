# DATA-AI-0004 - Data/AI Review - Fase 4 Raw YouTube Snapshots

- **Revisor:** Data/AI Pipeline Agent
- **Tarefa:** `task_phase4_dataai_validate_repro`
- **Action:** `validate_reproducibility`
- **Alvo:** `supabase/migrations/20260620000004_phase4_raw_youtube_snapshots.sql`
- **Verify:** `supabase/tests/phase4_post_apply_verify.sql`
- **Handoff:** `docs/database/HANDOFF-phase4-design.md`
- **Natureza:** validacao estrutural de imutabilidade/reproducibilidade do raw; nenhum apply, nenhuma coleta, nenhum Score, nenhum hash concreto e nenhum valor de metrica gerado.

---

## 0. Veredito

**Aprovado por Data/AI para o gate matrix #4. Sem veto metodologico ao DDL da Fase 4.**

O desenho preserva o contrato de raw sagrado: recoleta cria novo `run_id`; linhas raw nao tem rota de `UPDATE`/`DELETE`/`TRUNCATE`; o raw fica ancorado em `report_runs`; e o computed da Fase 5 pode ser reconstruido deterministicamente a partir de `raw_youtube_search_pages`, `raw_youtube_videos` e `raw_youtube_channels`.

Esta liberacao e somente Data/AI. O apply continua gated por Security #3, gate humano, required reviewers e verify pos-apply.

---

## 1. Raw imutavel e proveniencia por `run_id`

Ratifico a modelagem das tres tabelas raw com FK para `report_runs(id) ON DELETE RESTRICT`:

- `raw_youtube_search_pages.run_id`;
- `raw_youtube_videos.run_id`;
- `raw_youtube_channels.run_id`.

Isto preserva a proveniencia da Fase 3 e impede raw orfao. A regra operacional fica correta: uma nova coleta nao altera a linha anterior; ela cria um novo `run_id` e novos snapshots.

Ratifico tambem os guards:

- `public.raw_youtube_immutable()` bloqueia qualquer `UPDATE` ou `DELETE`;
- `public.raw_youtube_no_truncate()` bloqueia `TRUNCATE`;
- as duas funcoes sao aplicadas nas tres tabelas raw;
- o bloqueio fica no banco, abaixo do caminho normal de aplicacao.

Para Data/AI, isto atende o requisito "raw nunca e sobrescrito" e sustenta o teste de reproducibilidade: o mesmo snapshot raw permanece estavel para recompute futuro.

---

## 2. Reproducibilidade raw -> computed

Ratifico que `response_json` e `raw_json` ficam `NOT NULL` e armazenam o corpo de resposta do YouTube como fonte de verdade. As colunas extraidas (`title`, `published_at`, `views`, `likes`, `comments`, `subscriber_count`, `view_count`, etc.) sao projecoes de conveniencia; o `raw_json` permanece a verdade auditavel.

O desenho e fiel ao contrato aprovado em DATA-AI-0001:

- RAW: `raw_youtube_*` e insert-only e nao e recomputavel;
- COMPUTED: Fase 5 reconstrui mappings, elegibilidade, metricas, Score, Competition e Example por `run_id` + `rubric_hash`/versao de regra;
- SNAPSHOT: relatorio publicado aponta para as metricas usadas e preserva a trilha.

Consequencia esperada: mesmo `run_id` + mesmo rubric/regra deterministica => computed identico. Divergencia nesse cenario continua sendo bug bloqueante do pipeline.

---

## 3. SEC-F08 nao fere raw verbatim

Ratifico o CHECK `*_no_request_context` como compativel com "raw verbatim".

O que deve ser preservado verbatim e o corpo legitimo retornado pela YouTube API. O CHECK rejeita somente chaves top-level associadas a envelope de transporte/request (`config`, `request`, `headers`, `authorization`, `key`), que nao fazem parte do corpo legitimo esperado de `search.list`, `videos.list` ou `channels.list`.

O verify reforca essa leitura:

- corpo limpo de resposta e aceito;
- envelope com contexto de request/secret e rejeitado por `check_violation`.

Portanto, SEC-F08 e uma protecao contra persistir URL/header/key por engano, nao uma transformacao do corpo raw. O scrub autoritativo do pipeline continua sendo: persistir somente o body da resposta.

---

## 4. `bigint` e correcao de overflow, nao mudanca de semantica

Ratifico o desvio consciente de `int` para `bigint` nos contadores:

- `raw_youtube_videos.views`;
- `raw_youtube_videos.likes`;
- `raw_youtube_videos.comments`;
- `raw_youtube_channels.upload_count`;
- `raw_youtube_channels.subscriber_count`;
- `raw_youtube_channels.view_count`.

Isto e correcao de capacidade, nao mudanca metodologica. O YouTube entrega esses contadores como numeros inteiros no payload; usar `bigint` apenas evita overflow de int32 em videos virais e canais grandes. O valor nao e recalculado, estimado, normalizado ou gerado por IA.

Tambem ratifico a nulabilidade dos contadores: estatistica ausente/oculta e `NULL`, nao zero. Isso preserva a semantica do payload e evita fabricar numero.

---

## 5. Unicidade logica e granularidade de coleta

Ratifico as chaves logicas:

- pagina de busca: uma linha por `(run_id, coalesce(page_token, ''))`;
- video: uma linha por `(run_id, video_id)`;
- canal: uma linha por `(run_id, channel_id)`.

Essa granularidade e correta para reproducibilidade:

- a primeira pagina da busca tem slot unico mesmo com `page_token` nulo;
- o mesmo `video_id` pode reaparecer em outro `run_id` como novo snapshot;
- o mesmo `channel_id` pode reaparecer em outro `run_id` como novo snapshot;
- dedupe dentro da mesma run nao depende de heuristica do pipeline.

O indice `(run_id, channel_id)` em `raw_youtube_videos` tambem e coerente com a Fase 5, pois elegibilidade e Competition dependem de joins por canal dentro da run.

---

## 6. Verify pos-apply

Ratifico o escopo do `phase4_post_apply_verify.sql` para o gate Data/AI:

- verifica existencia das tres tabelas raw;
- verifica funcoes e triggers de imutabilidade;
- verifica indices de unicidade logica;
- verifica FKs para `report_runs`;
- verifica CHECKs SEC-F08;
- prova empiricamente que `UPDATE`/`DELETE`/`TRUNCATE` falham;
- prova que corpo limpo e aceito e envelope de request e rejeitado;
- prova duplicidade de `(run_id, video_id)` como `unique_violation`;
- executa probes em transacoes revertidas.

Nao executei apply nem verify localmente. A prova empirica deve rodar no job pos-apply com `ON_ERROR_STOP=1`.

---

## 7. Garantias e limites

- Nenhum numero foi gerado por IA.
- Nenhum Score, Velocity, Signals, Competition, ranking ou Example foi calculado.
- Nenhum rubric, peso, threshold ou regra de ranking foi alterado.
- Nenhuma coleta YouTube foi executada.
- Nenhuma mudanca de schema foi aplicada por esta revisao.
- Data/AI baixa o gate matrix #4; nao substitui Security #3, QA, DevOps, gate humano ou required reviewers.
- Qualquer alteracao futura que permita mutar raw, misture raw/computed, mude a granularidade por `run_id` ou altere semantica de contadores deve voltar para Data/AI.
