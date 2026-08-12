-- ATTACK A02 — a single, valid command whose command tag is NOT "DO".
-- Expected: succeeds server-side (tag "CREATE TABLE") but the runner rejects on
-- command-tag != "DO" -> ROLLBACK undoes the DDL. No ledger row, no head advance.
CREATE TABLE noxund_app_spike.evil_a02 (i int);
