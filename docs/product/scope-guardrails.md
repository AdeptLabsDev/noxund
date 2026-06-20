# Scope Guardrails — NOXUND MVP

**Mantido por:** Product Orchestrator Agent
**Função:** régua binária de "entra / não entra". Em dúvida, este arquivo + o decision log decidem.

Fonte: `00_Product_Lead_Decision_Log.md`, `01_MVP_Scope_PRD.md` §9/§11, `02_...` §11, `06_...` §6, `07_...` §5.

---

## Entra no MVP

- Landing/apply page **noindex**, fechada, premium, sem promessa de IA mágica.
- Formulário de aplicação curto (nome, email, YouTube, portfólio opcional, nicho, 2 perguntas de decisão).
- Aprovação **manual** de produtores (estados de aplicação).
- Auth gate — só produtor aprovado acessa `/app/report`.
- **Dois relatórios fixos**, 10 artistas cada, 2 HOT cada.
- Keyword **travada** `chicago drill type beat`, janela 30 dias, ~500 vídeos por `run_id`.
- Tabela com **Title, Tag (HOT), Score (`X/100`, só se > 83), Signals, Velocity, Competition, Example**.
- HOT se `Score > 90`; Competition por **canais distintos** (Low ≤5 / Medium 6–15 / High >15 ou +50% em 7d).
- Example por **regra determinística** (top-3 velocity → mais recente → maior views).
- Botão de alternância **honesto** ("Ver outro grupo de oportunidades" / "Relatório 1 de 2").
- Ações por linha: `Útil`, `Não útil`, `Vou produzir para esse artista`.
- Eventos de produtor (log, não flags) — todos os tipos do `04_...` §8.
- Follow-up 10–14 dias (scheduler + envio email/DM manual + captura de resposta).
- WTP (sim/não/talvez + faixa opcional).
- Score **determinístico, versionado, auditável, reproduzível** (rubric 40/25/20/15).
- Raw imutável + computed reconstruível + report snapshot congelado.
- Auditoria por célula (Score, Velocity, Signals, Competition, Example, artist name).
- Admin mínimo: aplicações, status, publicar relatório, métricas.
- Observabilidade: eventos de produto + erros técnicos (Sentry).

### Entra como P1 (se não atrasar P0)

- Dashboard admin bonito; export CSV; PostHog; filtros visuais; animações premium; tooltips extras; convite por email automatizado.

---

## Não entra no MVP

- Marketplace, checkout, carrinho, pagamentos, Stripe/Stripe Connect.
- Upload/download de beats, arquivos de áudio, processamento de áudio, storage privado.
- Licenças, contratos, split automático, payouts, cupons.
- Perfis públicos de produtores, sub-perfis/beatmaker names em produção, storefronts.
- Busca pública de beats, marketplace público, landing indexável.
- Múltiplos nichos, múltiplas keywords.
- Query sob demanda / 1-query-por-dia (é teatro de produto no MVP).
- Relatório gerado em tempo real; qualquer copy que sugira geração/IA ao vivo ("Re-Gen", "Generate again", "New AI analysis").
- IA generativa calculando ou exibindo número (Score, Velocity, Signals, Competition, ranking, Example).
- Insight textual gerado por IA sobre artistas no relatório.
- Análise histórica além de 30 dias; trendline multi-mês.
- Data lake diário; rastreio diário de todos os artistas.
- Exposure penalty; ML scoring.
- Redis/Celery como bloqueador; FastAPI persistente obrigatório.
- S3/R2, CDN de áudio, Elasticsearch/Meilisearch, Rust services, microservices reais.
- Tabelas de marketplace no banco (`beats`, `orders`, `payouts`, `licenses`, `carts`, etc.).
- Ads pagos massivos, SEO aberto, Product Hunt, "AI hype".

---

## Entra apenas na Fase 2 (ou posterior)

Condicionado aos critérios de avanço (`00_...` §14, `07_...` §5):

- Pipeline dos 6 agentes orquestrado ponta a ponta.
- Query real sob demanda (limite 1/dia).
- Novos subgêneros / multi-keyword (fan-out).
- Relatórios semanais.
- Cobrança / plano beta pago (só com WTP ≥ 25% + follow-up real).
- Exposure management (com fórmula documentada, versionada, auditável).
- Data lake seletivo (só com necessidade real de tendência histórica).
- ML scoring (só com volume de `producer_outcomes` + `model_version` + `feature_snapshot_id` + dataset versionado).
- Redis/Celery + FastAPI persistente (quando jobs recorrentes virarem gargalo).
- Camada de sub-perfis de produtores.
- Marketplace curado (só com base de produtores elite engajada).

---

## Decisões que exigem Product Lead

Parar e escalar (não decidir sozinho) quando houver:

- conflito entre documentos de `/context`;
- proposta de feature fora do MVP;
- mudança de stack;
- mudança no posicionamento / headline / promessa pública;
- mudança nos critérios de sucesso ou kill criteria;
- qualquer reabertura de decisão travada no `00_...`.

---

## Decisões que exigem Security Review

- qualquer endpoint novo ou mudança de exposição de rota;
- auth, sessão, roles, approval gate;
- manuseio de secrets / API keys (YouTube, email, Supabase service role);
- Row Level Security e políticas de acesso;
- logs (garantir ausência de tokens/keys/dados sensíveis);
- webhook/cron interno protegido por secret.

---

## Decisões que exigem Data/AI Review

- mudança no rubric, pesos ou versão do Score;
- mudança na coleta dos 500 vídeos (keyword, janela, volume, paginação);
- mudança na regra de Competition, Signals, Velocity ou seleção de Example;
- mudança no Entity Resolution (regex, uso de LLM, guardrails, fila de revisão);
- qualquer alteração que afete reprodutibilidade ou auditoria por célula;
- alterações destrutivas no banco / migrations que toquem raw ou computed.

---

## OPEN DECISIONS conhecidas

| ID | Tema | Estado | Encaminhamento |
|---|---|---|---|
| OD-01 | **Vertical:** Relatório Estratégico sugere Jersey Club/plugg; Product Lead travou Chicago Drill. | **Resolvida a favor de Chicago Drill** (`00_...` §3). Registrada por rastreabilidade. | Só reabrir via decisão do Product Lead. |
| OD-02 | **Auth:** Supabase Auth vs Clerk. | **Resolvida → Supabase Auth** (DEC-0005, confirmada pelo Product Lead 2026-06-20). Coerente com LD-12 (stack) e SEC-D01 (`auth.users`/`auth.uid()`). | Fechada. |
| OD-03 | **Email provider:** Resend vs Postmark. | Em aberto. | Confirmar antes da Sprint 2 (follow-up). |
| OD-04 | **Cron:** Vercel Cron vs Supabase Scheduled Functions. | Em aberto. | Confirmar antes da Sprint 2. |
| OD-05 | **FastAPI:** script/worker vs serviço. | Script/worker Python no MVP. | Reavaliar só se virar serviço. |
| OD-06 | **Local de registro de decisões:** `decisions/` (1 arquivo) vs `DECISIONS.md`. | Proposto `docs/product/decisions/<id>.md` (DEC-0001). | Confirmar com Product Lead. |
| OD-07 | **`Head of Product.md` vazio** em `/context`. | Conteúdo ausente. | Pedir conteúdo ao Product Lead ou remover. |

---

## Entra na fundação técnica

- Next.js;
- TypeScript;
- Tailwind CSS **v4** (CSS-first, `@theme`) — sistema monocromático sem acento (DEC-0002; ver `docs/agents/frontend-agent.md`);
- pnpm workspace;
- Python data-engine scaffold;
- shared package scaffold;
- `.env.example`;
- `.gitignore`;
- README operacional.

## Não entra na fundação técnica

- Fastify;
- `apps/api`;
- GSAP;
- Framer Motion;
- Redis;
- Celery;
- Stripe;
- Supabase schema real;
- YouTube API real;
- marketplace;
- ML scoring;
- data lake.

## Decisões que exigem Product Orchestrator

- criar API Node separada;
- trocar Tailwind;
- adicionar biblioteca de animação;
- adicionar UI framework pesado;
- criar endpoints reais;
- iniciar schema do banco;
- conectar YouTube API;
- alterar copy de promessa do produto.
