# Context Index — NOXUND `/context`

**Mantido por:** Product Orchestrator Agent
**Status:** vivo (atualizar sempre que `/context` mudar)
**Fonte:** `/context/*` — síntese operacional, não cópia integral.

> Regra: este índice é o mapa. A verdade detalhada continua nos arquivos originais.
> Nenhum arquivo de `/context` pode ser apagado ou movido sem atualizar este índice.

---

## Como ler esta tabela

Para cada arquivo: **tipo**, **função**, **decisões principais**, **riscos/atenção** e **como o Orchestrator usa**.

---

## 1. `README.md`

- **Tipo:** índice do pacote / capa.
- **Função:** apresentar o pacote do Product Lead e a ordem de leitura.
- **Decisões principais:** MVP = Hotspot Artists Report (não marketplace); vertical Chicago Drill; keyword travada `chicago drill type beat`.
- **Riscos/atenção:** lista "fontes de verdade" (`.docx`, `.txt`, `.pdf`) que **não estão** nesta pasta — são referências externas ao pacote. Tratar como contexto histórico, não artefato disponível.
- **Uso pelo Orchestrator:** ponto de entrada; confirmar tese antes de qualquer planejamento.

## 2. `00_Product_Lead_Decision_Log.md`  ⭐ FONTE DE VERDADE PRIMÁRIA

- **Tipo:** decision log oficial do Product Lead.
- **Função:** registrar as 14 decisões travadas e os cortes de escopo.
- **Decisões principais:** não-marketplace; headline "Market intelligence engine for producers"; vertical única; acesso fechado por aprovação manual; 2 relatórios fixos; sem query sob demanda; Score determinístico (rubric 40/25/20/15); IA generativa nunca calcula número; sem data lake / exposure penalty / ML no MVP; stack híbrida com cortes; marketing founder-led; critérios de avanço para Fase 2.
- **Riscos/atenção:** qualquer mudança aqui exige novo registro de decisão. É o documento que vence em conflito.
- **Uso pelo Orchestrator:** referência final de escopo. Em dúvida, este arquivo decide.

## 3. `01_MVP_Scope_PRD.md`  ⭐ FONTE DE VERDADE PRIMÁRIA

- **Tipo:** PRD / definição de escopo funcional.
- **Função:** definir exatamente o que o MVP faz e mede.
- **Decisões principais:** problema/hipótese central; ICP e critérios de aprovação; landing noindex + apply; aprovação manual; relatório autenticado; 7 colunas públicas (Title, Tag/HOT, Score `X/100`, Signals, Velocity, Competition, Example); HOT se Score > 90; Score exibido só se > 83; ações por linha (`Útil`, `Não útil`, `Vou produzir`); follow-up 10–14 dias; North Star = intenção declarada ≥ 30%; lista explícita de fora-de-escopo.
- **Riscos/atenção:** thresholds (90/83) e regra do Example são contratos — não alterar sem Data/AI Review.
- **Uso pelo Orchestrator:** base para critérios de aceite de Frontend, Backend e Data.

## 4. `02_Stack_Infra_Architecture.md`

- **Tipo:** arquitetura técnica / infra.
- **Função:** definir stack do MVP sem antecipar custo de marketplace.
- **Decisões principais:** Next.js + TS (front + core API via Route Handlers/Server Actions); Supabase (Postgres + Auth); Python data engine (script/worker, FastAPI opcional); Resend/Postmark; Vercel Cron ou Supabase Scheduled Functions; Sentry; Redis/Celery adiados; RLS; API key YouTube nunca no front; raw sagrado / computed reconstruível / report snapshot congelado.
- **Riscos/atenção:** API surface listada (`/apply`, `/app/report`, feedback/intent/wtp, admin, internal jobs) — manter alinhada ao schema.
- **Uso pelo Orchestrator:** validar boundaries; barrar qualquer item da lista "não entra na infra".

## 5. `03_Data_AI_Agents_Methodology.md`  ⭐ FONTE DE VERDADE PRIMÁRIA

- **Tipo:** metodologia de dados + pipeline de agentes.
- **Função:** definir como o relatório é produzido, auditado e blindado contra arbitrariedade.
- **Decisões principais:** princípio diretor "IA generativa nunca produz/julga/exibe número"; pipeline de 6 agentes (Search → Video Data → Entity Resolution → Channel Filter → Scoring → Opportunity); IA só no Agente 3 com validação por substring + fila de revisão; rubric versionado + hash; auditoria por célula; raw vs computed; reprodutibilidade obrigatória.
- **Riscos/atenção:** alterar rubric, coleta dos 500 vídeos ou regra do Example = escalation obrigatória.
- **Uso pelo Orchestrator:** régua de credibilidade. Toda entrega de Data/AI é medida contra este arquivo.

## 6. `04_Database_Event_Model.md`  ⭐ FONTE DE VERDADE PRIMÁRIA

- **Tipo:** modelo de dados e eventos.
- **Função:** definir schema mínimo com auditoria, reprodutibilidade e métricas.
- **Decisões principais:** raw imutável; computed reconstruível; eventos como log (não flags); `rubric_versions`/`outcome_weight_versions`; tabelas raw (search pages, videos, channels), resolução (artists, aliases, mappings), elegibilidade, métricas, reports/report_items, `producer_events`, `followups`, `wtp_responses`; lista de tabelas proibidas (beats, orders, payouts, etc.); queries de métricas; critério de aceite do banco.
- **Riscos/atenção:** alterações destrutivas no banco exigem Data Integrity Review.
- **Uso pelo Orchestrator:** base para tarefas de Database Agent e critérios de auditoria.

## 7. `05_Marketing_GTM_Validation.md`

- **Tipo:** GTM / validação / posicionamento.
- **Função:** atrair os produtores certos e proteger o posicionamento.
- **Decisões principais:** headline/subheadline; promessas permitidas vs proibidas; ICP de marketing; lista de 100 produtores em ondas (40–60 → reposição); DM via conta de artista + email; copy pronta de DM/email/onboarding; nota de honestidade na landing ("fixed report snapshots, not real-time generation"); loop de validação; leitura de resultados.
- **Riscos/atenção:** banir copy de previsão/garantia/IA mágica. Copy da landing e do toggle são restrições de produto, não só marketing.
- **Uso pelo Orchestrator:** insumo para Marketing/GTM Agent e revisão de toda copy pública.

## 8. `06_Execution_RACI_Backlog.md`

- **Tipo:** plano de execução, RACI e backlog inicial.
- **Função:** transformar escopo em plano executável com responsabilidades.
- **Decisões principais:** timeline Semana 0–5; matriz RACI; backlog por épicos (PL/RP/DE/FV/MT); P0 absoluto (9 itens); P1 permitido; P2/Fase 2; Definition of Done do MVP; checklist de lançamento.
- **Riscos/atenção:** o backlog deste pacote é a semente; `mvp-backlog.md` operacionaliza e expande sem contradizer.
- **Uso pelo Orchestrator:** base do backlog operacional e da priorização de sprint.

## 9. `07_Risks_Open_Decisions.md`

- **Tipo:** riscos, mitigações e decisões futuras.
- **Função:** registrar riscos reais e impedir escalada prematura.
- **Decisões principais:** matriz de riscos (toggle parecer IA, Score arbitrário, Competition duplicar Signals, Example "no olho", amostra pequena, intenção inflada, alucinação de nome, marketplace cedo demais); decisões futuras condicionadas (query 1/dia, Redis/Celery, plano pago, marketplace, sub-perfis, data lake, ML); kill criteria; pivot options; regra final "não escalar complexidade antes de provar comportamento".
- **Riscos/atenção:** este é o catálogo de armadilhas. Usar como checklist de "não fazer".
- **Uso pelo Orchestrator:** alimenta a seção Risks de toda resposta operacional e os Escalation Rules.

## 10. `NOXUND_Hotspot_Arquitetura_de_Agentes.md`

- **Tipo:** arquitetura de agentes + briefing ao Product Lead (AI Systems Architect).
- **Função:** detalhar a separação zona determinística × zona generativa e o catálogo de agentes.
- **Decisões principais:** tabela de duas zonas; entrada/saída/auditoria por agente; IA só no Agente 3 e blindada; 7 estratégias anti-alucinação; MVP vs Fase 2; cinco itens a remover por falta de metodologia (cálculo no olho, fake realtime, Example subjetivo, Competition duplicando Signals, insight de IA).
- **Riscos/atenção:** reforça que mesmo no MVP a aritmética dos Agentes 5–6 é por código, não à mão.
- **Uso pelo Orchestrator:** referência técnica de governança da credibilidade analítica.

## 11. `Relatório Estratégico de Posicionamento — NOXUND.md`

- **Tipo:** relatório estratégico de mercado/posicionamento.
- **Função:** justificar a estratégia "crescer pelas sombras" e o cavalo de Troia (ferramenta antes de marketplace).
- **Decisões principais:** não construir marketplace primeiro; concentrar oferta de elite num sub-gênero (rede atômica); inteligência de mercado como diferencial defensável; tier list de posicionamento (Tier S = ferramenta de inteligência disfarçada de marketplace premium).
- **Riscos/atenção:** ⚠️ **Tensão de vertical** — este relatório recomenda **Jersey Club/plugg** como rede atômica preferida; o Product Lead **travou Chicago Drill** (`00_...` §3). A decisão travada vence. Ver `OPEN-DECISION` em `scope-guardrails.md`. Números de mercado são proxies/ordens de grandeza, com caveats próprios.
- **Uso pelo Orchestrator:** contexto estratégico do "porquê"; nunca usar para reabrir escopo travado sem decisão registrada.

## 12. `Head of Product.md`

- **Tipo:** placeholder.
- **Função:** indefinida — arquivo **vazio (0 bytes)**.
- **Decisões principais:** nenhuma.
- **Riscos/atenção:** ⚠️ `OPEN-DECISION` — conteúdo ausente. Pode ser conteúdo pendente ou arquivo órfão.
- **Uso pelo Orchestrator:** não tratar como fonte. Pedir ao Product Lead o conteúdo pretendido ou remover.

---

## Hierarquia de fontes de verdade

Em caso de conflito entre documentos, a ordem de prioridade é:

1. `00_Product_Lead_Decision_Log.md` (decisões travadas)
2. `01_MVP_Scope_PRD.md` (escopo funcional)
3. `03_Data_AI_Agents_Methodology.md` + `04_Database_Event_Model.md` (metodologia e dados)
4. `02_...`, `05_...`, `06_...`, `07_...` (stack, GTM, execução, riscos)
5. `NOXUND_Hotspot_Arquitetura_de_Agentes.md` + `Relatório Estratégico` (arquitetura e contexto estratégico)

Conflito real entre níveis → `OPEN DECISION` + escalation ao Product Lead.
