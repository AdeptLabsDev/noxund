"""runner — single-connection / single-backend / single-transaction migration
runner prototype for PG-EXIT-P3C (TM-A).

IMPLEMENTED, NOT EXECUTED. Implements exactly the accepted 22-step sequence.
Every statement (BEGIN, SET LOCAL ROLE, the DO artifact, record_migration,
accessors, COMMIT) is driven through the PQexecParams transport. The artifact is
classified by the SERVER command tag (must be "DO"); the runner never pre-parses
it. On any error the runner ROLLBACKs (if live), closes the connection, returns
non-zero and NEVER reconnects or starts a replacement transaction.

Fault-injection hook points (group G) are present but default to no-ops; the
future gate wires them to a process-kill mechanism. Nothing runs in this unit
unless NOXUND_P3C_EXECUTE_GATE=AUTHORIZED (it is not).
"""
from __future__ import annotations

import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Optional

from psycopg import pq

import session_state as ss
from fault_injection import FaultPoint
from manifest import MigrationEntry, verify_artifact
from pq_transport import PQConn, TransportError, execute_gate_authorized

# Fixed advisory-lock key (defense-in-depth ONLY; NOT caller-chosen). Linearity
# does not depend on it — the singleton head FOR UPDATE is authoritative.
CANONICAL_ADVISORY_KEY = 4826110931533660001

MIGRATOR = "noxund_migrator"
OWNER = "noxund_owner"

FaultHook = Callable[[FaultPoint], None]


def _noop_fault(_p: FaultPoint) -> None:
    return None


@dataclass
class RunResult:
    ok: bool
    exit_code: int
    version: str
    stage: str = ""
    command_tag: str = ""
    transaction_status: Optional[int] = None
    sqlstate: Optional[str] = None
    backend_pid: Optional[int] = None
    top_xid: Optional[str] = None
    head_before: Optional[dict] = None
    head_after: Optional[dict] = None
    ledger_row: Optional[dict] = None
    state_findings: list = field(default_factory=list)
    error: str = ""


def apply_one_migration(conninfo: str, entry: MigrationEntry, migrations_dir: str | Path,
                        *, fault_hook: FaultHook = _noop_fault,
                        trace_path: Optional[str] = None) -> RunResult:
    r = RunResult(ok=False, exit_code=1, version=entry.version)
    conn: Optional[PQConn] = None
    try:
        # (1) fresh connection as noxund_migrator
        r.stage = "connect"
        conn = PQConn(conninfo)
        if trace_path:
            conn.enable_trace(trace_path)
        r.backend_pid = conn.connect_pid

        # (2) assert identity
        r.stage = "assert-identity-initial"
        for f in ss.assert_identity(conn, MIGRATOR, MIGRATOR):
            if not f.ok:
                raise TransportError(f"identity mismatch: {f.setting}={f.observed}")

        # (3) BEGIN READ COMMITTED
        r.stage = "begin"
        conn.require_ok(conn.exec_params("BEGIN ISOLATION LEVEL READ COMMITTED"), "BEGIN")

        # (4) fixed advisory transaction lock (defense-in-depth)
        r.stage = "advisory-lock"
        conn.require_ok(
            conn.exec_params(f"SELECT pg_catalog.pg_advisory_xact_lock({CANONICAL_ADVISORY_KEY})"),
            "advisory lock")

        # (5) capture backend PID
        r.stage = "capture-pid"
        pid_now = int(conn.scalar("SELECT pg_catalog.pg_backend_pid()"))
        if pid_now != conn.connect_pid:
            raise TransportError(f"backend PID changed at start: {pid_now} != {conn.connect_pid}")

        # (6) materialize + capture the authoritative top-level XID
        r.stage = "capture-xid"
        top_xid = conn.scalar("SELECT pg_catalog.pg_current_xact_id()::text")
        r.top_xid = top_xid

        # (7) read authoritative head via the accessor
        r.stage = "read-head"
        r.head_before = _read_head(conn)

        # (8) verify client manifest / checksum / version / predecessor
        r.stage = "verify-manifest"
        artifact_text = verify_artifact(entry, migrations_dir)  # raises on checksum mismatch
        head_ver = r.head_before["current_version"]
        if (entry.prev_version or None) != (head_ver or None):
            raise TransportError(
                f"predecessor mismatch (client): manifest.prev={entry.prev_version!r} head={head_ver!r}")

        # (9) SET LOCAL ROLE noxund_owner
        r.stage = "set-role-owner"
        conn.require_ok(conn.exec_params(f"SET LOCAL ROLE {OWNER}"), "SET LOCAL ROLE")
        cu = conn.scalar("SELECT current_user")
        if cu != OWNER:
            raise TransportError(f"expected current_user={OWNER}, got {cu}")

        fault_hook(FaultPoint.BEFORE_ARTIFACT)

        # (10) execute the one-command DO artifact through PQexecParams
        r.stage = "execute-artifact"
        out = conn.exec_params(artifact_text)  # zero params -> extended protocol, one command
        r.command_tag = out.command_tag
        r.sqlstate = out.sqlstate

        # (11) require success + command tag DO (server-authoritative classification)
        if out.status not in (pq.ExecStatus.COMMAND_OK, pq.ExecStatus.TUPLES_OK):
            raise TransportError(
                f"artifact failed: {out.error_message.strip()}",
                sqlstate=out.sqlstate, command_tag=out.command_tag)
        if out.command_tag != "DO":
            raise TransportError(
                f"artifact command tag is {out.command_tag!r}, expected 'DO'",
                command_tag=out.command_tag)

        fault_hook(FaultPoint.AFTER_DDL_BEFORE_LEDGER)

        # (12) require INTRANS
        r.stage = "assert-intrans"
        r.transaction_status = conn.transaction_status
        if not conn.is_intrans():
            raise TransportError(
                f"unexpected transaction status after artifact: {conn.transaction_status}")

        # (13) reassert PID + top-level XID
        r.stage = "reassert-pid-xid"
        pid2 = int(conn.scalar("SELECT pg_catalog.pg_backend_pid()"))
        xid2 = conn.scalar("SELECT pg_catalog.pg_current_xact_id()::text")
        if pid2 != conn.connect_pid:
            raise TransportError(f"backend PID changed: {pid2} != {conn.connect_pid}")
        if xid2 != top_xid:
            raise TransportError(f"top-level XID changed: {xid2} != {top_xid}")

        # (14) RESET ROLE (undo SET LOCAL + any persisted plain SET ROLE)
        r.stage = "reset-role"
        conn.require_ok(conn.exec_params("RESET ROLE"), "RESET ROLE")

        # (15) reassert + assert every security-relevant session state
        r.stage = "reassert-session-state"
        ss.reassert_baseline(conn)
        r.state_findings = ss.assert_baseline(conn)
        r.state_findings += ss.assert_identity(conn, MIGRATOR, MIGRATOR)
        bad = [f for f in r.state_findings if not f.ok]
        if bad:
            raise TransportError("session-state assertion failed: "
                                 + ", ".join(f"{f.setting}={f.observed}" for f in bad))

        # (16) call record_migration with bound parameters (3 params, extended)
        r.stage = "record-migration"
        rec = conn.exec_params(
            "SELECT ordinal, version, top_xid::text, backend_pid, recorded_at::text "
            "FROM noxund_migration_meta.record_migration($1, $2, $3)",
            [entry.version, entry.sha256, entry.prev_version])
        if rec.status != pq.ExecStatus.TUPLES_OK:
            raise TransportError(f"record_migration failed: {rec.error_message.strip()}",
                                 sqlstate=rec.sqlstate)
        row = rec.rows[0]
        r.ledger_row = {"ordinal": row[0], "version": row[1], "top_xid": row[2],
                        "backend_pid": row[3], "recorded_at": row[4]}

        fault_hook(FaultPoint.AFTER_LEDGER_BEFORE_COMMIT)

        # (17,18) independent verification: exactly one row for this top-level xid
        r.stage = "verify-ledger-row"
        vrows = conn.require_ok(conn.exec_params(
            "SELECT ordinal, version, checksum, prev_version, top_xid::text, backend_pid, "
            "session_identity, definer_identity "
            "FROM noxund_migration_meta.row_for_current_xact()"), "row_for_current_xact").rows
        if len(vrows) != 1:
            raise TransportError(f"expected exactly one ledger row for xid {top_xid}, got {len(vrows)}")
        vr = vrows[0]
        if vr[1] != entry.version or vr[2] != entry.sha256 or vr[4] != top_xid \
                or int(vr[5]) != conn.connect_pid or vr[6] != MIGRATOR or vr[7] != "noxund_ledger":
            raise TransportError(f"ledger row does not match expected: {vr}")

        # (19) head/history consistency
        r.stage = "assert-head-consistency"
        r.head_after = _read_head(conn)
        if r.head_after["current_version"] != entry.version \
                or str(r.head_after["current_ordinal"]) != str(vr[0]):
            raise TransportError(f"head/history inconsistent: head={r.head_after} row_ordinal={vr[0]}")

        # (20) reassert durability
        r.stage = "assert-durability"
        ss.assert_synchronous_commit_durable(conn)

        # (21) COMMIT once
        r.stage = "commit"
        conn.require_ok(conn.exec_params("COMMIT"), "COMMIT")

        r.ok = True
        r.exit_code = 0
        return r

    except Exception as exc:  # fail-closed: rollback if live, never reconnect
        r.error = f"{type(exc).__name__}: {exc}"
        if isinstance(exc, TransportError) and exc.sqlstate:
            r.sqlstate = exc.sqlstate
        if conn is not None and conn.is_live():
            try:
                conn.exec_params("ROLLBACK")
            except Exception:
                pass
        r.ok = False
        r.exit_code = 1
        return r
    finally:
        # (22) close the connection unconditionally; never reuse this backend.
        if conn is not None:
            conn.close()


def _read_head(conn: PQConn) -> dict:
    out = conn.require_ok(conn.exec_params(
        "SELECT current_ordinal, current_version, current_checksum "
        "FROM noxund_migration_meta.current_state()"), "current_state")
    row = out.rows[0]
    return {"current_ordinal": int(row[0]) if row[0] is not None else 0,
            "current_version": row[1], "current_checksum": row[2]}


def _main() -> int:
    if not execute_gate_authorized():
        print("IMPLEMENTED, NOT EXECUTED — runner is inert without "
              "NOXUND_P3C_EXECUTE_GATE=AUTHORIZED and a Product Lead execute GO.",
              file=sys.stderr)
        return 2
    print("execute gate present; the orchestrator (harness/run_pre_gate.py) drives real runs.",
          file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())
