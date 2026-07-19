"""Deterministic Channel Filter core (DATA-CHANNEL-001 · channel-filter-v1).

This is the first purely deterministic zone after Entity Resolution. No AI acts
here and no product number is model-generated: every verdict and count is a pure
function of the run's videos, the channel titles, and the frozen config, keyed by
the natural ``(run_id, channel_id)``.

``channel-filter-v1`` is intentionally *minimalist* (DEC-0017, ratified
2026-07-01). Only two gates are active, evaluated in a fixed order so the
``reason_code`` is deterministic:

1. ``self_channel`` — the artist's own channel is not a competing producer, so it
   is excluded from that artist's Competition. Matching is an *exact* comparison
   over the normalized form (no fuzzy) reusing ``normalize_for_match`` from the
   entity resolver.
2. ``run_domination`` — a single channel contributing **> 60** videos within the
   run is marked ineligible (guards extreme single-channel domination). Exactly
   60 stays eligible.

All size/history/duplicate gates from the design proposal are **disabled** in v1
(``MIN_PUBLIC_UPLOADS``, ``MIN_SUBSCRIBERS``, ``MIN_CHANNEL_VIEWS``,
``DUP_TITLE_CAP``). Where the spec's 4-gate proposal conflicts with DEC-0017,
DEC-0017 wins. NULL channel statistics are never coerced to zero.

Fail-closed precondition (DC2-01 · DEC-0022, amends DEC-0019 §2). Every channel in
the run footprint MUST carry a raw ``ChannelRecord``. Gated collection owns and
proves completeness upstream (§7); the filter reaffirms the same invariant here as
the last line of defense — a missing record raises ``ContractViolation`` *before*
any verdict, Competition or Signals is produced, never a silent tolerant pass. A
record with ``title=None`` still counts as present ("no signal" ≠ "no record"). This
is a contract precondition, not a gate change: gate order, constants, ``rule_version``
and ``rule_hash`` are untouched and the golden digest is unchanged.

No DB, secret, network, LLM, or real collection is touched. Verdicts are returned
in memory; a future gated writer persists them to ``channel_eligibility``.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from enum import StrEnum
from typing import Any, Mapping, Protocol, Sequence

from .entity_resolution import normalize_for_match


RULE_VERSION = "channel-filter-v1"

# The single active quantitative gate: a channel with strictly more than this many
# distinct videos in the run is ineligible (run_domination). 60 is eligible.
MAX_RUN_VIDEOS_PER_CHANNEL = 60

# Normalizer identity frozen into the rule hash. channel-filter-v1 reuses the
# entity resolver's contract verbatim rather than reinventing normalization.
NORMALIZER_ID = "entity-resolver-v1:normalize_for_match"

# Gates explicitly disabled in v1. Serialized into the frozen config so that
# re-enabling any of them necessarily changes rule_hash and requires a new
# rule_version (channel-filter-v2).
_DISABLED_GATES = (
    "MIN_PUBLIC_UPLOADS",
    "MIN_SUBSCRIBERS",
    "MIN_CHANNEL_VIEWS",
    "DUP_TITLE_CAP",
)


class ReasonCode(StrEnum):
    """Closed allow-list of machine-readable eligibility reasons (v1)."""

    ELIGIBLE = "eligible"
    SELF_CHANNEL = "self_channel"
    RUN_DOMINATION = "run_domination"
    HUMAN_OVERRIDE = "human_override"


class ChannelFilterError(RuntimeError):
    """Base error with a safe, non-PII message."""


class ContractViolation(ChannelFilterError):
    """An input violated the channel-filter contract.

    E.g. a blank key, a run mismatch, or a channel present in the run footprint with
    no raw ``ChannelRecord`` (fail-closed DC2-01 · DEC-0022).
    """


@dataclass(frozen=True, slots=True)
class FilterConfig:
    """Frozen configuration of channel-filter-v1.

    Only ``max_run_videos_per_channel`` is an active constant; the disabled gates
    are recorded in the canonical form so the hash covers the *whole* rule. Any
    change to a constant, gate order, normalizer, or allow-list must ship as a new
    ``rule_version`` — never a silent edit of v1.
    """

    rule_version: str = RULE_VERSION
    max_run_videos_per_channel: int = MAX_RUN_VIDEOS_PER_CHANNEL

    def canonical(self) -> dict[str, Any]:
        """Deterministic, JSON-serializable snapshot hashed into ``rule_hash``."""

        return {
            "rule_version": self.rule_version,
            "normalizer": NORMALIZER_ID,
            "gates_ordered": [
                ReasonCode.SELF_CHANNEL.value,
                ReasonCode.RUN_DOMINATION.value,
            ],
            "reason_codes": [code.value for code in ReasonCode],
            "constants": {
                "MAX_RUN_VIDEOS_PER_CHANNEL": self.max_run_videos_per_channel,
                **{gate: "disabled" for gate in _DISABLED_GATES},
            },
        }

    @property
    def rule_hash(self) -> str:
        """``sha256(canonical_json(config))`` — stable across runs and processes."""

        return hashlib.sha256(_canonical_json(self.canonical()).encode("utf-8")).hexdigest()


DEFAULT_CONFIG = FilterConfig()


@dataclass(frozen=True, slots=True)
class RunVideo:
    """One final-mapped video within a run.

    ``needs_review = false`` filtering happens upstream (Entity Resolution); only
    final mappings reach the Channel Filter. ``title`` is the *video* title and is
    deliberately **not** evaluated in v1 (DUP_TITLE_CAP disabled); it is carried so
    the disabled gate is auditable and re-enabling it is a visible change.
    """

    run_id: str
    video_id: str
    channel_id: str
    artist_id: str
    title: str | None = None


@dataclass(frozen=True, slots=True)
class ChannelRecord:
    """Channel-level raw signals (``raw_youtube_channels``) for one run.

    Only ``title`` is read in v1 (self_channel). ``subscriber_count`` /
    ``view_count`` / ``upload_count`` are carried but **never evaluated** (size and
    history gates disabled); ``None`` means "no signal" and is never treated as 0.
    """

    run_id: str
    channel_id: str
    title: str | None = None
    subscriber_count: int | None = None
    view_count: int | None = None
    upload_count: int | None = None


@dataclass(frozen=True, slots=True)
class ChannelVerdict:
    """Single deterministic verdict per ``(run_id, channel_id)``."""

    run_id: str
    channel_id: str
    is_eligible: bool
    reason_code: ReasonCode
    rule_version: str
    rule_hash: str
    run_video_count: int
    reviewed_by_human: bool = False


@dataclass(frozen=True, slots=True)
class ArtistProjection:
    """Signals/Competition projection for one artist over its ``ValidVideos``.

    Both cardinalities derive from the *same* filtered set. ``valid_video_ids`` is
    deduped by ``video_id`` (Signals); ``eligible_channel_ids`` is the distinct set
    of eligible channels contributing at least one valid video (Competition). A
    prolific eligible channel inflates Signals by many videos but adds at most +1
    to Competition; an ineligible channel drops from *both* simultaneously.
    """

    artist_id: str
    valid_video_ids: tuple[str, ...]
    eligible_channel_ids: tuple[str, ...]

    @property
    def signals(self) -> int:
        return len(self.valid_video_ids)

    @property
    def competition(self) -> int:
        return len(self.eligible_channel_ids)


@dataclass(frozen=True, slots=True)
class RunFilterResult:
    """Full deterministic output for one run: verdicts + per-artist projections."""

    run_id: str
    rule_version: str
    rule_hash: str
    verdicts: tuple[ChannelVerdict, ...]
    projections: tuple[ArtistProjection, ...]

    def verdict_for(self, channel_id: str) -> ChannelVerdict | None:
        for verdict in self.verdicts:
            if verdict.channel_id == channel_id:
                return verdict
        return None

    def projection_for(self, artist_id: str) -> ArtistProjection | None:
        for projection in self.projections:
            if projection.artist_id == artist_id:
                return projection
        return None

    def eligible_channel_ids(self) -> tuple[str, ...]:
        return tuple(v.channel_id for v in self.verdicts if v.is_eligible)


class ArtistNameCatalog(Protocol):
    """Raw ``canonical_name`` + ``artist_aliases.alias`` per artist for self_channel.

    Names are returned verbatim; the engine normalizes them with
    ``normalize_for_match`` so normalization stays owned by a single contract.
    """

    def names_for_artist(self, artist_id: str) -> Sequence[str]: ...


def _canonical_json(payload: Any) -> str:
    """Canonical JSON: sorted keys, no whitespace, UTF-8 preserving."""

    return json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def _require_nonblank(value: str, field: str) -> None:
    if not isinstance(value, str) or not value.strip():
        raise ContractViolation(f"{field} must be non-blank")


def run_video_ids_by_channel(videos: Sequence[RunVideo]) -> dict[str, set[str]]:
    """Distinct ``video_id`` set per channel — the run footprint (dedup by video)."""

    footprint: dict[str, set[str]] = {}
    for video in videos:
        footprint.setdefault(video.channel_id, set()).add(video.video_id)
    return footprint


def artist_ids_by_channel(videos: Sequence[RunVideo]) -> dict[str, set[str]]:
    """Artists a channel is linked to in the run (from final mappings)."""

    links: dict[str, set[str]] = {}
    for video in videos:
        links.setdefault(video.channel_id, set()).add(video.artist_id)
    return links


def is_self_channel(normalized_title: str, normalized_artist_names: frozenset[str]) -> bool:
    """Exact match of the normalized channel title against a normalized name set.

    Empty titles never match (a blank normalized title is "no signal", not a
    collision with an empty alias).
    """

    if not normalized_title:
        return False
    return normalized_title in normalized_artist_names


class ChannelFilter:
    """Deterministic ``channel-filter-v1`` engine over a single run's inputs."""

    def __init__(
        self,
        *,
        catalog: ArtistNameCatalog,
        config: FilterConfig = DEFAULT_CONFIG,
    ) -> None:
        _require_nonblank(config.rule_version, "rule_version")
        self._catalog = catalog
        self._config = config

    @property
    def config(self) -> FilterConfig:
        return self._config

    def evaluate_run(
        self,
        *,
        run_id: str,
        videos: Sequence[RunVideo],
        channels: Sequence[ChannelRecord] = (),
        human_overrides: Mapping[str, bool] | None = None,
    ) -> RunFilterResult:
        """Compute one verdict per judged channel and per-artist projections.

        ``human_overrides`` maps ``channel_id -> is_eligible`` and models a recorded
        human review decision (which lives in ``audit_events``); it is never
        model-generated. Only channels contributing at least one video are judged.

        Fail-closed (DC2-01 · DEC-0022): every channel in the run footprint must carry
        a raw ``ChannelRecord``; otherwise ``ContractViolation`` is raised before any
        verdict, Competition or Signals is produced. A human override does not exempt a
        channel from this precondition — the channel was still collected.
        """

        _require_nonblank(run_id, "run_id")
        self._assert_run_scope(run_id, videos, channels)
        overrides = human_overrides or {}

        footprint = run_video_ids_by_channel(videos)
        self._assert_channel_records_present(footprint, channels)
        links = artist_ids_by_channel(videos)
        titles = {record.channel_id: record.title for record in channels}

        verdicts = tuple(
            self._classify(
                run_id=run_id,
                channel_id=channel_id,
                normalized_title=normalize_for_match(titles.get(channel_id)),
                run_video_count=len(footprint[channel_id]),
                linked_artist_ids=links[channel_id],
                override=overrides.get(channel_id),
            )
            for channel_id in sorted(footprint)
        )

        eligibility = {verdict.channel_id: verdict.is_eligible for verdict in verdicts}
        projections = self._project(videos, eligibility)
        return RunFilterResult(
            run_id=run_id,
            rule_version=self._config.rule_version,
            rule_hash=self._config.rule_hash,
            verdicts=verdicts,
            projections=projections,
        )

    def _classify(
        self,
        *,
        run_id: str,
        channel_id: str,
        normalized_title: str,
        run_video_count: int,
        linked_artist_ids: set[str],
        override: bool | None,
    ) -> ChannelVerdict:
        if override is not None:
            return self._verdict(
                run_id, channel_id, override, ReasonCode.HUMAN_OVERRIDE,
                run_video_count, reviewed_by_human=True,
            )

        # Gate 1 (fixed order): self_channel — exact normalized title match against
        # the canonical_name/aliases of any artist the channel is linked to.
        if is_self_channel(normalized_title, self._normalized_names(linked_artist_ids)):
            return self._verdict(
                run_id, channel_id, False, ReasonCode.SELF_CHANNEL, run_video_count
            )

        # Gate 2: run_domination — strictly more than 60 distinct videos in the run.
        if run_video_count > self._config.max_run_videos_per_channel:
            return self._verdict(
                run_id, channel_id, False, ReasonCode.RUN_DOMINATION, run_video_count
            )

        return self._verdict(
            run_id, channel_id, True, ReasonCode.ELIGIBLE, run_video_count
        )

    def _normalized_names(self, artist_ids: set[str]) -> frozenset[str]:
        names: set[str] = set()
        for artist_id in artist_ids:
            for raw_name in self._catalog.names_for_artist(artist_id):
                normalized = normalize_for_match(raw_name)
                if normalized:
                    names.add(normalized)
        return frozenset(names)

    def _verdict(
        self,
        run_id: str,
        channel_id: str,
        is_eligible: bool,
        reason_code: ReasonCode,
        run_video_count: int,
        *,
        reviewed_by_human: bool = False,
    ) -> ChannelVerdict:
        return ChannelVerdict(
            run_id=run_id,
            channel_id=channel_id,
            is_eligible=is_eligible,
            reason_code=reason_code,
            rule_version=self._config.rule_version,
            rule_hash=self._config.rule_hash,
            run_video_count=run_video_count,
            reviewed_by_human=reviewed_by_human,
        )

    @staticmethod
    def _project(
        videos: Sequence[RunVideo], eligibility: Mapping[str, bool]
    ) -> tuple[ArtistProjection, ...]:
        valid_videos: dict[str, set[str]] = {}
        eligible_channels: dict[str, set[str]] = {}
        all_artists: set[str] = set()
        for video in videos:
            all_artists.add(video.artist_id)
            if not eligibility.get(video.channel_id, False):
                continue
            valid_videos.setdefault(video.artist_id, set()).add(video.video_id)
            eligible_channels.setdefault(video.artist_id, set()).add(video.channel_id)

        return tuple(
            ArtistProjection(
                artist_id=artist_id,
                valid_video_ids=tuple(sorted(valid_videos.get(artist_id, ()))),
                eligible_channel_ids=tuple(sorted(eligible_channels.get(artist_id, ()))),
            )
            for artist_id in sorted(all_artists)
        )

    @staticmethod
    def _assert_channel_records_present(
        footprint: Mapping[str, set[str]], channels: Sequence[ChannelRecord]
    ) -> None:
        """Fail-closed (DC2-01 · DEC-0022, amends DEC-0019 §2).

        Every channel contributing at least one video to the run MUST have a raw
        ``ChannelRecord``. Gated collection guarantees this upstream and proves it via
        §7; the filter reaffirms it here as the last line of defense instead of
        silently tolerating a gap. Raised before any verdict / Competition / Signals.
        A record with ``title=None`` counts as present ("no signal" ≠ "no record"), so
        a complete run stays byte-identical to the prior output.
        """

        recorded = {record.channel_id for record in channels}
        if any(channel_id not in recorded for channel_id in footprint):
            raise ContractViolation(
                "every channel in the run footprint requires a raw ChannelRecord"
            )

    @staticmethod
    def _assert_run_scope(
        run_id: str, videos: Sequence[RunVideo], channels: Sequence[ChannelRecord]
    ) -> None:
        for video in videos:
            _require_nonblank(video.video_id, "video_id")
            _require_nonblank(video.channel_id, "channel_id")
            _require_nonblank(video.artist_id, "artist_id")
            if video.run_id != run_id:
                raise ContractViolation("video does not belong to the evaluated run")
        for record in channels:
            if record.run_id != run_id:
                raise ContractViolation("channel does not belong to the evaluated run")
