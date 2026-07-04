"""Channel Data collector (SG-5) — ``channels.list`` → ``raw_youtube_channels``.

DESIGN-ONLY / DISARMED (DEC-0018 · SG-5). Landing this module does NOT arm the
gated ``youtube-collection.yml`` pipeline: the guard preflight stays fail-closed
until ``.github/collection/youtube-collection.armed`` is committed (SG-4) and a
human dispatches (SG-6). No real API call, no real secret, no dispatch is
performed by landing this file — it is authored, reviewable, and inert.

Non-negotiables locked before code (Security / Database / DevOps contracts):

  * The API key travels ONLY as the ``X-Goog-Api-Key`` header, NEVER ``?key=`` in
    the URL; it is read from the environment and is never logged (SEC-F06 / OQ-6).
  * BODY-ONLY persistence: ``raw_json`` is the verbatim channel resource. The
    transport envelope (``config``/``request``/``headers``/``authorization``/
    ``key``) is rejected before INSERT — defense-in-depth on top of the
    ``raw_youtube_channels_no_request_context`` CHECK (SEC-F08).
  * INSERT-only into ``raw_youtube_channels``; idempotency by
    ``(run_id, channel_id)`` via ``ON CONFLICT DO NOTHING`` (never ``DO UPDATE`` —
    the raw is trigger-immutable below service_role).
  * NULL != 0: an absent/hidden statistic projects to NULL, never a fabricated 0.
  * Fail-closed: quota / transport / omitted-channel (DC2-01) marks the whole run
    ``report_runs.status='failed'`` and exits non-zero → correction = new run_id.
  * Driver-agnostic: no DB driver is imported at module scope. A PEP-249
    connection is injected, so the module is importable and unit-testable with
    fakes — zero network, zero secret (mirrors ``postgres_entity_resolution``).
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, Callable, NamedTuple, Protocol, Sequence

_LOG = logging.getLogger("noxund.channel_collection")

# YouTube Data API v3 · channels.list. The key is a HEADER, never a query param.
_CHANNELS_ENDPOINT = "https://www.googleapis.com/youtube/v3/channels"
_CHANNELS_PARTS = "snippet,statistics"
_MAX_IDS_PER_CALL = 50  # channels.list hard limit and the F-1 cost envelope.
_REQUEST_CONTEXT_KEYS = ("config", "request", "headers", "authorization", "key")
_TRANSIENT_STATUS = frozenset({429, 500, 502, 503, 504})
_QUOTA_REASONS = frozenset({"quotaExceeded", "dailyLimitExceeded"})
_MAX_ATTEMPTS = 4
_BACKOFF_SCHEDULE = (1.0, 2.0, 4.0)  # deterministic; len == _MAX_ATTEMPTS - 1


class CollectionError(RuntimeError):
    """Fail-closed collection error.

    Messages are deliberately opaque: they NEVER carry a secret, an API key, a URL
    query string, a response body, or a channel title (log-hygiene G6). Only key
    names, counts, and HTTP status codes may appear.
    """


class QuotaExceeded(CollectionError):
    """channels.list signalled quota exhaustion — no retry; the whole run fails."""


class ChannelOmitted(CollectionError):
    """DC2-01: a requested channel was not returned by channels.list."""


class CursorLike(Protocol):
    def execute(self, operation: str, parameters: Sequence[Any] = ()) -> Any: ...

    def fetchall(self) -> Sequence[Sequence[Any]]: ...

    def close(self) -> None: ...


class ConnectionLike(Protocol):
    def cursor(self) -> CursorLike: ...

    def commit(self) -> None: ...

    def rollback(self) -> None: ...


class ChannelsApi(Protocol):
    """Fetches channels.list bodies.

    Implementations return the verbatim ``items`` array of the response BODY —
    never the transport envelope.
    """

    def list_channels(self, channel_ids: Sequence[str]) -> list[dict[str, Any]]: ...


class ProjectedChannel(NamedTuple):
    channel_id: str
    title: str | None
    upload_count: int | None
    subscriber_count: int | None
    view_count: int | None
    raw_json: dict[str, Any]


# --- pure logic (no I/O; fully unit-testable) --------------------------------


def distinct_channel_ids(video_channel_ids: Sequence[str]) -> list[str]:
    """Ordered de-dup of the channel ids surfaced by the run's video snapshot."""
    seen: dict[str, None] = {}
    for cid in video_channel_ids:
        if cid and cid not in seen:
            seen[cid] = None
    return list(seen)


def batched(ids: Sequence[str], size: int = _MAX_IDS_PER_CALL) -> list[list[str]]:
    if size < 1:
        raise ValueError("batch size must be >= 1")
    return [list(ids[i : i + size]) for i in range(0, len(ids), size)]


def reject_request_context(item: dict[str, Any]) -> dict[str, Any]:
    """Body-only guard (SEC-F08).

    The verbatim channel resource must not carry a transport-envelope key at the
    top level. Raises rather than silently strip, so a leak becomes a failed run —
    mirroring the DB CHECK backstop. Only the offending KEY names are surfaced.
    """
    present = [k for k in _REQUEST_CONTEXT_KEYS if k in item]
    if present:
        raise CollectionError(f"request-context key(s) in channel body: {','.join(present)}")
    return item


def _bigint_or_none(stats: dict[str, Any], key: str) -> int | None:
    """statistics.<key> → bigint. ABSENT ⇒ None (NULL != 0). Present '0' ⇒ 0."""
    if key not in stats or stats[key] is None:
        return None
    try:
        return int(str(stats[key]))
    except (TypeError, ValueError):
        raise CollectionError(f"non-integer statistics.{key}") from None


def project_channel(item: dict[str, Any]) -> ProjectedChannel:
    """Project a verbatim channel body into the raw_youtube_channels row shape."""
    reject_request_context(item)
    if item.get("kind") != "youtube#channel":
        raise CollectionError("channel body has unexpected kind")
    channel_id = item.get("id")
    if not isinstance(channel_id, str) or not channel_id:
        raise CollectionError("channel body missing id")
    snippet = item.get("snippet") or {}
    stats = item.get("statistics") or {}
    title = snippet.get("title")
    if title is not None and not isinstance(title, str):
        raise CollectionError("channel snippet.title is not text")
    return ProjectedChannel(
        channel_id=channel_id,
        title=title,
        upload_count=_bigint_or_none(stats, "videoCount"),
        subscriber_count=_bigint_or_none(stats, "subscriberCount"),
        view_count=_bigint_or_none(stats, "viewCount"),
        raw_json=item,
    )


def assert_complete(requested: Sequence[str], collected: Sequence[str]) -> None:
    """DC2-01 fail-closed: every requested channel must have been returned."""
    have = set(collected)
    missing = [c for c in requested if c not in have]
    if missing:
        # Count only — a bulk channel_id list must not reach the logs.
        raise ChannelOmitted(f"{len(missing)} channel(s) omitted by channels.list (DC2-01)")


# --- SQL (parameterized; the collector never interpolates values) ------------

_VIDEO_CHANNELS_SQL = """
select distinct channel_id
from public.raw_youtube_videos
where run_id = %s
""".strip()

_INSERT_CHANNEL_SQL = """
insert into public.raw_youtube_channels (
  run_id, channel_id, title, upload_count, subscriber_count, view_count, raw_json
)
values (%s, %s, %s, %s, %s, %s, %s::jsonb)
on conflict (run_id, channel_id) do nothing
""".strip()

_MARK_RUN_FAILED_SQL = "update public.report_runs set status = 'failed' where id = %s"


def fetch_video_channel_ids(conn: ConnectionLike, run_id: str) -> list[str]:
    cursor = conn.cursor()
    try:
        cursor.execute(_VIDEO_CHANNELS_SQL, (run_id,))
        return [str(row[0]) for row in cursor.fetchall() if row and row[0] is not None]
    finally:
        cursor.close()


def insert_channel(conn: ConnectionLike, run_id: str, channel: ProjectedChannel) -> None:
    cursor = conn.cursor()
    try:
        cursor.execute(
            _INSERT_CHANNEL_SQL,
            (
                run_id,
                channel.channel_id,
                channel.title,
                channel.upload_count,
                channel.subscriber_count,
                channel.view_count,
                json.dumps(channel.raw_json, ensure_ascii=False, separators=(",", ":")),
            ),
        )
    finally:
        cursor.close()


def mark_run_failed(conn: ConnectionLike, run_id: str) -> None:
    cursor = conn.cursor()
    try:
        cursor.execute(_MARK_RUN_FAILED_SQL, (run_id,))
    finally:
        cursor.close()


# --- orchestration (I/O injected; unit-testable with fakes) ------------------


def collect(run_id: str, api: ChannelsApi, conn: ConnectionLike) -> int:
    """Collect channel data for an EXISTING run; return the rows inserted.

    Derives the channel set from the run's frozen video snapshot, fetches in
    batches of <= 50 (body-only), INSERTs one immutable row per channel, and
    enforces DC2-01 completeness. Raises ``CollectionError`` (fail-closed) on any
    anomaly; the caller owns commit/rollback and marks the run failed.
    """
    requested = distinct_channel_ids(fetch_video_channel_ids(conn, run_id))
    if not requested:
        raise CollectionError("run has no video channel ids to collect")
    collected: list[str] = []
    for batch in batched(requested):
        for item in api.list_channels(batch):
            channel = project_channel(item)
            insert_channel(conn, run_id, channel)
            collected.append(channel.channel_id)
        _LOG.info("channel_data: batch collected (%d ids)", len(batch))
    assert_complete(requested, collected)
    return len(collected)


# --- real channels.list client (stdlib urllib; header auth; body-only) -------


class UrllibChannelsApi:
    """channels.list over stdlib urllib.

    The API key is sent ONLY as the ``X-Goog-Api-Key`` header (never ``?key=``)
    and only the response BODY ``items`` are returned. ``opener``/``sleep`` are
    injectable so retry/backoff is deterministic and tests never touch the network.
    """

    def __init__(
        self,
        api_key: str,
        *,
        sleep: Callable[[float], None] = time.sleep,
        opener: Callable[[urllib.request.Request], Any] = urllib.request.urlopen,
    ) -> None:
        if not api_key:
            raise CollectionError("missing YOUTUBE_API_KEY")
        self._api_key = api_key
        self._sleep = sleep
        self._opener = opener

    def list_channels(self, channel_ids: Sequence[str]) -> list[dict[str, Any]]:
        if len(channel_ids) > _MAX_IDS_PER_CALL:
            raise CollectionError("batch exceeds channels.list id limit")
        query = urllib.parse.urlencode({"part": _CHANNELS_PARTS, "id": ",".join(channel_ids)})
        body = self._get_json(f"{_CHANNELS_ENDPOINT}?{query}")  # no key= (OQ-6)
        items = body.get("items")
        if not isinstance(items, list):
            raise CollectionError("channels.list response has no items array")
        return items

    def _get_json(self, url: str) -> dict[str, Any]:
        for attempt in range(1, _MAX_ATTEMPTS + 1):
            request = urllib.request.Request(url, method="GET")
            request.add_header("X-Goog-Api-Key", self._api_key)  # key in header, never URL
            request.add_header("Accept", "application/json")
            try:
                with self._opener(request) as response:
                    return json.loads(response.read().decode("utf-8"))
            except urllib.error.HTTPError as exc:
                if _is_quota_error(exc):
                    raise QuotaExceeded("channels.list quota exceeded") from None
                if exc.code in _TRANSIENT_STATUS and attempt < _MAX_ATTEMPTS:
                    self._sleep(_BACKOFF_SCHEDULE[attempt - 1])
                    continue
                raise CollectionError(f"channels.list HTTP {exc.code}") from None
            except urllib.error.URLError:
                if attempt < _MAX_ATTEMPTS:
                    self._sleep(_BACKOFF_SCHEDULE[attempt - 1])
                    continue
                raise CollectionError("channels.list transport error") from None
        raise CollectionError("channels.list failed after retries")


def _is_quota_error(exc: urllib.error.HTTPError) -> bool:
    if exc.code != 403:
        return False
    try:
        body = json.loads(exc.read().decode("utf-8"))
    except Exception:
        return False
    errors = ((body.get("error") or {}).get("errors")) or []
    return any(isinstance(e, dict) and e.get("reason") in _QUOTA_REASONS for e in errors)


# --- composition root (the only place a driver is touched) -------------------


def _connect(dsn: str) -> ConnectionLike:
    """Open a real PEP-249 connection at the composition root only.

    The driver is imported lazily so this module stays importable/testable
    stdlib-only (design-only/disarmed); the driver is provisioned with the
    Environment at arm time (SG-4), not by landing this file.
    """
    try:
        import psycopg  # type: ignore
    except ModuleNotFoundError as exc:
        raise CollectionError("postgresql driver not provisioned") from exc
    return psycopg.connect(dsn)  # type: ignore[return-value]


def _fail_run(conn: ConnectionLike, run_id: str) -> None:
    try:
        mark_run_failed(conn, run_id)
        conn.commit()
    except Exception:
        # A bookkeeping failure must never mask the fail-closed exit.
        _LOG.error("channel_data: could not mark run failed")


def main(argv: Sequence[str] | None = None) -> int:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s %(message)s")
    parser = argparse.ArgumentParser(
        prog="channel_collection",
        description="Collect channels.list into raw_youtube_channels (INSERT-only, fail-closed).",
    )
    parser.add_argument(
        "--run-id",
        required=True,
        help="UUID of the EXISTING run whose video snapshot is frozen (never creates a run).",
    )
    args = parser.parse_args(argv)

    api_key = os.environ.get("YOUTUBE_API_KEY")
    dsn = os.environ.get("SUPABASE_DB_URL")
    if not api_key:
        _LOG.error("missing YOUTUBE_API_KEY (env-only); aborting with NO collection")
        return 2
    if not dsn:
        _LOG.error("missing SUPABASE_DB_URL; aborting with NO collection")
        return 2

    api = UrllibChannelsApi(api_key)
    conn = _connect(dsn)
    try:
        inserted = collect(args.run_id, api, conn)
        conn.commit()
        _LOG.info("channel_data: run %s complete (%d channels)", args.run_id, inserted)
        return 0
    except CollectionError as exc:
        conn.rollback()
        _fail_run(conn, args.run_id)
        # Log the class name only — even scrubbed messages stay out of the log.
        _LOG.error("channel_data: fail-closed — run marked failed (%s)", type(exc).__name__)
        return 1
    finally:
        try:
            conn.close()  # type: ignore[attr-defined]
        except Exception:
            pass


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
