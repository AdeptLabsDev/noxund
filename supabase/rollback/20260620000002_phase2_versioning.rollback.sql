-- ============================================================================
-- NOXUND · ROLLBACK — Fase 2: Versionamento
-- ----------------------------------------------------------------------------
-- Reverte 20260620000002_phase2_versioning.sql por completo.
--
-- LOCAL: fora de supabase/migrations/ DE PROPÓSITO — o Supabase CLI aplica tudo em
--        migrations/ como forward migration; um down-script ali seria aplicado por engano.
--        Rodar manualmente (service-role) só para reverter a Fase 2.
--
-- STATUS: AUTORADO, NÃO APLICADO. DoD do Database Agent: "migration aplica e reverte".
-- Ordem: triggers → função compartilhada → tabelas (sem dependentes na Fase 2;
--        FKs da Fase 5 ainda não existem). Sem enums/sequences a remover.
-- ============================================================================

begin;

-- triggers (todos) ANTES da função que todos reutilizam (senão o drop da função falha)
drop trigger if exists rubric_versions_no_truncate          on public.rubric_versions;
drop trigger if exists rubric_versions_no_update_delete      on public.rubric_versions;
drop trigger if exists outcome_weight_versions_no_truncate   on public.outcome_weight_versions;
drop trigger if exists outcome_weight_versions_no_update_delete on public.outcome_weight_versions;

drop function if exists public.versioning_row_immutable();

-- tabelas (independentes entre si na Fase 2)
drop table if exists public.outcome_weight_versions;
drop table if exists public.rubric_versions;

commit;
