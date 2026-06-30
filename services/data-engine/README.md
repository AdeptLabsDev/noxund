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

## Rodar testes

No diretório `services/data-engine`:

```powershell
$env:PYTHONPATH = "src"
python -m unittest discover -s tests -v
```

O ambiente atual precisa oferecer Python 3.11+. Não instalar dependências para esta etapa.

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
