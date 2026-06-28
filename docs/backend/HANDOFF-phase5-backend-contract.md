# Handoff — `task_phase5_backend_api_contract` · Contrato de consumo `report_items`/`artist_metric_id` · Backend Agent

## 1. Identificação
- **Tarefa:** `task_phase5_backend_api_contract` · **Action:** `create_api_contract` (não-sensível; sem apply, sem DDL, sem código de prod, sem número gerado)
- **Owner agent:** Backend/Next API (`backend_agent`)
- **Data:** 2026-06-27
- **Prioridade:** high
- **Vereditos de referência:** `docs/security/SEC-0014-...` (Security ✅ matrix #3) · `docs/database/HANDOFF-phase5-design.md` (Database, autor) · `docs/backend/BE-0001-...` §3.3 (compromisso SEC-F03 anterior)

## 2. Objetivo
Desenhar o **contrato de consumo** do snapshot (`report_items`) e da proveniência (`artist_metric_id`) **sem** auto-expandir escopo e **sem** implementar a superfície pública (Fase 9, vetada): mapear colunas públicas vs internas, provar que a exibição do produtor não usa colunas cruas (SEC-F03), preservar a rastreabilidade até o raw e **deferir** a VIEW/policy à Fase 9.

## 3. Critério de aceite (do `TaskCommand`)
Contrato público vs interno documentado (prova SEC-F03); leitura do produtor deferida à VIEW da Fase 9 (nenhuma VIEW/RLS criada); rastreabilidade preservada (`artist_metric_id → artist_metrics → artist_metric_videos → raw`; HOT>90/score>83 como formatação sobre número congelado); zero expansão de escopo; `next_recommendation` para DevOps → Security audit_secrets → run_migration gated.

## 4. Resultado
- [x] Critério de aceite atendido
- [x] Demonstrável (como verificar): ler `docs/backend/BE-0002-phase5-report-items-consumption-contract.md` — §1 (superfície pública/DTO), §2 (colunas internas), §3 (prova SEC-F03), §4 (formatação sobre número congelado), §5 (rastreabilidade), §7 (deferimento Fase 9).

**Entregue o contrato em `BE-0002`:** a superfície do produtor é uma **projeção pura de 9 colunas congeladas** de `report_items`; **nenhuma** deriva de `score_value`/`raw_score`/`final_score`/`metrics_detail_json`/`selection_reason_json`. As regras de exibição (HOT>90, score>83) são **formatação materializada no publish** pelo data-engine e lidas verbatim — Backend não recalcula, IA não toca número. A leitura do produtor fica **deferida** à VIEW da Fase 9 (sob veto): contrato define o shape, não cria VIEW/RLS/grant.

## 5. Arquivos alterados
- `docs/backend/BE-0002-phase5-report-items-consumption-contract.md` — contrato de consumo (novo).
- `docs/backend/HANDOFF-phase5-backend-contract.md` — este handoff (novo).

*(Nenhum schema, migration, VIEW, RLS policy, grant ou código de prod tocado — fora da alçada do Backend e desta tarefa. Nenhum número gerado.)*

## 6. Impacto no escopo
- **Mantém o MVP travado?** Sim. Sem marketplace/checkout/upload; sem API Node separada; sem query/real-time; sem endpoint público novo.
- **Toca non-negotiable?** Reforça: SEC-F03 (coluna interna nunca ao produtor), número sempre determinístico/rastreável até o raw, copy honesta (sem Re-Gen).
- **Toca número/banco/auth/copy pública?** Não gera número; não altera schema; não cria auth/RLS; não escreve copy pública. **Define** o shape que a Fase 9 (auth/RLS/VIEW) terá de honrar → revisão Security na Fase 9.

## 7. Validação executada
- Revisão linha-a-linha do DDL `report_items` (L367-414), `artist_metrics` (L259-294), `artist_metric_videos` (L304-321): confirmado que as 9 colunas públicas existem congeladas e que as FKs compostas sustentam a cadeia até o raw.
- Cruzamento com PRD §5 (colunas/regras), SEC-0001 L59 (SEC-F03), SEC-0014 §3/§5 (carry-forward), BE-0001 §3.3 (compromisso anterior).
- **Sem apply, sem execução de SQL** (apply é gated; sem Postgres conectado). Contrato documental — **sem commit** (conforme protocolo de governança).

## 8. Riscos
- **SEC-F03 (Alta) — vazamento de coluna.** Mitigado por construção: read = projeção pura das 9 públicas; `score_value` (persistido mesmo quando `score_display` é null) nunca no read-path. Trava real está na VIEW da Fase 9.
- **Materialização no publish.** O contrato depende de o data-engine congelar `tag`/`score_display`/`velocity_display`/`example_url` no publish (DDL tem as colunas). Se o publish não materializar, a regra de exibição não tem fonte congelada → fica a cargo do data-engine/P5-REPRO-01 (gate de publish, fora deste apply).
- **Fase 9 sob veto.** Implementar a VIEW/read antes do veto cair seria violação — explicitamente deferido (§7 do BE-0002).

## 9. Revisões necessárias
- [x] **Security** — SEC-0014 já baixou matrix #3 sobre o DDL/verify; SEC-F03 carry-forward endossado. A VIEW da Fase 9 exigirá novo re-review do Security (veto SEC-0001 §0 segue de pé).
- [ ] **DevOps** — autorar `phase5-db-apply.yml` (espelhar Fases 1–4; verify fail-closed; gate humano + required reviewers).
- [ ] **Security** — `audit_secrets` (matrix #8, delta) sobre o pipeline novo.
- [ ] **Database** — só se um achado mostrasse que o schema não suporta o contrato sem expor interno (**não é o caso** — BE-0002 §3).

## 10. Próximos passos
1. **DevOps:** `define_pipeline` → `phase5-db-apply.yml`.
2. **Security:** `audit_secrets` (#8 delta) no pipeline.
3. **`run_migration` gated por último** (humano + required reviewers em CI), em task separada.
4. **Fase 9** (RLS Policies + VIEW pública de `report_items`) permanece **vetada** (SEC-0001 §0) — este contrato **não** a destrava; quando abrir, Backend implementa a VIEW no shape de BE-0002 §1 + read endpoint com authz de BE-0001 §1.2.
5. **Backfill DATA-AI-0007** segue recomendado em paralelo (Security/Data) — não bloqueia.

## 11. Open decisions / bloqueios
| ID | Tema | Status | Encaminhamento |
|---|---|---|---|
| Fase 9 | VIEW pública de `report_items` + RLS policy (SEC-F03) | ⛔ **vetada** (SEC-0001 §0) | shape definido em BE-0002 §1; implementação só pós-veto |
| `selection_reason` público sanitizado | shape público opcional (BE-0001 §3.3.4) | **fora do DTO mínimo** | decisão de produto/Frontend/Security na Fase 9 (BE-0002 §7) |
| DATA-AI-0007 | backfill da aprovação Data/AI (só no AgentResult) | recomendado, paralelo | Security/Data — não bloqueia |
| P5-REPRO-01 | prova de 2 rodadas (publish/data-engine) | gate de publish | fora deste apply (HANDOFF-phase5 §12) |

**Bloqueios ativos:** Fase 9 vetada (SEC-0001 §0); `run_migration` gated por último. Contrato de consumo **fechado** por este handoff — superfície do produtor incapaz, por construção, de vazar coluna interna (SEC-F03).
