# Handoff — [DB] Proposta de Modelo de Dados do MVP · Database Agent

## 1. Identificação
- **Tarefa:** [DB] Proposta de modelo de dados do MVP (Épico 4 — Database; sem migrations nesta etapa)
- **Owner agent:** Database
- **Data:** 2026-06-20
- **Prioridade:** P0
- **Vereditos de referência:** `docs/product/decisions/DEC-0003-mvp-data-model-review.md` (PO) · `docs/security/SEC-0001-mvp-data-model-review.md` (Security) · `docs/database/DATA-AI-REVIEW-mvp-data-model.md` (Data/AI)

## 2. Objetivo
Propor o modelo de dados inicial do MVP da NOXUND Hotspot Artists Report — documentação, **não** migrations — fiel a `04_Database_Event_Model.md`, cobrindo os 15 requisitos, com separação raw/computed/snapshot, eventos append-only, versionamento de rubric e proveniência até o raw.

## 3. Critério de aceite (do backlog)
Modelo cobre: aplicação→aprovação, acesso de produtor aprovado, evento por interação, intenção→follow-up pendente, relatório reconstruível por `run_id` + `rubric_version`, e nenhum número público sem rastro até `raw_youtube_videos`. Sem tabela de marketplace/Fase 2.

## 4. Resultado
- [x] Critério de aceite atendido (no nível de proposta; migrations virão por fase)
- [x] Demonstrável (como verificar): ler `docs/database/` na ordem `README.md` → `mvp-data-model.md` → `entity-relationship-notes.md` → `migration-plan.md` → `rls-review-notes.md`
- [x] PO + Security + Data/AI revisaram; edições deles incorporadas (itens 2–4 da resposta do PO + DATA-AI-0001)

Entregue a proposta em `docs/database/` (5 docs centrais + handoffs/reviews) e **incorporadas as decisões fechadas** de PO (DEC-0003), Security (SEC-0001) e Data/AI (DATA-AI-0001): `auth_user_id` FK, `admin_users` + `is_admin()`, triggers de imutabilidade obrigatórios, VIEW pública de `report_items`, `report_runs` unificado, `report_items.artist_metric_id`, `artist_metrics.metrics_detail_json` e `artist_metrics` versionado por `rubric_hash`. **20 tabelas** (19 de modelo + `admin_users` de segurança); zero Fase 2.

## 5. Arquivos alterados
- `docs/database/README.md` — índice, mapa de nomes (+`admin_users`), cobertura dos 15 req., status de revisão PO/Security.
- `docs/database/mvp-data-model.md` — doc tabela a tabela; +`auth_user_id`, +`admin_users`, triggers SEC-D03, VIEW SEC-F03, ODs com status final.
- `docs/database/entity-relationship-notes.md` — ER, classes de imutabilidade (+trigger/SEC-F01), cadeias de proveniência, anti-padrões (+SEC-F03/D02/D03).
- `docs/database/migration-plan.md` — 9 fases; Fase 1 (+`auth_user_id`/`admin_users`/`/apply` whitelist), Fases 4/8 (triggers), Fase 9 (gate SEC-F01/F02/F03/F13/F14).
- `docs/database/rls-review-notes.md` — decisões SEC-D01/D02/D03 incorporadas; §3 trigger obrigatório; SEC-F03/F07; status condicional.
- `docs/database/HANDOFF-mvp-data-model.md` — este handoff.
- `docs/database/DATA-AI-REVIEW-mvp-data-model.md` — veredito Data/AI para OD-DB-01/04/06/07 e cadeia de reprodutibilidade.

*(Não tocados por mim: `docs/agents/*` aparecem modificados no working tree por trabalho anterior, alheio a esta tarefa.)*

## 6. Impacto no escopo
- **Mantém o MVP travado?** Sim. Nenhuma tabela de marketplace/Fase 2 (`04_...` §12). `admin_users` é controle de segurança, não produto.
- **Toca non-negotiable?** Reforça: raw imutável (trigger), snapshot congelado, eventos-não-flags, score versionado, proveniência total.
- **Toca número/banco/auth/copy?** Banco (schema/eventos — matriz #2), raw/computed/número (matriz #4/#5) e auth/RLS (matriz #3) → por isso passou por Database + Security + Data/AI; Backend ainda pendente.

## 7. Validação executada
- `git status` / `git diff --stat` rodados; mudanças isoladas em `docs/database/` (proposta, sem migration). **Sem commit** (conforme instrução).
- Reprodutibilidade aprovada pelo Data/AI no modelo unificado (DATA-AI-0001): re-score do mesmo `run_id` sob novo `rubric_hash` recompondo `artist_metrics` com chave lógica `(run_id, artist_id, rubric_hash)` — sem split.
- Cobertura dos 15 requisitos → mapeada na tabela do `README.md`.

## 8. Riscos
- **SEC-F01 (Alta) — service-role bypassa RLS.** Pré-condição da Fase 9 e dos endpoints: authz de propriedade/role **em código** em todo caminho service-role. Sem isso → IDOR.
- **SEC-F02 (Alta) — mass-assignment no `/apply`.** Pré-condição da Fase 1: `anon` zero-grant + whitelist + `status` forçado no servidor. Fura o approval gate (tese de validação) se ignorado.
- **SEC-F03 (Alta) — exposição de coluna em `report_items`.** Pré-condição da Fase 9 / read endpoint: VIEW pública; `score_value`/`raw_score`/json interno nunca ao produtor.
- **Gate de pré-produção:** SEC-F09 (LGPD: base legal + deleção manual de PII) e SEC-F10 (higiene de log/Sentry). Travam o **lançamento**, não o doc.
- **Renomear evento após ter dado** seria caro → travado nos nomes canônicos de `04_` agora (OD-DB-05).

## 9. Revisões necessárias
- [x] **Product Orchestrator** — ✅ aprovado (DEC-0003): OD-DB-01/02/03/05; zero Fase 2 (20 tabelas).
- [x] **Security & Privacy** — ⚠️ **aprovação condicional; veto MANTIDO** (SEC-0001) sobre Fase 9 (RLS), migrations/endpoints de acesso e gate de pré-produção. Decisões fechadas SEC-D01/D02/D03 incorporadas. Veto cai só com re-review + evidência (policies + triggers + view + checagens de ownership).
- [x] **Data/AI** — ✅ aprovado (DATA-AI-0001): raw/computed, proveniência por célula, reprodutibilidade sem split (OD-DB-01), OD-DB-04/06/07.
- [ ] **Backend/Next API** — ⏳ formato consumível; authz em código (SEC-F01), whitelist `/apply` (SEC-F02), VIEW de leitura (SEC-F03), cron 404+constant-time (SEC-F11); escrita atômica evento+payload (WTP/followup).
- [ ] **QA** — incluído quando houver migration/critério testável (matriz #3).
- DevOps acionado para SEC-F10 (Sentry scrub) e SEC-F11 (secret do cron).

## 10. Próximos passos
1. PO aciona **Backend** — revisor restante para formato consumível e escrita atômica. Backend recebe SEC-F01/F02/F03 como requisito de desenho dos handlers.
2. Só então abrir a **Fase 1** (`producers` + `applications` + `admin_users`) como primeira migration real, com revisão **Database + Security** e após **OD-02 (Auth Supabase)** confirmada.
3. RLS (Fase 9) e `audit_events` (Fase 8) dependem do **re-review do Security** (veto).

## 11. Open decisions / bloqueios
| OD | Tema | Status final | Encaminhamento |
|---|---|---|---|
| OD-DB-01 | `report_runs` único vs split | ✅ **Unificado no MVP** (DEC-0003 + DATA-AI-0001) | Reprodutibilidade por célula aprovada sem split |
| OD-DB-02 | `producer_events` vs `producer_outcomes` | ✅ **`producer_events`** (DEC-0003) | — |
| OD-DB-03 | Criar `audit_events` | ✅ **Criar** (DEC-0003) | RLS fechada pelo Security (Fase 8) |
| OD-DB-04 | mapping vs event-log na resolução | ✅ **`video_artist_mappings` como mapping canônico** (DATA-AI-0001) | — |
| OD-DB-05 | nomes de `event_type` | ✅ **Manter `04_`** (DEC-0003) | aliases só em doc |
| OD-DB-06 | `report_items.artist_metric_id` | ✅ **Ratificado por Data/AI** (PO/Security apoiam; ajuda SEC-F03) | Backend valida consumo nos endpoints |
| OD-DB-07 | `artist_metrics.metrics_detail_json` | ✅ **Ratificado por Data/AI** | — |
| OD-DB-08 | identidade de auth | ✅ **`auth_user_id` FK** (SEC-D01) — não `id=auth.uid()` | **Security (fechado)** |

**Bloqueios ativos:** veto do Security sobre Fase 9/endpoints/pré-prod (SEC-0001 §0) e revisão Backend pendente. Data/AI não mantém veto metodológico.
