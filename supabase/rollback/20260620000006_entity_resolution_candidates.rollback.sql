-- ============================================================================
-- NOXUND · ROLLBACK — entity_resolution_candidates (extensão aditiva · DEC-0014)
-- ----------------------------------------------------------------------------
-- Reverte 20260620000006_entity_resolution_candidates.sql por completo.
--
-- LOCAL: fora de supabase/migrations/ DE PROPÓSITO — o Supabase CLI aplica tudo em
--        migrations/ como forward migration; um down-script ali seria aplicado por engano.
--        Rodar manualmente (service-role) só para reverter esta extensão.
--
-- SEGURANÇA: a fila é STAGING MUTÁVEL (não é log de validação congelado). Reverter é de baixo
--   risco se não houver decisão humana pendente de migrar; decisões já tomadas vivem em
--   audit_events / metrics_detail_json.overrides[] (sobrevivem ao drop). DROP é DDL.
--
-- ADITIVO: NÃO toca video_artist_mappings nem qualquer tabela da Fase 5. NÃO remove o enum
--   REUSADO public.video_artist_method (pertence à Fase 5). Só dropa o que esta migration criou.
--
-- STATUS: AUTORADO, NÃO APLICADO (DESIGN-ONLY). DoD do Database Agent: "migration aplica e reverte".
--   Ordem: tabela (índices/constraints caem junto) → enum novo. FKs p/ Fases 3–5 permanecem.
-- ============================================================================

begin;

-- tabela (índices, partial-unique, constraints e FKs caem junto)
drop table if exists public.entity_resolution_candidates;

-- enum NOVO desta migration (NUNCA dropar public.video_artist_method — é da Fase 5, reusado)
drop type if exists public.entity_candidate_status;

commit;
