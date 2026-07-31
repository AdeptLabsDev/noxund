-- P3B V1 — prepare the spike + LP-0 fail-closed guard.
-- The guard proves the afterConnect callback established the least-privilege
-- identity on THIS migration connection: the login is noxund_migrator, the
-- effective role is noxund_owner. If either is wrong, the migration ABORTS
-- (fail-closed) and LP-0 escalates — no fatal test is attempted.
DO $$
BEGIN
  IF session_user <> 'noxund_migrator' OR current_user <> 'noxund_owner' THEN
    RAISE EXCEPTION 'P3B least-privilege contract violated: session_user=%, current_user=%',
      session_user, current_user;
  END IF;
END
$$;

-- Schema for the synthetic probe object. Created by the effective role
-- (noxund_owner), so it — and everything under it — is owned by noxund_owner.
CREATE SCHEMA IF NOT EXISTS spike;
