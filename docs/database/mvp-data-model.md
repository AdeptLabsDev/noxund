# MVP Data Model — NOXUND Hotspot Artists Report

**Status:** proposta. Não é schema final. Não gerar migrations a partir deste documento sem revisão.
**Fonte de verdade:** `context/04_Database_Event_Model.md`. Onde este doc refina `04_`, está marcado como **Open question** / **OD-DB-NN**.

Cada tabela segue o template:

```md
## table_name
### Purpose
### Key fields
### Relationships
### Immutability rule
### Notes
### Open questions
```

Os campos listados são os **principais necessários para implementar depois**, não o DDL final. Tipos são indicativos (Postgres/Supabase).

Classes de imutabilidade (detalhadas em `entity-relationship-notes.md`):

- **RAW** — insert-only, sem `UPDATE`/`DELETE`.
- **EVENT** — append-only, sem mutação semântica.
- **COMPUTED** — reconstruível: pode ser apagado e recomputado por `run_id`, nunca editado à mão.
- **SNAPSHOT** — congelado após `published`.
- **STATE** — colunas de status mutáveis controladas por máquina de estados.

---

# Grupo A — Identidade & Acesso

## producers

### Purpose
Produtor (beatmaker) que pediu acesso e, se aprovado, consome os relatórios. Âncora de todos os eventos, follow-ups e WTP.

### Key fields
- `id uuid pk`
- `auth_user_id uuid unique null` — FK lógica → `auth.users.id` (Supabase Auth). Preenchido **só na aprovação**, por service-role, com `audit_events` (SEC-D01). **Não há** coluna de senha/hash aqui — identidade delegada ao Supabase Auth (SEC-F12).
- `email text` — único, normalizado (lowercase, trim). Idempotência de `/apply`.
- `display_name text`
- `youtube_url text` — canal principal declarado
- `portfolio_url text null`
- `niche text` — nicho declarado
- `status enum('pending','approved','rejected','blocked')`
- `created_at timestamptz`
- `approved_at timestamptz null`

### Relationships
- `1—N` `applications`, `producer_events`, `followups`, `wtp_responses`.

### Immutability rule
**STATE.** `status` muda por aprovação manual (admin). Transições válidas: `pending → approved | rejected | blocked`; `approved → blocked`. Toda transição deve gerar `audit_events` + `producer_events` correspondente.

### Notes
- PII: `email`, URLs. Nunca em log (`02_...` §9). Acesso só server/admin.
- `approved_at` preenchido só quando `status = approved`.
- `auth_user_id` é provisionado no momento da **aprovação** (convite/magic-link), nunca no `/apply` — `/apply` é anônimo (SEC-D01/SEC-F02). Isso evita inflar `auth.users` com aplicantes/spam e fechar a enumeração de quem aplicou.

### Open questions
- **OD-DB-08 — RESOLVIDO (SEC-D01):** identidade via `auth_user_id uuid unique null` (FK lógica → `auth.users`), **não** `producers.id = auth.uid()`. RLS de produtor usa `auth_user_id = auth.uid()`. Sem hash de senha em `producers`. Detalhe e justificativa em `docs/security/SEC-0001-mvp-data-model-review.md`.
- Magic-link vs senha permanece detalhe de OD-02 (Auth); não afeta o schema (identidade no Supabase Auth).

---

## applications

*(tarefa: `producer_applications`)*

### Purpose
Registro de uma aplicação de acesso, com as respostas de decisão e o veredito manual do admin. Suporta o approval gate (`02_...` §9, backlog [DB] Schema base).

### Key fields
- `id uuid pk`
- `producer_id uuid fk → producers.id`
- `decision_process_answer text` — "como decide artistas hoje"
- `intent_answer text` — abertura a usar sinais
- `status enum('submitted','under_review','approved','rejected')`
- `reviewed_by uuid null` — admin (auth user)
- `review_notes text null` — motivo da decisão
- `created_at timestamptz`
- `reviewed_at timestamptz null`

### Relationships
- `N—1` `producers`.
- O veredito da aplicação reflete em `producers.status` (não duplicar verdade: a aplicação registra o **processo**; `producers.status` é o **estado efetivo**).

### Immutability rule
**STATE.** `status` evolui `submitted → under_review → approved | rejected`. `review_notes`/`reviewed_*` preenchidos na decisão. Decisão registrada em `audit_events`.

### Notes
- Idempotência: uma aplicação ativa por `producer_id` (ou por email). Reaplicar não deve sobrescrever histórico — preferir nova linha + `audit_events`.
- Eventos `application_submitted` / `application_approved` vão para `producer_events`.

### Open questions
- Permitir múltiplas aplicações por produtor (histórico) ou única? **Recomendação:** múltiplas (append), com índice parcial garantindo no máximo uma `submitted|under_review` por produtor.

---

## admin_users

*(NOVO — controle de segurança decidido pelo Security, SEC-D02. Aditivo às 19 tabelas; **não** é Fase 2/marketplace.)*

### Purpose
Fonte **única e controlada por service-role** de quem é admin. Lastreia o helper `is_admin()` (`SECURITY DEFINER`) usado nas policies RLS. Existe porque derivar admin de `user_metadata` (editável pelo próprio usuário no Supabase) seria escalonamento de privilégio crítico (SEC-D02).

### Key fields
- `id uuid pk`
- `auth_user_id uuid unique` — → `auth.users.id` do admin
- `granted_by uuid null` — admin que concedeu (auditável)
- `created_at timestamptz`
- `revoked_at timestamptz null` — revogação imediata sem depender de refresh de JWT

### Relationships
- Liga-se logicamente a `auth.users`. Consultada por `is_admin()` em todas as policies que exigem admin.

### Immutability rule
**STATE controlado.** Grant/revoke só por service-role/admin, **sempre** registrando `audit_events`. `revoked_at` desativa sem apagar histórico.

### Notes
- `is_admin()` é `SECURITY DEFINER` e checa `auth_user_id = auth.uid() AND revoked_at IS NULL`.
- Alternativa permitida por Security: `app_metadata.role` (server-controlado). **Nunca** `user_metadata`.
- É controle de acesso, não produto — registrar no escopo como tabela de segurança (passa a contagem a **20 tabelas**).

### Open questions
- Único nível `admin` no MVP ou já prever `role`/escopos? **Recomendação:** booleano implícito (presença = admin) no MVP; adicionar `role` só com necessidade real.

---

# Grupo B — Versionamento (pré-requisito de computed)

## rubric_versions

### Purpose
Versão imutável da fórmula de Score (pesos 40/25/20/15) e suas constantes. Todo `artist_metrics` e todo `report_run` apontam para uma versão. Base da reprodutibilidade (`03_...` §7, §12).

### Key fields
- `id uuid pk`
- `version text` — ex.: `score_rubric_2026_06_v1` (único)
- `config_json jsonb` — pesos, normalização, thresholds de Competition/HOT/Score-display
- `hash text` — hash determinístico de `config_json` (igual a `rubric_hash` usado no pipeline)
- `active_from timestamptz`
- `created_at timestamptz`

### Relationships
- `1—N` `report_runs`, `artist_metrics` (via `rubric_version` + `rubric_hash`).

### Immutability rule
**EVENT/immutable.** Nunca editar uma versão publicada. Mudança de pesos = **nova linha** (`...v2`). Editar in-place quebraria a auditoria de relatórios já congelados.

### Notes
- `hash` é a âncora: dois relatórios com mesmo snapshot + mesmo `hash` devem ser idênticos.
- Mudança aqui dispara revisão **Product Orchestrator + Data/AI + QA** (matriz #5).

### Open questions
- Guardar `rubric_version` como FK (`uuid`) ou como string textual (como `04_`)? **Recomendação:** manter a string `version` + `hash` denormalizados em `artist_metrics`/`report_runs` (auditoria legível) e opcionalmente uma FK para joins.

---

## outcome_weight_versions

### Purpose
Versão de pesos usados em **análise futura** de `producer_outcomes` (não em produto, não no Score). Evita pesos hardcoded em eventos (`04_...` §11).

### Key fields
- `id uuid pk`
- `version text` — ex.: `outcome_weights_v1`
- `config_json jsonb`
- `created_at timestamptz`

### Relationships
- Nenhuma FK direta no MVP; referenciada por queries analíticas.

### Immutability rule
**EVENT/immutable.** Append-only; nova versão = nova linha.

### Notes
- Não usar para alterar Score nem exibição. É metadado analítico.

### Open questions
- Pode ficar vazia no MVP (sem análise ponderada ainda). Manter por simetria com `rubric_versions`? **Recomendação:** criar tabela, popular só quando houver análise real.

---

# Grupo C — Coleta & Raw (imutável)

> OD-DB-01 (fechado por DEC-0003 + Data/AI): manter `report_runs` unificado no MVP. A independência snapshot/rubric fica preservada porque o RAW é ancorado por `run_id` e cada linha de `artist_metrics` carrega seu próprio `rubric_version`/`rubric_hash`. Re-score do mesmo raw sob novo rubric recompõe `artist_metrics` no mesmo `run_id`, sem split, com chave lógica `(run_id, artist_id, rubric_hash)`.

## report_runs

*(tarefa: `youtube_collection_runs`. Ver OD-DB-01.)*

### Purpose
Uma rodada de coleta/processamento. Âncora de toda proveniência: todo raw, computed e report aponta para um `run_id` (`04_...` §4).

### Key fields
- `id uuid pk` — o `run_id`
- `keyword text` — travado em `chicago drill type beat`
- `vertical text` — `Chicago Drill`
- `window_start timestamptz`, `window_end timestamptz` — janela de 30d
- `target_video_count int` (~500), `collected_video_count int`
- `youtube_quota_used int`
- `status enum('created','collecting','processed','published','failed')`
- `rubric_version text`, `rubric_hash text` — versão usada no scoring publicado/default desta run; a proveniência por célula vive em `artist_metrics.rubric_hash`
- `created_at timestamptz`

### Relationships
- `1—N` `raw_youtube_search_pages`, `raw_youtube_videos`, `raw_youtube_channels`, `video_artist_mappings`, `channel_eligibility`, `artist_metrics`, `reports`.

### Immutability rule
**STATE** apenas para `status` e contadores de progresso da coleta. `keyword` e `window_*` são **imutáveis após `collecting`**. O conjunto raw associado nunca muda; recoleta = **novo `run_id`**. `rubric_version`/`rubric_hash` em `report_runs` não substituem a proveniência por célula em `artist_metrics`.

### Notes
- `keyword`/janela travados pelo escopo (`scope-guardrails`). Mudança → revisão PO + Data/AI.
- Split `collection_runs`/`scoring_runs` fica fora do MVP. Se um fluxo futuro exigir múltiplas tentativas de scoring com orquestração própria, reabrir via nova DEC sem quebrar `run_id`.

### Open questions
- **OD-DB-01 — RESOLVIDO (DEC-0003 + DATA-AI-0001):** `report_runs` unificado no MVP. Re-score usa o mesmo `run_id` e novo `rubric_hash` em `artist_metrics`; sem split agora.

---

## raw_youtube_search_pages

### Purpose
Payload bruto de cada página de `search.list` (paginação por `page_token`). Permite reconstruir exatamente quais vídeos a busca retornou (`04_...` §4, `03_...` §3).

### Key fields
- `id uuid pk`
- `run_id uuid fk → report_runs.id`
- `page_token text null` — token usado (null = 1ª página)
- `response_json jsonb` — payload bruto verbatim
- `fetched_at timestamptz`

### Relationships
- `N—1` `report_runs`.

### Immutability rule
**RAW.** Insert-only. **Trigger `BEFORE UPDATE/DELETE` que levanta exceção é obrigatório** (SEC-D03) — grants/RLS não bastam, pois `service_role` faz **bypass de RLS** (SEC-F01).

### Notes
- Auditoria da coleta exigida por `03_...` §3 (query exata, page tokens, total).
- Pode ser volumoso; ainda assim guardar verbatim.

### Open questions
- Reter `response_json` completo ou só campos auditáveis? **Recomendação:** completo no MVP (volume baixo, 2 relatórios). Reavaliar custo na Fase 2.

---

## raw_youtube_videos

*(tarefa: `youtube_video_snapshots`)*

### Purpose
Snapshot bruto e imutável de cada vídeo coletado (estatísticas + snippet). **Fonte última de todo número exibido** (`04_...` §4, `02_...` §8).

### Key fields
- `id uuid pk`
- `run_id uuid fk → report_runs.id`
- `video_id text` — id YouTube
- `channel_id text`
- `title text` — título bruto (fonte da Entity Resolution)
- `published_at timestamptz`
- `views int`, `likes int`, `comments int` — raw
- `raw_json jsonb` — payload completo verbatim
- `fetched_at timestamptz`

### Relationships
- `N—1` `report_runs`.
- Referenciado por `video_artist_mappings.video_id`, `artist_metrics.computed_from_video_ids[]`, `report_items.example_video_id`.

### Immutability rule
**RAW.** Insert-only. Recoleta cria novo snapshot sob novo `run_id` — **nunca sobrescrever a linha** (`04_...` §4 "Regra"). **Trigger `BEFORE UPDATE/DELETE` obrigatório** (SEC-D03): a imutabilidade do raw sagrado precisa estar **abaixo** do service-role, que faz bypass de RLS (SEC-F01).

### Notes
- Unicidade lógica: `(run_id, video_id)`. O mesmo `video_id` pode reaparecer em outra run com outro snapshot — isso é esperado e desejado.
- Sem rota de `UPDATE` em hipótese alguma (DoD do Database Agent).

### Open questions
- Guardar `thumbnails`/`url` em colunas ou só dentro de `raw_json`? **Recomendação:** derivar de `raw_json` quando exibir; não duplicar.

---

## raw_youtube_channels

*(tarefa: `youtube_channel_snapshots`)*

### Purpose
Snapshot bruto de canais (histórico de uploads, inscritos, views) usado pelo Channel Filter para elegibilidade e contagem de canais distintos (`04_...` §4, `03_...` §6).

### Key fields
- `id uuid pk`
- `run_id uuid fk → report_runs.id`
- `channel_id text`
- `title text`
- `upload_count int`, `subscriber_count int null`, `view_count int null`
- `raw_json jsonb`
- `fetched_at timestamptz`

### Relationships
- `N—1` `report_runs`.
- Consumida por `channel_eligibility`.

### Immutability rule
**RAW.** Insert-only. Unicidade lógica `(run_id, channel_id)`. **Trigger `BEFORE UPDATE/DELETE` obrigatório** (SEC-D03) — service-role faz bypass de RLS (SEC-F01).

### Notes
- `subscriber_count`/`view_count` podem vir nulos (canal oculta) — tratar como ausente, não como zero.

### Open questions
- Coletar canal de todo vídeo ou só dos canais de artistas elegíveis (economia de quota)? **Recomendação:** decisão do Data/AI; o schema suporta ambos.

---

# Grupo D — Resolução, Elegibilidade & Computed

## artists

### Purpose
Identidade canônica do artista-alvo (o "type beat for"). Estável entre runs para permitir comparação futura (`04_...` §5).

### Key fields
- `id uuid pk`
- `canonical_name text`
- `created_at timestamptz`

### Relationships
- `1—N` `artist_aliases`, `video_artist_mappings`, `artist_metrics`, `report_items`.

### Immutability rule
**STATE leve.** `canonical_name` pode ser corrigido por humano (merge de duplicatas), com registro em `audit_events`. Não é raw nem snapshot.

### Notes
- Resolução de duplicatas (mesmo artista, grafias diferentes) acontece via `artist_aliases`.

### Open questions
- Artista é global (cross-run) ou por run? **Recomendação:** global, com a métrica por run em `artist_metrics`. Confirmar com Data/AI.

---

## artist_aliases

### Purpose
Variações de nome (extraídas/normalizadas) que apontam para um `artist` canônico. Registra a origem da variação (`04_...` §5).

### Key fields
- `id uuid pk`
- `artist_id uuid fk → artists.id`
- `alias text`
- `source enum('regex','llm_assisted','human')`
- `created_at timestamptz`

### Relationships
- `N—1` `artists`.

### Immutability rule
**EVENT-ish.** Append-only preferencialmente; correções humanas adicionam linhas/registram em `audit_events`.

### Notes
- `source = llm_assisted` marca aliases que passaram pelo único ponto de IA — útil para auditar guardrails (`03_...` §5).

### Open questions
- `alias` único globalmente ou por `artist_id`? **Recomendação:** único por `(lower(alias))` para evitar dois artistas reivindicando o mesmo alias; conflito → revisão humana.

---

## video_artist_mappings

*(tarefa: `artist_resolution_events`)*

### Purpose
Liga cada vídeo (raw) ao artista resolvido, registrando **método** e fila de revisão. É o registro auditável da Entity Resolution — o único ponto onde IA pode atuar (`04_...` §5, `03_...` §5).

### Key fields
- `id uuid pk`
- `run_id uuid fk → report_runs.id`
- `video_id text` — → `raw_youtube_videos(run_id, video_id)`
- `artist_id uuid fk → artists.id`
- `extracted_name text` — nome bruto extraído do título
- `method enum('regex','llm_assisted','human_override','unknown')`
- `needs_review boolean`
- `review_notes text null`
- `created_at timestamptz`

### Relationships
- `N—1` `report_runs`, `artists`.
- Liga-se logicamente a `raw_youtube_videos` por `(run_id, video_id)`.

### Immutability rule
**COMPUTED.** Reconstruível a partir do raw + regras/rubric de resolução. `human_override` é exceção registrada (não recomputável) — preservar e marcar em `audit_events`.

### Notes
- Guardrail (`03_...` §5): `extracted_name` deve ser substring/normalização plausível do `title`. Sem coluna pública de confidence.
- A tarefa chama isto de "evento" (`artist_resolution_events`); modelamos como **mapeamento por vídeo** (mais útil para join e contagem). A natureza append/recompute está coberta pela classe COMPUTED + `human_override`.
- **OD-DB-04 ratificado por Data/AI:** manter mapping canônico. Deve existir uma resolução final por `(run_id, video_id)`; tentativas intermediárias não entram no MVP.

### Open questions
- **OD-DB-04 — RESOLVIDO (DATA-AI-0001):** manter `video_artist_mappings` como mapping canônico. Se houver necessidade real de histórico de tentativas, adicionar `resolution_attempts` fora do MVP.

---

## channel_eligibility

### Purpose
Veredito de elegibilidade por canal numa run, com motivo e versão da regra. Alimenta Competition (canais distintos) e exclui spam (`04_...` §5, `03_...` §6).

### Key fields
- `id uuid pk`
- `run_id uuid fk → report_runs.id`
- `channel_id text`
- `is_eligible boolean`
- `reason text`
- `rule_version text`
- `reviewed_by_human boolean`
- `created_at timestamptz`

### Relationships
- `N—1` `report_runs`. Liga-se a `raw_youtube_channels` por `(run_id, channel_id)`.

### Immutability rule
**COMPUTED.** Reconstruível por `rule_version` sobre o raw. Override humano marcado (`reviewed_by_human = true`) + `audit_events`.

### Notes
- `rule_version` versiona a heurística de elegibilidade (separado de `rubric_version`).
- **Canais distintos elegíveis → Competition. Vídeos válidos → Signals.** Não duplicar (`03_...` §6).

### Open questions
- `rule_version` em tabela própria (como `rubric_versions`) ou string livre? **Recomendação:** string no MVP; promover a tabela se virar múltiplas regras.

---

## artist_metrics

*(tarefa: `artist_computed_metrics`)*

### Purpose
Métricas computadas e Score determinístico por artista por run. Coração do computed: tudo aqui é reconstruível e aponta para o raw e para o rubric (`04_...` §6, `03_...` §7, §10).

### Key fields
- `id uuid pk`
- `run_id uuid fk → report_runs.id`
- `artist_id uuid fk → artists.id`
- `signals int` — vídeos válidos
- `velocity_median_per_day numeric`
- `engagement_score numeric` — componente
- `channel_diversity_count int`, `channel_diversity_score numeric`
- `raw_score numeric`, `final_score numeric`
- `rubric_version text`, `rubric_hash text`
- `computed_from_video_ids text[]` — **rastreio até raw**
- `metrics_detail_json jsonb` — detalhe interno de auditoria por célula (vídeos aceitos/rejeitados + motivo, canais elegíveis, componentes e desempates)
- `created_at timestamptz`

### Relationships
- `N—1` `report_runs`, `artists`.
- Referenciada por `report_items.artist_metric_id` (ver Notes).

### Immutability rule
**COMPUTED.** Reconstruível para o par `run_id` + `rubric_hash`. **Nunca editar Score à mão** (`03_...` §7). Mesmo input + mesmo `rubric_hash` ⇒ mesmo output. Linhas já referenciadas por `report_items` publicados são preservadas por FK `ON DELETE RESTRICT`.

### Notes
- `computed_from_video_ids` + `rubric_hash` fecham a auditoria por célula de Score/Velocity/Signals/Competition (`03_...` §10).
- **OD-DB-07 ratificado por Data/AI:** adicionar `metrics_detail_json jsonb` para guardar a decomposição da auditoria por célula (top-3 velocity, vídeos rejeitados + motivo, lista de `channel_id`, inputs dos componentes e desempates), em vez de só `computed_from_video_ids`. Campo interno/admin-server, nunca exposto cru ao produtor (SEC-F03).
- **OD-DB-01 detalhe de re-score:** chave lógica recomendada `(run_id, artist_id, rubric_hash)`. Isso permite recompor o mesmo `run_id` sob novo rubric sem split e sem colidir com métricas antigas referenciadas por snapshots.

### Open questions
- Guardar componentes em colunas (atual) vs `components_json`? **Recomendação:** colunas para os 4 componentes do rubric + `metrics_detail_json` para o detalhe de auditoria.
- **OD-DB-07 — RESOLVIDO (DATA-AI-0001):** `metrics_detail_json` aprovado.
- Unicidade `(run_id, artist_id, rubric_hash)`? **Recomendação Data/AI:** sim, uma métrica por artista por run por rubric.

---

# Grupo E — Relatório (snapshot congelado)

## reports

### Purpose
Um dos dois relatórios fixos publicados ao produtor. Congelado após `published` (`04_...` §7, `scope-guardrails`).

### Key fields
- `id uuid pk`
- `run_id uuid fk → report_runs.id`
- `title text` — ex.: `Relatório 1 de 2`
- `vertical text`, `keyword text` (travada)
- `status enum('draft','published','archived')`
- `published_at timestamptz null`
- `created_at timestamptz`

### Relationships
- `N—1` `report_runs`. `1—N` `report_items`.

### Immutability rule
**SNAPSHOT.** Após `status = published`, conteúdo e `report_items` ficam **congelados** — não mudam mesmo com novos dados (`02_...` §8). `draft → published` é o ponto de congelamento; só `archived` depois.

### Notes
- Dois relatórios fixos no MVP (`scope-guardrails`). Não gerar sob demanda.
- Publicação registra `audit_events` + permite eventos `report_opened`.

### Open questions
- Publicar deve clonar/snapshot os `report_items` (já materializados) — não recomputar na leitura. **Recomendação:** materializar `report_items` no publish; nunca render-time compute.

---

## report_items

### Purpose
Uma linha do relatório (um artista no ranking) com os **valores congelados** exibidos e os ponteiros que justificam cada célula (`04_...` §7, `03_...` §8–§10). Atende ao princípio "report item aponta para os dados que justificam Score, Signals, Velocity, Competition e Example".

### Key fields
- `id uuid pk`
- `report_id uuid fk → reports.id`
- `artist_id uuid fk → artists.id`
- `artist_metric_id uuid fk → artist_metrics.id` — **ponteiro de proveniência** (OD-DB-06 ratificado)
- `rank int`
- `title text` — ex.: `Artist Type Beat`
- `tag text null` — `HOT` ou null (HOT se Score > 90)
- `score_display text null` — `92/100` (exibido só se > 83) · **público**
- `score_value numeric` — valor interno congelado · **admin/server-only (SEC-F03)**
- `signals int` · público
- `velocity_display text` — `1.2k/day` · público
- `competition_level enum('Low','Medium','High')` · público
- `competition_channel_count int` — canais distintos · público
- `example_video_id text` — → `raw_youtube_videos(run_id, video_id)` · público
- `example_url text` · público
- `selection_reason_json jsonb` — **prova determinística** (regra de Example, thresholds, top-3 velocity, desempate) · **cru: admin/server-only; produtor vê versão sanitizada (SEC-F03)**
- `created_at timestamptz`

### Relationships
- `N—1` `reports`, `artists`, `artist_metrics`.
- `example_video_id` resolve em `raw_youtube_videos` pelo `run_id` do report.

### Immutability rule
**SNAPSHOT.** Imutável após o report ser `published`. Os valores são **congelados** (cópia), não derivados em tempo de leitura — garante que o produtor sempre vê o mesmo número.

### Notes
- Cadeia de proveniência completa: `report_items → artist_metrics (rubric_hash, computed_from_video_ids, metrics_detail_json) → raw_youtube_videos → raw_youtube_search_pages`. Nenhum número público sem esse rastro (`04_...` §14).
- `score_display` null quando `score_value ≤ 83` (regra de exibição, `03_...` §8).
- `selection_reason_json` é o que torna Example e Competition auditáveis sem recomputar.
- **Exposição (SEC-F03 — bloqueante):** RLS do Postgres é **por linha, não por coluna**. A leitura do produtor passa por **VIEW pública dedicada** (ou `GRANT SELECT` por coluna) expondo **apenas**: `title`, `rank`, `tag`, `score_display`, `signals`, `velocity_display`, `competition_level`, `competition_channel_count`, `example_video_id`/`example_url` + `selection_reason` **sanitizado**. `score_value`, `raw_score` (via `artist_metrics`), `selection_reason_json` cru e `metrics_detail_json` **nunca** chegam ao produtor — senão o Score que o produto esconde (≤ 83) vazaria. A separação `artist_metric_id` (OD-DB-06) facilita: snapshot público em `report_items`, detalhe interno em `artist_metrics` (admin/server).

### Open questions
- **OD-DB-06 — RESOLVIDO para Data/AI (DATA-AI-0001):** adicionar `artist_metric_id` como FK de proveniência explícita e estável, com `ON DELETE RESTRICT`. Backend ainda valida consumo no desenho dos endpoints.

---

# Grupo F — Producer Outcomes (eventos append-only)

## producer_events

*(tarefa: `producer_outcomes`. Ver OD-DB-02.)*

### Purpose
Log **append-only** de tudo que o produtor faz e responde: interações, intenção, follow-up e WTP. Substitui qualquer flag booleana (`has_intent`, `produced`, etc.) (`04_...` §8, princípio #4). Fonte das métricas de validação (`04_...` §13).

### Key fields
- `id uuid pk`
- `producer_id uuid fk → producers.id`
- `event_type enum(...)` — ver lista abaixo
- `report_id uuid null fk → reports.id`
- `report_item_id uuid null fk → report_items.id`
- `artist_id uuid null fk → artists.id`
- `metadata jsonb` — detalhes específicos do evento
- `created_at timestamptz`

### Event types (canônico `04_...` §8 ⟷ nomes da tarefa)
| Evento (canônico) | Pedido na tarefa | Coberto |
|---|---|---|
| `application_submitted` | — | ✓ |
| `application_approved` | — | ✓ |
| `report_opened` | `report_opened` | ✓ |
| `report_switched` | `report_switched` | ✓ |
| `example_clicked` | `example_clicked` | ✓ |
| `artist_marked_useful` | `artist_marked_useful` | ✓ |
| `artist_marked_not_useful` | `artist_marked_not_useful` | ✓ |
| `intent_to_produce_declared` | `production_intent_declared` | ✓ (renomear? OD-DB-05) |
| `followup_sent` | `followup_sent` | ✓ |
| `followup_confirmed_produced` | `followup_answered_yes` | ✓ (OD-DB-05) |
| `followup_confirmed_not_produced` | `followup_answered_no` | ✓ (OD-DB-05) |
| `wtp_yes` | `wtp_yes` | ✓ |
| `wtp_no` | `wtp_no` | ✓ |
| `wtp_maybe` | `wtp_maybe` | ✓ |

### Relationships
- `N—1` `producers`; opcional `reports`, `report_items`, `artists`.
- `intent_to_produce_declared` é a origem de um `followups` (via `followups.producer_event_id`).

### Immutability rule
**EVENT (append-only).** Sem `UPDATE`/`DELETE`. Estado é derivado por agregação de eventos, **nunca** por coluna mutável. Correção = novo evento compensatório, não edição. **Trigger de imutabilidade recomendado** (SEC-D03): protege as métricas-norte de validação contra sobrescrita por service-role (que faz bypass de RLS, SEC-F01).

### Notes
- **Proibido**: `has_intent boolean`, `produced boolean`, etc. (instrução explícita da tarefa + `04_...` §8).
- Métricas (`04_...` §13): intenção/abertura, confirmação em follow-up, WTP positivo, utilidade HOT — todas `count(...)` sobre este log.
- Pesos de outcome (se um dia usados em análise) vêm de `outcome_weight_versions`, nunca hardcoded no evento.

### Open questions
- OD-DB-02: nome da tabela `producer_events` (canônico `04_`) vs `producer_outcomes` (tarefa). **Recomendação:** manter `producer_events` por consistência com Backend/backlog; tratar "producer_outcomes" como sinônimo conceitual. Decisão do Product Orchestrator.
- OD-DB-05: alinhar nomes de event_types (tarefa usa `production_intent_declared`, `followup_answered_yes/no`). **Recomendação:** manter nomes de `04_` (já referenciados nas queries de `04_...` §13); registrar os aliases da tarefa. Decisão do Product Orchestrator + Data/AI.
- Separar telemetria de UI (`report_opened`, `example_clicked`) de outcomes de validação (`intent`, `followup_*`, `wtp_*`) em duas tabelas? **Recomendação:** manter unificado no MVP (mais simples, mesma natureza append-only); reavaliar se volume de telemetria crescer.

---

## followups

### Purpose
Agendamento e resultado do follow-up 10–14 dias após uma intenção declarada (`04_...` §9, `scope-guardrails`). Liga a intenção original ao desfecho real.

### Key fields
- `id uuid pk`
- `producer_id uuid fk → producers.id`
- `producer_event_id uuid fk → producer_events.id` — o evento de intenção que originou
- `artist_id uuid fk → artists.id` — artista escolhido
- `due_at timestamptz` — intenção + 10–14 dias
- `channel enum('email','dm_manual')`
- `status enum('pending','sent','responded','missed')`
- `response jsonb null` — dados coletados
- `created_at timestamptz`, `sent_at timestamptz null`, `responded_at timestamptz null`

### Relationships
- `N—1` `producers`, `artists`, `producer_events` (intenção origem).

### Immutability rule
**STATE.** `status` evolui `pending → sent → responded | missed`. Cada transição relevante também emite `producer_events` (`followup_sent`, `followup_confirmed_*`) — a tabela é o **agendamento/estado**; o log é a fonte append-only.

### Notes
- `due_at` calculado a partir do `created_at` do evento de intenção (`04_...` §9).
- O cron de follow-up (`02_...` §6, OD-04) processa `status = pending AND due_at <= now()`.

### Open questions
- Janela exata 10 vs 14 dias por produtor? **Recomendação:** guardar `due_at` materializado (já permite variação); política de cálculo fica no Backend/cron.

---

## wtp_responses

### Purpose
Resposta estruturada de disposição a pagar (sim/não/talvez + faixa + texto). Complementa o evento `wtp_*` com o detalhe consultável (`04_...` §10).

### Key fields
- `id uuid pk`
- `producer_id uuid fk → producers.id`
- `response enum('yes','no','maybe')`
- `price_range text null`
- `free_text text null`
- `created_at timestamptz`

### Relationships
- `N—1` `producers`. Espelhado por `producer_events` (`wtp_yes|no|maybe`).

### Immutability rule
**EVENT-ish (append-only).** Nova resposta = nova linha. A métrica WTP usa a resposta mais recente por produtor (ou a primeira — decisão analítica).

### Notes
- Dupla escrita (evento + resposta) é intencional: o evento dá série temporal/auditoria; a resposta dá o payload consultável. Backend deve escrever ambos atomicamente.
- WTP ≥ 25% é gatilho de Fase 2 (`scope-guardrails`).

### Open questions
- Permitir múltiplas respostas WTP por produtor? **Recomendação:** sim (append); definir na análise se conta primeira vs última.

---

# Grupo G — Auditoria & Proveniência

## audit_events

*(NOVO — não existe em `04_`. Ver OD-DB-03.)*

### Purpose
Log append-only de **ações sensíveis e overrides humanos**: aprovação/rejeição de aplicação, publicação de relatório, override de Entity Resolution/elegibilidade, mudança de `producers.status`, merge de artista. Dá rastro de "quem fez o quê, quando e por quê" que `04_` cobre só parcialmente via colunas espalhadas.

### Key fields
- `id uuid pk`
- `actor_type enum('admin','system','pipeline')`
- `actor_id uuid null` — auth user (quando admin)
- `action text` — ex.: `application.approved`, `report.published`, `artist.merged`, `mapping.human_override`
- `entity_table text`, `entity_id uuid` — alvo da ação
- `before_json jsonb null`, `after_json jsonb null` — estado para diffs
- `reason text null`
- `created_at timestamptz`

### Relationships
- Polimórfica por `(entity_table, entity_id)`. Sem FK rígida (aponta para várias tabelas).

### Immutability rule
**EVENT (append-only).** Sem `UPDATE`/`DELETE`. **Trigger `BEFORE UPDATE/DELETE` que levanta exceção é obrigatório** (SEC-D03) — é o log de auditoria e precisa ser imutável **abaixo** do service-role, que faz bypass de RLS (SEC-F01); mutá-lo destruiria seu propósito.

### Notes
- Não substitui a proveniência de dados (essa vive em `run_id` + `rubric_hash` + `computed_from_video_ids` + `selection_reason_json`). `audit_events` cobre **proveniência de ações humanas/operacionais**.
- Eventos aqui são **sensíveis** (contêm decisões admin) → RLS restrita a admin/service role (ver `rls-review-notes.md`).
- `actor_id` pode ser nulo para ações de pipeline/sistema (`actor_type` em `('admin','system','pipeline')`).

### Open questions
- OD-DB-03: criar `audit_events` no MVP vs adiar e confiar nas colunas de `04_` (`reviewed_by`, `human_override`, etc.)? **Recomendação: criar** — barato e fecha o requisito #15 da tarefa de forma explícita. Confirmar com Product Orchestrator + Security.
- Granularidade: logar toda transição de status ou só as sensíveis? **Recomendação:** sensíveis no MVP (aprovação, publicação, overrides).

---

# Separação Raw / Computed / Snapshot (resumo)

| Classe | Tabelas | Pode recalcular? | Pode sobrescrever? |
|---|---|---|---|
| **RAW** | `raw_youtube_search_pages`, `raw_youtube_videos`, `raw_youtube_channels` | Não (é a fonte) | **Nunca** |
| **COMPUTED** | `video_artist_mappings`, `channel_eligibility`, `artist_metrics` | **Sim**, por `run_id` + `rubric_hash`/`rule_version` | Só via recompute determinístico; linhas referenciadas por snapshot publicado não são apagadas |
| **SNAPSHOT** | `reports` (pós-`published`), `report_items` | Não após publish (é congelado) | **Nunca** após publish |
| **EVENT** | `producer_events`, `audit_events`, `artist_aliases`, `wtp_responses` | — | **Nunca** (append-only) |
| **STATE** | `producers`, `applications`, `admin_users`, `followups`, `report_runs`, `artists` | — | Só colunas de status, via máquina de estados + `audit_events` |

> **Garantia de imutabilidade (SEC-D03):** RAW (`raw_youtube_*`) e `audit_events` têm **trigger `BEFORE UPDATE/DELETE` obrigatório** (recomendado em `producer_events`). Grants/RLS **não bastam**: `service_role` faz **bypass de RLS** (SEC-F01), então a imutabilidade do raw sagrado e do log de auditoria precisa estar abaixo do service-role, no banco.

Detalhe e cadeias em `entity-relationship-notes.md`.

---

# Open decisions (consolidado)

| ID | Tema | Recomendação | Quem decide | Status (DEC-0003) |
|---|---|---|---|---|
| OD-DB-01 | `report_runs` único vs `collection_runs` + `scoring_runs` | **Manter unificado no MVP**; split só via nova DEC se fluxo real exigir | Data/AI + Product Orchestrator | ✅ **Unificado ratificado** (DEC-0003 + DATA-AI-0001). Re-score no mesmo `run_id` via novo `rubric_hash` em `artist_metrics`. |
| OD-DB-02 | Nome `producer_events` vs `producer_outcomes` | Manter `producer_events` | Product Orchestrator | ✅ **Manter `producer_events`** |
| OD-DB-03 | Criar `audit_events` agora | **Criar** | Product Orchestrator + Security | ✅ **Criar** (condicionado à RLS do Security) |
| OD-DB-04 | `video_artist_mappings` mapping vs event-log | Manter mapping | Data/AI | ✅ **Mapping canônico ratificado** (DATA-AI-0001) |
| OD-DB-05 | Alinhar nomes de event_types da tarefa | Manter nomes de `04_`, registrar aliases | Product Orchestrator + Data/AI | ✅ **Manter nomes de `04_`** (aliases só em doc) |
| OD-DB-06 | `report_items.artist_metric_id` FK de proveniência | **Adicionar** | Data/AI + Backend | ✅ **Data/AI ratifica**; Backend valida consumo em endpoints |
| OD-DB-07 | `artist_metrics.metrics_detail_json` p/ auditoria por célula | **Adicionar** | Data/AI | ✅ **Data/AI ratifica** |
| OD-DB-08 | Identidade: `producers.id = auth.uid()` vs FK separada | Ligar ao Supabase Auth | Security | ✅ **`auth_user_id uuid UNIQUE NULL` FK** (SEC-D01) — **não** `id=auth.uid()`; preenchido só na aprovação. Ver `docs/security/SEC-0001-mvp-data-model-review.md`. |

Herdadas de `scope-guardrails`: OD-02 (Auth), OD-03 (Email), OD-04 (Cron) impactam, respectivamente, identidade, `followups.channel` e o cron de follow-up.

---

# Revisão obrigatória desta proposta

- ✅ **Product Orchestrator Agent** — OD-DB-01/02/03/05 decididos em `docs/product/decisions/DEC-0003-mvp-data-model-review.md`; zero Fase 2 verificado (**20 tabelas** = 19 + `admin_users` de segurança; nenhuma do `04_...` §12).
- ⚠️ **Security & Privacy Agent** — **aprovação condicional; veto mantido** (Fase 9 RLS, migrations/endpoints de acesso, gate pré-prod). Decisões fechadas SEC-D01 (`auth_user_id` FK, não `id=auth.uid()`), SEC-D02 (`admin_users` + `is_admin()`, nunca `user_metadata`), SEC-D03 (trigger de imutabilidade obrigatório em raw/audit). Condições bloqueantes SEC-F01 (service-role bypassa RLS → authz em código), SEC-F02 (mass-assignment no `/apply`), SEC-F03 (exposição de coluna ao produtor) em `docs/security/SEC-0001-mvp-data-model-review.md`.
- ✅ **Data/AI Pipeline Agent** — aprovado em `docs/database/DATA-AI-REVIEW-mvp-data-model.md`: raw/computed, proveniência por célula, reprodutibilidade sem split, OD-DB-01/04/06/07.
- ⏳ **Backend/Next API Agent** — formato consumível pelos endpoints (`02_...` §7) e escrita atômica evento+payload (WTP, followup).

Gatilhos da matriz (`agent-review-matrix.md`): #2 (schema/eventos → Database), #3 (migrations futuras → Database + Security), #4 (raw/computed → Data/AI), RLS → Security + Database.
