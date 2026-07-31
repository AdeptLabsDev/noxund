# PG-EXIT-P3A — machine-readable result

verdict: REJECT
requirement: DDL<->registry atomicity (PostgreSQL engine)
window_hit: YES (deterministic)

## pinning
branch_base: 46198f5c240ca9d846909ed654c6239e740f32c9
sqitch_image: sqitch/sqitch:v1.6.1
sqitch_image_digest: sha256:f247ab0e0b66e9c2d09a400864f7314358893f5cf209cddcc4f213f7d5bfe4d3
sqitch_version_runtime: v1.6.1
running_image_equals_pinned_digest: true
postgres_image: postgres:15.18-bookworm@sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51
server_version_num: 150018
dbd_pg_version: 3.20.2
psql_client_version: 17.10

## identity (no superuser)
session_user: noxund_migrator
current_role: noxund_owner
is_super: false

## timeline_utc
armed:             2026-07-31T11:27:35.776Z
deploy_launched:   2026-07-31T11:27:36.067Z
psql_invoke:       2026-07-31T11:27:36.433Z   # --file deploy/atomicity_gap_probe.sql
psql_rc0_commit:   2026-07-31T11:27:36.490Z   # deploy SQL COMMITTED
marker_written:    2026-07-31T11:27:36.492Z
kill_issued:       2026-07-31T11:27:37.450Z   # docker kill -s KILL (SIGKILL)
sqitch_container_exit: 137                     # 128+9 SIGKILL, oom=false

## decisive_state_post_kill (independent connection)
schema_table_present: true
registry_changes_rows_for_change: 0
registry_deploy_events_for_change: 0
registry_changes_all: [baseline_schema]
registry_tables: [changes,dependencies,events,projects,releases,tags]
prepared_xacts: 0
locks_on_sqitch_changes: 0
live_backends_on_db: 0
idle_in_transaction: 0

## exit_codes_observation (post-kill, disarmed; observation only, no repair)
sqitch_status_exit: 0     # reports change as "Undeployed"
sqitch_deploy_exit: 2     # reapply -> "relation already exists" -> Deploy failed (no auto-repair)
sqitch_check_exit: 0      # "Check successful" (FALSE GREEN vs the drift)

## teardown
scope: project-scoped (noxund-p3a-*)
docker_volume_prune: never
noxund_local_touched: false
remote_or_supabase: none
