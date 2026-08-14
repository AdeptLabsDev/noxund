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
| **Governance & Integrity** (`governance-integrity-agent.md`) | Verificação independente de autorização×ações, escopo/caminhos exatos, preservação, hashes/manifestos, estado de Git, remediação (independente do executor); veredito PASS/HOLD/RED | Execução da operação auditada; autoria do artefato que sozinho aceita; remediação que verifica; aceite final de produto | É revisor independente; **pode bloquear** (`HOLD`/`RED`) por evidência ausente/violação de autorização | Contrato (PROPOSED-NOT-OPERATIONAL) |
| **Orchestration Runtime Engineering** (`orchestration-runtime-engineering-agent.md`) | Implementação do control-plane de orquestração (`packages/orchestrator/src/**`, `tests/**`): registração/handlers/dispatcher/validator/safety/approval-gate/approval-binding, testes do runtime | Produto/backend/frontend/database/metodologia/deploy; aceitação de Security/QA/governança; decisões de produto | **QA obrigatório** em qualquer mudança de runtime; **Security obrigatório** em safety/approval/authorization/binding; Product Lead gate em mudança semântica de aprovação | **Contrato (CONTRACT-PROPOSED / RUNTIME-NOT-WIRED / NOT-OPERATIONAL)** |

### Ações permitidas do novo agente (allow-list proposta)

`governance_integrity_agent` — **apenas** ações read-only/atestação; **nenhuma** muta estado:
`verify_authorization_scope`, `verify_filesystem_state`, `verify_exact_paths`, `verify_preservation_claim`, `verify_artifact_integrity`, `replay_integrity_manifest`, `verify_git_state`, `verify_remediation`, `attest_evidence`. Postura `READ-ONLY BY DEFAULT`; ações sensíveis (gated) = **nenhuma**.

> **Nota de identidade.** O `governance_integrity_agent` é uma **identidade de runtime PROPOSTA** até o wiring. **Identidade de contrato e registro de runtime são DISTINTOS:** declarar o runtime-id pretendido **não** significa que um executor esteja registrado. A allow-list acima é o conjunto **proposto** de ações, não um executor ativo.

> **Wiring de runtime DEFERIDO (`PROPOSED-NOT-OPERATIONAL`).** Esta entrada **registra/descreve** a **identidade proposta** e as **ações permitidas** do novo agente; ela **não** se autoriza a si mesma. O avanço de `CONTRACT-PROPOSED` para aceito exige **aceite do Product Lead** — o registry apenas documenta o estado proposto. O **registro do executor** em `orchestration-runtime.md` (tabela agent↔runtime-id) e a **allow-list de onboarding** em `agent-onboarding-orchestration.md` §9 são arquivos **PROTEGIDOS** e **não** foram editados. Portanto: Contrato ✅ / Executor implementado ⛔. A capacidade só se torna operacional após **aceite do Product Lead** + uma **tarefa de runtime futura e separada**. Até lá, a delegação a este `target_agent` não está ligada no runtime.
>
> **Identidade de runtime PROPOSTA.** O `governance_integrity_agent` é uma **identidade de runtime PROPOSTA** até o wiring. **Identidade de contrato e registro de runtime são DISTINTOS:** declarar o runtime-id pretendido **não** significa que um executor esteja registrado.
>
> **Ciclo de vida da capacidade proposta:**
> `CONTRACT-PROPOSED → CONTRACT-ACCEPTED-RUNTIME-NOT-WIRED → RUNTIME-WIRED-AND-VERIFIED → OPERATIONAL`.
> Somente o **aceite do Product Lead** pode avançar `CONTRACT-PROPOSED → CONTRACT-ACCEPTED`; somente um **gate de wiring de runtime separadamente autorizado** pode avançar o estado de runtime. Tanto o **contrato Governance & Integrity** quanto a capacidade DevOps **`apply_exact_remediation`** estão atualmente em `CONTRACT-PROPOSED / RUNTIME-NOT-WIRED / NOT-OPERATIONAL`.

> **DevOps — `apply_exact_remediation` (`PROPOSED-NOT-OPERATIONAL`).** O contrato do `devops_agent` (`devops-infra-agent.md`) ganhou uma capacidade **estreita** de remediação exata aprovada pelo Product Lead: `requires_human_approval = true` para mutação destrutiva, alvo **sempre** fornecido pela tarefa (nunca escolhido pelo agente), sem wildcard/recursão não autorizada/limpeza ampla, e **handoff obrigatório** ao `governance_integrity_agent` independente. Também com **wiring de runtime DEFERIDO** (Contrato ✅ / Executor implementado ⛔) — não editamos `orchestration-runtime.md` nem `agent-onboarding-orchestration.md` §9.

### Ações permitidas do Orchestration Runtime Engineering Agent (allow-list proposta)

`orchestration_runtime_engineering_agent` — **allow-list PROPOSTA fechada:** `inspect_orchestration_runtime` (**read-only**), `implement_runtime_change`, `wire_runtime_agent`, `implement_runtime_handler`, `modify_runtime_safety_gate`, `implement_approval_binding`, `author_runtime_tests` (as **mutadoras** = **sensíveis / gated**, exigem aprovação humana por mutarem o control plane). Qualquer ação fora desta lista ⇒ `needs_review`, sem execução.

> **Wiring de runtime DEFERIDO (`CONTRACT-PROPOSED / RUNTIME-NOT-WIRED / NOT-OPERATIONAL`).** O **registro do executor** em `orchestration-runtime.md` (tabela agent↔runtime-id) e a **allow-list de onboarding** em `agent-onboarding-orchestration.md` §9 são arquivos **PROTEGIDOS** e **não foram editados** por esta provisão; este registry apenas **descreve** a identidade e as ações propostas. **Identidade de contrato ≠ registro de runtime:** `orchestration_runtime_engineering_agent` é uma **identidade de runtime PROPOSTA** até o wiring — declarar o runtime-id pretendido **não** significa que um executor esteja registrado.
>
> `SELF-WIRING = FORBIDDEN`; `INITIAL-RUNTIME-ACTIVATION = REQUIRES-SEPARATE-PRODUCT-LEAD-BOOTSTRAP-GATE`. Provisionar o `.md` e as entradas de registry/boundary **não** torna o agente operacional; a **PRIMEIRA registração em runtime** dependerá de uma **decisão futura e separada** do Product Lead que designe o autor estreito responsável. Só o **aceite do Product Lead** avança `CONTRACT-PROPOSED → CONTRACT-ACCEPTED`; só um **gate de wiring de runtime separadamente autorizado** avança o estado de runtime — ciclo de vida: `CONTRACT-PROPOSED → CONTRACT-ACCEPTED-RUNTIME-NOT-WIRED → RUNTIME-WIRED-AND-VERIFIED → OPERATIONAL`.

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
| Governance & Integrity | ✅ | ⛔ wiring deferido (`PROPOSED-NOT-OPERATIONAL`) |
| Orchestration Runtime Engineering | ✅ | ⛔ wiring deferido (`CONTRACT-PROPOSED / RUNTIME-NOT-WIRED / NOT-OPERATIONAL`) |
| DevOps — `apply_exact_remediation` (capacidade) | ✅ | ⛔ wiring deferido (`PROPOSED-NOT-OPERATIONAL`) |

Status atual do projeto: **Sprint 0** — governança + fundação técnica. Nenhum executor de produto ativo ainda. O agente **Governance & Integrity**, o agente **Orchestration Runtime Engineering** e a capacidade **DevOps `apply_exact_remediation`** estão em estado proposto (`CONTRACT-PROPOSED / RUNTIME-NOT-WIRED / NOT-OPERATIONAL`): contrato formalizado, mas sem registro no runtime nem allow-list de onboarding (arquivos protegidos), pendentes de aceite do Product Lead + tarefa de runtime separada.

> **Orchestration runtime (implementado).** A camada de **delegação automática** já existe em
> código: `packages/orchestrator` (`@noxund/orchestrator`). Ela transforma decisões do
> Orchestrator em comandos estruturados, valida, roteia ao agente registrado, captura o
> resultado padronizado, atualiza o estado central e registra logs JSONL — com gate de aprovação
> humana para operações sensíveis. Os **dez** executores de fundação **preexistentes** —
> **Product Orchestrator, Database, Backend/Next API, Frontend, Data/AI Pipeline, Security &
> Privacy, QA, DevOps/Infra, Marketing/GTM, Documentation** — estão **registrados como executores
> de fundação** (validam a ação e devolvem plano/handoff; ainda **não** fazem trabalho de produto
> nem geram número). Ver [`orchestration-runtime.md`](./orchestration-runtime.md). A coluna
> "Executor implementado" continua ⛔ porque se refere ao **executor de produto real**, não ao
> runtime de orquestração.
>
> **Governance & Integrity NÃO está entre os dez executores de fundação** — é `CONTRACT-PROPOSED`,
> não wired no runtime, e **não** deve ser contado como runtime-wired. O **Orchestration Runtime
> Engineering Agent** também **NÃO está entre os dez executores de fundação** — é
> `CONTRACT-PROPOSED / RUNTIME-NOT-WIRED / NOT-OPERATIONAL`, não wired no runtime, e **não** deve ser
> contado como runtime-wired. A capacidade DevOps `apply_exact_remediation` também **não** está wired.
