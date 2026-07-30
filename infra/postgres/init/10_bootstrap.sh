#!/usr/bin/env bash
# =============================================================================
# NOXUND — first-init bootstrap (PG-EXIT-P2 / DEC-0028).
# Runs ONCE, only on an EMPTY volume (docker-entrypoint-initdb.d contract), as
# the image bootstrap superuser, against POSTGRES_DB over the local socket.
#
# Creates exactly the 4 canonical roles, hardens the database/schema, and writes
# the canonical completion marker `noxund-bootstrap:p2-v1`. FAIL-CLOSED: if any
# canonical role already exists unexpectedly on this first init, it ABORTS —
# never adopts or modifies a pre-existing identity silently.
#
# Secret handling (binding): passwords are read from the mounted secret FILES,
# exported to the environment for psql `\getenv` (so they NEVER appear in a
# process ARGV), NEVER printed, and this script NEVER enables `set -x`.
# =============================================================================
set -euo pipefail   # NOTE: deliberately NO `set -x` — would leak secrets.

# Readable copies produced by the root entrypoint wrapper (init runs as postgres,
# which cannot read the root-owned /run/secrets mounts). Host files stay 0600.
MIGRATOR_SECRET="/run/noxund-secrets/noxund_migrator_password"
APP_SECRET="/run/noxund-secrets/noxund_app_password"

for f in "$MIGRATOR_SECRET" "$APP_SECRET"; do
  if [ ! -s "$f" ]; then
    echo "bootstrap FATAL: required secret file missing or empty: $f" >&2
    exit 1
  fi
done

# Export to env (consumed by psql \getenv — not passed as argv, never echoed).
NOXUND_MIGRATOR_PW="$(cat "$MIGRATOR_SECRET")"
NOXUND_APP_PW="$(cat "$APP_SECRET")"
export NOXUND_MIGRATOR_PW NOXUND_APP_PW

# psql over the local socket as the bootstrap superuser. ON_ERROR_STOP makes any
# failure fatal (fail-closed). No -a/-e/--echo-all → statements are not echoed.
psql -v ON_ERROR_STOP=1 --no-password \
     --username "${POSTGRES_USER:-postgres}" \
     --dbname "${POSTGRES_DB:-noxund}" \
     --host /var/run/postgresql <<'SQL'
\set ON_ERROR_STOP on
\getenv migrator_pw NOXUND_MIGRATOR_PW
\getenv app_pw NOXUND_APP_PW

-- FAIL-CLOSED: no canonical role may pre-exist on a first, empty-volume init.
do $$
declare r text;
begin
  foreach r in array array['noxund_owner','noxund_migrator','noxund_app','sg8_compute_writer'] loop
    if to_regrole(r) is not null then
      raise exception 'NOXUND bootstrap: role % already exists on first init — refusing to adopt/modify (fail-closed). Investigate the volume.', r;
    end if;
  end loop;
end $$;

-- ---- canonical roles (exact attributes; DEC-0028 §5) ----
create role noxund_owner
  nologin nosuperuser nocreatedb nocreaterole noinherit noreplication nobypassrls;

create role noxund_migrator
  login nosuperuser nocreatedb nocreaterole noinherit noreplication nobypassrls
  password :'migrator_pw';
grant noxund_owner to noxund_migrator;   -- controlled member; SET ROLE only during migrations

create role noxund_app
  login nosuperuser nocreatedb nocreaterole noinherit noreplication nobypassrls
  password :'app_pw';

create role sg8_compute_writer
  nologin nosuperuser nocreatedb nocreaterole noinherit noreplication nobypassrls;

-- ---- database ownership + least-privilege ----
alter database noxund owner to noxund_owner;
revoke all on database noxund from public;
-- CONNECT only where approved (migrator + app). sg8_compute_writer: NO grants until P7.
grant connect on database noxund to noxund_migrator, noxund_app;

-- ---- schema public hardening (PG15 already revokes CREATE from PUBLIC; reinforce) ----
alter schema public owner to noxund_owner;
revoke create on schema public from public;
grant usage on schema public to noxund_app;   -- USAGE only; ZERO table grants (no vanilla schema yet)

-- ---- canonical completion marker (NOT identity; noxund_identity is P4) ----
create schema noxund_bootstrap authorization noxund_owner;
revoke all on schema noxund_bootstrap from public;
create table noxund_bootstrap.marker (
  marker     text primary key,
  created_at timestamptz not null default now()
);
alter table noxund_bootstrap.marker owner to noxund_owner;
revoke all on table noxund_bootstrap.marker from public;
insert into noxund_bootstrap.marker (marker) values ('noxund-bootstrap:p2-v1');
SQL

echo "NOXUND bootstrap complete: roles created, database/schema hardened, marker noxund-bootstrap:p2-v1 written."
