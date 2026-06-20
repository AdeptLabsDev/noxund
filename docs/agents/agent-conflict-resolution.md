# Agent Conflict Resolution — NOXUND

**Função:** definir como conflitos entre agentes são resolvidos sem travar a execução nem furar a governança.
**Vinculado a:** `global-agent-rules.md`, `agent-boundaries.md`, `agent-review-matrix.md`.

---

## Regras de resolução

1. **O Product Orchestrator decide conflitos de escopo.** Disputa sobre o que entra/sai do MVP é dele.
2. **O Security & Privacy Agent pode bloquear por risco de segurança.** Bloqueio de segurança não é "voto" — é veto até mitigação.
3. **O Data/AI Pipeline Agent pode bloquear por risco metodológico.** Qualquer coisa que ameace determinismo, auditoria ou reprodutibilidade.
4. **O QA Agent pode bloquear por falha de critério de aceite.** Sem critério atendido, não há aprovação.
5. **Backend / Frontend / DevOps não podem passar por cima de Security.** Um bloqueio de segurança só cai com mitigação aceita pela Security.
6. **Marketing não pode alterar a promessa do produto sozinho.** Mudança de claim/posicionamento exige Product Orchestrator.
7. **Conflito não resolvido vira `OPEN DECISION`** e sobe ao Product Lead.

---

## Poderes de bloqueio (veto)

| Agente | Pode bloquear por | Como é levantado |
|---|---|---|
| Security & Privacy | risco de segurança/privacidade | mitigação aceita pela Security |
| Data/AI Pipeline | risco metodológico (determinismo, auditoria, reprodutibilidade) | correção aceita pelo Data/AI |
| QA | falha de critério de aceite | critério atendido e re-testado |
| Product Orchestrator | violação de escopo / non-negotiable | decisão registrada ou ajuste de escopo |

Bloqueio é sempre **rastreável**: motivo + severidade + mitigação exigida, registrados no handoff.

---

## Ordem de precedência

Quando dois princípios colidem, a ordem é:

1. **Segurança e integridade de dados** (Security; raw imutável).
2. **Credibilidade metodológica** (Data/AI; determinismo/auditoria).
3. **Escopo e tese do MVP** (Product Orchestrator).
4. **Critério de aceite / qualidade** (QA).
5. **Velocidade de entrega.**

Velocidade nunca vence segurança, método ou escopo.

---

## Fluxo de resolução

```txt
Conflito detectado
↓
Agentes tentam resolver no nível técnico (com base em /context)
↓
Há bloqueio de Security / Data/AI / QA?  → respeitar veto até mitigação
↓
É conflito de escopo?  → Product Orchestrator decide
↓
É conflito de promessa/posicionamento?  → Product Orchestrator (com Marketing)
↓
Resolvido?  → registrar decisão (decision-log-template.md)
Não resolvido?  → OPEN DECISION + escalar ao Product Lead
```

---

## Quando virar `OPEN DECISION`

- conflito entre documentos de `/context`;
- veto mantido sem mitigação acordada;
- proposta que exigiria mudar escopo, stack, rubric, schema ou posicionamento;
- ausência de fonte de verdade para decidir.

Registrar com: descrição do conflito, documentos/§ envolvidos, opções consideradas, agentes envolvidos e o que falta para decidir. Status `OPEN DECISION` até a resposta do Product Lead.

---

## Anti-padrões proibidos

- "Resolver" um bloqueio ignorando-o.
- Mudar critério de aceite para a entrega passar.
- Marketing reescrever promessa para encaixar uma feature.
- Backend/Frontend/DevOps fazer merge com revisão de segurança pendente.
- Tratar silêncio de um revisor como aprovação.
