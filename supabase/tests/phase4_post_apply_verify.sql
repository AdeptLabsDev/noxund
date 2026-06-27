-- ============================================================================
-- NOXUND · Phase 4 — post-apply verification (Raw YouTube Snapshots)
-- ----------------------------------------------------------------------------
-- Run by CI immediately after `supabase db push` applies
--   supabase/migrations/20260620000004_phase4_raw_youtube_snapshots.sql
-- Parity with supabase/tests/phase1_/phase2_/phase3_post_apply_verify.sql.
--
-- WHY EMPIRICAL: raw is SACRED and `service_role` bypasses RLS (SEC-F01), so the
-- "insert-only / never mutated" guarantee can only be proven by the TRIGGERS firing.
-- We assert BOTH role paths (lesson DEC-0009 / SEC-F21 + SEC-F22):
--   • as postgres (grant-holder): only the TRIGGER can block -> restrict_violation (positive
--     freeze proof — proves immutability is enforced, not merely a missing grant);
--   • as service_role: blocked by trigger OR grant -> either errcode (no false-negative).
-- We ALSO prove SEC-F08 empirically: a clean response body is ACCEPTED (raw verbatim),
-- while a request-context envelope (config/key/Authorization) is REJECTED by the CHECK.
--
-- CONTRACT: every check RAISES on mismatch, so `psql -v ON_ERROR_STOP=1` exits
-- non-zero and fails the CI job. There is no silent pass.
-- SIDE EFFECTS: none persisted — all probe writes live in rolled-back transactions.
-- Role: connects as project `postgres` (member of anon/authenticated/service_role).
-- ============================================================================

\set ON_ERROR_STOP on

\echo '== Phase 4 · §4 structural verification =='

-- 3 raw tables ----------------------------------------------------------------
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values ('raw_youtube_search_pages'), ('raw_youtube_videos'), ('raw_youtube_channels')) as t(want)
   where not exists (
     select 1 from information_schema.tables
      where table_schema = 'public' and table_name = t.want
   );
  if missing is not null then
    raise exception 'STRUCT/tables: missing Phase 4 table(s): %', missing;
  end if;
end $$;

-- 2 immutability guard functions with pinned search_path ----------------------
do $$
declare want text; cfg text[];
begin
  foreach want in array array['raw_youtube_immutable', 'raw_youtube_no_truncate'] loop
    select proconfig into cfg
      from pg_proc
     where proname = want and pronamespace = 'public'::regnamespace;
    if not found then
      raise exception 'STRUCT/function: public.%() not found', want;
    end if;
    if cfg is null or not exists (select 1 from unnest(cfg) c where c like 'search_path=%') then
      raise exception 'STRUCT/function: expected pinned search_path on %(), got %', want, cfg;
    end if;
  end loop;
end $$;

-- 6 immutability triggers (2 per raw table) -----------------------------------
do $$
declare t text; want text; missing text := '';
begin
  foreach t in array array['raw_youtube_search_pages', 'raw_youtube_videos', 'raw_youtube_channels'] loop
    foreach want in array array[t || '_immutable', t || '_no_truncate'] loop
      if not exists (
        select 1 from pg_trigger
         where tgrelid = ('public.' || t)::regclass
           and not tgisinternal
           and tgname = want
      ) then
        missing := missing || want || ' ';
      end if;
    end loop;
  end loop;
  if length(missing) > 0 then
    raise exception 'STRUCT/triggers: missing raw immutability trigger(s): %', missing;
  end if;
end $$;

-- logical-uniqueness indexes --------------------------------------------------
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values
      ('raw_youtube_search_pages_run_page_uidx'),
      ('raw_youtube_videos_run_video_uidx'),
      ('raw_youtube_channels_run_channel_uidx')
    ) as t(want)
   where not exists (
     select 1 from pg_indexes where schemaname = 'public' and indexname = t.want
   );
  if missing is not null then
    raise exception 'STRUCT/indexes: missing logical-uniqueness index(es): %', missing;
  end if;
end $$;

-- FK from each raw table to report_runs (raw anchored to Phase 3 provenance) ---
do $$
declare t text; missing text := '';
begin
  foreach t in array array['raw_youtube_search_pages', 'raw_youtube_videos', 'raw_youtube_channels'] loop
    if not exists (
      select 1 from pg_constraint
       where conrelid = ('public.' || t)::regclass
         and contype = 'f'
         and confrelid = 'public.report_runs'::regclass
    ) then
      missing := missing || t || ' ';
    end if;
  end loop;
  if length(missing) > 0 then
    raise exception 'STRUCT/fk: raw table(s) missing FK to report_runs: %', missing;
  end if;
end $$;

-- SEC-F08 scrub CHECK present on each raw payload -----------------------------
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values
      ('raw_youtube_search_pages_no_request_context'),
      ('raw_youtube_videos_no_request_context'),
      ('raw_youtube_channels_no_request_context')
    ) as t(want)
   where not exists (
     select 1 from pg_constraint where contype = 'c' and conname = t.want
   );
  if missing is not null then
    raise exception 'STRUCT/check: missing SEC-F08 scrub check(s): %', missing;
  end if;
end $$;

-- RLS enabled (default-deny) on all 3 -----------------------------------------
do $$
declare bad text;
begin
  select string_agg(relname, ', ') into bad
    from pg_class
   where relnamespace = 'public'::regnamespace
     and relname in ('raw_youtube_search_pages', 'raw_youtube_videos', 'raw_youtube_channels')
     and relrowsecurity = false;
  if bad is not null then
    raise exception 'STRUCT/rls: RLS not enabled on: %', bad;
  end if;
end $$;

\echo '== Phase 4 · §5 empirical verification =='

-- Raw immutability — the sacred guarantee. Seed a run + one row per raw table,
-- then prove UPDATE/DELETE/TRUNCATE are blocked on BOTH role paths.
begin;
  do $$
  declare v_run uuid; t text;
  begin
    insert into public.report_runs (window_start, window_end)
      values (now() - interval '30 days', now()) returning id into v_run;

    insert into public.raw_youtube_search_pages (run_id, page_token, response_json)
      values (v_run, null, '{"kind":"youtube#searchListResponse","items":[]}');
    insert into public.raw_youtube_videos (run_id, video_id, channel_id, raw_json)
      values (v_run, 'vid_1', 'chan_1', '{"kind":"youtube#video"}');
    insert into public.raw_youtube_channels (run_id, channel_id, raw_json)
      values (v_run, 'chan_1', '{"kind":"youtube#channel"}');

    -- A) grant-holder (postgres) path: only the TRIGGER can block -> restrict_violation (SEC-F22).
    --    Proves the freeze is the trigger, not an absent grant.
    foreach t in array array['raw_youtube_search_pages', 'raw_youtube_videos', 'raw_youtube_channels'] loop
      begin
        execute format('update public.%I set fetched_at = now()', t);
        raise exception 'EMPIRICAL/raw-immutable: UPDATE % as grant-holder SUCCEEDED (raw mutability regression)', t;
      exception when restrict_violation then null; end;

      begin
        execute format('delete from public.%I', t);
        raise exception 'EMPIRICAL/raw-immutable: DELETE % as grant-holder SUCCEEDED (raw mutability regression)', t;
      exception when restrict_violation then null; end;

      begin
        execute format('truncate public.%I', t);
        raise exception 'EMPIRICAL/raw-immutable: TRUNCATE % as grant-holder SUCCEEDED (raw mutability regression)', t;
      exception when restrict_violation then null; end;
    end loop;

    -- B) service_role path (bypasses RLS): blocked by trigger OR grant -> either errcode (SEC-F21).
    perform set_config('role', 'service_role', true);
    foreach t in array array['raw_youtube_search_pages', 'raw_youtube_videos', 'raw_youtube_channels'] loop
      begin
        execute format('update public.%I set fetched_at = now()', t);
        raise exception 'EMPIRICAL/raw-immutable: UPDATE % as service_role SUCCEEDED (raw mutability regression)', t;
      exception when restrict_violation or insufficient_privilege then null; end;

      begin
        execute format('delete from public.%I', t);
        raise exception 'EMPIRICAL/raw-immutable: DELETE % as service_role SUCCEEDED (raw mutability regression)', t;
      exception when restrict_violation or insufficient_privilege then null; end;

      begin
        execute format('truncate public.%I', t);
        raise exception 'EMPIRICAL/raw-immutable: TRUNCATE % as service_role SUCCEEDED (raw mutability regression)', t;
      exception when restrict_violation or insufficient_privilege then null; end;
    end loop;
  end $$;
rollback;

-- SEC-F08 scrub — clean response body ACCEPTED; request-context envelope REJECTED.
-- Proves the scrub is enforced AT THE SCHEMA (CHECK), not merely promised by the pipeline.
begin;
  do $$
  declare v_run uuid;
  begin
    insert into public.report_runs (window_start, window_end)
      values (now() - interval '30 days', now()) returning id into v_run;

    -- verbatim response bodies are accepted (no false positive on real YouTube payloads)
    insert into public.raw_youtube_search_pages (run_id, page_token, response_json)
      values (v_run, 'CAUQAA', '{"kind":"youtube#searchListResponse","nextPageToken":"x","items":[]}');
    insert into public.raw_youtube_videos (run_id, video_id, channel_id, raw_json)
      values (v_run, 'vid_clean', 'chan_clean', '{"kind":"youtube#video","statistics":{"viewCount":"10"}}');
    insert into public.raw_youtube_channels (run_id, channel_id, raw_json)
      values (v_run, 'chan_clean', '{"kind":"youtube#channel"}');

    -- request-context envelopes (axios/fetch dump carrying ?key= / Authorization) are blocked
    begin
      insert into public.raw_youtube_search_pages (run_id, page_token, response_json)
        values (v_run, 'dirty', '{"config":{"url":"https://www.googleapis.com/youtube/v3/search?key=AIzaLEAK"}}');
      raise exception 'EMPIRICAL/scrub: search_pages request-context payload ACCEPTED (SEC-F08 regression)';
    exception when check_violation then null; end;

    begin
      insert into public.raw_youtube_videos (run_id, video_id, channel_id, raw_json)
        values (v_run, 'vid_dirty', 'chan_x', '{"request":{"headers":{"authorization":"Bearer SECRET"}}}');
      raise exception 'EMPIRICAL/scrub: videos request-context payload ACCEPTED (SEC-F08 regression)';
    exception when check_violation then null; end;

    begin
      insert into public.raw_youtube_channels (run_id, channel_id, raw_json)
        values (v_run, 'chan_dirty', '{"key":"AIzaLEAK"}');
      raise exception 'EMPIRICAL/scrub: channels request-context payload ACCEPTED (SEC-F08 regression)';
    exception when check_violation then null; end;
  end $$;
rollback;

-- Logical uniqueness — a duplicate (run_id, video_id) within a run is rejected.
begin;
  do $$
  declare v_run uuid;
  begin
    insert into public.report_runs (window_start, window_end)
      values (now() - interval '30 days', now()) returning id into v_run;
    insert into public.raw_youtube_videos (run_id, video_id, channel_id, raw_json)
      values (v_run, 'dup', 'chan_1', '{"kind":"youtube#video"}');
    begin
      insert into public.raw_youtube_videos (run_id, video_id, channel_id, raw_json)
        values (v_run, 'dup', 'chan_2', '{"kind":"youtube#video"}');
      raise exception 'EMPIRICAL/uniqueness: duplicate (run_id, video_id) ACCEPTED (dedupe regression)';
    exception when unique_violation then null; end;
  end $$;
rollback;

-- Default-deny — anon + authenticated have ZERO access to the 3 raw tables -----
begin;
  do $$
  declare rol text; t text;
  begin
    foreach rol in array array['anon', 'authenticated'] loop
      foreach t in array array['raw_youtube_search_pages', 'raw_youtube_videos', 'raw_youtube_channels'] loop
        begin
          perform set_config('role', rol, true);
          execute format('select 1 from public.%I limit 1', t);
          raise exception 'EMPIRICAL/default-deny: role % could query public.% (expected permission denied)', rol, t;
        exception
          when insufficient_privilege then null;  -- expected: 42501
        end;
      end loop;
    end loop;
  end $$;
rollback;

\echo 'OK — Phase 4 post-apply verification PASSED (§4 structural + §5 empirical).'
