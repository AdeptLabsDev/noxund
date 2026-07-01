# DATA-OPP-001 — Opportunity Agent (ranking · HOT · Competition · Example determinísticos)

- **Tarefa:** `task_define_opportunity` (delegada via `delegate_task: define_opportunity`, prioridade high)
- **Owner:** Data/AI Pipeline Agent (`data_agent`)
- **Ação:** `define_opportunity` *(ver OPEN-DATA-OPP-08 — o nome ainda não consta na allow-list publicada do `data_agent`; o trabalho de especificar/planejar determinístico é permitido — onboarding §4)*
- **Versão da regra:** `opportunity-rules-2026_06_v1` (constantes de rótulo público e política de desempate — **propostas**, não travadas; §11)
- **Data:** 2026-06-30
- **Estado:** spec de DESIGN. As tabelas que recebem o relatório (`reports`, `report_items`) e o validador `report_item_reason_complete` (F5-05A) **já estão aplicados/verificados** em produção (Fase 5 — DEC-0012). Esta tarefa **não aplica, não conecta ao banco, não executa código, não computa número real**.
- **Natureza:** define-only. Zero coleta, zero número computado, zero LLM, zero migration, zero secret, zero rede.
- **Dependência de entrada:** saídas determinísticas do **Popularity Scoring** (`DATA-SCORING-001`): `final_score`/`raw_score` + os 4 componentes (`signals`, `velocity_median_per_day`, `channel_diversity_count`) por `(run_id, artist_id, rubric_hash)` em `artist_metrics`, com a evidência por-vídeo (`metrics_detail_json.videos.accepted[].{views, published_at, age_days, vel}`) já ancorada em `raw_youtube_videos`; **Competition / canais distintos** e `ValidVideos(run, artist)` de `DATA-CHANNEL-001`. Raw imutável de `DATA-COLLECT-001`/`DATA-COLLECT-002`, âncora temporal `report_runs.window_end`.
- **Fontes vinculantes:** `context/03_Data_AI_Agents_Methodology.md` §§1, 8, 9, 10–12; `context/01_MVP_Scope_PRD.md` §4.4, §5.1–5.7; `docs/data/DATA-SCORING-001-popularity-scoring-spec.md` (§§3–8; fronteira §8); `docs/data/DATA-CHANNEL-001-channel-filter-spec.md` (§6, contagem de canais distintos); `supabase/migrations/20260620000005_phase5_computed_metrics_reports.sql` (`reports` L331–353; `report_items` L367–414; validador `report_item_reason_complete` L164–188; enum `competition_level` L89–91; enum `report_status` L86–88; freeze de snapshot L430–513); `docs/agents/data-ai-pipeline-agent.md`; `docs/product/scope-guardrails.md`; `docs/product/mvp-backlog.md` Épico 5 (`[DATA] Opportunity Agent`); `docs/product/decisions/DEC-0013-sequencing-pipeline-first.md`.

---

## 1. Resultado e limite desta especificação

Esta spec fecha a metodologia do **Agente 6 — Opportunity**: o nó terminal do pipeline determinístico que transforma o Score e os componentes de `artist_metrics` (já computados por `DATA-SCORING-001`) nas **linhas do relatório** — ranking, rótulo **HOT**, gate de exibição do Score, rótulo **Competition Low/Medium/High** e o **Example** (vídeo-prova) — materializadas como `reports` + `report_items` (o snapshot congelado no publish). É a **terceira e última zona puramente determinística** do pipeline (depois de Channel Filter e Scoring); aqui **nenhuma IA atua** e **nenhum número de produto é gerado por modelo**.

Limite duro: **o Opportunity não recomputa o Score** e **não redefine Signals, Velocity ou Competition** — ele **consome** `final_score`/`raw_score`/componentes de `artist_metrics` (owned por `DATA-SCORING-001`) e a contagem de canais distintos (owned por `DATA-CHANNEL-001`), e sobre eles **ordena, rotula, seleciona e formata** por regras aritméticas/de-string determinísticas. Ranking, HOT, Competition-label e Example são **CODE**: funções puras de inputs já congelados no snapshot da run + a configuração congelada de `opportunity-rules-2026_06_v1` — **sem rede, sem LLM, sem relógio de parede** (o "agora" é `report_runs.window_end`). **Mesmo run + mesmas versões ⇒ `report_items` byte-idêntico** (P5-REPRO-01), inclusive o `example_video_id` (o risco de backlog "Example no olho" é eliminado por construção). Nenhuma linha do relatório é **editada à mão**.

O que esta spec **NÃO** define: o cálculo do Score/componentes (é `DATA-SCORING-001` §§5–7); a elegibilidade de canal e a contagem de canais distintos (é `DATA-CHANNEL-001` §§5–6); a coleta (é `DATA-COLLECT-001/002`); a VIEW pública de exposição por-coluna ao produtor (**Fase 9, vetada** — SEC-0001 §0; `report_items` permanece default-deny). Esta spec produz o snapshot **interno**; a superfície pública é a Fase 9.

O contrato lógico está nos §§2–12. As tabelas físicas `reports`/`report_items` e o validador `report_item_reason_complete` **já estão vivos** (Fase 5); esta spec **ratifica o shape aplicado** (§4) e define o **contrato de uso/escrita** sobre ele — **zero ALTER, zero migration nova** (gaps do shape aplicado viram OPEN QUESTIONS, §13). As decisões que dependem de humano — **constantes de threshold que governam rótulo público** e a **regra de composição do relatório** — estão isoladas no §13 como OPEN QUESTIONS, antes de qualquer compute-live.

## 2. Posição no pipeline

```text
… → 5 Popularity Scoring (DATA-SCORING-001, determinístico)
       └─ artist_metrics: final_score (X/100) + raw_score + signals +
          velocity_median_per_day + channel_diversity_count + metrics_detail_json
          (videos.accepted[].{views, published_at, age_days, vel} → ancorado no raw)
              └─→ 6 Opportunity (ESTA spec, determinístico)
                     ├─ Ranking     : ordem total sobre os artistas pontuados da run (§5)
                     ├─ HOT         : final_score > 90, cap de 2 por relatório (§6)
                     ├─ Score exibido: score_display só se final_score > 83 (§7)
                     ├─ Competition : Low/Medium/High sobre canais distintos (+7d) (§8)
                     └─ Example     : ValidVideos → top-3 por vel → mais recente → maior views (§9)
                            └─→ reports (draft→published) + report_items (SNAPSHOT congelado)
```

- **Consome (upstream):** por artista pontuado da run — `final_score`, `raw_score` (para ranking/HOT/gate), `signals`, `velocity_median_per_day`, `channel_diversity_count` (passthrough/rótulo), e a evidência por-vídeo já auditada em `metrics_detail_json` (para o Example, **sem recomputar velocity**). O par `(rubric_version, rubric_hash)` do Scoring viaja **congelado** para o report (FK composta, §4). Só entram artistas com linha em `artist_metrics` (`|ValidVideos| ≥ 1`; `DATA-SCORING-001` §3).
- **Produz (downstream):** um `reports` (um dos 2 relatórios fixos) e até **10** `report_items` (linhas ranqueadas), cada uma com `tag`/`score_display`/`competition_level`/`example_*` + `selection_reason_json` (prova determinística do Example). O relatório entra como **`draft`** (working set) e congela no **publish** (transição `draft→published` — trigger F5-01).
- **NÃO** computa Score, Velocity, Signals nem a contagem de canais — apenas **ordena, rotula, seleciona e formata** sobre números já computados. **NÃO** aplica/publica (o publish é ação de admin, downstream).

## 3. Entradas exatas e proveniência

Unidade de trabalho: **um relatório por run** — o conjunto `ScoredArtists(run) = { a : ∃ artist_metrics(run_id=run, artist_id=a, rubric_hash) }`. Todos os inputs vêm de linhas já persistidas e auditadas do Scoring/Channel Filter — o Opportunity **não lê o raw diretamente para número**; ele lê o computed congelado, cuja proveniência até `raw_youtube_videos` já está garantida por FK (`artist_metric_videos`, `report_items.example_video_id`).

### 3.1 Inputs por artista (nível `artist_metrics`, verbatim do computed)

| Campo | Origem (verbatim) | Uso no Opportunity | Nulo |
|---|---|---|---|
| `final_score` | `artist_metrics.final_score` | Ranking (primário), HOT (`>90`), gate de exibição (`>83`), `score_value`/`score_display` | não-nulo para artista pontuável (§9.x do Scoring) |
| `raw_score` | `artist_metrics.raw_score` | **desempate** de ranking e de HOT (precisão plena antes do arredondamento) | não-nulo |
| `signals` | `artist_metrics.signals` | passthrough → `report_items.signals` (coluna pública) | — |
| `velocity_median_per_day` | `artist_metrics.velocity_median_per_day` | formatação → `velocity_display` (coluna pública) | `NULL` possível (Velocity indefinível) → §10.2 |
| `channel_diversity_count` | `artist_metrics.channel_diversity_count` | Competition (contagem) → `competition_channel_count` + bucket (§8) | — |
| `metrics_detail_json.videos.accepted[]` | evidência do Scoring (`{video_id, views, published_at, age_days, vel}`) | Example: conjunto-candidato + ordenação por `vel` **sem recomputar** (§9) | `accepted` ≥ 1 (F5-05A) |
| `(rubric_version, rubric_hash)` | `artist_metrics` | congelado no report/item (FK composta; reprodutibilidade) | não-vazio |

### 3.2 Referência temporal e catálogo

| Campo | Origem | Uso |
|---|---|---|
| `window_end` / `window_start` | `report_runs` | janelas de 7d para o gatilho de crescimento de Competition (§8.3); **âncora determinística**, nunca o relógio |
| `artists.canonical_name` | `artists` | `title = "<canonical_name> Type Beat"` (PRD §5.1; §10.1) |

### 3.3 Proveniência (rastreável até o raw, herdada)

- Cada `report_items` aponta `artist_metric_id` pela **FK composta** `(artist_metric_id, run_id, artist_id, rubric_version, rubric_hash) → artist_metrics` (F5-02/F5-07): a linha aponta a **métrica exata** do snapshot, não "alguma métrica".
- O **Example** (`example_video_id`), quando presente, existe no raw daquele run pela **FK composta** `(run_id, example_video_id) → raw_youtube_videos` **`ON DELETE RESTRICT`** (F5-04, MATCH SIMPLE — opcional, mas validado quando presente).
- Os **candidatos do Example** são exatamente `videos.accepted[]` da métrica (= `ValidVideos`), cuja proveniência referencial até o raw já é garantida por `artist_metric_videos` (`DATA-SCORING-001` §3.4). Logo **toda célula do relatório é reconstruível byte-a-byte até `raw_youtube_videos`** por chave natural `(run_id, …)` + versões — sem depender de UUID mutável.

## 4. Tabelas `reports` / `report_items` — shape aplicado (ratificado, design-only)

> As tabelas **já estão vivas e verificadas** em produção (Fase 5, DEC-0012, projeto `pwbkplzyzmortwjjpcbg`). Esta seção **documenta o shape autoritativo** aplicado em `20260620000005_phase5_computed_metrics_reports.sql` (`reports` L331–353; `report_items` L367–414) e o **contrato de escrita** sobre ele. **Nenhum ALTER é proposto aqui**; deltas eventuais (§13) seguiriam migration **aditiva e gated**, como `entity_resolution_candidates`.

### 4.1 `reports` (SNAPSHOT — um dos 2 relatórios fixos)

```sql
-- LIVE (Fase 5). Entra como draft; congela após published (trigger F5-01). draft→published→archived.
create table public.reports (
  id             uuid primary key default gen_random_uuid(),
  run_id         uuid not null references public.report_runs (id) on delete restrict,
  title          text not null,                             -- "Relatório 1 de 2" / "Relatório 2 de 2" (PRD §4.4)
  vertical       text not null default 'Chicago Drill',     -- travado
  keyword        text not null default 'chicago drill type beat', -- travado
  rubric_version text not null,                             -- congela o par do Scoring consumido (F5-02)
  rubric_hash    text not null,
  status         public.report_status not null default 'draft',  -- draft | published | archived
  published_at   timestamptz,
  created_at     timestamptz not null default now(),
  constraint reports_published_at_chk check (status = 'draft' or published_at is not null),
  constraint reports_rubric_fk foreign key (rubric_version, rubric_hash)
    references public.rubric_versions (version, hash) on delete restrict,
  constraint reports_identity_key unique (id, run_id, rubric_version, rubric_hash)
);
```

### 4.2 `report_items` (SNAPSHOT — a linha do ranking; única superfície do produtor na Fase 9)

```sql
-- LIVE (Fase 5). Cadeia referencial: report_items → artist_metrics (mesmo run/artista/rubric) → raw.
create table public.report_items (
  id                        uuid primary key default gen_random_uuid(),
  report_id                 uuid not null,
  run_id                    uuid not null,
  artist_id                 uuid not null,
  artist_metric_id          uuid not null,                 -- ponteiro p/ a métrica EXATA (FK composta)
  rubric_version            text not null,                 -- deve casar report E metric
  rubric_hash               text not null,
  rank                      int  not null,                 -- ranking (§5) — unique (report_id, rank)
  title                     text,                          -- "<Artista> Type Beat" (§10.1)
  tag                       text,                          -- 'HOT' | null  (HOT se final_score > 90; §6)
  score_display             text,                          -- 'X/100' só se final_score > 83; senão null (§7) · público
  score_value               numeric,                       -- = final_score · interno (SEC-F03)
  signals                   int,                           -- passthrough · público
  velocity_display          text,                          -- formatação de velocity_median_per_day (§10.2) · público
  competition_level         public.competition_level,      -- Low | Medium | High (§8) · público
  competition_channel_count int,                           -- = channel_diversity_count · público
  example_video_id          text,                          -- FK composta → raw (opcional, validado; §9)
  example_url               text,                          -- 'https://www.youtube.com/watch?v=<id>' (§10.3) · público
  selection_reason_json     jsonb not null,                -- prova determinística do Example (§9) · interno (SEC-F03)
  created_at                timestamptz not null default now(),
  constraint report_items_report_fk        foreign key (report_id, run_id, rubric_version, rubric_hash)
    references public.reports (id, run_id, rubric_version, rubric_hash) on delete restrict,
  constraint report_items_artist_metric_fk foreign key (artist_metric_id, run_id, artist_id, rubric_version, rubric_hash)
    references public.artist_metrics (id, run_id, artist_id, rubric_version, rubric_hash) on delete restrict,
  constraint report_items_artist_fk        foreign key (artist_id) references public.artists (id) on delete restrict,
  constraint report_items_example_raw_fk   foreign key (run_id, example_video_id)
    references public.raw_youtube_videos (run_id, video_id) on delete restrict,
  constraint report_items_reason_complete_chk check (public.report_item_reason_complete(selection_reason_json))
);
create unique index report_items_report_rank_uidx   on public.report_items (report_id, rank);
create unique index report_items_report_artist_uidx on public.report_items (report_id, artist_id);
```

### 4.3 Contrato de escrita — o que o Opportunity **computa** vs o que **passa adiante**

O DDL é **só armazenamento**: **zero CHECK de faixa/threshold de número** (`tag`, `score_display`, `competition_level` etc. não são validados por valor — o cálculo é do data-engine). O CHECK vivo (`report_item_reason_complete`) é **estrutural** (presença de chaves), não numérico.

| Coluna | Dono do valor | Regra do write-layer |
|---|---|---|
| `rank` | **Opportunity** | ordem total determinística de `ScoredArtists(run)` (§5); `unique (report_id, rank)` garante 1..N sem buraco. |
| `tag` | **Opportunity** | `'HOT'` para o conjunto HOT (§6); caso contrário `null`. |
| `score_display` | **Opportunity** | `'{final_score}/100'` se `final_score > 83`; senão `null` (§7). |
| `score_value` | passthrough | `= final_score` (interno; SEC-F03 — nunca cru ao produtor; VIEW na Fase 9). |
| `signals` | passthrough | `= artist_metrics.signals`. |
| `velocity_display` | **Opportunity** | formatação determinística de `velocity_median_per_day` (§10.2). |
| `competition_level` | **Opportunity** | bucket `Low/Medium/High` (§8). |
| `competition_channel_count` | passthrough | `= artist_metrics.channel_diversity_count`. |
| `example_video_id` | **Opportunity** | `= selection_reason_json.selected_example.video_id` (§9); FK ao raw. |
| `example_url` | **Opportunity** | URL canônica do vídeo (§10.3). |
| `selection_reason_json` | **Opportunity** | prova determinística estruturalmente completa (§9); `{}`/seções ausentes rejeitados pelo CHECK; **nunca** cru ao produtor. |
| `title` | **Opportunity** | `"<artists.canonical_name> Type Beat"` (§10.1). |
| `report_id`/`run_id`/`artist_id`/`artist_metric_id`/`rubric_*` | chaves | coerência referencial (FKs compostas §4.2). |

**Snapshot congelado:** o Opportunity escreve no report **`draft`** (working set — recompute livre). O **publish** (`draft→published`, ação de admin) dispara o freeze por trigger (F5-01): a partir daí `reports`/`report_items` são imutáveis (só `published→archived` sem tocar conteúdo). Portanto o Opportunity **materializa**, não **publica** — e um recompute do relatório antes do publish é legítimo e byte-idêntico.

## 5. Ranking determinístico

A metodologia (§8) atribui ao Opportunity "gerar ranking e linhas do relatório", e o produto é um **ranking de oportunidade por tração recente sintetizada no Score** (PRD §5.3). A ordenação das linhas é uma **ordem total determinística** sobre `ScoredArtists(run)`, com chave primária de negócio + desempates estáveis que garantem unicidade absoluta:

```
ORDER BY  final_score   DESC,     -- 1) chave de negócio: maior Score primeiro (tração recente)
          raw_score     DESC,     -- 2) desempate de precisão plena (resolve empates de arredondamento
                                  --    sem introduzir nova regra de produto; já computado pelo Scoring)
          artist_id     ASC       -- 3) desempate final ESTÁVEL por chave natural única (total order)
```

- **`rank`** é atribuído `1, 2, …` sobre essa ordem; `unique (report_id, rank)` impede colisão. As **10 primeiras** posições (`rank ≤ 10`, PRD §4.4) materializam as `report_items` do relatório (composição em §13/OPEN-DATA-OPP-06).
- **Por que `raw_score` como 2º:** `final_score` é o inteiro arredondado (0–100) — empates são frequentes; `raw_score` (precisão decimal plena, já persistido) os resolve **deterministicamente** sem inventar critério novo e **sem contradizer o Score exibido** (nenhum artista com Score exibido menor aparece acima de um com Score maior).
- **Por que `artist_id` como 3º:** é a chave natural única do artista na run — desempate **absoluto e estável** (byte-idêntico entre execuções/máquinas), espelhando a disciplina de desempate por chave estável do Scoring (§5.7) e do Channel Filter.
- **Consistência com HOT (§6):** sob esta chave, os artistas HOT (`final_score > 90`) são exatamente os de topo — a hierarquia visual "HOT no topo" (PRD §5.2) emerge naturalmente, sem regra extra.

> **Nota de escopo:** a metodologia **não fixa literalmente** a chave de ordenação do relatório (o "ordenar por velocity" do §8 refere-se à **seleção do Example**, §9 — **não** ao ranking das linhas). A chave acima é a leitura fiel do produto (ranking por Score), registrada como **proposta determinística**; como governa a **ordem pública** das linhas, é ratificável pelo Product Lead — **OPEN-DATA-OPP-03**. Qualquer que seja a decisão, os desempates `raw_score`→`artist_id` permanecem para garantir ordem total.

## 6. Rótulo HOT — `final_score > 90` + a regra de "exatamente 2 por relatório"

Duas regras coexistem e precisam ser conciliadas deterministicamente:

- **Critério de rótulo (metodologia §8; PRD §5.2):** `HOT = true` se **`final_score > 90`** (estrito). Este critério é **inviolável** — nenhum artista com `final_score ≤ 90` pode receber `HOT` (fabricar o rótulo violaria a promessa metodológica pública, `03_…` §1/§17).
- **Regra de composição (PRD §4.4; scope-guardrails):** **2 artistas HOT por relatório**.

### 6.1 Conjunto HOT determinístico

```
HOTCandidates(report) = { a ∈ items(report) : final_score(a) > 90 }
HOT(report)           = top-2 de HOTCandidates por ( final_score DESC, raw_score DESC, artist_id ASC )
```

- **`report_items.tag = 'HOT'`** para `a ∈ HOT(report)`; `null` caso contrário.
- A seleção do HOT é definida por **ordenação de Score** (não pela `rank` diretamente), de modo que HOT marca sempre **os 2 maiores Scores acima de 90**, o que é o intento do produto ("apontar oportunidades urgentes"). Sob a chave de ranking proposta (§5), esses 2 coincidem com `rank 1` e `rank 2` — visualmente consistente.

### 6.2 Como interage com o ranking — casos pinados vs OPEN

| Caso | `|HOTCandidates|` | Regra determinística | Estado |
|---|---:|---|---|
| **Mais de 2 cruzam 90** | > 2 | **Cap de 2**: só os 2 maiores (por Score, desempate `raw_score`→`artist_id`) recebem `HOT`; o 3º+ acima de 90 **exibe o Score** (`> 83`) mas **sem badge HOT**. | ✅ **pinado** (determinístico) |
| **Exatamente 2 cruzam 90** | = 2 | Os 2 recebem `HOT`. Caso canônico do produto. | ✅ **pinado** |
| **Menos de 2 cruzam 90** | 0 ou 1 | O critério `>90` **impede fabricar** o 2º HOT. Conflito real entre PRD §4.4 ("exatamente 2") e §5.2/metodologia §8 (">90"). | ⚠️ **OPEN-DATA-OPP-02** |

- O caso **>2** é totalmente determinístico (cap-de-2 via ordenação de Score) — **não** é um OPEN.
- O caso **<2** é um **conflito entre documentos de `/context`** → por scope-guardrails, **parar e escalar ao Product Lead** (não decidir sozinho). **Recomendação do owner (honesta):** relaxar "exatamente 2" para **"no máximo 2"** — exibir 0 ou 1 HOT quando menos de 2 artistas cruzam 90, **nunca** rotular HOT um Score ≤ 90. Alternativa (curadoria): garantir na composição do relatório (§13) que ≥ 2 artistas do conjunto cruzem 90. **Decisão é do Product Lead** — OPEN-DATA-OPP-02.

## 7. Gate de exibição do Score — `score_display` só se `final_score > 83`

O Score é **computado para todos** os artistas pontuados (Scoring §1), mas **exibido** apenas acima do piso (metodologia §8; PRD §5.3):

```
score_display = (final_score > 83) ? format('{final_score}/100') : NULL
score_value   = final_score            -- SEMPRE persistido (interno, SEC-F03) — só a EXIBIÇÃO é gated
```

- **`final_score ≤ 83`:** `score_display = NULL` — a coluna Score aparece **vazia** para a linha; a linha **permanece no relatório** e continua exibindo **Title, Signals, Velocity, Competition, Example** (o produtor vê o sinal sem o número sintético). Isso é honesto: abaixo do piso, o número não é comunicado como confiável, mas o sinal bruto ainda é.
- **Coerência com HOT:** `HOT ⇒ final_score > 90 ⇒ final_score > 83` — toda linha HOT **sempre** exibe seu Score. Não há linha HOT sem Score.
- **`score_value` é interno** (SEC-F03): guarda o número congelado para auditoria/admin; a exposição pública ao produtor é por VIEW dedicada na **Fase 9** (fora deste escopo). O gate `> 83` protege a **string pública** `score_display`, não o valor interno.
- Os limiares `90`/`83` vêm verbatim da metodologia/PRD; como governam rótulos públicos, ficam sob a mesma disciplina de ratificação das demais constantes de rótulo (§13), embora aqui estejam textualmente fixados no `/context`.

## 8. Competition Low / Medium / High

Rótulo de **saturação de mercado** — quantos canais **distintos elegíveis** publicam type beats para o artista. A **leitura de saturação é exclusiva do Opportunity**; o Scoring usa a **mesma contagem** como sinal **positivo** de demanda validada (componente 15%) — as duas leituras da mesma contagem **não se contradizem** e são deliberadamente separadas (`DATA-SCORING-001` §5.6 nota). O Opportunity **não recomputa** a contagem: consome `channel_diversity_count` (= Competition de `DATA-CHANNEL-001` §6.2).

### 8.1 Entradas

```
count      = artist_metrics.channel_diversity_count           -- distinct channel_id sobre ValidVideos
                                                              -- → report_items.competition_channel_count (passthrough)
recent_7d  = |{ v ∈ ValidVideos(run, artist) : v.published_at ∈ (window_end − 7d , window_end] }|
prior_7d   = |{ v ∈ ValidVideos(run, artist) : v.published_at ∈ (window_end − 14d , window_end − 7d] }|
growth_7d  = (recent_7d − prior_7d) / prior_7d                -- crescimento de publicações (§8.3)
```

`recent_7d`/`prior_7d` são contagens de **publicações (vídeos válidos)** por sub-janela de 7d **dentro** da janela de 30d, ancoradas em `window_end` (determinístico; nunca o relógio). São derivadas de `published_at` dos `videos.accepted[]` — **sem recomputar** o conjunto.

### 8.2 Bucketing por contagem de canais (estrutura; constantes propostas)

```
base_level(count) =
   Low     if  count ≤ LOW_CHANNEL_MAX          -- proposto 5
   Medium  if  LOW_CHANNEL_MAX < count ≤ HIGH_CHANNEL_MAX   -- proposto 6..15
   High    if  count > HIGH_CHANNEL_MAX          -- proposto >15
```

Mapeia diretamente para o enum vivo `public.competition_level ∈ {'Low','Medium','High'}`.

### 8.3 Gatilho de crescimento (override → High)

```
competition_level = High   if  base_level == High  OR  growth_7d > GROWTH_HIGH_PCT     -- proposto 50%
                  = base_level  caso contrário
```

- O gatilho de crescimento pode **elevar para High** um artista cujo `count` seria Low/Medium — leitura literal do "OR" da metodologia §8 / PRD §5.6 ("**> 15 canais distintos OU crescimento de publicações nos últimos 7 dias > 50% vs 7 dias anteriores**"). Ele **nunca rebaixa** (só sobe para High).
- **Div-por-zero (`prior_7d = 0`):** `growth_7d` é indefinido; **regra determinística proposta:** com `prior_7d = 0`, o gatilho de crescimento **não dispara** (fail-closed conservador — sem base anterior, não se afirma "crescimento >50%"); o rótulo fica em `base_level`. (Alternativa: `prior_7d=0 ∧ recent_7d>0 ⇒ High`. É decisão de rótulo público → OPEN-DATA-OPP-04.)

### 8.4 Constantes → **PROPOSTAS, não travadas** (governam rótulo público)

| Constante | Papel | Proposta de partida (NÃO travada) |
|---|---|---|
| `LOW_CHANNEL_MAX` | teto de Low | `5` |
| `HIGH_CHANNEL_MAX` | teto de Medium (acima → High) | `15` |
| `GROWTH_HIGH_PCT` | limiar do gatilho de crescimento | `50%` |
| `GROWTH_WINDOW_DAYS` | tamanho de cada sub-janela | `7` (7d vs 7d anteriores) |
| `PRIOR_ZERO_RULE` | tratamento de `prior_7d = 0` | `no-trigger` (fail-closed) |

Os **números** vêm verbatim da metodologia/PRD, mas — coerente com `DATA-SCORING-001` §5.8 e `DATA-CHANNEL-001` §5.5 — como **governam um rótulo público**, esta spec define a **estrutura/semântica** e marca os valores finais como **OPEN-DATA-OPP-01** (ratificação Product Lead + Data/AI antes de `opportunity-rules-2026_06_v1` virar definitivo e de qualquer compute-live). Mudar qualquer um exige **nova versão** de regra (§11).

### 8.5 Auditoria de Competition (metodologia §10) — e um gap do shape aplicado

A metodologia §10 exige rastrear, para Competition: **canais distintos + lista de `channel_id` + nível final**. Os dois primeiros já estão auditados em `artist_metrics.metrics_detail_json.competition.{eligible_channel_ids, count}` (owned por Scoring/Channel Filter); o **nível final** está em `report_items.competition_level`. O **caminho por contagem é totalmente auditável**.

O **caminho por crescimento (§8.3)** introduz `recent_7d`/`prior_7d`, para os quais **o shape aplicado não tem coluna dedicada** em `report_items`. **Gap (design-only, sem ALTER):** ver **OPEN-DATA-OPP-04** — recomendação de aterrissar `recent_7d`/`prior_7d`/`growth_7d`/`PRIOR_ZERO_RULE` como **chaves aditivas** em `selection_reason_json.competition` (o validador F5-05A só exige as chaves do Example; chaves extras são aceitas) **ou** em `metrics_detail_json.competition` (chaves extras também aceitas por F5-05A), preservando a auditabilidade **sem** migration. Coluna dedicada seria migration **aditiva gated** futura.

## 9. Example / Reference — seleção determinística + `selection_reason_json`

Vídeo-prova do artista, escolhido por **regra determinística** (metodologia §8; PRD §5.7). Elimina o risco de backlog "Example no olho": **mesmo run ⇒ mesmo `example_video_id`**.

### 9.1 Algoritmo (determinístico, sem recomputar velocity)

```
1. Candidates = ValidVideos(run, artist) = metrics_detail_json.videos.accepted[]      -- vídeos elegíveis do artista
2. vel(v)     = views(v) / age_eff(v)   -- MESMA velocity por-vídeo do Scoring §5.3 passo 1 (age_eff com
                                        --   AGE_FLOOR_DAYS, âncora window_end); CONSUMIDA de videos.accepted[].vel,
                                        --   NÃO recomputada. Candidato sem views (vel indefinida) ordena por último.
3. Ordena Candidates por ( vel DESC, video_id ASC )  →  Top3 = os 3 primeiros (≤3 se houver menos)
4. selected = argmax_{v ∈ Top3} published_at            -- entre os 3, o publicado MAIS RECENTE
5. desempate 1 (published_at igual): argmax views(v)     -- maior views absoluto
6. desempate 2 (published_at E views iguais): min video_id   -- chave natural estável (completa a ordem total)
```

- **Passos 1–5 são verbatim** da metodologia §8 / PRD §5.7. O **passo 6** é uma **completude de determinismo** (não é regra de produto): a metodologia para em "maior views absoluto"; empate remanescente exige um desempate estável — usa-se a chave natural `video_id`, exatamente como o Scoring desempata a mediana por `video_id` (§5.3) e o Channel Filter/ranking por chave estável. Registrado em `tiebreak.final`.
- **Candidato sem `views`** (Velocity indefinível): ordena após todos os com `vel` (por `video_id`); só entra no Top3 se houver menos de 3 candidatos com `vel` — borda rara, resolvida deterministicamente.
- **Sempre há ≥ 1 candidato:** artista pontuado tem `|ValidVideos| ≥ 1` (Scoring §3) ⇒ `videos.accepted[] ≥ 1` (F5-05A) ⇒ `candidates ≥ 1` e `top3 ≥ 1` — satisfazendo o validador **por construção**.
- **Rastreabilidade:** `selected.video_id → report_items.example_video_id`, validado pela FK composta ao raw (§3.3). O Example é reconstruível até `raw_youtube_videos`.

### 9.2 Contrato `selection_reason_json` (satisfaz o validador F5-05A vivo)

O validador `report_item_reason_complete` (L164–188) exige, no mínimo: **`candidates`** (array ≥1), **`top3`** (array ≥1), **`tiebreak`** (presente), **`selected_example`** (objeto) com **`selected_example.video_id`** não-vazio. Esta spec **mapeia a prova ao shape exigido** (não inventa coluna); chaves aditivas (`versions`, `competition`) são **aceitas** (o validador só checa as obrigatórias):

```jsonc
{
  "candidates": [                                  // F5-05A: array não-vazio = ValidVideos considerados
    { "video_id": "…", "views": …, "published_at": "…Z", "age_days": …, "vel": "…" }
    // … um por vídeo de videos.accepted[] (proveniência de Signals; ancorado no raw)
  ],
  "top3": [                                        // F5-05A: array não-vazio = shortlist ordenada por velocity
    { "video_id": "…", "vel": "…", "rank": 1 },
    { "video_id": "…", "vel": "…", "rank": 2 },
    { "video_id": "…", "vel": "…", "rank": 3 }      // ≤ 3 se houver menos candidatos
  ],
  "tiebreak": {                                    // F5-05A: presente — regra determinística aplicada
    "order_by":  "vel_desc, video_id_asc",
    "primary":   "most_recent_published_at",
    "secondary": "max_views_absolute",
    "final":     "min_video_id",
    "applied":   "primary | secondary | final"      // qual regra efetivamente decidiu (auditoria)
  },
  "selected_example": {                            // F5-05A: objeto com video_id NÃO-VAZIO
    "video_id":     "…",                            // → report_items.example_video_id (FK → raw)
    "published_at": "…Z",
    "views":        …,
    "vel":          "…"
  },
  "versions": {                                    // ADITIVO (OPEN-DATA-OPP-05): versões efetivas p/ replay
    "opportunity_version": "opportunity-rules-2026_06_v1",
    "opportunity_hash":    "<sha256(canonical_json(config))>",
    "rubric_version":      "score_rubric_2026_06_v1", "rubric_hash": "<sha256>"
  },
  "competition": {                                 // ADITIVO (OPEN-DATA-OPP-04): evidência do gatilho de crescimento
    "count": …, "level": "Low|Medium|High",
    "recent_7d": …, "prior_7d": …, "growth_7d": "…", "prior_zero_rule": "no-trigger"
  }
}
```

- **Example → candidatos / top-3 por velocity / regra de desempate / vídeo escolhido** (metodologia §10) — tudo presente e determinístico.
- `selection_reason_json` é **INTERNO** (SEC-F03): nunca cru ao produtor; a superfície pública é a VIEW da Fase 9. `example_url` (público) é derivado do `video_id` (§10.3).

## 10. Formatação de exibição (determinística, string sobre número já computado)

Formatação **não é geração de número** — é serialização determinística de valores já computados. Toda regra abaixo é congelada em `opportunity-rules-2026_06_v1`.

### 10.1 `title` — `"<artists.canonical_name> Type Beat"`
Concatenação determinística do nome canônico do artista (`artists.canonical_name`) com o sufixo fixo ` Type Beat` (PRD §5.1: "Kairo Vee Type Beat"). Sem IA, sem edição livre — o nome vem do catálogo canônico (proveniente do Entity Resolution, já validado como substring do título-fonte).

### 10.2 `velocity_display` — formatação de `velocity_median_per_day`
Formato público (PRD §5.5): `'X.Xk/day'` para ≥ 1000, `'XXX/day'` abaixo. Regra determinística proposta: `v ≥ 1000 → round(v/1000, 1) + 'k/day'`; senão `round(v) + '/day'`. `velocity_median_per_day = NULL` (Velocity indefinível, Scoring §9.1) → `velocity_display = NULL` (coluna vazia; nunca "0/day" fabricado). A **regra de arredondamento** da formatação é cosmética (formata o número já computado, não o gera); registrada no `opportunity_hash`.

### 10.3 `example_url` — URL canônica do vídeo
`example_url = 'https://www.youtube.com/watch?v=' + example_video_id` — derivação determinística do `video_id` já validado contra o raw. `NULL` se não houver Example (não ocorre para artista pontuado, §9.1).

### 10.4 `score_display` — `'{final_score}/100'` (§7); `tag` — `'HOT'`/`null` (§6)
Já definidos; formatação trivial sobre `final_score`/conjunto HOT.

## 11. Versionamento da regra do Opportunity + congelamento no snapshot

O conjunto determinístico de decisões do Opportunity — **chave de ranking** (§5), **regra HOT + cap** (§6), **gate de exibição** (§7), **constantes/estrutura de Competition** (§8), **algoritmo do Example** (§9) e **regras de formatação** (§10) — é congelado como um todo em **`opportunity-rules-2026_06_v1`**, com `opportunity_hash = sha256(canonical_json(config_congelada))` computado **em código** (nunca fabricado pelo banco), à imagem do `rubric_hash` (Scoring §5.1) e do `rule_hash` (Channel Filter §5.5).

- **Congelamento:** qualquer alteração de chave de ranking, limiar de HOT/exibição, constante de Competition, algoritmo do Example ou regra de formatação exige **nova versão** (`opportunity-rules-2026_06_v2`) com **novo hash** — nunca editar o significado de `…v1` in-place. Como essas regras governam **rótulos e ordem públicos**, toda mudança é gatilho de **Data/AI + Product Lead Review** (scope-guardrails §"Decisões que exigem Data/AI Review": "regra de Competition, Signals, Velocity ou seleção de Example").
- **Onde persiste (gap do shape aplicado):** `report_items`/`reports` **não têm coluna** `opportunity_version`/`opportunity_hash` — só carregam `rubric_version`/`rubric_hash` (do Scoring). Para reprodutibilidade do rebuild (saber **quais** constantes de Competition/tie-break produziram o rótulo), a versão do Opportunity precisa de âncora. **Recomendação (sem ALTER):** persistir em `selection_reason_json.versions` (chaves aditivas — aceitas pelo validador, §9.2). Coluna dedicada = migration **aditiva gated** futura. Registrado como **OPEN-DATA-OPP-05** (espelha `DATA-CHANNEL-001` OPEN-DATA-CHANNEL-05 sobre `rule_hash`).
- **Snapshot:** no publish, `reports`/`report_items` congelam (trigger F5-01); a versão do Opportunity efetiva viaja congelada na evidência (`selection_reason_json.versions`), de modo que o replay não depende de tabela mutável.

## 12. Reprodutibilidade e auditoria por célula (rumo a P5-REPRO-01)

O relatório é a superfície onde a promessa metodológica pública se materializa (`03_…` §1, §17). Determinismo por construção:

1. **Função pura.** Ranking, HOT, gate, Competition e Example são funções de inputs já computados/congelados (`final_score`/`raw_score`/componentes/`videos.accepted[]`) + config congelada — **sem rede, sem LLM, sem relógio** (janelas de 7d ancoradas em `window_end`).
2. **Ordem total.** Ranking `(final_score, raw_score, artist_id)`, HOT `(final_score, raw_score, artist_id)`, Example `(vel, video_id)`+`(published_at, views, video_id)` — todos com **desempate por chave natural** ⇒ resultado **byte-idêntico** independente de ordem de leitura/máquina.
3. **Aritmética exata.** Comparações/limiares de Competition e do gate usam os mesmos `numeric` de precisão fixa do Scoring; nenhuma reintrodução de ponto-flutuante não determinístico.
4. **Sem edição manual.** Nenhuma linha é ajustada à mão; overrides humanos só existem **upstream** (elegibilidade/mapping), já congelados em `metrics_detail_json.overrides[]` — o Opportunity lê o computed congelado, não a tabela mutável.
5. **Mapeamento a P5-REPRO-01.** Duas montagens do relatório sobre o **mesmo `run_id`** + mesmas `rubric_version`/`rubric_hash`/`opportunity_version`/`opportunity_hash` ⇒ `rank`, `tag`, `score_display`, `competition_level`, `example_video_id` e `selection_reason_json` **byte-idênticos** (excluindo UUIDs/timestamps operacionais). Qualquer divergência = **bug metodológico → bloqueia o 1º publish** (`03_…` §12).

Auditoria por célula (metodologia §10) — mapeada ao shape aplicado, sem inventar coluna:

| Célula | Onde rastreia |
|---|---|
| **Ranking** | `report_items.rank` + chave `(final_score=score_value, raw_score, artist_id)`; `raw_score` via `artist_metric_id`. |
| **HOT** | `report_items.tag` + `score_value(>90)`; conjunto derivado por ordenação de Score. |
| **Score exibido** | `score_display` (gate `>83`) + `score_value` interno. |
| **Competition** | `competition_level` + `competition_channel_count` + `metrics_detail_json.competition.{eligible_channel_ids,count}`; gatilho 7d em `selection_reason_json.competition` (aditivo, OPEN-04). |
| **Example** | `selection_reason_json.{candidates, top3, tiebreak, selected_example}` + `example_video_id` (FK→raw). |
| **Versões** | `report_items.rubric_version/hash` + `selection_reason_json.versions.opportunity_*` (aditivo, OPEN-05). |

## 13. Casos de borda, stop conditions e OPEN QUESTIONS

### 13.1 Bordas e fail-closed

- **Menos de 10 artistas pontuados na run** (`|ScoredArtists(run)| < 10`): o engine ranqueia **o que existe**; o relatório teria `< 10` linhas — **conflita** com "10 artistas por relatório" (PRD §4.4). Não fabricar linhas → **OPEN-DATA-OPP-06**.
- **Todos os artistas com `final_score ≤ 83`:** todas as linhas ficam com `score_display = NULL` (coluna Score vazia) e **0 HOT** (nenhum `> 90`) — relatório estruturalmente válido, mas sem Score visível e violando "2 HOT" (liga-se a OPEN-02/06). Honesto: sem número confiável, não se exibe número.
- **Empate de `final_score` entre artistas:** resolvido por `raw_score` → `artist_id` (§5) — ordem total garantida.
- **Empate no Example** (velocity/data/views): resolvido por `video_id` (§9.1 passo 6).
- **Artista sem `views` em nenhum vídeo** (Velocity/Example degradados): `velocity_display = NULL`; Example ainda seleciona por `published_at`/`views` entre os candidatos (que existem, `≥1`).
- **`prior_7d = 0`** no gatilho de crescimento: `no-trigger` (fail-closed, §8.3) — sem base, não se afirma crescimento.
- **Artista zero-signal** (`|ValidVideos| = 0`): não pontuado, **não entra** no relatório (herdado do Scoring §9.1) — ausência de sinal ≠ Score 0.

### 13.2 Stop conditions (parar e devolver `needs_review`/`OPEN DECISION`)

- pedido para **IA gerar/julgar/ordenar/rotular** qualquer coisa do relatório (ranking/HOT/Competition/Example) — viola o não-negociável (`03_…` §1; `data-ai-pipeline-agent.md`);
- mudar **chave de ranking, limiar de HOT/exibição, constante de Competition, algoritmo/tie-break do Example ou formatação** sem **nova `opportunity_version`** + Data/AI + Product Lead;
- **redefinir** Score/Velocity/Signals (owned por `DATA-SCORING-001`) ou a contagem de canais distintos (owned por `DATA-CHANNEL-001`) — são **consumidos**, não reabertos;
- editar `rank`/`tag`/`competition_level`/`example_video_id` à mão, ou mutar `report_items` de relatório **publicado** (freeze F5-01);
- **divergência de replay** (qualquer célula) entre duas montagens;
- mudar keyword/janela/volume/fonte (Stop Condition global).

### 13.3 OPEN QUESTIONS (para Orchestrator / Product Lead / Data-AI / Database antes de qualquer compute-live)

| ID | Tema | Impacto | Encaminhamento |
|---|---|---|---|
| **OPEN-DATA-OPP-01** *(bloqueante p/ compute-live)* | **Constantes de Competition** `{ LOW_CHANNEL_MAX, HIGH_CHANNEL_MAX, GROWTH_HIGH_PCT, GROWTH_WINDOW_DAYS, PRIOR_ZERO_RULE }` (§8.4). Governam um **rótulo público** (Low/Medium/High). | Definem o rótulo de saturação exibido. | **Ratificar com Product Lead + Data/AI** antes de `opportunity-rules-2026_06_v1` definitivo e do 1º compute-live. Esta spec define **estrutura/semântica**, não trava o número final (mesmo que a metodologia proponha 5/15/50%). |
| **OPEN-DATA-OPP-02** *(conflito de `/context`)* | **"Exatamente 2 HOT" (PRD §4.4) vs "`>90`" (§8 metodologia / PRD §5.2)** quando **< 2** artistas cruzam 90 (§6.2). | Rótulo público urgente; não se pode fabricar HOT ≤ 90. | **Parar e escalar ao Product Lead.** Recomendação do owner: **"no máximo 2"** (honesto; 0/1 HOT possível) **ou** garantir na composição ≥ 2 acima de 90. O caso **> 2** já está **pinado** (cap-de-2 determinístico). |
| **OPEN-DATA-OPP-03** | **Chave de ranking** do relatório — a metodologia não a fixa literalmente (§5 nota). Proposta: `final_score DESC → raw_score DESC → artist_id ASC`. | Governa a **ordem pública** das linhas. | **Product Lead confirma** a chave de negócio; desempates `raw_score`→`artist_id` permanecem para ordem total independentemente. |
| **OPEN-DATA-OPP-04** | **Gatilho de crescimento de Competition** (§8.3): (a) regra de `prior_7d = 0`; (b) escopo do override (de qualquer base vs só Medium→High); (c) **sem coluna dedicada** para `recent_7d`/`prior_7d` no shape aplicado. | Rótulo público + auditabilidade do caminho de crescimento. | **Data/AI + Product Lead** ratificam (a)/(b); **Database** avalia (c) — recomendação: chaves **aditivas** em `selection_reason_json.competition`/`metrics_detail_json.competition` (aceitas por F5-05A), **sem** ALTER; coluna dedicada = migration aditiva gated futura. |
| **OPEN-DATA-OPP-05** | **Persistência da versão do Opportunity** (`opportunity_version`/`opportunity_hash`) — sem coluna em `report_items`/`reports` (§11). | Reprodutibilidade do rebuild (quais constantes produziram o rótulo). | Recomendação: `selection_reason_json.versions` (aditivo, aceito). Coluna dedicada = migration aditiva gated. **Database + Data/AI.** (Espelha OPEN-DATA-CHANNEL-05.) |
| **OPEN-DATA-OPP-06** | **Composição do relatório:** `N = 10` quando a run tem `< 10` pontuáveis; mapeamento dos **2 relatórios fixos** para run(s) ("Ver outro grupo de oportunidades" — uma run dividida em 2 grupos de 10 vs 2 runs); apresentação quando **todos ≤ 83**. | Satisfazer PRD §4.4 (10 artistas, 2 HOT, coluna Score). | **Product Lead** (curadoria vs relaxar). O engine ranqueia deterministicamente; a **curadoria/composição** dos 2 snapshots é decisão de produto. |
| **OPEN-DATA-OPP-07** *(herdada, downstream)* | Compute-live depende de `ValidVideos`/Score reais, que dependem de **OPEN-DATA-CHANNEL-01** (coleta de canal) + **OPEN-DATA-SCORING-01/02** (constantes/curvas de normalização). | Sem esses, não há `artist_metrics` live → Opportunity não roda live. | **Não bloqueia este DESIGN** (DEC-0013, pipeline-first). Bloqueia compute-live em conjunto com as abertas de Channel/Scoring. |
| **OPEN-DATA-OPP-08** *(governança, menor)* | A ação **`define_opportunity`** não consta na allow-list publicada do `data_agent` (`data-ai-pipeline-agent.md` §Operating Protocol), embora o Opportunity (Agente 6) seja explicitamente **owned** por este agente. | Coerência de runtime/decision-log. | **Orchestrator ratificar** o nome da ação (define-only, não-destrutivo). Trabalho em si permitido (especificar determinístico — onboarding §4). Espelha OPEN-DATA-CHANNEL-04. |

## 14. Escopo negativo (explícito)

- **Sem apply / sem `supabase db push` / sem migration nova.** `reports`/`report_items` e o validador `report_item_reason_complete` já estão vivos (Fase 5); esta spec **ratifica e define uso** — **não** ALTERa, **não** reaplica, **não** conecta ao banco, **não** insere linha. Qualquer delta (coluna de `opportunity_version`, coluna de evidência 7d) seria migration **aditiva gated** futura (Database + Security + Data/AI), como `entity_resolution_candidates`.
- **Zero número computado.** Nenhum Score/Velocity/Signals/Competition/ranking é calculado sobre dados reais aqui — só a **metodologia** de ordenar/rotular/selecionar/formatar é definida.
- **Zero IA / zero número gerado por modelo.** Ranking, HOT, Competition e Example são **CODE determinístico**; este estágio não tem LLM. IA permanece exclusiva do Entity Resolution (Agente 3).
- **Não redefine** Score/Velocity/Signals (owned por `DATA-SCORING-001`) nem a contagem de canais distintos (owned por `DATA-CHANNEL-001`) — **consumidos**, não reabertos.
- **Não publica** o relatório (o publish `draft→published` é ação de admin, downstream) e **não desenha** a VIEW pública de exposição por-coluna.
- **Não muda** keyword/janela/volume/fonte (`chicago drill type beat`, 30d, ~500/`run_id`); **não muda** os limiares textuais `>90`/`>83`/`5`/`15`/`50%` (só os **ratifica/estrutura** — OPEN-01).
- **Migration `0007` / `producer_events`: PARKED** (DEC-0013). **Fase 9 (RLS Policies + VIEW pública): VETADA** (SEC-0001 §0) — esta spec só assume a postura default-deny já aplicada (RLS-on + revoke).
- **Fora do escopo:** ML scoring; exposure penalty; data lake / baseline histórico; multi-keyword/multi-nicho; cross-report normalization; insight textual por IA; rodar o pipeline sobre dados reais; publicar; VIEW pública. **Raw imutável; computed reconstruível; snapshot congelado no publish.**
