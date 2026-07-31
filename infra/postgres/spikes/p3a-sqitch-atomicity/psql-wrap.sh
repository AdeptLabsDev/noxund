#!/usr/bin/env bash
# NOXUND PG-EXIT-P3A — instrumented psql client (core.pg.client).
# Runs the REAL psql UNCHANGED. On an ARMED fatal deploy that returns 0, it
# signals the deploy SQL has COMMITTED, then BLOCKS deterministically — freezing
# Sqitch AFTER the deploy COMMIT but BEFORE log_deploy_change(). It NEVER alters
# SQL and NEVER records credentials (password arrives via PGPASSWORD env, never
# on argv; the env is not logged).
set -u
WORK=/tmp/work
mkdir -p "$WORK/markers"
ts() { date -u +%Y-%m-%dT%H:%M:%S.%NZ; }
printf 'INVOKE %s argv=[%s]\n' "$(ts)" "$*" >> "$WORK/psql-invocations.log"
/usr/bin/psql "$@"
rc=$?
printf 'RESULT %s rc=%s\n' "$(ts)" "$rc" >> "$WORK/psql-invocations.log"
# Arm only for the fatal change: require ARM flag AND the target deploy file in argv.
if [ -f "$WORK/ARM" ] && [ "$rc" -eq 0 ] && printf '%s' "$*" | grep -q 'atomicity_gap_probe'; then
  ts > "$WORK/markers/DEPLOY_SQL_COMMITTED"
  sleep 300   # container-side freeze; host kills the container within this window
fi
exit "$rc"
