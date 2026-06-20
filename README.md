# NOXUND

**Product (MVP):** NOXUND Hotspot Artists Report — *market intelligence engine for producers.*
**Locked vertical:** Chicago Drill · locked keyword `chicago drill type beat`
**Status:** Sprint 0 — technical foundation scaffolded. **No product features built yet.**

> This README is **operational**. Strategy, scope and methodology live in [`/context`](./context).
> Agent governance lives in [`/docs/agents`](./docs/agents). Product operating system in [`/docs/product`](./docs/product).

---

## NOXUND MVP

A **closed** market-intelligence tool for type beat producers. It is **not** a marketplace.

Central hypothesis: *validated producers change their production decision when they receive structured, verifiable signals of recent traction* (Score, Velocity, Signals, Competition and clickable YouTube proof).

The MVP ships **two fixed reports** (10 artists each, 2 HOT each), manual approval access, capture of **intent to produce**, a **10–14 day follow-up** and **WTP** — all deterministic and auditable down to raw YouTube Data API data.

Full definition: [`context/01_MVP_Scope_PRD.md`](./context/01_MVP_Scope_PRD.md).

---

## Current MVP Scope

- Closed `noindex` landing/apply + manual approval.
- Two fixed report snapshots; honest toggle ("Ver outro grupo de oportunidades").
- Public table: Title, Tag (HOT > 90), Score (`X/100`, shown only if > 83), Signals, Velocity, Competition, Example.
- Per-artist actions (`Útil` / `Não útil` / `Vou produzir`), follow-up, WTP.
- Deterministic, versioned, auditable, reproducible Score (rubric 40/25/20/15).
- Raw immutable · computed reconstructible · report snapshot frozen.

Non-negotiables: **gen-AI never produces numbers**; no marketplace; no fake real-time AI; every public number traceable to `raw_youtube_videos`.

---

## Tech Stack

- **Frontend / App:** Next.js + TypeScript + Tailwind CSS (App Router, `src/`).
- **Core API:** Next.js Route Handlers / Server Actions (no separate Node API in the MVP).
- **Auth:** Supabase Auth *(future — only env vars prepared now)*.
- **Database:** Supabase Postgres *(future — no schema/migrations yet)*.
- **Data Engine:** Python (`services/data-engine`) *(future — no real collection yet)*.
- **Package manager:** pnpm (workspaces).
- **Observability:** Sentry *(future)*.

Source of truth: [`context/02_Stack_Infra_Architecture.md`](./context/02_Stack_Infra_Architecture.md).

---

## Repository Structure

```txt
noxund/
  apps/
    web/            # Next.js + TS + Tailwind (front + core API). Foundation scaffolded.
  services/
    data-engine/    # Python pipeline scaffold (no collection yet). Not a pnpm workspace.
  packages/
    shared/         # Shared TS types/contracts (minimal).
  supabase/         # Migrations + RLS (empty placeholder).
  context/          # Product source of truth (do not move without re-indexing).
  docs/
    agents/         # Governance + agent contracts.
    product/        # Product operating system + decisions/.
    foundation/     # Monorepo structure & stack decisions.
  .env.example  .gitignore  package.json  pnpm-workspace.yaml  tsconfig.base.json  README.md
```

> `context/` and `docs/` must not be deleted. Moving `/context` files requires updating
> [`docs/product/context-index.md`](./docs/product/context-index.md).

---

## Local Development

Requirements: **Node ≥ 20** (`.nvmrc` = 20) and **pnpm 9** (`corepack enable` activates it).

```bash
pnpm install              # install workspace deps
pnpm dev                  # run apps/web (Next.js dev server)
pnpm --filter web lint    # lint the web app
pnpm --filter web build   # production build
pnpm --filter web typecheck
```

The Python data engine (`services/data-engine`) has its own environment and is **not**
part of the pnpm workspace. It is a scaffold only at this stage (Python not required to
build the web app).

---

## Environment Variables

Copy [`.env.example`](./.env.example) to `.env` (gitignored) and fill locally. **Never commit secrets.**
Variables are prepared but not yet wired (no auth, no DB, no YouTube calls in this phase):

- App: `NEXT_PUBLIC_APP_URL`, `NEXT_PUBLIC_NOXUND_ENV`
- Supabase: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`
- YouTube: `YOUTUBE_API_KEY`
- Email: `EMAIL_PROVIDER`, `RESEND_API_KEY`, `POSTMARK_API_KEY`
- Jobs: `INTERNAL_JOB_SECRET`
- Observability: `SENTRY_DSN`, `NEXT_PUBLIC_SENTRY_DSN`

---

## What is intentionally out of scope

This foundation deliberately excludes (see [`docs/product/scope-guardrails.md`](./docs/product/scope-guardrails.md)):

- marketplace;
- separate Fastify API (`apps/api`);
- Redis;
- Celery;
- Stripe;
- GSAP;
- Framer Motion;
- ML scoring;
- data lake;
- on-demand generation;
- multi-keyword;
- real YouTube pipeline at this stage.

---

## Where to start

| You want to… | Read |
|---|---|
| Understand the full context | [`docs/product/context-index.md`](./docs/product/context-index.md) |
| Know who coordinates execution | [`docs/agents/product-orchestrator-agent.md`](./docs/agents/product-orchestrator-agent.md) |
| Know the global agent rules | [`docs/agents/global-agent-rules.md`](./docs/agents/global-agent-rules.md) |
| See what to build | [`docs/product/mvp-backlog.md`](./docs/product/mvp-backlog.md) |
| See what NOT to build | [`docs/product/scope-guardrails.md`](./docs/product/scope-guardrails.md) |
| Understand the monorepo | [`docs/foundation/monorepo-structure.md`](./docs/foundation/monorepo-structure.md) |

---

## Suggested sprints

- **Sprint 0** — organization & foundation (current).
- **Sprint 1** — navigable mocked report.
- **Sprint 2** — validation events (feedback, intent, WTP, follow-up, export).
- **Sprint 3** — real pipeline (YouTube → raw → computed → snapshot, reproducible).
