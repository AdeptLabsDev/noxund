# SEC-0004 — Security Re-review pós-fix · Fase 1 (Core Identity / Access)

- **Task:** `task_phase1_security_rereview_ddl_postfix` · **Action:** `review_rls` · **Agent:** `security_agent`
- **Data:** 2026-06-21
- **SQL:** `supabase/migrations/20260620000001_phase1_core_identity_access.sql`
- **Rollback:** `supabase/rollback/20260620000001_phase1_core_identity_access.rollback.sql`
- **Anterior:** `SEC-0003` (BLOQUEADO por SEC-F16) · **Gate humano:** `DEC-0006` (concedido)

---

## 0. Veredito

✅ **APROVADO — veto técnico do Security BAIXADO** sobre `supabase/migrations/20260620000001_phase1_core_identity_access.sql`.

SEC-F16 está **fechado** e **nenhuma** das 6 condições do SEC-0002 §5 nem o SEC-F15 sofreram regressão. O **único gate restante** para o `run_migration`/`change_db_schema` é o **gate humano, já concedido em DEC-0006**. O apply da Fase 1 pode prosseguir (gated).

*(O veto da **Fase 9 — RLS Policies** permanece à parte, SEC-0001 §0. Este aval cobre apenas a migration de schema da Fase 1.)*

---

## 1. SEC-F16 — fechado (sim)

| Item | Verificado no SQL |
|---|---|
| Trigger `BEFORE TRUNCATE` statement-level | ✅ L155-157: `create trigger audit_events_no_truncate before truncate on public.audit_events for each statement execute function public.audit_events_immutable();` |
| Mecanismo correto | ✅ `TRUNCATE` não dispara trigger row-level; só statement-level o intercepta. A função levanta exceção incondicional (qualquer `tg_op`) sem referenciar `NEW`/`OLD`, abortando o `TRUNCATE`. |
| Cobertura abaixo do service-role | ✅ Agora UPDATE + DELETE (L148-150) **e** TRUNCATE (L155-157). Triggers disparam inclusive para `service_role` (BYPASSRLS não desativa triggers). Imutabilidade real do log de auditoria. |
| Comentário reconciliado | ✅ L129: "Imutável por trigger (UPDATE + DELETE + TRUNCATE)". Não superestima mais. |
| Rollback atualizado | ✅ L18-20: dropa `audit_events_no_truncate` → `audit_events_no_update_delete` → função, na ordem correta. |

---

## 2. Sem regressão nas 6 condições + SEC-F15

| Condição | Status | Nota |
|---|---|---|
| §5.1 — RLS-on + default-deny + zero grant anon/auth | ✅ inalterado | L191-194 enable; L201-204 revoke; sem policies. |
| §5.2 — `auth_user_id` UNIQUE + ON DELETE SET NULL + sem credencial | ✅ inalterado | L46. |
| §5.3 / SEC-F15 — `is_admin()` definer + `search_path=''` + STABLE + qualificado + least-priv | ✅ inalterado | L164-184. |
| §5.4 — `audit_events` Fase 1 + imutabilidade por trigger + default-deny | ✅ **reforçado** | Bloco 5 agora cobre TRUNCATE (SEC-F16). |
| §5.5 — bootstrap service-role + audit_events, sem auto-promoção | ✅ inalterado | L208-224 (comentado). |
| §5.6 — reversível + atômico + seeds fake | ✅ inalterado | `begin/commit`; rollback completo e em ordem de FK. |

A mudança está isolada ao bloco 5 (1 trigger + comentário) e ao rollback (1 drop). Nada mais no SQL mudou.

---

## 3. Estado dos gates do apply

| Gate | Estado |
|---|---|
| #1 — Veto técnico do Security (SQL concreto) | ✅ **BAIXADO** (este review) |
| #2 — Aprovação humana (`change_db_schema`/`run_migration`) | ✅ **CONCEDIDA** (DEC-0006, escopada a esta migration) |

Ambos satisfeitos → `database_agent:run_migration` (gated) pode aplicar a Fase 1, seguido do rollback companheiro como rede de segurança.

---

## 4. Follow-up (registrado, não bloqueia a Fase 1)

- **Propagar o padrão UPDATE+DELETE+TRUNCATE** às tabelas imutáveis das próximas fases: RAW (`raw_youtube_*`, Fase 4) e `producer_events` (Fase 6). Já anotado em SEC-0003 §2; deve entrar no desenho do DDL dessas fases para não reintroduzir SEC-F16.
- **Fase 9 (RLS Policies)** segue sob veto próprio (SEC-0001 §0): SEC-F01 (authz em código nos caminhos service-role), SEC-F02 (whitelist `/apply`), SEC-F03 (view de leitura do produtor), SEC-F07/F13/F14.
- **Pós-apply:** validar em ambiente real que (a) `update`/`delete`/`truncate` em `audit_events` falham inclusive via service key, e (b) RLS default-deny bloqueia `anon`/`authenticated` nas 4 tabelas. Coordenar com QA/DevOps no provisionamento Supabase.
