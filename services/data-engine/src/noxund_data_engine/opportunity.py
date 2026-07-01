"""Deterministic Opportunity core (DATA-OPP-001 · opportunity-rules-2026_06_v1).

Agente 6 — the terminal node of the deterministic pipeline and the **third and
last purely deterministic zone** (after Channel Filter and Scoring). No AI acts
here and no product number is model-generated: ranking, the HOT tag, the display
gate, Competition Low/Medium/High and the Example are pure functions of numbers
already frozen upstream (``final_score`` + the normalized components +
``channel_diversity_count`` from ``DATA-SCORING-001``; the per-artist ValidVideos
from ``DATA-CHANNEL-001``) plus the frozen ``OpportunityConfig``. The Score is
**consumed, never recomputed**; Competition = distinct eligible channels is
**consumed**, never redefined.

Ratified in DEC-0017 (items 1/2/3) and LOCKED here (never re-decided):

* **OPP-02 (HOT — honest cap of 2).** ``tag='HOT'`` only if ``final_score > 90``
  (strict). A report shows **0, 1 or 2** HOT — "at most 2, honest". An artist with
  ``score <= 90`` is **never** promoted to fill a visual quota. If more than two
  cross 90, only the top two (by the ranking key) get the badge; if fewer than two
  cross 90, fewer HOT are shown.
* **OPP-03 (ranking — total order).** ``final_score DESC`` → ``velocity_component
  DESC`` → ``signals_component DESC`` → ``artist_id ASC``. ``velocity_component`` /
  ``signals_component`` are ``ArtistScore.components.norm_velocity`` /
  ``norm_signals`` (the normalized Score components), consumed verbatim. The final
  ``artist_id`` key guarantees a byte-stable total order.
* **OPP-06 (composition).** Up to **10** qualified artists; **display/qualification
  gate ``score >= 83``**; HOT on up to two with ``score > 90``. If fewer than 10
  qualify, fewer are shown; a slot is **never** filled with ``score < 83``. If
  **no** artist qualifies (all ``< 83``) the report is marked
  ``insufficient_opportunity`` with zero items. Each report is its own ``run_id``.

* **Competition (LOCKED — methodology L194-196 + PRD L207-209).** ``Low`` if
  ``count <= 5``; ``Medium`` if ``6 <= count <= 15``; ``High`` if ``count > 15``
  **OR** the 7-day publication growth ``> 50%`` (recent 7d vs prior 7d, anchored to
  the run's ``window_end``). The growth trigger only ever *raises* to High, never
  lowers. ``prior_7d == 0`` ⇒ **no-trigger** (fail-closed: with no prior base the
  engine never asserts ">50% growth").
* **Example (deterministic proof video).** candidates = ValidVideos → top-3 by
  ``vel`` (``vel DESC, video_id ASC``; vel is consumed from the Scoring per-video
  velocity, **never recomputed**; a candidate without views orders last) → among the
  top-3 the most recent ``published_at`` → tie-break ``max views`` → tie-break
  ``min video_id``. The proof is emitted as ``selection_reason_json`` satisfying the
  live validator ``report_item_reason_complete`` (F5-05A) **by construction**.

Determinism (P5-REPRO-01). Same run + same versions ⇒ byte-identical items, incl.
``example_video_id``. Guaranteed by construction: every ordering / tie-break ends in
a stable natural key (``artist_id`` / ``video_id``); the temporal reference is the
frozen ``window_end`` (never the wall clock); no set-iteration order and no
randomness ever reaches a label. The whole rule set — ranking key, HOT threshold +
cap, display gate, Competition constants + the 7d trigger, the Example algorithm and
the formatting rules — is frozen into ``OpportunityConfig.canonical`` so
``opportunity_hash = sha256(canonical_json(config))`` covers it end to end; the
effective versions travel additively in ``selection_reason_json.versions`` so a
rebuild does not depend on a mutable table.

OUT of scope (never here): computing the Score / components / Competition count
(``DATA-SCORING-001`` / ``DATA-CHANNEL-001`` own those — consumed, not reopened),
any AI/LLM/model-generated number, DB / secret / network / real collection,
publishing (``draft -> published`` is downstream admin), and the public per-column
VIEW (Fase 9, vetoed). Reports are materialized in memory as ``draft``; a future
gated writer persists them to ``reports`` / ``report_items``.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from datetime import datetime, timedelta
from decimal import ROUND_HALF_EVEN, ROUND_HALF_UP, Context, Decimal, localcontext
from functools import cmp_to_key
from typing import Any, Sequence

from .scoring import RUBRIC_VERSION, ArtistScore


OPPORTUNITY_VERSION = "opportunity-rules-2026_06_v1"

# Ratified label/composition constants (DEC-0017 items 1/2/3 — do NOT re-decide).
HOT_SCORE_MIN_EXCLUSIVE = 90       # HOT only if final_score > 90 (strict)
HOT_MAX = 2                        # at most 2 HOT per report ("honest" cap)
DISPLAY_GATE_MIN = 83              # qualified/displayed only if final_score >= 83
MAX_REPORT_ITEMS = 10              # up to 10 qualified artists per report

# Competition thresholds (LOCKED — methodology L194-196 + PRD L207-209).
LOW_CHANNEL_MAX = 5                # Low if channel count <= 5
HIGH_CHANNEL_MAX = 15              # Medium if 6..15; High if > 15
GROWTH_HIGH_PCT = Decimal("0.50")  # 7d publication growth override: > 50% -> High
GROWTH_WINDOW_DAYS = 7             # each sub-window is 7 days
PRIOR_ZERO_RULE = "no-trigger"     # prior_7d == 0 -> growth trigger does NOT fire

# Competition enum labels (mirror public.competition_level verbatim).
LEVEL_LOW = "Low"
LEVEL_MEDIUM = "Medium"
LEVEL_HIGH = "High"

# Report classification. This module only ever emits the ``draft`` DB status
# (publish/freeze is downstream admin). ``insufficient_opportunity`` is a
# composition outcome carried as a flag, not a DB status transition.
REPORT_STATUS_DRAFT = "draft"
INSUFFICIENT_OPPORTUNITY = "insufficient_opportunity"

# Display formatting (cosmetic serialization of already-computed numbers; §10).
TITLE_SUFFIX = " Type Beat"
VELOCITY_THOUSAND_THRESHOLD = Decimal("1000")
VELOCITY_THOUSAND_SUFFIX = "k/day"
VELOCITY_BELOW_SUFFIX = "/day"
EXAMPLE_URL_PREFIX = "https://www.youtube.com/watch?v="

DECIMAL_PRECISION = 50
ZERO = Decimal(0)

# Frozen decimal context (copied by ``localcontext`` — never mutated in place).
DEFAULT_CONTEXT = Context(prec=DECIMAL_PRECISION, rounding=ROUND_HALF_EVEN)


class OpportunityError(RuntimeError):
    """Base error with a safe, non-PII message."""


class ContractViolation(OpportunityError):
    """An input violated the Opportunity contract (blank key, drift, naive datetime)."""


def _canonical_json(payload: Any) -> str:
    """Canonical JSON: sorted keys, no whitespace, UTF-8 preserving."""

    return json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def _require_nonblank(value: str, field_name: str) -> None:
    if not isinstance(value, str) or not value.strip():
        raise ContractViolation(f"{field_name} must be non-blank")


def _require_aware(value: datetime, field_name: str) -> None:
    if not isinstance(value, datetime):
        raise ContractViolation(f"{field_name} must be a datetime")
    if value.tzinfo is None or value.utcoffset() is None:
        raise ContractViolation(f"{field_name} must be timezone-aware (UTC)")


def _dec_str(value: Decimal | None) -> str | None:
    """String form of a Decimal (byte-stable) or ``None`` — never a fabricated 0."""

    return None if value is None else str(value)


# ---------------------------------------------------------------------------
# Frozen configuration + hash.
# ---------------------------------------------------------------------------
@dataclass(frozen=True, slots=True)
class OpportunityConfig:
    """Frozen configuration of ``opportunity-rules-2026_06_v1``.

    Every knob that can move a public label or the public order lives here;
    ``canonical`` serializes the whole rule so ``opportunity_hash`` covers the
    ranking key, the HOT threshold + cap, the display gate, the Competition
    constants + the 7d trigger, the Example algorithm and the formatting rules.
    Any change must ship as a new ``opportunity_version`` — never a silent edit.
    """

    opportunity_version: str = OPPORTUNITY_VERSION
    hot_score_min_exclusive: int = HOT_SCORE_MIN_EXCLUSIVE
    hot_max: int = HOT_MAX
    display_gate_min: int = DISPLAY_GATE_MIN
    max_report_items: int = MAX_REPORT_ITEMS
    low_channel_max: int = LOW_CHANNEL_MAX
    high_channel_max: int = HIGH_CHANNEL_MAX
    growth_high_pct: Decimal = GROWTH_HIGH_PCT
    growth_window_days: int = GROWTH_WINDOW_DAYS
    prior_zero_rule: str = PRIOR_ZERO_RULE

    def __post_init__(self) -> None:
        if self.hot_max < 0:
            raise ContractViolation("hot_max must be >= 0")
        if self.max_report_items < 1:
            raise ContractViolation("max_report_items must be >= 1")
        # HOT (> min_exclusive) must imply qualified (>= display_gate_min).
        if self.hot_score_min_exclusive < self.display_gate_min:
            raise ContractViolation("HOT threshold must not be below the display gate")
        if not 0 <= self.low_channel_max < self.high_channel_max:
            raise ContractViolation("require 0 <= low_channel_max < high_channel_max")
        if self.growth_high_pct < ZERO:
            raise ContractViolation("growth_high_pct must be >= 0")
        if self.growth_window_days < 1:
            raise ContractViolation("growth_window_days must be >= 1")
        if self.prior_zero_rule != PRIOR_ZERO_RULE:
            raise ContractViolation("prior_zero_rule is locked to 'no-trigger' in v1")

    def canonical(self) -> dict[str, Any]:
        """Deterministic, JSON-serializable snapshot hashed into ``opportunity_hash``."""

        return {
            "opportunity_version": self.opportunity_version,
            "ranking_key": [
                "final_score_desc",
                "velocity_component_desc",
                "signals_component_desc",
                "artist_id_asc",
            ],
            "hot": {
                "score_min_exclusive": self.hot_score_min_exclusive,
                "max": self.hot_max,
            },
            "display_gate": {"score_min_inclusive": self.display_gate_min},
            "composition": {
                "max_report_items": self.max_report_items,
                "insufficient_status": INSUFFICIENT_OPPORTUNITY,
            },
            "competition": {
                "low_channel_max": self.low_channel_max,
                "high_channel_max": self.high_channel_max,
                "growth_high_pct": str(self.growth_high_pct),
                "growth_window_days": self.growth_window_days,
                "prior_zero_rule": self.prior_zero_rule,
            },
            "example": {
                "candidate_order": "vel_desc, video_id_asc",
                "top_n": 3,
                "select_primary": "most_recent_published_at",
                "select_secondary": "max_views_absolute",
                "select_final": "min_video_id",
            },
            "formatting": {
                "title_suffix": TITLE_SUFFIX,
                "velocity_thousand_threshold": str(VELOCITY_THOUSAND_THRESHOLD),
                "velocity_thousand_suffix": VELOCITY_THOUSAND_SUFFIX,
                "velocity_below_suffix": VELOCITY_BELOW_SUFFIX,
                "velocity_rounding": "ROUND_HALF_UP",
                "example_url_prefix": EXAMPLE_URL_PREFIX,
                "score_display_format": "{final_score}/100",
            },
        }

    @property
    def opportunity_hash(self) -> str:
        """``sha256(canonical_json(config))`` — stable across runs and processes."""

        return hashlib.sha256(
            _canonical_json(self.canonical()).encode("utf-8")
        ).hexdigest()

    def context(self) -> Context:
        """A fresh frozen decimal context for this config."""

        return Context(prec=DECIMAL_PRECISION, rounding=ROUND_HALF_EVEN)


DEFAULT_CONFIG = OpportunityConfig()


# ---------------------------------------------------------------------------
# Inputs (consumed from Scoring + the raw — never recomputed here).
# ---------------------------------------------------------------------------
@dataclass(frozen=True, slots=True)
class ValidVideo:
    """One ValidVideo's Opportunity-relevant evidence, consumed verbatim upstream.

    ``vel`` is the per-video velocity computed by ``DATA-SCORING-001`` (§5.3 step 1),
    consumed here — **never recomputed**. ``published_at`` comes from
    ``raw_youtube_videos`` (timezone-aware); ``views`` is verbatim from the raw.
    ``None`` is never coerced to 0: a video with ``views is None`` has ``vel is
    None`` and orders last among Example candidates.
    """

    video_id: str
    views: int | None
    published_at: datetime
    vel: Decimal | None


@dataclass(frozen=True, slots=True)
class ArtistOpportunityInput:
    """One scored artist for the report: its Score + ValidVideos + canonical name.

    ``score`` is the ``ArtistScore`` consumed verbatim from ``DATA-SCORING-001``
    (``final_score``, the normalized components, ``channel_diversity_count``) — never
    recomputed. ``valid_videos`` are the artist's ValidVideos (Example candidates +
    the 7d-growth publication counts) and must match ``score.contributing_video_ids``
    exactly (deduped by ``video_id``); a mismatch is a contract violation, so the
    Example candidates are provably the same set the Score consumed. ``canonical_name``
    is ``artists.canonical_name`` (for the report-item title).
    """

    score: ArtistScore
    valid_videos: Sequence[ValidVideo]
    canonical_name: str

    @property
    def artist_id(self) -> str:
        """Identity of the input — the Score's ``artist_id`` (single source)."""

        return self.score.artist_id


# ---------------------------------------------------------------------------
# Outputs.
# ---------------------------------------------------------------------------
@dataclass(frozen=True, slots=True)
class ReportItem:
    """One ranked report line — the write-contract for a ``report_items`` row.

    ``score_value`` and ``selection_reason_json`` are INTERNAL (SEC-F03): never
    exposed raw to the producer (the public surface is the Fase 9 VIEW).
    """

    artist_id: str
    rank: int
    title: str
    tag: str | None                       # 'HOT' or None (OPP-02)
    score_display: str | None             # 'X/100' when qualified; else None (§7)
    score_value: int                      # = final_score (internal)
    signals: int
    velocity_display: str | None          # formatted velocity_median_per_day (§10.2)
    competition_level: str                # 'Low' | 'Medium' | 'High'
    competition_channel_count: int        # = channel_diversity_count
    example_video_id: str
    example_url: str
    selection_reason_json: dict[str, Any]
    rubric_version: str
    rubric_hash: str


@dataclass(frozen=True, slots=True)
class OpportunityReport:
    """Deterministic Opportunity output for one run (a single ``draft`` report).

    ``insufficient_opportunity`` is True exactly when no artist qualifies (all
    ``final_score < display_gate_min``); then ``items`` is empty. ``status`` is
    always the DB ``draft`` (this module materializes, it never publishes).
    """

    run_id: str
    title: str
    status: str
    insufficient_opportunity: bool
    rubric_version: str
    rubric_hash: str
    opportunity_version: str
    opportunity_hash: str
    items: tuple[ReportItem, ...]

    def item_for(self, artist_id: str) -> ReportItem | None:
        for item in self.items:
            if item.artist_id == artist_id:
                return item
        return None

    @property
    def hot_artist_ids(self) -> tuple[str, ...]:
        return tuple(item.artist_id for item in self.items if item.tag == "HOT")


# ---------------------------------------------------------------------------
# Pure deterministic primitives.
# ---------------------------------------------------------------------------
def base_competition_level(count: int, config: OpportunityConfig = DEFAULT_CONFIG) -> str:
    """``Low`` (``<= low_max``) · ``Medium`` (``.. high_max``) · ``High`` (``> high_max``)."""

    if count <= config.low_channel_max:
        return LEVEL_LOW
    if count <= config.high_channel_max:
        return LEVEL_MEDIUM
    return LEVEL_HIGH


def publication_windows(
    videos: Sequence[ValidVideo], window_end: datetime, *, window_days: int = GROWTH_WINDOW_DAYS
) -> tuple[int, int]:
    """``(recent_7d, prior_7d)`` publication counts in two disjoint sub-windows.

    ``recent`` = ``(window_end - window_days, window_end]``; ``prior`` =
    ``(window_end - 2*window_days, window_end - window_days]`` — half-open so the
    boundary belongs to exactly one window (no double count). Anchored to
    ``window_end``; never the wall clock.
    """

    _require_aware(window_end, "window_end")
    recent_start = window_end - timedelta(days=window_days)
    prior_start = window_end - timedelta(days=2 * window_days)
    recent = 0
    prior = 0
    for video in videos:
        published = video.published_at
        if recent_start < published <= window_end:
            recent += 1
        elif prior_start < published <= recent_start:
            prior += 1
    return recent, prior


def growth_trigger(
    recent_7d: int,
    prior_7d: int,
    *,
    threshold: Decimal = GROWTH_HIGH_PCT,
    context: Context = DEFAULT_CONTEXT,
) -> tuple[bool, Decimal | None]:
    """``(fired, growth_7d)``. ``prior_7d == 0`` ⇒ ``(False, None)`` (fail-closed).

    Otherwise ``growth_7d = (recent - prior) / prior`` and ``fired`` iff it strictly
    exceeds ``threshold``. The trigger only ever raises to High; it never lowers.
    """

    if prior_7d == 0:
        return False, None
    with localcontext(context):
        growth = Decimal(recent_7d - prior_7d) / Decimal(prior_7d)
    return growth > threshold, growth


def _velocity_sort_key(video: ValidVideo) -> tuple[int, Decimal, str]:
    """``vel DESC`` (``None`` last), then ``video_id ASC`` — total order over candidates."""

    if video.vel is None:
        return (1, ZERO, video.video_id)
    return (0, -video.vel, video.video_id)


def _views_key(video: ValidVideo) -> int:
    """Absolute views for the Example tie-break; ``None`` (no data) sorts lowest."""

    return video.views if video.views is not None else -1


def _example_cmp(left: ValidVideo, right: ValidVideo) -> int:
    """Total order for the Example winner: most recent, then max views, then min id."""

    if left.published_at != right.published_at:
        return -1 if left.published_at > right.published_at else 1
    left_views, right_views = _views_key(left), _views_key(right)
    if left_views != right_views:
        return -1 if left_views > right_views else 1
    if left.video_id != right.video_id:
        return -1 if left.video_id < right.video_id else 1
    return 0


def format_velocity_display(
    velocity: Decimal | None, *, context: Context = DEFAULT_CONTEXT
) -> str | None:
    """``'X.Xk/day'`` (``>= 1000``) or ``'XXX/day'`` (below); ``None`` stays ``None``.

    Cosmetic serialization of the already-computed ``velocity_median_per_day`` — never
    a fabricated ``0/day`` when the median is undefined (``None``).
    """

    if velocity is None:
        return None
    with localcontext(context):
        if velocity >= VELOCITY_THOUSAND_THRESHOLD:
            thousands = (velocity / VELOCITY_THOUSAND_THRESHOLD).quantize(
                Decimal("0.1"), rounding=ROUND_HALF_UP
            )
            return f"{thousands}{VELOCITY_THOUSAND_SUFFIX}"
        whole = velocity.quantize(Decimal("1"), rounding=ROUND_HALF_UP)
        return f"{whole}{VELOCITY_BELOW_SUFFIX}"


# ---------------------------------------------------------------------------
# Engine.
# ---------------------------------------------------------------------------
class OpportunityBuilder:
    """Deterministic ``opportunity-rules-2026_06_v1`` engine over one run's inputs."""

    def __init__(self, *, config: OpportunityConfig = DEFAULT_CONFIG) -> None:
        _require_nonblank(config.opportunity_version, "opportunity_version")
        self._config = config
        self._context = config.context()

    @property
    def config(self) -> OpportunityConfig:
        return self._config

    def build_report(
        self,
        *,
        run_id: str,
        report_title: str,
        artists: Sequence[ArtistOpportunityInput],
        window_end: datetime,
    ) -> OpportunityReport:
        """Rank, gate, compose, label and select — the whole ``draft`` report.

        ``window_end`` is the run's frozen temporal anchor for the 7d Competition
        windows (never the wall clock). The Score / components / Competition count
        are consumed from each ``ArtistScore``, never recomputed.
        """

        _require_nonblank(run_id, "run_id")
        _require_nonblank(report_title, "report_title")
        _require_aware(window_end, "window_end")

        ordered = self._ordered_unique(artists)
        rubric_version, rubric_hash = self._rubric_identity(ordered)
        config = self._config

        # OPP-03: total order over ALL scored artists.
        ranked = sorted(ordered, key=self._ranking_key)

        # OPP-06: qualification/display gate (>= 83). Never fill a slot below it.
        qualified = [
            artist for artist in ranked
            if artist.score.final_score >= config.display_gate_min
        ]

        if not qualified:
            # All artists below the gate: honest "no qualified opportunities".
            return OpportunityReport(
                run_id=run_id,
                title=report_title,
                status=REPORT_STATUS_DRAFT,
                insufficient_opportunity=True,
                rubric_version=rubric_version,
                rubric_hash=rubric_hash,
                opportunity_version=config.opportunity_version,
                opportunity_hash=config.opportunity_hash,
                items=(),
            )

        displayed = qualified[: config.max_report_items]

        # OPP-02: HOT = the top-``hot_max`` displayed artists with final_score > 90.
        # ``displayed`` is already in ranking order, so the prefix IS the top set;
        # fewer than 2 crossing 90 honestly yields fewer HOT — never a fabricated tag.
        hot_candidates = [
            artist for artist in displayed
            if artist.score.final_score > config.hot_score_min_exclusive
        ]
        hot_ids = {artist.artist_id for artist in hot_candidates[: config.hot_max]}

        items = tuple(
            self._build_item(
                artist,
                rank=rank,
                is_hot=artist.artist_id in hot_ids,
                window_end=window_end,
                rubric_version=rubric_version,
                rubric_hash=rubric_hash,
            )
            for rank, artist in enumerate(displayed, start=1)
        )

        return OpportunityReport(
            run_id=run_id,
            title=report_title,
            status=REPORT_STATUS_DRAFT,
            insufficient_opportunity=False,
            rubric_version=rubric_version,
            rubric_hash=rubric_hash,
            opportunity_version=config.opportunity_version,
            opportunity_hash=config.opportunity_hash,
            items=items,
        )

    # -- ranking ---------------------------------------------------------------
    @staticmethod
    def _ranking_key(artist: ArtistOpportunityInput) -> tuple[int, Decimal, Decimal, str]:
        # OPP-03: final_score DESC, velocity_component DESC, signals_component DESC,
        # artist_id ASC. Components are the normalized Score components (consumed).
        score = artist.score
        return (
            -score.final_score,
            -score.components.norm_velocity,
            -score.components.norm_signals,
            artist.artist_id,
        )

    # -- input hygiene ---------------------------------------------------------
    def _ordered_unique(
        self, artists: Sequence[ArtistOpportunityInput]
    ) -> tuple[ArtistOpportunityInput, ...]:
        if not artists:
            raise ContractViolation("a run reaching Opportunity has >= 1 scored artist")
        seen: set[str] = set()
        for artist in artists:
            _require_nonblank(artist.artist_id, "artist_id")
            if artist.artist_id in seen:
                raise ContractViolation("duplicate artist_id in the run")
            seen.add(artist.artist_id)
            self._validate_artist(artist)
        return tuple(sorted(artists, key=lambda a: a.artist_id))

    def _validate_artist(self, artist: ArtistOpportunityInput) -> None:
        _require_nonblank(artist.canonical_name, "canonical_name")
        _require_nonblank(artist.score.artist_id, "artist_id")
        if not artist.valid_videos:
            raise ContractViolation("scored artist must have >= 1 ValidVideo (Example candidate)")
        video_ids = [video.video_id for video in artist.valid_videos]
        for video_id in video_ids:
            _require_nonblank(video_id, "video_id")
        if len(video_ids) != len(set(video_ids)):
            raise ContractViolation("duplicate video_id in artist ValidVideos")
        if tuple(sorted(video_ids)) != artist.score.contributing_video_ids:
            raise ContractViolation(
                "ValidVideos do not match the score's contributing_video_ids"
            )
        for video in artist.valid_videos:
            _require_aware(video.published_at, "published_at")

    @staticmethod
    def _rubric_identity(artists: Sequence[ArtistOpportunityInput]) -> tuple[str, str]:
        identities = {
            (artist.score.rubric_version, artist.score.rubric_hash) for artist in artists
        }
        if len(identities) != 1:
            raise ContractViolation(
                "all artists must share one (rubric_version, rubric_hash) — same run"
            )
        rubric_version, rubric_hash = next(iter(identities))
        _require_nonblank(rubric_version, "rubric_version")
        _require_nonblank(rubric_hash, "rubric_hash")
        return rubric_version, rubric_hash

    # -- per-item assembly -----------------------------------------------------
    def _build_item(
        self,
        artist: ArtistOpportunityInput,
        *,
        rank: int,
        is_hot: bool,
        window_end: datetime,
        rubric_version: str,
        rubric_hash: str,
    ) -> ReportItem:
        score = artist.score
        config = self._config

        competition = self._competition(artist, window_end)
        example = self._example(artist)
        reason_json = self._selection_reason_json(
            example=example,
            competition=competition,
            rubric_version=rubric_version,
            rubric_hash=rubric_hash,
        )

        final_score = score.final_score
        score_display = (
            f"{final_score}/100" if final_score >= config.display_gate_min else None
        )
        selected_id = example["selected"].video_id

        return ReportItem(
            artist_id=artist.artist_id,
            rank=rank,
            title=f"{artist.canonical_name}{TITLE_SUFFIX}",
            tag="HOT" if is_hot else None,
            score_display=score_display,
            score_value=final_score,
            signals=score.signals,
            velocity_display=format_velocity_display(
                score.velocity_median_per_day, context=self._context
            ),
            competition_level=competition["level"],
            competition_channel_count=score.channel_diversity_count,
            example_video_id=selected_id,
            example_url=f"{EXAMPLE_URL_PREFIX}{selected_id}",
            selection_reason_json=reason_json,
            rubric_version=rubric_version,
            rubric_hash=rubric_hash,
        )

    # -- Competition -----------------------------------------------------------
    def _competition(
        self, artist: ArtistOpportunityInput, window_end: datetime
    ) -> dict[str, Any]:
        config = self._config
        count = artist.score.channel_diversity_count
        base = base_competition_level(count, config)
        recent_7d, prior_7d = publication_windows(
            artist.valid_videos, window_end, window_days=config.growth_window_days
        )
        fired, growth = growth_trigger(
            recent_7d, prior_7d, threshold=config.growth_high_pct, context=self._context
        )
        level = LEVEL_HIGH if (base == LEVEL_HIGH or fired) else base
        return {
            "count": count,
            "base_level": base,
            "level": level,
            "recent_7d": recent_7d,
            "prior_7d": prior_7d,
            "growth_7d": _dec_str(growth),
            "growth_triggered": fired,
            "prior_zero_rule": config.prior_zero_rule,
        }

    # -- Example ---------------------------------------------------------------
    @staticmethod
    def _example(artist: ArtistOpportunityInput) -> dict[str, Any]:
        # 1-3: candidates = ValidVideos; rank by (vel DESC, video_id ASC); top-3.
        ranked = sorted(artist.valid_videos, key=_velocity_sort_key)
        top3 = ranked[:3]
        # 4-6: among top-3 pick most recent published_at, then max views, then min id.
        by_selection = sorted(top3, key=cmp_to_key(_example_cmp))
        selected = by_selection[0]
        runner_up = by_selection[1] if len(by_selection) > 1 else None
        applied = _which_rule_applied(selected, runner_up)
        return {
            "candidates": ranked,
            "top3": top3,
            "selected": selected,
            "applied": applied,
        }

    def _selection_reason_json(
        self,
        *,
        example: dict[str, Any],
        competition: dict[str, Any],
        rubric_version: str,
        rubric_hash: str,
    ) -> dict[str, Any]:
        """Assemble ``selection_reason_json`` satisfying F5-05A by construction.

        Requires (validator ``report_item_reason_complete``): ``candidates`` (>=1),
        ``top3`` (>=1), ``tiebreak`` (present), ``selected_example.video_id``
        (non-empty). The Example always has >= 1 candidate (scored artist ⇒ >= 1
        ValidVideo), so the shape holds by construction. ``versions`` / ``competition``
        are additive keys (accepted — the validator only checks the required ones).
        """

        config = self._config
        candidates = example["candidates"]
        top3 = example["top3"]
        selected: ValidVideo = example["selected"]
        return {
            "candidates": [
                {
                    "video_id": video.video_id,
                    "views": video.views,
                    "published_at": video.published_at.isoformat(),
                    "vel": _dec_str(video.vel),
                }
                for video in candidates
            ],
            "top3": [
                {"video_id": video.video_id, "vel": _dec_str(video.vel), "rank": position}
                for position, video in enumerate(top3, start=1)
            ],
            "tiebreak": {
                "order_by": "vel_desc, video_id_asc",
                "primary": "most_recent_published_at",
                "secondary": "max_views_absolute",
                "final": "min_video_id",
                "applied": example["applied"],
            },
            "selected_example": {
                "video_id": selected.video_id,
                "published_at": selected.published_at.isoformat(),
                "views": selected.views,
                "vel": _dec_str(selected.vel),
            },
            "versions": {
                "opportunity_version": config.opportunity_version,
                "opportunity_hash": config.opportunity_hash,
                "rubric_version": rubric_version,
                "rubric_hash": rubric_hash,
            },
            "competition": competition,
        }


def _which_rule_applied(selected: ValidVideo, runner_up: ValidVideo | None) -> str:
    """Which Example rule decided the winner over the closest runner-up (audit)."""

    if runner_up is None:
        return "primary"
    if selected.published_at != runner_up.published_at:
        return "primary"
    if _views_key(selected) != _views_key(runner_up):
        return "secondary"
    return "final"
