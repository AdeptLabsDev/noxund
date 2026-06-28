# DATA-AI-0007 - Data/AI Approval Backfill - Fase 5

- **Autoridade revisora:** Data/AI Pipeline Agent (matrix #4/#5)
- **Tarefa original:** `task_phase5_validate_reproducibility_rereview_v2`
- **Tarefa de backfill:** `task_phase5_dataai_approval_backfill`
- **Data:** 2026-06-27
- **Fonte canonica:** AgentResult da tarefa original, `status=completed`
- **Anteriores:** `DATA-AI-0005` (veto) e `DATA-AI-0006` (re-veto)
- **Natureza:** registro fiel de veredito ja concluido; nenhuma revalidacao, alteracao de DDL ou execucao de apply.

## 0. Veredito

**APROVADO no re-review pre-apply. DATA-RR-F5-03A/05A/06A/01A fechados; gate Data/AI matrix #4/#5 BAIXADO.**

Este documento materializa a aprovacao que ficou registrada apenas no AgentResult original apos
falha da ferramenta de escrita. Nao reabre o veto e nao amplia o escopo da revisao.

## 1. Achados fechados

| Achado | Evidencia aprovada |
|---|---|
| **DATA-RR-F5-03A** | `artist_metric_videos_published_guard` valida OLD em UPDATE/DELETE e NEW em INSERT/UPDATE separadamente. Mover input de metric nao-publicada para publicada falha nos caminhos postgres e service-role. |
| **DATA-RR-F5-05A** | Evidencia e estrutural: NULL, `{}` e secao ausente sao rejeitados; fixture completo e aceito; evidencia da metric publicada fica congelada. |
| **DATA-RR-F5-06A** | `versions` exige rubric/resolver/rule versions nao-vazios; `overrides[]` preserva `run_id` + `video_id` ou `channel_id`, permitindo replay por chave natural sem depender somente de UUID mutavel. |
| **DATA-RR-F5-01A** | Move `report_items` draft -> published tambem e provado no caminho service-role, com a paridade de errcode do projeto. |

## 2. Nao-regressoes confirmadas

- DDL storage-only: zero formula, generated column ou CHECK de faixa/threshold numerico.
- `unique(run_id, artist_id, rubric_hash)` preservado em `artist_metrics`.
- FKs de rubric e proveniencia ate raw usam `ON DELETE RESTRICT`.
- `report_items -> artists` possui uma unica FK; total do DDL = 16 FKs.
- Nao existe freeze global nas tres COMPUTED: mappings/eligibility tem zero triggers e metrics/junction usam somente guards condicionais da linhagem publicada.
- Zero `CREATE POLICY` executavel; a Fase 9 nao foi destravada.
- IA permanece restrita a Entity Resolution; Score, Velocity, Signals, Competition, ranking e Example continuam deterministas e nao sao gerados por LLM.

## 3. P5-REPRO-01 permanece de pe

**P5-REPRO-01 e gate do `services/data-engine` antes do pipeline/primeiro publish, nao deste migration apply.**

Antes do primeiro publish, Data/AI + Backend/DevOps devem entregar teste, fixture e comando CI
fail-closed que execute duas rodadas sobre o mesmo raw, rubric, resolver/rule versions e decisoes
replayable; ordene a projecao por report/rank/artista; e compare byte-a-byte campos de negocio e
evidencias, excluindo somente UUIDs e timestamps operacionais. Qualquer divergencia e bug
metodologico bloqueante.

## 4. Artefatos revisados

- `supabase/migrations/20260620000005_phase5_computed_metrics_reports.sql`
- `supabase/tests/phase5_post_apply_verify.sql`
- `supabase/rollback/20260620000005_phase5_computed_metrics_reports.rollback.sql`
- `docs/database/HANDOFF-phase5-design.md`

## 5. Trilha cruzada

- `docs/security/SEC-0014-phase5-computed-metrics-ddl-review.md` - Security #3 aprovado.
- `docs/security/SEC-0015-phase5-apply-pipeline-audit.md` - pipeline de apply auditada.
- `docs/backend/BE-0002-phase5-report-items-consumption-contract.md` - consumo de `artist_metric_id` concluido.
- `docs/database/HANDOFF-phase5-design.md` - desenho e sequencia de gates da Fase 5.

DATA-AI-0007 fecha exclusivamente a lacuna documental da aprovacao Data/AI ja renderizada. Nao
autoriza `run_migration`, nao altera migration/pipeline/secrets e nao toca as policies ou a VIEW
publica da Fase 9, que permanecem vetadas.
