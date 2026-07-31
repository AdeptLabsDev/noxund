#!/usr/bin/env bash
# =============================================================================
# NOXUND P3B — root entrypoint wrapper (mirrors the P2 pattern).
# The stock postgres entrypoint runs /docker-entrypoint-initdb.d as the NON-root
# `postgres` user, which cannot read the root/host-owned Compose secret mounts.
# ONLY on a fresh volume do we, as ROOT, copy the migrator role secret into a
# container-only dir owned by `postgres` (0400) so the init can read it. The HOST
# secret file is never touched (stays 0600). On an already-initialized volume we
# copy NOTHING and ensure no readable copy lingers. NO `set -x` — never echo secrets.
# =============================================================================
set -euo pipefail

PGDATA_DIR="${PGDATA:-/var/lib/postgresql/data}"
DEST=/run/noxund-secrets

if [ ! -s "${PGDATA_DIR}/PG_VERSION" ]; then
  install -d -m 0500 -o postgres -g postgres "${DEST}"
  s=noxund_migrator_password
  if [ ! -s "/run/secrets/${s}" ]; then
    echo "entrypoint FATAL: missing Compose secret /run/secrets/${s}" >&2
    exit 1
  fi
  install -m 0400 -o postgres -g postgres "/run/secrets/${s}" "${DEST}/${s}"
else
  rm -rf "${DEST}" 2>/dev/null || true
fi

exec /usr/local/bin/docker-entrypoint.sh "$@"
