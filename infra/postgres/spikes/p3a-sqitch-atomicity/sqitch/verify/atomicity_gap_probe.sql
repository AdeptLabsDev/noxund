-- Verify noxund_p3a_spike:atomicity_gap_probe on pg
SELECT 1/COUNT(*) FROM pg_tables WHERE schemaname='spike' AND tablename='atomicity_gap_probe';
