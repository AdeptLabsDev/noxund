"""Unit tests for the SG-8 Postgres persistence adapter (U1, stage-3 part-2; DEC-0025).

Pure and offline: every test drives ``PostgresSg8Store`` against a recording fake
connection — NO database, NO network, NO driver. These tests prove the ADAPTER's
behavior (parameterized SQL, transaction boundaries, error translation, append-only
surface, deterministic compute provenance); they deliberately do NOT assert that the
database's constraints/triggers hold — that is the E2E, against a local disposable
Supabase.

Provider-neutral (DEC-0025): each round persists a deterministic compute provenance
(``Sg8ComputeProvenance``) with a canonical ``compute_manifest_hash`` — no provider,
model or prompt anywhere.
"""

from __future__ import annotations

import ast
import inspect
import unittest

from noxund_data_engine import postgres_sg8 as pg
from noxund_data_engine.postgres_sg8 import (
    PostgresSg8Store,
    Sg8CheckViolation,
    Sg8ComputeProvenance,
    Sg8ContractViolation,
    Sg8ForeignKeyViolation,
    Sg8IntegrityGuardViolation,
    Sg8NotNullViolation,
    Sg8PersistenceError,
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


# A real sha256-shaped compute manifest hash (never a version token).
_MANIFEST_HASH = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
_PROVENANCE = Sg8ComputeProvenance(
    engine_name="noxund-pipeline",
    engine_version="pipeline-wiring-2026_06_v1",
    manifest_hash=_MANIFEST_HASH,
)


# ---------------------------------------------------------------------------
# Lifecycle writes.
# ---------------------------------------------------------------------------
class OpenSessionTests(unittest.TestCase):
    def test_open_session_inserts_minimal_and_commits(self) -> None:
        conn = _RecConn()
        PostgresSg8Store(conn).open_session("sess-1", "src-1")
        # The comparison contract is supplied EXPLICITLY from the canonical constant (never a PG
        # default, never caller-supplied) — one of exactly 3 INSERT params.
        self.assertEqual(
            conn.executed,
            [(pg._INSERT_SESSION, ("sess-1", "src-1", pg.SG8_COMPARISON_CONTRACT_VERSION))],
        )
        self.assertEqual(pg.SG8_COMPARISON_CONTRACT_VERSION, "sg8-pass-v1")
        self.assertEqual((conn.commits, conn.rollbacks), (1, 0))
        self.assertEqual(conn.closed_cursors, 1)

    def test_open_session_uses_canonical_constant_not_caller_value(self) -> None:
        # open_session takes NO comparison-contract argument — callers cannot silently substitute
        # an arbitrary value; the store always binds the single canonical constant.
        import inspect
        params = inspect.signature(PostgresSg8Store.open_session).parameters
        self.assertEqual(list(params), ["self", "sg8_session_id", "source_collection_run_id"])

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
    def test_append_round1_persists_full_compute_provenance(self) -> None:
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
            "noxund-pipeline",              # -> compute_engine_name
            "pipeline-wiring-2026_06_v1",   # -> compute_engine_version
            _MANIFEST_HASH,                 # -> compute_manifest_hash (a real 64-hex sha256)
        )
        self.assertEqual(conn.executed, [(pg._INSERT_ROUND, expected_params)])
        # The manifest-hash column receives the hash (index 7), never a version token.
        self.assertEqual(conn.executed[0][1][7], _MANIFEST_HASH)
        # No persistence-adapter or free-form-params value is ever persisted (3 provenance cols).
        self.assertEqual(len(conn.executed[0][1]), 8)
        self.assertEqual(conn.commits, 1)

    def test_append_round2_also_persists_full_compute_provenance(self) -> None:
        # DEC-0025: Round 2 carries the SAME deterministic provenance as Round 1 (no zero-LLM).
        conn = _RecConn()
        PostgresSg8Store(conn).append_round(
            round_execution_id="re-2",
            sg8_session_id="sess-1",
            round_number=2,
            source_collection_run_id="src-1",
            resolution_snapshot_id="snap-1",
            provenance=_PROVENANCE,
        )
        sql, params = conn.executed[0]
        self.assertEqual(sql, pg._INSERT_ROUND)
        self.assertEqual(params[:5], ("re-2", "sess-1", 2, "src-1", "snap-1"))
        self.assertEqual(
            params[5:],
            ("noxund-pipeline", "pipeline-wiring-2026_06_v1", _MANIFEST_HASH),
        )

    def test_append_round_rejects_bad_round_number(self) -> None:
        conn = _RecConn()
        with self.assertRaises(Sg8ContractViolation):
            PostgresSg8Store(conn).append_round(
                round_execution_id="re-3",
                sg8_session_id="sess-1",
                round_number=3,
                source_collection_run_id="src-1",
                resolution_snapshot_id="snap-1",
                provenance=_PROVENANCE,
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

    def test_not_null_violation_maps(self) -> None:
        # DEC-0025: a round missing its compute provenance raises 23502 at the DB.
        conn = _RecConn(error=_FakeDbError("23502"))
        with self.assertRaises(Sg8NotNullViolation):
            PostgresSg8Store(conn).append_round(
                round_execution_id="re-1",
                sg8_session_id="sess-1",
                round_number=1,
                source_collection_run_id="src-1",
                resolution_snapshot_id="snap-1",
                provenance=_PROVENANCE,
            )
        self.assertEqual(conn.rollbacks, 1)

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


# Drivers the contract forbids the driver-agnostic adapter from importing (Gate 4).
_FORBIDDEN_DRIVERS = frozenset(
    {"psycopg", "psycopg2", "asyncpg", "sqlalchemy", "pg8000", "aiopg", "pymysql", "oracledb"}
)


def _imported_root_modules(source: str) -> set[str]:
    """Root module of every real import, parsed via AST (not substrings/strings/comments).

    ``import a.b`` / ``import a.b as c`` → ``a``; ``from a.b import c`` → ``a``. Relative
    imports (``from . import x``) are internal and yield nothing.
    """
    roots: set[str] = set()
    for node in ast.walk(ast.parse(source)):
        if isinstance(node, ast.Import):
            for alias in node.names:
                roots.add(alias.name.split(".", 1)[0])
        elif isinstance(node, ast.ImportFrom):
            if not node.level and node.module:  # level 0 = absolute
                roots.add(node.module.split(".", 1)[0])
    return roots


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

    def test_no_llm_or_noncomputational_columns_in_any_sql(self) -> None:
        # DEC-0025: no residual LLM column, and no non-computational compute_* column
        # (persistence adapter / free-form params), anywhere in the adapter's SQL.
        for sql in _all_sql_constants():
            low = sql.lower()
            for forbidden in ("llm_provider", "llm_model", "llm_prompt_hash", "llm_params_json",
                              "llm_adapter_version", "llm_model_version", "ext_llm",
                              "compute_adapter_version", "compute_params_json"):
                self.assertNotIn(forbidden, low, f"residual forbidden column in: {sql!r}")

    def test_adapter_imports_no_database_driver_via_ast(self) -> None:
        # Positive: the real adapter imports no forbidden driver (AST, not substring).
        roots = _imported_root_modules(inspect.getsource(pg))
        self.assertTrue(
            _FORBIDDEN_DRIVERS.isdisjoint(roots),
            f"adapter imports a forbidden driver: {sorted(_FORBIDDEN_DRIVERS & roots)}",
        )

    def test_ast_guard_detects_every_driver_import_form(self) -> None:
        # Negative: each import form for a forbidden driver is detected by the AST guard.
        for sample in (
            "import psycopg",
            "import psycopg as db",
            "from psycopg import connect",
            "import psycopg.extras",
            "from psycopg.rows import dict_row",
            "import psycopg2",
            "from psycopg2 import connect",
            "import asyncpg",
            "from sqlalchemy import create_engine",
            "import pg8000.native",
        ):
            roots = _imported_root_modules(sample)
            self.assertFalse(
                _FORBIDDEN_DRIVERS.isdisjoint(roots), f"AST guard missed: {sample!r}"
            )

    def test_ast_guard_ignores_driver_names_in_strings_and_comments(self) -> None:
        # Proves the guard parses REAL imports, not substrings: a driver named only in a
        # comment or a string literal is NOT flagged.
        benign = (
            "# import psycopg (mentioned in a comment only)\n"
            "DOC = 'we deliberately do not import psycopg here'\n"
            "import json\n"
            "from . import sibling\n"
        )
        roots = _imported_root_modules(benign)
        self.assertTrue(_FORBIDDEN_DRIVERS.isdisjoint(roots))
        self.assertEqual(roots, {"json"})


# ---------------------------------------------------------------------------
# Reads (state for replay + comparison).
# ---------------------------------------------------------------------------
class ReadTests(unittest.TestCase):
    def test_read_session_state(self) -> None:
        conn = _RecConn(rows_by_call={1: [("r1_computed", "src-1", "rep-1", "rep-2", None, "sg8-pass-v1")]})
        state = PostgresSg8Store(conn).read_session_state("sess-1")
        self.assertEqual(
            state,
            Sg8SessionState(
                status="r1_computed",
                source_collection_run_id="src-1",
                report_id_1="rep-1",
                report_id_2="rep-2",
                verdict_reason=None,
                comparison_contract_version="sg8-pass-v1",
            ),
        )
        # The persisted comparison contract is read back verbatim (independent of compute).
        self.assertEqual(state.comparison_contract_version, "sg8-pass-v1")
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


# ---------------------------------------------------------------------------
# Compute manifest hash — structural format (adapter); store never derives it.
# ---------------------------------------------------------------------------
class ManifestHashContractTests(unittest.TestCase):
    def _round(self, conn, manifest_hash):
        PostgresSg8Store(conn).append_round(
            round_execution_id="re-1",
            sg8_session_id="sess-1",
            round_number=1,
            source_collection_run_id="src-1",
            resolution_snapshot_id="snap-1",
            provenance=Sg8ComputeProvenance(
                engine_name="noxund-pipeline",
                engine_version="pipeline-wiring-2026_06_v1",
                manifest_hash=manifest_hash,
            ),
        )

    def test_round_rejects_invalid_manifest_hash_formats_before_sql(self) -> None:
        bad_values = (
            "sg8-manifest-v1",                   # a version token (the exact bug class)
            "e3b0c442",                          # too short
            _MANIFEST_HASH[:-1],                 # 63 chars
            _MANIFEST_HASH + "a",                # 65 chars
            _MANIFEST_HASH.upper(),              # uppercase (must be lowercase)
            "g" * 64,                            # non-hex chars, right length
            "",                                  # blank
        )
        for bad in bad_values:
            conn = _RecConn()
            with self.assertRaises(Sg8ContractViolation, msg=f"accepted: {bad!r}"):
                self._round(conn, bad)
            self.assertEqual(conn.executed, [], f"SQL issued for bad manifest {bad!r}")

    def test_round_accepts_canonical_sha256_and_persists_at_manifest_column(self) -> None:
        conn = _RecConn()
        self._round(conn, _MANIFEST_HASH)
        self.assertEqual(conn.executed[0][1][7], _MANIFEST_HASH)  # index 7 = compute_manifest_hash
        self.assertEqual(conn.commits, 1)

    def test_store_validates_but_never_derives_the_manifest_hash(self) -> None:
        # The store owns FORMAT validation, never derivation: its source must not hash.
        store_src = inspect.getsource(pg.PostgresSg8Store)
        self.assertNotIn("hashlib", store_src)
        self.assertNotIn("canonical_compute_manifest", store_src)


# ---------------------------------------------------------------------------
# Deterministic compute provenance — mandatory + symmetric, fail-closed before any SQL.
# ---------------------------------------------------------------------------
class ComputeProvenanceTests(unittest.TestCase):
    def _append(self, conn, *, round_number, provenance):
        PostgresSg8Store(conn).append_round(
            round_execution_id="re-1",
            sg8_session_id="sess-1",
            round_number=round_number,
            source_collection_run_id="src-1",
            resolution_snapshot_id="snap-1",
            provenance=provenance,
        )

    def test_round1_without_provenance_is_rejected_before_sql(self) -> None:
        conn = _RecConn()
        with self.assertRaises(Sg8ContractViolation):
            self._append(conn, round_number=1, provenance=None)
        self.assertEqual(conn.executed, [])

    def test_round2_without_provenance_is_rejected_before_sql(self) -> None:
        # DEC-0025: Round 2 also requires provenance (no zero-LLM exemption).
        conn = _RecConn()
        with self.assertRaises(Sg8ContractViolation):
            self._append(conn, round_number=2, provenance=None)
        self.assertEqual(conn.executed, [])

    def test_rejects_each_blank_core_field_before_sql(self) -> None:
        base = dict(
            engine_name="noxund-pipeline",
            engine_version="pipeline-wiring-2026_06_v1",
            manifest_hash=_MANIFEST_HASH,
        )
        for field_name in ("engine_name", "engine_version"):
            conn = _RecConn()
            bad = dict(base, **{field_name: "   "})
            with self.assertRaises(Sg8ContractViolation, msg=field_name):
                self._append(conn, round_number=1, provenance=Sg8ComputeProvenance(**bad))
            self.assertEqual(conn.executed, [], field_name)

    def test_provenance_has_no_persistence_or_params_fields(self) -> None:
        # DEC-0025: the compute provenance carries ONLY computational identity — no
        # persistence-adapter version and no free-form params.
        for forbidden in ("adapter_version", "params"):
            self.assertFalse(hasattr(_PROVENANCE, forbidden), f"residual field: {forbidden}")

    def test_both_rounds_accept_identical_provenance(self) -> None:
        # Positive both sides of the symmetric contract: the SAME provenance on each round.
        for rn in (1, 2):
            conn = _RecConn()
            self._append(conn, round_number=rn, provenance=_PROVENANCE)
            self.assertEqual(conn.commits, 1)
            self.assertEqual(conn.executed[0][1][7], _MANIFEST_HASH)


# ---------------------------------------------------------------------------
# Read transaction ownership (exclusive-owner model; reusable connection).
# ---------------------------------------------------------------------------
class ReadTransactionOwnershipTests(unittest.TestCase):
    def test_successful_read_terminates_txn_and_leaves_connection_reusable(self) -> None:
        rows = {
            1: [("r1_computed", "src-1", "rep-1", "rep-2", None, "sg8-pass-v1")],
            2: [("r1_computed", "src-1", "rep-1", "rep-2", None, "sg8-pass-v1")],
        }
        conn = _RecConn(rows_by_call=rows)
        store = PostgresSg8Store(conn)
        self.assertIsNotNone(store.read_session_state("sess-1"))
        # read-only txn terminated (rollback), nothing committed
        self.assertEqual((conn.commits, conn.rollbacks), (0, 1))
        # connection reusable: a second read succeeds
        self.assertIsNotNone(store.read_session_state("sess-1"))
        self.assertEqual((conn.commits, conn.rollbacks), (0, 2))

    def test_failed_read_leaves_connection_reusable_and_preserves_cause(self) -> None:
        original = _FakeDbError("08006", "connection reset")
        # error only on call 1; call 2 returns a row → proves reusability after an error
        conn = _RecConn(
            error=original,
            error_on_call=1,
            rows_by_call={2: [("snap-1", "src-1", "entity-resolver-v1", "rhash", 7, "chash")]},
        )
        store = PostgresSg8Store(conn)
        with self.assertRaises(Sg8PersistenceError) as ctx:
            store.read_snapshot_state("sess-1")
        self.assertIs(ctx.exception.__cause__, original)  # original cause preserved
        self.assertEqual(conn.rollbacks, 1)  # errored read terminated the txn
        # connection reusable after the error
        self.assertIsNotNone(store.read_snapshot_state("sess-1"))

    def test_reads_never_commit_and_do_not_revert_committed_work(self) -> None:
        # A committed write must not be undone by a later read (reads only ever rollback
        # their own read-only txn and never commit).
        conn = _RecConn(rows_by_call={2: [("r1_resolved", "src-1", None, None, None, "sg8-pass-v1")]})
        store = PostgresSg8Store(conn)
        store.mark_resolved("sess-1")            # write → commit (call 1)
        self.assertEqual(conn.commits, 1)
        store.read_session_state("sess-1")       # read → rollback (call 2)
        self.assertEqual(conn.commits, 1)        # prior commit stands; read did not commit
        heads = [sql.split(None, 1)[0].lower() for sql, _ in conn.executed]
        self.assertEqual(heads, ["update", "select"])  # read issued no data mutation

    def test_read_session_state_rejects_invalid_shape(self) -> None:
        conn = _RecConn(rows_by_call={1: [("only", "four", "cols", "here", "five")]})  # want 6
        with self.assertRaises(Sg8PersistenceError):
            PostgresSg8Store(conn).read_session_state("sess-1")

    def test_read_snapshot_state_rejects_invalid_shape(self) -> None:
        conn = _RecConn(rows_by_call={1: [("snap-1", "src-1", "v", "h", 1)]})  # want 6
        with self.assertRaises(Sg8PersistenceError):
            PostgresSg8Store(conn).read_snapshot_state("sess-1")

    def test_read_round_evidence_rejects_invalid_shape(self) -> None:
        conn = _RecConn(rows_by_call={1: [("rep-1", "digest-1", "extra")]})  # want 2
        with self.assertRaises(Sg8PersistenceError):
            PostgresSg8Store(conn).read_round_evidence("re-1")


if __name__ == "__main__":
    unittest.main()
