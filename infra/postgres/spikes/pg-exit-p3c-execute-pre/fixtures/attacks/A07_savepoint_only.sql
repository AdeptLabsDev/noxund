-- ATTACK A07 — a lone SAVEPOINT (single command, tag "SAVEPOINT").
-- Expected: valid inside the tx, stays INTRANS; runner rejects on tag != "DO".
-- Confirms the command-tag guard, not the transaction-status guard, is decisive.
SAVEPOINT noxund_evil_a07;
