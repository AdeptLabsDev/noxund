-- Verify noxund_p3a_spike:baseline_schema on pg
SELECT 1/COUNT(*) FROM pg_namespace WHERE nspname = 'spike';
