-- ============================================================================
-- NOXUND · Phase 6 — post-apply verification (producer_events, append-only)
-- ----------------------------------------------------------------------------
-- Run by CI immediately after `supabase db push` applies
--   supabase/migrations/20260620000007_phase6_producer_events.sql
-- Parity with supabase/tests/phase1_…_phase5_post_apply_verify.sql.
--
-- DESIGN-ONLY: a Fase 6 está autorada mas NÃO aplicada (DEC-0013 pipeline-first). Este
-- verify roda no job `verify` quando o apply gated for sequenciado. Exercita CONSTRAINTS,
-- não o pipeline de captura (Backend/RPC DEC-0004).
--
-- WHY EMPIRICAL: append-only é garantia que o service_role poderia burlar (SEC-F01/F16),
-- então só o TRIGGER prova. Nos 2 caminhos (DEC-0009/0011/0012):
--   • as postgres (grant-holder): só o TRIGGER barra → restrict_violation (prova positiva SEC-F22);
--   • as service_role: barrado por trigger OU grant → qualquer errcode (SEC-F21, sem falso-negativo).
--
-- CONTRACT: todo check RAISES on mismatch → `psql -v ON_ERROR_STOP=1` sai não-zero e falha o CI.
-- SIDE EFFECTS: nenhum persistido — toda escrita de probe vive em transação revertida; helpers
--   pg_temp.* são da sessão (auto-drop; nunca tocam o schema public).
-- Role: conecta como `postgres` do projeto (membro de anon/authenticated/service_role).
-- ============================================================================

\set ON_ERROR_STOP on

-- Fixtures de evidência COMPLETA exigidas pelos CHECKs da Fase 5 (artist_metrics/report_items),
-- necessárias para montar a cadeia de proveniência até report_items. Conteúdo opaco às FKs.
create or replace function pg_temp.p6_detail() returns jsonb immutable language sql as $fn$
  select $j${"components":{"velocity":0.40,"signals":0.25,"engagement":0.20,"diversity":0.15},
             "normalization":{"sample":500},
             "videos":{"accepted":[{"video_id":"v1"}],"rejected":[]},
             "velocity":{"inputs":[{"video_id":"v1","vpd":10}],"median":10},
             "competition":{"eligible_channel_ids":["c1"],"count":1},
             "versions":{"rubric_version":"RV","rubric_hash":"RH","resolver_version":"resolver_v1","rule_version":"rule_v1"},
             "overrides":[]}$j$::jsonb
$fn$;
create or replace function pg_temp.p6_reason() returns jsonb immutable language sql as $fn$
  select $j${"candidates":[{"video_id":"v1"}],"top3":[{"video_id":"v1"}],"tiebreak":"higher_views","selected_example":{"video_id":"v1"}}$j$::jsonb
$fn$;

\echo '== Phase 6 · §4 structural verification =='

-- table present ---------------------------------------------------------------
do $$
begin
  if not exists (select 1 from information_schema.tables
     where table_schema = 'public' and table_name = 'producer_events') then
    raise exception 'STRUCT/table: producer_events missing';
  end if;
end $$;

-- enum present with the full canonical event set (04_ §8) ----------------------
do $$
declare n int; missing text;
begin
  if not exists (select 1 from pg_type where typname = 'producer_event_type') then
    raise exception 'STRUCT/enum: producer_event_type missing';
  end if;
  select count(*) into n from pg_enum e join pg_type t on t.oid = e.enumtypid
   where t.typname = 'producer_event_type';
  if n <> 14 then raise exception 'STRUCT/enum: expected 14 event types, found %', n; end if;
  -- north-star label must exist (04_ §13)
  select string_agg(want, ', ') into missing
    from (values ('intent_to_produce_declared'), ('report_opened'),
                 ('artist_marked_useful'), ('followup_confirmed_produced')) as t(want)
   where not exists (
     select 1 from pg_enum e join pg_type ty on ty.oid = e.enumtypid
      where ty.typname = 'producer_event_type' and e.enumlabel = t.want);
  if missing is not null then raise exception 'STRUCT/enum: missing label(s): %', missing; end if;
end $$;

-- mandated columns ------------------------------------------------------------
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values ('producer_id'), ('event_type'), ('report_id'), ('report_item_id'),
                 ('artist_id'), ('metadata'), ('created_at')) as t(want)
   where not exists (select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'producer_events' and column_name = t.want);
  if missing is not null then raise exception 'STRUCT/columns: missing: %', missing; end if;
end $$;

-- producer_id + event_type NOT NULL; optional FKs nullable --------------------
do $$
declare bad text;
begin
  select string_agg(column_name, ', ') into bad from information_schema.columns
   where table_schema = 'public' and table_name = 'producer_events'
     and column_name in ('producer_id', 'event_type', 'created_at') and is_nullable <> 'NO';
  if bad is not null then raise exception 'STRUCT/not-null: must be NOT NULL: %', bad; end if;
end $$;

-- immutability function with pinned search_path -------------------------------
do $$
declare cfg text[];
begin
  select proconfig into cfg from pg_proc
   where proname = 'producer_events_immutable' and pronamespace = 'public'::regnamespace;
  if not found then raise exception 'STRUCT/function: producer_events_immutable() not found'; end if;
  if cfg is null or not exists (select 1 from unnest(cfg) c where c like 'search_path=%') then
    raise exception 'STRUCT/function: producer_events_immutable() must pin search_path, got %', cfg;
  end if;
end $$;

-- 2 immutability triggers (row update/delete + statement truncate) ------------
do $$
declare want text; missing text := '';
begin
  foreach want in array array['producer_events_no_update_delete', 'producer_events_no_truncate'] loop
    if not exists (select 1 from pg_trigger
       where not tgisinternal and tgname = want and tgrelid = 'public.producer_events'::regclass) then
      missing := missing || want || ' ';
    end if;
  end loop;
  if length(missing) > 0 then raise exception 'STRUCT/triggers: missing: %', missing; end if;
end $$;

-- 4 named provenance FKs present ----------------------------------------------
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values ('producer_events_producer_fk'), ('producer_events_report_fk'),
                 ('producer_events_report_item_fk'), ('producer_events_artist_fk')) as t(want)
   where not exists (select 1 from pg_constraint where contype = 'f' and conname = t.want);
  if missing is not null then raise exception 'STRUCT/fk: missing named FK(s): %', missing; end if;
end $$;

-- ALL FKs on producer_events are ON DELETE RESTRICT (proveniência não se perde) -
do $$
declare bad text;
begin
  select string_agg(conname, ', ') into bad from pg_constraint
   where contype = 'f' and conrelid = 'public.producer_events'::regclass and confdeltype <> 'r';
  if bad is not null then raise exception 'STRUCT/fk: non-RESTRICT ON DELETE: %', bad; end if;
end $$;

-- 2 CHECK constraints (intent context + SEC-F08) ------------------------------
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values ('producer_events_intent_context_chk'), ('producer_events_no_request_context')) as t(want)
   where not exists (select 1 from pg_constraint where contype = 'c' and conname = t.want);
  if missing is not null then raise exception 'STRUCT/check: missing CHECK(s): %', missing; end if;
end $$;

-- indexes: funnel + north-star + FK-support + dedup ---------------------------
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values
      ('producer_events_producer_type_created_idx'),
      ('producer_events_type_producer_idx'),
      ('producer_events_report_idx'),
      ('producer_events_report_item_idx'),
      ('producer_events_artist_idx'),
      ('producer_events_intent_dedup_uidx')
    ) as t(want)
   where not exists (select 1 from pg_indexes where schemaname = 'public' and indexname = t.want);
  if missing is not null then raise exception 'STRUCT/indexes: missing: %', missing; end if;
end $$;

-- dedup index must be UNIQUE and PARTIAL (WHERE intent) -----------------------
do $$
declare r record;
begin
  select i.indisunique as uniq, (i.indpred is not null) as partial
    into r
    from pg_index i join pg_class c on c.oid = i.indexrelid
   where c.relname = 'producer_events_intent_dedup_uidx';
  if not found then raise exception 'STRUCT/dedup: intent dedup index missing'; end if;
  if not r.uniq then raise exception 'STRUCT/dedup: intent dedup index must be UNIQUE'; end if;
  if not r.partial then raise exception 'STRUCT/dedup: intent dedup index must be PARTIAL (WHERE event_type=intent)'; end if;
end $$;

-- RLS enabled + ZERO policies (Fase 9 vetada) ---------------------------------
do $$
declare n int;
begin
  if not exists (select 1 from pg_class where relnamespace = 'public'::regnamespace
     and relname = 'producer_events' and relrowsecurity = true) then
    raise exception 'STRUCT/rls: RLS not enabled on producer_events';
  end if;
  select count(*) into n from pg_policies where schemaname = 'public' and tablename = 'producer_events';
  if n <> 0 then raise exception 'STRUCT/policy: expected ZERO policies, found %', n; end if;
end $$;

\echo '== Phase 6 · §5 empirical verification =='

-- ----------------------------------------------------------------------------
-- Append-only — UPDATE/DELETE/TRUNCATE blocked, BOTH role paths; INSERT allowed.
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_prod uuid; v_evt uuid;
  begin
    insert into public.producers (email, display_name, youtube_url, niche)
      values ('p6.append@example.com', 'P6 Append', 'https://youtube.com/@p6', 'drill')
      returning id into v_prod;
    -- INSERT (append) is allowed
    insert into public.producer_events (producer_id, event_type)
      values (v_prod, 'report_opened') returning id into v_evt;

    -- A) grant-holder (postgres): only the TRIGGER can block -> restrict_violation (SEC-F22)
    begin
      update public.producer_events set event_type = 'report_switched' where id = v_evt;
      raise exception 'EMPIRICAL/append-only: UPDATE (postgres) SUCCEEDED';
    exception when restrict_violation then null; end;
    begin
      delete from public.producer_events where id = v_evt;
      raise exception 'EMPIRICAL/append-only: DELETE (postgres) SUCCEEDED';
    exception when restrict_violation then null; end;
    begin
      truncate public.producer_events;
      raise exception 'EMPIRICAL/append-only: TRUNCATE (postgres) SUCCEEDED';
    exception when restrict_violation then null; end;

    -- B) service_role: blocked by trigger OR grant -> either errcode (SEC-F21)
    perform set_config('role', 'service_role', true);
    begin
      update public.producer_events set event_type = 'report_switched' where id = v_evt;
      raise exception 'EMPIRICAL/append-only: UPDATE (service_role) SUCCEEDED';
    exception when restrict_violation or insufficient_privilege then null; end;
    begin
      delete from public.producer_events where id = v_evt;
      raise exception 'EMPIRICAL/append-only: DELETE (service_role) SUCCEEDED';
    exception when restrict_violation or insufficient_privilege then null; end;
    begin
      truncate public.producer_events;
      raise exception 'EMPIRICAL/append-only: TRUNCATE (service_role) SUCCEEDED';
    exception when restrict_violation or insufficient_privilege then null; end;
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- Provenance — FK ON DELETE RESTRICT preserves every anchor an event references.
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_prod uuid; v_run uuid; v_artist uuid; v_metric uuid; v_report uuid; v_item uuid;
  begin
    insert into public.producers (email, display_name, youtube_url, niche)
      values ('p6.prov@example.com', 'P6 Prov', 'https://youtube.com/@p6p', 'drill') returning id into v_prod;
    insert into public.report_runs (window_start, window_end)
      values (now() - interval '30 days', now()) returning id into v_run;
    insert into public.artists (canonical_name) values ('P6 Prov Artist') returning id into v_artist;
    insert into public.rubric_versions (version, config_json, hash) values ('__p6__', '{}', '__p6_h__');
    insert into public.artist_metrics (run_id, artist_id, rubric_version, rubric_hash, metrics_detail_json)
      values (v_run, v_artist, '__p6__', '__p6_h__', pg_temp.p6_detail()) returning id into v_metric;
    insert into public.reports (run_id, title, rubric_version, rubric_hash)
      values (v_run, 'P6 Report', '__p6__', '__p6_h__') returning id into v_report;
    insert into public.report_items (report_id, run_id, artist_id, artist_metric_id, rubric_version, rubric_hash, rank, selection_reason_json)
      values (v_report, v_run, v_artist, v_metric, '__p6__', '__p6_h__', 1, pg_temp.p6_reason()) returning id into v_item;

    -- the event links the whole chain (positive: insert succeeds)
    insert into public.producer_events (producer_id, event_type, report_id, report_item_id, artist_id)
      values (v_prod, 'example_clicked', v_report, v_item, v_artist);

    -- none of the referenced anchors can be deleted while the event exists
    begin
      delete from public.producers where id = v_prod;
      raise exception 'EMPIRICAL/provenance: DELETE referenced producer SUCCEEDED';
    exception when foreign_key_violation or restrict_violation then null; end;
    begin
      delete from public.report_items where id = v_item;
      raise exception 'EMPIRICAL/provenance: DELETE referenced report_item SUCCEEDED';
    exception when foreign_key_violation or restrict_violation then null; end;
    begin
      delete from public.reports where id = v_report;
      raise exception 'EMPIRICAL/provenance: DELETE referenced report SUCCEEDED';
    exception when foreign_key_violation or restrict_violation then null; end;
    begin
      delete from public.artists where id = v_artist;
      raise exception 'EMPIRICAL/provenance: DELETE referenced artist SUCCEEDED';
    exception when foreign_key_violation or restrict_violation then null; end;
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- North-star — intent_to_produce_declared deduped by (producer, artist, report);
-- append-only NOT broken (a re-declared intent is a rejected duplicate, never a mutation).
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_prod uuid; v_run uuid; v_artist uuid; v_artist2 uuid; v_report uuid;
  begin
    insert into public.producers (email, display_name, youtube_url, niche)
      values ('p6.intent@example.com', 'P6 Intent', 'https://youtube.com/@p6i', 'drill') returning id into v_prod;
    insert into public.report_runs (window_start, window_end)
      values (now() - interval '30 days', now()) returning id into v_run;
    insert into public.artists (canonical_name) values ('P6 Intent A') returning id into v_artist;
    insert into public.artists (canonical_name) values ('P6 Intent B') returning id into v_artist2;
    insert into public.rubric_versions (version, config_json, hash) values ('__p6i__', '{}', '__p6i_h__');
    insert into public.reports (run_id, title, rubric_version, rubric_hash)
      values (v_run, 'Intent Report', '__p6i__', '__p6i_h__') returning id into v_report;

    -- first intent accepted
    insert into public.producer_events (producer_id, event_type, report_id, artist_id)
      values (v_prod, 'intent_to_produce_declared', v_report, v_artist);
    -- duplicate intent (same producer, artist, report) rejected (dedup), table still append-only
    begin
      insert into public.producer_events (producer_id, event_type, report_id, artist_id)
        values (v_prod, 'intent_to_produce_declared', v_report, v_artist);
      raise exception 'EMPIRICAL/north-star: duplicate intent (producer,artist,report) ACCEPTED';
    exception when unique_violation then null; end;
    -- intent for a DIFFERENT artist is a distinct fact -> accepted
    insert into public.producer_events (producer_id, event_type, report_id, artist_id)
      values (v_prod, 'intent_to_produce_declared', v_report, v_artist2);

    -- intent WITHOUT context (artist/report) is rejected (CHECK) -> dedup grain always populated
    begin
      insert into public.producer_events (producer_id, event_type)
        values (v_prod, 'intent_to_produce_declared');
      raise exception 'EMPIRICAL/north-star: intent without artist/report ACCEPTED';
    exception when check_violation then null; end;
    begin
      insert into public.producer_events (producer_id, event_type, report_id)
        values (v_prod, 'intent_to_produce_declared', v_report);   -- artist_id null
      raise exception 'EMPIRICAL/north-star: intent without artist_id ACCEPTED';
    exception when check_violation then null; end;
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- SEC-F08 — metadata rejects transport/request envelope; clean metadata accepted.
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_prod uuid;
  begin
    insert into public.producers (email, display_name, youtube_url, niche)
      values ('p6.f08@example.com', 'P6 F08', 'https://youtube.com/@p6f', 'drill') returning id into v_prod;
    -- clean product detail accepted
    insert into public.producer_events (producer_id, event_type, metadata)
      values (v_prod, 'report_opened', '{"surface":"hot_row","ms_open":1200}'::jsonb);
    -- envelope carrying a key/secret rejected
    begin
      insert into public.producer_events (producer_id, event_type, metadata)
        values (v_prod, 'report_opened', '{"key":"sk-leak","request":{}}'::jsonb);
      raise exception 'EMPIRICAL/SEC-F08: metadata with request/secret envelope ACCEPTED';
    exception when check_violation then null; end;
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- Default-deny — anon + authenticated have ZERO access to producer_events.
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare rol text;
  begin
    foreach rol in array array['anon', 'authenticated'] loop
      begin
        perform set_config('role', rol, true);
        perform 1 from public.producer_events limit 1;
        raise exception 'EMPIRICAL/default-deny: role % could query producer_events', rol;
      exception when insufficient_privilege then null; end;
    end loop;
  end $$;
rollback;

\echo 'OK — Phase 6 post-apply verification PASSED (§4 structural + §5 empirical).'
