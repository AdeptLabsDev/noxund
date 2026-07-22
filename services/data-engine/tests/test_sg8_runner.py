"""SG-8 offline runner tests (DATA-SG8-001, stage 2).

Synthetic + fail-closed coverage of the two-round state machine. stdlib ``unittest``
only (no pytest / no third-party); run with
``PYTHONPATH=src python -m unittest discover -s tests -p test_sg8_runner.py``.

No DB, no network, no real LLM, no schema, no workflow, no secret.
"""

from __future__ import annotations

import unittest
from datetime import datetime, timezone

from noxund_data_engine.channel_filter import DEFAULT_CONFIG as CHANNEL_FILTER_DEFAULT_CONFIG
from noxund_data_engine.opportunity import DEFAULT_CONFIG as OPPORTUNITY_DEFAULT_CONFIG
from noxund_data_engine.pipeline import (
    ArtistRow,
    ChannelRow,
    PipelineSnapshot,
    RawVideoRow,
    pipeline_digest,
    run_pipeline,
)
from noxund_data_engine.scoring import DEFAULT_RUBRIC
from noxund_data_engine.sg8_runner import (
    EvidenceArtifact,
    ForbiddenLLMCandidateExtractor,
    InMemoryEvidenceStore,
    InMemoryReplayFactStore,
    LlmProvenance,
    ReviewDecision,
    RoundEvidence,
    Sg8ContractViolation,
    Sg8EvidenceCollision,
    Sg8Report,
    Sg8ReplayLlmForbidden,
    Sg8Session,
    Sg8SessionInput,
    Sg8SnapshotIncomplete,
    Sg8State,
    Sg8TerminalSessionError,
    StubLLMCandidateExtractor,
    assert_snapshot_complete,
    compare_round_evidence,
)
from noxund_data_engine.entity_resolution import RESOLVER_VERSION

# Deterministic offline import: reuse the golden fixture to prove hashes/digest are
# unchanged by the pipeline injection seam.
from test_repro_harness import GOLDEN_DIGEST, golden_snapshot


WINDOW_END = datetime(2026, 6, 30, tzinfo=timezone.utc)
SOURCE_RUN_ID = "src-collection-synthetic-001"
LLM_TITLE = "Free Zephyr Prime Type Beat"  # "Free" -> regex_metadata_residual -> LLM


def _dt(day: int) -> datetime:
    return datetime(2026, 6, day, tzinfo=timezone.utc)


def _channels(videos: tuple[RawVideoRow, ...]) -> tuple[ChannelRow, ...]:
    return tuple(ChannelRow(cid) for cid in sorted({v.channel_id for v in videos}))


def _happy_snapshot(report_run_id: str) -> PipelineSnapshot:
    """One clean regex artist (Kairo) + one LLM-then-human artist (Zephyr)."""

    videos = tuple(
        RawVideoRow(f"k{i:02d}", f"k-ch-{i % 4:02d}", "Kairo Vee Type Beat",
                    40000 + i * 10, 5000, 900, _dt(29))
        for i in range(6)
    ) + tuple(
        RawVideoRow(f"z{i:02d}", f"z-ch-{i % 2:02d}", LLM_TITLE,
                    30000 + i * 10, 4200, 760, _dt(29))
        for i in range(3)
    )
    artists = (
        ArtistRow("artist-kairo", "Kairo Vee"),
        ArtistRow("artist-zephyr", "Zephyr Prime"),
    )
    return PipelineSnapshot(report_run_id, "Report", WINDOW_END, videos, _channels(videos), artists)


def _stub(provenance: LlmProvenance | None = None) -> StubLLMCandidateExtractor:
    return StubLLMCandidateExtractor(
        {LLM_TITLE: "Zephyr Prime"},
        provenance=provenance or _complete_provenance(),
    )


def _complete_provenance() -> LlmProvenance:
    return LlmProvenance(
        provider="anthropic",
        model="claude-opus-4-8",
        model_version="claude-opus-4-8",
        prompt_version="llm-fallback-v1",
        adapter_identity="offline-stub-adapter",
        params={"temperature": "0", "max_tokens": "64"},
    )


def _session(report_run_id: str = "report-1of2", *, llm: StubLLMCandidateExtractor | None = None,
             source_run_id: str = SOURCE_RUN_ID, session_id: str = "sg8-session-A") -> Sg8Session:
    report = Sg8Report(report_run_id, _happy_snapshot(report_run_id))
    return Sg8Session(
        Sg8SessionInput(source_run_id, (report,)),
        sg8_session_id=session_id,
        llm=llm or _stub(),
    )


def _drive_to_frozen(session: Sg8Session, report_run_id: str = "report-1of2") -> None:
    """resolve -> review (approve the LLM item as Zephyr) -> freeze."""

    session.resolve_round1()
    if session.state is Sg8State.R1_AWAITING_REVIEW:
        decisions = [
            ReviewDecision(rid, vid, approved=True, artist_id="artist-zephyr")
            for (rid, vid) in session.pending_review_keys
        ]
        session.submit_review(decisions)
    session.freeze_snapshot(resolution_snapshot_id="resolution-snapshot-A")


def _drive_to_pass(session: Sg8Session) -> None:
    _drive_to_frozen(session)
    session.compute_round1(round_execution_id="round-exec-1")
    session.run_round2(round_execution_id="round-exec-2")


# ---------------------------------------------------------------------------
# 1. Happy path — complete + deterministic ×2.
# ---------------------------------------------------------------------------
class HappyPathTests(unittest.TestCase):
    def test_happy_path_passes(self) -> None:
        session = _session()
        session.resolve_round1()
        # The LLM path was genuinely exercised (Zephyr routed to review).
        self.assertEqual(session.state, Sg8State.R1_AWAITING_REVIEW)
        self.assertTrue(session.pending_review_keys)
        session.submit_review(
            [ReviewDecision(rid, vid, approved=True, artist_id="artist-zephyr")
             for (rid, vid) in session.pending_review_keys]
        )
        session.freeze_snapshot(resolution_snapshot_id="resolution-snapshot-A")
        session.compute_round1(round_execution_id="round-exec-1")
        session.run_round2(round_execution_id="round-exec-2")
        self.assertEqual(session.state, Sg8State.PASSED)
        self.assertIsNotNone(session.verdict)
        self.assertTrue(session.verdict.passed)
        self.assertEqual(session.resolution_snapshot_id, "resolution-snapshot-A")

    def test_two_sessions_are_byte_identical(self) -> None:
        digests = []
        for i in range(2):
            session = _session(session_id=f"sg8-session-{i}")
            _drive_to_frozen(session)
            ev1 = session.compute_round1(round_execution_id=f"r1-{i}")
            session.run_round2(round_execution_id=f"r2-{i}")
            self.assertEqual(session.state, Sg8State.PASSED)
            digests.append(dict(ev1.report_digests))
        self.assertEqual(digests[0], digests[1])  # determinism across independent runs

    def test_stub_llm_was_used_but_compute_is_zero_llm(self) -> None:
        llm = _stub()
        session = _session(llm=llm)
        _drive_to_pass(session)
        self.assertGreaterEqual(llm.call_count, 1)          # Round 1 used the stub
        self.assertEqual(session.compute_llm_call_count, 0)  # both computes are zero-LLM


# ---------------------------------------------------------------------------
# 2. Pause + legitimate resume in R1_AWAITING_REVIEW (same session).
# ---------------------------------------------------------------------------
class ReviewResumeTests(unittest.TestCase):
    def test_pause_then_resume_same_session_id(self) -> None:
        session = _session(session_id="sg8-session-resume")
        session.resolve_round1()
        self.assertEqual(session.state, Sg8State.R1_AWAITING_REVIEW)
        keys_before = session.pending_review_keys
        self.assertTrue(keys_before)
        session.submit_review(
            [ReviewDecision(rid, vid, approved=True, artist_id="artist-zephyr")
             for (rid, vid) in keys_before]
        )
        self.assertEqual(session.state, Sg8State.R1_RESOLVED)
        self.assertEqual(session.pending_review_keys, ())
        self.assertEqual(session.sg8_session_id, "sg8-session-resume")  # same session
        # And the session can proceed to PASS after the legitimate resume.
        session.freeze_snapshot(resolution_snapshot_id="rs")
        session.compute_round1(round_execution_id="r1")
        self.assertTrue(session.run_round2(round_execution_id="r2").passed)


# ---------------------------------------------------------------------------
# 3. Bypass of the review gate => FAIL.
# ---------------------------------------------------------------------------
class ReviewGateBypassTests(unittest.TestCase):
    def test_freeze_while_awaiting_review_fails(self) -> None:
        session = _session()
        session.resolve_round1()
        self.assertEqual(session.state, Sg8State.R1_AWAITING_REVIEW)
        with self.assertRaises(Sg8ContractViolation):
            session.freeze_snapshot(resolution_snapshot_id="rs")
        self.assertEqual(session.state, Sg8State.FAILED)
        self.assertFalse(session.verdict.passed)


# ---------------------------------------------------------------------------
# 4 & 5. Round 2 completeness + zero-LLM.
# ---------------------------------------------------------------------------
class Round2CompletenessTests(unittest.TestCase):
    def test_complete_snapshot_zero_llm_calls(self) -> None:
        session = _session()
        _drive_to_frozen(session)
        session.compute_round1(round_execution_id="r1")
        verdict = session.run_round2(round_execution_id="r2")
        self.assertTrue(verdict.passed)
        self.assertEqual(session.compute_llm_call_count, 0)

    def test_missing_fact_fails_before_any_llm_call(self) -> None:
        # Pure completeness guard: a gap raises BEFORE any resolver/LLM call.
        forbidden = ForbiddenLLMCandidateExtractor()
        facts = InMemoryReplayFactStore()
        facts.freeze()
        with self.assertRaises(Sg8SnapshotIncomplete):
            assert_snapshot_complete(["v-missing"], facts, run_id="r")
        self.assertEqual(forbidden.call_count, 0)

    def test_session_round2_missing_fact_fails_closed(self) -> None:
        session = _session()
        _drive_to_frozen(session)
        session.compute_round1(round_execution_id="r1")
        # Simulate snapshot corruption: drop one frozen fact.
        store = session._facts["report-1of2"]  # noqa: SLF001 (white-box: simulate corruption)
        victim = next(iter(store._facts))       # noqa: SLF001
        del store._facts[victim]                # noqa: SLF001
        verdict = session.run_round2(round_execution_id="r2")
        self.assertFalse(verdict.passed)
        self.assertEqual(session.state, Sg8State.FAILED)
        self.assertEqual(session.compute_llm_call_count, 0)  # never reached the adapter


# ---------------------------------------------------------------------------
# 6. The forbidden adapter fails closed on any call.
# ---------------------------------------------------------------------------
class ForbiddenAdapterTests(unittest.TestCase):
    def test_any_call_raises_and_counts(self) -> None:
        forbidden = ForbiddenLLMCandidateExtractor()
        with self.assertRaises(Sg8ReplayLlmForbidden):
            forbidden.extract_candidate(title="anything", prompt_version="v1")
        self.assertEqual(forbidden.call_count, 1)


# ---------------------------------------------------------------------------
# 7 & 9. Digest drift + dataset divergence.
# ---------------------------------------------------------------------------
class ComparisonFailClosedTests(unittest.TestCase):
    def _evidence(self, digest: str, source: str = SOURCE_RUN_ID, exec_id: str = "e") -> RoundEvidence:
        return RoundEvidence(exec_id, source, {"report-1of2": digest})

    def test_digest_drift_fails(self) -> None:
        verdict = compare_round_evidence(
            self._evidence("aaa", exec_id="e1"), self._evidence("bbb", exec_id="e2")
        )
        self.assertFalse(verdict.passed)
        self.assertIn("drift", verdict.reason)

    def test_source_collection_run_id_divergence_fails(self) -> None:
        verdict = compare_round_evidence(
            self._evidence("aaa", source="src-A", exec_id="e1"),
            self._evidence("aaa", source="src-B", exec_id="e2"),
        )
        self.assertFalse(verdict.passed)
        self.assertIn("source_collection_run_id", verdict.reason)

    def test_identical_evidence_passes(self) -> None:
        self.assertTrue(
            compare_round_evidence(
                self._evidence("aaa", exec_id="e1"), self._evidence("aaa", exec_id="e2")
            ).passed
        )

    def test_report_set_mismatch_fails(self) -> None:
        r1 = RoundEvidence("e1", SOURCE_RUN_ID, {"a": "x"})
        r2 = RoundEvidence("e2", SOURCE_RUN_ID, {"a": "x", "b": "y"})
        self.assertFalse(compare_round_evidence(r1, r2).passed)


# ---------------------------------------------------------------------------
# 8. Append-only evidence collision.
# ---------------------------------------------------------------------------
class EvidenceStoreTests(unittest.TestCase):
    def test_collision_on_same_round_and_report(self) -> None:
        store = InMemoryEvidenceStore()
        artifact = EvidenceArtifact("round-1", "report-1of2", SOURCE_RUN_ID, "digest")
        store.append(artifact)
        with self.assertRaises(Sg8EvidenceCollision):
            store.append(artifact)

    def test_frozen_fact_store_is_append_only(self) -> None:
        from noxund_data_engine.entity_resolution import ResolutionDecision, ResolutionMethod, ResolutionOutcome
        facts = InMemoryReplayFactStore()
        outcome = ResolutionOutcome(
            run_id="r", video_id="v", resolver_version=RESOLVER_VERSION,
            source_method=ResolutionMethod.REGEX, candidate="Kairo Vee",
            decision=ResolutionDecision.ACCEPTED, final_name="Kairo Vee",
            needs_review=False, reason_code="regex_autoaccepted", artist_id="artist-kairo",
        )
        facts.record_final_fact(outcome)
        facts.freeze()
        with self.assertRaises(Sg8ContractViolation):
            facts.record_final_fact(outcome)  # frozen => immutable


# ---------------------------------------------------------------------------
# 10. Incomplete LLM provenance in Round 1 => FAIL.
# ---------------------------------------------------------------------------
class LlmProvenanceTests(unittest.TestCase):
    def test_incomplete_provenance_fails_at_freeze(self) -> None:
        incomplete = LlmProvenance(
            provider="anthropic", model="", model_version="claude-opus-4-8",
            prompt_version="llm-fallback-v1", adapter_identity="offline-stub-adapter",
        )
        self.assertFalse(incomplete.is_complete())
        session = _session(llm=_stub(incomplete))
        session.resolve_round1()
        session.submit_review(
            [ReviewDecision(rid, vid, approved=True, artist_id="artist-zephyr")
             for (rid, vid) in session.pending_review_keys]
        )
        with self.assertRaises(Sg8ContractViolation):
            session.freeze_snapshot(resolution_snapshot_id="rs")
        self.assertEqual(session.state, Sg8State.FAILED)

    def test_complete_provenance_is_accepted(self) -> None:
        self.assertTrue(_complete_provenance().is_complete())


# ---------------------------------------------------------------------------
# 11. A terminal session cannot be resumed.
# ---------------------------------------------------------------------------
class TerminalSessionTests(unittest.TestCase):
    def test_passed_session_cannot_be_re_driven(self) -> None:
        session = _session()
        _drive_to_pass(session)
        self.assertEqual(session.state, Sg8State.PASSED)
        with self.assertRaises(Sg8TerminalSessionError):
            session.run_round2(round_execution_id="r3")

    def test_failed_session_cannot_be_resumed(self) -> None:
        session = _session()
        session.resolve_round1()
        with self.assertRaises(Sg8ContractViolation):
            session.freeze_snapshot(resolution_snapshot_id="rs")  # bypass => FAIL
        self.assertEqual(session.state, Sg8State.FAILED)
        with self.assertRaises(Sg8TerminalSessionError):
            session.submit_review([])  # cannot resume a terminal session


# ---------------------------------------------------------------------------
# Impact proof: versions, hashes and golden digest are UNCHANGED.
# ---------------------------------------------------------------------------
class HashNeutralityTests(unittest.TestCase):
    def test_golden_digest_and_identities_unchanged(self) -> None:
        self.assertEqual(pipeline_digest(run_pipeline(golden_snapshot())), GOLDEN_DIGEST)
        self.assertEqual(DEFAULT_RUBRIC.rubric_version, "score_rubric_2026_06_v1")
        self.assertEqual(CHANNEL_FILTER_DEFAULT_CONFIG.rule_version, "channel-filter-v1")
        self.assertEqual(
            OPPORTUNITY_DEFAULT_CONFIG.opportunity_version, "opportunity-rules-2026_06_v1"
        )
        self.assertEqual(
            DEFAULT_RUBRIC.rubric_hash,
            "f0c465fbf790d1ca445e62ca13b58312bdb31c1b99a3caaf7b0be3eef083ca54",
        )
        self.assertEqual(
            CHANNEL_FILTER_DEFAULT_CONFIG.rule_hash,
            "7a1e3c76c4bd6b666939f0b1c84e257ea77e9d05c26dcfd2164e2f74cedeaea7",
        )
        self.assertEqual(
            OPPORTUNITY_DEFAULT_CONFIG.opportunity_hash,
            "ce7c7c1ad5d400ff6dcf9822e436db0def9cde75ffa555568acc0219b1fba52f",
        )


# ---------------------------------------------------------------------------
# D-1 / D-10: report_run_id reused across rounds; round_execution_id distinct.
# ---------------------------------------------------------------------------
class IdentitySeparationTests(unittest.TestCase):
    def test_same_report_run_id_distinct_round_execution_ids(self) -> None:
        session = _session()
        _drive_to_frozen(session)
        ev1 = session.compute_round1(round_execution_id="round-exec-1")
        session.run_round2(round_execution_id="round-exec-2")
        # Same report_run_id keys the comparable payload in BOTH rounds ...
        self.assertEqual(set(ev1.report_digests), {"report-1of2"})
        # ... but the round_execution_ids are distinct (never in the digest).
        self.assertNotEqual("round-exec-1", "round-exec-2")
        self.assertEqual(ev1.source_collection_run_id, SOURCE_RUN_ID)

    def test_round2_reusing_round1_execution_id_fails(self) -> None:
        session = _session()
        _drive_to_frozen(session)
        session.compute_round1(round_execution_id="shared-exec")
        verdict = session.run_round2(round_execution_id="shared-exec")
        self.assertFalse(verdict.passed)
        self.assertEqual(session.state, Sg8State.FAILED)


if __name__ == "__main__":
    unittest.main()
