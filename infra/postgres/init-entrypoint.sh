#!/usr/bin/env bash
# =============================================================================
# NOXUND root entrypoint wrapper (PG-EXIT-P2).
# The stock postgres entrypoint runs /docker-entrypoint-initdb.d as the NON-root
# `postgres` user, which cannot read the root/host-owned Compose secret mounts
# (Compose ignores secret `mode` in non-swarm, so /run/secrets/* keep the host's
# 0600 ownership). As ROOT (before the stock entrypoint drops privileges) we copy
# ONLY the custom ROLE secrets into a container-only dir owned by `postgres`
# (0400). The HOST secret files are never touched (they stay 0600). Then we exec
# the stock entrypoint unchanged. NO `set -x` — secret content is never echoed.
# =============================================================================
set -euo pipefail

DEST=/run/noxund-secrets
install -d -m 0500 -o postgres -g postgres "${DEST}"
for s in noxund_migrator_password noxund_app_password; do
  if [ ! -s "/run/secrets/${s}" ]; then
    echo "entrypoint FATAL: missing Compose secret /run/secrets/${s}" >&2
    exit 1
  fi
  install -m 0400 -o postgres -g postgres "/run/secrets/${s}" "${DEST}/${s}"
done

exec /usr/local/bin/docker-entrypoint.sh "$@"
