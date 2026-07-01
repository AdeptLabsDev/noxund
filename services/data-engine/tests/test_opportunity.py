from __future__ import annotations

import json
import unittest
from datetime import datetime, timezone
from decimal import Decimal
from typing import Any, Sequence

from noxund_data_engine.scoring import RUBRIC_VERSION, ArtistScore, ScoreComponents
from noxund_data_engine.opportunity import (
    DEFAULT_CONFIG,
    DISPLAY_GATE_MIN,
    GROWTH_HIGH_PCT,
    HOT_MAX,
    HOT_SCORE_MIN_EXCLUSIVE,
    LOW_CHANNEL_MAX,
    MAX_REPORT_ITEMS,
    OPPORTUNITY_VERSION,
    ArtistOpportunityInput,
    ContractViolation,
    OpportunityBuilder,
    OpportunityConfig,
    ValidVideo,
    base_competition_level,
    format_velocity_display,
    publication_windows,
)


RUN_ID = "00000000-0000-0000-0000-000000000001"
RUBRIC_HASH = "a" * 64
WINDOW_END = datetime(2026, 6, 30, tzinfo=timezone.utc)


def _dt(year: int, month: int, day: int) -> datetime:
    return datetime(year, month, day, tzinfo=timezone.utc)


def _vv(
    video_id: str,
    *,
    views: int | None = 100,
    vel: Decimal | None = Decimal("10"),
    published_at: datetime = WINDOW_END,
) -> ValidVideo:
    return ValidVideo(video_id=video_id, views=views, vel=vel, published_at=published_at)


def _score(
    artist_id: str,
    *,
    final_score: int,
    velocity_median: Decimal | None = Decimal("100"),
    signals: int = 1,
    channel_count: int = 1,
    video_ids: Sequence[str] | None = None,
    norm_velocity: Decimal = Decimal("0.5"),
    norm_signals: Decimal = Decimal("0.5"),
    rubric_version: str = RUBRIC_VERSION,
    rubric_hash: str = RUBRIC_HASH,
) -> ArtistScore:
    ids = tuple(sorted(video_ids if video_ids is not None else (f"v-{artist_id}",)))
    components = ScoreComponents(
        norm_velocity=norm_velocity,
        norm_signals=norm_signals,
        norm_engagement=Decimal("0"),
        norm_diversity=Decimal("0"),
    )
    return ArtistScore(
        artist_id=artist_id,
        signals=signals,
        velocity_median_per_day=velocity_median,
        engagement_score=None,
        channel_diversity_count=channel_count,
        channel_diversity_score=Decimal("0"),
        components=components,
        raw_score=Decimal(final_score),
        final_score=final_score,
        contributing_video_ids=ids,
        rubric_version=rubric_version,
        rubric_hash=rubric_hash,
    )


def _artist(
    artist_id: str,
    *,
    final_score: int,
    videos: Sequence[ValidVideo] | None = None,
    canonical_name: str | None = None,
    **score_kw: Any,
) -> ArtistOpportunityInput:
    vids = list(videos) if videos is not None else [_vv(f"v-{artist_id}")]
    video_ids = tuple(sorted(video.video_id for video in vids))
    score = _score(artist_id, final_score=final_score, video_ids=video_ids, **score_kw)
    return ArtistOpportunityInput(
        score=score,
        valid_videos=vids,
        canonical_name=canonical_name or artist_id.replace("-", " ").title(),
    )


def _build(
    artists: Sequence[ArtistOpportunityInput],
    *,
    run_id: str = RUN_ID,
    title: str = "Relatório 1 de 2",
    window_end: datetime = WINDOW_END,
    config: OpportunityConfig = DEFAULT_CONFIG,
) -> Any:
    return OpportunityBuilder(config=config).build_report(
        run_id=run_id, report_title=title, artists=artists, window_end=window_end
    )


def _reason_structurally_complete(reason: Any) -> bool:
    """Python mirror of the SQL validator ``report_item_reason_complete`` (F5-05A)."""

    if not isinstance(reason, dict):
        return False
    candidates = reason.get("candidates")
    if not isinstance(candidates, list) or len(candidates) < 1:
        return False
    top3 = reason.get("top3")
    if not isinstance(top3, list) or len(top3) < 1:
        return False
    if "tiebreak" not in reason:
        return False
    selected = reason.get("selected_example")
    if not isinstance(selected, dict):
        return False
    if not selected.get("video_id"):
        return False
    return True


class OpportunityConfigTests(unittest.TestCase):
    def test_version_and_hash_stable_and_frozen(self) -> None:
        self.assertEqual(OPPORTUNITY_VERSION, "opportunity-rules-2026_06_v1")
        self.assertEqual(DEFAULT_CONFIG.opportunity_version, OPPORTUNITY_VERSION)
        opportunity_hash = DEFAULT_CONFIG.opportunity_hash
        self.assertEqual(len(opportunity_hash), 64)
        self.assertTrue(all(ch in "0123456789abcdef" for ch in opportunity_hash))
        # Stable across independently constructed identical configs.
        self.assertEqual(OpportunityConfig().opportunity_hash, opportunity_hash)

    def test_hash_sensitive_to_each_constant(self) -> None:
        baseline = DEFAULT_CONFIG.opportunity_hash
        self.assertNotEqual(
            OpportunityConfig(hot_score_min_exclusive=89).opportunity_hash, baseline
        )
        self.assertNotEqual(OpportunityConfig(hot_max=1).opportunity_hash, baseline)
        self.assertNotEqual(OpportunityConfig(display_gate_min=84).opportunity_hash, baseline)
        self.assertNotEqual(OpportunityConfig(max_report_items=8).opportunity_hash, baseline)
        self.assertNotEqual(OpportunityConfig(low_channel_max=4).opportunity_hash, baseline)
        self.assertNotEqual(OpportunityConfig(high_channel_max=16).opportunity_hash, baseline)
        self.assertNotEqual(
            OpportunityConfig(growth_high_pct=Decimal("0.75")).opportunity_hash, baseline
        )
        self.assertNotEqual(OpportunityConfig(growth_window_days=14).opportunity_hash, baseline)

    def test_ratified_constants_are_locked(self) -> None:
        self.assertEqual(HOT_SCORE_MIN_EXCLUSIVE, 90)
        self.assertEqual(HOT_MAX, 2)
        self.assertEqual(DISPLAY_GATE_MIN, 83)
        self.assertEqual(MAX_REPORT_ITEMS, 10)
        self.assertEqual(LOW_CHANNEL_MAX, 5)
        self.assertEqual(GROWTH_HIGH_PCT, Decimal("0.50"))

    def test_invalid_configs_are_rejected(self) -> None:
        with self.assertRaises(ContractViolation):
            OpportunityConfig(max_report_items=0)
        with self.assertRaises(ContractViolation):
            OpportunityConfig(low_channel_max=15, high_channel_max=5)
        with self.assertRaises(ContractViolation):
            # HOT threshold below the display gate would allow a HOT that is not shown.
            OpportunityConfig(hot_score_min_exclusive=80, display_gate_min=83)
        with self.assertRaises(ContractViolation):
            OpportunityConfig(prior_zero_rule="promote-high")


class RankingTests(unittest.TestCase):
    def test_primary_order_by_final_score_desc(self) -> None:
        report = _build(
            [
                _artist("a", final_score=85),
                _artist("b", final_score=95),
                _artist("c", final_score=90),
            ]
        )
        self.assertEqual([item.artist_id for item in report.items], ["b", "c", "a"])
        self.assertEqual([item.rank for item in report.items], [1, 2, 3])

    def test_tiebreak_velocity_then_signals_then_artist_id(self) -> None:
        # All final_score == 85; order decided by velocity_component, then signals.
        def _tb(artist_id: str, vel: str, sig: str) -> ArtistOpportunityInput:
            return _artist(
                artist_id, final_score=85,
                norm_velocity=Decimal(vel), norm_signals=Decimal(sig),
            )

        a1 = _tb("a1", "0.9", "0.1")  # highest velocity_component
        a2 = _tb("a2", "0.5", "0.9")  # tied velocity, highest signals_component
        a3 = _tb("a3", "0.5", "0.5")  # tied velocity, lowest signals
        report = _build([a3, a1, a2])  # shuffled input
        self.assertEqual([item.artist_id for item in report.items], ["a1", "a2", "a3"])

    def test_full_tie_breaks_by_artist_id_ascending(self) -> None:
        # Identical scores and components: the natural key artist_id breaks the tie.
        report = _build(
            [
                _artist("z-artist", final_score=88),
                _artist("a-artist", final_score=88),
            ]
        )
        self.assertEqual([item.artist_id for item in report.items], ["a-artist", "z-artist"])


class HotTests(unittest.TestCase):
    def test_exactly_two_hot_when_two_cross_90(self) -> None:
        report = _build(
            [
                _artist("h1", final_score=95),
                _artist("h2", final_score=92),
                _artist("n", final_score=88),
            ]
        )
        self.assertEqual(report.hot_artist_ids, ("h1", "h2"))
        self.assertIsNone(report.item_for("n").tag)

    def test_hot_capped_at_two_when_more_than_two_cross_90(self) -> None:
        # Three cross 90 -> only the top two get HOT; the third shows its score, no badge.
        report = _build(
            [
                _artist("h1", final_score=95),
                _artist("h2", final_score=93),
                _artist("h3", final_score=91),
                _artist("n", final_score=85),
            ]
        )
        self.assertEqual(report.hot_artist_ids, ("h1", "h2"))
        self.assertIsNone(report.item_for("h3").tag)
        self.assertEqual(report.item_for("h3").score_display, "91/100")

    def test_one_hot_when_only_one_crosses_90(self) -> None:
        report = _build(
            [
                _artist("h1", final_score=95),
                _artist("n1", final_score=90),
                _artist("n2", final_score=85),
            ]
        )
        self.assertEqual(report.hot_artist_ids, ("h1",))

    def test_zero_hot_when_none_cross_90(self) -> None:
        report = _build(
            [
                _artist("a", final_score=90),
                _artist("b", final_score=88),
                _artist("c", final_score=85),
            ]
        )
        self.assertEqual(report.hot_artist_ids, ())

    def test_never_promotes_score_equal_to_90(self) -> None:
        # 90 is NOT > 90: never fabricated into HOT to reach a quota of 2.
        report = _build(
            [
                _artist("a", final_score=90),
                _artist("b", final_score=85),
            ]
        )
        self.assertEqual(report.hot_artist_ids, ())
        self.assertIsNotNone(report.item_for("a"))
        self.assertIsNotNone(report.item_for("b"))


class DisplayGateAndCompositionTests(unittest.TestCase):
    def test_display_gate_83_boundary(self) -> None:
        report = _build(
            [
                _artist("q", final_score=83),
                _artist("nq", final_score=82),
            ]
        )
        self.assertFalse(report.insufficient_opportunity)
        self.assertIsNotNone(report.item_for("q"))
        self.assertIsNone(report.item_for("nq"))
        self.assertEqual(len(report.items), 1)
        self.assertEqual(report.item_for("q").score_display, "83/100")

    def test_insufficient_opportunity_when_all_below_83(self) -> None:
        report = _build(
            [
                _artist("a", final_score=80),
                _artist("b", final_score=70),
            ]
        )
        self.assertTrue(report.insufficient_opportunity)
        self.assertEqual(report.items, ())
        self.assertEqual(report.status, "draft")
        # Even an empty report still carries its frozen versions.
        self.assertEqual(report.opportunity_hash, DEFAULT_CONFIG.opportunity_hash)
        self.assertEqual(report.rubric_version, RUBRIC_VERSION)

    def test_fewer_than_ten_qualified_shows_fewer(self) -> None:
        report = _build([_artist(f"a{i}", final_score=90) for i in range(3)])
        self.assertEqual(len(report.items), 3)

    def test_caps_at_ten_items(self) -> None:
        # 12 qualified; only the top 10 by rank compose the report.
        artists = [_artist(f"a{i:02d}", final_score=83 + i) for i in range(12)]
        report = _build(artists)
        self.assertEqual(len(report.items), 10)
        self.assertEqual([item.rank for item in report.items], list(range(1, 11)))
        # The two lowest scores (a00=83, a01=84) are dropped, never a padded slot.
        self.assertIsNone(report.item_for("a00"))
        self.assertIsNone(report.item_for("a01"))

    def test_score_display_present_and_formatted_for_qualified(self) -> None:
        report = _build([_artist("a", final_score=87)])
        self.assertEqual(report.item_for("a").score_display, "87/100")
        self.assertEqual(report.item_for("a").score_value, 87)


class CompetitionTests(unittest.TestCase):
    def test_base_level_bucket_boundaries(self) -> None:
        self.assertEqual(base_competition_level(5), "Low")
        self.assertEqual(base_competition_level(6), "Medium")
        self.assertEqual(base_competition_level(15), "Medium")
        self.assertEqual(base_competition_level(16), "High")

    def test_bucket_boundaries_in_report_without_growth(self) -> None:
        # Single video at window_end => prior_7d == 0 => no growth trigger => base level.
        report = _build(
            [
                _artist("a5", final_score=90, channel_count=5),
                _artist("a6", final_score=90, channel_count=6),
                _artist("a15", final_score=90, channel_count=15),
                _artist("a16", final_score=90, channel_count=16),
            ]
        )
        self.assertEqual(report.item_for("a5").competition_level, "Low")
        self.assertEqual(report.item_for("a6").competition_level, "Medium")
        self.assertEqual(report.item_for("a15").competition_level, "Medium")
        self.assertEqual(report.item_for("a16").competition_level, "High")

    def test_growth_override_raises_to_high(self) -> None:
        # base Low (count 1) but recent_7d=2 vs prior_7d=1 => growth 100% > 50% => High.
        videos = [
            _vv("g1", published_at=WINDOW_END),
            _vv("g2", published_at=_dt(2026, 6, 28)),
            _vv("g3", published_at=_dt(2026, 6, 20)),
        ]
        report = _build([_artist("g", final_score=90, channel_count=1, videos=videos)])
        item = report.item_for("g")
        self.assertEqual(item.competition_level, "High")
        competition = item.selection_reason_json["competition"]
        self.assertEqual(competition["recent_7d"], 2)
        self.assertEqual(competition["prior_7d"], 1)
        self.assertEqual(competition["growth_7d"], "1")
        self.assertTrue(competition["growth_triggered"])

    def test_growth_prior_zero_is_no_trigger(self) -> None:
        # All publications in the recent window => prior_7d == 0 => fail-closed: no High.
        videos = [
            _vv("p1", published_at=WINDOW_END),
            _vv("p2", published_at=_dt(2026, 6, 28)),
            _vv("p3", published_at=_dt(2026, 6, 27)),
        ]
        report = _build([_artist("p", final_score=90, channel_count=1, videos=videos)])
        item = report.item_for("p")
        self.assertEqual(item.competition_level, "Low")
        competition = item.selection_reason_json["competition"]
        self.assertEqual(competition["recent_7d"], 3)
        self.assertEqual(competition["prior_7d"], 0)
        self.assertIsNone(competition["growth_7d"])
        self.assertFalse(competition["growth_triggered"])
        self.assertEqual(competition["prior_zero_rule"], "no-trigger")

    def test_growth_never_lowers_level(self) -> None:
        # Medium base with negative growth stays Medium; High base stays High.
        medium_videos = [
            _vv("m1", published_at=WINDOW_END),
            _vv("m2", published_at=_dt(2026, 6, 20)),
            _vv("m3", published_at=_dt(2026, 6, 19)),
            _vv("m4", published_at=_dt(2026, 6, 18)),
        ]
        report = _build(
            [
                _artist("med", final_score=90, channel_count=10, videos=medium_videos),
                _artist("high", final_score=90, channel_count=20),
            ]
        )
        self.assertEqual(report.item_for("med").competition_level, "Medium")
        self.assertEqual(report.item_for("high").competition_level, "High")

    def test_publication_windows_half_open_anchored_to_window_end(self) -> None:
        videos = [
            _vv("a", published_at=WINDOW_END),          # recent
            _vv("b", published_at=_dt(2026, 6, 24)),    # recent
            _vv("c", published_at=_dt(2026, 6, 23)),    # boundary = recent_start -> prior
            _vv("d", published_at=_dt(2026, 6, 17)),    # prior
            _vv("e", published_at=_dt(2026, 6, 16)),    # boundary = prior_start -> excluded
            _vv("f", published_at=_dt(2026, 6, 10)),    # too old -> excluded
        ]
        self.assertEqual(publication_windows(videos, WINDOW_END), (2, 2))


class ExampleTests(unittest.TestCase):
    def _reason(self, artist: ArtistOpportunityInput) -> dict:
        report = _build([artist])
        return report.item_for(artist.artist_id).selection_reason_json

    def test_top3_orders_by_velocity_then_video_id(self) -> None:
        videos = [
            _vv("vid-c", vel=Decimal("30")),
            _vv("vid-a", vel=Decimal("20")),
            _vv("vid-b", vel=Decimal("20")),
            _vv("vid-lowest", vel=Decimal("5")),
        ]
        reason = self._reason(_artist("t", final_score=90, videos=videos))
        self.assertEqual([row["video_id"] for row in reason["top3"]], ["vid-c", "vid-a", "vid-b"])
        self.assertNotIn(
            "vid-lowest", [row["video_id"] for row in reason["top3"]]
        )
        # All four remain candidates for the audit.
        self.assertEqual(len(reason["candidates"]), 4)

    def test_selects_most_recent_published_in_top3(self) -> None:
        videos = [
            _vv("vA", vel=Decimal("50"), published_at=_dt(2026, 6, 10)),
            _vv("vB", vel=Decimal("40"), published_at=_dt(2026, 6, 28)),  # most recent
            _vv("vC", vel=Decimal("30"), published_at=_dt(2026, 6, 20)),
        ]
        reason = self._reason(_artist("s", final_score=90, videos=videos))
        self.assertEqual(reason["selected_example"]["video_id"], "vB")
        self.assertEqual(reason["tiebreak"]["applied"], "primary")

    def test_tiebreak_max_views_secondary(self) -> None:
        videos = [
            _vv("vX", vel=Decimal("50"), views=100, published_at=WINDOW_END),
            _vv("vY", vel=Decimal("40"), views=500, published_at=WINDOW_END),  # max views
            _vv("vZ", vel=Decimal("30"), views=300, published_at=WINDOW_END),
        ]
        reason = self._reason(_artist("v", final_score=90, videos=videos))
        self.assertEqual(reason["selected_example"]["video_id"], "vY")
        self.assertEqual(reason["tiebreak"]["applied"], "secondary")

    def test_tiebreak_min_video_id_final(self) -> None:
        videos = [
            _vv("vA", vel=Decimal("40"), views=200, published_at=WINDOW_END),
            _vv("vB", vel=Decimal("30"), views=200, published_at=WINDOW_END),
        ]
        reason = self._reason(_artist("w", final_score=90, videos=videos))
        self.assertEqual(reason["selected_example"]["video_id"], "vA")
        self.assertEqual(reason["tiebreak"]["applied"], "final")

    def test_candidate_without_views_orders_last(self) -> None:
        videos = [
            _vv("v-fast", vel=Decimal("30")),
            _vv("v-mid", vel=Decimal("10")),
            ValidVideo("v-noviews", views=None, vel=None, published_at=WINDOW_END),
            _vv("v-slow", vel=Decimal("5")),
        ]
        reason = self._reason(_artist("nv", final_score=90, videos=videos))
        top3_ids = [row["video_id"] for row in reason["top3"]]
        self.assertEqual(top3_ids, ["v-fast", "v-mid", "v-slow"])
        self.assertNotIn("v-noviews", top3_ids)
        # With too few vel'd videos, the view-less one is forced into the shortlist.
        few = [
            _vv("only-fast", vel=Decimal("9")),
            ValidVideo("no-vel", views=None, vel=None, published_at=WINDOW_END),
        ]
        reason_few = self._reason(_artist("nv2", final_score=90, videos=few))
        self.assertEqual(
            [row["video_id"] for row in reason_few["top3"]], ["only-fast", "no-vel"]
        )

    def test_selection_reason_json_satisfies_f5_05a(self) -> None:
        videos = [
            _vv("e1", vel=Decimal("30"), published_at=_dt(2026, 6, 28)),
            _vv("e2", vel=Decimal("20"), published_at=_dt(2026, 6, 20)),
        ]
        report = _build([_artist("e", final_score=90, videos=videos)])
        reason = report.item_for("e").selection_reason_json
        self.assertTrue(_reason_structurally_complete(reason))
        # Persist-ready: the whole evidence is JSON-serializable.
        json.dumps(reason)
        self.assertGreaterEqual(len(reason["candidates"]), 1)
        self.assertGreaterEqual(len(reason["top3"]), 1)
        self.assertIn("tiebreak", reason)
        self.assertTrue(reason["selected_example"]["video_id"])

    def test_example_video_id_and_url_match_selected(self) -> None:
        videos = [_vv("chosen", vel=Decimal("30"), published_at=_dt(2026, 6, 29))]
        report = _build([_artist("x", final_score=90, videos=videos)])
        item = report.item_for("x")
        selected = item.selection_reason_json["selected_example"]["video_id"]
        self.assertEqual(item.example_video_id, selected)
        self.assertEqual(item.example_url, f"https://www.youtube.com/watch?v={selected}")


class FormattingTests(unittest.TestCase):
    def test_velocity_display_thousands_and_below_and_null(self) -> None:
        self.assertEqual(format_velocity_display(Decimal("1500")), "1.5k/day")
        self.assertEqual(format_velocity_display(Decimal("1000")), "1.0k/day")
        self.assertEqual(format_velocity_display(Decimal("500")), "500/day")
        self.assertEqual(format_velocity_display(Decimal("0")), "0/day")
        # Undefined median stays empty — never a fabricated 0/day.
        self.assertIsNone(format_velocity_display(None))

    def test_item_title_velocity_and_null_velocity(self) -> None:
        with_vel = _artist(
            "kv", final_score=90, canonical_name="Kairo Vee", velocity_median=Decimal("2500")
        )
        report = _build([with_vel])
        item = report.item_for("kv")
        self.assertEqual(item.title, "Kairo Vee Type Beat")
        self.assertEqual(item.velocity_display, "2.5k/day")

        null_vel = _artist("nv", final_score=90, velocity_median=None)
        report2 = _build([null_vel])
        self.assertIsNone(report2.item_for("nv").velocity_display)


class DeterminismAndContractTests(unittest.TestCase):
    def _mixed_run(self) -> list[ArtistOpportunityInput]:
        return [
            _artist(
                "a",
                final_score=95,
                channel_count=8,
                videos=[
                    _vv("a1", vel=Decimal("40"), published_at=_dt(2026, 6, 28)),
                    _vv("a2", vel=Decimal("20"), published_at=_dt(2026, 6, 20)),
                ],
            ),
            _artist("b", final_score=92, channel_count=3),
            _artist("c", final_score=84, channel_count=20),
        ]

    def test_determinism_byte_identical_reports(self) -> None:
        first = _build(self._mixed_run())
        second = _build(self._mixed_run())
        self.assertEqual(first, second)
        self.assertEqual(first.items, second.items)
        self.assertEqual(first.opportunity_hash, second.opportunity_hash)

    def test_versions_carried_in_selection_reason_json(self) -> None:
        report = _build([_artist("a", final_score=90)])
        versions = report.item_for("a").selection_reason_json["versions"]
        self.assertEqual(versions["opportunity_version"], OPPORTUNITY_VERSION)
        self.assertEqual(versions["opportunity_hash"], DEFAULT_CONFIG.opportunity_hash)
        self.assertEqual(versions["rubric_version"], RUBRIC_VERSION)
        self.assertEqual(versions["rubric_hash"], RUBRIC_HASH)

    def test_opportunity_hash_carried_on_report(self) -> None:
        report = _build([_artist("a", final_score=90)])
        self.assertEqual(report.opportunity_hash, DEFAULT_CONFIG.opportunity_hash)
        self.assertEqual(report.opportunity_version, OPPORTUNITY_VERSION)

    def test_contract_violations_are_rejected(self) -> None:
        good = _artist("a", final_score=90)
        with self.assertRaises(ContractViolation):
            _build([good], run_id="   ")
        with self.assertRaises(ContractViolation):
            _build([good], title="  ")
        with self.assertRaises(ContractViolation):
            _build([good], window_end=datetime(2026, 6, 30))  # naive
        with self.assertRaises(ContractViolation):
            _build([])  # empty run
        with self.assertRaises(ContractViolation):
            _build([_artist("a", final_score=90), _artist("a", final_score=88)])  # dup id
        # ValidVideos must match the score's contributing_video_ids exactly.
        mismatched = ArtistOpportunityInput(
            score=_score("m", final_score=90, video_ids=("v1", "v2")),
            valid_videos=[_vv("v1")],
            canonical_name="M",
        )
        with self.assertRaises(ContractViolation):
            _build([mismatched])
        # A scored artist must carry >= 1 ValidVideo (Example candidate).
        empty_videos = ArtistOpportunityInput(
            score=_score("z", final_score=90, video_ids=()),
            valid_videos=[],
            canonical_name="Z",
        )
        with self.assertRaises(ContractViolation):
            _build([empty_videos])
        # Artists of one report must share a single (rubric_version, rubric_hash).
        drift = _artist("d", final_score=90, rubric_hash="b" * 64)
        with self.assertRaises(ContractViolation):
            _build([good, drift])


if __name__ == "__main__":
    unittest.main()
