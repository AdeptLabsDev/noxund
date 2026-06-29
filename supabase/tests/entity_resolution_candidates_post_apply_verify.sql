-- ============================================================================
-- NOXUND · entity_resolution_candidates — post-apply verification (DEC-0014)
-- ----------------------------------------------------------------------------
-- Run by CI immediately after `supabase db push` applies
--   supabase/migrations/20260620000006_entity_resolution_candidates.sql
-- Parity with supabase/tests/phase1_…_phase5_post_apply_verify.sql.
--
-- DESIGN-ONLY: autorado, NÃO aplicado. Roda no job `verify` quando o apply gated for
-- sequenciado. Exercita CONSTRAINTS, não o resolver (Data/AI engine).
--
-- NATUREZA: a tabela é uma FILA MUTÁVEL (staging) — NÃO snapshot, NÃO append-only. O verify
-- prova o que É garantido (default-deny nos 2 role-paths, proveniência por FK RESTRICT,
-- enum/status + default, dedup do pendente, CHECKs de versão/decisão) E prova explicitamente
-- a MUTABILIDADE (UPDATE pending→approved permitido) — sem fingir imutabilidade.
--
-- WHY EMPIRICAL: default-deny é a garantia de superfície; provada nos 2 caminhos (DEC-0009):
--   • as postgres (grant-holder): só FK/CHECK/unique barram (prova positiva — SEC-F22);
--   • as anon/authenticated: sem grant → insufficient_privilege (SEC-F21/F07).
--
-- CONTRACT: todo check RAISES on mismatch → `psql -v ON_ERROR_STOP=1` sai não-zero, falha o CI.
-- SIDE EFFECTS: nenhum persistido — toda escrita de probe vive em transação revertida.
-- Role: conecta como `postgres` do projeto (membro de anon/authenticated/service_role).
-- ============================================================================

\set ON_ERROR_STOP on

\echo '== entity_resolution_candidates · §4 structural verification =='

-- table present ---------------------------------------------------------------
do $$
begin
  if not exists (select 1 from information_schema.tables
     where table_schema = 'public' and table_name = 'entity_resolution_candidates') then
    raise exception 'STRUCT/table: entity_resolution_candidates missing';
  end if;
end $$;

-- enums: NEW entity_candidate_status (3) + REUSED video_artist_method (4, da Fase 5) ----
do $$
declare n int;
begin
  if not exists (select 1 from pg_type where typname = 'entity_candidate_status') then
    raise exception 'STRUCT/enum: entity_candidate_status missing';
  end if;
  select count(*) into n from pg_enum e join pg_type t on t.oid = e.enumtypid
   where t.typname = 'entity_candidate_status';
  if n <> 3 then raise exception 'STRUCT/enum: entity_candidate_status expected 3 labels, found %', n; end if;
  -- método é REUSADO (não recriado): precisa existir da Fase 5.
  if not exists (select 1 from pg_type where typname = 'video_artist_method') then
    raise exception 'STRUCT/enum: video_artist_method (reused) missing — Fase 5 não aplicada?';
  end if;
end $$;

-- mandated columns ------------------------------------------------------------
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values ('run_id'), ('video_id'), ('proposed_name'), ('artist_id'), ('method'),
                 ('resolver_version'), ('prompt_version'), ('status'), ('review_notes'),
                 ('reviewed_at'), ('created_at')) as t(want)
   where not exists (select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'entity_resolution_candidates' and column_name = t.want);
  if missing is not null then raise exception 'STRUCT/columns: missing: %', missing; end if;
end $$;

-- NOT NULL onde exigido; nullable onde a fila precisa (artist_id/prompt_version/reviewed_at) -
do $$
declare bad text;
begin
  select string_agg(column_name, ', ') into bad from information_schema.columns
   where table_schema = 'public' and table_name = 'entity_resolution_candidates'
     and column_name in ('run_id','video_id','proposed_name','method','resolver_version','status','created_at')
     and is_nullable <> 'NO';
  if bad is not null then raise exception 'STRUCT/not-null: must be NOT NULL: %', bad; end if;

  select string_agg(column_name, ', ') into bad from information_schema.columns
   where table_schema = 'public' and table_name = 'entity_resolution_candidates'
     and column_name in ('artist_id','prompt_version','reviewed_at')
     and is_nullable <> 'YES';
  if bad is not null then raise exception 'STRUCT/nullable: must be NULLABLE (queue staging): %', bad; end if;
end $$;

-- status default 'pending' ----------------------------------------------------
do $$
declare def text;
begin
  select column_default into def from information_schema.columns
   where table_schema = 'public' and table_name = 'entity_resolution_candidates' and column_name = 'status';
  if def is null or def not like '%pending%' then
    raise exception 'STRUCT/default: status default must be pending, got %', def;
  end if;
end $$;

-- named composite provenance FK → raw, columns + RESTRICT ---------------------
do $$
declare v_target regclass; v_deltype char; v_cols text;
begin
  select confrelid::regclass, confdeltype,
         (select string_agg(a.attname, ',' order by a.attname)
            from unnest(c.conkey) k join pg_attribute a on a.attrelid = c.conrelid and a.attnum = k)
    into v_target, v_deltype, v_cols
    from pg_constraint c where c.conname = 'entity_resolution_candidates_raw_video_fk' and c.contype = 'f';
  if not found then raise exception 'STRUCT/fk: entity_resolution_candidates_raw_video_fk missing'; end if;
  if v_target is distinct from 'public.raw_youtube_videos'::regclass then
    raise exception 'STRUCT/fk: raw_video_fk must target raw_youtube_videos, got %', v_target; end if;
  if v_deltype <> 'r' then raise exception 'STRUCT/fk: raw_video_fk must be ON DELETE RESTRICT, got %', v_deltype; end if;
  if v_cols <> 'run_id,video_id' then raise exception 'STRUCT/fk: raw_video_fk cols must be run_id,video_id, got %', v_cols; end if;
end $$;

-- FK to report_runs and to artists exist; ALL FKs are ON DELETE RESTRICT -------
do $$
declare n int; bad text;
begin
  select count(*) into n from pg_constraint
   where contype = 'f' and conrelid = 'public.entity_resolution_candidates'::regclass
     and confrelid = 'public.report_runs'::regclass;
  if n < 1 then raise exception 'STRUCT/fk: missing FK → report_runs'; end if;
  select count(*) into n from pg_constraint
   where contype = 'f' and conrelid = 'public.entity_resolution_candidates'::regclass
     and confrelid = 'public.artists'::regclass;
  if n < 1 then raise exception 'STRUCT/fk: missing FK → artists'; end if;

  select string_agg(conname, ', ') into bad from pg_constraint
   where contype = 'f' and conrelid = 'public.entity_resolution_candidates'::regclass and confdeltype <> 'r';
  if bad is not null then raise exception 'STRUCT/fk: non-RESTRICT ON DELETE: %', bad; end if;
end $$;

-- 4 CHECK constraints (llm prompt + reviewed_at + non-blank versions — DATA-ENTITY-F01) -------
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values ('entity_resolution_candidates_llm_prompt_chk'),
                 ('entity_resolution_candidates_reviewed_at_chk'),
                 ('entity_resolution_candidates_resolver_version_nonblank_chk'),
                 ('entity_resolution_candidates_prompt_version_nonblank_chk')) as t(want)
   where not exists (select 1 from pg_constraint where contype = 'c' and conname = t.want);
  if missing is not null then raise exception 'STRUCT/check: missing CHECK(s): %', missing; end if;
end $$;

-- indexes: pending dedup (UNIQUE+PARTIAL), pending queue (PARTIAL), run/status, artist ---
do $$
declare missing text;
begin
  select string_agg(want, ', ') into missing
    from (values
      ('entity_resolution_candidates_pending_uidx'),
      ('entity_resolution_candidates_pending_queue_idx'),
      ('entity_resolution_candidates_run_status_idx'),
      ('entity_resolution_candidates_artist_idx')
    ) as t(want)
   where not exists (select 1 from pg_indexes where schemaname = 'public' and indexname = t.want);
  if missing is not null then raise exception 'STRUCT/indexes: missing: %', missing; end if;
end $$;

-- pending dedup index must be UNIQUE and PARTIAL ------------------------------
do $$
declare r record;
begin
  select i.indisunique as uniq, (i.indpred is not null) as partial into r
    from pg_index i join pg_class c on c.oid = i.indexrelid
   where c.relname = 'entity_resolution_candidates_pending_uidx';
  if not found then raise exception 'STRUCT/dedup: pending dedup index missing'; end if;
  if not r.uniq then raise exception 'STRUCT/dedup: pending dedup index must be UNIQUE'; end if;
  if not r.partial then raise exception 'STRUCT/dedup: pending dedup index must be PARTIAL (WHERE status=pending)'; end if;
end $$;

-- MUTÁVEL por design: NENHUM trigger de imutabilidade na tabela ----------------
do $$
declare n int;
begin
  select count(*) into n from pg_trigger
   where not tgisinternal and tgrelid = 'public.entity_resolution_candidates'::regclass;
  if n <> 0 then
    raise exception 'STRUCT/mutable: expected ZERO user triggers (staging queue é mutável), found %', n;
  end if;
end $$;

-- RLS enabled + ZERO policies (Fase 9 vetada) ---------------------------------
do $$
declare n int;
begin
  if not exists (select 1 from pg_class where relnamespace = 'public'::regnamespace
     and relname = 'entity_resolution_candidates' and relrowsecurity = true) then
    raise exception 'STRUCT/rls: RLS not enabled';
  end if;
  select count(*) into n from pg_policies where schemaname = 'public' and tablename = 'entity_resolution_candidates';
  if n <> 0 then raise exception 'STRUCT/policy: expected ZERO policies, found %', n; end if;
end $$;

\echo '== entity_resolution_candidates · §5 empirical verification =='

-- ----------------------------------------------------------------------------
-- Provenance — FK composta (run_id, video_id) → raw rejeita vídeo ausente/de outro run;
-- artist_id nullable (candidato novo/desconhecido) é aceito.
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_run1 uuid; v_run2 uuid;
  begin
    insert into public.report_runs (window_start, window_end) values (now() - interval '30 days', now()) returning id into v_run1;
    insert into public.report_runs (window_start, window_end) values (now() - interval '60 days', now() - interval '31 days') returning id into v_run2;
    insert into public.raw_youtube_videos (run_id, video_id, channel_id, raw_json) values (v_run1, 'vidA', 'chA', '{}');
    insert into public.raw_youtube_videos (run_id, video_id, channel_id, raw_json) values (v_run2, 'vidB', 'chB', '{}');

    -- candidato coerente por regex (sem prompt) com artist_id NULL → aceito
    insert into public.entity_resolution_candidates (run_id, video_id, proposed_name, method, resolver_version)
      values (v_run1, 'vidA', 'Lil Example', 'regex', 'entity-resolver-v1');

    -- vídeo AUSENTE do raw → rejeitado
    begin
      insert into public.entity_resolution_candidates (run_id, video_id, proposed_name, method, resolver_version)
        values (v_run1, 'nope', 'X', 'regex', 'entity-resolver-v1');
      raise exception 'EMPIRICAL/provenance: candidate of a video absent from raw ACCEPTED';
    exception when foreign_key_violation then null; end;

    -- vídeo de OUTRO run → rejeitado (raw do run1 não tem vidB)
    begin
      insert into public.entity_resolution_candidates (run_id, video_id, proposed_name, method, resolver_version)
        values (v_run1, 'vidB', 'X', 'regex', 'entity-resolver-v1');
      raise exception 'EMPIRICAL/provenance: candidate of a video from another run ACCEPTED';
    exception when foreign_key_violation then null; end;
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- Status default + MUTABILIDADE + dedup do pendente (índice parcial único).
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_run uuid; v_c1 uuid; v_st public.entity_candidate_status;
  begin
    insert into public.report_runs (window_start, window_end) values (now() - interval '30 days', now()) returning id into v_run;
    insert into public.raw_youtube_videos (run_id, video_id, channel_id, raw_json) values (v_run, 'v1', 'c1', '{}');

    -- default 'pending' aplicado quando status omitido
    insert into public.entity_resolution_candidates (run_id, video_id, proposed_name, method, resolver_version)
      values (v_run, 'v1', 'Cand One', 'regex', 'entity-resolver-v1') returning id, status into v_c1, v_st;
    if v_st <> 'pending' then raise exception 'EMPIRICAL/default: status should default to pending, got %', v_st; end if;

    -- dedup: um segundo PENDING para o mesmo (run, vídeo) é rejeitado
    begin
      insert into public.entity_resolution_candidates (run_id, video_id, proposed_name, method, resolver_version)
        values (v_run, 'v1', 'Cand Two', 'regex', 'entity-resolver-v1');
      raise exception 'EMPIRICAL/dedup: second PENDING for same (run, video) ACCEPTED';
    exception when unique_violation then null; end;

    -- MUTÁVEL por design: resolver o pendente (pending→rejected) é permitido (prova positiva)
    update public.entity_resolution_candidates set status = 'rejected', reviewed_at = now() where id = v_c1;

    -- com o anterior resolvido, um NOVO pendente para o mesmo (run, vídeo) agora é aceito
    insert into public.entity_resolution_candidates (run_id, video_id, proposed_name, method, resolver_version)
      values (v_run, 'v1', 'Cand Three', 'regex', 'entity-resolver-v1');
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- CHECK de versão do prompt (llm exige prompt_version) e de carimbo de decisão.
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_run uuid;
  begin
    insert into public.report_runs (window_start, window_end) values (now() - interval '30 days', now()) returning id into v_run;
    insert into public.raw_youtube_videos (run_id, video_id, channel_id, raw_json) values (v_run, 'v1', 'c1', '{}');
    insert into public.raw_youtube_videos (run_id, video_id, channel_id, raw_json) values (v_run, 'v2', 'c1', '{}');

    -- llm_assisted SEM prompt_version → rejeitado
    begin
      insert into public.entity_resolution_candidates (run_id, video_id, proposed_name, method, resolver_version)
        values (v_run, 'v1', 'Amb', 'llm_assisted', 'entity-resolver-v1');
      raise exception 'EMPIRICAL/prompt-chk: llm_assisted without prompt_version ACCEPTED';
    exception when check_violation then null; end;
    -- llm_assisted COM prompt_version → aceito
    insert into public.entity_resolution_candidates (run_id, video_id, proposed_name, method, resolver_version, prompt_version)
      values (v_run, 'v1', 'Amb', 'llm_assisted', 'entity-resolver-v1', 'llm-fallback-v1');
    -- regex SEM prompt_version → aceito (CHECK só vale p/ llm)
    insert into public.entity_resolution_candidates (run_id, video_id, proposed_name, method, resolver_version)
      values (v_run, 'v2', 'Plain', 'regex', 'entity-resolver-v1');

    -- decisão sem carimbo: status approved com reviewed_at NULL → rejeitado
    begin
      insert into public.entity_resolution_candidates (run_id, video_id, proposed_name, method, resolver_version, status)
        values (v_run, 'v2', 'Dup', 'regex', 'entity-resolver-v1', 'approved');
      raise exception 'EMPIRICAL/reviewed-chk: approved without reviewed_at ACCEPTED';
    exception when check_violation then null; end;
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- DATA-ENTITY-F01 — versões NÃO podem ser em branco (NOT NULL não barra '' / só-espaços).
-- resolver_version blank → rejeitado; prompt_version blank (quando presente) → rejeitado;
-- non-blank válido e prompt_version NULL (regex determinístico) seguem aceitos (sem regressão).
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_run uuid;
  begin
    insert into public.report_runs (window_start, window_end) values (now() - interval '30 days', now()) returning id into v_run;
    insert into public.raw_youtube_videos (run_id, video_id, channel_id, raw_json) values (v_run, 'v1', 'c1', '{}');
    insert into public.raw_youtube_videos (run_id, video_id, channel_id, raw_json) values (v_run, 'v2', 'c1', '{}');
    insert into public.raw_youtube_videos (run_id, video_id, channel_id, raw_json) values (v_run, 'v3', 'c1', '{}');

    -- (a) resolver_version '' → rejeitado
    begin
      insert into public.entity_resolution_candidates (run_id, video_id, proposed_name, method, resolver_version)
        values (v_run, 'v1', 'Cand', 'regex', '');
      raise exception 'EMPIRICAL/F01: empty resolver_version ACCEPTED';
    exception when check_violation then null; end;
    -- (a') resolver_version só-espaços → rejeitado (btrim)
    begin
      insert into public.entity_resolution_candidates (run_id, video_id, proposed_name, method, resolver_version)
        values (v_run, 'v1', 'Cand', 'regex', '   ');
      raise exception 'EMPIRICAL/F01: whitespace resolver_version ACCEPTED';
    exception when check_violation then null; end;

    -- (b) prompt_version '' (presente porém em branco) → rejeitado, com method que o aceitaria (regex)
    begin
      insert into public.entity_resolution_candidates (run_id, video_id, proposed_name, method, resolver_version, prompt_version)
        values (v_run, 'v1', 'Cand', 'regex', 'entity-resolver-v1', '');
      raise exception 'EMPIRICAL/F01: empty prompt_version ACCEPTED';
    exception when check_violation then null; end;

    -- (c) resolver_version non-blank válido → aceito
    insert into public.entity_resolution_candidates (run_id, video_id, proposed_name, method, resolver_version)
      values (v_run, 'v1', 'Cand', 'regex', 'entity-resolver-v1');
    -- (d) prompt_version NULL em candidato regex → aceito (nullabilidade preservada; sem regressão)
    insert into public.entity_resolution_candidates (run_id, video_id, proposed_name, method, resolver_version, prompt_version)
      values (v_run, 'v2', 'Cand', 'regex', 'entity-resolver-v1', null);
    -- (d') prompt_version non-blank em candidato llm → aceito
    insert into public.entity_resolution_candidates (run_id, video_id, proposed_name, method, resolver_version, prompt_version)
      values (v_run, 'v3', 'Cand', 'llm_assisted', 'entity-resolver-v1', 'llm-fallback-v1');
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- Provenance RESTRICT até artists — artista resolvido referenciado não pode ser apagado.
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare v_run uuid; v_artist uuid;
  begin
    insert into public.report_runs (window_start, window_end) values (now() - interval '30 days', now()) returning id into v_run;
    insert into public.raw_youtube_videos (run_id, video_id, channel_id, raw_json) values (v_run, 'v1', 'c1', '{}');
    insert into public.artists (canonical_name) values ('ERC Artist') returning id into v_artist;

    insert into public.entity_resolution_candidates (run_id, video_id, proposed_name, artist_id, method, resolver_version)
      values (v_run, 'v1', 'ERC Artist', v_artist, 'regex', 'entity-resolver-v1');

    begin
      delete from public.artists where id = v_artist;
      raise exception 'EMPIRICAL/provenance: DELETE referenced artist SUCCEEDED';
    exception when foreign_key_violation or restrict_violation then null; end;
  end $$;
rollback;

-- ----------------------------------------------------------------------------
-- Default-deny — anon + authenticated têm ZERO acesso à fila.
-- ----------------------------------------------------------------------------
begin;
  do $$
  declare rol text;
  begin
    foreach rol in array array['anon', 'authenticated'] loop
      begin
        perform set_config('role', rol, true);
        perform 1 from public.entity_resolution_candidates limit 1;
        raise exception 'EMPIRICAL/default-deny: role % could query entity_resolution_candidates', rol;
      exception when insufficient_privilege then null; end;
    end loop;
  end $$;
rollback;

\echo 'OK — entity_resolution_candidates post-apply verification PASSED (§4 structural + §5 empirical).'
