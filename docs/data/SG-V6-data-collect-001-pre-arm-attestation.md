# SG-V6 — DATA-COLLECT-001 Pre-Arm Attestation (Video Collection Track)

## 1. Identificação

- **Documento:** Atestação de estado pré-arm (SG-V6) — **não** é DEC, **não** autoriza arm, **não** autoriza coleta.
- **Trilha:** `DATA-COLLECT-001` — coleta de vídeo upstream (`search.list → raw_youtube_search_pages`, `videos.list → raw_youtube_videos`).
- **Gate:** SG-V6 — registrar o estado atual da trilha após o pouso do workflow DISARMED e deixar **explícito** que o arm continua **BLOQUEADO** até `F1'-c` e `F1'-d` ficarem **GREEN**.
- **Owner:** Product Orchestrator (co-lead de produto).
- **Data:** 2026-07-08
- **Natureza:** DOCS-ONLY / ATTESTATION-ONLY — zero alteração de workflow, zero criação de `.armed`, zero dispatch, zero toque em secrets/GCP/Supabase/Environment/migrations/CI gates, zero alteração de código de coleta.
- **Fontes vinculantes:** `docs/data/HANDOFF-data-collect-001-video-track.md §7.1` (checklist SG-V0..SG-V8); `docs/data/SG-V1-data-collect-001-product-ratification.md §8` (GO de produto); `docs/data/SG-V3-data-collect-001-database-ratification.md §8` (GO de Database); `docs/security/SEC-0023-sg-v2-data-collect-001-video-collection-review.md §8` (**checklist F-1' `F1'-a..g`**) + `§10`; `docs/security/SEC-0022-youtube-collection-sg4-sg5-closeout.md §1` (Environment `youtube-collection` provisionado/co-assinado); `.github/workflows/video-collection.yml` (workflow DISARMED landed via PR #40); **PR #40** (corpo — registra o veredito Security **F-2' `audit_secrets` = APPROVE WITH NOTES**, GO para landing DISARMED); **PR #39** (coletor emite `run_id` → `$GITHUB_OUTPUT` — fecha a nota **`F2'-N1`**).

## 2. Objetivo

Congelar, num único registro auditável, o **estado atual** da trilha de vídeo `DATA-COLLECT-001` no gate SG-V6 e emitir o veredito de que **NÃO há autorização de arm, de dispatch (SG-V7) nem de SG-6 (Channel Data)** enquanto as duas condições de atestação out-of-band do F-1' — **`F1'-c`** (alertas de quota re-confirmados para o perfil ~1010 unid) e **`F1'-d`** (API-restriction da mesma key re-confirmada) — não estiverem **GREEN** e co-assinadas.

Este documento **não implementa nem altera nada**: entrega o snapshot de estado, a checklist pré-arm consolidada e a decisão GO/NO-GO. O `youtube-collection` (Channel Data / 002) permanece **ARMADO e OCIOSO** e o `video-collection` (vídeo / 001) permanece **DISARMED** o tempo todo.

## 3. Invariantes de estado (declarações explícitas obrigatórias)

- **SG-V6 YAML landed em `main` via PR #40.** `.github/workflows/video-collection.yml` está em `main` (merge `e2360de`, PR #40 `MERGED` em 2026-07-07). É a entrega de DevOps do SG-V6 — arquivo **novo**, distinto do `youtube-collection.yml`, com **semântica de criação de run** (gera UUID + escreve `report_runs`; **sem** `run_id` de input).
- **`video-collection.yml` está DISARMED e NUNCA foi dispatchado.** O estado disarmed é imposto por construção (§4). Histórico de execução da workflow = **vazio** (zero runs; nenhum `workflow_dispatch` jamais acionado).
- **`.github/collection/video-collection.armed` está AUSENTE.** Verificado em `origin/main`: o marker de arm **próprio** desta pipeline (distinto de `youtube-collection.armed`) **não existe**. Sua **ausência é o estado disarmed**. Criá-lo é o **ato consciente e humano do DevOps** — não feito aqui, não autorizado aqui.
- **SG-6 (Channel Data / 002) continua NO-GO.** Não existe `run_id` de vídeo **congelado e §7-passed**. Esse `run_id` só pode nascer de um dispatch real de `DATA-COLLECT-001` (SG-V7), que é **NO-GO agora**. `youtube-collection` segue **ARMADO e OCIOSO** (`.armed` em `main`, `TOTAL_RUNS=0`, sem dispatch/coleta), **intocado**.
- **Bloco 3 — Environment `youtube-collection` → GREEN.** Provisionado e co-assinado por Security em `SEC-0022 §1`: branch policy `main`-only (SEC-F18), `required_reviewers = User:AdeptLabsDev`, secrets = exatamente `{YOUTUBE_API_KEY, SUPABASE_DB_PASSWORD}`, **sem** `SUPABASE_ACCESS_TOKEN` (incapaz de `db push`), **sem** `SUPABASE_SERVICE_ROLE_KEY` (SEC-F19), vars `{HOST, PORT, USER}`. Por OD-V1 (recomendação de Security, `SEC-0023 §3.1`), a trilha de vídeo **reutiliza** este Environment com **workflow separado** — nenhum 2º Environment é provisionado. **Nada a provisionar aqui; nada tocado aqui.**
- **`F1'-c` — PENDENTE.** Alerta per-run (> ~1.500 unid) + alertas GCP diários (50%/80% de 10k) **RE-CONFIRMADOS para o perfil de ~1010 unid** de vídeo (não o de ~10 do canal). Owner: DevOps + Security (co-sign). Verificação: **atestação out-of-band**. Estado: ⏳ **pendente** (`SEC-0023 §8`, item `F1'-c`).
- **`F1'-d` — PENDENTE.** API-restriction da **mesma** key = *YouTube Data API v3* re-confirmada; **sem key nova**; rotação (≤90d / pós-run / troca de pessoal / suspeita de leak) válida para o uso mais pesado. Owner: Security (atesta). Verificação: **atestação out-of-band**. Estado: ⏳ **pendente** (`SEC-0023 §8`, item `F1'-d`).
- **`F-2'` / `F1'-g` — GREEN (não é bloqueio de arm).** O `audit_secrets` **SEPARADO** do YAML de vídeo (F-2') já foi executado: veredito **APPROVE WITH NOTES** (GO para landing DISARMED), registrado no corpo do **PR #40**. Os controles repo-verificáveis estão **presentes no YAML landed em `main`**: `permissions: contents: read`, header `X-Goog-Api-Key` (nunca `?key=`), actions SHA-pinadas (SEC-F17), **sem** `SUPABASE_ACCESS_TOKEN` / **sem** service-role (SEC-F19), backstop SEC-F18 main-only. A **única** nota do F-2' — **`F2'-N1`** (coletor emite `run_id` → `$GITHUB_OUTPUT` para o job verify) — está **GREEN em `main`** (PR #39; `services/data-engine/src/noxund_data_engine/video_collection.py`). *NOTE de parity documental, não-bloqueante:* o veredito F-2' vive no corpo do PR #40 (não há SEC-doc autônomo); gap documental, não funcional.
- **`F1'-f` — pré-live/canary (não é bloqueio de arm).** Ver classificação explícita em §6/§7.

## 4. Como o estado DISARMED é imposto (evidência do repo)

O `guard` job do `video-collection.yml` roda **antes** de qualquer contato com o Environment ou secret e é fail-closed. O controle load-bearing é o **arming preflight**, que exige **duas condições independentes, todas obrigatórias**:

| Condição do preflight | O que exige | Estado verificado em `origin/main` |
|---|---|---|
| **(1) Arm marker próprio** | `.github/collection/video-collection.armed` presente (distinto de `youtube-collection.armed`) | ⛔ **AUSENTE** → **DISARMED** (aborta com NENHUMA coleta) |
| **(2a) Collector** | `services/data-engine/src/noxund_data_engine/video_collection.py` | ✅ presente (SG-V4) |
| **(2b) Testes §8** | `services/data-engine/tests/test_video_collection.py` | ✅ presente (SG-V4) |
| **(2c) Verify §7 SQL** | `supabase/tests/video_data_post_collection_verify.sql` | ✅ presente (SG-V5) |

Ou seja: o código inerte (SG-V4/V5) está **todo presente** — a **única** coisa que mantém a pipeline disarmed é a **ausência deliberada do arm marker**. Camadas adicionais fail-closed já no YAML: frase de confirmação `RUN-VIDEO-COLLECTION`, ack `I-UNDERSTAND-RAW-IS-IRREVERSIBLE`, backstop SEC-F18 (`dispatch ref MUST be refs/heads/main`), `permissions: contents: read`, actions SHA-pinadas, `concurrency` próprio (`cancel-in-progress: false`, `F1'-e`), e o gate humano de runtime dos required reviewers do Environment reusado.

## 5. Estado consolidado dos gates SG-V0..SG-V8

| Gate | Conteúdo | Estado | Evidência |
|---|---|---|---|
| **SG-V0** | Substrato de DB aplicado (`report_runs` + `raw_youtube_search_pages` + `raw_youtube_videos`, Fase 3/4); spec `DATA-COLLECT-001/v1` completa — **zero migration nova** | ✅ **verde** | handoff §4.1 |
| **SG-V1** | Product Orchestrator ratifica params/keyword/janela/vertical + topologia de criação de run + `source_exhausted` | ✅ **GO** | `SG-V1 §8` (PR #35) |
| **SG-V2** | Security `audit_secrets` (SEC-F23 body de vídeo, SEC-F08, scrub body-only, `pageToken` log-proibido, **F-1'**, OD-V1/OD-V2) | ✅ **GO (design)** | `SEC-0023 §10` (PR #36) |
| **SG-V3** | Database re-ratifica zero-ALTER + atomicidade da finalização + idempotência/imutabilidade | ✅ **GO (design)** | `SG-V3 §8` (PR #36) |
| **SG-V4** | Collector de vídeo (Agente 1+2) + 5 testes §8 — inerte/offline | ✅ **landed** | PR #37 + fix PR #38 (F1'-a/b em código) + PR #39 (run_id → `$GITHUB_OUTPUT`) |
| **SG-V5** | Verify §7 de vídeo (SQL) | ✅ **landed** | `video_data_post_collection_verify.sql` em `main` |
| **SG-V6** | DevOps autora workflow gated de vídeo (**DISARMED**) + `F-2'`/`F1'-g` (audit_secrets do YAML) + `configure_env`/quota (`F1'-c`/`F1'-d`) + Sentry-scrub/canary (`F1'-f`) | ⏳ **em curso** — YAML DISARMED landed (**PR #40**); **`F-2'`/`F1'-g` GREEN** (APPROVE WITH NOTES; nota `F2'-N1` fechada em `main`, PR #39). **Restam:** `F1'-c`/`F1'-d` (out-of-band, **bloqueiam arm**) + `F1'-f` (**pré-live/canary**, bloqueia o 1º run, não o arm) | este doc + `SEC-0023 §8` + PR #40 |
| **SG-V7** | **Dispatch humano** + confirmação + ack irreversibilidade + required reviewers → collect → **§7 passa → `run_id` congelado** | ⛔ **NO-GO agora** (fronteira humana; bloqueado por SG-V6 incompleto) | `SG-V1 §8` |
| **SG-V8** | Handoff: `run_id` §7-passed vira input do SG-6 do `youtube-collection.yml` (002) | ⬜ **downstream** | handoff §7.1 |
| **SG-8 (global)** | **P5-REPRO-01** — bloqueante antes do 1º publish | ⬜ **pré-publish** | handoff §7.1 |

## 6. Checklist F-1' pré-arm (fonte: `SEC-0023 §8`)

**Nenhuma chamada real a `search.list`/`videos.list` antes de TODOS verdes.** As duas condições que este doc destaca como **bloqueantes do arm** são `F1'-c` e `F1'-d` (atestação out-of-band).

| # | Condição F-1' | Owner | Verificação | Estado |
|---|---|---|---|---|
| **F1'-a** | Cap de quota por-run (hard budget) imposto; ultrapassagem projetada → fail-closed | Data/AI + DevOps | repo (código/YAML) | ✅ **em código** (PR #38) |
| **F1'-b** | Retry ≤ 2/chamada em classe transitória; `quotaExceeded`/`dailyLimitExceeded` **terminal, nunca retentado**; surplus ≤ ~500 unid/run | Data/AI | repo + teste §8.4 | ✅ **em código** (PR #38) |
| **F1'-c** | **Alerta per-run (> ~1.500 unid) + alertas GCP diários (50%/80% de 10k) RE-CONFIRMADOS para o perfil ~1010** (não o de ~10 do canal) | DevOps + Security (co-sign) | **atestação out-of-band** | ⏳ **PENDENTE — bloqueia arm** |
| **F1'-d** | **API-restriction da mesma key = YouTube Data API v3 re-confirmada; sem key nova; rotação (≤90d/pós-run/pessoal/leak) válida** | Security (atesta) | **atestação out-of-band** | ⏳ **PENDENTE — bloqueia arm** |
| **F1'-e** | Concurrency próprio do workflow de vídeo (`cancel-in-progress: false`) + avaliar gate quota-aware 001↔002 | DevOps | repo (YAML) | ✅ **no YAML** (PR #40) |
| **F1'-f** | Sentry-scrub desligado/redatado (URL/params/breadcrumbs) p/ canary §8.3 fechar | DevOps + Security | atestação + teste | ⏳ **pendente — PRÉ-LIVE/CANARY** (não bloqueia o arm; owed antes do 1º run real / SG-V7) |
| **F1'-g** | **F-2'** — audit_secrets SEPARADO do YAML de vídeo (SHA-pin SEC-F17, `contents:read`, SEC-F18, header `X-Goog-Api-Key`, service-role não usada) | Security | repo (YAML) + PR #40 | ✅ **GREEN** — F-2' **APPROVE WITH NOTES** (PR #40); controles presentes no YAML landed; **nota `F2'-N1` fechada** (`run_id` → `$GITHUB_OUTPUT`, PR #39) |

**Estado consolidado do F-1' (sem ambiguidade):**

- ✅ **GREEN:** `F1'-a`, `F1'-b` (código, PR #38), `F1'-e` (YAML, PR #40), `F1'-g`/`F-2'` (APPROVE WITH NOTES, PR #40; nota `F2'-N1` fechada, PR #39).
- ⏳ **Bloqueios de arm — REALMENTE PENDENTES (out-of-band, co-sign):** **`F1'-c`** e **`F1'-d`**. São os **únicos** dois itens cuja pendência mantém o arm em NO-GO.
- ⏳ **Pré-live/canary (não bloqueia o arm):** **`F1'-f`** — condição do **1º run real** (SG-V7), fechada no `configure_env` + teste canary §8.3, owner DevOps + Security. Não é atestação out-of-band pré-arm nem pendência descartável: é pré-condição do dispatch, distinta da decisão de arm.

> Este documento **não resolve** nenhum item do F-1'. Os **thresholds exatos** de quota permanecem **OD-V2** (decisão do Product Lead; `SEC-0023 §4`, floors recomendados).

## 7. Decisão (GO / NO-GO)

- **Arm da pipeline de vídeo → ⛔ NO-GO.** O commit de `.github/collection/video-collection.armed` **não está autorizado** enquanto **`F1'-c` e `F1'-d`** — os **únicos** bloqueios de arm realmente pendentes — não estiverem **GREEN** e co-assinados (atestação out-of-band). O `F-2'`/`F1'-g` **já está fechado** (APPROVE WITH NOTES, PR #40; nota `F2'-N1` em `main`, PR #39) e **não** bloqueia o arm. O `F1'-f` é **pré-live/canary**: não bloqueia o commit do marker (o preflight do YAML não o exige), mas deve ficar **GREEN antes do 1º dispatch real (SG-V7)**. O marker permanece **ausente**; sua criação é ato humano consciente do DevOps, pós-atestação.
- **Dispatch SG-V7 → ⛔ NO-GO.** Sem arm não há collect. Mesmo com arm, o dispatch exige `main` + `RUN-VIDEO-COLLECTION` + `I-UNDERSTAND-RAW-IS-IRREVERSIBLE` + aprovação dos required reviewers do Environment — fronteira humana, **não autorizada agora**.
- **SG-6 (Channel Data / 002) → ⛔ NO-GO (inalterado).** Bloqueado por dependência estrutural: não existe `run_id` de vídeo §7-passed. `youtube-collection` segue **ARMADO e OCIOSO**, intocado.
- **Estado das pipelines mantido:** `video-collection` **DISARMED** (nunca dispatchado); `youtube-collection` **ARMADO e OCIOSO** (`TOTAL_RUNS=0`).

## 8. Próximo passo seguro

1. **Fechar `F1'-c`** (DevOps + Security co-sign): re-confirmar alerta per-run > ~1.500 unid + alertas GCP diários 50%/80% de 10k calibrados para o perfil de ~1010 unid — registrar por **atestação out-of-band** (evidência privada fora do repo, como em `SEC-0022 §2`).
2. **Fechar `F1'-d`** (Security atesta): re-confirmar API-restriction da **mesma** key à *YouTube Data API v3*, sem key nova, com política de rotação válida — **atestação out-of-band**.
3. **`F1'-g`/`F-2'` — nada a fazer para o arm:** já GREEN (APPROVE WITH NOTES, PR #40; nota `F2'-N1` em `main`, PR #39). *Opcional, parity documental:* registrar o veredito F-2' num SEC-doc autônomo (hoje vive no corpo do PR #40) — não-bloqueante.
4. **`F1'-f` (pré-live/canary)** — fechar no `configure_env` (Sentry-scrub desligado/redatado + teste canary §8.3), owner DevOps + Security. É condição do **1º run real (SG-V7)**, não do arm.
5. **Só então** — com `F1'-c`/`F1'-d` GREEN — o DevOps decide, conscientemente, commitar o arm marker (fim do estado disarmed); com `F1'-f` GREEN, o SG-V7 (dispatch humano) passa a ser elegível. **Nada roda até lá.**

## 9. Restrições honradas / Intocados

- **Docs-only / attestation-only.** Nenhum workflow, marker `.armed`, dispatch, secret, GCP, Supabase, Environment, migration, CI gate ou código de coleta tocado. **Nada implementado, nada armado, nada dispatchado.**
- **Intocados:** `.github/workflows/video-collection.yml`; `.github/workflows/youtube-collection.yml`; `.github/collection/*` (nenhum `.armed` criado — `video-collection.armed` permanece **ausente**); `services/data-engine/*` (collector/testes); `supabase/migrations/*` (schema já vivo, **zero ALTER**); `supabase/tests/*` (verify); `20260620000007_phase6_producer_events.*` (**PARKED**, intocado).
- **Vetos ativos reafirmados:** arm NO-GO; SG-V7 dispatch NO-GO; SG-6 NO-GO; sem coleta; `0007` intocado; Fase 9/RLS vetada; publish barrado até SG-8/P5-REPRO-01; secrets/GCP/Supabase/Environment intocados; zero commit/push/PR além deste doc single-purpose.
- **Zero valor sensível.** Cita apenas **nomes** de secrets/vars (`YOUTUBE_API_KEY`, `SUPABASE_DB_PASSWORD`) e o project ref (não-secreto, aparece na URL do projeto) — nenhum valor, token, URL com query string, senha, connection string ou credencial. Nenhum screenshot.

---

## 10. Adendo (2026-07-14) — `F1'-c`/`F1'-d` fechados GREEN + correção de redação

Os §§1–9 acima são o snapshot congelado de 2026-07-08 e **não foram reescritos**. Este adendo registra a mudança de estado posterior:

- **`F1'-c` e `F1'-d` fecharam ✅ GREEN em 2026-07-14**, por atestação out-of-band do Product Lead sob os thresholds finais de **OD-V2** (`DEC-0020`). Registro completo: `docs/security/SEC-0024-sg-v6-f1c-f1d-closeout.md`. Com isso, **não resta bloqueio de arm no F-1'**.
- **Correção de redação:** este doc (§3/§6/§8) e o `SEC-0023 §8` descreviam o fechamento de `F1'-c` como "re-confirmação" de alertas existentes. O fechamento real deu-se pela **criação de três políticas novas** de alerta no GCP (`noxund-prod`) em 2026-07-14 — **ato humano de configuração do Product Lead, dentro da própria alçada** — nos thresholds de OD-V2 (≥ 1.500/run em rolling 30 min com avaliação a cada 60 s; diários ≥ 5.000 e ≥ 8.000; quota diária confirmada em 10.000). A única política pré-existente (legada, 30%) **permanece ativa** e intocável sem autorização separada (`DEC-0020`). Ou seja: durante o fechamento de E5a **o GCP foi modificado pelo Product Lead**; as declarações de "zero toque em GCP" deste doc valem para os agentes e para o mandato docs-only de 2026-07-08, e permanecem verdadeiras nesse escopo. Requisito satisfeito em rigor igual ou superior ao previsto.
- **O NO-GO de arm do §7 está superado apenas quanto a `F1'-c`/`F1'-d`.** A criação do marker `video-collection.armed` permanece **ato humano consciente, não autorizado** até ordem explícita; `F1'-f` segue **pré-live** (bloqueia o 1º dispatch/SG-V7, não o arm); SG-V7 e SG-6 seguem **NO-GO**.

## 11. Adendo (2026-07-15) — pipeline ARMADA; `F1'-f` fechado GREEN; F-1' COMPLETO

- **A pipeline foi ARMADA em 2026-07-15**: `.github/collection/video-collection.armed` commitado por ato consciente (Product Lead GO; PR #43, merge `13c2258`). Permanece **OCIOSA**: 0 runs, nenhum dispatch jamais acionado.
- **`F1'-f` fechou ✅ GREEN em 2026-07-15** — registro completo em `docs/security/SEC-0025-f1f-sentry-canary-closeout.md`. Síntese: **Sentry não integra o runtime de coleta** (ausência estrutural de SDK/DSN/import — não houve "scrub", não havia o que desligar); canary §8.3 **verde no `main` vigente** (`13c2258`, run `29385668057` via `workflow_dispatch`, 171/171 ×2, zero egress/mutação); **cláusula anti-drift**: telemetria futura no caminho de coleta reabre `F1'-f` + novo `audit_secrets`; placeholders Sentry da stack web fora de escopo enquanto não compartilharem processo com a coleta.
- **Com isso o checklist F-1' está COMPLETO (`F1'-a..g` todos GREEN)** e não resta pendência técnica pré-live. A **única fronteira antes da primeira coleta real é o SG-V7** — dispatch humano de `main` + `RUN-VIDEO-COLLECTION` + `I-UNDERSTAND-RAW-IS-IRREVERSIBLE` + required reviewer do Environment — **NO-GO até ordem explícita do Product Lead**. SG-6 segue NO-GO (depende de `run_id` §7-passed).
