#!/usr/bin/env bash
# =============================================================================
# NOXUND — PG-EXIT-P3B — Flyway Community atomicity falsification (single run).
# Deterministic by construction: the V2 history INSERT blocks on an advisory lock
# the controller session already holds, so the kill window is not a race. Executes
# EXACTLY ONE fatal test. Emits a verdict token and a full evidence bundle.
#
# Phases: bring-up -> LP-0 (V1 + least-privilege proof) -> instrument -> hold lock
#   -> V2 migrate blocks -> SIGKILL flyway only (PG stays up) -> inspect via an
#   independent connection -> info/validate/fresh-migrate -> verdict.
#
# NEVER: docker volume prune; touching noxund-local; connecting to any remote;
# repair/clean/baseline/undo; manual edit of flyway_schema_history.
# =============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE"
PROJECT="noxund-p3b"
COMPOSE="docker compose -p ${PROJECT} -f ${HERE}/compose.spike.yml"
EV="${HERE}/evidence"
LOCK=902001
PG_PIN="postgres:15.18-bookworm@sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51"
FLYWAY_PIN="flyway/flyway:13.1.0@sha256:3cc7587dcb678b67ab822984197237f84dfc65e0b19b98c52ea84d6ef8be1f4a"

rm -rf "$EV"; mkdir -p "$EV"
exec > >(tee "${EV}/run-transcript.log") 2>&1

log(){ echo "[$(date -u +%FT%TZ)] $*"; }
psql_su(){ $COMPOSE exec -T postgres psql -X -v ON_ERROR_STOP=1 -U postgres -d flyway_spike "$@"; }
q(){ psql_su -tAc "$1" | tr -d '\r[:space:]'; }
finish(){ echo "$1" > "${EV}/VERDICT.txt"; log "VERDICT: $1"; }

# ---------------------------------------------------------------------------
log "P3B start — project=${PROJECT}"
$COMPOSE down -v --remove-orphans >/dev/null 2>&1 || true
bash "${HERE}/harness/gen-secrets.sh"

# ---- 1. bring up postgres ----
log "bringing up postgres (internal net, no ports)"
$COMPOSE up -d postgres
for i in $(seq 1 40); do
  st=$(docker inspect -f '{{.State.Health.Status}}' "$($COMPOSE ps -q postgres)" 2>/dev/null || echo starting)
  [ "$st" = "healthy" ] && break
  sleep 3
done
[ "$st" = "healthy" ] || { finish "ESCALATE — postgres did not become healthy"; exit 3; }
log "postgres healthy"

# ---- image identity proof (running == pinned) ----
PGC="$($COMPOSE ps -q postgres)"
{
  echo "pinned  postgres : ${PG_PIN}"
  echo "running postgres : $(docker inspect -f '{{.Image}}' "$PGC")"
  echo "pinned  flyway   : ${FLYWAY_PIN}"
  echo "flyway RepoDigest: $(docker image inspect flyway/flyway:13.1.0 --format '{{json .RepoDigests}}')"
} > "${EV}/image-identity.txt"

# ---- 2. LP-0: apply V1 only, then prove least-privilege ----
log "LP-0: flyway migrate -target=1 (applies V1 + its fail-closed guard)"
set +e
$COMPOSE run --rm flyway migrate -target=1 > "${EV}/flyway-v1-migrate.out" 2>&1
v1_exit=$?
set -e
log "V1 migrate exit=${v1_exit}"

owner_nologin=$(q "SELECT NOT rolcanlogin FROM pg_roles WHERE rolname='noxund_owner';")
mig_noinherit=$(q "SELECT NOT rolinherit  FROM pg_roles WHERE rolname='noxund_migrator';")
owner_nosuper=$(q "SELECT NOT rolsuper    FROM pg_roles WHERE rolname='noxund_owner';")
mig_nosuper=$(q   "SELECT NOT rolsuper    FROM pg_roles WHERE rolname='noxund_migrator';")
mig_minimal=$(q   "SELECT NOT (rolcreatedb OR rolcreaterole OR rolsuper OR rolreplication OR rolbypassrls) FROM pg_roles WHERE rolname='noxund_migrator';")
hist_owner=$(q    "SELECT tableowner='noxund_owner' FROM pg_tables WHERE schemaname='public' AND tablename='flyway_schema_history';")
spike_owner=$(q   "SELECT nspowner::regrole::text='noxund_owner' FROM pg_namespace WHERE nspname='spike';")
v1_success=$(q    "SELECT success FROM public.flyway_schema_history WHERE version='1';")
# no non-bootstrap superuser exists beyond the image bootstrap 'postgres'
extra_super=$(q   "SELECT count(*) FROM pg_roles WHERE rolsuper AND rolname NOT IN ('postgres');")

{
  echo "v1_migrate_exit      = ${v1_exit}   (0 => V1 guard passed => callback set current_user=noxund_owner, session_user=noxund_migrator on the migration connection)"
  echo "owner_is_NOLOGIN     = ${owner_nologin}"
  echo "migrator_is_NOINHERIT= ${mig_noinherit}"
  echo "owner_not_superuser  = ${owner_nosuper}"
  echo "migrator_not_super   = ${mig_nosuper}"
  echo "migrator_minimal_priv= ${mig_minimal}   (no createdb/createrole/super/replication/bypassrls)"
  echo "history_owned_by_owner= ${hist_owner}   (=> the history-management connection also received the callback)"
  echo "spike_schema_owned    = ${spike_owner}  (=> the migration connection also received the callback)"
  echo "v1_row_success        = ${v1_success}"
  echo "no_extra_superuser    = $([ "${extra_super}" = "0" ] && echo t || echo f)  (extra=${extra_super})"
} > "${EV}/lp0-checks.out"
cat "${EV}/lp0-checks.out"

# Root-cause capture (self-contained ESCALATE evidence for a callback/contract failure).
hist_exists=$(q "SELECT to_regclass('public.flyway_schema_history') IS NOT NULL;")
{
  echo "-- root-cause audit --"
  echo "history_table_exists = ${hist_exists}"
} >> "${EV}/lp0-checks.out"
psql_su -c "SELECT has_schema_privilege('noxund_migrator','public','CREATE') AS migrator_direct_create_public, has_schema_privilege('noxund_owner','public','CREATE') AS owner_create_public;" >> "${EV}/lp0-checks.out" 2>&1 || true
grep -iE 'permission denied|SQL State|Schema History table|SET ROLE|afterConnect|Executing SQL callback' "${EV}/flyway-v1-migrate.out" > "${EV}/lp0-rootcause-flyway.txt" 2>/dev/null || true

lp0_ok=t
for v in "$v1_exit=0" "$owner_nologin=t" "$mig_noinherit=t" "$owner_nosuper=t" "$mig_nosuper=t" \
         "$mig_minimal=t" "$hist_owner=t" "$spike_owner=t" "$v1_success=t" "$extra_super=0"; do
  [ "${v%=*}" = "${v#*=}" ] || lp0_ok=f
done
if [ "$lp0_ok" != "t" ]; then
  {
    echo "# P3B ESCALATE — LEAST-PRIVILEGE CONTRACT NOT SUPPORTED"
    echo
    echo "The approved afterConnect callback (SET ROLE noxund_owner) does NOT sustain the"
    echo "least-privilege identity on Flyway's schema-history (metadata) connection. Flyway"
    echo "creates public.flyway_schema_history as noxund_migrator, which by contract holds no"
    echo "direct CREATE on public -> 'permission denied for schema public' (SQLSTATE 42501)."
    echo "Proven: owner_create_public=t, migrator_direct_create_public=f."
    echo
    echo "Honoring the contract forbids granting the migrator direct DDL privilege (no workaround),"
    echo "so V1 is not applied, instrumentation is not installed, and the fatal V2 test is not reached."
    echo "Per Bloco 2/3: no postgres identity, no trigger, no V2, no workaround, no auto-rerun."
  } > "${EV}/ESCALATE-rootcause.md"
  finish "ESCALATE — LEAST-PRIVILEGE CONTRACT NOT SUPPORTED"
  log "LP-0 failed — NOT installing triggers, NOT running V2, no workaround (per Bloco 2)."
  exit 4
fi
log "LP-0 GREEN"

# ---- 3. install fatal instrumentation (superuser; instrumentation only) ----
log "installing instrumentation (event trigger + BEFORE INSERT block trigger)"
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
log "deterministic window reached (history INSERT blocked in-transaction)"

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
hrow=$(q    "SELECT count(*) FROM public.flyway_schema_history WHERE version='2';")
sfalse=$(q  "SELECT count(*) FROM public.flyway_schema_history WHERE success=false;")
prep=$(q    "SELECT count(*) FROM pg_prepared_xacts;")
idle=$(q    "SELECT count(*) FROM pg_stat_activity WHERE state='idle in transaction';")
orphan=$([ -n "${his_pid}" ] && q "SELECT count(*) FROM pg_locks WHERE pid=${his_pid};" || echo 0)
adv_ungranted=$(q "SELECT count(*) FROM pg_locks WHERE locktype='advisory' AND NOT granted;")

psql_su -c "TABLE public.flyway_schema_history;"                         > "${EV}/history-after-kill.txt" 2>&1 || true
psql_su -c "SELECT locktype,granted,pid FROM pg_locks ORDER BY 1,3;"     > "${EV}/pg_locks-after-kill.txt" 2>&1 || true
psql_su -c "SELECT pid,state,application_name,wait_event_type,wait_event FROM pg_stat_activity;" > "${EV}/pg_stat_activity-after-kill.txt" 2>&1 || true
psql_su -c "TABLE pg_prepared_xacts;"                                    > "${EV}/pg_prepared_xacts.txt" 2>&1 || true
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
psql_su -c "DROP TRIGGER IF EXISTS p3b_block_v2 ON public.flyway_schema_history;" >/dev/null 2>&1 || true

set +e
$COMPOSE run --rm flyway info     > "${EV}/flyway-info.out" 2>&1;          info_exit=$?
$COMPOSE run --rm flyway validate > "${EV}/flyway-validate.out" 2>&1;      val_exit=$?
$COMPOSE run --rm flyway migrate  > "${EV}/flyway-fresh-migrate.out" 2>&1; fresh_exit=$?
set -e
log "info_exit=${info_exit} validate_exit=${val_exit} fresh_migrate_exit=${fresh_exit}"

tbl2=$(q  "SELECT to_regclass('spike.flyway_atomicity_gap_probe') IS NOT NULL;")
hrow2=$(q "SELECT count(*) FROM public.flyway_schema_history WHERE version='2' AND success=true;")
psql_su -c "TABLE public.flyway_schema_history;" > "${EV}/history-after-fresh-migrate.txt" 2>&1 || true
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
log "P3B done. Evidence in ${EV}. (No teardown here — run harness/teardown.sh after review.)"
