# Handoff Template — NOXUND

Modelo de handoff usado por **qualquer agente** ao devolver uma tarefa ao Product Orchestrator.

Sem handoff preenchido, a tarefa **não está concluída** (ver Definition of Done em `product-orchestrator-agent.md`).

Copie o bloco abaixo, preencha e anexe à tarefa/PR.

---

```md
# Handoff — <ID da tarefa> · <título curto>

## 1. Identificação
- **Tarefa:** <ID do backlog, ex.: RP-001>
- **Owner agent:** <Backend / Frontend / Data-AI / Database / Security / QA / DevOps / Marketing / Docs>
- **Data:** <YYYY-MM-DD>
- **Prioridade:** <P0 / P1 / P2>

## 2. Objetivo
<O que esta tarefa deveria entregar, em 1–2 frases.>

## 3. Critério de aceite (do backlog)
<Cole o critério de aceite original.>

## 4. Resultado
- [ ] Critério de aceite atendido
- [ ] Demonstrável (como verificar): <comando / rota / passo>
<Resumo do que foi feito.>

## 5. Arquivos alterados
- `caminho/arquivo` — <o que mudou>

## 6. Impacto no escopo
- Mantém o MVP travado? <sim/não — se não, PARAR e escalar>
- Toca algum non-negotiable? <quais e como>
- Toca número/banco/auth/copy pública? <sim/não → revisão necessária>

## 7. Validação executada
- Testes: <quais rodaram e resultado real>
- Auditoria/reprodutibilidade (se aplicável): <evidência>

## 8. Riscos
- <Novos riscos introduzidos ou riscos mitigados; referência a 07_Risks se aplicável>

## 9. Revisões necessárias
- [ ] Data/AI Review (se tocou número, rubric, pipeline ou coleta)
- [ ] Security Review (se tocou auth, secrets, API keys, endpoints, RLS)
- [ ] Database/Data Integrity Review (se tocou schema, migrations, raw/computed)
- [ ] QA Review (se tocou fluxo crítico ou eventos)
- [ ] Product Lead (se há OPEN DECISION ou mudança de escopo)

## 10. Próximos passos
- <O que vem depois; dependências desbloqueadas.>

## 11. Open decisions / bloqueios
- <Liste itens marcados como OPEN DECISION, ou "nenhum">
```

---

## Notas de uso

- **Honestidade obrigatória.** Se um teste falhou ou um passo foi pulado, registrar aqui — não marcar "atendido" sem evidência.
- **Um handoff por tarefa.** Tarefas grandes devem ser quebradas antes, não resumidas depois.
- **Revisões cruzadas** são gatilhos, não formalidade: marcar a revisão **e** acioná-la.
- O Orchestrator responde a cada handoff com **aprovar / rejeitar / pedir ajuste** e registra decisões relevantes via `decision-log-template.md`.
