"""Deterministic Entity Resolution core (DATA-ENTITY-001).

The LLM is an optional, text-only fallback. It never decides acceptance, never
produces a numeric field, and is never called before persisted replay state is
checked. All generated candidates pass the same deterministic title-span guard.
"""

from __future__ import annotations

import json
import re
import unicodedata
from dataclasses import dataclass, replace
from enum import StrEnum
from typing import Protocol, Sequence


RESOLVER_VERSION = "entity-resolver-v1"
PROMPT_VERSION = "llm-fallback-v1"

LLM_SYSTEM_PROMPT = """You extract one possible artist name from ONE YouTube title.
Use only text present in the supplied title.
Do not use external knowledge, complete names, or translate.
If there is not exactly one plausible candidate, return candidate=null.
Return only valid JSON matching {"candidate": string | null}.
Do not return explanations, confidence, scores, percentages, rankings, or numeric fields.
Digits may occur only when copied inside candidate as part of the name.
"""


class ResolutionMethod(StrEnum):
    REGEX = "regex"
    LLM_ASSISTED = "llm_assisted"
    HUMAN_OVERRIDE = "human_override"
    UNKNOWN = "unknown"


class ResolutionDecision(StrEnum):
    ACCEPTED = "accepted"
    REVIEW_REQUIRED = "review_required"
    REJECTED = "rejected"


class CandidateStatus(StrEnum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


class EntityResolutionError(RuntimeError):
    """Base error with a safe, non-PII message."""


class ContractViolation(EntityResolutionError):
    """A version, state, or adapter violated the resolver contract."""


class StateIntegrityError(EntityResolutionError):
    """Persisted replay/queue state is inconsistent with immutable raw."""


@dataclass(frozen=True, slots=True)
class RawVideo:
    run_id: str
    video_id: str
    source_title: str | None


@dataclass(frozen=True, slots=True)
class PendingCandidate:
    run_id: str
    video_id: str
    proposed_name: str
    method: ResolutionMethod
    resolver_version: str
    prompt_version: str | None
    status: CandidateStatus = CandidateStatus.PENDING
    artist_id: str | None = None
    review_notes: None = None


@dataclass(frozen=True, slots=True)
class ResolutionOutcome:
    run_id: str
    video_id: str
    resolver_version: str
    source_method: ResolutionMethod
    candidate: str | None
    decision: ResolutionDecision
    final_name: str | None
    needs_review: bool
    reason_code: str
    prompt_version: str | None = None
    artist_id: str | None = None
    replayed: bool = False


class ArtistCatalog(Protocol):
    """Normalized lookup over artists.canonical_name and artist_aliases.alias."""

    def find_artist_ids(self, normalized_name: str) -> Sequence[str]: ...


class LLMCandidateExtractor(Protocol):
    """Restricted adapter. The return value must be raw JSON, never free text."""

    def extract_candidate(self, *, title: str, prompt_version: str) -> str: ...


class CandidateQueue(Protocol):
    """Durable entity_resolution_candidates port."""

    def get_pending(self, run_id: str, video_id: str) -> PendingCandidate | None: ...

    def enqueue_pending(self, candidate: PendingCandidate) -> PendingCandidate: ...


class ReplayFactStore(Protocol):
    """Append-only audit-event facts addressed by the natural replay key."""

    def get_final_fact(
        self, run_id: str, video_id: str, resolver_version: str
    ) -> ResolutionOutcome | None: ...

    def record_rejected_fact(self, outcome: ResolutionOutcome) -> None: ...


_TYPE_BEAT_RE = re.compile(r"(?<!\w)type\s+beat(?!\w)", re.IGNORECASE)
_STRUCTURAL_DELIMITER_RE = re.compile(r"\||:|\]|\)|\s[-–—]\s")
_MULTI_ARTIST_RE = re.compile(
    r"(?<!\w)(?:x|feat\.?|ft\.?)\s|\s(?:x|feat\.?|ft\.?)(?!\w)|[&/,]",
    re.IGNORECASE,
)
_METADATA_RE = re.compile(
    r"(?:"
    r"(?<!\w)(?:free|prod(?:uced)?|bpm|key|lease|licen[cs]e|buy|price)(?!\w)"
    r"|(?<!\w)(?:19|20)\d{2}(?!\w)"
    r"|(?<!\w)\d{2,3}\s*bpm(?!\w)"
    r"|(?<!\w)[a-g](?:#|b)?\s*(?:maj(?:or)?|min(?:or)?)(?!\w)"
    r"|[$€£]|[\[\](){}]"
    r")",
    re.IGNORECASE,
)


def normalize_for_match(text: str | None) -> str:
    """Apply the versioned DATA-ENTITY-001 normalization contract."""

    if text is None:
        return ""
    normalized = unicodedata.normalize("NFKC", text).casefold()
    characters = (
        " " if unicodedata.category(character)[0] in {"P", "S", "Z"} else character
        for character in normalized
    )
    return " ".join("".join(characters).split())


def candidate_is_supported(candidate: str | None, source_title: str | None) -> bool:
    """Require candidate tokens to be contiguous, complete tokens in the title."""

    candidate_tokens = normalize_for_match(candidate).split()
    title_tokens = normalize_for_match(source_title).split()
    if not candidate_tokens:
        return False
    width = len(candidate_tokens)
    return any(
        title_tokens[index : index + width] == candidate_tokens
        for index in range(len(title_tokens) - width + 1)
    )


@dataclass(frozen=True, slots=True)
class _RegexAttempt:
    candidate: str | None
    reason_code: str
    terminal_rejection: bool = False


def _extract_candidate_before_marker(title: str, marker_start: int) -> str:
    prefix = title[:marker_start]
    candidate_start = 0
    for delimiter in _STRUCTURAL_DELIMITER_RE.finditer(prefix):
        candidate_start = delimiter.end()
    return prefix[candidate_start:].strip()


def _regex_attempt(title: str, catalog: ArtistCatalog) -> tuple[_RegexAttempt, str | None]:
    markers = list(_TYPE_BEAT_RE.finditer(title))
    if not markers:
        return _RegexAttempt(None, "regex_no_match"), None
    if len(markers) != 1:
        return _RegexAttempt(None, "regex_multiple_matches"), None

    candidate = _extract_candidate_before_marker(title, markers[0].start())
    if not candidate:
        return _RegexAttempt(None, "regex_empty_candidate"), None
    if not candidate_is_supported(candidate, title):
        return (
            _RegexAttempt(candidate, "candidate_outside_source_title", True),
            None,
        )
    if _MULTI_ARTIST_RE.search(candidate):
        return _RegexAttempt(candidate, "regex_multiple_artists"), None
    if _METADATA_RE.search(candidate):
        return _RegexAttempt(candidate, "regex_metadata_residual"), None

    matches = tuple(catalog.find_artist_ids(normalize_for_match(candidate)))
    if len(matches) > 1:
        return _RegexAttempt(candidate, "artist_alias_collision"), None
    return _RegexAttempt(candidate, "regex_autoaccepted"), matches[0] if matches else None


def _parse_llm_candidate(raw_output: str) -> tuple[str | None, str | None]:
    """Return (candidate, error_reason) under an exact one-field JSON contract."""

    try:
        payload = json.loads(raw_output)
    except (json.JSONDecodeError, TypeError):
        return None, "llm_contract_violation"
    if not isinstance(payload, dict) or set(payload) != {"candidate"}:
        return None, "llm_contract_violation"
    candidate = payload["candidate"]
    if candidate is not None and not isinstance(candidate, str):
        return None, "llm_contract_violation"
    return candidate, None


def _require_nonblank(value: str, field: str) -> None:
    if not isinstance(value, str) or not value.strip():
        raise ContractViolation(f"{field} must be non-blank")


class EntityResolver:
    """Regex-first resolver with durable replay and review-queue boundaries."""

    def __init__(
        self,
        *,
        catalog: ArtistCatalog,
        queue: CandidateQueue,
        replay_facts: ReplayFactStore,
        llm: LLMCandidateExtractor | None,
        resolver_version: str = RESOLVER_VERSION,
        prompt_version: str = PROMPT_VERSION,
    ) -> None:
        _require_nonblank(resolver_version, "resolver_version")
        _require_nonblank(prompt_version, "prompt_version")
        self._catalog = catalog
        self._queue = queue
        self._replay_facts = replay_facts
        self._llm = llm
        self._resolver_version = resolver_version
        self._prompt_version = prompt_version

    def resolve(self, video: RawVideo) -> ResolutionOutcome:
        _require_nonblank(video.run_id, "run_id")
        _require_nonblank(video.video_id, "video_id")
        title = video.source_title
        if not normalize_for_match(title):
            return self._outcome(
                video,
                method=ResolutionMethod.UNKNOWN,
                candidate=None,
                decision=ResolutionDecision.REJECTED,
                final_name=None,
                needs_review=False,
                reason_code="source_title_missing",
            )

        replayed = self._replay_facts.get_final_fact(
            video.run_id, video.video_id, self._resolver_version
        )
        if replayed is not None:
            self._validate_replay_fact(video, replayed)
            return replace(replayed, replayed=True)

        pending = self._queue.get_pending(video.run_id, video.video_id)
        if pending is not None:
            return self._reuse_pending(video, pending)

        regex_attempt, artist_id = _regex_attempt(title, self._catalog)
        if regex_attempt.reason_code == "regex_autoaccepted":
            return self._outcome(
                video,
                method=ResolutionMethod.REGEX,
                candidate=regex_attempt.candidate,
                decision=ResolutionDecision.ACCEPTED,
                final_name=regex_attempt.candidate,
                needs_review=False,
                reason_code=regex_attempt.reason_code,
                artist_id=artist_id,
            )
        if regex_attempt.terminal_rejection:
            return self._outcome(
                video,
                method=ResolutionMethod.REGEX,
                candidate=regex_attempt.candidate,
                decision=ResolutionDecision.REJECTED,
                final_name=None,
                needs_review=False,
                reason_code=regex_attempt.reason_code,
            )
        return self._resolve_ambiguous(video, regex_attempt.reason_code)

    def _resolve_ambiguous(self, video: RawVideo, regex_reason: str) -> ResolutionOutcome:
        if self._llm is None:
            return self._outcome(
                video,
                method=ResolutionMethod.UNKNOWN,
                candidate=None,
                decision=ResolutionDecision.REVIEW_REQUIRED,
                final_name=None,
                needs_review=True,
                reason_code="llm_unavailable",
            )

        try:
            raw_output = self._llm.extract_candidate(
                title=video.source_title or "", prompt_version=self._prompt_version
            )
        except Exception:
            return self._record_llm_rejection(video, None, "llm_call_failed")

        candidate, contract_error = _parse_llm_candidate(raw_output)
        if contract_error is not None:
            return self._record_llm_rejection(video, None, contract_error)
        if candidate is None:
            return self._record_llm_rejection(video, None, "llm_no_single_candidate")
        if not candidate_is_supported(candidate, video.source_title):
            return self._record_llm_rejection(
                video, candidate, "candidate_outside_source_title"
            )

        pending = PendingCandidate(
            run_id=video.run_id,
            video_id=video.video_id,
            proposed_name=candidate,
            method=ResolutionMethod.LLM_ASSISTED,
            resolver_version=self._resolver_version,
            prompt_version=self._prompt_version,
            artist_id=None,
            review_notes=None,
        )
        stored = self._queue.enqueue_pending(pending)
        outcome = self._reuse_pending(video, stored)
        return replace(outcome, reason_code=f"{regex_reason}:llm_candidate_pending")

    def _record_llm_rejection(
        self, video: RawVideo, candidate: str | None, reason_code: str
    ) -> ResolutionOutcome:
        outcome = self._outcome(
            video,
            method=ResolutionMethod.LLM_ASSISTED,
            candidate=candidate,
            decision=ResolutionDecision.REJECTED,
            final_name=None,
            needs_review=False,
            reason_code=reason_code,
            prompt_version=self._prompt_version,
        )
        self._replay_facts.record_rejected_fact(outcome)
        return outcome

    def _reuse_pending(
        self, video: RawVideo, pending: PendingCandidate
    ) -> ResolutionOutcome:
        if pending.status is not CandidateStatus.PENDING:
            raise StateIntegrityError("candidate queue returned a non-pending row")
        if pending.run_id != video.run_id or pending.video_id != video.video_id:
            raise StateIntegrityError("candidate queue natural key mismatch")
        if pending.resolver_version != self._resolver_version:
            return self._outcome(
                video,
                method=pending.method,
                candidate=pending.proposed_name,
                decision=ResolutionDecision.REVIEW_REQUIRED,
                final_name=None,
                needs_review=True,
                reason_code="pending_resolver_version_conflict",
                prompt_version=pending.prompt_version,
                replayed=True,
            )
        if not candidate_is_supported(pending.proposed_name, video.source_title):
            raise StateIntegrityError("persisted candidate fails the source-title guard")
        if pending.method is ResolutionMethod.LLM_ASSISTED:
            _require_nonblank(pending.prompt_version or "", "prompt_version")
        return self._outcome(
            video,
            method=pending.method,
            candidate=pending.proposed_name,
            decision=ResolutionDecision.REVIEW_REQUIRED,
            final_name=None,
            needs_review=True,
            reason_code="pending_candidate_reused",
            prompt_version=pending.prompt_version,
            artist_id=pending.artist_id,
            replayed=True,
        )

    def _validate_replay_fact(
        self, video: RawVideo, outcome: ResolutionOutcome
    ) -> None:
        if (
            outcome.run_id != video.run_id
            or outcome.video_id != video.video_id
            or outcome.resolver_version != self._resolver_version
        ):
            raise StateIntegrityError("replay fact natural key mismatch")
        if outcome.final_name is not None and not candidate_is_supported(
            outcome.final_name, video.source_title
        ):
            raise StateIntegrityError("replay fact fails the source-title guard")

    def _outcome(
        self,
        video: RawVideo,
        *,
        method: ResolutionMethod,
        candidate: str | None,
        decision: ResolutionDecision,
        final_name: str | None,
        needs_review: bool,
        reason_code: str,
        prompt_version: str | None = None,
        artist_id: str | None = None,
        replayed: bool = False,
    ) -> ResolutionOutcome:
        return ResolutionOutcome(
            run_id=video.run_id,
            video_id=video.video_id,
            resolver_version=self._resolver_version,
            source_method=method,
            candidate=candidate,
            decision=decision,
            final_name=final_name,
            needs_review=needs_review,
            reason_code=reason_code,
            prompt_version=prompt_version,
            artist_id=artist_id,
            replayed=replayed,
        )
