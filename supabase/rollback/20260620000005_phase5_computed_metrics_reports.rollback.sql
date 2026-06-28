-- ============================================================================
-- NOXUND · ROLLBACK — Fase 5: Computed Metrics + Resolução + Relatório
-- ----------------------------------------------------------------------------
-- Reverte 20260620000005_phase5_computed_metrics_reports.sql por completo
-- (versão CORRIGIDA pós-veto DATA-AI-0005 · DATA-F5-01..07).
--
-- LOCAL: fora de supabase/migrations/ DE PROPÓSITO — o Supabase CLI aplica tudo em
--        migrations/ como forward migration; um down-script ali seria aplicado por engano.
--        Rodar manualmente (service-role) só para reverter a Fase 5.
--
-- ⚠️ SNAPSHOT/COMPUTED: em produção, relatório publicado é congelado e o computed (com a
--    nova proveniência referencial artist_metric_videos) é a cadeia dos números exibidos.
--    Este rollback só é admissível se a(s) run(s) forem DESCARTÁVEIS (teste / antes de
--    publish real). DROP TABLE é DDL — não dispara os triggers de freeze (que barram só DML).
--    Exige revisão.
--
-- STATUS: AUTORADO, NÃO APLICADO. DoD do Database Agent: "migration aplica e reverte".
-- Ordem: triggers → funções de guard → tabelas (filhos→pais) → validadores de evidência → enums.
--   (os validadores caem DEPOIS das tabelas porque os CHECKs de evidência os referenciam.)
--   Tabelas: report_items (→ reports, artist_metrics) e artist_metric_videos (→ artist_metrics)
--   primeiro; depois reports, artist_metrics, channel_eligibility, video_artist_mappings.
--   FKs para Fases 2–4 (rubric_versions/report_runs/artists/raw_youtube_*) permanecem.
-- ============================================================================

begin;

-- triggers antes das funções que eles referenciam ----------------------------
drop trigger if exists artist_metric_videos_no_truncate       on public.artist_metric_videos;
drop trigger if exists artist_metric_videos_published_guard   on public.artist_metric_videos;
drop trigger if exists artist_metrics_published_guard         on public.artist_metrics;
drop trigger if exists report_items_no_truncate               on public.report_items;
drop trigger if exists report_items_snapshot_guard            on public.report_items;
drop trigger if exists reports_no_truncate                    on public.reports;
drop trigger if exists reports_snapshot_guard                 on public.reports;

-- funções de guard -----------------------------------------------------------
drop function if exists public.report_snapshot_no_truncate();
drop function if exists public.artist_metric_videos_published_guard();
drop function if exists public.artist_metrics_published_guard();
drop function if exists public.report_items_snapshot_guard();
drop function if exists public.reports_snapshot_guard();

-- tabelas (filhos→pais entre os objetos da Fase 5) ---------------------------
-- report_items e artist_metric_videos referenciam artist_metrics → caem antes dela.
drop table if exists public.report_items;
drop table if exists public.artist_metric_videos;
drop table if exists public.reports;
drop table if exists public.artist_metrics;
drop table if exists public.channel_eligibility;
drop table if exists public.video_artist_mappings;

-- validadores de evidência (F5-05A/F5-06A): só após as tabelas, pois os CHECKs os usam.
drop function if exists public.report_item_reason_complete(jsonb);
drop function if exists public.artist_metrics_detail_complete(jsonb);

-- enums por último -----------------------------------------------------------
drop type if exists public.competition_level;
drop type if exists public.report_status;
drop type if exists public.video_artist_method;

commit;
