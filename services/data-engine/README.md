# services/data-engine — NOXUND Data/AI Pipeline (Python)

**Status:** Entity Resolution core retomado (`entity-resolver-v1`); integrações externas ainda
não executadas. **Owner:** Data/AI Pipeline Agent.

Este serviço não é um workspace pnpm. O núcleo atual usa apenas Python 3.11+ e a biblioteca
padrão: nenhuma SDK de LLM, driver de banco, ML, Celery ou Redis foi adicionada.

## Implementado agora

- normalização determinística NFKC/casefold/tokenização e guardrail de span contíguo;
- regex-first para `<artist> type beat`, flags de ambiguidade e lookup canônico por porta;
- fallback LLM estrito (`{"candidate": string|null}`), sem confidence ou qualquer número;
- replay obrigatório antes do LLM: fato final em `audit_events`, depois pendente atual;
- fila `entity_resolution_candidates` com dedup do pending, versões non-blank, `artist_id NULL`
  e `review_notes NULL` no writer automatizado;
- adaptadores PostgreSQL sem dependência de driver: SQL parametrizado, payload de auditoria por
  allow-list e erros sanitizados. A transação/conexão é injetada pelo chamador;
- testes unitários do resolver, replay, dedup, guardrails, F01 e canary SEC-F10/SEC-0016.

Nenhuma conexão, chamada LLM ou escrita real ocorre ao importar ou testar o pacote; testes usam
doubles em memória.

## Qualidade — o comando canônico

De qualquer diretório, em qualquer sistema operacional:

```bash
python services/data-engine/run_quality_checks.py
```

Esse é **o entrypoint canônico de qualidade deste serviço**, e é exatamente o
que o CI executa — `.github/workflows/data-engine-tests.yml` invoca esse mesmo
arquivo versionado e **não guarda uma segunda cópia das asserções**. Não é
preciso definir `PYTHONPATH`, nem saber o separador de caminho do sistema, nem
fazer `cd`: o entrypoint monta o próprio caminho de importação a partir da
localização dele. Ele também não deixa `__pycache__` para trás.

Três limbs, executáveis isoladamente — `suite`, `repro`, `digest`:

```bash
python services/data-engine/run_quality_checks.py suite    # suíte unitária, ×2
python services/data-engine/run_quality_checks.py repro    # harness P5-REPRO-01, ×2
python services/data-engine/run_quality_checks.py digest   # golden digest
```

**O que ele cobre e o que ele NÃO cobre está declarado no docstring do próprio
arquivo** (`DEC-0042` §D10) — em resumo: sem lint, sem type check, sem testes de
integração, sem banco, sem rede, e **sem o contrato do driver de coleta**, que
permanece só no CI porque exige `pip install` com hash-pin e alteraria o
ambiente local. Essa exceção é aceita e documentada, não escondida.

Requisito: Python 3.11+ na biblioteca padrão. **Não instalar dependências para
esta etapa** — o núcleo declara `dependencies = []` de propósito.

## Sequência pipeline-first

1. Entity Resolution — núcleo atual; próxima integração liga catálogo/conexão/adapter LLM reais.
2. Channel Filter — grava `channel_eligibility` com `rule_version`.
3. Popularity Scoring + Opportunity — código determinístico, `rubric_version` + `rubric_hash`.
4. P5-REPRO-01 — duas rodadas canônicas e zero chamada LLM no replay; gate antes do 1º publish.

`producer_events` (`0007`) continua parked. Fase 9 (policies/VIEW pública) continua vetada.

## Restrições inegociáveis

- IA nunca gera Score, Velocity, Signals, Competition, ranking ou Example.
- Raw é imutável; recoleta significa novo `run_id`.
- Computed é reconstruível e versionado por rubric.
- Candidato não-aprovado fica fora de `artists` e `video_artist_mappings`.
- Decisão/override vive em `audit_events` e congela em
  `artist_metrics.metrics_detail_json.overrides[]`, nunca na fila mutável.
- Secrets/PII nunca entram em `review_notes`, binds livres, logs, Sentry ou `AgentResult`.
