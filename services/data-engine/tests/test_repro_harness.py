"""P5-REPRO-01 reproducibility harness (DATA-REPRO-001).

This is the fail-closed reproducibility gate for the deterministic pipeline
(``noxund_data_engine.pipeline``), proven over SYNTHETIC snapshots only — no real
YouTube data, no network, no DB, no secret. It composes the four ratified zones
(Entity Resolution -> Channel Filter -> Scoring -> Opportunity) end to end and
asserts the five P5-REPRO-01 properties:

1. Idempotence / determinism — pipeline() twice on the same snapshot ⇒ byte-identical
   serialized rows (deep equality + a stable sha256 digest).
2. Input-order independence — shuffling the input rows ⇒ identical output (probes
   hidden ordering nondeterminism).
3. Provenance stamping — every row carries the ratified v1 identities
   (rubric/rule/resolver/opportunity version + hash).
4. Golden-hash regression — a stable digest of a fixed fixture (guards silent drift;
   changing the rubric MUST change the digest, forcing a new rubric_version).
5. Edge cases — empty run; all scores < 83 ⇒ insufficient_opportunity; < 2 crossing
   90 ⇒ < 2 HOT; > 2 crossing 90 ⇒ HOT capped at 2; single-channel domination at
   exactly the MAX_RUN_VIDEOS_PER_CHANNEL boundary.

Style mirrors the sibling suites: stdlib ``unittest`` (no pytest / no third-party),
run with ``PYTHONPATH=src python -m unittest discover -s tests -p test_repro_harness.py``.
"""

from __future__ import annotations

import unittest
from datetime import datetime, timezone
from decimal import Decimal
from typing import Sequence

from noxund_data_engine.channel_filter import (
    DEFAULT_CONFIG as CHANNEL_FILTER_DEFAULT_CONFIG,
    RULE_VERSION,
    ReasonCode,
)
from noxund_data_engine.entity_resolution import RESOLVER_VERSION
from noxund_data_engine.opportunity import (
    DEFAULT_CONFIG as OPPORTUNITY_DEFAULT_CONFIG,
    OPPORTUNITY_VERSION,
)
from noxund_data_engine.pipeline import (
    PIPELINE_VERSION,
    ArtistRow,
    ChannelRow,
    PipelineContractViolation,
    PipelineResult,
    PipelineSnapshot,
    RawVideoRow,
    canonical_json,
    pipeline_digest,
    run_pipeline,
)
from noxund_data_engine.scoring import DEFAULT_RUBRIC, RUBRIC_VERSION, RubricConfig


# ---------------------------------------------------------------------------
# The locked golden baseline. Computed by the harness itself over GOLDEN_SNAPSHOT
# under the ratified v1 configs. It is a pure function of the synthetic input +
# the frozen rubric/rule/opportunity hashes and is portable across platforms
# (Decimal arithmetic, sha256 and canonical JSON are all deterministic). Any drift
# in a produced number, order, label or version identity changes this digest.
# ---------------------------------------------------------------------------
GOLDEN_DIGEST = "c8e33fe85034e2c406bb189249ff829d8928a5b085d192c73220afcb89674ca8"

WINDOW_END = datetime(2026, 6, 30, tzinfo=timezone.utc)


def _dt(month: int, day: int) -> datetime:
    return datetime(2026, month, day, tzinfo=timezone.utc)


def _artist_videos(
    prefix: str,
    name: str,
    *,
    base_views: int,
    n_videos: int,
    n_channels: int,
    day: int,
    likes: int,
    comments: int,
) -> list[RawVideoRow]:
    """N synthetic ``<name> Type Beat`` videos fanned across N channels (round-robin).

    Views grow by a fixed step per index so the Example ordering is a total order;
    every video shares one publish day so its age (vs the frozen window_end) is fixed.
    """

    return [
        RawVideoRow(
            video_id=f"{prefix}{i:02d}",
            channel_id=f"{prefix}-ch-{i % n_channels:02d}",
            source_title=f"{name} Type Beat",
            views=base_views + i * 10,
            likes=likes,
            comments=comments,
            published_at=_dt(6, day),
        )
        for i in range(n_videos)
    ]


# ---------------------------------------------------------------------------
# Synthetic fixtures (each builder returns a fresh snapshot — the determinism
# tests deliberately construct two independent, structurally-identical inputs).
# ---------------------------------------------------------------------------
def _channel_rows_for(videos: Sequence[RawVideoRow]) -> tuple[ChannelRow, ...]:
    """One title-less raw ``ChannelRow`` per channel the videos reference.

    channel-filter-v1 is fail-closed (DC2-01 · DEC-0022, amends DEC-0019 §2): every
    channel in the run footprint MUST carry a raw record — a complete collected run.
    Titles are ``None`` (no self_channel signal), so a complete snapshot stays
    byte-identical to the pre-fail-closed output and the GOLDEN_DIGEST is unchanged.
    """

    return tuple(
        ChannelRow(channel_id)
        for channel_id in sorted({video.channel_id for video in videos})
    )


def golden_videos() -> list[RawVideoRow]:
    videos: list[RawVideoRow] = []
    # Two structurally-identical leaders both sit at the run's p90 velocity/engagement
    # anchor -> both saturate to ~99 -> both HOT.
    videos += _artist_videos(
        "k", "Kairo Vee", base_views=40000, n_videos=18, n_channels=15, day=29,
        likes=5000, comments=900,
    )
    videos += _artist_videos(
        "n", "Nova Blade", base_views=40000, n_videos=18, n_channels=15, day=29,
        likes=5000, comments=900,
    )
    # A third strong artist that also crosses 90 (=> 3 cross 90) but, capped at 2,
    # gets NO HOT badge: proves the honest cap.
    videos += _artist_videos(
        "r", "Rune Sol", base_views=36000, n_videos=16, n_channels=12, day=29,
        likes=4200, comments=760,
    )
    # A weak artist far below the display gate -> dropped, never a padded slot.
    videos += [RawVideoRow("g0", "g-ch-0", "Ghost Lane Type Beat", 300, 10, 2, _dt(6, 12))]
    return videos


GOLDEN_ARTISTS = (
    ArtistRow("artist-kairo", "Kairo Vee"),
    ArtistRow("artist-nova", "Nova Blade"),
    ArtistRow("artist-rune", "Rune Sol"),
    ArtistRow("artist-ghost", "Ghost Lane"),
)


def golden_snapshot(videos: list[RawVideoRow] | None = None,
                    artists: tuple[ArtistRow, ...] | None = None) -> PipelineSnapshot:
    effective_videos = tuple(golden_videos() if videos is None else videos)
    return PipelineSnapshot(
        run_id="run-golden",
        report_title="Golden Run",
        window_end=WINDOW_END,
        videos=effective_videos,
        channels=_channel_rows_for(effective_videos),
        artists=GOLDEN_ARTISTS if artists is None else artists,
    )


def empty_snapshot() -> PipelineSnapshot:
    return PipelineSnapshot(
        run_id="run-empty", report_title="Empty Run", window_end=WINDOW_END,
        videos=(), channels=(), artists=(),
    )


def insufficient_snapshot() -> PipelineSnapshot:
    # Two small artists; run-relative normalization caps each at its own p90, but with
    # a single video / single channel the Score lands well under the 83 display gate.
    videos = (
        RawVideoRow("a0", "a-ch", "Alpha One Type Beat", 1000, 50, 10, _dt(6, 20)),
        RawVideoRow("b0", "b-ch", "Beta Two Type Beat", 800, 40, 8, _dt(6, 18)),
    )
    artists = (ArtistRow("artist-alpha", "Alpha One"), ArtistRow("artist-beta", "Beta Two"))
    return PipelineSnapshot(
        "run-insuf", "Insufficient Run", WINDOW_END, videos,
        _channel_rows_for(videos), artists,
    )


def one_hot_snapshot() -> PipelineSnapshot:
    videos = _artist_videos(
        "k", "Kairo Vee", base_views=40000, n_videos=20, n_channels=16, day=29,
        likes=5000, comments=900,
    )
    videos += [RawVideoRow("w0", "w-ch", "Weak Guy Type Beat", 200, 5, 1, _dt(6, 10))]
    artists = (ArtistRow("artist-kairo", "Kairo Vee"), ArtistRow("artist-weak", "Weak Guy"))
    return PipelineSnapshot(
        "run-onehot", "One HOT Run", WINDOW_END, tuple(videos),
        _channel_rows_for(videos), artists,
    )


def domination_boundary_snapshot() -> PipelineSnapshot:
    # chan-60: EXACTLY 60 videos in the run -> eligible (60 stays eligible).
    # chan-61: 61 videos -> run_domination -> ineligible (strictly > 60).
    videos = [
        RawVideoRow(f"bd{i:02d}", "chan-60", "Boundary Act Type Beat", 5000, 100, 20, _dt(6, 25))
        for i in range(60)
    ]
    videos += [
        RawVideoRow(f"dm{i:02d}", "chan-61", "Dominator Act Type Beat", 5000, 100, 20, _dt(6, 25))
        for i in range(61)
    ]
    channels = (ChannelRow("chan-60", "Beat Vault"), ChannelRow("chan-61", "Loop Depot"))
    artists = (
        ArtistRow("artist-boundary", "Boundary Act"),
        ArtistRow("artist-dominator", "Dominator Act"),
    )
    return PipelineSnapshot(
        "run-bound", "Boundary Run", WINDOW_END, tuple(videos), channels, artists
    )


def unresolvable_snapshot() -> PipelineSnapshot:
    videos = (
        RawVideoRow("ok0", "ok-ch", "Solo Star Type Beat", 1000, 50, 10, _dt(6, 20)),
        # Multi-artist ("x") -> regex rejects -> review (llm off) -> unresolved.
        RawVideoRow(
            "bad-multi", "x-ch", "Kairo Vee x Nova Blade Type Beat", 1000, 50, 10, _dt(6, 20)
        ),
        # No "type beat" marker -> no candidate -> review -> unresolved.
        RawVideoRow("bad-nomark", "y-ch", "Just A Random Upload", 1000, 50, 10, _dt(6, 20)),
        # Blank title -> source_title_missing -> rejected -> unresolved.
        RawVideoRow("bad-blank", "z-ch", "   ", 1000, 50, 10, _dt(6, 20)),
    )
    artists = (ArtistRow("artist-solo", "Solo Star"),)
    return PipelineSnapshot(
        "run-unres", "Unresolvable Run", WINDOW_END, videos,
        _channel_rows_for(videos), artists,
    )


def _final_scores(result: PipelineResult) -> dict[str, int]:
    return {s.artist_id: s.final_score for s in result.score_result.scores}


# ---------------------------------------------------------------------------
# 0. Composition sanity — the whole chain wires up and produces the report shape.
# ---------------------------------------------------------------------------
class PipelineCompositionTests(unittest.TestCase):
    def test_golden_run_shape(self) -> None:
        result = run_pipeline(golden_snapshot())
        self.assertIsNotNone(result.report)
        self.assertFalse(result.insufficient_opportunity)
        self.assertEqual(
            _final_scores(result),
            {"artist-ghost": 15, "artist-kairo": 99, "artist-nova": 99, "artist-rune": 92},
        )
        # 3 qualified rows (ghost dropped below the 83 gate), in ranking order.
        self.assertEqual(
            [(r.rank, r.artist_id, r.tag) for r in result.rows],
            [(1, "artist-kairo", "HOT"), (2, "artist-nova", "HOT"), (3, "artist-rune", None)],
        )
        self.assertIsNone(result.report.item_for("artist-ghost"))

    def test_example_and_url_and_reason_are_self_consistent(self) -> None:
        result = run_pipeline(golden_snapshot())
        for row in result.rows:
            selected = row.selection_reason_json["selected_example"]["video_id"]
            self.assertEqual(row.example_video_id, selected)
            self.assertEqual(row.example_url, f"https://www.youtube.com/watch?v={selected}")

    def test_unresolved_videos_are_excluded_honestly(self) -> None:
        result = run_pipeline(unresolvable_snapshot())
        self.assertEqual(set(result.unresolved_video_ids), {"bad-multi", "bad-nomark", "bad-blank"})
        # Only the cleanly-resolved artist reaches Scoring.
        self.assertEqual(result.scored_artist_ids, ("artist-solo",))


# ---------------------------------------------------------------------------
# 1. Idempotence / determinism.
# ---------------------------------------------------------------------------
class IdempotenceTests(unittest.TestCase):
    def test_two_runs_are_byte_identical(self) -> None:
        first = run_pipeline(golden_snapshot())
        second = run_pipeline(golden_snapshot())
        self.assertEqual(first.rows, second.rows)
        self.assertEqual(canonical_json(first), canonical_json(second))
        self.assertEqual(pipeline_digest(first), pipeline_digest(second))

    def test_digest_is_a_64_char_hex_sha256(self) -> None:
        digest = pipeline_digest(run_pipeline(golden_snapshot()))
        self.assertEqual(len(digest), 64)
        self.assertTrue(all(ch in "0123456789abcdef" for ch in digest))


# ---------------------------------------------------------------------------
# 2. Input-order independence.
# ---------------------------------------------------------------------------
class InputOrderIndependenceTests(unittest.TestCase):
    def test_reversed_inputs_yield_identical_output(self) -> None:
        baseline = pipeline_digest(run_pipeline(golden_snapshot()))
        reversed_videos = list(reversed(golden_videos()))
        reversed_artists = tuple(reversed(GOLDEN_ARTISTS))
        shuffled = golden_snapshot(videos=reversed_videos, artists=reversed_artists)
        self.assertEqual(pipeline_digest(run_pipeline(shuffled)), baseline)

    def test_rotated_video_order_yields_identical_output(self) -> None:
        baseline = pipeline_digest(run_pipeline(golden_snapshot()))
        videos = golden_videos()
        rotated = videos[7:] + videos[:7]
        self.assertEqual(pipeline_digest(run_pipeline(golden_snapshot(videos=rotated))), baseline)


# ---------------------------------------------------------------------------
# 3. Provenance stamping.
# ---------------------------------------------------------------------------
class ProvenanceStampingTests(unittest.TestCase):
    def test_every_row_carries_ratified_v1_identities(self) -> None:
        result = run_pipeline(golden_snapshot())
        self.assertTrue(result.rows)  # guard against a vacuous pass
        for row in result.rows:
            self.assertEqual(row.run_id, "run-golden")
            self.assertTrue(row.artist_id)
            self.assertEqual(row.rubric_version, RUBRIC_VERSION)
            self.assertEqual(row.rubric_version, "score_rubric_2026_06_v1")
            self.assertEqual(row.rubric_hash, DEFAULT_RUBRIC.rubric_hash)
            self.assertEqual(row.rule_version, RULE_VERSION)
            self.assertEqual(row.rule_version, "channel-filter-v1")
            self.assertEqual(row.rule_hash, CHANNEL_FILTER_DEFAULT_CONFIG.rule_hash)
            self.assertEqual(row.resolver_version, RESOLVER_VERSION)
            self.assertEqual(row.opportunity_version, OPPORTUNITY_VERSION)
            self.assertEqual(row.opportunity_hash, OPPORTUNITY_DEFAULT_CONFIG.opportunity_hash)

    def test_run_provenance_matches_the_frozen_configs(self) -> None:
        provenance = run_pipeline(golden_snapshot()).provenance
        self.assertEqual(provenance.pipeline_version, PIPELINE_VERSION)
        self.assertEqual(provenance.resolver_version, RESOLVER_VERSION)
        self.assertEqual(provenance.rule_version, RULE_VERSION)
        self.assertEqual(provenance.rule_hash, CHANNEL_FILTER_DEFAULT_CONFIG.rule_hash)
        self.assertEqual(provenance.rubric_version, RUBRIC_VERSION)
        self.assertEqual(provenance.rubric_hash, DEFAULT_RUBRIC.rubric_hash)
        self.assertEqual(provenance.opportunity_hash, OPPORTUNITY_DEFAULT_CONFIG.opportunity_hash)

    def test_selection_reason_json_embeds_effective_versions(self) -> None:
        result = run_pipeline(golden_snapshot())
        versions = result.rows[0].selection_reason_json["versions"]
        self.assertEqual(versions["rubric_version"], RUBRIC_VERSION)
        self.assertEqual(versions["rubric_hash"], DEFAULT_RUBRIC.rubric_hash)
        self.assertEqual(versions["opportunity_version"], OPPORTUNITY_VERSION)


# ---------------------------------------------------------------------------
# 4. Golden-hash regression.
# ---------------------------------------------------------------------------
class GoldenHashRegressionTests(unittest.TestCase):
    def test_digest_is_deterministic_and_drift_sensitive(self) -> None:
        """Always-on guard: no baked baseline required.

        Determinism + "changing the rubric changes the hash" are proven directly,
        so the "silent drift ⇒ new rubric_version" guarantee holds even before the
        literal baseline below is locked.
        """

        baseline = pipeline_digest(run_pipeline(golden_snapshot()))
        self.assertEqual(pipeline_digest(run_pipeline(golden_snapshot())), baseline)

        # A rubric change MUST move the digest (else a silent edit could pass).
        mutated_rubric = RubricConfig(half_life_days=Decimal("30"))
        mutated = pipeline_digest(run_pipeline(golden_snapshot(), rubric=mutated_rubric))
        self.assertNotEqual(mutated, baseline)

        # The frozen identities travel with the output.
        provenance = run_pipeline(golden_snapshot()).provenance
        self.assertEqual(provenance.rubric_version, "score_rubric_2026_06_v1")
        self.assertEqual(provenance.rule_version, "channel-filter-v1")
        self.assertEqual(provenance.opportunity_version, "opportunity-rules-2026_06_v1")

    def test_digest_matches_locked_baseline(self) -> None:
        """Regression against the committed golden digest (silent numeric drift guard)."""

        self.assertEqual(pipeline_digest(run_pipeline(golden_snapshot())), GOLDEN_DIGEST)


# ---------------------------------------------------------------------------
# 5. Edge cases.
# ---------------------------------------------------------------------------
class EdgeCaseTests(unittest.TestCase):
    def test_empty_run_is_insufficient_without_raising(self) -> None:
        result = run_pipeline(empty_snapshot())
        self.assertIsNone(result.report)
        self.assertEqual(result.rows, ())
        self.assertEqual(result.scored_artist_ids, ())
        self.assertTrue(result.insufficient_opportunity)
        # Even an empty run is deterministic and carries the frozen version identities.
        self.assertEqual(pipeline_digest(run_pipeline(empty_snapshot())), pipeline_digest(result))
        self.assertEqual(result.provenance.rubric_version, RUBRIC_VERSION)

    def test_all_below_gate_marks_insufficient_opportunity(self) -> None:
        result = run_pipeline(insufficient_snapshot())
        scores = _final_scores(result)
        self.assertTrue(scores)  # artists WERE scored ...
        self.assertTrue(all(score < 83 for score in scores.values()))  # ... all below the gate
        self.assertTrue(result.insufficient_opportunity)
        self.assertEqual(result.rows, ())
        self.assertEqual(result.report.status, "draft")

    def test_fewer_than_two_cross_90_yields_fewer_than_two_hot(self) -> None:
        result = run_pipeline(one_hot_snapshot())
        crossed = [aid for aid, sc in _final_scores(result).items() if sc > 90]
        self.assertEqual(len(crossed), 1)
        self.assertEqual(result.report.hot_artist_ids, ("artist-kairo",))

    def test_zero_cross_90_yields_zero_hot(self) -> None:
        # The insufficient run has no artist above 90 and no qualified row -> zero HOT.
        result = run_pipeline(insufficient_snapshot())
        self.assertEqual(result.report.hot_artist_ids, ())

    def test_more_than_two_cross_90_caps_hot_at_two(self) -> None:
        # Golden: kairo/nova/rune all cross 90, but only the top two are badged HOT.
        result = run_pipeline(golden_snapshot())
        crossed = [aid for aid, sc in _final_scores(result).items() if sc > 90]
        self.assertEqual(sorted(crossed), ["artist-kairo", "artist-nova", "artist-rune"])
        self.assertEqual(result.report.hot_artist_ids, ("artist-kairo", "artist-nova"))
        # rune crossed 90 but honestly shows no badge.
        self.assertIsNone(result.report.item_for("artist-rune").tag)

    def test_single_channel_domination_at_max_boundary(self) -> None:
        result = run_pipeline(domination_boundary_snapshot())
        eligible = result.filter_result.verdict_for("chan-60")
        dominated = result.filter_result.verdict_for("chan-61")
        # Exactly 60 stays eligible; 61 (strictly > 60) is run_domination.
        self.assertTrue(eligible.is_eligible)
        self.assertEqual(eligible.reason_code, ReasonCode.ELIGIBLE)
        self.assertEqual(eligible.run_video_count, 60)
        self.assertFalse(dominated.is_eligible)
        self.assertEqual(dominated.reason_code, ReasonCode.RUN_DOMINATION)
        self.assertEqual(dominated.run_video_count, 61)
        # The boundary artist is scorable; the dominated channel's artist drops entirely.
        self.assertIsNotNone(result.score_result.score_for("artist-boundary"))
        self.assertIsNone(result.score_result.score_for("artist-dominator"))
        self.assertEqual(result.filter_result.rule_version, "channel-filter-v1")
        self.assertEqual(CHANNEL_FILTER_DEFAULT_CONFIG.max_run_videos_per_channel, 60)

    def test_snapshot_contract_violations_are_rejected(self) -> None:
        good = RawVideoRow("v0", "ch", "Solo Star Type Beat", 100, 5, 1, WINDOW_END)
        artists = (ArtistRow("artist-solo", "Solo Star"),)
        with self.assertRaises(PipelineContractViolation):
            run_pipeline(PipelineSnapshot("  ", "T", WINDOW_END, (good,), (), artists))
        with self.assertRaises(PipelineContractViolation):
            run_pipeline(PipelineSnapshot("r", "  ", WINDOW_END, (good,), (), artists))
        with self.assertRaises(PipelineContractViolation):
            # Naive datetime is not a valid frozen window_end.
            run_pipeline(PipelineSnapshot("r", "T", datetime(2026, 6, 30), (good,), (), artists))
        with self.assertRaises(PipelineContractViolation):
            # Duplicate video_id in the raw snapshot.
            run_pipeline(PipelineSnapshot("r", "T", WINDOW_END, (good, good), (), artists))


# ---------------------------------------------------------------------------
# 6. HOT invariants — structural, hold for EVERY fixture regardless of scores.
# ---------------------------------------------------------------------------
class HotInvariantTests(unittest.TestCase):
    def _reports(self) -> list[PipelineResult]:
        return [
            run_pipeline(golden_snapshot()),
            run_pipeline(one_hot_snapshot()),
            run_pipeline(insufficient_snapshot()),
            run_pipeline(domination_boundary_snapshot()),
        ]

    def test_hot_is_capped_and_never_fabricated(self) -> None:
        for result in self._reports():
            if result.report is None:
                continue
            hot_ids = result.report.hot_artist_ids
            self.assertLessEqual(len(hot_ids), 2)
            crossed = sum(1 for s in result.score_result.scores if s.final_score > 90)
            # Never more HOT than artists honestly above 90.
            self.assertLessEqual(len(hot_ids), crossed)
            for item in result.report.items:
                if item.tag == "HOT":
                    self.assertGreater(item.score_value, 90)

    def test_no_displayed_row_below_the_gate(self) -> None:
        for result in self._reports():
            for row in result.rows:
                self.assertGreaterEqual(row.score_value, 83)


if __name__ == "__main__":
    unittest.main()
