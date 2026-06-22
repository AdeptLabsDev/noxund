# Handoff — [DB] Fase 1 `run_migration` (Apply) · Database Agent

## 1. Identificação
- **Tarefa:** `task_phase1_run_migration_apply` · **Action:** `run_migration` (sensível/gated)
- **Owner agent:** Database
- **Data:** 2026-06-21
- **Alvo:** projeto Supabase `pwbkplzyzmortwjjpcbg` · região `us-east-1`
- **Gates:** ✅ veto técnico do Security **baixado** (SEC-0004) · ✅ aprovação humana **concedida** (DEC-0006, Product Lead, 2026-06-21, escopada a esta migration)

## 2. Status — NÃO APLICADO deste ambiente (bloqueio nomeado)

**Governança liberada; execução bloqueada por dependência de ambiente.** Os dois gates estão satisfeitos. Porém **este ambiente não tem como aplicar** a migration contra o projeto remoto:

- ❌ **`supabase` CLI não instalado** (`command -v supabase` vazio).
- ❌ **Projeto não linkado** — não há `supabase/config.toml` apontando para `pwbkplzyzmortwjjpcbg`.
- ❌ **Sem credenciais** — não há `.env`; nenhum `SUPABASE_ACCESS_TOKEN` nem senha de banco. Apenas `.env.example` com **nomes** de variável (placeholders).
- 🔒 **Por desenho, secrets não trafegam no payload** (onboarding §8.6) — então não recebo nem devo receber a credencial por aqui.

Aplicar exige um **ambiente credenciado** (DevOps/operador) com o `SUPABASE_ACCESS_TOKEN` + senha do banco. Forjar um "migration aplicada" sem conexão real violaria a honestidade do `AgentResult` (onboarding §5: `completed` sem evidência é proibido). Logo, retorno **`blocked`** com o runbook abaixo, pronto para execução credenciada.

## 3. Runbook de apply (rodar no ambiente credenciado — DevOps/operador)

**Pré-condições:** os dois gates já satisfeitos (SEC-0004 + DEC-0006). Aplicar **somente** a forward migration; **não** rodar o rollback; **não** rodar o bootstrap do 1º admin.

### Opção A — Supabase CLI (recomendada)
```bash
export SUPABASE_ACCESS_TOKEN=...        # do cofre/CI, nunca commitado
supabase link --project-ref pwbkplzyzmortwjjpcbg
supabase db push                        # aplica supabase/migrations/*.sql (só a Fase 1 existe)
```

### Opção B — psql direto (o arquivo já é atômico: begin/commit)
```bash
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 \
  -f supabase/migrations/20260620000001_phase1_core_identity_access.sql
```

**Notas de segurança (do payload + SEC-0002 §5.5):**
- O **rollback companheiro** (`supabase/rollback/20260620000001_...rollback.sql`) **NÃO é aplicado** — é rede de segurança.
- O **bootstrap do 1º admin** **NÃO entra** neste passo: é operação manual service-role separada, sem auto-promoção.
- A migration é atômica: em erro, `ON_ERROR_STOP`/`begin-commit` evitam estado parcial.

## 4. Verificação estrutural pós-apply (rodar e anexar a saída ao apply log)

```sql
-- 4 tabelas
select table_name from information_schema.tables
 where table_schema='public'
   and table_name in ('producers','applications','admin_users','audit_events')
 order by 1;                                   -- esperado: 4 linhas

-- 3 enums
select typname from pg_type
 where typname in ('producer_status','application_status','audit_actor_type')
 order by 1;                                   -- esperado: 3

-- 2 triggers de imutabilidade em audit_events
select tgname from pg_trigger
 where tgrelid='public.audit_events'::regclass and not tgisinternal
 order by 1;                                   -- esperado: audit_events_no_truncate, audit_events_no_update_delete

-- is_admin() blindado (SEC-F15)
select proname, prosecdef, proconfig from pg_proc
 where proname='is_admin' and pronamespace='public'::regnamespace;
                                               -- prosecdef=t; proconfig contém search_path=''

-- índices
select indexname from pg_indexes
 where schemaname='public'
   and tablename in ('producers','applications','audit_events')
 order by 1;                                   -- inclui producers_email_lower_uidx,
                                               -- applications_one_open_per_producer_uidx,
                                               -- audit_events_entity_idx, audit_events_created_idx

-- RLS habilitado nas 4
select relname, relrowsecurity from pg_class
 where relnamespace='public'::regnamespace
   and relname in ('producers','applications','admin_users','audit_events')
 order by 1;                                   -- relrowsecurity=t nas 4
```

## 5. Verificação empírica (recomendada à QA/DevOps após apply)
- **Imutabilidade (SEC-D03/SEC-F16):** como `service_role`, tentar `truncate public.audit_events;` **e** `delete from public.audit_events;` → ambos devem **levantar exceção** (`audit_events is append-only`).
- **Default-deny (SEC-F13/F02):** como `anon` e `authenticated`, `select` nas 4 tabelas → **zero acesso** (sem policy na Fase 1).

## 6. Revisões / próximos passos
- **Database:** migration + rollback autorados e corrigidos (SEC-F16). Apply depende de ambiente credenciado.
- **DevOps:** prover ambiente credenciado e executar o runbook (§3) — re-dispatch do `run_migration` gated a partir de lá.
- **QA/DevOps:** rodar §4 + §5 e anexar evidência como o apply log real.
- **Próximo (pós-apply):** Fase 2 (Versionamento) na ordem do `migration-plan.md`.

## 7. Bloqueio
**Bloqueio nomeado:** falta conexão credenciada ao projeto `pwbkplzyzmortwjjpcbg` (sem CLI, sem link, sem `SUPABASE_ACCESS_TOKEN`/senha de banco neste ambiente). Não é gate de governança (esses caíram); é dependência de execução, de alçada do DevOps.
