-- ============================================================================
-- NOXUND · ROLLBACK — Fase 6: producer_events (append-only)
-- ----------------------------------------------------------------------------
-- Reverte 20260620000007_phase6_producer_events.sql por completo.
--
-- LOCAL: fora de supabase/migrations/ DE PROPÓSITO — o Supabase CLI aplica tudo em
--        migrations/ como forward migration; um down-script ali seria aplicado por engano.
--        Rodar manualmente (service-role) só para reverter a Fase 6.
--
-- ⚠️ APPEND-ONLY: producer_events é log de comportamento real do produtor (métrica-norte +
--    funil de validação). Este rollback só é admissível se NÃO houver evento real capturado
--    (design/teste / antes do 1º publish). DROP TABLE é DDL — não dispara o trigger de
--    imutabilidade (que barra só DML). Exige revisão (Security/Data-AI/Backend diferidas).
--
-- STATUS: AUTORADO, NÃO APLICADO (DESIGN-ONLY, DEC-0013). DoD do Database Agent:
--         "migration aplica e reverte". Ordem: triggers → função → tabela → enum.
--   FKs para Fases 1/3/5 (producers/artists/reports/report_items) permanecem.
-- ============================================================================

begin;

-- triggers antes da função que eles referenciam
drop trigger if exists producer_events_no_truncate      on public.producer_events;
drop trigger if exists producer_events_no_update_delete on public.producer_events;

drop function if exists public.producer_events_immutable();

-- tabela (índices/constraints/partial-unique caem junto)
drop table if exists public.producer_events;

-- enum por último
drop type if exists public.producer_event_type;

commit;
