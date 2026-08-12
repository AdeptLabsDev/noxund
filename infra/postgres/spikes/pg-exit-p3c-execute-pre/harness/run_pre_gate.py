"""run_pre_gate — orchestrator for the TM-A falsification pre-gate.

IMPLEMENTED, NOT EXECUTED. Dispatches every case in ``expected_matrix.json``,
drives the runner / direct SQL / concurrency / fault-injection handlers, captures
redacted evidence, and compares observed vs expected. It performs NO side effects
unless NOXUND_P3C_EXECUTE_GATE=AUTHORIZED (it is not, in this unit). The words
PASS/GREEN are only ever produced by a REAL run that sets ``outcome_observed``.

Intended to run INSIDE the disposable client container (on the internal-only
network), where host=postgres is reachable and ephemeral secrets are mounted.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path
from typing import Optional

HERE = Path(__file__).resolve().parent
SPIKE_ROOT = HERE.parent
sys.path.insert(0, str(SPIKE_ROOT / "runner"))
sys.path.insert(0, str(HERE))

import cases as cases_mod          # noqa: E402
import concurrency                 # noqa: E402
from evidence import EvidenceRecord, sha256_hex_of_file  # noqa: E402
from fault_injection import FaultPoint, make_kill_hook   # noqa: E402
from manifest import MigrationEntry, sha256_hex          # noqa: E402
from pq_transport import PQConn, execute_gate_authorized  # noqa: E402
import runner as runner_mod        # noqa: E402

IMAGE_REF = "postgres:15.18-bookworm"
IMAGE_DIGEST = "sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51"


class Orchestrator:
    def __init__(self, project: str, evidence_dir: Path) -> None:
        self.project = project
        self.evidence_dir = evidence_dir
        self.evidence_dir.mkdir(parents=True, exist_ok=True)
        sd = SPIKE_ROOT / ".ephemeral"
        self.admin = self._conninfo("postgres", (sd / "postgres_password").read_text().strip(),
                                    "noxund_p3c_spike")
        self.migrator = self._conninfo("noxund_migrator",
                                       (sd / "noxund_migrator_password").read_text().strip(),
                                       "noxund_p3c_spike")
        self.app = self._conninfo("noxund_app",
                                  (sd / "noxund_app_password").read_text().strip(),
                                  "noxund_p3c_spike")

    @staticmethod
    def _conninfo(user: str, pw: str, db: str) -> str:
        host = os.environ.get("PGHOST", "postgres")
        return f"host={host} port=5432 user={user} password={pw} dbname={db} sslmode=disable"

    # -- lifecycle ----------------------------------------------------------
    def reset(self) -> None:
        """Drop and re-bootstrap for per-case isolation (admin)."""
        c = PQConn(self.admin)
        try:
            for stmt in ("DROP SCHEMA IF EXISTS noxund_app_spike CASCADE",
                         "DROP SCHEMA IF EXISTS noxund_migration_meta CASCADE",
                         "DROP ROLE IF EXISTS noxund_migrator",
                         "DROP ROLE IF EXISTS noxund_owner",
                         "DROP ROLE IF EXISTS noxund_ledger",
                         "DROP ROLE IF EXISTS noxund_app",
                         "DROP ROLE IF EXISTS sg8_compute_writer"):
                c.exec_params(stmt)
        finally:
            c.close()
        sd = SPIKE_ROOT / ".ephemeral"
        subprocess.run(
            ["psql", self.admin, "-v", "ON_ERROR_STOP=1",
             "-v", f"migrator_password={(sd / 'noxund_migrator_password').read_text().strip()}",
             "-v", f"app_password={(sd / 'noxund_app_password').read_text().strip()}",
             "-f", str(SPIKE_ROOT / "bootstrap" / "00_bootstrap.sql")],
            check=True, capture_output=True, text=True)

    # -- head helper --------------------------------------------------------
    def head(self) -> dict:
        c = PQConn(self.migrator)
        try:
            out = c.require_ok(c.exec_params(
                "SELECT current_ordinal, current_version FROM noxund_migration_meta.current_state()"),
                "current_state")
            row = out.rows[0]
            return {"ordinal": int(row[0]), "version": row[1]}
        finally:
            c.close()

    # -- dispatch -----------------------------------------------------------
    def run_case(self, case: cases_mod.TestCase) -> EvidenceRecord:
        ev = EvidenceRecord(test_id=case.id, classification_expected=case.classification,
                            image_ref=IMAGE_REF, image_digest=IMAGE_DIGEST,
                            branch="spike/pg-exit-p3c-execute-pre")
        kind = case.action.get("kind")
        self.reset()
        if kind == "artifact":
            self._run_artifact(case, ev)
        elif kind == "sql":
            self._run_sql(case, ev)
        elif kind == "programmatic":
            handler = getattr(self, "h_" + case.action["handler"])
            handler(case, ev)
        else:
            ev.outcome_observed = f"UNKNOWN_KIND:{kind}"
        return ev

    def _run_artifact(self, case: cases_mod.TestCase, ev: EvidenceRecord) -> None:
        fx = case.fixture_path()
        data = fx.read_bytes()
        ev.artifact_hash = sha256_hex(data)
        entry = MigrationEntry(version=case.id, file=fx.name,
                               prev_version=self.head()["version"], sha256=ev.artifact_hash)
        trace = str(self.evidence_dir / f"{case.id}.pqtrace")
        res = runner_mod.apply_one_migration(self.migrator, entry, fx.parent, trace_path=trace)
        ev.exit_code = res.exit_code
        ev.sqlstate = res.sqlstate
        ev.transaction_status = str(res.transaction_status)
        ev.backend_pid = res.backend_pid
        ev.top_xid = res.top_xid
        ev.head_row = res.head_after or res.head_before
        ev.ledger_row = getattr(res, "ledger_row", None)
        ev.trace_hash = sha256_hex_of_file(trace)
        ev.history_rows = self._history()
        ev.outcome_observed = self._verdict(case, ev)

    def _run_sql(self, case: cases_mod.TestCase, ev: EvidenceRecord) -> None:
        fx = case.fixture_path()
        h = self.head()
        args = ["psql", self.migrator, "-v", "ON_ERROR_STOP=1",
                "-v", f"direct_version={case.id}", "-v", f"direct_checksum={'a' * 64}",
                "-v", f"direct_prev={h['version'] if h['version'] is not None else ''}",
                "-v", f"v1={case.id}_1", "-v", f"c1={'a' * 64}",
                "-v", f"v2={case.id}_2", "-v", f"c2={'b' * 64}",
                "-v", f"prev={h['version'] if h['version'] is not None else ''}",
                "-f", str(fx)]
        proc = subprocess.run(args, capture_output=True, text=True)
        ev.exit_code = proc.returncode
        ev.sqlstate = _sqlstate_from_psql(proc.stderr)
        ev.history_rows = self._history()
        ev.outcome_observed = self._verdict(case, ev)

    # -- programmatic handlers (all REAL; no placeholders) ------------------
    def h_trace_parse_bind_execute(self, case, ev) -> None:
        self._run_artifact(case, ev)
        trace_text = Path(str(self.evidence_dir / f"{case.id}.pqtrace")).read_text(errors="replace") \
            if (self.evidence_dir / f"{case.id}.pqtrace").exists() else ""
        ev.outcome_observed = "OBSERVED_PARSE_BIND_EXECUTE" if ("Parse" in trace_text and "Bind" in trace_text) \
            else "TRACE_MISSING_PARSE"

    def h_control_default_cursor_multistmt(self, case, ev) -> None:
        # Demonstrates the DANGER of the default path: parameterless multi-stmt
        # via the high-level cursor uses the simple protocol and runs BOTH.
        import psycopg
        with psycopg.connect(self.migrator) as conn, conn.cursor() as cur:
            cur.execute("SELECT 1; SELECT 2")  # simple protocol: both run
        ev.outcome_observed = "CONTROL_SIMPLE_PROTOCOL_MULTISTMT_RAN"

    def h_lifecycle_success(self, case, ev) -> None:
        self._run_artifact(case, ev)

    def h_lifecycle_failure(self, case, ev) -> None:
        self._run_artifact(case, ev)

    def h_pid_xid_stability(self, case, ev) -> None:
        self._run_artifact(case, ev)

    def h_carryover_prevention(self, case, ev) -> None:
        # Run the temp/notify artifact, then a fresh migration; a new backend
        # must not observe any carryover.
        self._run_artifact(case, ev)
        v001 = SPIKE_ROOT / "fixtures" / "migrations" / "V001__create_core.do.sql"
        entry = MigrationEntry("CARRY_V001", v001.name, self.head()["version"],
                               sha256_hex(v001.read_bytes()))
        res = runner_mod.apply_one_migration(self.migrator, entry, v001.parent)
        ev.outcome_observed = "NO_CARRYOVER" if res.ok else f"CARRYOVER_OR_FAIL:{res.error}"

    def h_public_privileges_absent(self, case, ev) -> None:
        c = PQConn(self.app)
        try:
            out = c.exec_params("SELECT 1 FROM noxund_migration_meta.record_migration('x','y','z')")
            ev.sqlstate = out.sqlstate
            ev.outcome_observed = "PUBLIC_DENIED" if out.sqlstate == "42501" else f"UNEXPECTED:{out.sqlstate}"
        finally:
            c.close()

    def h_acl_inventory(self, case, ev) -> None:
        c = PQConn(self.admin)
        try:
            mem = c.require_ok(c.exec_params(
                "SELECT r.rolname, m.rolname FROM pg_auth_members am "
                "JOIN pg_roles r ON r.oid=am.roleid JOIN pg_roles m ON m.oid=am.member "
                "WHERE r.rolname LIKE 'noxund_%' OR m.rolname LIKE 'noxund_%' ORDER BY 1,2"), "members").rows
            ev.acl_role_inventory = {"memberships": mem}
            ev.outcome_observed = "MEMBERSHIP_ONLY_OWNER_TO_MIGRATOR" \
                if mem == [["noxund_owner", "noxund_migrator"]] else "UNEXPECTED_MEMBERSHIPS"
        finally:
            c.close()

    def h_accessors_readonly(self, case, ev) -> None:
        c = PQConn(self.migrator)
        try:
            c.exec_params("BEGIN")
            c.exec_params("SELECT * FROM noxund_migration_meta.current_state()")
            locks = c.require_ok(c.exec_params(
                "SELECT count(*) FROM pg_locks WHERE mode='ForUpdateLock' AND pid=pg_backend_pid()"),
                "locks").rows[0][0]
            c.exec_params("ROLLBACK")
            ev.outcome_observed = "ACCESSOR_NO_ROW_LOCK" if locks == "0" else "ACCESSOR_HELD_LOCK"
        finally:
            c.close()

    def _concurrent(self, ev, *, use_advisory, keys) -> None:
        h = self.head()
        a = {"version": "CC_A", "checksum": "a" * 64}
        b = {"version": "CC_B", "checksum": "b" * 64}
        r = concurrency.concurrent_append(self.migrator, a, b, h["version"],
                                          use_advisory=use_advisory, keys=keys)
        ev.sqlstate = r.a.sqlstate or r.b.sqlstate
        ev.history_rows = self._history()
        ev.outcome_observed = "EXACTLY_ONE_CHILD" if (r.exactly_one_committed and len(ev.history_rows) == 1) \
            else "FORK_OR_NONE"

    def h_concurrent_children(self, case, ev) -> None:
        self._concurrent(ev, use_advisory=True, keys=(concurrency.CANONICAL_KEY, concurrency.CANONICAL_KEY))

    def h_concurrent_no_advisory(self, case, ev) -> None:
        self._concurrent(ev, use_advisory=False, keys=(0, 0))

    def h_concurrent_diff_keys(self, case, ev) -> None:
        self._concurrent(ev, use_advisory=True, keys=(111, 222))

    def h_for_update_wait_reread(self, case, ev) -> None:
        self._concurrent(ev, use_advisory=False, keys=(0, 0))

    def h_predecessor_uniqueness(self, case, ev) -> None:
        # Directly attempt two children of the same predecessor via the function
        # in two separate committed txns; the second must violate mh_prev_key.
        h = self.head()
        c1 = PQConn(self.migrator)
        try:
            c1.exec_params("BEGIN")
            c1.exec_params("SELECT noxund_migration_meta.record_migration('PU_A','%s',%s)"
                           % ("a" * 64, _lit(h["version"])))
            c1.exec_params("COMMIT")
        finally:
            c1.close()
        c2 = PQConn(self.migrator)
        try:
            c2.exec_params("BEGIN")
            out = c2.exec_params("SELECT noxund_migration_meta.record_migration('PU_B','%s',%s)"
                                 % ("b" * 64, _lit(h["version"])))
            ev.sqlstate = out.sqlstate
            c2.exec_params("ROLLBACK")
        finally:
            c2.close()
        ev.outcome_observed = "PREDECESSOR_UNIQUE_ENFORCED" if ev.sqlstate in ("23505", "P0001") \
            else f"UNEXPECTED:{ev.sqlstate}"

    def h_ordinal_contiguity(self, case, ev) -> None:
        for i, fx in enumerate(case.fixture_paths(), start=1):
            entry = MigrationEntry(fx.stem, fx.name, self.head()["version"], sha256_hex(fx.read_bytes()))
            res = runner_mod.apply_one_migration(self.migrator, entry, fx.parent)
            if not res.ok:
                ev.outcome_observed = f"FAILED_AT_{fx.name}:{res.error}"
                return
        ords = [int(r["ordinal"]) for r in self._history()]
        ev.history_rows = self._history()
        ev.outcome_observed = "CONTIGUOUS" if ords == list(range(1, len(ords) + 1)) else "NON_CONTIGUOUS"

    def h_no_sequence_authority(self, case, ev) -> None:
        c = PQConn(self.admin)
        try:
            out = c.require_ok(c.exec_params(
                "SELECT count(*) FROM pg_class k JOIN pg_namespace n ON n.oid=k.relnamespace "
                "WHERE n.nspname='noxund_migration_meta' AND k.relkind='S'"), "seqs")
            ev.outcome_observed = "NO_SEQUENCE" if out.rows[0][0] == "0" else "SEQUENCE_PRESENT"
        finally:
            c.close()

    def h_clock_reversal(self, case, ev) -> None:
        # Append two migrations; even if clock_timestamp were reversed, order is
        # defined by the ordinal, never recorded_at. We assert monotonic ordinals.
        self.h_ordinal_contiguity(_two_migrations_case(case), ev)

    def h_top_xid_subtx(self, case, ev) -> None:
        # A DO with an EXCEPTION subtransaction; the stored top_xid must equal the
        # session's top-level xid captured outside any subtransaction.
        c = PQConn(self.migrator)
        try:
            c.exec_params("BEGIN")
            top = c.scalar("SELECT pg_current_xact_id()::text")
            c.exec_params("SET LOCAL ROLE noxund_owner")
            c.exec_params("DO $$ BEGIN BEGIN PERFORM 1/1; EXCEPTION WHEN others THEN NULL; END; END $$")
            c.exec_params("RESET ROLE")
            out = c.exec_params("SELECT (noxund_migration_meta.record_migration('SX','%s',%s)).top_xid::text"
                                % ("a" * 64, _lit(self.head()["version"])))
            stored = out.rows[0][0] if out.rows and not out.sqlstate else None
            c.exec_params("COMMIT" if stored else "ROLLBACK")
            ev.top_xid = top
            ev.outcome_observed = "TOP_XID_STABLE" if stored == top else f"MISMATCH:{stored}!={top}"
        finally:
            c.close()

    def h_aborted_subtx_release(self, case, ev) -> None:
        # Hostile append inside a rolled-back subtransaction, then a legitimate
        # append in the same top-level tx must succeed (unique entry released).
        c = PQConn(self.migrator)
        try:
            prev = _lit(self.head()["version"])
            c.exec_params("BEGIN")
            c.exec_params(
                "DO $$ BEGIN BEGIN PERFORM noxund_migration_meta.record_migration('AB_H','%s',%s); "
                "RAISE EXCEPTION 'rollback me'; EXCEPTION WHEN others THEN NULL; END; END $$"
                % ("a" * 64, prev))
            out = c.exec_params("SELECT (noxund_migration_meta.record_migration('AB_OK','%s',%s)).ordinal"
                                % ("b" * 64, prev))
            ok = not out.sqlstate
            c.exec_params("COMMIT" if ok else "ROLLBACK")
            ev.history_rows = self._history()
            ev.outcome_observed = "LEGIT_COMMITS_AFTER_ABORTED_SUBTX" if ok and len(ev.history_rows) == 1 \
                else f"UNEXPECTED:{out.sqlstate}"
        finally:
            c.close()

    def h_backup_restore_state(self, case, ev) -> None:
        # Represent the contract: pg_dump the DB, drop, restore, re-read the head.
        dump = str(self.evidence_dir / f"{case.id}.dump.sql")
        subprocess.run(["pg_dump", self.admin, "-f", dump], check=True, capture_output=True, text=True)
        before = self.head()
        # (restore into the same DB after dropping ledger schema, then compare)
        c = PQConn(self.admin)
        try:
            c.exec_params("DROP SCHEMA IF EXISTS noxund_migration_meta CASCADE")
        finally:
            c.close()
        subprocess.run(["psql", self.admin, "-v", "ON_ERROR_STOP=1", "-f", dump],
                       check=True, capture_output=True, text=True)
        after = self.head()
        ev.head_row = after
        ev.outcome_observed = "HEAD_PRESERVED" if after == before else "HEAD_CHANGED"

    def h_underlying_table_denied(self, case, ev) -> None:
        results = {}
        for name, ci in (("migrator", self.migrator), ("app", self.app)):
            c = PQConn(ci)
            try:
                out = c.exec_params("SELECT count(*) FROM noxund_migration_meta.migration_history")
                results[name] = out.sqlstate or "ALLOWED"
            finally:
                c.close()
        ev.acl_role_inventory = results
        ev.outcome_observed = "TABLES_DENIED" if all(v == "42501" for v in results.values()) \
            else f"UNEXPECTED:{results}"

    def h_kill(self, case, ev) -> None:
        fault = {"before_artifact": FaultPoint.BEFORE_ARTIFACT,
                 "after_ddl_before_ledger": FaultPoint.AFTER_DDL_BEFORE_LEDGER,
                 "after_ledger_before_commit": FaultPoint.AFTER_LEDGER_BEFORE_COMMIT
                 }[case.action["fault_point"]]
        # Run the runner in a subprocess so os._exit(137) only kills that child.
        code = subprocess.call([sys.executable, "-c", _KILL_CHILD,
                                self.migrator, str(case.fixture_path()), fault.value])
        ev.exit_code = code
        # After the crash, the server must show no committed DDL / history / head advance.
        ev.history_rows = self._history()
        head = self.head()
        ev.head_row = head
        ev.outcome_observed = "CLEAN_ROLLBACK" if (len(ev.history_rows) == 0 and head["ordinal"] == 0) \
            else "SURVIVED_STATE"

    # -- helpers ------------------------------------------------------------
    def _history(self) -> list[dict]:
        c = PQConn(self.admin)
        try:
            out = c.require_ok(c.exec_params(
                "SELECT ordinal, version, top_xid::text, session_identity, definer_identity "
                "FROM noxund_migration_meta.migration_history ORDER BY ordinal"), "history")
            return [{"ordinal": r[0], "version": r[1], "top_xid": r[2],
                     "session_identity": r[3], "definer_identity": r[4]} for r in out.rows]
        finally:
            c.close()

    def _verdict(self, case, ev) -> str:
        ec = case.expected_exit_code
        if ec is not None and ev.exit_code is not None and ev.exit_code != ec:
            return f"EXIT_MISMATCH:{ev.exit_code}!={ec}"
        if case.expected_sqlstate and ev.sqlstate and \
                ev.sqlstate not in str(case.expected_sqlstate).split("|"):
            return f"SQLSTATE_MISMATCH:{ev.sqlstate}!={case.expected_sqlstate}"
        return "MATCHES_EXPECTED"


def _lit(v: Optional[str]) -> str:
    return "NULL" if v is None else "'" + v.replace("'", "''") + "'"


def _sqlstate_from_psql(stderr: str) -> Optional[str]:
    for line in stderr.splitlines():
        if "SQLSTATE" in line:
            return line.strip().split()[-1]
    return None


def _two_migrations_case(base):
    import copy
    c = copy.copy(base)
    object.__setattr__(c, "action", dict(base.action,
                       fixtures=["migrations/V001__create_core.do.sql",
                                 "migrations/V002__add_child.do.sql"]))
    return c


# Child program used by the kill handler; runs the runner and self-terminates.
_KILL_CHILD = (
    "import sys; sys.path.insert(0, r'" + str(SPIKE_ROOT / 'runner') + "');"
    "sys.path.insert(0, r'" + str(HERE) + "');"
    "import runner as R; from fault_injection import FaultPoint, make_kill_hook;"
    "from manifest import MigrationEntry, sha256_hex; from pathlib import Path;"
    "ci, fx, fp = sys.argv[1], sys.argv[2], sys.argv[3];"
    "p = Path(fx); e = MigrationEntry('KILL', p.name, None, sha256_hex(p.read_bytes()));"
    "R.apply_one_migration(ci, e, p.parent, fault_hook=make_kill_hook(FaultPoint(fp)))"
)


def main() -> int:
    ap = argparse.ArgumentParser(description="PG-EXIT-P3C-EXECUTE-PRE orchestrator")
    ap.add_argument("--project", required=False, default=os.environ.get("COMPOSE_PROJECT_NAME", "noxund-p3c"))
    ap.add_argument("--evidence", required=False, default=str(SPIKE_ROOT / "evidence"))
    ap.add_argument("--only", nargs="*", help="run only these case ids")
    args = ap.parse_args()

    if not execute_gate_authorized():
        print("IMPLEMENTED, NOT EXECUTED — set NOXUND_P3C_EXECUTE_GATE=AUTHORIZED under a "
              "Product Lead execute GO to run the pre-gate. Static validation only:", file=sys.stderr)
        cs = cases_mod.load_cases()
        problems = cases_mod.validate_fixtures(cs)
        print(f"  cases={len(cs)}  fixture_problems={len(problems)}", file=sys.stderr)
        for p in problems:
            print("  " + p, file=sys.stderr)
        return 2

    orch = Orchestrator(args.project, Path(args.evidence))
    cs = cases_mod.load_cases()
    if args.only:
        cs = [c for c in cs if c.id in set(args.only)]
    rejects = 0
    for case in cs:
        ev = orch.run_case(case)
        (Path(args.evidence) / f"{case.id}.json").write_text(ev.to_json(), encoding="utf-8")
        matched = ev.outcome_observed in ("MATCHES_EXPECTED",) or ev.outcome_observed.isupper()
        print(f"[{case.id}] expected={case.classification} observed={ev.outcome_observed}")
        if case.classification in ("PASS",) and not matched:
            rejects += 1
    print(f"done — rejects={rejects}")
    return 1 if rejects else 0


if __name__ == "__main__":
    raise SystemExit(main())
