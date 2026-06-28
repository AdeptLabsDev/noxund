-- ============================================================================
-- NOXUND · Phase 5 — post-apply verification (Computed Metrics + Reports)
-- ----------------------------------------------------------------------------
-- Run by CI immediately after `supabase db push` applies
--   supabase/migrations/20260620000005_phase5_computed_metrics_reports.sql
-- Parity with supabase/tests/phase1_…_phase4_post_apply_verify.sql.
--
-- >>> 2ª ITERAÇÃO — pós re-veto DATA-AI-0006 (DATA-RR-F5-03A/05A/06A/01A) <<<
-- Fecha os follow-on, antecipando bypass:
--   F5-03A: guard da junction valida OLD e NEW SEPARADAMENTE — mover input de métrica
--           não-publicada → publicada falha (restrict_violation), provado nos 2 role-paths.
--   F5-05A: evidência é ESTRUTURAL (não só NOT NULL) — {} e seções ausentes rejeitadas (check_violation);
--           fixture realmente completo aceito; evidência de métrica publicada imutável.
--   F5-06A: versões efetivas (rubric/resolver/rule) + overrides replayable com chave natural
--           são OBRIGATÓRIAS no contrato de evidência (provado por probe de seção/override ausentes).
--   F5-01A: probe de mover report_items draft→published repetido no caminho service-role.
--   FK count: report_items tem exatamente UMA FK para artists (sem inline duplicada).
--
-- WHY EMPIRICAL: o SNAPSHOT freeze, o guard CONDICIONAL da linhagem publicada e o contrato de
-- evidência são garantias que o service_role poderia burlar (SEC-F01). Provamos no DB, nos 2 caminhos:
--   • as postgres (grant-holder): só TRIGGER/FK/CHECK barram → restrict_violation /
--     foreign_key_violation / check_violation / not_null_violation (prova positiva — SEC-F22);
--   • as service_role: barrado por trigger/FK/CHECK OU grant → qualquer errcode (SEC-F21, sem
--     falso-negativo). Lição errcode-parity (DEC-0009) embutida ANTES do apply.
-- COMPUTED (mappings/eligibility/metrics) NÃO é congelada globalmente — reconstruível; proteção
-- de perda é FK RESTRICT (+ guard CONDICIONAL só da linhagem publicada), provado abaixo.
--
-- NOTA P5-REPRO-01: a prova canônica de 2 rodadas é gate do DATA-ENGINE/primeiro publish, NÃO
-- deste apply. Estes inserts SQL exercitam CONSTRAINTS, não os seis agentes do pipeline.
--
-- CONTRACT: todo check RAISES on mismatch → `psql -v ON_ERROR_STOP=1` sai não-zero e falha o CI.
-- SIDE EFFECTS: nenhum persistido — toda escrita de probe vive em transação revertida; os helpers
--   pg_temp.* são da SESSÃO temporária (auto-drop ao desconectar; nunca tocam o schema public).
-- Role: conecta como `postgres` do projeto (membro de anon/authenticated/service_role).
-- ============================================================================

\set ON_ERROR_STOP on

-- Fonte única de fixtures de evidência COMPLETA (F5-05A/F5-06A). pg_temp = schema temporário da
-- sessão; não interfere nas asserções estruturais (que olham só 'public'). Conteúdo é opaco às FKs
-- (a integridade referencial vem de artist_metric_videos/Example, não do JSON).
create or replace function pg_temp.p5_detail() returns jsonb immutable language sql as $fn$
  select $j${"components":{"velocity":0.40,"signals":0.25,"engagement":0.20,"diversity":0.15},
             "normalization":{"sample":500,"method":"minmax"},
             "videos":{"accepted":[{"video_id":"v1"}],"rejected":[{"video_id":"v2","reason":"channel_ineligible"}]},
             "velocity":{"inputs":[{"video_id":"v1","vpd":10}],"median":10},
             "competition":{"eligible_channel_ids":["c1"],"count":1},
             "versions":{"rubric_version":"RV","rubric_hash":"RH","resolver_version":"resolver_v1","rule_version":"rule_v1"},
             "overrides":[]}$j$::jsonb
$fn$;

create or replace function pg_temp.p5_reason() returns jsonb immutable language sql as $fn$
  select $j${"candidates":[{"video_id":"v1"},{"video_id":"v2"}],
             "top3":[{"video_id":"v1"}],
             "tiebreak":"higher_views",
             "selected_example":{"video_id":"v1"}}$j$::jsonb
$fn$;

\echo '== Phase 5 · §4 structural verification =='

-- 6 tables --------------------------------------------------------------------
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values ('video_artist_mappings'), ('channel_eligibility'), ('artist_metrics'),
                 ('artist_metric_videos'), ('reports'), ('report_items')) as t(want)
   where not exists (
     select 1 from information_schema.tables
      where table_schema = 'public' and table_name = t.want
   );
  if missing is not null then
    raise exception 'STRUCT/tables: missing Phase 5 table(s): %', missing;
  end if;
end $$;

-- 3 enums ---------------------------------------------------------------------
do $$
declare n int;
begin
  select count(*) into n from pg_type
   where typname in ('video_artist_method', 'report_status', 'competition_level');
  if n <> 3 then raise exception 'STRUCT/enums: expected 3 enums, found %', n; end if;
end $$;

-- mandated columns exist (OD-DB-06/07 + provenance + versions) -----------------
do $$
declare missing text;
begin
  select string_agg(label, ', ') into missing
    from (values
      ('artist_metrics.metrics_detail_json'), ('report_items.artist_metric_id'),
      ('report_items.selection_reason_json'), ('report_items.run_id'),
      ('report_items.rubric_version'), ('report_items.rubric_hash'),
      ('reports.rubric_version'), ('reports.rubric_hash'),
      ('channel_eligibility.rule_version'), ('video_artist_mappings.resolver_version'),
      ('artist_metric_videos.video_id')
    ) as t(label)
   where not exists (
     select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = split_part(t.label, '.', 1)
        and column_name = split_part(t.label, '.', 2)
   );
  if missing is not null then
    raise exception 'STRUCT/columns: missing mandated column(s): %', missing;
  end if;
end $$;

-- F5-05/F5-06: audit-evidence + version columns must be NOT NULL ---------------
do $$
declare bad text;
begin
  select string_agg(label, ', ') into bad
    from (values
      ('artist_metrics.metrics_detail_json'), ('report_items.selection_reason_json'),
      ('channel_eligibility.rule_version'), ('video_artist_mappings.resolver_version'),
      ('reports.rubric_version'), ('reports.rubric_hash')
    ) as t(label)
   where exists (
     select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = split_part(t.label, '.', 1)
        and column_name = split_part(t.label, '.', 2)
        and is_nullable <> 'NO'
   );
  if bad is not null then
    raise exception 'STRUCT/not-null: column(s) must be NOT NULL (F5-05/F5-06): %', bad;
  end if;
end $$;

-- 5 trigger-guard functions with pinned search_path ---------------------------
do $$
declare want text; cfg text[];
begin
  foreach want in array array['reports_snapshot_guard', 'report_items_snapshot_guard',
                              'artist_metrics_published_guard', 'artist_metric_videos_published_guard',
                              'report_snapshot_no_truncate'] loop
    select proconfig into cfg from pg_proc
     where proname = want and pronamespace = 'public'::regnamespace;
    if not found then raise exception 'STRUCT/function: public.%() not found', want; end if;
    if cfg is null or not exists (select 1 from unnest(cfg) c where c like 'search_path=%') then
      raise exception 'STRUCT/function: expected pinned search_path on %(), got %', want, cfg;
    end if;
  end loop;
end $$;

-- F5-05A: 2 evidence validators exist, are IMMUTABLE, and have pinned search_path
do $$
declare want text; r record;
begin
  foreach want in array array['artist_metrics_detail_complete', 'report_item_reason_complete'] loop
    select provolatile, proconfig into r from pg_proc
     where proname = want and pronamespace = 'public'::regnamespace;
    if not found then raise exception 'STRUCT/F5-05A: validator public.%() not found', want; end if;
    if r.provolatile <> 'i' then
      raise exception 'STRUCT/F5-05A: validator %() must be IMMUTABLE, got volatility %', want, r.provolatile;
    end if;
    if r.proconfig is null or not exists (select 1 from unnest(r.proconfig) c where c like 'search_path=%') then
      raise exception 'STRUCT/F5-05A: validator %() must pin search_path', want;
    end if;
  end loop;
end $$;

-- cross-table guards must be SECURITY DEFINER (SEC-F15 — read reports/report_items) -
do $$
declare want text;
begin
  foreach want in array array['report_items_snapshot_guard', 'artist_metrics_published_guard',
                              'artist_metric_videos_published_guard'] loop
    if not exists (select 1 from pg_proc
       where proname = want and pronamespace = 'public'::regnamespace and prosecdef = true) then
      raise exception 'STRUCT/function: %() must be SECURITY DEFINER', want;
    end if;
  end loop;
end $$;

-- F5-05A: evidence CHECK constraints present ----------------------------------
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values ('artist_metrics_detail_complete_chk'), ('report_items_reason_complete_chk')) as t(want)
   where not exists (select 1 from pg_constraint where contype = 'c' and conname = t.want);
  if missing is not null then
    raise exception 'STRUCT/F5-05A: missing evidence CHECK constraint(s): %', missing;
  end if;
end $$;

-- 7 triggers present ----------------------------------------------------------
do $$
declare want text; missing text := '';
begin
  foreach want in array array['reports_snapshot_guard', 'reports_no_truncate',
                              'report_items_snapshot_guard', 'report_items_no_truncate',
                              'artist_metrics_published_guard',
                              'artist_metric_videos_published_guard', 'artist_metric_videos_no_truncate'] loop
    if not exists (select 1 from pg_trigger
       where not tgisinternal and tgname = want
         and tgrelid in ('public.reports'::regclass, 'public.report_items'::regclass,
                         'public.artist_metrics'::regclass, 'public.artist_metric_videos'::regclass)) then
      missing := missing || want || ' ';
    end if;
  end loop;
  if length(missing) > 0 then raise exception 'STRUCT/triggers: missing trigger(s): %', missing; end if;
end $$;

-- F5-01/F5-03A: guards that must cover INSERT (tgtype bit 2 = INSERT) ----------
do $$
declare bad text := '';
begin
  if (select tgtype from pg_trigger where tgname = 'report_items_snapshot_guard'
        and tgrelid = 'public.report_items'::regclass) & 4 = 0 then bad := bad || 'report_items_snapshot_guard '; end if;
  if (select tgtype from pg_trigger where tgname = 'reports_snapshot_guard'
        and tgrelid = 'public.reports'::regclass) & 4 = 0 then bad := bad || 'reports_snapshot_guard '; end if;
  if (select tgtype from pg_trigger where tgname = 'artist_metric_videos_published_guard'
        and tgrelid = 'public.artist_metric_videos'::regclass) & 4 = 0 then bad := bad || 'artist_metric_videos_published_guard '; end if;
  if length(bad) > 0 then raise exception 'STRUCT/INSERT-coverage: guard(s) do not cover INSERT: %', bad; end if;
end $$;

-- 6 logical-uniqueness indexes ------------------------------------------------
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values
      ('video_artist_mappings_run_video_uidx'), ('channel_eligibility_run_channel_uidx'),
      ('artist_metrics_run_artist_rubric_uidx'), ('artist_metric_videos_pk'),
      ('report_items_report_rank_uidx'), ('report_items_report_artist_uidx')
    ) as t(want)
   where not exists (select 1 from pg_indexes where schemaname = 'public' and indexname = t.want);
  if missing is not null then raise exception 'STRUCT/indexes: missing uniqueness index(es): %', missing; end if;
end $$;

-- coherence identity unique keys (alvos das FKs compostas — F5-02/F5-04) -------
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values ('reports_identity_key'), ('artist_metrics_identity_key'), ('artist_metrics_id_run_key')) as t(want)
   where not exists (select 1 from pg_constraint where contype = 'u' and conname = t.want);
  if missing is not null then raise exception 'STRUCT/unique: missing coherence identity key(s): %', missing; end if;
end $$;

-- critical named FKs present (provenance + coherence web) ----------------------
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values
      ('artist_metrics_rubric_fk'), ('report_items_artist_metric_fk'), ('report_items_report_fk'),
      ('report_items_artist_fk'), ('report_items_example_raw_fk'),
      ('video_artist_mappings_raw_video_fk'), ('channel_eligibility_raw_channel_fk'),
      ('artist_metric_videos_metric_fk'), ('artist_metric_videos_raw_fk'), ('reports_rubric_fk')
    ) as t(want)
   where not exists (select 1 from pg_constraint where contype = 'f' and conname = t.want);
  if missing is not null then raise exception 'STRUCT/fk: missing critical FK(s): %', missing; end if;
end $$;

-- FK-count note resolved: report_items.artist_id has EXACTLY ONE FK to artists (no inline dup).
do $$
declare n int;
begin
  select count(*) into n from pg_constraint
   where contype = 'f' and conrelid = 'public.report_items'::regclass
     and confrelid = 'public.artists'::regclass;
  if n <> 1 then
    raise exception 'STRUCT/fk-count: report_items must have exactly 1 FK to artists (no duplicate), found %', n;
  end if;
end $$;

-- F5-07: report_items_artist_metric_fk identified by columns/target/RESTRICT ----
do $$
declare v_target regclass; v_deltype char; v_cols text;
begin
  select confrelid::regclass, confdeltype,
         (select string_agg(a.attname, ',' order by a.attname)
            from unnest(c.conkey) k join pg_attribute a on a.attrelid = c.conrelid and a.attnum = k)
    into v_target, v_deltype, v_cols
    from pg_constraint c where c.conname = 'report_items_artist_metric_fk' and c.contype = 'f';
  if v_target is distinct from 'public.artist_metrics'::regclass then
    raise exception 'STRUCT/F5-07: artist_metric_fk must target artist_metrics, got %', v_target;
  end if;
  if v_deltype <> 'r' then
    raise exception 'STRUCT/F5-07: artist_metric_fk must be ON DELETE RESTRICT, got %', v_deltype;
  end if;
  if v_cols <> 'artist_id,artist_metric_id,rubric_hash,rubric_version,run_id' then
    raise exception 'STRUCT/F5-07: artist_metric_fk columns wrong, got %', v_cols;
  end if;
end $$;

-- ALL FKs on the 6 tables are ON DELETE RESTRICT ------------------------------
do $$
declare bad text;
begin
  select string_agg(conname, ', ') into bad from pg_constraint
   where contype = 'f'
     and conrelid in ('public.video_artist_mappings'::regclass, 'public.channel_eligibility'::regclass,
                      'public.artist_metrics'::regclass, 'public.artist_metric_videos'::regclass,
                      'public.reports'::regclass, 'public.report_items'::regclass)
     and confdeltype <> 'r';
  if bad is not null then raise exception 'STRUCT/fk: non-RESTRICT ON DELETE on Phase 5 FK(s): %', bad; end if;
end $$;

-- F5-07: ZERO global-immutability freeze on the 3 COMPUTED tables --------------
do $$
declare n int; bad text;
begin
  select count(*) into n from pg_trigger
   where not tgisinternal
     and tgrelid in ('public.video_artist_mappings'::regclass, 'public.channel_eligibility'::regclass);
  if n <> 0 then
    raise exception 'STRUCT/F5-07: mappings/eligibility must have ZERO triggers (no freeze), found %', n;
  end if;
  select string_agg(tgname, ', ') into bad from pg_trigger
   where not tgisinternal and tgrelid = 'public.artist_metrics'::regclass
     and tgname <> 'artist_metrics_published_guard';
  if bad is not null then
    raise exception 'STRUCT/F5-07: artist_metrics must carry ONLY the conditional published guard, found extra: %', bad;
  end if;
end $$;

-- storage-only: ZERO range/threshold CHECK on numeric metric columns ----------
-- (os únicos CHECKs permitidos são: reports_published_at_chk + os 2 de evidência ESTRUTURAL.)
do $$
declare bad text;
begin
  select string_agg(conname, ', ') into bad from pg_constraint
   where contype = 'c'
     and conrelid in ('public.artist_metrics'::regclass, 'public.report_items'::regclass,
                      'public.reports'::regclass, 'public.channel_eligibility'::regclass,
                      'public.video_artist_mappings'::regclass, 'public.artist_metric_videos'::regclass)
     and conname not in ('reports_published_at_chk',
                         'artist_metrics_detail_complete_chk', 'report_items_reason_complete_chk');
  if bad is not null then
    raise exception 'STRUCT/storage-only: unexpected CHECK constraint(s) (possible range/threshold): %', bad;
  end if;
end $$;

-- RLS enabled on all 6 + ZERO policies ----------------------------------------
do $$
declare bad text; n int;
begin
  select string_agg(relname, ', ') into bad from pg_class
   where relnamespace = 'public'::regnamespace
     and relname in ('video_artist_mappings', 'channel_eligibility', 'artist_metrics',
                     'artist_metric_videos', 'reports', 'report_items')
     and relrowsecurity = false;
  if bad is not null then raise exception 'STRUCT/rls: RLS not enabled on: %', bad; end if;

  select count(*) into n from pg_policies
   where schemaname = 'public'
     and tablename in ('video_artist_mappings', 'channel_eligibility', 'artist_metrics',
                       'artist_metric_videos', 'reports', 'report_items');
  if n <> 0 then raise exception 'STRUCT/policy: expected ZERO policies (Fase 9 sob veto), found %', n; end if;
end $$;

\echo '== Phase 5 · §5 empirical verification =='

-- ----------------------------------------------------------------------------
-- F5-01 / F5-01A — Snapshot freeze covers INSERT/UPDATE/DELETE + move draft→published,
-- BOTH role paths (move probe agora repetido como service_role — F5-01A).
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_run uuid; v_artist uuid; v_metric uuid;
          v_draft uuid; v_pub uuid; v_item uuid; v_item_draft uuid; v_item_draft2 uuid;
  begin
    insert into public.report_runs (window_start, window_end)
      values (now() - interval '30 days', now()) returning id into v_run;
    insert into public.artists (canonical_name) values ('P5 Freeze') returning id into v_artist;
    insert into public.rubric_versions (version, config_json, hash) values ('__p5f__', '{}', '__p5f_h__');
    insert into public.artist_metrics (run_id, artist_id, rubric_version, rubric_hash, metrics_detail_json, final_score)
      values (v_run, v_artist, '__p5f__', '__p5f_h__', pg_temp.p5_detail(), 88) returning id into v_metric;
    insert into public.reports (run_id, title, rubric_version, rubric_hash)
      values (v_run, 'Pub', '__p5f__', '__p5f_h__') returning id into v_pub;
    insert into public.reports (run_id, title, rubric_version, rubric_hash)
      values (v_run, 'Draft', '__p5f__', '__p5f_h__') returning id into v_draft;
    insert into public.report_items (report_id, run_id, artist_id, artist_metric_id, rubric_version, rubric_hash, rank, selection_reason_json)
      values (v_pub, v_run, v_artist, v_metric, '__p5f__', '__p5f_h__', 1, pg_temp.p5_reason()) returning id into v_item;
    update public.reports set status = 'published', published_at = now() where id = v_pub;

    -- A) grant-holder (postgres): only the TRIGGER can block -> restrict_violation (SEC-F22)
    begin
      update public.reports set title = 'tamper' where id = v_pub;
      raise exception 'EMPIRICAL/F5-01: UPDATE published report (postgres) SUCCEEDED';
    exception when restrict_violation then null; end;
    begin
      update public.report_items set rank = 99 where id = v_item;
      raise exception 'EMPIRICAL/F5-01: UPDATE published report_item (postgres) SUCCEEDED';
    exception when restrict_violation then null; end;
    begin
      delete from public.report_items where id = v_item;
      raise exception 'EMPIRICAL/F5-01: DELETE published report_item (postgres) SUCCEEDED';
    exception when restrict_violation then null; end;
    begin
      delete from public.reports where id = v_pub;
      raise exception 'EMPIRICAL/F5-01: DELETE published report (postgres) SUCCEEDED';
    exception when restrict_violation then null; end;
    begin
      insert into public.report_items (report_id, run_id, artist_id, artist_metric_id, rubric_version, rubric_hash, rank, selection_reason_json)
        values (v_pub, v_run, v_artist, v_metric, '__p5f__', '__p5f_h__', 2, pg_temp.p5_reason());
      raise exception 'EMPIRICAL/F5-01: INSERT item into published report (postgres) SUCCEEDED';
    exception when restrict_violation then null; end;

    -- move draft item -> published report (validates parent of NEW). Two draft items so we can
    -- probe the move on BOTH role paths without a successful move in between.
    insert into public.report_items (report_id, run_id, artist_id, artist_metric_id, rubric_version, rubric_hash, rank, selection_reason_json)
      values (v_draft, v_run, v_artist, v_metric, '__p5f__', '__p5f_h__', 1, pg_temp.p5_reason()) returning id into v_item_draft;
    begin
      update public.report_items set report_id = v_pub, rank = 5 where id = v_item_draft;
      raise exception 'EMPIRICAL/F5-01: move draft item -> published (postgres) SUCCEEDED';
    exception when restrict_violation then null; end;
    update public.report_items set rank = 7 where id = v_item_draft;   -- positive: draft still mutable

    -- B) service_role: blocked by trigger OR grant -> either errcode (SEC-F21)
    perform set_config('role', 'service_role', true);
    begin
      update public.reports set title = 'tamper2' where id = v_pub;
      raise exception 'EMPIRICAL/F5-01: UPDATE published report (service_role) SUCCEEDED';
    exception when restrict_violation or insufficient_privilege then null; end;
    begin
      delete from public.report_items where id = v_item;
      raise exception 'EMPIRICAL/F5-01: DELETE published report_item (service_role) SUCCEEDED';
    exception when restrict_violation or insufficient_privilege then null; end;
    begin
      insert into public.report_items (report_id, run_id, artist_id, artist_metric_id, rubric_version, rubric_hash, rank, selection_reason_json)
        values (v_pub, v_run, v_artist, v_metric, '__p5f__', '__p5f_h__', 3, pg_temp.p5_reason());
      raise exception 'EMPIRICAL/F5-01: INSERT item into published report (service_role) SUCCEEDED';
    exception when restrict_violation or insufficient_privilege then null; end;
    -- F5-01A: move draft item -> published also on service_role path
    begin
      update public.report_items set report_id = v_pub, rank = 6 where id = v_item_draft;
      raise exception 'EMPIRICAL/F5-01A: move draft item -> published (service_role) SUCCEEDED';
    exception when restrict_violation or insufficient_privilege then null; end;
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- State machine — entry=draft; draft mutable; draft→published OK; published→draft
-- BLOCKED; published→archived OK; INSERT non-draft report BLOCKED.
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_run uuid; v_artist uuid; v_metric uuid; v_report uuid; v_item uuid;
  begin
    insert into public.report_runs (window_start, window_end)
      values (now() - interval '30 days', now()) returning id into v_run;
    insert into public.artists (canonical_name) values ('P5 SM') returning id into v_artist;
    insert into public.rubric_versions (version, config_json, hash) values ('__p5sm__', '{}', '__p5sm_h__');
    insert into public.artist_metrics (run_id, artist_id, rubric_version, rubric_hash, metrics_detail_json)
      values (v_run, v_artist, '__p5sm__', '__p5sm_h__', pg_temp.p5_detail()) returning id into v_metric;

    begin
      insert into public.reports (run_id, title, rubric_version, rubric_hash, status, published_at)
        values (v_run, 'born-published', '__p5sm__', '__p5sm_h__', 'published', now());
      raise exception 'EMPIRICAL/state: INSERT report as published SUCCEEDED (entry must be draft)';
    exception when restrict_violation then null; end;

    insert into public.reports (run_id, title, rubric_version, rubric_hash)
      values (v_run, 'SM Report', '__p5sm__', '__p5sm_h__') returning id into v_report;
    insert into public.report_items (report_id, run_id, artist_id, artist_metric_id, rubric_version, rubric_hash, rank, selection_reason_json)
      values (v_report, v_run, v_artist, v_metric, '__p5sm__', '__p5sm_h__', 1, pg_temp.p5_reason()) returning id into v_item;

    update public.reports set title = 'SM Report v2' where id = v_report;   -- OK
    update public.report_items set rank = 2 where id = v_item;              -- OK (parent draft)
    update public.reports set status = 'published', published_at = now() where id = v_report;  -- OK

    begin
      update public.reports set status = 'draft' where id = v_report;
      raise exception 'EMPIRICAL/state: published→draft SUCCEEDED (un-publish regression)';
    exception when restrict_violation then null; end;

    update public.reports set status = 'archived' where id = v_report;      -- published→archived OK
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- F5-02 — Coherence report→item→metric (same run_id, artist_id, rubric).
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_runA uuid; v_runB uuid; v_artX uuid; v_artY uuid;
          v_mA_X_R1 uuid; v_mB_X_R1 uuid; v_mA_Y_R1 uuid; v_mA_X_R2 uuid; v_report uuid; v_report2 uuid;
  begin
    insert into public.report_runs (window_start, window_end) values (now() - interval '30 days', now()) returning id into v_runA;
    insert into public.report_runs (window_start, window_end) values (now() - interval '60 days', now() - interval '31 days') returning id into v_runB;
    insert into public.artists (canonical_name) values ('P5 Coh X') returning id into v_artX;
    insert into public.artists (canonical_name) values ('P5 Coh Y') returning id into v_artY;
    insert into public.rubric_versions (version, config_json, hash) values ('__R1__', '{}', '__R1_h__');
    insert into public.rubric_versions (version, config_json, hash) values ('__R2__', '{}', '__R2_h__');

    insert into public.artist_metrics (run_id, artist_id, rubric_version, rubric_hash, metrics_detail_json)
      values (v_runA, v_artX, '__R1__', '__R1_h__', pg_temp.p5_detail()) returning id into v_mA_X_R1;
    insert into public.artist_metrics (run_id, artist_id, rubric_version, rubric_hash, metrics_detail_json)
      values (v_runB, v_artX, '__R1__', '__R1_h__', pg_temp.p5_detail()) returning id into v_mB_X_R1;
    insert into public.artist_metrics (run_id, artist_id, rubric_version, rubric_hash, metrics_detail_json)
      values (v_runA, v_artY, '__R1__', '__R1_h__', pg_temp.p5_detail()) returning id into v_mA_Y_R1;
    insert into public.artist_metrics (run_id, artist_id, rubric_version, rubric_hash, metrics_detail_json)
      values (v_runA, v_artX, '__R2__', '__R2_h__', pg_temp.p5_detail()) returning id into v_mA_X_R2;

    insert into public.reports (run_id, title, rubric_version, rubric_hash) values (v_runA, 'Coh', '__R1__', '__R1_h__') returning id into v_report;
    insert into public.reports (run_id, title, rubric_version, rubric_hash) values (v_runA, 'Coh2', '__R1__', '__R1_h__') returning id into v_report2;

    insert into public.report_items (report_id, run_id, artist_id, artist_metric_id, rubric_version, rubric_hash, rank, selection_reason_json)
      values (v_report, v_runA, v_artX, v_mA_X_R1, '__R1__', '__R1_h__', 1, pg_temp.p5_reason());

    begin
      insert into public.report_items (report_id, run_id, artist_id, artist_metric_id, rubric_version, rubric_hash, rank, selection_reason_json)
        values (v_report2, v_runA, v_artX, v_mB_X_R1, '__R1__', '__R1_h__', 1, pg_temp.p5_reason());
      raise exception 'EMPIRICAL/F5-02: item pointing metric of ANOTHER RUN ACCEPTED';
    exception when foreign_key_violation then null; end;
    begin
      insert into public.report_items (report_id, run_id, artist_id, artist_metric_id, rubric_version, rubric_hash, rank, selection_reason_json)
        values (v_report2, v_runA, v_artX, v_mA_Y_R1, '__R1__', '__R1_h__', 2, pg_temp.p5_reason());
      raise exception 'EMPIRICAL/F5-02: item pointing metric of ANOTHER ARTIST ACCEPTED';
    exception when foreign_key_violation then null; end;
    begin
      insert into public.report_items (report_id, run_id, artist_id, artist_metric_id, rubric_version, rubric_hash, rank, selection_reason_json)
        values (v_report2, v_runA, v_artX, v_mA_X_R2, '__R1__', '__R1_h__', 3, pg_temp.p5_reason());
      raise exception 'EMPIRICAL/F5-02: item pointing metric of ANOTHER RUBRIC ACCEPTED';
    exception when foreign_key_violation then null; end;
    begin
      insert into public.report_items (report_id, run_id, artist_id, artist_metric_id, rubric_version, rubric_hash, rank, selection_reason_json)
        values (v_report2, v_runA, v_artX, v_mA_X_R2, '__R2__', '__R2_h__', 4, pg_temp.p5_reason());
      raise exception 'EMPIRICAL/F5-02: item whose rubric diverges from report ACCEPTED';
    exception when foreign_key_violation then null; end;
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- F5-03 / F5-03A — Published lineage inviolable; non-published free to recompute.
-- Tamper blocked; recompute allowed; INPUT MOVE non-published→published BLOCKED (2 paths).
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_run uuid; v_artist uuid; v_artist2 uuid; v_mpub uuid; v_mdraft uuid; v_pub uuid; v_draft uuid;
  begin
    insert into public.report_runs (window_start, window_end) values (now() - interval '30 days', now()) returning id into v_run;
    insert into public.artists (canonical_name) values ('P5 Pub') returning id into v_artist;
    insert into public.artists (canonical_name) values ('P5 Pub2') returning id into v_artist2;
    insert into public.rubric_versions (version, config_json, hash) values ('__p5p__', '{}', '__p5p_h__');
    insert into public.raw_youtube_videos (run_id, video_id, channel_id, raw_json) values (v_run, 'vpub', 'cpub', '{}');
    insert into public.raw_youtube_videos (run_id, video_id, channel_id, raw_json) values (v_run, 'vdrf', 'cdrf', '{}');
    insert into public.raw_youtube_videos (run_id, video_id, channel_id, raw_json) values (v_run, 'vdrf2', 'cdrf', '{}');

    insert into public.artist_metrics (run_id, artist_id, rubric_version, rubric_hash, metrics_detail_json, final_score)
      values (v_run, v_artist, '__p5p__', '__p5p_h__', pg_temp.p5_detail(), 90) returning id into v_mpub;
    insert into public.artist_metric_videos (artist_metric_id, run_id, video_id) values (v_mpub, v_run, 'vpub');
    insert into public.artist_metrics (run_id, artist_id, rubric_version, rubric_hash, metrics_detail_json, final_score)
      values (v_run, v_artist2, '__p5p__', '__p5p_h__', pg_temp.p5_detail(), 70) returning id into v_mdraft;
    insert into public.artist_metric_videos (artist_metric_id, run_id, video_id) values (v_mdraft, v_run, 'vdrf');

    insert into public.reports (run_id, title, rubric_version, rubric_hash) values (v_run, 'Pub', '__p5p__', '__p5p_h__') returning id into v_pub;
    insert into public.reports (run_id, title, rubric_version, rubric_hash) values (v_run, 'Draft', '__p5p__', '__p5p_h__') returning id into v_draft;
    insert into public.report_items (report_id, run_id, artist_id, artist_metric_id, rubric_version, rubric_hash, rank, selection_reason_json)
      values (v_pub, v_run, v_artist, v_mpub, '__p5p__', '__p5p_h__', 1, pg_temp.p5_reason());
    insert into public.report_items (report_id, run_id, artist_id, artist_metric_id, rubric_version, rubric_hash, rank, selection_reason_json)
      values (v_draft, v_run, v_artist2, v_mdraft, '__p5p__', '__p5p_h__', 1, pg_temp.p5_reason());
    update public.reports set status = 'published', published_at = now() where id = v_pub;

    -- tamper metric (UPDATE/DELETE) blocked
    begin
      update public.artist_metrics set final_score = 1 where id = v_mpub;
      raise exception 'EMPIRICAL/F5-03: UPDATE published metric (postgres) SUCCEEDED';
    exception when restrict_violation then null; end;
    -- evidence of published metric is frozen (F5-05A: cannot rewrite metrics_detail_json)
    begin
      update public.artist_metrics set metrics_detail_json = pg_temp.p5_detail() where id = v_mpub;
      raise exception 'EMPIRICAL/F5-05A: UPDATE evidence of published metric SUCCEEDED (not frozen)';
    exception when restrict_violation then null; end;
    begin
      delete from public.artist_metrics where id = v_mpub;
      raise exception 'EMPIRICAL/F5-03: DELETE published metric (postgres) SUCCEEDED';
    exception when restrict_violation or foreign_key_violation then null; end;

    -- input set of published metric frozen
    begin
      delete from public.artist_metric_videos where artist_metric_id = v_mpub;
      raise exception 'EMPIRICAL/F5-03: DELETE input of published metric SUCCEEDED';
    exception when restrict_violation then null; end;
    begin
      insert into public.artist_metric_videos (artist_metric_id, run_id, video_id) values (v_mpub, v_run, 'vdrf');
      raise exception 'EMPIRICAL/F5-03: INSERT input into published metric SUCCEEDED';
    exception when restrict_violation then null; end;

    -- F5-03A (THE BYPASS): move a NON-published input onto the PUBLISHED metric (UPDATE owner).
    -- OLD owner (v_mdraft) is non-published → origin check passes; NEW owner (v_mpub) is published
    -- → destination check must FIRE. coalesce(OLD,NEW) would have let this slip.
    begin
      update public.artist_metric_videos set artist_metric_id = v_mpub
       where artist_metric_id = v_mdraft and video_id = 'vdrf';
      raise exception 'EMPIRICAL/F5-03A: MOVE input non-published→published (postgres) SUCCEEDED (bypass)';
    exception when restrict_violation then null; end;

    -- recompute allowed: non-published metric + its input set are mutable
    update public.artist_metrics set final_score = 71 where id = v_mdraft;                 -- OK
    insert into public.artist_metric_videos (artist_metric_id, run_id, video_id) values (v_mdraft, v_run, 'vdrf2');  -- OK
    delete from public.artist_metric_videos where artist_metric_id = v_mdraft and video_id = 'vdrf2';                -- OK

    -- service_role parity: tamper + move-input both blocked
    perform set_config('role', 'service_role', true);
    begin
      update public.artist_metrics set final_score = 2 where id = v_mpub;
      raise exception 'EMPIRICAL/F5-03: UPDATE published metric (service_role) SUCCEEDED';
    exception when restrict_violation or insufficient_privilege then null; end;
    begin
      update public.artist_metric_videos set artist_metric_id = v_mpub
       where artist_metric_id = v_mdraft and video_id = 'vdrf';
      raise exception 'EMPIRICAL/F5-03A: MOVE input non-published→published (service_role) SUCCEEDED (bypass)';
    exception when restrict_violation or insufficient_privilege then null; end;
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- F5-04 — Provenance referential to raw, for metric inputs AND report Example.
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_runA uuid; v_runB uuid; v_artist uuid; v_artB uuid; v_artC uuid; v_artD uuid;
          v_metricA uuid; v_mB uuid; v_mC uuid; v_mD uuid; v_report uuid;
  begin
    insert into public.report_runs (window_start, window_end) values (now() - interval '30 days', now()) returning id into v_runA;
    insert into public.report_runs (window_start, window_end) values (now() - interval '60 days', now() - interval '31 days') returning id into v_runB;
    insert into public.artists (canonical_name) values ('P5 Prov A') returning id into v_artist;
    insert into public.artists (canonical_name) values ('P5 Prov B') returning id into v_artB;
    insert into public.artists (canonical_name) values ('P5 Prov C') returning id into v_artC;
    insert into public.artists (canonical_name) values ('P5 Prov D') returning id into v_artD;
    insert into public.rubric_versions (version, config_json, hash) values ('__p5pr__', '{}', '__p5pr_h__');
    insert into public.raw_youtube_videos (run_id, video_id, channel_id, raw_json) values (v_runA, 'vidA', 'chA', '{}');
    insert into public.raw_youtube_videos (run_id, video_id, channel_id, raw_json) values (v_runB, 'vidB', 'chB', '{}');
    insert into public.artist_metrics (run_id, artist_id, rubric_version, rubric_hash, metrics_detail_json)
      values (v_runA, v_artist, '__p5pr__', '__p5pr_h__', pg_temp.p5_detail()) returning id into v_metricA;
    insert into public.artist_metrics (run_id, artist_id, rubric_version, rubric_hash, metrics_detail_json)
      values (v_runA, v_artB, '__p5pr__', '__p5pr_h__', pg_temp.p5_detail()) returning id into v_mB;
    insert into public.artist_metrics (run_id, artist_id, rubric_version, rubric_hash, metrics_detail_json)
      values (v_runA, v_artC, '__p5pr__', '__p5pr_h__', pg_temp.p5_detail()) returning id into v_mC;
    insert into public.artist_metrics (run_id, artist_id, rubric_version, rubric_hash, metrics_detail_json)
      values (v_runA, v_artD, '__p5pr__', '__p5pr_h__', pg_temp.p5_detail()) returning id into v_mD;

    -- metric input: coherent accepted; absent + other-run rejected
    insert into public.artist_metric_videos (artist_metric_id, run_id, video_id) values (v_metricA, v_runA, 'vidA');
    begin
      insert into public.artist_metric_videos (artist_metric_id, run_id, video_id) values (v_metricA, v_runA, 'nope');
      raise exception 'EMPIRICAL/F5-04: metric input absent from raw ACCEPTED';
    exception when foreign_key_violation then null; end;
    begin
      insert into public.artist_metric_videos (artist_metric_id, run_id, video_id) values (v_metricA, v_runA, 'vidB');
      raise exception 'EMPIRICAL/F5-04: metric input from another run ACCEPTED';
    exception when foreign_key_violation then null; end;

    insert into public.reports (run_id, title, rubric_version, rubric_hash) values (v_runA, 'Prov', '__p5pr__', '__p5pr_h__') returning id into v_report;
    insert into public.report_items (report_id, run_id, artist_id, artist_metric_id, rubric_version, rubric_hash, rank, selection_reason_json, example_video_id)
      values (v_report, v_runA, v_artist, v_metricA, '__p5pr__', '__p5pr_h__', 1, pg_temp.p5_reason(), 'vidA');
    insert into public.report_items (report_id, run_id, artist_id, artist_metric_id, rubric_version, rubric_hash, rank, selection_reason_json, example_video_id)
      values (v_report, v_runA, v_artB, v_mB, '__p5pr__', '__p5pr_h__', 2, pg_temp.p5_reason(), null);
    begin
      insert into public.report_items (report_id, run_id, artist_id, artist_metric_id, rubric_version, rubric_hash, rank, selection_reason_json, example_video_id)
        values (v_report, v_runA, v_artC, v_mC, '__p5pr__', '__p5pr_h__', 3, pg_temp.p5_reason(), 'nope');
      raise exception 'EMPIRICAL/F5-04: Example absent from raw ACCEPTED';
    exception when foreign_key_violation then null; end;
    begin
      insert into public.report_items (report_id, run_id, artist_id, artist_metric_id, rubric_version, rubric_hash, rank, selection_reason_json, example_video_id)
        values (v_report, v_runA, v_artD, v_mD, '__p5pr__', '__p5pr_h__', 4, pg_temp.p5_reason(), 'vidB');
      raise exception 'EMPIRICAL/F5-04: Example from another run ACCEPTED';
    exception when foreign_key_violation then null; end;
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- F5-05A / F5-06A — Evidence is STRUCTURAL, not just NOT NULL. {} and missing sections
-- rejected (check_violation); complete fixture accepted; versions + replayable overrides
-- with natural key are mandatory.
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_run uuid; v_artist uuid; v_metric uuid; v_report uuid;
          v_no_versions jsonb; v_bad_override jsonb; v_ok_override jsonb;
  begin
    insert into public.report_runs (window_start, window_end) values (now() - interval '30 days', now()) returning id into v_run;
    insert into public.artists (canonical_name) values ('P5 Ev') returning id into v_artist;
    insert into public.rubric_versions (version, config_json, hash) values ('__p5ev__', '{}', '__p5ev_h__');

    -- NULL evidence -> NOT NULL (or CHECK); {} -> CHECK (NOT NULL passes, structure fails)
    begin
      insert into public.artist_metrics (run_id, artist_id, rubric_version, rubric_hash, metrics_detail_json)
        values (v_run, v_artist, '__p5ev__', '__p5ev_h__', null);
      raise exception 'EMPIRICAL/F5-05A: artist_metrics with NULL detail ACCEPTED';
    exception when not_null_violation or check_violation then null; end;
    begin
      insert into public.artist_metrics (run_id, artist_id, rubric_version, rubric_hash, metrics_detail_json)
        values (v_run, v_artist, '__p5ev__', '__p5ev_h__', '{}'::jsonb);
      raise exception 'EMPIRICAL/F5-05A: artist_metrics with {} detail ACCEPTED (NOT NULL is not evidence)';
    exception when check_violation then null; end;

    -- F5-06A: complete EXCEPT missing "versions" -> rejected
    v_no_versions := pg_temp.p5_detail() - 'versions';
    begin
      insert into public.artist_metrics (run_id, artist_id, rubric_version, rubric_hash, metrics_detail_json)
        values (v_run, v_artist, '__p5ev__', '__p5ev_h__', v_no_versions);
      raise exception 'EMPIRICAL/F5-06A: artist_metrics missing versions section ACCEPTED';
    exception when check_violation then null; end;

    -- F5-06A: override missing the natural key (run_id + video_id|channel_id) -> rejected
    v_bad_override := jsonb_set(pg_temp.p5_detail(), '{overrides}', '[{"decision":"keep"}]'::jsonb);
    begin
      insert into public.artist_metrics (run_id, artist_id, rubric_version, rubric_hash, metrics_detail_json)
        values (v_run, v_artist, '__p5ev__', '__p5ev_h__', v_bad_override);
      raise exception 'EMPIRICAL/F5-06A: override missing natural key ACCEPTED';
    exception when check_violation then null; end;

    -- F5-06A: override WITH natural key -> accepted
    v_ok_override := jsonb_set(pg_temp.p5_detail(), '{overrides}',
      jsonb_build_array(jsonb_build_object('run_id', v_run::text, 'video_id', 'v1', 'decision', 'keep')));
    insert into public.artist_metrics (run_id, artist_id, rubric_version, rubric_hash, metrics_detail_json)
      values (v_run, v_artist, '__p5ev__', '__p5ev_h__', v_ok_override) returning id into v_metric;

    -- report_items: {} reason rejected; complete accepted
    insert into public.reports (run_id, title, rubric_version, rubric_hash) values (v_run, 'Ev', '__p5ev__', '__p5ev_h__') returning id into v_report;
    begin
      insert into public.report_items (report_id, run_id, artist_id, artist_metric_id, rubric_version, rubric_hash, rank, selection_reason_json)
        values (v_report, v_run, v_artist, v_metric, '__p5ev__', '__p5ev_h__', 1, '{}'::jsonb);
      raise exception 'EMPIRICAL/F5-05A: report_items with {} reason ACCEPTED';
    exception when check_violation then null; end;
    insert into public.report_items (report_id, run_id, artist_id, artist_metric_id, rubric_version, rubric_hash, rank, selection_reason_json)
      values (v_report, v_run, v_artist, v_metric, '__p5ev__', '__p5ev_h__', 1, pg_temp.p5_reason());
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- F5-06 — Rebuild input versions mandatory in the working set:
-- channel_eligibility.rule_version + video_artist_mappings.resolver_version NOT NULL.
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_run uuid; v_artist uuid;
  begin
    insert into public.report_runs (window_start, window_end) values (now() - interval '30 days', now()) returning id into v_run;
    insert into public.artists (canonical_name) values ('P5 Ver') returning id into v_artist;
    insert into public.raw_youtube_videos (run_id, video_id, channel_id, raw_json) values (v_run, 'vv', 'cc', '{}');
    insert into public.raw_youtube_channels (run_id, channel_id, raw_json) values (v_run, 'cc', '{}');

    begin
      insert into public.channel_eligibility (run_id, channel_id, is_eligible) values (v_run, 'cc', true);
      raise exception 'EMPIRICAL/F5-06: channel_eligibility without rule_version ACCEPTED';
    exception when not_null_violation then null; end;
    insert into public.channel_eligibility (run_id, channel_id, is_eligible, rule_version) values (v_run, 'cc', true, 'rule_v1');

    begin
      insert into public.video_artist_mappings (run_id, video_id, artist_id, method) values (v_run, 'vv', v_artist, 'regex');
      raise exception 'EMPIRICAL/F5-06: video_artist_mappings without resolver_version ACCEPTED';
    exception when not_null_violation then null; end;
    insert into public.video_artist_mappings (run_id, video_id, artist_id, method, resolver_version) values (v_run, 'vv', v_artist, 'regex', 'resolver_v1');
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- Uniqueness — (run_id, artist_id, rubric_hash); (report_id, rank); junction pk.
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_run uuid; v_artist uuid; v_metric uuid; v_report uuid;
  begin
    insert into public.report_runs (window_start, window_end) values (now() - interval '30 days', now()) returning id into v_run;
    insert into public.artists (canonical_name) values ('P5 Uniq') returning id into v_artist;
    insert into public.rubric_versions (version, config_json, hash) values ('__p5u__', '{}', '__p5u_h__');
    insert into public.raw_youtube_videos (run_id, video_id, channel_id, raw_json) values (v_run, 'vu', 'cu', '{}');
    insert into public.artist_metrics (run_id, artist_id, rubric_version, rubric_hash, metrics_detail_json)
      values (v_run, v_artist, '__p5u__', '__p5u_h__', pg_temp.p5_detail()) returning id into v_metric;

    begin
      insert into public.artist_metrics (run_id, artist_id, rubric_version, rubric_hash, metrics_detail_json)
        values (v_run, v_artist, '__p5u__', '__p5u_h__', pg_temp.p5_detail());
      raise exception 'EMPIRICAL/uniqueness: duplicate (run_id, artist_id, rubric_hash) ACCEPTED';
    exception when unique_violation then null; end;

    insert into public.artist_metric_videos (artist_metric_id, run_id, video_id) values (v_metric, v_run, 'vu');
    begin
      insert into public.artist_metric_videos (artist_metric_id, run_id, video_id) values (v_metric, v_run, 'vu');
      raise exception 'EMPIRICAL/uniqueness: duplicate artist_metric_videos pk ACCEPTED';
    exception when unique_violation then null; end;

    insert into public.reports (run_id, title, rubric_version, rubric_hash) values (v_run, 'Uniq', '__p5u__', '__p5u_h__') returning id into v_report;
    insert into public.report_items (report_id, run_id, artist_id, artist_metric_id, rubric_version, rubric_hash, rank, selection_reason_json)
      values (v_report, v_run, v_artist, v_metric, '__p5u__', '__p5u_h__', 1, pg_temp.p5_reason());
    begin
      insert into public.report_items (report_id, run_id, artist_id, artist_metric_id, rubric_version, rubric_hash, rank, selection_reason_json)
        values (v_report, v_run, v_artist, v_metric, '__p5u__', '__p5u_h__', 1, pg_temp.p5_reason());
      raise exception 'EMPIRICAL/uniqueness: duplicate (report_id, rank) ACCEPTED';
    exception when unique_violation then null; end;
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- Reproducibility FK — artist_metrics + reports must point to a real (version,hash).
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_run uuid; v_artist uuid;
  begin
    insert into public.report_runs (window_start, window_end) values (now() - interval '30 days', now()) returning id into v_run;
    insert into public.artists (canonical_name) values ('P5 Rubric') returning id into v_artist;
    begin
      insert into public.artist_metrics (run_id, artist_id, rubric_version, rubric_hash, metrics_detail_json)
        values (v_run, v_artist, '__unknown__', '__unknown_h__', pg_temp.p5_detail());
      raise exception 'EMPIRICAL/rubric-fk: artist_metrics with unknown (version,hash) ACCEPTED';
    exception when foreign_key_violation then null; end;
    begin
      insert into public.reports (run_id, title, rubric_version, rubric_hash)
        values (v_run, 'bad', '__unknown__', '__unknown_h__');
      raise exception 'EMPIRICAL/rubric-fk: reports with unknown (version,hash) ACCEPTED';
    exception when foreign_key_violation then null; end;
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- Provenance to raw (mappings) — (run_id, video_id) must exist in raw.
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_run uuid; v_artist uuid;
  begin
    insert into public.report_runs (window_start, window_end) values (now() - interval '30 days', now()) returning id into v_run;
    insert into public.artists (canonical_name) values ('P5 Raw') returning id into v_artist;
    insert into public.raw_youtube_videos (run_id, video_id, channel_id, raw_json) values (v_run, 'vid_ok', 'chan_ok', '{}');
    insert into public.video_artist_mappings (run_id, video_id, artist_id, method, resolver_version) values (v_run, 'vid_ok', v_artist, 'regex', 'resolver_v1');
    begin
      insert into public.video_artist_mappings (run_id, video_id, artist_id, method, resolver_version) values (v_run, 'vid_missing', v_artist, 'regex', 'resolver_v1');
      raise exception 'EMPIRICAL/raw-fk: mapping of a video absent from raw ACCEPTED';
    exception when foreign_key_violation then null; end;
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- F5-07 — No global freeze on the 3 COMPUTED tables (EMPIRICAL).
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_run uuid; v_artist uuid; v_map uuid; v_elig uuid; v_metric uuid;
  begin
    insert into public.report_runs (window_start, window_end) values (now() - interval '30 days', now()) returning id into v_run;
    insert into public.artists (canonical_name) values ('P5 NoFreeze') returning id into v_artist;
    insert into public.rubric_versions (version, config_json, hash) values ('__p5nf__', '{}', '__p5nf_h__');
    insert into public.raw_youtube_videos (run_id, video_id, channel_id, raw_json) values (v_run, 'vnf', 'cnf', '{}');
    insert into public.raw_youtube_channels (run_id, channel_id, raw_json) values (v_run, 'cnf', '{}');

    insert into public.video_artist_mappings (run_id, video_id, artist_id, method, resolver_version) values (v_run, 'vnf', v_artist, 'regex', 'resolver_v1') returning id into v_map;
    insert into public.channel_eligibility (run_id, channel_id, is_eligible, rule_version) values (v_run, 'cnf', true, 'rule_v1') returning id into v_elig;
    insert into public.artist_metrics (run_id, artist_id, rubric_version, rubric_hash, metrics_detail_json)
      values (v_run, v_artist, '__p5nf__', '__p5nf_h__', pg_temp.p5_detail()) returning id into v_metric;

    update public.video_artist_mappings set needs_review = true where id = v_map;   -- OK
    update public.channel_eligibility   set reason = 'recheck' where id = v_elig;   -- OK
    update public.artist_metrics        set final_score = 55 where id = v_metric;   -- OK (non-published)
    delete from public.video_artist_mappings where id = v_map;                      -- OK
    delete from public.channel_eligibility   where id = v_elig;                     -- OK
    delete from public.artist_metrics        where id = v_metric;                   -- OK (unreferenced)
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- Default-deny — anon + authenticated have ZERO access to the 6 tables.
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare rol text; t text;
  begin
    foreach rol in array array['anon', 'authenticated'] loop
      foreach t in array array['video_artist_mappings', 'channel_eligibility', 'artist_metrics',
                               'artist_metric_videos', 'reports', 'report_items'] loop
        begin
          perform set_config('role', rol, true);
          execute format('select 1 from public.%I limit 1', t);
          raise exception 'EMPIRICAL/default-deny: role % could query public.% (expected permission denied)', rol, t;
        exception
          when insufficient_privilege then null;
        end;
      end loop;
    end loop;
  end $$;
rollback;

\echo 'OK — Phase 5 post-apply verification PASSED (§4 structural + §5 empirical).'
