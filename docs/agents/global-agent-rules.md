# Global Agent Rules — NOXUND

**Aplica-se a:** todos os agentes (Product Orchestrator + especializados).
**Status:** vinculante. Quebrar uma regra aqui invalida a entrega.
**Fonte:** `/context` (ver `docs/product/context-index.md`) + `product-orchestrator-agent.md`.

> Estas regras existem para proteger o único ativo defensável da NOXUND: **credibilidade analítica**. Toda regra abaixo é inegociável até decisão registrada do Product Lead.

---

## Regras inegociáveis

1. **Nenhum agente pode alterar o escopo do MVP sem o Product Orchestrator.** Escopo novo vira proposta no decision log, não entrega.
2. **Nenhum agente pode transformar o MVP em marketplace.** Sem checkout, upload, licenças, payouts, perfis públicos, sub-perfis em produção.
3. **Nenhum agente pode criar feature de Fase 2 sem decisão registrada** (query sob demanda, multi-keyword, ML, data lake, exposure penalty, Redis/Celery obrigatório, pagamentos).
4. **Nenhum agente pode usar IA generativa para gerar números do relatório.** Score, Velocity, Signals, Competition, ranking e Example saem de código determinístico.
5. **Score, Velocity, Signals, Competition, ranking e Example devem ser determinísticos** — mesmo input ⇒ mesmo output, versionado por rubric (`rubric_version` + `rubric_hash`).
6. **Raw data é imutável.** Nenhum agente sobrescreve dado bruto da YouTube API. Recoleta = novo `run_id`.
7. **Computed data é reconstruível.** Métricas, scores e linhas do relatório recalculáveis a partir do raw.
8. **Toda alteração relevante precisa de handoff** (`docs/agents/handoff-template.md`). Sem handoff, a tarefa não está concluída.
9. **Toda decisão precisa ir para o decision log ou ser marcada como `OPEN DECISION`.** Decisão implícita não existe.
10. **Secrets nunca podem ser commitados.** API keys, tokens, service roles e senhas só em `.env` (gitignored); `.env.example` sem valores reais.
11. **Nenhum agente pode fazer deploy sem revisão** (DevOps + Security).
12. **Nenhum agente pode fazer push direto na `main`.** Trabalho via branch + revisão; `main` é protegida.

---

## Regras de processo derivadas

- **Honestidade de copy:** nenhuma copy pode sugerir geração ou IA em tempo real ("Re-Gen", "AI predicts", "new AI analysis"). Toggle e tooltips seguem `05_...` e `01_...`.
- **Rastreabilidade:** nenhum número público sem rastro até `raw_youtube_videos`; auditoria por célula obrigatória.
- **Revisões cruzadas:** entregas que tocam número/banco/auth/copy pública acionam a revisão correspondente (`agent-review-matrix.md`) antes do "aprovado".
- **Reprodutibilidade:** reprocessar o mesmo snapshot com o mesmo rubric gera o relatório idêntico; divergência = bug bloqueante.
- **Escalation:** conflito de documentos ou risco (segurança, dados, escopo, metodologia, posicionamento) → parar e marcar `OPEN DECISION` (`agent-conflict-resolution.md`).
- **Mínimo necessário:** não instalar dependências, não criar tabelas, não criar serviços além do exigido pela tarefa.

---

## Hierarquia de autoridade (resumo)

- **Product Orchestrator** decide escopo, prioridade e aprova/rejeita entregas.
- **Security & Privacy Agent** pode **bloquear** por risco de segurança.
- **Data/AI Pipeline Agent** pode **bloquear** por risco metodológico.
- **QA Agent** pode **bloquear** por falha de critério de aceite.
- Backend/Frontend/DevOps **não** passam por cima de Security.
- Marketing **não** altera promessa do produto sozinho.
- Conflito não resolvido → `OPEN DECISION` + Product Lead.

Detalhe em `agent-conflict-resolution.md`. Limites por agente em `agent-boundaries.md`.
