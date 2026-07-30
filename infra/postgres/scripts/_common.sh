#!/usr/bin/env bash
# =============================================================================
# NOXUND local Postgres — shared helpers (sourced by the operational scripts).
# Everything is DISCOVERED from Compose (container/volume/network/port); nothing
# is hardcoded, so a different COMPOSE_PROJECT_NAME (e.g. in CI) never collides.
# The bootstrap CONTRACT (roles/attrs/memberships/owners/privs/settings/marker)
# lives HERE as ONE source of truth, shared by start-local and verify-local.
# =============================================================================
set -euo pipefail

# Project scope: default local; overridable (CI isolation).
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-noxund-local}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${INFRA_DIR}/compose.local.yml"
SECRETS_DIR="${INFRA_DIR}/.local-secrets"

SERVICE="postgres"
SECRET_NAMES=(postgres_password noxund_migrator_password noxund_app_password)
EXPECTED_MARKER="noxund-bootstrap:p2-v1"

dc() { docker compose -f "${COMPOSE_FILE}" --project-directory "${INFRA_DIR}" "$@"; }
die() { echo "::error:: $*" >&2; exit 1; }
info() { echo "[$(date -u +%H:%M:%SZ)] $*"; }

# ---------------------------------------------------------------------------
# STRICTLY-LOCAL DOCKER precondition (fail-closed). Must run before ANY docker
# op in every script/test. Accepts only a local unix (or Windows npipe) endpoint
# for the effective context; rejects tcp/ssh/http/https and any unavailable or
# ambiguous context. Never mutates the user's context.
# ---------------------------------------------------------------------------
assert_local_docker() {
  # 1) explicit override via DOCKER_HOST wins and must be a local unix socket.
  if [ -n "${DOCKER_HOST:-}" ]; then
    case "${DOCKER_HOST}" in
      unix://*|npipe://*) : ;;
      tcp://*|ssh://*|http://*|https://*)
        die "DOCKER_HOST='${DOCKER_HOST}' is a REMOTE daemon — refusing (strictly-local only)." ;;
      *) die "DOCKER_HOST='${DOCKER_HOST}' is not a recognized LOCAL endpoint — refusing (ambiguous)." ;;
    esac
    return 0
  fi
  # 2) resolve the effective context + its docker endpoint.
  local ctx ep
  ctx="$(docker context show 2>/dev/null || true)"
  [ -n "${ctx}" ] || die "docker context is unavailable/ambiguous — refusing."
  ep="$(docker context inspect "${ctx}" --format '{{ (index .Endpoints "docker").Host }}' 2>/dev/null || true)"
  [ -n "${ep}" ] || die "cannot resolve a docker endpoint for context '${ctx}' — refusing (ambiguous)."
  case "${ep}" in
    unix://*|npipe://*) : ;;  # local socket / Docker Desktop named pipe
    tcp://*|ssh://*|http://*|https://*)
      die "docker endpoint '${ep}' (context '${ctx}') is REMOTE — refusing (strictly-local only)." ;;
    *) die "docker endpoint '${ep}' (context '${ctx}') is not a recognized LOCAL endpoint — refusing (ambiguous)." ;;
  esac
}

# ---------------------------------------------------------------------------
# Secret-source safety: dir + each file must be regular (not symlink), present,
# non-empty, and NOT group/other accessible. Fail-closed.
# ---------------------------------------------------------------------------
assert_secret_source_safe() {
  local d="${SECRETS_DIR}"
  [ -e "${d}" ] || die "secrets dir missing — run scripts/prepare-local first."
  [ ! -L "${d}" ] || die "secrets dir '${d}' is a SYMLINK — refusing."
  [ -d "${d}" ] || die "secrets path '${d}' is not a directory — refusing."
  local dperm; dperm="$(stat -c '%a' "${d}")"
  [ "${dperm: -2}" = "00" ] || die "secrets dir perms ${dperm} insecure (group/other) — fix to 700. Refused."
  local name f perm
  for name in "${SECRET_NAMES[@]}"; do
    f="${d}/${name}"
    [ -e "${f}" ] || die "secret '${name}' missing — run scripts/prepare-local (refused BEFORE container)."
    [ ! -L "${f}" ] || die "secret '${name}' is a SYMLINK — refusing (regular file required)."
    [ -f "${f}" ] || die "secret '${name}' is not a regular file — refusing."
    [ -s "${f}" ] || die "secret '${name}' is empty — refusing."
    perm="$(stat -c '%a' "${f}")"
    [ "${perm: -2}" = "00" ] || die "secret '${name}' has insecure perms ${perm} (group/other can access) — fix to 600. Refused."
  done
}

# Discover the running container id for the postgres service (empty if down).
container_id() { dc ps -q "${SERVICE}" 2>/dev/null || true; }

# Discover the project-scoped volume via Compose labels (never hardcode the name).
volume_name() {
  docker volume ls -q \
    --filter "label=com.docker.compose.project=${COMPOSE_PROJECT_NAME}" \
    --filter "label=com.docker.compose.volume=pgdata" 2>/dev/null | head -n1
}

# CONFIGURED host binding from the RENDERED compose config — works up or down.
configured_hostport() {
  dc config --format json 2>/dev/null | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin); p=d["services"]["postgres"]["ports"][0]
    print("%s:%s" % (p.get("host_ip","0.0.0.0"), p["published"]))
except Exception:
    pass'
}
runtime_hostport() { dc port "${SERVICE}" 5432 2>/dev/null | head -n1; }

assert_loopback() {
  local hp; hp="$(configured_hostport)"
  [ -n "${hp}" ] || die "cannot determine configured port from compose config."
  case "${hp}" in
    127.0.0.1:*) echo "${hp}" ;;
    *) die "configured binding '${hp}' is NOT loopback (127.0.0.1) — refusing." ;;
  esac
}

# Image reference pinned in the rendered compose config, and the one the running
# container was actually created from (derivation proof).
compose_image() {
  dc config --format json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["services"]["postgres"]["image"])'
}
running_image() { docker inspect -f '{{.Config.Image}}' "$(container_id)" 2>/dev/null || true; }

# Is the host TCP port currently accepting connections? (/dev/tcp.)
port_open() { (exec 3<>"/dev/tcp/$1/$2") 2>/dev/null && { exec 3>&- 3<&-; return 0; } || return 1; }

# psql inside the running container as the bootstrap superuser (fail-closed).
psql_admin() { dc exec -T "${SERVICE}" psql -v ON_ERROR_STOP=1 --no-password \
  -U postgres -d noxund -h /var/run/postgresql "$@"; }

read_marker() { psql_admin -tAc "select marker from noxund_bootstrap.marker" 2>/dev/null | tr -d '[:space:]' || true; }

# ---------------------------------------------------------------------------
# THE SHARED BOOTSTRAP CONTRACT (single source of truth). Emits one row per
# check: id|ok|detail. `ok` is a boolean compared to the EXPECTED value inside
# SQL (not merely folded into a digest). Used by start-local (gate) AND
# verify-local (per-check report). No `$$` (quoted heredoc → no bash expansion).
# ---------------------------------------------------------------------------
catalog_contract_sql() {
  cat <<'SQL'
select id, ok, detail from (
  -- role attribute bits: canlogin,super,createdb,createrole,inherit,repl,bypassrls
  select 'role_owner_attrs' id,
    coalesce((select concat(rolcanlogin::int,rolsuper::int,rolcreatedb::int,rolcreaterole::int,rolinherit::int,rolreplication::int,rolbypassrls::int) from pg_roles where rolname='noxund_owner'),'MISSING')='0000000' ok,
    coalesce((select concat(rolcanlogin::int,rolsuper::int,rolcreatedb::int,rolcreaterole::int,rolinherit::int,rolreplication::int,rolbypassrls::int) from pg_roles where rolname='noxund_owner'),'MISSING') detail
  union all select 'role_migrator_attrs',
    coalesce((select concat(rolcanlogin::int,rolsuper::int,rolcreatedb::int,rolcreaterole::int,rolinherit::int,rolreplication::int,rolbypassrls::int) from pg_roles where rolname='noxund_migrator'),'MISSING')='1000000',
    coalesce((select concat(rolcanlogin::int,rolsuper::int,rolcreatedb::int,rolcreaterole::int,rolinherit::int,rolreplication::int,rolbypassrls::int) from pg_roles where rolname='noxund_migrator'),'MISSING')
  union all select 'role_app_attrs',
    coalesce((select concat(rolcanlogin::int,rolsuper::int,rolcreatedb::int,rolcreaterole::int,rolinherit::int,rolreplication::int,rolbypassrls::int) from pg_roles where rolname='noxund_app'),'MISSING')='1000000',
    coalesce((select concat(rolcanlogin::int,rolsuper::int,rolcreatedb::int,rolcreaterole::int,rolinherit::int,rolreplication::int,rolbypassrls::int) from pg_roles where rolname='noxund_app'),'MISSING')
  union all select 'role_sg8_attrs',
    coalesce((select concat(rolcanlogin::int,rolsuper::int,rolcreatedb::int,rolcreaterole::int,rolinherit::int,rolreplication::int,rolbypassrls::int) from pg_roles where rolname='sg8_compute_writer'),'MISSING')='0000000',
    coalesce((select concat(rolcanlogin::int,rolsuper::int,rolcreatedb::int,rolcreaterole::int,rolinherit::int,rolreplication::int,rolbypassrls::int) from pg_roles where rolname='sg8_compute_writer'),'MISSING')
  -- exactly one canonical-involving membership: migrator->owner, admin_option=false
  union all select 'membership_only_migrator_owner',
    (select count(*) from pg_auth_members am
       join pg_roles mm on mm.oid=am.member join pg_roles gg on gg.oid=am.roleid
      where (mm.rolname in ('noxund_owner','noxund_migrator','noxund_app','sg8_compute_writer')
          or gg.rolname in ('noxund_owner','noxund_migrator','noxund_app','sg8_compute_writer'))
        and not (mm.rolname='noxund_migrator' and gg.rolname='noxund_owner' and am.admin_option=false))=0,
    'no canonical membership other than migrator->owner(admin=false)'
  union all select 'membership_migrator_owner_present',
    exists(select 1 from pg_auth_members am join pg_roles mm on mm.oid=am.member join pg_roles gg on gg.oid=am.roleid
           where mm.rolname='noxund_migrator' and gg.rolname='noxund_owner' and am.admin_option=false),
    'migrator is member of owner without admin option'
  -- ownership
  union all select 'db_owner',
    coalesce((select pg_get_userbyid(datdba) from pg_database where datname='noxund'),'MISSING')='noxund_owner',
    coalesce((select pg_get_userbyid(datdba) from pg_database where datname='noxund'),'MISSING')
  union all select 'schema_public_owner',
    coalesce((select nspowner::regrole::text from pg_namespace where nspname='public'),'MISSING')='noxund_owner',
    coalesce((select nspowner::regrole::text from pg_namespace where nspname='public'),'MISSING')
  union all select 'schema_bootstrap_owner',
    coalesce((select nspowner::regrole::text from pg_namespace where nspname='noxund_bootstrap'),'MISSING')='noxund_owner',
    coalesce((select nspowner::regrole::text from pg_namespace where nspname='noxund_bootstrap'),'MISSING')
  -- PUBLIC has no CONNECT / TEMP / CREATE
  union all select 'public_no_connect', has_database_privilege('public','noxund','CONNECT')=false, 'PUBLIC CONNECT must be false'
  union all select 'public_no_temp',    has_database_privilege('public','noxund','TEMP')=false,    'PUBLIC TEMP must be false'
  union all select 'public_no_create',  has_schema_privilege('public','public','CREATE')=false,     'PUBLIC CREATE on public must be false'
  -- app: CONNECT + USAGE, no TEMP, no CREATE
  union all select 'app_connect',   has_database_privilege('noxund_app','noxund','CONNECT')=true, 'app CONNECT'
  union all select 'app_usage',     has_schema_privilege('noxund_app','public','USAGE')=true,      'app USAGE public'
  union all select 'app_no_temp',   has_database_privilege('noxund_app','noxund','TEMP')=false,    'app TEMP must be false'
  union all select 'app_no_create', has_schema_privilege('noxund_app','public','CREATE')=false,     'app CREATE must be false'
  -- SG-8 has no CONNECT (no grants until P7)
  union all select 'sg8_no_connect', has_database_privilege('sg8_compute_writer','noxund','CONNECT')=false, 'sg8 CONNECT must be false'
  -- server settings compared to expected
  union all select 'pg_version_150018', current_setting('server_version_num')='150018', current_setting('server_version_num')
  union all select 'data_checksums_on',  current_setting('data_checksums')='on',        current_setting('data_checksums')
  union all select 'server_encoding_utf8',current_setting('server_encoding')='UTF8',    current_setting('server_encoding')
  union all select 'datcollate_c_utf8',  coalesce((select datcollate from pg_database where datname='noxund'),'?')='C.UTF-8', coalesce((select datcollate from pg_database where datname='noxund'),'?')
  union all select 'datctype_c_utf8',    coalesce((select datctype  from pg_database where datname='noxund'),'?')='C.UTF-8', coalesce((select datctype  from pg_database where datname='noxund'),'?')
  union all select 'timezone_utc',       current_setting('TimeZone')='UTC',              current_setting('TimeZone')
  union all select 'log_timezone_utc',   current_setting('log_timezone')='UTC',          current_setting('log_timezone')
  union all select 'password_encryption_scram', current_setting('password_encryption')='scram-sha-256', current_setting('password_encryption')
  union all select 'host_hba_scram',
    (select count(*) from pg_hba_file_rules where type like 'host%' and auth_method <> 'scram-sha-256')=0,
    'all host HBA rules must be scram-sha-256'
  -- marker: exactly one, exact value
  union all select 'marker_unique', (select count(*) from noxund_bootstrap.marker)=1, 'exactly one marker row'
  union all select 'marker_value',
    coalesce((select marker from noxund_bootstrap.marker order by created_at limit 1),'MISSING')='noxund-bootstrap:p2-v1',
    coalesce((select marker from noxund_bootstrap.marker order by created_at limit 1),'MISSING')
) t order by id;
SQL
}

# Run the shared contract. Prints `CHK  <id> (ok)` / `CHKFAIL <id> :: <detail>`
# for each check; returns non-zero if ANY check fails (or the SQL itself errors).
check_catalog_contract() {
  local out rc=0
  if ! out="$(psql_admin -tA -F'|' -c "$(catalog_contract_sql)" 2>&1)"; then
    echo "CHKFAIL  contract_sql :: ${out}"
    return 1
  fi
  local id ok detail
  while IFS='|' read -r id ok detail; do
    [ -z "${id:-}" ] && continue
    if [ "${ok}" = "t" ]; then
      echo "CHK  ${id} (ok=${detail})"
    else
      echo "CHKFAIL  ${id} :: got '${detail}'"
      rc=1
    fi
  done <<< "${out}"
  return "${rc}"
}
