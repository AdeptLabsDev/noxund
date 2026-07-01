# Handoff — task_entity_resolution_realign_and_resume · Entity Resolution pós-apply

## 1. Identificação

- **Tarefa:** `task_entity_resolution_realign_and_resume`
- **Owner:** Data/AI Pipeline Agent (`data_agent`)
- **Ação:** `define_entity_resolution` · **Prioridade:** high
- **Data:** 2026-06-29
- **Resultado:** spec re-alinhada ao schema vivo e núcleo do resolver retomado localmente
- **Evidência de schema:** DEC-0015 · run `28343949123` · commit `9a1ac52`
- **Natureza:** código/spec sem conexão, LLM real, secret, DDL/DML ou número gerado

## 2. Resultado

`DATA-ENTITY-001` agora trata `entity_resolution_candidates` como schema **aplicado**, não como
gate futuro. O serviço Python deixou de ser placeholder puro: há normalização/regex-first,
guardrail, fallback LLM por porta estrita, replay-before-LLM, writer da fila e adaptador de fatos
append-only. A implementação é inerte até receber catálogo, conexão e adapter LLM do runner.

## 3. Alinhamento com o schema aplicado

| Garantia viva | Consumo pelo resolver |
|---|---|
| enum `pending/approved/rejected` | writer automatizado só emite `pending` |
| FK composta `(run_id,video_id) → raw` RESTRICT | insert usa a chave natural; banco rejeita raw ausente/outro run |
| FK `artist_id → artists` nullable | candidato LLM entra com `artist_id = NULL`; nenhuma canônica provisória |
| 4 CHECK, incl. F01 | versões validadas no código e novamente pelo banco |
| unique parcial do pending | lookup antes do LLM + `ON CONFLICT … WHERE status='pending'` |
| fila mutável, 0 trigger | fila é WIP; replay final nunca depende dela |
| RLS-on + revoke, 0 policy | conexão futura deve ser server-side; nenhuma exposição foi criada |

## 4. Implementação retomada

### `entity_resolution.py`

- `normalize_for_match`: NFKC → casefold → pontuação/símbolo/separador como espaço → collapse;
- tokens contíguos completos como guardrail único de regex, LLM e replay;
- regex `<artist> type beat`, delimitadores, múltiplos artistas, metadata e colisão de alias;
- JSON LLM exato `{"candidate": string|null}`; campo extra/número/texto livre falha fechado;
- consulta fato final e pending antes do LLM; replay marca zero nova chamada;
- candidato LLM válido vira `PendingCandidate` com prompt/resolver versionados e revisão obrigatória;
- saída inválida/null/falha do adapter vira fato rejeitado durável para não rechamar em replay.

### `postgres_entity_resolution.py`

- porta DB-API sem dependência de driver e sem `commit` implícito;
- SQL parametrizado; insert explicita `artist_id=NULL`, `status='pending'`, `review_notes=NULL`;
- dedup por `ON CONFLICT (run_id,video_id) WHERE status='pending' DO NOTHING` + releitura;
- `audit_events.after_json` por allow-list natural (`run_id+video_id+resolver_version`);
- exceções externas são sanitizadas; título/candidato/notas/diagnóstico não são logados.

## 5. Security/write-layer

Contrato SEC-0017 incorporado no código:

1. writer automatizado rejeita qualquer `review_notes` e qualquer `artist_id` no pending LLM;
2. payload de auditoria não aceita request context e não carrega título/review notes;
3. módulo não emite logs; erros de driver são substituídos por códigos/mensagens estáveis;
4. teste canary mantém secret do adapter fora de candidate, bind, erro e log.

## 6. Validação

- Testes stdlib `unittest` autorados para regex/guardrail, LLM estrito, replay/dedup, F01,
  canary, SQL parametrizado, erro sanitizado e payload natural de auditoria.
- Checagens estáticas locais confirmam arquivos, imports relativos, SQL allow-listed e ausência
  de dependências/secret/Score no writer.
- **Limite do ambiente:** o executável disponível é apenas o alias Windows Store; não há runtime
  Python 3.11 real. Portanto a suíte não foi executada nesta sessão e não será declarada verde.
  O primeiro gate do runner é executar:

```powershell
$env:PYTHONPATH = "src"
python -m unittest discover -s tests -v
```

Nenhuma instalação foi tentada: instalar runtime/dependência está fora desta ação não-sensível.

## 7. Sequenciamento e gates

1. **Resolver integration:** Python 3.11 + testes verdes → injetar catálogo/conexão/LLM
   server-side → rodar canary → fixture local; nenhuma execução real antes desses gates.
2. **Channel Filter:** só recebe mappings finais (`needs_review=false`); pending/rejected não entra.
3. **Scoring/Opportunity:** só código determinístico, com `rubric_version` + `rubric_hash`; fatos
   LLM/humanos consumidos congelam em `metrics_detail_json.overrides[]`.
4. **P5-REPRO-01:** duas rodadas canônicas sobre mesmos raw/versions/fatos, byte-idênticas nos
   campos de negócio/evidência e mock LLM com zero chamadas; falha bloqueia 1º publish.

## 8. Não-negociáveis e guardrails

- IA gera somente nome candidato; zero Score/Velocity/Signals/Competition/ranking/Example.
- raw é somente leitura e recoleta exige novo `run_id`; computed segue reconstruível.
- decisão/override autoritativo vive em `audit_events` e congela em `overrides[]`, não na fila.
- `0007/producer_events` continua parked; Fase 9, marketplace e Fase 2 continuam fora.

## 9. Arquivos

- `docs/data/DATA-ENTITY-001-entity-resolution-spec.md` — modificado, estado pós-apply + sequência.
- `docs/data/HANDOFF-task_dataengine_define_entity_resolution.md` — marcado como histórico.
- `services/data-engine/src/noxund_data_engine/entity_resolution.py` — criado, núcleo do resolver.
- `services/data-engine/src/noxund_data_engine/postgres_entity_resolution.py` — criado, write/replay.
- `services/data-engine/tests/test_entity_resolution.py` — criado, suíte stdlib.
- `services/data-engine/{README.md,pyproject.toml}` e package `__init__.py` — atualizados.

## 10. Próxima recomendação

Antes de integrar Channel Filter, QA/runner deve executar a suíte em Python 3.11 e validar a
fixture do resolver. O schema `0006` já está vivo; esta tarefa não executou nem reverteu migration.
