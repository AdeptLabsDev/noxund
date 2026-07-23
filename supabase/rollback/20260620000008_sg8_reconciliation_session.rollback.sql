-- ============================================================================
-- NOXUND · ROLLBACK — SG-8 Reconciliation Session (DATA-SG8-001 estágio 3)
-- ----------------------------------------------------------------------------
-- Reverte 20260620000008_sg8_reconciliation_session.sql por completo, incluindo a UNIQUE
-- aditiva reports_id_run_key adicionada em public.reports.
--
-- LOCAL: fora de supabase/migrations/ DE PROPÓSITO — o Supabase CLI aplica tudo em
--        migrations/ como forward migration; um down-script ali seria aplicado por engano.
--        Rodar manualmente (service-role) só para reverter esta unidade.
--
-- ADITIVO ⇒ reversível sem perda de contrato existente: só dropa o que ESTA migration criou.
--   NÃO toca report_runs, reports (além de remover a unique que ela mesma adicionou), nem
--   qualquer tabela/enum das Fases 1–6. reports permanece com id (PK) e run_id intactos.
--
-- SEGURANÇA: as 4 tabelas SG-8 são append-only/imutáveis por design; reverter é DDL (DROP).
--   Fazer só com a unidade DESARMADA e SEM sessão SG-8 real materializada (estágio 4 não
--   autorizado). Ordem: dependências reversas (evidência → rodadas → snapshot → sessão) →
--   funções → unique aditiva em reports → enum.
--
-- STATUS: AUTORADO, NÃO APLICADO (DESIGN-ONLY). DoD Database: "migration aplica e reverte".
-- ============================================================================

begin;

-- 1. Tabelas (índices, uniques, constraints, FKs e triggers caem junto), dependências reversas.
drop table if exists public.sg8_round_report_evidence;
drop table if exists public.sg8_round_executions;
drop table if exists public.sg8_resolution_snapshots;
drop table if exists public.sg8_sessions;

-- 2. Funções de integridade desta migration (triggers já caíram com as tabelas).
drop function if exists public.sg8_round_report_evidence_guard();
drop function if exists public.sg8_sessions_guard();
drop function if exists public.sg8_append_only_guard();

-- 3. UNIQUE aditiva em reports (id, run_id) — remover deixa reports EXATAMENTE como antes
--    (id continua PK; nenhuma coluna/enum/trigger de reports foi tocada por esta migration).
alter table public.reports drop constraint if exists reports_id_run_key;

-- 4. Enum novo desta migration (todas as tabelas que o usavam já foram dropadas).
drop type if exists public.sg8_session_status;

commit;
