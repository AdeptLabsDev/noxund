# SEC-0005 — Security Audit · Ambiente credenciado da Fase 1 (CI)

- **Task:** `task_phase1_security_audit_secrets_env` · **Action:** `audit_secrets` · **Agent:** `security_agent`
- **Data:** 2026-06-21
- **Escopo:** branch `infra/phase1-credentialed-apply-env` (commit `748cf6d`) — ambiente credenciado de apply (CI).
- **Mandato:** DEC-0007 §2a (`audit_secrets` sem bloqueio antes do merge/apply) · matrix #8 (DevOps+Security) · INFRA-0001 §5.

---

## 0. Veredito

⛔ **COM BLOQUEIO — DEC-0007 §2a NÃO satisfeita.**

- ✅ **Zero secret em arquivo versionado** — confirmado por varredura (não é "assumido").
- ⛔ **2 bloqueantes:** SEC-F17 (actions sem SHA-pin) e SEC-F18 (Environment não escopado ao branch protegido).
- ⚠️ **2 condições obrigatórias antes do apply:** SEC-F19 (service-role key fora do CI) e SEC-F20 (rotação/revogação).

**Não libero para merge/apply.** O merge do PR só prossegue com SEC-F17 corrigido **no PR**; o apply só com SEC-F18 comprovado **antes de popular os secrets**. SEC-F19/F20 antes do apply. Re-auditar após a correção.

---

## 1. Varredura de secrets (checklist #1) — PASSA

| Padrão | Resultado |
|---|---|
| `sbp_…` (access token) | 0 ocorrências |
| `eyJ…` (JWT service-role/anon) | 1 falso-positivo: substring dentro de um hash `integrity` do `pnpm-lock.yaml` (não é JWT — sem estrutura `header.payload.sig`). Nenhum token. |
| `-----BEGIN` (chave PEM) | 0 ocorrências |
| Atribuições `SECRET=valor` | Só **referências** `${{ secrets.* }}` no workflow e placeholders `...`/vazios em `.env.example`. Nenhum **valor**. |
| `postgres://user:senha@` (URL com credencial) | 0 ocorrências — a URL é montada em runtime a partir de `secrets.*`, url-encodada e **mascarada**. |
| Arquivos `.env` rastreados | Só `.env.example` (raiz + `services/data-engine`), ambos com chaves **vazias**. Nenhum `.env` real. `.gitignore` cobre `.env`/`.env.*` com exceção `!.env.example`. |

**Conclusão:** nenhum secret em arquivo versionado. `project_ref` (`pwbkplzyzmortwjjpcbg`) é corretamente tratado como **não-secret** (aparece na URL do projeto) em `config.toml` e no `env:` do workflow.

---

## 2. Checklist item a item

| # | Item | Veredito | Nota |
|---|---|---|---|
| 1 | Zero secret versionado | ✅ **PASSA** | Varredura §1. |
| 2 | Workflow lê secrets só por `secrets.*`/`vars.*`; DB URL mascarada; nada ecoado | ✅ **PASSA** | Secrets via contexto (L73,90-91,96,121,145); `::add-mask::${url}` **antes** de gravar no `GITHUB_ENV` (L85-86,133-134); `curl -s -o /dev/null -w '%{http_code}'` não imprime corpo nem chave (L160-165); auto-masking do GitHub cobre os `secrets.*`. |
| 3 | SHA-pin de `actions/checkout@v4` e `supabase/setup-cli@v1` | ⛔ **FALHA → SEC-F17** | Tags mutáveis de major, não SHA. |
| 4 | Environment `production-db` escopado ao branch protegido (`main`) | ⛔ **NÃO COMPROVÁVEL NO REPO → SEC-F18** | É config out-of-band do GitHub; exijo evidência antes de popular secrets. |
| 5 | Rotação de `SUPABASE_ACCESS_TOKEN`/`SUPABASE_DB_PASSWORD`; revogar tokens de teste pós-apply | ⚠️ **FALTA → SEC-F20** | INFRA-0001 §5 lista como follow-up; sem política documentada. |
| 6 | `permissions` mínimas (`contents: read`) | ✅ **PASSA** | L30-31, top-level. `GITHUB_TOKEN` read-only; sem `write`/`packages`/`id-token`. |

---

## 3. Bloqueantes

### SEC-F17 (Alta) — Actions de terceiros sem SHA-pin
`actions/checkout@v4` (L64,110) e `supabase/setup-cli@v1` (L67) usam **tags mutáveis**. Os jobs `apply`/`verify` rodam com `environment: production-db` (DB password, access token e — se provisionada — a service-role key). Uma tag repointada (comprometimento de conta/repo do mantenedor) executa código arbitrário nesse contexto. **Vetor concreto:** `supabase/setup-cli` instala o **binário `supabase`** que o passo de apply executa **com `SUPABASE_ACCESS_TOKEN` e a `SUPABASE_DB_URL` no env** → exfiltração de credencial de produção.
**Mitigação (no PR, antes do merge):** pinar por **commit SHA completo** com comentário de versão, ex.:
```yaml
- uses: actions/checkout@<sha>        # v4.x.x
- uses: supabase/setup-cli@<sha>      # v1.x.x
```

### SEC-F18 (Alta) — Environment `production-db` não escopado ao branch protegido
Por padrão, um GitHub Environment aceita **qualquer branch**. Como o workflow é `workflow_dispatch`, alguém com permissão de dispatch poderia rodar uma **versão modificada do workflow a partir de uma branch** (ex.: que ecoa os secrets ou roda SQL malicioso) e **acessar os secrets do `production-db`** — anulando o gate "PR revisado + merge na main" (DEC-0007 §2b).
**Mitigação (out-of-band, antes de popular os secrets):** em `Settings → Environments → production-db → Deployment branch rules`, restringir a **`main`** (branch protegido). **Evidência exigida** (screenshot/confirmação do DevOps/Product Lead) — não posso verificar no repo. Sequência limpa: configurar a regra **antes** de adicionar os secrets (INFRA-0001 §6 confirma que ainda não foram populados).

---

## 4. Condições obrigatórias antes do apply (não bloqueiam o merge dos artefatos)

### SEC-F19 (Média) — Não provisionar `SUPABASE_SERVICE_ROLE_KEY` no CI (least privilege)
A própria INFRA-0001 §4.2 admite que o teste de API é **best-effort, não-autoritativo** ("honestidade > teatro de teste"); a prova autoritativa de SEC-F16 é a de **banco** (`set role service_role` + truncate/update/delete), que **não usa** a service key. Colocar o secret mais perigoso do projeto (bypass total de RLS) no CI por um teste não-autoritativo **amplia o raio de explosão** — e **compõe** com SEC-F17 (action comprometida poderia lê-la). O workflow já **pula graciosamente** se a chave estiver ausente (L149-152).
**Mitigação:** **não popular** `SUPABASE_SERVICE_ROLE_KEY` no Environment; deixar o passo de API pular; confiar na prova de banco. Se mantida por decisão, registrar o risco e revogar imediatamente após o apply.

### SEC-F20 (Média) — Política de rotação + revogação de tokens de teste
Sem política documentada. **Mitigação (documentar antes do apply):** rotação de `SUPABASE_ACCESS_TOKEN` e `SUPABASE_DB_PASSWORD` (gatilhos: pós-apply, troca de pessoal, periódica); **revogar** qualquer token temporário/de teste **imediatamente após o apply**. `SUPABASE_ACCESS_TOKEN` escopado ao mínimo necessário.

---

## 5. Pontos fortes confirmados (não-bloqueantes)

- Workflow **manual-only** (`workflow_dispatch` + frase `APPLY-PHASE1` no job `guard` sem secrets) + **required reviewers** do Environment (DevOps+Security) — defesa em duas camadas, alinhada a DEC-0006/INFRA-0001 §3.
- DB URL via **session pooler** mascarada; `concurrency` evita applies paralelos; apply atômico (`begin/commit`, falha = job vermelho).
- Verificação pós-apply autoritativa em banco (estrutural §4 + empírica §5: imutabilidade de `audit_events` e default-deny `anon`/`authenticated`), efeito colateral nulo (sonda em transação revertida).

---

## 6. Gate consolidado do `run_migration` (atualização do quadro DEC-0007)

| Gate | Estado |
|---|---|
| Veto técnico do Security (SQL) — SEC-0004 | ✅ baixado |
| Aprovação humana da migration — DEC-0006 | ✅ concedida |
| `audit_secrets` sem bloqueio — DEC-0007 (a) | ✅ **BAIXADO na re-auditoria** — `SEC-0006` (SEC-F17/F18/F19/F20 fechados; SHAs verificados na API do GitHub). Este doc registrou o bloqueio original (SEC-F17, SEC-F18). |
| PR revisado + mergeado — DEC-0007 (b) | ⏳ pendente (SEC-F17 deve entrar no PR) |
| Required reviewers em CI — INFRA-0001 §3 | ⏳ em tempo de execução |

**Como o bloqueio cai:** SEC-F17 corrigido no PR + evidência de SEC-F18 (branch rule = `main`) antes de popular secrets + SEC-F19/F20 endereçados → novo `audit_secrets` → "sem bloqueio". Silêncio de Security ≠ aprovação.
