# Monorepo Structure — NOXUND

**Status:** fundação mínima criada. **Nenhuma feature de produto.**
**Owner:** DevOps/Infra Agent + Documentation Agent (com Product Orchestrator).

Esta camada prepara o terreno técnico sem antecipar construção. `apps/web` está
scaffoldado e **passa no typecheck** (`tsc --noEmit`, verificado no CI);
`packages/shared` idem. **`next build` NÃO é executado por nenhum workflow e
permanece `UNPROVEN`** — a palavra "buildável" foi retirada desta página porque
nada a sustentava. `services/data-engine` **não** é mais um scaffold: é o maior
corpo de código ativo do repositório, com suíte determinística e CI próprio.
`supabase/` é `HISTORICAL / PRESERVED` e não recebe investimento de qualidade.

---

## Layout

```txt
noxund/
├─ apps/
│  └─ web/                 # Next.js + TS + Tailwind (front + core API). Scaffold mínimo; typecheck no CI.
├─ packages/
│  ├─ shared/              # Tipos/contratos TS compartilhados (mínimo). ACTIVE-BUT-UNREACHED.
│  └─ orchestrator/        # LEGACY / NON-AUTHORITATIVE (DEC-0038 D1). Fora do workspace; sem investimento de qualidade. EXCLUÍDO ≠ REMOVIDO.
├─ services/
│  └─ data-engine/         # Pipeline Python determinístico. NÃO é pnpm workspace. CI próprio.
├─ tools/
│  └─ governance/          # Checker de durabilidade de referência + suíte própria. ACTIVE TOOLING.
├─ infra/
│  └─ postgres/            # PostgreSQL 15 local (DEC-0028). ACTIVE TOOLING · LOCAL ONLY — sem CI.
├─ supabase/               # HISTORICAL / PRESERVED. Sem investimento de qualidade.
├─ context/                # Fonte de verdade do produto (NÃO alterar sem indexar).
├─ docs/
│  ├─ agents/              # Governança + contratos de agentes.
│  ├─ product/             # Sistema operacional do produto + decisions/.
│  ├─ result/              # Registros de evidência por unidade.
│  └─ foundation/          # Este documento.
├─ package.json            # Root privado. Scripts de raiz — `typecheck` é o entrypoint canônico JS/TS.
├─ pnpm-workspace.yaml     # Workspaces JS/TS ativos: root, apps/web, packages/shared (services/ é Python, fora daqui).
├─ tsconfig.base.json      # Config TS base (apps/packages estendem).
├─ .env.example            # Template de env (sem secrets).
├─ .gitignore  .nvmrc  .editorconfig
└─ README.md               # README operacional da raiz.
```

---

## Decisões de fundação

| Item | Escolha | Nota |
|---|---|---|
| Gerenciador de pacotes | **pnpm** (workspaces) | Padrão eficiente p/ monorepo Next.js. Confirmar com Product Lead (DEC-0001). |
| Node | **20** (`.nvmrc`) | LTS. |
| Front + core API | **Next.js + TS + Tailwind v4** em `apps/web` | Já travado em `02_...`. Route Handlers/Server Actions. Design system monocromático (DEC-0002). |
| Data engine | **Python** em `services/data-engine` | Script/worker; FastAPI só Fase 2 (OD-05). |
| Banco/Auth | **Supabase** em `supabase/` | Postgres + Auth + RLS. |
| Tipos compartilhados | **`packages/shared`** | TS agnóstico, sem cálculo de Score. |

Frameworks (Next/Supabase/Python) já estavam decididos em `/context`. O que é **novo** nesta fundação e precisa de confirmação é apenas a **tooling** (pnpm, layout) — registrado em `docs/product/decisions/DEC-0001-monorepo-foundation.md`.

---

## O que esta fundação NÃO faz

- Não cria features de produto (sem login, dashboard, tabela real, jobs).
- Não cria tabelas/migrations nem schema Supabase.
- Não configura Vercel/Supabase/Sentry remotos (só quando necessário — `02_...` §5).
- Não commita nada (sem `git init`/push neste passo).

---

## Entrypoints canônicos de qualidade

**Um comando por superfície, versionado, e o CI invoca exatamente o mesmo
artefato.** Ninguém precisa ler YAML de workflow para reconstruir estes
comandos.

| Superfície | Comando canônico | O CI invoca esse mesmo comando? |
|---|---|---|
| JS/TS ativo (`apps/web` + `packages/shared`) | `pnpm typecheck` (da raiz) | **Sim** — `js-ts-quality.yml` |
| Data engine (`services/data-engine`) | `python services/data-engine/run_quality_checks.py` | **Sim** — `data-engine-tests.yml` |
| Governança (`tools/governance`) | `python tools/governance/run_quality_checks.py` | **Sim** — `governance-checks.yml` |
| PostgreSQL local (`infra/postgres`) | `infra/postgres/scripts/verify-local` | **Não — LOCAL ONLY, por decisão.** Sem CI |

Instalação das dependências JS/TS, com o lockfile como autoridade:

```bash
pnpm install --frozen-lockfile
```

**Cada nome descreve exatamente o que o comando checa** (`DEC-0042` §D10).
`typecheck` é `tsc --noEmit` — correção de tipos e nada mais: **não** builda,
**não** roda lint, **não** roda testes e nada afirma sobre Python. Os dois
runners Python declaram no próprio docstring o que cobrem e o que **não**
cobrem.

**Não há comando de raiz que rode tudo, e isso é deliberado.** Um `quality` ou
`check-all` de raiz atravessando linguagens afirmaria uma cobertura que nenhum
mecanismo entrega.

### Duas exceções, declaradas em vez de escondidas

- **`infra/postgres` é `LOCAL ONLY`.** Exige Docker Desktop + WSL 2 e roda por
  `infra/postgres/scripts/*-local`; `verify-local` é a suíte de asserção.
  **Nenhum CI existe para ele e nenhum é criado** — ver `infra/postgres/README.md`.
- **O contrato do driver de coleta permanece só no CI.** Provar que o wheel
  hash-pinado do `psycopg` importa exige `pip install`, o que alteraria o
  ambiente local; por isso ele não entra no comando local padrão do data engine.

### O que ainda NÃO é verificado por nada

Dito porque uma lista de comandos verdes sugere cobertura que não existe:

- **`next build`** — nenhum workflow o executa; integridade de build (`Q1`) de
  `apps/web` permanece `UNPROVEN`, **roteada e não dispensada**.
- **Lint / análise estática** — ESLint, Ruff, shellcheck e actionlint estão
  configurados ou ausentes, mas **nenhum é executado**. É a adjudicação `D4`.
- **Testes de comportamento em JS/TS** — não existem, e `D2` adjudicou que
  nenhuma suíte se justifica na superfície atual. Resposta temporal, não
  permanente.
