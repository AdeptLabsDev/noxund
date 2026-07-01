from __future__ import annotations

import json
import unittest
from dataclasses import fields
from datetime import datetime, timezone
from decimal import Decimal, localcontext
from typing import Any, Sequence

from noxund_data_engine.channel_filter import RULE_VERSION, ArtistProjection
from noxund_data_engine.entity_resolution import RESOLVER_VERSION
from noxund_data_engine.scoring import (
    AGE_FLOOR_DAYS,
    DEFAULT_CONTEXT,
    DEFAULT_RUBRIC,
    ONE,
    P_ENG,
    P_VEL,
    RUBRIC_VERSION,
    ZERO,
    ArtistScore,
    ArtistScoringInput,
    ContractViolation,
    PopularityScorer,
    RubricConfig,
    VideoStats,
    effective_age_days,
    engagement_rate,
    final_score_from_raw,
    ln_saturating,
    median,
    percentile_inclusive,
    recency_weight,
    weighted_average,
)


RUN_ID = "00000000-0000-0000-0000-000000000001"
# Frozen run reference. Deliberately in the past so a wall-clock leak would diverge.
WINDOW_END = datetime(2026, 6, 30, tzinfo=timezone.utc)


def _dt(year: int, month: int, day: int) -> datetime:
    return datetime(year, month, day, tzinfo=timezone.utc)


def _video(
    video_id: str,
    *,
    views: int | None,
    likes: int | None = None,
    comments: int | None = None,
    published_at: datetime = WINDOW_END,
) -> VideoStats:
    return VideoStats(
        video_id=video_id,
        views=views,
        likes=likes,
        comments=comments,
        published_at=published_at,
    )


def _input(
    artist_id: str,
    videos: Sequence[VideoStats],
    *,
    channels: Sequence[str] | None = None,
) -> ArtistScoringInput:
    valid_video_ids = tuple(sorted(video.video_id for video in videos))
    eligible = tuple(sorted(channels if channels is not None else (f"chan-{artist_id}",)))
    projection = ArtistProjection(
        artist_id=artist_id,
        valid_video_ids=valid_video_ids,
        eligible_channel_ids=eligible,
    )
    return ArtistScoringInput(
        artist_id=artist_id, videos=tuple(videos), projection=projection
    )


def _solo(
    artist_id: str,
    *,
    views: int | None,
    likes: int | None = None,
    comments: int | None = None,
    published_at: datetime = WINDOW_END,
    channels: Sequence[str] | None = None,
) -> ArtistScoringInput:
    video = _video(
        f"v-{artist_id}",
        views=views,
        likes=likes,
        comments=comments,
        published_at=published_at,
    )
    return _input(artist_id, [video], channels=channels)


def _detail_structurally_complete(detail: Any) -> bool:
    """Python mirror of the SQL validator ``artist_metrics_detail_complete`` (F5-06A)."""

    if not isinstance(detail, dict):
        return False
    components = detail.get("components")
    if not isinstance(components, (list, dict)) or components in ([], {}):
        return False
    if "normalization" not in detail:
        return False
    videos = detail.get("videos")
    if not isinstance(videos, dict):
        return False
    if not isinstance(videos.get("accepted"), list) or len(videos["accepted"]) < 1:
        return False
    if not isinstance(videos.get("rejected"), list):
        return False
    velocity = detail.get("velocity")
    if not isinstance(velocity, dict) or "inputs" not in velocity or "median" not in velocity:
        return False
    competition = detail.get("competition")
    if not isinstance(competition, dict):
        return False
    if not isinstance(competition.get("eligible_channel_ids"), list):
        return False
    if "count" not in competition:
        return False
    versions = detail.get("versions")
    if not isinstance(versions, dict):
        return False
    for key in ("rubric_version", "rubric_hash", "resolver_version", "rule_version"):
        if not versions.get(key):
            return False
    overrides = detail.get("overrides")
    if not isinstance(overrides, list):
        return False
    for override in overrides:
        if not (
            isinstance(override, dict)
            and "run_id" in override
            and ("video_id" in override or "channel_id" in override)
        ):
            return False
    return True


class RubricIdentityTests(unittest.TestCase):
    def test_rubric_version_and_hash_are_stable_and_frozen(self) -> None:
        self.assertEqual(RUBRIC_VERSION, "score_rubric_2026_06_v1")
        self.assertEqual(DEFAULT_RUBRIC.rubric_version, RUBRIC_VERSION)

        rubric_hash = DEFAULT_RUBRIC.rubric_hash
        self.assertEqual(len(rubric_hash), 64)
        self.assertTrue(all(character in "0123456789abcdef" for character in rubric_hash))
        # Stable across independently constructed identical configs.
        self.assertEqual(RubricConfig().rubric_hash, rubric_hash)
        # A produced score carries the same frozen version + hash.
        result = PopularityScorer().score_run(
            run_id=RUN_ID, artists=[_solo("a", views=10)], window_end=WINDOW_END
        )
        self.assertEqual(result.rubric_hash, rubric_hash)
        self.assertEqual(result.rubric_version, RUBRIC_VERSION)
        self.assertEqual(result.scores[0].rubric_hash, rubric_hash)

    def test_rubric_hash_is_sensitive_to_each_constant(self) -> None:
        baseline = DEFAULT_RUBRIC.rubric_hash
        # Every ratified knob is inside the hash: bumping any one changes it.
        self.assertNotEqual(RubricConfig(signals_sat_cap=21).rubric_hash, baseline)
        self.assertNotEqual(RubricConfig(diversity_target=16).rubric_hash, baseline)
        self.assertNotEqual(RubricConfig(p_vel=Decimal("0.95")).rubric_hash, baseline)
        self.assertNotEqual(RubricConfig(p_eng=Decimal("0.95")).rubric_hash, baseline)
        self.assertNotEqual(RubricConfig(half_life_days=Decimal("10")).rubric_hash, baseline)
        self.assertNotEqual(RubricConfig(age_floor_days=Decimal("2")).rubric_hash, baseline)
        self.assertNotEqual(RubricConfig(decimal_precision=40).rubric_hash, baseline)
        self.assertNotEqual(
            RubricConfig(percentile_method="min_max").rubric_hash, baseline
        )
        self.assertNotEqual(
            RubricConfig(recency_method="linear").rubric_hash, baseline
        )

    def test_weights_are_locked_and_must_sum_to_one(self) -> None:
        self.assertEqual(DEFAULT_RUBRIC.weight_velocity, Decimal("0.40"))
        self.assertEqual(DEFAULT_RUBRIC.weight_signals, Decimal("0.25"))
        self.assertEqual(DEFAULT_RUBRIC.weight_engagement, Decimal("0.20"))
        self.assertEqual(DEFAULT_RUBRIC.weight_diversity, Decimal("0.15"))
        # Tampering with a weight so the four no longer sum to 1.00 is rejected.
        with self.assertRaises(ContractViolation):
            RubricConfig(weight_velocity=Decimal("0.50"))


class PrimitiveTests(unittest.TestCase):
    def test_recency_weight_is_exponential_with_15_day_half_life(self) -> None:
        # One half-life (15d) halves the weight; two quarter it; age 0 -> 1.
        self.assertEqual(recency_weight(ZERO), ONE)
        self.assertLess(abs(recency_weight(Decimal("15")) - Decimal("0.5")), Decimal("1e-30"))
        self.assertLess(abs(recency_weight(Decimal("30")) - Decimal("0.25")), Decimal("1e-30"))
        # Strictly monotonic decreasing in age.
        self.assertGreater(recency_weight(Decimal("1")), recency_weight(Decimal("2")))

    def test_ln_saturating_signals_at_and_above_cap(self) -> None:
        cap = DEFAULT_RUBRIC.signals_sat_cap  # 20
        # At the cap the curve reaches exactly 1; above it stays capped at 1.
        self.assertEqual(ln_saturating(cap, cap), ONE)
        self.assertEqual(ln_saturating(cap + 5, cap), ONE)
        # A mid count is strictly between 0 and 1 and matches the ln formula.
        with localcontext(DEFAULT_CONTEXT):
            expected = Decimal(1 + 7).ln() / Decimal(1 + cap).ln()
        self.assertEqual(ln_saturating(7, cap), expected)
        self.assertLess(ZERO, expected)
        self.assertLess(expected, ONE)

    def test_ln_saturating_diversity_uses_target(self) -> None:
        target = DEFAULT_RUBRIC.diversity_target  # 15
        self.assertEqual(ln_saturating(target, target), ONE)
        self.assertEqual(ln_saturating(target + 3, target), ONE)
        self.assertLess(ln_saturating(1, target), ONE)

    def test_median_odd_even_and_deterministic(self) -> None:
        self.assertEqual(median([Decimal("3"), Decimal("1"), Decimal("2")]), Decimal("2"))
        # Even count -> exact arithmetic mean of the two central order statistics.
        self.assertEqual(
            median([Decimal("4"), Decimal("1"), Decimal("2"), Decimal("3")]),
            Decimal("2.5"),
        )
        with self.assertRaises(ContractViolation):
            median([])

    def test_percentile_inclusive_linear_interpolation(self) -> None:
        values = [Decimal(i) for i in range(1, 11)]  # 1..10
        # rank = (10-1)*0.9 = 8.1 -> interpolate between order stats 9 and 10.
        self.assertEqual(percentile_inclusive(values, P_VEL), Decimal("9.1"))
        # A single-element reference set returns itself.
        self.assertEqual(percentile_inclusive([Decimal("42")], P_VEL), Decimal("42"))
        # p90 of two values interpolates 90% of the way to the max.
        self.assertEqual(
            percentile_inclusive([Decimal("0"), Decimal("10")], P_VEL), Decimal("9")
        )

    def test_final_score_rounds_half_up_at_90_5_and_83(self) -> None:
        # ROUND_HALF_UP at the exact .5 boundaries (half-even would give 90 and 82).
        self.assertEqual(final_score_from_raw(Decimal("90.5")), 91)
        self.assertEqual(final_score_from_raw(Decimal("82.5")), 83)
        self.assertEqual(final_score_from_raw(Decimal("83.5")), 84)
        self.assertEqual(final_score_from_raw(Decimal("83.49")), 83)
        self.assertEqual(final_score_from_raw(Decimal("0")), 0)
        self.assertEqual(final_score_from_raw(Decimal("100")), 100)

    def test_engagement_rate_null_likes_comments_are_absent_not_zero(self) -> None:
        # Missing likes/comments are an absent numerator contribution -> rate 0/views.
        self.assertEqual(engagement_rate(None, None, 100), ZERO)
        self.assertEqual(engagement_rate(50, 0, 100), Decimal("0.5"))


class ScoringBehaviourTests(unittest.TestCase):
    def setUp(self) -> None:
        self.scorer = PopularityScorer()

    def test_velocity_uses_frozen_window_end_not_wall_clock(self) -> None:
        # Published exactly 10 days before the frozen window_end.
        artist = _solo("a", views=1000, published_at=_dt(2026, 6, 20))
        result = self.scorer.score_run(
            run_id=RUN_ID, artists=[artist], window_end=WINDOW_END
        )
        score = result.score_for("a")
        assert score is not None
        # 1000 views / 10 days = 100/day, computed from window_end (not "today").
        self.assertEqual(score.velocity_median_per_day, Decimal("100"))
        self.assertEqual(score.metrics_detail_json["velocity"]["median"], "100")
        self.assertEqual(
            score.metrics_detail_json["velocity"]["inputs"][0]["age_days"], "10"
        )

    def test_velocity_normalization_p90_anchor_and_cap(self) -> None:
        # 10 artists, one video each published at window_end (age floored to 1 day),
        # so vel_artist == views == 1..10. p90 anchor V_REF == 9.1.
        artists = [
            _solo(f"a{i:02d}", views=i, channels=(f"c{i}",)) for i in range(1, 11)
        ]
        result = self.scorer.score_run(
            run_id=RUN_ID, artists=artists, window_end=WINDOW_END
        )

        v_ref = percentile_inclusive([Decimal(i) for i in range(1, 11)], P_VEL)
        self.assertEqual(v_ref, Decimal("9.1"))
        self.assertEqual(
            Decimal(result.score_for("a10").metrics_detail_json["normalization"]["velocity"]["ref"]),
            v_ref,
        )
        # Top artist is above the anchor -> capped at exactly 1.
        self.assertEqual(result.score_for("a10").components.norm_velocity, ONE)
        # A below-anchor artist normalizes to value / V_REF (< 1).
        with localcontext(DEFAULT_CONTEXT):
            expected = Decimal(5) / v_ref
        self.assertEqual(result.score_for("a05").components.norm_velocity, expected)
        self.assertLess(result.score_for("a05").components.norm_velocity, ONE)

    def test_engagement_recency_weighted_average_and_null_policy(self) -> None:
        # v1 recent (age->floor 1), v2 one half-life old (15d). Recent video weighs more.
        videos = [
            _video("v1", views=100, likes=50, comments=0, published_at=WINDOW_END),
            _video("v2", views=100, likes=10, comments=0, published_at=_dt(2026, 6, 15)),
        ]
        artist = _input("a", videos)
        result = self.scorer.score_run(
            run_id=RUN_ID, artists=[artist], window_end=WINDOW_END
        )
        score = result.score_for("a")
        assert score is not None

        w1 = recency_weight(effective_age_days(WINDOW_END, WINDOW_END))
        w2 = recency_weight(effective_age_days(_dt(2026, 6, 15), WINDOW_END))
        eng1 = engagement_rate(50, 0, 100)  # 0.5
        eng2 = engagement_rate(10, 0, 100)  # 0.1
        expected = weighted_average([(w1, eng1), (w2, eng2)])

        self.assertEqual(score.engagement_score, expected)
        # Recent 0.5 dominates the stale 0.1: the weighted mean exceeds the flat mean.
        self.assertGreater(expected, Decimal("0.3"))

    def test_signals_and_diversity_consumed_from_projection(self) -> None:
        # 3 valid videos across 2 eligible channels: Signals=3, Competition=2 come
        # verbatim from the projection; the scorer only normalizes them.
        videos = [_video(f"v{i}", views=100) for i in range(3)]
        artist = _input("a", videos, channels=("c1", "c2"))
        result = self.scorer.score_run(
            run_id=RUN_ID, artists=[artist], window_end=WINDOW_END
        )
        score = result.score_for("a")
        assert score is not None
        self.assertEqual(score.signals, 3)
        self.assertEqual(score.channel_diversity_count, 2)
        self.assertEqual(score.components.norm_signals, ln_saturating(3, 20))
        self.assertEqual(score.components.norm_diversity, ln_saturating(2, 15))
        self.assertEqual(score.channel_diversity_score, score.components.norm_diversity)

    def test_projection_video_mismatch_is_rejected(self) -> None:
        # Videos and projection.valid_video_ids must be the same set (dedup by id).
        projection = ArtistProjection(
            artist_id="a",
            valid_video_ids=("v1", "v2"),
            eligible_channel_ids=("c1",),
        )
        artist = ArtistScoringInput(
            artist_id="a", videos=(_video("v1", views=1),), projection=projection
        )
        with self.assertRaises(ContractViolation):
            self.scorer.score_run(run_id=RUN_ID, artists=[artist], window_end=WINDOW_END)

    def test_run_relative_reference_composition_dependence(self) -> None:
        # Same artist, two different runs: alone it caps at 1; alongside a much faster
        # artist its Velocity norm drops. The reference set is the run itself.
        alone = self.scorer.score_run(
            run_id=RUN_ID, artists=[_solo("a", views=10)], window_end=WINDOW_END
        )
        self.assertEqual(alone.score_for("a").components.norm_velocity, ONE)

        together = self.scorer.score_run(
            run_id=RUN_ID,
            artists=[_solo("a", views=10), _solo("b", views=1000, channels=("cb",))],
            window_end=WINDOW_END,
        )
        self.assertLess(together.score_for("a").components.norm_velocity, ONE)

    def test_single_artist_caps_components_at_one(self) -> None:
        artist = _solo("a", views=500, likes=50, comments=50)
        result = self.scorer.score_run(
            run_id=RUN_ID, artists=[artist], window_end=WINDOW_END
        )
        score = result.score_for("a")
        assert score is not None
        # With a one-artist reference set, Velocity and Engagement anchor to self -> 1.
        self.assertEqual(score.components.norm_velocity, ONE)
        self.assertEqual(score.components.norm_engagement, ONE)

    def test_all_null_views_velocity_and_engagement_null_but_still_scored(self) -> None:
        # No views anywhere: Velocity + Engagement undefined (NULL, not 0), yet the
        # artist is still scored by Signals + Diversity.
        artist = _solo("a", views=None)
        result = self.scorer.score_run(
            run_id=RUN_ID, artists=[artist], window_end=WINDOW_END
        )
        score = result.score_for("a")
        assert score is not None
        self.assertIsNone(score.velocity_median_per_day)
        self.assertIsNone(score.engagement_score)
        self.assertEqual(score.components.norm_velocity, ZERO)
        self.assertEqual(score.components.norm_engagement, ZERO)
        # Still produces a valid integer score from the other two components.
        self.assertGreater(score.final_score, 0)
        self.assertLessEqual(score.final_score, 100)
        reasons = {r["reason"] for r in score.metrics_detail_json["videos"]["rejected"]}
        self.assertIn("views_null", reasons)

    def test_null_views_distinct_from_zero_views(self) -> None:
        # X: views NULL -> velocity NULL. Z: views 0 -> velocity 0 (a real zero).
        artist_null = _solo("x", views=None)
        artist_zero = _solo("z", views=0, likes=5, channels=("cz",))
        result = self.scorer.score_run(
            run_id=RUN_ID, artists=[artist_null, artist_zero], window_end=WINDOW_END
        )
        self.assertIsNone(result.score_for("x").velocity_median_per_day)
        self.assertEqual(result.score_for("z").velocity_median_per_day, ZERO)
        # views==0 is excluded from Engagement (rate undefined), not from Velocity.
        self.assertIsNone(result.score_for("z").engagement_score)
        reasons = {r["reason"] for r in result.score_for("z").metrics_detail_json["videos"]["rejected"]}
        self.assertIn("views_null_or_zero", reasons)

    def test_ties_produce_identical_scores(self) -> None:
        # Two artists with identical inputs get identical components and final_score.
        first = _solo("a", views=250, likes=20, comments=5)
        second = _solo("b", views=250, likes=20, comments=5, channels=("chan-b",))
        result = self.scorer.score_run(
            run_id=RUN_ID, artists=[first, second], window_end=WINDOW_END
        )
        a = result.score_for("a")
        b = result.score_for("b")
        assert a is not None and b is not None
        self.assertEqual(a.final_score, b.final_score)
        self.assertEqual(a.components, b.components)

    def test_determinism_same_inputs_byte_identical(self) -> None:
        artists = [
            _input(
                "a",
                [
                    _video("a1", views=1200, likes=90, comments=10, published_at=_dt(2026, 6, 25)),
                    _video("a2", views=None, published_at=_dt(2026, 6, 10)),
                    _video("a3", views=0, likes=3, published_at=_dt(2026, 6, 1)),
                ],
                channels=("c1", "c2"),
            ),
            _solo("b", views=300, likes=15, published_at=_dt(2026, 6, 18), channels=("cb",)),
            _solo("c", views=300, likes=15, published_at=_dt(2026, 6, 18), channels=("cc",)),
        ]
        first = PopularityScorer().score_run(
            run_id=RUN_ID, artists=artists, window_end=WINDOW_END
        )
        second = PopularityScorer().score_run(
            run_id=RUN_ID, artists=artists, window_end=WINDOW_END
        )
        self.assertEqual(first.scores, second.scores)
        self.assertEqual(first.rubric_hash, second.rubric_hash)

    def test_metrics_detail_json_satisfies_structural_validator(self) -> None:
        artist = _input(
            "a",
            [
                _video("v1", views=500, likes=40, comments=10),
                _video("v2", views=None, published_at=_dt(2026, 6, 5)),
            ],
            channels=("c1", "c2"),
        )
        result = self.scorer.score_run(
            run_id=RUN_ID, artists=[artist], window_end=WINDOW_END
        )
        detail = result.score_for("a").metrics_detail_json

        self.assertTrue(_detail_structurally_complete(detail))
        # Persist-ready: the whole evidence is JSON-serializable.
        json.dumps(detail)
        self.assertEqual(len(detail["components"]), 4)
        self.assertEqual(detail["normalization"]["reference_set"], "run_scored_artists")
        self.assertEqual(detail["versions"]["rubric_version"], RUBRIC_VERSION)
        self.assertEqual(detail["versions"]["resolver_version"], RESOLVER_VERSION)
        self.assertEqual(detail["versions"]["rule_version"], RULE_VERSION)
        self.assertEqual(detail["versions"]["rubric_hash"], DEFAULT_RUBRIC.rubric_hash)
        self.assertEqual(detail["overrides"], [])

    def test_provenance_carries_contributing_video_ids(self) -> None:
        artist = _input(
            "a",
            [_video("v-b", views=100), _video("v-a", views=None)],
            channels=("c1",),
        )
        result = self.scorer.score_run(
            run_id=RUN_ID, artists=[artist], window_end=WINDOW_END
        )
        score = result.score_for("a")
        assert score is not None
        # Provenance = the full ValidVideos set (accepted), sorted, deduped.
        self.assertEqual(score.contributing_video_ids, ("v-a", "v-b"))
        accepted = {row["video_id"] for row in score.metrics_detail_json["videos"]["accepted"]}
        self.assertEqual(accepted, {"v-a", "v-b"})
        # Velocity inputs only carry the views-present video.
        velocity_inputs = [i["video_id"] for i in score.metrics_detail_json["velocity"]["inputs"]]
        self.assertEqual(velocity_inputs, ["v-b"])

    def test_zero_signal_artist_is_not_scorable(self) -> None:
        projection = ArtistProjection(
            artist_id="a", valid_video_ids=(), eligible_channel_ids=()
        )
        artist = ArtistScoringInput(artist_id="a", videos=(), projection=projection)
        with self.assertRaises(ContractViolation):
            self.scorer.score_run(run_id=RUN_ID, artists=[artist], window_end=WINDOW_END)

    def test_contract_violations_are_rejected(self) -> None:
        good = _solo("a", views=10)
        with self.assertRaises(ContractViolation):
            self.scorer.score_run(run_id="   ", artists=[good], window_end=WINDOW_END)
        # Naive (tz-unaware) window_end is rejected (no wall-clock ambiguity allowed).
        with self.assertRaises(ContractViolation):
            self.scorer.score_run(
                run_id=RUN_ID, artists=[good], window_end=datetime(2026, 6, 30)
            )
        # Duplicate artist_id in one run.
        with self.assertRaises(ContractViolation):
            self.scorer.score_run(
                run_id=RUN_ID,
                artists=[_solo("a", views=1), _solo("a", views=2)],
                window_end=WINDOW_END,
            )
        # projection.artist_id must match the input artist_id.
        mismatched = ArtistScoringInput(
            artist_id="a",
            videos=(_video("v-a", views=1),),
            projection=ArtistProjection(
                artist_id="other", valid_video_ids=("v-a",), eligible_channel_ids=("c1",)
            ),
        )
        with self.assertRaises(ContractViolation):
            self.scorer.score_run(
                run_id=RUN_ID, artists=[mismatched], window_end=WINDOW_END
            )

    def test_scoring_does_not_leak_opportunity_fields(self) -> None:
        # Boundary guard: the Score exposes the number + 4 components only. Ranking,
        # HOT tag, display gate, Competition label and Example are Agente 6's.
        field_names = {f.name for f in fields(ArtistScore)}
        forbidden = {
            "rank",
            "ranking",
            "tag",
            "hot",
            "is_hot",
            "score_display",
            "display",
            "competition_level",
            "example",
            "selected_example",
        }
        self.assertEqual(field_names & forbidden, set())

        # Output order is a stable natural key (artist_id), NOT a ranking by score:
        # z-artist scores higher yet still sorts after a-artist.
        result = self.scorer.score_run(
            run_id=RUN_ID,
            artists=[
                _solo("z-artist", views=1000, channels=("cz",)),
                _solo("a-artist", views=1, channels=("ca",)),
            ],
            window_end=WINDOW_END,
        )
        order = [score.artist_id for score in result.scores]
        self.assertEqual(order, ["a-artist", "z-artist"])
        self.assertGreater(
            result.score_for("z-artist").final_score,
            result.score_for("a-artist").final_score,
        )


if __name__ == "__main__":
    unittest.main()
