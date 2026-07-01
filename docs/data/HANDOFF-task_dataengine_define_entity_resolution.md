# Handoff — task_dataengine_define_entity_resolution · Entity Resolution

> **HISTÓRICO · SUPERADO.** O `needs_review`/`OPEN-DATA-ENTITY-001` abaixo foi resolvido por
> DEC-0014 e aplicado/verificado por DEC-0015. Estado corrente e retomada do resolver:
> `HANDOFF-task_entity_resolution_realign_and_resume.md`.

## 1. Identificação

- **Tarefa:** `task_dataengine_define_entity_resolution`
- **Owner agent:** Data/AI Pipeline (`data_agent`)
- **Ação:** `define_entity_resolution`
- **Data:** 2026-06-28
- **Prioridade:** P0 / high
- **Resultado do agente:** `needs_review`
- **Open decision:** `OPEN-DATA-ENTITY-001`

## 2. Objetivo

Definir a metodologia regex-first da única zona de IA do pipeline, incluindo prompt restrito, guardrail de substring, revisão humana e replay sem reinvocar LLM. Nenhum dado real, número, secret, migration ou chamada de modelo faz parte desta ação.

## 3. Critérios recebidos e veredito

| Critério | Veredito |
|---|---|
| regex-first + LLM só no ambíguo, prompt restrito/versionado | ✅ definido em DATA-ENTITY-001 §§4–5 |
| guardrail formal `nome ∈ normalize(título)` | ✅ definido em §3; vale também para humano |
| baixa confiança → fila / nada entra sem decisão | ✅ política definida: toda saída LLM exige revisão; persistência física da fila está bloqueada pelo schema |
| replay por `(run_id, video_id)` sem rechamar LLM | ✅ contrato definido em §8; armazenamento completo pré-scoring depende de OPEN-DATA-ENTITY-001 |
| `resolver_version + rule_version` e confiança em todo mapping | ⛔ incompatível com o schema live: só `resolver_version` existe no mapping |
| rastreabilidade até raw / nenhum número | ✅ FK live confirmada; nenhum número foi gerado |
| handoff, casos de revisão e Data/AI review | ✅ este documento + §11 da spec |

Não é honesto retornar `completed`: os critérios de persistência tipada não são implementáveis sobre a tabela aplicada sem uma decisão de produto/schema.

## 4. Resultado metodológico

- `entity-resolver-v1` define NFKC, casefold, pontuação/símbolos como espaço e whitespace colapsado.
- Regex autoaceita somente um candidato inequívoco e sustentado por tokens contíguos do título.
- Ambiguidade aciona o prompt `entity-resolver-v1/llm-fallback-v1` com output JSON `candidate|null`.
- Todo candidato LLM válido recebe `needs_review=true`; o LLM não gera confiança numérica.
- Nome fora do título é sempre rejeitado, inclusive em edição humana.
- Aprovação preserva `llm_assisted`; edição usa `human_override`; decisões são auditadas.
- Replay consulta fatos por chave natural antes de qualquer LLM; P5 deve comprovar zero chamadas.
- Fatos LLM/humanos consumidos no scoring são congelados em `metrics_detail_json.overrides[]` com `run_id + video_id`.

## 5. Arquivos alterados

- `docs/data/DATA-ENTITY-001-entity-resolution-spec.md` — criado: metodologia, prompt, guardrails, replay, testes e open decision.
- `docs/data/HANDOFF-task_dataengine_define_entity_resolution.md` — criado: handoff e veredito `needs_review`.

Nenhum arquivo de schema, migration, serviço ou configuração foi alterado.

## 6. Impacto no escopo

- **Mantém o MVP travado:** sim; IA permanece exclusiva da Entity Resolution.
- **Número via IA:** nenhum; confiança numérica foi explicitamente proibida.
- **Raw:** somente leitura por chave natural; nenhuma mutação.
- **Computed:** contrato de mapping definido sem fingir colunas inexistentes.
- **Fase 2:** nenhuma feature adicionada.

## 7. Validação executada

- Conferência com `03_Data_AI_Agents_Methodology.md` §5 e arquitetura Agente 3.
- Conferência com o Épico 5: regex-first, guardrail e `needs_review` preservados.
- Conferência com `DATA-COLLECT-001`: Entity Resolution só recebe runs completas e raw imutável.
- Conferência com a migration live Fase 5: enum, FK raw, unique `(run_id, video_id)`, `artist_id NOT NULL` e colunas reais.
- Conferência com DATA-AI-0007/F5-06A: versões e overrides naturais precisam chegar a `metrics_detail_json`.
- Casos de validação futuros enumerados em DATA-ENTITY-001 §11.

Não foram executados testes de regex, LLM, banco ou P5 porque o serviço continua placeholder e esta tarefa é define-only.

## 8. Riscos e bloqueio

- `confidence`, `rule_version` e evidence JSON não existem em `video_artist_mappings`.
- `rule_version` live pertence ao Channel Filter, não ao Entity Resolver.
- `artist_id NOT NULL` impede fila durável limpa para candidato novo/rejeitado sem artista provisório.
- `audit_events` por UUID não substitui sozinho fatos replayable por chave natural.
- Usar `review_notes` como JSON oculto criaria contrato sem constraint e foi proibido.

**Bloqueio:** Entity Resolution real e P5-REPRO-01 não devem iniciar até `OPEN-DATA-ENTITY-001` ser decidido.

## 9. Revisões necessárias

- [x] **Data/AI** — metodologia, anti-alucinação e replay definidos.
- [ ] **Product Orchestrator** — decidir `OPEN-DATA-ENTITY-001`.
- [ ] **Database + Security + Data/AI** — somente se a decisão autorizar delta de schema.
- [ ] **QA / P5-REPRO-01** — após implementação, com duas rodadas e zero chamadas LLM no replay.

Silêncio de revisor não equivale a aprovação.

## 10. Próximos passos

1. Product Orchestrator registrar decisão sobre compatibilizar critérios ou delegar extensão aditiva ao Database Agent.
2. Se critérios forem alinhados ao schema, atualizar esta spec com o local durável da fila/fatos pré-scoring.
3. Se houver delta, seguir migration gated e todas as revisões; esta tarefa não o executa.
4. Somente depois implementar resolver e fixtures; então seguir Channel Filter → scoring → P5-REPRO-01.

## 11. Open decisions / bloqueios

### OPEN-DATA-ENTITY-001

**Conflito:** o payload requer `confidence`, `rule_version`, evidence/override e fila durável por mapping, mas o schema live não oferece esses campos/estado e exige `artist_id NOT NULL`.

**Opções para o decisor:**

1. alinhar os critérios ao schema e definir formalmente onde fila/fatos pré-scoring persistem; ou
2. delegar proposta de extensão ao Database Agent, com migration e revisões gated.

**Owner da decisão:** Product Orchestrator / Product Lead. Até decisão registrada, status desta tarefa permanece `needs_review`.
