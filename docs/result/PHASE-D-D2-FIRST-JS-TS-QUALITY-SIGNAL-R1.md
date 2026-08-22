# PHASE D — `D2` First automatic JS/TS quality signal, and the `Q3` test-surface adjudication · R1

**Status:** COMPLETE as an Author deliverable · **Date:** 2026-08-22 · **Author:** a task-scoped Author, under the topology [`DEC-0037`](../product/decisions/DEC-0037-execution-topology-role-independence-governance-review-function.md) D5 fixes, carried into this unit by the Product Lead's own explicit `D2` R2 writ ([`DEC-0042`](../product/decisions/DEC-0042-engineering-quality-phase-charter.md) §D16) · **Independent review:** a separate, fresh, distinct Reviewer was instantiated and **returned `PASS` on all four review functions**, after which the Product Lead accepted the substantive `D2` architecture and authorized **one bounded pre-merge correction round**, whose three items are recorded at §5.1, §17.2 and §17.3. **That verdict is the Reviewer's and the acceptance is the Product Lead's; neither is this Author's to state or to restate as its own** ([`DEC-0040`](../product/decisions/DEC-0040-governed-result-disposition-closeout-contract.md) D11) · **Ratification gate:** the Product Lead's manual merge ([`DEC-0037`](../product/decisions/DEC-0037-execution-topology-role-independence-governance-review-function.md) D11)
**Authority class:** DESCRIPTIVE-CURRENT · **Lifecycle:** CURRENT · **Mutability:** FROZEN
**Type:** First-quality-signal record for a **mutating** unit, plus one adjudication. **This is not a decision record** — it creates no authority, classifies no artifact, narrows no clause, sets no threshold and authorizes no execution. `D2` operates entirely under the landed charter [`DEC-0042`](../product/decisions/DEC-0042-engineering-quality-phase-charter.md) and **creates no new normative authority of its own.**
**Canonical base:** `main` @ `618512198bdfa43b3b29c1e79a99e24424bf38bc` (the PR #95 merge landing `D1`), working tree clean at unit start.
**Method.** Every load-bearing claim below was **re-derived by this unit at the canonical base** — by live execution in CI wherever execution was possible, and by direct repository and read-only GitHub API reads otherwise. The unit writ supplied a list of already-derived facts; **every one was treated as `REPORTED` and independently re-verified.** `D0`'s and `D1`'s counts were **recounted rather than inherited**. No conversation claim and no memory content was used as proof ([`DEC-0035`](../product/decisions/DEC-0035-canonical-context-v2-authority-lifecycle-supersession-model.md) §5).
**Evidence classes** are exactly the four of [`DEC-0040`](../product/decisions/DEC-0040-governed-result-disposition-closeout-contract.md) D3 — `REPORTED` · `VERIFIED` · `ACCEPTED` · `UNPROVEN`. `HOLD` and `RED` are unit-disposition values on a different axis and are used nowhere here as evidence classes.
**Author boundary.** This record states **no unit disposition and no artifact verdict** ([`DEC-0040`](../product/decisions/DEC-0040-governed-result-disposition-closeout-contract.md) D11). Both are void coming from an Author. `AUTHOR PASS = REPORTED, NOT ACCEPTED`.

---

## 1. Classification, adjudicated rather than copied

`DEC-0035` §9's `docs/result/**` row defaults to `DESCRIPTIVE-CURRENT · CURRENT · FROZEN` **for phase closeouts**, and carries an anticipatory clause that *"should this family later carry run or gate outputs, those take class: **EVIDENCE**"*. This artifact is not a phase closeout, and it carries something the two Phase-D records before it did not: the output of a **live CI run that is itself the unit's load-bearing implementation evidence**. So the case for classifying the whole file `EVIDENCE` is considered rather than skipped.

**Adjudication: `DESCRIPTIVE-CURRENT · CURRENT · FROZEN`, with the live-run outputs at §9 and §10 carrying `EVIDENCE` at clause level.** Two reasons.

1. **The file's dominant function is a state report plus an adjudication.** What a later reader needs from it is *what automatic signal now exists on the JS/TS surface, exactly what it observes, and whether either active surface warrants a behavioural test suite today* — which is what `DEC-0035` §3.1 defines DESCRIPTIVE-CURRENT for: *"A statement of current repository or system state, safe to route from. Creates no authority."* The run is the ground for that statement, not the statement.
2. **Whole-file promotion on the strength of some clauses is the move `DEC-0035` §9.1 forbids** in the mirror direction — *"A whole file is therefore never promoted … because one of its clauses was ratified elsewhere."* The clause-level discipline `D0` and `D1` applied is applied here for the same reason, not by imitation.

`FROZEN` follows the family. The body is never rewritten, and its accuracy is bounded by the canonical base declared in the header.

---

## 2. The prior attempt — recorded accurately, and not turned into an incident report

> A prior D2 R1 attempt stopped before implementation and closed at HOLD. It produced no artifact. A reported out-of-scope write allegation could not be independently reproduced and therefore did not satisfy DEC-0040 D5's VERIFIED-breach trigger.

That is the whole of it. Three facts follow from it and are stated because a later reader needs them, not to enlarge the note.

- **`D2 R1 = HOLD`, and `D2 R1` is NOT a historical `RED`.** The Product Lead ruled on the reported action in terms: `OCCURRENCE = REPORTED`, `IF TRUE => UNAUTHORIZED MUTATION`, `VERIFIED BREACH = NO`, and therefore `DEC-0040 D5 RED TRIGGER = NOT SATISFIED`. **The report is neither erased nor promoted.** `REPORTED` is never converted directly to `ACCEPTED` (`DEC-0040` D3).
- **`R1` is historical and is not rewritten by this unit.** `R2` is a new governed attempt, not a revision of `R1`.
- **The canonical base is untouched by `R1`.** It produced no branch, no PR, no CI run and no repository artifact, which this unit re-derived: at the canonical base `origin/main` is `618512198bdfa43b3b29c1e79a99e24424bf38bc`, the local tree was clean, and no `js-ts-quality` workflow existed in the tree or in the registered-workflow list. `VERIFIED`.

**One design consequence, stated because it is the reason this unit ran differently.** The `R1` writ authorized a local validation worktree and prescribed `git worktree remove` as its cleanup — a command that cannot complete on this host, as `D1` recorded twice on `main`. **The Product Lead removed that entire design from the `R2` writ.** `D2 R2` therefore created **no local validation surface at all**: no worktree, no store, no install, no build. Its implementation evidence is the live CI run at §10. That is not a shortcut; it is the authorized design.

---

## 3. The `D1` precondition, and how this unit verified it

`D0` §16's `D2` entry declares `D1` the prerequisite, and `D1` §16 handed forward four facts *"as established fact, never as authorization"*. This unit re-verified the three that gate its own work, and did so **on Linux and on Node 20**, which is where `D1` could not.

| `D1` fact handed forward | How `D2` re-verified it | Result | Class |
|---|---|---|---|
| a reproducible install exists that exits 0 from a clean checkout | `pnpm install --frozen-lockfile --ignore-scripts` in the live CI job, from a fresh `actions/checkout` | exit 0; pnpm reported *"Lockfile is up to date, resolution step is skipped"* and `Done in 3.6s` | `VERIFIED` |
| the active workspace is exactly three projects, matching the lockfile importers | pnpm's own line in the install output; independently, the `importers:` keys of `pnpm-lock.yaml` re-read at the base | pnpm printed `Scope: all 3 workspace projects`; the lockfile declares importers `.`, `apps/web`, `packages/shared` — **three, and the same three** | `VERIFIED` |
| both active typechecks pass at this base | the two CI steps at §9 | both exit 0 | `VERIFIED` |
| the lockfile stays byte-identical across a frozen install | **not separately asserted, and deliberately so** — see §7 | — | see §7 |

**Two of `D1`'s named `UNPROVEN` inputs are closed by this run, and one is not.**

- **Node 20 specifically** — `D1` §15 recorded *"Whether the frozen install succeeds on Node 20 specifically"* as `UNPROVEN`, because only Node v24.15.0 was available to it. **CI selected Node v20.20.2 from `.nvmrc` and the frozen install and both typechecks passed on it.** `VERIFIED`.
- **Linux** — `D1` §15 recorded *"Whether the resolved closure is identical on Linux"* as `UNKNOWN`, since only Windows was exercised. **The frozen install succeeds on Linux** — `VERIFIED`. **Closure *identity* between the two platforms is a different and stronger claim and is NOT established here:** no cross-platform closure comparison was performed. `UNPROVEN`, narrowed but not closed.
- **A scripts-enabled install** — `D1` §15 recorded it `UNPROVEN`; CI uses `--ignore-scripts` by writ, so it remains `UNPROVEN — NOT PROBED`. Routed at §14.

---

## 4. Active surfaces, and their standings

Standings are `DEC-0042` §D4's four. Re-derived at this base by tracked-file enumeration and an importer search; nothing rests on a manifest's self-description.

| Surface | Standing | Re-derived evidence | Class |
|---|---|---|---|
| `apps/web/**` | **ACTIVE PRODUCT** | 13 tracked files. Three source files: a page component, a root layout, one stylesheet — 25, 19 and 79 lines. The sole target of all four root scripts | `VERIFIED` |
| `packages/shared/**` | **ACTIVE-BUT-UNREACHED** | 4 tracked files, one of them a 9-line source module. `git grep '@noxund/shared'` over the whole tree returns, outside documentation and this unit's own new workflow, exactly one hit — its own manifest `name` field. An import-form search returns **zero source importers** | `VERIFIED` |
| root JS/TS toolchain (`package.json`, `.nvmrc`, `pnpm-workspace.yaml`, `pnpm-lock.yaml`, `tsconfig.base.json`) | **ACTIVE TOOLING** | these five files decide what the two packages above install and compile against; all five are in this workflow's path filter | `VERIFIED` |
| `packages/orchestrator/**` | **LEGACY / NON-AUTHORITATIVE** | disposition is `DEC-0038` D1. **`DEC-0042` §D11: no quality investment.** Re-confirmed untouched by this unit: the tree object is `7457f3f259ce8987e74ebe9f3db48172eabbd02b` at both the canonical base and this unit's head — **byte-identical** | `VERIFIED` |

**The legacy exclusion, stated as a positive design choice rather than an omission.** `packages/orchestrator` is TypeScript, and a path filter written by reflex would have included it. It is deliberately absent from both trigger lists, is not an active workspace member, is not installed, and is not typechecked. **EXCLUDED IS NOT REMOVED** (`DEC-0038` D3) — nothing here deletes, moves, empties or edits it, and its exclusion from a CI filter disposes of nothing.

---

## 5. Signal selection — what was included, and on what ground

The writ fixed the minimum expected signal and this unit implemented exactly it, in this order.

1. exact Node selection from the landed `.nvmrc`;
2. exact pnpm from the repository pin;
3. `pnpm install --frozen-lockfile --ignore-scripts`;
4. `pnpm --filter web --fail-if-no-match typecheck`;
5. `pnpm --filter @noxund/shared --fail-if-no-match typecheck`.

**The two typechecks are invoked as package scripts, directly, and NOT through root `typecheck`.** Root `typecheck` is `pnpm --filter web typecheck` — it routes to `web` only, so calling it would have left `@noxund/shared` silently unobserved while appearing to be a whole-repository command. **Root scripts were not modified.** `D3` owns entrypoint parity; this unit neither pre-empts nor prejudges it.

**Each filtered invocation carries `--fail-if-no-match`, and the first candidate did not.** Stated plainly rather than presented as if the property were there from the start: **the initial candidate lacked explicit zero-match failure; it was corrected before landing**, on a Product-Lead direction after independent review. The defect it removes is specific. This is a **detective control over two packages named literally in the command**, so a rename, a removal or a workspace-membership error would have made `pnpm --filter web …` match **zero projects, do nothing, and exit 0** — leaving a green check that observes nothing. That is exactly the false-confidence failure `DEC-0042` §D10 exists to prevent, and it is the same hazard `DEC-0041` §6 refused a control over: *"a control whose green is more misleading than its absence is a net negative"*.

**pnpm provides this natively, so nothing was hand-rolled.** `--fail-if-no-match` is pnpm's own filtering option and **no custom shell wrapper, package-count parser or project-list comparison was added** — a parser would have been a second, unverified implementation of a guarantee the package manager already makes.

---

### 5.1 How this unit established that pnpm 9.0.0 genuinely accepts the option

A flag the tool silently ignored would produce a green run offering **zero** protection, which is worse than not adding it. The acceptance question was therefore treated as something to establish, not assume, and it was established **only from the live run** — no local execution of pnpm was performed or authorized.

| Step of the argument | Observation | Class |
|---|---|---|
| pnpm rejects rather than ignores an option it does not know: an unrecognized CLI option is a hard error and a non-zero exit | the step runs under `set -euo pipefail`, so a non-zero pnpm exit fails the step and reddens the job | `ACCEPTED` — a documented property of the tool, relied on rather than re-proved |
| the flag was actually present on the executed command line | the runner echoes the command verbatim: `pnpm --filter web --fail-if-no-match typecheck` and `pnpm --filter @noxund/shared --fail-if-no-match typecheck` | `VERIFIED` |
| pnpm did not report an unknown, unrecognized, ignored or deprecated option | a search of the whole run log for `Unknown option`, `ERR_PNPM`, `unrecognized`, `ignored` and any pnpm `WARN` line returns **nothing** | `VERIFIED` |
| the command did not merely parse — it ran the real work | pnpm printed `> web@0.0.0 typecheck …` then `> tsc --noEmit`, and the same pair for `@noxund/shared`. **The filter matched, the script resolved, and `tsc` genuinely executed** in both cases | `VERIFIED` |
| both invocations exited 0 | steps 7 and 8 both concluded `success` | `VERIFIED` |

> **Conclusion, at the strength the evidence actually supports: `pnpm 9.0.0 ACCEPTS --fail-if-no-match IN THIS ORDERING` — `VERIFIED`.** The Product Lead's stated form was used unchanged; no ordering variant was needed and none was tried.

**What is NOT established here, stated rather than glossed.** That a zero-match filter *does* fail was **not exercised in this repository**, because demonstrating it would have required a deliberately-failing probe commit, which is forbidden. So the fail-closed *behaviour* rests on pnpm's documented contract plus the verified fact that the option is accepted and honoured on the command line — **`ACCEPTED`, not `VERIFIED`**. **This record does not claim to have observed a zero-match failure, and no one should read it as claiming that.**

**Root `pnpm typecheck` is NOT complete coverage and this record does not call it that.** Stated explicitly per `DEC-0042` §D10.

**What this signal is, in domain terms.** It is a `Q4` (CI coverage) and `Q2` (type and static correctness) signal for two packages. **It is not a `Q1` signal** — no build runs — **and it is not a `Q3` signal**: no test exists to run. `DEC-0042` D7 is applied literally here — `TESTS EXIST` ≠ `TESTS COVER CURRENT ACTIVE BEHAVIOR` ≠ `TESTS RUN IN CI`, and **this workflow asserts none of the three.**

**Deliberately excluded, each with its ground.**

| Excluded | Ground | Where it goes |
|---|---|---|
| `next build` | see §6 | routed to a later Phase-D decision |
| lint / ESLint | static analysis for the non-typecheck surfaces is `D0` §16's `D4`; adopting a linter run here would pre-empt an adjudication `D4` owns | `D4` |
| any test framework, any test file | **no test dependency is authorized**, and §12 and §13 conclude none is warranted on the current surface anyway | §14 |
| any cache — `actions/cache`, a pnpm store cache, `.next`, and `cache:` on `actions/setup-node` | the writ fixes `No cache in D2 R2 … Correctness first`. A cache on the first run a surface has ever had would make a green result partly a property of the cache | a later unit, if a measured need appears |
| `workflow_dispatch` | no demonstrated requirement; the two triggers already cover every input the job reads, and manual dispatch is forbidden to this unit in any case | — |
| a post-install `git diff` assertion on `pnpm-lock.yaml` | **`--frozen-lockfile` already refuses to write the lockfile at all**, so such a check could never fail. `DEC-0041` D2 — *"FEWER REAL CONTROLS > MORE CONTROLS THAT DO NOT OBSERVE THE WORK"* — makes a control that cannot fail a net negative, not a free extra | not adopted |

---

## 6. `S4` — the `apps/web` build is DEFERRED, and the deferral is not a quality waiver

**Disposition: `S4 WEB BUILD = DEFER`.** The Product-Lead writ set `DEFER BY DEFAULT` and permitted adoption only where *"canonical landed evidence already independently demonstrates it is deterministic, side-effect acceptable and clearly within D2 rather than D4."*

**No canonical landed evidence meets that bar, and this unit checked rather than assumed.** `D0` §12 item 2 records whether `next build` passes as *"`UNPROVEN — NOT PROBED`"*; `D1` §15 records `next build` as `UNPROVEN — NOT PROBED` a second time and notes it was forbidden to that unit. **Two landed records, both negative. The precondition fails on the record itself.** `VERIFIED` as a statement about the record; the build's behaviour remains `UNPROVEN`.

**A second, independent ground, from read-only inspection only.** `apps/web` declares `next` at `^15.1.6`, and at Next 15.x `next build` also performs lint and type checking as part of the build. That entangles build integrity (`Q1`) with static analysis that `D0` §16 assigns to **`D4`** — so adding it here would have imported a `D4` question into a `D2` workflow under a `Q1` label, which `DEC-0042` §D10 treats as a naming defect rather than a bonus. **This is an inspection-derived observation about a documented framework behaviour. This unit did NOT execute `next build`, on this host or in CI, and asserts nothing about what such a run would do.** `UNPROVEN — NOT PROBED`.

> **Absence from `D2` is not a quality waiver.** `Q1` for `apps/web` is **unobserved by any automatic signal today**, exactly as it was before this unit, and that is a real gap this record leaves open rather than closes. It is routed at §14, not absorbed.

---

## 7. The workflow

**Path:** `.github/workflows/js-ts-quality.yml` — **new; it did not exist at the canonical base**, and no registered workflow collided with it. Re-derived: the registered-workflow listing returned 13 workflows before this unit and 14 after, the new entry being id `340140169`, state `active`. `VERIFIED`.

**One narrow workflow, one job, eight steps.** It was not split for presentation.

### 7.1 Triggers, and the self-trigger requirement

Both `pull_request` and `push` to `main`, carrying the identical path filter:

```
.nvmrc
package.json
pnpm-lock.yaml
pnpm-workspace.yaml
tsconfig.base.json
apps/web/**
packages/shared/**
.github/workflows/js-ts-quality.yml
```

**The workflow's own file is in its own filter, deliberately.** A CI workflow that can change without evaluating itself is not an adequate signal. `D0` §6 recorded the mirror defect on the one workflow that already watched governance surfaces — it declares no `push:` trigger — and named it a real observability gap. **That gap is not repeated here:** this workflow observes both events, and a change to it alone fires it.

**`packages/orchestrator/**` is absent from both filters** even though it is TypeScript. See §4.

### 7.2 Permissions and blast radius

`permissions: contents: read`, declared at the top level, which is the whole of the token grant. **Zero secrets, zero Environment binding, zero write-token capability, zero deploy, zero database, zero cloud, zero collection operation.** `--ignore-scripts` means **no package lifecycle script executes**. The workflow **re-arms nothing** (`DEC-0033` §8) and dispatches nothing. `VERIFIED` by reading the landed file and by the run's own step list.

### 7.3 Actions — full-SHA pinned, resolved against the API

| `uses:` | Pinned commit | Tag | How the mapping was established |
|---|---|---|---|
| `actions/checkout` | `34e114876b0b11c390a56381ad16ebd13914f8d5` | `v4.3.1` | `gh api repos/actions/checkout/git/ref/tags/v4.3.1` returned that object with `type` `commit` — a lightweight tag, so the object **is** the commit; the commit was then fetched and confirmed to exist |
| `actions/setup-node` | `48b55a011bda9f5d6aeb4c2d9c7362e8dae4041e` | `v6.4.0` | `gh api repos/actions/setup-node/git/ref/tags/v6.4.0`, same method; commit confirmed, message *"Update Node.js versions in versions.yml and bump package to v6.4.0"* |

`VERIFIED`. **Neither pin relies on tag mutability** — the tag was dereferenced once to obtain a commit SHA, and the SHA is what the workflow carries. The `# vN.N.N` comment is a human label, never the resolution mechanism.

**Two choices are stated rather than left implicit.**

- **`actions/checkout` reuses the exact SHA already pinned on `main`** by `governance-checks.yml`. That adds **zero new distinct third-party action commits** to the repository beyond `setup-node`, which is the smallest dependency set actually available. See the deprecation finding at §14 item 2, which this choice inherits and which is disclosed rather than quietly avoided.
- **`actions/setup-node` is pinned to `v6.4.0` rather than to the newest release.** `v7.0.0` and `v6.5.0` were both published five weeks before this base; `v6.4.0` had been in the field four months. The one breaking change in the `v6` line — *"Limit automatic caching to npm"* — is inert here because this workflow sets no cache. A five-week-old major was not chosen for a repository's first-ever signal on this surface.

### 7.4 Concurrency and timeout

`concurrency.group: js-ts-quality-${{ github.ref }}` with `cancel-in-progress: true`, matching the shape the house workflow already uses. `timeout-minutes: 15` is set on the job, against a platform default of six hours; the observed run took **17 seconds**, so the bound is generous by two orders of magnitude and exists only to stop a hung install.

### 7.5 Naming honesty

`DEC-0042` §D10: *"A gate must not claim a surface it does not validate. A name broader than its mechanism is a defect, not a convenience."* Applied to every name this unit wrote:

| Name | Why it is true of the mechanism |
|---|---|
| workflow: `JS/TS Quality · frozen install + typecheck (apps/web, packages/shared)` | names the two packages explicitly, and names the two things it does. It does **not** say *TypeScript*, *quality gate*, *CI*, or anything implying whole-repository coverage |
| job: `Frozen install, then typecheck apps/web and packages/shared (no build, no lint, no tests)` | states the three exclusions in the name itself, where a reader scanning a PR check list will see them |
| steps: `… tsc --noEmit, fail-closed if the filter matches no project`, `… frozen lockfile, no lifecycle scripts` | each step names both what it does and the limit on it |

The file also carries a leading `BINDING STATUS` comment block stating what the check covers and, at greater length, what it does not — following the convention the house governance workflow established.

---

## 8. Node and pnpm — the contract, and the versions actually observed

**Node.** Selected by `actions/setup-node` with `node-version-file: '.nvmrc'`. `.nvmrc` contains `20` and is the repository's only Node selector. The assertion step **derives the expected major from `.nvmrc` at run time** rather than hardcoding a literal, so the assertion follows the pin instead of drifting from it, and it **fails closed** if `.nvmrc` ever holds a non-numeric value it cannot understand.

**pnpm.** Corepack, plus the repository's own `packageManager` pin. `corepack enable` installs the shims; the shim then reads `packageManager` from the nearest `package.json` and runs **exactly** that version, fetching it if absent. **Nothing upgrades pnpm, nothing names a version to install, and no `corepack prepare`, `corepack use` or global install is performed** — the repository pin is the only input. The assertion step **derives the expected version from that pin** and requires `pnpm --version` to equal it exactly, **failing closed** both when the field is not a pnpm pin at all and when the resolved binary disagrees with it.

> **This is a deliberate deviation from the literal wording of the writ, and it is disclosed rather than buried.** The writ says *"`pnpm --version` must resolve to `9.0.0`"*. A hardcoded `9.0.0` literal in the workflow would satisfy that sentence too. The derived form was chosen because it also catches Corepack silently ignoring the pin, and because a second hardcoded copy of a version that already lives in `package.json` is a maintenance trap of exactly the kind `D1` was convened to remove. **The writ's requirement is met on the outcome:** the live run observed `pnpm --version` as **`9.0.0`**. **The Reviewer and the Product Lead may reasonably prefer the literal form; this Author does not treat its own reasoning as settling that.**

**Versions actually observed in the live CI log**, ANSI escapes and per-line timestamps stripped, otherwise verbatim:

```
corepack --version = 0.34.6
.nvmrc pin      = 20
node --version  = v20.20.2
OK - Node v20.20.2 satisfies the .nvmrc pin 20.
packageManager  = pnpm@9.0.0
pnpm --version  = 9.0.0
OK - pnpm 9.0.0 is exactly the repository pin.
```

`VERIFIED` — **Node `v20.20.2`, pnpm `9.0.0`, Corepack `0.34.6`.** No runtime incompatibility arose, so the writ's pnpm `HOLD` branch was never approached. **`.nvmrc` pins a major only, not a patch**, so `v20.20.2` is what the pin resolved to on this runner on this date and is **not itself a pinned value**; a later run may legitimately observe a different 20.x patch.

---

## 9. The exact commands CI ran

Quoted from the landed workflow, in order.

```
corepack enable
pnpm install --frozen-lockfile --ignore-scripts
pnpm --filter web --fail-if-no-match typecheck             # > tsc --noEmit
pnpm --filter @noxund/shared --fail-if-no-match typecheck  # > tsc --noEmit
```

Install output, ANSI and timestamps stripped, otherwise verbatim:

```
Scope: all 3 workspace projects
Lockfile is up to date, resolution step is skipped
Progress: resolved 1, reused 0, downloaded 0, added 0
Packages: +327
Progress: resolved 327, reused 0, downloaded 327, added 327, done
Done in 3.6s
```

Typecheck output, same treatment:

```
> web@0.0.0 typecheck /home/runner/work/noxund/noxund/apps/web
> tsc --noEmit

> @noxund/shared@0.0.0 typecheck /home/runner/work/noxund/noxund/packages/shared
> tsc --noEmit
```

**Zero type errors on either package; both steps concluded `success`.** `EVIDENCE`.

**One thing this does NOT establish, stated because a green `tsc` here says more than it did in `D1` and it should not be over-read in the other direction either.** `D1` R3 repaired `apps/web/tsconfig.json` to extend `tsconfig.base.json`, so this run checks `apps/web` against the **inherited strict settings**, not against the weak local configuration `D1` R1 warned about. **But `D1` §19.6 also recorded that the inherited strictness is `unexercised by the four files in the program`** — the source is small enough that a strict option can be live and still never bind. A green result here is therefore evidence that the code typechecks, **not** evidence that the strict configuration is doing work.

---

## 10. Live run evidence

The workflow YAML is not itself sufficient evidence. Every item the writ required was checked against the platform.

| Required check | Observation | Class |
|---|---|---|
| GitHub recognizes the workflow | registered, id `340140169`, path `.github/workflows/js-ts-quality.yml`, state `active`; registry count moved from 13 to 14 | `VERIFIED` |
| the intended job actually starts | job id `97064205573`, name `Frozen install, then typecheck apps/web and packages/shared (no build, no lint, no tests)` | `VERIFIED` |
| Node is correct | `v20.20.2`, asserted fail-closed against the `.nvmrc` pin | `VERIFIED` |
| pnpm is exactly `9.0.0` | `9.0.0`, asserted fail-closed against the `packageManager` pin | `VERIFIED` |
| frozen install executes | *"Lockfile is up to date, resolution step is skipped"*, 327 packages, `Done in 3.6s` | `VERIFIED` |
| web typecheck executes | step 7, `success` | `VERIFIED` |
| shared typecheck executes | step 8, `success` | `VERIFIED` |
| terminal job result obtained | run `status` `completed`, `conclusion` `success` | `VERIFIED` |

**Run identity.**

| Field | Value |
|---|---|
| run id | `32586763336` |
| URL | https://github.com/AdeptLabsDev/noxund/actions/runs/32586763336 |
| event | `pull_request` |
| head SHA evaluated | `5da1a3645d0230c549b38bc41538e55283120953` |
| duration | 17 s |
| conclusion | `success` |

**All eight executable steps concluded `success`, with none skipped.** The run was caused by the `pull_request` trigger firing on PR #96; **it was not manually dispatched, and this unit ran no `gh workflow run` and no `workflow_dispatch` of any kind.** Retrieval used read-only operations only.

### 10.1 A second run, and a prediction of this Author's that observation falsified

**A first draft of this section asserted that the documentation commit which follows the workflow commit on this branch "changes no path in the workflow's filter, so the workflow correctly does not re-fire for it". That was wrong, it was written as a prediction rather than an observation, and it is corrected here rather than quietly deleted.**

**What actually happens.** For a `pull_request` event, GitHub evaluates a path filter against **the whole set of files the pull request changes**, not against the newest commit alone. The pull request as a whole still changes `.github/workflows/js-ts-quality.yml`, so the `synchronize` event fired the workflow again on the documentation head.

| Field | Run 1 | Run 2 |
|---|---|---|
| run id | `32586763336` | `32587386670` |
| head SHA | `5da1a3645d0230c549b38bc41538e55283120953` | `c3e2374c40636275f93c1ca2e730c032a567a12c` |
| trigger | PR opened | PR synchronized |
| conclusion | `success` | `success` |

**Two consequences, both in the honest direction.** The signal is evidenced on **both** heads of this branch rather than only on the first, so the caveat that draft was trying to state does not arise. And **a claim this Author reasoned to rather than measured turned out to be false** — recorded because §10's whole purpose is that the workflow YAML is not self-evidencing, and an Author's expectation of platform behaviour is not either. `VERIFIED` by two runs; the earlier sentence is withdrawn.

**The `governance-checks.yml` reference-durability workflow also fired on the documentation head, as its own path filter requires, and concluded `success`** — run `32587386665`, both of its jobs green. That is an authorized automatic effect of a documentation change, not an effect of this unit's workflow.

### 10.2 The correction round — live CI on the hardened workflow

**The workflow changed, so hash-only review would not have been sufficient and the corrected file was re-executed rather than re-read.** The `--fail-if-no-match` commit fired the workflow **through the workflow's own self-trigger**, which is itself part of the evidence: the only path in this commit is `.github/workflows/js-ts-quality.yml`, and the job ran anyway because the workflow watches its own file.

| Field | Value |
|---|---|
| run id | `32589235883` |
| URL | https://github.com/AdeptLabsDev/noxund/actions/runs/32589235883 |
| event | `pull_request` — **automatic; no manual dispatch, and no `gh workflow run` was issued at any point in this unit** |
| head SHA | `ea899760dbebd52b3ec7231eb4321f1df4756ea5` |
| duration | 16 s |
| conclusion | `success`, with **all eight executable steps `success` and none skipped** |

**Every item the Product Lead required from the new terminal run, checked individually.**

| Required | Observed | Class |
|---|---|---|
| workflow triggered automatically | `pull_request`, via the workflow's own path filter matching its own file | `VERIFIED` |
| no manual dispatch | the workflow declares no `workflow_dispatch`, and none was issued | `VERIFIED` |
| Node remains the landed `.nvmrc` selector | `.nvmrc pin = 20`, `node --version = v20.20.2`, assertion green | `VERIFIED` |
| pnpm remains `9.0.0` | `packageManager = pnpm@9.0.0`, `pnpm --version = 9.0.0`, assertion green | `VERIFIED` |
| frozen install succeeds | `Scope: all 3 workspace projects`, *"Lockfile is up to date, resolution step is skipped"*, `Done in 3.8s` | `VERIFIED` |
| the `web` filter matched and `tsc` genuinely executed | `> web@0.0.0 typecheck …` followed by `> tsc --noEmit` | `VERIFIED` |
| the `@noxund/shared` filter matched and `tsc` genuinely executed | `> @noxund/shared@0.0.0 typecheck …` followed by `> tsc --noEmit` | `VERIFIED` |
| both fail-if-no-match commands exit 0 | steps 7 and 8 both `success` | `VERIFIED` |

**No failed iteration occurred, and that is reported as a fact rather than as a claim of foresight.** The Product Lead's stated ordering worked on the first attempt, so **no ordering variant was tried, no `--filter=web` form was needed, and no red run was produced by this round.** Had one been produced it would be listed here.

**Versions observed in the correction run, ANSI escapes and per-line timestamps stripped, otherwise verbatim:**

```
corepack --version = 0.34.6
.nvmrc pin      = 20
node --version  = v20.20.2
OK - Node v20.20.2 satisfies the .nvmrc pin 20.
packageManager  = pnpm@9.0.0
pnpm --version  = 9.0.0
OK - pnpm 9.0.0 is exactly the repository pin.
```

**The `packageManager`-derived pnpm assertion is unchanged and the correction run did not disprove it**, so it stands as `D2` landed it: read the root pin, validate it is a pnpm pin, resolve through Corepack, require exact equality. **No second `9.0.0` literal was added.**

**`governance-checks.yml` also fired on this head and concluded `success`** — run `32589235958`. Authorized automatic effect of the pull request, not of this workflow.

---

## 11. Binding strength — re-derived read-only

> **`AUTOMATIC DETECTIVE · NOT MECHANICALLY MERGE-BLOCKING`** (`DEC-0041` D1's vocabulary; `DEC-0042` §D8).

Re-derived at this base with GET requests only, and **nothing was modified**.

| Read | Result | Class |
|---|---|---|
| the repository's rulesets | three active: `Protect main` (id `19697151`), `Preserve authority evidence` (id `20890207`), `Preserve recovery checkpoints` (id `20727975`) | `VERIFIED` |
| `Protect main` rule types | exactly three — `deletion`, `non_fast_forward`, `pull_request`. **No `required_status_checks` rule of any kind** | `VERIFIED` |
| `Protect main` bypass scoping | one actor, `actor_type` `User`, `bypass_mode` `pull_request`; conditions include `refs/heads/main` and exclude nothing | `VERIFIED` |
| the legacy branch-protection endpoint | HTTP 404, *"Branch not protected"* — `main` is governed by rulesets, not by legacy protection | `VERIFIED` |

**Therefore, stated in the only direction the evidence supports.** No CI check on this repository can prevent a merge today, and **this one is no exception**. It produces a deterministic, automatic signal on the pull request and nothing more. **This record does not describe it as preventive, does not call it a required check, and does not claim it gates `main`** — and any later document that does is wrong unless a separately authorized unit has first added a `required_status_checks` rule, which this unit neither performs nor recommends.

**Nothing in this class was touched.** No ruleset, branch protection, required status check, `CODEOWNERS` file or reviewer threshold was created, modified or deleted — see §17.

---

## 12. `Q3` for `apps/web` — the ten questions, answered individually

**Method.** The **current** source was inspected at the canonical base; `D0`'s counts were **recounted, not inherited**. The whole of `apps/web` is 13 tracked files, of which three are source: `page.tsx` (25 lines), `layout.tsx` (19 lines) and `globals.css` (79 lines). The rest are configuration, a generated ambient-types declaration, a README and three `.gitkeep` placeholders. A single search over `apps/web/src` covering client directives, every React state and effect hook, DOM event handlers, `if`, `?`, `&&`, `||`, `for`, `while`, `switch`, `try`/`catch`, `.map`/`.filter`/`.reduce`, `fetch`, `async`/`await`, `process.env`, `JSON.parse`, `new Date` and `Math.` returned **zero matches, for every one of those patterns.** A second search for `use server`, `generateMetadata`, `generateStaticParams`, `revalidate` and route segment config returned zero. A file-name search for route handlers, middleware, `error`, `not-found`, `loading`, `template`, an `api/` directory, or any existing test file returned nothing.

| # | Question | Answer | Evidence | Class |
|---|---|---|---|---|
| 1 | Does it branch? | **No** | zero conditional operators of any form in the whole of `apps/web/src` | `VERIFIED` |
| 2 | Does it manage state? | **No** | no `use client` directive anywhere, and zero occurrences of every React state or effect hook. Both components are server components rendering statically | `VERIFIED` |
| 3 | Is there user interaction? | **No** | zero DOM event handlers, zero form elements, zero inputs, zero `addEventListener` | `VERIFIED` |
| 4 | Does it parse or validate input? | **No** | there is no input. Zero `JSON.parse`, zero schema, zero validator, zero `process.env` read | `VERIFIED` |
| 5 | Does it fetch data? | **No** | zero `fetch`, zero `async`/`await`, zero route handlers, zero server actions, zero API directory. `next.config.ts` is seven lines and sets `reactStrictMode` only | `VERIFIED` |
| 6 | Does it transform data? | **No** | every value rendered is a string literal in the JSX. Zero `.map`/`.filter`/`.reduce` | `VERIFIED` |
| 7 | Are there domain calculations? | **No** | zero arithmetic, zero `Math.`, zero date handling. The four displayed values are literals | `VERIFIED` |
| 8 | Is there error behaviour? | **No** | zero `try`/`catch`, no `error` or `not-found` segment file, no error boundary | `VERIFIED` |
| 9 | Is there stable behaviour a typecheck or a build would not already cover? | **No** | the only assertable propositions are the literal text of the markup and the Tailwind class strings. Neither is behaviour; the first is copy, the second is styling | `VERIFIED` |
| 10 | Would a test now exercise NOXUND behaviour, or mostly Next/React and static markup? | **Mostly Next/React and static markup** | a render test would assert that React renders an `h1` containing `NOXUND` and that Next composes a layout around a page — assertions about the framework and about copy, not about anything NOXUND decides | `VERIFIED` as a characterization of the current source |

> ### `apps/web`: **BEHAVIORAL TEST SUITE NOT JUSTIFIED ON CURRENT SURFACE**

**The factual conditions this rests on**, stated so the decision can be checked and so its expiry is visible:

1. `apps/web/src` contains exactly two TypeScript modules, 44 lines between them, plus one stylesheet.
2. Neither module branches, holds state, handles an event, reads an input, fetches, transforms, calculates or catches.
3. There is no route handler, no server action, no middleware and no API surface.
4. Every rendered value is a literal in the component that renders it.
5. Both modules already typecheck clean against the inherited strict configuration, in CI, on every change to the surface — as of this unit.

**Against the `DEC-0042` criteria the writ names, the decisive one is the last:** a suite is justified where a surface *can regress while the typecheck stays green*. On this source there is no such regression available. A test written today would assert literal static markup, framework composition, or both — which the writ names as the fake-test failure mode, and which `DEC-0041` D2's *"FEWER REAL CONTROLS > MORE CONTROLS THAT DO NOT OBSERVE THE WORK"* independently rejects: a green suite over static markup manufactures confidence in a surface it is not observing.

> **A future substantive change that invalidates those facts reopens the engineering question; this record is not permanent authority that the surface never needs tests.** The first route handler, the first piece of client state, the first fetch, the first parse of external data, the first calculation — **any one of them ends this answer**, and the reopening is an engineering fact rather than a governance event. **This decision is temporal, not permanent**, and **it is not a testing policy**: it is an adjudication of one surface as it stands at one base, and it authorizes nothing about any other surface in this repository.

---

## 13. `Q3` for `packages/shared` — the five questions, answered individually

**Method.** Same discipline. The package is 4 tracked files: a manifest, a `tsconfig.json`, a README and `src/index.ts` at 9 lines, of which 4 are a comment block and 4 are exports.

| # | Question | Answer | Evidence | Class |
|---|---|---|---|---|
| 1 | Is it still constants and types only? | **Constants only — and not even types** | four `export const` string literals. **Zero exported types, zero interfaces, zero enums.** The README states an intent to hold shared types and validation schemas; **none exists yet**, and the README's aspiration is not evidence of content | `VERIFIED` |
| 2 | Does it contain behaviour? | **No** | zero functions, zero arrow expressions, zero classes, zero conditionals. **A grep for `function`, `=>`, `interface`, `type`, `class` and `enum` returns exactly one line, and it is a false positive** — the word *type* inside the string literal `"chicago drill type beat"`. Recorded rather than reported as a hit | `VERIFIED` |
| 3 | Does any active package import it? | **No** | an import-form search over the whole tree returns **zero source importers**. Outside documentation and this unit's own workflow file, the only occurrence of `@noxund/shared` anywhere is its own manifest `name` field | `VERIFIED` |
| 4 | Is there a stable contract that can regress independently of typechecking? | **No** | the four constants are consumed by nothing, so no contract with a consumer exists to regress. Changing a value would break no caller, because there is no caller | `VERIFIED` |
| 5 | Would a unit test do more than repeat the exported literals? | **No** | the only available assertion is that `NOXUND_KEYWORD` equals `"chicago drill type beat"` — the literal restated in a second file, which then has to be edited in lockstep with the first | `VERIFIED` |

> ### `packages/shared`: **BEHAVIORAL TEST SUITE NOT JUSTIFIED ON CURRENT SURFACE**

**The factual conditions this rests on:**

1. The package's entire source is four exported string constants.
2. It exports no function, no type and no schema.
3. Nothing in the repository imports it.
4. Its standing is **ACTIVE-BUT-UNREACHED**, whose `DEC-0042` §D4 treatment is *"make it coherent; do not build machinery around it"* — and a test suite over four constants is machinery.

**Stated so it is not misread: zero importers does NOT make this package legacy.** It is `ACTIVE-BUT-UNREACHED`, it is a declared and maintained workspace member, it is installed on every CI run, and its typecheck now runs automatically on every change to it — which is the coherence its standing calls for. **Zero behaviour, not zero importers, is what makes a suite unjustified today**; a package with four importers and four constants would get the same answer.

> **A future substantive change that invalidates those facts reopens the engineering question; this record is not permanent authority that the surface never needs tests.** The first validation schema, the first exported function, the first non-trivial type guard — **any one of them ends this answer**, and the README already says such things are intended to live here. **This decision is temporal, not permanent.**

**Also not decided here, deliberately.** Whether `packages/shared` should be imported or retired is a product-architecture question `D0` §17 and `D1` §15 both routed and neither answered. **`D2` does not answer it either**, and adjudicating `Q3` on the current surface is not a vote on it in either direction.

---

## 14. Test-framework standing, and remaining unknowns

### 14.1 Test-framework standing

> **`NO TEST FRAMEWORK IS ADOPTED, INSTALLED, CONFIGURED OR PROPOSED BY THIS UNIT.`**

No Vitest, no Jest, no Playwright, no Cypress, no Testing Library, no other test runtime. **Zero test dependencies were added to any manifest, and the lockfile was not touched.** Re-derived at the base and again at this unit's head: a case-insensitive search across `apps/web`, `packages/shared`, root `package.json` and `pnpm-workspace.yaml` for every one of those names, plus `mocha`, `ava` and `node:test`, returns **nothing**. `VERIFIED`.

**The framework `HOLD` branch was real and did not fire.** Had either adjudication concluded that behavioural tests are justified and require a new dependency, the required return was `HOLD — TEST SURFACE JUSTIFIED; FRAMEWORK ADOPTION REQUIRES PRODUCT-LEAD SCOPE EXTENSION` with nothing installed. **Both adjudications returned `NOT JUSTIFIED ON CURRENT SURFACE`, so the branch was not reached** — recorded so a reader can see the branch existed, rather than assuming the outcome was the only one available.

### 14.2 Remaining unknowns and routed items

`UNPROVEN` / `UNKNOWN` rather than assumed in either direction, and **routed rather than absorbed. Naming is not authorization.**

1. **Whether `next build` passes, and whether it is deterministic and side-effect acceptable** — `UNPROVEN — NOT PROBED`, for the third consecutive Phase-D unit. **`Q1` for `apps/web` remains observed by nothing.** → the Product Lead, to route to a later Phase-D unit; §6 states why `D2` was the wrong venue on the current evidence.
2. **The `actions/checkout` pin this workflow inherits is deprecated at the Actions-runtime level.** The live run emitted, verbatim: *"Node.js 20 is deprecated. The following actions target Node.js 20 but are being forced to run on Node.js 24: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5."* **`VERIFIED` — observed in this unit's own run.** Three things about it are stated precisely. **(i)** It is a warning, not a failure; the platform already runs the action on the newer runtime, so there is no behavioural difference today. **(ii)** It concerns the **action's own JavaScript runtime** and has nothing to do with the `.nvmrc` Node 20 this workflow selects for the project — **two different Node 20s, and conflating them would be a real error.** **(iii)** `governance-checks.yml` carries the identical pin and is therefore affected identically, but **that file is outside this unit's write scope and was not edited.** → **routed to the Product Lead: a repository-wide action-pin refresh is its own bounded unit.** Deliberately not repaired here, because pinning this workflow alone to a newer major would put two `actions/checkout` majors on `main` without an adjudication — the class of incoherence `D1` existed to remove.
3. **Whether a scripts-enabled install succeeds** — `UNPROVEN`; every install in this unit used `--ignore-scripts` by writ. The `HOLD — LIFECYCLE-SCRIPT EXECUTION REQUIRES PRODUCT-LEAD ADJUDICATION` condition **was never approached**: the frozen, script-free install exited 0. → a later unit, if a need is ever demonstrated.
4. **Whether the resolved closure is byte-identical between Linux and Windows** — `UNPROVEN`. The frozen install now demonstrably succeeds on both, which is what `D1` §15 could not say; **closure identity is a stronger claim and no comparison was performed.**
5. **Whether the inherited strict TypeScript settings are exercised by the current source** — `UNPROVEN`, and `D1` §19.6 said so first. The program is small enough that a strict option can be live and never bind. Not a defect; a limit on how much a green typecheck means.
6. **Whether `packages/shared` should be imported or retired** — unchanged from `D0` §17 and `D1` §15. A product-architecture question. `D2` changed nothing about it.
7. **`Q1` and `Q3` for every non-JS/TS active surface** — untouched by this unit and out of its scope. `D4` owns the static-analysis adjudication for those surfaces.

---

## 15. What `D3` may rely on

`D0` §16 makes `D2` the prerequisite of `D3`, whose subject is *"one invocable, documented quality entry point per active surface"*. Handed forward **as established fact, never as authorization** (`DEC-0042` §D16; `DEC-0040` D8), and limited to what entrypoint parity actually needs.

1. **A CI-side entry point now exists for the JS/TS surface**, and its exact commands are quoted at §9. `D3`'s parity question is now answerable, because there is finally something to be at parity *with*.
2. **The parity defect is named and unresolved, not fixed in passing.** Root `typecheck` reaches `web` only; `packages/shared` has a working `typecheck` script that **no root script invokes**. CI works around this by calling both package scripts directly. **That is a workaround inside the workflow, not a repaired entry point** — the root scripts were deliberately not modified, and the defect `D0` §16 assigned to `D3` is still there for `D3` to fix.
3. **Whatever `D3` lands must keep the CI and developer commands identical.** If `D3` introduces a root script that covers both packages, this workflow's two steps should become that one command — **and changing this workflow is a `D3` act requiring `D3`'s own GO, not something `D2` pre-authorizes.**
4. **The workflow watches its own file**, so a `D3` edit to it will be evaluated by it.
5. **`D3` remains NOT AUTHORIZED and NOT STARTED** and requires its own explicit Product-Lead GO.

---

## 16. What this unit deliberately did not do

Each was in reach, and each was declined.

- **No local execution of anything.** No `pnpm`, `npm`, `npx`, `corepack`, `node`, `tsc` or `next` was run on this host — not install, not typecheck, not build, not lint, not once. **No git worktree was created.** No pnpm store, no `node_modules`, no build directory, no `/tmp` or system-temp helper, no scratch file. The writ removed the local validation surface and this unit built none.
- **No product source change, and none was needed.** Both typechecks passed, so the branch where a CI failure would have had to be **recorded and routed rather than repaired by editing product behaviour** was never reached.
- **No manifest, lockfile or root-script change.** No dependency added, removed or upgraded.
- **No test dependency, no test file, no test framework configuration.**
- **No custom shell wrapper, package-count parser or project-list comparison** around the filtered typechecks. The zero-match guarantee is pnpm's own `--fail-if-no-match`; a hand-rolled second implementation of it was available and was declined (§5.1).
- **No ruleset, branch protection, required status check, `CODEOWNERS` file or reviewer threshold** — read-only GET requests only.
- **No manual workflow dispatch**, and no `workflow_dispatch` trigger added to the new workflow.
- **No change to any existing workflow file**, including `governance-checks.yml`.
- **No file under `packages/orchestrator/**`** — tree object identical at both ends.
- **No Axis-1 surface, no database, no cloud resource, no collection capability re-armed** (`DEC-0033` §8; `DEC-0042` §D12).
- **No decision record.** None was required: `D2` applies `DEC-0042` and `DEC-0038`, and creates no new normative policy. Disclosed here because `D1` §15 recorded the mirror-image divergence and asymmetric disclosure was its lesson.
- **No merge.** PR #96 is open and unmerged; ratification is the Product Lead's.

---

## 17. Mutation accounting

Per `DEC-0040` D13. **`OUTSIDE REPOSITORY ≠ OUTSIDE write_scope`**, and **a clean `git status` is NOT a `ZERO MUTATION` proof** — so the checks supporting every line, including every `ZERO`, are named.

### 17.1 Repository, inside write scope

| Path | Action | Classification |
|---|---|---|
| `.github/workflows/js-ts-quality.yml` | **added** | `AUTHORIZED MUTATION` |
| `docs/result/PHASE-D-D2-FIRST-JS-TS-QUALITY-SIGNAL-R1.md` | **added** | `AUTHORIZED MUTATION` |
| `docs/product/current-state.md` | **modified**, minimally | `AUTHORIZED MUTATION` |
| `docs/product/context-map.md` | **modified**, minimally | `AUTHORIZED MUTATION` |

**Four paths, four writes, zero deletions.** Supporting check: `git diff --name-status` between the canonical base and this branch's head enumerates exactly these four and no others.

**The pre-merge correction round narrowed that further, and its own scope is accounted separately.** The Product-Lead correction GO authorized **two files only** — the workflow and this record — and **that is exactly what it touched.** Supporting checks: `git diff --name-only` between the pre-correction head and the final head lists only `.github/workflows/js-ts-quality.yml` and `docs/result/PHASE-D-D2-FIRST-JS-TS-QUALITY-SIGNAL-R1.md` · **`current-state.md` and `context-map.md` are byte-identical across the correction round**, confirmed by blob-id comparison at both heads, because no correction proved either of them false · no new path entered the four-path set above.

### 17.2 Repository, outside write scope — `ZERO`

**Named checks, not an assertion.** `git diff --name-status <base>...HEAD` returns only the four paths above · `git status --porcelain --untracked-files=all` returns **empty**, so no untracked or modified file was left behind anywhere in the tree · `git rev-parse HEAD:packages/orchestrator` equals the same read at the canonical base — `7457f3f259ce8987e74ebe9f3db48172eabbd02b`, **byte-identical**, so nothing under the legacy tree changed · a filesystem `find` for files modified during this unit's execution window, excluding `.git`, `node_modules` and `.next`, returns **only** the four authorized paths.

**A modification-time check surfaced five further tracked files carrying this unit's date, and they do NOT all belong to one class.** An earlier revision of this section put all five in one bucket and called them byte-identical to the canonical base. **That was wrong: two of them are this unit's own authorized routing mutations, already accounted at §17.1, and they are not byte-identical.** The two buckets are now separated so that §17.1 and §17.2 cannot contradict each other. **The residue set below was re-derived rather than assumed** — by `git diff --name-status` between the canonical base and this head over the five paths, and independently by comparing each path's **git blob object id** at both ends.

#### PRE-SESSION RESET RESIDUE — three files, byte-identical to the canonical base

| Path | blob at base | blob at head | Identity |
|---|---|---|---|
| `pnpm-workspace.yaml` | `4ad2e693…` | `4ad2e693…` | **identical** |
| `apps/web/tsconfig.json` | `cfdac2ba…` | `cfdac2ba…` | **identical** |
| `docs/result/PHASE-D-D1-JS-TS-TOOLCHAIN-COHERENCE-R1.md` | `95f14290…` | `95f14290…` | **identical** |

These three carry a current modification time **only** because the pre-session `git reset` onto `origin/main` — the reflog entry for the `D1` merge, more than an hour before this unit's first action — rewrote them on disk. **Content unchanged, timestamp changed.** `HARNESS OR SYSTEM PERSISTENCE OUTSIDE AGENT CONTROL`, in the sense that it predates this unit entirely; **not a `D2` mutation.** `VERIFIED`.

#### `D2` AUTHORIZED ROUTING MUTATIONS — two files, explicitly EXCLUDED from the byte-identical claim

| Path | blob at base | blob at head | Identity |
|---|---|---|---|
| `docs/product/current-state.md` | `f8bd0a7a…` | `aa188c73…` | **DIFFERS** |
| `docs/product/context-map.md` | `40170b51…` | `7ed63271…` | **DIFFERS** |

**These two are `D2` mutations, authorized, and already recorded at §17.1. They are NOT byte-identical to the canonical base and are not part of the reset residue.** Their current modification time reflects both the pre-session reset **and** this unit's own edits, so timestamp alone never distinguished them — **blob identity did**, which is why the check is stated that way now rather than in terms of dates.

> **Recorded as a record-accuracy repair, not as a governance finding.** No authorization breach occurred, none was found by the independent Reviewer, and none is manufactured here. The earlier wording overstated the reach of one check; the underlying mutation set never changed.

### 17.3 Local filesystem outside the repository — `ZERO` created by this unit

**Named checks.** `git worktree list` returns three worktrees — the primary checkout plus `noxund-design-ref` and `noxund-p3c-execute-pre` — **all three pre-existing; this unit ran no `git worktree add` and no `git worktree remove`**, which is exactly the failure mode the `R2` writ was designed to eliminate · **no pnpm store directory was created**, because pnpm was never invoked locally · the four `node_modules` trees in the tree all carry mtime `2026-08-08`, two weeks before this unit, and were **neither created, refreshed, read as evidence nor deleted** · `apps/web/.next` carries mtime `2026-06-20` and was likewise untouched.

**The `.tsbuildinfo` claim, corrected.** An earlier revision of this section asserted that **no `.tsbuildinfo` exists anywhere under `apps/web`**. **That assertion is false and is withdrawn.** One does exist, it predates this unit, and the search that produced the claim was bounded to the top level of `apps/web` while the sentence was written as though it covered the whole subtree — **an overstated named check, disclosed rather than quietly narrowed.**

| Path | Size | mtime | Standing |
|---|---|---|---|
| `apps/web/.next/cache/.tsbuildinfo` | 140,837 bytes |  `2026-06-20` | **pre-existing**; the only `.tsbuildinfo` anywhere in the repository |

> **The corrected claim, at the strength the evidence supports.** **`D2` created no `.tsbuildinfo` on the local host. The pre-existing `apps/web/.next/cache/.tsbuildinfo` predates `D2` and was not created, refreshed or modified by this unit.**

**Evidence, and its limits.** Re-derived by a **repository-wide** `find` for `*.tsbuildinfo`, reading **metadata only** — the file was never opened, never read, never moved and never deleted. Its modification time is **two months before this unit's execution window**, and it lies inside `apps/web/.next`, itself unmodified at mtime `2026-06-20`. That timestamp evidence is what supports the claim; **no absence is claimed, and no blob-level history for an untracked, gitignored file is available to claim more.** The independent supporting fact remains that **no local `tsc` was invoked at all** — no `pnpm`, `npm`, `npx`, `corepack`, `node`, `tsc` or `next` ran on this host in this unit — so there was no mechanism by which this unit could have written one.

### 17.4 System temp, `/tmp`, and the session scratchpad — `ZERO`

**Named checks.** The `R2` writ withdrew scratchpad authorization for this unit, and **nothing was written to it, to `/tmp`, or to `%TEMP%`.** No redirection operator was used to create a helper file at any point: the workflow and this record were written directly to their authorized repository paths, and **the PR body was passed to `gh pr create` on stdin via a heredoc, never through a temporary file.** No command in this unit named a path under any temp directory.

### 17.5 Harness and system persistence outside agent control — **ONE, disclosed**

| Item | Classification |
|---|---|
| one tool-result file written by the harness under the session's `tool-results` directory, when a repository `grep` returned roughly 35 KB and exceeded the harness display cap | `HARNESS OR SYSTEM PERSISTENCE OUTSIDE AGENT CONTROL` |

**Disclosed with its cause and with the honest answer to whether it was avoidable: it was.** The writ directs the use of bounded reads, and this particular search was a `grep` over a large routing document without a width or count bound. A narrower search would have avoided it, and every subsequent read in this unit was bounded. **The file was written by the harness, not by an agent command; it was not deleted** — deletion compounds rather than remedies — **and it lies outside the repository and outside the PR.**

### 17.6 Memory and configuration — `ZERO`

**Named checks.** No memory file was written or read as proof; `DEC-0035` §5 forbids memory content as evidence and none was used. **No CLAUDE.md, no permission setting, no harness configuration and no repository setting was changed.**

### 17.7 GitHub control plane — `ZERO` writes

**Named checks.** Every ruleset, branch-protection, workflow-registry and run read in this unit was an HTTP GET. **No POST, PUT, PATCH or DELETE was issued against any settings, ruleset, protection, `CODEOWNERS`, reviewer or Environment endpoint**, and no `gh workflow run`, `gh workflow enable`, `gh workflow disable` or `gh api --method` call was made at all. The three rulesets and their rule sets are identical to the readings at §11 taken before any write occurred.

### 17.8 Authorized external effects

| Effect | Classification |
|---|---|
| branch `chore/phase-d-d2-first-js-ts-quality-signal` created from the canonical base and pushed | `AUTHORIZED MUTATION` |
| PR #96 opened against `main`, and left **unmerged** | `AUTHORIZED MUTATION` |
| automatic Actions runs caused by that PR's `pull_request` trigger — `32586763336`, `32587386670`, `32587458090` and `32589235883` on this workflow; `32587386665`, `32587458094` and `32589235958` on `governance-checks.yml`. **All seven `success`; zero failed runs, zero cancelled runs, zero manual dispatches** | `AUTHORIZED MUTATION` — automatic effects the writ names |
| the ephemeral runner's own filesystem — a checkout, a Node toolchain, a pnpm store and 327 installed packages | `AUTHORIZED MUTATION`, entirely inside the runner, destroyed with it, and **outside this repository and this host** |
| workflow id `340140169` registered by GitHub on first sight of the file | `HARNESS OR SYSTEM PERSISTENCE OUTSIDE AGENT CONTROL` — an automatic platform consequence of committing a workflow file, not a separate act |

**Every automatic run above is a consequence of an authorized push or pull-request event and of nothing else.** None was manually dispatched. **A further round of runs will fire on any commit this branch receives after this record is written** — including the one that lands this very paragraph — which is the ordinary and intended behaviour of the two path filters involved, not an unaccounted effect; their results are `UNPROVEN` here for the same reason a record cannot contain its own consequences.

### 17.9 `UNKNOWN MUTATION STATE`

**None claimed, and the absence is deliberate rather than convenient.** Every surface class above resolved to either a named write or a `ZERO` backed by named checks. Where this unit could not establish something — a scripts-enabled install, cross-platform closure identity, `next build` behaviour — those are **`UNPROVEN` facts about the world, not unknown mutations by this unit**, and they are at §14 rather than here.

---

*Related: [`DEC-0042`](../product/decisions/DEC-0042-engineering-quality-phase-charter.md) §D4 (surface standings), §D6 (evidence before threshold — no threshold is set here), D7 (tests, CI and static checks are three different things), §D8 and §D10 (control strength and gate honesty), §D11 (legacy surfaces), §D12 (the Axis-1 boundary), §D16 (every unit needs its own GO); [`DEC-0041`](../product/decisions/DEC-0041-mechanical-governance-enforcement.md) D1 (control-strength vocabulary), D2 (fewer real controls), D5 (not merge-blocking), D10 (no configuration touched); [`DEC-0040`](../product/decisions/DEC-0040-governed-result-disposition-closeout-contract.md) D3 (evidence classes), D5 (the `RED` trigger), D8 (`NEXT` is never authorization), D11 (the Author boundary), D13 (mutation accounting), D15 (reference durability); [`DEC-0038`](../product/decisions/DEC-0038-packages-orchestrator-disposition-reduce-to-approval-integrity-primitives.md) D1 and D3 (`REDUCE`; zero code action); [`DEC-0035`](../product/decisions/DEC-0035-canonical-context-v2-authority-lifecycle-supersession-model.md) §3.1, §5, §6, §9, §9.1. Baseline: [`PHASE-D-D0-ENGINEERING-QUALITY-BASELINE-R1`](PHASE-D-D0-ENGINEERING-QUALITY-BASELINE-R1.md). Prerequisite unit: [`PHASE-D-D1-JS-TS-TOOLCHAIN-COHERENCE-R1`](PHASE-D-D1-JS-TS-TOOLCHAIN-COHERENCE-R1.md). Routing surfaces reconciled: [`current-state.md`](../product/current-state.md), [`context-map.md`](../product/context-map.md).*
