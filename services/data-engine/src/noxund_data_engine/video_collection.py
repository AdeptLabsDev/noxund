"""Video Data collector (SG-V4) — ``search.list`` + ``videos.list`` → raw_youtube_*.

DESIGN-ONLY / OFFLINE (DATA-COLLECT-001 · SG-V4). Landing this module performs NO
real API call, NO real secret read, NO dispatch. The gated video-collection
pipeline (SG-V6) does not exist yet; nothing here arms or dispatches anything — it
is authored, reviewable, and inert.

This is Agentes 1 (``search.list``, paginated) + 2 (``videos.list``, batched) of
DATA-COLLECT-001. UNLIKE ``channel_collection`` (002, which REUSES an existing
run_id), this collector CREATES the run_id and its ``report_runs`` row — it is the
sole producer of the run (spec §2; SG-V1 ratification).

Non-negotiables locked before code (spec §§1–8; Security SEC-0023 / Database SG-V3):

  * Locked identity (§1): ``keyword == 'chicago drill type beat'`` (literal),
    ``vertical == 'Chicago Drill'``, ``window_days == 30``,
    ``target_video_count == 500`` (HARD cap). None is a CLI argument — they are
    constants; changing them is a Stop Condition, not a flag.
  * run_id lifecycle (§2): a fresh UUID is generated BEFORE the first external
    call; ``report_runs`` is created ``status='created'`` → ``'collecting'``; the
    run is finalized (``collected_video_count`` written once) only after the
    in-process §7 preflight passes. recoleta = a NEW run_id (never reuse).
  * The API key travels ONLY as the ``X-Goog-Api-Key`` header, NEVER ``?key=`` in
    the URL; it is read from the environment and is never logged (SEC-F06 / OQ-6).
  * BODY-ONLY persistence: ``response_json`` / ``raw_json`` are the verbatim
    response bodies; the transport envelope (``config``/``request``/``headers``/
    ``authorization``/``key``) is rejected before INSERT — defense-in-depth on top
    of the ``*_no_request_context`` CHECK (SEC-F08).
  * Deterministic pagination (§3.2): the first ``page_token`` is NULL; each
    ``nextPageToken`` is followed verbatim; a cycle / repeat / missing-expected
    token fails closed. Selection derives ids in ``(page, item)`` order, dedups by
    first occurrence, and stops at 500 unique ids or a page with no next token.
  * ``source_exhausted`` (§3.2.7) is ONLY a natural end-of-source (a valid page
    with no ``nextPageToken`` before the cap). Any quota / API / network / parse /
    DB error FAILS the run — it is NEVER downgraded to ``source_exhausted``.
  * Append-only: INSERT-only into ``raw_youtube_search_pages`` /
    ``raw_youtube_videos``. The unique indexes are the idempotency backstop; a
    ``unique_violation`` is a fail-closed anomaly (NEVER swallowed with
    ``DO NOTHING`` — a fresh run never collides; §5).
  * Fail-closed: any anomaly marks ``report_runs.status='failed'`` and exits
    nonzero → correction = a new run_id.
  * Log hygiene (§8): logs carry run_id / stage / counts / status / HTTP class
    ONLY — NEVER the key, the DB URL, a body, a title, or a pageToken.
  * Driver-agnostic: no DB driver at module scope; a PEP-249 connection is injected
    (importable/unit-testable with fakes — zero network, zero secret; mirrors
    ``channel_collection`` / ``postgres_entity_resolution``).
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
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Callable, NamedTuple, Protocol, Sequence

_LOG = logging.getLogger("noxund.video_collection")

# YouTube Data API v3 endpoints. The key is a HEADER, never a query param.
_SEARCH_ENDPOINT = "https://www.googleapis.com/youtube/v3/search"
_VIDEOS_ENDPOINT = "https://www.googleapis.com/youtube/v3/videos"

# §1 — LOCKED identity. Constants, not CLI args: changing any is a Stop Condition.
_KEYWORD = "chicago drill type beat"
_VERTICAL = "Chicago Drill"
_WINDOW_DAYS = 30
_TARGET_VIDEO_COUNT = 500  # HARD cap on unique video_ids.

# §3.1 — canonical request shape (omissions are part of v1; no `fields`).
_SEARCH_PART = "snippet"
_SEARCH_TYPE = "video"
_SEARCH_ORDER = "relevance"
_MAX_RESULTS = 50
# §4.1 — videos.list batch shape.
_VIDEOS_PART = "statistics,snippet"
_MAX_IDS_PER_CALL = 50

# Quota accounting (§2.5): search.list = 100 units/call; videos.list = 1 unit/call.
_SEARCH_QUOTA_UNIT = 100
_VIDEOS_QUOTA_UNIT = 1
# Cycle / runaway guard: 500/50 ≈ 10 pages; 100 is a generous, fail-closed ceiling.
_MAX_PAGES = 100

# F-1' / OD-V2 quota floors (Product Lead ratified 2026-07-06). The per-run HARD cap
# fail-closes a runaway pagination / retry storm before it can burn the shared project
# quota (RR-1/RR-8); the nominal run is ~1010 units, so 2000 is ~2x headroom. Retry
# surplus is bounded separately so a transient storm cannot silently double the spend.
_PER_RUN_QUOTA_CAP = 2000
_PER_RUN_RETRY_SURPLUS_CAP = 500

_REQUEST_CONTEXT_KEYS = ("config", "request", "headers", "authorization", "key")
_TRANSIENT_STATUS = frozenset({429, 500, 502, 503, 504})
_QUOTA_REASONS = frozenset({"quotaExceeded", "dailyLimitExceeded"})
_MAX_ATTEMPTS = 3  # <= 2 retries per call (F-1'/OD-V2); quotaExceeded is never retried
_BACKOFF_SCHEDULE = (1.0, 2.0)  # deterministic; len == _MAX_ATTEMPTS - 1


class CollectionError(RuntimeError):
    """Fail-closed collection error.

    Messages are deliberately opaque: they NEVER carry a secret, an API key, a URL
    query string, a response body, a video/channel title, or a pageToken (log
    hygiene §8). Only key names, counts, and HTTP status codes may appear.
    """


class QuotaExceeded(CollectionError):
    """search.list / videos.list signalled quota exhaustion — no retry; run fails."""


class QuotaCapExceeded(CollectionError):
    """Projected per-run quota (nominal + retry surplus) would exceed the F-1' hard
    cap (OD-V2). Fail-closed — a cost guard, NEVER a source_exhausted stop."""


class PaginationError(CollectionError):
    """§3.2 violation: token cycle/repeat, missing-expected token, or page ceiling."""


class VideoValidationError(CollectionError):
    """§4.2 violation: a batch item is missing, duplicated, unrequested, or malformed."""


class CursorLike(Protocol):
    def execute(self, operation: str, parameters: Sequence[Any] = ()) -> Any: ...

    def fetchall(self) -> Sequence[Sequence[Any]]: ...

    def close(self) -> None: ...


class ConnectionLike(Protocol):
    def cursor(self) -> CursorLike: ...

    def commit(self) -> None: ...

    def rollback(self) -> None: ...


class SearchApi(Protocol):
    """Fetches one ``search.list`` page BODY (verbatim), given a page token."""

    def list_search_page(self, page_token: str | None) -> dict[str, Any]: ...


class VideosApi(Protocol):
    """Fetches ``videos.list`` BODY ``items`` for a batch of ids (verbatim)."""

    def list_videos(self, video_ids: Sequence[str]) -> list[dict[str, Any]]: ...


class ProjectedVideo(NamedTuple):
    video_id: str
    channel_id: str
    title: str | None
    published_at: str | None
    views: int | None
    likes: int | None
    comments: int | None
    raw_json: dict[str, Any]


class _Quota:
    """Per-run YouTube quota with a fail-closed hard cap (§2.5 + F-1'/OD-V2).

    ``charge`` PROJECTS the spend BEFORE it happens (the "antes/durante" guard) and
    raises ``QuotaCapExceeded`` if the per-run cap — or the retry-surplus sub-cap —
    would be exceeded. It carries no payload (only counts). A rejected charge never
    mutates the counters (it is fail-closed, not a partial spend).
    """

    def __init__(self, cap: int | None = None, retry_surplus_cap: int | None = None) -> None:
        self.used = 0
        self.retry_surplus = 0
        self._cap = _PER_RUN_QUOTA_CAP if cap is None else cap
        self._retry_surplus_cap = (
            _PER_RUN_RETRY_SURPLUS_CAP if retry_surplus_cap is None else retry_surplus_cap
        )

    def charge(self, units: int, *, retry: bool = False) -> None:
        if retry and self.retry_surplus + units > self._retry_surplus_cap:
            raise QuotaCapExceeded(
                f"per-run retry surplus would exceed cap ({self._retry_surplus_cap})"
            )
        if self.used + units > self._cap:
            raise QuotaCapExceeded(f"per-run quota would exceed cap ({self._cap})")
        self.used += units
        if retry:
            self.retry_surplus += units


# --- pure logic (no I/O; fully unit-testable) --------------------------------


def window_bounds(now: datetime) -> tuple[datetime, datetime]:
    """§1/§2: window_end is captured once; window_start = window_end - 30 days (UTC)."""
    end = now.astimezone(timezone.utc)
    return end - timedelta(days=_WINDOW_DAYS), end


def rfc3339(dt: datetime) -> str:
    """RFC 3339 UTC for publishedAfter/publishedBefore (§3.1)."""
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def reject_request_context(body: dict[str, Any]) -> dict[str, Any]:
    """Body-only guard (SEC-F08).

    A verbatim response body must not carry a transport-envelope key at the top
    level. Raises rather than silently strip, so a leak becomes a failed run —
    mirroring the DB CHECK backstop. Only the offending KEY names are surfaced.
    """
    present = [k for k in _REQUEST_CONTEXT_KEYS if k in body]
    if present:
        raise CollectionError(f"request-context key(s) in body: {','.join(present)}")
    return body


def next_page_token(body: dict[str, Any]) -> str | None:
    """The verbatim ``nextPageToken`` of a search body, or None if absent/last."""
    token = body.get("nextPageToken")
    if token is None:
        return None
    if not isinstance(token, str) or not token:
        raise PaginationError("nextPageToken present but not a non-empty string")
    return token


def select_video_ids(page_bodies: Sequence[dict[str, Any]]) -> list[str]:
    """§3.2: derive the ordered, de-duplicated, capped video_id vector.

    Order is ``(page_ordinal, item_ordinal)`` over the raw bodies; only a non-empty
    ``item.id.videoId`` is accepted; the first occurrence wins; the vector stops at
    the first 500 unique ids (HARD cap).
    """
    seen: dict[str, None] = {}
    for body in page_bodies:
        for item in body.get("items") or []:
            vid = (item.get("id") or {}).get("videoId")
            if isinstance(vid, str) and vid and vid not in seen:
                seen[vid] = None
                if len(seen) >= _TARGET_VIDEO_COUNT:
                    return list(seen)
    return list(seen)


def batched(ids: Sequence[str], size: int = _MAX_IDS_PER_CALL) -> list[list[str]]:
    if size < 1:
        raise ValueError("batch size must be >= 1")
    return [list(ids[i : i + size]) for i in range(0, len(ids), size)]


def _bigint_or_none(stats: dict[str, Any], key: str) -> int | None:
    """statistics.<key> → bigint. ABSENT ⇒ None (NULL != 0). Present '0' ⇒ 0."""
    if key not in stats or stats[key] is None:
        return None
    try:
        return int(str(stats[key]))
    except (TypeError, ValueError):
        raise VideoValidationError(f"non-integer statistics.{key}") from None


def project_video(item: dict[str, Any]) -> ProjectedVideo:
    """Project a verbatim video body into the raw_youtube_videos row shape."""
    reject_request_context(item)
    if item.get("kind") != "youtube#video":
        raise VideoValidationError("video body has unexpected kind")
    video_id = item.get("id")
    if not isinstance(video_id, str) or not video_id:
        raise VideoValidationError("video body missing id")
    snippet = item.get("snippet") or {}
    stats = item.get("statistics") or {}
    channel_id = snippet.get("channelId")
    if not isinstance(channel_id, str) or not channel_id:
        raise VideoValidationError("video snippet missing channelId")
    title = snippet.get("title")
    if title is not None and not isinstance(title, str):
        raise VideoValidationError("video snippet.title is not text")
    published_at = snippet.get("publishedAt")
    if published_at is not None and not isinstance(published_at, str):
        raise VideoValidationError("video snippet.publishedAt is not text")
    return ProjectedVideo(
        video_id=video_id,
        channel_id=channel_id,
        title=title,
        published_at=published_at,
        views=_bigint_or_none(stats, "viewCount"),
        likes=_bigint_or_none(stats, "likeCount"),
        comments=_bigint_or_none(stats, "commentCount"),
        raw_json=item,
    )


def validate_batch(
    requested: Sequence[str], items: Sequence[dict[str, Any]]
) -> list[ProjectedVideo]:
    """§4.2: each requested id appears exactly once; no unrequested/duplicate item.

    A missing id (video removed/private between Search and Video Data), duplicate,
    or unexpected item FAILS the run (never silently dropped — the denominator is
    not reduced). Returns projections in the requested order.
    """
    by_id: dict[str, dict[str, Any]] = {}
    for item in items:
        vid = item.get("id")
        if not isinstance(vid, str) or not vid:
            raise VideoValidationError("videos.list item missing id")
        if vid in by_id:
            raise VideoValidationError("duplicate id in videos.list response")
        by_id[vid] = item
    requested_set = set(requested)
    extra = [v for v in by_id if v not in requested_set]
    if extra:
        raise VideoValidationError(f"{len(extra)} unrequested video(s) in videos.list response")
    missing = [v for v in requested if v not in by_id]
    if missing:
        raise VideoValidationError(f"{len(missing)} requested video(s) omitted by videos.list")
    return [project_video(by_id[v]) for v in requested]


# --- SQL (parameterized; the collector never interpolates values) ------------

_INSERT_RUN_SQL = """
insert into public.report_runs (
  id, keyword, vertical, window_start, window_end, target_video_count, status
)
values (%s, %s, %s, %s, %s, %s, 'created')
""".strip()

_SET_COLLECTING_SQL = """
update public.report_runs set status = 'collecting' where id = %s and status = 'created'
""".strip()

# Append-only. NO `on conflict`: a unique_violation is a fail-closed anomaly (§5),
# not a swallowed no-op — a fresh run_id never collides.
_INSERT_SEARCH_PAGE_SQL = """
insert into public.raw_youtube_search_pages (run_id, page_token, response_json)
values (%s, %s, %s::jsonb)
""".strip()

_INSERT_VIDEO_SQL = """
insert into public.raw_youtube_videos (
  run_id, video_id, channel_id, title, published_at, views, likes, comments, raw_json
)
values (%s, %s, %s, %s, %s, %s, %s, %s, %s::jsonb)
""".strip()

_COLLECTED_VIDEO_IDS_SQL = "select video_id from public.raw_youtube_videos where run_id = %s"

_FINALIZE_RUN_SQL = """
update public.report_runs set collected_video_count = %s, youtube_quota_used = %s where id = %s
""".strip()

_MARK_RUN_FAILED_SQL = """
update public.report_runs set status = 'failed', youtube_quota_used = %s where id = %s
""".strip()


def create_run(
    conn: ConnectionLike, run_id: str, window_start: datetime, window_end: datetime
) -> None:
    cursor = conn.cursor()
    try:
        cursor.execute(
            _INSERT_RUN_SQL,
            (run_id, _KEYWORD, _VERTICAL, window_start, window_end, _TARGET_VIDEO_COUNT),
        )
    finally:
        cursor.close()


def set_collecting(conn: ConnectionLike, run_id: str) -> None:
    cursor = conn.cursor()
    try:
        cursor.execute(_SET_COLLECTING_SQL, (run_id,))
    finally:
        cursor.close()


def insert_search_page(
    conn: ConnectionLike, run_id: str, page_token: str | None, body: dict[str, Any]
) -> None:
    reject_request_context(body)
    cursor = conn.cursor()
    try:
        cursor.execute(
            _INSERT_SEARCH_PAGE_SQL,
            (run_id, page_token, json.dumps(body, ensure_ascii=False, separators=(",", ":"))),
        )
    finally:
        cursor.close()


def insert_video(conn: ConnectionLike, run_id: str, video: ProjectedVideo) -> None:
    cursor = conn.cursor()
    try:
        cursor.execute(
            _INSERT_VIDEO_SQL,
            (
                run_id,
                video.video_id,
                video.channel_id,
                video.title,
                video.published_at,
                video.views,
                video.likes,
                video.comments,
                json.dumps(video.raw_json, ensure_ascii=False, separators=(",", ":")),
            ),
        )
    finally:
        cursor.close()


def fetch_collected_video_ids(conn: ConnectionLike, run_id: str) -> list[str]:
    cursor = conn.cursor()
    try:
        cursor.execute(_COLLECTED_VIDEO_IDS_SQL, (run_id,))
        return [str(row[0]) for row in cursor.fetchall() if row and row[0] is not None]
    finally:
        cursor.close()


def finalize_run(conn: ConnectionLike, run_id: str, collected: int, quota_used: int) -> None:
    cursor = conn.cursor()
    try:
        cursor.execute(_FINALIZE_RUN_SQL, (collected, quota_used, run_id))
    finally:
        cursor.close()


def mark_run_failed(conn: ConnectionLike, run_id: str, quota_used: int) -> None:
    cursor = conn.cursor()
    try:
        cursor.execute(_MARK_RUN_FAILED_SQL, (quota_used, run_id))
    finally:
        cursor.close()


def assert_video_completeness(conn: ConnectionLike, run_id: str, ids: Sequence[str]) -> None:
    """In-process §7 preflight before finalization.

    The persisted ``(run_id, video_id)`` set must equal EXACTLY the selected id
    vector (no omission, no extra) and never exceed the hard cap. The §7 verify SQL
    re-proves this (and the token chain / verbatim / NULL!=0) post-hoc; the
    collector does not trust its own process state alone.
    """
    collected = set(fetch_collected_video_ids(conn, run_id))
    want = set(ids)
    if collected != want:
        raise CollectionError(
            f"video set mismatch at finalize (missing={len(want - collected)}, "
            f"extra={len(collected - want)})"
        )
    if len(want) > _TARGET_VIDEO_COUNT:
        raise CollectionError("collected video count exceeds hard cap")


# --- orchestration (I/O injected; unit-testable with fakes) ------------------


def _run_search(
    api: SearchApi, conn: ConnectionLike, run_id: str, quota: _Quota
) -> tuple[list[dict[str, Any]], str]:
    """Agente 1: paginate search.list, persisting each body; return (bodies, stop)."""
    pages: list[dict[str, Any]] = []
    requested: set[str] = set()
    token: str | None = None
    while True:
        key = token or ""
        if key in requested:
            raise PaginationError("pageToken cycle/repeat detected")
        requested.add(key)
        quota.charge(_SEARCH_QUOTA_UNIT)  # project the page cost BEFORE the call (cap guard)
        body = api.list_search_page(token)
        insert_search_page(conn, run_id, token, body)
        pages.append(body)
        if len(select_video_ids(pages)) >= _TARGET_VIDEO_COUNT:
            _LOG.info("search: stop=target_reached pages=%d", len(pages))
            return pages, "target_reached"
        nxt = next_page_token(body)
        if not nxt:
            _LOG.info("search: stop=source_exhausted pages=%d", len(pages))
            return pages, "source_exhausted"
        token = nxt
        if len(pages) >= _MAX_PAGES:
            raise PaginationError("page ceiling exceeded without a stop condition")


def _run_videos(
    api: VideosApi, conn: ConnectionLike, run_id: str, ids: Sequence[str], quota: _Quota
) -> None:
    """Agente 2: fetch videos.list in <= 50-id batches; validate; INSERT-only."""
    for batch in batched(ids):
        quota.charge(_VIDEOS_QUOTA_UNIT)  # project the batch cost BEFORE the call (cap guard)
        items = api.list_videos(batch)
        for video in validate_batch(batch, items):
            insert_video(conn, run_id, video)
        _LOG.info("videos: batch persisted (%d ids)", len(batch))


def collect_new_run(
    run_id: str,
    window_start: datetime,
    window_end: datetime,
    search_api: SearchApi,
    videos_api: VideosApi,
    conn: ConnectionLike,
    quota: _Quota | None = None,
) -> tuple[int, str]:
    """Create a NEW run and collect its video snapshot; return (count, stop_reason).

    Creates ``report_runs`` (created → collecting), runs Agente 1 (search) then
    Agente 2 (videos), proves in-process §7 completeness, and finalizes
    ``collected_video_count`` in a single write. Raises ``CollectionError``
    (fail-closed) on any anomaly — including ``QuotaCapExceeded`` (F-1' cap), which
    is a fail-closed cost guard, NEVER a source_exhausted stop; the caller owns
    commit/rollback and marks failed. Pass ``quota`` shared with the API clients so
    nominal + retry-surplus aggregate against one per-run cap (main wires them).
    """
    quota = quota if quota is not None else _Quota()
    create_run(conn, run_id, window_start, window_end)
    set_collecting(conn, run_id)
    pages, stop = _run_search(search_api, conn, run_id, quota)
    ids = select_video_ids(pages)
    _run_videos(videos_api, conn, run_id, ids, quota)
    assert_video_completeness(conn, run_id, ids)
    finalize_run(conn, run_id, len(ids), quota.used)
    _LOG.info("video_data: run finalized count=%d stop=%s quota=%d", len(ids), stop, quota.used)
    return len(ids), stop


# --- real clients (stdlib urllib; header auth; body-only) --------------------


def _http_get_json(
    url: str,
    unit_cost: int,
    api_key: str,
    quota: _Quota,
    sleep: Callable[[float], None],
    opener: Callable[[urllib.request.Request], Any],
) -> dict[str, Any]:
    """GET a JSON body with header auth + deterministic retry (<= 2). Key never in URL.

    The nominal cost of the call is charged by the orchestration BEFORE the call; each
    RETRY here charges the endpoint cost again as retry surplus (bounded by the F-1'
    sub-cap and projected fail-closed), because a retried request re-consumes quota.
    """
    for attempt in range(1, _MAX_ATTEMPTS + 1):
        if attempt > 1:
            quota.charge(unit_cost, retry=True)  # retry re-spends quota (projected/fail-closed)
        request = urllib.request.Request(url, method="GET")
        request.add_header("X-Goog-Api-Key", api_key)  # key in header, never ?key=
        request.add_header("Accept", "application/json")
        try:
            with opener(request) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            if _is_quota_error(exc):
                raise QuotaExceeded("youtube quota exceeded") from None
            if exc.code in _TRANSIENT_STATUS and attempt < _MAX_ATTEMPTS:
                sleep(_BACKOFF_SCHEDULE[attempt - 1])
                continue
            raise CollectionError(f"youtube HTTP {exc.code}") from None
        except urllib.error.URLError:
            if attempt < _MAX_ATTEMPTS:
                sleep(_BACKOFF_SCHEDULE[attempt - 1])
                continue
            raise CollectionError("youtube transport error") from None
    raise CollectionError("youtube request failed after retries")


class UrllibSearchApi:
    """``search.list`` over stdlib urllib. Key is header-only; body is returned verbatim."""

    def __init__(
        self,
        api_key: str,
        *,
        published_after: str,
        published_before: str,
        quota: _Quota | None = None,
        sleep: Callable[[float], None] = time.sleep,
        opener: Callable[[urllib.request.Request], Any] = urllib.request.urlopen,
    ) -> None:
        if not api_key:
            raise CollectionError("missing YOUTUBE_API_KEY")
        self._api_key = api_key
        self._after = published_after
        self._before = published_before
        self._quota = quota if quota is not None else _Quota()
        self._sleep = sleep
        self._opener = opener

    def list_search_page(self, page_token: str | None) -> dict[str, Any]:
        params = {
            "part": _SEARCH_PART,
            "q": _KEYWORD,
            "type": _SEARCH_TYPE,
            "order": _SEARCH_ORDER,
            "maxResults": _MAX_RESULTS,
            "publishedAfter": self._after,
            "publishedBefore": self._before,
        }
        if page_token:
            params["pageToken"] = page_token
        query = urllib.parse.urlencode(params)
        return _http_get_json(
            f"{_SEARCH_ENDPOINT}?{query}", _SEARCH_QUOTA_UNIT, self._api_key,
            self._quota, self._sleep, self._opener,
        )


class UrllibVideosApi:
    """``videos.list`` over stdlib urllib. Key is header-only; body items verbatim."""

    def __init__(
        self,
        api_key: str,
        *,
        quota: _Quota | None = None,
        sleep: Callable[[float], None] = time.sleep,
        opener: Callable[[urllib.request.Request], Any] = urllib.request.urlopen,
    ) -> None:
        if not api_key:
            raise CollectionError("missing YOUTUBE_API_KEY")
        self._api_key = api_key
        self._quota = quota if quota is not None else _Quota()
        self._sleep = sleep
        self._opener = opener

    def list_videos(self, video_ids: Sequence[str]) -> list[dict[str, Any]]:
        if len(video_ids) > _MAX_IDS_PER_CALL:
            raise CollectionError("batch exceeds videos.list id limit")
        query = urllib.parse.urlencode({"part": _VIDEOS_PART, "id": ",".join(video_ids)})
        body = _http_get_json(
            f"{_VIDEOS_ENDPOINT}?{query}", _VIDEOS_QUOTA_UNIT, self._api_key,
            self._quota, self._sleep, self._opener,
        )
        items = body.get("items")
        if not isinstance(items, list):
            raise CollectionError("videos.list response has no items array")
        return items


def _is_quota_error(exc: urllib.error.HTTPError) -> bool:
    if exc.code != 403:
        return False
    try:
        body = json.loads(exc.read().decode("utf-8"))
    except Exception:
        return False
    errors = ((body.get("error") or {}).get("errors")) or []
    return any(isinstance(e, dict) and e.get("reason") in _QUOTA_REASONS for e in errors)


# --- composition root (the only place a driver / clock / uuid is touched) ----


def _connect(dsn: str) -> ConnectionLike:
    """Open a real PEP-249 connection at the composition root only.

    The driver is imported lazily so this module stays importable/testable
    stdlib-only (design-only/offline); it is provisioned with the Environment at
    arm time (SG-V6), not by landing this file.
    """
    try:
        import psycopg  # type: ignore
    except ModuleNotFoundError as exc:
        raise CollectionError("postgresql driver not provisioned") from exc
    return psycopg.connect(dsn)  # type: ignore[return-value]


def _new_run_id() -> str:
    """A fresh run_id per invocation (§2.1: recoleta = new run_id, never reuse)."""
    return str(uuid.uuid4())


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _emit_run_id_output(run_id: str) -> None:
    """Emit the CREATED run_id to ``$GITHUB_OUTPUT`` for the gated verify job (SG-V6).

    GitHub Actions surfaces a step's outputs to downstream jobs when the step appends
    ``name=value`` lines to the file named by ``$GITHUB_OUTPUT``. video-collection.yml
    exposes ``steps.collect.outputs.run_id`` and its verify job fails closed unless
    that value is a well-formed UUID. This writes EXACTLY one line — ``run_id=<uuid>``
    followed by a newline — and nothing else: never the key, the DB URL, a body, a
    title, or a pageToken (log hygiene §8 governs this sink too). The run_id is
    non-secret (it lives in ``report_runs``); surfacing it leaks nothing sensitive.

    When ``GITHUB_OUTPUT`` is UNSET (a local/offline run) this is a silent no-op, so
    the collector still runs with no error and no file side effect. When it IS set a
    write failure is allowed to propagate: ``main()`` emits BEFORE ``conn.commit()``,
    so an emit that cannot surface the run_id fail-closes the whole run atomically
    (rationale documented at the call site).
    """
    output_path = os.environ.get("GITHUB_OUTPUT")
    if not output_path:
        return
    with open(output_path, "a", encoding="utf-8") as handle:
        handle.write(f"run_id={run_id}\n")


def _fail_run(conn: ConnectionLike, run_id: str, quota_used: int) -> None:
    try:
        mark_run_failed(conn, run_id, quota_used)
        conn.commit()
    except Exception:
        # A bookkeeping failure must never mask the fail-closed exit.
        _LOG.error("video_data: could not mark run failed")


def main(argv: Sequence[str] | None = None) -> int:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s %(message)s")
    argparse.ArgumentParser(
        prog="video_collection",
        description="Collect search.list + videos.list into raw_youtube_* (creates the "
        "run_id; INSERT-only; fail-closed). Identity is locked (§1) — no collection flags.",
    ).parse_args(argv)

    api_key = os.environ.get("YOUTUBE_API_KEY")
    dsn = os.environ.get("SUPABASE_DB_URL")
    if not api_key:
        _LOG.error("missing YOUTUBE_API_KEY (env-only); aborting with NO collection")
        return 2
    if not dsn:
        _LOG.error("missing SUPABASE_DB_URL; aborting with NO collection")
        return 2

    run_id = _new_run_id()
    window_start, window_end = window_bounds(_utc_now())
    quota = _Quota()  # one per-run cap shared by both clients + orchestration (F-1'/OD-V2)
    search_api = UrllibSearchApi(
        api_key, published_after=rfc3339(window_start), published_before=rfc3339(window_end),
        quota=quota,
    )
    videos_api = UrllibVideosApi(api_key, quota=quota)
    conn = _connect(dsn)
    _LOG.info("video_data: run %s created (collecting)", run_id)
    try:
        count, stop = collect_new_run(
            run_id, window_start, window_end, search_api, videos_api, conn, quota
        )
        # Surface the CREATED run_id to $GITHUB_OUTPUT (SG-V6 / F2'-N1) BEFORE the
        # durable commit, so the emit is part of ONE atomic success criterion: the
        # run is committed ONLY once its run_id has been surfaced for the verify job.
        # If the emit cannot write, control falls to the fail-closed handlers below —
        # the run is rolled back + marked failed and main() exits nonzero, so the
        # collect job fails and the verify job never runs (correction = a new run_id).
        # This ordering means a completed run can never be left committed-but-
        # unemittable, and an emit hiccup can never mark an already-committed run as
        # failed. A local/offline run (GITHUB_OUTPUT unset) is a silent no-op. run_id
        # (non-secret; in report_runs) is the ONLY value written — no key/DB URL/body.
        _emit_run_id_output(run_id)
        conn.commit()
        _LOG.info("video_data: run %s complete (%d videos, stop=%s)", run_id, count, stop)
        return 0
    except CollectionError as exc:
        conn.rollback()
        _fail_run(conn, run_id, quota.used)
        # Log the class name only — even scrubbed messages stay out of the log.
        _LOG.error("video_data: fail-closed — run marked failed (%s)", type(exc).__name__)
        return 1
    except Exception as exc:  # any driver/parse error is ALSO fail-closed (§6)
        conn.rollback()
        _fail_run(conn, run_id, quota.used)
        _LOG.error("video_data: fail-closed — unexpected error (%s)", type(exc).__name__)
        return 1
    finally:
        try:
            conn.close()  # type: ignore[attr-defined]
        except Exception:
            pass


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
