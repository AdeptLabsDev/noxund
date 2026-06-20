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
- Bloqueio só é levantado pelo agente que bloqueou, mediante mitigação.
- Revisão pendente nunca é "assumida como ok".

---

## Como registrar a revisão

No handoff (`handoff-template.md`, seção 9), marcar cada revisão exigida **e** anexar o resultado:

- ✅ aprovada (com nota do revisor),
- ⛔ bloqueada (com motivo + mitigação exigida),
- ⏳ pendente (entrega não pode ser aprovada).
