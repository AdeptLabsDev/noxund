## DEC-0016 — Fechamento do CI de teste read-only do `data-engine` (resolver core PR #8 + workflow PR #9 mergeados e verdes em `main` — semente do P5-REPRO-01 reproduzível fora da workstation)

- **Data:** 2026-06-30
- **Status:** **Registrada — fato consumado.** PRs **#8** e **#9** mergeados em `main`; workflow `success` no ref mergeado (fail-closed na contagem ⟹ `18/18 ×2 + Determinism proven`). Fecha `task_land_data_engine_tests_ci`.
- **Decisor:** Product Lead (re-sequenciou **code-first**, revisou *Files changed* e mergeou #8 e #9, acompanhou o run verde) · registrada pelo Product Orchestrator · autoria DevOps (workflow) + Data/AI (resolver core).
- **Área:** CI/Infra (DevOps) / Metodologia (reprodutibilidade — P5-REPRO-01) / Data/AI (Entity Resolution core, zona generativa blindada) / Supply chain
- **Relaciona:** **DEC-0013** (pipeline-first — Channel Filter é o próximo do Épico 5), **DEC-0015** (entity-candidates apply; carry-forward: resolver→Channel Filter→scoring→P5-REPRO-01), `HANDOFF-data-engine-ci-tests.md` (autoria DevOps), `DATA-AI-0007 §3` (P5-REPRO-01 = gate do `data-engine` antes do 1º publish), carry-forward #1 da QA (verde preso a uma workstation)

### Contexto
O workflow `data-engine-tests.yml` roda a suíte do resolver e asserta `Ran 18 tests … OK` **fail-closed ×2**. No landing, o Orchestrator descobriu um conflito **escopo × critério**: o código Python do resolver (`entity_resolution.py`, `postgres_entity_resolution.py`) e a suíte de 18 testes estavam **uncommitted** (untracked no working tree), e `origin/main:services/data-engine/` só tinha o scaffold (4 arquivos). O DEC-0015 fechou o lado **de DB** da Entity Resolution (migration aplicada), mas o **código Python nunca foi commitado** — gap de proveniência. Landar só o workflow daria `Ran 0 tests` → **vermelho**. O Orchestrator **escalou** (Escalation Rules) em vez de (a) abrir um PR que nasceria vermelho ou (b) expandir escopo unilateralmente.

### Decisão (o que se registra)
1. **Re-sequenciamento code-first autorizado pelo Product Lead.** **PR #8** (`data-ai/entity-resolution-core`) landou o resolver core — `entity_resolution.py` (regex-first, NFKC/casefold, guardrail de span contíguo, fallback LLM estrito sem número), `postgres_entity_resolution.py` (adapters sem driver, SQL parametrizado, auditoria por allow-list), suíte de **18 testes** (doubles em memória) + wiring (`__init__.py`/`pyproject.toml`/`README.md`, **stdlib-only**, v0.0.0→0.1.0). **Mergeado em `main` (`7c003da`)** — fecha o gap de proveniência do código Python da Entity Resolution.
2. **PR #9** (`infra/data-engine-ci-tests`) landou o **workflow read-only** + handoff. **Mergeado em `main` (`f5746a9`)**: actions **SHA-pinadas** (`checkout 34e1148`=v4.3.1, `setup-python 0b93645`=v5.3.0), `permissions: contents: read`, **zero** secret/Environment/DB, Python **3.11 pinado** + assert `CPython 3.11.x`, **stdlib-only** (zero `pip install`). Roda em `push`/`pull_request` (desvio consciente e correto vs. template de apply gated — teste read-only sem produção).
3. **Verde reprodutível ancorado.** Run em `push main f5746a9` = **`success`**; como o job asserta a **contagem fail-closed** (uma regressão de discovery que rodasse 0 testes sairia 0 no unittest), `success` ⟹ `attempt 1/2: 18/18 OK` + `Determinism proven`. O `18/18` agora é reproduzível **fora da workstation da QA** → resolve o **carry-forward #1 da QA** e ancora a **semente do P5-REPRO-01**.
4. **Nenhum gate downstream destravado.** Sem migration aplicada, sem `production-db`, sem secret/Environment. **Fase 9** (RLS Policies + VIEW pública, SEC-0001 §0) segue **vetada**; **`producer_events`/`0007`** segue **PARKED** (DEC-0013).

### Evidência de registro
| Item | Evidência |
|---|---|
| PR #8 (resolver core) | merge `7c003da`; 6 arquivos (resolver + 18 testes + wiring); `tests/test_entity_resolution.py` = 18 `def test_` em `main` |
| PR #9 (workflow) | merge `f5746a9`; 2 arquivos (`data-engine-tests.yml` +102 / `HANDOFF-data-engine-ci-tests.md` +105) |
| Supply chain | `actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5` (v4.3.1) · `actions/setup-python@0b93645e9fea7318ecaed2b359559ac225c90a2b` (v5.3.0) |
| Verde no ref mergeado | run `28477118960` (`push main f5746a9`) → `success`; + runs `28477020805`/`28476991444` no branch → `success` |
| Higiene | `permissions: contents: read`; 0 `secrets.*`/`environment:`/`db push`/`on:schedule` (matches de `production-db` são comentários de escopo-negativo) |

### Impacto
- **Escopo/tese/non-negotiables:** inalterados. Só código da zona generativa **blindada** (Entity Resolution — **IA não gera número**) + um job de teste read-only. Stack inalterada (stdlib-only, `dependencies=[]`).
- **Non-negotiables reforçados:** **reprodutibilidade** (determinismo provado em CI, não machine-bound — base do P5-REPRO-01) e **supply chain** (SHA-pin). **Zero** número/Score/banco/auth/secret tocado.

### Reversibilidade
Alta. Reverter = `git revert` dos PRs #8/#9 — nada destrutivo, nenhum dado, nenhuma migration. O resolver é zona generativa sem número; o workflow é read-only.

### Sequenciamento (próximo)
1. **`delegate_task` → `data_agent` (`define_channel_filter`)** — **Channel Filter** design-only: `channel_eligibility` + `rule_version`, canais distintos, elegibilidade determinística e versionada. **Sem apply, sem secret, sem DB** nesta etapa.
2. Em sequência: **Popularity Scoring** (`rubric_version` + `rubric_hash`, determinístico) → **Opportunity** (ranking/HOT/Competition/Example por código) → **P5-REPRO-01** (gate fail-closed do `data-engine` antes do 1º publish — 2 rodadas canônicas idênticas).
3. **Apply** do schema `channel_eligibility` só via **pipeline gated + aprovação humana** (precedente `entity-db-apply.yml`, DEC-0015) — **não** nesta etapa de design.
4. **Sob veto/parked, não sequenciar:** Fase 9 (RLS Policies + VIEW pública); `producer_events`/`0007`.
