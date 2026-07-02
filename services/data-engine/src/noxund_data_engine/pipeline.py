"""Deterministic pipeline wiring (DATA-PIPELINE-001 · v1 composition).

This module is the *seam* that composes the four already-landed deterministic
zones into one pure function, in the ratified order (DEC-0017):

    Entity Resolution  ->  Channel Filter  ->  Popularity Scoring  ->  Opportunity

It reinvents **nothing**: every verdict, count, number and label is produced by
the existing engines through their public interfaces. The pipeline only *routes*
data between them and stamps run-level provenance onto each emitted row so any
published number is traceable back to the raw snapshot. No AI acts here; no
report number is model-generated (Entity Resolution's optional LLM boundary is
deliberately left OFF — ``llm=None`` — so the composition is 100% deterministic).

Design-only + pure. It touches NO database, NO network, NO secret, NO env, NO
real collection, NO wall clock. The input is an *in-memory synthetic snapshot*
(``raw_youtube_videos`` + ``raw_youtube_channels`` + the artist registry for one
``run_id``); the output is the ordered, provenance-stamped report rows a future
gated writer would persist to ``reports`` / ``report_items`` (matching the shape
of migration ``20260620000005_phase5_computed_metrics_reports.sql``).

Determinism (P5-REPRO-01). Same snapshot + same versioned configs ⇒ byte-identical
serialized rows, regardless of input row order. Guaranteed by construction: each
engine re-sorts its own inputs by a stable natural key, and the pipeline itself
addresses every video by its natural ``video_id`` (never dict-insertion order) and
carries the frozen ``window_end`` as the only temporal reference.

Provenance. Every ``ReportRow`` carries ``run_id``, ``artist_id``,
``rubric_version``/``rubric_hash`` (Scoring), ``rule_version``/``rule_hash``
(Channel Filter), ``resolver_version`` (Entity Resolution) and
``opportunity_version``/``opportunity_hash`` (Opportunity). The per-cell audit
(``selection_reason_json``) additionally embeds the effective versions, so a
rebuild never depends on a mutable table.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass, field
from datetime import datetime
from decimal import Decimal
from typing import Any, Mapping, Sequence

from .channel_filter import (
    DEFAULT_CONFIG as CHANNEL_FILTER_DEFAULT_CONFIG,
    ChannelFilter,
    ChannelRecord,
    FilterConfig,
    RunFilterResult,
    RunVideo,
)
from .entity_resolution import (
    RESOLVER_VERSION,
    EntityResolver,
    PendingCandidate,
    RawVideo,
    ResolutionDecision,
    ResolutionOutcome,
    normalize_for_match,
)
from .opportunity import (
    DEFAULT_CONFIG as OPPORTUNITY_DEFAULT_CONFIG,
    ArtistOpportunityInput,
    OpportunityBuilder,
    OpportunityConfig,
    OpportunityReport,
    ReportItem,
    ValidVideo,
)
from .scoring import (
    DEFAULT_RUBRIC,
    ArtistScore,
    ArtistScoringInput,
    PopularityScorer,
    RubricConfig,
    RunScoreResult,
    VideoStats,
)


PIPELINE_VERSION = "pipeline-wiring-2026_06_v1"


class PipelineError(RuntimeError):
    """Base error with a safe, non-PII message."""


class PipelineContractViolation(PipelineError):
    """The synthetic snapshot violated the pipeline contract (dup key, drift)."""


# ---------------------------------------------------------------------------
# Synthetic snapshot inputs (one run_id; verbatim raw + the artist registry).
# ---------------------------------------------------------------------------
@dataclass(frozen=True, slots=True)
class RawVideoRow:
    """One ``raw_youtube_videos`` row for the run (verbatim; NULL never coerced).

    ``source_title`` feeds Entity Resolution; ``channel_id`` joins the channel
    filter; ``views``/``likes``/``comments`` feed Scoring; ``published_at`` is the
    timezone-aware publication instant (age is measured against the frozen
    ``window_end``, never the wall clock).
    """

    video_id: str
    channel_id: str
    source_title: str | None
    views: int | None
    likes: int | None
    comments: int | None
    published_at: datetime


@dataclass(frozen=True, slots=True)
class ChannelRow:
    """One ``raw_youtube_channels`` row for the run.

    Only ``title`` is read in ``channel-filter-v1`` (self_channel). The size fields
    are carried but never evaluated (disabled gates); ``None`` means "no signal".
    """

    channel_id: str
    title: str | None = None
    subscriber_count: int | None = None
    view_count: int | None = None
    upload_count: int | None = None


@dataclass(frozen=True, slots=True)
class ArtistRow:
    """One ``artists`` row plus its ``artist_aliases`` (the resolution registry).

    ``canonical_name`` titles the report item; ``aliases`` widen the name set used
    for exact (normalized) resolution and for the Channel Filter's self_channel
    check. The pipeline resolves a video to an artist ONLY when the extracted name
    matches exactly one registered artist — mirroring the real system, where a new
    (unregistered) artist goes through human review, not auto-creation.
    """

    artist_id: str
    canonical_name: str
    aliases: tuple[str, ...] = ()


@dataclass(frozen=True, slots=True)
class PipelineSnapshot:
    """A deterministic in-memory snapshot for exactly one ``run_id``."""

    run_id: str
    report_title: str
    window_end: datetime
    videos: tuple[RawVideoRow, ...]
    channels: tuple[ChannelRow, ...] = ()
    artists: tuple[ArtistRow, ...] = ()


# ---------------------------------------------------------------------------
# Outputs.
# ---------------------------------------------------------------------------
@dataclass(frozen=True, slots=True)
class PipelineProvenance:
    """Run-level identity of every deterministic zone that produced the rows.

    These are the exact identifiers a rebuild needs: "same raw + these versions ⇒
    same report". They are stamped identically onto every ``ReportRow``.
    """

    run_id: str
    window_end: datetime
    pipeline_version: str
    resolver_version: str
    rule_version: str
    rule_hash: str
    rubric_version: str
    rubric_hash: str
    opportunity_version: str
    opportunity_hash: str


@dataclass(frozen=True, slots=True)
class ReportRow:
    """One ordered report line + full run-level provenance (write-contract shape).

    Mirrors a ``report_items`` row (``score_value``/``selection_reason_json`` are
    INTERNAL — SEC-F03) and additionally carries the run-scoped provenance so the
    row is self-describing and independently replayable.
    """

    run_id: str
    rank: int
    artist_id: str
    title: str
    tag: str | None
    score_display: str | None
    score_value: int
    signals: int
    velocity_display: str | None
    competition_level: str
    competition_channel_count: int
    example_video_id: str
    example_url: str
    selection_reason_json: dict[str, Any]
    rubric_version: str
    rubric_hash: str
    rule_version: str
    rule_hash: str
    resolver_version: str
    opportunity_version: str
    opportunity_hash: str


@dataclass(frozen=True, slots=True)
class PipelineResult:
    """Full deterministic output for one run + the intermediate audit artifacts.

    ``report`` is ``None`` only when the run has zero scorable artists (no valid
    video survived resolution + filtering) — an honest empty run. When at least one
    artist is scored, ``report`` is the Opportunity ``draft`` (possibly
    ``insufficient_opportunity`` if none clears the display gate).
    """

    provenance: PipelineProvenance
    resolution_outcomes: tuple[ResolutionOutcome, ...]
    filter_result: RunFilterResult
    score_result: RunScoreResult
    report: OpportunityReport | None
    rows: tuple[ReportRow, ...]
    unresolved_video_ids: tuple[str, ...] = field(default_factory=tuple)

    @property
    def insufficient_opportunity(self) -> bool:
        """True when no qualified opportunity exists (empty run OR all below gate)."""

        return self.report is None or self.report.insufficient_opportunity

    @property
    def scored_artist_ids(self) -> tuple[str, ...]:
        return tuple(score.artist_id for score in self.score_result.scores)


# ---------------------------------------------------------------------------
# In-memory adapters over the synthetic snapshot (implement the engines' ports).
# These are pure, side-effect-free stand-ins for the durable DB adapters; they
# hold no state that outlives one pipeline call and touch no I/O.
# ---------------------------------------------------------------------------
class _RegistryCatalog:
    """``ArtistCatalog`` over the snapshot registry (normalized name -> artist_ids)."""

    def __init__(self, name_index: Mapping[str, tuple[str, ...]]) -> None:
        self._index = name_index

    def find_artist_ids(self, normalized_name: str) -> Sequence[str]:
        return self._index.get(normalized_name, ())


class _RegistryNameCatalog:
    """``ArtistNameCatalog`` (self_channel): artist_id -> its canonical_name + aliases."""

    def __init__(self, names_by_artist: Mapping[str, tuple[str, ...]]) -> None:
        self._names = names_by_artist

    def names_for_artist(self, artist_id: str) -> Sequence[str]:
        return self._names.get(artist_id, ())


class _NullQueue:
    """No durable review queue in the deterministic replay (llm=None never enqueues)."""

    def get_pending(self, run_id: str, video_id: str) -> PendingCandidate | None:
        return None

    def enqueue_pending(self, candidate: PendingCandidate) -> PendingCandidate:
        # Unreachable with llm=None; present only to satisfy the port contract.
        return candidate


class _NullReplayFacts:
    """No prior persisted facts: a synthetic snapshot is resolved from scratch."""

    def get_final_fact(
        self, run_id: str, video_id: str, resolver_version: str
    ) -> ResolutionOutcome | None:
        return None

    def record_rejected_fact(self, outcome: ResolutionOutcome) -> None:
        # Unreachable with llm=None (only LLM-rejected facts are recorded).
        return None


# ---------------------------------------------------------------------------
# Registry indexing.
# ---------------------------------------------------------------------------
def _index_registry(
    artists: Sequence[ArtistRow],
) -> tuple[dict[str, tuple[str, ...]], dict[str, tuple[str, ...]], dict[str, str]]:
    """Build the three registry projections the engines consume.

    Returns ``(name_index, names_by_artist, canonical_by_artist)``:
    * ``name_index`` — normalized name -> sorted, de-duplicated artist_ids (a name
      shared by >1 artist is a collision that Entity Resolution routes to review);
    * ``names_by_artist`` — artist_id -> (canonical_name, *aliases) for self_channel;
    * ``canonical_by_artist`` — artist_id -> canonical_name for the report title.
    """

    name_index: dict[str, list[str]] = {}
    names_by_artist: dict[str, tuple[str, ...]] = {}
    canonical_by_artist: dict[str, str] = {}
    for artist in artists:
        if not artist.artist_id or not artist.artist_id.strip():
            raise PipelineContractViolation("artist_id must be non-blank")
        if artist.artist_id in canonical_by_artist:
            raise PipelineContractViolation("duplicate artist_id in the registry")
        if not artist.canonical_name or not artist.canonical_name.strip():
            raise PipelineContractViolation("canonical_name must be non-blank")
        canonical_by_artist[artist.artist_id] = artist.canonical_name
        names_by_artist[artist.artist_id] = (artist.canonical_name, *artist.aliases)
        for name in names_by_artist[artist.artist_id]:
            normalized = normalize_for_match(name)
            if not normalized:
                continue
            bucket = name_index.setdefault(normalized, [])
            if artist.artist_id not in bucket:
                bucket.append(artist.artist_id)
    frozen_index = {key: tuple(sorted(value)) for key, value in name_index.items()}
    return frozen_index, names_by_artist, canonical_by_artist


def _raw_by_id(videos: Sequence[RawVideoRow]) -> dict[str, RawVideoRow]:
    index: dict[str, RawVideoRow] = {}
    for video in videos:
        if not video.video_id or not video.video_id.strip():
            raise PipelineContractViolation("video_id must be non-blank")
        if video.video_id in index:
            raise PipelineContractViolation("duplicate video_id in the run snapshot")
        if not video.channel_id or not video.channel_id.strip():
            raise PipelineContractViolation("channel_id must be non-blank")
        index[video.video_id] = video
    return index


def _video_stats(row: RawVideoRow) -> VideoStats:
    return VideoStats(
        video_id=row.video_id,
        views=row.views,
        likes=row.likes,
        comments=row.comments,
        published_at=row.published_at,
    )


def _vel_index(score: ArtistScore) -> dict[str, Decimal | None]:
    """Per-video velocity CONSUMED from the Scoring audit (never recomputed here).

    ``metrics_detail_json.videos.accepted[]`` is the frozen per-video evidence; the
    ``vel`` string round-trips exactly through ``Decimal`` so Opportunity's Example
    ranks on the identical number Scoring produced.
    """

    index: dict[str, Decimal | None] = {}
    accepted = score.metrics_detail_json.get("videos", {}).get("accepted", ())
    for row in accepted:
        video_id = row.get("video_id")
        vel_str = row.get("vel")
        index[video_id] = None if vel_str is None else Decimal(vel_str)
    return index


# ---------------------------------------------------------------------------
# The pipeline.
# ---------------------------------------------------------------------------
def run_pipeline(
    snapshot: PipelineSnapshot,
    *,
    rubric: RubricConfig = DEFAULT_RUBRIC,
    filter_config: FilterConfig = CHANNEL_FILTER_DEFAULT_CONFIG,
    opportunity_config: OpportunityConfig = OPPORTUNITY_DEFAULT_CONFIG,
    resolver_version: str = RESOLVER_VERSION,
) -> PipelineResult:
    """Compose the four deterministic zones over one synthetic snapshot.

    Order (DEC-0017): Entity Resolution -> Channel Filter -> Scoring -> Opportunity.
    Pure and total: no I/O, no network, no DB, no LLM, no wall clock. Returns the
    ordered, provenance-stamped report rows plus the intermediate audit artifacts.
    """

    if not snapshot.run_id or not snapshot.run_id.strip():
        raise PipelineContractViolation("run_id must be non-blank")
    if not snapshot.report_title or not snapshot.report_title.strip():
        raise PipelineContractViolation("report_title must be non-blank")
    if snapshot.window_end.tzinfo is None or snapshot.window_end.utcoffset() is None:
        raise PipelineContractViolation("window_end must be timezone-aware (UTC)")

    raw_by_id = _raw_by_id(snapshot.videos)
    name_index, names_by_artist, canonical_by_artist = _index_registry(snapshot.artists)

    # -- Zone 1: Entity Resolution (regex-first; generative boundary OFF). --------
    resolver = EntityResolver(
        catalog=_RegistryCatalog(name_index),
        queue=_NullQueue(),
        replay_facts=_NullReplayFacts(),
        llm=None,
        resolver_version=resolver_version,
    )
    outcomes: list[ResolutionOutcome] = []
    mappings: list[tuple[str, str]] = []          # (video_id, artist_id) — final only
    unresolved: list[str] = []
    for video in snapshot.videos:                 # order-independent (per-video pure)
        outcome = resolver.resolve(
            RawVideo(
                run_id=snapshot.run_id,
                video_id=video.video_id,
                source_title=video.source_title,
            )
        )
        outcomes.append(outcome)
        is_final = (
            outcome.decision is ResolutionDecision.ACCEPTED
            and not outcome.needs_review
            and outcome.artist_id is not None
        )
        if is_final:
            mappings.append((video.video_id, outcome.artist_id))  # type: ignore[arg-type]
        else:
            unresolved.append(video.video_id)

    # -- Zone 2: Channel Filter (eligibility + per-artist Signals/Competition). ----
    run_videos = tuple(
        RunVideo(
            run_id=snapshot.run_id,
            video_id=video_id,
            channel_id=raw_by_id[video_id].channel_id,
            artist_id=artist_id,
            title=raw_by_id[video_id].source_title,
        )
        for video_id, artist_id in mappings
    )
    channels = tuple(
        ChannelRecord(
            run_id=snapshot.run_id,
            channel_id=channel.channel_id,
            title=channel.title,
            subscriber_count=channel.subscriber_count,
            view_count=channel.view_count,
            upload_count=channel.upload_count,
        )
        for channel in snapshot.channels
    )
    filter_result = ChannelFilter(
        catalog=_RegistryNameCatalog(names_by_artist), config=filter_config
    ).evaluate_run(run_id=snapshot.run_id, videos=run_videos, channels=channels)

    # -- Zone 3: Popularity Scoring (deterministic Score + 4 components). ---------
    scoring_inputs = tuple(
        ArtistScoringInput(
            artist_id=projection.artist_id,
            videos=tuple(_video_stats(raw_by_id[vid]) for vid in projection.valid_video_ids),
            projection=projection,
        )
        for projection in filter_result.projections
        if projection.signals > 0
    )
    score_result = PopularityScorer(
        config=rubric,
        resolver_version=resolver_version,
        rule_version=filter_config.rule_version,
    ).score_run(
        run_id=snapshot.run_id,
        artists=scoring_inputs,
        window_end=snapshot.window_end,
    )

    provenance = PipelineProvenance(
        run_id=snapshot.run_id,
        window_end=snapshot.window_end,
        pipeline_version=PIPELINE_VERSION,
        resolver_version=resolver_version,
        rule_version=filter_result.rule_version,
        rule_hash=filter_result.rule_hash,
        rubric_version=score_result.rubric_version,
        rubric_hash=score_result.rubric_hash,
        opportunity_version=opportunity_config.opportunity_version,
        opportunity_hash=opportunity_config.opportunity_hash,
    )

    # -- Zone 4: Opportunity (rank, gate, HOT, Competition, Example). -------------
    opportunity_inputs = tuple(
        ArtistOpportunityInput(
            score=score,
            valid_videos=tuple(
                ValidVideo(
                    video_id=vid,
                    views=raw_by_id[vid].views,
                    published_at=raw_by_id[vid].published_at,
                    vel=vel.get(vid),
                )
                for vid in score.contributing_video_ids
            ),
            canonical_name=canonical_by_artist[score.artist_id],
        )
        for score, vel in ((s, _vel_index(s)) for s in score_result.scores)
    )

    if not opportunity_inputs:
        # Honest empty run: no artist survived resolution + filtering to be scored.
        return PipelineResult(
            provenance=provenance,
            resolution_outcomes=tuple(outcomes),
            filter_result=filter_result,
            score_result=score_result,
            report=None,
            rows=(),
            unresolved_video_ids=tuple(sorted(unresolved)),
        )

    report = OpportunityBuilder(config=opportunity_config).build_report(
        run_id=snapshot.run_id,
        report_title=snapshot.report_title,
        artists=opportunity_inputs,
        window_end=snapshot.window_end,
    )
    rows = tuple(_report_row(item, provenance) for item in report.items)
    return PipelineResult(
        provenance=provenance,
        resolution_outcomes=tuple(outcomes),
        filter_result=filter_result,
        score_result=score_result,
        report=report,
        rows=rows,
        unresolved_video_ids=tuple(sorted(unresolved)),
    )


def _report_row(item: ReportItem, provenance: PipelineProvenance) -> ReportRow:
    return ReportRow(
        run_id=provenance.run_id,
        rank=item.rank,
        artist_id=item.artist_id,
        title=item.title,
        tag=item.tag,
        score_display=item.score_display,
        score_value=item.score_value,
        signals=item.signals,
        velocity_display=item.velocity_display,
        competition_level=item.competition_level,
        competition_channel_count=item.competition_channel_count,
        example_video_id=item.example_video_id,
        example_url=item.example_url,
        selection_reason_json=item.selection_reason_json,
        rubric_version=item.rubric_version,
        rubric_hash=item.rubric_hash,
        rule_version=provenance.rule_version,
        rule_hash=provenance.rule_hash,
        resolver_version=provenance.resolver_version,
        opportunity_version=provenance.opportunity_version,
        opportunity_hash=provenance.opportunity_hash,
    )


# ---------------------------------------------------------------------------
# Deterministic serialization (the P5-REPRO-01 comparison surface).
# ---------------------------------------------------------------------------
def _row_to_dict(row: ReportRow) -> dict[str, Any]:
    return {
        "run_id": row.run_id,
        "rank": row.rank,
        "artist_id": row.artist_id,
        "title": row.title,
        "tag": row.tag,
        "score_display": row.score_display,
        "score_value": row.score_value,
        "signals": row.signals,
        "velocity_display": row.velocity_display,
        "competition_level": row.competition_level,
        "competition_channel_count": row.competition_channel_count,
        "example_video_id": row.example_video_id,
        "example_url": row.example_url,
        "selection_reason_json": row.selection_reason_json,
        "rubric_version": row.rubric_version,
        "rubric_hash": row.rubric_hash,
        "rule_version": row.rule_version,
        "rule_hash": row.rule_hash,
        "resolver_version": row.resolver_version,
        "opportunity_version": row.opportunity_version,
        "opportunity_hash": row.opportunity_hash,
    }


def canonical_report(result: PipelineResult) -> dict[str, Any]:
    """A JSON-native, deterministic snapshot of the run's public output + provenance.

    This is the exact surface P5-REPRO-01 compares and hashes: the ordered rows,
    the insufficiency flag, and the frozen version identities. It excludes the
    heavy intermediate audit artifacts (they are reconstructable) but keeps every
    field that reaches the report.
    """

    provenance = result.provenance
    return {
        "run_id": provenance.run_id,
        "window_end": provenance.window_end.isoformat(),
        "pipeline_version": provenance.pipeline_version,
        "insufficient_opportunity": result.insufficient_opportunity,
        "provenance": {
            "resolver_version": provenance.resolver_version,
            "rule_version": provenance.rule_version,
            "rule_hash": provenance.rule_hash,
            "rubric_version": provenance.rubric_version,
            "rubric_hash": provenance.rubric_hash,
            "opportunity_version": provenance.opportunity_version,
            "opportunity_hash": provenance.opportunity_hash,
        },
        "rows": [_row_to_dict(row) for row in result.rows],
    }


def canonical_json(result: PipelineResult) -> str:
    """Canonical JSON: sorted keys, no whitespace, UTF-8 preserving (byte-stable)."""

    return json.dumps(
        canonical_report(result),
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    )


def pipeline_digest(result: PipelineResult) -> str:
    """``sha256(canonical_json(result))`` — the golden hash of the run's output.

    Any change to a produced number, order, label, or frozen version identity
    necessarily changes this digest, forcing a new ``rubric_version`` /
    ``rule_version`` / ``opportunity_version`` rather than a silent edit.
    """

    return hashlib.sha256(canonical_json(result).encode("utf-8")).hexdigest()
