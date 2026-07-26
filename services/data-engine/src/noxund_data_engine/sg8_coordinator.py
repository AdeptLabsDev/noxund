"""Driver-agnostic wiring between the SG-8 runner and ``PostgresSg8Store`` (U2B).

U2B of DATA-SG8-001 stage 3 part 2, revised by DEC-0025 (LLM decoupling). This is the
**smallest** layer that lets the live integration drive the durable store from the
runner's own results, for the E2E test against a disposable local Supabase. It is
**driver-free** (imports no database driver; the real connection is injected upstream by
the integration bootstrap), **offline** and **provider-neutral** (no LLM, model or
external provider anywhere).

What this layer MAY do (and only this):
  * translate the results/events the runner already produced into store calls;
  * mint application-owned ids through an injected :class:`IdFactory`;
  * build the **deterministic compute provenance** (:func:`build_compute_provenance`),
    deriving the canonical ``compute_manifest_hash`` from the versioned artifacts +
    configuration that actually determine the result (:func:`canonical_compute_manifest`);
  * persist the SAME provenance for Round 1 and Round 2;
  * coordinate persistence and resume.

What this layer MUST NOT do:
  * create a second finite-state machine — it never *decides* a transition, it mirrors
    the state the runner reports and lets the schema (0008) reject an illegal one;
  * duplicate the PASS gate — ``mark_passed`` is issued to the store, and the schema's
    PASS gate independently accepts/rejects it (including manifest equality R1==R2);
  * recompute or reinterpret any score/digest — Round-1 digests are taken verbatim from
    the runner's ``RoundEvidence``; on PASS the runner's verdict CERTIFIES Round 2 is
    byte-identical to Round 1, so the same digests are persisted as Round-2 evidence and
    the schema re-verifies the equality (no recomputation here);
  * alter the canonical payload, versions or the golden digest — it touches none of them;
  * make any external/network call.

Transition legality lives in the runner (``sg8_runner.Sg8Session``) and — authoritatively
— in the schema. ``sg8_runner`` is imported and driven **unchanged**.
"""

from __future__ import annotations

import hashlib
import itertools
import json
import uuid
from typing import Protocol, Sequence

from .channel_filter import DEFAULT_CONFIG as CHANNEL_FILTER_DEFAULT_CONFIG
from .entity_resolution import RESOLVER_VERSION
from .opportunity import DEFAULT_CONFIG as OPPORTUNITY_DEFAULT_CONFIG
from .pipeline import PIPELINE_VERSION
from .postgres_sg8 import (
    SG8_COMPARISON_CONTRACT_VERSION,
    Sg8ComputeProvenance,
    Sg8Store,
)
from .scoring import DEFAULT_RUBRIC
from .sg8_runner import (
    ReviewDecision,
    RoundEvidence,
    Sg8Session,
    Sg8SessionInput,
    Sg8State,
    Sg8Verdict,
)


# The deterministic engine identity SG-8 records for every round (never a model id).
# The "engine" IS the deterministic pipeline composition; its version is PIPELINE_VERSION.
COMPUTE_ENGINE_NAME = "noxund-pipeline"
# Version of the manifest SCHEMA itself: the set/serialization of determinants below. Bump
# it whenever a determinant is added/removed so the manifest hash necessarily changes.
COMPUTE_MANIFEST_FORMAT_VERSION = "sg8-compute-manifest-v1"

# SG8_COMPARISON_CONTRACT_VERSION is imported (and thus re-exported) from the adapter so the
# coordinator's canonical open path and its callers share ONE source of truth for the
# comparison-contract identity. It is DELIBERATELY absent from the compute manifest below:
# compute_manifest_hash identifies the CONDITIONS that PRODUCE the result;
# SG8_COMPARISON_CONTRACT_VERSION identifies the RULES that JUDGE Round 1 vs Round 2.


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
# Compute manifest — the canonical, versioned hash of what determines the result.
# ---------------------------------------------------------------------------
def canonical_compute_manifest(
    *,
    manifest_format_version: str,
    engine_name: str,
    engine_version: str,
    pipeline_version: str,
    resolver_version: str,
    rule_version: str,
    rule_hash: str,
    rubric_version: str,
    rubric_hash: str,
    opportunity_version: str,
    opportunity_hash: str,
) -> str:
    """Canonical §DEC-0025 derivation of ``compute_manifest_hash``.

    The manifest is the ordered, versioned identity of EVERY computational determinant of
    the report — everything that can change resolution / scoring / opportunity / the
    canonical payload / the per-report digests / the comparison decision, EXCEPT the input
    data (which is protected by the frozen snapshot):

      * ``manifest_format_version`` — the version of the manifest schema itself, so adding
        or removing a determinant necessarily changes the hash;
      * ``engine_name`` + ``engine_version`` — the deterministic engine identity (the
        pipeline composition; ``engine_version`` == ``pipeline_version``);
      * ``pipeline_version`` — the composition/wiring version (DEC-0017 order);
      * ``resolver_version`` — entity-resolution algorithm identity;
      * ``rule_version`` + ``rule_hash`` — channel-filter ruleset;
      * ``rubric_version`` + ``rubric_hash`` — scoring rubric;
      * ``opportunity_version`` + ``opportunity_hash`` — opportunity rules.

    It DELIBERATELY excludes: session/round ids, timestamps, credentials, local paths,
    unstable values, and the persistence-adapter identity (persistence does NOT participate
    in the computation). There are NO free-form runtime parameters: every knob that affects
    the result lives inside a versioned config and is captured by its version + hash above.

    Serialized canonically — ``json.dumps(sort_keys=True, separators=(",",":"), ensure_ascii=False)``
    — so key ORDER never affects the hash; then SHA-256 → 64 lowercase hex chars. Identical
    determinants ⇒ identical manifest; any single determinant change flips it. There is no
    prompt/model/provider hash and no silent fallback to a hardcoded constant — the value is
    always derived from these sources of truth.
    """
    manifest = {
        "manifest_format_version": manifest_format_version,
        "engine_name": engine_name,
        "engine_version": engine_version,
        "pipeline_version": pipeline_version,
        "resolver_version": resolver_version,
        "rule_version": rule_version,
        "rule_hash": rule_hash,
        "rubric_version": rubric_version,
        "rubric_hash": rubric_hash,
        "opportunity_version": opportunity_version,
        "opportunity_hash": opportunity_hash,
    }
    canonical = json.dumps(
        manifest, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    )
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def default_compute_manifest() -> str:
    """The canonical manifest DERIVED from the frozen default configs (golden-digest lineage).

    Every value is read from its source of truth (``PIPELINE_VERSION``, ``RESOLVER_VERSION``,
    and the DEFAULT config objects' version/hash) — never a hardcoded digest. Tests pin the
    resulting value only as a golden fixture that is re-derived and compared here.
    """
    return canonical_compute_manifest(
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


def build_compute_provenance(*, manifest_hash: str | None = None) -> Sg8ComputeProvenance:
    """Build the deterministic ``Sg8ComputeProvenance`` persisted for every round.

    Carries only the COMPUTATIONAL identity: ``engine_name`` + ``engine_version`` (also
    inside the manifest, for explicit PASS-gate defense-in-depth) and the derived
    ``compute_manifest_hash`` (default = :func:`default_compute_manifest`). No persistence
    adapter, no free-form params, no provider/model/prompt.

    The SAME provenance is persisted for Round 1 and Round 2; the schema PASS gate
    independently re-checks engine identity + manifest equality R1==R2.
    """
    return Sg8ComputeProvenance(
        engine_name=COMPUTE_ENGINE_NAME,
        engine_version=PIPELINE_VERSION,
        manifest_hash=manifest_hash or default_compute_manifest(),
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
    digest. Both rounds persist the SAME deterministic compute provenance.
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
        self._round2_evidence: RoundEvidence | None = None
        self._compute_provenance: Sg8ComputeProvenance | None = None

    # -- accessors (for assertions/resume) ------------------------------------
    @property
    def session_id(self) -> str:
        return self._runner.sg8_session_id

    @property
    def resolution_snapshot_id(self) -> str | None:
        return self._snapshot_id

    def round_execution_id(self, round_number: int) -> str | None:
        return self._round_ids.get(round_number)

    @property
    def round2_evidence(self) -> RoundEvidence | None:
        """The REAL evidence Round 2 produced (what was persisted for round_number = 2)."""
        return self._round2_evidence

    @property
    def comparison_contract_version(self) -> str:
        """The comparison contract every session opened by this coordinator is judged under.

        Provider-neutral, versioned identity of the R1-vs-R2 gate semantics — the single
        canonical constant the store persists at :meth:`open_session`. It is NOT a compute
        determinant: it never enters :func:`canonical_compute_manifest` / the manifest hash.
        """
        return SG8_COMPARISON_CONTRACT_VERSION

    # -- lifecycle mirror ------------------------------------------------------
    def open_session(self) -> None:
        # The canonical open path: the store persists SG8_COMPARISON_CONTRACT_VERSION explicitly
        # (no PG default, no caller-supplied value) — every session is born under the implemented
        # gate contract, separate from the compute manifest.
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
        provenance: Sg8ComputeProvenance,
        report_run_id_1: str,
        report_run_id_2: str,
    ) -> RoundEvidence:
        if self._snapshot_id is None:
            raise RuntimeError("freeze() must precede compute_round1()")
        # The deterministic compute provenance is captured ONCE and reused verbatim for
        # Round 2 — same engine, same versioned artifacts, same compute_manifest_hash.
        self._compute_provenance = provenance
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

    def run_round2(self) -> Sg8Verdict:
        if self._snapshot_id is None:
            raise RuntimeError("compute_round1() must precede run_round2()")
        if self._compute_provenance is None:
            raise RuntimeError("compute_round1() must set the compute provenance first")
        round_id = self._ids.new_id()
        # Round 2 is computed EXACTLY ONCE by the runner; we persist the evidence it
        # ACTUALLY produced — never Round 1's, never inferred from PASS, never recomputed.
        result = self._runner.run_round2_result(round_execution_id=round_id)
        # Round 2 persists the SAME deterministic compute provenance as Round 1 (identical
        # engine + manifest). The schema PASS gate independently re-checks manifest equality.
        self._store.append_round(
            round_execution_id=round_id,
            sg8_session_id=self._runner.sg8_session_id,
            round_number=2,
            source_collection_run_id=self._src,
            resolution_snapshot_id=self._snapshot_id,
            provenance=self._compute_provenance,
        )
        self._round_ids[2] = round_id
        self._round2_evidence = result.evidence
        # Persist Round 2's own per-report digests (present unless Round 2 failed before
        # producing any evidence). The schema PASS gate independently compares R1 vs R2.
        if result.evidence is not None:
            self._persist_evidence(round_id, result.evidence)
        if result.verdict.passed:
            self._store.mark_passed(
                self._runner.sg8_session_id, verdict_reason=result.verdict.reason
            )
        else:
            self._store.mark_failed(
                self._runner.sg8_session_id, verdict_reason=result.verdict.reason
            )
        return result.verdict

    def _persist_evidence(self, round_execution_id: str, evidence: RoundEvidence) -> None:
        for report_run_id, digest in sorted(evidence.report_digests.items()):
            self._store.append_evidence(
                round_execution_id=round_execution_id,
                sg8_session_id=self._runner.sg8_session_id,
                report_run_id=report_run_id,
                canonical_digest=digest,
            )
