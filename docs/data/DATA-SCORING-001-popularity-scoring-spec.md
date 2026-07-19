# DATA-SCORING-001 — Popularity Scoring (Score determinístico, versionado e reproduzível)

- **Tarefa:** `task_define_popularity_scoring` (delegada via `delegate_task: define_scoring_methodology`, prioridade high)
- **Owner:** Data/AI Pipeline Agent (`data_agent`)
- **Ação:** `define_scoring_methodology` *(consta na allow-list publicada do `data_agent` — `data-ai-pipeline-agent.md` §Operating Protocol)*
- **Versão do rubric:** `score_rubric_2026_06_v1` (alinhada ao seed template da Fase 2; pesos do §7 da metodologia — **persistir, não redecidir**)
- **Data:** 2026-06-30
- **Estado:** spec de DESIGN. As tabelas que recebem o Score (`artist_metrics`, `rubric_versions`) **já estão aplicadas/verificadas** em produção (Fase 5 — DEC-0012; Fase 2). Esta tarefa **não aplica, não conecta ao banco, não executa código, não computa número real**.
- **Natureza:** define-only. Zero coleta, zero número computado, zero LLM, zero migration, zero secret, zero rede.
- **Dependência de entrada:** saídas determinísticas do **Channel Filter** (`DATA-CHANNEL-001`): conjunto canônico `ValidVideos(run, artist)`, **Signals** (`count` por `video_id`) e **Competition / canais distintos** (`count distinct channel_id`); raw imutável de `DATA-COLLECT-001` (`raw_youtube_videos` — `views`, `likes`, `comments`, `published_at`) ancorado em `report_runs.window_end`.
- **Fontes vinculantes:** `context/03_Data_AI_Agents_Methodology.md` §§1, 7, 8, 10–12, 14–15; `context/01_MVP_Scope_PRD.md` §5.2–5.6; `supabase/migrations/20260620000005_phase5_computed_metrics_reports.sql` (`artist_metrics` L259–294; validador `artist_metrics_detail_complete` L108–161; FK `(rubric_version, rubric_hash) → rubric_versions` L274–276); `supabase/migrations/20260620000002_phase2_versioning.sql` (`rubric_versions` L35–46; seed template L119–144); `docs/data/DATA-CHANNEL-001-channel-filter-spec.md` (§§6–7); `docs/data/DATA-COLLECT-001-youtube-collection-spec.md` (§4.3, §2); `docs/agents/data-ai-pipeline-agent.md`; `docs/product/scope-guardrails.md`; `docs/product/mvp-backlog.md` Épico 5 (`[DATA] Popularity Scoring Agent`, `[DATA] Opportunity Agent`); `docs/product/decisions/DEC-0013-sequencing-pipeline-first.md`.

---

## 1. Resultado e limite desta especificação

Esta spec fecha a metodologia do **Agente 5 — Popularity Scoring**: o nó que transforma o conjunto filtrado do Channel Filter + as estatísticas brutas de vídeo em **um único número determinístico por artista por run — o Score `X/100`** — gravado em `artist_metrics`. É a **segunda zona puramente determinística** depois do Channel Filter; aqui não atua nenhuma IA e nenhum número de produto é gerado por modelo.

Limite duro: o Score, seus quatro componentes e toda a normalização são **função aritmética determinística** de `raw_youtube_videos` (raw imutável) + `ValidVideos`/Signals/Competition (já definidos em `DATA-CHANNEL-001`) + a configuração congelada do rubric. **Mesmo raw + mesmo `rubric_version`/`rubric_hash` ⇒ Score byte-idêntico** (P5-REPRO-01), sem relógio de parede, sem rede, sem LLM. O Score **nunca é editado à mão**.

O que esta spec **NÃO** define (escopo do **Agente 6 — Opportunity**, §8): ranking, a regra de 2 HOT por relatório, a rotulação **Competition Low/Medium/High**, a seleção do **Example**, e a materialização das colunas públicas de exibição (`tag` HOT, `score_display`, gate de exibição `> 83`). Esta spec **computa** o número e os componentes para **todos** os artistas pontuáveis; quem decide **exibir** e **rotular** é o Opportunity.

O contrato lógico está nos §§2–9. As tabelas físicas `artist_metrics` e `rubric_versions` **já estão vivas** (Fase 5 / Fase 2); esta spec **ratifica o shape aplicado** (§4) e define o **contrato de uso/escrita** sobre ele — **zero ALTER, zero migration nova**. As decisões que dependem de humano (constantes e curvas de normalização que governam um número público) estão isoladas no §9 como OPEN QUESTIONS, antes de qualquer compute-live.

## 2. Posição no pipeline

```text
… → 4 Channel Filter (DATA-CHANNEL-001)
       ├─ ValidVideos(run, artist)            → inputs de vídeo (views, likes, comments, published_at do raw)
       ├─ Signals = count(ValidVideos)        → componente 25%
       └─ Competition = count(distinct channel)→ componente 15%
              └─→ 5 Popularity Scoring (ESTA spec, determinístico)
                     └─ artist_metrics: signals, velocity_median_per_day, engagement_score,
                        channel_diversity_count/score, raw_score, final_score (X/100),
                        rubric_version + rubric_hash, metrics_detail_json (auditoria)
                            └─→ 6 Opportunity: ranking · HOT(>90) · Score exibido(>83) ·
                               Competition Low/Med/High · Example  → reports/report_items (snapshot)
```

- **Consome (upstream):** o conjunto canônico `ValidVideos(run, artist)` e as duas cardinalidades ortogonais (Signals por `video_id`, Competition por `channel_id` distinto) **exatamente como definidos em `DATA-CHANNEL-001` §6** — esta spec **não redefine** Signals nem Competition; ela os **consome**. Cada vídeo de `ValidVideos` traz `views`/`likes`/`comments`/`published_at` verbatim de `raw_youtube_videos`. Só entram runs cujo gate de completude (`DATA-COLLECT-001` §7) passou e mappings finais (`needs_review=false`) do Entity Resolution.
- **Produz (downstream):** uma linha `artist_metrics` por `(run_id, artist_id, rubric_hash)` com os quatro componentes, o `raw_score`/`final_score` e a evidência `metrics_detail_json`. O Agente 6 lê `final_score` (para HOT/exibição) e os componentes (Signals/Velocity/Competition) para montar as linhas.
- **NÃO calcula** ranking, HOT, label de Competition nem Example — §8.

## 3. Entradas exatas e proveniência

Unidade de cálculo: **artista por run** — `(run_id, artist_id)`. Só é pontuado um artista que possui **`|ValidVideos(run, artist)| ≥ 1`** (pelo menos um vídeo válido — canal elegível + mapping final). Artista sem vídeo válido **não é pontuado** e **não gera linha** em `artist_metrics` (coerente com o CHECK estrutural F5-05A, que exige `videos.accepted` com ≥1 elemento). Zero-signal ⇒ fora do relatório (§9.1).

### 3.1 Inputs por vídeo (nível vídeo, verbatim do raw)

Para cada `v ∈ ValidVideos(run, artist)`:

| Campo | Origem (verbatim do raw) | Uso no scoring | Nulo |
|---|---|---|---|
| `video_id` | `raw_youtube_videos.video_id` | chave natural / dedup / proveniência | nunca nulo (PK do raw) |
| `views` | `raw_youtube_videos.views` | Velocity (numerador) + Engajamento (denominador) | **ausente ≠ 0** — vídeo sai do conjunto de inputs de Velocity/Engajamento (§5.3/§5.5), nunca vira zero fabricado |
| `likes` | `raw_youtube_videos.likes` | Engajamento (numerador) | **ausente ≠ 0** — tratado como contribuição ausente (§5.5) |
| `comments` | `raw_youtube_videos.comments` | Engajamento (numerador) | **ausente ≠ 0** — tratado como contribuição ausente (§5.5) |
| `published_at` | `raw_youtube_videos.published_at` | idade do vídeo (Velocity / recência) | nunca nulo na projeção válida (`DATA-COLLECT-001` §4.2) |

> **NULL nunca é tratado como zero** (espelha `DATA-COLLECT-001` §4.2 e a postura do Channel Filter): uma estatística oculta (`NULL`) não fabrica um zero que distorceria a média. A política por componente está em §5; ela é **explícita e auditada** em `metrics_detail_json` (vídeo no `videos.rejected[]` de um componente carrega o motivo, ex. `views_null`).

### 3.2 Inputs já agregados pelo Channel Filter (não recomputados aqui)

| Derivado | Origem | Uso |
|---|---|---|
| `ValidVideos(run, artist)` | `DATA-CHANNEL-001` §6.1 | conjunto-fonte de todos os componentes |
| `Signals` = `count(ValidVideos)` por `video_id` | `DATA-CHANNEL-001` §6.2 | componente 25% (§5.4); grava `artist_metrics.signals` |
| `Competition` = `count(distinct channel_id)` | `DATA-CHANNEL-001` §6.2 | componente 15% (§5.6); grava `artist_metrics.channel_diversity_count` |

A invariante de **não-duplicação** (Signals conta vídeos; Competition conta canais; mesma fonte `ValidVideos`; remoção atômica) é **propriedade herdada** do Channel Filter (`DATA-CHANNEL-001` §6.3) — esta spec **não a reabre**, apenas **consome** as duas projeções.

### 3.3 Referência temporal e parâmetros da run

| Campo | Origem | Uso |
|---|---|---|
| `window_end` | `report_runs.window_end` (instante UTC fixado uma vez na coleta) | **âncora temporal determinística** — é o "agora" usado para idade do vídeo. **Nunca** o relógio de parede (§5.2). |
| `window_start` | `report_runs.window_start` (= `window_end − 30d`) | bound da janela de recência |
| `run_id` | `report_runs.id` | escopo do conjunto de normalização (§5.7) |

### 3.4 Proveniência (rastreável até o raw)

- Cada `artist_metrics` ancora seus inputs em **`artist_metric_videos`** (`(artist_metric_id, run_id, video_id)`), cuja FK composta `(run_id, video_id) → raw_youtube_videos` **`ON DELETE RESTRICT`** garante que **todo vídeo que entrou em qualquer componente existe no raw e é indeletável** (Fase 5 §4 / F5-04).
- A evidência por célula (componentes, pesos, normalização, vídeos aceitos/rejeitados, versões, overrides) viaja em `metrics_detail_json` (§7), cujo shape mínimo o CHECK `artist_metrics_detail_complete` **já exige**.
- Logo, **todo Score é reconstruível byte-a-byte até `raw_youtube_videos`** por chave natural `(run_id, …)` + `rubric_version`/`rubric_hash`, sem depender de UUID mutável.

## 4. Tabela `artist_metrics` — shape aplicado (ratificado, design-only)

> A tabela **já está viva e verificada** em produção (Fase 5, DEC-0012, projeto `pwbkplzyzmortwjjpcbg`). Esta seção **documenta o shape autoritativo** aplicado em `20260620000005_phase5_computed_metrics_reports.sql` (L259–294) e o **contrato de escrita** sobre ele. **Nenhum ALTER é proposto aqui.**

```sql
-- LIVE (Fase 5). COMPUTED reconstruível por (run_id, artist_id, rubric_hash) sobre o raw.
-- DDL é SÓ ARMAZENAMENTO: ZERO CHECK de faixa/threshold de número (o cálculo é do data-engine).
create table public.artist_metrics (
  id                       uuid primary key default gen_random_uuid(),
  run_id                   uuid not null references public.report_runs (id) on delete restrict,
  artist_id                uuid not null references public.artists (id) on delete restrict,
  signals                  int,            -- count(ValidVideos) por video_id (§5.4) — de DATA-CHANNEL-001
  velocity_median_per_day  numeric,        -- mediana de views/dia dos vídeos válidos (§5.3)
  engagement_score         numeric,        -- engajamento ponderado por recência (§5.5)
  channel_diversity_count  int,            -- count(distinct channel_id) (§5.6) — de DATA-CHANNEL-001
  channel_diversity_score  numeric,        -- diversidade normalizada [0,1] (§5.6)
  raw_score                numeric,        -- soma ponderada contínua 0–100 (§5.7)
  final_score              numeric,        -- Score inteiro 0–100 = round(raw_score) (§5.7) → X/100 público
  rubric_version           text not null,  -- 'score_rubric_2026_06_v1'
  rubric_hash              text not null,  -- sha256(canonical_json(config do rubric)) (§5.1)
  metrics_detail_json      jsonb not null, -- auditoria por célula (§7); CHECK estrutural F5-05A/F5-06A
  created_at               timestamptz not null default now(),
  constraint artist_metrics_rubric_fk
    foreign key (rubric_version, rubric_hash) references public.rubric_versions (version, hash) on delete restrict,
  constraint artist_metrics_identity_key unique (id, run_id, artist_id, rubric_version, rubric_hash),
  constraint artist_metrics_id_run_key unique (id, run_id),
  constraint artist_metrics_detail_complete_chk
    check (public.artist_metrics_detail_complete(metrics_detail_json))
);
create unique index artist_metrics_run_artist_rubric_uidx
  on public.artist_metrics (run_id, artist_id, rubric_hash);  -- uma métrica por artista/run/rubric
```

**Contrato de escrita (sobre o shape aplicado):**

| Coluna | Regra do write-layer |
|---|---|
| `run_id`, `artist_id` | chave natural do artista pontuado na run; FK a `report_runs`/`artists`. |
| `signals` | `= count(ValidVideos)` (de DATA-CHANNEL-001); o componente 25% é a **normalização** desse inteiro (§5.4). |
| `velocity_median_per_day` | mediana determinística de `views/dia` dos vídeos válidos (§5.3); `NULL` se nenhum vídeo tiver `views` (auditado). |
| `engagement_score` | engajamento ponderado por recência ∈ [0,1] (§5.5); `NULL` se nenhum vídeo tiver `views>0`. |
| `channel_diversity_count` | `= count(distinct channel_id)` (Competition de DATA-CHANNEL-001). |
| `channel_diversity_score` | diversidade normalizada ∈ [0,1] (§5.6). |
| `raw_score` | soma ponderada contínua 0–100 (§5.7), precisão decimal plena. |
| `final_score` | `round(raw_score)` ∈ {0,…,100} pela regra de arredondamento fixa (§5.7). É o número que vira `X/100`. |
| `rubric_version` + `rubric_hash` | `('score_rubric_2026_06_v1', sha256(…))` — par **existe** em `rubric_versions` (FK composta); versiona o rubric inteiro (§5.9). |
| `metrics_detail_json` | evidência estruturalmente completa (§7); `{}` é rejeitado pelo CHECK; **nunca** exposta crua ao produtor (SEC-F03). |

**Unicidade lógica `(run_id, artist_id, rubric_hash)` (DATA-AI-0001):** re-score do **mesmo** raw sob um **novo** rubric (`…v2`) **não colide** — gera nova linha, preservando auditoria do Score anterior. Re-score sob o **mesmo** rubric reescreve sob a mesma chave (recompute legítimo), **enquanto a métrica não estiver publicada** (o guard condicional F5-03 torna inviolável só a linhagem já publicada).

## 5. O rubric versionado — `score_rubric_2026_06_v1`

O rubric é a **única autoridade** sobre como os números brutos viram Score. Ele é congelado como um todo (§5.9) e **persiste a decisão §7 da metodologia — pesos 40/25/20/15 — sem redecidir** (qualquer mudança de peso/componente é Stop Condition → escalar). Os **componentes e pesos são travados**; as **curvas/constantes de normalização** (que o §7 descreve por intenção, não por número) são **PROPOSTAS** e dependem de ratificação Data/AI + Product Lead (§5.8, §9), porque governam um número público.

### 5.1 Identidade e hash do rubric

- `rubric_version = 'score_rubric_2026_06_v1'` (string estável; alinhada ao seed template da Fase 2).
- `rubric_hash = sha256(canonical_json(config_congelada))`, computado **em código** pelo data-engine sobre a serialização canônica determinística de `config_json` (chaves ordenadas, sem espaço, números com representação fixa) — **nunca fabricado pelo banco** (o `rubric_versions.hash` é o mesmo valor; o Database só armazena, `20260620000002` §1/§seed).
- `config_congelada` inclui, como um todo: a **lista de componentes + pesos** (§5.3–5.6), as **funções e constantes de normalização** (§5.7–5.8), a **referência temporal** (§5.2), a **regra de mediana e a regra de arredondamento** (§5.3/§5.7), e a **política de NULL por componente** (§5).
- O par `(rubric_version, rubric_hash)` é gravado em **toda** linha `artist_metrics` (FK composta → `rubric_versions`) **e** em `metrics_detail_json.versions` (`rubric_version` + `rubric_hash` não-vazios — exigido por F5-06A). A versão também viaja para `reports`/`report_items` (congelada no snapshot, Fase 5 §5/§6).

### 5.2 Referência temporal determinística

Toda "idade" usa `report_runs.window_end` como o instante de referência — **o `now` da run, fixado uma vez na coleta**, jamais o relógio de parede. Para `v`:

```
age_days(v) = ( window_end − v.published_at ) / 86400   (em segundos UTC, aritmética exata)
age_eff(v)  = max( AGE_FLOOR_DAYS , age_days(v) )         (piso para evitar div→0 / spike absurdo)
```

`AGE_FLOOR_DAYS` é uma constante do rubric (§5.8). O piso protege determinismo e sanidade para vídeos publicados perto de `window_end` (idade ~0). Usar `window_end` (e não o relógio) é o que torna o replay byte-idêntico (§6).

### 5.3 Componente Velocity normalizada — peso **0.40**

Intenção §7: *views/dia do artista relativo à amostra*. Mediana (não média) por decisão de produto (PRD §5.5: reduz distorção de um viral isolado).

1. **Velocity por vídeo:** para cada `v ∈ ValidVideos` com `views` presente: `vel(v) = views(v) / age_eff(v)`. Vídeo com `views = NULL` **sai** do conjunto de inputs de Velocity (→ `velocity.rejected` com motivo `views_null`), **nunca** vira `0`.
2. **Velocity do artista (grava `velocity_median_per_day`):** `vel_artist = median{ vel(v) }` sobre os vídeos com `views`. Mediana **determinística**: ordenar ascendente por `(vel(v), video_id)` (chave de desempate estável); para `n` ímpar, o elemento central; para `n` par, média aritmética exata dos dois centrais. Se **nenhum** vídeo tiver `views`, `vel_artist = NULL` e a contribuição normalizada do componente = `0` (auditado; §9.2).
3. **Normalização relativa à amostra (`norm_velocity ∈ [0,1]`):** sobre o **conjunto de referência da run** = todos os artistas pontuados na run (§5.7). Função **PROPOSTA**: razão a um percentil-âncora com teto —
   `norm_velocity = min( 1 , vel_artist / V_REF )`, onde `V_REF = percentil P_VEL{ vel_artist : artistas pontuados da run }`.
   `P_VEL` (ex.: p90) é constante do rubric (§5.8). O teto-percentil é proposto por robustez a outliers (coerente com a escolha da mediana) e por estabilidade frente a um único artista extremo. **A função exata e `P_VEL` são OPEN-DATA-SCORING-02.** `V_REF` efetivo é **congelado em `metrics_detail_json.normalization`** para reconstrução por-artista (§7).

### 5.4 Componente Signals — peso **0.25** (com penalização de excesso)

Intenção §7: *quantidade de vídeos válidos, com penalização de excesso*. Mais sinal é bom, mas **retornos decrescentes** — volume muito alto sugere saturação/ruído, não demanda proporcionalmente maior.

1. **Bruto (grava `signals`):** `signals = count(ValidVideos)` — **consumido** de DATA-CHANNEL-001 §6.2 (por `video_id`), **não recomputado**.
2. **Normalização saturante (`norm_signals ∈ [0,1]`):** curva côncava (saturante) **PROPOSTA**:
   `norm_signals = min( 1 , ln(1 + signals) / ln(1 + SIGNALS_SAT_CAP) )`.
   `SIGNALS_SAT_CAP` é a contagem a partir da qual o componente satura em ~1 (constante do rubric, §5.8). A concavidade do `ln` **é** a "penalização de excesso": o ganho marginal por vídeo cai conforme `signals` cresce. **A curva exata e `SIGNALS_SAT_CAP` são OPEN-DATA-SCORING-02.**

### 5.5 Componente Engajamento ponderado por recência — peso **0.20**

Intenção §7 / seed Fase 2: *(likes+comments)/views, com peso maior para vídeos recentes*.

1. **Taxa por vídeo:** para `v ∈ ValidVideos` com `views(v) > 0`: `eng(v) = ( coalesce(likes,0) + coalesce(comments,0) ) / views(v)`.
   - **Política de NULL (auditada):** apenas o **numerador** trata `likes`/`comments` ausentes como **ausência de contribuição** (não há engajamento observável a somar) — isto **não** é "fabricar zero de estatística", é a definição da taxa quando o sinal positivo não foi reportado; fica registrado em `metrics_detail_json`. Vídeo com `views = NULL` **ou** `views = 0` **sai** do conjunto (`eng.rejected`, motivo `views_null_or_zero`) — taxa indefinida, nunca forçada.
2. **Peso de recência:** `w(v) = recency_weight( age_eff(v) )`, monotônico decrescente na idade dentro da janela de 30d. Forma **PROPOSTA**: decaimento exponencial `w(v) = exp( −LAMBDA_REC · age_eff(v) )` (alternativa linear `w(v) = max(0, (30 − age_eff(v))/30)`). `LAMBDA_REC` (ou meia-vida equivalente) é constante do rubric (§5.8). **Forma e constante são OPEN-DATA-SCORING-02.**
3. **Engajamento do artista (grava `engagement_score`):** média ponderada `engagement_raw = Σ w(v)·eng(v) / Σ w(v)` sobre os vídeos elegíveis ao componente; `NULL` se nenhum vídeo tiver `views>0`.
4. **Normalização (`norm_engagement ∈ [0,1]`):** mesma disciplina sample-relative do §5.3 com âncora-percentil `P_ENG` e teto 1 (`min(1, engagement_raw / E_REF)`), com `E_REF` congelado em `metrics_detail_json.normalization`. **OPEN-DATA-SCORING-02.**

### 5.6 Componente Diversidade de canais — peso **0.15**

Intenção §7: *múltiplos canais distintos validando a demanda*. Vários canais elegíveis distintos publicando para o artista = demanda **validada por terceiros** (não inflada por um único canal).

1. **Bruto (grava `channel_diversity_count`):** `= count(distinct channel_id over ValidVideos)` — **idêntico** ao **Competition** de DATA-CHANNEL-001 §6.2, **consumido**, não recomputado.
2. **Normalização (`norm_diversity = channel_diversity_score ∈ [0,1]`):** curva saturante **PROPOSTA** `min(1, ln(1+count)/ln(1+DIVERSITY_TARGET))` (mesma família do §5.4). `DIVERSITY_TARGET` é constante do rubric (§5.8). **OPEN-DATA-SCORING-02.**

> **Nota crítica de fronteira (mesma contagem, dois leitores ortogonais).** A **mesma** contagem de canais distintos é lida de duas formas que **não se contradizem**: (a) **aqui no Score**, como sinal **positivo** de demanda validada (componente 15%); (b) **no Opportunity** (§8), como **saturação de mercado** rotulada `Low/Medium/High`. O **Score não embute penalidade de saturação** sobre Competition — a leitura de saturação é exclusivamente do label do Agente 6. Manter as duas leituras separadas é deliberado e está alinhado à metodologia §§7–8.

### 5.7 Combinação → `raw_score` → `final_score` (X/100)

Conjunto de referência da normalização: **todos os artistas pontuados da run** (`|ValidVideos| ≥ 1`), congelado deterministicamente — o Score de um artista depende da composição da run, e isso é legítimo ("relativo à amostra", §7) **desde que a run inteira seja reprocessada junta** (§6). Os valores de referência efetivos (`V_REF`, `E_REF`, etc.) são **congelados em `metrics_detail_json.normalization`** para reconstrução por-artista no replay.

```
raw_score = 100 · ( 0.40·norm_velocity + 0.25·norm_signals + 0.20·norm_engagement + 0.15·norm_diversity )
              ∈ [0, 100]    (pesos somam 1.00; cada norm ∈ [0,1])
final_score = ROUND_HALF_UP( raw_score )   ∈ {0, 1, …, 100}     -- grava artist_metrics.final_score
```

- `raw_score` é gravado com **precisão decimal plena** (`numeric`); `final_score` é o inteiro `X/100`.
- **Arredondamento determinístico:** regra **fixa e congelada** no rubric — proposta `ROUND_HALF_UP` (metade arredonda para cima). A escolha entra no `rubric_hash`; **half-even vs half-up é OPEN-DATA-SCORING-03** (afeta o número público em bordas).
- **Aritmética exata:** todo cálculo intermediário usa **decimal de precisão fixa** (não ponto-flutuante IEEE-754), com escala intermediária congelada no rubric, para garantir resultado **byte-idêntico** entre execuções/máquinas (§6). Ordenações e desempates sempre por chave estável (`video_id`, `channel_id`, `artist_id`).

### 5.8 Constantes de threshold — PROPOSTAS, não travadas

A **estrutura e a semântica** das constantes são definidas aqui; **os valores numéricos finais não** — eles governam um **número público** e são ratificados por **Product Lead + Data/AI** antes de `score_rubric_2026_06_v1` virar definitivo e antes de qualquer compute-live (OPEN-DATA-SCORING-01/02/03).

| Constante | Papel | Componente | Proposta de partida (NÃO travada) |
|---|---|---|---|
| `AGE_FLOOR_DAYS` | piso de idade (evita div→0 / spike) | Velocity, Recência | `1` dia |
| `P_VEL` | percentil-âncora da normalização de Velocity | Velocity | `p90` |
| `SIGNALS_SAT_CAP` | contagem onde Signals satura (~1) | Signals | a ratificar |
| `LAMBDA_REC` (ou meia-vida) | taxa de decaimento de recência | Engajamento | meia-vida a ratificar dentro de 30d |
| `P_ENG` | percentil-âncora da normalização de Engajamento | Engajamento | `p90` |
| `DIVERSITY_TARGET` | contagem onde Diversidade satura (~1) | Diversidade | a ratificar |
| `ROUNDING` | regra de arredondamento de `final_score` | combinação | `ROUND_HALF_UP` |

Os **pesos 40/25/20/15 NÃO estão nesta tabela**: são **decisão travada §7** (persistir, não redecidir). Mudar peso/componente é Stop Condition (§9.4).

### 5.9 Congelamento por `rubric_version` / `rubric_hash`

`score_rubric_2026_06_v1` congela, como um todo: (1) componentes + pesos (§5.3–5.6); (2) referência temporal e `AGE_FLOOR_DAYS` (§5.2); (3) regra de mediana (§5.3) e regra de arredondamento (§5.7); (4) funções e constantes de normalização (§5.7–5.8); (5) política de NULL por componente (§5). **Qualquer** alteração de qualquer um desses itens exige **nova versão** (`score_rubric_2026_06_v2`) com **novo `rubric_hash`** — **nunca** editar o significado de `…v1` in-place (`rubric_versions` é append-only por trigger, Fase 2 §3). Como o rubric governa o Score, toda mudança é gatilho de **Data/AI + Product Orchestrator + QA Review** (`data-ai-pipeline-agent.md` §Required Reviews #5; scope-guardrails §"Decisões que exigem Data/AI Review").

## 6. Determinismo e reprodutibilidade (P5-REPRO-01)

O Score é o ponto mais sensível da promessa metodológica pública (`03_…` §1, §17): **IA generativa nunca produz, julga ou exibe número**. Esta spec garante isso por construção:

1. **Função pura.** Cada componente e a combinação são funções de `raw_youtube_videos` + `ValidVideos`/Signals/Competition + config congelada — **sem rede, sem LLM, sem relógio** (a referência temporal é `window_end`, do raw, não o `now()` do sistema).
2. **Aritmética exata.** Decimal de precisão fixa + arredondamento congelado + desempates por chave estável ⇒ resultado **byte-idêntico** independente de máquina/ordem de leitura.
3. **Conjunto de referência reproduzível.** A normalização sample-relative usa **todos os artistas pontuados da run** e congela os valores de referência efetivos em `metrics_detail_json.normalization` — o Score de cada artista é reconstruível mesmo isoladamente, e o replay da run inteira reproduz a mesma normalização.
4. **Sem edição manual.** O Score nunca é gravado/ajustado à mão. Override humano só existe **upstream** (elegibilidade de canal / mapping de artista) e viaja **congelado** em `metrics_detail_json.overrides[]` preservando a chave natural (`run_id` + `video_id|channel_id`, F5-06A) — o replay lê o override congelado, não a tabela mutável.
5. **Mapeamento direto a P5-REPRO-01.** Duas execuções de scoring sobre o **mesmo `run_id`** + **mesmas `rubric_version`/`rubric_hash`/`resolver_version`/`rule_version`** + **mesmas decisões replayable** ⇒ `signals`, `velocity_median_per_day`, `engagement_score`, `channel_diversity_count/score`, `raw_score`, `final_score` e a evidência **byte-idênticos** (excluindo apenas UUIDs e timestamps operacionais). Qualquer divergência = **bug metodológico → bloqueia o 1º publish** (`03_…` §12). Zero chamadas a qualquer adaptador não determinístico (não há LLM neste estágio — é justamente o ponto).

Ordem de replay (continuação da de DATA-CHANNEL-001 §7.3): (1) carregar raw + `ValidVideos`/Signals/Competition do Channel Filter sob `rule_version`; (2) validar `rubric_version`/`rubric_hash` registrados em `rubric_versions`; (3) ler overrides congelados (não a tabela mutável); (4) recomputar componentes → `raw_score` → `final_score`; (5) comparar byte-a-byte.

## 7. Proveniência e auditoria por célula

Toda linha `artist_metrics` carrega `metrics_detail_json` **estruturalmente completo** (CHECK `artist_metrics_detail_complete` — `{}` é rejeitado no banco). Esta spec **mapeia o cálculo ao shape já exigido** (não inventa coluna). Conteúdo mínimo (espelha `03_…` §10 — auditoria de Score/Velocity/Signals/Competition):

```jsonc
{
  "components": [                       // F5-05A: não-vazio
    { "key": "velocity_normalized",         "weight": 0.40, "raw": "<vel_artist>", "norm": "<norm_velocity>" },
    { "key": "signals",                     "weight": 0.25, "raw": "<signals>",    "norm": "<norm_signals>" },
    { "key": "engagement_recency_weighted", "weight": 0.20, "raw": "<engagement_raw>", "norm": "<norm_engagement>" },
    { "key": "channel_diversity",           "weight": 0.15, "raw": "<count>",      "norm": "<norm_diversity>" }
  ],
  "normalization": {                    // F5-05A: presente — referência sample-relative CONGELADA p/ replay
    "reference_set": "run_scored_artists",
    "velocity":   { "fn": "<func>", "p": "<P_VEL>",  "ref": "<V_REF efetivo>" },
    "engagement": { "fn": "<func>", "p": "<P_ENG>",  "ref": "<E_REF efetivo>" },
    "signals":    { "fn": "ln_saturating", "cap": "<SIGNALS_SAT_CAP>" },
    "diversity":  { "fn": "ln_saturating", "target": "<DIVERSITY_TARGET>" },
    "age_floor_days": "<AGE_FLOOR_DAYS>", "rounding": "<ROUNDING>"
  },
  "videos": {
    "accepted": [ { "video_id": "…", "views": …, "likes": …, "comments": …, "age_days": …, "vel": …, "eng": …, "w": … } ], // ≥1 (F5-05A) = ValidVideos
    "rejected": [ { "video_id": "…", "reason": "views_null | views_null_or_zero | mapping_not_final | channel_ineligible" } ]
  },
  "velocity":    { "inputs": [ { "video_id": "…", "views": …, "age_days": … } ], "median": "<velocity_median_per_day | null>" }, // F5-06A
  "competition": { "eligible_channel_ids": [ "…" ], "count": "<channel_diversity_count>" },                                    // = projeção de DATA-CHANNEL-001
  "versions":    { "rubric_version": "score_rubric_2026_06_v1", "rubric_hash": "<sha256>",
                   "resolver_version": "entity-resolver-v1", "rule_version": "channel-filter-v1" },                            // F5-06A: 4 não-vazios
  "overrides":   [ /* { "run_id": "…", "channel_id": "…", … } | { "run_id": "…", "video_id": "…", … } */ ]                      // F5-06A
}
```

- **Score → componentes/pesos/normalização/vídeos usados/`rubric_version`/`run_id`** (`03_…` §10); **Velocity → vídeos, views, idade, mediana**; **Signals → aceitos/rejeitados + motivo**; **Competition → canais distintos + lista**. Tudo presente.
- `metrics_detail_json` é **INTERNO** (SEC-F03): nunca exposto cru ao produtor; a superfície pública é `report_items` (via VIEW na Fase 9 — fora deste escopo).
- `artist_metric_videos` (proveniência referencial até o raw) é populado com **os `video_id` de `videos.accepted`** (FK composta → `raw_youtube_videos`).

## 8. Fronteira Scoring ↔ Opportunity (escopo OUT, handoff)

Esta spec **computa o número e os componentes**; o **Agente 6 — Opportunity** decide **exibição, rótulo, ordem e prova**. Limite explícito:

| Decisão | Dono | Regra | Por que NÃO é do Scoring |
|---|---|---|---|
| **HOT** (`tag = 'HOT'`) | **Opportunity** | `final_score > 90` (`03_…` §8; PRD §5.2) | É **rótulo de exibição** derivado do Score, não o Score. |
| **Score exibido** (`score_display = 'X/100'`) | **Opportunity** | só se `final_score > 83` (`03_…` §8; PRD §5.3) | O Scoring computa o número para **todos** (inclusive ≤83); o **gate de exibição** é do relatório. |
| **Ranking** | **Opportunity** | ordenação das 10 linhas | Scoring não ordena; produz métrica por artista. |
| **Regra 2 HOT por relatório** | **Opportunity** | composição do snapshot (PRD §4.4) | Decisão de montagem do relatório. |
| **Competition Low/Medium/High** | **Opportunity** | `Low ≤5 / Medium 6–15 / High >15 ou +50% em 7d` (`03_…` §8; PRD §5.6) | Scoring usa a **contagem** como componente (§5.6); o **label de saturação** é do relatório (§5.6 nota). |
| **Example / Reference** | **Opportunity** | top-3 por velocity → mais recente → maior views (`03_…` §8; PRD §5.7) | Seleção determinística de **prova**, com `selection_reason_json` próprio. |

O Scoring **entrega ao Opportunity**: `final_score` (para HOT/exibição), `signals`, `velocity_median_per_day`, `channel_diversity_count` (para Competition), e a evidência. Tudo o resto acima é **handoff** para o design de Opportunity (próxima tarefa recomendada).

## 9. Casos de borda, stop conditions e OPEN QUESTIONS

### 9.1 Bordas e fail-closed

- **Artista zero-signal** (`|ValidVideos| = 0`): **não pontuado**, **sem linha** em `artist_metrics` (o CHECK exige `videos.accepted ≥ 1`). Não entra no relatório. Honesto: ausência de sinal ≠ Score 0.
- **Todos os vídeos sem `views`** (Velocity indefinível): `velocity_median_per_day = NULL`, `norm_velocity = 0` (contribuição nula, auditada em `videos.rejected`/`velocity`), mas o artista **ainda é pontuado** pelos outros 3 componentes. Nunca fabricar views=0.
- **Nenhum vídeo com `views>0`** (Engajamento indefinível): `engagement_score = NULL`, `norm_engagement = 0`, auditado.
- **Vídeo publicado quase em `window_end`** (idade ~0): protegido por `AGE_FLOOR_DAYS` (§5.2) — sem div→0 nem spike.
- **Empates de `final_score` entre artistas:** o Scoring **não desempata** (não ranqueia); ties são resolvidos no Opportunity (ranking). O número em si é o que é.
- **Run incompleta** (gate `DATA-COLLECT-001` §7 não satisfeito) ou **mapping não-final** (`needs_review=true`): o vídeo não está em `ValidVideos` (já filtrado upstream) → não pontua; run incompleta **não** chega ao scoring (fail-closed).
- **`rubric_hash`/`rubric_version` ausente ou não registrado em `rubric_versions`:** a FK composta **impede** inserir a métrica → **Stop**; nenhum Score sem rubric versionado e registrado.

### 9.2 Política de NULL (resumo, nunca zero fabricado)

| Sinal ausente | Efeito | Auditoria |
|---|---|---|
| `views = NULL` | vídeo sai de Velocity **e** Engajamento | `videos.rejected` / `velocity` |
| `views = 0` | vídeo sai de Engajamento (taxa indefinida) | `videos.rejected` motivo `views_null_or_zero` |
| `likes`/`comments = NULL` | numerador de engajamento sem aquela contribuição (não é "estatística = 0") | registrado por-vídeo em `videos.accepted` |
| nenhum input válido p/ um componente | `norm = 0` e coluna `= NULL`, artista ainda pontuado pelos demais | `normalization` + `videos` |

### 9.3 Stop conditions (parar e devolver `needs_review`/`OPEN DECISION`)

- pedido para **IA gerar/julgar/ajustar** qualquer número (Score/Velocity/Signals/Competition) — viola o não-negociável (`03_…` §1; `data-ai-pipeline-agent.md`);
- mudar **peso/componente/normalização/constante/arredondamento** sem **nova `rubric_version`** + Data/AI + Product Lead Review;
- editar `final_score`/`raw_score` à mão, ou recompute de métrica **já publicada** (guard F5-03);
- **divergência de replay** (qualquer célula de negócio) entre duas rodadas;
- `rubric_hash` divergente do `config_json` registrado em `rubric_versions`;
- redefinir Signals/Competition (são **owned** por `DATA-CHANNEL-001`, não por esta spec);
- mudar keyword/janela/volume/fonte (Stop Condition global).

### 9.4 OPEN QUESTIONS (para Orchestrator / Product Lead / Data-AI antes de qualquer compute-live)

| ID | Tema | Impacto | Encaminhamento |
|---|---|---|---|
| **OPEN-DATA-SCORING-01** *(bloqueante p/ compute-live)* | **Valores finais das constantes** `{ AGE_FLOOR_DAYS, P_VEL, SIGNALS_SAT_CAP, LAMBDA_REC, P_ENG, DIVERSITY_TARGET }` (§5.8). Governam um **número público** (Score, e via Opportunity o HOT/exibição). | Definem o Score; afetam reprodutibilidade só por valor (a função é determinística para qualquer valor). | **Ratificar com Product Lead + Data/AI** antes de declarar `score_rubric_2026_06_v1` definitivo e antes do 1º compute-live. Esta spec define **estrutura/semântica**, não o número. |
| **OPEN-DATA-SCORING-02** *(bloqueante p/ compute-live)* | **Forma exata das curvas de normalização** por componente: (a) Velocity/Engajamento sample-relative — percentil-âncora+teto **vs** min-max **vs** percentile-rank; (b) Signals/Diversidade — `ln`-saturante **vs** outra côncava; (c) recência — exponencial **vs** linear. O §7 fixa a **intenção**, não a fórmula. | Muda o Score; cross-report comparability (min-max ata o topo ao melhor da run). | **Data/AI propõe + Product Lead ratifica.** Proposta default registrada (§5.3–5.6); congelar no `rubric_hash`. |
| **OPEN-DATA-SCORING-03** | **Regra de arredondamento** de `final_score` (half-up vs half-even) (§5.7). | Afeta o número público **em bordas** (ex.: 90.5→90/91 cruza o HOT). | Data/AI define; congelar no `rubric_hash`. Recomendação: `ROUND_HALF_UP`, explícito. |
| **OPEN-DATA-SCORING-04** | **Conjunto de referência da normalização** = "artistas pontuados da run". Confirmar que **não** se usa um baseline externo/histórico (proibido no MVP — sem data lake, `03_…` §13). | Define a semântica "relativo à amostra" e a estabilidade do Score. | Confirmar com Data/AI: referência é **a run**, congelada em `metrics_detail_json.normalization`. Sem baseline histórico no MVP. |
| **OPEN-DATA-SCORING-05** *(herdada, downstream de DATA-CHANNEL-001)* | Velocity/Engajamento de Velocity dependem de `views` ricos do raw (já coletados, `DATA-COLLECT-001` §4.3) — **mas** Signals/Competition dependem de `channel_eligibility`, que depende de `raw_youtube_channels` **ainda não coletado** (OPEN-DATA-CHANNEL-01). | Sem Channel Filter live, não há `ValidVideos` → Scoring não roda live. | **Não bloqueia este DESIGN** (DEC-0013, pipeline-first). Bloqueia compute-live junto com OPEN-DATA-CHANNEL-01. |

## 10. Escopo negativo (explícito)

- **Sem apply / sem `supabase db push` / sem migration nova.** `artist_metrics` e `rubric_versions` já estão vivos (Fase 5/Fase 2); esta spec **ratifica e define uso** — **não** ALTERa, **não** reaplica, **não** conecta ao banco, **não** insere `rubric_versions`.
- **Zero número computado.** Nenhum Score/Velocity/Engajamento/Diversidade é calculado sobre dados reais aqui — só a **metodologia** é definida.
- **Zero IA / zero número gerado por modelo.** Score e componentes são **CODE determinístico**; este estágio não tem LLM. IA permanece exclusiva do Entity Resolution (Agente 3).
- **Não redefine Signals nem Competition** — owned por `DATA-CHANNEL-001` (consumidos, não reabertos).
- **Não define** ranking, HOT, label de Competition, Example, exibição (`>83`) nem `score_display` — são do **Opportunity** (Agente 6, §8).
- **Não muda** keyword/janela/volume/fonte (`chicago drill type beat`, 30d, ~500/`run_id`); **não muda** pesos 40/25/20/15 (§7, travados).
- **Migration `0007` / `producer_events`: PARKED** (DEC-0013). **Fase 9 (RLS Policies + VIEW pública): VETADA** — esta spec só assume a postura default-deny já aplicada (RLS-on + revoke).
- **Fora do escopo:** ML scoring; exposure penalty; data lake / baseline histórico; multi-keyword/multi-nicho; cross-report normalization; rodar o rubric sobre dados reais; computar/inserir `rubric_versions`. **Raw imutável; computed reconstruível.**

---

## Adendo — 2026-07-19 — Spec-refresh (DEC-0023), aditivo, histórico preservado

> Este adendo **não reescreve** o corpo acima e **não altera** nenhum valor, `rubric_version` ou `rubric_hash`. O rubric `score_rubric_2026_06_v1` foi ratificado **como proposto** por [DEC-0017] (valores congelados no `rubric_hash`); estas ratificações apenas **nomeiam/fixam por escrito** o que já está congelado, fechando OPEN-A/OPEN-B do `DATA-AUDIT-001`.

- **§5.3 / §5.5 (normalização percentil-âncora) — método RATIFICADO: type-7 / interpolação linear inclusiva (vinculado a [DEC-0023] D-A).** A parte "método de cálculo do percentil" da `OPEN-DATA-SCORING-02` fica **fechada**: `V_REF`/`E_REF` usam **type-7** (numpy `linear` / `PERCENTILE.INC`), como já implementado (`scoring.py:103`, `:467-490`) e congelado. `V_REF`/`E_REF` efetivos seguem congelados em `metrics_detail_json.normalization`.
- **§5.3 / §5.7 e `OPEN-DATA-SCORING-04` — conjunto de referência com exclusão NULL RATIFICADA (vinculado a [DEC-0023] D-B).** A referência é **a run** (sem baseline histórico) e é formada **apenas por artistas com valor definido**: um artista com `vel_artist = NULL` (nenhum vídeo com `views`) **não entra na âncora** e **nunca** é convertido em zero — permanece pontuado, com contribuição normalizada `0` (auditada, coerente com o §5.3 item 2). Confirma `scoring.py:745-751`.
- **Sem mudança de valor/hash:** as constantes/pesos/curvas permanecem as de DEC-0017; nenhum código é tocado — `rubric_hash` e golden digest **inalterados**.

[DEC-0017]: ../product/decisions/DEC-0017-pipeline-v1-ratifications.md
[DEC-0023]: ../product/decisions/DEC-0023-audit-residual-ratifications-spec-refresh.md
