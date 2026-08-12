-- ATTACK A04 — ROLLBACK inside a DO in a transaction block.
-- Expected: server error (transaction control not allowed) -> runner ROLLBACK.
DO $a04$
BEGIN
    ROLLBACK;
END
$a04$;
