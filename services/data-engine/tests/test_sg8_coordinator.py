"""Unit tests for the SG-8 U2B wiring layer (driver-free, offline; DEC-0025).

These drive the REAL in-memory ``Sg8Session`` runner through ``Sg8Coordinator`` against
a recording fake store — NO database, NO psycopg, NO Docker, NO network, NO LLM. They
prove the wiring MIRRORS the runner's transitions onto the store (no second FSM), mints
application-owned ids, and persists the SAME deterministic compute provenance on both
rounds. The DB-enforced behaviour (constraints/triggers/PASS gate) is the E2E suite's job.
"""

from __future__ import annotations

import hashlib
import inspect
import json
import re
import unittest
from datetime import datetime, timezone

from noxund_data_engine import sg8_coordinator as coord_mod
from noxund_data_engine.channel_filter import DEFAULT_CONFIG as CHANNEL_FILTER_DEFAULT_CONFIG
from noxund_data_engine.entity_resolution import RESOLVER_VERSION
from noxund_data_engine.opportunity import DEFAULT_CONFIG as OPPORTUNITY_DEFAULT_CONFIG
from noxund_data_engine.pipeline import (
    PIPELINE_VERSION,
    ArtistRow,
    ChannelRow,
    PipelineSnapshot,
    RawVideoRow,
)
from noxund_data_engine.postgres_sg8 import Sg8ComputeProvenance
from noxund_data_engine.scoring import DEFAULT_RUBRIC
from noxund_data_engine.sg8_coordinator import (
    COMPUTE_ENGINE_NAME,
    COMPUTE_MANIFEST_FORMAT_VERSION,
    SequentialIdFactory,
    Sg8Coordinator,
    UuidIdFactory,
    build_compute_provenance,
    canonical_compute_manifest,
    default_compute_manifest,
    derive_snapshot_metadata,
)
from noxund_data_engine.sg8_runner import (
    ReviewDecision,
    Sg8Report,
    Sg8Session,
    Sg8SessionInput,
    Sg8State,
    Sg8TerminalSessionError,
)

WINDOW_END = datetime(2026, 6, 30, tzinfo=timezone.utc)
PUBLISHED = datetime(2026, 6, 29, tzinfo=timezone.utc)
# "Free ... Type Beat": a metadata residual the rules cannot resolve -> human review.
AMBIGUOUS_TITLE = "Free Zephyr Prime Type Beat"


def _snapshot(run_id: str, *, with_ambiguous: bool) -> PipelineSnapshot:
    videos = [
        RawVideoRow(f"{run_id}-k{i:02d}", f"ch-{i % 3}", "Kairo Vee Type Beat",
                    40000 + i, 5000, 900, PUBLISHED)
        for i in range(4)
    ]
    if with_ambiguous:
        videos.append(
            RawVideoRow(f"{run_id}-z01", "ch-9", AMBIGUOUS_TITLE, 30000, 4200, 760, PUBLISHED)
        )
    videos_t = tuple(videos)
    artists = (ArtistRow("artist-kairo", "Kairo Vee"), ArtistRow("artist-zephyr", "Zephyr Prime"))
    channels = tuple(ChannelRow(cid) for cid in sorted({v.channel_id for v in videos_t}))
    return PipelineSnapshot(run_id, "Report", WINDOW_END, videos_t, channels, artists)


def _session(*, with_ambiguous: bool, session_id: str = "sg8-session-A") -> Sg8Session:
    reports = (
        Sg8Report("report-1of2", _snapshot("report-1of2", with_ambiguous=with_ambiguous)),
        Sg8Report("report-2of2", _snapshot("report-2of2", with_ambiguous=False)),
    )
    return Sg8Session(Sg8SessionInput("src-run-1", reports), sg8_session_id=session_id)


class _RecStore:
    """Records the coordinator's store calls in order (Sg8Store surface it uses)."""

    def __init__(self) -> None:
        self.calls: list[tuple] = []

    def open_session(self, sid, src):
        self.calls.append(("open_session", sid, src))

    def mark_awaiting_review(self, sid):
        self.calls.append(("mark_awaiting_review", sid))

    def mark_resolved(self, sid):
        self.calls.append(("mark_resolved", sid))

    def freeze_snapshot(self, sid, **kw):
        self.calls.append(("freeze_snapshot", sid, kw))

    def bind_reports(self, sid, **kw):
        self.calls.append(("bind_reports", sid, kw))

    def append_round(self, **kw):
        self.calls.append(("append_round", kw["round_number"], kw["provenance"], kw["round_execution_id"]))

    def append_evidence(self, **kw):
        self.calls.append(("append_evidence", kw["round_execution_id"], kw["report_run_id"], kw["canonical_digest"]))

    def mark_passed(self, sid, *, verdict_reason):
        self.calls.append(("mark_passed", sid, verdict_reason))

    def mark_failed(self, sid, *, verdict_reason):
        self.calls.append(("mark_failed", sid, verdict_reason))

    def names(self) -> list[str]:
        return [c[0] for c in self.calls]


def _drive_to_passed(coord: Sg8Coordinator, session: Sg8Session) -> None:
    coord.open_session()
    state = coord.resolve_round1()
    if state is Sg8State.R1_AWAITING_REVIEW:
        coord.submit_review(
            [ReviewDecision(rid, vid, approved=True, artist_id="artist-zephyr")
             for (rid, vid) in session.pending_review_keys]
        )
    meta = derive_snapshot_metadata(session._input, resolver_version=RESOLVER_VERSION)  # type: ignore[attr-defined]
    coord.freeze(snapshot_metadata=meta)
    coord.compute_round1(
        provenance=build_compute_provenance(),
        report_run_id_1="report-1of2",
        report_run_id_2="report-2of2",
    )
    coord.run_round2()


# ---------------------------------------------------------------------------
# IdFactory.
# ---------------------------------------------------------------------------
class IdFactoryTests(unittest.TestCase):
    def test_sequential_is_deterministic_and_uuid_shaped(self) -> None:
        import uuid as _uuid
        a = SequentialIdFactory(namespace=0x00000001)
        b = SequentialIdFactory(namespace=0x00000001)
        ids_a = [a.new_id() for _ in range(3)]
        ids_b = [b.new_id() for _ in range(3)]
        self.assertEqual(ids_a, ids_b)  # deterministic
        self.assertEqual(ids_a[0], "00000001-0000-4000-8000-000000000001")
        for i in ids_a:
            self.assertEqual(str(_uuid.UUID(i)), i)  # valid uuid string

    def test_sequential_namespaces_do_not_collide(self) -> None:
        a = SequentialIdFactory(namespace=0x0000000a)
        b = SequentialIdFactory(namespace=0x0000000b)
        self.assertTrue(set(a.new_id() for _ in range(5)).isdisjoint(b.new_id() for _ in range(5)))

    def test_uuid_factory_is_random_and_valid(self) -> None:
        import uuid as _uuid
        f = UuidIdFactory()
        v1, v2 = f.new_id(), f.new_id()
        self.assertNotEqual(v1, v2)
        self.assertEqual(str(_uuid.UUID(v1)), v1)


# ---------------------------------------------------------------------------
# Compute manifest + provenance bridge + snapshot metadata.
# ---------------------------------------------------------------------------
# Full determinant set (the 11 keys the manifest must incorporate).
_MANIFEST_KW = dict(
    manifest_format_version="mfv", engine_name="eng", engine_version="ev",
    pipeline_version="pv", resolver_version="rv", rule_version="rul", rule_hash="rh",
    rubric_version="rbv", rubric_hash="rbh", opportunity_version="ov", opportunity_hash="oh",
)

# GOLDEN FIXTURE — the DERIVED default compute manifest, pinned so ANY drift in a determinant,
# a source-of-truth value, the determinant SET, or the canonical serialization is caught
# fail-closed by CI. This is NOT a source the code reads: `default_compute_manifest()` derives
# the value from the real sources of truth (PIPELINE_VERSION, RESOLVER_VERSION, the DEFAULT
# config objects) and the test only COMPARES that derivation to this constant. It is the
# manifest-provenance analogue of `test_repro_harness.GOLDEN_DIGEST`. Retired lineage (the
# GREEN-but-insufficient 8-key manifest at SHA 3cc4d3d) was 6450b692…f89937; adding the
# manifest-format-version + engine-identity determinants necessarily flipped it (DEC-0025 §6).
_DEFAULT_MANIFEST_GOLDEN = "57cb27f4339b8b702675d7f17f65905da7ba1d04bbd33a09b62704e8104f0404"


class ComputeManifestTests(unittest.TestCase):
    def test_canonical_manifest_is_deterministic_and_64hex(self) -> None:
        a = canonical_compute_manifest(**_MANIFEST_KW)
        b = canonical_compute_manifest(**_MANIFEST_KW)
        self.assertEqual(a, b)  # same determinants ⇒ same hash
        self.assertRegex(a, r"^[0-9a-f]{64}$")

    def test_changing_any_single_determinant_flips_the_hash(self) -> None:
        base = canonical_compute_manifest(**_MANIFEST_KW)
        for key in _MANIFEST_KW:
            changed = canonical_compute_manifest(**{**_MANIFEST_KW, key: _MANIFEST_KW[key] + "-x"})
            self.assertNotEqual(base, changed, f"determinant {key} did not affect the hash")

    def test_key_order_does_not_change_the_hash(self) -> None:
        # Independently recompute over the SAME determinants but a REVERSED dict order:
        # canonical serialization sorts keys, so the hash must be identical.
        manifest = {
            "manifest_format_version": _MANIFEST_KW["manifest_format_version"],
            "engine_name": _MANIFEST_KW["engine_name"],
            "engine_version": _MANIFEST_KW["engine_version"],
            "pipeline_version": _MANIFEST_KW["pipeline_version"],
            "resolver_version": _MANIFEST_KW["resolver_version"],
            "rule_version": _MANIFEST_KW["rule_version"],
            "rule_hash": _MANIFEST_KW["rule_hash"],
            "rubric_version": _MANIFEST_KW["rubric_version"],
            "rubric_hash": _MANIFEST_KW["rubric_hash"],
            "opportunity_version": _MANIFEST_KW["opportunity_version"],
            "opportunity_hash": _MANIFEST_KW["opportunity_hash"],
        }
        reversed_order = dict(reversed(list(manifest.items())))
        independent = hashlib.sha256(
            json.dumps(reversed_order, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        ).hexdigest()
        self.assertEqual(canonical_compute_manifest(**_MANIFEST_KW), independent)

    def test_default_manifest_is_derived_from_the_real_sources_of_truth(self) -> None:
        # Recompute independently from the SAME sources of truth the builder reads — proving
        # the value is DERIVED (not a hardcoded constant) and matches byte-for-byte.
        independent = canonical_compute_manifest(
            manifest_format_version=COMPUTE_MANIFEST_FORMAT_VERSION,
            engine_name=COMPUTE_ENGINE_NAME,
            engine_version=PIPELINE_VERSION,
            pipeline_version=PIPELINE_VERSION,
            resolver_version=RESOLVER_VERSION,
            rule_version=CHANNEL_FILTER_DEFAULT_CONFIG.rule_version,
            rule_hash=CHANNEL_FILTER_DEFAULT_CONFIG.rule_hash,
            rubric_version=DEFAULT_RUBRIC.rubric_version,
            rubric_hash=DEFAULT_RUBRIC.rubric_hash,
            opportunity_version=OPPORTUNITY_DEFAULT_CONFIG.opportunity_version,
            opportunity_hash=OPPORTUNITY_DEFAULT_CONFIG.opportunity_hash,
        )
        self.assertEqual(default_compute_manifest(), independent)
        self.assertRegex(default_compute_manifest(), r"^[0-9a-f]{64}$")

    def test_default_manifest_matches_pinned_golden_fixture(self) -> None:
        # The derived value is COMPARED to the pinned golden — never fed from it. Any change to
        # a determinant / source of truth / determinant set / serialization flips this and fails
        # CI, forcing a conscious, reviewed golden bump (no silent drift, no manual copy).
        self.assertEqual(default_compute_manifest(), _DEFAULT_MANIFEST_GOLDEN)

    def test_default_manifest_is_sensitive_to_a_default_determinant(self) -> None:
        # Swapping the REAL rubric hash for a different value flips the default lineage hash.
        base = default_compute_manifest()
        drifted = canonical_compute_manifest(
            manifest_format_version=COMPUTE_MANIFEST_FORMAT_VERSION,
            engine_name=COMPUTE_ENGINE_NAME,
            engine_version=PIPELINE_VERSION,
            pipeline_version=PIPELINE_VERSION,
            resolver_version=RESOLVER_VERSION,
            rule_version=CHANNEL_FILTER_DEFAULT_CONFIG.rule_version,
            rule_hash=CHANNEL_FILTER_DEFAULT_CONFIG.rule_hash,
            rubric_version=DEFAULT_RUBRIC.rubric_version,
            rubric_hash=DEFAULT_RUBRIC.rubric_hash + "-drift",
            opportunity_version=OPPORTUNITY_DEFAULT_CONFIG.opportunity_version,
            opportunity_hash=OPPORTUNITY_DEFAULT_CONFIG.opportunity_hash,
        )
        self.assertNotEqual(base, drifted)

    def test_no_hardcoded_manifest_constant_in_coordinator_source(self) -> None:
        # No silent fallback to an old constant: the coordinator source contains no 64-hex
        # literal — the manifest is always derived from the sources of truth.
        src = inspect.getsource(coord_mod)
        self.assertIsNone(
            re.search(r"(?<![0-9a-f])[0-9a-f]{64}(?![0-9a-f])", src),
            "a 64-hex literal (a hardcoded manifest?) is present in the coordinator source",
        )

    def test_build_compute_provenance_is_deterministic_engine_identity(self) -> None:
        prov = build_compute_provenance()
        self.assertIsInstance(prov, Sg8ComputeProvenance)
        self.assertEqual(prov.engine_name, COMPUTE_ENGINE_NAME)
        self.assertEqual(prov.engine_version, PIPELINE_VERSION)
        self.assertEqual(prov.manifest_hash, default_compute_manifest())
        # only computational identity: no persistence adapter, no params, no provider/model/prompt
        for forbidden in ("adapter_version", "params", "provider", "model", "model_version", "prompt_hash"):
            self.assertFalse(hasattr(prov, forbidden), f"residual non-computational field: {forbidden}")

    def test_build_compute_provenance_accepts_explicit_manifest(self) -> None:
        mh = "a" * 64  # valid format
        prov = build_compute_provenance(manifest_hash=mh)
        self.assertEqual(prov.manifest_hash, mh)


class SnapshotMetadataTests(unittest.TestCase):
    def test_snapshot_metadata_is_deterministic(self) -> None:
        s = _session(with_ambiguous=True)
        m1 = derive_snapshot_metadata(s._input, resolver_version=RESOLVER_VERSION)  # type: ignore[attr-defined]
        m2 = derive_snapshot_metadata(s._input, resolver_version=RESOLVER_VERSION)  # type: ignore[attr-defined]
        self.assertEqual(m1, m2)
        self.assertEqual(m1["fact_count"], 5 + 4)  # report1 (4 regex + 1 ambiguous) + report2 (4 regex)
        self.assertRegex(str(m1["content_hash"]), r"^[0-9a-f]{64}$")
        self.assertRegex(str(m1["resolver_hash"]), r"^[0-9a-f]{64}$")


# ---------------------------------------------------------------------------
# Coordinator mirror (no second FSM).
# ---------------------------------------------------------------------------
class CoordinatorMirrorTests(unittest.TestCase):
    def test_happy_path_with_review_mirrors_full_sequence(self) -> None:
        store = _RecStore()
        session = _session(with_ambiguous=True)
        coord = Sg8Coordinator(session, store, SequentialIdFactory(namespace=1), source_collection_run_id="src-run-1")
        _drive_to_passed(coord, session)
        self.assertEqual(
            store.names(),
            [
                "open_session", "mark_awaiting_review", "mark_resolved", "freeze_snapshot",
                "bind_reports", "append_round", "append_evidence", "append_evidence",
                "append_round", "append_evidence", "append_evidence", "mark_passed",
            ],
        )

    def test_no_ambiguity_path_skips_awaiting_review(self) -> None:
        store = _RecStore()
        session = _session(with_ambiguous=False)
        coord = Sg8Coordinator(session, store, SequentialIdFactory(namespace=2), source_collection_run_id="src-run-1")
        state = coord.resolve_round1()
        self.assertIs(state, Sg8State.R1_RESOLVED)
        self.assertEqual(store.names(), ["mark_resolved"])
        self.assertNotIn("mark_awaiting_review", store.names())

    def test_both_rounds_persist_identical_compute_provenance(self) -> None:
        store = _RecStore()
        session = _session(with_ambiguous=True)
        coord = Sg8Coordinator(session, store, SequentialIdFactory(namespace=3), source_collection_run_id="src-run-1")
        _drive_to_passed(coord, session)
        rounds = [c for c in store.calls if c[0] == "append_round"]
        self.assertEqual([r[1] for r in rounds], [1, 2])          # round_number order
        self.assertIsNotNone(rounds[0][2])                        # R1 provenance present
        self.assertIsNotNone(rounds[1][2])                        # R2 provenance present (DEC-0025)
        # both rounds carry the SAME deterministic manifest (PASS gate equality by construction)
        self.assertEqual(rounds[0][2].manifest_hash, rounds[1][2].manifest_hash)
        self.assertIs(rounds[0][2], rounds[1][2])                 # the identical provenance object

    def test_exactly_two_evidence_per_round(self) -> None:
        store = _RecStore()
        session = _session(with_ambiguous=True)
        coord = Sg8Coordinator(session, store, SequentialIdFactory(namespace=4), source_collection_run_id="src-run-1")
        _drive_to_passed(coord, session)
        r1 = coord.round_execution_id(1)
        r2 = coord.round_execution_id(2)
        ev = [c for c in store.calls if c[0] == "append_evidence"]
        self.assertEqual(sum(1 for c in ev if c[1] == r1), 2)
        self.assertEqual(sum(1 for c in ev if c[1] == r2), 2)
        self.assertNotEqual(r1, r2)  # distinct round_execution_ids

    def test_ids_are_application_owned_and_stable(self) -> None:
        store = _RecStore()
        session = _session(with_ambiguous=True)
        coord = Sg8Coordinator(session, store, SequentialIdFactory(namespace=7), source_collection_run_id="src-run-1")
        _drive_to_passed(coord, session)
        # snapshot id then r1 then r2, from the injected deterministic factory
        self.assertEqual(coord.resolution_snapshot_id, "00000007-0000-4000-8000-000000000001")
        self.assertEqual(coord.round_execution_id(1), "00000007-0000-4000-8000-000000000002")
        self.assertEqual(coord.round_execution_id(2), "00000007-0000-4000-8000-000000000003")

    def test_coordinator_does_not_reimplement_fsm_or_recompute(self) -> None:
        # The mirror never re-decides a transition nor recomputes a digest/score: it must
        # not call the runner's state guard, the pipeline, or the evidence comparator.
        import inspect
        src = inspect.getsource(Sg8Coordinator)
        for forbidden in ("_require_state(", "pipeline_digest(", "run_pipeline(", "compare_round_evidence("):
            self.assertNotIn(forbidden, src)

    def test_coordinator_module_is_driver_free(self) -> None:
        # The wiring layer is core code: it must import NO database driver (AST, not substring).
        import ast
        import inspect
        from noxund_data_engine import sg8_coordinator
        roots: set[str] = set()
        for node in ast.walk(ast.parse(inspect.getsource(sg8_coordinator))):
            if isinstance(node, ast.Import):
                roots.update(a.name.split(".", 1)[0] for a in node.names)
            elif isinstance(node, ast.ImportFrom) and not node.level and node.module:
                roots.add(node.module.split(".", 1)[0])
        for driver in ("psycopg", "psycopg2", "asyncpg", "sqlalchemy", "pg8000"):
            self.assertNotIn(driver, roots)


def _runner_to_computed():
    session = _session(with_ambiguous=True)
    session.resolve_round1()
    if session.state is Sg8State.R1_AWAITING_REVIEW:
        session.submit_review([ReviewDecision(rid, vid, approved=True, artist_id="artist-zephyr")
                               for (rid, vid) in session.pending_review_keys])
    session.freeze_snapshot(resolution_snapshot_id="snap-1")
    r1 = session.compute_round1(round_execution_id="r1-exec")
    return session, r1


# ---------------------------------------------------------------------------
# Round 2 evidence has its OWN origin (never a Round-1 copy) — computed once.
# ---------------------------------------------------------------------------
class Round2EvidenceOriginTests(unittest.TestCase):
    def test_runner_exposes_real_round2_evidence_distinct_from_round1(self) -> None:
        session, r1 = _runner_to_computed()
        result = session.run_round2_result(round_execution_id="r2-exec")
        self.assertTrue(result.verdict.passed)
        self.assertIsNotNone(result.evidence)
        # Round 2 carries its OWN round_execution_id (distinct origin from Round 1)...
        self.assertEqual(result.evidence.round_execution_id, "r2-exec")
        self.assertNotEqual(result.evidence.round_execution_id, r1.round_execution_id)
        self.assertIsNot(result.evidence, r1)                       # distinct object, not a copy
        # ...over the same two reports, with equal VALUES (byte-for-byte determinism).
        self.assertEqual(set(result.evidence.report_digests), set(r1.report_digests))
        self.assertEqual(result.evidence.report_digests, r1.report_digests)

    def test_round2_compute_runs_once_second_call_blocked_by_terminal(self) -> None:
        session, _ = _runner_to_computed()
        session.run_round2_result(round_execution_id="r2-exec")           # computes once -> terminal
        with self.assertRaises(Sg8TerminalSessionError):
            session.run_round2_result(round_execution_id="r2-exec-again")  # cannot recompute

    def test_coordinator_persists_round2_own_evidence_not_round1_copy(self) -> None:
        store = _RecStore()
        session = _session(with_ambiguous=True)
        coord = Sg8Coordinator(session, store, SequentialIdFactory(namespace=8), source_collection_run_id="src-run-1")
        coord.open_session()
        if coord.resolve_round1() is Sg8State.R1_AWAITING_REVIEW:
            coord.submit_review([ReviewDecision(rid, vid, approved=True, artist_id="artist-zephyr")
                                 for (rid, vid) in session.pending_review_keys])
        coord.freeze(snapshot_metadata=derive_snapshot_metadata(session._input, resolver_version=RESOLVER_VERSION))  # type: ignore[attr-defined]
        r1_evidence = coord.compute_round1(provenance=build_compute_provenance(), report_run_id_1="report-1of2", report_run_id_2="report-2of2")
        coord.run_round2()

        r2 = coord.round2_evidence
        self.assertIsNotNone(r2)
        self.assertEqual(r2.round_execution_id, coord.round_execution_id(2))   # R2's own id
        self.assertNotEqual(r2.round_execution_id, r1_evidence.round_execution_id)
        self.assertIsNot(r2, r1_evidence)                                      # not a Round-1 copy
        # exactly the digests Round 2 produced were persisted for round_number = 2
        r2_id = coord.round_execution_id(2)
        persisted = {c[2]: c[3] for c in store.calls if c[0] == "append_evidence" and c[1] == r2_id}
        self.assertEqual(persisted, dict(r2.report_digests))


if __name__ == "__main__":
    unittest.main()
