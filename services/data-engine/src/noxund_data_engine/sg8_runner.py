"""SG-8 offline runner (DATA-SG8-001, stage 2 — PURE, OFFLINE).

This is the stage-2 unit of the SG-8 design contract: a **pure, offline** driver of
the two-round P5-REPRO-01 protocol (Round 1 compute + Round 2 zero-LLM replay) over
an in-memory synthetic dataset. It orchestrates the mandatory state machine and the
fail-closed verdict; it touches NO database, NO network, NO real LLM, NO schema, NO
workflow, NO Environment and NO secret. Every dependency is a port with an in-memory
adapter (``entity_resolution`` protocols + an append-only evidence store).

It reuses the frozen deterministic surface verbatim: ``pipeline.run_pipeline`` (via its
optional ``resolver`` injection seam) and ``pipeline.pipeline_digest`` — so no produced
number, order, label, version or the golden digest changes.

State machine (contract §4, mandatory):

    SESSION_OPEN
      -> resolve_round1()            deterministic first; stub LLM only for the
                                     items regex cannot cleanly resolve
      -> R1_AWAITING_REVIEW          any needs_review -> downstream is BLOCKED
      -> submit_review()             human decisions; legitimate resume in the SAME
                                     sg8_session_id; clears the review queue
      -> R1_RESOLVED
      -> freeze_snapshot()           freezes resolution facts -> resolution_snapshot_id
                                     (bypassing the review gate here => FAIL)
      -> R1_SNAPSHOT_FROZEN
      -> compute_round1()            run_pipeline per report; append-only evidence,
                                     partitioned by round_execution_id
      -> R1_COMPUTED
      -> run_round2()                validate snapshot completeness BEFORE any LLM;
                                     replay with a ForbiddenLLMCandidateExtractor;
                                     compare per report_run_id (same
                                     source_collection_run_id); drift / evidence
                                     collision / dataset divergence => FAIL
      -> PASSED | FAILED (terminal)  a FAILED session cannot be resumed; a new attempt
                                     requires a new sg8_session_id.

Non-goals (stage 2): no live adapters (Postgres / real LLM), no Q-1/Q-2 schema, no real
compute, no SG-8 execution. The live wiring is stage 3, behind these SAME ports.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field, replace
from enum import StrEnum
from typing import Any, Mapping, Sequence

from .entity_resolution import (
    RESOLVER_VERSION,
    ArtistCatalog,
    EntityResolver,
    LLMCandidateExtractor,
    PendingCandidate,
    RawVideo,
    ResolutionDecision,
    ResolutionMethod,
    ResolutionOutcome,
    candidate_is_supported,
    normalize_for_match,
)
from .pipeline import PipelineSnapshot, pipeline_digest, run_pipeline


# ---------------------------------------------------------------------------
# Errors.
# ---------------------------------------------------------------------------
class Sg8Error(RuntimeError):
    """Base error with a safe, non-PII message."""


class Sg8ContractViolation(Sg8Error):
    """An input or a caller sequence violated the SG-8 runner contract."""


class Sg8ReplayLlmForbidden(Sg8Error):
    """The LLM was invoked during a zero-LLM replay (Round 2 defense-in-depth)."""


class Sg8EvidenceCollision(Sg8Error):
    """An append-only evidence artifact would be overwritten."""


class Sg8SnapshotIncomplete(Sg8Error):
    """The frozen resolution snapshot does not cover every video of a report."""


class Sg8TerminalSessionError(Sg8Error):
    """A terminal (PASSED/FAILED) session cannot be resumed or re-driven."""


# ---------------------------------------------------------------------------
# State machine.
# ---------------------------------------------------------------------------
class Sg8State(StrEnum):
    SESSION_OPEN = "session_open"
    R1_AWAITING_REVIEW = "r1_awaiting_review"
    R1_RESOLVED = "r1_resolved"
    R1_SNAPSHOT_FROZEN = "r1_snapshot_frozen"
    R1_COMPUTED = "r1_computed"
    PASSED = "passed"
    FAILED = "failed"


_TERMINAL = frozenset({Sg8State.PASSED, Sg8State.FAILED})


# ---------------------------------------------------------------------------
# LLM provenance (mandatory in Round 1; audited, NEVER part of the digest).
# ---------------------------------------------------------------------------
@dataclass(frozen=True, slots=True)
class LlmProvenance:
    """Mandatory provenance of ONE Round-1 LLM invocation (contract §5.3).

    Persisted with the resolution snapshot for audit; it is deliberately EXCLUDED
    from the comparable payload (it is operational metadata, never a product number).
    """

    provider: str
    model: str
    model_version: str
    prompt_version: str
    adapter_identity: str
    params: Mapping[str, Any] = field(default_factory=dict)

    def is_complete(self) -> bool:
        fields = (
            self.provider,
            self.model,
            self.model_version,
            self.prompt_version,
            self.adapter_identity,
        )
        if not all(isinstance(v, str) and v.strip() for v in fields):
            return False
        return isinstance(self.params, Mapping)


# ---------------------------------------------------------------------------
# In-memory adapters (pure; stage-3 swaps these for durable/live ones).
# ---------------------------------------------------------------------------
class InMemoryCatalog:
    """``ArtistCatalog`` over a synthetic registry (normalized name -> artist_ids)."""

    def __init__(self, index: Mapping[str, tuple[str, ...]]) -> None:
        self._index = dict(index)

    @classmethod
    def from_registry(cls, registry: Sequence[tuple[str, Sequence[str]]]) -> "InMemoryCatalog":
        index: dict[str, list[str]] = {}
        for artist_id, names in registry:
            for name in names:
                normalized = normalize_for_match(name)
                if not normalized:
                    continue
                bucket = index.setdefault(normalized, [])
                if artist_id not in bucket:
                    bucket.append(artist_id)
        return cls({key: tuple(sorted(value)) for key, value in index.items()})

    def find_artist_ids(self, normalized_name: str) -> Sequence[str]:
        return self._index.get(normalized_name, ())


class InMemoryCandidateQueue:
    """Durable ``CandidateQueue`` port, in memory (one review queue per report)."""

    def __init__(self) -> None:
        self._pending: dict[tuple[str, str], PendingCandidate] = {}

    def get_pending(self, run_id: str, video_id: str) -> PendingCandidate | None:
        return self._pending.get((run_id, video_id))

    def enqueue_pending(self, candidate: PendingCandidate) -> PendingCandidate:
        self._pending[(candidate.run_id, candidate.video_id)] = candidate
        return candidate


class InMemoryReplayFactStore:
    """Append-only ``ReplayFactStore`` with an explicit freeze (immutability)."""

    def __init__(self) -> None:
        self._facts: dict[tuple[str, str, str], ResolutionOutcome] = {}
        self._frozen = False

    # -- ReplayFactStore protocol ---------------------------------------------
    def get_final_fact(
        self, run_id: str, video_id: str, resolver_version: str
    ) -> ResolutionOutcome | None:
        return self._facts.get((run_id, video_id, resolver_version))

    def record_rejected_fact(self, outcome: ResolutionOutcome) -> None:
        self._record(outcome)

    # -- runner-only extensions ------------------------------------------------
    def record_final_fact(self, outcome: ResolutionOutcome) -> None:
        self._record(outcome)

    def _record(self, outcome: ResolutionOutcome) -> None:
        if self._frozen:
            raise Sg8ContractViolation("cannot record a fact into a frozen snapshot")
        key = (outcome.run_id, outcome.video_id, outcome.resolver_version)
        existing = self._facts.get(key)
        if existing is not None and existing != outcome:
            raise Sg8EvidenceCollision("append-only replay fact would be overwritten")
        self._facts[key] = outcome

    def freeze(self) -> None:
        self._frozen = True

    @property
    def frozen(self) -> bool:
        return self._frozen

    def video_ids_with_fact(self, run_id: str, resolver_version: str) -> frozenset[str]:
        return frozenset(
            vid
            for (rid, vid, rver) in self._facts
            if rid == run_id and rver == resolver_version
        )


@dataclass(frozen=True, slots=True)
class EvidenceArtifact:
    """One append-only compute artifact of one report in one round."""

    round_execution_id: str
    report_run_id: str
    source_collection_run_id: str
    digest: str


class InMemoryEvidenceStore:
    """Append-only evidence, partitioned by ``round_execution_id`` (contract §6.5 / D-10).

    Round 1 and Round 2 write into disjoint partitions keyed by their own
    ``round_execution_id``; a write that would overwrite an existing artifact — a
    Round 2 collision with a Round 1 artifact included — is a contract violation.
    """

    def __init__(self) -> None:
        self._artifacts: dict[tuple[str, str], EvidenceArtifact] = {}

    def append(self, artifact: EvidenceArtifact) -> None:
        key = (artifact.round_execution_id, artifact.report_run_id)
        if key in self._artifacts:
            raise Sg8EvidenceCollision(
                "append-only evidence artifact already exists for this round/report"
            )
        self._artifacts[key] = artifact

    def artifacts_for_round(self, round_execution_id: str) -> tuple[EvidenceArtifact, ...]:
        return tuple(
            a for a in self._artifacts.values() if a.round_execution_id == round_execution_id
        )


class ForbiddenLLMCandidateExtractor:
    """A ``LLMCandidateExtractor`` that FAILS CLOSED on any call (Round 2 defense).

    Round 2 replays a frozen snapshot, so every video hits the replay-fact branch and
    this adapter is never reached; if a logic bug ever reached it, it raises rather
    than silently resolving. ``call_count`` lets tests assert it stayed at 0.
    """

    def __init__(self) -> None:
        self.call_count = 0

    def extract_candidate(self, *, title: str, prompt_version: str) -> str:
        self.call_count += 1
        raise Sg8ReplayLlmForbidden("LLM invoked during a zero-LLM replay round")


class StubLLMCandidateExtractor:
    """A deterministic offline ``LLMCandidateExtractor`` (never a real provider).

    Returns the one-field JSON contract the resolver expects, driven by a fixed
    ``title -> candidate`` map. ``provenance`` is the mandatory §5.3 provenance the
    runner attaches to every video this stub resolves.
    """

    def __init__(
        self, by_title: Mapping[str, str | None], *, provenance: LlmProvenance
    ) -> None:
        self._by_title = dict(by_title)
        self.provenance = provenance
        self.call_count = 0

    def extract_candidate(self, *, title: str, prompt_version: str) -> str:
        self.call_count += 1
        return json.dumps({"candidate": self._by_title.get(title)})


# ---------------------------------------------------------------------------
# Session inputs + evidence + verdict.
# ---------------------------------------------------------------------------
@dataclass(frozen=True, slots=True)
class Sg8Report:
    """One report in the session: its frozen ``report_run_id`` + synthetic snapshot.

    ``snapshot.run_id`` MUST equal ``report_run_id`` (the digest carries ``run_id``);
    both rounds reuse this same ``report_run_id`` (contract §2.1 / D-1).
    """

    report_run_id: str
    snapshot: PipelineSnapshot


@dataclass(frozen=True, slots=True)
class Sg8SessionInput:
    source_collection_run_id: str
    reports: tuple[Sg8Report, ...]


@dataclass(frozen=True, slots=True)
class ReviewDecision:
    """One human decision on a pending (needs_review) item — the §8 A3 act (offline)."""

    report_run_id: str
    video_id: str
    approved: bool
    artist_id: str | None = None


@dataclass(frozen=True, slots=True)
class RoundEvidence:
    """The comparable evidence of ONE round: digests keyed by ``report_run_id``."""

    round_execution_id: str
    source_collection_run_id: str
    report_digests: Mapping[str, str]


@dataclass(frozen=True, slots=True)
class Sg8Verdict:
    passed: bool
    reason: str


def compare_round_evidence(round1: RoundEvidence, round2: RoundEvidence) -> Sg8Verdict:
    """Fail-closed comparison of two rounds (contract §1 PASS/FAIL).

    PASS requires: same ``source_collection_run_id`` (dataset), same set of
    ``report_run_id``, and a byte-identical digest for EVERY report. Any drift or
    dataset divergence is a FAIL — there is no tolerance.
    """

    if round1.source_collection_run_id != round2.source_collection_run_id:
        return Sg8Verdict(False, "source_collection_run_id divergence between rounds")
    if set(round1.report_digests) != set(round2.report_digests):
        return Sg8Verdict(False, "report_run_id set mismatch between rounds")
    for report_run_id, digest_r1 in sorted(round1.report_digests.items()):
        if round2.report_digests[report_run_id] != digest_r1:
            return Sg8Verdict(False, f"digest drift for report {report_run_id}")
    return Sg8Verdict(True, "byte-identical across both rounds")


def assert_snapshot_complete(
    video_ids: Sequence[str],
    facts: InMemoryReplayFactStore,
    *,
    run_id: str,
    resolver_version: str = RESOLVER_VERSION,
) -> None:
    """Pre-flight completeness check for Round 2 — runs BEFORE any resolver/LLM call.

    Every video of the report must carry a frozen final fact; a gap raises
    ``Sg8SnapshotIncomplete`` here, so an incomplete snapshot fails closed *before*
    the resolver could ever reach the (forbidden) LLM adapter.
    """

    covered = facts.video_ids_with_fact(run_id, resolver_version)
    missing = [vid for vid in video_ids if vid not in covered]
    if missing:
        raise Sg8SnapshotIncomplete(
            f"{len(missing)} video(s) lack a frozen resolution fact"
        )


# ---------------------------------------------------------------------------
# The session (the state machine).
# ---------------------------------------------------------------------------
class Sg8Session:
    """One SG-8 attempt over one ``source_collection_run_id`` (a Round 1 + Round 2 pair)."""

    def __init__(
        self,
        session_input: Sg8SessionInput,
        *,
        sg8_session_id: str,
        llm: StubLLMCandidateExtractor,
        resolver_version: str = RESOLVER_VERSION,
    ) -> None:
        _require_nonblank(sg8_session_id, "sg8_session_id")
        _require_nonblank(session_input.source_collection_run_id, "source_collection_run_id")
        if not session_input.reports:
            raise Sg8ContractViolation("a session needs at least one report")
        seen: set[str] = set()
        for report in session_input.reports:
            _require_nonblank(report.report_run_id, "report_run_id")
            if report.report_run_id != report.snapshot.run_id:
                raise Sg8ContractViolation("snapshot.run_id must equal report_run_id")
            if report.report_run_id in seen:
                raise Sg8ContractViolation("duplicate report_run_id in the session")
            seen.add(report.report_run_id)

        self._input = session_input
        self._session_id = sg8_session_id
        self._llm = llm
        self._resolver_version = resolver_version
        self._state = Sg8State.SESSION_OPEN
        self._evidence_store = InMemoryEvidenceStore()
        self._compute_llm = ForbiddenLLMCandidateExtractor()

        # Per report_run_id working state.
        self._catalogs: dict[str, InMemoryCatalog] = {}
        self._facts: dict[str, InMemoryReplayFactStore] = {}
        self._pending: dict[tuple[str, str], ResolutionOutcome] = {}
        self._resolved: dict[tuple[str, str], ResolutionOutcome] = {}
        self._llm_assisted: set[tuple[str, str]] = set()
        self._resolution_snapshot_id: str | None = None
        self._round1_evidence: RoundEvidence | None = None
        self._verdict: Sg8Verdict | None = None

    # -- introspection ---------------------------------------------------------
    @property
    def state(self) -> Sg8State:
        return self._state

    @property
    def sg8_session_id(self) -> str:
        return self._session_id

    @property
    def resolution_snapshot_id(self) -> str | None:
        return self._resolution_snapshot_id

    @property
    def compute_llm_call_count(self) -> int:
        return self._compute_llm.call_count

    @property
    def verdict(self) -> Sg8Verdict | None:
        return self._verdict

    @property
    def pending_review_keys(self) -> tuple[tuple[str, str], ...]:
        return tuple(sorted(self._pending))

    # -- transition 1: Round 1 resolution -------------------------------------
    def resolve_round1(self) -> Sg8State:
        self._guard_not_terminal()
        self._require_state(Sg8State.SESSION_OPEN, "resolve_round1")
        for report in self._input.reports:
            catalog = _catalog_for(report.snapshot)
            self._catalogs[report.report_run_id] = catalog
            facts = InMemoryReplayFactStore()
            self._facts[report.report_run_id] = facts
            resolver = EntityResolver(
                catalog=catalog,
                queue=InMemoryCandidateQueue(),
                replay_facts=facts,
                llm=self._llm,
                resolver_version=self._resolver_version,
            )
            for video in report.snapshot.videos:
                key = (report.report_run_id, video.video_id)
                outcome = resolver.resolve(
                    RawVideo(
                        run_id=report.report_run_id,
                        video_id=video.video_id,
                        source_title=video.source_title,
                    )
                )
                if outcome.source_method is ResolutionMethod.LLM_ASSISTED:
                    self._llm_assisted.add(key)
                if outcome.needs_review:
                    self._pending[key] = outcome
                else:
                    self._resolved[key] = outcome
        self._state = (
            Sg8State.R1_AWAITING_REVIEW if self._pending else Sg8State.R1_RESOLVED
        )
        return self._state

    # -- transition 2: legitimate resume (human review) -----------------------
    def submit_review(self, decisions: Sequence[ReviewDecision]) -> Sg8State:
        self._guard_not_terminal()
        self._require_state(Sg8State.R1_AWAITING_REVIEW, "submit_review")
        for decision in decisions:
            key = (decision.report_run_id, decision.video_id)
            pending = self._pending.get(key)
            if pending is None:
                raise Sg8ContractViolation("review decision for a non-pending item")
            if decision.approved:
                if not decision.artist_id or not decision.artist_id.strip():
                    raise Sg8ContractViolation("an approved item must assign an artist_id")
                final = replace(
                    pending,
                    source_method=ResolutionMethod.HUMAN_OVERRIDE,
                    decision=ResolutionDecision.ACCEPTED,
                    final_name=pending.candidate,
                    needs_review=False,
                    reason_code="human_approved",
                    artist_id=decision.artist_id,
                )
            else:
                final = replace(
                    pending,
                    source_method=ResolutionMethod.HUMAN_OVERRIDE,
                    decision=ResolutionDecision.REJECTED,
                    final_name=None,
                    needs_review=False,
                    reason_code="human_rejected",
                    artist_id=None,
                )
            self._resolved[key] = final
            del self._pending[key]
        self._state = (
            Sg8State.R1_AWAITING_REVIEW if self._pending else Sg8State.R1_RESOLVED
        )
        return self._state

    # -- transition 3: freeze the resolution snapshot -------------------------
    def freeze_snapshot(self, *, resolution_snapshot_id: str) -> str:
        self._guard_not_terminal()
        # Bypassing the review gate (freezing while items still await review) is a FAIL.
        if self._state is Sg8State.R1_AWAITING_REVIEW:
            self._fail("freeze attempted while items still await review (gate bypass)")
            raise Sg8ContractViolation("cannot freeze: review gate not cleared (session FAILED)")
        self._require_state(Sg8State.R1_RESOLVED, "freeze_snapshot")
        _require_nonblank(resolution_snapshot_id, "resolution_snapshot_id")

        # §5.3 — every LLM-assisted accepted item must carry complete provenance.
        for key in self._llm_assisted:
            outcome = self._resolved.get(key)
            if outcome is None or outcome.decision is not ResolutionDecision.ACCEPTED:
                continue
            if not self._llm.provenance.is_complete():
                self._fail("incomplete LLM provenance on a Round 1 accepted item")
                raise Sg8ContractViolation("incomplete LLM provenance (session FAILED)")

        for report in self._input.reports:
            facts = self._facts[report.report_run_id]
            for video in report.snapshot.videos:
                outcome = self._resolved[(report.report_run_id, video.video_id)]
                facts.record_final_fact(outcome)
            facts.freeze()

        self._resolution_snapshot_id = resolution_snapshot_id
        self._state = Sg8State.R1_SNAPSHOT_FROZEN
        return resolution_snapshot_id

    # -- transition 4: Round 1 compute ----------------------------------------
    def compute_round1(self, *, round_execution_id: str) -> RoundEvidence:
        self._guard_not_terminal()
        self._require_state(Sg8State.R1_SNAPSHOT_FROZEN, "compute_round1")
        evidence = self._compute_round(round_execution_id, validate_completeness=False)
        self._round1_evidence = evidence
        self._state = Sg8State.R1_COMPUTED
        return evidence

    # -- transition 5: Round 2 replay + verdict -------------------------------
    def run_round2(self, *, round_execution_id: str) -> Sg8Verdict:
        self._guard_not_terminal()
        self._require_state(Sg8State.R1_COMPUTED, "run_round2")
        assert self._round1_evidence is not None
        if round_execution_id == self._round1_evidence.round_execution_id:
            self._fail("Round 2 must use a round_execution_id distinct from Round 1")
            return self._verdict  # type: ignore[return-value]

        # Completeness is checked BEFORE any compute/resolver call (=> before any LLM).
        try:
            for report in self._input.reports:
                assert_snapshot_complete(
                    [v.video_id for v in report.snapshot.videos],
                    self._facts[report.report_run_id],
                    run_id=report.report_run_id,
                    resolver_version=self._resolver_version,
                )
        except Sg8SnapshotIncomplete as exc:
            self._fail(f"Round 2 aborted: {exc}")
            return self._verdict  # type: ignore[return-value]

        try:
            round2_evidence = self._compute_round(round_execution_id, validate_completeness=True)
        except Sg8EvidenceCollision as exc:
            self._fail(f"Round 2 evidence collision: {exc}")
            return self._verdict  # type: ignore[return-value]

        if self._compute_llm.call_count != 0:
            self._fail("LLM was reached during a zero-LLM replay round")
            return self._verdict  # type: ignore[return-value]

        verdict = compare_round_evidence(self._round1_evidence, round2_evidence)
        self._verdict = verdict
        self._state = Sg8State.PASSED if verdict.passed else Sg8State.FAILED
        return verdict

    # -- internals -------------------------------------------------------------
    def _compute_round(
        self, round_execution_id: str, *, validate_completeness: bool
    ) -> RoundEvidence:
        _require_nonblank(round_execution_id, "round_execution_id")
        digests: dict[str, str] = {}
        for report in self._input.reports:
            facts = self._facts[report.report_run_id]
            replay_resolver = EntityResolver(
                catalog=self._catalogs[report.report_run_id],
                queue=InMemoryCandidateQueue(),
                replay_facts=facts,
                llm=self._compute_llm,          # forbidden — must never be reached
                resolver_version=self._resolver_version,
            )
            result = run_pipeline(report.snapshot, resolver=replay_resolver)
            digest = pipeline_digest(result)
            digests[report.report_run_id] = digest
            self._evidence_store.append(
                EvidenceArtifact(
                    round_execution_id=round_execution_id,
                    report_run_id=report.report_run_id,
                    source_collection_run_id=self._input.source_collection_run_id,
                    digest=digest,
                )
            )
        return RoundEvidence(
            round_execution_id=round_execution_id,
            source_collection_run_id=self._input.source_collection_run_id,
            report_digests=digests,
        )

    def _fail(self, reason: str) -> None:
        self._verdict = Sg8Verdict(False, reason)
        self._state = Sg8State.FAILED

    def _guard_not_terminal(self) -> None:
        if self._state in _TERMINAL:
            raise Sg8TerminalSessionError(
                "session is terminal; a new attempt requires a new sg8_session_id"
            )

    def _require_state(self, expected: Sg8State, action: str) -> None:
        if self._state is not expected:
            raise Sg8ContractViolation(
                f"{action} requires state {expected}, but session is {self._state}"
            )


# ---------------------------------------------------------------------------
# Helpers.
# ---------------------------------------------------------------------------
def _require_nonblank(value: str, field_name: str) -> None:
    if not isinstance(value, str) or not value.strip():
        raise Sg8ContractViolation(f"{field_name} must be non-blank")


def _catalog_for(snapshot: PipelineSnapshot) -> InMemoryCatalog:
    return InMemoryCatalog.from_registry(
        [
            (artist.artist_id, (artist.canonical_name, *artist.aliases))
            for artist in snapshot.artists
        ]
    )
