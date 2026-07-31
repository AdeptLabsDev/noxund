#!/usr/bin/env bash
# =============================================================================
# NOXUND P3B — spike role bootstrap (runs ONCE, on an empty volume, as the image
# bootstrap superuser, against flyway_spike over the local socket).
#
# Creates EXACTLY the two roles the least-privilege contract needs and hands the
# database + public schema to noxund_owner. FAIL-CLOSED: aborts if a canonical
# role already exists on first init. Secret handling mirrors P2: read from the
# mounted file, passed via psql \getenv (never argv), never printed, no `set -x`.
#
# Contract established here (verified later by LP-0):
#   noxund_owner     : NOLOGIN NOINHERIT — owns flyway_spike, schema public, and
#                      every object a migration creates (via SET ROLE in the callback).
#   noxund_migrator  : LOGIN   NOINHERIT — the only login Flyway uses; member of
#                      noxund_owner, so it can SET ROLE but inherits NO privilege
#                      until it does. Never a superuser.
# =============================================================================
set -euo pipefail   # deliberately NO `set -x` — would leak the secret.

trap 'rm -f /run/noxund-secrets/* 2>/dev/null || true; rmdir /run/noxund-secrets 2>/dev/null || true' EXIT

MIGRATOR_SECRET="/run/noxund-secrets/noxund_migrator_password"
if [ ! -s "$MIGRATOR_SECRET" ]; then
  echo "bootstrap FATAL: required secret file missing or empty: $MIGRATOR_SECRET" >&2
  exit 1
fi
NOXUND_MIGRATOR_PW="$(cat "$MIGRATOR_SECRET")"
export NOXUND_MIGRATOR_PW

psql -v ON_ERROR_STOP=1 --no-password \
     --username "${POSTGRES_USER:-postgres}" \
     --dbname "${POSTGRES_DB:-flyway_spike}" \
     --host /var/run/postgresql <<'SQL'
\set ON_ERROR_STOP on
\getenv migrator_pw NOXUND_MIGRATOR_PW

-- FAIL-CLOSED: no canonical role may pre-exist on a first, empty-volume init.
do $$
declare r text;
begin
  foreach r in array array['noxund_owner','noxund_migrator'] loop
    if to_regrole(r) is not null then
      raise exception 'P3B bootstrap: role % already exists on first init — refusing to adopt/modify (fail-closed).', r;
    end if;
  end loop;
end $$;

-- ---- canonical roles (least-privilege; never superuser, never BYPASSRLS) ----
create role noxund_owner
  nologin nosuperuser nocreatedb nocreaterole noinherit noreplication nobypassrls;

create role noxund_migrator
  login nosuperuser nocreatedb nocreaterole noinherit noreplication nobypassrls
  password :'migrator_pw';

-- Controlled membership: migrator may SET ROLE noxund_owner, but NOINHERIT means
-- it holds NONE of owner's privileges until it explicitly does so (the callback).
grant noxund_owner to noxund_migrator;

-- ---- database ownership + least-privilege ----
alter database flyway_spike owner to noxund_owner;
revoke all on database flyway_spike from public;
grant connect on database flyway_spike to noxund_migrator;

-- ---- schema public: owned by noxund_owner so the effective role (after SET ROLE)
--      owns flyway_schema_history and every migration object it creates ----
alter schema public owner to noxund_owner;
revoke create on schema public from public;

-- Marker (parity with P2; not an identity object).
create schema noxund_bootstrap authorization noxund_owner;
revoke all on schema noxund_bootstrap from public;
create table noxund_bootstrap.marker (
  marker     text primary key,
  created_at timestamptz not null default now()
);
alter table noxund_bootstrap.marker owner to noxund_owner;
insert into noxund_bootstrap.marker (marker) values ('noxund-p3b:v1');
SQL

echo "P3B bootstrap complete: noxund_owner/noxund_migrator created, flyway_spike + public handed to noxund_owner."
