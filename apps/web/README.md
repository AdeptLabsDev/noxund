# apps/web — NOXUND Frontend + Core API

**Status:** minimal Next.js scaffold, present and dependency-declared. **Not** a
placeholder any more, and **not** a built product either — see *What is actually
here* below, which is deliberately literal.
**Stack:** Next.js + TypeScript + Tailwind v4 (front + core API via Route
Handlers/Server Actions).
**Standing:** `ACTIVE PRODUCT` (`DEC-0042` §D4).
**Owner agents:** Frontend Agent, Backend Agent.

## Quality — the canonical command

From the repository root:

```bash
pnpm typecheck
```

That is **the one canonical entrypoint for active JS/TS type correctness**, and
it is the same command CI runs — `.github/workflows/js-ts-quality.yml` invokes
exactly it, and holds no separate copy of what it does. It requires **both**
active packages individually (`web` and `@noxund/shared`), each with
`--fail-if-no-match`, so a rename or a workspace-membership error fails the
command instead of silently checking nothing.

**`typecheck` means type correctness only.** It is `tsc --noEmit`. It does not
build, does not lint, does not run tests, and asserts nothing about the Python
surface (`DEC-0042` §D10).

Dependencies materialize from the repository root with the lockfile as
authority:

```bash
pnpm install --frozen-lockfile
```

## What is actually here

Deliberately literal, because a status line that overstates a package is the
defect this section replaces:

- the App Router entry — `src/app/layout.tsx`, `src/app/page.tsx`,
  `src/app/globals.css`;
- configuration — `next.config.ts`, `postcss.config.mjs`, `eslint.config.mjs`,
  `tsconfig.json` (which **does** extend `../../tsconfig.base.json`);
- empty, tracked placeholders for `src/components/`, `src/lib/` and `public/`.

**No test suite exists here, and none is currently justified.** `D2`
adjudicated `Q3` for this surface and returned `BEHAVIORAL TEST SUITE NOT
JUSTIFIED ON CURRENT SURFACE`: the two source modules branch, hold state,
handle events, parse, fetch, transform, calculate and catch exactly zero times.
**That answer is temporal, not permanent** — a future substantive change
reopens the engineering question. No test framework is installed.

**`next build` is UNPROVEN and is deliberately not claimed.** No workflow runs
it, and no quality command here invokes it. Build integrity (`Q1`) for this
package is **routed, not waived** — do not read a green typecheck as a working
build.

## What will live here (not yet built)

- Landing/apply page `noindex` (Frontend).
- Report UI: table, honest toggle, per-row actions, WTP (Frontend).
- API surface: `/apply`, feedback/intent/wtp, admin, internal jobs (Backend).
- Auth + approval gate (Backend + Security).

## Scaffolding

**This package is already scaffolded.** The `pnpm create next-app` instruction
that used to sit here has been removed rather than re-guarded: it targeted this
directory, this directory is now populated, and a copy-pasteable command that
would overwrite it is a hazard no prose guard reliably contains.

## Restrições (ver docs/agents/)

- Nenhuma copy de geração/IA em tempo real.
- Nenhum número exibido sem rastro até `raw_youtube_videos`.
- `tsconfig.json` deve estender `../../tsconfig.base.json` — **satisfeito**.
- Variáveis públicas só via `NEXT_PUBLIC_*`; secrets ficam server-side.
