#!/usr/bin/env bash
# =============================================================================
# NOXUND — PG-EXIT-P3B2 — Flyway metadata-schema + atomicity falsification.
# Option A (restricted contract): noxund_migrator may create/administer objects
# ONLY in the control schema noxund_migration_meta (the ledger). It holds NO direct
# DDL on public/spike/business schemas. The migration executor still runs as
# noxund_owner (SET ROLE via afterConnect). The ledger lives at
# noxund_migration_meta.flyway_schema_history.
#
# Flow: bring-up -> capture control-schema grants -> LP-1 (V1 + revised contract
# proof) -> instrument (trigger on the meta ledger) -> hold advisory lock -> V2
# migrate blocks -> SIGKILL flyway only (PG stays up) -> inspect via an independent
# connection -> info/validate/fresh-migrate -> verdict.
#
# NEVER: docker volume prune; touch noxund-local; connect remote; repair/clean/
# baseline/undo; manual edit of the ledger; grant beyond noxund_migration_meta.
# =============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE"
PROJECT="noxund-p3b"
COMPOSE="docker compose -p ${PROJECT} -f ${HERE}/compose.spike.yml"
EV="${HERE}/evidence"
LOCK=902001
META="noxund_migration_meta"
HIST="noxund_migration_meta.flyway_schema_history"
PG_PIN="postgres:15.18-bookworm@sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51"
FLYWAY_PIN="flyway/flyway:13.1.0@sha256:3cc7587dcb678b67ab822984197237f84dfc65e0b19b98c52ea84d6ef8be1f4a"

rm -rf "$EV"; mkdir -p "$EV"
exec > >(tee "${EV}/run-transcript.log") 2>&1

log(){ echo "[$(date -u +%FT%TZ)] $*"; }
psql_su(){ $COMPOSE exec -T postgres psql -X -v ON_ERROR_STOP=1 -U postgres -d flyway_spike "$@"; }
q(){ psql_su -tAc "$1" | tr -d '\r[:space:]'; }
finish(){ echo "$1" > "${EV}/VERDICT.txt"; log "VERDICT: $1"; }

# ---------------------------------------------------------------------------
log "P3B2 start — project=${PROJECT}"
$COMPOSE down -v --remove-orphans >/dev/null 2>&1 || true
bash "${HERE}/harness/gen-secrets.sh"

# ---- 1. bring up postgres (bootstrap also creates the control schema + grants) ----
log "bringing up postgres (internal net, no ports)"
$COMPOSE up -d postgres
for i in $(seq 1 40); do
  st=$(docker inspect -f '{{.State.Health.Status}}' "$($COMPOSE ps -q postgres)" 2>/dev/null || echo starting)
  [ "$st" = "healthy" ] && break
  sleep 3
done
[ "$st" = "healthy" ] || { finish "ESCALATE — postgres did not become healthy"; exit 3; }
log "postgres healthy"

PGC="$($COMPOSE ps -q postgres)"
{
  echo "pinned  postgres : ${PG_PIN}"
  echo "running postgres : $(docker inspect -f '{{.Image}}' "$PGC")"
  echo "pinned  flyway   : ${FLYWAY_PIN}"
  echo "flyway RepoDigest: $(docker image inspect flyway/flyway:13.1.0 --format '{{json .RepoDigests}}')"
} > "${EV}/image-identity.txt"

# ---- 1b. capture the EXACT control-schema grants (returned to the Lead) ----
psql_su -c "\dn+ ${META}" > "${EV}/control-schema-grants.txt" 2>&1 || true
{
  echo "-- control schema owner + ACL --"
  echo "owner                          = $(q "SELECT pg_get_userbyid(nspowner) FROM pg_namespace WHERE nspname='${META}';")"
  echo "raw nspacl                     = $(q "SELECT COALESCE(array_to_string(nspacl,'|'),'(none)') FROM pg_namespace WHERE nspname='${META}';")"
  echo "migrator USAGE                 = $(q "SELECT has_schema_privilege('noxund_migrator','${META}','USAGE');")"
  echo "migrator CREATE                = $(q "SELECT has_schema_privilege('noxund_migrator','${META}','CREATE');")"
  echo "app      USAGE                 = $(q "SELECT has_schema_privilege('noxund_app','${META}','USAGE');")"
  echo "app      CREATE                = $(q "SELECT has_schema_privilege('noxund_app','${META}','CREATE');")"
  echo "sg8      USAGE                 = $(q "SELECT has_schema_privilege('sg8_compute_writer','${META}','USAGE');")"
  echo "sg8      CREATE                = $(q "SELECT has_schema_privilege('sg8_compute_writer','${META}','CREATE');")"
  echo "migrator CREATE on public      = $(q "SELECT has_schema_privilege('noxund_migrator','public','CREATE');")"
  echo "migrator CREATE on spike?      = $(q "SELECT CASE WHEN to_regnamespace('spike') IS NULL THEN 'no-spike-yet' ELSE has_schema_privilege('noxund_migrator','spike','CREATE')::text END;")"
} >> "${EV}/control-schema-grants.txt"
cat "${EV}/control-schema-grants.txt"

# ---- 2. LP-1: apply V1 only, then prove the revised least-privilege contract ----
log "LP-1: flyway migrate -target=1 (metadata conn creates ledger; executor applies V1)"
set +e
$COMPOSE run --rm flyway migrate -target=1 > "${EV}/flyway-v1-migrate.out" 2>&1
v1_exit=$?
set -e
log "V1 migrate exit=${v1_exit}"

set +e   # LP-1 probes must never abort the run; failed/empty => LP-1 fails => classified below.
hist_present=$(q "SELECT to_regclass('${HIST}') IS NOT NULL;")
hist_in_meta=$(q "SELECT count(*)>0 FROM pg_tables WHERE schemaname='${META}' AND tablename='flyway_schema_history';")
hist_owner=$(q   "SELECT tableowner FROM pg_tables WHERE schemaname='${META}' AND tablename='flyway_schema_history';")
if [ "$hist_present" = "t" ]; then
  v1_success=$(q "SELECT success FROM ${HIST} WHERE version='1';")
else
  v1_success="(no-history-table)"
fi
spike_owner=$(q  "SELECT CASE WHEN to_regnamespace('spike') IS NULL THEN '(no-spike)' ELSE pg_get_userbyid(nspowner)::text END FROM pg_namespace WHERE nspname='spike';")
mig_no_pub=$(q   "SELECT NOT has_schema_privilege('noxund_migrator','public','CREATE');")
mig_no_spike=$(q "SELECT CASE WHEN to_regnamespace('spike') IS NULL THEN true ELSE NOT has_schema_privilege('noxund_migrator','spike','CREATE') END;")
mig_meta_create=$(q "SELECT has_schema_privilege('noxund_migrator','${META}','CREATE');")
mig_meta_usage=$(q  "SELECT has_schema_privilege('noxund_migrator','${META}','USAGE');")
app_no_meta=$(q  "SELECT NOT (has_schema_privilege('noxund_app','${META}','USAGE') OR has_schema_privilege('noxund_app','${META}','CREATE'));")
sg8_no_meta=$(q  "SELECT NOT (has_schema_privilege('sg8_compute_writer','${META}','USAGE') OR has_schema_privilege('sg8_compute_writer','${META}','CREATE'));")
if [ "$hist_present" = "t" ]; then
  app_no_ledger=$(q "SELECT NOT (has_table_privilege('noxund_app','${HIST}','SELECT') OR has_table_privilege('noxund_app','${HIST}','INSERT'));")
  sg8_no_ledger=$(q "SELECT NOT (has_table_privilege('sg8_compute_writer','${HIST}','SELECT') OR has_table_privilege('sg8_compute_writer','${HIST}','INSERT'));")
else
  app_no_ledger="(no-history-table)"; sg8_no_ledger="(no-history-table)"
fi
extra_super=$(q  "SELECT count(*) FROM pg_roles WHERE rolsuper AND rolname NOT IN ('postgres');")
meta_owner_ok=$(q "SELECT pg_get_userbyid(nspowner)='noxund_owner' FROM pg_namespace WHERE nspname='${META}';")
conf_createschemas_false=$(grep -qiE '^flyway\.createSchemas=false' "${HERE}/flyway/conf/flyway.conf" && echo t || echo f)
set -e

{
  echo "v1_migrate_exit           = ${v1_exit}   (0 => V1 applied => executor session_user=noxund_migrator, current_user=noxund_owner)"
  echo "history_present           = ${hist_present}"
  echo "history_in_meta_schema    = ${hist_in_meta}"
  echo "history_owner             = ${hist_owner}   (expect noxund_migrator)"
  echo "v1_row_success            = ${v1_success}"
  echo "spike_schema_owner        = ${spike_owner}  (expect noxund_owner)"
  echo "migrator_no_create_public = ${mig_no_pub}"
  echo "migrator_no_create_spike  = ${mig_no_spike}"
  echo "migrator_CREATE_meta      = ${mig_meta_create}"
  echo "migrator_USAGE_meta       = ${mig_meta_usage}"
  echo "app_no_meta_priv          = ${app_no_meta}"
  echo "sg8_no_meta_priv          = ${sg8_no_meta}"
  echo "app_no_ledger_access      = ${app_no_ledger}"
  echo "sg8_no_ledger_access      = ${sg8_no_ledger}"
  echo "no_extra_superuser        = $([ "${extra_super}" = "0" ] && echo t || echo f) (extra=${extra_super})"
  echo "meta_owner_is_owner       = ${meta_owner_ok}   (bootstrap-created, not Flyway)"
  echo "conf_createSchemas_false  = ${conf_createschemas_false}"
} > "${EV}/lp1-checks.out"
cat "${EV}/lp1-checks.out"
grep -iE 'permission denied|SQL State|Schema History table|SET ROLE|Executing SQL callback|ERROR' "${EV}/flyway-v1-migrate.out" > "${EV}/lp1-rootcause-flyway.txt" 2>/dev/null || true

lp1_ok=t
for v in "$v1_exit=0" "$hist_present=t" "$hist_in_meta=t" "$hist_owner=noxund_migrator" "$v1_success=t" \
         "$spike_owner=noxund_owner" "$mig_no_pub=t" "$mig_no_spike=t" "$mig_meta_create=t" "$mig_meta_usage=t" \
         "$app_no_meta=t" "$sg8_no_meta=t" "$app_no_ledger=t" "$sg8_no_ledger=t" "$extra_super=0" \
         "$meta_owner_ok=t" "$conf_createschemas_false=t"; do
  [ "${v%=*}" = "${v#*=}" ] || lp1_ok=f
done

if [ "$lp1_ok" != "t" ]; then
  # Classify per the Lead: a permission-denied during a migration/ledger op means an
  # application migration ran as migrator without SET ROLE, or the ledger write would
  # need grants beyond noxund_migration_meta -> REJECT. Otherwise LP-1 unsupported -> ESCALATE.
  if grep -qiE 'permission denied' "${EV}/flyway-v1-migrate.out"; then
    verdict="REJECT FLYWAY"
    cause="A migration/ledger operation needs privilege beyond noxund_migration_meta (migration ran as migrator without SET ROLE, or the ledger write requires grants outside the control schema). Extending grants is a REJECT condition, not a workaround."
  else
    verdict="ESCALATE — LP-1 CONTRACT NOT SUPPORTED"
    cause="LP-1 not satisfied on the revised contract (see lp1-checks.out)."
  fi
  { echo "# P3B2 ${verdict}"; echo; echo "$cause"; echo;
    echo "Per Bloco: no privilege expansion, no postgres identity, no fatal test, no auto-rerun."; } > "${EV}/LP1-FAIL-rootcause.md"
  finish "$verdict"
  log "LP-1 failed — NOT installing triggers, NOT running V2, no privilege expansion."
  exit 4
fi
log "LP-1 GREEN"

# ---- 3. install fatal instrumentation (superuser; instrumentation only) ----
log "installing instrumentation (event trigger + BEFORE INSERT block trigger on the meta ledger)"
psql_su -f - < "${HERE}/harness/instrument.sql" > "${EV}/instrument.out" 2>&1

# ---- 4. controller holds the advisory lock (background session) ----
log "controller acquiring advisory lock ${LOCK}"
$COMPOSE exec -T postgres psql -X -U postgres -d flyway_spike > "${EV}/controller.out" 2>&1 <<'SQL' &
SET application_name = 'p3b_controller';
SELECT pg_advisory_lock(902001);
SELECT pg_sleep(600);
SQL
CONTROLLER_LOCAL_PID=$!
held=0
for i in $(seq 1 30); do
  held=$(q "SELECT count(*) FROM pg_locks l JOIN pg_stat_activity a ON a.pid=l.pid WHERE l.locktype='advisory' AND l.granted AND a.application_name='p3b_controller';")
  [ "${held:-0}" -ge 1 ] && break
  sleep 1
done
[ "${held:-0}" -ge 1 ] || { finish "ESCALATE — controller could not acquire advisory lock"; exit 3; }
log "controller holds advisory lock"

# ---- 5. launch V2 migrate (detached) so we can SIGKILL it in the window ----
log "launching flyway migrate for V2 (detached)"
CID=$($COMPOSE run -d flyway migrate 2>"${EV}/flyway-v2-run.err" | tail -1 | tr -d '\r[:space:]')
[ -n "$CID" ] || { finish "ESCALATE — could not launch flyway V2 container"; exit 3; }
log "flyway V2 container=${CID}"

# ---- 6. wait for the deterministic window: history trigger logged AND blocked ----
window=f
for i in $(seq 1 120); do
  hist_log=$($COMPOSE logs postgres 2>/dev/null | grep -c 'P3B_FATAL history version=2' || true)
  blocked=$(q "SELECT count(*) FROM pg_locks l JOIN pg_stat_activity a ON a.pid=l.pid WHERE l.locktype='advisory' AND NOT l.granted AND a.application_name IS DISTINCT FROM 'p3b_controller';")
  if [ "${hist_log:-0}" -ge 1 ] && [ "${blocked:-0}" -ge 1 ]; then window=t; break; fi
  running=$(docker inspect -f '{{.State.Running}}' "$CID" 2>/dev/null || echo false)
  if [ "$running" != "true" ] && [ "${blocked:-0}" -lt 1 ]; then
    docker logs "$CID" > "${EV}/flyway-v2.log" 2>&1 || true
    finish "ESCALATE — flyway V2 exited before reaching the block window (instrumentation did not hit the window deterministically)"
    exit 5
  fi
  sleep 1
done
[ "$window" = "t" ] || { docker logs "$CID" > "${EV}/flyway-v2.log" 2>&1 || true; finish "ESCALATE — deterministic window not reached"; exit 5; }
log "deterministic window reached (V2 history INSERT blocked in-transaction)"

# ---- parse PID/XID from the durable server log (survives the kill) ----
LOGS=$($COMPOSE logs postgres 2>/dev/null)
printf '%s\n' "$LOGS" | grep 'P3B_FATAL' > "${EV}/pglog-p3b-markers.txt" || true
ddl_line=$(printf '%s\n' "$LOGS" | grep 'P3B_FATAL ddl'     | tail -1 || true)
his_line=$(printf '%s\n' "$LOGS" | grep 'P3B_FATAL history' | tail -1 || true)
ddl_pid=$(printf '%s' "$ddl_line" | sed -n 's/.*pid=\([0-9]\{1,\}\).*/\1/p')
ddl_xid=$(printf '%s' "$ddl_line" | sed -n 's/.*xid=\([0-9]\{1,\}\).*/\1/p')
his_pid=$(printf '%s' "$his_line" | sed -n 's/.*pid=\([0-9]\{1,\}\).*/\1/p')
his_xid=$(printf '%s' "$his_line" | sed -n 's/.*xid=\([0-9]\{1,\}\).*/\1/p')
log "captured DDL pid=${ddl_pid} xid=${ddl_xid} ; HISTORY pid=${his_pid} xid=${his_xid}"

# ---- 7. SIGKILL flyway ONLY; PostgreSQL stays up ----
log "SIGKILL flyway container only"
docker kill --signal=KILL "$CID" >/dev/null 2>&1 || true
sleep 2
FLYWAY_EXIT=$(docker inspect -f '{{.State.ExitCode}}' "$CID" 2>/dev/null || echo NA)
docker logs "$CID" > "${EV}/flyway-v2.log" 2>&1 || true
log "flyway container exit code=${FLYWAY_EXIT}"

# ---- 8. wait for the killed backend to roll back, then inspect independently ----
if [ -n "${his_pid}" ]; then
  for i in $(seq 1 30); do
    alive=$(q "SELECT count(*) FROM pg_stat_activity WHERE pid=${his_pid};")
    [ "${alive:-0}" -eq 0 ] && break
    sleep 1
  done
fi

tbl=$(q     "SELECT to_regclass('spike.flyway_atomicity_gap_probe') IS NOT NULL;")
hrow=$(q    "SELECT count(*) FROM ${HIST} WHERE version='2';")
sfalse=$(q  "SELECT count(*) FROM ${HIST} WHERE success=false;")
prep=$(q    "SELECT count(*) FROM pg_prepared_xacts;")
idle=$(q    "SELECT count(*) FROM pg_stat_activity WHERE state='idle in transaction';")
orphan=$([ -n "${his_pid}" ] && q "SELECT count(*) FROM pg_locks WHERE pid=${his_pid};" || echo 0)
adv_ungranted=$(q "SELECT count(*) FROM pg_locks WHERE locktype='advisory' AND NOT granted;")

psql_su -c "TABLE ${HIST};"                                          > "${EV}/history-after-kill.txt" 2>&1 || true
psql_su -c "SELECT locktype,granted,pid FROM pg_locks ORDER BY 1,3;"  > "${EV}/pg_locks-after-kill.txt" 2>&1 || true
psql_su -c "SELECT pid,state,application_name,wait_event_type,wait_event FROM pg_stat_activity;" > "${EV}/pg_stat_activity-after-kill.txt" 2>&1 || true
psql_su -c "TABLE pg_prepared_xacts;"                                 > "${EV}/pg_prepared_xacts.txt" 2>&1 || true
{
  echo "table_present_after_kill   = ${tbl}      (expect f)"
  echo "history_v2_rows_after_kill = ${hrow}     (expect 0)"
  echo "success_false_rows         = ${sfalse}   (expect 0)"
  echo "prepared_xacts             = ${prep}     (expect 0)"
  echo "idle_in_transaction        = ${idle}     (expect 0)"
  echo "locks_held_by_dead_pid     = ${orphan}   (expect 0)"
  echo "advisory_ungranted         = ${adv_ungranted}"
  echo "ddl_pid=${ddl_pid} his_pid=${his_pid} (expect equal & non-empty)"
  echo "ddl_xid=${ddl_xid} his_xid=${his_xid} (expect equal & non-empty)"
  echo "flyway_container_exit      = ${FLYWAY_EXIT} (expect 137 = SIGKILL)"
} > "${EV}/inspection.out"
cat "${EV}/inspection.out"

# ---- 9. release controller, drop triggers, then info/validate/fresh-migrate ----
log "releasing controller + dropping instrumentation (no repair)"
psql_su -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE application_name='p3b_controller';" >/dev/null 2>&1 || true
kill "${CONTROLLER_LOCAL_PID}" 2>/dev/null || true
psql_su -c "DROP EVENT TRIGGER IF EXISTS p3b_v2_ddl;" >/dev/null 2>&1 || true
psql_su -c "DROP TRIGGER IF EXISTS p3b_block_v2 ON ${HIST};" >/dev/null 2>&1 || true

set +e
$COMPOSE run --rm flyway info     > "${EV}/flyway-info.out" 2>&1;          info_exit=$?
$COMPOSE run --rm flyway validate > "${EV}/flyway-validate.out" 2>&1;      val_exit=$?
$COMPOSE run --rm flyway migrate  > "${EV}/flyway-fresh-migrate.out" 2>&1; fresh_exit=$?
set -e
log "info_exit=${info_exit} validate_exit=${val_exit} fresh_migrate_exit=${fresh_exit}"

tbl2=$(q  "SELECT to_regclass('spike.flyway_atomicity_gap_probe') IS NOT NULL;")
hrow2=$(q "SELECT count(*) FROM ${HIST} WHERE version='2' AND success=true;")
psql_su -c "TABLE ${HIST};" > "${EV}/history-after-fresh-migrate.txt" 2>&1 || true
echo "after_fresh_migrate: table_present=${tbl2} (expect t) ; v2_success_rows=${hrow2} (expect >=1)" >> "${EV}/inspection.out"

# ---- 10. verdict ----
verdict="REJECT FLYWAY"
if [ "$tbl" = "f" ] && [ "${hrow:-1}" -eq 0 ] \
   && [ -n "$ddl_pid" ] && [ "$ddl_pid" = "$his_pid" ] \
   && [ -n "$ddl_xid" ] && [ "$ddl_xid" = "$his_xid" ] \
   && [ "${sfalse:-1}" -eq 0 ] && [ "${prep:-1}" -eq 0 ] \
   && [ "${orphan:-1}" -eq 0 ] && [ "${idle:-1}" -eq 0 ] \
   && [ "${fresh_exit:-1}" -eq 0 ] && [ "$tbl2" = "t" ] && [ "${hrow2:-0}" -ge 1 ]; then
  verdict="PASS ATOMICITY"
fi
finish "$verdict"
log "P3B2 done. Evidence in ${EV}. (No teardown here — run harness/teardown.sh after review.)"
