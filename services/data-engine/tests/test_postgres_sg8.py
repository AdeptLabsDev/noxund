"""Unit tests for the SG-8 Postgres persistence adapter (U1, stage-3 part-2).

Pure and offline: every test drives ``PostgresSg8Store`` against a recording fake
connection — NO database, NO network, NO driver. These tests prove the ADAPTER's
behavior (parameterized SQL, transaction boundaries, error translation, append-only
surface); they deliberately do NOT assert that the database's constraints/triggers
hold — that is U2, against a local disposable Supabase.
"""

from __future__ import annotations

import inspect
import json
import unittest

from noxund_data_engine import postgres_sg8 as pg
from noxund_data_engine.postgres_sg8 import (
    PostgresSg8Store,
    Sg8CheckViolation,
    Sg8ContractViolation,
    Sg8ForeignKeyViolation,
    Sg8IntegrityGuardViolation,
    Sg8PersistenceError,
    Sg8RoundProvenance,
    Sg8SessionState,
    Sg8SnapshotState,
    Sg8UniqueViolation,
)


# ---------------------------------------------------------------------------
# Recording fakes (no driver, no I/O).
# ---------------------------------------------------------------------------
class _FakeDbError(Exception):
    """A driver-like error carrying a SQLSTATE (psycopg3 ``sqlstate`` attribute)."""

    def __init__(self, sqlstate: str, message: str = "db error") -> None:
        super().__init__(message)
        self.sqlstate = sqlstate


class _RecCursor:
    def __init__(self, conn: "_RecConn") -> None:
        self._conn = conn
        self._rows: list = []
        self.closed = False

    def execute(self, operation: str, parameters=()) -> None:
        self._conn.executed.append((operation, tuple(parameters)))
        n = len(self._conn.executed)
        err = self._conn.error
        if err is not None and (self._conn.error_on_call is None or n == self._conn.error_on_call):
            raise err
        self._rows = list(self._conn.rows_by_call.get(n, []))

    def fetchone(self):
        return self._rows[0] if self._rows else None

    def fetchall(self):
        rows, self._rows = self._rows, []
        return rows

    def close(self) -> None:
        self.closed = True
        self._conn.closed_cursors += 1


class _RecConn:
    def __init__(self, *, error=None, error_on_call=None, rows_by_call=None) -> None:
        self.executed: list[tuple[str, tuple]] = []
        self.commits = 0
        self.rollbacks = 0
        self.closed_cursors = 0
        self.error = error
        self.error_on_call = error_on_call
        self.rows_by_call = rows_by_call or {}

    def cursor(self) -> _RecCursor:
        return _RecCursor(self)

    def commit(self) -> None:
        self.commits += 1

    def rollback(self) -> None:
        self.rollbacks += 1


# A real sha256-shaped prompt hash (never a version token) for the llm_prompt_hash column.
_PROMPT_HASH = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
_PROVENANCE = Sg8RoundProvenance(
    provider="anthropic",
    model="claude-opus-4-8",
    model_version="2026-01",
    prompt_hash=_PROMPT_HASH,
    adapter_version="adapter-v1",
    params={"temperature": 0},
)


# ---------------------------------------------------------------------------
# Lifecycle writes.
# ---------------------------------------------------------------------------
class OpenSessionTests(unittest.TestCase):
    def test_open_session_inserts_minimal_and_commits(self) -> None:
        conn = _RecConn()
        PostgresSg8Store(conn).open_session("sess-1", "src-1")
        self.assertEqual(conn.executed, [(pg._INSERT_SESSION, ("sess-1", "src-1"))])
        self.assertEqual((conn.commits, conn.rollbacks), (1, 0))
        self.assertEqual(conn.closed_cursors, 1)

    def test_open_session_cannot_express_binding_or_terminal(self) -> None:
        sql = pg._INSERT_SESSION.lower()
        for forbidden in ("report_id_1", "report_id_2", "status", "terminal_at", "verdict_reason"):
            self.assertNotIn(forbidden, sql)  # relies on DB defaults: session_open + NULLs

    def test_open_session_rejects_blank(self) -> None:
        conn = _RecConn()
        with self.assertRaises(Sg8ContractViolation):
            PostgresSg8Store(conn).open_session("  ", "src-1")
        self.assertEqual(conn.executed, [])


class StateAdvanceTests(unittest.TestCase):
    def test_mark_awaiting_review_persists_pause(self) -> None:
        conn = _RecConn()
        PostgresSg8Store(conn).mark_awaiting_review("sess-1")
        self.assertEqual(conn.executed, [(pg._SET_STATUS, ("r1_awaiting_review", "sess-1"))])
        self.assertEqual(conn.commits, 1)

    def test_resume_uses_same_session_id(self) -> None:
        conn = _RecConn()
        store = PostgresSg8Store(conn)
        store.mark_awaiting_review("sess-1")
        store.mark_resolved("sess-1")  # legitimate resume on the SAME session id
        self.assertEqual(
            conn.executed,
            [
                (pg._SET_STATUS, ("r1_awaiting_review", "sess-1")),
                (pg._SET_STATUS, ("r1_resolved", "sess-1")),
            ],
        )
        self.assertEqual(conn.commits, 2)


class FreezeSnapshotTests(unittest.TestCase):
    def test_freeze_snapshot_is_atomic_insert_then_advance(self) -> None:
        conn = _RecConn()
        PostgresSg8Store(conn).freeze_snapshot(
            "sess-1",
            source_collection_run_id="src-1",
            resolution_snapshot_id="snap-1",
            resolver_version="entity-resolver-v1",
            resolver_hash="rhash",
            fact_count=500,
            content_hash="chash",
        )
        self.assertEqual(
            conn.executed,
            [
                (
                    pg._INSERT_SNAPSHOT,
                    ("snap-1", "sess-1", "src-1", "entity-resolver-v1", "rhash", 500, "chash"),
                ),
                (pg._SET_STATUS, ("r1_snapshot_frozen", "sess-1")),
            ],
        )
        # Both statements committed as ONE unit (freeze before compute, atomic).
        self.assertEqual((conn.commits, conn.rollbacks), (1, 0))

    def test_freeze_snapshot_rejects_negative_fact_count(self) -> None:
        conn = _RecConn()
        with self.assertRaises(Sg8ContractViolation):
            PostgresSg8Store(conn).freeze_snapshot(
                "sess-1",
                source_collection_run_id="src-1",
                resolution_snapshot_id="snap-1",
                resolver_version="v",
                resolver_hash="h",
                fact_count=-1,
                content_hash="c",
            )
        self.assertEqual(conn.executed, [])


class BindReportsTests(unittest.TestCase):
    def test_bind_reports_is_single_atomic_update(self) -> None:
        conn = _RecConn()
        PostgresSg8Store(conn).bind_reports(
            "sess-1", report_run_id_1="rep-1", report_run_id_2="rep-2"
        )
        self.assertEqual(
            conn.executed, [(pg._BIND_REPORTS, ("rep-1", "rep-2", "r1_computed", "sess-1"))]
        )
        self.assertEqual(len(conn.executed), 1)  # both reports bound in ONE statement
        self.assertEqual(conn.commits, 1)


class RoundTests(unittest.TestCase):
    def test_append_round1_persists_full_provenance(self) -> None:
        conn = _RecConn()
        PostgresSg8Store(conn).append_round(
            round_execution_id="re-1",
            sg8_session_id="sess-1",
            round_number=1,
            source_collection_run_id="src-1",
            resolution_snapshot_id="snap-1",
            provenance=_PROVENANCE,
        )
        expected_params = (
            "re-1",
            "sess-1",
            1,
            "src-1",
            "snap-1",
            "anthropic",
            "claude-opus-4-8",
            "2026-01",
            _PROMPT_HASH,  # -> llm_prompt_hash: a real hash, NOT a version token
            json.dumps(
                {"temperature": 0}, ensure_ascii=False, separators=(",", ":"), sort_keys=True
            ),
            "adapter-v1",  # -> llm_adapter_version
        )
        self.assertEqual(conn.executed, [(pg._INSERT_ROUND, expected_params)])
        # The prompt-hash column receives the hash (index 8), never the model_version.
        self.assertEqual(conn.executed[0][1][8], _PROMPT_HASH)
        self.assertEqual(conn.commits, 1)

    def test_append_round2_is_zero_llm(self) -> None:
        conn = _RecConn()
        PostgresSg8Store(conn).append_round(
            round_execution_id="re-2",
            sg8_session_id="sess-1",
            round_number=2,
            source_collection_run_id="src-1",
            resolution_snapshot_id="snap-1",
            provenance=None,
        )
        sql, params = conn.executed[0]
        self.assertEqual(sql, pg._INSERT_ROUND)
        self.assertEqual(params[:5], ("re-2", "sess-1", 2, "src-1", "snap-1"))
        self.assertEqual(params[5:], (None, None, None, None, None, None))  # zero-LLM

    def test_append_round_rejects_bad_round_number(self) -> None:
        conn = _RecConn()
        with self.assertRaises(Sg8ContractViolation):
            PostgresSg8Store(conn).append_round(
                round_execution_id="re-3",
                sg8_session_id="sess-1",
                round_number=3,
                source_collection_run_id="src-1",
                resolution_snapshot_id="snap-1",
            )
        self.assertEqual(conn.executed, [])


class EvidenceTests(unittest.TestCase):
    def test_append_evidence_partitioned_by_round(self) -> None:
        conn = _RecConn()
        PostgresSg8Store(conn).append_evidence(
            round_execution_id="re-1",
            sg8_session_id="sess-1",
            report_run_id="rep-1",
            canonical_digest="digest-1",
        )
        self.assertEqual(
            conn.executed, [(pg._INSERT_EVIDENCE, ("re-1", "sess-1", "rep-1", "digest-1"))]
        )
        # round_execution_id is the partition key (first parameter).
        self.assertEqual(conn.executed[0][1][0], "re-1")
        self.assertEqual(conn.commits, 1)


class TerminalTests(unittest.TestCase):
    def test_mark_passed_emits_terminal_update(self) -> None:
        conn = _RecConn()
        PostgresSg8Store(conn).mark_passed("sess-1", verdict_reason="byte-identical")
        self.assertEqual(
            conn.executed, [(pg._MARK_TERMINAL, ("passed", "byte-identical", "sess-1"))]
        )
        self.assertIn("terminal_at = now()", pg._MARK_TERMINAL)
        self.assertEqual(conn.commits, 1)

    def test_mark_failed_emits_terminal_update(self) -> None:
        conn = _RecConn()
        PostgresSg8Store(conn).mark_failed("sess-1", verdict_reason="drift")
        self.assertEqual(conn.executed, [(pg._MARK_TERMINAL, ("failed", "drift", "sess-1"))])

    def test_mark_terminal_rejects_blank_verdict(self) -> None:
        conn = _RecConn()
        with self.assertRaises(Sg8ContractViolation):
            PostgresSg8Store(conn).mark_passed("sess-1", verdict_reason="   ")
        self.assertEqual(conn.executed, [])


# ---------------------------------------------------------------------------
# Error translation + transaction boundaries.
# ---------------------------------------------------------------------------
class ErrorTranslationTests(unittest.TestCase):
    def test_unique_violation_maps_and_rolls_back(self) -> None:
        conn = _RecConn(error=_FakeDbError("23505"))
        with self.assertRaises(Sg8UniqueViolation):
            PostgresSg8Store(conn).append_evidence(
                round_execution_id="re-1",
                sg8_session_id="sess-1",
                report_run_id="rep-1",
                canonical_digest="dup",
            )
        self.assertEqual((conn.commits, conn.rollbacks), (0, 1))

    def test_foreign_key_violation_maps(self) -> None:
        conn = _RecConn(error=_FakeDbError("23503"))
        with self.assertRaises(Sg8ForeignKeyViolation):
            PostgresSg8Store(conn).append_round(
                round_execution_id="re-1",
                sg8_session_id="sess-1",
                round_number=1,
                source_collection_run_id="src-other",
                resolution_snapshot_id="snap-1",
                provenance=_PROVENANCE,
            )
        self.assertEqual(conn.rollbacks, 1)

    def test_check_violation_maps(self) -> None:
        conn = _RecConn(error=_FakeDbError("23514"))
        with self.assertRaises(Sg8CheckViolation):
            PostgresSg8Store(conn).bind_reports("sess-1", report_run_id_1="r", report_run_id_2="r")

    def test_restrict_violation_maps_integrity_guard(self) -> None:
        # FSM / terminality / append-only / PASS gate all raise SQLSTATE 23001.
        conn = _RecConn(error=_FakeDbError("23001"))
        with self.assertRaises(Sg8IntegrityGuardViolation):
            PostgresSg8Store(conn).mark_passed("sess-1", verdict_reason="byte-identical")
        self.assertEqual(conn.rollbacks, 1)

    def test_unknown_sqlstate_maps_to_base_error(self) -> None:
        conn = _RecConn(error=_FakeDbError("08006"))  # connection failure
        with self.assertRaises(Sg8PersistenceError) as ctx:
            PostgresSg8Store(conn).mark_resolved("sess-1")
        # base class, not one of the specific subclasses
        self.assertIs(type(ctx.exception), Sg8PersistenceError)
        self.assertEqual(conn.rollbacks, 1)

    def test_error_preserves_original_cause(self) -> None:
        original = _FakeDbError("23505", "duplicate key value")
        conn = _RecConn(error=original)
        with self.assertRaises(Sg8UniqueViolation) as ctx:
            PostgresSg8Store(conn).append_evidence(
                round_execution_id="re-1",
                sg8_session_id="sess-1",
                report_run_id="rep-1",
                canonical_digest="dup",
            )
        self.assertIs(ctx.exception.__cause__, original)  # cause preserved

    def test_error_message_does_not_leak_parameters(self) -> None:
        conn = _RecConn(error=_FakeDbError("23503"))
        with self.assertRaises(Sg8ForeignKeyViolation) as ctx:
            PostgresSg8Store(conn).append_evidence(
                round_execution_id="secret-re",
                sg8_session_id="secret-sess",
                report_run_id="secret-rep",
                canonical_digest="secret-digest",
            )
        msg = str(ctx.exception)
        for value in ("secret-re", "secret-sess", "secret-rep", "secret-digest"):
            self.assertNotIn(value, msg)

    def test_error_mid_transaction_rolls_back_all(self) -> None:
        # freeze = 2 statements; make the SECOND (status advance) fail.
        conn = _RecConn(error=_FakeDbError("23001"), error_on_call=2)
        with self.assertRaises(Sg8IntegrityGuardViolation):
            PostgresSg8Store(conn).freeze_snapshot(
                "sess-1",
                source_collection_run_id="src-1",
                resolution_snapshot_id="snap-1",
                resolver_version="v",
                resolver_hash="h",
                fact_count=1,
                content_hash="c",
            )
        self.assertEqual(len(conn.executed), 2)  # both attempted
        self.assertEqual((conn.commits, conn.rollbacks), (0, 1))  # nothing committed


# ---------------------------------------------------------------------------
# Append-only surface + SQL discipline.
# ---------------------------------------------------------------------------
def _all_sql_constants() -> list[str]:
    return [
        getattr(pg, name)
        for name in dir(pg)
        if name.isupper() and name.startswith("_") and isinstance(getattr(pg, name), str)
        and (
            getattr(pg, name).lower().startswith("insert")
            or getattr(pg, name).lower().startswith("update")
            or getattr(pg, name).lower().startswith("delete")
            or getattr(pg, name).lower().startswith("select")
        )
    ]


class SqlDisciplineTests(unittest.TestCase):
    _IMMUTABLE = (
        "sg8_resolution_snapshots",
        "sg8_round_executions",
        "sg8_round_report_evidence",
    )

    def test_no_update_or_delete_of_immutable_tables(self) -> None:
        for sql in _all_sql_constants():
            head = sql.lower().split(None, 1)[0]
            if head in ("update", "delete"):
                for table in self._IMMUTABLE:
                    self.assertNotIn(table, sql.lower(), f"mutation of immutable table in: {sql!r}")
                # the only mutable target is sg8_sessions (state/binding/terminal).
                self.assertIn("sg8_sessions", sql.lower())

    def test_all_sql_is_parameterized_no_interpolation(self) -> None:
        for sql in _all_sql_constants():
            self.assertNotIn("{", sql)  # no str.format / f-string braces
            self.assertNotIn("%(", sql)  # no named paramstyle
            # every '%' belongs to a '%s' placeholder (no other formatting).
            self.assertEqual(sql.count("%"), sql.count("%s"), f"non-%s formatting in: {sql!r}")

    def test_adapter_imports_no_database_driver(self) -> None:
        source = inspect.getsource(pg)
        for driver in ("psycopg", "asyncpg", "sqlalchemy", "pg8000"):
            self.assertNotIn(f"import {driver}", source)


# ---------------------------------------------------------------------------
# Reads (state for replay + comparison).
# ---------------------------------------------------------------------------
class ReadTests(unittest.TestCase):
    def test_read_session_state(self) -> None:
        conn = _RecConn(rows_by_call={1: [("r1_computed", "src-1", "rep-1", "rep-2", None)]})
        state = PostgresSg8Store(conn).read_session_state("sess-1")
        self.assertEqual(
            state,
            Sg8SessionState(
                status="r1_computed",
                source_collection_run_id="src-1",
                report_id_1="rep-1",
                report_id_2="rep-2",
                verdict_reason=None,
            ),
        )
        self.assertEqual(conn.executed[0], (pg._READ_SESSION, ("sess-1",)))

    def test_read_session_state_missing_returns_none(self) -> None:
        conn = _RecConn()  # no rows
        self.assertIsNone(PostgresSg8Store(conn).read_session_state("sess-x"))

    def test_read_snapshot_state(self) -> None:
        conn = _RecConn(
            rows_by_call={1: [("snap-1", "src-1", "entity-resolver-v1", "rhash", 500, "chash")]}
        )
        snap = PostgresSg8Store(conn).read_snapshot_state("sess-1")
        self.assertEqual(
            snap,
            Sg8SnapshotState(
                resolution_snapshot_id="snap-1",
                source_collection_run_id="src-1",
                resolver_version="entity-resolver-v1",
                resolver_hash="rhash",
                fact_count=500,
                content_hash="chash",
            ),
        )

    def test_read_round_execution_id(self) -> None:
        conn = _RecConn(rows_by_call={1: [("re-1",)]})
        self.assertEqual(PostgresSg8Store(conn).read_round_execution_id("sess-1", 1), "re-1")
        self.assertEqual(conn.executed[0], (pg._READ_ROUND_ID, ("sess-1", 1)))

    def test_read_round_evidence_returns_digest_map(self) -> None:
        conn = _RecConn(rows_by_call={1: [("rep-1", "digest-1"), ("rep-2", "digest-2")]})
        evidence = PostgresSg8Store(conn).read_round_evidence("re-1")
        self.assertEqual(dict(evidence), {"rep-1": "digest-1", "rep-2": "digest-2"})


if __name__ == "__main__":
    unittest.main()
