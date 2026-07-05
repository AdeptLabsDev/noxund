-- ============================================================================
-- NOXUND · Video Data — §7 post-collection completeness gate (fail-closed)
-- ----------------------------------------------------------------------------
-- DATA-COLLECT-001 §7. Run by the `verify` job of the (future, SG-V6) gated
-- video-collection pipeline AFTER a real collection, as the owner `postgres` /
-- DB-password (session pooler; OQ-2):
--
--   psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -v run_id="$RUN_ID" \
--     -f supabase/tests/video_data_post_collection_verify.sql
--
-- DESIGN-ONLY / OFFLINE (SG-V5): authored, reviewable, INERT. It never runs until
-- the video pipeline exists (SG-V6) and a human dispatches (SG-V7). It certifies
-- the §7 invariant for ONE run_id — the frozen snapshot that DATA-COLLECT-002
-- (youtube-collection) later REUSES. Any failure RAISES → ON_ERROR_STOP → nonzero
-- → the run is failed → correction = new run_id. This is NOT a rollback trigger.
--
-- What it proves (spec §7):
--   • run identity == the 4 locked params + window is exactly 30 days;
--   • the search page chain starts at page_token NULL, follows each nextPageToken
--     verbatim, reaches every page, and contains no cycle;
--   • the stop is explained (target_reached at the 500 cap, or source_exhausted),
--     never by error;
--   • set(raw_youtube_videos.video_id) is EXACTLY the id vector reconstructed from
--     the raw search bodies (no omission, no extra), capped at 500;
--   • one immutable row per video; projections faithful to raw_json (NULL != 0);
--   • response_json / raw_json / fetched_at not null, body-only (SEC-F08);
--   • collected_video_count is written and the run is not failed.
--
-- READ-ONLY: pure SELECT assertions; no writes, side-effect free. The one
-- session-local set_config below is a psql→plpgsql bridge, not a data write.
-- ============================================================================

\set ON_ERROR_STOP on

select set_config('noxund.run_id', :'run_id', false);

\echo '== Video Data · §7 completeness gate =='

-- §7.1 — run identity == the 4 locked params and the window is EXACTLY 30 days.
do $$
declare
  v_run uuid := current_setting('noxund.run_id')::uuid;
  r public.report_runs%rowtype;
begin
  select * into r from public.report_runs where id = v_run;
  if not found then
    raise exception 'GATE/identity: run % not found', v_run;
  end if;
  if r.keyword is distinct from 'chicago drill type beat' then
    raise exception 'GATE/identity: keyword is not the locked literal for run %', v_run;
  end if;
  if r.vertical is distinct from 'Chicago Drill' then
    raise exception 'GATE/identity: vertical is not ''Chicago Drill'' for run %', v_run;
  end if;
  if (r.window_end - r.window_start) is distinct from interval '30 days' then
    raise exception 'GATE/identity: window is not exactly 30 days for run %', v_run;
  end if;
end $$;

-- §7.2 — the search page chain: exactly one NULL-token first page, a linear walk
--        that reaches every page (no orphan), and no cycle (a runaway loop would
--        inflate the walk past the page count → mismatch → RAISE).
do $$
declare
  v_run uuid := current_setting('noxund.run_id')::uuid;
  n_first int;
  n_pages int;
  n_walk  int;
begin
  select count(*) into n_first
    from public.raw_youtube_search_pages where run_id = v_run and page_token is null;
  if n_first <> 1 then
    raise exception 'GATE/chain: expected exactly one first (null-token) page, found % in run %', n_first, v_run;
  end if;

  select count(*) into n_pages
    from public.raw_youtube_search_pages where run_id = v_run;

  with recursive walk as (
    select p.page_token,
           (p.response_json->>'nextPageToken') as next_tok,
           1 as depth
      from public.raw_youtube_search_pages p
     where p.run_id = v_run and p.page_token is null
    union all
    select p.page_token,
           (p.response_json->>'nextPageToken'),
           w.depth + 1
      from walk w
      join public.raw_youtube_search_pages p
        on p.run_id = v_run and p.page_token = w.next_tok
     where w.next_tok is not null and w.depth < 1000
  )
  select count(*) into n_walk from walk;

  if n_walk <> n_pages then
    raise exception 'GATE/chain: token walk visited % of % page(s) (orphan/cycle) in run %', n_walk, n_pages, v_run;
  end if;
end $$;

-- §7.3 — the stop is explained, never by error: either the source was exhausted
--        (no dangling nextPageToken) OR the 500 cap was reached (target_reached).
do $$
declare
  v_run uuid := current_setting('noxund.run_id')::uuid;
  n_dangling int;
  v_collected int;
begin
  select count(*) into n_dangling
    from public.raw_youtube_search_pages p
   where p.run_id = v_run
     and (p.response_json->>'nextPageToken') is not null
     and not exists (
       select 1 from public.raw_youtube_search_pages q
        where q.run_id = v_run and q.page_token = p.response_json->>'nextPageToken'
     );
  select collected_video_count into v_collected from public.report_runs where id = v_run;
  if n_dangling <> 0 and v_collected is distinct from 500 then
    raise exception 'GATE/stop: unfollowed nextPageToken with collected % <> 500 (stop not explained) in run %', v_collected, v_run;
  end if;
end $$;

-- §7.4 — set-equality: the collected video set equals EXACTLY the id vector
--        reconstructed from the raw search bodies (no extra ⊄ candidates; when the
--        source is not truncated, no omission), capped at 500.
do $$
declare
  v_run uuid := current_setting('noxund.run_id')::uuid;
  n_candidates int;
  n_collected  int;
  n_extra      int;
  n_missing    int;
begin
  create temp table _cand on commit drop as
    select distinct (item->'id'->>'videoId') as video_id
      from public.raw_youtube_search_pages p
      cross join lateral jsonb_array_elements(coalesce(p.response_json->'items', '[]'::jsonb)) item
     where p.run_id = v_run
       and (item->'id'->>'videoId') is not null
       and (item->'id'->>'videoId') <> '';

  select count(*) into n_candidates from _cand;
  select count(distinct video_id) into n_collected
    from public.raw_youtube_videos where run_id = v_run;

  -- no extra: every collected video was surfaced by search.
  select count(*) into n_extra from (
    select video_id from public.raw_youtube_videos where run_id = v_run
    except
    select video_id from _cand
  ) s;
  if n_extra <> 0 then
    raise exception 'GATE/set-equality: % collected video(s) not present in the search candidates in run %', n_extra, v_run;
  end if;

  if n_candidates <= 500 then
    -- source not truncated ⇒ every candidate must be collected (source_exhausted).
    select count(*) into n_missing from (
      select video_id from _cand
      except
      select video_id from public.raw_youtube_videos where run_id = v_run
    ) s;
    if n_missing <> 0 then
      raise exception 'GATE/set-equality: % candidate video(s) missing from raw_youtube_videos in run %', n_missing, v_run;
    end if;
  else
    -- source truncated ⇒ exactly the 500-cap was collected (target_reached).
    if n_collected <> 500 then
      raise exception 'GATE/set-equality: % candidates but % collected (cap must be 500) in run %', n_candidates, n_collected, v_run;
    end if;
  end if;
end $$;

-- §7.5 — exactly ONE row per video (unique index gives <=1; set-equality gives
--        >=1). No NULL video_id / channel_id.
do $$
declare
  v_run uuid := current_setting('noxund.run_id')::uuid;
  n_bad int;
begin
  select count(*) into n_bad from (
    select video_id from public.raw_youtube_videos
     where run_id = v_run group by video_id having count(*) <> 1
  ) s;
  if n_bad <> 0 then
    raise exception 'GATE/one-row: % video(s) without exactly one row in run %', n_bad, v_run;
  end if;
  if exists (select 1 from public.raw_youtube_videos
              where run_id = v_run and (video_id is null or channel_id is null)) then
    raise exception 'GATE/one-row: null video_id/channel_id present in run %', v_run;
  end if;
end $$;

-- §7.6 — raw_json / fetched_at present for every row (verbatim body, no tombstone),
--        on BOTH raw tables.
do $$
declare
  v_run uuid := current_setting('noxund.run_id')::uuid;
  n_bad int;
begin
  select count(*) into n_bad from public.raw_youtube_videos
   where run_id = v_run and (raw_json is null or fetched_at is null);
  if n_bad <> 0 then
    raise exception 'GATE/not-null: % video row(s) with null raw_json/fetched_at in run %', n_bad, v_run;
  end if;
  select count(*) into n_bad from public.raw_youtube_search_pages
   where run_id = v_run and (response_json is null or fetched_at is null);
  if n_bad <> 0 then
    raise exception 'GATE/not-null: % search page(s) with null response_json/fetched_at in run %', n_bad, v_run;
  end if;
end $$;

-- §7.7 — raw_json is the verbatim video body (blocks a fabricated payload).
do $$
declare
  v_run uuid := current_setting('noxund.run_id')::uuid;
  n_bad int;
begin
  select count(*) into n_bad from public.raw_youtube_videos
   where run_id = v_run
     and (raw_json->>'kind' is distinct from 'youtube#video'
          or raw_json->>'id' is distinct from video_id);
  if n_bad <> 0 then
    raise exception 'GATE/verbatim: % row(s) whose raw_json is not the video body (kind/id) in run %', n_bad, v_run;
  end if;
end $$;

-- §7.8 — projection consistency + NULL != 0. `is not distinct from` is the exact
--        mechanism that makes a fabricated 0 (while the stat is absent) RAISE.
do $$
declare
  v_run uuid := current_setting('noxund.run_id')::uuid;
  n_bad int;
begin
  select count(*) into n_bad from public.raw_youtube_videos
   where run_id = v_run and not (
         channel_id is not distinct from (raw_json->'snippet'->>'channelId')
     and title      is not distinct from (raw_json->'snippet'->>'title')
     and views      is not distinct from (raw_json->'statistics'->>'viewCount')::bigint
     and likes      is not distinct from (raw_json->'statistics'->>'likeCount')::bigint
     and comments   is not distinct from (raw_json->'statistics'->>'commentCount')::bigint
   );
  if n_bad <> 0 then
    raise exception 'GATE/projection: % row(s) whose columns diverge from raw_json (NULL != 0) in run %', n_bad, v_run;
  end if;
end $$;

-- §7.9 — SEC-F08: no request-context keys in any persisted body (asserts the
--        *_no_request_context CHECKs held), on BOTH raw tables.
do $$
declare
  v_run uuid := current_setting('noxund.run_id')::uuid;
  n_bad int;
begin
  select count(*) into n_bad from public.raw_youtube_videos
   where run_id = v_run and raw_json ?| array['config','request','headers','authorization','key'];
  if n_bad <> 0 then
    raise exception 'GATE/SEC-F08: % video row(s) with request-context keys in raw_json in run %', n_bad, v_run;
  end if;
  select count(*) into n_bad from public.raw_youtube_search_pages
   where run_id = v_run and response_json ?| array['config','request','headers','authorization','key'];
  if n_bad <> 0 then
    raise exception 'GATE/SEC-F08: % search page(s) with request-context keys in response_json in run %', n_bad, v_run;
  end if;
end $$;

-- §7.10 — finalization: collected_video_count is written, equals the distinct
--         video count, is <= 500, and the run is not failed.
do $$
declare
  v_run uuid := current_setting('noxund.run_id')::uuid;
  v_status text;
  v_collected int;
  n_distinct int;
begin
  select status::text, collected_video_count into v_status, v_collected
    from public.report_runs where id = v_run;
  if v_status = 'failed' then
    raise exception 'GATE/run: run % is marked failed — collection incomplete (correction = new run_id)', v_run;
  end if;
  if v_collected is null then
    raise exception 'GATE/run: run % has null collected_video_count (never finalized)', v_run;
  end if;
  if v_collected > 500 then
    raise exception 'GATE/run: run % collected_video_count % exceeds the 500 cap', v_run, v_collected;
  end if;
  select count(distinct video_id) into n_distinct
    from public.raw_youtube_videos where run_id = v_run;
  if v_collected <> n_distinct then
    raise exception 'GATE/run: collected_video_count % <> distinct video rows % in run %', v_collected, n_distinct, v_run;
  end if;
end $$;

\echo 'OK — Video Data §7 completeness gate PASSED (identity/30d, chain, stop, set-equality, one-row, verbatim, NULL!=0, SEC-F08, finalized).'
