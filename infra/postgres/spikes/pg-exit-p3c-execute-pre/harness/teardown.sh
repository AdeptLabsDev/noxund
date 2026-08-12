#!/usr/bin/env bash
# =============================================================================
# teardown.sh — PROJECT-SCOPED teardown ONLY. IMPLEMENTED, NOT EXECUTED here.
# Destroys the disposable spike stack for ONE project. It NEVER runs a global
# prune (`docker volume prune` / `docker system prune`) and refuses to run
# without an explicit project name.
# =============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${1:-}"

if [[ -z "${PROJECT}" ]]; then
  echo "usage: teardown.sh <COMPOSE_PROJECT_NAME>  (project-scoped; never a global prune)" >&2
  exit 2
fi
case "${PROJECT}" in
  noxund-local|"" ) echo "refusing: '${PROJECT}' is not a disposable spike project" >&2; exit 3 ;;
esac

echo "tearing down project-scoped stack: ${PROJECT}"
docker compose -p "${PROJECT}" -f "${HERE}/compose.spike.yml" down -v --remove-orphans

# Remove ephemeral secrets for this run (best-effort; they are gitignored).
rm -f "${HERE}/.ephemeral/postgres_password" \
      "${HERE}/.ephemeral/noxund_migrator_password" \
      "${HERE}/.ephemeral/noxund_app_password" 2>/dev/null || true

echo "OK — project ${PROJECT} destroyed. No global prune was run."
