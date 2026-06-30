"""Driver-agnostic PostgreSQL write/replay adapters for Entity Resolution.

The module accepts a PEP-249-like connection but imports no database driver.
Transaction ownership remains with the caller. SQL is parameterized and the
automated writer always stores NULL in review_notes and artist_id.
"""

from __future__ import annotations

import json
from typing import Any, Protocol, Sequence

from .entity_resolution import (
    CandidateStatus,
    ContractViolation,
    PendingCandidate,
    ResolutionDecision,
    ResolutionMethod,
    ResolutionOutcome,
)


class CursorLike(Protocol):
    def execute(self, operation: str, parameters: Sequence[Any] = ()) -> Any: ...

    def fetchone(self) -> Sequence[Any] | None: ...

    def close(self) -> None: ...


class ConnectionLike(Protocol):
    def cursor(self) -> CursorLike: ...


class CandidatePersistenceError(RuntimeError):
    """Safe persistence error: deliberately excludes SQL values and DB details."""


_PENDING_COLUMNS = """
run_id, video_id, proposed_name, method, resolver_version,
prompt_version, status, artist_id, review_notes
""".strip()

_GET_PENDING_SQL = f"""
select {_PENDING_COLUMNS}
from public.entity_resolution_candidates
where run_id = %s and video_id = %s and status = 'pending'
limit 1
""".strip()

_INSERT_PENDING_SQL = f"""
insert into public.entity_resolution_candidates (
  run_id, video_id, proposed_name, artist_id, method,
  resolver_version, prompt_version, status, review_notes
)
values (%s, %s, %s, null, %s, %s, %s, 'pending', null)
on conflict (run_id, video_id) where status = 'pending'
do nothing
returning {_PENDING_COLUMNS}
""".strip()

_GET_FINAL_FACT_SQL = """
select after_json
from public.audit_events
where entity_table = 'video_artist_mappings'
  and action in (
    'mapping.review_approved',
    'mapping.human_override',
    'mapping.review_rejected',
    'mapping.llm_rejected'
  )
  and after_json ->> 'run_id' = %s
  and after_json ->> 'video_id' = %s
  and after_json ->> 'resolver_version' = %s
order by created_at desc, id desc
limit 1
""".strip()

_INSERT_REJECTED_FACT_SQL = """
insert into public.audit_events (
  actor_type, actor_id, action, entity_table, entity_id,
  before_json, after_json, reason
)
values ('pipeline', null, 'mapping.llm_rejected',
        'video_artist_mappings', null, null, %s::jsonb, %s)
""".strip()


def _nonblank(value: str | None, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ContractViolation(f"{field} must be non-blank")
    return value


def _pending_from_row(row: Sequence[Any]) -> PendingCandidate:
    if len(row) != 9:
        raise CandidatePersistenceError("candidate query returned an invalid shape")
    return PendingCandidate(
        run_id=str(row[0]),
        video_id=str(row[1]),
        proposed_name=str(row[2]),
        method=ResolutionMethod(str(row[3])),
        resolver_version=str(row[4]),
        prompt_version=None if row[5] is None else str(row[5]),
        status=CandidateStatus(str(row[6])),
        artist_id=None if row[7] is None else str(row[7]),
        review_notes=None,
    )


class PostgresCandidateQueue:
    """Queue writer matching live migration 20260620000006.

    The composite FK to raw_youtube_videos proves provenance. The partial
    ON CONFLICT target mirrors the live unique pending index. No commit is
    issued here so a caller can compose an explicit transaction boundary.
    """

    def __init__(self, connection: ConnectionLike) -> None:
        self._connection = connection

    def get_pending(self, run_id: str, video_id: str) -> PendingCandidate | None:
        cursor = self._connection.cursor()
        try:
            cursor.execute(_GET_PENDING_SQL, (run_id, video_id))
            row = cursor.fetchone()
            return None if row is None else _pending_from_row(row)
        except CandidatePersistenceError:
            raise
        except Exception:
            raise CandidatePersistenceError("candidate lookup failed") from None
        finally:
            cursor.close()

    def enqueue_pending(self, candidate: PendingCandidate) -> PendingCandidate:
        self._validate_automated_candidate(candidate)
        cursor = self._connection.cursor()
        try:
            cursor.execute(
                _INSERT_PENDING_SQL,
                (
                    candidate.run_id,
                    candidate.video_id,
                    candidate.proposed_name,
                    candidate.method.value,
                    candidate.resolver_version,
                    candidate.prompt_version,
                ),
            )
            row = cursor.fetchone()
            if row is not None:
                return _pending_from_row(row)

            cursor.execute(_GET_PENDING_SQL, (candidate.run_id, candidate.video_id))
            existing = cursor.fetchone()
            if existing is None:
                raise CandidatePersistenceError("pending candidate conflict was not recoverable")
            return _pending_from_row(existing)
        except (CandidatePersistenceError, ContractViolation):
            raise
        except Exception:
            # Do not leak proposed_name, title, SQL parameters, or driver diagnostics.
            raise CandidatePersistenceError("candidate persistence failed") from None
        finally:
            cursor.close()

    @staticmethod
    def _validate_automated_candidate(candidate: PendingCandidate) -> None:
        _nonblank(candidate.run_id, "run_id")
        _nonblank(candidate.video_id, "video_id")
        _nonblank(candidate.proposed_name, "proposed_name")
        _nonblank(candidate.resolver_version, "resolver_version")
        if candidate.status is not CandidateStatus.PENDING:
            raise ContractViolation("automated candidate must be pending")
        if candidate.method is not ResolutionMethod.LLM_ASSISTED:
            raise ContractViolation("automated queue writer accepts only llm_assisted")
        _nonblank(candidate.prompt_version, "prompt_version")
        if candidate.artist_id is not None:
            raise ContractViolation("unapproved candidate cannot create or bind an artist")
        if candidate.review_notes is not None:
            raise ContractViolation("automated writer cannot serialize review_notes")


class PostgresAuditReplayFacts:
    """Append-only replay facts using audit_events natural-key payloads."""

    def __init__(self, connection: ConnectionLike) -> None:
        self._connection = connection

    def get_final_fact(
        self, run_id: str, video_id: str, resolver_version: str
    ) -> ResolutionOutcome | None:
        cursor = self._connection.cursor()
        try:
            cursor.execute(_GET_FINAL_FACT_SQL, (run_id, video_id, resolver_version))
            row = cursor.fetchone()
            if row is None:
                return None
            return self._outcome_from_payload(row[0])
        except CandidatePersistenceError:
            raise
        except Exception:
            raise CandidatePersistenceError("entity replay lookup failed") from None
        finally:
            cursor.close()

    def record_rejected_fact(self, outcome: ResolutionOutcome) -> None:
        if outcome.source_method is not ResolutionMethod.LLM_ASSISTED:
            raise ContractViolation("only rejected LLM facts use the pipeline audit writer")
        if outcome.decision is not ResolutionDecision.REJECTED:
            raise ContractViolation("audit writer requires a rejected outcome")
        payload = {
            "run_id": _nonblank(outcome.run_id, "run_id"),
            "video_id": _nonblank(outcome.video_id, "video_id"),
            "resolver_version": _nonblank(outcome.resolver_version, "resolver_version"),
            "prompt_version": _nonblank(outcome.prompt_version, "prompt_version"),
            "source_method": outcome.source_method.value,
            "candidate": outcome.candidate,
            "decision": "rejected",
            "final_name": None,
            "reason_code": _nonblank(outcome.reason_code, "reason_code"),
        }
        serialized = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
        cursor = self._connection.cursor()
        try:
            cursor.execute(_INSERT_REJECTED_FACT_SQL, (serialized, outcome.reason_code))
        except Exception:
            raise CandidatePersistenceError("entity replay persistence failed") from None
        finally:
            cursor.close()

    @staticmethod
    def _outcome_from_payload(raw_payload: Any) -> ResolutionOutcome:
        if isinstance(raw_payload, str):
            try:
                payload = json.loads(raw_payload)
            except json.JSONDecodeError:
                raise CandidatePersistenceError("replay fact has invalid JSON") from None
        else:
            payload = raw_payload
        if not isinstance(payload, dict):
            raise CandidatePersistenceError("replay fact has an invalid shape")
        try:
            persisted_decision = str(payload["decision"])
            if persisted_decision not in {"accepted", "approved", "edited", "rejected"}:
                raise ValueError("unsupported replay decision")
            decision = (
                ResolutionDecision.REJECTED
                if persisted_decision == "rejected"
                else ResolutionDecision.ACCEPTED
            )
            candidate = payload.get("candidate")
            final_name = payload.get("final_name")
            prompt_version = payload.get("prompt_version")
            if candidate is not None and not isinstance(candidate, str):
                raise TypeError("candidate must be text or null")
            if final_name is not None and not isinstance(final_name, str):
                raise TypeError("final_name must be text or null")
            if prompt_version is not None and not isinstance(prompt_version, str):
                raise TypeError("prompt_version must be text or null")
            return ResolutionOutcome(
                run_id=_nonblank(payload.get("run_id"), "run_id"),
                video_id=_nonblank(payload.get("video_id"), "video_id"),
                resolver_version=_nonblank(
                    payload.get("resolver_version"), "resolver_version"
                ),
                source_method=ResolutionMethod(str(payload["source_method"])),
                candidate=candidate,
                decision=decision,
                final_name=final_name,
                needs_review=False,
                reason_code=_nonblank(payload.get("reason_code"), "reason_code"),
                prompt_version=prompt_version,
            )
        except (KeyError, TypeError, ValueError, ContractViolation):
            raise CandidatePersistenceError("replay fact has an invalid contract") from None
