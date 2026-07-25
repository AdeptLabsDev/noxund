"""Driver-agnostic wiring between the SG-8 runner and ``PostgresSg8Store`` (U2B).

U2B of DATA-SG8-001 stage 3 part 2. This is the **smallest** layer that lets the live
integration drive the durable store from the runner's own results, for the E2E test
against a disposable local Supabase. It is **driver-free** (imports no database driver;
the real connection is injected upstream by the integration bootstrap) and **offline**.

What this layer MAY do (and only this):
  * translate the results/events the runner already produced into store calls;
  * mint application-owned ids through an injected :class:`IdFactory`;
  * build Round-1 provenance from the **bytes the provider received** (never a version
    token) via :func:`build_round1_provenance`;
  * coordinate persistence and resume.

What this layer MUST NOT do:
  * create a second finite-state machine — it never *decides* a transition, it mirrors
    the state the runner reports and lets the schema (0008) reject an illegal one;
  * duplicate the PASS gate — ``mark_passed`` is issued to the store, and the schema's
    PASS gate independently accepts/rejects it;
  * recompute or reinterpret any score/digest — Round-1 digests are taken verbatim from
    the runner's ``RoundEvidence``; on PASS the runner's verdict CERTIFIES Round 2 is
    byte-identical to Round 1, so the same digests are persisted as Round-2 evidence and
    the schema re-verifies the equality (no recomputation here);
  * alter the canonical payload, versions or the golden digest — it touches none of them.

Transition legality lives in the runner (``sg8_runner.Sg8Session``) and — authoritatively
— in the schema. ``sg8_runner`` is imported and driven **unchanged**.
"""

from __future__ import annotations

import hashlib
import itertools
import json
import uuid
from typing import Protocol, Sequence

from .postgres_sg8 import Sg8RoundProvenance, Sg8Store, canonical_prompt_sha256
from .sg8_runner import (
    LlmProvenance,
    ReviewDecision,
    RoundEvidence,
    Sg8Session,
    Sg8SessionInput,
    Sg8State,
    Sg8Verdict,
)


# ---------------------------------------------------------------------------
# Application-owned id generation (no implicit DB default for any relevant id).
# ---------------------------------------------------------------------------
class IdFactory(Protocol):
    """Mints the ids the application owns: session, snapshot and round-execution ids.

    No relevant id ever relies on a DB default (``gen_random_uuid()``); the application
    controls them so they stay STABLE across resume/replay of the same attempt.
    """

    def new_id(self) -> str: ...


class UuidIdFactory:
    """Production factory: a fresh random UUID4 per id."""

    def new_id(self) -> str:
        return str(uuid.uuid4())


class SequentialIdFactory:
    """Deterministic factory for tests: stable, reproducible ids.

    ``namespace`` (0..0xffffffff) separates one test's ids from another's so several
    E2E cases can share one disposable database without collision, while each remains
    fully deterministic. Emits RFC-4122-shaped UUID strings (version nibble 4, variant
    8) so they are valid ``uuid`` column values.
    """

    def __init__(self, namespace: int = 0) -> None:
        if not 0 <= namespace <= 0xFFFFFFFF:
            raise ValueError("namespace must fit in 32 bits")
        self._namespace = namespace
        self._counter = itertools.count(1)

    def new_id(self) -> str:
        n = next(self._counter)
        return f"{self._namespace:08x}-0000-4000-8000-{n:012x}"


# ---------------------------------------------------------------------------
# Provenance bridge — derive prompt_hash from the EXACT bytes the provider received.
# ---------------------------------------------------------------------------
def build_round1_provenance(
    prompt_bytes: bytes, provenance: LlmProvenance
) -> Sg8RoundProvenance:
    """Map the runner's ``LlmProvenance`` to a persistable ``Sg8RoundProvenance``.

    ``prompt_hash`` is derived HERE, at the boundary that owns the prompt bytes, as
    ``canonical_prompt_sha256(prompt_bytes)`` — never from ``prompt_version``, a template
    id/name or any metadata. Every other field maps 1:1 (``adapter_identity`` →
    ``adapter_version``). The store validates the digest's format and persists it; U2 E2E
    recomputes it from the captured bytes and proves byte-for-byte equality.
    """
    return Sg8RoundProvenance(
        provider=provenance.provider,
        model=provenance.model,
        model_version=provenance.model_version,
        prompt_hash=canonical_prompt_sha256(prompt_bytes),
        adapter_version=provenance.adapter_identity,
        params=provenance.params,
    )


# ---------------------------------------------------------------------------
# Snapshot metadata — a deterministic snapshot IDENTITY, not the report payload.
# ---------------------------------------------------------------------------
def derive_snapshot_metadata(
    session_input: Sg8SessionInput, *, resolver_version: str
) -> dict[str, object]:
    """Deterministic snapshot identity for ``freeze_snapshot`` (resolver id + fact
    cardinality + content hash).

    This is the frozen-snapshot IDENTITY the store persists as evidence of *which* set
    was frozen — NOT the canonical report payload and NOT ``pipeline_digest`` (those are
    untouched). It is a pure function of the frozen inputs, so Round 1 and Round 2 reuse
    the identical row.
    """
    fact_count = sum(len(report.snapshot.videos) for report in session_input.reports)
    canonical = json.dumps(
        [
            [report.report_run_id, sorted(v.video_id for v in report.snapshot.videos)]
            for report in sorted(session_input.reports, key=lambda r: r.report_run_id)
        ],
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    )
    return {
        "resolver_version": resolver_version,
        "resolver_hash": hashlib.sha256(resolver_version.encode("utf-8")).hexdigest(),
        "fact_count": fact_count,
        "content_hash": hashlib.sha256(canonical.encode("utf-8")).hexdigest(),
    }


# ---------------------------------------------------------------------------
# The coordinator — a MIRROR of the runner's transitions onto the store.
# ---------------------------------------------------------------------------
class Sg8Coordinator:
    """Drives ``PostgresSg8Store`` from a live ``Sg8Session``, mirror-only.

    Each method calls the runner's transition, reads the state the runner reports, and
    issues the corresponding store write. It never decides legality (the runner raises on
    an illegal sequence; the schema rejects an illegal write) and never recomputes a
    digest.
    """

    def __init__(
        self,
        runner: Sg8Session,
        store: Sg8Store,
        ids: IdFactory,
        *,
        source_collection_run_id: str,
    ) -> None:
        self._runner = runner
        self._store = store
        self._ids = ids
        self._src = source_collection_run_id
        self._snapshot_id: str | None = None
        self._round_ids: dict[int, str] = {}

    # -- accessors (for assertions/resume) ------------------------------------
    @property
    def session_id(self) -> str:
        return self._runner.sg8_session_id

    @property
    def resolution_snapshot_id(self) -> str | None:
        return self._snapshot_id

    def round_execution_id(self, round_number: int) -> str | None:
        return self._round_ids.get(round_number)

    # -- lifecycle mirror ------------------------------------------------------
    def open_session(self) -> None:
        self._store.open_session(self._runner.sg8_session_id, self._src)

    def resolve_round1(self) -> Sg8State:
        state = self._runner.resolve_round1()
        self._mirror_review_state(state)
        return state

    def submit_review(self, decisions: Sequence[ReviewDecision]) -> Sg8State:
        state = self._runner.submit_review(decisions)
        self._mirror_review_state(state)
        return state

    def _mirror_review_state(self, state: Sg8State) -> None:
        if state is Sg8State.R1_AWAITING_REVIEW:
            self._store.mark_awaiting_review(self._runner.sg8_session_id)
        elif state is Sg8State.R1_RESOLVED:
            self._store.mark_resolved(self._runner.sg8_session_id)

    def freeze(self, *, snapshot_metadata: dict[str, object]) -> str:
        snapshot_id = self._ids.new_id()
        self._runner.freeze_snapshot(resolution_snapshot_id=snapshot_id)
        self._store.freeze_snapshot(
            self._runner.sg8_session_id,
            source_collection_run_id=self._src,
            resolution_snapshot_id=snapshot_id,
            resolver_version=str(snapshot_metadata["resolver_version"]),
            resolver_hash=str(snapshot_metadata["resolver_hash"]),
            fact_count=int(snapshot_metadata["fact_count"]),  # type: ignore[arg-type]
            content_hash=str(snapshot_metadata["content_hash"]),
        )
        self._snapshot_id = snapshot_id
        return snapshot_id

    def compute_round1(
        self,
        *,
        provenance: Sg8RoundProvenance,
        report_run_id_1: str,
        report_run_id_2: str,
    ) -> RoundEvidence:
        if self._snapshot_id is None:
            raise RuntimeError("freeze() must precede compute_round1()")
        round_id = self._ids.new_id()
        evidence = self._runner.compute_round1(round_execution_id=round_id)
        # Binding advances the DB session to r1_computed; the schema enforces both-or-
        # neither / distinct / composite FK / required-post-compute.
        self._store.bind_reports(
            self._runner.sg8_session_id,
            report_run_id_1=report_run_id_1,
            report_run_id_2=report_run_id_2,
        )
        self._store.append_round(
            round_execution_id=round_id,
            sg8_session_id=self._runner.sg8_session_id,
            round_number=1,
            source_collection_run_id=self._src,
            resolution_snapshot_id=self._snapshot_id,
            provenance=provenance,
        )
        self._persist_evidence(round_id, evidence)
        self._round_ids[1] = round_id
        return evidence

    def run_round2(self, *, round1_evidence: RoundEvidence) -> Sg8Verdict:
        if self._snapshot_id is None:
            raise RuntimeError("compute_round1() must precede run_round2()")
        round_id = self._ids.new_id()
        verdict = self._runner.run_round2(round_execution_id=round_id)
        self._store.append_round(
            round_execution_id=round_id,
            sg8_session_id=self._runner.sg8_session_id,
            round_number=2,
            source_collection_run_id=self._src,
            resolution_snapshot_id=self._snapshot_id,
            provenance=None,  # Round 2 is zero-LLM
        )
        self._round_ids[2] = round_id
        if verdict.passed:
            # The runner's verdict CERTIFIES Round 2 ≡ Round 1 byte-for-byte; persist the
            # runner's Round-1 digests as Round-2 evidence and let the schema PASS gate
            # re-verify. No digest is recomputed here.
            self._persist_evidence(round_id, round1_evidence)
            self._store.mark_passed(
                self._runner.sg8_session_id, verdict_reason=verdict.reason
            )
        else:
            self._store.mark_failed(
                self._runner.sg8_session_id, verdict_reason=verdict.reason
            )
        return verdict

    def _persist_evidence(self, round_execution_id: str, evidence: RoundEvidence) -> None:
        for report_run_id, digest in sorted(evidence.report_digests.items()):
            self._store.append_evidence(
                round_execution_id=round_execution_id,
                sg8_session_id=self._runner.sg8_session_id,
                report_run_id=report_run_id,
                canonical_digest=digest,
            )
