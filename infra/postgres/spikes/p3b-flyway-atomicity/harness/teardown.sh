#!/usr/bin/env bash
# P3B — project-scoped teardown ONLY. Removes exactly the noxund-p3b containers,
# network and volume. NEVER `docker volume prune`, NEVER touches noxund-local.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="noxund-p3b"
COMPOSE="docker compose -p ${PROJECT} -f ${HERE}/compose.spike.yml"

# Remove any lingering detached one-off flyway containers from this project.
docker ps -aq --filter "label=com.docker.compose.project=${PROJECT}" | while read -r c; do
  [ -n "$c" ] && docker rm -f "$c" >/dev/null 2>&1 || true
done

$COMPOSE down -v --remove-orphans
echo "P3B teardown complete (project ${PROJECT} only). noxund-local untouched."
