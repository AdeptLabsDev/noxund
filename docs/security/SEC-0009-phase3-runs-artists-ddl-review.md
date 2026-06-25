# SEC-0009 — Security Review (review_rls) · Fase 3 — Runs + Artists (DDL)

- **Task:** `task_phase3_security_review_rls` · **Action:** `review_rls` · **Agent:** `security_agent`
- **Data:** 2026-06-25
- **SQL:** `supabase/migrations/20260620000003_phase3_runs_artists.sql`
- **Rollback:** `supabase/rollback/20260620000003_phase3_runs_artists.rollback.sql`
- **Verify:** `supabase/tests/phase3_post_apply_verify.sql`
- **Handoff:** `docs/database/HANDOFF-phase3-runs-artists.md`
- **Mandato:** SEC-0002 §5 + matrix #3 (Database+Security em toda migration). Gate de veto.

---

## 0. Veredito

⛔ **BLOQUEADO — veto mantido.** **A migration (DDL) está correta**; o bloqueio é **um defeito no verify**: as asserções de imutabilidade §5 aceitam **só `restrict_violation`**, reintroduzindo **exatamente o falso-negativo da Fase 2** que o DEC-0009 corrigiu. Como neste projeto o `service_role` **não tem grant de DML** (fato empírico do run da Fase 2), o bloqueio chega como `insufficient_privilege` (grant layer) **antes** do trigger — e o verify, como está, ficaria **vermelho pós-apply**, repetindo o ciclo de hotfix da Fase 2 (PR #3). O escopo desta tarefa pediu para pegar isso **antes** do apply. Fix abaixo (SEC-F21). 1 melhoria dobrada (SEC-F22).

*(Veto da **Fase 9 — RLS Policies** segue à parte, SEC-0001 §0.)*

---

## 0.1 Reconciliação honesta com DEC-0009 (correção do meu SEC-0008)

DEC-0009 corrigiu o registro do meu **SEC-0008**: lá classifiquei a estritez do verify da Fase 2 (aceitar só `restrict_violation`) como *"mais estrito / hardening"*. **Estava errado.** O run real provou que era uma **regressão de paridade**: o `service_role` foi barrado no *grant layer* (`insufficient_privilege`), nunca chegou ao trigger, e o verify falhou. Aplico a lição aqui: **bloqueio por grant OU por trigger ambos comprovam imutabilidade**; o verify deve aceitar os dois, e a existência do trigger é provada **separadamente** pela checagem estrutural §4. Não repito o erro — agora ele vira um achado bloqueante.

---

## 1. Migration (DDL) — PASSA

| Item do escopo | Veredito | Evidência |
|---|---|---|
| **RLS enable + default-deny + revoke anon/authenticated nas 3 tabelas** | ✅ **PASSA** | `enable row level security` em `report_runs`/`artists`/`artist_aliases` (L153-155); `revoke all ... from anon, authenticated` nas 3 (L160-162); nenhuma `create policy` (default-deny). |
| **Triggers de proveniência de `report_runs` (congelam keyword/vertical/janela; bloqueiam DELETE/TRUNCATE abaixo do service_role)** | ✅ **PASSA** | `report_runs_row_guard()` (L108-128): DELETE → `restrict_violation`; UPDATE → bloqueia se `keyword/vertical/window_start/window_end` mudarem, senão `return new` (permite STATE: status/contadores). `report_runs_no_truncate()` (L134-143): TRUNCATE → `restrict_violation`. Triggers row + statement (L130-147). Lógica correta: DELETE tratado antes de tocar `new` (em DELETE `new` é null). |
| **`search_path=''` nas 2 funções de trigger** | ✅ **PASSA** | L111 e L137. Funções só usam built-ins (`tg_op`/`new`/`old`) — search_path vazio não quebra nada. (Não são SECURITY DEFINER — trigger functions; o pin é higiene correta.) |
| **Zero secret; nenhuma tabela de marketplace** | ✅ **PASSA** | Sem credencial no SQL/handoff. `report_runs`/`artists`/`artist_aliases` são do `04_ §4/§5`; nenhuma proibida (`04_ §12`). |

**Checagens independentes (OK):** atômico (`begin/commit`); enums guardados por `if not exists` (L33-41); dedupe por `unique lower(canonical_name)` e `unique lower(alias)` (L79, L96); FK `artist_aliases→artists ON DELETE CASCADE` (L89, apaga aliases junto com o artista — aceitável); `check (window_end >= window_start)` (L63). **Rollback** correto e atômico: triggers → funções → tabelas (`artist_aliases`→`artists`→`report_runs`) → enums (`DROP TABLE` é DDL, não dispara os triggers). 

**`rubric_version/rubric_hash` nullable e não-congelados em `report_runs`:** sem objeção de segurança — é decisão de fluxo de re-publish do **Data/AI #5** (DATA-AI-0001 keya o rubric por-scoring em `artist_metrics`).

---

## 2. Achado bloqueante

### SEC-F21 (Médio-Alto · bloqueante) — verify §5 só aceita `restrict_violation` (regressão de paridade DEC-0009)
Os 3 blocos de imutabilidade do `phase3_post_apply_verify.sql` capturam **apenas** `restrict_violation`:
- TRUNCATE `report_runs` como `service_role` — `when restrict_violation then null` (L135);
- UPDATE `keyword` como `service_role` — idem (L157);
- DELETE `report_runs` como `service_role` — idem (L164).

Neste projeto o `service_role` **não detém grant de DML** sobre as tabelas criadas por estas migrations (provado no run da Fase 2 — DEC-0009: `permission denied for table rubric_versions`). Logo a mutação é barrada no *grant layer* (`insufficient_privilege`/42501) **antes** do trigger; o `except` não captura → o `do $$` levanta → `ON_ERROR_STOP=1` falha o job `verify`. **Falso-negativo de teste, schema correto** — mas trava o run e força hotfix pós-apply (exatamente a Fase 2).

**Mitigação exigida (antes do apply):** aceitar **`restrict_violation OR insufficient_privilege`** nos 3 blocos — paridade com `phase1_post_apply_verify.sql` e o `phase2_post_apply_verify.sql` pós-hotfix. A existência do trigger continua provada pela checagem estrutural §4 (não se perde garantia ao alargar o errcode). O bloco de default-deny (L181, `insufficient_privilege`) está correto e não muda.

## 3. Melhoria a dobrar no mesmo fix

### SEC-F22 (Médio · dobrar no fix do SEC-F21) — provar o *freeze por-coluna*, não só "service_role não escreve"
A garantia central de `report_runs` é **status mutável, identidade de coleta congelada**. O probe de identidade roda como `service_role` (L154) que — sem grant — é barrado no grant layer, **não pelo trigger**: o teste então prova "service_role não escreve", não "keyword congelada / status permitido". O lado "status passa" já é provado como `postgres` (L149). Para provar o **bloqueio da coluna de identidade pelo trigger**, adicionar um probe de `update ... set keyword=...` **como `postgres`** (que detém grant) esperando **`restrict_violation`**. Sem isso, uma regressão na lógica de coluna do `row_guard` poderia passar despercebida. (Não é defeito de schema; é fidelidade do teste — barato, e o arquivo já será tocado pelo SEC-F21.)

---

## 4. Quadro de gates do `run_migration` (Fase 3)

| Gate | Estado |
|---|---|
| Security `review_rls` do SQL (matrix #3) | ⛔ **BLOQUEADO** — DDL ok; **verify** precisa do fix SEC-F21 (e SEC-F22 dobrado) — este doc |
| Data/AI #5 (identidade/dedupe + placement de `rubric_*`) | ⏳ pendente (não é meu gate) |
| Pipeline de apply da Fase 3 (`phase3-db-apply.yml`) + `audit_secrets` (matrix #8) | ⏳ ainda não vista por mim |
| PR revisado + merge na `main` (sem push direto, #12) | ⏳ |
| Gate humano + required reviewers em CI | ⏳ runtime |
| Fase 9 — RLS Policies | ⛔ veto à parte (SEC-0001 §0) |

**Como o veto cai:** corrigir o verify (SEC-F21 + SEC-F22) → novo `review_rls` sobre o SQL+verify corrigidos. Sendo o DDL já aprovado, é a única pendência do meu gate. Silêncio de Security ≠ aprovação (`agent-conflict-resolution.md`).
