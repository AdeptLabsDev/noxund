# NOXUND Agent Registry

## Purpose

Ponto único de entrada para a camada de agentes da NOXUND: quem existe, o que cada um possui, quais revisões dispara, em que ordem devem executar e como conflitos/handoffs fluem. É um **mapa**, não a fonte das regras — estas vivem em `global-agent-rules.md`, `agent-boundaries.md`, `agent-review-matrix.md` e `agent-conflict-resolution.md`, e o contrato detalhado de cada agente no seu próprio arquivo.

Escopo travado: MVP **NOXUND Hotspot Artists Report** (não marketplace, vertical Chicago Drill, números determinísticos). Ver `docs/product/scope-guardrails.md`.

## Agent List

| Agent | Owns | Does not own | Required reviews (dispara) | Status |
|---|---|---|---|---|
| **Product Orchestrator** (`product-orchestrator-agent.md`) | Backlog, prioridade, decision log, aprovação/rejeição, escalation | Implementação de features; calcular número | É o aprovador; aciona PO em escopo/posicionamento | Ativo |
| **Database** (`database-agent.md`) | Schema, migrations, raw/computed, report snapshots, rubric versioning, RLS (com Security) | Endpoints, Score, UI, auth policy | Security + Data/AI (migrations, raw/computed, RLS) | Contrato |
| **Backend/Next API** (`backend-agent.md`) | Route Handlers, Server Actions, eventos, approval gate, follow-up trigger | Schema, Score, auth/RLS policy, UI | Security (auth/API/rotas), Database (schema/eventos) | Contrato |
| **Frontend** (`frontend-agent.md`) | UI, tabela do relatório, responsividade, a11y, estados, toggle honesto | Copy/promessa, metodologia, thresholds, dados | PO + Marketing (copy), QA (fluxos críticos) | Contrato |
| **Data/AI Pipeline** (`data-ai-pipeline-agent.md`) | Python engine, coleta, raw/computed, scoring determinístico, Entity Resolution, reprodutibilidade | Schema, endpoints/UI, secrets policy | PO + Data/AI + QA (Score/rubric); Data/AI (coleta/raw) | Contrato |
| **Security & Privacy** (`security-privacy-agent.md`) | Auth, roles, RLS, secrets, endpoints, logs, privacidade | Escopo, metodologia, features | É revisor; **pode bloquear** por risco de segurança | Contrato |
| **QA** (`qa-agent.md`) | Critérios de aceite, fluxos críticos, testes UI/API/regressão/reprodutibilidade, métricas | Escopo, schema, metodologia, features | É revisor; **pode bloquear** por falha de critério | Contrato |
| **DevOps/Infra** (`devops-infra-agent.md`) | Ambientes, build, deploy, env, cron, observabilidade, branch protection | Stack, features, schema, secrets policy | **Security antes de qualquer deploy** (DevOps + Security) | Contrato |
| **Marketing/GTM** (`marketing-gtm-agent.md`) | Convite, aplicação, seleção manual, follow-up/WTP (mensagens), conteúdo agregado | Promessa/posicionamento central, abertura pública, eventos/UI | **PO** ao mexer em promessa/posicionamento/copy pública | Contrato |
| **Documentation** (`documentation-agent.md`) | README, changelog, decision log, handoffs, índice, glossário, rastreabilidade | Conteúdo de decisões, escopo, código | **PO** quando o doc registra/altera decisão | Contrato |

## Recommended Execution Order

1. **Database Agent**
2. **Backend/Next API Agent**
3. **Frontend Agent**
4. **Data/AI Pipeline Agent**
5. **Security & Privacy Agent**
6. **QA Agent**
7. **DevOps/Infra Agent**
8. **Marketing/GTM Agent**
9. **Documentation Agent**

**Por que Database antes de Backend:** o MVP é, antes de tudo, uma promessa de **auditabilidade e credibilidade**. Backend, eventos, approval gate e follow-up só fazem sentido sobre um modelo que já garante **raw imutável**, **computed reconstruível**, **report snapshots congelados**, **producer outcomes** e **rubric versionado**. Definir o schema primeiro fixa os contratos de dados (eventos, auditoria) que o Backend apenas consome — evitando endpoints que depois precisem ser refeitos por mudança de schema. Security, QA e DevOps são predominantemente **transversais/revisores** e por isso vêm após a base executável; Marketing e Documentation fecham o ciclo (validação e rastreabilidade).

> Ordem é recomendação de sequência de **fundação**, não exclusividade: Security, QA e Data/AI atuam em paralelo como revisores assim que há o que revisar.

## Escalation Rules

Regras completas em `agent-conflict-resolution.md`. Resumo:

- **Product Orchestrator** decide conflitos de escopo e posicionamento.
- **Security** pode **bloquear** por risco de segurança (veto até mitigação).
- **Data/AI** pode **bloquear** por risco metodológico (determinismo/auditoria/reprodutibilidade).
- **QA** pode **bloquear** por falha de critério de aceite.
- Backend/Frontend/DevOps **não** passam por cima de Security.
- Marketing **não** altera promessa do produto sozinho.
- Conflito não resolvido → **`OPEN DECISION`** + Product Lead.

## Handoff Rules

- Toda entrega relevante usa `docs/agents/handoff-template.md`. Sem handoff, a tarefa **não está concluída**.
- O handoff lista: critério de aceite atendido, arquivos alterados, impacto no escopo, riscos, **revisões acionadas** e próximos passos.
- Revisões exigidas (ver `agent-review-matrix.md`) precisam estar ✅ aprovadas (ou bloqueio ⛔ resolvido) antes do "aprovado" do PO. Revisão ⏳ pendente nunca é assumida como ok.
- O PO responde cada handoff com **aprovar / rejeitar / pedir ajuste** e registra decisões via `docs/product/decision-log-template.md`.

## Agent Status

| Agent | Contrato | Executor implementado |
|---|---|---|
| Product Orchestrator | ✅ | ✅ (este agente) |
| Database | ✅ | ⛔ ainda não |
| Backend/Next API | ✅ | ⛔ ainda não |
| Frontend | ✅ | ⛔ ainda não |
| Data/AI Pipeline | ✅ | ⛔ ainda não |
| Security & Privacy | ✅ | ⛔ ainda não |
| QA | ✅ | ⛔ ainda não |
| DevOps/Infra | ✅ | ⛔ ainda não |
| Marketing/GTM | ✅ | ⛔ ainda não |
| Documentation | ✅ | ⛔ ainda não |

Status atual do projeto: **Sprint 0** — governança + fundação técnica. Nenhum executor de produto ativo ainda.

> **Orchestration runtime (implementado).** A camada de **delegação automática** já existe em
> código: `packages/orchestrator` (`@noxund/orchestrator`). Ela transforma decisões do
> Orchestrator em comandos estruturados, valida, roteia ao agente registrado, captura o
> resultado padronizado, atualiza o estado central e registra logs JSONL — com gate de aprovação
> humana para operações sensíveis. Os 10 agentes acima estão **registrados como executores de
> fundação** (validam a ação e devolvem plano/handoff; ainda **não** fazem trabalho de produto
> nem geram número). Ver [`orchestration-runtime.md`](./orchestration-runtime.md). A coluna
> "Executor implementado" continua ⛔ porque se refere ao **executor de produto real**, não ao
> runtime de orquestração.
