# INFRA-0001 — Ambiente credenciado para o apply da Fase 1 (CI)

- **Task:** `task_phase1_devops_configure_credentialed_env` · **Action:** `configure_env` (sensível/gated)
- **Owner agent:** `devops_agent`
- **Data:** 2026-06-21
- **Alvo:** projeto Supabase `pwbkplzyzmortwjjpcbg` · região `us-east-1`
- **Desbloqueia:** `MISSING_CREDENTIALED_CONNECTION` (HANDOFF-phase1-apply.md §2/§7)

---

## 0. O que este documento é (e o que NÃO é)

Este é o **contrato do ambiente credenciado** que permite aplicar a migration da Fase 1
**via CI, não no laptop**. Ele especifica:

1. os **artefatos versionados** (config + pipeline + verificação) — todos **sem secret**;
2. as **referências de secret** (apenas **nomes**) a popular no cofre/CI;
3. o **gate de execução** (GitHub Environment + revisores DevOps+Security).

**NÃO** contém valores de secret. **NÃO** aplica nada. O apply é o passo seguinte
(`database_agent:run_migration`), disparado a partir deste ambiente. Hard-constraint do
payload: *"Nenhum apply neste passo — configure_env só prepara o ambiente."*

> **Non-negotiable (global rule #10 / onboarding §8.6):** secrets nunca entram em payload,
> arquivo versionado, log ou no contexto do Orchestrator. Os **valores** são fornecidos pelo
> **Product Lead out-of-band**, direto no cofre/CI.

---

## 1. Artefatos versionados (sem secret)

| Artefato | Caminho | Papel |
|---|---|---|
| Config do projeto | `supabase/config.toml` | Linka o repo ao `project_ref` `pwbkplzyzmortwjjpcbg`. Zero secret. |
| Pipeline de apply | `.github/workflows/phase1-db-apply.yml` | Encapsula o runbook §3 (Opção A) + verificação §4/§5. **Manual-only + gated.** |
| Job de verificação | `supabase/tests/phase1_post_apply_verify.sql` | Asserções §4 (estrutural) + §5 (imutabilidade/default-deny). Falha alto. |

Nenhum desses arquivos contém credencial. O `config.toml` carrega só o `project_ref`
(que não é secret — aparece na URL do projeto). A pipeline referencia secrets **por nome**
via `secrets.*` / `vars.*` do GitHub Environment.

---

## 2. Referências de secret a popular (NOMES, não valores)

Tudo abaixo vive **exclusivamente** no **GitHub Environment `production-db`**
(Settings → Environments). Populado **out-of-band pelo Product Lead**. Zero valor neste repo.

### 2.1 Secrets (Environment **secrets**)

| Nome | Uso | Least-privilege / origem |
|---|---|---|
| `SUPABASE_ACCESS_TOKEN` | `supabase link` (CLI auth) | Personal/CI access token do Supabase. Escopar ao mínimo necessário; rotacionável. Dashboard → Account → Access Tokens. |
| `SUPABASE_DB_PASSWORD` | `supabase db push` + string de conexão do `psql` na verificação | Senha do banco do projeto. Único secret embutido na connection URL (mascarada em runtime). Dashboard → Project → Database → Password. |
| `SUPABASE_SERVICE_ROLE_KEY` | **Somente** o teste negativo §5 (API): provar que a service key **não** consegue update/delete/truncate em `audit_events` | JWT service-role. Dashboard → Project → API. Ver §4.2 sobre por que a prova **autoritativa** é a de banco, não a de API. |

### 2.2 Coordenadas de conexão (Environment **variables** — NÃO são secret)

Separar as coordenadas não-secretas reduz o secret a **um só** valor (a senha). Copiar do
dashboard → Project → Database → **Connection string → Session pooler**.

| Nome (`vars.*`) | Exemplo | Nota |
|---|---|---|
| `SUPABASE_DB_HOST` | `aws-0-us-east-1.pooler.supabase.com` | **Session pooler** (IPv4) — os runners do GitHub são IPv4; o host direto `db.<ref>.supabase.co` costuma ser IPv6-only e falha. |
| `SUPABASE_DB_PORT` | `5432` | Session mode (`set role` exige sessão; **não** usar o transaction pooler 6543). |
| `SUPABASE_DB_USER` | `postgres.pwbkplzyzmortwjjpcbg` | Usuário do pooler. Default no pipeline: `postgres.<ref>`. |

> `SUPABASE_PROJECT_REF` (`pwbkplzyzmortwjjpcbg`) é **não-secret** e está fixado no
> `config.toml` e no `env:` do workflow.

---

## 3. Gate de execução (humano, em CI)

O apply real é gated em **duas camadas**, ambas exigindo ação humana:

1. **Dispatch manual + frase de confirmação.** O workflow só roda via `workflow_dispatch`
   e exige digitar `APPLY-PHASE1`. Nunca roda em push/cron.
2. **Required reviewers do Environment `production-db`.** Configurar os revisores =
   **DevOps + Security** (agent-review-matrix.md #8). A execução do job `apply` fica
   suspensa até a aprovação dos revisores — é a aprovação humana **em tempo de execução**,
   complementar ao gate de governança do Orchestrator (`requires_human_approval`) e ao
   `DEC-0006` (gate humano da migration).

Setup no GitHub (Product Lead/DevOps, fora do repo):
`Settings → Environments → New environment → production-db` → **Required reviewers**
(DevOps + Security) → adicionar os **secrets** (2.1) e as **variables** (2.2).

---

## 4. Verificação pós-apply

### 4.1 Estrutural (§4) + imutabilidade/default-deny (§5) — autoritativa, em banco

`supabase/tests/phase1_post_apply_verify.sql`, executado pelo job `verify` com
`psql -v ON_ERROR_STOP=1`. Cada checagem **levanta exceção** em divergência → job vermelho.
Cobre: 4 tabelas, 3 enums, 2 triggers de imutabilidade, `is_admin()` blindado (SEC-F15),
índices, RLS-on; e empiricamente — `truncate/update/delete` em `audit_events` como
`service_role` **bloqueados** (SEC-F16), `anon`/`authenticated` com **zero acesso** às 4
tabelas (SEC-F02/F13). Efeito colateral nulo: a única escrita é uma linha-sonda dentro de
transação sempre revertida.

### 4.2 API com service key (§5) — complementar, best-effort

A prova **autoritativa de imutabilidade é a de banco** (`set role service_role` + tentativa
de `truncate/update/delete`): ela demonstra que o trigger dispara **abaixo** do bypass do
`service_role`, que é exatamente SEC-F16. O passo de API (DELETE via PostgREST com a service
key) é **complementar** e best-effort — sem semear uma linha real, um 2xx só significa "0
linhas", não falha de segurança. Por isso `SUPABASE_SERVICE_ROLE_KEY` é provisionada
conforme o payload, mas o veredito de segurança vem do teste de banco. Honestidade > teatro
de teste (onboarding §5).

---

## 5. Hardening — follow-ups para a revisão de Security (matrix #8)

Registrados, **não** bloqueiam a preparação do ambiente:

- **SHA-pin das actions de terceiros.** `actions/checkout@v4` e `supabase/setup-cli@v1` estão
  em tags de major. Recomendado pinar por **commit SHA** (supply chain) — validar/aplicar na
  revisão de Security.
- **Rotação de credenciais.** Definir política de rotação para `SUPABASE_ACCESS_TOKEN` e
  `SUPABASE_DB_PASSWORD`; revogar tokens de teste após o apply.
- **Escopo do Environment.** Restringir o `production-db` ao branch protegido (`main`) via
  deployment branch rules, e confirmar que os logs do Actions não vazam a URL (já mascarada).

---

## 6. Estado e próximo passo

- **Ambiente:** **preparado** (artefatos versionados, sem secret). **Pendente** de ação
  humana out-of-band: aprovar `configure_env` e popular o Environment `production-db`
  (secrets + variables).
- **Revisão obrigatória:** DevOps + Security desta mudança de ambiente (matrix #8) — **não**
  assumida; acionada via `security_agent:audit_secrets` (ver handoff).
- **Depois:** com o Environment populado e a revisão baixada → `database_agent:run_migration`
  dispara o workflow `phase1-db-apply.yml`, que aplica a Fase 1 e roda §4/§5.
