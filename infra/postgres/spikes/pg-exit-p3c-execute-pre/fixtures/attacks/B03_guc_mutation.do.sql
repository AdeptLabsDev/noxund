-- ATTACK B03 — artifact mutates encoding/date/time GUCs.
-- Expected: the runner reasserts the baseline (client_encoding=UTF8,
-- DateStyle='ISO, MDY', TimeZone='UTC', standard_conforming_strings=on) at
-- step 15 and asserts it; the ledger row's bound parameters are interpreted
-- deterministically regardless of the artifact's attempt.
DO $b03$
BEGIN
    SET client_encoding = 'LATIN1';
    SET DateStyle = 'German, DMY';
    SET TimeZone = 'Asia/Kolkata';
    SET standard_conforming_strings = off;
END
$b03$;
