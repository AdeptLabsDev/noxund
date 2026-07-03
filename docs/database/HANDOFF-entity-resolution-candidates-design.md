# Handoff — [DB] entity_resolution_candidates (extensão aditiva · DEC-0014) · Database Agent

> ✅ **APLICADO E VERIFICADO (em CI) — não leia este documento como design/`needs_review`.**
> O apply gated da migration `20260620000006` foi **executado e verificado em produção** (CI run
> `28343949123`, workflow `entity-db-apply.yml`, origem `main`, reviewer AdeptLabsDev; commit
> `9a1ac52`; **DEC-0015**). As 3 revisões de desenho fecharam (Database · Security **SEC-0017** ·
> Data/AI com `DATA-ENTITY-F01` **levantado** pós-mitigação). **Fonte canônica de status:**
> [`HANDOFF-entity-resolution-candidates-apply-closeout.md`](HANDOFF-entity-resolution-candidates-apply-closeout.md).
> Este documento permanece como registro de **design** (decisões + mapa de CHECKs/índices).
> Fase 9 (RLS Policies + VIEW) **não** foi destravada.

## 1. Identificação
- **Tarefa:** `task_entity_candidates_design_schema` · **Action:** `design_schema` (não-sensível) · `priority: high` (caminho crítico DEC-0013/0014)
- **Owner agent:** Database (`database_agent`) · **Data:** 2026-06-28
- **Predecessoras (aplicadas):** Fase 3 (`report_runs`/`artists`), Fase 4 (`raw_youtube_videos`), Fase 5 (`video_artist_mappings` + enum `video_artist_method`) — DEC-0009..0012.
- **Fontes:** `DEC-0014-entity-resolution-candidates-extension.md` · `DATA-ENTITY-001-entity-resolution-spec.md` (§2 estado lógico · §6 fila · §7 projeção · §8 replay · §10 gate pre-apply) · Fase 5 migration `…0005` · `DATA-AI-0007` (F5-05/F5-06A) · `SEC-0017`.

## 2. Objetivo
Destravar a **Entity Resolution** com uma **fila durável** de candidatos AINDA não aprovados, sem poluir `artists`/`video_artist_mappings` com saída de IA não-revisada. `artist_id NOT NULL` + unique `(run_id, video_id)` no mapping canônico impedem segurar um candidato LLM pendente/rejeitado — a fila resolve isso **mantendo a integridade das tabelas canônicas** (DEC-0014 §2).

## 3. Natureza da tabela — STAGING MUTÁVEL (não confundir com snapshot/log)
- **É** uma review queue: `status` transiciona `pending → approved | rejected`; `reviewed_at` é carimbado na decisão. **NÃO** é snapshot congelado, **NÃO** é append-only → **NÃO** há trigger de imutabilidade.
- A **decisão/override** humano é logado em **`audit_events`** (replay por chave natural `run_id+video_id`, DATA-ENTITY-001 §6) e, no scoring, congelado em **`artist_metrics.metrics_detail_json.overrides[]`** (F5-06A) — **NÃO** nesta tabela. A fila é trabalho-em-progresso; a verdade congelada vive a jusante.

## 4. Diff de schema (forward migration · `20260620000006_entity_resolution_candidates.sql`)
```text
+ enum entity_candidate_status ('pending','approved','rejected')   -- NOVO
  (REUSA public.video_artist_method da Fase 5 — NÃO recria)
+ table entity_resolution_candidates(
    id uuid pk,
    run_id uuid NOT NULL → report_runs(id) ON DELETE RESTRICT,
    video_id text NOT NULL,
    proposed_name text NOT NULL,                 -- span do título (STRING; nunca artist_id)
    artist_id uuid NULL → artists(id) ON DELETE RESTRICT,   -- só se resolvido; null até aprovação
    method public.video_artist_method NOT NULL,  -- enum reusado
    resolver_version text NOT NULL,              -- entity-resolver-v1 (determinística)
    prompt_version text NULL,                    -- versão do prompt restrito (llm_assisted)
    status public.entity_candidate_status NOT NULL default 'pending',
    review_notes text NULL, reviewed_at timestamptz NULL, created_at timestamptz NOT NULL,
    FK entity_resolution_candidates_raw_video_fk (run_id, video_id) → raw_youtube_videos ON DELETE RESTRICT,
    CHECK entity_resolution_candidates_llm_prompt_chk    (method<>'llm_assisted' OR prompt_version IS NOT NULL),
    CHECK entity_resolution_candidates_reviewed_at_chk   (status='pending' OR reviewed_at IS NOT NULL),
    CHECK entity_resolution_candidates_resolver_version_nonblank_chk (btrim(resolver_version) <> ''),                 -- F01
    CHECK entity_resolution_candidates_prompt_version_nonblank_chk   (prompt_version IS NULL OR btrim(prompt_version) <> ''))  -- F01
+ UNIQUE PARTIAL index entity_resolution_candidates_pending_uidx (run_id, video_id) WHERE status='pending'
+ PARTIAL index        entity_resolution_candidates_pending_queue_idx (created_at)  WHERE status='pending'
+ index                entity_resolution_candidates_run_status_idx (run_id, status)
+ PARTIAL index        entity_resolution_candidates_artist_idx (artist_id) WHERE artist_id IS NOT NULL
+ enable row level security  +  revoke all from anon, authenticated   -- default-deny; ZERO policy
```
**Totais:** 1 tabela NOVA · 1 enum novo (reusa 1 da Fase 5) · 3 FK (todas RESTRICT) · **4 CHECK** (2 + 2 non-blank de versão, F01) · 4 índices · RLS-on · 0 policy · 0 trigger (mutável). **Atômica** (`begin`/`commit`). **ZERO ALTER** de tabela aplicada.

## 5. Decisões de modelagem (e por quê)
- **`proposed_name` STRING + `artist_id` NULLABLE.** O candidato carrega o **nome proposto** (span sustentado pelo guardrail §3 da spec), não um `artist_id`. `artist_id` só é preenchido quando o regex casa um artista existente (§4.2) ou na aprovação humana; **null** para novo/desconhecido. Assim, um candidato não-aprovado **não cria** linha em `artists` nem em `video_artist_mappings` (o objetivo central do DEC-0014).
- **Proveniência por FK composta → raw (RESTRICT).** `(run_id, video_id) → raw_youtube_videos` (igual ao mapping): todo candidato é rastreável até o raw; vídeo ausente ou de outro run é rejeitado na escrita. `run_id → report_runs` e `artist_id → artists` também RESTRICT.
- **Dedup do CORRENTE por índice PARCIAL único `(run_id, video_id) WHERE status='pending'`.** No máximo **um pendente** por (run, vídeo) — impede dois candidatos competindo e força resolver o atual antes de propor outro; linhas approved/rejected **podem coexistir**. A fila continua mutável: a trilha autoritativa e imutável é `audit_events`. *Alternativa rejeitada:* unique total `(run_id, video_id)` — bloquearia re-proposta após rejeição. (O mapping canônico mantém o unique total; a fila deduplica só o corrente.)
- **CHECKs estruturais (storage-only, sem número).** `llm_prompt_chk`: candidato `llm_assisted` exige `prompt_version` (determinismo/replay do Agente 3, alinhado a F5-06A). `reviewed_at_chk`: candidato revisado (approved/rejected) carrega o carimbo da decisão (espelha `reports_published_at_chk`). **`*_nonblank_chk` (DATA-ENTITY-F01):** `NOT NULL` garante PRESENÇA, não CONTEÚDO — `resolver_version`/`prompt_version` em branco (`''`/só-espaços) passariam e quebrariam o determinismo/replay (versão não-rastreável). `resolver_version` exige `btrim(...) <> ''`; `prompt_version` **preserva a nullabilidade** (`IS NULL OR btrim(...) <> ''`) para não regredir candidatos `regex` determinísticos. Nenhum valida número/threshold.
- **MUTÁVEL por design (sem freeze).** `status`/`reviewed_at` mudam por UPDATE legítimo (tela de revisão) → **nenhum** trigger de imutabilidade. O verify prova a mutabilidade (UPDATE pending→approved/rejected aceito), sem fingir imutabilidade.
- **Default-deny (SEC-F13).** RLS-on + `revoke`; **zero `create policy`/view**. Escrita (resolver) e leitura (tela de revisão) são server/admin; policies eventuais ficam na **Fase 9** (vetada — SEC-0001 §0).
- **Zona determinística intacta.** É fila de **nomes**, não de métricas; **zero** número/Score/IA-gera-número. Sem tabela de marketplace/Fase 2.

## 6. PII / SEC-F08 (Security concluída — SEC-0017)
- **Sem coluna `jsonb` livre** → **nenhum vetor SEC-F08** nesta camada (não há envelope de request/secret para escrutinar). `proposed_name`/`review_notes` são **texto** sob **default-deny** (server/admin-only).
- **PII mínima:** nomes de artista derivados de **títulos públicos** do YouTube; sem email/identidade de produtor aqui. SEC-0017 aprovou o desenho e tornou vinculante: nunca serializar secret/PII em `review_notes`/`proposed_name`; não logar esses textos (SEC-F10); executar canary pré-live espelhando SEC-0016; nunca expor `review_notes` ao produtor. Coluna estruturada/`jsonb` futura reabre SEC-F08.

## 7. Verify §4/§5 (`entity_resolution_candidates_post_apply_verify.sql`, fail-closed)
- **§4 estrutural:** tabela; enum novo (3 labels) + `video_artist_method` reusado presente; colunas; NOT NULL/nullable corretos; `status` default `pending`; FK composta nomeada → raw (colunas+RESTRICT); FK→report_runs e →artists presentes; **todas as FK RESTRICT**; **4 CHECK** (incl. os 2 non-blank de versão, F01); 4 índices; dedup index **UNIQUE+PARTIAL**; **ZERO trigger** (mutável); RLS-on; **zero policies**.
- **§5 empírico (probes revertidos):** **proveniência** (vídeo ausente/de outro run → `foreign_key_violation`; coerente + `artist_id` null aceitos) · **status default** = pending · **mutabilidade** (UPDATE pending→rejected aceito — prova positiva) · **dedup** (2º pendente mesmo (run,vídeo) → `unique_violation`; após resolver, novo pendente aceito) · **prompt CHECK** (`llm_assisted` sem `prompt_version` → `check_violation`; com → aceito; `regex` sem prompt → aceito) · **reviewed_at CHECK** (`approved` sem `reviewed_at` → `check_violation`) · **non-blank de versão (DATA-ENTITY-F01)** (`resolver_version=''` e `'   '` → `check_violation`; `prompt_version=''` → `check_violation`; non-blank válido + `prompt_version` NULL em `regex` + non-blank em `llm` → aceitos, sem regressão) · **RESTRICT até artists** (DELETE de artista referenciado → bloqueado) · **default-deny** (anon/authenticated → `insufficient_privilege`).

## 8. Rollback
`supabase/rollback/20260620000006_entity_resolution_candidates.rollback.sql` — declarado, **NÃO executado**: drop tabela (índices/constraints/FKs caem junto) → drop enum novo. **NUNCA** dropa `public.video_artist_method` (é da Fase 5, reusado). Baixo risco (fila mutável; decisões já tomadas sobrevivem em `audit_events`/`overrides[]`).

## 9. Ordenação de migrations (resolvida)
- **`entity_resolution_candidates` = ts `20260620000006`** — aplica **independente e À FRENTE** da Fase 6.
- **`producer_events` (Fase 6) renumerada `0006 → 0007`** (migration + rollback + refs em verify/handoff). Ambas estavam **parked/untracked** (não aplicadas/não commitadas) → renumeração **sem custo** (sem conflito de histórico de migration). `db push` aplica em ordem: …0005 (aplicada) → 0006 (esta) → 0007 (producer_events).

## 10. Revisões pre-apply — veredito explícito
- [x] **Database** — autor (este handoff) + **mitigação `DATA-ENTITY-F01` aplicada** (2 CHECKs non-blank + probes).
- [x] **Security & Privacy** — ✅ **APROVADO sem bloqueio** em SEC-0017: default-deny/PII/FK RESTRICT; contrato write-layer ratificado; Fase 9 segue vetada. *(Superfície inalterada por esta mitigação — sem re-review.)*
- [x] **Data/AI** — ✅ **APROVADO no re-review estreito**; `DATA-ENTITY-F01` levantado por `task_entity_candidates_rereview_dataai_f01`. Terceiro gate de desenho baixado.

### Veredito Data/AI original — histórico superado (`task_entity_candidates_review_dataai_queue`)

O desenho está aprovado nos seguintes pontos: dedup do pendente pelo índice parcial preserva a coexistência de linhas finalizadas; a fila é WIP mutável e não substitui `audit_events`/`metrics_detail_json.overrides[]`; candidato não-aprovado permanece fora de `artists`/`video_artist_mappings` pelo schema habilitador + contrato transacional do writer; guardrail de span continua vinculante; fila contém nomes e **zero número**; contrato SEC-0017 (sem secret/PII, SEC-F10, canary) foi incorporado à DATA-ENTITY-001.

**Bloqueio então registrado:** o DDL aceitava `resolver_version = ''`/whitespace e, para `llm_assisted`, `prompt_version = ''`/whitespace. O verify cobria `NULL`, não blank. Isso contradizia a versão determinística/non-blank declarada e permitia fato de replay sem identidade de versão.

**Mitigação então exigida ao Database, design-only:** adicionar CHECK nomeado non-blank para `resolver_version`; fortalecer a garantia de prompt non-blank; adicionar probes negativos blank/whitespace e positivos com `entity-resolver-v1`/`llm-fallback-v1`; então solicitar re-review Data/AI. Nenhuma mudança de modelo, coluna de evidence, número ou freeze era necessária.

Esse veto original era exclusivamente pre-apply e foi levantado abaixo; nunca autorizou apply nem destravou a Fase 9.

### ✅ Resolução `DATA-ENTITY-F01` (task `task_entity_candidates_fix_data_entity_f01`, design-only)
Mitigação aplicada **in-place** na migration `…0006` (ts inalterado; untracked; sem renumeração; banco intocado):
- `entity_resolution_candidates_resolver_version_nonblank_chk` → `check (btrim(resolver_version) <> '')` (NOT NULL já garante presença; este garante conteúdo).
- `entity_resolution_candidates_prompt_version_nonblank_chk` → `check (prompt_version is null or btrim(prompt_version) <> '')` (**preserva nullabilidade**; coerente com `llm_prompt_chk`; não regride `regex` com prompt null).
- Ambos **storage-only** (zero número/threshold). Verify §4 passa a assertar **4 CHECKs**; §5 prova fail-closed (`''`/`'   '` → `check_violation`; non-blank/`null`-regex → aceitos).
- **Superfície SEC-0017 inalterada** (sem nova policy/view/jsonb/RLS/role/FK/PII) → **sem re-review de Security**.

### ✅ Re-review Data/AI (`task_entity_candidates_rereview_dataai_f01`)

**`DATA-ENTITY-F01` LEVANTADO — gate Data/AI baixado.** Confirmado no escopo estreito:

- `entity_resolution_candidates_resolver_version_nonblank_chk` rejeita `''` e só-espaços por `btrim(resolver_version) <> ''`;
- `entity_resolution_candidates_prompt_version_nonblank_chk` rejeita prompt presente em branco e preserva `NULL` no caminho regex; combinado com `llm_prompt_chk`, `llm_assisted` exige prompt presente e non-blank;
- verify §4 exige os 4 CHECKs por nome; §5 cobre a/a'/b/c/d/d' com `check_violation` fail-closed e positivos de não-regressão;
- nenhum achado anterior foi reaberto: fila/replay/guardrail/write-layer permanecem aprovados e a superfície SEC-0017 não mudou.

Esta é liberação do **desenho pre-apply**, não autorização de execução. `run_migration` continua em task separada e sensível, com confirmação humana, Environment `production-db`, dispatch de `main` e SEC-F18. Fase 9 não destravada.

## 11. Impacto no escopo / não-negociáveis
- **MVP travado?** Sim. 1 tabela aditiva de staging da única zona de IA; **zero** marketplace/Fase 2; **zero** ALTER de tabela aplicada.
- **Não-negociáveis honrados:** aditivo-não-destrutivo, **proveniência** até raw (RESTRICT), **IA não gera número** (fila de nomes), **default-deny** + **zero policy** (Fase 9 intacta), candidato não-aprovado **fora** de artists/mappings, replay/override em `audit_events`/`overrides[]`, **PII sinalizada** ao Security.

## 12. Próximos passos / `next_recommendation`
1. ✅ **`database_agent:design_schema`** corrigiu `DATA-ENTITY-F01` na migration/verify, sem apply (esta task — §10 Resolução).
2. ✅ **`data_agent` re-review** concluiu: `DATA-ENTITY-F01` levantado e terceiro gate de desenho baixado.
3. Com as 3 liberações concluídas, o Orchestrator pode criar a **task gated separada** de `run_migration` (workflow dedicado, confirmação humana, Environment `production-db`, dispatch de `main`/SEC-F18; verify fail-closed). Este handoff não autoriza nem executa o apply.
4. Após apply comprovado, implementar resolver/fixtures → Channel Filter → scoring → **P5-REPRO-01**.
5. Fase 6 (`producer_events`, ts `0007`) segue parada em design até a captura virar gargalo (DEC-0013).
- **Vetos de pé:** Fase 9 — RLS Policies + VIEW pública (SEC-0001 §0). Esta autoria **não** os destrava.
