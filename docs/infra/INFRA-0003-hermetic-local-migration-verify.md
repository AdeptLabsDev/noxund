# INFRA-0003 — Validação hermética local de migrations (workflow genérico)

- **Data:** 2026-07-24
- **Status:** **PR aberto — NÃO mergeado, NÃO executado.** Aguarda revisões DevOps + Security + Database + QA.
- **Artefato:** `.github/workflows/migrations-local-verify.yml`
- **Escopo:** infraestrutura de validação. **Não** toca banco remoto/live, schema, Environment, secrets, PR #57 nem Phase 6.
- **Relaciona:** `DEC-0024` (unidade SG-8, PR #57 — o 1º consumidor deste workflow) · `agent-review-matrix.md` #8 (DevOps+Security) · padrão SHA-pin dos workflows de apply existentes.

---

## Por que existe

Nenhuma migration deveria mergear com o par migration/rollback/verify **não executado**. Os workflows de apply existentes rodam contra o **projeto remoto** (Environment `production-db` + secrets) — inadequados para provar apply/rollback de uma migration ainda em revisão. Este workflow prova o ciclo completo contra um **Supabase local descartável**, **sem nenhuma credencial remota**, de forma **genérica** (serve qualquer unidade de migration, não só SG-8).

## Invariantes herméticas (superfície de revisão Security + DevOps)

| Invariante | Como é garantida |
|---|---|
| Manual apenas | `on: workflow_dispatch` — sem push/schedule/PR. |
| Sem Environment | Nenhum job declara `environment:` → **impossível** ler secrets de `production-db`. |
| Sem secrets | Nenhum `secrets.*` referenciado; nenhum access token / senha remota / URL externa de banco; **sem `supabase link`**. |
| Permissões mínimas | `permissions: contents: read` (sem write, sem id-token). |
| SHA obrigatório | `target_sha` deve casar `^[0-9a-f]{40}$` — rejeita branch/tag/SHA curto/malformado (2× — job `guard` e re-assert pré-checkout). |
| Checkout exato | `actions/checkout` com `ref: target_sha` + `fetch-depth: 0`; passo assere `HEAD == target_sha` e que é objeto `commit`. |
| DBURL loopback | `DBURL` fixo em `127.0.0.1:54322`, asserido em runtime; qualquer host não-loopback aborta. Sem host/URL/senha remota. |
| CLI pinado | `supabase/setup-cli` com `version: 2.109.1` (**exato, nunca `latest`**). |
| Actions pinadas | Todo `uses:` por commit SHA completo (SEC-F17). |
| Destruição garantida | `supabase stop --no-backup` em `if: always()`. |
| Sem injeção | Paths passados a `psql` como **variáveis de shell** (`env:`), nunca interpolados no corpo do script. |

> **O que "hermético" significa aqui:** ausência de conexão com um projeto Supabase **remoto** e ausência de **secrets** — **não** isolamento de rede. O runner ainda baixa da internet as **actions**, o **CLI** do Supabase, **pacotes** (apt) e **imagens** Docker; a garantia é que nada disso alcança um banco remoto/live nem lê credenciais.

## Contrato de inputs (genérico)

| Input | Regra | Diretório exigido |
|---|---|---|
| `target_sha` | SHA de commit completo, 40 hex minúsculos. | — |
| `migration_path` | forward migration. | `supabase/migrations/` |
| `rollback_path` | rollback pareado. | `supabase/rollback/` |
| `post_apply_verify_path` | verify pós-apply. | `supabase/tests/` |
| `post_rollback_verify_path` | verify pós-rollback (objetos removidos + contratos anteriores intactos). | `supabase/tests/` |

**Validação de todos os `*_path`** (job `guard` + job `local-verify` pós-checkout): **restrição semântica por diretório** — cada input só é aceito sob o seu diretório de papel (regex `^<dir>/[A-Za-z0-9._/-]+\.sql$`); além disso pertencem ao checkout (`git cat-file -e HEAD:<path>` + `test -f`), sem `..`, terminam em `.sql`, charset seguro, casados como string inteira (anti-multilinha). Inputs chegam ao shell por `env:` e são usados sempre com aspas.

## Ciclo executado

1. iniciar stack local descartável (`supabase start`, offline);
2. aplicar a sequência canônica de migrations do SHA (`supabase db reset`, fail-closed);
3. post-apply verify (`psql -v ON_ERROR_STOP=1 -f <post_apply>`);
4. rollback (`-f <rollback>`);
5. post-rollback verify (`-f <post_rollback>`);
6. reaplicar a migration (`-f <migration>`; o ledger já a marca aplicada, por isso `psql -f`, não `db push`);
7. repetir post-apply verify;
8. destruir a stack (`stop --no-backup`, `always()`).

Qualquer etapa que falhe encerra o run não-zero (fail-closed).

## Fronteira / não-goals

- **Não** aplica nada em banco remoto/live e **não** detém credencial capaz disso.
- **Não** mergeia, **não** altera o PR #57, **não** toca schema, Environment, secrets ou Phase 6.
- **Não** é executado por esta entrega — o disparo é manual, pós-revisão.

## Dependência para validar o SG-8 (PR #57)

Este workflow exige um `post_rollback_verify_path` **existente no `target_sha`**. O commit `47402c9` (PR #57) ainda **não** contém esse script (é o artefato proposto `supabase/tests/sg8_reconciliation_session_post_rollback_verify.sql`). Portanto, para validar o SG-8, o PR #57 deve primeiro adicioná-lo — trabalho do PR #57, fora do escopo desta PR de infraestrutura. Invocação-alvo (após esse script existir), a título de exemplo:

```
target_sha                = <SHA de 40 hex do commit do PR #57 com o post-rollback verify>
migration_path            = supabase/migrations/20260620000008_sg8_reconciliation_session.sql
rollback_path             = supabase/rollback/20260620000008_sg8_reconciliation_session.rollback.sql
post_apply_verify_path    = supabase/tests/sg8_reconciliation_session_post_apply_verify.sql
post_rollback_verify_path = supabase/tests/sg8_reconciliation_session_post_rollback_verify.sql
```

## Revisões obrigatórias (antes de qualquer uso)

- [ ] **DevOps** — pin do CLI/actions, hermeticidade, ciclo, descarte.
- [ ] **Security** — ausência de Environment/secrets/link/token; DBURL loopback; validação de SHA e paths; anti-injeção.
- [ ] **Database** — fidelidade do ciclo apply/rollback/reapply; `db reset` como sequência canônica.
- [ ] **QA** — fail-closed em cada etapa; cobertura do contrato de inputs.
