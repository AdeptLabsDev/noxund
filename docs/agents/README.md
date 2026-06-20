# NOXUND — Camada de Agentes

Esta pasta define a **camada operacional de agentes** do MVP NOXUND Hotspot Artists Report.

O único agente **implementado** nesta fase é o **Product Orchestrator Agent**. Os demais estão **especificados, mas não criados** — serão instanciados sob demanda, sempre coordenados pelo Orchestrator.

> Princípio: agentes existem para **elevar a qualidade dentro do escopo travado**, nunca para expandir escopo.

---

## Arquivos

### Governança (vinculante para todos)

| Arquivo | Função |
|---|---|
| `agent-registry.md` | Mapa único: lista de agentes, ordem de execução, escalation, handoff, status. |
| `global-agent-rules.md` | Regras inegociáveis que todo agente obedece. |
| `agent-boundaries.md` | Mission/Owns/limites de cada agente. |
| `agent-review-matrix.md` | Qual mudança dispara qual revisão. |
| `agent-conflict-resolution.md` | Como conflitos e vetos são resolvidos. |
| `orchestration-runtime.md` | Contraparte **executável** desta governança: como a delegação roda de fato (`packages/orchestrator`). |

### Agentes

| Arquivo | Função |
|---|---|
| `product-orchestrator-agent.md` | Agente central. Role, authority, escopo, non-negotiables, escalation, output format. |
| `backend-agent.md` | Contrato do Backend Agent. |
| `frontend-agent.md` | Contrato do Frontend Agent. |
| `database-agent.md` | Contrato do Database Agent. |
| `data-ai-pipeline-agent.md` | Contrato do Data/AI Pipeline Agent. |
| `security-privacy-agent.md` | Contrato do Security & Privacy Agent. |
| `qa-agent.md` | Contrato do QA Agent. |
| `devops-infra-agent.md` | Contrato do DevOps/Infra Agent. |
| `marketing-gtm-agent.md` | Contrato do Marketing/GTM Agent. |
| `documentation-agent.md` | Contrato do Documentation Agent. |
| `handoff-template.md` | Modelo de handoff entre qualquer agente e o Orchestrator. |
| `README.md` | Este catálogo. |

Documentos de produto que governam os agentes vivem em `../product/`:
`context-index.md`, `product-operating-system.md`, `mvp-backlog.md`, `decision-log-template.md`, `scope-guardrails.md`.

---

## Catálogo de agentes (planejados)

Cada agente recebe tarefas do Orchestrator com contexto + critério de aceite, executa e devolve um handoff.

| Agente | Responsabilidade | Fonte principal | Contrato | Status |
|---|---|---|---|---|
| **Product Orchestrator** | Quebrar escopo, priorizar, aprovar/rejeitar, manter rastreabilidade. | todo `/context` | `product-orchestrator-agent.md` | **Ativo** |
| **Backend Agent** | Route Handlers/Server Actions, API surface, auth gate, eventos. | `02`, `04` | `backend-agent.md` | Contrato |
| **Frontend Agent** | Landing/apply, report UI, tabela, toggle honesto, ações por linha. | `01`, `05` | `frontend-agent.md` | Contrato |
| **Data/AI Pipeline Agent** | 6 agentes do pipeline, coleta YouTube, Entity Resolution, Scoring determinístico. | `03`, arquitetura | `data-ai-pipeline-agent.md` | Contrato |
| **Database Agent** | Schema, migrations, raw/computed, RLS, reprodutibilidade. | `04` | `database-agent.md` | Contrato |
| **Security & Privacy Agent** | Auth, secrets, API keys, acesso restrito, RLS, logs sem dados sensíveis. | `02` §9, `07` | `security-privacy-agent.md` | Contrato |
| **QA Agent** | Fluxos críticos, edge cases, validação dos eventos e do follow-up. | `01`, `06` | `qa-agent.md` | Contrato |
| **DevOps/Infra Agent** | Ambientes (local/staging/prod), Vercel, Supabase, Sentry, cron, jobs. | `02` §5, §11 | `devops-infra-agent.md` | Contrato |
| **Marketing/GTM Agent** | Lista de produtores, ondas de convite, copy DM/email/landing honesta. | `05` | `marketing-gtm-agent.md` | Contrato |
| **Documentation Agent** | Manter docs, context-index, decision log, READMEs atualizados. | todo `/context` | `documentation-agent.md` | Contrato |

> Mapeamento de papéis humanos ↔ agentes segue o RACI em `06_Execution_RACI_Backlog.md`.

---

## Regras gerais para todos os agentes

1. **Escopo é travado.** Qualquer ideia fora do MVP volta ao Orchestrator como proposta, não como entrega.
2. **Número é determinístico.** Nenhum agente usa IA generativa para produzir Score, Velocity, Signals, Competition, ranking ou Example.
3. **Raw é sagrado.** Nenhum agente sobrescreve dado bruto da YouTube API.
4. **Rastreabilidade.** Toda entrega lista arquivos alterados, riscos e próximos passos via handoff.
5. **Revisões cruzadas.** Entregas que tocam número/banco/auth/copy pública passam por Data/Security/QA antes do "aprovado".
6. **Escalation.** Em conflito de documentos ou risco (segurança, dados, escopo, metodologia), parar e marcar `OPEN DECISION`.

---

## Como adicionar um novo agente (futuro)

1. Criar `docs/agents/<nome>-agent.md` seguindo a estrutura do Product Orchestrator (Role, Mission, Authority, Source of Truth, Non-Negotiables, Definition of Done, Escalation, Output Format).
2. Registrar no catálogo acima.
3. Registrar a criação no decision log.
4. Definir as revisões cruzadas que esse agente dispara.
