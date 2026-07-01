# DATA-CHANNEL-001 — Channel Filter (elegibilidade determinística + canais distintos)

> **⚠️ RATIFICADO v1 por [DEC-0017](../product/decisions/DEC-0017-pipeline-v1-ratifications.md) (2026-07-01) — `channel-filter-v1` MINIMALISTA.** O conjunto de 4 gates ordenados descrito no corpo foi **SUPERSEDIDO**. Regras v1 vigentes:
> - **MANTÉM `self_channel`** — exclui o canal do próprio artista da Competition desse artista (regra semântica).
> - **`MAX_RUN_VIDEOS_PER_CHANNEL=60`** — único gate quantitativo (anti-domínio extremo de um canal no run).
> - **DISABLED:** `MIN_PUBLIC_UPLOADS`, `MIN_SUBS`, `MIN_CHANNEL_VIEWS`, `DUP_TITLE_CAP` (sem filtro por tamanho/duplicidade de título).
> - Contrato de dedup (Signals = vídeos válidos por `video_id`; Competition = canais elegíveis distintos) **permanece**.

- **Tarefa:** `task_define_channel_filter` (delegada via `delegate_task: define_channel_filter`)
- **Owner:** Data/AI Pipeline Agent (`data_agent`)
- **Ação:** `define_channel_filter` *(ver OPEN-DATA-CHANNEL-04 — nome ainda não está na allow-list publicada)*
- **Versão da regra:** `channel-filter-v1`
- **Data:** 2026-06-30
- **Estado:** spec de DESIGN. Schema `channel_eligibility` **já aplicado/verificado** em produção (DEC-0012); esta tarefa **não aplica, não conecta ao banco, não executa código**.
- **Natureza:** define-only. Zero coleta, zero número gerado, zero LLM, zero migration, zero secret, zero rede.
- **Dependência de entrada:** mappings finais de `DATA-ENTITY-001` (`video_artist_mappings.needs_review = false`) + raw imutável (`raw_youtube_videos`, `raw_youtube_channels`) de `DATA-COLLECT-001`.
- **Fontes vinculantes:** `context/03_Data_AI_Agents_Methodology.md` §§6, 8, 10–12, 16; `docs/agents/data-ai-pipeline-agent.md`; `docs/product/mvp-backlog.md` Épico 5 (`[DATA] Channel Filter Agent`, ~L276); `docs/product/scope-guardrails.md`; `docs/data/DATA-COLLECT-001-youtube-collection-spec.md`; `docs/data/DATA-ENTITY-001-entity-resolution-spec.md` (§§6.2, 8, 13); `supabase/migrations/20260620000004_phase4_raw_youtube_snapshots.sql` (raw); `supabase/migrations/20260620000005_phase5_computed_metrics_reports.sql` (`channel_eligibility` L228–245; `artist_metrics_detail_complete` L108–161); `docs/product/decisions/DEC-0012-phase5-apply-completed.md`; `docs/product/decisions/DEC-0013-sequencing-pipeline-first.md`.

---

## 1. Resultado e limite desta especificação

Esta spec fecha a metodologia do **Agente 4 — Channel Filter**: a primeira zona puramente **determinística** depois da única zona generativa (Entity Resolution). Ela define como, a partir do raw imutável e dos mappings finais, o pipeline decide **elegibilidade de canal** (com motivo + `rule_version`), conta **canais distintos por artista** (alimenta Competition) e seleciona **vídeos válidos** (alimentam Signals) **sem duplicar** os dois conceitos.

Limite duro: **nenhuma IA atua aqui** e **nenhum número de produto é gerado por modelo**. Toda a saída é função aritmética/string determinística de `raw_youtube_videos` + `raw_youtube_channels` + `video_artist_mappings`, congelada por `rule_version`. Mesmo raw + mesma `rule_version` ⇒ elegibilidade e contagens **idênticas**, sem I/O externo.

O contrato lógico está nos §§2–7. A tabela física `channel_eligibility` **já está viva** (DEC-0012); esta spec **ratifica o shape aplicado** (§4) e define o **contrato de uso/escrita** sobre ele — não propõe ALTER nem reaplicação. As decisões que dependem de humano (constantes de threshold, coleta de canal, taxonomia do `reason`) estão isoladas no §8 como OPEN QUESTIONS, antes de qualquer execução live.

## 2. Posição no pipeline

```text
… → 3 Entity Resolution (mappings finais, needs_review=false)
       └─→ 4 Channel Filter (ESTA spec)
              ├─ channel_eligibility (is_eligible + reason + rule_version)   → Competition
              └─ conjunto canônico de vídeos válidos por artista             → Signals
                     └─→ 5 Popularity Scoring (determinístico) → 6 Opportunity → snapshot
```

- **Consome (upstream):** somente `video_artist_mappings` com `needs_review = false`. Itens `pending`/`review_required` da fila `entity_resolution_candidates` **não entram** (DATA-ENTITY-001 §6.2). Run incompleta (gate de `DATA-COLLECT-001 §7` não satisfeito) **não entra**.
- **Produz (downstream):** o veredito por canal e o conjunto filtrado de vídeos/canais que o Agente 5 transforma em `signals`, `channel_diversity_count`/`channel_diversity_score` e que o Agente 6 lê como `competition_level`/`competition_channel_count`.
- **Não calcula Score**, Velocity, ranking nem Example — isso é do Agente 5/6.

## 3. Entradas exatas e proveniência

Unidade de avaliação: **canal por run** — `(run_id, channel_id)`. Só são avaliados os `channel_id` distintos que possuem **≥ 1 mapping final** (`needs_review = false`) na run; canais sem mapping final não são julgados e não afetam nenhuma métrica.

### 3.1 Sinais de canal (nível canal)

| Campo | Origem (verbatim do raw) | Uso | Nulo |
|---|---|---|---|
| `title` | `raw_youtube_channels.title` | detecção de `self_channel` | ausente = sem sinal de título |
| `upload_count` | `raw_youtube_channels.upload_count` | histórico mínimo de uploads públicos | **ausente ≠ 0** — não dispara `insufficient_history` |
| `subscriber_count` | `raw_youtube_channels.subscriber_count` | sinal de canal real | **ausente ≠ 0** — não dispara `low_channel_signal` |
| `view_count` | `raw_youtube_channels.view_count` | sinal de canal real | **ausente ≠ 0** — não dispara `low_channel_signal` |

> **NULL nunca é tratado como zero.** Um canal que oculta estatística (`NULL`) não é punido por uma faixa numérica que não pode ser avaliada (espelha a regra de `DATA-COLLECT-001 §4.2`: estatística ausente permanece `NULL`, nunca zero fabricado). Gates que dependem de um sinal ausente **não disparam**; o canal segue para os gates que ainda são avaliáveis.

### 3.2 Sinais de footprint na run (nível vídeo agregado por canal)

Derivados deterministicamente de `raw_youtube_videos` filtrado por `(run_id, channel_id)`:

| Derivado | Definição |
|---|---|
| `run_channel_video_ids` | conjunto de `video_id` do canal presentes no raw da run |
| `run_channel_video_count` | `|run_channel_video_ids|` |
| `run_channel_dup_title_max` | maior multiplicidade de um mesmo `normalize_channel(title)` entre os vídeos do canal na run |

### 3.3 Vínculo artista↔canal

De `video_artist_mappings` (`needs_review = false`): cada vídeo final aponta `artist_id`. O conjunto de artistas a que um canal está vinculado na run = `{ m.artist_id : m.run_id = run, m.video_id ∈ run_channel_video_ids, m.needs_review = false }`. Catálogo canônico (`artists.canonical_name`, `artist_aliases.alias`) é lido apenas para `self_channel`.

### 3.4 Proveniência (rastreável até o raw)

- Toda linha `channel_eligibility` ancora em `raw_youtube_channels(run_id, channel_id)` pela **FK composta `ON DELETE RESTRICT`** já aplicada — o canal julgado **existe** no raw e é indeletável.
- Todo vídeo válido ancora em `raw_youtube_videos(run_id, video_id)` (FK do mapping, DATA-ENTITY-001 §7). Logo, **Signals e Competition são reconstruíveis até `raw_youtube_videos`** por chave natural `(run_id, …)`, sem depender de UUID mutável.

## 4. Tabela `channel_eligibility` — shape aplicado (ratificado, design-only)

> A tabela **já está viva e verificada** em produção (DEC-0012, run `28311371393`, projeto `pwbkplzyzmortwjjpcbg`). Esta seção **documenta o shape autoritativo** aplicado em `20260620000005_phase5_computed_metrics_reports.sql` (L228–245) e o **contrato de escrita** sobre ele. **Nenhum ALTER é proposto aqui**; deltas eventuais (§8) seguiriam migration aditiva e gated, como `entity_resolution_candidates`.

```sql
-- LIVE (Fase 5). COMPUTED reconstruível por rule_version sobre o raw; ZERO trigger (recompute livre).
create table public.channel_eligibility (
  id                uuid primary key default gen_random_uuid(),
  run_id            uuid not null references public.report_runs (id) on delete restrict,
  channel_id        text not null,
  is_eligible       boolean not null,
  reason            text,                 -- contrato de uso: SEMPRE preenchido com um reason_code (§5.3)
  rule_version      text not null,        -- determinística (channel-filter-v1); nunca vazia
  reviewed_by_human boolean not null default false,
  created_at        timestamptz not null default now(),
  constraint channel_eligibility_raw_channel_fk
    foreign key (run_id, channel_id) references public.raw_youtube_channels (run_id, channel_id) on delete restrict
);
create unique index channel_eligibility_run_channel_uidx
  on public.channel_eligibility (run_id, channel_id);   -- um veredito por (run, canal)
-- RLS: enable + revoke anon/authenticated; ZERO policy / ZERO view (Fase 9 vetada). ZERO trigger.
```

Convenções herdadas das migrations aplicadas (mesma postura de `entity_resolution_candidates`):

- **Chave natural / unicidade:** `(run_id, channel_id)` único — exatamente **um** veredito por canal por run.
- **Proveniência forte:** FK composta `(run_id, channel_id) → raw_youtube_channels` **`ON DELETE RESTRICT`**.
- **Default-deny:** `enable row level security` + `revoke all ... from anon, authenticated`; **zero `create policy`**, **zero `create view`** (Fase 9 sob veto SEC-0001 §0).
- **COMPUTED reconstruível:** **zero trigger** de imutabilidade — recompute por `run_id` sob `rule_version` é legítimo (o veredito não é congelado; o que congela é a **evidência consumida pelo scoring**, em `artist_metrics`, §6.3).
- **Versão obrigatória:** `rule_version NOT NULL` (F5-06) — toda elegibilidade registra a versão determinística da regra que a produziu.

**Contrato de escrita (sobre o shape aplicado):**

| Coluna | Regra do write-layer |
|---|---|
| `run_id`, `channel_id` | chave natural ligada por FK ao raw; nunca canal fora do raw da run. |
| `is_eligible` | resultado booleano do §5 (gates determinísticos). |
| `reason` | **sempre não-vazio**: um `reason_code` da allow-list fechada do §5.3 (a coluna é nullable no schema, mas o writer nunca deixa `NULL`). |
| `rule_version` | `channel-filter-v1` non-blank — versiona a regra inteira (§5.5). |
| `reviewed_by_human` | `true` apenas quando há override humano registrado em `audit_events` (§6.3). |

## 5. Regra de elegibilidade determinística — `channel-filter-v1`

Heurística numérica de spam/histórico, **versionada e reproduzível**. Para cada `(run_id, channel_id)` avaliado (§3), os gates abaixo rodam em **ordem fixa**; o **primeiro** gate que falha define `is_eligible = false` e o `reason_code`. Se nenhum gate falha, `is_eligible = true`, `reason_code = eligible`. A ordem é parte de `channel-filter-v1` (determinismo do `reason`).

### 5.1 Normalização determinística

`normalize_channel(text)` é parte de `channel-filter-v1` e é **semanticamente idêntica** ao `normalize_for_match` de `entity-resolver-v1` (DATA-ENTITY-001 §3), versionada de forma independente para não derivar:

1. rejeitar `null`; string vazia → vazio normalizado;
2. Unicode NFKC; 3. Unicode casefold; 4. pontuação/símbolo/separador → espaço ASCII; 5. colapsar whitespace; 6. trim.

### 5.2 Gates (ordem fixa)

| # | Gate | Condição de **ineligível** (`is_eligible=false`) | `reason_code` | Sinal usado |
|---|---|---|---|---|
| 1 | **Self-channel** | `normalize_channel(channel.title)` é igual a `normalize_for_match(artist.canonical_name)` **ou** a algum `normalize_for_match(alias)` de um artista a que o canal está vinculado na run | `self_channel` | `title` + catálogo |
| 2 | **Histórico mínimo** | `upload_count IS NOT NULL` **e** `upload_count < MIN_PUBLIC_UPLOADS` | `insufficient_history` | `upload_count` |
| 3 | **Surto de spam** | `run_channel_video_count > MAX_RUN_VIDEOS_PER_CHANNEL` **ou** `run_channel_dup_title_max ≥ DUP_TITLE_CAP` | `spam_burst` | footprint na run |
| 4 | **Sinal de canal real** | `subscriber_count IS NOT NULL` **e** `subscriber_count < MIN_SUBSCRIBERS` **e** `view_count IS NOT NULL` **e** `view_count < MIN_CHANNEL_VIEWS` | `low_channel_signal` | `subscriber_count` + `view_count` |
| — | **Elegível** | nenhum gate acima falhou | `eligible` | — |

Notas de determinismo e conservadorismo:

- **Gate 1 (`self_channel`)** remove o canal do próprio artista da contagem de Competition — o artista não é um produtor concorrente; manter inflaria saturação de mercado. Casamento é **exato sobre forma normalizada** (sem fuzzy) → determinístico. Ambiguidade real (título do canal parecido, mas não idêntico) **não** dispara `self_channel`; cai em revisão humana opcional (§5.4, metodologia §16).
- **Gate 3 (`spam_burst`)** é puramente run-local (deriva de `raw_youtube_videos`), portanto avaliável mesmo sem `raw_youtube_channels` rico — mas a **escrita** ainda exige a linha raw do canal (FK, §8/OPEN-DATA-CHANNEL-01).
- **Gate 4** usa **AND** entre dois pisos (subscriber **e** view), para não derrubar canal pequeno-porém-real por um único sinal; ambos precisam estar **presentes e baixos**. `NULL` em qualquer um **não** dispara o gate.
- **"Vídeo alinhado ao padrão type beat"** (metodologia §6) já é garantido upstream: só vídeos com mapping final `<artist> type beat` (`needs_review=false`) chegam aqui. Não há gate de canal separado para isso — um canal sem nenhum vídeo válido simplesmente não entra em nenhum conjunto de artista (§6).

### 5.3 Taxonomia fechada de `reason_code` (machine-readable enum + motivo humano)

A elegibilidade **sempre carrega um motivo**: um código de máquina de uma **allow-list fechada** + uma frase humana **derivada deterministicamente** do par `(reason_code, rule_version)` por um mapa `código→texto` congelado no engine (não há texto livre escrito pela IA; nenhum número no motivo).

```
reason_code ∈ {
  eligible,              # is_eligible = true
  self_channel,          # canal do próprio artista (gate 1)
  insufficient_history,  # upload_count < MIN_PUBLIC_UPLOADS (gate 2)
  spam_burst,            # surto/duplicação em massa na run (gate 3)
  low_channel_signal,    # subscriber e view ambos presentes e abaixo do piso (gate 4)
  human_override         # veredito definido por revisão humana (reviewed_by_human=true; detalhe em audit_events)
}
```

- O `reason_code` é gravado em `channel_eligibility.reason` (a coluna `text` viva é usada como **valor codificado de allow-list**, não como texto livre). A frase legível é reconstruída em runtime/admin a partir do código + `rule_version`; **não** depende de uma coluna nova.
- `human_override` registra que o veredito final veio de decisão humana; o **antes/depois e o porquê** ficam em `audit_events` (§6.3), nunca embutidos como número ou PII na coluna `reason`.
- Representação do `reason` (text codificado vs enum tipado em migration aditiva futura) é **OPEN-DATA-CHANNEL-03** (decisão de Database).

### 5.4 Revisão humana (borda, não calibração)

Espelhando a metodologia §16, casos de borda vão a revisão humana sem "ajuste no olho":

- canal parece spam mas nenhum gate determinístico o cobre;
- `self_channel` ambíguo (semelhança não-exata);
- padrão de upload artificial não capturado por `spam_burst`;
- métrica outlier extremo.

O humano pode **sobrescrever o veredito** (ex.: marcar inelegível um spam que a regra não pegou), gravando `reviewed_by_human = true`, `reason_code = human_override`, e o evento append-only em `audit_events`. O humano **não** edita Score, contagem nem qualquer número — apenas o booleano de elegibilidade, e isso é reprocessável (§6.3). Mudar a **regra** (thresholds/gates) é forbidden sem nova `rule_version` + revisão Data/AI.

### 5.5 Congelamento por `rule_version` / `rule_hash`

`channel-filter-v1` congela, como um todo:

1. a função `normalize_channel`;
2. a lista ordenada de gates (§5.2) e a allow-list de `reason_code` (§5.3);
3. as **constantes** `{ MIN_PUBLIC_UPLOADS, MAX_RUN_VIDEOS_PER_CHANNEL, DUP_TITLE_CAP, MIN_SUBSCRIBERS, MIN_CHANNEL_VIEWS }`.

`rule_hash = sha256(canonical_json(config_congelada))` é computado em código sobre essa configuração e **persistido na evidência do scoring** em `artist_metrics.metrics_detail_json.versions.rule_hash` (chave aditiva — o validador F5-06A exige apenas `versions.rule_version` não-vazio; chaves extras são permitidas). **Qualquer** alteração de normalizador, gate, allow-list ou constante exige nova `rule_version` (`channel-filter-v2`) — **nunca** editar o significado de `channel-filter-v1`. Como mudar elegibilidade muda **Competition**, isso é gatilho de **Data/AI Review** (scope-guardrails §"Decisões que exigem Data/AI Review").

> **As constantes de threshold são PROPOSTAS, não travadas (OPEN-DATA-CHANNEL-02).** Valores numéricos de partida só viram `channel-filter-v1` definitivo após ratificação Product Orchestrator + Data/AI, porque governam Competition. Esta spec define a **estrutura e a semântica** das constantes; não inventa o número final.

## 6. Contagem de canais distintos × seleção de vídeos válidos — contrato de dedup

Esta é a invariante central (risco de backlog: *"Competition duplicar Signals"*). Tudo deriva de **um único conjunto canônico filtrado** por artista/run.

### 6.1 Conjunto canônico `ValidVideos(run, artist)`

```
ValidVideos(run, artist) = {
  v ∈ raw_youtube_videos(run) :
       ∃ m ∈ video_artist_mappings(run, v.video_id)
            com m.needs_review = false e m.artist_id = artist
   ∧  channel_eligibility(run, v.channel_id).is_eligible = true
}
```

Um vídeo só é "válido" se (a) tem mapping **final** para o artista **e** (b) seu canal é **elegível**. A elegibilidade é aplicada **uma vez, no nível do canal**, e propaga para tudo que segue.

### 6.2 Duas cardinalidades ortogonais sobre o MESMO conjunto

| Métrica | Definição (sobre `ValidVideos(run, artist)`) | Grão / dedup | Alimenta |
|---|---|---|---|
| **Signals** | `count(ValidVideos)` | **por `video_id`** (cada vídeo conta 1×) | Scoring §7 (25%, com penalização de excesso) |
| **Competition / channel diversity** | `count(distinct v.channel_id)` | **por `channel_id`** (cada canal conta 1×) | Scoring §7 (15%) + Opportunity §8 (Low ≤5 / Medium 6–15 / High >15) |

### 6.3 Invariantes de não-duplicação (o contrato explícito)

1. **Fonte única.** Signals e Competition saem do **mesmo** `ValidVideos`. Nenhum vídeo entra em Signals se seu canal for inelegível; nenhum canal entra em Competition sem ≥ 1 vídeo em `ValidVideos`.
2. **Grãos diferentes, nunca a mesma unidade duas vezes.** Signals conta **vídeos**; Competition conta **canais**. Um canal prolífico e elegível eleva Signals (muitos vídeos) mas soma **no máximo +1** em Competition (`distinct channel_id`). Eles **medem coisas diferentes** — não há dupla contagem da mesma unidade.
3. **Remoção atômica.** Marcar um canal inelegível remove **todos** os seus vídeos de `ValidVideos` → ele cai de Signals **e** de Competition **simultaneamente**. É impossível contar um vídeo em Signals enquanto se exclui seu canal de Competition (ou vice-versa).
4. **Aterrissagem auditável.** As duas projeções vão para `artist_metrics.metrics_detail_json`, cujo shape mínimo o CHECK estrutural F5-05A/F5-06A **já exige** (não inventa coluna):
   - `videos.accepted[]` (≥1) = `ValidVideos` (proveniência de Signals); `videos.rejected[]` = vídeos descartados + motivo (mapping pendente, canal inelegível, etc.);
   - `competition.eligible_channel_ids[]` + `competition.count` = projeção distinta de canais (proveniência de Competition).
   - **Asserção de coerência (gate de P5):** todo `channel_id` em `competition.eligible_channel_ids[]` é o canal de ≥ 1 vídeo em `videos.accepted[]`; `Signals = len(videos.accepted)`; `Competition = len(distinct competition.eligible_channel_ids)`. Divergência = bug metodológico → bloqueia publish.

### 6.4 Canal vinculado a múltiplos artistas

`is_eligible` é propriedade do **canal na run** (chave `(run_id, channel_id)`), não do par `(canal, artista)` — há **um** veredito. Esse veredito é aplicado independentemente ao `ValidVideos` de **cada** artista a que o canal contribui. Assim, um canal elegível que faz beats para dois artistas conta para a Competition de **ambos** (cada um +1), e seus vídeos contam para o Signals **do artista a que cada vídeo foi mapeado** — sem cross-count entre artistas.

## 7. Reprodutibilidade, auditoria e replay (rumo a P5-REPRO-01)

### 7.1 Recompute determinístico

`channel_eligibility` é **COMPUTED sem freeze** (zero trigger): pode ser recalculada por `run_id` sob a mesma `rule_version`. Como cada gate é função pura de raw + constantes congeladas (sem rede, sem LLM, sem relógio), **mesmo raw + mesma `rule_version` ⇒ vereditos byte-idênticos**. A unicidade `(run_id, channel_id)` garante um veredito por canal; um recompute legítimo reescreve sob a mesma chave.

### 7.2 Override humano — append-only + congelamento no scoring

Quando um humano sobrescreve elegibilidade (§5.4):

- `channel_eligibility.reviewed_by_human = true`, `reason = human_override`;
- decisão **append-only** em `audit_events` (`entity_table = 'channel_eligibility'`, `entity_id`, `before_json`, `after_json`, `reason`, `actor_type='admin'`) — `audit_events` é imutável por trigger (Fase 1);
- quando o fato é **consumido pelo scoring**, congela em `artist_metrics.metrics_detail_json.overrides[]` preservando a **chave natural** `run_id + channel_id`. O validador F5-06A **explicitamente aceita** `channel_id` em cada override (`(o ? 'run_id') and ((o ? 'video_id') or (o ? 'channel_id'))`) — é exatamente o slot do override de canal.

Assim, o replay não depende da tabela mutável nem só de `audit_events`: o fato não determinístico (a decisão humana) viaja congelado na evidência da métrica, como os overrides de Entity Resolution (DATA-ENTITY-001 §8.2).

### 7.3 Ordem de replay (P5-REPRO-01)

1. Carregar raw por `(run_id, …)`; validar `rule_version` non-blank/registrada.
2. Carregar mappings finais (`needs_review=false`) — sem reabrir a fila de Entity Resolution.
3. Em replay de scoring/publicação, ler primeiro os overrides congelados em `metrics_detail_json.overrides[]` (chave natural) — a tabela mutável `channel_eligibility` não substitui o fato congelado.
4. Na ausência de override, **reexecutar os gates** (determinísticos) sobre o raw para reconstruir o veredito automático.
5. Recomputar `ValidVideos`, Signals e Competition; **byte-idênticos** entre as duas rodadas nos campos de negócio/evidência (excluindo só UUIDs e timestamps operacionais).

P5-REPRO-01 segue **bloqueante antes do 1º publish**: duas rodadas sobre o mesmo `run_id` + mesmas `resolver_version`/`rule_version` + mesmas decisões replayable devem produzir as mesmas células e **zero** chamadas a qualquer adaptador não determinístico (não há LLM neste estágio — esse é justamente o ponto).

## 8. Casos de borda, stop conditions e OPEN QUESTIONS

### 8.1 Bordas e fail-closed

- **`raw_youtube_channels` ausente para um canal com vídeos mapeados** → a FK `channel_eligibility.(run_id, channel_id) → raw_youtube_channels` **impede** inserir o veredito. **Stop** (OPEN-DATA-CHANNEL-01); **não** descartar silenciosamente os vídeos do canal (encolheria o denominador de Signals/Competition de forma desonesta). Fail-closed: a etapa de Channel Filter da run não completa.
- **Todas as stats de canal `NULL`** → só `self_channel` e `spam_burst` (run-local) podem disparar; `insufficient_history`/`low_channel_signal` não asseveram (NULL ≠ pequeno). O canal pode passar como elegível pelos sinais disponíveis. Honesto e documentado.
- **Mapping pendente/`needs_review=true`** → o vídeo não entra em `ValidVideos`; vai para `videos.rejected[]` com motivo `mapping_not_final`.
- **Canal sem nenhum vídeo válido** (todos rejeitados no nível vídeo) → não integra nenhum `ValidVideos`; não afeta Signals/Competition. Veredito ainda pode ser gravado por completude de auditoria, mas não muda métrica.
- **Outlier extremo / padrão artificial não coberto por regra** → revisão humana (metodologia §16), `human_override`; nunca auto-filtragem fora de `channel-filter-v1`.

### 8.2 Stop conditions (parar e devolver `needs_review`/`OPEN DECISION`)

- pedido para IA gerar qualquer número/elegibilidade (viola não-negociável);
- mudar gate/threshold/`reason_code` sem nova `rule_version` + Data/AI Review;
- tentar mutar raw, ou compensar canal sem `raw_youtube_channels` burlando a FK;
- divergência de replay (Signals/Competition/elegibilidade) entre duas rodadas;
- run incompleta (gate `DATA-COLLECT-001 §7`) alcançando o Channel Filter.

### 8.3 OPEN QUESTIONS (para Orchestrator / Database / Security / Data-AI antes de qualquer apply/live)

| ID | Tema | Impacto | Encaminhamento |
|---|---|---|---|
| **OPEN-DATA-CHANNEL-01** *(bloqueante p/ LIVE)* | `raw_youtube_channels` **não é populado** por `DATA-COLLECT-001` (`channels.list` está fora do escopo, §11 daquela spec), mas `channel_eligibility` tem **FK obrigatória** a ele. Sem coleta de canal, nenhum veredito pode ser inserido **e** faltam os sinais ricos (`upload_count`/`subscriber_count`) dos gates 2 e 4. | Channel Filter **não pode rodar live**; gates 2/4 inavaliáveis. | Definir um **contrato de Channel Data** (`channels.list`) — extensão de `DATA-COLLECT-001` ou novo `DATA-COLLECT-002` — gated por Security (SEC-F23, body-only)/DevOps, como Search/Video Data. **Não bloqueia este DESIGN nem o design de Scoring** (DEC-0013, pipeline-first). |
| **OPEN-DATA-CHANNEL-02** | Valores numéricos das constantes `{ MIN_PUBLIC_UPLOADS, MAX_RUN_VIDEOS_PER_CHANNEL, DUP_TITLE_CAP, MIN_SUBSCRIBERS, MIN_CHANNEL_VIEWS }` de `channel-filter-v1`. | Mudam Competition → gatilho de **Data/AI Review**; afetam reprodutibilidade. | Ratificar com Product Orchestrator + Data/AI antes de declarar `channel-filter-v1` definitivo e antes de live. Esta spec define estrutura/semântica, não o número. |
| **OPEN-DATA-CHANNEL-03** | Representação de `reason`: `text` codificado (allow-list, **sem mudança de schema**) vs enum tipado em migration **aditiva** futura. | Tipagem/observabilidade. | Recomendação: manter `text` codificado (zero ALTER). Se Database preferir enum, é migration aditiva gated (Database + Security + Data/AI), como `entity_resolution_candidates`. |
| **OPEN-DATA-CHANNEL-04** *(governança, menor)* | A ação `define_channel_filter` **não consta** na allow-list publicada do `data_agent` (`agent-onboarding-orchestration.md` §9; `data-ai-pipeline-agent.md`), embora o Channel Filter (Agente 4) seja explicitamente **owned** por este agente. | Coerência de runtime/decision-log. | Orchestrator ratificar o nome da ação na allow-list (define-only, não-destrutivo). Trabalho em si é permitido (especificar/planejar determinístico — onboarding §4). |
| **OPEN-DATA-CHANNEL-05** | `rule_hash` não tem coluna em `channel_eligibility`. | Auditoria de versão da regra. | Recomendação: persistir em `metrics_detail_json.versions.rule_hash` (chave aditiva, já aceita). Coluna dedicada seria migration aditiva futura — flag p/ Database/Data-AI. |

## 9. Escopo negativo (explícito)

- **Sem apply / sem `supabase db push` / sem migration nova.** `channel_eligibility` já está vivo (DEC-0012); esta spec ratifica e define uso — **não** ALTERa, **não** reaplica, **não** conecta ao banco. Qualquer apply futuro (ex.: coleta de canal, enum de `reason`) segue **pipeline gated + aprovação humana + revisões Database/Security/Data-AI**, como `entity-db-apply`. Este estágio de design **não** o faz.
- **Migration `0007` / `producer_events`: PARKED** (DEC-0013) — fora desta cadeia.
- **Fase 9 (RLS Policies + VIEW pública, SEC-0001 §0): VETADA** — esta spec **não** desenha policy nem view; só postura default-deny (RLS-on + revoke), coerente com as Fases 1–5.
- **Zero IA / zero número gerado por modelo.** Toda elegibilidade e contagem é determinística sobre raw.
- **Sem mudar keyword/janela/volume** (`chicago drill type beat`, 30d, ~500/`run_id`). **Raw imutável; computed reconstruível.**
- **Fora do escopo:** rodar a regra sobre dados reais; coletar canais; Scoring; Opportunity; Example; multi-keyword; multi-nicho; data lake; exposure penalty; ML.
