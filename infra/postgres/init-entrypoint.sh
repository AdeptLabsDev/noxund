#!/usr/bin/env bash
# =============================================================================
# NOXUND root entrypoint wrapper (PG-EXIT-P2).
# The stock postgres entrypoint runs /docker-entrypoint-initdb.d as the NON-root
# `postgres` user, which cannot read the root/host-owned Compose secret mounts.
# ONLY when the volume still requires bootstrap (empty PGDATA) do we, as ROOT,
# copy the custom ROLE secrets into a container-only dir owned by `postgres`
# (0400) so the init can read them. The HOST secret files are never touched
# (they stay 0600). On an ALREADY-initialized volume we copy NOTHING and ensure
# no postgres-readable copy lingers — only the original Compose mounts remain.
# Then exec the stock entrypoint unchanged. NO `set -x` — never echo secrets.
# =============================================================================
set -euo pipefail

PGDATA_DIR="${PGDATA:-/var/lib/postgresql/data}"
DEST=/run/noxund-secrets

if [ ! -s "${PGDATA_DIR}/PG_VERSION" ]; then
  # fresh volume -> bootstrap (initdb.d) will run and needs readable role secrets.
  install -d -m 0500 -o postgres -g postgres "${DEST}"
  for s in noxund_migrator_password noxund_app_password; do
    if [ ! -s "/run/secrets/${s}" ]; then
      echo "entrypoint FATAL: missing Compose secret /run/secrets/${s}" >&2
      exit 1
    fi
    install -m 0400 -o postgres -g postgres "/run/secrets/${s}" "${DEST}/${s}"
  done
else
  # already-initialized: NEVER copy; make sure no readable copy is left behind.
  rm -rf "${DEST}" 2>/dev/null || true
fi

exec /usr/local/bin/docker-entrypoint.sh "$@"
