# SEC-0002 — Security Review · Migration da Fase 1 (Core Identity / Access)

- **Task:** `task_phase1_security_review` · **Action:** `review_auth` · **Agent:** `security_agent`
- **Data:** 2026-06-20
- **Alvo:** **desenho** da migration da Fase 1 — `producers`, `applications`, `admin_users` (+ `audit_events`, ver §3).
- **Fontes verificadas:** `docs/database/migration-plan.md` (Fase 1), `docs/database/mvp-data-model.md` (producers/applications/admin_users/audit_events), `DEC-0005` (Auth=Supabase, OD-02 fechada), `SEC-0001` (veto base).
- **Estado do código:** `supabase/migrations/` contém só `.gitkeep`. **Nenhum DDL/SQL autorado.** Esta é revisão de **desenho**, não de SQL final.

---

## 0. Veredito

**CONDICIONAL — aprovado no desenho; veto de migration de acesso parcialmente baixado.**

- ✅ **Veto de DESENHO da Fase 1: BAIXADO.** O desenho incorporou SEC-D01/D02/SEC-F13/SEC-F02/SEC-F12 corretamente. Pode autorar o DDL.
- ⛔ **Veto de `run_migration` / `change_db_schema`: MANTIDO** até eu revisar o **DDL concreto** contra as condições de SQL do §5. Não há SQL para autorizar agora — autorizar um apply sobre desenho seria aprovar SQL que não li.
- ⛔ **Veto da Fase 9 (RLS Policies): MANTIDO à parte** (SEC-0001 §0) — independente desta Fase 1.

---

## 1. Veredito por condição

| Condição | Veredito (desenho) | Nota |
|---|---|---|
| **SEC-D01** — `producers.auth_user_id uuid unique null`, provisionado só na aprovação por service-role + `audit_events`; sem coluna de senha/hash | ✅ **PASSA** | `mvp-data-model.md` producers reflete exatamente. DEC-0005 (Supabase Auth) confirma a base. **Condição de DDL:** FK → `auth.users(id)` com **`ON DELETE SET NULL`** (deletar o auth user não pode apagar o produtor nem seu histórico/PII; `CASCADE` proibido). |
| **SEC-D02** — `admin_users` + `is_admin()` `SECURITY DEFINER`; admin nunca de `user_metadata`; grant/revoke auditável | ✅ **PASSA (desenho)** | Modelo correto (`auth_user_id unique`, `granted_by`, `revoked_at`; `is_admin()` checa `auth_user_id = auth.uid() AND revoked_at IS NULL`). **Bloqueante de DDL → ver SEC-F15** (search_path do `SECURITY DEFINER`). |
| **SEC-F13** — `ENABLE ROW LEVEL SECURITY` + default-deny nas tabelas já nesta migration | ✅ **PASSA** | Policies completas ficam na Fase 9 — correto. **Condição de DDL:** `ENABLE ROW LEVEL SECURITY` em **todas** as tabelas da Fase 1 e **nenhuma** policy permissiva p/ `anon`/`authenticated` aqui. Caminhos legítimos da Fase 1 (apply, aprovação, grant) são service-role (bypassa RLS), então default-deny não trava nada necessário. |
| **SEC-F02** — nível de permissão: `anon` com zero grant direto | ✅ **PASSA** | A whitelist de campos do `/apply` é contrato do Backend (fora desta migration) — escopo correto. **Condição de DDL:** a migration **não** emite nenhum `GRANT ... TO anon` nessas tabelas; default-deny + escrita via service-role. |
| **SEC-F12** — ausência de coluna portadora de secret | ✅ **PASSA** | Verificado em `producers`/`applications`/`admin_users`/`audit_events`: nenhuma coluna de senha, hash, token ou api_key. Identidade no Supabase Auth. |

---

## 2. Novo achado desta revisão

**SEC-F15 (Alta) — `is_admin()` `SECURITY DEFINER` sem `search_path` fixo é vetor de escalonamento.**
Uma função `SECURITY DEFINER` sem `search_path` cravado pode ser sequestrada (resolução de nome para objeto malicioso em schema controlado pelo chamador), rodando com privilégios do owner. Como `is_admin()` é a raiz de toda autorização de admin, isto é crítico.
**Mitigação exigida (DDL):** `is_admin()` deve ser `SECURITY DEFINER` **+** `SET search_path = pg_catalog, public` (ou `''` com nomes totalmente qualificados), `STABLE`, e referenciar `admin_users` por nome **qualificado por schema**. `admin_users` permanece default-deny para `anon`/`authenticated` (a função, por ser definer, lê assim mesmo). Bloqueia o `run_migration`.

---

## 3. Decisão de sequenciamento — `audit_events` (pedida no payload)

**Decisão (Security): ANTECIPAR `audit_events` para a Fase 1.** Não adiar para a Fase 8.

Razão (não é preferência — fecha um non-negotiable): SEC-D02 exige que grant/revoke de admin **sempre** escreva `audit_events`, e a aprovação de produtor (`producers.status → approved`) idem. Se a Fase 1 já habilita essas mutações mas `audit_events` só existe na Fase 8, a **primeira** aprovação e o **primeiro** grant de admin ocorreriam **sem trilha de auditoria imutável** — violando SEC-D02 e a rastreabilidade (regra global). Logo, no momento em que `admin_users`/`producers` existem com operação de aprovação/grant, `audit_events` **tem** de existir.

**Escopo do que entra na Fase 1 para `audit_events`:** tabela + `ENABLE RLS` + default-deny + **trigger `BEFORE UPDATE/DELETE` obrigatório (SEC-D03)** + caminho de escrita por service-role. A **policy de leitura admin** pode ficar na Fase 9 (não há leitura de auditoria no fluxo da Fase 1). Resultado: tabelas da Fase 1 = **`producers`, `applications`, `admin_users`, `audit_events`**.

**Nota de bootstrap (condição):** o **primeiro** `admin_users` é bootstrap (não há admin para conceder) — criar por seed/service-role com `audit_events(actor_type='system', action='admin.bootstrap')`. Nunca um caminho de auto-promoção.

---

## 4. Itens fora desta migration (registrados, não bloqueiam a Fase 1)

- **DEC-0005 / item Security em aberto (magic-link vs senha):** confirmo — **sem impacto de schema** na Fase 1 (identidade no Supabase Auth; SEC-0001). A config de sessão/magic-link, expiração e fluxo de convite entram num `review_auth`/`review_endpoint` próprio quando o gate de sessão for desenhado, não aqui.
- **SEC-F02 whitelist de `/apply`, SEC-F01 authz em código:** contrato de **Backend** — serão revisados em `review_endpoint` sobre os handlers, não nesta migration de schema.
- **SEC-F03 (exposição de coluna em `report_items`):** Fase 5, não Fase 1.

---

## 5. Condições de DDL — gate do `run_migration` (re-review obrigatório)

O `run_migration`/`change_db_schema` da Fase 1 só é autorizado depois que eu revisar o **SQL concreto** e confirmar **todos**:

1. `ENABLE ROW LEVEL SECURITY` em `producers`, `applications`, `admin_users`, `audit_events`; **zero** policy permissiva p/ `anon`/`authenticated`; **zero** `GRANT ... TO anon`.
2. `producers.auth_user_id` → `auth.users(id)` **UNIQUE**, **`ON DELETE SET NULL`**; **sem** coluna de credencial.
3. `is_admin()` `SECURITY DEFINER` **+ `SET search_path` fixo** + `STABLE` + referência qualificada a `admin_users` (**SEC-F15**).
4. `audit_events` presente na Fase 1, com **trigger `BEFORE UPDATE/DELETE`** que levanta exceção (**SEC-D03**); default-deny.
5. Caminho de bootstrap do 1º admin por service-role + `audit_events`, sem auto-promoção.
6. Migration **reversível** (rollback declarado) e **idempotente** no que for seguro; seeds só fake (`supabase/README.md`).

---

## 6. Handoff (review-matrix #3 — Migration de banco → Database + Security)

- **Resultado:** desenho da Fase 1 **aprovado condicionalmente** por Security. Veto de desenho **baixado**; veto de `run_migration`/`change_db_schema` **mantido** até re-review do DDL (§5). Fase 9 RLS sob veto à parte.
- **Decisão de Security registrada:** `audit_events` **antecipada à Fase 1** (§3).
- **Novo risco:** SEC-F15 (search_path do `is_admin()`) — Alta, condição de DDL.
- **Próximo passo:** Database autora o **DDL concreto** da Fase 1 (`plan_migration`) incorporando §5 → Security faz re-review do SQL (`review_rls`/`review_auth` sobre o DDL) → só então o `change_db_schema`/`run_migration` gated, com aprovação humana.
- **Como o veto de apply cai:** re-review do SQL satisfazendo §5. Silêncio de Security ≠ aprovação (`agent-conflict-resolution.md`).
