# Handoff — `task_phase2_devops_fix_verify_errcode_parity` · DevOps Agent

## 1. Identificação
- **Tarefa:** `task_phase2_devops_fix_verify_errcode_parity` · **Action:** `define_pipeline` (não-sensível)
- **Owner agent:** DevOps / Infra (`devops_agent`)
- **Data:** 2026-06-24
- **Prioridade:** P1 (high)
- **Tipo:** hotfix de artefato de pipeline (verify) — **sem apply, sem schema**

## 2. Objetivo
Corrigir o **falso-negativo** do job `verify` da Fase 2: aceitar `restrict_violation` **OR**
`insufficient_privilege` nos 3 blocos de imutabilidade §5, em **paridade exata** com
`phase1_post_apply_verify.sql`. O schema aplicado está **correto e imutável**; o defeito era
no teste.

## 3. Root cause (regressão de paridade do teste, NÃO defeito de schema)
- **Incidente:** run da Fase 2 — job `apply` **SUCCESS**; job `verify` **FAIL** em §5 (UPDATE como `service_role`) com `permission denied` (`insufficient_privilege`/42501) em vez de `restrict_violation`.
- **Causa:** a migration (paridade com a Fase 1, aprovada em SEC-0004/0006) **não concede DML a `service_role`** — revoga só de `anon`/`authenticated`. Logo a mutação é barrada no **grant layer** (`insufficient_privilege`), **antes** de chegar ao trigger. O verify da Fase 1 aceita **os dois** errcodes; o da Fase 2 estreitou para só `restrict_violation` e produziu o falso-negativo.
- **Por que ambos provam append-only:** se a mutação é bloqueada por **trigger** (restrict_violation) **ou** por **ausência de grant** (insufficient_privilege), em qualquer caso `service_role` **não consegue mutar** a tabela versionada. Só uma mutação **bem-sucedida** é regressão.
- **Precedente:** este resultado é **exatamente o risco que registrei** em `HANDOFF-phase2-apply-pipeline.md` §9 ("se um ambiente não conceder o grant, o truncate levantaria insufficient_privilege e o verify falharia"). O empírico confirmou o estado de grant; o teste agora reflete isso.

## 4. Resultado (mudança exata)
- [x] **§5 — 3 blocos de imutabilidade** (TRUNCATE; UPDATE; DELETE como `service_role`):
  `when restrict_violation then null` → **`when restrict_violation or insufficient_privilege then null`** (paridade exata com `phase1_post_apply_verify.sql`).
- [x] **FAIL-on-success preservado:** os 4 `raise exception 'EMPIRICAL/...'` (TRUNCATE/UPDATE/DELETE + default-deny) seguem intactos — uma mutação que **suceda** ainda derruba o run.
- [x] **§4 estrutural inalterado** (2 tabelas, 4 triggers, função `search_path`-pinned, 4 unique constraints, RLS-on).
- [x] **Bloco default-deny inalterado** (`anon`/`authenticated` → `insufficient_privilege`).
- [x] **Comentário de razão adicionado** (cabeçalho "WHY EMPIRICAL" + comentários dos 3 blocos): o estado de grant de `service_role` é **dependente de ambiente**; bloqueio por grant **OU** por trigger ambos provam append-only — para a divergência **não reincidir**.
- [x] **Sem nova migration; zero mudança em grants/triggers/RLS; zero secret.**

**Como verificar:**
`grep -c 'restrict_violation or insufficient_privilege' supabase/tests/phase2_post_apply_verify.sql` → **3** ·
`grep -c "when restrict_violation then null" …` → **0** ·
diff vs. Fase 1 (L133/153/160): mesmos ramos de exceção.

## 5. Arquivos alterados
- `supabase/tests/phase2_post_apply_verify.sql` — **modificado**: paridade de errcode em §5 + comentários. **Único arquivo do hotfix.**

## 6. PR atômico só-verify (atenção ao working tree)
O branch atual carrega mudanças **não-comitadas de outras tarefas** (hardening do
`phase1-db-apply.yml`, `INFRA-0001`, `.env.example`, vários docs). **O PR deste hotfix deve
conter SOMENTE:**
- `supabase/tests/phase2_post_apply_verify.sql`
- este handoff (`docs/infra/HANDOFF-phase2-verify-errcode-fix.md`)

**Não** varrer as demais mudanças do working tree (pertencem a PRs/tarefas separados). Stage
seletivo: `git add supabase/tests/phase2_post_apply_verify.sql docs/infra/HANDOFF-phase2-verify-errcode-fix.md`.

## 7. Semântica de re-run (após merge na `main`)
Re-disparar `phase2-db-apply.yml` a partir de `main` (gated):
- **`apply`** — `supabase db push` é **no-op/up-to-date**: a migration `20260620000002` já está
  no histórico (`supabase_migrations.schema_migrations`); o apply **não reaplica**.
- **`verify`** — roda contra o **schema live**; com o errcode corrigido, esta é a **verificação
  real** (esperado: verde — imutabilidade comprovada por `insufficient_privilege` neste ambiente).

## 8. Impacto no escopo
- **MVP travado?** Sim. Só teste de pipeline; nada de schema/migration/grant/RLS; stack inalterada.
- **Non-negotiable?** Reforça #5 (append-only verificável em banco) sem afrouxar a asserção: regressão real (mutação bem-sucedida) continua falhando. Zero secret.
- **Decisão settled preservada:** **não** adicionei grant a `service_role` (divergiria da Fase 1 aprovada em SEC-0004/0006 e reabriria decisão de acesso fechada).

## 9. Riscos
- **Nenhum risco de segurança novo.** A mudança torna o teste **mais fiel** ao schema real; o FAIL-on-success mantém a detecção de regressão append-only.
- **Drift de paridade futuro:** mitigado pelo comentário explicativo nos blocos — qualquer fase nova que copie este verify herda a dupla-aceitação documentada.

## 10. Revisões necessárias
- [x] **DevOps** — esta entrega (autor).
- [ ] **Security (opcional, leve):** confirma que a dupla-aceitação é **paridade** com o padrão da Fase 1 já aprovado (não afrouxa: mutação bem-sucedida ainda falha). Não bloqueia o re-run gated.

## 11. Próximos passos
1. **Merge do PR atômico** (verify + handoff) via branch + revisão (sem push direto na `main`).
2. **Database (`run_migration`, gated):** re-disparar `phase2-db-apply.yml` de `main` → apply no-op + verify **real/verde**. Gate humano + required reviewers permanecem.
3. Fechar a paridade de verificação da Fase 2 (matrix #8) com o run verde anexado como evidência.

## 12. Open decisions / bloqueios
- **Nenhum bloqueio de DevOps.** Hotfix pronto. O re-run gated é humano (downstream, intacto); o veto da Fase 9 (RLS Policies) segue à parte e **não foi tocado**.
