# Handoff — [BE] Review de consumibilidade + contrato de authz · Backend Agent

## 1. Identificação
- **Tarefa:** [BE] Review de consumibilidade dos endpoints + contrato de authz (Épico 3 — Backend/API; revisão + compromisso de desenho, sem código)
- **Owner agent:** Backend/Next API
- **Data:** 2026-06-20
- **Prioridade:** P0
- **Vereditos de referência:** `docs/security/SEC-0001-mvp-data-model-review.md` (Security) · `docs/database/HANDOFF-mvp-data-model.md` (Database) · `docs/product/decisions/DEC-0003-mvp-data-model-review.md` (PO)

## 2. Objetivo
Revisar se o modelo de dados proposto serve a API surface do MVP (`02_` §7) e assumir, como contrato de implementação, as condições "Alta"/"Baixa" do SEC-0001 cuja mitigação é de handler (SEC-F01/F02/F03/F11), além de confirmar a escrita atômica evento+payload.

## 3. Critério de aceite (do backlog)
Backend confirma que o modelo serve os endpoints e assume SEC-F01/F02/F03/F11 como contrato de implementação (não-negociável antes da Fase 1/9). DevOps acionado por Backend para SEC-F10 (Sentry scrub) e SEC-F11 (secret do cron).

## 4. Resultado
- [x] Critério de aceite atendido
- [x] Demonstrável (como verificar): ler `docs/backend/BE-0001-consumability-authz-contract-review.md` — §1 (matriz de consumibilidade), §3 (contrato SEC-F01/F02/F03/F11), §4 (atomicidade), §5 (revisões acionadas).

Entregue a revisão em `docs/backend/BE-0001-...`: **o modelo serve todos os endpoints de `02_` §7**; Backend **assume** SEC-F01/F02/F03/F11 como desenho dos handlers; **escrita atômica confirmada** (WTP, intenção, aprovação) via função RPC; **5 achados** de consumibilidade (4 de implementação, 1 gap na API surface).

## 5. Arquivos alterados
- `docs/backend/BE-0001-consumability-authz-contract-review.md` — revisão + contrato de authz (novo).
- `docs/backend/HANDOFF-consumability-authz-review.md` — este handoff (novo).

*(Nenhum schema, migration, RLS ou código tocado — está fora da minha alçada e desta tarefa.)*

## 6. Impacto no escopo
- **Mantém o MVP travado?** Sim. Nada de Fase 2, nenhuma API Node separada (Route Handlers/Server Actions só), nenhum cálculo de número.
- **Toca non-negotiable?** Reforça: authz em código (anti-IDOR), approval gate (anti mass-assignment), Score escondido (≤83) nunca vaza ao produtor.
- **Toca número/banco/auth/copy?** Auth/endpoints/RLS (matriz #3 → Security) e eventos/funções RPC (matriz #2 → Database). Por isso aciono os dois.

## 7. Validação executada
- Revisão documental cruzada: `02_` §7 ↔ `04_` (§3–§13) ↔ `mvp-data-model.md` ↔ `SEC-0001` ↔ `rls-review-notes` ↔ `migration-plan`. Cada rota de `02_` §7 mapeada a tabelas/colunas/eventos/authz (§1 do BE-0001).
- Atomicidade WTP/intenção conferida contra o modelo (`wtp_responses` + `producer_events`; `followups.producer_event_id`). Mecanismo definido (RPC `plpgsql`) por limitação per-statement do PostgREST.
- Sem código/migration — revisão de proposta. **Sem commit** (conforme instrução).

## 8. Riscos
- **SEC-F01 (Alta) — IDOR.** Se `producer_id` vier do cliente em vez da sessão, produtor A forja evento/WTP/intent como B. Contrato: `producer_id` sempre da sessão. Trava Fase 1/9.
- **SEC-F02 (Alta) — mass-assignment no `/apply`.** Whitelist estrita + `status` forçado; sem isso, aplicante fura o approval gate (tese de validação). Trava Fase 1.
- **SEC-F03 (Alta) — vazamento de coluna.** Leitura só por VIEW; `score_value`/`raw_score`/json interno nunca ao produtor — senão o Score escondido (≤83) vaza. Trava Fase 9.
- **SEC-F11 (Baixa) — `/internal/*`.** Secret + constant-time + 404. Trava endpoints internos.
- **Gap §2-E:** `02_` §7 não tem rota de captura da resposta do follow-up → métrica "Confirmação em follow-up" fica sem caminho de entrada. Sobe ao PO.
- **OD-02 (Auth) aberta** é o gargalo real da Fase 1: `auth_user_id` e o `/apply` pós-aprovação dependem dela.

## 9. Revisões necessárias
- [x] **Security & Privacy** — Backend assume SEC-F01/F02/F03/F11; re-review do Security cai com evidência (handlers + testes) antes da Fase 9. Veto do Security permanece até lá.
- [ ] **Database** — funções RPC atômicas (`fn_record_wtp`, `fn_declare_intent`, `fn_record_feedback`, `fn_decide_application`) + resolução `report_item_id`; matriz #2.
- [ ] **Frontend** — `selection_reason` sanitizado (shape público da VIEW) e seletor de relatório (§2-B); microcopy.
- [ ] **Product Orchestrator** — achado §2-E (rota de resposta do follow-up em `02_` §7); confirmar OD-02 com Product Lead.
- DevOps acionado para **SEC-F10** (Sentry scrub) e **SEC-F11** (secret do cron + agendamento OD-04).

## 10. Próximos passos
1. **PO:** decidir §2-E (incluir rota de resposta do follow-up na API surface) e empurrar **OD-02 (Auth)** ao Product Lead — destrava o desenho final de `/apply` + sessão.
2. **DevOps:** SEC-F10 (scrub) e SEC-F11 (secret + cron OD-04).
3. **Database:** desenhar as funções RPC atômicas (revisão Database) — pré-requisito da implementação dos endpoints de evento (Fases 6/7).
4. **Fase 1** abre quando: Data/AI ✓, Backend assume contrato ✓ (este handoff), **OD-02 confirmada**, revisão Database + Security. Backend entrega `/apply` e leitura do relatório já com SEC-F01/F02/F03.
5. **Fase 9 (RLS)** e **Fase 8 (audit_events)**: re-review do Security com evidência (policies + triggers + view + checagens de ownership). Veto ativo.

## 11. Open decisions / bloqueios
| ID | Tema | Status | Encaminhamento |
|---|---|---|---|
| OD-02 | Auth (Supabase) | Em aberto — **gargalo da Fase 1** | Product Lead (via PO; já em `[PRODOPS]`) |
| OD-03 | Email | Em aberto | default de `followups.channel` (§2-D); não bloqueia intenção |
| OD-04 | Cron | Em aberto | agendamento de `/internal/followups/run-due`; DevOps |
| §2-E | Rota de resposta do follow-up ausente em `02_` §7 | **Novo achado** | Product Orchestrator (escopo MVP) |
| OD-DB-06 | `report_items.artist_metric_id` | ⏳ Data/AI + Backend | **Backend apoia** (facilita SEC-F03: snapshot público vs detalhe interno) |

**Bloqueios ativos:** veto do Security sobre Fase 9/endpoints (SEC-0001 §0); Fase 1 não abre sem OD-02 confirmada + revisão Database + Security. Contrato de authz (SEC-F01/F02/F03/F11) **assumido** por este handoff.
