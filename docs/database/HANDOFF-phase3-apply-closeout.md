# Handoff — [DB] Fase 3 `run_migration` (Apply) · CLOSEOUT pós-apply · Database Agent

## 1. Identificação
- **Tarefa:** `task_phase3_run_migration_apply` · **Action:** `run_migration` (sensível/gated) — **closeout evidenciado (record-only)**
- **Owner agent:** Database (`database_agent`)
- **Data:** 2026-06-25
- **Alvo:** projeto `pwbkplzyzmortwjjpcbg` · **Supersede:** `HANDOFF-phase3-apply.md` (estado anterior `needs_review` — aguardando gate humano).
- **Migration aplicada:** `supabase/migrations/20260620000003_phase3_runs_artists.sql` (forward-only, atômica).

## 2. Status — ✅ APLICADO E VERIFICADO (em CI), com evidência

O `needs_review` (handoff anterior) está **resolvido**: o gate humano + required reviewers do
Environment `production-db` executaram o apply **via CI**. A migration da Fase 3 foi aplicada e a
verificação pós-apply passou. Este é o `completed` com **evidência real** (onboarding §5 — nada
forjado).

**Record-only:** este closeout **não reaplicou** a migration, **não** rodou o rollback, **não**
executou DDL/DML novo. Apenas registra o run já aprovado e executado.

### 2.1 Evidência do apply
| Item | Evidência |
|---|---|
| Run do pipeline | `phase3-db-apply.yml` → https://github.com/AdeptLabsDev/noxund/actions/runs/28234275173 |
| Origem do run | branch **`main`** (SEC-F18 — dispatch do branch protegido) |
| Confirmação de intenção | job `guard` (`APPLY-PHASE3`) → **success** |
| Apply | job `apply` (`supabase db push`, forward-only) → **success** |
| Verificação pós-apply | job `verify` (`phase3_post_apply_verify.sql`, `psql -v ON_ERROR_STOP=1`) → **success** |
| Saída do `verify` | `OK — Phase 3 post-apply verification PASSED (§4 structural + §5 empirical).` |
| Aprovação humana em runtime | required reviewer **AdeptLabsDev** (DevOps+Security) aprovou o deployment, origem `main` |

> O job `verify` levanta exceção em qualquer divergência (job vermelho em falha). **Verde =
> todas as asserções §4/§5 seguraram.** Os logs por-asserção vivem no run (URL acima) — a fonte
> autoritativa. Confirmei repo-side que a **linha final do verify bate verbatim** com a evidência
> e que a migration referenciada é a que autorei (`report_runs`/`artists`/`artist_aliases`). Não
> re-busquei o run ao vivo deste ambiente (sem `gh`/rede); tomo a run de CI como evidência de
> registro.

### 2.2 O que o `verify` cobriu (autoritativo, em banco)
- **§4 estrutural:** 3 tabelas (`report_runs`, `artists`, `artist_aliases`); 2 enums
  (`report_run_status`, `artist_alias_source`); 2 triggers de proveniência em `report_runs`;
  funções `versioning`/guard com `search_path` pinado; 2 unique de dedupe + FK
  `artist_aliases→artists`; RLS habilitado nas 3.
- **§5 empírico:** **âncora `report_runs` imutável** — `service_role` tentando
  `TRUNCATE`/`UPDATE keyword`/`DELETE` → **bloqueado** (`restrict_violation`/`insufficient_privilege`,
  SEC-F21); freeze por-coluna provado também como grant-holder (`postgres` → `restrict_violation`,
  SEC-F22); **`UPDATE status` PASSA** (freeze é por-coluna). `anon`/`authenticated` → **zero acesso**
  às 3 tabelas (default-deny, SEC-F02/F13).
- **Efeito colateral nulo:** as únicas escritas do `verify` são probes em transações sempre revertidas.

## 3. Gate board do `run_migration` Fase 3 — TODOS FECHADOS
| Gate | Fonte | Estado |
|---|---|---|
| DDL aprovado pelo Security | SEC-0009 | ✅ |
| Data/AI #5 (identidade/dedupe + rubric placement) | `DATA-AI-REVIEW-phase3-runs-artists.md` | ✅ baixado |
| Verify corrigido (errcode-parity + freeze grant-holder) | SEC-F21 / SEC-F22 | ✅ resolvidos + re-review |
| PR atômico revisado + mergeado na `main`, sem push direto | — | ✅ |
| Required reviewers em CI (origem `main`, SEC-F18) | INFRA-0001 §3 | ✅ AdeptLabsDev |
| Apply forward-only + verify §4/§5 fail-closed | run `28234275173` | ✅ success |

## 4. Definition of Done (database-agent.md) — checada
- [x] Migration **aplica** (evidência §2.1) e **reverte** (rollback declarado — §6, não executado).
- [x] Raw sem rota de update — **âncora `report_runs` imutável provada em banco** (§2.2 §5).
- [x] RLS testada — RLS-on nas 3 + default-deny `anon`/`authenticated` (§2.2).
- [x] Revisões acionadas — Security (SEC-0009 DDL + SEC-F21/F22 verify), Data/AI #5, reviewer em runtime.
- [x] Handoff preenchido (este documento).

## 5. Arquivos
- `docs/database/HANDOFF-phase3-apply-closeout.md` — **criado** (este closeout evidenciado).
- `docs/database/HANDOFF-phase3-apply.md` — **modificado**: banner de resolução apontando para este closeout (evita leitura stale de `needs_review`).
- **Nenhuma mudança de código/SQL.** A migration e o `verify` já estavam versionados; o apply ocorreu em CI.

## 6. Rollback (rede de segurança — NÃO executado)
- `supabase/rollback/20260620000003_phase3_runs_artists.rollback.sql` permanece como rede de
  segurança declarada e reversível. **Não** foi aplicado.

## 7. Impacto no escopo / não-negociáveis
- **MVP travado?** Sim. 3 tabelas de runs/identidade; **zero** marketplace/Fase 2-produto.
- **Não-negociáveis provados em banco:** **raw imutável** (âncora `report_runs` indeletável/congelada),
  **default-deny** (anon/authenticated), proveniência por `run_id`. "Sem push direto na `main`"
  (merge por PR); secrets fora de repo/log/payload.

## 8. Próximos passos
1. **Product Orchestrator (`record_decision`):** registrar no decision log o **fechamento do gate
   board do `run_migration` Fase 3** (run `28234275173`).
2. **Fundação seguinte:** Fase 4 — Raw YouTube Snapshots (`raw_youtube_search_pages`,
   `raw_youtube_videos`, `raw_youtube_channels`), na ordem do `migration-plan.md` (owner
   `database_agent`; raw imutável com trigger UPDATE+DELETE+TRUNCATE — SEC-D03/SEC-F16; revisão
   Database + Security matrix #3, Data/AI matrix #4).
3. **Veto que continua de pé:** Fase 9 — RLS Policies (SEC-0001 §0). Este apply **não** o destrava.

## 9. Open decisions / bloqueios
- **Nenhum bloqueio.** `task_phase3_run_migration_apply` transiciona → **`completed`**.
- Gates sensíveis downstream (Fase 4+, RLS da Fase 9) permanecem **intactos** e exigem suas próprias revisões.
