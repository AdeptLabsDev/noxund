# SEC-0010 — Security Re-review (review_rls) · Verify corrigido da Fase 3

- **Task:** `task_phase3_security_rereview_verify` · **Action:** `review_rls` · **Agent:** `security_agent`
- **Data:** 2026-06-25
- **Verify:** `supabase/tests/phase3_post_apply_verify.sql` (corrigido)
- **Anterior:** `SEC-0009` ⛔ (DDL aprovado; verify bloqueado por SEC-F21 + SEC-F22)
- **Contexto:** DDL já aprovado (SEC-0009 §1 — não re-revisado); Data/AI #5 baixado (DATA-AI-0003). Verify era a única pendência do meu gate.

---

## 0. Veredito

✅ **SEM BLOQUEIO — veto de `review_rls` da Fase 3 BAIXADO.** SEC-F21 e SEC-F22 resolvidos; default-deny (§5) e estrutural (§4) intactos; nada além do verify mudou. Meu gate (matrix #3) sobre a Fase 3 está integralmente baixado.

*(Veto da **Fase 9 — RLS Policies** segue à parte, SEC-0001 §0.)*

---

## 1. SEC-F21 — RESOLVIDO (paridade de errcode nos 3 blocos de imutabilidade)

| Bloco §5 (service_role) | Errcode aceito | Status |
|---|---|---|
| TRUNCATE `report_runs` (L131-136) | `when restrict_violation or insufficient_privilege` (L135) | ✅ |
| identity UPDATE `keyword` (L164-169) | `... or insufficient_privilege` (L168) | ✅ |
| DELETE `report_runs` (L171-176) | `... or insufficient_privilege` (L175) | ✅ |

Bloqueio por *trigger* **ou** por *grant* ambos contam como imutabilidade comprovada (lição DEC-0009). Não reincide o falso-negativo da Fase 2. A existência do trigger continua provada à parte pela checagem estrutural §4 — alargar o errcode **não** afrouxa a garantia.

## 2. SEC-F22 — RESOLVIDO (freeze por-coluna provado no caminho grant-holder)

O teste agora prova as **duas** metades do freeze por-coluna de forma inequívoca:

- **STATUS permitido:** `update ... set status='collecting'` como `postgres` **passa** (L151) — o trigger permite STATE.
- **IDENTIDADE bloqueada pelo TRIGGER:** `update ... set keyword='tamper'` como `postgres` (grant-holder) espera **`restrict_violation` específico** (L155-160). Como `postgres` detém o grant, o único mecanismo que pode barrar é o **trigger** → prova que o freeze é *enforced*, não um grant ausente. (Triggers disparam inclusive para o owner; só RLS é bypassada por BYPASSRLS — a asserção é válida.)
- **Caminho bypass re-testado:** mesma `keyword` como `service_role` com OR-errcode (L162-169).

Distinção que faltava — "identidade congelada / status permitido" vs "service_role não escreve" — agora está coberta. Probe benigno preservado.

## 3. Não-afrouxamento (escopo confirmado)

- **§4 estrutural (L21-122):** intacto — 3 tabelas, 2 enums, 2 triggers de proveniência, `search_path` pinado nas 2 funções, índices de dedupe + FK, RLS-on. Continua provando a existência do trigger.
- **Default-deny §5 (L180-197):** intacto — `anon`/`authenticated` SELECT nas 3 tabelas → `insufficient_privilege` **específico** (42501). Correto manter estrito (SELECT sem grant é sempre 42501; trigger não entra). **Não** alargado.
- **Isolamento da mudança:** alteração restrita aos 3 blocos de imutabilidade §5 + o probe grant-holder do SEC-F22. Nada mais. `ON_ERROR_STOP=1`, probes em transações revertidas (efeito colateral nulo).

## 4. Nota não-bloqueante (opcional — não exigida)

A ramificação **DELETE** do `report_runs_row_guard` é provada por trigger só no caminho `service_role` (OR-errcode); um probe de `delete` como `postgres` (grant-holder) esperando `restrict_violation` específico daria à DELETE a mesma prova trigger-only que o `keyword` agora tem. **Marginal** — §4 prova a existência do trigger e a função é a mesma do branch de UPDATE já provado. **Não bloqueia, não exijo**; registro por completude.

## 5. Quadro de gates do `run_migration` (Fase 3)

| Gate | Estado |
|---|---|
| Security `review_rls` (DDL + verify, matrix #3) | ✅ **BAIXADO** — SEC-0009 (DDL) + este doc (verify) |
| Data/AI #5 (identidade/dedupe + placement de `rubric_*`) | ✅ baixado (DATA-AI-0003) |
| Pipeline `phase3-db-apply.yml` + `audit_secrets` (matrix #8) | ⏳ ainda não autorada/auditada por mim |
| PR revisado + merge na `main` (sem push direto, #12) | ⏳ |
| Gate humano + required reviewers em CI | ⏳ runtime |
| Fase 9 — RLS Policies | ⛔ veto à parte (SEC-0001 §0) |

**Próximo:** DevOps autora `phase3-db-apply.yml` (espelhando a Fase 2 endurecida) → Security `audit_secrets` (matrix #8, delta) → PR + merge → `run_migration` gated (humano + required reviewers, origem `main`). Silêncio de Security ≠ aprovação.
