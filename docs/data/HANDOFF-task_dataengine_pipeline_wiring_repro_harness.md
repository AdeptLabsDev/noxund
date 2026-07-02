# Handoff — task_dataengine_pipeline_wiring_repro_harness · Wiring determinístico + harness P5-REPRO-01

## 1. Identificação
- **Tarefa:** `task_dataengine_pipeline_wiring_repro_harness` (re-dispatch; execução anterior morreu em limite de sessão sem artefatos persistidos)
- **Owner agent:** Data/AI Pipeline Agent (`data_agent`)
- **Data:** 2026-07-02
- **Prioridade:** P1 (gate fail-closed antes de qualquer publish — DEC-0017 item 7)

## 2. Objetivo
Rascunhar o **wiring determinístico** do pipeline (compõe `entity_resolution → channel_filter → scoring → opportunity` via interfaces públicas) e o **harness P5-REPRO-01** que prova reprodutibilidade sobre fixtures **sintéticos** — DESIGN-ONLY. Entrega: 2 arquivos de código + 1 design doc + 1 handoff.

## 3. Critério de aceite (do backlog)
Função pura/determinística que recebe snapshot sintético em memória (raw + channel data de um `run_id`) e devolve as linhas de relatório ordenadas, compondo os módulos existentes na ordem ratificada; harness que prova idempotência/determinismo, independência de ordem, carimbo de proveniência (= v1 ratificado), regressão por golden-hash e casos de borda (vazio; `<83`→`insufficient`; `<2` cruzam 90 → `<2` HOT; dominação na fronteira `MAX_RUN_VIDEOS_PER_CHANNEL`). Sem coleta real, sem rede, sem DB, sem publish. Proveniência por linha (`run_id`, `artist_id`, `rubric_version`/`rubric_hash`, `rule_version`/`rule_hash`).

## 4. Resultado
- [x] Critério de aceite atendido
- [x] Demonstrável (como verificar): `cd services/data-engine && PYTHONPATH=src python -m unittest discover -s tests -p test_repro_harness.py -v` → `Ran 21 tests ... OK`

`pipeline.py` compõe as 4 zonas ratificadas por suas **interfaces públicas apenas** (nada dos internos foi reescrito), com a fronteira generativa (LLM do Agente 3) **desligada** (`llm=None`) para composição 100% determinística — títulos ambíguos/multi-artista/sem-marcador caem honestamente em `unresolved_video_ids`. Cada `ReportRow` carrega proveniência de nível-run completa (`run_id`, `artist_id`, `rubric_version`/`rubric_hash`, `rule_version`/`rule_hash`, `resolver_version`, `opportunity_version`/`opportunity_hash`). O harness prova as 5 propriedades de P5-REPRO-01 e travou o golden digest `c8e33fe8…74ca8`. Shape das linhas alinhado a `report_items` (Fase 5) — sem tocar DB.

## 5. Arquivos alterados
- `services/data-engine/src/noxund_data_engine/pipeline.py` — **NOVO.** Wiring puro/determinístico (`run_pipeline`), tipos de snapshot (`RawVideoRow`/`ChannelRow`/`ArtistRow`/`PipelineSnapshot`), saída (`ReportRow`/`PipelineProvenance`/`PipelineResult`), adaptadores in-memory dos ports (catalog/queue/replay), serialização canônica (`canonical_report`/`canonical_json`/`pipeline_digest`). `PIPELINE_VERSION = pipeline-wiring-2026_06_v1`.
- `services/data-engine/tests/test_repro_harness.py` — **NOVO.** 21 testes (stdlib `unittest`), fixtures sintéticos inline, golden digest travado.
- `docs/data/DATA-REPRO-001-p5-repro-harness-spec.md` — **NOVO.** Define o que fecha P5-REPRO-01, assertivas, modelo de fixtures, prova de reprodutibilidade.
- `docs/data/HANDOFF-task_dataengine_pipeline_wiring_repro_harness.md` — **NOVO.** Este handoff.

Nenhum módulo landado (`channel_filter`/`scoring`/`opportunity`/`entity_resolution`/`postgres_entity_resolution`) foi modificado. Nenhuma migration/DDL/workflow/env tocado.

## 6. Impacto no escopo
- **Mantém o MVP travado?** Sim. Compõe o que já foi ratificado (DEC-0017); zero constante nova de produto; `PIPELINE_VERSION` é só identidade do wiring.
- **Toca algum non-negotiable?** Não. IA **não** gera número (LLM desligado; todo número sai dos motores determinísticos). Pesos 40/25/20/15, keyword/janela/volume, Competition/Example — intocados.
- **Toca número/banco/auth/copy pública?** Número: **computa em memória sobre fixtures sintéticos** (não real, não persiste) → requer Data/AI review (§9). Banco/auth/copy: **não**.

## 7. Validação executada
- **Testes:** `test_repro_harness.py` → **21/21 OK**, executado **2× em processos independentes** com saída byte-idêntica (posture de CI). Suite completa da data-engine → **119/119 OK** (98 pré-existentes + 21 novos). Suite do resolver → **18 testes** (asserção fail-closed do job `data-engine-tests.yml` não afetada — filtra `-p test_entity_resolution.py`). Interpretador: **CPython 3.11.9** (Windows).
- **Reprodutibilidade (evidência):** `run_id=run-golden`, `rubric_hash` = `DEFAULT_RUBRIC.rubric_hash` (`f0c465fb…`), `rule_hash` (`7a1e3c76…`), `opportunity_hash` (`ce7c7c1a…`); `GOLDEN_DIGEST = c8e33fe85034e2c406bb189249ff829d8928a5b085d192c73220afcb89674ca8`. Idempotência, independência de ordem (reversão+rotação) e drift-sensibilidade (rubric mutado ⇒ digest muda) todas verdes. **O harness FOI executado** (Python disponível localmente); não estou reportando "passou" sem rodar.

## 8. DRIFT findings (código × DEC-0017 — registrados, NÃO corrigidos)
Auditei os módulos landados contra o v1 ratificado. **Nenhuma divergência comportamental encontrada** — o código está alinhado a DEC-0017:
- `channel_filter.MAX_RUN_VIDEOS_PER_CHANNEL = 60` ✓ (DEC-0017 item 5, **não** os 50 da proposta). `MIN_PUBLIC_UPLOADS`/`MIN_SUBSCRIBERS`/`MIN_CHANNEL_VIEWS`/`DUP_TITLE_CAP` = disabled ✓. `self_channel` exato ativo ✓.
- `scoring`: `P_VEL=P_ENG=p90`, `SIGNALS_SAT_CAP=20`, `DIVERSITY_TARGET=15`, `HALF_LIFE_DAYS=15`, `AGE_FLOOR_DAYS=1`, pesos 40/25/20/15, `ROUND_HALF_UP` final, normalização relativa ao run ✓.
- `opportunity`: HOT `>90` cap 2, ranking `final_score→velocity_component→signals_component→artist_id`, display `≥83`, até 10, `insufficient_opportunity` ✓.

**Observações (não-comportamentais, não corrigidas):**
- **D-1 (doc-stale, baixo):** `docs/data/DATA-CONST-001-rubric-constants-proposal.md` (tabela L59-62 + §6.2) ainda lista `MAX_RUN_VIDEOS_PER_CHANNEL=50` e os 4 gates como "PROPOSTA" — pré-ratificação. O código usa 60 (correto). Spec-refresh design-only já previsto em DEC-0017 §"Itens abertos". **Não** toquei a proposta.
- **D-2 (label, cosmético):** DEC-0017 usa `MIN_SUBS`; o código rotula `MIN_SUBSCRIBERS` na lista de gates desabilitados (`channel_filter._DISABLED_GATES`). Puramente nominal; entra no `rule_hash` congelado; mudar exigiria nova `rule_version`. **Não** corrigido (mudar quebraria o `rule_hash` ratificado).

## 9. Revisões necessárias
- [x] **Data/AI Review** — tocou pipeline/número (em memória, sintético) e reprodutibilidade.
- [ ] Security Review — não aplicável (zero auth/secret/endpoint/RLS/rede).
- [ ] Database/Data Integrity Review — não aplicável (zero schema/migration; shape apenas espelhado).
- [ ] QA Review — recomendável confirmar o harness como gate (fluxo crítico de reprodutibilidade).
- [ ] Product Lead — não há OPEN DECISION nova; DEC-0017 já ratificou tudo que o wiring honra.

## 10. Próximos passos
- **DevOps:** adicionar job de CI que rode `test_repro_harness.py` em cada PR (o job atual filtra só o resolver). Mecanismo pronto e reexecutável; falta o gate automatizado — ver DATA-REPRO-001 §7/§8.
- **Orchestrator:** abrir PR (sem auto-merge) com os 4 artefatos. Ao mergear, o `GOLDEN_DIGEST` fica travado como baseline de regressão.
- **Trilha gated (futuro, fora deste artefato):** writer que persiste `PipelineResult` em `artist_metrics`/`reports`/`report_items`; DC2-01 na coleta; spec-refresh de `DATA-CONST-001`/`DATA-CHANNEL-001` ao v1.

## 11. Open decisions / bloqueios
- **Nenhum bloqueio.** Todas as constantes/regras foram ratificadas em DEC-0017; o wiring apenas compõe.
- **Não-bloqueante:** o gate de CI dedicado (item DevOps §10) e o spec-refresh doc-stale (D-1) são follow-ups; não impedem o merge deste mecanismo.
