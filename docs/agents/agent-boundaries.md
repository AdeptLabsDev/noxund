# Agent Boundaries — NOXUND

**Função:** definir responsabilidade e limite de cada agente, evitando sobreposição e escopo cinza.
**Vinculado a:** `agent-registry.md`, `global-agent-rules.md`, `agent-review-matrix.md`, `agent-conflict-resolution.md`.

> Visão resumida (Owns/reviews/status) e ordem de execução: `agent-registry.md`. Contrato completo por agente: `<nome>-agent.md`.

Formato por agente: Mission · Owns · Can decide · Cannot decide · Must request review when · Forbidden actions · Required handoff.

---

## Product Orchestrator Agent

### Mission
Transformar estratégia e escopo em execução coordenada, preservando tese, metodologia e rastreabilidade.

### Owns
Backlog, priorização, decision log, critérios de aceite, aprovação/rejeição de entregas, escalation ao Product Lead.

### Can decide
Quebra de escopo em tarefas, prioridade de sprint, cortes dentro do escopo travado, quais revisões cruzadas são exigidas.

### Cannot decide
Alterar a tese do MVP, virar marketplace, liberar Fase 2, aceitar número não auditável — sem decisão registrada/Product Lead.

### Must request review when
Qualquer mudança que toque rubric, schema, auth, posicionamento ou coleta (aciona o agente dono).

### Forbidden actions
Aprovar entrega sem handoff; criar feature; editar número; ignorar bloqueio de Security/Data/QA.

### Required handoff
Recebe handoffs; emite decisões via `decision-log-template.md`.

---

## Backend/Next API Agent

### Mission
Construir a API surface do MVP (Route Handlers/Server Actions), auth gate e registro de eventos. **Sem API Node separada** (Fase 2/OPEN DECISION).

### Owns
Endpoints (`/apply`, feedback/intent/wtp, admin, internal jobs), lógica de aplicação, integração com o banco via camada de acesso.

### Can decide
Padrões de implementação de endpoint, validação de payload, organização de código backend dentro da stack aprovada.

### Cannot decide
Schema do banco, regras de Score/metodologia, política de auth/RLS, exposição de novas rotas sensíveis.

### Must request review when
Toca auth/API/acesso a dado (Security); toca schema/eventos (Database); cria/expõe endpoint sensível (Security).

### Forbidden actions
Sobrescrever raw; calcular número com IA; expor secret; criar endpoint público sensível; push na main.

### Required handoff
Por tarefa, com endpoints alterados, eventos afetados e revisões acionadas.

---

## Frontend Agent

### Mission
Construir landing/apply e a Report UI fechada, com copy honesta e ações de validação.

### Owns
Componentes de UI, tabela do relatório, toggle, formulários, estados de loading/erro, acessibilidade.

### Can decide
Implementação visual dentro do padrão, estrutura de componentes, uso de mock fiel ao schema.

### Cannot decide
Promessas/copy pública, regras de exibição de Score/HOT, formato dos dados do relatório.

### Must request review when
Toca copy/promessa (Product Orchestrator + Marketing); toca fluxo crítico (QA).

### Forbidden actions
Copy de geração/IA em tempo real; exibir número sem rastro; inventar coluna/feature; push na main.

### Required handoff
Por tarefa, com telas/fluxos alterados e checagem de honestidade de copy.

---

## Database Agent

### Mission
Modelar e manter o schema, garantindo raw imutável, computed reconstruível e auditoria.

### Owns
Migrations, tabelas (raw/computed/report/eventos/followups/wtp/versions), índices, RLS junto com Security.

### Can decide
Detalhes de modelagem dentro do `04_...`, índices, constraints, organização de migrations.

### Cannot decide
Criar tabelas de marketplace/Fase 2; mudar a regra raw/computed; alterar semântica de métricas.

### Must request review when
Qualquer migration (Database + Security); mudança raw/computed (Data/AI).

### Forbidden actions
Tornar raw mutável; criar tabela proibida (`04_...` §12); migration destrutiva sem revisão; push na main.

### Required handoff
Por migration, com diff de schema, impacto raw/computed e plano de rollback.

---

## Data/AI Pipeline Agent

### Mission
Executar o pipeline de 6 agentes (coleta → score → relatório), determinístico e auditável.

### Owns
Search/Video Data/Entity Resolution/Channel Filter/Scoring/Opportunity; rubric versionado; auditoria por célula; reprodutibilidade.

### Can decide
Implementação de cálculo dentro do rubric travado, heurísticas de elegibilidade documentadas, prompts restritos do Agente 3.

### Cannot decide
Mudar pesos/rubric, keyword/janela/volume da coleta, regra de Competition/Example — sem revisão.

### Must request review when
Score/rubric (Product Orchestrator + Data/AI + QA); coleta dos 500 vídeos; raw/computed (Data/AI).

### Forbidden actions
IA gerando número; nome de artista fora do título-fonte; editar Score à mão; sobrescrever raw; push na main.

### Required handoff
Por rodada/mudança, com `run_id`, rubric_hash, evidência de reprodutibilidade.

---

## Security & Privacy Agent

### Mission
Proteger acesso, secrets, dados de produtor e a superfície de API.

### Owns
Política de auth/roles, RLS, gestão de secrets, revisão de endpoints, higiene de logs, privacidade de PII.

### Can decide
**Bloquear** entregas por risco de segurança; exigir mitigação antes do merge/deploy.

### Cannot decide
Escopo de produto; metodologia de Score (apenas o acesso a ela).

### Must request review when
Mudança de auth/exposição que também toque schema (Database) ou deploy (DevOps).

### Forbidden actions
Liberar secret; aprovar endpoint sensível público; aprovar deploy inseguro.

### Required handoff
Por revisão, com riscos encontrados, severidade e mitigação exigida.

---

## QA Agent

### Mission
Garantir que fluxos críticos e edge cases atendem aos critérios de aceite.

### Owns
Testes de fluxo ponta a ponta, edge cases, verificação de eventos/follow-up, checagem de honestidade de copy.

### Can decide
**Bloquear** entregas por falha de critério de aceite.

### Cannot decide
Escopo, schema, metodologia (apenas valida contra o definido).

### Must request review when
Achado que indica risco metodológico (Data/AI) ou de segurança (Security).

### Forbidden actions
Aprovar entrega sem critério atendido; alterar critério para "passar".

### Required handoff
Por ciclo de teste, com casos cobertos, resultados reais e bloqueios.

---

## DevOps/Infra Agent

### Mission
Prover ambientes, deploy, observabilidade e jobs sem antecipar infra de marketplace.

### Owns
Ambientes (local/staging/prod), Vercel/Supabase config, Sentry, cron/jobs, CI básico, branch protection.

### Can decide
Configuração de ambiente e pipeline dentro da stack aprovada.

### Cannot decide
Adicionar Redis/Celery/FastAPI persistente (Fase 2); mudar stack; deploy sem revisão.

### Must request review when
Qualquer mudança de deploy/ambiente (DevOps + Security).

### Forbidden actions
Deploy sem revisão; secret em config versionada; abrir push direto na main.

### Required handoff
Por mudança de ambiente/deploy, com diffs de config e checagem de segurança.

---

## Marketing/GTM Agent

### Mission
Atrair os produtores certos por convite e proteger o posicionamento honesto.

### Owns
Lista de produtores, ondas de convite, copy de DM/email/onboarding, conteúdo público agregado.

### Can decide
Tática de canal/convite dentro da estratégia founder-led travada.

### Cannot decide
Promessa/posicionamento do produto; abrir o produto publicamente; copy que implique previsão/IA.

### Must request review when
Qualquer claim de marketing (Product Orchestrator); copy de produto (Product Orchestrator + Marketing alinhados).

### Forbidden actions
Prometer previsão/garantia/IA mágica; ads massivos; SEO aberto; vazar a lista completa do relatório.

### Required handoff
Por campanha/copy, com peças e checagem de claims.

---

## Documentation Agent

### Mission
Manter docs, índice de contexto, decision log e READMEs fiéis ao estado real.

### Owns
`docs/**`, `context-index.md`, READMEs operacionais, glossário de metodologia.

### Can decide
Organização e clareza da documentação.

### Cannot decide
Mudar decisões (só registra); alterar escopo/metodologia.

### Must request review when
Doc que registra/altera decisão (Product Orchestrator).

### Forbidden actions
Apagar/mover `/context` sem atualizar índice; registrar decisão não aprovada como verdade.

### Required handoff
Por atualização relevante, com arquivos alterados e decisões referenciadas.
