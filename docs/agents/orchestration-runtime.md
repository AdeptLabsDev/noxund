# Orchestration Runtime — NOXUND

**Status:** implementado (fundação executável)
**Pacote:** [`packages/orchestrator`](../../packages/orchestrator) · `@noxund/orchestrator`
**Relação:** este é o **contraparte executável** dos contratos em `docs/agents/`.

---

## O que mudou

Antes, o **Product Orchestrator** tomava decisões e as escrevia como **texto livre no
terminal**; um humano lia e encaminhava manualmente para o agente seguinte. O terminal era o
centro operacional.

Agora existe um **control plane real**: o Orchestrator emite uma **decisão estruturada (JSON)**,
um **validador** confirma que ela é válida e segura, um **dispatcher** roteia automaticamente
para o agente registrado correto, o agente devolve um **resultado padronizado**, e o **estado
central do projeto** é atualizado. O terminal passa a ser apenas **camada de log/observação**
(JSONL).

> Os documentos desta pasta continuam sendo a **fonte de verdade de governança** (quem é cada
> agente, o que possui, que revisões dispara). O runtime apenas **executa** essa governança.

---

## Fluxo

```txt
Product Orchestrator → Structured Decision → Decision Validator → Task Dispatcher
   → Agent Registry → Specialized Agent → AgentResult → Project State Update → Product Orchestrator
```

| Etapa | Módulo | Responsabilidade |
|---|---|---|
| Decisão estruturada | `core/decision-schema.ts` | `delegate_task` / `request_human_approval` / `escalate` / `no_action`. |
| Validação | `core/decision-validator.ts` | JSON válido? agente existe? ação permitida? payload mínimo? exige aprovação humana? destrutivo? |
| Roteamento + gate | `core/dispatcher.ts` | Roteia para o agente; **bloqueia execução de tarefa sensível sem aprovação**. Não toma decisão de produto. |
| Registro | `core/agent-registry.ts` | Allow-list: impede chamada a agente inexistente ou ação não permitida. |
| Execução | `agents/*.ts` | Cada agente executa a ação e devolve `AgentResult`. |
| Estado | `core/project-state.ts` | `completed/pending/blocked`, decisões, artefatos, últimos resultados (persistido em JSON). |
| Logs | `core/logger.ts` | JSONL por evento: decisão, validação, dispatch, resultado, bloqueio, aprovação. |
| Autoridade | `core/orchestrator.ts` | Roda o pipeline e mantém o estado. Continua sendo o centro. |

---

## Mapeamento agentes ↔ runtime

Os 10 agentes de `agent-registry.md` existem como executores registrados (ids `snake_case`):

| Contrato (doc) | Id no runtime |
|---|---|
| Product Orchestrator | `product_agent` |
| Database | `database_agent` |
| Backend / Next API | `backend_agent` |
| Frontend | `frontend_agent` |
| Data / AI Pipeline | `data_agent` |
| Security & Privacy | `security_agent` |
| QA | `qa_agent` |
| DevOps / Infra | `devops_agent` |
| Marketing / GTM | `marketing_agent` |
| Documentation | `documentation_agent` |

Cada agente declara um conjunto **fechado** de ações (`allowedActions`). O validador e o
dispatcher recusam qualquer ação fora desse conjunto.

---

## Aprovação humana (segurança)

Coerente com `global-agent-rules.md`, o runtime **nunca executa automaticamente** operações
sensíveis. Exigem aprovação humana explícita: deletar arquivos, alterar `.env`, instalar
dependências, alterar schema de banco, rodar migrations, push para GitHub, deploy, remover
pastas, sobrescrever arquivos, alterar arquitetura central e comandos shell perigosos — além de
qualquer payload com padrão destrutivo (`rm -rf`, `DROP`, `--force`, etc.). Sem aprovação, o
resultado é `needs_review` com o resumo *"Esta tarefa exige aprovação humana antes da execução."*

---

## Escopo e honestidade

Os executores são **de fundação**: validam a ação, produzem um plano/handoff estruturado e
devolvem um `AgentResult` bem-formado — **sem** fazer trabalho de produto real ainda (não
escrevem schema, **não geram número**). Isso preserva dois não-negociáveis: *IA generativa nunca
gera número* e *mínimo necessário*. Os executores reais entram depois, agente por agente, **atrás
deste mesmo contrato** — o loop não muda quando um agente passa de "planejar" para "fazer".

---

## Como rodar

```bash
pnpm --filter @noxund/orchestrator demo        # demonstração end-to-end
pnpm --filter @noxund/orchestrator test        # suíte node:test
pnpm --filter @noxund/orchestrator typecheck   # tsc --noEmit
```

Detalhes, API e exemplos: [`packages/orchestrator/README.md`](../../packages/orchestrator/README.md).
