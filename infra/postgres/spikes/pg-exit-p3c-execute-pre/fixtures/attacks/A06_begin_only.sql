-- ATTACK A06 — a lone BEGIN (single command, tag "BEGIN").
-- Expected: server issues a warning, transaction stays INTRANS (state unchanged).
-- The INTRANS guard alone would NOT catch this; the runner rejects on
-- command-tag != "DO" -> ROLLBACK. No ledger row, no head advance.
BEGIN;
