# PG-EXIT-P3A — Sqitch DDL↔Registry Atomicity Falsification

**Verdict: REJECT (Sqitch fails the DDL↔registry atomicity requirement).**
**Scope:** the single fatal experiment authorized under PG-EXIT-P3A. NOT the full P3 matrix.
**Date:** 2026-07-31 · **Branch base:** `main @ 46198f5c240ca9d846909ed654c6239e740f32c9`
**OD-5 recommendation:** REJECT SQITCH (as the migration runner, on the atomicity requirement). OD-7 NOT evaluated.

> This experiment was designed to *falsify*, not to confirm. The hypothesis under test:
> "In the PostgreSQL engine, Sqitch runs the deploy script over an **external psql**
> connection while the registry is written over a **separate DBI** connection, so DDL and
> registry are **not** in the same transaction." The experiment reproduces the exact fatal
> window and inspects the result with an independent connection.

## Pinning (resolved empirically, not presumed)

| Component | Value |
|---|---|
| Sqitch image | `sqitch/sqitch:v1.6.1` (real tag carries the `v`; bare `1.6.1` does **not** exist) |
| Sqitch image digest | `sha256:f247ab0e0b66e9c2d09a400864f7314358893f5cf209cddcc4f213f7d5bfe4d3` |
| `sqitch --version` (runtime) | `sqitch (App::Sqitch) v1.6.1` |
| Running image == pinned digest | YES (derivation proof) |
| PostgreSQL image (P2, reused) | `postgres:15.18-bookworm@sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51` |
| `server_version_num` | `150018` |
| psql client (in sqitch image) | 17.10 · DBD::Pg 3.20.2 (registry DBI) |

## Method

- Isolated Docker project: network `noxund-p3a-net`, disposable volume `noxund-p3a-pgdata`,
  internal-only (no host port). `noxund-local` untouched. Teardown project-scoped; never `volume prune`.
- Identity: connect as **`noxund_migrator`** with `ALTER ROLE noxund_migrator SET role = noxund_owner`
  → `session_user=noxund_migrator`, `current_role=noxund_owner`, `is_super=false`. **No superuser.**
- Registry pre-initialized with a normal baseline change (`baseline_schema`). Confirmed present before the fatal test.
- **Instrumented client** (`psql-wrap.sh`) set as `target.spike.client` (the effective key; precedence is
  `--client` → `target.$name.client` → `engine.$engine.client` → `core.client` — NOT `core.pg.client`).
  The wrapper runs the **real psql unchanged**; only on an **armed** fatal deploy that returns 0 does it
  write a `DEPLOY_SQL_COMMITTED` marker and block, freezing Sqitch **after the deploy COMMIT but before
  `log_deploy_change()`**. It never alters SQL and never records credentials.
- Fatal change deploy body (exactly as mandated):
  ```sql
  BEGIN;
  CREATE TABLE spike.atomicity_gap_probe(id integer PRIMARY KEY);
  COMMIT;
  ```
- Interruption: on marker, `docker kill -s KILL` the Sqitch container. PostgreSQL left alive. No cleanup/handler.
- Inspection: an **independent** connection (as `postgres`).

## Source-level confirmation (App::Sqitch::Engine::pg, v1.6.1, in-image)

- `run_file` → `_run('--file' => $file)` → `$sqitch->run($self->psql, ...)` — **deploy scripts run via external psql**.
- `begin_work` → `$dbh->begin_work; $dbh->do('LOCK TABLE changes IN EXCLUSIVE MODE')` — **registry txn is DBI**.
- `log_deploy_change` writes the `changes`/`events`/`dependencies` rows over DBI and `finish_work` commits it.
- Therefore the DDL (psql connection) and the registry write (DBI connection) are **two connections / two
  transactions**. The experiment kills Sqitch in the gap between them.

## Timeline (UTC)

| t | event |
|---|---|
| 11:27:35.776 | ARMED (fatal deploy) |
| 11:27:36.067 | `sqitch deploy … --to atomicity_gap_probe` launched |
| 11:27:36.433 | psql INVOKE `--file deploy/atomicity_gap_probe.sql` (no password on argv) |
| 11:27:36.490 | psql RESULT **rc=0** → deploy SQL **COMMITTED** |
| 11:27:36.492 | wrapper wrote `DEPLOY_SQL_COMMITTED`; Sqitch frozen (pre-`log_deploy_change`) |
| 11:27:37.450 | **SIGKILL** the Sqitch container |
| — | Sqitch container `exited exit=137` (SIGKILL), `oom=false`. `deploy.out` frozen at `+ atomicity_gap_probe ..` |

## Decisive state (independent connection, immediately post-kill)

| Probe | Result | Meaning |
|---|---|---|
| `spike.atomicity_gap_probe` present? | **YES** (`t`, column `id`) | DDL committed by psql |
| Rows in `sqitch.changes` for it | **0** | change ABSENT from registry |
| Deploy events for it | **0** | no registry event at kill time |
| Registry tables | `changes,dependencies,events,projects,releases,tags` | registry structurally intact |
| Prepared xacts (2PC) | 0 | none |
| Locks on `sqitch.changes` | 0 | the DBI `LOCK TABLE changes` was released by rollback |
| Live backends on DB / idle-in-txn | 0 / 0 | killed connection cleanly reaped |

**→ table present + change absent from registry = the REJECT condition.**

## Operational consequence (observed post-kill; observation only, no repair)

| Command | Exit | Behavior |
|---|---|---|
| `sqitch status` | 0 | reports `atomicity_gap_probe` as **"Undeployed change"** — the committed table is invisible |
| `sqitch deploy` | 2 | **tries to reapply** → `ERROR: relation "atomicity_gap_probe" already exists` → **Deploy failed**. No recognition, no adoption, **no auto-repair** |
| `sqitch check` | 0 | **"Check successful"** — a **FALSE GREEN**; does not detect the drift |

The gap does not self-heal: `status` under-reports, `deploy` is wedged on the pre-existing object, `check`
returns success. (`events` later shows a `fail:atomicity_gap_probe` row @ 11:29:17 — that is from the
post-kill reapply **observation**, not the fatal deploy; the `changes` table still holds only `baseline_schema`.)

## Conclusion

The deploy of a change is **not atomic** across DDL and registry in the PostgreSQL engine. A crash in the
window `COMMIT(deploy) → (registry not yet written)` leaves a **committed schema object with no registry
record**, and Sqitch cannot recover automatically. **OD-5 → REJECT SQITCH** on the atomicity requirement.
Per the P3A protocol, verify/revert/manifest/concurrency were **not** tested after this REJECT.

## Documental corrections (recorded, decisions NOT closed here)

- Sqitch **1.6.1** supersedes the earlier candidate 1.4.1 in the design.
- `sqitch check` must be included in any future **deploy-immutability** test (here it returned a false green vs the atomicity drift; its immutability scope is separate and still to be characterized).
- `revert/` and `verify/` remain candidates for an external SHA-256 manifest (out of scope here).
- `sqitch.plan` is **linear**; `requires` validates dependencies but does **not** turn `deploy --to` into a selective graph scheduler.
- An `ATOM-1`-style error *inside* `BEGIN/COMMIT` proves script atomicity, **not** registry atomicity — this experiment targets the registry boundary specifically.

## Evidence index (`evidence/`)

- `psql-invocations.log` — the single armed deploy invocation, rc=0.
- `deploy.out.fatal-frozen` — Sqitch stdout frozen at the change line.
- `marker-DEPLOY_SQL_COMMITTED.ts` — commit-completed timestamp.
- `registry-changes.csv` / `registry-events.csv` / `registry-dependencies.csv` — registry dumps.
- `pg_dump-schema-only.sql` — full schema (contains the orphan `spike.atomicity_gap_probe`).
- `RESULT-timeline.md` — machine-readable timeline + exit codes + pinning.
- `psql-wrap.sh`, `sqitch/` — the instrumentation + Sqitch project (reproducibility).

No credentials appear in this bundle (ephemeral, internal-network-only; secret scan clean).
