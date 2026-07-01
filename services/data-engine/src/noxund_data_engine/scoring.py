"""Deterministic Popularity Scoring core (DATA-SCORING-001 · score_rubric_2026_06_v1).

This is the second purely deterministic zone after the Channel Filter. No AI acts
here and no product number is model-generated: the Score, its four components and
every normalization are a pure arithmetic function of the run's valid videos
(``views``/``likes``/``comments``/``published_at``, verbatim from
``raw_youtube_videos``), the run's frozen ``window_end``, and the Channel Filter's
per-artist projection (``ArtistProjection`` — Signals + Competition), under the
frozen ``RubricConfig``.

Constants are ratified in DEC-0017 item 4 and are LOCKED here (never re-decided):
Velocity 40% · Signals 25% · Engagement 20% · Diversity 15%; ``P_VEL = P_ENG = p90``,
``SIGNALS_SAT_CAP = 20``, ``DIVERSITY_TARGET = 15``, recency half-life 15 days,
``AGE_FLOOR_DAYS = 1``, ``ROUND_HALF_UP``. The reference set for the sample-relative
normalizations is the run's own scored artists (no historical baseline).

Formula (methodology §7, weights LOCKED)::

    final_score = ROUND_HALF_UP(
        100 * ( 0.40*norm_velocity + 0.25*norm_signals
              + 0.20*norm_engagement + 0.15*norm_diversity ) )  in {0..100}

* **Velocity** — per-artist *median* of ``views / age_eff`` (``velocity_median_per_day``),
  then p90-anchor + cap normalization across the run's scored artists.
* **Signals** — ``count(ValidVideos)`` consumed from ``ArtistProjection.signals``
  (never recomputed) → ln-saturating with ``SIGNALS_SAT_CAP``.
* **Engagement** — per video ``(likes+comments)/views``, recency-weighted average
  (weight ``0.5 ** (age_eff/15)``), then p90-anchor + cap normalization.
* **Diversity** — ``count(distinct eligible channels)`` consumed from
  ``ArtistProjection.competition`` (never recomputed) → ln-saturating with
  ``DIVERSITY_TARGET``.

Determinism (P5-REPRO-01). Same raw snapshot + same rubric ⇒ byte-identical
``final_score`` and components. Guaranteed by construction:

* the temporal reference is the frozen ``window_end`` (never the wall clock);
  ``age_days = (window_end - published_at) / 86400`` is computed from an integer
  ``timedelta`` (days/seconds/microseconds), so no float ever enters an age;
* all arithmetic runs under a single frozen ``decimal`` context — fixed precision
  (``DECIMAL_PRECISION``) + ``ROUND_HALF_EVEN`` for intermediates; the *final* Score
  is quantized with ``ROUND_HALF_UP``;
* percentile uses exactly one documented rule: linear interpolation, inclusive
  (a.k.a. type-7 / numpy ``linear`` / Excel ``PERCENTILE.INC``);
* the recency weight ``0.5 ** (age/15)`` is evaluated as ``exp(ln(0.5)*age/15)`` via
  ``Decimal.ln`` / ``Decimal.exp`` (both *correctly rounded* under the General
  Decimal Arithmetic spec). ``Decimal.__pow__`` with a non-integer exponent — only
  "almost always correctly rounded" — is deliberately NOT used;
* every ordering / tie-break is by a stable natural key (``video_id`` / ``artist_id``);
  no set-iteration order and no randomness ever reaches a number.

The exact method (precision, intermediate + final rounding, percentile rule,
recency method, curves, constants) is frozen into ``RubricConfig.canonical`` so that
``rubric_hash = sha256(canonical_json(config))`` covers it end to end: changing any
of them necessarily changes the hash and requires a new ``rubric_version`` — never a
silent edit of ``…v1``.

OUT of scope (Opportunity / Agente 6 — never implemented here): ranking, the HOT tag
(>90), the display gate (>83), Competition Low/Medium/High labels, and Example
selection. This module computes the number + 4 components for ALL scorable artists;
whoever decides to *display*, *label* and *order* is the Opportunity agent.

No DB, secret, network, LLM, or real collection is touched. Scores are returned in
memory; a future gated writer persists them to ``artist_metrics``.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass, field
from datetime import datetime
from decimal import (
    ROUND_HALF_EVEN,
    ROUND_HALF_UP,
    Context,
    Decimal,
    localcontext,
)
from typing import Any, Sequence

from .channel_filter import RULE_VERSION, ArtistProjection
from .entity_resolution import RESOLVER_VERSION


RUBRIC_VERSION = "score_rubric_2026_06_v1"

# Weights (methodology §7 — LOCKED; changing any weight/component is a Stop Condition).
WEIGHT_VELOCITY = Decimal("0.40")
WEIGHT_SIGNALS = Decimal("0.25")
WEIGHT_ENGAGEMENT = Decimal("0.20")
WEIGHT_DIVERSITY = Decimal("0.15")

# Ratified constants (DEC-0017 item 4 — do NOT re-decide here).
P_VEL = Decimal("0.90")            # percentile anchor for Velocity normalization
P_ENG = Decimal("0.90")            # percentile anchor for Engagement normalization
SIGNALS_SAT_CAP = 20               # count where Signals saturates (~1)
DIVERSITY_TARGET = 15              # count where Diversity saturates (~1)
HALF_LIFE_DAYS = Decimal("15")     # recency exponential half-life
AGE_FLOOR_DAYS = Decimal("1")      # age floor (avoids div-by-zero / spike near window_end)

# Deterministic method identifiers frozen into ``rubric_hash``.
DECIMAL_PRECISION = 50             # fixed significant digits for every intermediate op
PERCENTILE_METHOD = "linear_interpolation_inclusive"  # type-7 / numpy 'linear' / PERCENTILE.INC
RECENCY_METHOD = "exp_ln_decimal_correctly_rounded"   # exp(ln(0.5)*age/15); no Decimal.__pow__
INTERMEDIATE_ROUNDING = "ROUND_HALF_EVEN"
FINAL_ROUNDING = "ROUND_HALF_UP"

# Component keys — mirror metrics_detail_json §7 verbatim (audited into the hash).
KEY_VELOCITY = "velocity_normalized"
KEY_SIGNALS = "signals"
KEY_ENGAGEMENT = "engagement_recency_weighted"
KEY_DIVERSITY = "channel_diversity"

# Per-component NULL-rejection reasons (audited in metrics_detail_json.videos.rejected).
REASON_VIEWS_NULL = "views_null"            # views absent -> out of Velocity AND Engagement
REASON_VIEWS_ZERO = "views_null_or_zero"    # views == 0   -> out of Engagement (rate undefined)

ZERO = Decimal(0)
ONE = Decimal(1)

# Default frozen decimal context (matches the default rubric's precision/rounding).
# ``localcontext`` copies it, so this module-level object is never mutated.
DEFAULT_CONTEXT = Context(prec=DECIMAL_PRECISION, rounding=ROUND_HALF_EVEN)


class ScoringError(RuntimeError):
    """Base error with a safe, non-PII message."""


class ContractViolation(ScoringError):
    """An input violated the scoring contract (blank key, naive datetime, drift)."""


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


@dataclass(frozen=True, slots=True)
class RubricConfig:
    """Frozen configuration of ``score_rubric_2026_06_v1``.

    Every field that can move the public number lives here; ``canonical`` serializes
    the whole rule so ``rubric_hash`` covers weights, constants, curves, the
    percentile method, the recency method, the decimal precision, and both rounding
    modes. Any change must ship as a new ``rubric_version`` — never a silent edit.
    """

    rubric_version: str = RUBRIC_VERSION
    weight_velocity: Decimal = WEIGHT_VELOCITY
    weight_signals: Decimal = WEIGHT_SIGNALS
    weight_engagement: Decimal = WEIGHT_ENGAGEMENT
    weight_diversity: Decimal = WEIGHT_DIVERSITY
    p_vel: Decimal = P_VEL
    p_eng: Decimal = P_ENG
    signals_sat_cap: int = SIGNALS_SAT_CAP
    diversity_target: int = DIVERSITY_TARGET
    half_life_days: Decimal = HALF_LIFE_DAYS
    age_floor_days: Decimal = AGE_FLOOR_DAYS
    decimal_precision: int = DECIMAL_PRECISION
    percentile_method: str = PERCENTILE_METHOD
    recency_method: str = RECENCY_METHOD

    def __post_init__(self) -> None:
        weight_sum = (
            self.weight_velocity
            + self.weight_signals
            + self.weight_engagement
            + self.weight_diversity
        )
        if weight_sum != ONE:
            raise ContractViolation("component weights must sum to exactly 1.00")
        if self.signals_sat_cap < 1 or self.diversity_target < 1:
            raise ContractViolation("saturation constants must be >= 1")
        if self.half_life_days <= ZERO or self.age_floor_days <= ZERO:
            raise ContractViolation("half_life_days and age_floor_days must be > 0")
        if self.decimal_precision < 1:
            raise ContractViolation("decimal_precision must be >= 1")

    def canonical(self) -> dict[str, Any]:
        """Deterministic, JSON-serializable snapshot hashed into ``rubric_hash``."""

        return {
            "rubric_version": self.rubric_version,
            "weights": {
                "velocity": str(self.weight_velocity),
                "signals": str(self.weight_signals),
                "engagement": str(self.weight_engagement),
                "diversity": str(self.weight_diversity),
            },
            "components_ordered": [
                KEY_VELOCITY,
                KEY_SIGNALS,
                KEY_ENGAGEMENT,
                KEY_DIVERSITY,
            ],
            "constants": {
                "AGE_FLOOR_DAYS": str(self.age_floor_days),
                "P_VEL": str(self.p_vel),
                "P_ENG": str(self.p_eng),
                "SIGNALS_SAT_CAP": self.signals_sat_cap,
                "DIVERSITY_TARGET": self.diversity_target,
                "HALF_LIFE_DAYS": str(self.half_life_days),
            },
            "curves": {
                "velocity": "percentile_anchor_cap",
                "engagement": "percentile_anchor_cap",
                "signals": "ln_saturating",
                "diversity": "ln_saturating",
                "recency": "exponential_half_life",
            },
            "method": {
                "percentile": self.percentile_method,
                "recency": self.recency_method,
                "decimal_precision": self.decimal_precision,
                "intermediate_rounding": INTERMEDIATE_ROUNDING,
                "final_rounding": FINAL_ROUNDING,
            },
            "reference_set": "run_scored_artists",
            "temporal_reference": "report_runs.window_end",
            "null_policy": "null_never_zero",
        }

    @property
    def rubric_hash(self) -> str:
        """``sha256(canonical_json(config))`` — stable across runs and processes."""

        return hashlib.sha256(
            _canonical_json(self.canonical()).encode("utf-8")
        ).hexdigest()

    def context(self) -> Context:
        """A fresh frozen decimal context honoring this config's precision."""

        return Context(prec=self.decimal_precision, rounding=ROUND_HALF_EVEN)


DEFAULT_RUBRIC = RubricConfig()


# ---------------------------------------------------------------------------
# Inputs (consumed from the raw + the Channel Filter — never recomputed here).
# ---------------------------------------------------------------------------
@dataclass(frozen=True, slots=True)
class VideoStats:
    """Per-video raw statistics for one ValidVideo (verbatim from ``raw_youtube_videos``).

    NULL (``None``) is never coerced to 0. Absent ``views`` removes the video from
    Velocity *and* Engagement; absent ``likes``/``comments`` are a missing engagement
    contribution (numerator), not a fabricated zero. ``published_at`` must be
    timezone-aware; the age reference is the run's frozen ``window_end``.
    """

    video_id: str
    views: int | None
    likes: int | None
    comments: int | None
    published_at: datetime


@dataclass(frozen=True, slots=True)
class ArtistScoringInput:
    """One scorable artist for a run: its ValidVideos stats + Channel Filter projection.

    ``projection`` is the ``ArtistProjection`` consumed verbatim from the Channel
    Filter: ``signals = projection.signals`` and ``competition = projection.competition``
    are *never* recomputed here — this scorer only normalizes them. The video set must
    match ``projection.valid_video_ids`` exactly (deduped by ``video_id``); a mismatch
    is a contract violation, guaranteeing Signals/Velocity read the same ValidVideos.

    ``overrides`` carries frozen upstream human decisions (channel eligibility /
    artist mapping) for the replayable ``metrics_detail_json.overrides[]`` audit; the
    scorer never generates them.
    """

    artist_id: str
    videos: Sequence[VideoStats]
    projection: ArtistProjection
    overrides: tuple[dict[str, Any], ...] = ()


# ---------------------------------------------------------------------------
# Outputs.
# ---------------------------------------------------------------------------
@dataclass(frozen=True, slots=True)
class ScoreComponents:
    """The four normalized components in [0, 1] (weights applied in ``raw_score``)."""

    norm_velocity: Decimal
    norm_signals: Decimal
    norm_engagement: Decimal
    norm_diversity: Decimal


@dataclass(frozen=True, slots=True)
class ArtistScore:
    """Deterministic Score for one ``(run, artist)`` — the number + full evidence.

    Note the deliberate absence of any Opportunity field (rank / HOT tag /
    display gate / Competition label / Example): those belong to Agente 6.
    """

    artist_id: str
    signals: int
    velocity_median_per_day: Decimal | None
    engagement_score: Decimal | None
    channel_diversity_count: int
    channel_diversity_score: Decimal
    components: ScoreComponents
    raw_score: Decimal
    final_score: int
    contributing_video_ids: tuple[str, ...]
    rubric_version: str
    rubric_hash: str
    metrics_detail_json: dict[str, Any] = field(compare=True, hash=False, default_factory=dict)


@dataclass(frozen=True, slots=True)
class RunScoreResult:
    """Full deterministic scoring output for one run (ordered by ``artist_id``).

    The order is a stable natural-key order, NOT a ranking — ranking is Opportunity's.
    """

    run_id: str
    rubric_version: str
    rubric_hash: str
    window_end: datetime
    scores: tuple[ArtistScore, ...]

    def score_for(self, artist_id: str) -> ArtistScore | None:
        for score in self.scores:
            if score.artist_id == artist_id:
                return score
        return None


@dataclass(frozen=True, slots=True)
class _PreparedArtist:
    """Pass-1 per-artist aggregates + audit rows, before run-relative normalization."""

    artist_id: str
    signals: int
    competition: int
    eligible_channel_ids: tuple[str, ...]
    contributing_video_ids: tuple[str, ...]
    velocity_median_per_day: Decimal | None
    engagement_raw: Decimal | None
    accepted_rows: tuple[dict[str, Any], ...]
    rejected_rows: tuple[dict[str, Any], ...]
    velocity_input_rows: tuple[dict[str, Any], ...]
    overrides: tuple[dict[str, Any], ...]


# ---------------------------------------------------------------------------
# Pure deterministic primitives (each self-contained under a frozen context so it
# is byte-identical regardless of the caller's ambient decimal context).
# ---------------------------------------------------------------------------
def age_days(
    published_at: datetime, window_end: datetime, *, context: Context = DEFAULT_CONTEXT
) -> Decimal:
    """``(window_end - published_at) / 86400`` from an integer timedelta (no float)."""

    _require_aware(published_at, "published_at")
    _require_aware(window_end, "window_end")
    delta = window_end - published_at
    with localcontext(context):
        seconds = (
            Decimal(delta.days) * Decimal(86400)
            + Decimal(delta.seconds)
            + Decimal(delta.microseconds) / Decimal(1_000_000)
        )
        return seconds / Decimal(86400)


def effective_age_days(
    published_at: datetime,
    window_end: datetime,
    *,
    age_floor_days: Decimal = AGE_FLOOR_DAYS,
    context: Context = DEFAULT_CONTEXT,
) -> Decimal:
    """``max(AGE_FLOOR_DAYS, age_days)`` — the floor protects near-``window_end`` videos."""

    raw = age_days(published_at, window_end, context=context)
    return raw if raw > age_floor_days else age_floor_days


def velocity_ratio(
    views: int, age_eff_days: Decimal, *, context: Context = DEFAULT_CONTEXT
) -> Decimal:
    """``views / age_eff`` — views/day for one video (caller guarantees age_eff > 0)."""

    with localcontext(context):
        return Decimal(views) / age_eff_days


def engagement_rate(
    likes: int | None,
    comments: int | None,
    views: int,
    *,
    context: Context = DEFAULT_CONTEXT,
) -> Decimal:
    """``(coalesce(likes,0)+coalesce(comments,0)) / views`` — the rate definition.

    Absent ``likes``/``comments`` are a missing positive contribution to the
    numerator, not a fabricated statistic. Caller guarantees ``views > 0``.
    """

    numerator = (likes or 0) + (comments or 0)
    with localcontext(context):
        return Decimal(numerator) / Decimal(views)


def recency_weight(
    age_eff_days: Decimal,
    *,
    half_life_days: Decimal = HALF_LIFE_DAYS,
    context: Context = DEFAULT_CONTEXT,
) -> Decimal:
    """``0.5 ** (age_eff/half_life)`` via ``exp(ln(0.5)*age_eff/half_life)``.

    ``Decimal.ln``/``Decimal.exp`` are correctly rounded (deterministic); the
    non-integer ``Decimal.__pow__`` (only "almost always correctly rounded") is
    intentionally avoided.
    """

    with localcontext(context):
        ln_half = Decimal("0.5").ln()
        return (ln_half * age_eff_days / half_life_days).exp()


def median(values: Sequence[Decimal], *, context: Context = DEFAULT_CONTEXT) -> Decimal:
    """Deterministic median: central element (odd) or exact mean of the two central."""

    if not values:
        raise ContractViolation("median of an empty set")
    ordered = sorted(values)
    n = len(ordered)
    mid = n // 2
    if n % 2 == 1:
        return ordered[mid]
    with localcontext(context):
        return (ordered[mid - 1] + ordered[mid]) / Decimal(2)


def percentile_inclusive(
    values: Sequence[Decimal], p: Decimal, *, context: Context = DEFAULT_CONTEXT
) -> Decimal:
    """Linear-interpolation inclusive percentile (type-7 / numpy 'linear').

    ``rank = (n-1)*p`` (0-indexed); interpolate between the two straddling order
    statistics. One value returns itself. This is the single frozen percentile rule.
    """

    if not values:
        raise ContractViolation("percentile of an empty reference set")
    ordered = sorted(values)
    n = len(ordered)
    if n == 1:
        return ordered[0]
    with localcontext(context):
        rank = Decimal(n - 1) * p
        lower = int(rank)
        if lower >= n - 1:
            return ordered[-1]
        frac = rank - Decimal(lower)
        low_value = ordered[lower]
        high_value = ordered[lower + 1]
        return low_value + frac * (high_value - low_value)


def ln_saturating(
    count: int, cap: int, *, context: Context = DEFAULT_CONTEXT
) -> Decimal:
    """``min(1, ln(1+count) / ln(1+cap))`` — concave saturation (excess penalty)."""

    with localcontext(context):
        value = Decimal(1 + count).ln() / Decimal(1 + cap).ln()
        return value if value < ONE else ONE


def normalized_ratio(
    value: Decimal, ref: Decimal, *, context: Context = DEFAULT_CONTEXT
) -> Decimal:
    """``min(1, value/ref)`` — percentile-anchor + cap (caller guarantees ref > 0)."""

    with localcontext(context):
        ratio = value / ref
        return ratio if ratio < ONE else ONE


def weighted_average(
    pairs: Sequence[tuple[Decimal, Decimal]], *, context: Context = DEFAULT_CONTEXT
) -> Decimal:
    """``sum(w*x) / sum(w)`` over ``(weight, value)`` pairs in the given order."""

    with localcontext(context):
        total_weight = ZERO
        total_weighted = ZERO
        for weight, value in pairs:
            total_weight += weight
            total_weighted += weight * value
        if total_weight == ZERO:
            raise ContractViolation("weighted average with zero total weight")
        return total_weighted / total_weight


def raw_score(
    norm_velocity: Decimal,
    norm_signals: Decimal,
    norm_engagement: Decimal,
    norm_diversity: Decimal,
    *,
    w_vel: Decimal = WEIGHT_VELOCITY,
    w_sig: Decimal = WEIGHT_SIGNALS,
    w_eng: Decimal = WEIGHT_ENGAGEMENT,
    w_div: Decimal = WEIGHT_DIVERSITY,
    context: Context = DEFAULT_CONTEXT,
) -> Decimal:
    """``100 * (0.40*nv + 0.25*ns + 0.20*ne + 0.15*nd)`` — the continuous 0..100 score."""

    with localcontext(context):
        return Decimal(100) * (
            w_vel * norm_velocity
            + w_sig * norm_signals
            + w_eng * norm_engagement
            + w_div * norm_diversity
        )


def final_score_from_raw(value: Decimal, *, context: Context = DEFAULT_CONTEXT) -> int:
    """``ROUND_HALF_UP(raw_score)`` in {0..100} — the public integer ``X/100``.

    The rounding argument overrides the context's ROUND_HALF_EVEN, so 90.5 -> 91 and
    82.5 -> 83 (half-even would give 90 and 82).
    """

    with localcontext(context):
        return int(value.quantize(ONE, rounding=ROUND_HALF_UP))


# ---------------------------------------------------------------------------
# Engine.
# ---------------------------------------------------------------------------
class PopularityScorer:
    """Deterministic ``score_rubric_2026_06_v1`` engine over one run's inputs."""

    def __init__(
        self,
        *,
        config: RubricConfig = DEFAULT_RUBRIC,
        resolver_version: str = RESOLVER_VERSION,
        rule_version: str = RULE_VERSION,
    ) -> None:
        _require_nonblank(config.rubric_version, "rubric_version")
        _require_nonblank(resolver_version, "resolver_version")
        _require_nonblank(rule_version, "rule_version")
        self._config = config
        self._resolver_version = resolver_version
        self._rule_version = rule_version
        self._context = config.context()

    @property
    def config(self) -> RubricConfig:
        return self._config

    def score_run(
        self,
        *,
        run_id: str,
        artists: Sequence[ArtistScoringInput],
        window_end: datetime,
    ) -> RunScoreResult:
        """Compute the Score + 4 components for every scorable artist in the run.

        The normalization reference set is *this run's* scored artists (no historical
        baseline); ``V_REF``/``E_REF`` are the run's p90 anchors and are frozen into
        every row's ``metrics_detail_json.normalization`` for isolated replay.
        """

        _require_nonblank(run_id, "run_id")
        _require_aware(window_end, "window_end")

        ordered = self._ordered_unique(artists)
        prepared = tuple(self._prepare(artist, window_end) for artist in ordered)

        v_ref = self._reference([p.velocity_median_per_day for p in prepared], self._config.p_vel)
        e_ref = self._reference([p.engagement_raw for p in prepared], self._config.p_eng)

        scores = tuple(self._finalize(p, v_ref, e_ref) for p in prepared)
        return RunScoreResult(
            run_id=run_id,
            rubric_version=self._config.rubric_version,
            rubric_hash=self._config.rubric_hash,
            window_end=window_end,
            scores=scores,
        )

    # -- pass 0: input hygiene -------------------------------------------------
    @staticmethod
    def _ordered_unique(
        artists: Sequence[ArtistScoringInput],
    ) -> tuple[ArtistScoringInput, ...]:
        seen: set[str] = set()
        for artist in artists:
            _require_nonblank(artist.artist_id, "artist_id")
            if artist.artist_id in seen:
                raise ContractViolation("duplicate artist_id in the run")
            seen.add(artist.artist_id)
        return tuple(sorted(artists, key=lambda a: a.artist_id))

    # -- pass 1: per-artist raw aggregates ------------------------------------
    def _prepare(
        self, artist: ArtistScoringInput, window_end: datetime
    ) -> _PreparedArtist:
        projection = artist.projection
        if projection.artist_id != artist.artist_id:
            raise ContractViolation("projection artist_id does not match the input artist")
        if not artist.videos or projection.signals == 0:
            raise ContractViolation("artist has no valid videos (not scorable)")

        video_ids = [video.video_id for video in artist.videos]
        for video_id in video_ids:
            _require_nonblank(video_id, "video_id")
        if len(video_ids) != len(set(video_ids)):
            raise ContractViolation("duplicate video_id in artist inputs")
        if tuple(sorted(video_ids)) != projection.valid_video_ids:
            raise ContractViolation(
                "artist videos do not match the channel-filter ValidVideos projection"
            )

        config = self._config
        context = self._context

        accepted_rows: list[dict[str, Any]] = []
        rejected_rows: list[dict[str, Any]] = []
        velocity_inputs: list[tuple[Decimal, str]] = []
        velocity_input_rows: list[dict[str, Any]] = []
        engagement_pairs: list[tuple[str, Decimal, Decimal]] = []  # (video_id, weight, rate)

        for video in sorted(artist.videos, key=lambda v: v.video_id):
            age_eff = effective_age_days(
                video.published_at,
                window_end,
                age_floor_days=config.age_floor_days,
                context=context,
            )
            weight = recency_weight(
                age_eff, half_life_days=config.half_life_days, context=context
            )

            velocity: Decimal | None = None
            rate: Decimal | None = None

            if video.views is None:
                # views absent -> out of Velocity AND Engagement (never a fabricated 0).
                rejected_rows.append({"video_id": video.video_id, "reason": REASON_VIEWS_NULL})
            else:
                velocity = velocity_ratio(video.views, age_eff, context=context)
                velocity_inputs.append((velocity, video.video_id))
                velocity_input_rows.append(
                    {
                        "video_id": video.video_id,
                        "views": video.views,
                        "age_days": _dec_str(age_eff),
                    }
                )
                if video.views == 0:
                    # rate undefined -> out of Engagement only (Velocity keeps the 0).
                    rejected_rows.append(
                        {"video_id": video.video_id, "reason": REASON_VIEWS_ZERO}
                    )
                else:
                    rate = engagement_rate(
                        video.likes, video.comments, video.views, context=context
                    )
                    engagement_pairs.append((video.video_id, weight, rate))

            accepted_rows.append(
                {
                    "video_id": video.video_id,
                    "views": video.views,
                    "likes": video.likes,
                    "comments": video.comments,
                    "age_days": _dec_str(age_eff),
                    "vel": _dec_str(velocity),
                    "eng": _dec_str(rate),
                    "w": _dec_str(weight),
                }
            )

        velocity_median = (
            median([vel for vel, _ in sorted(velocity_inputs)], context=context)
            if velocity_inputs
            else None
        )
        engagement_raw = (
            weighted_average(
                [
                    (weight, rate)
                    for _, weight, rate in sorted(engagement_pairs, key=lambda t: t[0])
                ],
                context=context,
            )
            if engagement_pairs
            else None
        )

        return _PreparedArtist(
            artist_id=artist.artist_id,
            signals=projection.signals,
            competition=projection.competition,
            eligible_channel_ids=projection.eligible_channel_ids,
            contributing_video_ids=projection.valid_video_ids,
            velocity_median_per_day=velocity_median,
            engagement_raw=engagement_raw,
            accepted_rows=tuple(accepted_rows),
            rejected_rows=tuple(rejected_rows),
            velocity_input_rows=tuple(velocity_input_rows),
            overrides=tuple(artist.overrides),
        )

    # -- pass 2: run-relative reference anchors -------------------------------
    def _reference(
        self, values: Sequence[Decimal | None], percentile: Decimal
    ) -> Decimal | None:
        defined = [value for value in values if value is not None]
        if not defined:
            return None
        return percentile_inclusive(defined, percentile, context=self._context)

    # -- pass 3: normalize + combine + audit ----------------------------------
    def _finalize(
        self, prepared: _PreparedArtist, v_ref: Decimal | None, e_ref: Decimal | None
    ) -> ArtistScore:
        config = self._config
        context = self._context

        norm_velocity = self._sample_relative(prepared.velocity_median_per_day, v_ref)
        norm_engagement = self._sample_relative(prepared.engagement_raw, e_ref)
        norm_signals = ln_saturating(prepared.signals, config.signals_sat_cap, context=context)
        norm_diversity = ln_saturating(
            prepared.competition, config.diversity_target, context=context
        )

        continuous = raw_score(
            norm_velocity,
            norm_signals,
            norm_engagement,
            norm_diversity,
            w_vel=config.weight_velocity,
            w_sig=config.weight_signals,
            w_eng=config.weight_engagement,
            w_div=config.weight_diversity,
            context=context,
        )
        final = final_score_from_raw(continuous, context=context)

        components = ScoreComponents(
            norm_velocity=norm_velocity,
            norm_signals=norm_signals,
            norm_engagement=norm_engagement,
            norm_diversity=norm_diversity,
        )
        detail = self._detail(prepared, components, v_ref, e_ref)

        return ArtistScore(
            artist_id=prepared.artist_id,
            signals=prepared.signals,
            velocity_median_per_day=prepared.velocity_median_per_day,
            engagement_score=prepared.engagement_raw,
            channel_diversity_count=prepared.competition,
            channel_diversity_score=norm_diversity,
            components=components,
            raw_score=continuous,
            final_score=final,
            contributing_video_ids=prepared.contributing_video_ids,
            rubric_version=config.rubric_version,
            rubric_hash=config.rubric_hash,
            metrics_detail_json=detail,
        )

    def _sample_relative(self, value: Decimal | None, ref: Decimal | None) -> Decimal:
        # NULL (absent) contributes 0, never a fabricated statistic; a non-positive
        # anchor (whole reference set at/below 0) also yields 0 (no meaningful anchor).
        if value is None or ref is None or ref <= ZERO:
            return ZERO
        return normalized_ratio(value, ref, context=self._context)

    def _detail(
        self,
        prepared: _PreparedArtist,
        components: ScoreComponents,
        v_ref: Decimal | None,
        e_ref: Decimal | None,
    ) -> dict[str, Any]:
        config = self._config
        return {
            "components": [
                {
                    "key": KEY_VELOCITY,
                    "weight": str(config.weight_velocity),
                    "raw": _dec_str(prepared.velocity_median_per_day),
                    "norm": str(components.norm_velocity),
                },
                {
                    "key": KEY_SIGNALS,
                    "weight": str(config.weight_signals),
                    "raw": prepared.signals,
                    "norm": str(components.norm_signals),
                },
                {
                    "key": KEY_ENGAGEMENT,
                    "weight": str(config.weight_engagement),
                    "raw": _dec_str(prepared.engagement_raw),
                    "norm": str(components.norm_engagement),
                },
                {
                    "key": KEY_DIVERSITY,
                    "weight": str(config.weight_diversity),
                    "raw": prepared.competition,
                    "norm": str(components.norm_diversity),
                },
            ],
            "normalization": {
                "reference_set": "run_scored_artists",
                "velocity": {
                    "fn": "percentile_anchor_cap",
                    "p": str(config.p_vel),
                    "ref": _dec_str(v_ref),
                    "method": config.percentile_method,
                },
                "engagement": {
                    "fn": "percentile_anchor_cap",
                    "p": str(config.p_eng),
                    "ref": _dec_str(e_ref),
                    "method": config.percentile_method,
                },
                "signals": {"fn": "ln_saturating", "cap": config.signals_sat_cap},
                "diversity": {"fn": "ln_saturating", "target": config.diversity_target},
                "recency": {"fn": "exponential", "half_life_days": str(config.half_life_days)},
                "age_floor_days": str(config.age_floor_days),
                "rounding": FINAL_ROUNDING,
                "decimal_precision": config.decimal_precision,
            },
            "videos": {
                "accepted": list(prepared.accepted_rows),
                "rejected": list(prepared.rejected_rows),
            },
            "velocity": {
                "inputs": list(prepared.velocity_input_rows),
                "median": _dec_str(prepared.velocity_median_per_day),
            },
            "competition": {
                "eligible_channel_ids": list(prepared.eligible_channel_ids),
                "count": prepared.competition,
            },
            "versions": {
                "rubric_version": config.rubric_version,
                "rubric_hash": config.rubric_hash,
                "resolver_version": self._resolver_version,
                "rule_version": self._rule_version,
            },
            "overrides": list(prepared.overrides),
        }
