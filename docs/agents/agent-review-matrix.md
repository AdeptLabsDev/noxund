# Agent Review Matrix — NOXUND

**Função:** definir qual mudança dispara qual revisão, antes do "aprovado" do Product Orchestrator.
**Vinculado a:** `agent-registry.md`, `global-agent-rules.md`, `agent-boundaries.md`.

Uma mudança pode disparar várias revisões. Revisão exigida e **não** acionada = entrega bloqueada.

---

## Matriz

| # | Tipo de mudança | Revisão obrigatória | Por quê |
|---|---|---|---|
| 1 | Backend — auth / API / acesso a dado | **Security** | Superfície de acesso e exposição de dados. |
| 2 | Backend — schema / eventos | **Database** | Integridade do modelo de dados e eventos. |
| 3 | Migrations de banco | **Database + Security** | Risco estrutural + risco de acesso/RLS. |
| 4 | Mudança em raw / computed data | **Data/AI** | Imutabilidade do raw e reconstrutibilidade do computed. |
| 5 | Mudança em Score / rubric | **Product Orchestrator + Data/AI + QA** | Coração da credibilidade analítica; precisa de escopo, método e validação. |
| 6 | Frontend — copy / promessas | **Product Orchestrator + Marketing** | Posicionamento e honestidade pública. |
| 7 | Frontend — fluxos críticos | **QA** | Garantia de eventos e critérios de aceite. |
| 8 | Deploy / mudança de ambiente | **DevOps + Security** | Estabilidade + secrets/exposição. |
| 9 | Claims de marketing | **Product Orchestrator** | Promessa do produto não pode inflar. |
| 10 | Documentação que altera decisões | **Product Orchestrator** | Decisão só vale se registrada e aprovada. |
| 11 | Remediação destrutiva/exata de filesystem | Ordem normativa: **aprovação humana do Product Lead → verificação de pré-condição exata pelo `devops_agent` → mutação exata autorizada → verificação independente pós-remediação pelo `governance_integrity_agent`** | Mutação destrutiva exige que a aprovação humana **preceda** a mutação; alvo exato; verificação de pré-condição; e verificação independente do executor após a mutação. A aprovação humana **DEVE** vir antes de qualquer mutação destrutiva. |
| 12 | Artefato sensível de governança/integridade | **`governance_integrity_agent`** (revisor obrigatório) | Integridade/autorização precisa de verificação independente, distinguindo evidência verificada de atestada. |
| 13 | Mudança de fronteira sensível a segurança | **`security_agent`** (revisor obrigatório) | Alteração de boundary pode expandir superfície de acesso/risco. |
| 14 | Runtime registration / handler / dispatcher / validator change (control plane `@noxund/orchestrator`) — autor `orchestration_runtime_engineering_agent` | **QA obrigatório** | Qualquer mudança de código do runtime exige validação independente de comportamento/verificabilidade; o autor não é a única autoridade que aceita seus próprios testes. |
| 15 | Safety / sensitivity / human-approval / authorization change (control plane) — autor `orchestration_runtime_engineering_agent` | **Security obrigatório + QA obrigatório** | Toca `safety.ts`/`dispatcher.ts`/gate de aprovação/classificação de sensibilidade/provenance/approval binding/replay/expiry/handler privilegiado — superfície de segurança + comportamento verificável. |
| 16 | Human-approval **semantic** change (control plane) | **Product Lead gate** | Alterar a semântica da aprovação humana muda uma barreira de governança; exige gate humano do Product Lead (além de Security + QA). |

---

## Bootstrap — Governance & Integrity Agent

O Governance & Integrity Agent **NÃO PODE** ser exigido como revisor/aprovador de:

- (a) sua **própria definição inicial**;
- (b) seu **próprio registro inicial**;
- (c) seu **próprio primeiro wiring/ativação de runtime**.

Exigir isso criaria um **deadlock de self-review** — explicitamente **não permitido**.

Apenas para essa transição de bootstrap, a topologia aceita é:

`documentation_agent (autor) + security_agent (revisão de domínio independente) + qa_agent (revisão independente de verificabilidade / separação de deveres) + Product Lead (aceite final de bootstrap)`.

Depois que o Governance & Integrity estiver operacional, os requisitos normais da review matrix voltam a valer integralmente (incluindo os itens #11 e #12).

---

## Bootstrap — Orchestration Runtime Engineering Agent

Para a **ativação inicial** (primeiro wiring/ativação de runtime) do `orchestration_runtime_engineering_agent`, o **`governance_integrity_agent` NÃO PODE** ser exigido como revisor de bootstrap: a Governança **não** está operacional em runtime ainda, e um **self-bootstrap deadlock** é **proibido**. A topologia de bootstrap aceita é a mesma já aceita no projeto:

`documentation_agent (autor da definição) + security_agent (revisão de domínio independente) + qa_agent (revisão independente de verificabilidade / separação de deveres) + Product Lead (aceite final de bootstrap)`.

O próprio agente **NÃO PODE** autorar nem aprovar sua **própria primeira ativação** (`SELF-WIRING = FORBIDDEN`) e **NÃO participa** da revisão/aprovação da própria definição inicial. Depois de operacional, os itens #14–#16 desta matriz valem integralmente.

> **Testes autorados pelo próprio agente.** O `orchestration_runtime_engineering_agent` **PODE** autorar seus próprios testes de runtime, mas **NÃO PODE** ser a **única autoridade** que os aceita como prova de correção — a **aceitação independente do QA** é **obrigatória** (item #14).

---

## Gatilhos adicionais (derivados de `/context`)

| Tipo de mudança | Revisão obrigatória |
|---|---|
| Coleta dos 500 vídeos (keyword, janela, volume, paginação) | Product Orchestrator + Data/AI |
| Regra de Competition / Signals / Velocity / Example | Data/AI + QA |
| Entity Resolution (regex, uso de LLM, guardrails) | Data/AI |
| RLS / roles / política de acesso | Security + Database |
| Gestão de secrets / API keys | Security |
| Internal jobs / cron protegidos | Security + DevOps |
| Tabelas próximas de marketplace/Fase 2 | Product Orchestrator (bloqueio) |
| Texto público de metodologia / tooltips | Product Orchestrator + Marketing |

---

## Fluxo de aplicação

```txt
Agente entrega → identifica gatilhos na matriz →
aciona revisor(es) → revisor aprova/bloqueia →
Product Orchestrator confirma todas as revisões → aprova/rejeita/pede ajuste
```

- **Security**, **Data/AI** e **QA** têm poder de **bloqueio** (ver `agent-conflict-resolution.md`).
- **Governance & Integrity** bloqueia com `HOLD` (evidência load-bearing ausente) ou `RED` (violação de autorização quando o gate governante a define como `RED`).
- Bloqueio só é levantado pelo agente que bloqueou, mediante mitigação.
- Revisão pendente nunca é "assumida como ok".
- **Nenhum voto de maioria supera um `HOLD` de revisor obrigatório** — consistente com `agent-conflict-resolution.md` (bloqueio é veto, não voto). Também vale para remediação exata: o gate humano (`requires_human_approval = true`) e a verificação independente do `governance_integrity_agent` não são dispensáveis por conveniência de roteamento.

---

## Como registrar a revisão

No handoff (`handoff-template.md`, seção 9), marcar cada revisão exigida **e** anexar o resultado:

- ✅ aprovada (com nota do revisor),
- ⛔ bloqueada (com motivo + mitigação exigida),
- ⏳ pendente (entrega não pode ser aprovada).
