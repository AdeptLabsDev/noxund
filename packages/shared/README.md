# packages/shared — Tipos e contratos compartilhados

**Status:** minimal TypeScript package, present and typechecked. **Not** a
placeholder, and **not** yet reached — see *Standing* below.
**Package name:** `@noxund/shared`.
**Stack:** TypeScript puro (sem runtime pesado).
**Owner agents:** Backend Agent, Frontend Agent (com Database/Data-AI para tipos de dados).

## Standing

`ACTIVE-BUT-UNREACHED` (`DEC-0042` §D4): declared, maintained, installed and
typechecked — but **no source file anywhere imports it yet**. The rule for that
standing is *make it coherent; do not build machinery around it*, which is why
this package has quality coverage but no scaffolding beyond what it uses.

Whether it should eventually be imported or retired is a **product-architecture
question, not a quality one**, and is routed rather than answered here.

## Quality — the canonical command

From the repository root:

```bash
pnpm typecheck
```

That is **the one canonical entrypoint for active JS/TS type correctness**, and
it is the same command CI runs. It requires this package individually — via
`pnpm --filter @noxund/shared --fail-if-no-match typecheck` — so if the package
were renamed or dropped from the workspace, the command **fails** rather than
quietly checking one package and reporting green.

**`typecheck` means type correctness only** — `tsc --noEmit`, nothing else
(`DEC-0042` §D10).

## What is actually here

`src/index.ts`, exporting **four string constants** — the MVP name, the
tagline, the vertical and the locked keyword — plus `package.json` and a
`tsconfig.json` that extends `../../tsconfig.base.json`.

**No test suite exists here, and none is currently justified.** `D2`
adjudicated `Q3` for this surface and returned `BEHAVIORAL TEST SUITE NOT
JUSTIFIED ON CURRENT SURFACE`: the entire source is four exported string
constants that nothing imports. **That answer is temporal, not permanent** — a
future substantive change reopens the engineering question. No test framework
is installed.

## O que viverá aqui (quando construído)

- Tipos compartilhados entre `apps/web` e futuras libs (ex.: shape de `report_item`, enums de `event_type`).
- Schemas de validação (ex.: Zod) reutilizáveis entre front e API.
- Constantes do domínio (ex.: thresholds públicos: HOT > 90, Score exibido > 83) — **somente exibição**, nunca o rubric/fórmula.

## Restrições

- **Não** colocar aqui lógica de cálculo de Score/metodologia (vive no data engine, determinístico).
- `tsconfig.json` estende `../../tsconfig.base.json` — **satisfeito**.
- Sem dependências de framework (Next/React) — mantém-se agnóstico.
