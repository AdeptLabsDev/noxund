-- ATTACK C02 — artifact tries to assume the ledger-owner identity directly.
-- Expected: SQLSTATE 42501 — session_user=noxund_migrator is NOT a member of
-- noxund_ledger, so SET ROLE noxund_ledger is denied -> runner ROLLBACK.
DO $c02$
BEGIN
    SET ROLE noxund_ledger;
END
$c02$;
