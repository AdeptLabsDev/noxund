# Handoff — [DB] Fase 2 `run_migration` (Apply) · CLOSEOUT pós-apply (backfill) · Database Agent

## 1. Identificação
- **Tarefa:** `task_phase2_run_migration_apply` · **Action:** `run_migration` (sensível/gated) — **closeout evidenciado (record-only / backfill)**
- **Owner agent:** Database (`database_agent`)
- **Data:** 2026-06-25 (backfill; apply ocorreu antes)
- **Motivo do backfill:** **OD-PROV-02** (aberta na DEC-0009) — a Fase 2 estava **aplicada sem closeout/DEC**. Esta entrega fecha a lacuna de proveniência com **evidência real, sem forjar**.
- **Supersede:** `HANDOFF-phase2-apply.md` (estado anterior `⏳ aguardando gate humano`).
- **Migration aplicada:** `supabase/migrations/20260620000002_phase2_versioning.sql` (forward-only, atômica).

## 2. Status — ✅ APLICADO E VERIFICADO (em CI), com evidência

A Fase 2 (Versionamento) foi aplicada e verificada **via CI** no Environment `production-db`, com
gate humano + required reviewers. Backfill da trilha que faltava — `completed` com **evidência real**
(onboarding §5 — nada forjado).

**Record-only:** este closeout **não reaplicou** a migration, **não** rodou o rollback, **não**
rodou o seed §7 do rubric, **não** executou DDL/DML novo. Apenas registra o run já aprovado/executado.

### 2.1 Evidência do apply
| Item | Evidência |
|---|---|
| Run do pipeline | `phase2-db-apply.yml` → https://github.com/AdeptLabsDev/noxund/actions/runs/28129447446 |
| Origem do run | branch **`main`** (SEC-F18) |
| Confirmação de intenção | job `guard` (`APPLY-PHASE2`) → **success** |
| Apply | job `apply` (`supabase db push`, forward-only) → **success** |
| Verificação pós-apply | job `verify` (`phase2_post_apply_verify.sql`, `psql -v ON_ERROR_STOP=1`) → **success** |
| Saída do `verify` | `OK — Phase 2 post-apply verification PASSED (§4 structural + §5 empirical).` |
| Aprovação humana em runtime | required reviewer **AdeptLabsDev** (DevOps+Security), origem `main` |
| Verify-hotfix refletido no run | PR **#3** `phase2/verify-hotfix`, commit **`a5e68b9`** ("align verify immutability assertions") — o run reflete o verify §4/§5 corrigido |

> **Verify-hotfix (contexto):** o `phase2_post_apply_verify.sql` alinhou as asserções de
> imutabilidade para aceitar **`restrict_violation` OR `insufficient_privilege`** ("trigger ou
> grant"), em paridade com Fases 1/3. Confirmei repo-side: a **linha final do verify bate verbatim**
> com a evidência (`phase2_post_apply_verify.sql:197`), o verify carrega o idiom corrigido (3
> ocorrências), a migration referenciada é a que autorei (`rubric_versions`/`outcome_weight_versions`),
> e o commit `a5e68b9` está no histórico. Não re-busquei o run ao vivo deste ambiente (sem `gh`/rede);
> tomo a run de CI como **evidência de registro**.

### 2.2 O que o `verify` cobriu (autoritativo, em banco)
- **§4 estrutural:** 2 tabelas (`rubric_versions`, `outcome_weight_versions`); 4 triggers de
  imutabilidade (`*_no_update_delete` + `*_no_truncate` nas 2); função `versioning_row_immutable()`
  com `search_path` pinado; 4 unique (`*_version_key`, `*_version_hash_key`); RLS-on nas 2.
- **§5 empírico:** **imutabilidade append-only** — `service_role` tentando `TRUNCATE`/`UPDATE`/`DELETE`
  nas 2 tabelas → **bloqueado** (`restrict_violation`/`insufficient_privilege`, pós-hotfix);
  `anon`/`authenticated` → **zero acesso** (default-deny, `insufficient_privilege`).
- **Efeito colateral nulo:** as únicas escritas do `verify` são probes em transações sempre revertidas.

## 3. Gate board do `run_migration` Fase 2 — TODOS FECHADOS
| Gate | Fonte | Estado |
|---|---|---|
| `review_rls` do SQL concreto | SEC-0007 | ✅ sem bloqueio |
| `audit_secrets` da pipeline | SEC-0008 | ✅ sem bloqueio |
| Data/AI #5 (fidelidade ao §7 / rubric_hash) | DATA-AI #5 | ✅ sem veto |
| Verify-hotfix (errcode-parity) | PR #3 / `a5e68b9` | ✅ refletido no run |
| PR atômico só-Fase-2 revisado + mergeado na `main`, sem push direto | PR #2 (`f1cc622`) | ✅ |
| Required reviewers em CI (origem `main`, SEC-F18) | INFRA-0001 §3 | ✅ AdeptLabsDev |
| Apply forward-only + verify §4/§5 fail-closed | run `28129447446` | ✅ success |

## 4. Definition of Done (database-agent.md) — checada
- [x] Migration **aplica** (evidência §2.1) e **reverte** (rollback declarado — §6, não executado).
- [x] Versões **imutáveis provadas em banco** (§2.2 §5 — backbone da reprodutibilidade).
- [x] RLS testada — RLS-on nas 2 + default-deny `anon`/`authenticated` (§2.2).
- [x] Revisões acionadas — Security (SEC-0007 SQL + SEC-0008 secrets), Data/AI #5, reviewer em runtime.
- [x] Handoff preenchido (este documento) — fecha OD-PROV-02.

## 5. Arquivos
- `docs/database/HANDOFF-phase2-apply-closeout.md` — **criado** (este closeout/backfill).
- `docs/database/HANDOFF-phase2-apply.md` — **modificado**: banner de resolução apontando para este closeout.
- **Nenhuma mudança de código/SQL.** Migration e `verify` já versionados; apply ocorreu em CI.

## 6. Rollback (rede de segurança — NÃO executado)
- `supabase/rollback/20260620000002_phase2_versioning.rollback.sql` permanece como rede de
  segurança declarada e reversível. **Não** foi aplicado.

## 7. Impacto no escopo / não-negociáveis
- **MVP travado?** Sim. 2 tabelas de versionamento; **zero** marketplace/Fase 2-produto.
- **Não-negociáveis provados em banco:** **score versionado + rubric imutável** (triggers
  UPDATE/DELETE/TRUNCATE), **default-deny**; IA não gera número (`rubric_hash` determinístico em
  código, não no banco); secrets fora de repo/log/payload; merge por PR (sem push direto na `main`).

## 8. Próximos passos
1. **Product Orchestrator (`record_decision`):** registrar o **fechamento do gate board do
   `run_migration` Fase 2** (run `28129447446`) e **fechar OD-PROV-02** (trilha de proveniência
   restaurada). A Fase 3 já tem closeout (`HANDOFF-phase3-apply-closeout.md`).
2. **Fundação seguinte:** Fase 4 — Raw YouTube Snapshots, na ordem do `migration-plan.md`.
3. **Veto que continua de pé:** Fase 9 — RLS Policies (SEC-0001 §0). Este apply **não** o destrava.

## 9. Open decisions / bloqueios
- **OD-PROV-02:** ✅ resolvida por este backfill (evidência + closeout). Falta só o `record_decision` do Orchestrator.
- **Nenhum bloqueio.** `task_phase2_run_migration_apply` transiciona → **`completed`**.
- Gates sensíveis downstream (Fase 4+, RLS da Fase 9) permanecem **intactos**.
