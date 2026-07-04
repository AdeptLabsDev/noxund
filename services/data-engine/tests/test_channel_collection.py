"""SG-5 §8 tests for the Channel Data collector — stdlib unittest, no network.

Every test runs with fakes/mocks: zero live egress to googleapis.com, zero real
secret, zero real DB. Maps to DATA-COLLECT-002 §8.1–§8.6:

  §8.1 body-vs-envelope   — only the response BODY is persisted, never the wrapper
  §8.2 CHECK/scrub        — clean body accepted; request-context keys rejected
  §8.3 canary             — a known fake key never reaches raw_json or the logs
  §8.4 quota fail         — quotaExceeded fails the whole run (no partial success)
  §8.5 retry              — transient errors retried deterministically; idempotent
  §8.6 DC2-01             — an omitted channel fails closed (no fabricated row)
"""

from __future__ import annotations

import io
import json
import logging
import unittest
import urllib.error
from unittest import mock

from noxund_data_engine import channel_collection as cc

_RUN = "11111111-1111-4111-8111-111111111111"
_CANARY = "AIzaSy-CANARY-must-never-be-logged-or-persisted-000"


# --- fakes -------------------------------------------------------------------


def _channel_body(channel_id, *, title="Chan", video_count="10",
                  subscriber_count="100", view_count="1000", extra=None):
    stats = {}
    if video_count is not None:
        stats["videoCount"] = video_count
    if subscriber_count is not None:
        stats["subscriberCount"] = subscriber_count
    if view_count is not None:
        stats["viewCount"] = view_count
    item = {"kind": "youtube#channel", "id": channel_id,
            "snippet": {"title": title}, "statistics": stats}
    if extra:
        item.update(extra)
    return item


class FakeApi:
    """ChannelsApi fake: returns bodies for known ids; omits unknown ids (DC2-01)."""

    def __init__(self, bodies_by_id):
        self._bodies = bodies_by_id
        self.calls = []

    def list_channels(self, channel_ids):
        self.calls.append(list(channel_ids))
        return [self._bodies[c] for c in channel_ids if c in self._bodies]


class FakeCursor:
    def __init__(self, conn):
        self._conn = conn
        self._result = []

    def execute(self, sql, params=()):
        s = " ".join(sql.lower().split())
        self._conn.executed.append((s, tuple(params)))
        if "from public.raw_youtube_videos" in s:
            self._result = [(cid,) for cid in self._conn.video_channel_ids]
        elif "insert into public.raw_youtube_channels" in s:
            key = (params[0], params[1])
            if "on conflict" in s and key in self._conn.channels:
                pass  # DO NOTHING — never overwrite (raw is immutable)
            else:
                self._conn.channels[key] = tuple(params)
            self._result = []
        elif "update public.report_runs" in s and "'failed'" in s:
            self._conn.failed_run = params[0]
            self._result = []
        else:
            self._result = []

    def fetchall(self):
        return self._result

    def close(self):
        pass


class FakeConnection:
    def __init__(self, video_channel_ids=()):
        self.video_channel_ids = list(video_channel_ids)
        self.channels = {}
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

    def stored_raw_json(self):
        return [params[6] for params in self.channels.values()]

    def mutated_raw(self):
        verbs = ("update ", "delete ", "truncate ")
        return any(
            "raw_youtube_channels" in s and any(w in s for w in verbs)
            for s, _ in self.executed
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


class RecordingOpener:
    def __init__(self, body):
        self._body = body
        self.requests = []

    def __call__(self, request):
        self.requests.append(request)
        return _FakeResponse(json.dumps(self._body).encode("utf-8"))


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
    def __call__(self, request):
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
    cc._LOG.addHandler(handler)
    cc._LOG.setLevel(logging.DEBUG)
    return handler


# --- §8.1 body-vs-envelope ---------------------------------------------------


class BodyVsEnvelope(unittest.TestCase):
    def test_only_the_body_item_is_persisted(self):
        body = _channel_body("UC_a")
        conn = FakeConnection(video_channel_ids=["UC_a"])
        cc.collect(_RUN, FakeApi({"UC_a": body}), conn)
        stored = self.assertStoredOne(conn)
        self.assertEqual(json.loads(stored), body)
        for envelope_key in ("config", "request", "headers", "authorization", "key"):
            self.assertNotIn(envelope_key, json.loads(stored))

    def assertStoredOne(self, conn):
        raw = conn.stored_raw_json()
        self.assertEqual(len(raw), 1)
        return raw[0]


# --- §8.2 CHECK / scrub ------------------------------------------------------


class CheckScrub(unittest.TestCase):
    def test_clean_body_accepted(self):
        item = _channel_body("UC_a")
        self.assertIs(cc.reject_request_context(item), item)

    def test_request_context_key_rejected(self):
        for envelope_key in ("config", "request", "headers", "authorization", "key"):
            item = _channel_body("UC_a", extra={envelope_key: "leak"})
            with self.assertRaises(cc.CollectionError):
                cc.reject_request_context(item)
            with self.assertRaises(cc.CollectionError):
                cc.project_channel(item)

    def test_error_message_never_echoes_the_value(self):
        item = _channel_body("UC_a", extra={"key": "sk-secret-value"})
        with self.assertRaises(cc.CollectionError) as ctx:
            cc.reject_request_context(item)
        self.assertNotIn("sk-secret-value", str(ctx.exception))


# --- §8.3 canary (secret-leak) ----------------------------------------------


class Canary(unittest.TestCase):
    def test_key_travels_in_header_only_and_never_leaks(self):
        opener = RecordingOpener({"items": [_channel_body("UC_a"), _channel_body("UC_b")]})
        api = cc.UrllibChannelsApi(_CANARY, sleep=lambda _s: None, opener=opener)
        conn = FakeConnection(video_channel_ids=["UC_a", "UC_b"])
        handler = _capture_logs()
        try:
            cc.collect(_RUN, api, conn)
        finally:
            cc._LOG.removeHandler(handler)

        request = opener.requests[0]
        self.assertNotIn("key=", request.full_url)  # OQ-6: never ?key=
        header_values = [v for _k, v in request.header_items()]
        self.assertIn(_CANARY, header_values)  # sent only as X-Goog-Api-Key header

        for raw in conn.stored_raw_json():
            self.assertNotIn(_CANARY, raw)
        self.assertNotIn(_CANARY, "\n".join(handler.messages))


# --- §8.4 quota fail ---------------------------------------------------------


class QuotaFail(unittest.TestCase):
    def test_quota_raises_and_does_not_commit(self):
        api = cc.UrllibChannelsApi(_CANARY, sleep=lambda _s: None, opener=QuotaOpener())
        conn = FakeConnection(video_channel_ids=["UC_a"])
        with self.assertRaises(cc.QuotaExceeded):
            cc.collect(_RUN, api, conn)
        self.assertEqual(conn.committed, 0)

    def test_main_marks_run_failed_and_exits_nonzero(self):
        failing = mock.Mock()
        failing.list_channels.side_effect = cc.QuotaExceeded("channels.list quota exceeded")
        conn = FakeConnection(video_channel_ids=["UC_a"])
        env = {"YOUTUBE_API_KEY": _CANARY, "SUPABASE_DB_URL": "postgresql://x"}
        with mock.patch.dict("os.environ", env, clear=False), \
                mock.patch.object(cc, "_connect", return_value=conn), \
                mock.patch.object(cc, "UrllibChannelsApi", return_value=failing):
            rc = cc.main(["--run-id", _RUN])
        self.assertEqual(rc, 1)
        self.assertEqual(conn.failed_run, _RUN)
        self.assertGreaterEqual(conn.rolled_back, 1)


# --- §8.5 retry / idempotency ------------------------------------------------


class RetryIdempotency(unittest.TestCase):
    def test_transient_errors_retried_deterministically(self):
        sleeps = []
        opener = FlakyOpener(fails=2, body={"items": [_channel_body("UC_a")]})
        api = cc.UrllibChannelsApi(_CANARY, sleep=sleeps.append, opener=opener)
        items = api.list_channels(["UC_a"])
        self.assertEqual(len(items), 1)
        self.assertEqual(opener.calls, 3)
        self.assertEqual(sleeps, [1.0, 2.0])  # fixed backoff, no randomness

    def test_reinsert_is_do_nothing_never_overwrite(self):
        conn = FakeConnection()
        channel = cc.project_channel(_channel_body("UC_a"))
        cc.insert_channel(conn, _RUN, channel)
        cc.insert_channel(conn, _RUN, channel)  # simulate retry / restart
        self.assertEqual(len(conn.channels), 1)
        self.assertFalse(conn.mutated_raw())
        insert_sql = next(
            s for s, _ in conn.executed if "insert into public.raw_youtube_channels" in s
        )
        self.assertIn("on conflict", insert_sql)
        self.assertIn("do nothing", insert_sql)


# --- §8.6 DC2-01 (omitted channel) ------------------------------------------


class Dc201(unittest.TestCase):
    def test_omitted_channel_fails_closed_no_fabricated_row(self):
        api = FakeApi({"UC_a": _channel_body("UC_a"), "UC_b": _channel_body("UC_b")})
        conn = FakeConnection(video_channel_ids=["UC_a", "UC_b", "UC_gone"])
        with self.assertRaises(cc.ChannelOmitted):
            cc.collect(_RUN, api, conn)
        self.assertNotIn((_RUN, "UC_gone"), conn.channels)  # no fabricated raw row


# --- projection (NULL != 0) + entrypoint guards ------------------------------


class Projection(unittest.TestCase):
    def test_absent_stat_is_null_present_zero_is_zero(self):
        item = _channel_body("UC_a", video_count="0", subscriber_count=None, view_count="5")
        row = cc.project_channel(item)
        self.assertEqual(row.upload_count, 0)  # present "0" ⇒ 0
        self.assertIsNone(row.subscriber_count)  # absent ⇒ NULL (never 0)
        self.assertEqual(row.view_count, 5)


class EntrypointGuards(unittest.TestCase):
    def test_missing_env_fails_closed(self):
        with mock.patch.dict("os.environ", {}, clear=True):
            self.assertEqual(cc.main(["--run-id", _RUN]), 2)

    def test_success_commits_and_returns_zero(self):
        api = mock.Mock()
        api.list_channels.return_value = [_channel_body("UC_a")]
        conn = FakeConnection(video_channel_ids=["UC_a"])
        env = {"YOUTUBE_API_KEY": _CANARY, "SUPABASE_DB_URL": "postgresql://x"}
        with mock.patch.dict("os.environ", env, clear=False), \
                mock.patch.object(cc, "_connect", return_value=conn), \
                mock.patch.object(cc, "UrllibChannelsApi", return_value=api):
            rc = cc.main(["--run-id", _RUN])
        self.assertEqual(rc, 0)
        self.assertEqual(len(conn.channels), 1)
        self.assertGreaterEqual(conn.committed, 1)
        self.assertIsNone(conn.failed_run)


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
