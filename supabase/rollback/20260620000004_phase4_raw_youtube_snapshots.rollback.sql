-- ============================================================================
-- NOXUND · ROLLBACK — Fase 4: Raw YouTube Snapshots
-- ----------------------------------------------------------------------------
-- Reverte 20260620000004_phase4_raw_youtube_snapshots.sql por completo.
--
-- LOCAL: fora de supabase/migrations/ DE PROPÓSITO — o Supabase CLI aplica tudo em
--        migrations/ como forward migration; um down-script ali seria aplicado por engano.
--        Rodar manualmente (service-role) só para reverter a Fase 4.
--
-- ⚠️ RAW SAGRADO: em produção, raw NÃO se apaga. Este rollback só é admissível se a(s)
--    run(s) coletada(s) forem DESCARTÁVEIS (ambiente de teste / antes de qualquer coleta
--    real). DROP TABLE é DDL — não dispara os triggers de imutabilidade (que barram só
--    UPDATE/DELETE/TRUNCATE em DML). É a única rota legítima de remoção, e exige revisão.
--
-- STATUS: AUTORADO, NÃO APLICADO. DoD do Database Agent: "migration aplica e reverte".
-- Ordem: triggers → funções → tabelas. As 3 tabelas não dependem entre si; o FK aponta
--        para report_runs (Fase 3), que permanece.
-- ============================================================================

begin;

-- triggers antes das funções que eles referenciam
drop trigger if exists raw_youtube_search_pages_immutable   on public.raw_youtube_search_pages;
drop trigger if exists raw_youtube_search_pages_no_truncate on public.raw_youtube_search_pages;
drop trigger if exists raw_youtube_videos_immutable         on public.raw_youtube_videos;
drop trigger if exists raw_youtube_videos_no_truncate       on public.raw_youtube_videos;
drop trigger if exists raw_youtube_channels_immutable       on public.raw_youtube_channels;
drop trigger if exists raw_youtube_channels_no_truncate     on public.raw_youtube_channels;

drop function if exists public.raw_youtube_no_truncate();
drop function if exists public.raw_youtube_immutable();

-- tabelas (FK → report_runs da Fase 3 permanece; sem dependências entre as 3)
drop table if exists public.raw_youtube_search_pages;
drop table if exists public.raw_youtube_videos;
drop table if exists public.raw_youtube_channels;

commit;
