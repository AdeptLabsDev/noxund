# Handoff — [DB] Fase 3 DDL (Runs + Artists) · Database Agent

## 1. Identificação
- **Tarefa:** `task_phase3_plan_migration_report_runs_artists` · **Action:** `plan_migration` (não-sensível; apply gated)
- **Owner agent:** Database (`database_agent`)
- **Data:** 2026-06-24
- **Predecessora:** Fase 2 reapply+verify `completed` (DEC-0009).
- **Fontes:** `migration-plan.md §Fase 3` · `04_…§4/§5` · `00_…§3` (vertical travada) · `mvp-data-model.md` · `DATA-AI-0001` · padrão Fases 1–2.

## 2. Objetivo
Autorar o **DDL concreto (não aplicado) + rollback + verify** de `report_runs`, `artists`, `artist_aliases` — esqueleto de runs e identidade de artista, âncoras das Fases 4–5. **Forward-only, atômica.** Apply permanece gated (CI: humano + required reviewers).

## 3. Diff de schema (forward migration)
`supabase/migrations/20260620000003_phase3_runs_artists.sql`:

```text
+ enum public.report_run_status ('created','collecting','processed','published','failed')
+ enum public.artist_alias_source ('regex','llm_assisted','human')
+ table public.report_runs(
+   id uuid pk, keyword text d'chicago drill type beat', vertical text d'Chicago Drill',
+   window_start/window_end timestamptz, target_video_count int d500, collected_video_count int,
+   youtube_quota_used int, status report_run_status d'created', rubric_version text, rubric_hash text, created_at,
+   check (window_end >= window_start)
+ )
+ table public.artists(id uuid pk, canonical_name text, created_at)
+   unique index lower(canonical_name)
+ table public.artist_aliases(id uuid pk, artist_id fk->artists ON DELETE CASCADE, alias text, source artist_alias_source, created_at)
+   unique index lower(alias);  index (artist_id)
+ function public.report_runs_row_guard()    set search_path=''   -- DELETE bloqueado; UPDATE congela keyword/vertical/janela
+ function public.report_runs_no_truncate()  set search_path=''   -- TRUNCATE bloqueado
+ trigger report_runs_row_guard   (before update or delete, row)
+ trigger report_runs_no_truncate (before truncate, statement)
+ enable row level security  report_runs, artists, artist_aliases   -- default-deny
+ revoke all ... from anon, authenticated  (as 3)
```

### Mapa requisito → SQL
| Requisito (payload) | Onde |
|---|---|
| Migration forward-only + atômica, ordem do migration-plan | `begin/commit`; `report_runs` → `artists` → `artist_aliases` |
| **Raw imutável preservada** | `report_runs` é a âncora: identidade de coleta congelada + DELETE/TRUNCATE bloqueados por trigger (abaixo do service_role); recoleta = novo `run_id` |
| Zero marketplace/Fase 2-produto | só runs/identidade; nenhuma tabela proibida (`04_ §12`) |
| Verify §4/§5 em paridade com Fases 1–2 | `supabase/tests/phase3_post_apply_verify.sql` (idêntico em estrutura ao phase1/phase2) |
| Data/AI se tocar identidade/dedupe | `artists`/`artist_aliases` tocam dedupe → **Data/AI #5 acionada** |

## 4. Verify §4/§5 (paridade exata — `phase3_post_apply_verify.sql`)
- **§4 estrutural:** 3 tabelas; 2 enums; 2 triggers de proveniência em `report_runs`; funções `search_path`-pinned; 2 unique de dedupe + FK `artist_aliases→artists`; RLS-on nas 3.
- **§5 empírico (pós-fix SEC-F21/F22, paridade com Fases 1–2 DEC-0009):**
  - `service_role` → `TRUNCATE`/`UPDATE keyword`/`DELETE` em `report_runs` = bloqueado, aceitando **`restrict_violation` OR `insufficient_privilege`** ("trigger ou grant" — **SEC-F21**, idêntico ao idiom phase1/phase2 pós-hotfix).
  - **Probe positivo de freeze (SEC-F22):** `UPDATE keyword` como `postgres` (grant-holder) = **`restrict_violation`** (prova que o **trigger** impõe o freeze, não a ausência de grant).
  - **UPDATE de `status` PASSA** (freeze é por-coluna, não bloqueio total) — probe benigno preservado.
  - `anon`/`authenticated` → `insufficient_privilege` nas 3. `ON_ERROR_STOP=1`, probes sempre revertidos.

## 5. Decisões de modelagem (e por quê)
- **`report_runs` âncora, não imutável-total:** STATE (status/contadores muda), mas **identidade de coleta** (keyword/vertical/janela) congelada e linha indeletável. Justificativa: o `run_id` + a query/janela definem o que produziu o raw; se editáveis/deletáveis, a auditoria "qual busca gerou estes 500 vídeos" seria falsificável. Trigger garante abaixo do service_role (lição SEC-F16). **Integridade do Database — Security ratifica no #3.**
- **`rubric_version/rubric_hash` em `report_runs` = nullable, NÃO congelado:** DATA-AI-0001 keya o rubric por-scoring em `artist_metrics` `(run_id, artist_id, rubric_hash)`. Em `report_runs` fica só o ponteiro do rubric do relatório **publicado**. **Não** congelei para não pré-decidir o fluxo de re-score/re-publish (domínio Data/AI). **Confirmar com Data/AI (#5).**
- **Dedupe sem imutabilidade:** `artists`/`artist_aliases` são o working set de dedupe — merge/correção humana **precisa** de mutabilidade. Logo, sem trigger de imutabilidade; integridade via `unique lower(canonical_name)` + `unique lower(alias)` (conflito → revisão humana) e correções registradas em `audit_events`. **Decisão de identidade ⇒ Data/AI #5.**
- **Vertical travada (§3):** `keyword`/`vertical` com default nos valores travados; sem `CHECK` rígido (evita fricção de multi-keyword na Fase 2).

## 6. Impacto raw/computed
- **Habilita Fase 4 (raw):** `raw_youtube_*` FK por `run_id`. A âncora imutável de `report_runs` é o que torna o raw auditável até a query/janela.
- **Habilita Fase 5 (computed):** `artist_metrics`/`report_items` FK por `run_id` + `artist_id`.
- **Nenhum número gerado;** nenhum raw tocado (raw é Fase 4).

## 7. Rollback
`supabase/rollback/20260620000003_phase3_runs_artists.rollback.sql` — atômico, reversível: triggers → funções → tabelas (`artist_aliases`→`artists`→`report_runs`) → enums. Fora de `migrations/`.

## 8. Impacto no escopo / não-negociáveis
- **MVP travado?** Sim. 3 tabelas de runs/identidade; **zero** marketplace/Fase 2-produto.
- **Não-negociáveis:** reforça **raw imutável** (âncora indeletável/congelada) e **proveniência** (run_id); secrets fora de repo/log/payload.

## 9. Validação executada
- Estrutural: revisão linha a linha; verify em paridade com Fases 1–2; ordem de drop do rollback conferida.
- **Não executado:** nenhum apply (sem Postgres conectado; apply é gated). `git status` confirma só arquivos novos/doc.

## 10. Revisões necessárias (⏳, nunca assumidas como ok)
- [x] **Database** — autor (este handoff).
- [~] **Security** — **matrix #3**: DDL **aprovado (SEC-0009)**. Bloqueou no **verify**: **SEC-F21** (errcode-parity) + **SEC-F22** (freeze por-coluna grant-holder) → **resolvidos** em `phase3_post_apply_verify.sql` (esta entrega). ⏳ Aguarda **re-`review_rls`** do Security sobre o verify corrigido. Gate de apply mantido.
- [x] **Data/AI** — ✅ **matrix #5 baixado** em `docs/database/DATA-AI-REVIEW-phase3-runs-artists.md`: identidade/dedupe de artista (`unique` em canonical_name/alias; FK cascade) **e** placement de `rubric_*` (report_runs vs artist_metrics). Mudança futura de identidade/rubric ⇒ escalar ao Orchestrator.

## 11. Próximos passos / bloqueios
1. Security #3 conclui os ajustes/ratificações pendentes. Silêncio ≠ aprovação.
2. Com liberações + gate humano + required reviewers, `run_migration` (gated) aplica a Fase 3 — espelhando Fases 1–2 (pipeline `phaseN-db-apply.yml`; verify `phase3_post_apply_verify.sql`).
3. Segue **Fase 4** (raw `raw_youtube_*`) na ordem do `migration-plan.md`.
- **Veto que continua de pé:** Fase 9 — RLS Policies (SEC-0001 §0). Esta fase **não** o destrava.
