# DATA-CONST-001 — Proposta de constantes e curvas do rubric (candidatas à ratificação)

> **⚠️ RATIFICADO por [DEC-0017](../product/decisions/DEC-0017-pipeline-v1-ratifications.md) (2026-07-01).** Este doc é a **proposta** (snapshot de design). Fonte de verdade v1 = DEC-0017:
> **SCORING** ratificado **como proposto** → `score_rubric_2026_06_v1`.
> **CHANNEL-02 REVISADO para minimalista** (supersede as propostas de canal abaixo): `MAX_RUN_VIDEOS_PER_CHANNEL=60`; `MIN_PUBLIC_UPLOADS`/`MIN_SUBS`/`MIN_CHANNEL_VIEWS`/`DUP_TITLE_CAP` = **disabled** → `channel-filter-v1`.

- **Tarefa:** `task_propose_rubric_constants` (delegada via `delegate_task: propose_rubric_constants`, prioridade high)
- **Owner:** Data/AI Pipeline Agent (`data_agent`)
- **Ação:** `propose_rubric_constants` (DESIGN-only — proposta para ratificação humana)
- **Data:** 2026-06-30
- **Natureza:** define-only / propose-only. **Zero** apply, DB, secret, rede, código, IA e **zero número de produto computado**. Este documento **não** liga nenhum valor ao rubric vivo, **não** computa Score e **não** altera `score_rubric_2026_06_v1`.
- **Estado global:** **TODA proposta neste documento é candidata — "PROPOSTA — requer ratificação do Product Lead".** Nenhum valor é final, travado ou vivo enquanto o Product Lead (com Data/AI) não ratificar. O Score continua sendo **código determinístico** computado sobre constantes **ratificadas** e congeladas em `rubric_version`/`rubric_hash`. Isto respeita o não-negociável "IA nunca gera número": **o número (Score) é código; estes são candidatos de configuração para ratificação humana.**
- **Fontes de verdade lidas:** `docs/data/DATA-SCORING-001-popularity-scoring-spec.md` (§§5.2–5.8, §9.4 OPEN-DATA-SCORING-01/02/03/04); `docs/data/DATA-CHANNEL-001-channel-filter-spec.md` (§5.2–5.5, §8.3 OPEN-DATA-CHANNEL-02); `docs/data/DATA-COLLECT-001-youtube-collection-spec.md` (§1, §4.2–4.3); `docs/data/DATA-COLLECT-002-channel-data-collection-spec.md` (§4.2–4.3); `context/03_Data_AI_Agents_Methodology.md` §§1, 7, 8; `context/01_MVP_Scope_PRD.md` §§4.4, 5.2–5.7.
- **Fora do escopo (duro):** pesos 40/25/20/15 (§7 travado — **não tocados**); keyword/janela/volume/vertical; `0007`/`producer_events` (PARKED); Fase 9 (VETADA); ranking/HOT-tag/Competition-label/Example (Opportunity — Agente 6); computar qualquer Score/Velocity/Engajamento sobre dados reais.

---

## 1. Resultado, enquadramento e resumo das propostas

### 1.1 O que este documento é (e o que **não** é)

Este documento **propõe candidatos numéricos e de curva** para as decisões abertas que governam o rubric de scoring (`OPEN-DATA-SCORING-01/02/03/04`) e o filtro de canal (`OPEN-DATA-CHANNEL-02`). Cada item traz: **valor(es) proposto(s) + justificativa + 2–3 opções com trade-offs + recomendação + selo de ratificação.**

Ele **não** define a estrutura/semântica (isso já está fechado em `DATA-SCORING-001` e `DATA-CHANNEL-001`) e **não** computa número algum. A separação é deliberada e é o coração da promessa metodológica (`03_…` §1):

> **A fórmula é código determinístico. As constantes são configuração ratificada por humano. A IA não gera nenhum dos dois.**

Um valor só vira parte de `score_rubric_2026_06_v1` (ou `channel-filter-v1`) **após ratificação do Product Lead + Data/AI**, e então é congelado no `rubric_hash`/`rule_hash`. Enquanto isso, tudo aqui é **candidato**.

### 1.2 Calibração — escalas realistas do nicho (base de todas as propostas)

Todas as propostas são calibradas contra a única realidade coletável definida nas specs de coleta: **`chicago drill type beat`, janela de 30 dias, ~500 vídeos/run, produtores de canal pequeno**. As faixas abaixo são **estimativas de ordem de grandeza** do nicho (produtores small-channel de type beat), usadas só para dimensionar constantes — **não são números computados sobre dados reais** (nenhuma run foi coletada; `OPEN-DATA-CHANNEL-01` ainda bloqueia o live).

| Grandeza (por run de 30d, nicho small-channel) | Cauda baixa (típico) | Mediana aprox. | Cauda alta (artista/canal "quente") |
|---|---|---|---|
| Views por vídeo | dezenas | ~100–300 | 5k–50k+ (viral raro) |
| Velocity por vídeo (views/dia, idade 1–30d) | < 10/dia | ~10–40/dia | 500–2.000/dia |
| **Signals** (vídeos válidos por artista) | 1–2 | 2–5 | 15–40+ |
| Taxa de engajamento `(likes+comments)/views` | ~0,01 | ~0,02–0,05 | ~0,08–0,12 |
| **Competition / canais distintos** por artista | 1–3 | 3–6 | 15–30+ |

> As faixas são conservadoras e servem só para **dimensionar** as constantes (onde saturar, onde ancorar). O mecanismo de normalização é **sample-relative** (percentil da run) e **saturante** (teto `ln`), de modo que a maior parte da calibração é **auto-ajustável à run** — ver §7.

### 1.3 Tabela-resumo (todas as propostas — cada uma requer ratificação)

| Decisão | Constante / curva | **PROPOSTA (top recomendação)** | Estado |
|---|---|---|---|
| SCORING-01 | `AGE_FLOOR_DAYS` | **1 dia** | PROPOSTA — requer ratificação |
| SCORING-01 | `P_VEL` (âncora percentil Velocity) | **p90** | PROPOSTA — requer ratificação |
| SCORING-01 | `SIGNALS_SAT_CAP` | **20** vídeos | PROPOSTA — requer ratificação |
| SCORING-01 | `LAMBDA_REC` (decaimento recência) | **meia-vida 15 dias** (λ ≈ 0,0462/dia) | PROPOSTA — requer ratificação |
| SCORING-01 | `P_ENG` (âncora percentil Engajamento) | **p90** | PROPOSTA — requer ratificação |
| SCORING-01 | `DIVERSITY_TARGET` | **15** canais | PROPOSTA — requer ratificação |
| SCORING-02a | curva Velocity/Engajamento | **percentil-âncora + teto** (`min(1, x/pP)`) | PROPOSTA — requer ratificação |
| SCORING-02b | curva Signals/Diversidade | **`ln`-saturante** | PROPOSTA — requer ratificação |
| SCORING-02c | peso de recência | **exponencial** (`exp(−λ·age_eff)`) | PROPOSTA — requer ratificação |
| SCORING-03 | arredondamento de `final_score` | **`ROUND_HALF_UP`** | PROPOSTA — requer ratificação |
| SCORING-04 | conjunto de referência da normalização | **artistas pontuados da run** (sem baseline histórico) | PROPOSTA (confirmação) — requer ratificação |
| CHANNEL-02 | `MIN_PUBLIC_UPLOADS` | **3** uploads públicos | PROPOSTA — requer ratificação |
| CHANNEL-02 | `MAX_RUN_VIDEOS_PER_CHANNEL` | **50** vídeos na run | PROPOSTA — requer ratificação |
| CHANNEL-02 | `DUP_TITLE_CAP` | **3** títulos normalizados idênticos | PROPOSTA — requer ratificação |
| CHANNEL-02 | `MIN_SUBSCRIBERS` | **50** inscritos | PROPOSTA — requer ratificação |
| CHANNEL-02 | `MIN_CHANNEL_VIEWS` | **1.000** views de canal | PROPOSTA — requer ratificação |

---

## 2. SCORING-01 — as 6 constantes do rubric (valores propostos)

Lembrete de mecânica (de `DATA-SCORING-001` §5.7, **não redefinida aqui**):

```
raw_score = 100 · ( 0.40·norm_velocity + 0.25·norm_signals + 0.20·norm_engagement + 0.15·norm_diversity )
final_score = ROUND( raw_score )                      cada norm ∈ [0,1]; pesos travados
```

Consequência de fronteira que guia todas as propostas: para **HOT** um artista precisa de `final_score > 90` (ou seja, `raw_score` que arredonde para ≥ 91); para **Score exibido**, `final_score > 83` (arredonde para ≥ 84). Como Velocity pesa 40% e Signals 25%, **as constantes desses dois componentes são as que mais movem quem cruza 90/83** (§7).

### 2.1 `AGE_FLOOR_DAYS` — piso de idade

- **Papel:** `age_eff(v) = max(AGE_FLOOR_DAYS, age_days(v))`. Evita divisão→0 e o spike absurdo de velocity para vídeos publicados quase em `window_end` (idade ~0). Também define o teto do peso de recência (`exp(−λ·AGE_FLOOR)` no vídeo mais fresco).
- **PROPOSTA:** **1 dia.**
- **Justificativa (nicho + fronteira):** um vídeo publicado ~2h antes de `window_end` com 500 views teria idade ~0,08d → velocity fabricada de ~6.000/dia (outlier de "primeiro dia" inflado por notificação de inscritos), quando o dado ainda não estabilizou. Piso de 1 dia limita isso a 500/dia. "1 dia" é a **unidade natural** do próprio formato público de Velocity (`X/day`, PRD §5.5), portanto interpretável e auditável sem conversão. A distorção residual já é **duplamente amortecida** a jusante: Velocity usa **mediana** por vídeo (um vídeo fresco não domina) e depois **normalização por percentil** — por isso esta constante é de **baixa alavancagem** sobre quem cruza 90/83 (§7).
- **Opções:**
  - **1 dia (recomendado):** unidade natural, conservador o suficiente, mantém vídeos legitimamente rápidos.
  - **2 dias:** mais protetor contra surto de notificação do 1º dia; custo = penaliza vídeo genuinamente veloz. Alternativa razoável **se** dados reais mostrarem ruído de "day-one burst".
  - **0,5 dia:** menos amortecimento, mais risco de spike; não recomendado.
- **Recomendação:** **1 dia**, com `2 dias` como recuo conservador caso o burst do primeiro dia se prove ruidoso na primeira run.
- **Estado:** PROPOSTA — requer ratificação do Product Lead.

### 2.2 `P_VEL` — percentil-âncora da normalização de Velocity (componente 40%)

- **Papel:** `norm_velocity = min(1, vel_artist / V_REF)`, `V_REF = percentil P_VEL{ vel_artist : artistas pontuados da run }`. Todo artista **no ou acima** do percentil `P_VEL` recebe `norm_velocity = 1,0`.
- **PROPOSTA:** **p90.**
- **Justificativa (nicho + fronteira):** Velocity é o **maior peso (40%)**, logo esta é **a constante de maior alavancagem** sobre quem alcança HOT (§7). Ancorar em **p90** significa: só o **decil superior** de velocity da run "estoura" o componente dominante — o que torna HOT genuinamente seletivo (coerente com o alvo de ~2 HOT num relatório de 10, PRD §4.4). É **robusto por construção**: o artista mais extremo **não** define a escala (fica no teto 1,0), espelhando a decisão de usar **mediana** (não média) para Velocity — as duas escolhas resistem à distorção por um único viral. Determinístico: percentil sobre um conjunto fixo (a run) é reprodutível, desde que o **método de interpolação do percentil seja congelado** (ver §3.1).
- **Opções:**
  - **p90 (recomendado):** decil superior satura; HOT seletivo; robusto.
  - **p95:** ainda mais seletivo (só top 5%); risco de **não** preencher naturalmente 2 HOT em runs fracas.
  - **p75–p80:** mais generoso (quartil superior satura); mais artistas cruzam 90/83; dilui a exclusividade de HOT.
  - **min-max (`x/max`):** ata o topo ao **único** artista mais extremo → um outlier comprime todos os demais para baixo; frágil e não-robusto. **Rejeitado** (também é a decisão SCORING-02a).
- **Recomendação:** **p90.** É o ponto que concilia seletividade de HOT, robustez a outlier e coerência com a mediana.
- **Estado:** PROPOSTA — requer ratificação do Product Lead. **(Alta alavancagem — ratificar deliberadamente, §7.)**

### 2.3 `SIGNALS_SAT_CAP` — contagem onde Signals satura (componente 25%)

- **Papel:** `norm_signals = min(1, ln(1+signals) / ln(1+SIGNALS_SAT_CAP))`. `signals = count(ValidVideos)` (consumido de `DATA-CHANNEL-001`). A concavidade do `ln` **é** a "penalização de excesso" do §7 (retornos decrescentes).
- **PROPOSTA:** **20.**
- **Justificativa (nicho + fronteira):** Signals é o **2º maior peso (25%)**. Com `CAP=20`, ~20 vídeos válidos em 30 dias (um beat a cada ~1,5 dia mirando o artista) = **demanda saturada** — patamar coerente com a cauda alta do nicho (15–40, §1.2). A concavidade recompensa fortemente **"sair de 1 vídeo"** (1→3 sobe muito) e achata no topo (excesso ≠ demanda proporcional). Curva de referência com `CAP=20` (`ln(21)≈3,04`):

  | `signals` | `norm_signals` (CAP=20) |
  |---:|---:|
  | 1 | 0,23 |
  | 3 | 0,46 |
  | 5 | 0,59 |
  | 10 | 0,79 |
  | 20 | 1,00 |

  O meio-de-tabela (5–10 sinais) fica em **0,59–0,79** — abaixo da saturação, **preservando poder discriminante** exatamente na faixa onde a maioria dos artistas vive. Como `signals ≥ canais_distintos` sempre, um artista de Competition **High** (>15 canais → >15 vídeos) satura ou quase satura Signals — o que é coerente: quem tem mais atenção de produtores maximiza o componente.
- **Opções:**
  - **15:** satura mais cedo (nicho "quente" onde 15 já é pico); mais generoso.
  - **20 (recomendado):** equilíbrio; 20 vídeos = demanda claramente saturada.
  - **30:** mais rígido; só volume muito alto satura; risco de sub-recompensar.
- **Recomendação:** **20**, com `15` como alternativa "ajustada ao nicho quente" e `30` como conservadora. Constante semi-absoluta (não auto-ajusta à run) → **alta alavancagem, calibrar contra a distribuição real na 1ª run** e endurecer via nova `rubric_version` se necessário.
- **Estado:** PROPOSTA — requer ratificação do Product Lead. **(Alta alavancagem, §7.)**

### 2.4 `LAMBDA_REC` — decaimento de recência do Engajamento (componente 20%)

- **Papel:** `w(v) = exp(−LAMBDA_REC · age_eff(v))`; engajamento do artista = média ponderada por `w(v)`. Peso maior para vídeos recentes dentro da janela de 30d (`03_…` §7).
- **PROPOSTA:** **meia-vida de 15 dias** ⇒ `LAMBDA_REC = ln(2)/15 ≈ 0,0462 / dia`.
- **Justificativa (nicho + fronteira):** meia-vida de 15 dias (metade da janela) dá **preferência de recência real sem esvaziar a segunda metade da janela**. Pesos de referência (`λ≈0,0462`):

  | idade do vídeo | `w(v)` (meia-vida 15d) |
  |---:|---:|
  | 1 dia | 0,955 |
  | 7 dias | 0,724 |
  | 15 dias | 0,500 |
  | 30 dias | 0,250 |

  Um vídeo de 30 dias ainda carrega **25%** do peso de um fresco — recente conta mais, mas o vídeo do fim da janela **não é zerado**. Isso é essencial: uma meia-vida curta (ex.: 7d) faria a janela de engajamento **se comportar como ~10 dias**, contradizendo a janela de 30 dias travada (`DATA-COLLECT-001` §1). Alavancagem **média-baixa** (só 20% de peso, e reformula o interior do componente, não seu teto — que é fixado pela normalização percentil).
- **Opções:**
  - **meia-vida 15d (recomendado):** recência significativa, respeita a janela de 30d.
  - **meia-vida 7d:** favorece fortemente a última semana; **encolhe** a janela efetiva — não recomendado (briga com o invariante de janela).
  - **meia-vida 10d:** meio-termo (vídeo de 30d ≈ 0,125 de peso); alternativa se a última semana precisar de mais destaque.
- **Recomendação:** **meia-vida 15 dias.** Ver forma (exp vs linear) em SCORING-02c (§3.3).
- **Estado:** PROPOSTA — requer ratificação do Product Lead.

### 2.5 `P_ENG` — percentil-âncora da normalização de Engajamento (componente 20%)

- **Papel:** `norm_engagement = min(1, engagement_raw / E_REF)`, `E_REF = percentil P_ENG{ engagement_raw : artistas pontuados da run }`. Mesma família de `P_VEL`.
- **PROPOSTA:** **p90.**
- **Justificativa:** manter `P_ENG = P_VEL = p90` é **deliberado** — unifica um único conceito ("âncora sample-relative do decil superior") aplicado aos dois componentes de razão contínua, reduzindo a complexidade do rubric e a superfície de ratificação (um parâmetro conceitual, não dois). Robustez é **ainda mais** necessária aqui: taxas de engajamento de vídeos com poucas views são ruidosas; o percentil-âncora (contra min-max) impede que uma taxa extrema de um vídeo de baixa audiência defina a escala. O filtro `views>0`, o peso de recência e o teto-percentil, juntos, domam a cauda.
- **Opções:**
  - **p90 (recomendado):** coerência com `P_VEL`; robusto; um só conceito de âncora.
  - **p85:** levemente mais generoso; considerar só se o engajamento se mostrar muito comprimido na 1ª run.
  - **min-max / percentile-rank:** rejeitados pelos mesmos motivos de `P_VEL` (SCORING-02a).
- **Recomendação:** **p90**, casado com `P_VEL`.
- **Estado:** PROPOSTA — requer ratificação do Product Lead.

### 2.6 `DIVERSITY_TARGET` — contagem onde Diversidade satura (componente 15%)

- **Papel:** `norm_diversity = min(1, ln(1+count) / ln(1+DIVERSITY_TARGET))`. `count = channel_diversity_count` = **Competition** (canais distintos, consumido de `DATA-CHANNEL-001`).
- **PROPOSTA:** **15.**
- **Justificativa (amarra a um número que o Product Lead já ratifica):** 15 canais distintos é **exatamente a fronteira Medium/High** de Competition (`03_…` §8; PRD §5.6). Ancorar a saturação de diversidade **no mesmo 15** reaproveita um limiar que o Product Lead **já usa** para raciocinar sobre saturação de mercado — em vez de inventar um número novo. Curva de referência com `TARGET=15` (`ln(16)≈2,77`):

  | `count` (canais distintos) | `norm_diversity` (TARGET=15) | Bucket Competition |
  |---:|---:|---|
  | 1 | 0,25 | Low |
  | 3 | 0,50 | Low |
  | 5 | 0,65 | Low |
  | 10 | 0,87 | Medium |
  | 15 | 1,00 | Medium/High (fronteira) |

  O artista comum de Competition **Low** (1–5 canais) fica em **0,25–0,65** (bom poder discriminante), e quem tem validação genuinamente ampla (entrando em High) recebe crédito total de diversidade.
  > **Nota de fronteira crítica (herdada de `DATA-SCORING-001` §5.6):** a **mesma** contagem é lida **positivamente** aqui (15% do Score) e como **saturação** no label do Opportunity (Low/Med/High). O Score **não** embute penalidade de saturação; as duas leituras convivem. Esta proposta **não** reabre isso — só dimensiona a saturação positiva.
- **Opções:**
  - **15 (recomendado):** amarrado à fronteira Medium/High já ratificada.
  - **10:** satura no meio de Medium (mais generoso; mais artistas com diversidade cheia).
  - **20:** só artistas claramente High saturam (mais rígido).
- **Recomendação:** **15**, ancorado no limiar de Competition. Menor peso (15%) ⇒ **menor alavancagem** entre os quatro componentes (§7).
- **Estado:** PROPOSTA — requer ratificação do Product Lead.

---

## 3. SCORING-02 — curvas de normalização (forma exata)

O §7 fixa a **intenção** de cada componente; a **fórmula** é `OPEN-DATA-SCORING-02`. Três sub-decisões:

### 3.1 (a) Velocity/Engajamento sample-relative — **percentil-âncora + teto**

- **PROPOSTA:** `norm = min(1, x / x_ref)`, com `x_ref = percentil P{...}` (p90). **Recomendada** sobre min-max e percentile-rank.
- **Justificativa comparativa:**
  - **min-max (`(x−min)/(max−min)`):** ata **ambas** as pontas a artistas extremos; um viral isolado comprime todo o resto perto de 0 (péssima discriminação) e torna o Score refém de um artista. **Não-robusto → rejeitado.**
  - **percentile-rank (`rank/N`):** puramente **ordinal** — descarta magnitude (o #1 recebe 1,0 seja 2× ou 100× a mediana) e **garante** que sempre exista alguém em ~1,0 e alguém em ~0. Isso produziria um "artista perfeito" em **toda** run, inclusive numa run fraca — inflando HOT e **quebrando a honestidade** de "HOT = genuinamente quente" (não "apenas o melhor relativo"). **Rejeitado** pela lente de threshold público.
  - **percentil-âncora + teto (recomendado):** preserva **magnitude** abaixo da âncora (linear em `x/x_ref`), é **robusto** acima dela (satura em 1,0), e é o mais interpretável ("estar no decil superior de velocity da run = crédito total"). É a escolha coerente com mediana + `P_VEL`.
- **Determinismo obrigatório (congelar no `rubric_hash`):** o **método de cálculo do percentil** deve ser fixado — recomendação: **interpolação linear entre postos adjacentes** sobre o conjunto ordenado, com **desempate estável por `artist_id`**; e o **valor efetivo `V_REF`/`E_REF` congelado** em `metrics_detail_json.normalization` (já exigido pela spec) para replay por-artista.
- **Estado:** PROPOSTA — requer ratificação do Product Lead.

### 3.2 (b) Signals/Diversidade — **`ln`-saturante**

- **PROPOSTA:** `min(1, ln(1+n)/ln(1+CAP))`. **Recomendada.**
- **Justificativa:** é a curva côncava de "retornos decrescentes" com **um único parâmetro interpretável** (a contagem de saturação `CAP`/`TARGET`, que tem significado de produto). Alternativas: `sqrt` **nunca satura** (sem patamar → sem "penalização de excesso" clara); logística exige **dois** parâmetros (ponto médio + inclinação) sem ganho interpretativo. `ln`+teto é a escolha côncava de **mínimo número de parâmetros**. Monotônica, suave, determinística.
- **Estado:** PROPOSTA — requer ratificação do Product Lead.

### 3.3 (c) Peso de recência — **exponencial**

- **PROPOSTA:** `w(v) = exp(−LAMBDA_REC · age_eff(v))`. **Recomendada** sobre linear.
- **Justificativa:** exponencial é suave, **nunca chega a 0 dentro da janela** (o vídeo de 30d ainda pesa 0,25 com meia-vida 15d) e é parametrizada por **uma meia-vida interpretável**. A linear `max(0,(30−age)/30)` cria um **penhasco de borda**: um vídeo de 29 dias pesa ~0,03 e um de 30 dias pesa **exatamente 0** — descontinuidade arbitrária no fim da janela, que efetivamente descarta engajamento do último dia elegível. Exponencial evita esse cliff. (A meia-vida está em §2.4.)
- **Estado:** PROPOSTA — requer ratificação do Product Lead.

---

## 4. SCORING-03 — regra de arredondamento de `final_score`

- **PROPOSTA:** **`ROUND_HALF_UP`** (metade arredonda para cima).
- **Por que importa exatamente em 90,0/83,0:** os gates são **desigualdades estritas** — HOT exige `final_score > 90` (⇒ inteiro ≥ 91) e exibição exige `> 83` (⇒ inteiro ≥ 84). Logo o arredondamento **só** decide o destino de um artista que caia **exatamente** num `raw_score` terminando em `,5`. Exemplo de fronteira (o caso load-bearing):

  | `raw_score` | `HALF_UP` | HOT? | `HALF_EVEN` | HOT? |
  |---:|---:|:--:|---:|:--:|
  | 90,5 | **91** | **sim** | 90 | não |
  | 91,5 | 92 | sim | 92 | sim |
  | 83,5 | 84 | exibe | 84 | exibe |
  | 82,5 | 83 | não exibe | 82 | não exibe |

  Ou seja: **um artista em `raw_score = 90,5` é HOT sob half-up e não-HOT sob half-even** — a única diferença material entre as regras.
- **Justificativa (determinismo + auditoria):**
  1. **Ambas** as regras são 100% determinísticas; a decisão é qual congelar no `rubric_hash`. Não há vantagem de determinismo de um lado.
  2. A vantagem clássica do **half-even** (viés nulo em **somas** de muitos arredondamentos) **não se aplica aqui**: arredonda-se **um** número por artista, independentemente — não há somatório onde o viés se acumule.
  3. **Explicabilidade/confiança:** o produto promete um número **auditável e não-arbitrário** (`03_…` §1, §17). `HALF_UP` casa com a intuição leiga ("0,5 sobe, como na escola"); `HALF_EVEN` levando `90,5 → 90` (não-HOT) seria **surpreendente** para um produtor e mina a confiança na régua.
- **Interação a sinalizar ao Product Lead:** por causa da desigualdade estrita + arredondamento, o corte inteiro efetivo é `≥ 91` (HOT) e `≥ 84` (exibição). Uma alternativa mais limpa seria cravar o gate **direto no `raw_score`** (ex.: HOT sse `raw_score ≥ 90,5`), evitando o duplo-threshold (arredonda-e-compara). Como a spec fixa `final_score = round(raw_score)` como o `X/100` público e o gate como `final_score > 90`, mantém-se dentro dela; apenas **registra-se** a interação.
- **Opções:** `ROUND_HALF_UP` (recomendado, explicável) · `ROUND_HALF_EVEN` (default IEEE-754, mas sem benefício aqui e contra-intuitivo na borda).
- **Recomendação:** **`ROUND_HALF_UP`**, explícito e congelado no `rubric_hash`.
- **Estado:** PROPOSTA — requer ratificação do Product Lead.

---

## 5. SCORING-04 — conjunto de referência da normalização

- **PROPOSTA (confirmação):** referência = **todos os artistas pontuados da run** (`|ValidVideos| ≥ 1`). **Sem** baseline externo/histórico no MVP.
- **Justificativa:** é **mandatório** pela decisão de não construir data lake / histórico no MVP (`03_…` §13) — não há de onde tirar um baseline; construir um seria Stop Condition. A referência é a própria run, com `V_REF`/`E_REF` efetivos **congelados** em `metrics_detail_json.normalization` para reconstrução por-artista no replay (P5-REPRO-01). O conjunto **exclui zero-signal** (artista sem vídeo válido não é pontuado, `DATA-SCORING-001` §9.1) — logo os percentis são calculados sobre o **denominador honesto** (só quem tem sinal).
- **Implicações a ratificar conscientemente:**
  1. **Score é "relativo à amostra".** O mesmo artista pode pontuar diferente em outra run (composição diferente) — legítimo e **por design**, desde que a run inteira seja reprocessada junta (determinismo intra-run preservado).
  2. **Comparabilidade cross-report limitada:** um Score 88 no Relatório 1 **não** é diretamente comparável a 88 no Relatório 2 (conjuntos de referência distintos). **Aceitável no MVP** (2 relatórios fixos, sem alegação de tendência temporal). É coerente com o tooltip público — "mede performance recente dentro da janela analisada, **não** crescimento histórico" (PRD §5.3) — e com "sem exposure penalty" (`03_…` §14).
- **Recomendação:** **confirmar** run-scored-artists como referência única; **proibir** baseline histórico no MVP (Stop Condition se solicitado).
- **Estado:** PROPOSTA (confirmação) — requer ratificação do Product Lead + Data/AI.

---

## 6. CHANNEL-02 — as 5 constantes do filtro de canal

Mecânica (de `DATA-CHANNEL-001` §5.2, **não redefinida aqui**): gates em ordem fixa; o **primeiro** que falha define `is_eligible=false`. **NULL nunca é zero** — gates 2 e 4 só disparam quando o sinal está **presente E baixo** (`IS NOT NULL AND < piso`). Isso torna os gates **conservadores por construção** (§6.6).

Filosofia de dimensionamento: estes gates são filtros de **spam/qualidade**, **não** de popularidade. Num nicho de **produtores small-channel**, os pisos devem ser **baixos** — pegar só o lixo evidente **sem** excluir produtor pequeno-porém-real (excluir demais encolheria os denominadores de Signals/Competition de forma desonesta, `DATA-CHANNEL-001` §8.1). **Começar conservador; endurecer com dados reais via nova `rule_version`.**

### 6.1 `MIN_PUBLIC_UPLOADS` — Gate 2 (`insufficient_history`)

- **Papel:** `upload_count IS NOT NULL AND upload_count < MIN_PUBLIC_UPLOADS` ⇒ inelegível. `upload_count = statistics.videoCount` = **vídeos públicos totais do canal** (all-time, `DATA-COLLECT-002` §4.2).
- **PROPOSTA:** **3.**
- **Justificativa:** um canal com 1–2 uploads públicos totais quase certamente **não** é um produtor estabelecido; ≥3 já indica um histórico mínimo. Como `videoCount` é all-time, um produtor real facilmente tem dezenas/centenas — então mesmo um piso baixo (3) **não** ameaça produtor legítimo, e maximiza a proteção contra **falsa exclusão** (a postura NULL≠0). Distinguir `0` real (canal sem uploads públicos) de `NULL` (oculto) é mandatório (`DATA-COLLECT-002` §9).
- **Opções:** **3 (recomendado, remove só canais quase-vazios)** · 5 (moderado) · 10 (agressivo — risco de excluir produtor novo-mas-real).
- **Recomendação:** **3**; endurecer para 5–8 **só se** a 1ª run mostrar spam-farms com poucos uploads passando.
- **Estado:** PROPOSTA — requer ratificação do Product Lead.

### 6.2 `MAX_RUN_VIDEOS_PER_CHANNEL` — Gate 3 (`spam_burst`)

- **Papel:** `run_channel_video_count > MAX_RUN_VIDEOS_PER_CHANNEL` ⇒ inelegível. Conta vídeos **daquele canal na run** (run-local, deriva de `raw_youtube_videos`).
- **PROPOSTA:** **50.**
- **Justificativa:** a run inteira tem ~500 vídeos; **um único** canal com >50 vídeos do nicho em 30 dias é **>10% de todo o snapshot** — padrão de flood/upload-farm, não de produtor legítimo (que raramente passa de ~1–2 uploads/dia do mesmo nicho exato). É run-local, portanto **avaliável mesmo sem `raw_youtube_channels` rico**.
- **Opções:** 30 (agressivo — um "beat factory" legítimo postando 1/dia bate 30) · **50 (recomendado — claramente flood)** · 100 (muito permissivo).
- **Recomendação:** **50**; validar contra a distribuição real de vídeos-por-canal na 1ª run (constante candidata a ajuste com dados). Poderia ser expresso como fração (>10% da run), mas inteiro fixo é mais simples/determinístico.
- **Estado:** PROPOSTA — requer ratificação do Product Lead.

### 6.3 `DUP_TITLE_CAP` — Gate 3 (`spam_burst`, duplicação)

- **Papel:** `run_channel_dup_title_max ≥ DUP_TITLE_CAP` ⇒ inelegível. Maior multiplicidade de um mesmo `normalize_channel(title)` entre os vídeos do canal na run.
- **PROPOSTA:** **3.**
- **Justificativa:** produtor legítimo dá títulos distintos; repetir o **mesmo título normalizado** ≥3 vezes é reupload/manipulação. O cap opera sobre a **forma normalizada** (NFKC + casefold + pontuação→espaço), então `"CHICAGO DRILL Type Beat!!!"` e `"chicago drill type beat"` colapsam — pega dupes **semânticos**, não formatação. Cap=3 tolera 1 duplicata acidental (2) e pega o **padrão** (3+).
- **Opções:** 2 (agressivo — um único repost acidental dispara) · **3 (recomendado — padrão claro)** · 5 (permissivo).
- **Recomendação:** **3.**
- **Estado:** PROPOSTA — requer ratificação do Product Lead.

### 6.4 `MIN_SUBSCRIBERS` — Gate 4 (`low_channel_signal`, em **AND** com views)

- **Papel:** dispara **só** se `subscriber_count IS NOT NULL AND < MIN_SUBSCRIBERS` **E** `view_count IS NOT NULL AND < MIN_CHANNEL_VIEWS` (ambos presentes e baixos).
- **PROPOSTA:** **50.**
- **Justificativa:** muitos produtores small-channel legítimos têm <100 inscritos no início — por isso o piso é **baixo** e, crucialmente, **ANDado** com views: um canal com 30 inscritos mas 5.000 views de canal **não** é filtrado (o piso de views o salva). 50 é um "claramente não é canal real" quando **combinado** com view-count desprezível, não uma barra de popularidade. `hiddenSubscriberCount=true` ⇒ `NULL` ⇒ gate **não** dispara.
- **Opções:** **50 (recomendado)** · 100 (moderado) · 10 (muito permissivo).
- **Recomendação:** **50**, enfatizando a semântica **AND** (difícil de disparar por design).
- **Estado:** PROPOSTA — requer ratificação do Product Lead.

### 6.5 `MIN_CHANNEL_VIEWS` — Gate 4 (`low_channel_signal`, em **AND** com inscritos)

- **Papel:** o segundo piso do Gate 4 (ver §6.4). `view_count = statistics.viewCount` (views totais do canal, all-time).
- **PROPOSTA:** **1.000.**
- **Justificativa:** combinado com `<50 inscritos`, `<1.000 views de canal` identifica um canal com footprint de audiência essencialmente nulo (provável inativo/fake). Um produtor pequeno real cruza 1.000 views totais rapidamente. Ambos os pisos precisam falhar juntos → filtra só o canal que **prova** ser irrelevante.
- **Opções:** 500 (permissivo) · **1.000 (recomendado)** · 5.000 (moderado-agressivo).
- **Recomendação:** **1.000.**
- **Estado:** PROPOSTA — requer ratificação do Product Lead.

### 6.6 Por que **NULL ≠ 0** mantém os gates conservadores

Os gates 2 e 4 só disparam com o sinal **presente E abaixo** do piso (`IS NOT NULL AND < piso`). Logo:

- Um canal que **oculta** estatística (`subscriberCount` oculto, `videoCount`/`viewCount` ausente) **nunca** é excluído por um número que **não publicou** — o filtro erra para a **inclusão**.
- Isso é a postura honesta: **ausência de evidência (NULL) não é evidência de pequenez.** Impede fabricar um "0 inscritos" que **derrubaria falsamente** o gate.
- Efeito de sistema: os denominadores de Signals/Competition **não encolhem** por dado faltante; os gates pegam **só** canais que **afirmativamente revelam** um sinal baixo (ou padrão spam run-local). Gate 4 ainda exige **ambos** os sinais presentes e baixos (AND) — um `NULL` em qualquer um **desarma** o gate. Conservadorismo por construção.

---

## 7. Nota de sensibilidade — quais constantes mais movem quem cruza HOT(>90)/exibição(>83)/Competition

**Insight estrutural:** como a normalização é **sample-relative** (percentis) e **saturante** (tetos `ln`), a distribuição de Score é em grande parte **auto-calibrante** — as **âncoras percentil** controlam a *forma/seletividade* mais do que as escalas absolutas dos dados. Portanto, o Product Lead deve concentrar energia de ratificação nas **âncoras e nos dois tetos de saturação**, porque são elas — não a magnitude bruta dos dados — que decidem a população de HOT. As constantes de "contagem absoluta" (`SIGNALS_SAT_CAP`, `DIVERSITY_TARGET`) **não** auto-ajustam (codificam "quantos vídeos/canais = saturado"), logo são igualmente de alta alavancagem e específicas do nicho.

### 7.1 Ranking de alavancagem sobre os thresholds públicos (HOT >90 / exibição >83)

| # | Constante | Peso do componente | Alavancagem | Por quê |
|---:|---|---:|:--:|---|
| 1 | **`P_VEL`** | 40% | **ALTÍSSIMA** | Ancora o componente dominante; `p90→p80` inflaria muito quem chega a 90/83; `p90→p95` esvazia HOT. **A constante mais decisiva.** |
| 2 | **`SIGNALS_SAT_CAP`** | 25% | **ALTA** | Define onde os 25% saturam; baixá-la (20→10) empurra artistas de volume médio ao crédito cheio → infla Scores. Semi-absoluta (não auto-calibra). |
| 3 | **`P_ENG`** | 20% | **MÉDIA** | Mesmo mecanismo de `P_VEL`, peso menor e contribuição mais ruidosa. |
| 4 | **`DIVERSITY_TARGET`** | 15% | **MÉDIA-BAIXA** | Menor peso; além disso, `count` correlaciona com `signals` (ambos crescem com atenção de produtores) → alavancagem parcialmente redundante. |
| 5 | **`ROUNDING`** | — | **BAIXA (mas afiada na borda)** | Afeta ~nenhuma população, mas em **exatamente** `raw_score=90,5` liga/desliga HOT. "Baixa na população, decisiva no fio da navalha." |
| 6 | **`LAMBDA_REC`** | 20% (interno) | **BAIXA-MÉDIA** | Reformula o *interior* do engajamento; o teto do componente é fixado pela normalização percentil. |
| 7 | **`AGE_FLOOR_DAYS`** | 40%/20% (guard) | **BAIXA** | Amortecida por mediana + percentil; só afeta artistas com vídeos quase todos frescos. Guarda secundária. |

### 7.2 Constantes de canal — alavancagem sobre **Competition** (e indiretamente Signals/Score)

Remover um canal via qualquer gate custa **−1 em Competition** e **−(vídeos daquele canal) em Signals** para cada artista afetado, podendo **deslocar buckets** (High→Medium→Low, cortes em 5 e 15) e encolher o conjunto de referência da run:

- **Maior alavancagem em Competition:** `MIN_PUBLIC_UPLOADS` e os pisos do Gate 4 (`MIN_SUBSCRIBERS`/`MIN_CHANNEL_VIEWS`) — removem **canais inteiros** (−1 cada em Competition). Como os buckets cortam em **5 e 15**, endurecer esses pisos pode rebaixar artistas de High→Medium ou Medium→Low.
- **Maior alavancagem em Signals:** `MAX_RUN_VIDEOS_PER_CHANNEL` — remover um canal **prolífico** apaga **muitos** vídeos de uma vez (grande queda de Signals do(s) artista(s) daquele canal).
- **`DUP_TITLE_CAP`:** alavancagem menor (atinge poucos canais de reupload), mas protege a **integridade** da contagem contra manipulação.

> Recomendação de governança: ratificar **primeiro e com mais cuidado** `P_VEL`, `SIGNALS_SAT_CAP` e (para Competition) `MIN_PUBLIC_UPLOADS` + pisos do Gate 4 — são as alavancas que mais deslocam quem aparece como HOT, quem é exibido, e em qual bucket de Competition o artista cai. As demais podem ser ratificadas com os valores propostos e revisitadas após a 1ª run real (nova `rubric_version`/`rule_version` se mudarem).

---

## 8. Ratificação, versionamento e stop conditions

- **Nada aqui é vivo.** Cada valor só entra em `score_rubric_2026_06_v1` / `channel-filter-v1` **após ratificação Product Lead + Data/AI** e é então congelado em `rubric_hash` / `rule_hash`. Qualquer alteração posterior de constante/curva/arredondamento exige **nova versão** (`…v2`, novo hash) — nunca editar o significado de `…v1` in-place (`DATA-SCORING-001` §5.9; `DATA-CHANNEL-001` §5.5).
- **Bloqueantes de compute-live** que permanecem abertos independentemente desta proposta: `OPEN-DATA-SCORING-05` / `OPEN-DATA-CHANNEL-01` (`raw_youtube_channels` ainda não coletado — resolvido no **design** por `DATA-COLLECT-002`, mas o live depende do gate de coleta gated por Security/DevOps). Este documento **não** desbloqueia o live; só entrega os candidatos numéricos.
- **Stop conditions relevantes:** pedir à IA para **gerar/ajustar** qualquer número; tratar qualquer valor aqui como final sem ratificação; mudar peso 40/25/20/15 (travado, §7); mudar keyword/janela/volume; construir baseline histórico (proibido no MVP).

## 9. Escopo negativo (explícito)

- **Zero** número de produto computado; **zero** apply/DB/migration/secret/rede/código/IA. Um único artefato: **esta** proposta de design.
- **Não** altera pesos (§7 travado), estrutura/semântica das constantes (já fechadas em `DATA-SCORING-001`/`DATA-CHANNEL-001`), keyword/janela/volume/vertical.
- **Não** define ranking, HOT-tag, label de Competition, Example nem gate de exibição — são do **Opportunity (Agente 6)**.
- **Não** apresenta valor como final/ratificado — **todos são PROPOSTAS pendentes de ratificação do Product Lead.** `0007` PARKED; Fase 9 VETADA.
