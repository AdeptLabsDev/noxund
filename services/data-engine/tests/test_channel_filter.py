from __future__ import annotations

import unittest
from typing import Sequence

from noxund_data_engine.channel_filter import (
    DEFAULT_CONFIG,
    MAX_RUN_VIDEOS_PER_CHANNEL,
    RULE_VERSION,
    ChannelFilter,
    ChannelRecord,
    ContractViolation,
    FilterConfig,
    ReasonCode,
    RunVideo,
    is_self_channel,
)
from noxund_data_engine.entity_resolution import normalize_for_match


RUN_ID = "00000000-0000-0000-0000-000000000001"


class FakeArtistCatalog:
    """In-memory ArtistNameCatalog: artist_id -> raw canonical_name + aliases."""

    def __init__(self, names: dict[str, Sequence[str]] | None = None) -> None:
        self.names = names or {}

    def names_for_artist(self, artist_id: str) -> Sequence[str]:
        return self.names.get(artist_id, ())


def make_filter(
    *,
    catalog: FakeArtistCatalog | None = None,
    config: FilterConfig = DEFAULT_CONFIG,
) -> ChannelFilter:
    return ChannelFilter(catalog=catalog or FakeArtistCatalog(), config=config)


def videos_for_channel(
    channel_id: str, count: int, *, artist_id: str = "artist-1", prefix: str = "v"
) -> list[RunVideo]:
    return [
        RunVideo(RUN_ID, f"{prefix}-{channel_id}-{index}", channel_id, artist_id)
        for index in range(count)
    ]


def channel_records(
    videos: Sequence[RunVideo], *, titles: dict[str, str | None] | None = None
) -> list[ChannelRecord]:
    """One raw ``ChannelRecord`` per channel the videos reference (a complete run).

    channel-filter-v1 is fail-closed (DC2-01 · DEC-0022): every channel in the run
    footprint needs a raw record. Titles default to ``None`` (no self_channel signal);
    pass ``titles`` to give a specific channel a title.
    """

    lookup = titles or {}
    return [
        ChannelRecord(RUN_ID, channel_id, title=lookup.get(channel_id))
        for channel_id in sorted({video.channel_id for video in videos})
    ]


class ChannelFilterTests(unittest.TestCase):
    def test_self_channel_excluded_from_its_own_competition(self) -> None:
        catalog = FakeArtistCatalog({"artist-1": ("Kairo Vée",)})
        run_filter = make_filter(catalog=catalog)
        videos = [
            RunVideo(RUN_ID, "v1", "chan-self", "artist-1"),
            RunVideo(RUN_ID, "v2", "chan-rival", "artist-1"),
        ]
        channels = [
            ChannelRecord(RUN_ID, "chan-self", title="KAIRO—Vée"),
            ChannelRecord(RUN_ID, "chan-rival", title="BeatFactory"),
        ]

        result = run_filter.evaluate_run(run_id=RUN_ID, videos=videos, channels=channels)

        self_verdict = result.verdict_for("chan-self")
        assert self_verdict is not None
        self.assertFalse(self_verdict.is_eligible)
        self.assertEqual(self_verdict.reason_code, ReasonCode.SELF_CHANNEL)

        projection = result.projection_for("artist-1")
        assert projection is not None
        # Own channel drops from Signals and Competition; only the rival remains.
        self.assertEqual(projection.valid_video_ids, ("v2",))
        self.assertEqual(projection.eligible_channel_ids, ("chan-rival",))

    def test_self_channel_matches_via_alias_not_only_canonical(self) -> None:
        catalog = FakeArtistCatalog({"artist-1": ("Kairo Vée", "KV Beats")})
        run_filter = make_filter(catalog=catalog)
        videos = [RunVideo(RUN_ID, "v1", "chan-self", "artist-1")]
        channels = [ChannelRecord(RUN_ID, "chan-self", title="  kv   beats ")]

        result = run_filter.evaluate_run(run_id=RUN_ID, videos=videos, channels=channels)

        verdict = result.verdict_for("chan-self")
        assert verdict is not None
        self.assertEqual(verdict.reason_code, ReasonCode.SELF_CHANNEL)

    def test_self_channel_requires_exact_normalized_match_no_fuzzy(self) -> None:
        catalog = FakeArtistCatalog({"artist-1": ("Kairo Vée",)})
        run_filter = make_filter(catalog=catalog)
        videos = [RunVideo(RUN_ID, "v1", "chan-near", "artist-1")]
        # Similar but not identical after normalization -> stays eligible (no fuzzy).
        channels = [ChannelRecord(RUN_ID, "chan-near", title="Kairo Vée Official")]

        result = run_filter.evaluate_run(run_id=RUN_ID, videos=videos, channels=channels)

        verdict = result.verdict_for("chan-near")
        assert verdict is not None
        self.assertTrue(verdict.is_eligible)
        self.assertEqual(verdict.reason_code, ReasonCode.ELIGIBLE)

    def test_run_domination_boundary_60_eligible_61_ineligible(self) -> None:
        run_filter = make_filter()
        videos = (
            videos_for_channel("chan-60", 60)
            + videos_for_channel("chan-61", 61, artist_id="artist-2")
        )
        result = run_filter.evaluate_run(
            run_id=RUN_ID, videos=videos, channels=channel_records(videos)
        )

        at_cap = result.verdict_for("chan-60")
        over_cap = result.verdict_for("chan-61")
        assert at_cap is not None and over_cap is not None
        self.assertEqual(at_cap.run_video_count, 60)
        self.assertTrue(at_cap.is_eligible)
        self.assertEqual(at_cap.reason_code, ReasonCode.ELIGIBLE)
        self.assertEqual(over_cap.run_video_count, 61)
        self.assertFalse(over_cap.is_eligible)
        self.assertEqual(over_cap.reason_code, ReasonCode.RUN_DOMINATION)

    def test_disabled_gates_do_not_fire_tiny_zero_channel_stays_eligible(self) -> None:
        run_filter = make_filter()
        # Zero subs, zero views, one upload, and duplicate video titles: every
        # disabled gate's trigger is present, yet the channel stays eligible.
        videos = [
            RunVideo(RUN_ID, "v1", "chan-tiny", "artist-1", title="chicago drill type beat"),
            RunVideo(RUN_ID, "v2", "chan-tiny", "artist-1", title="chicago drill type beat"),
            RunVideo(RUN_ID, "v3", "chan-tiny", "artist-1", title="chicago drill type beat"),
        ]
        channels = [
            ChannelRecord(
                RUN_ID, "chan-tiny", title="BeatFactory",
                subscriber_count=0, view_count=0, upload_count=1,
            )
        ]
        result = run_filter.evaluate_run(run_id=RUN_ID, videos=videos, channels=channels)

        verdict = result.verdict_for("chan-tiny")
        assert verdict is not None
        self.assertTrue(verdict.is_eligible)
        self.assertEqual(verdict.reason_code, ReasonCode.ELIGIBLE)
        projection = result.projection_for("artist-1")
        assert projection is not None
        self.assertEqual(projection.signals, 3)
        self.assertEqual(projection.competition, 1)

    def test_null_channel_stats_are_not_treated_as_zero(self) -> None:
        run_filter = make_filter()
        # All stats NULL. Size gates are disabled AND NULL != 0, so eligibility is
        # driven purely by the real (count-based) footprint: 61 distinct videos ->
        # run_domination, proving the count is genuine, not fabricated from NULLs.
        videos = videos_for_channel("chan-null", 61)
        channels = [ChannelRecord(RUN_ID, "chan-null", title=None)]

        result = run_filter.evaluate_run(run_id=RUN_ID, videos=videos, channels=channels)

        verdict = result.verdict_for("chan-null")
        assert verdict is not None
        self.assertIsNone(channels[0].subscriber_count)
        self.assertFalse(verdict.is_eligible)
        self.assertEqual(verdict.reason_code, ReasonCode.RUN_DOMINATION)

    def test_signals_inflate_but_competition_adds_one_for_prolific_channel(self) -> None:
        run_filter = make_filter()
        # One eligible prolific channel (10 videos) + one single-video channel.
        videos = videos_for_channel("chan-prolific", 10) + [
            RunVideo(RUN_ID, "solo", "chan-solo", "artist-1"),
        ]
        result = run_filter.evaluate_run(
            run_id=RUN_ID, videos=videos, channels=channel_records(videos)
        )

        projection = result.projection_for("artist-1")
        assert projection is not None
        # Signals counts videos (10 + 1); Competition counts distinct channels (2).
        self.assertEqual(projection.signals, 11)
        self.assertEqual(projection.competition, 2)
        self.assertEqual(
            projection.eligible_channel_ids, ("chan-prolific", "chan-solo")
        )

    def test_ineligible_channel_drops_from_both_signals_and_competition(self) -> None:
        run_filter = make_filter()
        # chan-dom is over the cap (61 videos) and must vanish from BOTH sets, while
        # the same artist's eligible chan-ok remains.
        videos = (
            videos_for_channel("chan-dom", 61)
            + [RunVideo(RUN_ID, "ok-1", "chan-ok", "artist-1")]
        )
        result = run_filter.evaluate_run(
            run_id=RUN_ID, videos=videos, channels=channel_records(videos)
        )

        dom = result.verdict_for("chan-dom")
        assert dom is not None
        self.assertFalse(dom.is_eligible)

        projection = result.projection_for("artist-1")
        assert projection is not None
        self.assertEqual(projection.valid_video_ids, ("ok-1",))
        self.assertEqual(projection.eligible_channel_ids, ("chan-ok",))
        self.assertNotIn("chan-dom", projection.eligible_channel_ids)

    def test_eligible_channel_linked_to_two_artists_counts_for_both(self) -> None:
        run_filter = make_filter()
        # A single eligible channel makes beats for two artists: +1 Competition each,
        # and its videos split by mapping (no cross-count between artists).
        videos = [
            RunVideo(RUN_ID, "a1", "chan-shared", "artist-1"),
            RunVideo(RUN_ID, "a2", "chan-shared", "artist-1"),
            RunVideo(RUN_ID, "b1", "chan-shared", "artist-2"),
        ]
        result = run_filter.evaluate_run(
            run_id=RUN_ID, videos=videos, channels=channel_records(videos)
        )

        first = result.projection_for("artist-1")
        second = result.projection_for("artist-2")
        assert first is not None and second is not None
        self.assertEqual(first.signals, 2)
        self.assertEqual(first.competition, 1)
        self.assertEqual(second.signals, 1)
        self.assertEqual(second.competition, 1)
        self.assertEqual(first.eligible_channel_ids, ("chan-shared",))
        self.assertEqual(second.eligible_channel_ids, ("chan-shared",))

    def test_self_channel_takes_precedence_over_run_domination(self) -> None:
        catalog = FakeArtistCatalog({"artist-1": ("BeatFactory",)})
        run_filter = make_filter(catalog=catalog)
        videos = videos_for_channel("chan-self-dom", 61)  # both self AND over cap
        channels = [ChannelRecord(RUN_ID, "chan-self-dom", title="BeatFactory")]

        result = run_filter.evaluate_run(run_id=RUN_ID, videos=videos, channels=channels)

        verdict = result.verdict_for("chan-self-dom")
        assert verdict is not None
        self.assertFalse(verdict.is_eligible)
        # Gate 1 wins deterministically over gate 2.
        self.assertEqual(verdict.reason_code, ReasonCode.SELF_CHANNEL)

    def test_human_override_sets_reason_and_reviewed_flag(self) -> None:
        run_filter = make_filter()
        videos = [
            RunVideo(RUN_ID, "v1", "chan-a", "artist-1"),
            RunVideo(RUN_ID, "v2", "chan-b", "artist-1"),
        ]
        # A human forces the otherwise-eligible chan-a to ineligible.
        result = run_filter.evaluate_run(
            run_id=RUN_ID, videos=videos, channels=channel_records(videos),
            human_overrides={"chan-a": False},
        )

        overridden = result.verdict_for("chan-a")
        assert overridden is not None
        self.assertFalse(overridden.is_eligible)
        self.assertEqual(overridden.reason_code, ReasonCode.HUMAN_OVERRIDE)
        self.assertTrue(overridden.reviewed_by_human)

        projection = result.projection_for("artist-1")
        assert projection is not None
        self.assertEqual(projection.valid_video_ids, ("v2",))
        self.assertEqual(projection.eligible_channel_ids, ("chan-b",))

    def test_human_override_can_force_eligible_over_a_domination_verdict(self) -> None:
        run_filter = make_filter()
        videos = videos_for_channel("chan-dom", 61)
        result = run_filter.evaluate_run(
            run_id=RUN_ID, videos=videos, channels=channel_records(videos),
            human_overrides={"chan-dom": True},
        )

        verdict = result.verdict_for("chan-dom")
        assert verdict is not None
        self.assertTrue(verdict.is_eligible)
        self.assertEqual(verdict.reason_code, ReasonCode.HUMAN_OVERRIDE)
        self.assertTrue(verdict.reviewed_by_human)

    def test_determinism_same_inputs_produce_identical_output(self) -> None:
        catalog = FakeArtistCatalog({"artist-1": ("BeatFactory",)})
        run_filter = make_filter(catalog=catalog)
        videos = (
            videos_for_channel("chan-a", 5)
            + videos_for_channel("chan-self", 3)
            + videos_for_channel("chan-dom", 61, artist_id="artist-2")
        )
        # chan-a / chan-dom carry title-less records; only chan-self is a self match.
        channels = channel_records(videos, titles={"chan-self": "BeatFactory"})

        first = run_filter.evaluate_run(run_id=RUN_ID, videos=videos, channels=channels)
        second = run_filter.evaluate_run(run_id=RUN_ID, videos=videos, channels=channels)

        self.assertEqual(first.verdicts, second.verdicts)
        self.assertEqual(first.projections, second.projections)

    def test_rule_hash_is_stable_frozen_and_sensitive_to_constants(self) -> None:
        self.assertEqual(RULE_VERSION, "channel-filter-v1")
        self.assertEqual(MAX_RUN_VIDEOS_PER_CHANNEL, 60)

        rule_hash = DEFAULT_CONFIG.rule_hash
        self.assertEqual(len(rule_hash), 64)
        self.assertTrue(all(character in "0123456789abcdef" for character in rule_hash))
        # Stable across independently constructed identical configs.
        self.assertEqual(FilterConfig().rule_hash, rule_hash)
        # A verdict carries the same frozen version + hash.
        result = make_filter().evaluate_run(
            run_id=RUN_ID,
            videos=[RunVideo(RUN_ID, "v1", "chan", "artist-1")],
            channels=[ChannelRecord(RUN_ID, "chan")],
        )
        self.assertEqual(result.rule_hash, rule_hash)
        self.assertEqual(result.rule_version, RULE_VERSION)
        # Changing the only active constant must change the hash (=> new rule_version).
        self.assertNotEqual(FilterConfig(max_run_videos_per_channel=61).rule_hash, rule_hash)

    def test_reason_code_allow_list_is_closed_to_v1(self) -> None:
        self.assertEqual(
            {code.value for code in ReasonCode},
            {"eligible", "self_channel", "run_domination", "human_override"},
        )

    def test_channel_without_record_fails_closed(self) -> None:
        # Fail-closed (DC2-01 · DEC-0022, amends DEC-0019 §2): a channel present in the
        # run footprint with no raw ChannelRecord is a ContractViolation, NOT a silently
        # tolerated eligible pass. Enforced before any verdict / Competition / Signals.
        catalog = FakeArtistCatalog({"artist-1": ("BeatFactory",)})
        run_filter = make_filter(catalog=catalog)
        videos = [
            RunVideo(RUN_ID, "v1", "chan-a", "artist-1"),
            RunVideo(RUN_ID, "v2", "chan-b", "artist-1"),
        ]

        # (a) no records at all.
        with self.assertRaises(ContractViolation):
            run_filter.evaluate_run(run_id=RUN_ID, videos=videos, channels=())

        # (b) partial coverage — chan-b still missing a record fails closed just the same.
        with self.assertRaises(ContractViolation):
            run_filter.evaluate_run(
                run_id=RUN_ID,
                videos=videos,
                channels=[ChannelRecord(RUN_ID, "chan-a")],
            )

    def test_complete_channel_records_run_the_full_green_path(self) -> None:
        # The satisfied precondition (every footprint channel has a raw record) runs the
        # full deterministic path: self_channel, eligible and run_domination all resolve
        # and Signals/Competition project honestly — no verdict is skipped or fabricated.
        catalog = FakeArtistCatalog({"artist-1": ("Kairo Vée",)})
        run_filter = make_filter(catalog=catalog)
        videos = (
            [RunVideo(RUN_ID, "s1", "chan-self", "artist-1")]
            + [RunVideo(RUN_ID, "r1", "chan-rival", "artist-1")]
            + videos_for_channel("chan-dom", 61, artist_id="artist-1")
        )
        channels = channel_records(videos, titles={"chan-self": "KAIRO—Vée"})

        result = run_filter.evaluate_run(run_id=RUN_ID, videos=videos, channels=channels)

        self_v = result.verdict_for("chan-self")
        rival_v = result.verdict_for("chan-rival")
        dom_v = result.verdict_for("chan-dom")
        assert self_v is not None and rival_v is not None and dom_v is not None
        self.assertEqual(self_v.reason_code, ReasonCode.SELF_CHANNEL)
        self.assertTrue(rival_v.is_eligible)
        self.assertEqual(rival_v.reason_code, ReasonCode.ELIGIBLE)
        self.assertEqual(dom_v.reason_code, ReasonCode.RUN_DOMINATION)

        projection = result.projection_for("artist-1")
        assert projection is not None
        # self + dominated both drop from Competition and Signals; only the rival remains.
        self.assertEqual(projection.eligible_channel_ids, ("chan-rival",))
        self.assertEqual(projection.valid_video_ids, ("r1",))

    def test_is_self_channel_pure_helper_guards_empty_title(self) -> None:
        names = frozenset({normalize_for_match("BeatFactory")})
        self.assertTrue(is_self_channel(normalize_for_match("beatfactory"), names))
        self.assertFalse(is_self_channel("", frozenset({""})))
        self.assertFalse(is_self_channel(normalize_for_match("Other"), names))

    def test_run_scope_and_blank_key_violations_are_rejected(self) -> None:
        run_filter = make_filter()
        with self.assertRaises(ContractViolation):
            run_filter.evaluate_run(run_id="   ", videos=[])
        with self.assertRaises(ContractViolation):
            run_filter.evaluate_run(
                run_id=RUN_ID,
                videos=[RunVideo("other-run", "v1", "chan", "artist-1")],
            )
        with self.assertRaises(ContractViolation):
            run_filter.evaluate_run(
                run_id=RUN_ID,
                videos=[RunVideo(RUN_ID, "v1", "", "artist-1")],
            )


if __name__ == "__main__":
    unittest.main()
