## DEC-0004 — Captura de resposta do follow-up (fecha gap de API surface, BE §2-E)

- **Data:** 2026-06-20
- **Status:** Aprovada (alçada do Product Orchestrator — "criar endpoints reais" é decisão do PO; a capacidade já está no escopo travado)
- **Decisor:** Product Orchestrator
- **Área:** Escopo / Backend (endpoint)
- **Prioridade/Impacto:** Alto (atinge métrica de validação)

### Contexto
O Backend Agent (`docs/backend/BE-0001-consumability-authz-contract-review.md`, achado §2-E) confirmou que o modelo de dados serve `02_...` §7, **mas** identificou que `02_...` §7 não enumera rota para capturar a **resposta** do follow-up — só `POST /internal/followups/run-due` (envio/processamento de due). Sem rota de entrada, a métrica **"Confirmação em follow-up"** (`04_...` §13; critério de avanço de Fase 2 LD-14: confirmação ≥ 50%) fica sem caminho de captura.

Não é expansão de escopo. Há **omissão dentro do próprio `02_`**: §10 (linha 190) lista "follow-up respondido" como **evento de produto obrigatório**, e `scope-guardrails` já trava "Follow-up 10–14 dias (scheduler + envio email/DM manual + **captura de resposta**)". O modelo de dados **já suporta** (`followups.status='responded'` + `followups.response jsonb` + eventos `followup_confirmed_produced`/`followup_confirmed_not_produced`). Falta apenas o endpoint.

### Decisão
1. **É in-scope. Autorizado.** O gap é de enumeração em `02_...` §7, não de escopo — fechado por esta DEC (criar endpoints = alçada do PO, `scope-guardrails` §"Decisões que exigem Product Orchestrator").
2. **Mecanismo, espelhando `followups.channel`:**
   - Canal **`email`** → **link assinado, single-use, expirável** abrindo uma página mínima de captura (produziu? sim/não + opcional). Maximiza taxa de resposta — a métrica depende disso; re-login derruba resposta. Token e rota nova → **revisão Security**.
   - Canal **`dm_manual`** → **captura manual pelo admin** via `/admin` (lê a resposta do DM e registra). Zero superfície nova ao produtor; é o fallback consistente com "DM manual".
3. **Escrita atômica obrigatória:** ambos gravam `followups.response` + emitem `producer_events` (`followup_confirmed_produced`/`_not_produced`) numa **função RPC Postgres** (PostgREST é por statement; dois round-trips não são atômicos — achado do Backend).

### Alternativas consideradas
- **In-app autenticado** (produtor faz login e responde) — re-login 10–14 dias depois é fricção que derruba a métrica norte. (não como canal primário do email)
- **Só captura manual pelo admin** — funciona para `dm_manual`, mas não escala para `email` e adiciona trabalho operacional. (mantido só como fallback do `dm_manual`)
- **Não capturar / adiar p/ Fase 2** — quebraria o evento obrigatório `02_...` §10 e a métrica de confirmação. (rejeitado)

### Justificativa
Completa o loop de validação P0 (intenção → follow-up → confirmação) e protege a métrica secundária que destrava a Fase 2. Superfície mínima, revisada por Security (token) e Database (RPC atômica). Reforça non-negotiables: evento, não flag; atomicidade evento+payload.

### Impacto
- **Escopo:** nenhuma expansão — capacidade já travada (`scope-guardrails`, `02_...` §10). Fecha enumeração faltante em `02_...` §7.
- **Non-negotiables:** reforçados (eventos append-only, atomicidade). Nenhum violado.
- **Documentos a atualizar:** `mvp-backlog.md` (novos itens [BE] e [DB]); referência cruzada em `BE-0001`.
- **Tarefas afetadas:** novas `[BE] Captura de resposta do follow-up` e `[DB] Funções RPC atômicas evento+payload`.

### Reversibilidade
Alta — endpoint isolado; o canal `dm_manual`/admin sozinho já garante a métrica se o link assinado for descartado.

### Revisões necessárias
- [x] Product Orchestrator
- [ ] Security — rota/token assinado (rota nova → matriz #1; `scope-guardrails` §Security)
- [ ] Database — função RPC atômica (`followups.response` + `producer_events`)
- [ ] Backend — handler + página de captura
- [ ] QA — incluída no fluxo crítico aplicar→...→follow-up (matriz #7)

### Follow-up
Envio depende de **OD-03 (Email provider)**; a **captura** em si é desenhável já. A parte de token/rota entra no gate do Security junto com SEC-F01..F03 antes da Fase 9. Não bloqueia o fechamento da etapa de proposta de modelo de dados.
