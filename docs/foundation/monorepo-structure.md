# Monorepo Structure — NOXUND

**Status:** fundação mínima criada e **buildável** (Sprint 0). **Nenhuma feature de produto.**
**Owner:** DevOps/Infra Agent + Documentation Agent (com Product Orchestrator).

Esta camada prepara o terreno técnico sem antecipar construção. `apps/web` está scaffoldado e compila; `services/data-engine` e `supabase/` permanecem scaffolds mínimos.

---

## Layout

```txt
noxund/
├─ apps/
│  └─ web/                 # Next.js + TS + Tailwind (front + core API). Scaffoldado e buildável.
├─ packages/
│  └─ shared/              # Tipos/contratos TS compartilhados (mínimo).
├─ services/
│  └─ data-engine/         # Pipeline Python (scaffold). NÃO é pnpm workspace.
├─ supabase/
│  ├─ migrations/          # Migrations do schema (vazio). Placeholder.
│  └─ README.md
├─ context/                # Fonte de verdade do produto (NÃO alterar sem indexar).
├─ docs/
│  ├─ agents/              # Governança + contratos de agentes.
│  ├─ product/             # Sistema operacional do produto + decisions/.
│  └─ foundation/          # Este documento.
├─ package.json            # Root privado, workspaces (apps/*, packages/*).
├─ pnpm-workspace.yaml     # Workspaces JS/TS (services/ é Python, fora daqui).
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
| Front + core API | **Next.js + TS** em `apps/web` | Já travado em `02_...`. Route Handlers/Server Actions. |
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

## Próximo passo técnico (quando autorizado)

1. Confirmar DEC-0001 (pnpm + layout).
2. `git init`, branch protection da `main` (DevOps).
3. Scaffold `apps/web` (Frontend/Backend) — Sprint 1 (relatório mockado).
4. `supabase init` + primeira migration (Database + Security) — Sprint 3 prep.
5. Bootstrap `services/data-engine` (Data/AI) — Sprint 3.
