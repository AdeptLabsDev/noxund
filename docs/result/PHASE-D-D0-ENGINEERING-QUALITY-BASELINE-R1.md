# PHASE D — `D0` Engineering-quality baseline · R1

**Status:** COMPLETE as an Author deliverable · **Date:** 2026-08-21 · **Author:** a task-scoped Author, reviewed by a **distinct** task-scoped independent reviewer, under the topology [`DEC-0037`](../product/decisions/DEC-0037-execution-topology-role-independence-governance-review-function.md) D5 fixes, carried into this unit by the Product Lead's Phase-D and `D0` GO · **Ratification gate:** the Product Lead's manual merge
**Authority class:** DESCRIPTIVE-CURRENT · **Lifecycle:** CURRENT · **Mutability:** FROZEN
**Type:** Baseline measurement record. **This is not a decision record** — it creates no authority, classifies no artifact, narrows no clause, sets no threshold and authorizes no execution. The Phase-D charter is [`DEC-0042`](../product/decisions/DEC-0042-engineering-quality-phase-charter.md); this record is the evidence that charter's reasons rest on.
**Canonical base:** `main` @ `9f12680d329a6107693bdd9f1b077fdfb17dd0dc`, working tree clean at unit start.
**Method.** Every claim below was **re-derived by this unit at the canonical base** from the repository itself and from live read-only platform reads. Two read-only Specialist reports were supplied as input; **every one of their findings was treated as `REPORTED — UNVERIFIED` and independently re-derived.** Where re-derivation disagreed, the disagreement is recorded at §13 rather than smoothed. No conversation claim and no memory content was used as proof (`DEC-0035` §5).
**Evidence classes** are exactly the four of [`DEC-0040`](../product/decisions/DEC-0040-governed-result-disposition-closeout-contract.md) D3 — `REPORTED` · `VERIFIED` · `ACCEPTED` · `UNPROVEN`. `HOLD` and `RED` are unit-disposition values and are used nowhere here as evidence classes.
**Author boundary.** This record states **no unit disposition and no artifact verdict** ([`DEC-0040`](../product/decisions/DEC-0040-governed-result-disposition-closeout-contract.md) D11). Both are void coming from an Author.

---

## 1. Classification, adjudicated rather than copied

`DEC-0035` §9's `docs/result/**` row defaults to `DESCRIPTIVE-CURRENT · CURRENT · FROZEN` **for phase closeouts**, and carries an anticipatory clause that *"should this family later carry run or gate outputs, those take class: EVIDENCE"*. This artifact is neither: it is a **baseline measurement record**, produced mid-phase rather than at its close, and it contains run outputs without being one.

**Adjudication: `DESCRIPTIVE-CURRENT · CURRENT · FROZEN`, with the run outputs inside it carrying `EVIDENCE` at clause level.** The reason is the artifact's dominant function. Its purpose is to state what is factually true of this repository now, so that Phase D can route from it — which is exactly what `DEC-0035` §3.1 defines DESCRIPTIVE-CURRENT for: *"A statement of current repository or system state, safe to route from. Creates no authority."* The executed suites and the digest reproduction reported at §5 are genuine run evidence and are marked `VERIFIED` individually; classifying the whole file EVIDENCE on their account would apply the whole-file promotion `DEC-0035` §9.1 expressly forbids in the mirror direction — *"A whole file is therefore never promoted … because one of its clauses was ratified elsewhere."* The same clause-level discipline is applied here. `FROZEN` follows the family and the precedent of the three closeouts already in it: the body is never rewritten, and its accuracy is bounded by the canonical base declared in the header.

---

## 2. Repository surface classification

Standings are `DEC-0042` §D4's four. Every row was established by tracked-file enumeration plus an importer and workflow search; nothing rests on a manifest's self-description.

| Surface | Standing | Evidence | Class |
|---|---|---|---|
| `apps/web/**` | **ACTIVE PRODUCT** | 13 tracked files; the sole target of all four root scripts, every one of which is `pnpm --filter web …`. Three source files only: a static page component, a static root layout, and one stylesheet | `VERIFIED` |
| `packages/shared/**` | **ACTIVE-BUT-UNREACHED** | declared workspace under the `packages/*` glob; `git grep '@noxund/shared'` returns exactly one hit — its own manifest name field. **Zero importers repo-wide** | `VERIFIED` |
| `packages/orchestrator/**` | **LEGACY / NON-AUTHORITATIVE** | the disposition is `DEC-0038` D1. Re-confirmed here: 35 tracked files, 32 TypeScript; every `@noxund/orchestrator` hit outside the package is documentation prose; **zero executable importers, zero workflow references** | `VERIFIED` |
| `services/data-engine/src/**` | **ACTIVE PRODUCT** | 12 Python modules, the largest active code body in the tree; watched by two workflows | `VERIFIED` |
| `services/data-engine/tests/**` and `tests_integration/**` | **ACTIVE PRODUCT** (test surface) | 10 unit modules watched by CI; 1 integration module requiring a container stack | `VERIFIED` |
| `tools/governance/**` | **ACTIVE TOOLING** | the `DEC-0041` reference-durability checker plus its suite; invoked by `governance-checks.yml` in three steps | `VERIFIED` |
| `infra/postgres/**` | **ACTIVE TOOLING · LOCAL ONLY** | shell scripts, a compose file and a local stack test. `grep -rn 'infra/postgres' .github/workflows/` returns nothing — **no workflow invokes any of it** | `VERIFIED` |
| `supabase/**` | **HISTORICAL / PRESERVED** | `supabase/README.md` opens *"supabase — Database & Auth (RETIRED — historical artifacts)"*. 29 SQL files across migrations, rollback and tests | `VERIFIED` |
| `supabase/config.toml` | **INERT** | it names a project reference that `DEC-0034` retired, and the six workflows that would consume it are disabled at platform level. **Two independent reasons, not one** | `VERIFIED` |
| `db/**` | **PLACEHOLDER** | four `.gitkeep` files and one legacy map document; no executable content | `VERIFIED` |
| `design/**` | **NON-EXECUTABLE REFERENCE** | one SVG and three colour/typography notes | `VERIFIED` |
| `context/**` | **MIXED AT CLAUSE LEVEL** | 12 files. **Not a blanket historical surface**: `DEC-0035` §9 gives this family *"No blanket class"* and assigns authority per file through the Product-Orchestrator source-of-truth hierarchy | `VERIFIED` |
| `.github/workflows/**` | **ACTIVE TOOLING** | 12 files on disk; see §6 | `VERIFIED` |
| `.agents/`, `skills-lock.json`, `.claude/` | **NOT NOXUND ARTIFACTS** | `.gitignore` names the first two under the heading *"Local tooling scaffolding (NOT NOXUND artifacts)"*. `.claude/` is ignored by a **user-global** ignore file outside this repository — `git check-ignore -v` resolves it to the pattern `**/.claude/settings.local.json` in the user's global git ignore. **Established, not left unknown** (§13, item 7) | `VERIFIED` |

**One reported anomaly is resolved rather than carried.** A `git ls-files` entry beginning with a quote character is **not a defect**: it is `core.quotePath` at its default, octal-escaping a non-ASCII path. `git ls-files -z | tr '\0' '\n'` renders it as `context/Relatório Estratégico de Posicionamento — NOXUND.md`. `VERIFIED`. No repository defect exists here and none should be routed.

---

## 3. Volume, and where the commands point

Stated once, as a point-in-time measurement, because the asymmetry it shows is the single most load-bearing fact in this baseline. **These figures belong here and are deliberately absent from `DEC-0042`** (`DEC-0042` §5).

| Body | Lines | Reached by a root script? |
|---|---|---|
| `apps/web` source (page, layout, stylesheet) | 123 | **yes** — all four root scripts |
| `services/data-engine` source | 6,437 | no |
| `tools/governance` (checker + suite) | 923 | no |
| `infra/postgres` shell | 829 | no |
| `packages/shared` source | 9 | no |
| `packages/orchestrator` TypeScript (legacy) | 2,779 | no |
| `supabase` SQL (historical) | 8,131 | no |

> **Roughly 8,200 lines of *active* code sit outside every root command, against roughly 120 inside them.** Adding the legacy control plane and the historical SQL, the four root scripts reach about 123 of some 19,200 tracked lines. `VERIFIED`.

---

## 4. The four root scripts, and the two that no runner invokes

`package.json` at the repository root declares exactly four scripts — `dev`, `build`, `lint`, `typecheck` — and **all four are `pnpm --filter web …`**. **There is no root `test` script.** The only workspace declaring a `test` script is `packages/orchestrator`, which is legacy. `VERIFIED`.

`packages/shared` declares a working `typecheck` script that **no root command reaches**, because the root filter names `web` only. `VERIFIED`.

---

## 5. Commands executed — exact, quoted

Every command below was run at the canonical base, read-only, with byte-code writing suppressed by environment variable so that children inherit it. **Nothing was installed; no lockfile was read or written by a package manager; no workflow was dispatched; no configuration was changed.**

| # | Command, verbatim | Result | Class |
|---|---|---|---|
| 1 | `git rev-parse HEAD` · `git status --porcelain` | `9f12680d329a6107693bdd9f1b077fdfb17dd0dc`, clean | `VERIFIED` |
| 2 | `git grep -n 'DEC-0042'` and `git log --all --oneline --name-only --diff-filter=A \| grep -i 'DEC-0042'` | both return no match. The second searches, via `--all`, every commit reachable from every ref — **64 refs and 241 commits** at the canonical base, re-derived by `git for-each-ref \| wc -l` and `git rev-list --all --count`. The identifier was free | `VERIFIED` |
| 3 | `PYTHONDONTWRITEBYTECODE=1 python -B -m unittest discover -s tests -p 'test_*.py'` in `tools/governance` | `Ran 40 tests` · `OK` | `VERIFIED` |
| 4 | `PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=src python -B -m unittest discover -s tests -p test_repro_harness.py` in `services/data-engine` | `Ran 21 tests` · `OK` | `VERIFIED` |
| 5 | `PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=src python -B -m unittest discover -s tests -p 'test_[a-u]*.py'` in `services/data-engine` | `Ran 237 tests` · `OK` — the whole unit suite except the one module that writes to system temp | `VERIFIED` |
| 6 | the CI golden-digest one-liner with `PYTHONPATH='src;tests'` | digest reproduced twice, both `c8e33fe85034e2c406bb189249ff829d8928a5b085d192c73220afcb89674ca8`, equal to the locked golden value | `VERIFIED` |
| 7 | the same one-liner with CI's own `PYTHONPATH='src:tests'` | `ModuleNotFoundError: No module named 'test_repro_harness'` — the parity defect reproduced (§9) | `VERIFIED` |
| 8 | `PYTHONDONTWRITEBYTECODE=1 python -B tools/governance/check_reference_durability.py audit` | 48 governed files scanned, 11 findings | `VERIFIED` |
| 9 | `PYTHONDONTWRITEBYTECODE=1 python -B tools/governance/check_reference_durability.py check --base HEAD~1` | `OK - no malformed reference shape introduced` | `VERIFIED` |
| 10 | `grep -rn -E 'apps/\|packages/\|pnpm\|next build\|next lint\|tsc \|node --test\|npm \|yarn \|\.tsx?\|node-version\|setup-node' .github/workflows/` | **no match** — exit 1 (§6) | `VERIFIED` |
| 11 | every unique workflow blob on every reachable ref, scanned for the same command set | 47 unique blobs, **zero hits** (§6) | `VERIFIED` |
| 12 | `gh api repos/AdeptLabsDev/noxund/rulesets` and the full read of ruleset `19697151` | three active rulesets; rules are deletion, non-fast-forward and pull request; **no required-status-checks rule** (§8) | `VERIFIED` |
| 13 | `gh api repos/AdeptLabsDev/noxund/branches/main/protection` | `404` · `Branch not protected` | `VERIFIED` |
| 14 | `gh api repos/AdeptLabsDev/noxund/actions/workflows` | 13 registered against 12 on disk (§6) | `VERIFIED` |
| 15 | `gh run list --limit 300 --json name` and `gh api repos/AdeptLabsDev/noxund/actions/runs?per_page=1` | **112 runs as at the canonical base, before this unit's own push**, across **13 distinct workflow names**, **none JS/TS**. The run total rises with every push and is deliberately dated here rather than stated flat; **the distinct-name set and the JS/TS conclusion are unaffected by it** | `VERIFIED` |

**Search commands establishing an absence**, stated explicitly because an absence proved by a manifest is not proved at all:

- test assets — `find apps packages/shared -type d -name node_modules -prune -o -type f \( -name '*.test.*' -o -name '*.spec.*' \) -print` and the same for directories named `__tests__`: **no result**.
- runner configuration — `find apps packages -type d -name node_modules -prune -o -type f \( -name 'jest.config*' -o -name 'vitest.config*' -o -name 'playwright.config*' -o -name 'cypress.config*' -o -name 'conftest.py' -o -name 'pytest.ini' -o -name 'tox.ini' -o -name 'Makefile' -o -name 'noxfile.py' \) -print`: **no result**.
- runner dependencies — `git grep -n 'jest\|vitest\|playwright\|cypress\|mocha\|@testing-library' -- '*.json'`: **no match**.
- developer entry points — `git ls-files | grep -iE 'makefile|tox\.ini|noxfile|justfile|conftest'`: **no match**.

> **`apps/web` and `packages/shared` have zero tests, and this is established by search, not by the absence of a devDependency.** `VERIFIED`.

---

## 6. CI coverage matrix

12 workflow files on disk. The inverse question is asked of every surface, because it is the one that matters.

| Surface | Any workflow watches it? | Can it change with **no** quality signal firing? | Class |
|---|---|---|---|
| `services/data-engine/**` | yes — two, on push and pull request | **no** | `VERIFIED` |
| `tools/governance/**` | yes — `governance-checks.yml`, pull request only | **on a pull request, no. On a direct push, yes** — that workflow declares no `push:` trigger | `VERIFIED` |
| `docs/product/decisions/**`, `docs/result/**`, `context-map.md`, `current-state.md`, `task-context-pack.md` | yes — `governance-checks.yml` | same as above | `VERIFIED` |
| `supabase/migrations/**` | partially — one pull-request workflow lists it | mostly no | `VERIFIED` |
| **`apps/web/**`** | **no** | **YES — silently** | `VERIFIED` |
| **`packages/shared/**`** | **no** | **YES — silently** | `VERIFIED` |
| **`packages/orchestrator/**`** | **no** | **YES — silently** (legacy; correctly uninvested per `DEC-0042` §D11) | `VERIFIED` |
| **`infra/postgres/**`** | **no** | **YES — silently** | `VERIFIED` |
| **root `package.json`, `pnpm-lock.yaml`, `tsconfig.base.json`, `.nvmrc`** | **no** | **YES — silently** | `VERIFIED` |
| **`.github/workflows/**` as a set** | **self-referentially only** — each of the three triggered workflows lists its own filename and no other | **YES** — adding a new workflow, or editing a database-apply workflow, fires nothing | `VERIFIED` |

### 6.1 The JS/TS finding, at full strength

**No JS/TS command has ever run in CI in this repository — not "unverified recently", never.** This is stated at the strongest level the evidence supports, and the evidence is stronger than a current-state search:

1. no workflow on `main` lists any path under `apps/` or `packages/`, and none runs a build, lint, type-check, package-manager or Node test command (§5 item 10);
2. **47 unique workflow blobs across every reachable ref** were scanned for the same command set and **none contains one** (§5 item 11);
3. **13 distinct workflow names** have ever produced a run — across 112 runs **as at the canonical base, before this unit's own push** — and every one is Python, database, collection or governance (§5 item 15). **The run total is a moving number; the distinct-name set is the load-bearing one, and adding runs of existing workflows cannot change it.**

### 6.2 The observability defect, stated exactly

Observability **where CI runs is good**: annotation-style error output, expectation-bearing step names, the checked-out SHA echoed, head-SHA checkout, and the offending value printed on failure. There is no step summary, no uploaded artifact and no cache in any workflow — `grep -rn 'GITHUB_STEP_SUMMARY\|upload-artifact\|actions/cache' .github/workflows/` returns nothing. `VERIFIED`.

> **The decisive observability defect is not a bad log.** For `apps/web` and `packages/**` a pull request shows **no checks at all**, and the platform gives no warning that zero checks ran. **An absence of checks renders identically to a clean pass.** That is what `DEC-0042` §D1 names as a silent surface.

### 6.3 The registration that has no file on `main`

13 workflows are registered; 12 files exist on disk. The extra registration is `sg8-r0-preflight-local-test.yml`, `state: active`, last run a failure on 2026-07-29.

**Corrected against the Specialist report** (§13, item 5): its history is **not** empty. `git log --all` resolves it to commit `2d0fbcd`, on the preserved branch `feat/sg8-r0-preflight-author-production-db`, and `git cat-file -e main:…` confirms the file **does not exist on `main`**. So this is a registration created when the file was once pushed on a branch, surviving the file's absence from the default branch — **not an unexplained ghost**. `VERIFIED`.

**Consequence for any future inventory:** an inventory taken from files alone is short by one; an inventory taken from the platform API alone names a file that is not on `main`. Both must be read together.

---

## 7. Test inventory — what each suite actually tests

| Suite | Size | What it exercises | Runs in CI? | Class |
|---|---|---|---|---|
| `services/data-engine/tests` | 276 tests, 10 modules | entity resolution and its Postgres port; the channel filter gates; scoring and the rubric; opportunity ranking and byte-identical report determinism; channel and video collection against recording fakes; the reproducibility harness; the SG-8 runner, coordinator and Postgres adapter, including AST-enforced structural guards | **yes** — twice per run, with a fail-closed count assertion | `VERIFIED` (see §7.1) |
| `tools/governance/tests` | 40 tests | the reference-durability checker: shapes that must fail, shapes that must pass, both enumeration boundaries, mention-versus-use, diff parsing, governed-scope membership, CLI exit codes — and four cases asserting what the checker deliberately does **not** detect | **yes**, with a fail-closed count assertion | `VERIFIED` — executed here, 40/40 |
| `services/data-engine/tests_integration` | 7 tests | SG-8 end-to-end against a disposable local Postgres | pull-request triggered; needs Docker and a driver | `EXECUTABILITY NOT ESTABLISHED IN D0` |
| `packages/orchestrator/tests` | 36 tests, 6 modules | registry, dispatcher, decision validator, project state, safety classification, end-to-end flow | **never** — no workflow watches the path | `REPORTED` (static count) |
| `infra/postgres/tests/p2-local-stack-test.sh` | 1 script | the local Postgres stack | **never** | `REPORTED` |
| `apps/web`, `packages/shared` | **zero** | — | n/a | `VERIFIED` by search (§5) |

**The Python suites are stdlib-only, network-free and database-free by construction.** Collection tests drive recording fakes and construct error objects rather than opening sockets; the SG-8 adapter tests assert by AST that no database driver is imported at all.

### 7.1 Executability actually established in `D0`

This unit went further than a static count, and the arithmetic closes exactly.

- **`VERIFIED` executable offline, zero writes:** the governance suite in full; both checker modes; the reproducibility harness; the golden-digest reproduction; and **237 of the 276 data-engine tests**, run as one process.
- **The 39 not run** are the single module `services/data-engine/tests/test_video_collection.py`, excluded because it writes to the system temp directory — its only such call reads `tempfile.mkstemp()  # local temp file; zero network, zero secret`, which is outside this unit's write scope. **This is a write-scope boundary, not a dependency problem.**
- **237 + 39 = 276**, matching exactly the count CI asserts fail-closed. `VERIFIED`.
- **Canonical CI substitute for the excluded module:** the suite last ran green on `main` in run `30183476983`, and `services/data-engine/**` is unchanged since. **The evidence is applicable but stale**, and is recorded as `REPORTED`, not upgraded.

**`EXECUTABILITY NOT ESTABLISHED IN D0`:** that one module; every `apps/web` and `packages/**` command, **for which no CI substitute exists because none has ever run**; the SG-8 integration job; the hermetic migration verify; and the `infra/postgres` stack.

---

## 8. Quality-gate consistency — the answer is no

**`Q6` — can the repository state one minimum pre-merge expectation per active surface? No.** `VERIFIED`.

It can for exactly two surfaces, `services/data-engine` and `tools/governance` — and **even there the expectation is advisory**, because `Protect main` carries a pull-request rule, a deletion rule and a non-fast-forward rule and **no required-status-checks rule**. The pull-request rule's parameters, **enumerated exhaustively** from `gh api repos/AdeptLabsDev/noxund/rulesets/19697151`, are `required_approving_review_count` `0`, `dismiss_stale_reviews_on_push` false, `required_reviewers` empty, `require_code_owner_review` false, `require_last_push_approval` false, `required_review_thread_resolution` **true**, `require_extra_approval_for_unattributed_changes` **true**, and `allowed_merge_methods` `["merge"]`. **The last two are the only parameters set to `true`, and neither is a status-check requirement**: they constrain *how* a merge proceeds — unresolved threads block it, and an unattributed change costs one more approval against a threshold of zero — and neither makes the passing of any check a condition of merging. `gh api …/branches/main/protection` returns `404 Branch not protected`. The sole bypass actor is scoped to the pull-request context, and the computed bypass field reads `pull_requests_only`.

> **No CI check can block a merge in this repository, on any surface.** `DEC-0041` D5 stands re-verified at this base. Every existing and future check is `AUTOMATIC DETECTIVE` in `DEC-0041` D1's vocabulary.

**Mirror-image parity failure.** The JavaScript side has package scripts that **no runner invokes** — nothing in CI runs `pnpm` at all. The Python side has CI commands that exist **only inside workflow YAML** — there is no Makefile, tox, nox, justfile or script a developer can invoke, established by search at §5. **Local and CI are therefore transcriptions of one intent, not the same artifact**, and they can drift without either side noticing.

---

## 9. Dependency, lock and reproducibility findings

**Asymmetric rigor, and the asymmetry is the finding.**

- **Python: fully pinned and hash-locked.** Both requirements files pin every requirement to one exact version with sha256 wheel hashes and mandate installation under `--require-hashes --only-binary=:all:`, so an unpinned requirement, a hash mismatch or a source build is refused. The deterministic core keeps `dependencies = []` deliberately. `VERIFIED`.
- **JavaScript: caret ranges throughout, with incomplete lock coverage.** `VERIFIED`.
- **The lockfile omits a declared workspace.** `pnpm-lock.yaml` lists importers `.`, `apps/web` and `packages/shared`. **`packages/orchestrator` is absent** although the `packages/*` glob declares it, it carries devDependencies, and it has materialized `node_modules`. **Whether `--frozen-lockfile` would fail on this today is `UNPROVEN — NOT PROBED`:** establishing it requires a dependency install, which this unit is forbidden to perform, and no outcome is assumed in either direction.
- **Node constraint conflict, material.** Root `engines.node` is `>=20` and `.nvmrc` reads `20`; `packages/orchestrator` requires `>=22.6`, because running its `node --test` suite over TypeScript sources needs native type-stripping. No `engine-strict` setting exists. **The only JavaScript test asset in the repository is unrunnable on the repository's own declared Node version.** `VERIFIED`.
- **Cross-platform output determinism, empirically demonstrated and genuinely strong.** The golden digest reproduced **byte-identically on Windows / CPython 3.11.9** against a value locked from Linux CI runs, twice in one process, matching the locked constant exactly (§5 item 6). `VERIFIED`.
- **A real local/CI parity defect, reproduced rather than inferred.** `.github/workflows/data-engine-tests.yml` sets `PYTHONPATH: src:tests` for the golden-digest step. That separator is POSIX. Run verbatim on Windows the import fails with `ModuleNotFoundError: No module named 'test_repro_harness'`; with `src;tests` it succeeds. **The CI job itself is correct — it runs on Linux.** The defect is that the documented command is not the command a developer on the other supported platform can run. `VERIFIED` by execution.
- **No dependency or vulnerability scanning, and no `dependabot` configuration.** `VERIFIED`.

---

## 10. Maintainability findings

**The honest headline: maintainability of *code* is good. The drift is in documentation and wiring.**

### 10.1 Genuine strengths, stated because a list of complaints would be inaccurate

- **Error semantics are strong.** `git grep -nE '^\s*except\s*:'` and `git grep -n 'except BaseException'` both return no match across the tree, and a regex search for empty TypeScript catch blocks returns none. All 17 `except Exception` sites are deliberate and commented. All 12 workflows use `set -euo pipefail`, and every one carries annotated failure output. `VERIFIED`.
- **The layering is real, and it is test-enforced rather than conventional.** `entity_resolution` and its Postgres adapter, and the SG-8 runner, coordinator and adapter, form an **acyclic hexagonal structure** — the pure core imports no adapter, and the adapters import the core. This is not a naming convention: `services/data-engine/tests/test_sg8_coordinator.py:407` defines "test_coordinator_does_not_reimplement_fsm_or_recompute", and sibling AST guards assert that no database driver is importable from the pure modules and that all SQL is parameterized. **This is not duplication, and no code-refactor unit is recommended.**
- **CI assertions are fail-closed by design.** Both count-asserting jobs would fail on a silent under-discovery that `unittest` itself would exit zero on.

### 10.2 Concrete defects

| # | Finding | Locator and quotation | Class |
|---|---|---|---|
| 1 | **`apps/web` does not extend the shared compiler configuration** although its own README states it must. It therefore loses `noUncheckedIndexedAccess`, `noImplicitOverride`, `verbatimModuleSyntax` and `forceConsistentCasingInFileNames`, and targets an older ECMAScript level. **The one surface a root command can reach runs the weakest settings; the two packages carrying the strict settings are unreachable from root** | `apps/web/README.md:27` states the constraint: "`tsconfig.json` deve estender `../../tsconfig.base.json`". `apps/web/tsconfig.json` declares no `extends` key at all | `VERIFIED` |
| 2 | **Stale package status, contradicted by a sibling document** | `apps/web/README.md:3` reads "**Status:** placeholder. Não scaffoldado ainda (sem dependências instaladas)" for a package with eleven declared devDependencies; `docs/foundation/monorepo-structure.md:6` says the opposite — "`apps/web` está scaffoldado e compila" | `VERIFIED` |
| 3 | **A scaffold command that would now write into a populated directory** | `apps/web/README.md:20` offers "pnpm create next-app@latest apps/web" — under a heading that does carry the guard "Não rodar agora", which is stated rather than omitted. The hazard is that the guard is prose and the command is copy-pasteable | `VERIFIED` |
| 4 | **The same staleness in the shared package** | `packages/shared/README.md:3` — "**Status:** placeholder. Não scaffoldado ainda." for a package that has source, a manifest and a working typecheck script | `VERIFIED` |
| 5 | **The root README presents the legacy control plane as the active architecture**, which `DEC-0038` D1 forbids in terms — *"no document may present it as such"*. It is described in the structure tree as the "Multi-agent control plane", and the *Where to start* table routes the reader to it under "See how delegation runs (code)" | `README.md:63` and `README.md:135` | `VERIFIED` |
| 6 | **Duplicated domain constants instead of the workspace that exports them.** `packages/shared` exports the tagline and keyword; `apps/web` hardcodes both | `apps/web/src/app/page.tsx:12` renders "Market intelligence engine for producers." and line 17 renders the locked keyword — both exported as constants from `packages/shared/src/index.ts` | `VERIFIED` |
| 7 | **Decorative static analysis.** `pyproject.toml` declares a `[tool.ruff]` section, while `dependencies` and the `dev` extra are both empty and no workflow invokes ruff — yet ruff suppression codes are written into source | `services/data-engine/src/noxund_data_engine/postgres_sg8.py:524` carries "# noqa: BLE001 — mapped to a domain error below", and three further sites plus two test files carry others. **Configuration and suppressions for a linter that never runs** | `VERIFIED` |
| 8 | **No checker for three further active languages.** No shellcheck over the shell scripts, no actionlint over the workflows, no linter over the SQL, and no configuration validation — `git grep -rn -i 'shellcheck\|actionlint\|sqlfluff\|ruff' -- .github/` returns no match | `VERIFIED` |
| 9 | **No repository hygiene files.** No `CODEOWNERS` at any of the three conventional locations, no pull-request template, no `dependabot` configuration, no `SECURITY.md` | `VERIFIED` |

---

## 11. Q1–Q10 quality-domain matrix

For each domain: **present state** · **required target** (the property Phase D should establish) · **implementation mechanism** — which `D0` **routes** rather than designs.

| # | Domain | State | Present state | Required target | Mechanism |
|---|---|---|---|---|---|
| **Q1** | Build integrity | **PARTIAL** · `VERIFIED` | One build command exists and targets one surface. The Python engine has no build step by design. Nothing verifies that the build command still works, ever | Every active surface has a defined command that a machine runs | **route** — `D2` |
| **Q2** | Type / static correctness | **PARTIAL** · `VERIFIED` | Three TypeScript configurations exist; the strictest two are unreachable from root and the reachable one violates its own documented constraint. Python static analysis is configured, suppressed against, and never run | Each active surface is checked against the configuration it declares, and the declaration matches its documentation | **route** — `D1` for the configuration defect, `D4` for the Python and non-TypeScript adjudication |
| **Q3** | Automated test surface | **PARTIAL** · `VERIFIED` | Strong on Python — 276 unit tests plus 40 governance tests, stdlib-only and deterministic. **Zero on the entire JS/TS surface**, established by search | Every active surface either has a suite exercising its relied-on behaviour, or a recorded decision that it needs none | **route** — not `D0`'s to design |
| **Q4** | CI coverage | **ABSENT for JS/TS · VERIFIED for Python** | Two Python surfaces are covered. `apps/web`, `packages/**`, `infra/postgres` and every root configuration file are covered by nothing, and **no JS/TS command has ever run in this repository's CI history** | No active surface can change with zero signal firing | **route** — `D2` |
| **Q5** | Dependency / lock / install reproducibility | **PARTIAL** · `VERIFIED` | Python exact and hash-locked. JavaScript caret-ranged with a **declared workspace missing from the lockfile**, and a root Node constraint that contradicts a workspace's own requirement | One resolvable, coherent install for the whole workspace | **route** — `D1` |
| **Q6** | Quality-gate consistency | **ABSENT** · `VERIFIED` | Statable for two surfaces of many; advisory even there, because no check is required for merge anywhere | One stated minimum expectation per active surface, and the same command locally and in CI | **route** — `D3` |
| **Q7** | Maintainability / simplicity | **VERIFIED — good, with documentation drift** | Acyclic hexagonal layering, AST-enforced anti-duplication, no accidental duplication found in code. Documentation is stale in four places and misdescribes the architecture in one | Documentation that describes a build, test or architecture path is true | **route** — `D3` for build-path documents; the architecture misdescription is a `DEC-0038` D1 compliance item |
| **Q8** | Error / failure semantics | **VERIFIED — strong** | Zero bare exception handlers, zero `BaseException` handlers, zero empty catch blocks; every broad handler deliberate and commented; fail-closed CI assertions throughout | Preserve it; **do not disturb it** | **no unit required** |
| **Q9** | Output determinism | **VERIFIED — strong** | Byte-identical digest reproduced across processes **and across operating systems**, matching a locked constant; determinism additionally asserted by dedicated tests | Preserve it, and extend the discipline where new checks are added (`DEC-0042` §D9) | **no unit required** |
| **Q10** | Quality observability | **PARTIAL** · `VERIFIED` | Good where CI runs. **Decisively defective where it does not**: zero checks renders as a clean pull request with no warning | A reader can tell what did **not** run | **route** — `D2`, then `D3` |

---

## 12. Known unknowns

Recorded as `UNKNOWN` or `UNPROVEN` rather than assumed in either direction (`DEC-0039` D2's discipline).

1. **Whether `pnpm install --frozen-lockfile` currently succeeds** given the missing importer — `UNPROVEN — NOT PROBED`. Probing requires an install this unit may not perform.
2. **Whether `next build`, `next lint` or `tsc --noEmit` currently pass on `apps/web`** — `UNPROVEN — NOT PROBED`. Each materializes output into the working tree, which is outside this unit's write scope. **No CI substitute exists, because none has ever run.**
3. **Whether the `packages/orchestrator` suite passes at this base** — `REPORTED` only. Its declared Node floor exceeds the repository's declared version, and it has never run in CI.
4. **Whether the excluded 39-test module passes at this base** — `REPORTED` via a stale but applicable CI run (§7.1).
5. **Whether any GitHub App or bot holds repository access** — `UNKNOWN`; unchanged from `DEC-0039` §3.3, and absence must not be inferred.
6. **Whether a container-dependent job would pass** — the SG-8 integration suite, the hermetic migration verify and the local Postgres stack are all `EXECUTABILITY NOT ESTABLISHED IN D0`.

---

## 13. Disagreements with the Specialist input, recorded rather than smoothed

Every Specialist finding was re-derived. Most were confirmed. **Seven did not survive re-derivation unchanged, and the corrections are stated at the point they matter.**

1. **`packages/orchestrator` file count.** Reported as 32 files. Re-derived: **35 tracked files, of which 32 are TypeScript.** The conclusion is unaffected.
2. **Which shared constants `apps/web` duplicates.** Reported as three, all in the page component. Re-derived: the page duplicates the **tagline and keyword**; the product name appears in `apps/web/src/app/layout.tsx:7`, inside the metadata description — "NOXUND Hotspot Artists Report. Market intelligence engine for producers." — not in the page. The fourth exported constant is duplicated nowhere.
3. **SQL file count.** Reported as 31. Re-derived: **29**, in three directories, totalling 8,131 lines.
4. **The `next lint` risk was overstated, and this matters for the roadmap.** The deprecation text is real and was read verbatim: "`next lint` is deprecated and will be removed in Next.js 16." **But the manifest range is `^15.1.6`, which resolves strictly below 16**, so a routine resolution does **not** break the root lint script. The accurate finding is narrower and still real: **the repository's only lint entry point rests on a command with an announced removal date, tied to a major upgrade nobody has scheduled.** The claim that a routine resolution breaks it is withdrawn.
5. **The extra workflow registration is not historyless.** Reported as having no history anywhere in the object graph. Re-derived: `git log --all` resolves it to commit `2d0fbcd` on the preserved branch `feat/sg8-r0-preflight-author-production-db`; the file is confirmed **absent from `main`**. It is an ordinary orphaned registration, not an anomaly (§6.3).
6. **CI run history.** Reported as five workflow names ever. Re-derived: **13 distinct workflow names, across 112 runs as at the canonical base, before this unit's own push.** The load-bearing conclusion survives and is in fact strengthened — none of the 13 is a JS/TS workflow, and §5 item 11 raises the claim from "never observed" to "never present in any workflow blob on any ref".
7. **The `.claude/` ignore source is established, not unknown.** `git check-ignore -v` resolves it to a pattern in the user's **global** git ignore file, outside this repository. It is neither a repository artifact nor a repository defect.

**Also confirmed against the Specialist input:** `docs/product/decisions/**` and `docs/result/**` classification semantics; the zero-importer findings; the tsconfig defect; the ruff finding; the lockfile omission; the Node conflict; the `PYTHONPATH` defect; all test counts; the ruleset configuration; the audit drift; and the `core.quotePath` resolution.

---

## 14. Audit drift, and why it belongs in the charter's reasoning

The reference-durability audit reports **48 governed files and 11 findings** at this base. `DEC-0041` §8 recorded **47 and 11**. The findings are identical; the file count rose by one because unit `C6` added a governed file after that record was written.

> **This is expected corpus growth, not a control failure.** It is also direct in-repository evidence for the rule `DEC-0042` §5 adopts: **a transient measurement must not be embedded in a durable normative record.** A `FROZEN` record cannot be corrected, so a number inside one goes stale the first time correct work changes it — which here took exactly one unit.

---

## 15. Concrete gaps, consolidated

1. Zero CI coverage on the entire JS/TS surface, and never any. 2. No test of any kind for `apps/web` or `packages/shared`. 3. A declared workspace missing from the lockfile. 4. A root Node constraint contradicting a workspace requirement. 5. `apps/web` violating its own documented compiler-configuration constraint. 6. No root `test` script; the only one is on a legacy package. 7. A configured linter installed and invoked nowhere, with suppressions written into source. 8. No checker for shell, workflows or SQL. 9. No invocable developer entry point for the Python quality commands. 10. A POSIX-only path separator in a documented CI command. 11. Four stale build-path documents, one containing a copy-pasteable destructive command. 12. A root README presenting a legacy surface as the active architecture. 13. No `CODEOWNERS`, pull-request template, dependency scanning or `SECURITY.md`. 14. No merge-blocking check anywhere, on any surface.

---

## 16. Proposed `D`-unit roadmap

**A proposal for the Product Lead, tested against this unit's own evidence and revised where the evidence disagreed.** Ordered by prerequisite, not preference. **Ranking is qualitative — impact, reach, detectability, change frequency, repair cost, enforceability. No numeric score exists or is implied.**

### `D1` — JS/TS toolchain coherence and reproducible install

**Exact problem.** The lockfile omits a declared workspace; root `engines.node` and `.nvmrc` contradict `packages/orchestrator`; `apps/web/tsconfig.json` violates the `extends` constraint its own README states. **Revised against `D0` evidence:** the `next lint` item is included as a **scheduled-removal risk on a future major upgrade**, not as a live breakage (§13 item 4) — the Specialist framing is not carried.
**Active surface.** Root configuration, `apps/web`, `packages/*`. **Prerequisite.** None.
**Expected artifact.** Coherent manifests, lockfile and compiler configuration, plus a decision record for the choices made. **Mutating:** YES.
**Why its own unit.** These are the inputs every later quality signal consumes; fixing them under a unit that is also adding CI would conflate a configuration change with a coverage change and make a failure ambiguous.
**Must NOT absorb.** Adding CI; adopting any test framework or linter; dependency upgrades beyond what coherence requires; anything touching `packages/orchestrator` source.

### `D2` — First quality signal for the JS/TS surface

**Exact problem.** Zero CI coverage, ever, on the whole JS/TS half — and a pull request that displays no checks rather than a warning.
**Active surface.** `apps/web`, `packages/shared`. **Prerequisite: `D1`.**
**The prerequisite reason, stated at the strength the evidence supports.** A `--frozen-lockfile` job on a lockfile that omits a declared workspace is not meaningful. **Whether it would actually fail is `UNPROVEN — NOT PROBED`** (§12 item 1), so the ordering rests on the coherence ground, not on a predicted failure — and that ground is sufficient on its own.
**Expected artifact.** One workflow. **Mutating:** YES.
**Must NOT absorb.** Any ruleset, branch-protection or required-status-check change — an authority interaction under `DEC-0041` D5 and D10; test-framework adoption; any Python surface.

### `D3` — One invocable, documented quality entry point per active surface

**Exact problem.** The JavaScript side has scripts no runner invokes; the Python side has commands that exist only inside workflow YAML, with no Makefile, tox, nox or justfile anywhere. `packages/shared` has a working typecheck script unreachable from root. The documented golden-digest command uses a POSIX-only separator that fails on Windows. Four build-path documents are stale and one carries a destructive command.
**Active surface.** All active surfaces, plus their documentation. **Prerequisite: `D2`.**
**Expected artifact.** One invocable entry point per active surface, invoked identically by a developer and by CI; repaired documentation. **Mutating:** YES.
**Must NOT absorb.** Thresholds; new tools; the root README architecture misdescription, which is routed separately below.

### `D4` — Static-analysis adjudication for the non-TypeScript active surfaces

**Exact problem.** Ruff is configured and suppressed against but installed and run nowhere, over the largest active code body in the repository. Shell, workflows and SQL have no checker at all.
**Active surface.** `services/data-engine`, `tools/governance`, `infra/postgres`, `.github/workflows`, `supabase` SQL as a linting target only. **Prerequisite: `D2`** — a place to run it.
**Expected artifact.** A per-surface adjudication under `DEC-0042` §D6, and only the adoptions it justifies. **Mutating:** YES, but **adjudication-first** — installing everything is the failure mode, not the objective. Removing the orphaned configuration and its suppressions is as legitimate an outcome as adopting the linter.
**Must NOT absorb.** Thresholds; any change to `supabase` SQL content, which is historical and preserved.

### `D5` — Phase-D closeout

Against `DEC-0042` §D17's five conditions. **Mutating:** documentation only.

### Ranking, qualitatively

`D1` ranks first on **enforceability and repair cost** — every defect is verified, self-contained and cheap now, and each is a prerequisite input to a later signal. `D2` ranks first on **impact and reach** but cannot go first. `D3` ranks highest on **change frequency**, because parity defects recur on every developer interaction. `D4` ranks highest on **detectability**, since it converts an unobserved surface into an observed one, but it is the least urgent because §10.1 found the code it would examine to be in good order.

### `NEXT CANDIDATE`

> **`NEXT CANDIDATE` = `D1` — JS/TS toolchain coherence and reproducible install.**

Evidence: it is the only unit whose every defect is already `VERIFIED` rather than `UNPROVEN`; it is the declared prerequisite of `D2`, which carries the largest impact; and it is the only unit that can be completed without first resolving an unknown.

> **`NEXT CANDIDATE ≠ GO`** (`DEC-0040` D8). **`D0` does not begin `D1`**, and `D1` requires its own explicit Product-Lead GO (`DEC-0042` §D16). Naming it places it and authorizes nothing.

---

## 17. Routed, not absorbed

Named so a later unit finds each one. **Naming is not authorization.**

| # | Item | Route |
|---|---|---|
| 1 | The `sg8-r0-preflight-local-test.yml` registration with no file on `main` (§6.3) | **Platform-settings action, out of Phase-D scope.** Removing a workflow registration is a repository-configuration change |
| 2 | Any `required_status_checks` rule, reviewer threshold or `CODEOWNERS` file | **Authority interaction** — `DEC-0041` D5 and D10; escalated to the Product Lead, never taken by a `D` unit |
| 3 | The two collection workflows, `active` at registry level and disarmed **in-workflow only** — a code-level control a merge could flip, on a repository where merges need no passing check and no approval | **Axis-1 / security adjacent.** Not a Phase-D question |
| 4 | The root README presenting `packages/orchestrator` as the active control plane (§10.2 row 5) | **`DEC-0038` D1 compliance item** — a documentation repair a `D` unit may perform under `DEC-0042` §D11, or the Product-Lead-authorized reconciliation unit |
| 5 | The `DEC-0035` §7 header-classification check | Already routed and expressly **not** authorized by `DEC-0041` §10; unchanged here |
| 6 | Whether `packages/shared` should be imported or retired | A product-architecture question, not a quality question |

---

## 18. Mutation accounting

Per `DEC-0040` D13. **A clean `git status` is not a `ZERO MUTATION` proof**, so the checks supporting every line below are named.

| Surface | Finding | Class |
|---|---|---|
| **Repository files** | Exactly four created or modified, all inside the declared write scope: `DEC-0042`, this record, `current-state.md`, `context-map.md`. Checked by `git status --porcelain` and by the commit diff | `AUTHORIZED MUTATION` |
| **Branches** | One created — `docs/phase-d-d0-engineering-quality-baseline-and-charter`. Checked by `git branch --show-current` and `git for-each-ref` | `AUTHORIZED MUTATION` |
| **Commits / pushes / pull requests** | Commits on that branch only; one push; one pull request, left **unmerged** | `AUTHORIZED MUTATION` |
| **Refs, tags, worktrees, stash** | None created, deleted or moved by this unit. Checked by `git for-each-ref`, `git stash list` (one pre-existing entry, untouched) and `git worktree list` (three pre-existing entries, untouched). **Six `refs/codex/turn-diffs/checkpoints/…` refs were present at unit start and are outside this agent's control** | `HARNESS / SYSTEM PERSISTENCE OUTSIDE AGENT CONTROL` |
| **Temp, cache, sidecar, backup files** | **None created.** `PYTHONDONTWRITEBYTECODE=1` was exported as an environment variable so children inherited it, and `-B` was passed as well; the ignored-file set from `git status --porcelain --ignored=traditional` is **byte-for-byte identical before and after every execution** | `ZERO MUTATION`, on that named basis |
| **`/tmp` and system temp** | **Nothing written.** The one test module that calls `tempfile.mkstemp()` was **deliberately excluded** from execution for exactly this reason (§7.1) | `ZERO MUTATION`, on that named basis |
| **Session scratchpad** | **Not used at any point.** No scratch, notes, helper-script, pull-request-body or intermediate file was created anywhere. The pull-request body was passed inline | `ZERO MUTATION` |
| **Memory files** | **None written, of any kind**, in the repository or outside it | `ZERO MUTATION` |
| **Pre-existing ignored working-tree state** | `apps/web/.next/`, four `node_modules` trees, three `__pycache__` directories, `.agents/`, `.claude/`, `skills-lock.json` and a local-secrets directory were **all present at unit start and are unchanged** | pre-existing; not this unit's |
| **External mutable systems** | **Zero writes.** Every platform call was a read — rulesets, branch protection, workflows, runs. No workflow was created, edited, enabled, disabled or dispatched; no ruleset, Environment, secret, variable, reviewer requirement or repository setting was touched; no database, cloud or collection resource was reached; nothing was re-armed | `ZERO MUTATION`, on that named basis |

**No breach is recognized by this Author.** The only judgment call worth disclosing is the deliberate exclusion of one test module to stay inside the write boundary, which is recorded as a limit on the evidence at §7.1 rather than as a completed run.

---

*Current state is owned by [`current-state.md`](../product/current-state.md); routing by [`context-map.md`](../product/context-map.md); classification and precedence by [`DEC-0035`](../product/decisions/DEC-0035-canonical-context-v2-authority-lifecycle-supersession-model.md); the Phase-D charter is [`DEC-0042`](../product/decisions/DEC-0042-engineering-quality-phase-charter.md). Convention follows [`PHASE-C-CLOSEOUT-R1`](PHASE-C-CLOSEOUT-R1.md).*
