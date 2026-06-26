-- ============================================================================
-- NOXUND · ROLLBACK — Fase 3: Runs + Artists
-- ----------------------------------------------------------------------------
-- Reverte 20260620000003_phase3_runs_artists.sql por completo.
--
-- LOCAL: fora de supabase/migrations/ DE PROPÓSITO — o Supabase CLI aplica tudo em
--        migrations/ como forward migration; um down-script ali seria aplicado por engano.
--        Rodar manualmente (service-role) só para reverter a Fase 3.
--
-- STATUS: AUTORADO, NÃO APLICADO. DoD do Database Agent: "migration aplica e reverte".
-- Ordem: triggers → funções → tabelas (filhos→pais) → enums.
-- ============================================================================

begin;

-- triggers antes das funções que usam
drop trigger if exists report_runs_no_truncate on public.report_runs;
drop trigger if exists report_runs_row_guard   on public.report_runs;
drop function if exists public.report_runs_no_truncate();
drop function if exists public.report_runs_row_guard();

-- tabelas: artist_aliases (FK → artists) antes de artists; report_runs independente
drop table if exists public.artist_aliases;
drop table if exists public.artists;
drop table if exists public.report_runs;

-- enums por último
drop type if exists public.artist_alias_source;
drop type if exists public.report_run_status;

commit;
