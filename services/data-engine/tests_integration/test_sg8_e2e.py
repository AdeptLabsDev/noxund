"""SG-8 E2E integration tests — runner ↔ PostgresSg8Store vs a disposable local Supabase.

Requires the local stack (``supabase start`` + ``supabase db reset``) and the hash-pinned
psycopg driver; run ONLY by ``.github/workflows/sg8-integration-local.yml`` (never the
driver-free unit suite). Each test owns its own dedicated connection and unique id
namespace, and closes the connection explicitly. No network beyond the loopback stack.

Provider-neutral (DEC-0025): the SG-8 path uses NO LLM/model/provider. Entity resolution
runs with the generative boundary OFF; an ambiguous title goes to human review. Both rounds
persist the SAME deterministic compute provenance (identical ``compute_manifest_hash``).

The driver is imported ONLY by ``bootstrap`` — this module catches DB errors by SQLSTATE
without importing psycopg.
"""

from __future__ import annotations

import json
import os
import unittest
from datetime import datetime, timezone

from bootstrap import connect_local

from noxund_data_engine.entity_resolution import RESOLVER_VERSION
from noxund_data_engine.pipeline import ArtistRow, ChannelRow, PipelineSnapshot, RawVideoRow
from noxund_data_engine.postgres_sg8 import (
    PostgresSg8Store,
    Sg8ForeignKeyViolation,
    Sg8IntegrityGuardViolation,
    Sg8UniqueViolation,
)
from noxund_data_engine.sg8_coordinator import (
    SequentialIdFactory,
    Sg8Coordinator,
    build_compute_provenance,
    default_compute_manifest,
    derive_snapshot_metadata,
)
from noxund_data_engine.sg8_runner import (
    ReviewDecision,
    Sg8Report,
    Sg8Session,
    Sg8SessionInput,
    Sg8State,
)

WINDOW_END = datetime(2026, 6, 30, tzinfo=timezone.utc)
PUBLISHED = datetime(2026, 6, 29, tzinfo=timezone.utc)
# "Free ...": a metadata residual the rules cannot resolve -> human review (no model).
AMBIGUOUS_TITLE = "Free Zephyr Prime Type Beat"

_SQLSTATE_NOT_NULL = "23502"
_SQLSTATE_CHECK = "23514"
_SQLSTATE_RESTRICT = "23001"


def _snapshot(run_id: str, *, with_ambiguous: bool) -> PipelineSnapshot:
    videos = [
        RawVideoRow(f"{run_id}-k{i:02d}", f"ch-{i % 3}", "Kairo Vee Type Beat",
                    40000 + i, 5000, 900, PUBLISHED)
        for i in range(4)
    ]
    if with_ambiguous:
        videos.append(RawVideoRow(f"{run_id}-z01", "ch-9", AMBIGUOUS_TITLE, 30000, 4200, 760, PUBLISHED))
    videos_t = tuple(videos)
    artists = (ArtistRow("artist-kairo", "Kairo Vee"), ArtistRow("artist-zephyr", "Zephyr Prime"))
    channels = tuple(ChannelRow(cid) for cid in sorted({v.channel_id for v in videos_t}))
    return PipelineSnapshot(run_id, "Report", WINDOW_END, videos_t, channels, artists)


def _build_session(src, rep1, rep2, session_id) -> Sg8Session:
    reports = (
        Sg8Report(rep1, _snapshot(rep1, with_ambiguous=True)),
        Sg8Report(rep2, _snapshot(rep2, with_ambiguous=False)),
    )
    return Sg8Session(Sg8SessionInput(src, reports), sg8_session_id=session_id)


def _prov():
    """The deterministic compute provenance persisted for both rounds (identical manifest)."""
    return build_compute_provenance()


# ---------------------------------------------------------------------------
# Predecessor fixtures + direct store-driven walks (for DB-gate tests).
# ---------------------------------------------------------------------------
def _insert_fixtures(conn, *, src, rep1, rep2, rubric, src2=None) -> None:
    with conn.cursor() as cur:
        cur.execute("insert into public.rubric_versions (version, config_json, hash) values (%s, %s::jsonb, %s)",
                    (rubric, "{}", "h"))
        cur.execute("insert into public.report_runs (id, window_start, window_end) "
                    "values (%s, now() - interval '30 days', now())", (src,))
        if src2 is not None:
            cur.execute("insert into public.report_runs (id, window_start, window_end) "
                        "values (%s, now() - interval '60 days', now() - interval '31 days')", (src2,))
        cur.execute("insert into public.reports (id, run_id, title, rubric_version, rubric_hash) "
                    "values (%s, %s, %s, %s, %s)", (rep1, src, "R1", rubric, "h"))
        cur.execute("insert into public.reports (id, run_id, title, rubric_version, rubric_hash) "
                    "values (%s, %s, %s, %s, %s)", (rep2, src, "R2", rubric, "h"))
    conn.commit()


def _walk_store_to_computed(store, ids, *, session_id, src, rep1, rep2):
    """Drive the STORE (not the runner) to r1_computed + binding + snapshot (for DB gates)."""
    store.open_session(session_id, src)
    store.mark_awaiting_review(session_id)
    store.mark_resolved(session_id)
    snap = ids.new_id()
    store.freeze_snapshot(session_id, source_collection_run_id=src, resolution_snapshot_id=snap,
                          resolver_version="entity-resolver-v1", resolver_hash="rhash",
                          fact_count=2, content_hash="chash")
    store.bind_reports(session_id, report_run_id_1=rep1, report_run_id_2=rep2)
    return snap


class _E2EBase(unittest.TestCase):
    def _expect_sqlstate(self, conn, sql, params, sqlstate):
        try:
            with conn.cursor() as cur:
                cur.execute(sql, params)
            conn.rollback()
            self.fail(f"expected SQLSTATE {sqlstate}, but the statement succeeded")
        except AssertionError:
            raise
        except Exception as exc:  # a DB error carrying a SQLSTATE
            got = getattr(exc, "sqlstate", None)
            conn.rollback()
            self.assertEqual(got, sqlstate, f"expected {sqlstate}, got {got}: {exc}")


# ---------------------------------------------------------------------------
# Happy path — full lifecycle to passed + deterministic compute-manifest proof.
# ---------------------------------------------------------------------------
class HappyPathTests(_E2EBase):
    def test_lifecycle_reaches_passed_with_provenance_and_digest_proof(self) -> None:
        conn = connect_local()
        try:
            ids = SequentialIdFactory(namespace=0x0A)
            src, rep1, rep2, session_id = (ids.new_id() for _ in range(4))
            _insert_fixtures(conn, src=src, rep1=rep1, rep2=rep2, rubric="sg8-vr-0a")
            session = _build_session(src, rep1, rep2, session_id)
            store = PostgresSg8Store(conn)
            coord = Sg8Coordinator(session, store, ids, source_collection_run_id=src)

            coord.open_session()
            state = coord.resolve_round1()
            # No model was consulted; the ambiguous item was routed to human review.
            self.assertIs(state, Sg8State.R1_AWAITING_REVIEW)
            self.assertEqual(session.external_resolver_call_count, 0)
            coord.submit_review([ReviewDecision(rid, vid, approved=True, artist_id="artist-zephyr")
                                 for (rid, vid) in session.pending_review_keys])
            coord.freeze(snapshot_metadata=derive_snapshot_metadata(
                session._input, resolver_version=RESOLVER_VERSION))  # type: ignore[attr-defined]
            evidence = coord.compute_round1(provenance=_prov(), report_run_id_1=rep1, report_run_id_2=rep2)
            verdict = coord.run_round2()
            self.assertTrue(verdict.passed)
            self.assertEqual(session.external_resolver_call_count, 0)  # zero external calls, both rounds

            # terminal state
            self.assertEqual(store.read_session_state(session_id).status, "passed")
            r1, r2 = coord.round_execution_id(1), coord.round_execution_id(2)
            self.assertEqual(store.read_round_execution_id(session_id, 1), r1)
            self.assertEqual(store.read_round_execution_id(session_id, 2), r2)
            self.assertNotEqual(r1, r2)

            # exactly two evidences per round; R1 == R2; persisted == runner-computed
            ev1, ev2 = dict(store.read_round_evidence(r1)), dict(store.read_round_evidence(r2))
            self.assertEqual(set(ev1), {rep1, rep2})
            self.assertEqual(len(ev1), 2)
            self.assertEqual(len(ev2), 2)
            self.assertEqual(ev1, ev2)
            self.assertEqual(ev1, dict(evidence.report_digests))

            # DEC-0025 compute provenance: R1 manifest == canonical default; R2 identical to R1;
            # deterministic engine identity present; NO provider/model/prompt column exists.
            expected_manifest = default_compute_manifest()
            with conn.cursor() as cur:
                cur.execute("select compute_engine_name, compute_engine_version, compute_manifest_hash, "
                            "compute_adapter_version, compute_params_json from public.sg8_round_executions "
                            "where id = %s", (r1,))
                row1 = cur.fetchone()
                cur.execute("select compute_engine_name, compute_engine_version, compute_manifest_hash, "
                            "compute_adapter_version from public.sg8_round_executions where id = %s", (r2,))
                row2 = cur.fetchone()
            conn.rollback()
            self.assertEqual(row1[2], expected_manifest)          # R1 manifest = canonical default
            self.assertEqual(row2[2], expected_manifest)          # R2 manifest = SAME (DEC-0025)
            self.assertEqual(row1[0], "noxund-pipeline")
            self.assertTrue(all(v is not None for v in row1[:4]))  # deterministic provenance present

            # Round 2 evidence has its OWN origin — persisted verbatim, never an R1 copy.
            r2_ev = coord.round2_evidence
            self.assertIsNotNone(r2_ev)
            self.assertEqual(r2_ev.round_execution_id, r2)
            self.assertNotEqual(r2_ev.round_execution_id, evidence.round_execution_id)
            self.assertIsNot(r2_ev, evidence)
            self.assertEqual(ev2, dict(r2_ev.report_digests))          # persisted == R2's own result
            self.assertEqual(dict(r2_ev.report_digests), dict(evidence.report_digests))  # equal values, distinct origin

            # Deterministic happy-path manifest (compared byte-for-byte across the ×2 runs).
            manifest_path = os.environ.get("SG8_E2E_MANIFEST")
            if manifest_path:
                with open(manifest_path, "w", encoding="utf-8") as fh:
                    json.dump({
                        "status": "passed",
                        "session_id": session_id,
                        "snapshot_id": coord.resolution_snapshot_id,
                        "round1_id": r1, "round2_id": r2,
                        "round1_digests": dict(sorted(ev1.items())),
                        "round2_digests": dict(sorted(ev2.items())),
                        "compute_manifest_hash": row1[2],
                    }, fh, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        finally:
            conn.close()


# ---------------------------------------------------------------------------
# Resume — close after the waiting state, reopen, continue on the same session.
# ---------------------------------------------------------------------------
class ResumeTests(_E2EBase):
    def test_resume_across_connections_without_duplication(self) -> None:
        ids = SequentialIdFactory(namespace=0x0B)
        src, rep1, rep2, session_id = (ids.new_id() for _ in range(4))
        session = _build_session(src, rep1, rep2, session_id)

        conn1 = connect_local()
        try:
            _insert_fixtures(conn1, src=src, rep1=rep1, rep2=rep2, rubric="sg8-vr-0b")
            coord1 = Sg8Coordinator(session, PostgresSg8Store(conn1), ids, source_collection_run_id=src)
            coord1.open_session()
            self.assertIs(coord1.resolve_round1(), Sg8State.R1_AWAITING_REVIEW)
        finally:
            conn1.close()  # end the first connection/store at the waiting state

        conn2 = connect_local()
        try:
            store2 = PostgresSg8Store(conn2)
            resumed = store2.read_session_state(session_id)
            self.assertEqual(resumed.status, "r1_awaiting_review")
            self.assertEqual(resumed.source_collection_run_id, src)

            coord2 = Sg8Coordinator(session, store2, ids, source_collection_run_id=src)
            coord2.submit_review([ReviewDecision(rid, vid, approved=True, artist_id="artist-zephyr")
                                  for (rid, vid) in session.pending_review_keys])
            coord2.freeze(snapshot_metadata=derive_snapshot_metadata(
                session._input, resolver_version=RESOLVER_VERSION))  # type: ignore[attr-defined]
            coord2.compute_round1(provenance=_prov(), report_run_id_1=rep1, report_run_id_2=rep2)
            self.assertTrue(coord2.run_round2().passed)
            self.assertEqual(store2.read_session_state(session_id).status, "passed")

            with conn2.cursor() as cur:
                cur.execute("select count(*) from public.sg8_resolution_snapshots where sg8_session_id=%s", (session_id,))
                self.assertEqual(cur.fetchone()[0], 1)   # no duplicate snapshot
                cur.execute("select count(*) from public.sg8_round_executions where sg8_session_id=%s", (session_id,))
                self.assertEqual(cur.fetchone()[0], 2)   # exactly one R1 + one R2
                cur.execute("select count(*) from public.sg8_sessions where id=%s", (session_id,))
                self.assertEqual(cur.fetchone()[0], 1)   # no duplicate session
            conn2.rollback()
        finally:
            conn2.close()


# ---------------------------------------------------------------------------
# Drift — the DB PASS gate rejects a mismatched pair; session ends failed/terminal.
# ---------------------------------------------------------------------------
class DriftTests(_E2EBase):
    def test_drift_rejected_by_db_and_transitions_to_failed(self) -> None:
        conn = connect_local()
        try:
            ids = SequentialIdFactory(namespace=0x0C)
            src, rep1, rep2, session_id = (ids.new_id() for _ in range(4))
            _insert_fixtures(conn, src=src, rep1=rep1, rep2=rep2, rubric="sg8-vr-0c")
            store = PostgresSg8Store(conn)
            snap = _walk_store_to_computed(store, ids, session_id=session_id, src=src, rep1=rep1, rep2=rep2)
            r1, r2 = ids.new_id(), ids.new_id()
            # Both rounds carry the SAME compute provenance (identical manifest) so the manifest
            # gate passes and the DIGEST drift is what the PASS gate rejects.
            store.append_round(round_execution_id=r1, sg8_session_id=session_id, round_number=1,
                               source_collection_run_id=src, resolution_snapshot_id=snap, provenance=_prov())
            store.append_round(round_execution_id=r2, sg8_session_id=session_id, round_number=2,
                               source_collection_run_id=src, resolution_snapshot_id=snap, provenance=_prov())
            store.append_evidence(round_execution_id=r1, sg8_session_id=session_id, report_run_id=rep1, canonical_digest="DIG-A")
            store.append_evidence(round_execution_id=r1, sg8_session_id=session_id, report_run_id=rep2, canonical_digest="DIG-B")
            store.append_evidence(round_execution_id=r2, sg8_session_id=session_id, report_run_id=rep1, canonical_digest="DIG-A")
            store.append_evidence(round_execution_id=r2, sg8_session_id=session_id, report_run_id=rep2, canonical_digest="DIG-B-DRIFT")

            with self.assertRaises(Sg8IntegrityGuardViolation):
                store.mark_passed(session_id, verdict_reason="should be rejected by PASS gate")
            self.assertEqual(store.read_session_state(session_id).status, "r1_computed")  # not passed

            store.mark_failed(session_id, verdict_reason="digest drift R1 != R2")
            self.assertEqual(store.read_session_state(session_id).status, "failed")

            # terminal: no reopening — another transition is rejected
            with self.assertRaises(Sg8IntegrityGuardViolation):
                store.mark_failed(session_id, verdict_reason="attempt to re-drive a terminal session")
            self.assertEqual(store.read_session_state(session_id).status, "failed")
        finally:
            conn.close()


# ---------------------------------------------------------------------------
# Real constraints — the DB enforces them; the adapter translates + stays reusable.
# ---------------------------------------------------------------------------
class RealConstraintTests(_E2EBase):
    def test_violations_translate_to_domain_exceptions_and_connection_reusable(self) -> None:
        conn = connect_local()
        try:
            ids = SequentialIdFactory(namespace=0x0D)
            src, rep1, rep2, session_id, src2 = (ids.new_id() for _ in range(5))
            _insert_fixtures(conn, src=src, rep1=rep1, rep2=rep2, rubric="sg8-vr-0d", src2=src2)
            store = PostgresSg8Store(conn)
            snap = _walk_store_to_computed(store, ids, session_id=session_id, src=src, rep1=rep1, rep2=rep2)
            r1 = ids.new_id()
            store.append_round(round_execution_id=r1, sg8_session_id=session_id, round_number=1,
                               source_collection_run_id=src, resolution_snapshot_id=snap, provenance=_prov())
            store.append_evidence(round_execution_id=r1, sg8_session_id=session_id, report_run_id=rep1, canonical_digest="d1")
            store.append_evidence(round_execution_id=r1, sg8_session_id=session_id, report_run_id=rep2, canonical_digest="d2")

            # duplicate evidence (same round, same report) -> unique
            with self.assertRaises(Sg8UniqueViolation):
                store.append_evidence(round_execution_id=r1, sg8_session_id=session_id, report_run_id=rep1, canonical_digest="dup")
            # second Round 1 -> unique
            with self.assertRaises(Sg8UniqueViolation):
                store.append_round(round_execution_id=ids.new_id(), sg8_session_id=session_id, round_number=1,
                                   source_collection_run_id=src, resolution_snapshot_id=snap, provenance=_prov())
            # divergent dataset (source_collection_run_id != the session's) -> foreign key
            with self.assertRaises(Sg8ForeignKeyViolation):
                store.append_round(round_execution_id=ids.new_id(), sg8_session_id=session_id, round_number=2,
                                   source_collection_run_id=src2, resolution_snapshot_id=snap, provenance=_prov())

            # connection reusable after every handled error
            self.assertEqual(store.read_session_state(session_id).status, "r1_computed")
            self.assertEqual(len(store.read_round_evidence(r1)), 2)
        finally:
            conn.close()

    def test_db_enforces_compute_provenance_and_manifest_hash_format(self) -> None:
        # Direct SQL proves the SCHEMA rejects these independently of the adapter pre-check.
        conn = connect_local()
        try:
            ids = SequentialIdFactory(namespace=0x0E)
            src, rep1, rep2, session_id = (ids.new_id() for _ in range(4))
            _insert_fixtures(conn, src=src, rep1=rep1, rep2=rep2, rubric="sg8-vr-0e")
            store = PostgresSg8Store(conn)
            snap = _walk_store_to_computed(store, ids, session_id=session_id, src=src, rep1=rep1, rep2=rep2)
            base = ("insert into public.sg8_round_executions "
                    "(id, sg8_session_id, round_number, source_collection_run_id, resolution_snapshot_id")
            cols = (", compute_engine_name, compute_engine_version, compute_manifest_hash, compute_adapter_version)")
            good_mh = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

            # DEC-0025: Round 1 with NO compute provenance -> not_null_violation
            self._expect_sqlstate(
                conn, base + ") values (%s, %s, 1, %s, %s)",
                (ids.new_id(), session_id, src, snap), _SQLSTATE_NOT_NULL)
            # DEC-0025: Round 2 with NO compute provenance -> not_null_violation (symmetric)
            self._expect_sqlstate(
                conn, base + ") values (%s, %s, 2, %s, %s)",
                (ids.new_id(), session_id, src, snap), _SQLSTATE_NOT_NULL)
            # blank compute_engine_name -> check_violation (nonblank)
            self._expect_sqlstate(
                conn, base + cols + " values (%s, %s, 1, %s, %s, %s, %s, %s, %s)",
                (ids.new_id(), session_id, src, snap, "   ", "pipeline-wiring-2026_06_v1", good_mh, "sg8-store-adapter-v1"),
                _SQLSTATE_CHECK)
            # version-token (non-64-hex) compute_manifest_hash -> check_violation
            self._expect_sqlstate(
                conn, base + cols + " values (%s, %s, 1, %s, %s, %s, %s, %s, %s)",
                (ids.new_id(), session_id, src, snap, "noxund-pipeline", "pipeline-wiring-2026_06_v1", "sg8-manifest-v1", "sg8-store-adapter-v1"),
                _SQLSTATE_CHECK)
            self.assertEqual(store.read_session_state(session_id).status, "r1_computed")  # reusable
        finally:
            conn.close()

    def test_append_only_update_delete_are_blocked(self) -> None:
        conn = connect_local()
        try:
            ids = SequentialIdFactory(namespace=0x0F)
            src, rep1, rep2, session_id = (ids.new_id() for _ in range(4))
            _insert_fixtures(conn, src=src, rep1=rep1, rep2=rep2, rubric="sg8-vr-0f")
            store = PostgresSg8Store(conn)
            snap = _walk_store_to_computed(store, ids, session_id=session_id, src=src, rep1=rep1, rep2=rep2)
            r1 = ids.new_id()
            store.append_round(round_execution_id=r1, sg8_session_id=session_id, round_number=1,
                               source_collection_run_id=src, resolution_snapshot_id=snap, provenance=_prov())
            store.append_evidence(round_execution_id=r1, sg8_session_id=session_id, report_run_id=rep1, canonical_digest="d1")

            # snapshot / round / evidence are append-only -> UPDATE and DELETE raise restrict
            self._expect_sqlstate(conn, "update public.sg8_resolution_snapshots set content_hash='x' where id=%s", (snap,), _SQLSTATE_RESTRICT)
            self._expect_sqlstate(conn, "update public.sg8_round_executions set compute_engine_name='x' where id=%s", (r1,), _SQLSTATE_RESTRICT)
            self._expect_sqlstate(conn, "delete from public.sg8_round_report_evidence where round_execution_id=%s", (r1,), _SQLSTATE_RESTRICT)
            self.assertEqual(store.read_session_state(session_id).status, "r1_computed")  # reusable
        finally:
            conn.close()


if __name__ == "__main__":
    unittest.main()
