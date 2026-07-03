# Handoff — [DB] Fase 4 Design (Raw YouTube Snapshots) · Database Agent

> ✅ **RESOLVIDO — APLICADO E VERIFICADO (2026-06-27).** As revisões pendentes do §11 baixaram
> (**SEC-0012** Security #3 · **DATA-AI-0004** Data/AI #4 · **SEC-0013** pipeline #8) e o apply
> gated rodou verde em CI a partir de `main` (run `28277270507`, reviewer AdeptLabsDev). Evidência
> canônica e ratificação repo-side em **`HANDOFF-phase4-apply-closeout.md`**. Não leia o estado
> `needs_review`/⏳ abaixo como atual. Fase 9 (RLS Policies, SEC-0001 §0) **não** foi destravada.

## 1. Identificação
- **Tarefa:** `task_phase4_design_raw_snapshots` · **Action:** `design_schema` (não-sensível; apply gated)
- **Owner agent:** Database (`database_agent`)
- **Data:** 2026-06-26
- **Predecessora:** Fase 3 (runs + artists) aplicada — `report_runs` é a âncora de proveniência do raw (DEC-0009).
- **Fontes:** `migration-plan.md §Fase 4` · `04_…§4` · `mvp-data-model.md` Grupo C + §"Separação Raw/Computed/Snapshot" · `SEC-0001` (SEC-D03/F01/F08/F13/F16) · padrão Fases 1–3.

## 2. Objetivo
Autorar o **DDL concreto (não aplicado) + rollback + verify** das 3 tabelas RAW — `raw_youtube_search_pages`, `raw_youtube_videos`, `raw_youtube_channels` — fonte última de todo número e base reconstruível do computed (Fase 5). **Forward-only, atômica.** Apply permanece gated (CI: humano + required reviewers + verify fail-closed), espelhando Fases 1–3.

## 3. Critério de aceite (do backlog [DB] Tabelas raw)
> recoleta cria novo `run_id`; nenhuma rota de update em raw; trigger barra UPDATE/DELETE até via service-role.

## 4. Diff de schema (forward migration)
`supabase/migrations/20260620000004_phase4_raw_youtube_snapshots.sql`:

```text
+ function public.raw_youtube_immutable()    set search_path=''  -- UPDATE/DELETE bloqueados (restrict_violation)
+ function public.raw_youtube_no_truncate()  set search_path=''  -- TRUNCATE bloqueado (restrict_violation)
+ table public.raw_youtube_search_pages(
+   id uuid pk, run_id uuid fk->report_runs ON DELETE RESTRICT, page_token text null,
+   response_json jsonb NOT NULL, fetched_at,
+   check no_request_context (not response_json ?| {config,request,headers,authorization,key})  -- SEC-F08
+ )  unique index (run_id, coalesce(page_token,''))   -- chave lógica de página
+ table public.raw_youtube_videos(
+   id uuid pk, run_id fk->report_runs ON DELETE RESTRICT, video_id text NOT NULL, channel_id text NOT NULL,
+   title, published_at, views/likes/comments bigint null, raw_json jsonb NOT NULL, fetched_at,
+   check no_request_context (… SEC-F08)
+ )  unique index (run_id, video_id);  index (run_id, channel_id)
+ table public.raw_youtube_channels(
+   id uuid pk, run_id fk->report_runs ON DELETE RESTRICT, channel_id text NOT NULL, title,
+   upload_count/subscriber_count/view_count bigint null, raw_json jsonb NOT NULL, fetched_at,
+   check no_request_context (… SEC-F08)
+ )  unique index (run_id, channel_id)
+ trigger <table>_immutable    (before update or delete, row)       × 3 tabelas
+ trigger <table>_no_truncate  (before truncate, statement)         × 3 tabelas
+ enable row level security  (as 3)   -- default-deny
+ revoke all … from anon, authenticated  (as 3)
```

### Mapa requisito (payload) → SQL
| Constraint do payload | Onde no SQL |
|---|---|
| **Raw SAGRADO — imutabilidade por TRIGGER (SEC-D03/F16), não só grants/RLS (service_role bypassa RLS, SEC-F01)** | 2 funções `raw_youtube_immutable()`/`raw_youtube_no_truncate()` + 6 triggers (`before update or delete` row · `before truncate` statement) nas 3 tabelas. Barram abaixo do service_role. |
| Unicidade lógica `(run_id, video_id)` / `(run_id, channel_id)` + chave lógica de página | `..._run_video_uidx`, `..._run_channel_uidx`, `..._run_page_uidx` em `(run_id, coalesce(page_token,''))` |
| FK → `report_runs(run_id)`; recoleta = novo `run_id` | `run_id … references public.report_runs(id) on delete restrict` nas 3; sem rota de update ⇒ nova coleta só por novo run |
| **Scrub de contexto/secret no payload — SEC-F08, verificável no schema** | CHECK `*_no_request_context` rejeita envelope de transport (`config/request/headers/authorization/key` no topo) + ausência deliberada de qualquer coluna de request/URL/key |
| RLS ENABLE + default-deny; zero grant a anon/authenticated; revoke explícito (SEC-F13/F02) | `enable row level security` + `revoke all … from anon, authenticated` nas 3; nenhuma `create policy` |
| Reprodutibilidade: raw é a fonte; computed (Fase 5) reconstrói daqui | `raw_json`/`response_json` verbatim NOT NULL; ancorado por `run_id`; sem mutação ⇒ fonte estável |
| NÃO aplicar; NÃO destravar Fase 9 | `begin/commit` autorado, sem `change_db_schema/run_migration`; zero policy RLS (Fase 9 segue vetada, SEC-0001 §0) |

## 5. Verify §4/§5 (`phase4_post_apply_verify.sql`, paridade exata com Fases 1–3)
- **§4 estrutural:** 3 tabelas; 2 funções de imutabilidade `search_path`-pinned; **6 triggers** (2/tabela); 3 índices de unicidade lógica; **3 FKs** para `report_runs`; **3 CHECKs SEC-F08**; RLS-on nas 3.
- **§5 empírico (fail-closed, `ON_ERROR_STOP=1`, probes sempre revertidos):**
  - **Imutabilidade nas 3 tabelas, nos 2 caminhos de role** — lição DEC-0009 já embutida:
    - como **postgres (grant-holder):** `UPDATE`/`DELETE`/`TRUNCATE` = **`restrict_violation`** (prova positiva de que o **trigger** impõe a imutabilidade — não a ausência de grant; **SEC-F22**).
    - como **service_role:** `UPDATE`/`DELETE`/`TRUNCATE` = **`restrict_violation` OR `insufficient_privilege`** ("trigger ou grant"; **SEC-F21**, idêntico ao idiom phase1/2/3 pós-hotfix — sem falso-negativo).
  - **SEC-F08:** corpo de resposta limpo é **ACEITO** (raw verbatim, sem falso-positivo); payload com contexto de request (`config`/`request.headers.authorization`/`key`) é **REJEITADO** (`check_violation`) — scrub provado no schema.
  - **Unicidade lógica:** `(run_id, video_id)` duplicado = `unique_violation`.
  - **Default-deny:** `anon`/`authenticated` = `insufficient_privilege` nas 3.

## 6. Decisões de modelagem (e por quê)
- **Imutabilidade TOTAL do raw (não por-coluna):** diferente de `report_runs` (freeze por-coluna, STATE mutável), o raw não tem STATE — `raw_youtube_immutable()` levanta exceção **incondicional** em qualquer UPDATE/DELETE. Recoleta nunca toca a linha; cria novo `run_id`. **Integridade do Database — Security ratifica no #3; imutabilidade do raw é o objeto da revisão Data/AI #4.**
- **Funções de trigger compartilhadas (DRY):** uma `raw_youtube_immutable()` (row) e uma `raw_youtube_no_truncate()` (statement) reusadas pelas 3 tabelas, em vez de 6 funções. Menos superfície, mesma garantia; `search_path=''` fixo (higiene).
- **SEC-F08 verificável no schema (CHECK + ausência de coluna):** o vetor concreto que o SEC-F08 nomeia é o **dump do envelope de request** (objeto axios/fetch traz `config.url` com `?key=` e `config.headers.Authorization`). O corpo legítimo do YouTube (`kind/etag/items/pageInfo/nextPageToken/…`) **nunca** tem `config/request/headers/authorization/key` no topo ⇒ o CHECK é **defesa-em-profundidade com zero falso-positivo** e não fere o "raw verbatim" (o que ele rejeita não é corpo de resposta, é transporte). A defesa primária é estrutural: **não existe coluna** para request/URL/key. **Honestidade:** o CHECK é top-level (não recursivo) — o scrub autoritativo (extrair o body) é responsabilidade do pipeline (Data/AI/Backend); um scan recursivo no insert teria custo e risco de falso-positivo e foi deliberadamente evitado.
- **Contadores em `bigint` (desvio consciente dos tipos "indicativos" do mvp-data-model):** `views`/`likes`/`comments`/`subscriber_count`/`view_count`/`upload_count` em `bigint`, não `int`. `int` (int32, máx 2.147.483.647) **estoura** em `viewCount` de vídeo viral e em `view_count` de canal grande — e Postgres dá **erro de overflow no insert**, falhando a coleta e corrompendo "a fonte última de todo número". `bigint` é correção, não preferência. Nullable: stats podem estar ocultas (`ausente ≠ zero`, regra explícita do canal estendida ao vídeo); `raw_json` é a verdade, as colunas são projeção de conveniência.
- **`ON DELETE RESTRICT` no FK para `report_runs`:** belt-and-suspenders — `report_runs` já é indeletável por trigger (Fase 3); o RESTRICT declara que raw nunca fica órfão de proveniência.
- **Chave de página `(run_id, coalesce(page_token,''))`:** a 1ª página tem `page_token` null; `unique` puro trataria cada null como distinto. O `coalesce` torna a 1ª página um slot único determinístico — idiom consistente com o `lower(...)` funcional da Fase 3.

## 7. Impacto raw/computed
- **Fecha a fundação RAW** da cadeia de proveniência: `report_items → artist_metrics(computed_from_video_ids, rubric_hash) → raw_youtube_videos → raw_youtube_search_pages`. Nenhum número público sem este rastro (`04_ §14`).
- **Habilita Fase 5 (computed):** `video_artist_mappings`/`channel_eligibility`/`artist_metrics` lerão o raw por `(run_id, video_id)` / `(run_id, channel_id)`; o índice `(run_id, channel_id)` em videos serve o join de elegibilidade.
- **Nenhum número gerado; nenhum raw coletado** (isto é design/DDL — coleta real é pipeline, pós-apply). O rubric 40/25/20/15 permanece intocado.

## 8. Rollback
`supabase/rollback/20260620000004_phase4_raw_youtube_snapshots.rollback.sql` — atômico, reversível: triggers (6) → funções (2) → tabelas (3). Fora de `migrations/`. **Ressalva raw sagrado:** em produção raw não se apaga; o rollback só é admissível para run(s) descartável(is) (teste / pré-coleta). `DROP TABLE` é DDL, não dispara os triggers (que barram só DML).

## 9. Impacto no escopo / não-negociáveis
- **MVP travado?** Sim. 3 tabelas RAW do `04_ §4`; **zero** marketplace/Fase 2 (`04_ §12`).
- **Não-negociáveis reforçados:** **raw imutável** (trigger abaixo do service_role), **proveniência** (`run_id`), **rastreabilidade** até `raw_youtube_videos`, **secrets fora de repo/log/payload** (SEC-F08 no schema).

## 10. Validação executada
- Estrutural: revisão linha a linha; verify em paridade com Fases 1–3; ordem de drop do rollback conferida (triggers→funções→tabelas).
- **Não executado:** nenhum apply (sem Postgres conectado; apply é gated). `git status` confirma só arquivos novos. A prova empírica das garantias roda no job `verify` pós-apply.

## 11. Revisões necessárias (⏳, nunca assumidas como ok)
- [x] **Database** — autor (este handoff).
- [ ] **Security** — **matrix #3** (`review_rls` sobre o SQL+verify): trigger de imutabilidade (SEC-D03) abaixo do service_role; SEC-F08 (scrub no CHECK); RLS default-deny + revoke (SEC-F13/F02); paridade de errcode no verify (SEC-F21/F22). **Gate de veto — silêncio ≠ aprovação.**
- [ ] **Data/AI** — **matrix #4** (imutabilidade do raw / reprodutibilidade): raw verbatim como fonte; computed reconstrói por `run_id`; ausência de qualquer rota de mutação; tipos/nulabilidade fiéis ao payload do YouTube.

## 12. Próximos passos / bloqueios
1. Security #3 (`review_rls`) + Data/AI #4 sobre o SQL/verify. Ajustes, se houver, voltam ao Database (autor).
2. Com liberações + gate humano + required reviewers, `run_migration` (gated) aplica a Fase 4 — espelhando Fases 1–3 (pipeline `phase4-db-apply.yml` a definir por DevOps; verify `phase4_post_apply_verify.sql` fail-closed).
3. Segue **Fase 5** (computed + resolução + relatório) na ordem do `migration-plan.md`.
- **Veto que continua de pé:** Fase 9 — RLS Policies (SEC-0001 §0). Esta fase **não** o destrava.
