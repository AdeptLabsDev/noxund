-- ============================================================================
-- NOXUND · Channel Data — §7 post-collection completeness gate (fail-closed)
-- ----------------------------------------------------------------------------
-- Run by the `verify` job of .github/workflows/youtube-collection.yml AFTER a
-- real collection, as the owner `postgres` / DB-password (session pooler; OQ-2):
--
--   psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -v run_id="$RUN_ID" \
--     -f supabase/tests/channel_data_post_collection_verify.sql
--
-- DESIGN-ONLY / DISARMED (SG-5): authored, reviewable, INERT. It never runs until
-- the pipeline is armed (SG-4) and a human dispatches (SG-6). It proves the §7
-- invariant for ONE run_id: the collected channel set equals EXACTLY the channel
-- set surfaced by that run's frozen video snapshot — no omission (DC2-01), no
-- extra, exactly one immutable row per channel, projections faithful to raw_json
-- (NULL != 0), body-only (SEC-F08). Any failure RAISES → ON_ERROR_STOP → nonzero
-- → the run is failed → correction = new run_id. This is NOT a rollback trigger.
--
-- READ-ONLY: pure SELECT assertions; no writes, no probes, side-effect free. The
-- one session-local set_config below is a psql→plpgsql bridge, not a data write
-- (psql does not interpolate :vars inside a DO $$ … $$ body).
-- ============================================================================

\set ON_ERROR_STOP on

-- Bridge the psql var into a session GUC the DO blocks can read (no data write).
select set_config('noxund.run_id', :'run_id', false);

\echo '== Channel Data · §7 completeness gate =='

-- §7.1 — set-equality (the hard invariant), symmetric: every video channel is
--        collected (no omission / DC2-01) AND no channel exists without a video.
do $$
declare
  v_run uuid := current_setting('noxund.run_id')::uuid;
  n_missing int;
  n_extra   int;
begin
  select count(*) into n_missing from (
    select channel_id from public.raw_youtube_videos   where run_id = v_run
    except
    select channel_id from public.raw_youtube_channels where run_id = v_run
  ) s;
  if n_missing <> 0 then
    raise exception 'GATE/set-equality: % video channel(s) missing from raw_youtube_channels (DC2-01) for run %', n_missing, v_run;
  end if;

  select count(*) into n_extra from (
    select channel_id from public.raw_youtube_channels where run_id = v_run
    except
    select channel_id from public.raw_youtube_videos   where run_id = v_run
  ) s;
  if n_extra <> 0 then
    raise exception 'GATE/set-equality: % collected channel(s) with no video in run %', n_extra, v_run;
  end if;
end $$;

-- §7.2 — exactly ONE row per channel (unique index gives <=1; set-equality gives
--        >=1). No NULL channel_id.
do $$
declare
  v_run uuid := current_setting('noxund.run_id')::uuid;
  n_bad int;
begin
  select count(*) into n_bad from (
    select channel_id from public.raw_youtube_channels
     where run_id = v_run group by channel_id having count(*) <> 1
  ) s;
  if n_bad <> 0 then
    raise exception 'GATE/one-row: % channel(s) without exactly one row in run %', n_bad, v_run;
  end if;
  if exists (select 1 from public.raw_youtube_channels where run_id = v_run and channel_id is null) then
    raise exception 'GATE/one-row: null channel_id present in run %', v_run;
  end if;
end $$;

-- §7.3 — raw_json / fetched_at present for every row (verbatim body, no tombstone).
do $$
declare
  v_run uuid := current_setting('noxund.run_id')::uuid;
  n_bad int;
begin
  select count(*) into n_bad from public.raw_youtube_channels
   where run_id = v_run and (raw_json is null or fetched_at is null);
  if n_bad <> 0 then
    raise exception 'GATE/not-null: % row(s) with null raw_json/fetched_at in run %', n_bad, v_run;
  end if;
end $$;

-- §7.4 — raw_json is the verbatim channel body (blocks a fabricated payload).
do $$
declare
  v_run uuid := current_setting('noxund.run_id')::uuid;
  n_bad int;
begin
  select count(*) into n_bad from public.raw_youtube_channels
   where run_id = v_run
     and (raw_json->>'kind' is distinct from 'youtube#channel'
          or raw_json->>'id' is distinct from channel_id);
  if n_bad <> 0 then
    raise exception 'GATE/verbatim: % row(s) whose raw_json is not the channel body (kind/id) in run %', n_bad, v_run;
  end if;
end $$;

-- §7.5 — projection consistency + NULL != 0. `is not distinct from` is the exact
--        mechanism that makes a fabricated 0 (while the stat is absent) RAISE.
do $$
declare
  v_run uuid := current_setting('noxund.run_id')::uuid;
  n_bad int;
begin
  select count(*) into n_bad from public.raw_youtube_channels
   where run_id = v_run and not (
         title            is not distinct from (raw_json->'snippet'->>'title')
     and upload_count     is not distinct from (raw_json->'statistics'->>'videoCount')::bigint
     and subscriber_count is not distinct from (raw_json->'statistics'->>'subscriberCount')::bigint
     and view_count       is not distinct from (raw_json->'statistics'->>'viewCount')::bigint
   );
  if n_bad <> 0 then
    raise exception 'GATE/projection: % row(s) whose columns diverge from raw_json (NULL != 0) in run %', n_bad, v_run;
  end if;
end $$;

-- §7.6 — SEC-F08: no request-context keys in any persisted body (asserts the
--        raw_youtube_channels_no_request_context CHECK held).
do $$
declare
  v_run uuid := current_setting('noxund.run_id')::uuid;
  n_bad int;
begin
  select count(*) into n_bad from public.raw_youtube_channels
   where run_id = v_run
     and raw_json ?| array['config', 'request', 'headers', 'authorization', 'key'];
  if n_bad <> 0 then
    raise exception 'GATE/SEC-F08: % row(s) with request-context keys in raw_json in run %', n_bad, v_run;
  end if;
end $$;

-- §7.7 — the run is not marked failed (finalization condition; not a rollback).
do $$
declare
  v_run uuid := current_setting('noxund.run_id')::uuid;
  v_status text;
begin
  select status::text into v_status from public.report_runs where id = v_run;
  if v_status is null then
    raise exception 'GATE/run: run % not found', v_run;
  end if;
  if v_status = 'failed' then
    raise exception 'GATE/run: run % is marked failed — collection incomplete (correction = new run_id)', v_run;
  end if;
end $$;

\echo 'OK — Channel Data §7 completeness gate PASSED (set-equality, one-row, verbatim, NULL!=0, SEC-F08).'
