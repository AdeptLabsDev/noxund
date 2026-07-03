# Handoff — [DB] Fase 5 `run_migration` (Apply) · CLOSEOUT pós-apply · Database Agent

## 1. Identificação
- **Tarefa:** `task_phase5_run_migration_closeout` · **Action:** `run_migration` (sensível/gated) — **closeout evidenciado (record-only, `no_db_mutation`)**
- **Owner agent:** Database (`database_agent`)
- **Data:** 2026-06-28
- **Environment:** `production-db` · **Supersede:** estado `needs_review` de `HANDOFF-phase5-design.md` (banner de resolução aplicado).
- **Migration aplicada:** `supabase/migrations/20260620000005_phase5_computed_metrics_reports.sql` (forward-only, atômica) — versão corrigida pós ciclo de re-reviews (DATA-AI-0005→0006→0007).

## 2. Status — ✅ APLICADO E VERIFICADO (em CI), com evidência

O apply gated da Fase 5 **já foi executado em CI a partir de `main`** (PR #6 → merge `6d842b1`), com `guard`,
`apply` e `verify` verdes. Este é o `completed` com **evidência real** (onboarding §5 — nada forjado).

**Record-only:** este closeout **não reaplicou** a migration, **não** rodou o rollback, **não** executou
DDL/DML novo, **não tocou o publicado**. Apenas ratifica repo-side o run já aprovado e executado e emite a
evidência canônica — fechando a convenção closeout+DEC das Fases 1–5 (precedente DEC-0010).

### 2.1 Evidência do apply
| Item | Evidência |
|---|---|
| Run do pipeline | https://github.com/AdeptLabsDev/noxund/actions/runs/28311371393 |
| Origem do run | branch **`main`** (SEC-F18 — origem reconfirmada pelo reviewer) |
| Merge de origem | PR **#6** `phase5/computed-metrics-apply` → `main` (commit `6d842b1`) |
| Apply | `supabase db push` (forward-only, atômico) → **success** |
| Verificação pós-apply | `phase5_post_apply_verify.sql` (`psql -v ON_ERROR_STOP=1`) → **success** |
| Saída do `verify` | `OK — Phase 5 post-apply verification PASSED (§4 structural + §5 empirical).` |
| Aprovação humana em runtime | required reviewer **AdeptLabsDev**, origem `main`, rollback de produção **não** executado |

> O job `verify` levanta exceção em qualquer divergência (job vermelho em falha). **Verde = todas as
> asserções §4/§5 seguraram.** Os logs por-asserção vivem no run (URL acima) — fonte autoritativa.
> Confirmei repo-side que a **linha final do `verify` bate VERBATIM** com a evidência
> (`phase5_post_apply_verify.sql` **L883**) e que a migration referenciada é a que autorei (working tree
> **git-clean** contra `HEAD`; `git diff HEAD` vazio nos 3 SQL). **Não** re-busquei o run ao vivo (sem
> `gh`/rede); tomo o run de CI como evidência de registro — idêntico ao closeout da Fase 4.

## 3. Ratificação repo-side (os 4 itens da tarefa — conferidos linha a linha)

| # | Item | Veredito | Evidência (no repo) |
|---|---|---|---|
| 1 | Migration aplicada **==** a autorada; forward-only, atômica; zero drop/truncate/delete from | ✅ | `20260620000005_…sql`: `begin` (**L76**) … `commit` (**L666**); só `create`/`enable rls`/`revoke`/`comment`. `grep` de `drop \| truncate \| delete from` executável → **NONE** (as ocorrências de "truncate" são definição de trigger `before truncate` e a string do `raise`, não comandos). |
| 2 | Linha final do `verify` **verbatim** | ✅ | **L883**: `OK — Phase 5 post-apply verification PASSED (§4 structural + §5 empirical).` — idêntica ao `verify_final_line_expected`. |
| 3 | Inventário estrutural: 6 tabelas + 3 enums + 7 funções (5 guards + 2 validators IMMUTABLE) + 7 triggers + 16 FK ON DELETE RESTRICT + 2 CHECK structural-evidence + `reports.published_at` CHECK + RLS-on/revoke nas 6 | ✅ | Ver §5 (contagem + line cites batem exatamente). |
| 4 | Nada downstream destravado — veto Fase 9 (SEC-0001 §0): zero CREATE POLICY/VIEW executável | ✅ | `grep -i "create policy"` → **2 ocorrências, ambas COMENTÁRIO** (L65 cabeçalho, L645 §8); zero `create policy`/`create view` executável. Apenas `enable row level security` + `revoke` (default-deny puro). |

## 4. Gate board do `run_migration` Fase 5 — TODOS FECHADOS
| Gate | Fonte | Estado |
|---|---|---|
| Data/AI `validate_reproducibility` (matrix #4/#5) — ciclo de 3 reviews | **DATA-AI-0005 → 0006 → 0007** (0007 = aprovado, sem veto) | ✅ |
| Security `review_rls` (matrix #3) — guards/DEFINER/RLS/zero policy | **SEC-0014** | ✅ |
| Pipeline de apply auditada (matrix #8, `audit_secrets`) | **SEC-0015** | ✅ |
| Required reviewers em CI (origem `main`, SEC-F18) | run `28311371393` | ✅ AdeptLabsDev |
| Apply forward-only + verify §4/§5 fail-closed | run `28311371393` | ✅ guard·apply·verify success |
| Decisão registrada no decision log | **DEC-0012**-phase5-apply-completed | ✅ |

## 5. Inventário estrutural ratificado (line cites contra o arquivo versionado)
- **6 tabelas:** `video_artist_mappings` (L198), `channel_eligibility` (L228), `artist_metrics` (L259), `artist_metric_videos` (L304), `reports` (L331), `report_items` (L367).
- **3 enums:** `video_artist_method` (L84), `report_status` (L87), `competition_level` (L90).
- **7 funções:** 2 validadores **IMMUTABLE** `artist_metrics_detail_complete` (L108) / `report_item_reason_complete` (L164); 5 guards `reports_snapshot_guard` (L430), `report_items_snapshot_guard` (L482, SECURITY DEFINER), `artist_metrics_published_guard` (L519, DEFINER), `artist_metric_videos_published_guard` (L565, DEFINER), `report_snapshot_no_truncate` (L607). Todas com `search_path` fixo.
- **7 triggers:** L619/622 (reports guard + no_truncate), L626/629 (report_items guard + no_truncate), L633 (artist_metrics published guard), L637/640 (artist_metric_videos published guard + no_truncate).
- **16 FK `ON DELETE RESTRICT`:** `grep -c 'on delete restrict'` = 16 (3 mappings + 2 eligibility + 3 metrics + 2 junction + 2 reports + 4 report_items). `report_items` tem **exatamente 1** FK → `artists` (sem inline duplicada — nota FK count resolvida; DDL==handoff==16).
- **3 CHECK:** `reports_published_at_chk` (L342, estado) + 2 de **evidência ESTRUTURAL** `artist_metrics_detail_complete_chk` (L284) e `report_items_reason_complete_chk` (L406). Nenhum CHECK de faixa/threshold (storage-only preservado).
- **RLS + revoke:** `enable row level security` nas 6 (a partir de L649); `revoke all … from anon, authenticated` nas 6 (a partir de L659). Default-deny.

## 6. O que o `verify` provou em banco (autoritativo)
- **§4 estrutural:** 6 tabelas; 3 enums; colunas mandatórias `NOT NULL`; 5 guards + 2 validadores com `search_path` fixo; 3 guards SECURITY DEFINER; 2 CHECK de evidência; 7 triggers; bit INSERT nos guards de snapshot/junction; 6 índices de unicidade; 3 chaves de identidade; 10 FK nomeadas; `report_items_artist_metric_fk` por nome+colunas+RESTRICT; report_items↔artists = 1 FK; todas as FK RESTRICT; únicos CHECKs = published_at + 2 evidência; ausência de freeze global nas 3 COMPUTED; RLS-on nas 6; zero policies.
- **§5 empírico (probes revertidos, 2 role-paths):** freeze do snapshot (INSERT/move/UPDATE/DELETE, postgres + service_role); coerência report→item→metric (coerente aceito, 4 mismatches rejeitados); **linhagem publicada inviolável** (tamper + UPDATE de evidência bloqueados; **mover input não-publicado→publicado bloqueado — F5-03A — nos 2 role-paths**); recompute do não-publicado OK; proveniência referencial até raw (input/Example inexistente e outro-run rejeitados); **evidência ESTRUTURAL** (`{}`/seção ausente → `check_violation`; override sem chave natural → `check_violation`; fixture completo aceito — F5-05A/06A); unicidade; FK de rubric; default-deny. **Efeito colateral nulo** (probes em transações revertidas; helpers `pg_temp` da sessão).

## 7. Definition of Done (database-agent.md) — checada
- [x] Migration **aplica** (evidência §2.1) e **reverte** (rollback declarado — §9, não executado).
- [x] Computed **reconstruível** (sem freeze global) + **linhagem publicada inviolável** (guard condicional) — provado em banco (§6).
- [x] Relatório **reconstruível** por `run_id` + `(rubric_version, rubric_hash)` + versões/overrides na evidência congelada.
- [x] RLS testada — RLS-on nas 6 + default-deny `anon`/`authenticated`.
- [x] Revisões acionadas — Data/AI (DATA-AI-0007), Security #3 (SEC-0014), pipeline #8 (SEC-0015), reviewer em runtime.
- [x] Handoff preenchido (este documento).

## 8. Carry-forward (não-bloqueante — registrado, não é gate deste closeout)
- **P5-REPRO-01 (prova canônica de 2 rodadas):** gate do `services/data-engine` (hoje placeholder) **ANTES** da liberação do pipeline / primeiro publish — **NÃO** deste apply. O verify SQL exercita constraints, não os seis agentes; inserts SQL não substituem a prova do data-engine. Registrada em `HANDOFF-phase5-design.md §12`. **Owner:** Data/AI + Backend/DevOps no pipeline. Sem trava sobre este apply.

## 9. Rollback (rede de segurança — NÃO executado)
- `supabase/rollback/20260620000005_phase5_computed_metrics_reports.rollback.sql` permanece declarado e
  reversível (triggers → guards → tabelas filhos→pais → validadores → enums). **Não** foi aplicado.
  **`rollback_production` = NÃO executar:** relatório publicado é **FROZEN** e a cadeia computada
  (`artist_metric_videos`) é a trilha de proveniência; rollback só admissível para run(s) descartável(is).
  `DROP TABLE` é DDL (não dispara os triggers de freeze, que barram só DML).

## 10. Impacto no escopo / não-negociáveis
- **MVP travado?** Sim. 6 tabelas computed/resolução/snapshot (`04_ §5–§7`); **zero** marketplace/Fase 2 (`04_ §12`).
- **Não-negociáveis provados em banco:** **report snapshot congelado** (trigger pós-publish), **computed reconstruível** (sem freeze global), **linhagem publicada inviolável** (guard condicional, anti-bypass OLD/NEW), **proveniência referencial** até o raw, **evidência de auditoria estrutural** (versões + overrides com chave natural), **número de código** (DDL storage-only; zero CHECK de faixa), **default-deny** nas 6, **Fase 9 não destravada** (zero policy).

## 11. Arquivos
- `docs/database/HANDOFF-phase5-apply-closeout.md` — **criado** (este closeout evidenciado).
- `docs/database/HANDOFF-phase5-design.md` — **modificado**: banner de resolução apontando para este closeout (evita leitura stale do estado `needs_review`/revisões ⏳).
- **Nenhuma mudança de código/SQL.** Migration, rollback e `verify` já versionados (git-clean) e aplicados em CI.

## 12. Próximos passos / open decisions
- **Nenhum bloqueio.** `task_phase5_run_migration_closeout` transiciona → **`completed`**.
- **Decisão já registrada:** **DEC-0012**-phase5-apply-completed (run `28311371393`, origem `main`, reviewer AdeptLabsDev; gate board §4 fechado).
- **Fundação seguinte:** Fase 6 — `producer_events` (append-only), na ordem do `migration-plan.md`.
- **Vetos que continuam de pé:** Fase 9 — RLS Policies + **VIEW pública de `report_items` (SEC-F03)** (SEC-0001 §0). Este apply **não** os destrava. Gates sensíveis downstream exigem suas próprias revisões.
