# DATA-COLLECT-001 — Video Collection Track Handoff

## 1. Identificação

- **Documento:** Handoff de trilha (design/diagnóstico) — **não** é DEC, **não** autoriza coleta.
- **Trilha:** `DATA-COLLECT-001` — coleta de vídeo upstream (`search.list → raw_youtube_search_pages`, `videos.list → raw_youtube_videos`).
- **Owner de origem:** Product Orchestrator (co-lead de produto) — foco em segurança, dados sensíveis e trilhas gated.
- **Data:** 2026-07-05
- **Prioridade:** P0 — caminho crítico: sem `run_id` §7-passed de vídeo, o Channel Data (002) e o 1º relatório não avançam.
- **Estado:** **DIAGNÓSTICO/HANDOFF-ONLY** — zero código, zero workflow, zero migration, zero API, zero secret, zero dispatch, zero deployment.
- **Fontes vinculantes:** `docs/data/DATA-COLLECT-001-youtube-collection-spec.md` (contrato §§1–11); `docs/data/DATA-COLLECT-002-channel-data-collection-spec.md` (downstream que reusa o `run_id`); `docs/product/decisions/DEC-0018-gated-channel-data-collection-track.md` (template de gate SG-0..SG-8); `supabase/migrations/20260620000003_phase3_runs_artists.sql` (`report_runs` aplicado); `supabase/migrations/20260620000004_phase4_raw_youtube_snapshots.sql` (`raw_youtube_search_pages` + `raw_youtube_videos` aplicados); `.github/workflows/youtube-collection.yml` (pipeline 002, ARMADO).

## 2. Objetivo

Registrar formalmente o **diagnóstico de arquitetura** e a **sequência segura** para implementar a coleta de vídeo upstream de `DATA-COLLECT-001`, mantendo o pipeline `youtube-collection` (Channel Data / 002) **ARMADO e OCIOSO** até existir um `run_id` de vídeo **congelado e §7-passed**. Este documento não implementa nada: entrega estado, gaps, riscos, checkpoints (SG-V0..SG-V8) e as decisões abertas (OD-V1/OD-V2).

## 3. Invariantes de estado (declarações explícitas obrigatórias)

- **`youtube-collection.yml` / Channel Data (002) está ARMADO e OCIOSO.** `.github/collection/youtube-collection.armed` está em `main`; `TOTAL_RUNS = 0`; nenhuma coleta executada; nenhum deployment aprovado.
- **SG-6 do Channel Data (002) continua NO-GO.** Motivo estrutural: o `youtube-collection.yml` **exige** um `run_id` de entrada cujo snapshot de vídeo já passou `DATA-COLLECT-001 §7`. Esse `run_id` **só pode nascer de `DATA-COLLECT-001`**, que ainda não existe como código/pipeline executado. Não é bug — é dependência não satisfeita.
- **Não há migration necessária para `DATA-COLLECT-001`.** O substrato de banco (`report_runs` + `raw_youtube_search_pages` + `raw_youtube_videos`) já está aplicado (Fase 3/4) e suporta 001 **sem nenhum ALTER**. O gate de Database para 001 é **re-ratificação de zero-ALTER**, não um novo apply.
- **OD-V1 e OD-V2 permanecem OPEN DECISIONS — não resolvidas** neste documento (ver §8).

## 4. Estado de arquitetura

### 4.1 Verde — o que já existe

**Substrato de banco — 100% aplicado, ZERO migration necessária** (verificado coluna a coluna):

| Objeto | Fase | Suporte a 001 |
|---|---|---|
| `report_runs` | phase3 (aplicada) | Âncora completa: `id` (run_id), `keyword`/`vertical` (defaults travados), `window_start`/`window_end` (+ CHECK `window_end ≥ window_start`), `target_video_count = 500`, `collected_video_count` (nullable até finalizar), `youtube_quota_used`, `status` enum `created→collecting→processed→published→failed`. Row-guard permite `UPDATE` de status/contadores, **congela** identidade de coleta (keyword/vertical/janela) e bloqueia DELETE/TRUNCATE. Casa com o ciclo de vida do §2 da spec. |
| `raw_youtube_search_pages` | phase4 (aplicada) | Byte-idêntico ao §3.3: `run_id` FK RESTRICT, `page_token` (null = 1ª página), `response_json` NOT NULL, `fetched_at`; unique `(run_id, coalesce(page_token,''))`; CHECK SEC-F08 anti-envelope; triggers de imutabilidade; RLS default-deny; revoke anon/authenticated. |
| `raw_youtube_videos` | phase4 (aplicada) | Byte-idêntico ao §4.3: `run_id` FK RESTRICT, `video_id`, `channel_id`, `title`, `published_at`, `views`/`likes`/`comments` bigint nullable, `raw_json` NOT NULL, `fetched_at`; unique `(run_id, video_id)`; índice `(run_id, channel_id)`; CHECK SEC-F08; triggers; RLS; revoke. |

**Contrato — `DATA-COLLECT-001/v1` completo e review-ready.** Invariantes travados (keyword/janela/~500/vertical/fonte), ciclo de `run_id` (§2), contrato `search.list` (§3), `videos.list` (§4), append-only/idempotência (§5), fail-closed (§6), gate de completude §7, gate de segurança SEC-F23 + 5 testes obrigatórios (§8), pré-condição P5-REPRO-01 (§9), Stop Conditions (§10).

**Downstream (002) construído e estruturalmente bloqueado — corretamente.** `channel_collection.py` + `test_channel_collection.py` + `channel_data_post_collection_verify.sql` + `youtube-collection.yml` ARMADO. O workflow exige `run_id` de entrada cujo snapshot de vídeo já passou §7 — que só nasce de 001.

**Governança comprovada.** A trilha SG-0..SG-8 do DEC-0018 (002) é o template reutilizável.

### 4.2 Topologia da dependência

```
DATA-COLLECT-001 (NÃO EXISTE em código)          DATA-COLLECT-002 (ARMADO, ocioso)
┌─────────────────────────────────────┐          ┌──────────────────────────────────┐
│ Agente 1: search.list               │          │ channels.list → raw_youtube_     │
│   → raw_youtube_search_pages        │          │   channels                       │
│ Agente 2: videos.list               │  run_id  │ INPUT: run_id §7-passed  ◄───────┼── depende
│   → raw_youtube_videos              │ ────────►│ youtube-collection.yml           │
│ CRIA report_runs (novo run_id)      │ congelado│ REUSA run_id (nunca cria)        │
│ §7 vídeo → collected_video_count    │  §7-pass │ §7 canal (set-equality)          │
└─────────────────────────────────────┘          └──────────────────────────────────┘
        ↑ ESTE é o gap                                    ↑ pronto, esperando input
```

## 5. Gaps (o que falta para 001 produzir um `run_id` válido)

| # | Gap | Análogo existente em 002 | Severidade |
|---|---|---|---|
| **G1** | **Collector de vídeo inexistente.** Nenhum Agente 1 (`search.list → raw_youtube_search_pages`) nem Agente 2 (`videos.list → raw_youtube_videos`). `data-engine` só tem `channel_collection.py`. | `channel_collection.py` | **Bloqueante** |
| **G2** | **Testes §8 do collector de vídeo ausentes** (os 5 obrigatórios: spy body-not-envelope; payload limpo vs. sujo; canary de log/Sentry; quota/erro entre lotes → `failed`; retry/restart sem duplicação). | `test_channel_collection.py` | **Bloqueante** |
| **G3** | **Verify §7 de vídeo ausente.** Nenhum SQL de completude (cadeia de tokens verbatim, set-equality `(run_id,video_id)`, projeção == raw_json, no-envelope, `collected_video_count ≤ 500`). | `channel_data_post_collection_verify.sql` | **Bloqueante** |
| **G4** | **Pipeline de coleta de vídeo inexistente.** Nenhum workflow gated para o estágio de vídeo. Diferença topológica crítica: 001 **CRIA** o `run_id` (gera UUID + escreve `report_runs`); 002 apenas **REUSA**. O YAML de 001 não recebe `run_id` como input — ele o produz. | `youtube-collection.yml` (com `run_id` de input) | **Bloqueante** |
| **G5** | **Nenhum `run_id` §7-passed jamais produzido.** `report_runs` não tem run de vídeo congelada. Por isso 002/SG-6 = NO-GO. | — | **Estado esperado** |
| **G6** | **Perfil de quota/custo não re-escopado.** `search.list` = ~100 unid/chamada × ~10 páginas ≈ 1000 + `videos.list` ~1 × ~10 ≈ 10 → **~1010 unid/run** (~10% da cota diária padrão de 10k). O F-1 do DEC-0018 foi atestado para os ~10 unid/run do Channel Data. Search é ~100× mais pesado por página; retry storm multiplica rápido. | F-1 (escopado p/ ~10 unid) | **Alto — re-escopo** |
| **G7** | **Decisão de topologia de Environment aberta.** 001 reusa o Environment `youtube-collection` (mesma `YOUTUBE_API_KEY`, mesmos reviewers) ou ganha trilha própria? A mesma chave é inevitável (mesmo projeto Google), mas workflow/reviewers/arm podem ser separados. | Environment `youtube-collection` | **OPEN DECISION (OD-V1)** |

## 6. Riscos

| # | Risco | Mitigação |
|---|---|---|
| **R1** | **Custo/quota elevado vs. 002.** `search.list` = ~100 unid/chamada; re-dispatch ou retry storm queima cota/billing e pode estourar o teto diário de 10k no meio da run (fail-closed → run falha → quota desperdiçada). | Re-escopo F-1' na Fase A2: cap por-run, budget de retry versionado (§6), alerta de quota, API-restriction reconfirmada. |
| **R2** | **Primeiro egress real de `search.list` + manejo de token.** `pageToken` é superfície de correção **e** de segurança (verbatim, sem ciclo, sem fabricação; proibido em log §8). | Contrato §3.2 + teste canary de log §8; verify §7 valida integridade da cadeia. |
| **R3** | **Caminho de escrita em `report_runs` é novo.** 001 é o 1º path de CI que muta STATE de `report_runs` (não só raw). Crash em `collecting` com `collected_video_count = NULL` não pode parecer completo. | A3 atesta atomicidade da finalização; §6 fail-closed; retomada só pelas regras idempotentes do §5. |
| **R4** | **Idempotência/replay sob falha parcial.** Retomada de run `collecting` deve reusar páginas/lotes persistidos, nunca re-requisitar/sobrescrever (sobrescrita bate no trigger de imutabilidade → falha dura). | Teste §8 (retry/restart sem duplicação); índices únicos já impostos pelo schema. |
| **R5** | **Ambiguidade `source_exhausted` vs. erro.** Parada < 500 tem de ser exaustão natural provável, nunca quota/erro mascarado. | Política congelada em A1; §3.2.7 exige review Product Orchestrator + Data/AI do volume real. |
| **R6** | **§7 é load-bearing.** É a **única** coisa que certifica o `run_id` como input válido do 002. §7 fraco deixa snapshot ruim fluir para Channel Data. | B3 tão rigoroso quanto o verify de canal: set-equality, integridade de cadeia, no-envelope. |
| **R7** | **Higiene de secret sob novos shapes de payload.** Body de search + item de vídeo maiores/diferentes; CHECK SEC-F08 + scrub body-only têm de segurar. | Teste canary obrigatório §8; CHECK anti-envelope já no schema. |
| **R8** | **Dependência P5-REPRO-01.** Se o raw não for verbatim (vazamento de envelope, não-determinismo), o replay quebra e o publish fica barrado para sempre. | §9 + SG-8 bloqueante; verify §7 exige `raw_json` == projeção. |
| **R9** | **Blast-radius de Environment.** Reuso vs. dedicado (G7/OD-V1). Em qualquer caso: **sem `SUPABASE_ACCESS_TOKEN`, sem service-role** (least-privilege preservado). | OPEN DECISION em A2/C3. |
| **R10** | **Scope creep / Stop Conditions.** Alargar keyword/janela/volume "para chegar a 500" é Stop Condition dura. Não tocar em `0007`; Fase 9/RLS vetada; publish barrado. | §10 do contrato + restrições permanentes da trilha. |

## 7. Sequência segura de implementação (SG-V0..SG-V8)

Cada fase é fail-closed; **nada bate na API até o dispatch humano (Fase D)**. O `youtube-collection` (002) permanece ARMADO e OCIOSO o tempo todo. Rótulo `SG-V*` para não colidir com a numeração do 002.

**Fase A — Ratificar design (zero código):**
- **A1 · Product Orchestrator:** ratificar params ~500/keyword/janela/vertical; confirmar topologia de criação de run (001 cria `run_id`; 002 reusa); congelar política `source_exhausted` (parada < 500 exige review Product Orchestrator + Data/AI, nunca máscara de erro).
- **A2 · Security (`audit_secrets`):** re-escopar dado + chave. SEC-F23 do body de vídeo (title/stats), CHECK SEC-F08, scrub body-only, `pageToken` proibido em log. Re-escopar **F-1'** para ~1010 unid + budget de retry + cap por-run + alerta de quota. Encaminhar OD-V1.
- **A3 · Database (`review`):** re-ratificar **zero ALTER**; atestar atomicidade da finalização (`collecting → collected_video_count`) e que o row-guard permite UPDATE de status/contador. Confirmação, **não migration**.

**Fase B — Construir código inerte (offline, sem rede):**
- **B1 · Data/AI + Backend:** autorar o collector de vídeo (Agente 1 + Agente 2) fiel ao contrato: ciclo de `run_id`, paginação determinística verbatim sem ciclo, append-only, fail-closed, scrub body-only.
- **B2:** os 5 testes §8 (todos mockados, zero egress).
- **B3:** o verify §7 de vídeo (SQL, análogo ao de canal).

**Fase C — Pipeline (design-only, DISARMED ao aterrissar):**
- **C1 · DevOps:** autorar o workflow gated de coleta de vídeo — `workflow_dispatch` + frase de confirmação + ack de irreversibilidade + Environment required reviewers + SEC-F18 main-only + SHA-pin + `contents: read` + DB URL mascarada + header `X-Goog-Api-Key` + body-only + preflight de arm fail-closed próprio. **Semântica de criação de run** (gera UUID, escreve `report_runs`; sem input `run_id`).
- **C2 · Security:** `audit_secrets` **SEPARADO deste YAML** (análogo F-2') — não herda a liberação do 002; novo egress `search.list` + novo caminho de escrita em `report_runs` + quota mais pesada.
- **C3 · DevOps:** `configure_env`/re-escopo — API-restriction confirmada para `search.list`, threshold de alerta para ~1010+retries, cap por-run.

**Fase D — Gate humano + run:**
- **D1:** dispatch humano do `main` + confirmação + ack + required reviewers aprovam (fronteira humana).
- **D2:** collect → **gate §7** → se passar, `collected_video_count` congelado e `run_id` fica §7-passed.
- **D3:** esse `run_id` vira o input do SG-6 do `youtube-collection.yml` (002) — que hoje é NO-GO exatamente por isto.
- **D4:** P5-REPRO-01 permanece bloqueante antes de qualquer publish.

### 7.1 Checklist de gate — trilha DATA-COLLECT-001 (vídeo)

| Gate | Conteúdo | Estado |
|---|---|---|
| **SG-V0** | Pré-req: substrato de DB aplicado (`report_runs` + `raw_youtube_search_pages` + `raw_youtube_videos`, phase3/4) — **zero migration nova**; spec `DATA-COLLECT-001/v1` completa | ✅ **verde** (verificado neste handoff) |
| **SG-V1** | Product Orchestrator ratifica: params ~500/keyword/janela/vertical; topologia de criação de run; política `source_exhausted` | ⬜ pendente (próximo passo) |
| **SG-V2** | Security `audit_secrets`: SEC-F23 body de vídeo + SEC-F08 + scrub body-only + `pageToken` log-proibido + **F-1' re-escopo de quota (~1010 + retry + cap + alerta)** + decisão de Environment (OD-V1) | ⬜ pendente |
| **SG-V3** | Database re-ratifica: zero ALTER; atomicidade da finalização + path de UPDATE de status/contador; índices/imutabilidade cobrem 001 (**confirmação, não apply**) | ⬜ pendente |
| **SG-V4** | Data/AI + Backend autoram collector de vídeo (Agente 1+2) — inerte/offline, fiel ao contrato | ⬜ pendente |
| **SG-V5** | 5 testes §8 + verify §7 de vídeo (SQL) | ⬜ pendente |
| **SG-V6** | DevOps autora workflow gated de vídeo (**semântica de criação de run**; disarmed) + **Security `audit_secrets` SEPARADO deste YAML (F-2')** + `configure_env`/quota | ⬜ pendente |
| **SG-V7** | **Dispatch humano** + confirmação + ack irreversibilidade + required reviewers → collect → **§7 passa → `run_id` congelado** | ⬜ pendente (fronteira humana; **NO-GO agora**) |
| **SG-V8** | Handoff: `run_id` §7-passed vira input do SG-6 do `youtube-collection.yml` (002) | ⬜ downstream |
| **SG-8 (global)** | **P5-REPRO-01** — bloqueante antes do 1º publish | ⬜ pré-publish |

## 8. OPEN DECISIONS (não resolvidas)

- **OD-V1 (G7 · Security + DevOps):** Environment reutilizado vs. dedicado para o estágio de vídeo. A `YOUTUBE_API_KEY` é a mesma (mesmo projeto Google); workflow/arm/reviewers podem ser separados. **Não resolvida** — escalar ao Product Lead via Security/DevOps.
- **OD-V2 (G6 · Security):** threshold de re-escopo do **F-1'** — cap por-run e budget de retry para ~1010 unid/run. **Não resolvida** — escalar ao Product Lead via Security.

## 9. Próximo passo recomendado

Abrir **SG-V1** (ratificação Product Orchestrator dos parâmetros + topologia de criação de run + política `source_exhausted`) e, **em paralelo, encaminhar OD-V1/OD-V2 a Security**. Isso destrava a Fase A **sem tocar em código, API, secret, deployment ou no pipeline armado**. Nada aqui altera o estado ocioso do `youtube-collection` nem aproxima o SG-6 do 002 — que continua corretamente **NO-GO** até existir `run_id` upstream §7-passed.

## 10. Restrições honradas / Intocados

- **Docs-only.** Nenhum código, workflow, migration, secret, GCP, Supabase, dispatch ou deployment tocado.
- **Intocados:** `.github/workflows/youtube-collection.yml`; `.github/collection/youtube-collection.armed`; `services/data-engine/*` (collector/testes); `supabase/migrations/*` (schema já vivo, **zero ALTER**); `supabase/tests/*` (verify); `20260620000007_phase6_producer_events.*` (**PARKED**).
- **Vetos ativos reafirmados:** SG-6 não executado; sem dispatch; sem deployment; sem Channel Data sem `run_id` válido; `0007` intocado; Fase 9/RLS vetada; publish barrado até SG-8/P5-REPRO-01; secrets/GCP/Supabase intocados; zero migration/commit/PR sem autorização explícita.
- **Zero valor sensível.** Este documento cita apenas **nomes** de secrets/vars (`YOUTUBE_API_KEY`, `SUPABASE_DB_PASSWORD`) — nenhum valor, token, URL com query string, senha ou credencial.
