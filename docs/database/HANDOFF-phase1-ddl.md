# Handoff — [DB] Fase 1 DDL (Core Identity / Access) · Database Agent

## 1. Identificação
- **Tarefa:** `task_phase1_ddl_authoring` (rev. 1) · `task_phase1_db_fix_secf16_truncate_guard` (rev. 2) · **Action:** `plan_migration`
- **Owner agent:** Database
- **Data:** 2026-06-20 (rev. 1) · 2026-06-21 (rev. 2 — fix SEC-F16)
- **Prioridade:** high
- **Vereditos de referência:** `docs/security/SEC-0002-phase1-access-migration-review.md` (§5 condições de DDL, SEC-F15, §3 audit_events) · `docs/security/SEC-0003-phase1-ddl-rereview.md` (§2 SEC-F16) · `SEC-0001` · `DEC-0003` · `DEC-0005` (Auth=Supabase) · `DEC-0006` (gate humano concedido)

> ## Rev. 2 (2026-06-21) — Correção SEC-F16: guard de TRUNCATE em `audit_events`
>
> **Defeito (SEC-0003 §2, veto bloqueante):** o trigger `BEFORE UPDATE OR DELETE ... FOR EACH ROW` **não** intercepta `TRUNCATE` (evento separado no Postgres), e `service_role` mantém o privilégio de `TRUNCATE` (o `revoke` só atinge `anon`/`authenticated`). Logo, um caminho de servidor comprometido/bugado com a service key poderia apagar **todo** o log de auditoria — viola SEC-D03 e a rastreabilidade.
>
> **Diff de schema (forward migration):**
> - `+ create trigger audit_events_no_truncate before truncate on public.audit_events for each statement execute function public.audit_events_immutable();` — statement-level, reutiliza a função existente (levanta exceção para qualquer `tg_op`; não referencia `NEW`/`OLD`).
> - Comentário da tabela (`comment on table public.audit_events`) reconciliado: imutabilidade agora declara **UPDATE + DELETE + TRUNCATE**.
> - Header do bloco 5 atualizado (dois triggers; menção a SEC-F16).
>
> **Diff de rollback:** `+ drop trigger if exists audit_events_no_truncate on public.audit_events;` **antes** do `drop function ... audit_events_immutable()` (ambos os triggers caem antes da função que ambos reutilizam).
>
> **Escopo:** apenas o guard de TRUNCATE + comentário + drop. **Nenhuma** das 6 condições do SEC-0002 §5 + SEC-F15 foi tocada (sem regressão); sem novas tabelas/colunas/constraints; zero Fase 2.
>
> **Princípio para fases futuras (SEC-0003 §2):** RAW (Fase 4) e `producer_events` (Fase 6) precisam do guard **UPDATE + DELETE + TRUNCATE**, não só UPDATE/DELETE. Registrado para incorporar quando esses DDLs forem autorados.

## 2. Objetivo
Autorar o **DDL concreto** da Fase 1 (Core Identity / Access) em `supabase/migrations/`, com rollback reversível, incorporando as 6 condições de SQL do SEC-0002 §5 + SEC-F15 + `audit_events` antecipada. **Authoring é não-sensível; NÃO aplicar** — `change_db_schema`/`run_migration` seguem gated.

## 3. Critério de aceite (do TaskCommand)
DDL da Fase 1 (`producers`, `applications`, `admin_users`, `audit_events`) com rollback; `auth_user_id` FK `ON DELETE SET NULL` sem coluna de credencial; `is_admin()` `SECURITY DEFINER` com `search_path` fixo; `ENABLE RLS` + default-deny + zero grant a `anon`; trigger `BEFORE UPDATE/DELETE` em `audit_events`; bootstrap do 1º admin auditado; `migration-plan.md` atualizado; handoff pedindo re-review do Security; nenhuma migration aplicada.

## 4. Resultado
- [x] Critério atendido — DDL autorado, **não aplicado**.
- [x] Demonstrável: `supabase/migrations/20260620000001_phase1_core_identity_access.sql` + rollback companheiro.

Mapa critério → SQL:
| Condição (SEC-0002 §5 / SEC-F15) | Onde no SQL |
|---|---|
| §5.1 `ENABLE RLS` + default-deny + zero grant `anon` | blocos 7–8 (`enable row level security` nas 4 tabelas; `revoke all ... from anon, authenticated`) |
| §5.2 `auth_user_id` → `auth.users(id)` UNIQUE, `ON DELETE SET NULL`; sem credencial | bloco 1 (`producers`) |
| §5.3 / SEC-F15 `is_admin()` `SECURITY DEFINER` + `search_path` fixo + `STABLE` + ref. qualificada | bloco 6 (`set search_path = ''`, `public.admin_users`, `revoke ... from public`) |
| §5.4 `audit_events` na Fase 1 + trigger `BEFORE UPDATE/DELETE` + default-deny | blocos 4–5 |
| §5.5 bootstrap 1º admin por service-role + `audit_events`, sem auto-promoção | template comentado ao final (não executado) |
| §5.6 reversível + idempotente seguro; seeds só fake | enums guardados; arquivo de rollback; nota de seed |

## 5. Arquivos alterados
- `supabase/migrations/20260620000001_phase1_core_identity_access.sql` — **criado**: DDL up da Fase 1 (4 tabelas, enums, `is_admin()`, trigger, RLS, revokes, bootstrap comentado).
- `supabase/rollback/20260620000001_phase1_core_identity_access.rollback.sql` — **criado**: rollback reversível (fora de `migrations/` para o CLI não aplicá-lo como forward).
- `docs/database/migration-plan.md` — **modificado**: Fase 1 inclui `audit_events`/SEC-F15/bootstrap + ponteiros de arquivo; Fase 8 marcada como movida.
- `supabase/README.md` — **modificado**: convenção de rollback e arquivos da Fase 1.

## 6. Impacto no escopo
- **MVP travado?** Sim. 4 tabelas de identidade/acesso/auditoria; nenhuma de marketplace/Fase 2.
- **Toca número/banco/auth?** Banco + auth/RLS (matriz #2/#3) → re-review **Database + Security** obrigatório no SQL.
- **Não-negociáveis:** raw imutável (n/a nesta fase), auditoria imutável (trigger), secrets fora do banco (SEC-F12). Nenhum violado.

## 7. Validação executada
- Estrutural: revisão linha a linha contra SEC-0002 §5 (tabela do item 4). Ordem de FK no rollback conferida (filhos→pais, objetos→tipos).
- **Não executado:** nenhum apply. Não há Postgres/Supabase conectado; `change_db_schema`/`run_migration` permanecem gated (aprovação humana) e o Security re-revisa este SQL antes.

## 8. Riscos
- **SEC-F15** mitigado no SQL (`search_path = ''` + nomes qualificados). Se o re-review pedir `pg_catalog, public` em vez de `''`, é troca de uma linha.
- **Imutabilidade vs service-role:** o trigger barra UPDATE/DELETE inclusive via service-role; um superuser ainda pode `session_replication_role=replica` — fora do escopo do schema, registrar como hardening de operação (DevOps/Security).
- **Bootstrap:** depende de um `auth.users.id` real em deploy; mantido como template manual para não embutir dado real (seeds só fake).

## 9. Revisões necessárias
- [~] **Security** — re-review 1 feito (`SEC-0003`): 6 condições §5 + SEC-F15 ✅; **veto MANTIDO** só por **SEC-F16** (TRUNCATE). **Rev. 2 corrige SEC-F16** → precisa de **novo `review_rls` sobre o SQL corrigido**; sendo a única pendência, o re-review deve **baixar o veto**.
- [x] **Database** — autoria + fix SEC-F16 concluídos (este handoff).
- [ ] **Backend** — whitelist `/apply` (SEC-F02) e authz em código (SEC-F01) nos handlers — fora desta migration, mas pré-requisito do fluxo.

**Gate restante para o apply:** veto técnico do Security (SEC-F16) é o único bloqueio entre o estado atual e o `run_migration`. Baixado o veto no re-review, com **DEC-0006** (gate humano já concedido) + aprovação do `run_migration` gated, a Fase 1 aplica.

## 10. Próximos passos
1. **Security re-revisa o SQL** (SEC-0002 §5). Silêncio ≠ aprovação.
2. Com o veto baixado **e** aprovação humana, `change_db_schema`/`run_migration` (gated) aplicam a Fase 1.
3. Segue Fase 2 (Versionamento) na ordem do `migration-plan.md`.

## 11. Open decisions / bloqueios
- **Bloqueio ativo:** veto de apply do Security (SEC-0002 §0/§5) até re-review do DDL.
- **Sem auto-promoção de admin:** bootstrap só por service-role + `audit_events` (SEC-0002 §5.5).
