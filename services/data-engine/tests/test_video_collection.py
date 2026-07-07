"""SG-V5 §8 tests for the Video Data collector — stdlib unittest, no network.

Every test runs with fakes/mocks: zero live egress to googleapis.com, zero real
secret, zero real DB, zero migration. Maps to DATA-COLLECT-001 §8.1–§8.5 plus the
run-creation (§2), pagination (§3.2) and batch-validation (§4.2) invariants:

  §8.1 body-vs-envelope   — only the response BODY is persisted, never the wrapper
  §8.2 CHECK/scrub        — clean body accepted; request-context keys rejected
  §8.3 canary             — a fake key travels in the header only; never reaches
                            raw_json, the request URL, or the logs; pageToken never logged
  §8.4 quota fail         — quotaExceeded (search OR videos) fails the whole run
  §8.5 retry/idempotency  — transient errors retried deterministically; a duplicate
                            INSERT is fail-closed (NO `on conflict do nothing`; §5)
  §3.2 pagination         — token chain verbatim; cycle fails; stop=target/exhausted
  §4.2 batch validation   — missing / extra / duplicate item fails the run
  §2   run creation       — creates report_runs (created→collecting); 30-day window
"""

from __future__ import annotations

import io
import json
import logging
import unittest
import urllib.error
from datetime import datetime, timezone
from unittest import mock

from noxund_data_engine import video_collection as vc

_RUN = "22222222-2222-4222-8222-222222222222"
_CANARY = "AIzaSy-CANARY-must-never-be-logged-or-persisted-000"
_WS, _WE = vc.window_bounds(datetime(2026, 7, 1, tzinfo=timezone.utc))


# --- body builders -----------------------------------------------------------


def _search_body(video_ids, *, next_token=None, extra=None):
    body = {
        "kind": "youtube#searchListResponse",
        "items": [
            {"id": {"kind": "youtube#video", "videoId": v}, "snippet": {"title": "t"}}
            for v in video_ids
        ],
        "pageInfo": {"totalResults": len(video_ids), "resultsPerPage": 50},
    }
    if next_token is not None:
        body["nextPageToken"] = next_token
    if extra:
        body.update(extra)
    return body


def _video_item(video_id, *, channel="UC_chan", title="Vid", published="2026-06-15T00:00:00Z",
                views="1000", likes="100", comments="10", extra=None):
    stats = {}
    if views is not None:
        stats["viewCount"] = views
    if likes is not None:
        stats["likeCount"] = likes
    if comments is not None:
        stats["commentCount"] = comments
    item = {
        "kind": "youtube#video",
        "id": video_id,
        "snippet": {"channelId": channel, "title": title, "publishedAt": published},
        "statistics": stats,
    }
    if extra:
        item.update(extra)
    return item


def _videos_body(items):
    return {"kind": "youtube#videoListResponse", "items": items}


# --- fakes -------------------------------------------------------------------


class FakeSearchApi:
    def __init__(self, pages_by_token):
        self._pages = pages_by_token
        self.tokens = []

    def list_search_page(self, page_token):
        self.tokens.append(page_token)
        return self._pages[page_token]


class FakeVideosApi:
    """VideosApi fake: returns items for known ids; omits `omit` ids (validation)."""

    def __init__(self, items_by_id, *, omit=()):
        self._items = items_by_id
        self._omit = set(omit)
        self.batches = []

    def list_videos(self, video_ids):
        self.batches.append(list(video_ids))
        return [self._items[v] for v in video_ids if v in self._items and v not in self._omit]


class FakeUniqueViolation(Exception):
    """Simulates a DB unique-index violation (append-only collision)."""


class FakeCursor:
    def __init__(self, conn):
        self._conn = conn
        self._result = []

    def execute(self, sql, params=()):
        s = " ".join(sql.lower().split())
        self._conn.executed.append((s, tuple(params)))
        if s.startswith("insert into public.report_runs"):
            self._conn.runs[params[0]] = {
                "keyword": params[1], "vertical": params[2], "window_start": params[3],
                "window_end": params[4], "target": params[5], "status": "created",
                "collected": None, "quota": None,
            }
        elif "update public.report_runs set status = 'collecting'" in s:
            self._conn.runs[params[0]]["status"] = "collecting"
        elif s.startswith("insert into public.raw_youtube_search_pages"):
            key = (params[0], params[1] or "")
            if key in self._conn.pages:
                raise FakeUniqueViolation("duplicate search page")
            self._conn.pages[key] = tuple(params)
        elif s.startswith("insert into public.raw_youtube_videos"):
            key = (params[0], params[1])
            if key in self._conn.videos:
                raise FakeUniqueViolation("duplicate video")
            self._conn.videos[key] = tuple(params)
        elif s.startswith("select video_id from public.raw_youtube_videos"):
            self._result = [(vid,) for (run, vid) in self._conn.videos if run == params[0]]
        elif "update public.report_runs set collected_video_count" in s:
            run = self._conn.runs[params[2]]
            run["collected"] = params[0]
            run["quota"] = params[1]
        elif "update public.report_runs set status = 'failed'" in s:
            run = self._conn.runs.get(params[1])
            if run is not None:
                run["status"] = "failed"
                run["quota"] = params[0]
            self._conn.failed_run = params[1]
        else:
            self._result = []

    def fetchall(self):
        return self._result

    def close(self):
        pass


class FakeConnection:
    def __init__(self):
        self.runs = {}
        self.pages = {}
        self.videos = {}
        self.executed = []
        self.committed = 0
        self.rolled_back = 0
        self.failed_run = None

    def cursor(self):
        return FakeCursor(self)

    def commit(self):
        self.committed += 1

    def rollback(self):
        self.rolled_back += 1

    def close(self):
        pass

    def stored_search_json(self):
        return [params[2] for params in self.pages.values()]

    def stored_video_json(self):
        return [params[8] for params in self.videos.values()]

    def mutated_raw(self):
        verbs = ("update ", "delete ", "truncate ")
        raw = ("raw_youtube_search_pages", "raw_youtube_videos")
        return any(
            any(t in s for t in raw) and any(w in s for w in verbs) for s, _ in self.executed
        )


class _FakeResponse:
    def __init__(self, payload):
        self._payload = payload

    def read(self):
        return self._payload

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


class RoutingOpener:
    def __init__(self, search_body, videos_body):
        self._search = search_body
        self._videos = videos_body
        self.requests = []

    def __call__(self, request):
        self.requests.append(request)
        url = request.full_url
        payload = self._search if "/youtube/v3/search" in url else (
            self._videos if "/youtube/v3/videos" in url else {})
        return _FakeResponse(json.dumps(payload).encode("utf-8"))


class FlakyOpener:
    def __init__(self, fails, body):
        self._remaining = fails
        self._body = body
        self.calls = 0

    def __call__(self, request):
        self.calls += 1
        if self._remaining > 0:
            self._remaining -= 1
            raise urllib.error.HTTPError(request.full_url, 503, "busy", {}, io.BytesIO(b""))
        return _FakeResponse(json.dumps(self._body).encode("utf-8"))


class QuotaOpener:
    def __init__(self):
        self.calls = 0

    def __call__(self, request):
        self.calls += 1
        body = {"error": {"errors": [{"reason": "quotaExceeded"}]}}
        raise urllib.error.HTTPError(
            request.full_url, 403, "quota", {}, io.BytesIO(json.dumps(body).encode("utf-8"))
        )


class _ListHandler(logging.Handler):
    def __init__(self):
        super().__init__()
        self.messages = []

    def emit(self, record):
        self.messages.append(record.getMessage())


def _capture_logs():
    handler = _ListHandler()
    vc._LOG.addHandler(handler)
    vc._LOG.setLevel(logging.DEBUG)
    return handler


def _collect(conn, search_api, videos_api, run_id=_RUN):
    return vc.collect_new_run(run_id, _WS, _WE, search_api, videos_api, conn)


# --- §8.1 body-vs-envelope ---------------------------------------------------


class BodyVsEnvelope(unittest.TestCase):
    def test_search_and_video_bodies_persisted_verbatim(self):
        search = FakeSearchApi({None: _search_body(["v1", "v2"])})
        videos = FakeVideosApi({"v1": _video_item("v1"), "v2": _video_item("v2")})
        conn = FakeConnection()
        _collect(conn, search, videos)

        self.assertEqual(json.loads(conn.stored_search_json()[0]), _search_body(["v1", "v2"]))
        stored_videos = [json.loads(r) for r in conn.stored_video_json()]
        self.assertEqual({v["id"] for v in stored_videos}, {"v1", "v2"})
        for blob in conn.stored_search_json() + conn.stored_video_json():
            for envelope in ("config", "request", "headers", "authorization"):
                self.assertNotIn(f'"{envelope}"', blob)


# --- §8.2 CHECK / scrub ------------------------------------------------------


class CheckScrub(unittest.TestCase):
    def test_clean_bodies_accepted(self):
        body = _search_body(["v1"])
        self.assertIs(vc.reject_request_context(body), body)
        item = _video_item("v1")
        self.assertIs(vc.reject_request_context(item), item)

    def test_request_context_key_rejected_in_search_body(self):
        for envelope in ("config", "request", "headers", "authorization", "key"):
            conn = FakeConnection()
            with self.assertRaises(vc.CollectionError):
                vc.insert_search_page(conn, _RUN, None, _search_body(["v1"], extra={envelope: "x"}))

    def test_request_context_key_rejected_in_video_item(self):
        for envelope in ("config", "request", "headers", "authorization", "key"):
            with self.assertRaises(vc.CollectionError):
                vc.project_video(_video_item("v1", extra={envelope: "leak"}))

    def test_error_message_never_echoes_the_value(self):
        with self.assertRaises(vc.CollectionError) as ctx:
            vc.reject_request_context(_video_item("v1", extra={"key": "sk-secret-value"}))
        self.assertNotIn("sk-secret-value", str(ctx.exception))


# --- §8.3 canary (secret / pageToken leak) ----------------------------------


class Canary(unittest.TestCase):
    def test_key_header_only_never_leaks_to_url_body_or_logs(self):
        opener = RoutingOpener(
            _search_body(["v1", "v2"]), _videos_body([_video_item("v1"), _video_item("v2")])
        )
        search = vc.UrllibSearchApi(
            _CANARY, published_after=vc.rfc3339(_WS), published_before=vc.rfc3339(_WE),
            sleep=lambda _s: None, opener=opener,
        )
        videos = vc.UrllibVideosApi(_CANARY, sleep=lambda _s: None, opener=opener)
        conn = FakeConnection()
        handler = _capture_logs()
        try:
            _collect(conn, search, videos)
        finally:
            vc._LOG.removeHandler(handler)

        for request in opener.requests:
            self.assertNotIn("key=", request.full_url)  # OQ-6: never ?key=
            self.assertIn(_CANARY, [v for _k, v in request.header_items()])
        for blob in conn.stored_search_json() + conn.stored_video_json():
            self.assertNotIn(_CANARY, blob)
        self.assertNotIn(_CANARY, "\n".join(handler.messages))

    def test_page_token_never_reaches_the_logs(self):
        token = "SECRET-PAGE-TOKEN-must-not-log"
        search = FakeSearchApi({
            None: _search_body(["v1"], next_token=token),
            token: _search_body(["v2"]),
        })
        videos = FakeVideosApi({"v1": _video_item("v1"), "v2": _video_item("v2")})
        conn = FakeConnection()
        handler = _capture_logs()
        try:
            _collect(conn, search, videos)
        finally:
            vc._LOG.removeHandler(handler)
        self.assertNotIn(token, "\n".join(handler.messages))


# --- §8.4 quota fail ---------------------------------------------------------


class QuotaFail(unittest.TestCase):
    def test_search_quota_fails_run_no_commit(self):
        search = vc.UrllibSearchApi(
            _CANARY, published_after="a", published_before="b",
            sleep=lambda _s: None, opener=QuotaOpener(),
        )
        conn = FakeConnection()
        with self.assertRaises(vc.QuotaExceeded):
            _collect(conn, search, FakeVideosApi({}))
        self.assertEqual(conn.committed, 0)

    def test_videos_quota_fails_run_no_commit(self):
        search = FakeSearchApi({None: _search_body(["v1"])})
        videos = vc.UrllibVideosApi(_CANARY, sleep=lambda _s: None, opener=QuotaOpener())
        conn = FakeConnection()
        with self.assertRaises(vc.QuotaExceeded):
            _collect(conn, search, videos)
        self.assertEqual(conn.committed, 0)

    def test_main_marks_run_failed_and_exits_nonzero(self):
        failing = mock.Mock()
        failing.list_search_page.side_effect = vc.QuotaExceeded("quota")
        conn = FakeConnection()
        env = {"YOUTUBE_API_KEY": _CANARY, "SUPABASE_DB_URL": "postgresql://x"}
        with mock.patch.dict("os.environ", env, clear=False), \
                mock.patch.object(vc, "_connect", return_value=conn), \
                mock.patch.object(vc, "_new_run_id", return_value=_RUN), \
                mock.patch.object(vc, "UrllibSearchApi", return_value=failing), \
                mock.patch.object(vc, "UrllibVideosApi", return_value=mock.Mock()):
            rc = vc.main([])
        self.assertEqual(rc, 1)
        self.assertEqual(conn.failed_run, _RUN)
        self.assertEqual(conn.runs[_RUN]["status"], "failed")
        self.assertGreaterEqual(conn.rolled_back, 1)


# --- §8.5 retry / idempotency ------------------------------------------------


class RetryIdempotency(unittest.TestCase):
    def test_transient_errors_retried_deterministically(self):
        sleeps = []
        quota = vc._Quota()
        opener = FlakyOpener(fails=2, body=_search_body(["v1"]))
        search = vc.UrllibSearchApi(
            _CANARY, published_after="a", published_before="b",
            quota=quota, sleep=sleeps.append, opener=opener,
        )
        body = search.list_search_page(None)
        self.assertEqual(body["items"][0]["id"]["videoId"], "v1")
        self.assertEqual(opener.calls, 3)
        self.assertEqual(sleeps, [1.0, 2.0])  # fixed backoff, no randomness
        self.assertEqual(quota.retry_surplus, 200)  # 2 retries x 100 (search) as surplus

    def test_inserts_have_no_on_conflict_do_nothing(self):
        conn = FakeConnection()
        _collect(conn, FakeSearchApi({None: _search_body(["v1"])}),
                 FakeVideosApi({"v1": _video_item("v1")}))
        for s, _p in conn.executed:
            if s.startswith("insert into public.raw_youtube_"):
                self.assertNotIn("on conflict", s)  # §5: unique_violation is fail-closed

    def test_duplicate_insert_is_fail_closed(self):
        conn = FakeConnection()
        vc.insert_video(conn, _RUN, vc.project_video(_video_item("v1")))
        with self.assertRaises(FakeUniqueViolation):
            vc.insert_video(conn, _RUN, vc.project_video(_video_item("v1")))
        self.assertFalse(conn.mutated_raw())


# --- F-1' / OD-V2 quota cap + retry budget (RR-8) ----------------------------


class QuotaCapAndRetryBudget(unittest.TestCase):
    def test_retry_capped_at_two_per_call(self):
        sleeps = []
        opener = FlakyOpener(fails=3, body=_search_body(["v1"]))  # never succeeds
        search = vc.UrllibSearchApi(
            _CANARY, published_after="a", published_before="b",
            sleep=sleeps.append, opener=opener,
        )
        with self.assertRaises(vc.CollectionError):
            search.list_search_page(None)
        self.assertEqual(opener.calls, 3)  # 1 initial + exactly 2 retries
        self.assertEqual(sleeps, [1.0, 2.0])  # <= 2 backoffs

    def test_quota_error_is_terminal_single_call_no_retry(self):
        opener = QuotaOpener()
        search = vc.UrllibSearchApi(
            _CANARY, published_after="a", published_before="b",
            sleep=lambda _s: None, opener=opener,
        )
        with self.assertRaises(vc.QuotaExceeded):
            search.list_search_page(None)
        self.assertEqual(opener.calls, 1)  # quotaExceeded/dailyLimitExceeded never retried

    def test_quota_projection_is_before_spend(self):
        q = vc._Quota(cap=100)
        q.charge(100)
        self.assertEqual(q.used, 100)
        with self.assertRaises(vc.QuotaCapExceeded):
            q.charge(1)  # projected to exceed 100
        self.assertEqual(q.used, 100)  # rejected charge never mutates (fail-closed)

    def test_per_run_cap_fail_closed_not_source_exhausted(self):
        search = FakeSearchApi({
            None: _search_body(["v1"], next_token="T1"),
            "T1": _search_body(["v2"]),
        })
        videos = FakeVideosApi({"v1": _video_item("v1"), "v2": _video_item("v2")})
        conn = FakeConnection()
        # cap 150 admits page 1 (100) but fail-closes the page-2 charge (200 > 150).
        with self.assertRaises(vc.QuotaCapExceeded):
            vc.collect_new_run(_RUN, _WS, _WE, search, videos, conn, vc._Quota(cap=150))
        self.assertIsNone(conn.runs[_RUN]["collected"])  # never finalized
        self.assertEqual(conn.runs[_RUN]["status"], "collecting")  # NOT source_exhausted

    def test_retry_surplus_capped(self):
        opener = FlakyOpener(fails=1, body=_search_body(["v1"]))
        search = vc.UrllibSearchApi(
            _CANARY, published_after="a", published_before="b",
            quota=vc._Quota(retry_surplus_cap=50), sleep=lambda _s: None, opener=opener,
        )
        with self.assertRaises(vc.QuotaCapExceeded):
            search.list_search_page(None)  # one retry costs 100 > surplus cap 50

    def test_cap_exceeded_via_main_marks_run_failed_and_nonzero(self):
        search = mock.Mock()
        search.list_search_page.side_effect = [
            _search_body(["v1"], next_token="T1"), _search_body(["v2"]),
        ]
        conn = FakeConnection()
        env = {"YOUTUBE_API_KEY": _CANARY, "SUPABASE_DB_URL": "postgresql://x"}
        with mock.patch.dict("os.environ", env, clear=False), \
                mock.patch.object(vc, "_PER_RUN_QUOTA_CAP", 150), \
                mock.patch.object(vc, "_connect", return_value=conn), \
                mock.patch.object(vc, "_new_run_id", return_value=_RUN), \
                mock.patch.object(vc, "UrllibSearchApi", return_value=search), \
                mock.patch.object(vc, "UrllibVideosApi", return_value=mock.Mock()):
            rc = vc.main([])
        self.assertEqual(rc, 1)
        self.assertEqual(conn.failed_run, _RUN)
        self.assertEqual(conn.runs[_RUN]["status"], "failed")


# --- §3.2 pagination determinism --------------------------------------------


class Pagination(unittest.TestCase):
    def test_token_chain_followed_verbatim(self):
        search = FakeSearchApi({
            None: _search_body(["v1"], next_token="T1"),
            "T1": _search_body(["v2"], next_token="T2"),
            "T2": _search_body(["v3"]),
        })
        videos = FakeVideosApi({v: _video_item(v) for v in ("v1", "v2", "v3")})
        conn = FakeConnection()
        count, stop = _collect(conn, search, videos)
        self.assertEqual(search.tokens, [None, "T1", "T2"])  # verbatim, in order
        self.assertEqual(count, 3)
        self.assertEqual(stop, "source_exhausted")
        self.assertEqual({params[1] for params in conn.pages.values()}, {None, "T1", "T2"})

    def test_cycle_detected_fails_closed(self):
        search = FakeSearchApi({
            None: _search_body(["v1"], next_token="T1"),
            "T1": _search_body(["v2"], next_token="T1"),  # points back to itself
        })
        videos = FakeVideosApi({"v1": _video_item("v1"), "v2": _video_item("v2")})
        conn = FakeConnection()
        with self.assertRaises(vc.PaginationError):
            _collect(conn, search, videos)

    def test_source_exhausted_when_no_next_token(self):
        conn = FakeConnection()
        _n, stop = _collect(conn, FakeSearchApi({None: _search_body(["v1"])}),
                            FakeVideosApi({"v1": _video_item("v1")}))
        self.assertEqual(stop, "source_exhausted")

    def test_target_reached_caps_at_500(self):
        page1 = _search_body([f"a{i}" for i in range(300)], next_token="T1")
        page2 = _search_body([f"b{i}" for i in range(300)], next_token="T2")
        ids = [f"a{i}" for i in range(300)] + [f"b{i}" for i in range(200)]
        videos = FakeVideosApi({v: _video_item(v) for v in ids})
        conn = FakeConnection()
        count, stop = _collect(conn, FakeSearchApi({None: page1, "T1": page2}), videos)
        self.assertEqual(stop, "target_reached")
        self.assertEqual(count, 500)
        self.assertEqual(len(conn.videos), 500)


# --- §4.2 batch validation ---------------------------------------------------


class BatchValidation(unittest.TestCase):
    def test_omitted_video_fails_closed(self):
        search = FakeSearchApi({None: _search_body(["v1", "v2", "gone"])})
        videos = FakeVideosApi(
            {"v1": _video_item("v1"), "v2": _video_item("v2"), "gone": _video_item("gone")},
            omit=("gone",),
        )
        conn = FakeConnection()
        with self.assertRaises(vc.VideoValidationError):
            _collect(conn, search, videos)
        self.assertNotIn((_RUN, "gone"), conn.videos)  # no fabricated row

    def test_unrequested_video_fails_closed(self):
        with self.assertRaises(vc.VideoValidationError):
            vc.validate_batch(["v1"], [_video_item("v1"), _video_item("vX")])

    def test_duplicate_video_in_response_fails_closed(self):
        with self.assertRaises(vc.VideoValidationError):
            vc.validate_batch(["v1"], [_video_item("v1"), _video_item("v1")])


# --- projection (NULL != 0) --------------------------------------------------


class Projection(unittest.TestCase):
    def test_absent_stat_is_null_present_zero_is_zero(self):
        item = _video_item("v1", views="0", likes=None, comments="7")
        row = vc.project_video(item)
        self.assertEqual(row.views, 0)  # present "0" ⇒ 0
        self.assertIsNone(row.likes)  # absent ⇒ NULL (never 0)
        self.assertEqual(row.comments, 7)


# --- §2 run creation / finalization -----------------------------------------


class RunLifecycle(unittest.TestCase):
    def test_creates_run_with_locked_identity_and_30_day_window(self):
        conn = FakeConnection()
        _collect(conn, FakeSearchApi({None: _search_body(["v1"])}),
                 FakeVideosApi({"v1": _video_item("v1")}))
        run = conn.runs[_RUN]
        self.assertEqual(run["keyword"], "chicago drill type beat")
        self.assertEqual(run["vertical"], "Chicago Drill")
        self.assertEqual(run["target"], 500)
        self.assertEqual((run["window_end"] - run["window_start"]).days, 30)
        self.assertEqual(run["status"], "collecting")  # never promoted past collecting

    def test_finalize_writes_collected_count_and_not_failed(self):
        conn = FakeConnection()
        count, _stop = _collect(conn, FakeSearchApi({None: _search_body(["v1", "v2"])}),
                                FakeVideosApi({"v1": _video_item("v1"), "v2": _video_item("v2")}))
        self.assertEqual(count, 2)
        self.assertEqual(conn.runs[_RUN]["collected"], 2)
        self.assertNotEqual(conn.runs[_RUN]["status"], "failed")

    def test_window_bounds_is_exactly_30_days_utc(self):
        now = datetime(2026, 7, 1, 12, 0, tzinfo=timezone.utc)
        start, end = vc.window_bounds(now)
        self.assertEqual(end, now)
        self.assertEqual((end - start).days, 30)

    def test_new_run_id_is_fresh_each_call(self):
        self.assertNotEqual(vc._new_run_id(), vc._new_run_id())  # recoleta = new run_id


# --- entrypoint guards -------------------------------------------------------


class EntrypointGuards(unittest.TestCase):
    def test_missing_env_fails_closed(self):
        with mock.patch.dict("os.environ", {}, clear=True):
            self.assertEqual(vc.main([]), 2)

    def test_success_path_commits_and_returns_zero(self):
        search = mock.Mock()
        search.list_search_page.return_value = _search_body(["v1"])
        videos = mock.Mock()
        videos.list_videos.return_value = [_video_item("v1")]
        conn = FakeConnection()
        env = {"YOUTUBE_API_KEY": _CANARY, "SUPABASE_DB_URL": "postgresql://x"}
        with mock.patch.dict("os.environ", env, clear=False), \
                mock.patch.object(vc, "_connect", return_value=conn), \
                mock.patch.object(vc, "_new_run_id", return_value=_RUN), \
                mock.patch.object(vc, "UrllibSearchApi", return_value=search), \
                mock.patch.object(vc, "UrllibVideosApi", return_value=videos):
            rc = vc.main([])
        self.assertEqual(rc, 0)
        self.assertEqual(conn.runs[_RUN]["collected"], 1)
        self.assertGreaterEqual(conn.committed, 1)
        self.assertIsNone(conn.failed_run)

    def test_unexpected_db_error_is_fail_closed(self):
        search = mock.Mock()
        search.list_search_page.return_value = _search_body(["v1"])
        videos = mock.Mock()
        videos.list_videos.return_value = [_video_item("v1")]
        conn = FakeConnection()
        # Pre-seed the page so the collector's INSERT collides (unique_violation).
        conn.pages[(_RUN, "")] = ("pre",)
        env = {"YOUTUBE_API_KEY": _CANARY, "SUPABASE_DB_URL": "postgresql://x"}
        with mock.patch.dict("os.environ", env, clear=False), \
                mock.patch.object(vc, "_connect", return_value=conn), \
                mock.patch.object(vc, "_new_run_id", return_value=_RUN), \
                mock.patch.object(vc, "UrllibSearchApi", return_value=search), \
                mock.patch.object(vc, "UrllibVideosApi", return_value=videos):
            rc = vc.main([])
        self.assertEqual(rc, 1)
        self.assertEqual(conn.failed_run, _RUN)


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
