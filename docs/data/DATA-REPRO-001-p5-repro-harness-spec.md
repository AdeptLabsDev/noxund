# DATA-REPRO-001 — P5-REPRO-01: harness de reprodutibilidade do pipeline determinístico

- **Tarefa:** `task_dataengine_pipeline_wiring_repro_harness` (wiring determinístico + harness P5-REPRO-01)
- **Owner:** Data/AI Pipeline Agent (`data_agent`)
- **Ação:** `validate_reproducibility` (allow-list do `data_agent`)
- **Versão do wiring:** `pipeline-wiring-2026_06_v1` (`PIPELINE_VERSION`) — composição pura; **não** introduz constante nova de produto
- **Data:** 2026-07-02
- **Estado:** DESIGN + código de composição/teste sobre fixtures **sintéticos**. **Zero** coleta real, **zero** rede, **zero** DB, **zero** secret, **zero** LLM, **zero** publish. Nenhuma migration, nenhum ALTER.
- **Natureza:** compõe módulos já landados via suas interfaces públicas; **não** altera comportamento ratificado.
- **Fontes vinculantes:** `docs/product/decisions/DEC-0017-pipeline-v1-ratifications.md` (v1 ratificado — autoritativo); `docs/data/DATA-SCORING-001-popularity-scoring-spec.md`; `docs/data/DATA-CHANNEL-001-channel-filter-spec.md`; `docs/data/DATA-OPP-001-opportunity-spec.md`; `docs/data/DATA-CONST-001-rubric-constants-proposal.md` (proposta — DEC-0017 supersede onde diferem); `context/03_Data_AI_Agents_Methodology.md`; `context/04_Database_Event_Model.md`; `context/01_MVP_Scope_PRD.md`; `supabase/migrations/20260620000005_phase5_computed_metrics_reports.sql` (shape de `reports`/`report_items`, validadores F5-05A/F5-06A); `docs/agents/data-ai-pipeline-agent.md` (Definition of Done: "mesmo snapshot + rubric ⇒ relatório idêntico").
- **Artefatos de código:** `services/data-engine/src/noxund_data_engine/pipeline.py` (composição); `services/data-engine/tests/test_repro_harness.py` (harness).

---

## 1. O que P5-REPRO-01 exige para ser considerado FECHADO

P5-REPRO-01 é o **gate fail-closed** que precede qualquer publish real (DEC-0017 item 7; §Sequenciamento passo 5). Ele está **FECHADO** quando existe uma prova executável, versionada e reexecutável de que:

1. **Determinismo/idempotência.** Para um mesmo snapshot raw e as mesmas versões congeladas (`rubric_hash`, `rule_version`/`rule_hash`, `resolver_version`, `opportunity_hash`), o pipeline determinístico produz **linhas de relatório byte-idênticas** — igualdade profunda + ordenação estável.
2. **Independência da ordem de entrada.** Permutar a ordem das linhas de entrada (vídeos, canais, artistas do registry) **não** muda a saída — não há não-determinismo escondido em iteração de `set`/`dict`, ordenação instável ou relógio de parede.
3. **Proveniência carimbada.** Toda linha computada carrega as identidades ratificadas v1 (`rubric_version`/`rubric_hash` + `rule_version`/`rule_hash` + `resolver_version` + `opportunity_version`/`opportunity_hash`) — rastreável do número até o raw.
4. **Regressão por golden-hash.** Um digest estável (`sha256` da serialização canônica) de um fixture fixo guarda contra drift silencioso: **se o rubric mudar, o digest tem de mudar** ⇒ força uma nova `rubric_version` em vez de edição silenciosa de `…v1`.
5. **Casos de borda honestos.** Run vazio; todos os scores `< 83` ⇒ `insufficient_opportunity`; `< 2` cruzando 90 ⇒ `< 2` HOT; `> 2` cruzando 90 ⇒ HOT limitado a 2; dominação de canal único **exatamente** na fronteira `MAX_RUN_VIDEOS_PER_CHANNEL`.

Além disso, a prova precisa: (a) rodar **sem** rede/DB/secret/LLM (stdlib-only, coerente com `pyproject` `dependencies=[]`); (b) rodar de forma **repetível em CI** (o verde não pode estar preso a uma máquina); (c) **não** compor sobre dado real (não existe — só fixtures sintéticos).

**Nota de escopo (design-only):** este documento e o código associado **não** executam o publish, **não** conectam ao banco e **não** coletam. O fechamento operacional de P5-REPRO-01 como *gate de CI* (job dedicado que roda o harness em cada PR) é follow-up de **DevOps** (ver §7); o mecanismo de prova — objeto desta spec — está pronto e executado localmente.

## 2. Posição no pipeline (o que está sendo composto)

```text
raw_youtube_videos + raw_youtube_channels + registry de artists  (snapshot sintético, 1 run_id)
   │
   ▼  Zona 1 — Entity Resolution (DATA-ENTITY-001)         regex-first; LLM DESLIGADO (llm=None)
   │      resolve(video) → (video_id → artist_id) final; ambíguo/sem-match → unresolved (honesto)
   ▼  Zona 2 — Channel Filter (DATA-CHANNEL-001, v1)        verdicts + projeções Signals/Competition
   │      channel-filter-v1: único gate ativo MAX_RUN_VIDEOS_PER_CHANNEL=60; self_channel exato
   ▼  Zona 3 — Popularity Scoring (DATA-SCORING-001, v1)    final_score + 4 componentes + evidência
   │      score_rubric_2026_06_v1; normalização relativa aos artistas do próprio run
   ▼  Zona 4 — Opportunity (DATA-OPP-001, v1)               ranking · HOT · Competition · Example
          opportunity-rules-2026_06_v1 → ReportRow ordenadas + proveniência
```

O wiring **reinventa nada**: cada veredito, contagem, número e rótulo sai dos motores já landados, pelas suas interfaces públicas. `pipeline.py` apenas **roteia** dados entre as zonas e **carimba** a proveniência de nível-run em cada linha. A fronteira generativa (LLM do Agente 3) é deliberadamente mantida **desligada** para que a composição seja 100% determinística — isso é honesto: títulos ambíguos/multi-artista/sem marcador vão para `unresolved_video_ids` e **não** viram número.

## 3. Modelo de fixtures sintéticos

Os fixtures são construídos em memória (`PipelineSnapshot`), nunca coletados. Um snapshot descreve exatamente um `run_id`:

| Entrada | Tipo | Papel | Campos relevantes |
|---|---|---|---|
| `RawVideoRow` | linha de `raw_youtube_videos` | título → Entity Resolution; stats → Scoring; canal → Channel Filter | `video_id`, `channel_id`, `source_title`, `views`, `likes`, `comments`, `published_at` (tz-aware) |
| `ChannelRow` | linha de `raw_youtube_channels` | `title` → self_channel; tamanho carregado mas **não** avaliado (gates disabled) | `channel_id`, `title`, `subscriber_count`, `view_count`, `upload_count` |
| `ArtistRow` | `artists` + `artist_aliases` | registry de resolução: nome→artist_id; nomes→self_channel; canonical→título do item | `artist_id`, `canonical_name`, `aliases` |
| `PipelineSnapshot` | o run | agrega tudo + `report_title` + `window_end` (âncora temporal congelada) | — |

**Regras do modelo (para reprodutibilidade por construção):**

- **Sem relógio de parede.** A idade dos vídeos é medida contra `window_end` congelado; todo fixture fixa `window_end = 2026-06-30T00:00:00Z`.
- **NULL nunca vira 0.** `views=None` remove o vídeo de Velocity/Engagement (e o deixa por último no Example); o modelo permite `None` verbatim.
- **Resolução ancorada no registry.** Um vídeo só vira mapeamento final quando o nome extraído casa **exatamente um** artista registrado (espelha o real: artista novo passa por revisão, não é auto-criado). Nomes de fixture evitam disparar os regex de metadata/multi-artista do resolver.
- **Normalização é relativa ao run.** Como o Score normaliza contra o **p90 dos próprios artistas do run** (DEC-0017 item 4, sem baseline histórico), o valor absoluto de um artista depende dos demais no mesmo run — os fixtures são desenhados com essa dependência em mente (dois líderes estruturalmente idênticos saturam ao mesmo p90 → ambos HOT; artista único mínimo cai ~69 < 83).

**Fixture golden (fixo, digest travado).** `run-golden`: dois líderes idênticos (`Kairo Vee`, `Nova Blade`, 18 vídeos × 15 canais) → ambos `final_score=99` (HOT); um terceiro forte (`Rune Sol`, 16×12) → `92` (cruza 90 mas **sem** badge — prova o cap honesto de 2); um fraco (`Ghost Lane`, 1 vídeo) → `15` (abaixo do gate, descartado). Saída: 3 linhas exibidas, 2 HOT.

## 4. Assertivas do harness (`test_repro_harness.py`)

stdlib `unittest` (sem pytest, sem libs). 21 testes, agrupados pelas 5 propriedades + sanidade de composição + invariantes estruturais:

| # | Classe / teste | Prova |
|---|---|---|
| 0 | `PipelineCompositionTests` | a cadeia inteira conecta; shape do golden (scores, ranks, tags, Example↔URL↔reason coerentes); vídeos irresolvíveis são excluídos honestamente (`unresolved_video_ids`). |
| 1 | `IdempotenceTests` | duas execuções do golden ⇒ `rows` idênticas + `canonical_json` idêntico + `pipeline_digest` idêntico; digest é `sha256` hex de 64 chars. |
| 2 | `InputOrderIndependenceTests` | ordem **invertida** e ordem **rotacionada** dos vídeos/artistas ⇒ digest idêntico ao baseline. |
| 3 | `ProvenanceStampingTests` | **toda** linha carrega `rubric_version=score_rubric_2026_06_v1` + `rubric_hash=DEFAULT_RUBRIC.rubric_hash`, `rule_version=channel-filter-v1` + `rule_hash`, `resolver_version=entity-resolver-v1`, `opportunity_version/hash`; `selection_reason_json.versions` embute as versões efetivas. |
| 4 | `GoldenHashRegressionTests` | **(sempre ativo)** determinismo do digest + **drift-sensibilidade** (rubric mutado `half_life_days=30` ⇒ digest diferente) + identidades = v1 ratificado; **(baseline travado)** `pipeline_digest == GOLDEN_DIGEST`. |
| 5 | `EdgeCaseTests` | run vazio → `report=None`, `rows=()`, `insufficient=True` **sem** exceção; todos `<83` → `insufficient_opportunity`, 0 linhas; `<2` cruzam 90 → `<2` HOT; `>2` cruzam 90 → HOT capado em 2 (`rune` sem badge); dominação **exatamente** em 60 elegível / 61 `run_domination`; violações de contrato do snapshot rejeitadas. |
| 6 | `HotInvariantTests` | invariante estrutural em **todos** os fixtures: `len(HOT) ≤ 2`, `len(HOT) ≤ #(final>90)`, todo HOT tem `score_value>90`, e **nenhuma** linha exibida com `score_value<83`. |

### 4.1 O digest canônico (superfície de comparação)

`canonical_report(result)` projeta a saída pública + proveniência num dicionário JSON-nativo:

```json
{ "run_id", "window_end" (isoformat), "pipeline_version", "insufficient_opportunity",
  "provenance": { resolver_version, rule_version, rule_hash, rubric_version, rubric_hash,
                  opportunity_version, opportunity_hash },
  "rows": [ { run_id, rank, artist_id, title, tag, score_display, score_value, signals,
              velocity_display, competition_level, competition_channel_count,
              example_video_id, example_url, selection_reason_json, <proveniência por-linha> } ] }
```

`canonical_json` = `json.dumps(…, sort_keys=True, separators=(",",":"), ensure_ascii=False)`; `pipeline_digest` = `sha256` desse texto. `Decimal` (via evidência de string), `sha256` e JSON canônico são **determinísticos e portáveis entre plataformas** — o digest gerado em CPython 3.11 no Windows é igual ao de CI (ubuntu, CPython 3.11), o que autoriza travar o literal.

### 4.2 Golden-hash: por que o mecanismo é honesto mesmo com literal travado

O digest travado (`GOLDEN_DIGEST = c8e33fe8…74ca8`) foi **computado pelo próprio harness** e verificado por execução local (§6). A garantia central de P5-REPRO-01 — "drift no número ⇒ digest muda ⇒ nova `rubric_version`" — **não depende** do literal: o teste `test_digest_is_deterministic_and_drift_sensitive` prova, sem baseline, que mutar o rubric muda o digest. O literal (`test_digest_matches_locked_baseline`) adiciona o guarda contra **drift numérico silencioso** de um fixture fixo. Se algum motor mudar um número de forma legítima, o literal deve ser reatualizado **junto** com a nova `rubric_version`/`rule_version`/`opportunity_version` — nunca sozinho.

## 5. Como a reprodutibilidade é provada (cadeia de garantias)

- **Fonte da verdade temporal:** `window_end` congelado; nunca `now()`. (Scoring e Opportunity já constroem contra isso.)
- **Aritmética congelada:** Scoring roda sob contexto `decimal` de precisão fixa + `ROUND_HALF_EVEN` intermediário / `ROUND_HALF_UP` final; percentil com regra única (`linear_interpolation_inclusive`); recência via `exp(ln(0.5)·age/H)` (correctly-rounded). O wiring **não** faz aritmética de produto — só transporta números já congelados (a velocidade por-vídeo é **consumida** de `metrics_detail_json.videos.accepted[].vel` via `Decimal(str)`, round-trip exato).
- **Ordenação estável em cada zona:** cada motor re-ordena suas entradas por chave natural (`video_id`/`artist_id`); o wiring endereça vídeos por `video_id` (nunca por ordem de inserção de `dict`). ⇒ independência de ordem por construção, provada empiricamente por reversão e rotação.
- **Proveniência additiva:** as versões efetivas viajam na própria evidência (`selection_reason_json.versions`, `metrics_detail_json.versions`) — um rebuild não depende de tabela mutável (coerente com F5-06A do schema Fase 5).
- **Fail-closed honesto:** run vazio e "todos abaixo do gate" **não** fabricam HOT nem preenchem slot; canal deletado/suspenso é DC2-01 (aborta/recoleta como novo `run_id`) — fora do escopo puro deste harness, registrado como fronteira em §7.

## 6. Evidência de execução

Executado localmente em **CPython 3.11.9** (Windows), `PYTHONPATH=src python -m unittest discover -s tests -p test_repro_harness.py`:

```
Ran 21 tests ... OK     (2 execuções independentes, byte-idênticas)
GOLDEN_DIGEST = c8e33fe85034e2c406bb189249ff829d8928a5b085d192c73220afcb89674ca8
```

Suite completa da data-engine: **119 testes OK** (98 pré-existentes + 21 novos). A suite do resolver permanece em **18 testes** (a asserção fail-closed do job de CI `data-engine-tests.yml` — `-p test_entity_resolution.py` — não é afetada).

## 7. Fronteiras e follow-ups (design-only; fora deste artefato)

- **CI gate (DevOps):** adicionar um job que rode `test_repro_harness.py` em cada PR (o job atual filtra só `test_entity_resolution.py`). Enquanto isso, o harness é reexecutável manualmente e o determinismo já é provado ×2.
- **DC2-01 (canal deletado/suspenso):** fail-closed é regra de **coleta** (aborta/recoleta como novo `run_id`), não do compute puro; não modelado aqui além da exclusão honesta de vídeos irresolvíveis.
- **Writer gated:** persistir `PipelineResult` em `artist_metrics`/`reports`/`report_items` é trilha **gated** separada; este mecanismo só materializa em memória.
- **Registro de drift (código × DEC-0017):** ver handoff §8 — nenhuma divergência comportamental encontrada; a única observação é doc-stale em `DATA-CONST-001` (tabela ainda lista `MAX_RUN_VIDEOS_PER_CHANNEL=50`, pré-ratificação; o código usa 60 correto).

## 8. Definition of Done (checklist P5-REPRO-01)

- [x] Determinismo/idempotência provado (digest byte-idêntico ×2).
- [x] Independência de ordem provada (reversão + rotação).
- [x] Proveniência carimbada em toda linha, = identidades v1 ratificadas.
- [x] Golden-hash: drift-sensível (sempre ativo) + baseline literal travado.
- [x] Casos de borda: vazio · `insufficient` · `<2` HOT · cap-2 · fronteira 60/61.
- [x] stdlib-only, sem rede/DB/secret/LLM; reexecutável.
- [ ] **Gate de CI dedicado** (DevOps follow-up) — mecanismo pronto; falta o job.
