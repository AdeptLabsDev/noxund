-- ATTACK A05 — dynamic transaction control (EXECUTE 'COMMIT') inside a DO.
-- Expected: server rejects transaction control via SPI in a transaction block
-- -> runner ROLLBACK. Closes the dynamic-SQL escape.
DO $a05$
BEGIN
    EXECUTE 'COMMIT';
END
$a05$;
