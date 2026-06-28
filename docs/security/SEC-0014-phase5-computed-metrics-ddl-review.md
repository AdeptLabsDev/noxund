# SEC-0014 — Security Review (review_rls) · Fase 5 — Computed Metrics + Reports (DDL + verify)

- **Task:** `task_phase5_security_review_rls` · **Action:** `review_rls` · **Agent:** `security_agent`
- **Data:** 2026-06-27
- **SQL:** `supabase/migrations/20260620000005_phase5_computed_metrics_reports.sql`
- **Verify:** `supabase/tests/phase5_post_apply_verify.sql`
- **Handoff:** `docs/database/HANDOFF-phase5-design.md` (§5 integridade · §10/§11 revisões)
- **Base de segurança:** SEC-0001 (SEC-D03/F01/F03/F13) · SEC-0002/0003 (**SEC-F15** — padrão `SECURITY DEFINER` do `is_admin()`) · padrão de freeze/errcode-parity das Fases 1–4 (SEC-0012/0010, lição DEC-0009).
- **Mandato:** matrix #3 (Database + Security em toda migration). Gate de veto. Silêncio ≠ aprovação.
- **Status do alvo:** AUTORADO, NÃO APLICADO. `run_migration` segue gated (humano + required reviewers), em task separada.

---

## 0. Veredito

✅ **APROVADO — SEM BLOQUEIO. Meu gate (matrix #3) sobre a Fase 5 está baixado.** A superfície genuinamente nova desta fase — **3 guards cross-table `SECURITY DEFINER`** — está **endurecida no padrão SEC-F15** (search_path pinado, refs qualificadas `public.*`, **zero SQL dinâmico**, **zero entrada de usuário** na query, **zero escrita privilegiada**, não-invocável diretamente, nada retornado ao caller). O freeze do snapshot e o guard condicional da linhagem publicada rodam **por TRIGGER abaixo do service_role** (SEC-D03/F01) — RLS/grants sozinhos não bastariam, e o verify prova nos **2 role-paths** com paridade de errcode. RLS default-deny + revoke nas **6** (SEC-F13); **zero policy**, **zero VIEW** → a Fase 9 **não** é destravada. Colunas internas (`score_value`/`metrics_detail_json`/`selection_reason_json`) **sem superfície pública** nesta fase (SEC-F03).

Registro **2 notas não-bloqueantes**: a obrigação SEC-F03 (VIEW que exclui colunas internas) é carry-forward da **Fase 9** (já sob veto); e endosso o **backfill de rastreabilidade DATA-AI-0007** sinalizado pelo Orchestrator (aprovação Data/AI só no `AgentResult`) — **não bloqueia**, pois revisei o DDL/verify concretos, não a procuração.

*(Vetos de pé, à parte, intactos: **Fase 9 — RLS Policies + VIEW pública de `report_items`** (SEC-0001 §0). **P5-REPRO-01** é gate de publish/data-engine, fora deste apply.)*

---

## 1. SECURITY DEFINER — ratificação SEC-F15 (o núcleo desta review)

O padrão SEC-F15 (SEC-0002 §5.3 / SEC-0003): função `SECURITY DEFINER` só é segura com **(a)** `search_path` fixo, **(b)** referências qualificadas por schema, **(c)** sem SQL dinâmico, **(d)** sem entrada de usuário na resolução de nomes/query, **(e)** menor privilégio. Apliquei aos 5 objetos de função:

| Função | Modo | search_path | Refs | SQL dinâmico | Entrada de usuário | Escrita | Veredito |
|---|---|---|---|---|---|---|---|
| `report_items_snapshot_guard` (L482-513) | **DEFINER** | `''` (L486) | `public.reports` qualificado (L494, L502) | **nenhum** (`select … into` parametrizado por `old/new.report_id` uuid) | **nenhuma** (só id de linha; sem `format()`/`execute`) | **nenhuma** (só lê `reports.status` → raise/return) | ✅ **SEC-F15 OK** |
| `artist_metrics_published_guard` (L519-554) | **DEFINER** | `''` (L523) | `public.report_items`/`public.reports` (L529-530, L542-543) | **nenhum** (EXISTS parametrizado por `old.id`/`new.id`) | **nenhuma** | **nenhuma** | ✅ **SEC-F15 OK** |
| `artist_metric_videos_published_guard` (L565-599) | **DEFINER** | `''` (L569) | qualificado (L575-577, L585-587) | **nenhum** (EXISTS por `old/new.artist_metric_id`) | **nenhuma** | **nenhuma** | ✅ **SEC-F15 OK** |
| `reports_snapshot_guard` (L430-474) | **INVOKER** | `''` (L433) | lê **só a própria linha** (`new/old.*`); **zero** acesso a outra tabela | — | — | nenhuma | ✅ **DEFINER desnecessário, corretamente INVOKER** |
| `report_snapshot_no_truncate` (L607-616) | INVOKER | `''` (L610) | só `tg_table_name`/raise | — | — | nenhuma | ✅ |

**Por que DEFINER é a escolha SEGURA aqui (não um risco):** o escritor legítimo (`service_role`) **não detém `SELECT`** em `reports`/`report_items`. Um guard INVOKER falharia a leitura do pai e quebraria a escrita de draft legítima **ou** — pior — se o caller tivesse visibilidade parcial via RLS, um `EXISTS` poderia **não enxergar** a linha publicada e **deixar o freeze escapar**. Rodando como owner (que faz bypass de RLS por ser dono), o guard enxerga **todas** as linhas → a decisão de freeze é correta e **não-burlável** para qualquer caller, inclusive service_role. O DEFINER aqui **fecha** um bypass, não abre um.

**Ausência de vetor de escalonamento (checagem adversarial):**
- **search_path hijack:** neutralizado por `set search_path=''` + refs `public.*`; built-ins (`=`, `in`, `jsonb_*`) resolvem por `pg_catalog` (sempre implícito) — nenhuma chamada não-qualificada a função de schema de usuário.
- **Invocação direta abusiva:** funções `returns trigger` não são chamáveis fora de contexto de trigger (`select f()` levanta "can only be called as triggers") → sem rota de chamada direta por papel de baixo privilégio.
- **Exfiltração:** nenhuma das DEFINER **retorna dado** ao caller; `reports.status` (enum) só aparece na mensagem de `raise` — não-sensível.
- **Ação privilegiada coagida:** zero `INSERT/UPDATE/DELETE`, zero `EXECUTE`, zero string building dentro das DEFINER → impossível coagi-las a agir sobre objeto escolhido pelo atacante.

**Validadores de evidência (`artist_metrics_detail_complete` L108-158, `report_item_reason_complete` L164-185):** IMMUTABLE, **NÃO DEFINER**, `search_path=''`. **Puros** — leem **só o argumento jsonb**, **zero acesso a tabela**, zero SQL. Usados em CHECK. O caveat clássico de "CHECK que chama função lendo outra tabela" **não se aplica** (não leem tabela) → sem disclosure, sem escalonamento. NULL-safety correta: retornam `false` explícito em cada falha (um validador que retornasse NULL faria o CHECK **passar** — NULL = satisfeito); cada ramo retorna boolean definido. ✅

> O **verify trava esse posture estruturalmente**: §4 asserta `prosecdef=true` nos 3 guards cross-table (L165-176), IMMUTABLE + search_path nos 2 validadores (L148-163) e search_path pinado nas 5 funções de guard (L132-146). Uma regressão que removesse DEFINER ou o pin **falha o verify**. Forte.

---

## 2. Freeze abaixo do service_role (SEC-D03/F01) + paridade de errcode (DEC-0009) → ✅

| Garantia | Mecanismo | Prova no verify (2 role-paths) |
|---|---|---|
| SNAPSHOT congelado pós-publish (`reports`/`report_items`) cobre INSERT/UPDATE/DELETE + move draft→publicado | triggers `*_snapshot_guard` (row, INSERT/UPDATE/DELETE) + `*_no_truncate` (statement) | F5-01/F5-01A (L364-437): grant-holder = `restrict_violation` **estrito** (prova positiva, SEC-F22); service_role = `restrict_violation OR insufficient_privilege` (SEC-F21). Move draft→published bloqueado nos **2** paths. |
| Linhagem publicada inviolável; computed não-publicado recompute-livre | `artist_metrics_published_guard` / `artist_metric_videos_published_guard` (CONDICIONAL — só se alimenta report publicado/archived) | F5-03/F5-03A (L535-613): tamper/DELETE/move-input bloqueados nos 2 paths; recompute de não-publicado OK; o **bypass** (mover input não-publicado→publicado via `coalesce(OLD,NEW)`) **fechado** — valida OLD e NEW separadamente. |
| TRUNCATE catastrófico barrado | `no_truncate` em `reports`/`report_items`/`artist_metric_videos`; `artist_metrics` protegida transitivamente (referenciada por FK → TRUNCATE exige CASCADE que esbarra no `no_truncate` dos filhos) | §4 (7 triggers, bit INSERT) + raciocínio de FK confirmado. |

Triggers disparam **abaixo do service_role** (BYPASSRLS bypassa RLS, **não** trigger) — RLS/grants sozinhos não bastariam, exatamente o motivo de SEC-D03. A lição errcode-parity (DEC-0009) está embutida **antes** do apply, como nas Fases 3/4. ✅

---

## 3. RLS default-deny + zero policy + SEC-F03 → ✅

| Item | Veredito | Evidência |
|---|---|---|
| RLS ENABLE nas 6 | ✅ | L649-654. |
| `revoke all from anon, authenticated` nas 6 (SEC-F13/F02) | ✅ | L659-664. |
| **Zero `create policy`** (Fase 9 sob veto SEC-0001 §0) | ✅ | Nenhuma no arquivo; verify §4 asserta `pg_policies = 0` (L351-355). |
| **Zero `create view`** (VIEW pública de report_items = Fase 9) | ✅ | Nenhuma VIEW criada. A Fase 9 segue **não** destravada. |
| **SEC-F03 — colunas internas sem superfície pública** | ✅ (nesta fase) | `report_items.score_value`/`selection_reason_json` e `artist_metrics.metrics_detail_json` existem como colunas, mas **default-deny + sem grant + sem VIEW + sem policy** ⇒ produtor não lê **nenhuma** coluna. Comentários marcam-nas "admin/server-only (SEC-F03)". **Carry-forward não-bloqueante:** a VIEW da Fase 9 deve expor só o público (`score_display`/`tag`/`signals`/`velocity_display`/`competition_*`/`example_url`/`rank` + reason sanitizado) — **nunca** `score_value`/`raw_score`/json interno. Sob veto da Fase 9. |

---

## 4. Checagens independentes (minhas, além do escopo) — todas OK

- **Atômico:** `begin/commit` (L76/L666).
- **Storage-only / número nunca do DDL:** zero CHECK de faixa/threshold, zero generated column, zero expressão de cálculo. Os 2 CHECKs de evidência são **estruturais** (presença/não-vazio de chaves), nunca validam valor — verify §4 asserta que os **únicos** CHECKs são `reports_published_at_chk` + os 2 de evidência (L323-338). Sem superfície de cálculo/tamper embutida no schema.
- **Alvos de FK existem:** `rubric_versions (version, hash)` UNIQUE (Fase 2 L45); `raw_youtube_videos (run_id, video_id)` / `raw_youtube_channels (run_id, channel_id)` (Fase 4); `artist_metrics` identity keys (L278, L280). FKs compostas válidas.
- **Menor superfície DEFINER:** só 3 funções são DEFINER (as que cruzam tabela); as demais INVOKER. Minimizar DEFINER é a postura correta.
- **Zero secret; zero tabela de marketplace/Fase 2.** Confirmado.
- **service_role:** sem grant novo; revoke só de anon/authenticated — consistente com Fases 1–4. Identidade de servidor confiável inalterada.

---

## 5. Notas não-bloqueantes

- **SEC-F03 (carry-forward Fase 9):** VIEW pública de `report_items` deve excluir colunas internas — sob veto SEC-0001 §0. Esta fase corretamente não expõe nada.
- **Rastreabilidade (endosso de backfill):** a aprovação Data/AI (DATA-RR-F5-03A/05A/06A/01A) vive só no `AgentResult` (patch documental do `data_agent` falhou, sem escrita parcial). **Não bloqueia** minha review — ratifiquei o DDL/verify concretos, não a procuração. Para integridade da trilha de auditoria, **endosso** o backfill `DATA-AI-0007` recomendado pelo Orchestrator.
- **P5-REPRO-01:** prova canônica de 2 rodadas é gate do data-engine/primeiro publish — **fora** deste apply, corretamente registrada no handoff §12.

---

## 6. Quadro de gates do `run_migration` (Fase 5)

| Gate | Estado |
|---|---|
| Data/AI #4/#5 (`validate_reproducibility` re-review — DATA-RR-F5-03A/05A/06A/01A) | ✅ baixado (AgentResult; backfill DATA-AI-0007 recomendado) |
| **Security `review_rls` do SQL + verify (matrix #3)** | ✅ **BAIXADO — este doc (SEC-0014)** |
| Backend — consumo de `artist_metric_id`/snapshot sem auto-expandir escopo | ⏳ próximo (leitura por VIEW só na Fase 9) |
| Pipeline `phase5-db-apply.yml` (DevOps) + Security `audit_secrets` (matrix #8, delta) | ⏳ ainda não autorada/auditada |
| PR revisado + merge na `main` (sem push direto) | ⏳ |
| Gate humano + required reviewers em CI | ⏳ runtime |
| Fase 9 — RLS Policies + VIEW pública de `report_items` (SEC-F03) | ⛔ veto à parte (SEC-0001 §0) — **não destravado aqui** |
| P5-REPRO-01 (prova de 2 rodadas) | ⏳ gate do data-engine/publish — fora deste apply |

**Como meu gate ficou baixado:** o DDL e o verify atendem integralmente SEC-F15 (DEFINER), SEC-D03/F01 (freeze abaixo do service_role, 2 role-paths), SEC-F13/F02 (default-deny + revoke), zero policy/VIEW (Fase 9 intacta) e SEC-F03 (sem exposição de coluna interna). Nenhuma correção exigida. Silêncio de Security ≠ aprovação — este doc é a liberação explícita.
