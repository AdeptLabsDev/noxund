# Handoff — [DB] Fase 2 DDL (Versionamento) · Database Agent

## 1. Identificação
- **Tarefa:** `task_phase2_versioning_plan_migration` · **Action:** `plan_migration` (não-sensível; apply gated)
- **Owner agent:** Database (`database_agent`)
- **Data:** 2026-06-20
- **Prioridade:** high
- **Predecessora:** Fase 1 fechada (DEC-0008; closeout `HANDOFF-phase1-apply-closeout.md`).
- **Fontes:** `migration-plan.md §Fase 2` · `00_Product_Lead_Decision_Log.md §7` · `04_…§11` · `mvp-data-model.md` · padrão Fase 1.

## 2. Objetivo
Autorar o **DDL concreto (não aplicado) + rollback** do versionamento de rubric e outcome weights — pré-requisito de computed (Fase 5 referencia `rubric_version` + `rubric_hash`). **Só estrutura de versionamento;** nenhuma mudança de rubric/pesos/Score.

## 3. Diff de schema (forward migration)
`supabase/migrations/20260620000002_phase2_versioning.sql`:

```text
+ table public.rubric_versions(
+   id uuid pk, version text, config_json jsonb, hash text, active_from timestamptz, created_at timestamptz,
+   unique(version), unique(version, hash)                 -- alvo de FK futura (Fase 5)
+ )
+ table public.outcome_weight_versions(
+   id uuid pk, version text, config_json jsonb, hash text, created_at timestamptz,
+   unique(version), unique(version, hash)
+ )
+ function public.versioning_row_immutable()  set search_path=''   -- levanta exceção p/ qualquer tg_op
+ trigger rubric_versions_no_update_delete           (before update or delete, row)
+ trigger rubric_versions_no_truncate                (before truncate, statement)
+ trigger outcome_weight_versions_no_update_delete   (before update or delete, row)
+ trigger outcome_weight_versions_no_truncate        (before truncate, statement)
+ enable row level security  rubric_versions, outcome_weight_versions      -- default-deny
+ revoke all ... from anon, authenticated   (ambas)
# seed do rubric §7 = template COMENTADO (não executado); rubric_hash computado pelo data-engine
```

### Mapa requisito → SQL
| Requisito (payload) | Onde |
|---|---|
| `version` ÚNICO; `hash` determinístico; componentes+pesos versionados (não recalculados) | `unique(version)`; `hash` documentado como computado pelo data-engine; `config_json` opaco; seed §7 verbatim (template) |
| `outcome_weight_versions` mesma disciplina (version único + hash) | tabela 2 idêntica em disciplina |
| Desenho suporta FK futura por `(rubric_version + rubric_hash)` | `unique (version, hash)` em ambas (alvo de FK na Fase 5) |
| RLS `ENABLE` + default-deny; zero GRANT a anon/authenticated; revoke explícito | blocos 4–5 |
| Reversível; ordem respeita FK (filhos→pais, objetos→tipos) | rollback companheiro (triggers→função→tabelas) |

## 4. Impacto raw/computed
- **Nenhum dado raw tocado.** Versionamento é **input do computed**, não raw nem snapshot.
- **Habilita computed (Fase 5):** `artist_metrics`/`report_runs` poderão FK por `(rubric_version, rubric_hash)`. Reprodutibilidade: relatório congelado recompõe o mesmo Score sob o mesmo `(version, hash)` — por isso `rubric_versions` é **imutável** (editar in-place quebraria a auditoria de relatórios já congelados).
- **Nenhum número gerado.** O `rubric_hash` é determinístico e computado pelo **data-engine** (Data/AI, owner), não fabricado no banco.

## 5. Decisões de modelagem (e por quê)
- **`unique (version, hash)`** além de `unique(version)`: Postgres exige unique sobre exatamente as colunas de uma FK composta → habilita a FK da Fase 5 sem retrabalho.
- **`config_json` opaco (sem CHECK de pesos):** não encodo a semântica do rubric no banco — isso é do Data/AI; encodar criaria risco de drift e invadiria ownership.
- **Imutabilidade (UPDATE+DELETE+TRUNCATE)** nas duas tabelas: aplico o princípio SEC-0003 §2 (toda tabela append-only/imutável precisa do guard completo). **É decisão de integridade do Database — Security ratifica no #3;** se discordar, é 1 par de triggers a remover (reversível).
- **Seed do §7 como template comentado:** persiste a decisão (pesos 40/25/20/15 verbatim) **sem** redecidir nem fabricar `hash`; o INSERT real é coordenado com Data/AI.

## 6. Rollback
`supabase/rollback/20260620000002_phase2_versioning.rollback.sql` — atômico, reversível: dropa os 4 triggers → a função compartilhada → as 2 tabelas. Sem enums/sequences. Fora de `migrations/` (CLI não aplica como forward).

## 7. Impacto no escopo / não-negociáveis
- **MVP travado?** Sim. 2 tabelas de versionamento; **zero** marketplace/Fase 2-produto.
- **Não-negociáveis:** reforça **score versionado** + **rubric imutável** (reprodutibilidade); **IA não gera número** (hash determinístico em código, não no banco); secrets fora de repo/log/payload.
- **Rubric/Score:** **INALTERADO** — apenas estrutura. Qualquer mudança de rubric/pesos seria **escalada ao Orchestrator** (Escalation Rules), não decidida aqui.

## 8. Validação executada
- Estrutural: revisão linha a linha contra requisitos (tabela §3). Ordem de drop do rollback conferida (triggers→função→tabelas).
- **Não executado:** nenhum apply (sem Postgres conectado; apply é gated). `git status` confirma só arquivos novos/doc.

## 9. Revisões necessárias (acionadas — ⏳, nunca assumidas como ok)
- [x] **Database** — autor (este handoff).
- [ ] **Security** — ⏳ **matrix #3** (toda migration): re-review do **SQL concreto** (RLS+default-deny, revoke, triggers de imutabilidade, search_path da função) **antes** de qualquer `change_db_schema`/`run_migration`. Gate de apply mantido até lá.
- [ ] **Data/AI** — ⏳ **matrix #5**: confirmar que o versionamento captura fielmente o **§7** (componentes/pesos) e ratificar a propriedade do `rubric_hash` (owner do hash determinístico). Mudança de rubric/Score ⇒ escalar ao Orchestrator.

## 10. Próximos passos
1. **Security #3 + Data/AI #5** revisam o SQL. Silêncio ≠ aprovação.
2. Com ambos liberados + gate humano + required reviewers, o `run_migration` (gated) aplica a Fase 2 — espelhando a Fase 1 (pipeline `phase1-db-apply.yml` como referência; um verify §estrutural análogo é recomendado à DevOps).
3. Segue **Fase 3** (`report_runs`, `artists`, `artist_aliases`) na ordem do `migration-plan.md`.

## 11. Open decisions / bloqueios
- **Bloqueio de apply:** Security #3 + Data/AI #5 pendentes (e gate humano/required reviewers) — nenhuma escrita de schema antes disso.
- **Para o re-review:** confirmar (a) imutabilidade das `*_versions` como desejada (recomendo manter) e (b) `outcome_weight_versions.hash` — adicionei `hash` para honrar o requisito "mesma disciplina" do payload (o `04_ §11` não listava `hash`); Data/AI confirma se há uso real no MVP ou se fica só estrutural.
- **Veto que continua de pé:** Fase 9 — RLS Policies (SEC-0001 §0). Esta fase não o destrava.
