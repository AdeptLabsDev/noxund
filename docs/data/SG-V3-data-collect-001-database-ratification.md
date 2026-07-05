# SG-V3 — DATA-COLLECT-001 Database Re-Ratification (Video Collection Track)

## 1. Identificação

- **Documento:** Re-ratificação de Database (SG-V3) — **não** é DEC, **não** autoriza coleta, **não** é migration/apply.
- **Trilha:** `DATA-COLLECT-001` — coleta de vídeo upstream (`search.list → raw_youtube_search_pages`, `videos.list → raw_youtube_videos`).
- **Gate:** SG-V3 (Database re-ratifica zero-ALTER + atomicidade da finalização + idempotência/imutabilidade cobrem 001).
- **Papel:** Database reviewer (`database_agent`) · **Ação:** `plan_migration` (plano de migration para 001 = **nenhuma**) · **Não-sensível** (nenhum `change_db_schema`/`run_migration` invocado).
- **Owner:** Database Agent.
- **Data:** 2026-07-05
- **Natureza:** REVIEW/DESIGN-ONLY — zero conexão Supabase, zero secret, zero migration, zero ALTER, zero collector, zero workflow, zero teste, zero verify SQL, zero dispatch, zero coleta, zero commit/push/PR.
- **Fontes vinculantes:** `supabase/migrations/20260620000003_phase3_runs_artists.sql` (`report_runs` aplicado); `supabase/migrations/20260620000004_phase4_raw_youtube_snapshots.sql` (`raw_youtube_search_pages` + `raw_youtube_videos` aplicados); `docs/data/DATA-COLLECT-001-youtube-collection-spec.md` §§2–7; `docs/data/HANDOFF-data-collect-001-video-track.md` §§3–7; `docs/data/SG-V1-data-collect-001-product-ratification.md`.

## 2. Objetivo

Registrar formalmente a re-ratificação de Database do SG-V3: confirmar, coluna a coluna, que o substrato aplicado (Fase 3/4) suporta o contrato `DATA-COLLECT-001/v1` **sem nenhum ALTER**, atestar a atomicidade da finalização e a idempotência/imutabilidade sob restart, e emitir o veredito **GO** de Database para a trilha avançar ao build (SG-V4/SG-V5), mantendo SG-6 (Channel Data / 002) **NO-GO** e o `youtube-collection` **ARMADO e OCIOSO**.

## 3. Tabela SG-V3 de objetos DB (verificação coluna a coluna vs. contrato)

### 3.1 · `report_runs` — âncora de proveniência (phase3, linhas 50–64)

| Requisito da spec (§2) | Objeto no schema aplicado | Veredito |
|---|---|---|
| Criação de `run_id` | `id uuid primary key default gen_random_uuid()` | ✅ |
| status `created→collecting→processed/failed` | enum `report_run_status = (created, collecting, processed, published, failed)` | ✅ cobre todos |
| `collected_video_count` (nullable até finalizar) | `collected_video_count int` (NULL default) | ✅ |
| `youtube_quota_used` | `youtube_quota_used int` (nullable) | ✅ |
| `window_start` / `window_end` | ambos `timestamptz not null` + `CHECK (window_end >= window_start)` | ✅ |
| `target_video_count` | `int not null default 500` | ✅ |
| Identidade de coleta imutável | `report_runs_row_guard` congela `keyword/vertical/window_start/window_end` no UPDATE; bloqueia DELETE; `report_runs_no_truncate` bloqueia TRUNCATE | ✅ |

**Nota semântica:** o row-guard congela **só** a identidade — permite UPDATE de STATE (`status`, `collected_video_count`, `youtube_quota_used`), exatamente o exigido pelo ciclo `created→collecting→finalize`. `keyword`/`vertical` têm defaults travados (`chicago drill type beat` / `Chicago Drill`), casando com SG-V1.

### 3.2 · `raw_youtube_search_pages` — Agente 1 (phase4, linhas 72–89)

| Requisito da spec (§3.3) | Objeto no schema aplicado | Veredito |
|---|---|---|
| `run_id` | `uuid not null references report_runs(id) on delete restrict` | ✅ |
| `page_token` (null = 1ª página) | `page_token text` | ✅ |
| `response_json` verbatim | `response_json jsonb not null` (corpo, verbatim) | ✅ |
| `fetched_at` | `timestamptz not null default now()` | ✅ |
| Idempotência por página | unique `(run_id, coalesce(page_token,''))` | ✅ |
| Imutabilidade | triggers `_immutable` (row UPDATE/DELETE) + `_no_truncate` (statement) | ✅ |
| SEC-F08 / no-envelope | `CHECK (not response_json ?| array['config','request','headers','authorization','key'])` | ✅ |

### 3.3 · `raw_youtube_videos` — Agente 2 (phase4, linhas 97–121)

| Requisito da spec (§4.3) | Objeto no schema aplicado | Veredito |
|---|---|---|
| `run_id` | `uuid not null references report_runs(id) on delete restrict` | ✅ |
| `video_id` | `text not null` | ✅ |
| `channel_id` | `text not null` | ✅ |
| `title` | `text` (nullable) | ✅ |
| `published_at` | `timestamptz` (nullable) | ✅ |
| stats nullable | `views/likes/comments bigint` nullable (ausente ≠ zero; `bigint` evita overflow int32 em vídeo viral) | ✅ |
| `raw_json` verbatim | `jsonb not null` (item completo, verbatim) | ✅ |
| `fetched_at` | `timestamptz not null default now()` | ✅ |
| Unique `(run_id, video_id)` | `raw_youtube_videos_run_video_uidx` | ✅ |
| Índice `(run_id, channel_id)` | `raw_youtube_videos_run_channel_idx` | ✅ |
| Imutabilidade | triggers `_immutable` + `_no_truncate` | ✅ |
| SEC-F08 / no-envelope | `CHECK (not raw_json ?| array[...])` | ✅ |

Todas as três tabelas: RLS ENABLE + default-deny + `revoke all from anon, authenticated`. Imutabilidade por **trigger** (não só RLS/grant) — necessária porque o `service_role` faz bypass de RLS (SEC-F01); o guard fica **abaixo** do service_role, no banco.

## 4. Confirmação zero-ALTER / zero migration

**Confirmado: DATA-COLLECT-001 exige ZERO ALTER e ZERO migration nova.** Cada coluna, tipo, constraint, índice único e trigger que o contrato §2/§3.3/§4.3/§5 demanda **já existe e está aplicado** nas Fases 3 e 4. Não há coluna faltante, tipo a corrigir nem índice a criar. O gate de Database para 001 é **re-ratificação** — não um novo apply. Re-ratificado.

Corolário: `0007` (`phase6_producer_events`) permanece PARKED e irrelevante para 001; nenhuma migration foi criada, alterada ou proposta.

## 5. Análise de atomicidade da finalização

O caminho de escrita em `report_runs` STATE é **novo** (001 é o 1º CI que muta STATE, não só raw — R3 do handoff).

1. **Como sair de `collecting`:** UPDATE de linha única em `report_runs` (`status` e/ou contadores). UPDATE de linha única é atômico no Postgres; o row-guard permite porque não toca identidade.
2. **Quando gravar `collected_video_count`:** só na finalização única, após o gate §7 passar. No schema, `collected_video_count` nasce **NULL** e é o sinal de "não finalizado". *(a condição "após §7" é garantia de aplicação — o schema não avalia §7; ver R-DB2.)*
3. **Como marcar `failed`:** `UPDATE ... SET status='failed'` (+ `youtube_quota_used` quando conhecido, §2.5). `collected_video_count` **permanece NULL** → nunca aparenta completude (§6.3).
4. **Como evitar que run parcial pareça válida — invariante load-bearing:**
   - **Completude é sinalizada por `collected_video_count IS NOT NULL`, não por `status`.** Detalhe crítico: o collector **não** promove a run a `processed`/`published` (§2.6) — uma run §7-passed fica `status='collecting'` **com `collected_video_count` preenchido**. O marcador §7-passed a nível de banco é **`collected_video_count IS NOT NULL AND status <> 'failed'`**. Downstream (002/SG-6, Entity Resolution) **deve** chavear por `collected_video_count` e repetir o preflight §7 (spec §7, última linha).
   - Crash em `collecting` deixa `collected_video_count = NULL` → indistinguível de run em voo, mas **distinguível** de run completa. Nenhum crash fabrica completude.
   - Linhas raw já inseridas são preservadas (imutáveis) como evidência — "run parcial falha", nunca snapshot elegível (§6.5). FK `ON DELETE RESTRICT` + row-guard bloqueando DELETE tornam a âncora duplamente indestrutível.
   - Cada página e cada lote de ≤50 vídeos são gravados atomicamente (§5). Reinserção de linha já escrita ⇒ `unique_violation` (não `DO NOTHING`), expondo divergência em vez de sobrescrever.

**Veredito atomicidade:** o schema **suporta** a finalização atômica e a invariante "parcial nunca parece válida". As garantias que faltam ao schema são semânticas (§7) e por design pertencem ao verify/collector — ver R-DB1/R-DB2.

## 6. Análise de idempotência / restart

| Exigência (§5/§6) | Mecanismo de schema | Veredito |
|---|---|---|
| Sem duplicar páginas | unique `(run_id, coalesce(page_token,''))`; 1ª página (NULL) = slot único determinístico | ✅ |
| Sem sobrescrever raw | triggers `_immutable` fazem UPDATE/DELETE **falhar duro** mesmo sob service_role → overwrite em restart quebra alto, não corrompe | ✅ |
| Sem UPDATE/DELETE/TRUNCATE | raw: 2 triggers/tabela; `report_runs`: row-guard (DELETE) + no_truncate (TRUNCATE) | ✅ |
| Idempotência de lote de vídeo | unique `(run_id, video_id)`: zero linhas → chama; todas → reusa; parcial → violação de atomicidade detectável e falha a run (§5) | ✅ |
| Retomada em `collecting` | `collected_video_count = NULL` sinaliza estado retomável; §5 reusa páginas/lotes persistidos; sem provar consistência → `failed` (§6) | ✅ |

**Veredito idempotência:** schema sustenta restart seguro. As chaves únicas transformam re-request em erro observável em vez de duplicata silenciosa; a imutabilidade transforma overwrite em falha dura — fail-closed exigido por §5/§6.

## 7. Riscos residuais (DB-scoped)

| # | Risco | Severidade | Cobertura / observação |
|---|---|---|---|
| **R-DB1** | STATE não é imutável pós-finalização. O row-guard congela **só** a identidade; nada no banco impede 2º UPDATE sobrescrever `collected_video_count` já gravado, ou mover `status` para trás. Não há state-machine no banco. | **Baixa** | Coberto por: writer único (collector), fail-closed §6, recoleta = novo `run_id` (§2.7), preflight §7 repetido por downstream. Endurecer (trigger OLD/NEW de STATE) exigiria **migration → fora do escopo de SG-V3** e não é pré-condição de GO. |
| **R-DB2** | §7 **não é** (nem pode ser) constraint de banco: set-equality `(run_id,video_id)` vs. vetor selecionado, integridade da cadeia de tokens, `projeção == raw_json` são checagens cross-row/semânticas. | **Esperada** | Por isso o verify §7 (SG-V5, gap G3) é gate bloqueante separado. O schema não certifica §7-pass sozinho — correto por design. |
| **R-DB3** | O CHECK SEC-F08 é guard de **chave top-level** (`?|` no topo do JSONB). Secret aninhado mais fundo, ou sob chave de nome diferente, não seria pego pelo CHECK. | **Baixa / aceita** | Defense-in-depth explícita (spec §8): controle primário é o scrub body-only do collector + teste canary de log. Corpo legítimo do YouTube nunca traz essas chaves no topo → falso-positivo ≈ 0. |
| **R-DB4** | Índice usa `coalesce(page_token,'')`: se a API retornasse `page_token` string-vazia, colidiria com o slot da 1ª página. | **Negligível** | Tokens do YouTube são opacos e não-vazios; contrato §3.2.1 trata 1ª página como NULL. Registrado só para completude. |

Pontos que são **força** (não risco): `bigint` para contadores (evita overflow int32 em vídeo viral); `timestamptz` normaliza UTC internamente (disciplina UTC é do collector, tipo é o certo); FK `ON DELETE RESTRICT` + row-guard = âncora de proveniência indestrutível.

## 8. Veredito GO/NO-GO

- **SG-V3 → ✅ GO (Database).** Zero-ALTER / zero migration re-ratificado (verificado coluna a coluna); atomicidade da finalização suportada; idempotência/restart suportadas; riscos residuais todos ou application/verify-level (cobertos por SG-V5/§7/§8) ou endurecimento de baixa severidade que exigiria migration (fora do escopo de SG-V3, não pré-condição de GO).
- Este GO é **de revisão/design**. Não aprova coleta, dispatch, deployment nem apply.
- **SG-6 (Channel Data / 002) → ⛔ NO-GO (inalterado)** — sem `run_id` de vídeo §7-passed. `youtube-collection` segue **ARMADO e OCIOSO** (`TOTAL_RUNS=0`, `.armed` em `main`). Nada aqui altera esse estado.

## 9. Próximos passos seguros

1. **SG-V3 fecha em paralelo com SG-V2 (Security).** OD-V1 (Environment) e OD-V2 (quota/F-1') seguem com Security/DevOps — pré-condição de **execução** (SG-V7), não de design; não bloqueiam o build.
2. **Design-gate restante para destravar o build:** SG-V2 (Security `audit_secrets`). Com SG-V2 + SG-V3 verdes, elegível a **SG-V4** (Data/AI + Backend autoram o collector inerte/offline) e **SG-V5** (5 testes §8 + verify §7).
3. **Recomendação de Database para o verify §7 (SG-V5):** ancorar asserções nos objetos aqui confirmados — `collected_video_count IS NOT NULL AND status <> 'failed'` como marcador §7-passed; set-equality via unique `(run_id, video_id)`; integridade da cadeia via `coalesce(page_token,'')`; `projeção == raw_json`; re-checar o CHECK anti-envelope. Isso fecha R-DB2 no nível certo (verify), não no schema.
4. **Nada de código/migration/workflow/dispatch** até SG-V2..SG-V6 verdes + gate humano (SG-V7). `0007` PARKED. Fase 9/RLS vetada. Publish barrado até P5-REPRO-01 (SG-8).

## 10. Restrições honradas / Intocados

- **Docs-only.** Nenhum código, workflow, migration, teste, verify, secret, GCP, Supabase, dispatch ou deployment tocado. Este documento é a única saída (review artifact).
- **Não é DEC** — registro de re-ratificação de Database (SG-V3).
- **Intocados:** `.github/workflows/youtube-collection.yml`; `.github/collection/youtube-collection.armed`; `services/data-engine/*`; `supabase/migrations/*` (schema já vivo, **zero ALTER**); `supabase/tests/*`; `20260620000007_phase6_producer_events.*` (**PARKED**).
- **Vetos ativos reafirmados:** SG-6 NO-GO; sem dispatch; sem deployment; sem coleta; `0007` intocado; Fase 9/RLS vetada; publish barrado até SG-8/P5-REPRO-01; secrets/GCP/Supabase intocados; zero commit/push/PR sem autorização explícita.
- **Zero valor sensível.** Cita apenas **nomes** de secrets/vars (`YOUTUBE_API_KEY`) — nenhum valor, token, URL com query string, senha ou credencial.
