# Handoff — `task_data_engine_ci_test_pipeline` · DevOps Agent

## 1. Identificação
- **Tarefa:** `task_data_engine_ci_test_pipeline` · **Action:** `define_pipeline` (não-sensível)
- **Owner agent:** DevOps / Infra (`devops_agent`)
- **Data:** 2026-06-29
- **Prioridade:** P1 (high)
- **Escopo:** CI test job da `services/data-engine` — 18 testes do resolver, Python 3.11 PINADO, reproduzível (ancora a semente determinística do P5-REPRO-01). Resolve o carry-forward #1 da QA (verde preso a uma workstation).

## 2. Objetivo
Autorar `.github/workflows/data-engine-tests.yml` — job **read-only** que torna o `18/18` reproduzível
FORA da workstation da QA, sob **Python 3.11 pinado**, **stdlib-only**, **sem secret / sem Environment /
sem DB**. **Não** é manual-only (desvio intencional do template de apply gated, correto para teste sem
produção). **Não** aplica migration, **não** toca `production-db`, **não** destrava a Fase 9; 0007 PARKED.

## 3. Critério de aceite (do payload)
1. Rodar os 18 testes sob Python 3.11 PINADO (setup-python SHA-pinned + `python-version '3.11'`), stdlib-only, a partir de `services/data-engine` com o comando exato da QA.
2. Gatilhos: `push` + `pull_request` em `services/data-engine/**` + `workflow_dispatch`; read-only (`contents: read`), ZERO secret, sem Environment, sem DB.
3. Determinismo: executar a suíte **≥2×** e **falhar** se qualquer execução não for 18/18.
4. NÃO aplicar migration, NÃO tocar `production-db`, NÃO destravar Fase 9; 0007 PARKED.
5. Higiene: actions SHA-pinadas, sem valor de secret, sem `on:schedule`; preparar landing em `main` via PR revisado.

## 4. Resultado
- [x] **Critério 1 — 18 testes, Python 3.11 pinado, comando exato da QA.** `actions/setup-python` SHA-pinada (`0b93645…` v5.3.0) com `python-version: '3.11'`; step extra asserta que o interpretador é **CPython 3.11.x** (fail-closed). Comando: `python -m unittest discover -s tests -p test_entity_resolution.py -v`, com `working-directory: services/data-engine` + `env: PYTHONPATH: src`. **stdlib-only** — `pyproject dependencies=[]` ⇒ **zero** `pip install`. **Verificado na fonte:** o arquivo de teste tem exatamente **18** métodos `def test_` → a asserção `Ran 18 tests` é exata.
- [x] **Critério 2 — gatilhos + read-only.** `on: push` + `pull_request` com `paths: services/data-engine/** ` (+ o próprio arquivo do workflow) + `workflow_dispatch`. `permissions: contents: read` (sem `write` em nenhum escopo). **Zero** `secrets.*`, **zero** `environment:`, **zero** acesso a DB. As chaves do `.env.example` (`YOUTUBE_API_KEY`/`DATABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY`/`ANTHROPIC_API_KEY`) **não** são referenciadas — a suíte usa doubles em memória (README §"Nenhuma conexão … ocorre ao testar").
- [x] **Critério 3 — determinismo ≥2×.** Loop roda a suíte **2× em processos independentes**; cada execução exige `^Ran 18 tests in ` **E** saída OK (exit 0). **Fail-closed no count:** uma regressão de discovery que rodasse 0 testes ainda sairia 0 no unittest ("OK") — por isso o job asserta a **contagem** explicitamente e aborta se ≠ 18.
- [x] **Critério 4 — escopo negativo.** Não há `db push`, `production-db`, `environment`, secret, policy ou view no arquivo. 0007/`producer_events` intocado/PARKED; Fase 9 não destravada.
- [x] **Critério 5 — higiene + landing.** Ver §7 (higiene) e §10/§11 (landing/risco). Sem `on:schedule`; 2 SHA-pins; 0 valor de secret.

**Como verificar (higiene + escopo):**
`grep -nE 'uses:.*@(v[0-9]+|main|latest)' .github/workflows/data-engine-tests.yml` → vazio ·
`grep -nE 'schedule:|secrets\.|environment:|production-db|db push' …` → vazio ·
1º run em PR/push: log mostra `attempt 1: 18/18 OK` + `attempt 2: 18/18 OK` + `Determinism proven`.

## 5. Desvio consciente vs. template de apply gated (e por que é correto)
| Dimensão | Apply gated (phase*/entity-db-apply) | Este job (data-engine-tests) |
|---|---|---|
| Gatilho | `workflow_dispatch` only + confirm phrase | `push` + `pull_request` + `workflow_dispatch` |
| Aprovação | Environment `production-db` + required reviewers | **nenhuma** (read-only) |
| Secrets | secrets/vars do Environment | **zero** |
| DB/produção | `supabase db push` no remoto | **nenhum** acesso |
| `cancel-in-progress` | `false` (apply não pode ser cancelado a meio) | **`true`** (nada a corromper; poupa runner) |

Rodar em push/PR é o **desvio intencional e correto** para um teste sem secret/produção. **Por ser
read-only e secret-free, não há gate obrigatório de Security.** Se algum dia o job ganhar
secret/Environment/acesso a DB, isso é mudança de Deploy/ambiente → **Security review (matrix #8)**
ANTES do merge. Esta autoria **não** introduz nada disso.

## 6. Arquivos alterados
- `.github/workflows/data-engine-tests.yml` — **criado**: CI test job read-only do resolver (Python 3.11 pinado, ×2 determinismo).

**Intocados:** todo o código/teste da `services/data-engine` (só executado, nunca modificado); migrations/rollback/verify; 0007 (PARKED).

## 7. Validação executada
- **Estrutural (grep, evidenciado):** **2 SHA-pins** (`actions/checkout@34e1148…` v4.3.1; `actions/setup-python@0b93645…` v5.3.0) / **0** tag mutável / **0** `on:schedule` / **0** `secrets.*` / **0** `environment:` / **0** `production-db` / **0** `db push` / **0** nomes de chave de secret (`*_API_KEY`/`DATABASE_URL`/`SERVICE_ROLE`) / `permissions: contents: read` (sem escalonamento).
- **Contagem de testes:** **18** `def test_` na fonte (`grep -c`) → asserção `Ran 18 tests` correta.
- **Execução real da suíte:** **não executada no sandbox** (Python ausente na workstation do agente — exatamente o motivo deste CI job; carry-forward #1 da QA). O verde será produzido pelo runner no 1º push/PR. A QA já validou `18/18` determinístico em CPython 3.11.9; o job pina 3.11 e prova a reprodutibilidade fora da máquina.

## 8. Impacto no escopo
- **MVP travado?** Sim. Só um job de teste read-only; nada de Fase 2/marketplace; stack inalterada (stdlib-only, sem novas deps).
- **Non-negotiable?** Reforça **reprodutibilidade** (fundação do P5-REPRO-01: determinismo provado em CI, não machine-bound) e **supply chain** (SHA-pin). **Não** toca número/Score (é teste do resolver — zona de IA sem número), **não** toca banco/auth/produção, **não** versiona secret.
- **Toca número/banco/auth/copy pública?** Não.

## 9. Riscos
- **Pin do `setup-python` (verificar no landing):** `actions/setup-python@0b93645e9fea7318ecaed2b359559ac225c90a2b` está rotulado `# v5.3.0`. **Sem rede no sandbox**, não pude resolver o SHA contra o upstream — **DevOps/Security devem confirmar o mapeamento SHA↔tag no PR** (checagem padrão de supply-chain antes do merge). O `actions/checkout` reusa o SHA já verificado em phase1–5 (`34e1148…` v4.3.1). Se preferirem, re-pinar `setup-python` para a tag corrente verificada no momento do landing.
- **Versão patch 3.11.x flutua:** `python-version: '3.11'` resolve o patch mais recente disponível no runner (ex.: 3.11.9→futuro). É o comportamento desejado (segurança), e o determinismo da suíte não depende de patch — o step asserta só `3.11.*`.
- **Discovery silenciosa:** mitigada — a asserção de contagem (`Ran 18 tests`) falha fechado se o pattern/discovery regredir para <18.
- **Landing:** sem push direto na `main` (global rules §7) — PR + revisão.

## 10. Revisões necessárias
- [x] **DevOps** — esta entrega (autor).
- [ ] **Security (matrix #8)** — **NÃO obrigatória neste estado** (read-only, sem secret/Environment/DB). **Gatilho condicional:** torna-se obrigatória se uma iteração futura adicionar secret/Environment/acesso a DB. (Recomendação leve: confirmar o pin do `setup-python` no PR — supply-chain.)

## 11. Próximos passos
1. **Landing em `main` via PR revisado** (sem push direto §7) — como no PR #7. Confirmar o pin do `setup-python` no review.
2. **1º run** em push/PR produz o verde reproduzível (`18/18` ×2) — destrava o uso do job como gate de regressão do resolver.
3. **Data/AI** estende a fundação para o **Channel Filter** (`channel_eligibility` + `rule_version`) → Popularity Scoring → **P5-REPRO-01** (2 rodadas canônicas, gate de publish — fora deste job).
4. `producer_events` (0007) segue PARKED; Fase 9 (policies/VIEW) segue vetada.

## 12. Open decisions / bloqueios
- **Nenhum bloqueio de DevOps.** O job de teste está autorado e endurecido. Único item de atenção:
  **confirmar o SHA do `setup-python` no landing** (não pude resolver offline). Nenhum secret/Environment
  novo; nenhum retorno ao Orchestrator necessário. 0007 PARKED; Fase 9 intacta.

---

### `next_recommendation` (AgentResult)
```json
{
  "status": "completed",
  "next_recommendation": {
    "target_agent": "product_agent",
    "action": "route_landing",
    "priority": "high",
    "reason": "data-engine-tests.yml autorado (read-only, Python 3.11 pinado, stdlib-only, 18/18 x2 determinismo, zero secret/Environment/DB). Nao ha gate de Security obrigatorio neste estado read-only. Proximo passo: rotear o landing em main por PR revisado (sem push direto §7), confirmando no review o pin SHA do setup-python (supply-chain). Apos merge, o 1o push/PR produz o verde reproduzivel que ancora P5-REPRO-01. Nenhuma migration aplicada; 0007 PARKED; Fase 9 nao destravada.",
    "evidence": {
      "file": ".github/workflows/data-engine-tests.yml",
      "hygiene": "2 SHA-pins; 0 tag mutavel; 0 on:schedule; 0 secrets.*; 0 environment; 0 production-db; 0 db push; permissions contents:read",
      "test_contract": "comando exato da QA (unittest discover -p test_entity_resolution.py) sob Python 3.11 pinado; 18 testes (confirmado na fonte) exigidos x2 fail-closed",
      "deviation": "push/PR (nao manual-only) — correto p/ teste read-only sem secret; vira gate de Security (matrix #8) so se ganhar secret/Environment/DB",
      "open_item": "confirmar SHA<->tag do setup-python (v5.3.0) no PR — sem rede no sandbox"
    }
  }
}
```
