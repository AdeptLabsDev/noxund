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

Apenas **dois** secrets entram no CI — least privilege (SEC-F19). A
`SUPABASE_SERVICE_ROLE_KEY` **NÃO é provisionada no CI** (ver §4.2).

| Nome | Uso | Least-privilege / origem |
|---|---|---|
| `SUPABASE_ACCESS_TOKEN` | `supabase link` (CLI auth) | Personal/CI access token do Supabase. Escopar ao mínimo necessário; rotação em §5.2. Dashboard → Account → Access Tokens. |
| `SUPABASE_DB_PASSWORD` | `supabase db push` + string de conexão do `psql` na verificação | Senha do banco do projeto. Único secret embutido na connection URL (mascarada em runtime). Rotação em §5.2. Dashboard → Project → Database → Password. |

> **SEC-F19 — `SUPABASE_SERVICE_ROLE_KEY` fora do CI.** A service-role key (bypass total de
> RLS) é o secret mais perigoso do projeto e **não** entra no Environment. A prova de SEC-F16
> é a de banco (§4.2), que não a usa. Se a chave já foi adicionada ao `production-db`,
> **removê-la** (pré-flight runbook §7).

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

Setup no GitHub (Product Lead/DevOps, fora do repo) — **a ordem importa** (SEC-F18):
1. `Settings → Environments → New environment → production-db`.
2. **Deployment branch rules → restringir a `main`** (branch protegido), **ANTES** de
   adicionar qualquer secret. Sem isso, um `workflow_dispatch` a partir de uma branch
   arbitrária acessaria os secrets do Environment, anulando o gate "PR revisado + merge na
   `main`" (DEC-0007 §2b).
3. **Required reviewers** (DevOps + Security).
4. Só então adicionar os **secrets** (2.1) e as **variables** (2.2).

O passo 2 e a sequência exigem **evidência** (pré-flight runbook §7) — não verificável no repo.

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

### 4.2 SEC-F16 provado em banco — service key NÃO entra no CI (SEC-F19)

A prova **autoritativa de imutabilidade é a de banco**: `set role service_role` + tentativa
de `truncate/update/delete` em `audit_events`, demonstrando que o trigger dispara **abaixo**
do bypass do `service_role` — exatamente SEC-F16. Esse teste **não usa** a service-role key:
usa o papel `service_role` via `set role` na sessão `postgres`.

Por isso o passo de API via service key foi **removido** do workflow (era best-effort e
não-autoritativo) e a `SUPABASE_SERVICE_ROLE_KEY` **não é provisionada no CI**. Colocar o
secret de maior raio de explosão no CI por um teste não-autoritativo é risco desnecessário —
e **compõe** com supply chain (SEC-F17). O veredito de SEC-F16 vem 100% da prova de banco.
Honestidade > teatro de teste (onboarding §5).

---

## 5. Remediações de segurança (SEC-0005) e política de rotação

### 5.1 Fechado no PR (devops_agent)
- **SEC-F17 — SHA-pin (supply chain).** Actions de terceiros pinadas por **commit SHA
  completo** com comentário de versão; **zero tag mutável** no workflow.
  - `actions/checkout` → `34e114876b0b11c390a56381ad16ebd13914f8d5` (v4.3.1)
  - `supabase/setup-cli` → `ab058987d8d6c725971f6cf9d0b5c98467e30bd1` (v1.7.1)
  - SHAs resolvidos das release tags oficiais via API do GitHub. Re-pinar a cada bump.
- **SEC-F19 — service key fora do CI.** Passo de API removido do workflow; `SUPABASE_SERVICE_ROLE_KEY` não referenciada (§2.1, §4.2).

### 5.2 Política de rotação / revogação (SEC-F20)
- **`SUPABASE_ACCESS_TOKEN`:** escopado ao mínimo necessário; rotacionar (a) **pós-apply** da
  Fase 1, (b) em **troca de pessoal**, (c) **periodicamente** (≤ 90 dias). Tokens
  **temporários/de teste** → **revogar imediatamente após o apply** (Dashboard → Account →
  Access Tokens).
- **`SUPABASE_DB_PASSWORD`:** mesmos gatilhos; após rotação, atualizar o secret do Environment.
  Resetável em Dashboard → Project → Database → Reset password.
- **Comprometimento (suspeita de leak):** revogar/rotacionar **antes** de qualquer novo run e
  invalidar runs em andamento.
- **Pós-apply:** remover do Environment todo secret não mais necessário.

### 5.3 Out-of-band, com evidência exigida (SEC-F18) → ver §7.

---

## 6. Estado e próximo passo

- **Ambiente:** artefatos versionados, sem secret. **SEC-0005 remediado no PR** (SEC-F17 +
  SEC-F19); SEC-F18/F20 documentados como pré-flight out-of-band (§7) com evidência exigida.
- **Revisão obrigatória:** re-auditoria `security_agent:audit_secrets` sobre o PR atualizado
  (matrix #8) para baixar o bloqueio do SEC-0005 §6.
- **Depois:** bloqueio baixado + §7 evidenciado + merge (DEC-0007 §2b) → o Environment já
  populado dispara `database_agent:run_migration` no workflow `phase1-db-apply.yml`.

---

## 7. Pré-flight runbook (out-of-band) — evidência exigida antes do apply

Itens **não verificáveis no repo**: exigem ação do Product Lead/DevOps e **evidência**
(screenshot/confirmação) anexada ao re-audit. Pré-condição do apply.

| # | Ação (Settings → Environments → production-db) | Evidência | Origem |
|---|---|---|---|
| 1 | **Deployment branch rules = `main`** (branch protegido). Idealmente **antes** de popular secrets. | Screenshot da regra de branch | SEC-F18 |
| 2 | **Remover `SUPABASE_SERVICE_ROLE_KEY`** do Environment (não é usada pelo CI). | Screenshot da lista de secrets sem a chave | SEC-F19 |
| 3 | Confirmar **Required reviewers** (DevOps + Security). | Screenshot dos reviewers | INFRA §3 |
| 4 | Confirmar **rotação/revogação** combinada (§5.2); revogar tokens de teste pós-apply. | Confirmação escrita | SEC-F20 |

> **Atenção à sequência (SEC-F18):** os secrets do `production-db` já foram populados — se a
> **branch rule `= main`** não estava ativa nesse intervalo, trate como **exposição
> potencial**: configure a regra **agora** e **rotacione** `SUPABASE_ACCESS_TOKEN` +
> `SUPABASE_DB_PASSWORD` (§5.2) **antes** do primeiro run. Anexe a evidência da regra ao
> re-audit.
