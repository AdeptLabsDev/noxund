-- ATTACK A01 — multiple top-level commands in one artifact.
-- Expected: the server rejects at Parse under PQexecParams (extended protocol,
-- "cannot insert multiple commands into a prepared statement", SQLSTATE 42601).
-- Runner: artifact fails -> ROLLBACK. No DDL, no ledger row, no head advance.
CREATE TABLE noxund_app_spike.evil_a01 (i int); DROP TABLE noxund_app_spike.evil_a01;
