-- ATTACK B01 — artifact weakens durability (SET synchronous_commit = off).
-- Expected: the plain SET persists past the DO, but the runner reasserts
-- synchronous_commit=on at step 15 and asserts durability at step 20; if it
-- could not restore 'on', the runner FAILS the migration (fail-closed).
-- This is a VALID DO block (tag "DO"); the durability control is what is tested.
DO $b01$
BEGIN
    SET synchronous_commit = off;
    CREATE TABLE noxund_app_spike.b01_marker (i int);
END
$b01$;
