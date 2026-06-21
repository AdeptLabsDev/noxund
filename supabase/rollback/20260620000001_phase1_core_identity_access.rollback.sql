-- ============================================================================
-- NOXUND · ROLLBACK — Fase 1: Core Identity / Access
-- ----------------------------------------------------------------------------
-- Reverte 20260620000001_phase1_core_identity_access.sql por completo.
--
-- LOCAL: fora de supabase/migrations/ DE PROPÓSITO — o Supabase CLI aplica tudo em
--        migrations/ como forward migration; um down-script ali seria aplicado por engano.
--        Rodar manualmente (service-role) só para reverter a Fase 1.
--
-- STATUS: AUTORADO, NÃO APLICADO. Garante o DoD do Database Agent: "migration aplica e reverte".
-- Ordem: respeita dependências de FK (filhos antes de pais; objetos antes dos tipos).
-- ============================================================================

begin;

-- triggers e funções primeiro (dependem das tabelas)
-- ambos os triggers ANTES da função que ambos reutilizam (senão o drop da função falha)
drop trigger if exists audit_events_no_truncate on public.audit_events;
drop trigger if exists audit_events_no_update_delete on public.audit_events;
drop function if exists public.audit_events_immutable();
drop function if exists public.is_admin();

-- tabelas (applications depende de producers; demais independentes entre si)
drop table if exists public.audit_events;
drop table if exists public.applications;
drop table if exists public.admin_users;
drop table if exists public.producers;

-- enums por último (já sem colunas que os referenciem)
drop type if exists public.application_status;
drop type if exists public.producer_status;
drop type if exists public.audit_actor_type;

commit;
