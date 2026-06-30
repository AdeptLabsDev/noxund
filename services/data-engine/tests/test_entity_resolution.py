from __future__ import annotations

import json
import logging
import unittest
from typing import Any, Sequence

from noxund_data_engine.entity_resolution import (
    CandidateStatus,
    ContractViolation,
    EntityResolver,
    PendingCandidate,
    PROMPT_VERSION,
    RESOLVER_VERSION,
    RawVideo,
    ResolutionDecision,
    ResolutionMethod,
    ResolutionOutcome,
    candidate_is_supported,
    normalize_for_match,
)
from noxund_data_engine.postgres_entity_resolution import (
    CandidatePersistenceError,
    PostgresAuditReplayFacts,
    PostgresCandidateQueue,
)


RUN_ID = "00000000-0000-0000-0000-000000000001"


class FakeCatalog:
    def __init__(self, matches: dict[str, Sequence[str]] | None = None) -> None:
        self.matches = matches or {}

    def find_artist_ids(self, normalized_name: str) -> Sequence[str]:
        return self.matches.get(normalized_name, ())


class FakeLLM:
    def __init__(
        self, *outputs: str, secret: str = "CANARY-SECRET-DO-NOT-SERIALIZE"
    ) -> None:
        self.outputs = list(outputs)
        self.calls = 0
        self.secret = secret

    def extract_candidate(self, *, title: str, prompt_version: str) -> str:
        self.calls += 1
        if prompt_version != PROMPT_VERSION:
            raise AssertionError("unexpected prompt version")
        return self.outputs.pop(0)


class MemoryState:
    def __init__(self) -> None:
        self.pending: dict[tuple[str, str], PendingCandidate] = {}
        self.final: dict[tuple[str, str, str], ResolutionOutcome] = {}
        self.rejected_facts: list[ResolutionOutcome] = []

    def get_pending(self, run_id: str, video_id: str) -> PendingCandidate | None:
        return self.pending.get((run_id, video_id))

    def enqueue_pending(self, candidate: PendingCandidate) -> PendingCandidate:
        key = (candidate.run_id, candidate.video_id)
        return self.pending.setdefault(key, candidate)

    def get_final_fact(
        self, run_id: str, video_id: str, resolver_version: str
    ) -> ResolutionOutcome | None:
        return self.final.get((run_id, video_id, resolver_version))

    def record_rejected_fact(self, outcome: ResolutionOutcome) -> None:
        self.rejected_facts.append(outcome)
        self.final[(outcome.run_id, outcome.video_id, outcome.resolver_version)] = outcome


def make_resolver(
    *,
    llm: FakeLLM | None = None,
    state: MemoryState | None = None,
    catalog: FakeCatalog | None = None,
    resolver_version: str = RESOLVER_VERSION,
    prompt_version: str = PROMPT_VERSION,
) -> tuple[EntityResolver, MemoryState]:
    state = state or MemoryState()
    return (
        EntityResolver(
            catalog=catalog or FakeCatalog(),
            queue=state,
            replay_facts=state,
            llm=llm,
            resolver_version=resolver_version,
            prompt_version=prompt_version,
        ),
        state,
    )


class EntityResolutionTests(unittest.TestCase):
    def test_normalization_and_contiguous_token_guard(self) -> None:
        self.assertEqual(normalize_for_match("  KAIRO—Vée  "), "kairo vée")
        self.assertTrue(candidate_is_supported("Kairo Vée", "FREE | Kairo—Vée Type Beat"))
        self.assertFalse(candidate_is_supported("Kairo V", "Kairo Vée Type Beat"))
        self.assertFalse(candidate_is_supported("Outside", "Kairo Vée Type Beat"))

    def test_regex_autoaccepts_one_supported_candidate_without_llm(self) -> None:
        llm = FakeLLM('{"candidate":"must not run"}')
        resolver, state = make_resolver(llm=llm)
        outcome = resolver.resolve(RawVideo(RUN_ID, "v1", "Kairo Vee Type Beat [FREE]"))

        self.assertEqual(outcome.decision, ResolutionDecision.ACCEPTED)
        self.assertEqual(outcome.source_method, ResolutionMethod.REGEX)
        self.assertEqual(outcome.final_name, "Kairo Vee")
        self.assertFalse(outcome.needs_review)
        self.assertEqual(llm.calls, 0)
        self.assertEqual(state.pending, {})

    def test_regex_reuses_one_canonical_artist_match(self) -> None:
        catalog = FakeCatalog({"kairo vee": ("artist-1",)})
        resolver, _ = make_resolver(catalog=catalog)
        outcome = resolver.resolve(RawVideo(RUN_ID, "v1", "Kairo Vee Type Beat"))
        self.assertEqual(outcome.artist_id, "artist-1")

    def test_ambiguous_regex_uses_llm_and_enqueues_pending_candidate(self) -> None:
        llm = FakeLLM('{"candidate":"Kairo Vee"}')
        resolver, state = make_resolver(llm=llm)
        video = RawVideo(RUN_ID, "v1", "Kairo Vee x L5 Type Beat")

        outcome = resolver.resolve(video)

        self.assertEqual(outcome.decision, ResolutionDecision.REVIEW_REQUIRED)
        self.assertEqual(outcome.source_method, ResolutionMethod.LLM_ASSISTED)
        self.assertEqual(outcome.candidate, "Kairo Vee")
        self.assertTrue(outcome.needs_review)
        self.assertEqual(llm.calls, 1)
        pending = state.pending[(RUN_ID, "v1")]
        self.assertEqual(pending.status, CandidateStatus.PENDING)
        self.assertEqual(pending.resolver_version, RESOLVER_VERSION)
        self.assertEqual(pending.prompt_version, PROMPT_VERSION)
        self.assertIsNone(pending.artist_id)
        self.assertIsNone(pending.review_notes)

    def test_pending_dedup_reuses_existing_row_without_second_llm_call(self) -> None:
        llm = FakeLLM('{"candidate":"Kairo Vee"}')
        resolver, state = make_resolver(llm=llm)
        video = RawVideo(RUN_ID, "v1", "Kairo Vee x L5 Type Beat")

        first = resolver.resolve(video)
        second = resolver.resolve(video)

        self.assertEqual(first.candidate, second.candidate)
        self.assertTrue(second.replayed)
        self.assertEqual(second.reason_code, "pending_candidate_reused")
        self.assertEqual(llm.calls, 1)
        self.assertEqual(len(state.pending), 1)

    def test_final_replay_fact_prevents_llm_call(self) -> None:
        state = MemoryState()
        fact = ResolutionOutcome(
            run_id=RUN_ID,
            video_id="v1",
            resolver_version=RESOLVER_VERSION,
            source_method=ResolutionMethod.HUMAN_OVERRIDE,
            candidate="Kairo Vee",
            decision=ResolutionDecision.ACCEPTED,
            final_name="Kairo Vee",
            needs_review=False,
            reason_code="mapping.human_override",
        )
        state.final[(RUN_ID, "v1", RESOLVER_VERSION)] = fact
        llm = FakeLLM('{"candidate":"must not run"}')
        resolver, _ = make_resolver(llm=llm, state=state)

        outcome = resolver.resolve(RawVideo(RUN_ID, "v1", "Kairo Vee Type Beat"))

        self.assertTrue(outcome.replayed)
        self.assertEqual(outcome.final_name, "Kairo Vee")
        self.assertEqual(llm.calls, 0)

    def test_llm_name_outside_title_is_rejected_and_replayed(self) -> None:
        llm = FakeLLM('{"candidate":"Invented Artist"}', '{"candidate":"must not run"}')
        resolver, state = make_resolver(llm=llm)
        video = RawVideo(RUN_ID, "v1", "Ambiguous production title")

        first = resolver.resolve(video)
        second = resolver.resolve(video)

        self.assertEqual(first.decision, ResolutionDecision.REJECTED)
        self.assertEqual(first.reason_code, "candidate_outside_source_title")
        self.assertEqual(len(state.rejected_facts), 1)
        self.assertTrue(second.replayed)
        self.assertEqual(llm.calls, 1)
        self.assertEqual(state.pending, {})

    def test_llm_adapter_failure_is_a_durable_rejection(self) -> None:
        llm = FakeLLM()
        resolver, state = make_resolver(llm=llm)
        video = RawVideo(RUN_ID, "v1", "Ambiguous production title")

        first = resolver.resolve(video)
        second = resolver.resolve(video)

        self.assertEqual(first.reason_code, "llm_call_failed")
        self.assertEqual(first.decision, ResolutionDecision.REJECTED)
        self.assertEqual(len(state.rejected_facts), 1)
        self.assertTrue(second.replayed)
        self.assertEqual(llm.calls, 1)

    def test_llm_contract_rejects_extra_fields_and_numeric_candidate(self) -> None:
        for output in (
            '{"candidate":"Kairo","confidence":99}',
            '{"candidate":99}',
        ):
            with self.subTest(output=output):
                resolver, state = make_resolver(llm=FakeLLM(output))
                result = resolver.resolve(RawVideo(RUN_ID, output[-4:], "Kairo audio"))
                self.assertEqual(result.decision, ResolutionDecision.REJECTED)
                self.assertEqual(result.reason_code, "llm_contract_violation")
                self.assertEqual(len(state.pending), 0)

    def test_digits_are_allowed_only_when_copied_inside_the_title_candidate(self) -> None:
        resolver, _ = make_resolver(llm=FakeLLM('{"candidate":"L5"}'))
        accepted = resolver.resolve(RawVideo(RUN_ID, "v1", "L5 official audio"))
        self.assertEqual(accepted.candidate, "L5")

        resolver, _ = make_resolver(llm=FakeLLM('{"candidate":"L5"}'))
        rejected = resolver.resolve(RawVideo(RUN_ID, "v2", "Kairo official audio"))
        self.assertEqual(rejected.decision, ResolutionDecision.REJECTED)

    def test_blank_versions_fail_before_any_persistence(self) -> None:
        invalid_versions = (
            ("", PROMPT_VERSION),
            ("   ", PROMPT_VERSION),
            (RESOLVER_VERSION, ""),
            (RESOLVER_VERSION, "   "),
        )
        for resolver_version, prompt_version in invalid_versions:
            with self.subTest(
                resolver_version=resolver_version, prompt_version=prompt_version
            ):
                with self.assertRaises(ContractViolation):
                    make_resolver(
                        resolver_version=resolver_version,
                        prompt_version=prompt_version,
                    )

    def test_canary_secret_never_reaches_candidate_write_or_logs(self) -> None:
        canary = "CANARY-SECRET-7f02"
        llm = FakeLLM('{"candidate":"Kairo Vee"}', secret=canary)
        resolver, state = make_resolver(llm=llm)
        logger = logging.getLogger("noxund_data_engine")

        with self.assertNoLogs(logger, level="DEBUG"):
            resolver.resolve(RawVideo(RUN_ID, "v1", "Kairo Vee x L5 Type Beat"))

        pending = state.pending[(RUN_ID, "v1")]
        serialized = json.dumps(
            {
                "run_id": pending.run_id,
                "video_id": pending.video_id,
                "proposed_name": pending.proposed_name,
                "resolver_version": pending.resolver_version,
                "prompt_version": pending.prompt_version,
                "review_notes": pending.review_notes,
            }
        )
        self.assertNotIn(canary, serialized)
        self.assertIsNone(pending.review_notes)

    def test_missing_title_is_deterministically_rejected_without_llm(self) -> None:
        llm = FakeLLM('{"candidate":"must not run"}')
        resolver, _ = make_resolver(llm=llm)
        result = resolver.resolve(RawVideo(RUN_ID, "v1", None))
        self.assertEqual(result.reason_code, "source_title_missing")
        self.assertEqual(llm.calls, 0)


class FakeCursor:
    def __init__(
        self,
        rows: Sequence[Sequence[Any] | None] = (),
        error: Exception | None = None,
    ) -> None:
        self.rows = list(rows)
        self.error = error
        self.executions: list[tuple[str, Sequence[Any]]] = []
        self.closed = False

    def execute(self, operation: str, parameters: Sequence[Any] = ()) -> None:
        self.executions.append((operation, parameters))
        if self.error is not None:
            raise self.error

    def fetchone(self) -> Sequence[Any] | None:
        return self.rows.pop(0) if self.rows else None

    def close(self) -> None:
        self.closed = True


class FakeConnection:
    def __init__(self, cursor: FakeCursor) -> None:
        self.fake_cursor = cursor

    def cursor(self) -> FakeCursor:
        return self.fake_cursor


def pending_row(name: str = "Kairo Vee") -> tuple[Any, ...]:
    return (
        RUN_ID,
        "v1",
        name,
        "llm_assisted",
        RESOLVER_VERSION,
        PROMPT_VERSION,
        "pending",
        None,
        None,
    )


class PostgresWriteContractTests(unittest.TestCase):
    def test_queue_insert_is_parameterized_and_never_writes_notes_or_artist(self) -> None:
        cursor = FakeCursor(rows=(pending_row(),))
        queue = PostgresCandidateQueue(FakeConnection(cursor))
        candidate = PendingCandidate(
            run_id=RUN_ID,
            video_id="v1",
            proposed_name="Kairo Vee",
            method=ResolutionMethod.LLM_ASSISTED,
            resolver_version=RESOLVER_VERSION,
            prompt_version=PROMPT_VERSION,
        )

        stored = queue.enqueue_pending(candidate)

        sql, parameters = cursor.executions[0]
        self.assertIn("on conflict (run_id, video_id) where status = 'pending'", sql)
        self.assertIn("values (%s, %s, %s, null", sql)
        self.assertIn("'pending', null", sql)
        self.assertEqual(len(parameters), 6)
        self.assertIsNone(stored.artist_id)
        self.assertIsNone(stored.review_notes)
        self.assertTrue(cursor.closed)

    def test_writer_rejects_artist_binding_and_review_notes_before_sql(self) -> None:
        for candidate in (
            PendingCandidate(
                RUN_ID,
                "v1",
                "Kairo",
                ResolutionMethod.LLM_ASSISTED,
                RESOLVER_VERSION,
                PROMPT_VERSION,
                artist_id="artist-1",
            ),
            PendingCandidate(
                RUN_ID,
                "v1",
                "Kairo",
                ResolutionMethod.LLM_ASSISTED,
                RESOLVER_VERSION,
                PROMPT_VERSION,
                review_notes="must never be automated",  # type: ignore[arg-type]
            ),
        ):
            with self.subTest(candidate=candidate):
                cursor = FakeCursor()
                queue = PostgresCandidateQueue(FakeConnection(cursor))
                with self.assertRaises(ContractViolation):
                    queue.enqueue_pending(candidate)
                self.assertEqual(cursor.executions, [])

    def test_database_error_is_sanitized(self) -> None:
        canary = "CANARY-SECRET-DB-ERROR"
        cursor = FakeCursor(error=RuntimeError(f"driver leaked {canary} Kairo Vee"))
        queue = PostgresCandidateQueue(FakeConnection(cursor))
        candidate = PendingCandidate(
            RUN_ID,
            "v1",
            "Kairo Vee",
            ResolutionMethod.LLM_ASSISTED,
            RESOLVER_VERSION,
            PROMPT_VERSION,
        )

        with self.assertRaises(CandidatePersistenceError) as raised:
            queue.enqueue_pending(candidate)

        self.assertEqual(str(raised.exception), "candidate persistence failed")
        self.assertNotIn(canary, str(raised.exception))

    def test_rejected_audit_payload_is_allowlisted(self) -> None:
        cursor = FakeCursor()
        replay = PostgresAuditReplayFacts(FakeConnection(cursor))
        outcome = ResolutionOutcome(
            run_id=RUN_ID,
            video_id="v1",
            resolver_version=RESOLVER_VERSION,
            source_method=ResolutionMethod.LLM_ASSISTED,
            candidate=None,
            decision=ResolutionDecision.REJECTED,
            final_name=None,
            needs_review=False,
            reason_code="llm_no_single_candidate",
            prompt_version=PROMPT_VERSION,
        )

        replay.record_rejected_fact(outcome)

        _, parameters = cursor.executions[0]
        payload = json.loads(str(parameters[0]))
        self.assertEqual(payload["run_id"], RUN_ID)
        self.assertEqual(payload["video_id"], "v1")
        self.assertEqual(payload["resolver_version"], RESOLVER_VERSION)
        self.assertNotIn("review_notes", payload)
        self.assertNotIn("source_title", payload)

    def test_audit_replay_loads_final_fact_by_natural_key(self) -> None:
        payload = {
            "run_id": RUN_ID,
            "video_id": "v1",
            "resolver_version": RESOLVER_VERSION,
            "prompt_version": PROMPT_VERSION,
            "source_method": "human_override",
            "candidate": "Kairo Vee",
            "decision": "edited",
            "final_name": "Kairo Vee",
            "reason_code": "mapping.human_override",
        }
        cursor = FakeCursor(rows=((payload,),))
        replay = PostgresAuditReplayFacts(FakeConnection(cursor))

        result = replay.get_final_fact(RUN_ID, "v1", RESOLVER_VERSION)

        self.assertIsNotNone(result)
        assert result is not None
        self.assertEqual(result.decision, ResolutionDecision.ACCEPTED)
        self.assertEqual(result.source_method, ResolutionMethod.HUMAN_OVERRIDE)
        sql, parameters = cursor.executions[0]
        self.assertIn("after_json ->> 'run_id'", sql)
        self.assertEqual(parameters, (RUN_ID, "v1", RESOLVER_VERSION))


if __name__ == "__main__":
    unittest.main()
