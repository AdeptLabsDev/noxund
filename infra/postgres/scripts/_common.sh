#!/usr/bin/env bash
# =============================================================================
# NOXUND local Postgres — shared helpers (sourced by the operational scripts).
# Everything is DISCOVERED from Compose (container/volume/network/port); nothing
# is hardcoded, so a different COMPOSE_PROJECT_NAME (e.g. in CI) never collides.
# =============================================================================
set -euo pipefail

# Project scope: default local; overridable (CI isolation).
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-noxund-local}"

# Resolve infra dir (this file lives in infra/postgres/scripts/).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${INFRA_DIR}/compose.local.yml"
SECRETS_DIR="${INFRA_DIR}/.local-secrets"

SERVICE="postgres"
SECRET_NAMES=(postgres_password noxund_migrator_password noxund_app_password)

# Compose wrapper — always this file + project dir (so relative paths resolve).
dc() { docker compose -f "${COMPOSE_FILE}" --project-directory "${INFRA_DIR}" "$@"; }

die() { echo "::error:: $*" >&2; exit 1; }
info() { echo "[$(date -u +%H:%M:%SZ)] $*"; }

# Discover the running container id for the postgres service (empty if down).
container_id() { dc ps -q "${SERVICE}" 2>/dev/null || true; }

# Discover the project-scoped volume via Compose labels (never hardcode the name).
volume_name() {
  docker volume ls -q \
    --filter "label=com.docker.compose.project=${COMPOSE_PROJECT_NAME}" \
    --filter "label=com.docker.compose.volume=pgdata" 2>/dev/null | head -n1
}

# Configured (static) host binding from the RENDERED compose config — works whether
# the service is up or down. Derived, never hardcoded.
configured_hostport() {
  dc config --format json 2>/dev/null | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin); p=d["services"]["postgres"]["ports"][0]
    print("%s:%s" % (p.get("host_ip","0.0.0.0"), p["published"]))
except Exception:
    pass'
}

# Runtime published binding (only meaningful when the container is up) — for status.
runtime_hostport() { dc port "${SERVICE}" 5432 2>/dev/null | head -n1; }

# Assert the CONFIGURED binding is loopback-only. Prints host:port on success.
assert_loopback() {
  local hp; hp="$(configured_hostport)"
  [ -n "${hp}" ] || die "cannot determine configured port from compose config."
  case "${hp}" in
    127.0.0.1:*) echo "${hp}" ;;
    *) die "configured binding '${hp}' is NOT loopback (127.0.0.1) — refusing." ;;
  esac
}

# Is the host TCP port currently accepting connections? (Git Bash/WSL /dev/tcp.)
port_open() {  # port_open <host> <port>
  (exec 3<>"/dev/tcp/$1/$2") 2>/dev/null && { exec 3>&- 3<&-; return 0; } || return 1
}

# psql inside the running container as the bootstrap superuser (admin checks).
psql_admin() { dc exec -T "${SERVICE}" psql -v ON_ERROR_STOP=1 --no-password \
  -U postgres -d noxund -h /var/run/postgresql "$@"; }

# The canonical marker query (single value or empty).
read_marker() {
  psql_admin -tAc "select marker from noxund_bootstrap.marker" 2>/dev/null | tr -d '[:space:]' || true
}

EXPECTED_MARKER="noxund-bootstrap:p2-v1"
