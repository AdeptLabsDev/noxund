## DEC-0015 — Fechamento do gate board do apply de `entity_resolution_candidates` (`run_migration` aplicado e verificado — extensão aditiva da Entity Resolution, DEC-0014)

- **Data:** 2026-06-29
- **Status:** **Registrada — fato consumado.** Apply executado e verificado em CI; `task_entity_candidates_run_migration_0006` transiciona → `completed` e este closeout fecha `task_entity_candidates_run_migration_closeout`.
- **Decisor:** Product Lead (autorizou e disparou o apply gated em CI de `main`, aprovou como required reviewer) · matrix #10 (closeout) confirmada e registrada pelo Product Orchestrator · ratificação repo-side pelo `database_agent`.
- **Área:** Schema (extensão aditiva) / Segurança & Privacidade (RLS/PII) / Metodologia (Entity Resolution / determinismo) / Processo de gate
- **Relaciona:** **DEC-0014** (autorização da extensão aditiva — **fechada por esta DEC**), `DATA-ENTITY-001-entity-resolution-spec.md` (§10 gate pre-apply), `SEC-0017` (`review_rls`/PII — matrix #3, sem bloqueio), veto técnico **`DATA-ENTITY-F01`** (Data/AI) → **levantado** pós-mitigação non-blank, `HANDOFF-entity-resolution-candidates-design.md` (desenho + CHECKs F01), `HANDOFF-entity-resolution-candidates-apply-closeout.md` (ratificação repo-side), DEC-0012/0011/0010/0009/0008 (precedentes da convenção closeout+DEC), `migration-plan.md`

### Contexto
Os gates do `run_migration` desta extensão foram satisfeitos **na ordem correta**: Database (autoria) → Security (**SEC-0017** — `review_rls`/PII/SEC-F08, sem bloqueio) → Data/AI (**veto técnico pre-apply `DATA-ENTITY-F01`**: `resolver_version`/`prompt_version` aceitavam `''`/whitespace, quebrando determinismo/replay) → **mitigação design-only** pelo `database_agent` (2 CHECKs non-blank + probes fail-closed, **superfície SEC-0017 inalterada** → sem re-review de Security) → **re-review Data/AI** que **levantou** o veto → workflow gated dedicado `entity-db-apply.yml` (autorado por DevOps) → required reviewers do Environment `production-db`, dispatch **de `main`** (SEC-F18). A paridade de errcode do projeto (default-deny nos 2 caminhos de role — SEC-F21/F22) já estava **embutida no `verify` antes do apply**, sem hotfix. O apply ocorreu **via CI**, forward-only e atômico.

### Decisão (o que se registra)
1. **A migration `entity_resolution_candidates` está aplicada e verificada em produção:** `supabase/migrations/20260620000006_entity_resolution_candidates.sql`, forward-only, atômica (`begin` L44 … `commit` L134; **zero** drop/truncate/`delete from`; **único** `alter table` = `enable row level security` na tabela nova). Está **live** a fila durável de candidatos da Entity Resolution (staging mutável), mantendo a saída de IA não-aprovada **fora** de `artists`/`video_artist_mappings`.
2. **A extensão é aditiva e não-destrutiva:** **ZERO ALTER** de tabela aplicada/congelada; **`public.video_artist_method` reusado (não recriado)**; **`0007`/producer_events NÃO aplicado** (parked — o `preflight` `db push --dry-run` confirmou pendentes `== {20260620000006}`).
3. **O gate board do `run_migration` está integralmente fechado** (tabela abaixo). Evidência canônica no run de CI **`28343949123`**; closeout record-only em `HANDOFF-entity-resolution-candidates-apply-closeout.md` (ratificação repo-side: artefatos byte-idênticos ao commit aplicado `9a1ac52`, linha final do verify **verbatim**).
4. **DEC-0014 está fechada** por este apply: a OPEN-DATA-ENTITY-001 (fila durável tipada para candidato pendente/rejeitado sem poluir as canônicas) está resolvida no schema live.
5. **Nenhum gate downstream foi destravado.** O **veto da Fase 9 — RLS Policies + VIEW pública (SEC-0001 §0)** permanece de pé: zero `CREATE POLICY`/`CREATE VIEW` executável (as ocorrências de "create policy" são comentário); apenas `enable row level security` + `revoke` — default-deny puro vivo.

### Evidência de registro
| Item | Evidência |
|---|---|
| Run do pipeline | `entity-db-apply.yml` → https://github.com/AdeptLabsDev/noxund/actions/runs/28343949123 (origem `main`, SEC-F18) |
| Jobs | `guard` (`APPLY-ENTITY-CANDIDATES`) · `preflight` (`db push --dry-run` → pendentes `== {20260620000006}`) · `apply` (`supabase db push`, forward-only) · `verify` — todos **success** |
| Verificação | `entity_resolution_candidates_post_apply_verify.sql` com `ON_ERROR_STOP=1` → `OK — entity_resolution_candidates post-apply verification PASSED (§4 structural + §5 empirical).` |
| Aprovação em runtime | required reviewer **AdeptLabsDev**, origem `main`, rollback de produção **não** executado |
| Verificação repo-side (Database) | commit **`9a1ac52`** contém migration/verify/rollback/workflow; artefatos **byte-idênticos** (sha256) ao working tree autorado; `begin` L44 / `commit` L134; zero policy/view executável; `enable rls` + `revoke`; linha final do verify **verbatim**; `video_artist_method` intacto; `0007` não aplicado |

### Gate board final do `run_migration` `entity_resolution_candidates`
| Gate | Fonte | Estado |
|---|---|---|
| Database (schema) — autoria + mitigação F01 | HANDOFF design + closeout | ✅ |
| `review_rls`/PII (matrix #3) | **SEC-0017** (superfície inalterada por F01 → sem re-review) | ✅ |
| Data/AI — integridade da fila + replay/determinismo | veto **DATA-ENTITY-F01** → **levantado** pós-mitigação (2 CHECKs non-blank + probes) | ✅ |
| Workflow gated dedicado | `entity-db-apply.yml` (DevOps; commit `9a1ac52`) | ✅ |
| Required reviewers em CI (origem `main`, SEC-F18) | run `28343949123` | ✅ AdeptLabsDev |
| Apply forward-only + verify §4/§5 fail-closed | run `28343949123` | ✅ guard·preflight·apply·verify success |

### Impacto
- **Escopo:** nenhum desvio. 1 tabela **aditiva** de staging da única zona de IA; **zero** marketplace/Fase 2.
- **Non-negotiables — provados em banco no run (§5 empírico):**
  - **aditivo-não-destrutivo** — zero ALTER de tabela aplicada; `video_artist_method` intacto; `0007` parked;
  - **proveniência até o raw** — FK composta `(run_id, video_id) → raw_youtube_videos` **`ON DELETE RESTRICT`**; vídeo ausente/de outro run **rejeitado**; candidato não-aprovado **fora** de `artists`/`video_artist_mappings` (`proposed_name` string + `artist_id` nullable);
  - **determinismo/replay (DATA-ENTITY-F01)** — `resolver_version` non-blank (`btrim<>''`) e `prompt_version` non-blank-quando-presente (`IS NULL OR btrim<>''`, preservando regex determinístico); `''`/whitespace **rejeitados** no banco;
  - **fila mutável honesta** — `status` pending→approved/rejected por UPDATE (prova positiva), **sem** fingir imutabilidade; dedup do corrente por índice **parcial único** `(run_id, video_id) WHERE status='pending'`, preservando histórico;
  - **default-deny** — RLS-on + revoke; **zero policy/view** executável;
  - **zona determinística intacta** — fila de **nomes**, zero número/Score; IA restrita à Entity Resolution.

### Reversibilidade
Schema reversível em declaração: `supabase/rollback/20260620000006_entity_resolution_candidates.rollback.sql` permanece como rede de segurança **declarada e não executada** (drop tabela → drop enum novo; **nunca** dropa `video_artist_method`). `rollback_production` = **NÃO executado** (o contrato do workflow só dispara rollback se o verify falhar — não ocorreu).

### Carry-forward (não-bloqueante — registrado, não é gate deste apply)
- **`data_agent`** re-alinha `DATA-ENTITY-001` ao schema final aplicado e retoma a implementação: resolver/fixtures (regex-first + LLM fallback restrito) → Channel Filter → scoring → **P5-REPRO-01** (gate do `services/data-engine` antes do 1º publish — **não** deste apply).
- **`producer_events` (Fase 6, ts `0007`)** segue **parked em design** até a captura de eventos virar gargalo (DEC-0013).

### Sequenciamento (próximo)
1. **`data_agent`:** retomar Entity Resolution real sobre o schema aplicado (acima).
2. **Pipeline/1º publish:** **P5-REPRO-01** como gate fail-closed do `data-engine`.
3. **Sob veto, não sequenciar:** Fase 9 — RLS Policies + VIEW pública (SEC-0001 §0). Este apply **não** o destrava.
