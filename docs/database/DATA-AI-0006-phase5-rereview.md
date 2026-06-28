# DATA-AI-0006 - Data/AI Re-review - Fase 5

- **Revisor:** Data/AI Pipeline Agent (veto metodologico; matrix #4/#5)
- **Tarefa:** `task_phase5_validate_reproducibility_rereview`
- **Action:** `validate_reproducibility`
- **Data:** 2026-06-27
- **Anterior:** `DATA-AI-0005` - veto por `DATA-F5-01..07`
- **Natureza:** re-review pre-apply. Nenhum DDL aplicado/modificado e nenhum numero gerado.

## 0. Veredito

**RE-VETO Data/AI pre-apply (`needs_review`). Matrix #4/#5 continua aberta.**

As correcoes fecharam a coerencia declarativa `report -> item -> metric`, normalizaram a
proveniencia ate raw, alinharam OD-DB-06 e preservaram storage-only. Tres garantias ainda nao
estao fechadas:

1. `artist_metric_videos_published_guard` permite mover input de metric nao-publicada para uma
   publicada em UPDATE;
2. os fixtures chamados de completos usam `{}`, provando NOT NULL, nao OD-DB-07;
3. nao existe teste executavel de duas rodadas canonicas: o data-engine segue placeholder.

Os itens 1 e 2 reabrem F5-03/F5-05; sem evidencia que preserve versoes/overrides, F5-06 fica
apenas parcialmente fechado.

## 1. Resultado item a item

| Achado | Resultado | Evidencia / limite |
|---|---|---|
| **F5-01** freeze report/items | **DDL fechado; verify parcial** | Guards validam OLD/NEW. Postgres prova INSERT e move; service-role prova INSERT, mas nao repete o move pedido. |
| **F5-02** coerencia report/item/metric | **Fechado** | Rubric no report + FKs compostas; caso coerente e mismatches de run/artista/rubric cobertos. |
| **F5-03** linhagem publicada inviolavel | **Reaberto** | Junction usa `coalesce(OLD.artist_metric_id, NEW.artist_metric_id)`; em UPDATE, OLD vence e destino publicado nao e checado. |
| **F5-04** FK ate raw | **Fechado para referencia; condicionado a F5-03 para freeze** | Junction e Example rejeitam ausente/outro-run; conjunto publicado ainda pode mudar pelo bypass. |
| **F5-05** evidencia suficiente | **Reaberto** | NOT NULL existe, mas `{}` e aceito como fixture completo. |
| **F5-06** entrada completa do rebuild | **Parcial** | Versoes sao NOT NULL no working set, mas nao sao preservadas/enforcadas na metric publicada; JSON vazio passa. |
| **F5-07** FK nomeada/no global freeze | **Fechado** | Nome, colunas, alvo e RESTRICT verificados; metric nao-publicada permanece mutavel. |

## 2. Correcoes exigidas

### DATA-RR-F5-03A - UPDATE da junction contorna o freeze (critico)

No UPDATE, `coalesce(old.artist_metric_id, new.artist_metric_id)` escolhe sempre OLD. Trocar o
owner de um input de metric nao-publicada para metric publicada do mesmo run pode passar guard,
PK e FKs.

**Exigido:** validar OLD e NEW separadamente no UPDATE; INSERT valida NEW e DELETE valida OLD.
Adicionar probe que move input distinto para metric publicada e espera `restrict_violation` como
postgres, repetindo no caminho service-role com paridade de errcode.

### DATA-RR-F5-05A - `{}` nao e auditoria suficiente (alto)

Os positivos F5-05 gravam `{}` nos dois JSONs. Isso nao contem componentes/pesos/normalizacao,
videos aceitos/rejeitados, velocity, Competition, top-3/Example, versoes nem overrides exigidos.

**Exigido:** definir/testar o shape minimo Data/AI. Sem calcular numero no DDL, o publish deve
rejeitar `{}`/secoes ausentes e aceitar fixture realmente completo; a evidencia congelada deve
permanecer identica apos publish.

### DATA-RR-F5-06A - versoes nao chegam obrigatoriamente a metric publicada (alto)

`resolver_version`/`rule_version` vivem em tabelas mutaveis nao ligadas a `artist_metrics`. O JSON
deveria preservar as versoes/overrides efetivos, mas hoje pode ser `{}`.

**Exigido:** o contrato F5-05 deve carregar essas versoes e decisoes replayable. `audit_events`
por UUID polimorfico nao garante sozinho a chave natural `(run_id, video_id)` ou
`(run_id, channel_id)`; payload/teste de replay precisa preserva-la.

### DATA-RR-F5-01A - completar segundo role-path (medio)

Repetir no caminho service-role o probe de mover `report_items` draft -> published.

## 3. Prova canonica - precondicao registrada

**Nao executada:** `services/data-engine` declara status placeholder; nao ha pipeline, fixtures ou
teste de reproducibilidade. O SQL verify testa constraints, nao os seis agentes.

Precondicao **P5-REPRO-01**, bloqueante antes da liberacao final do pipeline/primeiro publish:

1. executar duas vezes sobre mesmo raw, rubric, resolver/rule versions e decisoes replayable;
2. ordenar projecao canonica por report/rank/artista;
3. comparar byte-a-byte campos de negocio/evidencias, excluindo UUIDs/timestamps operacionais;
4. falhar em qualquer divergencia de valor, ordem ou evidencia.

Para ser executavel, o repo precisa conter teste, fixture e comando fail-closed no CI. Inserts SQL
hardcoded nao substituem a prova do data-engine.

## 4. Nao-regressoes confirmadas

- storage-only: zero formula/generated/CHECK de faixa; unico CHECK e status/published_at;
- `unique(run_id, artist_id, rubric_hash)` preservado;
- metrics/reports referenciam `rubric_versions` por par composto RESTRICT;
- zero `CREATE POLICY` executavel; Fase 9 segue vetada;
- mappings/eligibility sem trigger; metric tem somente guard condicional;
- FKs ate raw usam RESTRICT; rollback inclui novos objetos;
- IA continua restrita a Entity Resolution e nao gera numero.

Nota nao-bloqueante: `report_items.artist_id` tem FK inline e FK nomeada equivalente; por isso o
handoff declara 16 FKs enquanto o DDL cria 17. Remover duplicata ou corrigir a contagem.

## 5. Sequencia de gates

- **Data/AI #4/#5:** bloqueado por DATA-RR-F5-03A/05A/06A; completar 01A no verify.
- **Proximo:** `database_agent:design_schema`, sem apply; depois novo Data/AI.
- Se aprovado: `security_agent:review_rls` -> Backend -> `run_migration` gated por ultimo.
- Fase 9 continua vetada.

Nenhum artefato corrigido foi modificado. Este arquivo e o unico criado por Data/AI.
