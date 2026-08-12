"""session_state — security-relevant session GUC reassertion & assertions.

IMPLEMENTED, NOT EXECUTED. A `DO` artifact may issue plain ``SET`` (which
persists per PostgreSQL's SECURITY DEFINER SET-clause rules) to shift encoding,
date/time, role, search_path, timeouts, RLS or durability. After the artifact
and before the ledger call/COMMIT, the runner reasserts a fixed, safe baseline
and then asserts it — using targeted statements, NOT a broad ``RESET ALL``.

Every statement here is sent through the PQexecParams transport.
"""
from __future__ import annotations

from dataclasses import dataclass

from pq_transport import PQConn, TransportError

# Fixed, safe baseline the runner requires before the ledger call and COMMIT.
# `synchronous_commit=on` is the required durable value (stricter than the
# server default cannot be assumed away). search_path is minimal; the runner
# fully-qualifies every ledger object, so name resolution never depends on it.
EXPECTED_GUCS: dict[str, str] = {
    "search_path": "pg_catalog",
    "client_encoding": "UTF8",
    "DateStyle": "ISO, MDY",
    "IntervalStyle": "postgres",
    "TimeZone": "UTC",
    "standard_conforming_strings": "on",
    "statement_timeout": "0",
    "lock_timeout": "3000",
    "idle_in_transaction_session_timeout": "0",
    "transaction_read_only": "off",
    "row_security": "on",
    "synchronous_commit": "on",
}

# application_name is evidence only — recorded, never used as authorization.
RUNNER_APPLICATION_NAME = "noxund-p3c-runner"


@dataclass
class StateFinding:
    setting: str
    expected: str
    observed: str
    ok: bool


def reassert_baseline(conn: PQConn) -> None:
    """Force the safe baseline for the remainder of the transaction/connection.

    Uses plain ``SET`` (session scope) so that a value the artifact changed with
    plain ``SET`` is overridden; the fresh-connection lifecycle discards it after
    COMMIT/close regardless.
    """
    for name, value in EXPECTED_GUCS.items():
        # numeric/timeouts and identifiers are set with explicit literals.
        conn.require_ok(
            conn.exec_params(f"SET {name} = %s" % _quote(name, value)),
            f"reassert {name}",
        )
    conn.require_ok(
        conn.exec_params("SET application_name = %s" % _quote("application_name",
                                                              RUNNER_APPLICATION_NAME)),
        "reassert application_name",
    )


def _quote(name: str, value: str) -> str:
    # search_path/identifiers vs plain scalars — keep it simple and safe: all
    # our baseline values are safe tokens; wrap in single quotes for SET.
    return "'" + value.replace("'", "''") + "'"


def assert_baseline(conn: PQConn) -> list[StateFinding]:
    findings: list[StateFinding] = []
    for name, expected in EXPECTED_GUCS.items():
        observed = conn.scalar("SELECT current_setting(%s, true)" % _quote("n", name)) or ""
        observed_norm = _normalize(name, observed)
        expected_norm = _normalize(name, expected)
        findings.append(StateFinding(name, expected_norm, observed_norm,
                                     observed_norm == expected_norm))
    return findings


def _normalize(name: str, value: str) -> str:
    v = value.strip()
    if name in ("standard_conforming_strings", "transaction_read_only",
                "row_security"):
        return "on" if v in ("on", "true", "yes", "1") else "off"
    if name == "synchronous_commit":
        return v.lower()
    return v


def assert_identity(conn: PQConn, expected_current: str, expected_session: str) -> list[StateFinding]:
    cur = conn.scalar("SELECT current_user") or ""
    sess = conn.scalar("SELECT session_user") or ""
    return [
        StateFinding("current_user", expected_current, cur, cur == expected_current),
        StateFinding("session_user", expected_session, sess, sess == expected_session),
    ]


def assert_synchronous_commit_durable(conn: PQConn) -> StateFinding:
    """Eliminatory: the final COMMIT must be durable. If an artifact left
    synchronous_commit weaker, the runner has already reasserted 'on'; this
    asserts it and FAILS the migration otherwise."""
    observed = (conn.scalar("SELECT current_setting('synchronous_commit', true)") or "").lower()
    ok = observed == "on"
    finding = StateFinding("synchronous_commit", "on", observed, ok)
    if not ok:
        raise TransportError(
            f"durability violated: synchronous_commit={observed!r} before COMMIT")
    return finding
