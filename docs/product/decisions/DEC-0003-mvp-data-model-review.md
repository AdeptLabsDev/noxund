## DEC-0003 — Review do Modelo de Dados do MVP (proposta do Database Agent)

- **Data:** 2026-06-20
- **Status:** Aprovada (parcial) — Data/AI ratificou OD-DB-01/04/06/07; itens condicionados a Security/Backend marcados abaixo
- **Decisor:** Product Orchestrator (itens OD-DB-02/03/05/01); Security mantém veto nos itens indicados, Backend segue como revisão pendente de consumo/handlers
- **Área:** Schema
- **Prioridade/Impacto:** Alto

### Contexto
O Database Agent entregou a proposta de modelo de dados do MVP em `docs/database/` (`README.md`, `mvp-data-model.md`, `entity-relationship-notes.md`, `migration-plan.md`, `rls-review-notes.md`). É **proposta** — nenhuma migration, nenhum schema real no Supabase, nenhum commit. A proposta mantém `04_Database_Event_Model.md` como canônico e levanta 8 decisões abertas (OD-DB-01..08). Quatro foram encaminhadas ao Product Orchestrator: OD-DB-01, 02, 03, 05. Esta entrada registra o veredito do Product Orchestrator sobre elas e confirma que **nada na proposta toca Fase 2** (`04_...` §12, `scope-guardrails`).

### Decisão
1. **OD-DB-02 — Nome `producer_events` vs `producer_outcomes`: manter `producer_events`** (canônico `04_...` §8). "producer_outcomes" fica como sinônimo conceitual documentado. Razão: o nome já está cravado nas queries de métrica (`04_...` §13) e referenciado por Backend/backlog. **Aprovada (autoridade do PO).**
2. **OD-DB-05 — Nomes de `event_type`: manter os canônicos de `04_...` §8** (`intent_to_produce_declared`, `followup_confirmed_produced`, `followup_confirmed_not_produced`). Os nomes da tarefa (`production_intent_declared`, `followup_answered_yes/no`) ficam só como aliases de documentação, **nunca** como valores do enum. Razão: as métricas-norte de validação (`04_...` §13) fazem match exato por string; renomear quebraria silenciosamente a medição. **Aprovada (PO); Data/AI confirma — uso confirmatório, já são os nomes do pipeline.**
3. **OD-DB-03 — Criar `audit_events` no MVP: aprovado.** Tabela append-only de proveniência de ações humanas/operacionais (aprovação, publicação, overrides). Fortalece o non-negotiable de rastreabilidade total e fecha o requisito #15 da tarefa. **Não é tabela de marketplace** e não adiciona superfície de produto. **Condição:** RLS restrita a `admin`/`service_role` é de fechamento do **Security Agent** (co-owner de RLS, com veto) antes da migration (Fase 8 do `migration-plan.md`). **Aprovada (condicional ao Security).**
4. **OD-DB-01 — Split `report_runs` → `collection_runs` + `scoring_runs`: manter o modelo unificado de `04_` no MVP; não fazer o split agora.** Para 2 relatórios fixos o modelo unificado **já** satisfaz a reprodutibilidade (`04_...` §14): o raw é ancorado por `run_id` e o computed carrega seu próprio `rubric_version`/`rubric_hash`, então re-score do mesmo raw sob novo rubric já é possível recomputando `artist_metrics` no mesmo `run_id`. O split é complexidade prematura (YAGNI) e desvia do canônico. **Requisito:** o schema não pode cravar premissas que impeçam um split futuro. **Data/AI ratificou** a reprodutibilidade por célula sem split em `docs/database/DATA-AI-REVIEW-mvp-data-model.md`, com chave lógica de `artist_metrics` em `(run_id, artist_id, rubric_hash)`.

### Alternativas consideradas
- **OD-DB-01 separar runs agora** — mais limpo semanticamente, mas adiciona uma tabela + indireção de FK para resolver um problema que o MVP (2 relatórios) não tem; desvia de `04_`. (não agora)
- **OD-DB-02/05 adotar os nomes da tarefa** — alinharia ao texto da tarefa, mas quebraria as queries de métrica de `04_...` §13 e a consistência com Backend. (não)
- **OD-DB-03 adiar `audit_events`** — confiar nas colunas espalhadas de `04_` (`reviewed_by`, `human_override`, `reviewed_by_human`). Barato adiar, mas deixa a proveniência de ação humana implícita e incompleta; criar é barato e fecha o requisito #15. (não — criar)

### Justificativa
Preserva a tese e os non-negotiables: rastreabilidade total (`audit_events` + cadeia `run_id`/`rubric_hash`/`computed_from_video_ids`), reprodutibilidade (mantida no modelo unificado), métricas de validação intactas (nomes de evento canônicos). Mantém o MVP enxuto (sem tabela extra sem necessidade real) e fiel a `04_` como fonte de verdade. Zero vazamento de Fase 2.

### Impacto
- **Escopo:** nenhum. Nenhuma feature nova; nenhuma tabela de marketplace (`04_...` §12) — verificado nas 19 tabelas propostas.
- **Non-negotiables:** reforçados (rastreabilidade, reprodutibilidade, eventos-não-flags, raw imutável, snapshot congelado). Nenhum violado.
- **Documentos a atualizar:** `docs/database/README.md` e `docs/database/mvp-data-model.md` (status de revisão do PO + tabela de open decisions). `04_` permanece canônico; refinos (`audit_events`, `report_items.artist_metric_id`, `artist_metrics.metrics_detail_json`) são aditivos sobre ele e ficam rastreados aqui.
- **Tarefas afetadas:** tarefa de proposta de modelo de dados (Database Agent); destrava redação do handoff e o roteamento das revisões restantes.

### Reversibilidade
Alta — é proposta em docs, sem migration. OD-DB-01 é explicitamente reabrível por demonstração do Data/AI. Renomeações de evento (OD-DB-05) seriam caras depois que houver dados de evento, por isso travadas agora nos nomes canônicos.

### Revisões necessárias
- [x] Product Orchestrator (OD-DB-01/02/03/05)
- [~] Security — **revisado: aprovação condicional, veto mantido sobre Fase 9 (RLS)/endpoints/pré-produção** (`docs/security/SEC-0001-mvp-data-model-review.md`). Fechou OD-DB-08 (`auth_user_id` FK, não `id=auth.uid()`), role admin (`admin_users` + `is_admin()`), imutabilidade raw/audit por trigger. Condições bloqueantes: SEC-F01 (service-role bypassa RLS → authz em código), SEC-F02 (mass-assignment no `/apply`), SEC-F03 (exposição de coluna interna ao produtor) — **tem veto**
- [x] Data/AI — aprovado em `docs/database/DATA-AI-REVIEW-mvp-data-model.md`: raw/computed, proveniência por célula, reprodutibilidade sem split (OD-DB-01), OD-DB-04/06/07
- [ ] Backend — formato consumível por endpoints, escrita atômica evento+payload (WTP/followup), OD-DB-06
- [ ] QA — incluído quando houver migration/critério testável (matriz #3)

### Follow-up
Database Agent prepara o handoff (`docs/agents/handoff-template.md`) incorporando esta DEC e o roteamento de revisões. Data/AI já fechou seus itens metodológicos; **nenhuma migration** abre antes de Security ter as mitigações no desenho (matriz #3) e da revisão aplicável de Backend quando endpoint/consumo for tocado. Primeira migration real recomendada: Fase 1 (`producers` + `applications`) com revisão Database + Security, só após OD-02 (Auth) confirmada.
