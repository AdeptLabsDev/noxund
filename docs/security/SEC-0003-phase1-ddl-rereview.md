# SEC-0003 — Security Re-review do DDL · Fase 1 (Core Identity / Access)

- **Task:** `task_phase1_security_rereview_ddl` · **Action:** `review_rls` · **Agent:** `security_agent`
- **Data:** 2026-06-21
- **SQL revisado:** `supabase/migrations/20260620000001_phase1_core_identity_access.sql`
- **Rollback:** `supabase/rollback/20260620000001_phase1_core_identity_access.rollback.sql`
- **Baseline:** `SEC-0002` §5 + SEC-F15 · **Gate humano:** `DEC-0006` (concedido, condicionado a este review)

---

## 0. Veredito

⛔ **BLOQUEADO — veto de `run_migration`/`change_db_schema` MANTIDO.**

Uma falha bloqueante (**SEC-F16**). As **6 condições do §5 e SEC-F15 passam**; o defeito está na **garantia de imutabilidade do `audit_events`**, que não cobre `TRUNCATE` — exatamente o vetor que SEC-D03/SEC-F01 existem para fechar. Não baixo o veto sobre este SQL. Como o gate humano (DEC-0006) já está concedido, **meu veto técnico é o único gate restante** — portanto o apply **não** prossegue até a correção + re-review.

---

## 1. Veredito por condição (lendo o SQL concreto)

| Condição | Veredito | Evidência no SQL |
|---|---|---|
| **§5.1** — `ENABLE RLS` nas 4 tabelas + default-deny + zero GRANT/policy a `anon`/`authenticated` | ✅ **PASSA** | `enable row level security` nas 4 (L183-186); `revoke all ... from anon, authenticated` nas 4 (L193-196); **nenhuma** `create policy` (= default-deny); nenhum `grant` permissivo. Revoke explícito defende contra os default privileges do Supabase. |
| **§5.2** — `producers.auth_user_id` → `auth.users(id)` UNIQUE, `ON DELETE SET NULL`, sem coluna de credencial | ✅ **PASSA** | L46: `auth_user_id uuid unique references auth.users (id) on delete set null`. Nenhuma coluna de senha/hash/token. |
| **§5.3 / SEC-F15** — `is_admin()` `SECURITY DEFINER` + `search_path` fixo + `STABLE` + ref. qualificada | ✅ **PASSA** | L156-169: `security definer`, `set search_path = ''`, `stable`, `from public.admin_users`, `auth.uid()` qualificado. L175-176: `revoke all ... from public` + `grant execute ... to authenticated, service_role` (least privilege; anon não executa). **SEC-F15 fechado.** |
| **§5.4** — `audit_events` na Fase 1 com trigger `BEFORE UPDATE/DELETE` (SEC-D03) + default-deny | ⛔ **FALHA PARCIAL → SEC-F16** | Tabela na Fase 1 ✅ (L112), trigger `BEFORE UPDATE OR DELETE FOR EACH ROW` ✅ (L147-149), função `set search_path=''` ✅, default-deny ✅. **MAS** o trigger row-level **não dispara em `TRUNCATE`**, e `service_role` mantém `TRUNCATE` (revoke só atinge anon/authenticated). Imutabilidade **não** garantida abaixo do service-role — contradiz SEC-D03 e o comentário "Imutável por trigger" (L129). |
| **§5.5** — bootstrap do 1º admin por service-role + `audit_events`, sem auto-promoção | ✅ **PASSA** | L200-216: template **comentado** (não executado), `actor_type='system'`, `action='admin.bootstrap'`, `granted_by null`. Sem caminho de auto-promoção no schema. |
| **§5.6** — reversibilidade + idempotência segura; seeds só fake | ✅ **PASSA** | Migration atômica (`begin/commit`); enums guardados por `if not exists` (L25-36); `create table` sem `IF NOT EXISTS` é aceitável e falha alto (a atomicidade evita estado parcial). Rollback completo e na ordem de FK correta (filhos→pais→tipos), em `supabase/rollback/` (fora de `migrations/`, justificado). PKs `uuid` (sem footgun de grant de sequence). |

---

## 2. Achado bloqueante

### SEC-F16 (Alta) — `audit_events` vulnerável a `TRUNCATE`
Um trigger `BEFORE UPDATE OR DELETE ... FOR EACH ROW` **não** intercepta `TRUNCATE` (evento separado no Postgres). `service_role` faz bypass de RLS **e** mantém privilégio de `TRUNCATE` sobre tabelas `public` (os grants padrão do Supabase dão `ALL` a `service_role`; a migration só revoga de `anon`/`authenticated`). Logo, um caminho de servidor com bug/comprometido — ou um script administrativo com a service key — pode `TRUNCATE public.audit_events` e **apagar todo o log de auditoria silenciosamente**, derrotando o propósito de SEC-D03 (imutabilidade abaixo do service-role) e o non-negotiable de rastreabilidade. O comentário do SQL (L129) afirma "Imutável por trigger", o que **superestima** a garantia atual.

**Mitigação exigida (bloqueante):** adicionar um trigger statement-level reaproveitando a função existente (que já levanta exceção para qualquer `tg_op` e não referencia `NEW`/`OLD`):

```sql
create trigger audit_events_no_truncate
  before truncate on public.audit_events
  for each statement execute function public.audit_events_immutable();
```

E o **rollback** deve passar a dropar este trigger (`drop trigger if exists audit_events_no_truncate on public.audit_events;`).

> Princípio para fases futuras: toda tabela verdadeiramente append-only/imutável (RAW na Fase 4, `producer_events` na Fase 6) precisa do guard de **UPDATE + DELETE + TRUNCATE**, não só UPDATE/DELETE.

---

## 3. Notas não-bloqueantes (não travam; registrar)

- **`admin_users.auth_user_id ON DELETE CASCADE` (L98):** aceitável — deletar o auth user remove a linha de admin; o histórico do grant/bootstrap sobrevive em `audit_events` (sem FK). Alternativa defensável seria `RESTRICT` (impedir deletar auth user de admin ativo). Decisão do Database; não bloqueia.
- **`applications.producer_id ON DELETE CASCADE` (L73):** desejável para erasure de PII (LGPD/SEC-F09) — apagar o produtor apaga as respostas; a decisão permanece em `audit_events`. OK.

---

## 4. Como o veto cai

Adicionar o trigger `BEFORE TRUNCATE` (e o drop no rollback) → novo `review_rls` sobre o SQL corrigido. Sendo essa a única pendência, o re-review baixa o veto. Aí, com **DEC-0006** (gate humano já concedido) + veto baixado, o `database_agent:run_migration` (gated) aplica a Fase 1. Silêncio de Security ≠ aprovação (`agent-conflict-resolution.md`).
