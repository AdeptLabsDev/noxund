# Handoff — [DB] Fase 1 `run_migration` (Apply) · CLOSEOUT pós-apply · Database Agent

## 1. Identificação
- **Tarefa:** `task_phase1_run_migration_apply` · **Action:** `run_migration` (sensível/gated) — **closeout evidenciado (record-only)**
- **Owner agent:** Database (`database_agent`)
- **Data:** 2026-06-24
- **Alvo:** projeto Supabase `pwbkplzyzmortwjjpcbg` · região `us-east-1`
- **Supersede:** `HANDOFF-phase1-apply.md` (status anterior `blocked` — `MISSING_CREDENTIALED_CONNECTION`).
- **Migration aplicada:** `supabase/migrations/20260620000001_phase1_core_identity_access.sql` (forward only).

## 2. Status — ✅ APLICADO E VERIFICADO (em CI), com evidência

O bloqueio `MISSING_CREDENTIALED_CONNECTION` (handoff anterior §7) está **resolvido**: o ambiente
credenciado `production-db` (INFRA-0001) permitiu o apply **via CI, não no laptop**. A migration
da Fase 1 foi aplicada e a verificação pós-apply passou. Este é o `completed` com **evidência
real** que o padrão exige (onboarding §5 — `completed` sem evidência é proibido; nada forjado).

**Record-only:** este closeout **não reaplicou** a migration, **não** rodou o rollback e **não**
executou DML/DDL novo. Apenas registra o run já aprovado e executado.

### 2.1 Evidência do apply
| Item | Evidência |
|---|---|
| Run do pipeline | `phase1-db-apply.yml` → https://github.com/AdeptLabsDev/noxund/actions/runs/27956757153 |
| Origem do run | branch **`main`** (reconfirma SEC-F18 no 1º run — dispatch veio do branch protegido) |
| Confirmação de intenção | job `guard` (`APPLY-PHASE1`) → **success** |
| Apply | job `apply` (`supabase db push`, forward only) → **success** |
| Verificação pós-apply | job `verify` (`phase1_post_apply_verify.sql`, `psql -v ON_ERROR_STOP=1`) → **success** |
| Saída do `verify` | `OK — Phase 1 post-apply verification PASSED (§4 structural + §5 empirical).` |
| Aprovação humana em runtime | required reviewer **AdeptLabsDev** (encarna DevOps+Security) aprovou o deployment, origem `main` |

> O job `verify` levanta exceção em qualquer divergência (job vermelho em falha). **Verde =
> todas as asserções §4/§5 seguraram.** O detalhamento por asserção vive nos logs do run (URL
> acima) — a fonte autoritativa, não reproduzida aqui para evitar transcrição manual.

### 2.2 O que o `verify` cobriu (autoritativo, em banco)
- **§4 estrutural:** 4 tabelas (`producers`, `applications`, `admin_users`, `audit_events`);
  3 enums (`producer_status`, `application_status`, `audit_actor_type`); 2 triggers de
  imutabilidade em `audit_events`; `is_admin()` blindado — `prosecdef=t` + `search_path=''`
  (SEC-F15); índices esperados; RLS habilitado nas 4 tabelas.
- **§5 empírico:** `service_role` tentando `truncate/update/delete` em `audit_events` →
  **bloqueado** (SEC-D03 / SEC-F16 — trigger dispara **abaixo** do bypass do `service_role`);
  `anon` e `authenticated` → **zero acesso** às 4 tabelas (SEC-F02 / SEC-F13 default-deny).
- **Efeito colateral nulo:** a única escrita do `verify` é uma linha-sonda dentro de transação
  sempre revertida.

## 3. Gate board do `run_migration` — TODOS FECHADOS
| Gate | Fonte | Estado |
|---|---|---|
| Veto técnico do Security (SQL) | SEC-0004 | ✅ baixado |
| Aprovação humana da migration | DEC-0006 (escopada a `20260620000001`) | ✅ concedida |
| `audit_secrets` sem bloqueio | DEC-0007 (a) → SEC-0006 (2026-06-21) | ✅ **antes** do merge |
| PR revisado + mergeado na `main` | DEC-0007 (b) | ✅ via PR, sem push direto |
| Required reviewers em CI | INFRA-0001 §3 | ✅ AdeptLabsDev aprovou, origem `main` |
| Conexão credenciada | INFRA-0001 (ambiente `production-db`) | ✅ resolvido `MISSING_CREDENTIALED_CONNECTION` |

## 4. Definition of Done (database-agent.md) — checada
- [x] Migration **aplica** (evidência §2.1) e **reverte** (rollback declarado, ver §6 — não executado).
- [x] Raw sem rota de update — invariante de imutabilidade de `audit_events` **provado em banco** (§2.2 §5).
- [x] RLS testada — RLS-on nas 4 tabelas + default-deny `anon`/`authenticated` (§2.2).
- [x] Revisões acionadas — Security (SEC-0004 SQL + SEC-0006 secrets), DevOps (INFRA-0001), reviewer em runtime.
- [x] Handoff preenchido (este documento).

## 5. Arquivos
- `docs/database/HANDOFF-phase1-apply-closeout.md` — **criado** (este closeout evidenciado).
- `docs/database/HANDOFF-phase1-apply.md` — **modificado**: banner de resolução apontando para este closeout (evita leitura stale de `blocked`).
- **Nenhuma mudança de código/SQL.** A migration e o `verify` já estavam versionados; o apply ocorreu em CI.

## 6. Rollback (rede de segurança — NÃO executado)
- `supabase/rollback/20260620000001_phase1_core_identity_access.rollback.sql` permanece como
  rede de segurança declarada e reversível. **Não** foi aplicado. Bootstrap do 1º admin **não**
  faz parte deste apply (operação service-role manual, separada, sem auto-promoção).

## 7. Impacto no escopo
- **MVP travado?** Sim. 4 tabelas de identidade/acesso/auditoria; **zero** tabela de marketplace/Fase 2.
- **Non-negotiables:** preservados e reforçados — raw imutável (provado), default-deny (provado),
  "sem push direto na `main`" (merge por PR), secrets fora de repo/log/payload.

## 8. Riscos / follow-ups pós-apply (registrados — não bloqueiam)
1. **SEC-F18 residual (belt-and-suspenders):** o run positivo veio de `main`. Falta o **teste
   negativo** — um `workflow_dispatch` a partir de uma branch **≠ `main`** deve ser **NEGADO** ao
   acessar o Environment. Agendar como verificação independente da branch rule. **Não bloqueia.**
2. **SEC-F20:** tokens temporários/de teste **revogados** pós-apply (atestado pelo Product Lead).
   Gatilho permanente registrado (INFRA-0001 §5.2): rotação ≤90d / troca de pessoal / suspeita de leak.
3. **Drift de versão das actions:** SHA-pin congela versão; re-pinar conscientemente a cada bump (INFRA §5.1).

## 9. Revisões necessárias
- [x] **Database** — esta entrega (autor): apply confirmado e verificado, evidência anexada.
- [x] **Security** — SEC-0004 (SQL) + SEC-0006 (secrets) baixados antes do apply; default-deny/imutabilidade reprovados em banco no run.
- [x] **DevOps** — INFRA-0001 (pipeline gated) + aprovação do reviewer em runtime.

## 10. Próximos passos
1. **Product Orchestrator (`record_decision`):** registrar no decision log o **fechamento do gate
   board do `run_migration`** (Fase 1 aplicada+verificada, run `27956757153`) e atualizar os
   quadros em DEC-0007 e SEC-0006 §6.
2. **Fundação seguinte:** Fase 2 — Versionamento, na ordem do `migration-plan.md` (owner
   `database_agent`; revisão Database + Security, matrix #3).
3. **Veto que continua de pé:** Fase 9 — RLS Policies (SEC-0001 §0). Este apply **não** o destrava.

## 11. Open decisions / bloqueios
- **Nenhum bloqueio.** O `task_phase1_run_migration_apply` transiciona `blocked` → **`completed`**.
- Gates sensíveis downstream (Fase 2+, RLS da Fase 9) permanecem **intactos** e exigem suas próprias revisões.
