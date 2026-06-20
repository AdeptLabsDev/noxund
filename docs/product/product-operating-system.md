# Product Operating System — NOXUND MVP

**Mantido por:** Product Orchestrator Agent
**Escopo:** como o MVP Hotspot Artists Report é executado, do backlog à validação.

Este é o "como trabalhamos". O "o que construímos" está em `/context` e em `mvp-backlog.md`. O "o que não construímos" está em `scope-guardrails.md`.

---

## 1. Como criar tarefas

Toda tarefa nasce no formato do backlog (`mvp-backlog.md`):

```md
### [AREA] Nome da tarefa
**Objetivo:** **Descrição:** **Critério de aceite:**
**Dependências:** **Risco:** **Owner agent sugerido:** **Prioridade:** P0/P1/P2
```

Regras:

- Tarefa sem **critério de aceite verificável** não entra no backlog.
- Tarefa que toca número/banco/auth/copy pública nasce com a **revisão cruzada** já marcada.
- Tarefa fora do MVP **não vira tarefa** — vira proposta no decision log.
- Toda tarefa tem **um** owner agent sugerido (ver `docs/agents/README.md`).

---

## 2. Como priorizar

Prioridade segue `06_Execution_RACI_Backlog.md`:

- **P0** — sem isso o MVP não vai ao ar (os 9 itens do "P0 absoluto").
- **P1** — entra se não atrasar P0 (dashboard bonito, export CSV, PostHog, polish).
- **P2 / Fase 2** — não construir agora.

Ordem de desempate dentro de P0:
1. desbloqueia outros P0 (dependência);
2. protege credibilidade analítica (metodologia/auditoria);
3. protege segurança/dados;
4. encurta caminho até medir comportamento real.

---

## 3. Como registrar decisões

- Toda decisão que altera escopo, stack, rubric, schema ou posicionamento usa `decision-log-template.md`.
- Decisões ficam em `docs/product/decisions/` (um arquivo por decisão) **ou** num `DECISIONS.md` apendado — escolher um padrão e manter (`OPEN DECISION`: definir o local definitivo na Sprint 0).
- Decisão que contradiz `/context` exige aprovação do Product Lead antes de virar verdade.
- Nada de decisão implícita: se não está registrada, não aconteceu.

---

## 4. Como revisar PRs

Checklist mínimo de PR (o Orchestrator não aprova sem isto):

- [ ] handoff preenchido (`docs/agents/handoff-template.md`);
- [ ] critério de aceite demonstrado;
- [ ] nenhum número novo sem rastro até `raw_youtube_videos`;
- [ ] nenhuma IA generativa produzindo número;
- [ ] nenhuma copy sugerindo geração/IA em tempo real;
- [ ] secrets fora do código e do front;
- [ ] mudança de schema acompanhada de migration + nota de raw/computed;
- [ ] revisões cruzadas necessárias acionadas e respondidas.

Qualquer item não marcado → pedir ajuste, não aprovar.

---

## 5. Como aprovar mudanças de escopo

1. Mudança de escopo só nasce como proposta no decision log.
2. O Orchestrator avalia contra `scope-guardrails.md` e a hierarquia de fontes de verdade.
3. Se contraria decisão travada → **escalation ao Product Lead**.
4. Aprovada → atualizar `/context` (ou registrar exceção), `mvp-backlog.md` e o `context-index.md`.
5. Rejeitada → registrar o motivo (decisões rejeitadas também são histórico).

---

## 6. Como lidar com agentes especializados

- O Orchestrator cria a tarefa com contexto + critério de aceite e atribui ao owner agent.
- O agente executa e devolve handoff.
- Revisões cruzadas (Data/Security/QA/Database) rodam conforme o gatilho.
- O Orchestrator aprova/rejeita/pede ajuste e registra o que for decisão.
- Nenhum agente expande escopo; escopo novo volta ao Orchestrator.

---

## 7. Como definir sprint

- Sprint curta (sugestão: 1 semana, alinhada à timeline Semana 0–5 do `06_...`).
- Cada sprint tem um **objetivo único e verificável** (ver Sprints 0–3 abaixo).
- Só entram P0 enquanto houver P0 aberto; P1 preenche folga.
- Fechamento da sprint = todos os handoffs revisados + métricas/critérios da sprint avaliados.

---

## 8. Como validar entrega

- **Tarefa:** critério de aceite + handoff + revisões = done.
- **Sprint:** objetivo da sprint atingido e demonstrável.
- **MVP:** Definition of Done agregada (`06_...` §7) + checklist de lançamento (`06_...` §8).
- **Produto (hipótese):** métricas de validação (`01_...` §8) — intenção ≥ 30%, confirmação ≥ 50%, WTP ≥ 25%, HOT úteis ≥ 60%, open rate ≥ 70%.

Validação de produto **só conta com follow-up real** (10–14 dias). Sem follow-up, mede-se curiosidade, não comportamento.

---

## Recomendação de primeiras sprints

### Sprint 0 — Organização e fundação

- estruturar docs (esta camada operacional);
- definir agentes (catálogo + Orchestrator);
- criar backlog inicial;
- preparar repo;
- validar stack contra `02_...`;
- criar `.env.example` (sem secrets reais);
- configurar Supabase/Vercel **somente quando necessário** (não antecipar).

**Objetivo:** centro operacional pronto; ninguém começa a codar sem escopo e critérios claros.

### Sprint 1 — Relatório mockado navegável

- frontend inicial (landing/apply + shell autenticado);
- tabela do relatório com as colunas públicas;
- dois relatórios mockados (dados fake fiéis ao schema);
- botão honesto de alternância ("Ver outro grupo de oportunidades");
- **sem pipeline real ainda.**

**Objetivo:** experiência navegável que prova o formato sem tocar dados reais.

### Sprint 2 — Eventos de validação

- feedback por artista (`Útil`/`Não útil`);
- intenção de produção (`Vou produzir`);
- WTP;
- follow-up (scheduler + due_at 10–14 dias);
- export básico (CSV).

**Objetivo:** todo clique vira evento auditável; o loop de validação fecha.

### Sprint 3 — Pipeline real

- YouTube Data API (Search + Video Data);
- raw snapshot imutável (`run_id`);
- computed metrics + Score determinístico (rubric versionado);
- report snapshot congelado;
- auditoria/reprodutibilidade (mesmo snapshot ⇒ mesmo relatório).

**Objetivo:** substituir o mock por dados reais sem mudar o formato já validado.

---

## Cadência de revisão

- **Diária (assíncrona):** handoffs pendentes, bloqueios, `OPEN DECISION` abertos.
- **Fim de sprint:** objetivo atingido? métricas? riscos novos? backlog re-priorizado.
- **Pré-lançamento:** checklist de lançamento (`06_...` §8) + revisão Security + Data Integrity.
