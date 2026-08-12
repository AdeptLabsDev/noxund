#!/usr/bin/env bash
# =============================================================================
# gen-ephemeral-credentials.sh — RUNTIME ONLY (execute gate).
# Generates ephemeral, single-run credentials under ./.ephemeral (gitignored,
# 0600). NEVER writes them to a tracked file or to evidence output. This script
# is NOT run in the implementation unit; it exists so the future gate can create
# throwaway secrets without any static password ever entering the repository.
# =============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRET_DIR="${HERE}/.ephemeral"

# Hard guard: refuse unless the execute gate is explicitly authorized.
if [[ "${NOXUND_P3C_EXECUTE_GATE:-}" != "AUTHORIZED" ]]; then
  echo "IMPLEMENTED, NOT EXECUTED — set NOXUND_P3C_EXECUTE_GATE=AUTHORIZED under a Product Lead execute GO to run." >&2
  exit 2
fi

umask 077
mkdir -p "${SECRET_DIR}"

gen() { # 32 bytes of CSPRNG, url-safe, no newline
  if command -v openssl >/dev/null 2>&1; then openssl rand -base64 24 | tr -d '\n';
  else head -c 24 /dev/urandom | base64 | tr -d '\n'; fi
}

for name in postgres_password noxund_migrator_password noxund_app_password; do
  f="${SECRET_DIR}/${name}"
  printf '%s' "$(gen)" > "${f}"
  chmod 600 "${f}"
  echo "ephemeral secret written: ${f} (0600)"
done

echo "OK — ephemeral credentials generated. They are gitignored and never emitted to evidence."
