-- ATTACK A03 — transaction control (COMMIT) inside a DO in a transaction block.
-- Expected: server error (a DO executed in a transaction block cannot execute
-- transaction control statements; SQLSTATE 2D000/invalid_transaction_termination).
-- Runner: artifact fails -> ROLLBACK. The transaction is never split.
DO $a03$
BEGIN
    CREATE TABLE noxund_app_spike.evil_a03 (i int);
    COMMIT;
END
$a03$;
