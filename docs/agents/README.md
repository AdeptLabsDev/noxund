# NOXUND — Camada de Agentes

Esta pasta define a **camada operacional de agentes** do MVP NOXUND Hotspot Artists Report.

### Modelo de estado operacional (três estados)

A arquitetura real distingue **três** estados — um contrato existir **não** significa que o agente faça trabalho de produto:

- **FORMAL CONTRACT** — existe um `.md` de contrato do agente em `docs/agents`.
- **FOUNDATION RUNTIME HANDLER** — registrado como executor em `@noxund/orchestrator` que **valida a ação e devolve um plano/handoff**, mas **NÃO** faz trabalho de produto real e **NÃO** gera números.
- **REAL PRODUCT EXECUTOR** — de fato executa trabalho de produto. **Nenhum existe ainda.**

Estado atual:

- Os **10 agentes preexistentes** (Product Orchestrator, Backend/Next API, Frontend, Data/AI Pipeline, Database, Security & Privacy, QA, DevOps/Infra, Marketing/GTM, Documentation) têm **FORMAL CONTRACT + FOUNDATION RUNTIME HANDLER** (nenhum REAL PRODUCT EXECUTOR).
- O **Governance & Integrity Agent** e a capacidade DevOps **`apply_exact_remediation`** têm **FORMAL CONTRACT ONLY** e permanecem **`PROPOSED-NOT-OPERATIONAL`** (não wired como foundation runtime handler, não operacional) até aceite do Product Lead + um gate de wiring de runtime posterior e separado.
- O **Orchestration Runtime Engineering Agent** tem `FORMAL CONTRACT = PROPOSED`, `FOUNDATION RUNTIME HANDLER = ABSENT`, `REAL RUNTIME ENGINEERING EXECUTOR = ABSENT` — estado **`PROPOSED-NOT-OPERATIONAL`** (`CONTRACT-PROPOSED / RUNTIME-NOT-WIRED / NOT-OPERATIONAL`); `SELF-WIRING = FORBIDDEN`; a ativação inicial em runtime exige um **gate de bootstrap separado do Product Lead**.

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
| `agent-onboarding-orchestration.md` | **Onboarding/prompt** para os agentes operarem o runtime: TaskCommand, AgentResult, status, segurança, exemplos. |

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
| `governance-integrity-agent.md` | Contrato do Governance & Integrity Agent (revisor independente, `READ-ONLY BY DEFAULT`). `PROPOSED-NOT-OPERATIONAL`. |
| `orchestration-runtime-engineering-agent.md` | Contrato do Orchestration Runtime Engineering Agent (implementação do control plane `@noxund/orchestrator`). `PROPOSED-NOT-OPERATIONAL` (`CONTRACT-PROPOSED / RUNTIME-NOT-WIRED / NOT-OPERATIONAL`). |
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
| **Governance & Integrity Agent** | Verificação independente de autorização×ações, escopo/caminhos exatos, preservação, hashes/manifestos, estado de Git, remediação; veredito PASS/HOLD/RED. `READ-ONLY BY DEFAULT`. | operações governadas + artefatos técnicos | `governance-integrity-agent.md` | Contrato (`PROPOSED-NOT-OPERATIONAL`) |
| **Orchestration Runtime Engineering Agent** | Implementação do control plane `@noxund/orchestrator` (`packages/orchestrator/src/**`, `tests/**`): registração/handlers/dispatcher/validator/safety/approval-gate/binding e testes do runtime. Não é o Product Orchestrator; não decide produto. | runtime `@noxund/orchestrator` (`packages/orchestrator`) | `orchestration-runtime-engineering-agent.md` | Contrato (`PROPOSED-NOT-OPERATIONAL`) |

> **Legenda de estado (coerente com o modelo de três estados acima).** `Ativo` / `Contrato` na coluna Status referem-se ao **contrato**. Os agentes com `Contrato` já possuem FORMAL CONTRACT + FOUNDATION RUNTIME HANDLER, mas **nenhum** é REAL PRODUCT EXECUTOR ainda. `Contrato (PROPOSED-NOT-OPERATIONAL)` = **FORMAL CONTRACT ONLY** (sem foundation runtime handler, não operacional) — vale para o **Governance & Integrity Agent** e para o **Orchestration Runtime Engineering Agent**. Para o Orchestration Runtime Engineering Agent, os três estados são: `FORMAL CONTRACT = PROPOSED`, `FOUNDATION RUNTIME HANDLER = ABSENT`, `REAL RUNTIME ENGINEERING EXECUTOR = ABSENT`; a ativação inicial exige gate de bootstrap separado do Product Lead (`SELF-WIRING = FORBIDDEN`).

> Mapeamento de papéis humanos ↔ agentes segue o RACI em `06_Execution_RACI_Backlog.md`.

> **DevOps — capacidade de remediação exata (`apply_exact_remediation`, `PROPOSED-NOT-OPERATIONAL`).** O contrato do DevOps/Infra Agent (`devops-infra-agent.md`) inclui uma capacidade **estreita** de remediação exata aprovada pelo Product Lead: mutação destrutiva com `requires_human_approval = true`, alvo sempre fornecido pela tarefa (nunca escolhido pelo agente), sem wildcard/recursão não autorizada/limpeza ampla, e handoff obrigatório ao `governance_integrity_agent` independente. A **fonte normativa** é o contrato do agente + `agent-registry.md` / `agent-boundaries.md` / `agent-review-matrix.md`; este README apenas cataloga.

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

Modelo vinculante **registry-first**, nesta ordem:

1. capability gap estabelecido;
2. autorização de provisioning task-scoped do Product Lead;
3. Agent Definition / Configuration Gate separado;
4. autor registrado e elegível;
5. revisores independentes obrigatórios;
6. aceite do Product Lead;
7. fechamento em registry / boundaries / review-matrix;
8. wiring de runtime separado, se necessário;
9. o agente recém-criado **NÃO** pode executar a tarefa dependente durante seu próprio provisioning gate.

Nenhuma permissão permanente (standing permission) é criada por este processo.
