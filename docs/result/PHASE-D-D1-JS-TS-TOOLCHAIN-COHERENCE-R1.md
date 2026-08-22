# PHASE D — `D1` JS/TS toolchain coherence and reproducible install · R1

**Status:** COMPLETE as an Author deliverable · **Date:** 2026-08-22 · **Author:** a task-scoped Author, to be reviewed by a **distinct** task-scoped independent reviewer, under the topology [`DEC-0037`](../product/decisions/DEC-0037-execution-topology-role-independence-governance-review-function.md) D5 fixes, carried into this unit by the Product Lead's own explicit `D1` GO ([`DEC-0042`](../product/decisions/DEC-0042-engineering-quality-phase-charter.md) §D16) · **Ratification gate:** the Product Lead's manual merge ([`DEC-0037`](../product/decisions/DEC-0037-execution-topology-role-independence-governance-review-function.md) D11)
**Authority class:** DESCRIPTIVE-CURRENT · **Lifecycle:** CURRENT · **Mutability:** FROZEN
**Type:** Toolchain-coherence record for a **mutating** unit. **This is not a decision record** — it creates no authority, classifies no artifact, narrows no clause, sets no threshold and authorizes no execution. `D1` operates entirely under the landed charter [`DEC-0042`](../product/decisions/DEC-0042-engineering-quality-phase-charter.md) and **creates no new normative authority of its own.**
**Canonical base:** `main` @ `3110acff2225e5a5e8e2c5a5ccfebefaca4ec9ae` (PR #94 merge), working tree clean at unit start.
**Method.** Every load-bearing claim below was **re-derived by this unit at the canonical base**, by execution wherever execution was possible. The unit writ supplied a list of already-derived facts; **every one was treated as `REPORTED` and independently re-verified**, and the two that materially govern the outcome — pnpm's actual workspace membership, and whether `--frozen-lockfile` fails today — were established by running pnpm rather than by reading YAML. No conversation claim and no memory content was used as proof ([`DEC-0035`](../product/decisions/DEC-0035-canonical-context-v2-authority-lifecycle-supersession-model.md) §5).
**Evidence classes** are exactly the four of [`DEC-0040`](../product/decisions/DEC-0040-governed-result-disposition-closeout-contract.md) D3 — `REPORTED` · `VERIFIED` · `ACCEPTED` · `UNPROVEN`. `HOLD` and `RED` are unit-disposition values and are used nowhere here as evidence classes.
**Author boundary.** This record states **no unit disposition and no artifact verdict** ([`DEC-0040`](../product/decisions/DEC-0040-governed-result-disposition-closeout-contract.md) D11). Both are void coming from an Author.

---

## 1. Classification, adjudicated rather than copied

`DEC-0035` §9's `docs/result/**` row defaults to `DESCRIPTIVE-CURRENT · CURRENT · FROZEN` **for phase closeouts**, and carries an anticipatory clause that *"should this family later carry run or gate outputs, those take class: **EVIDENCE**"*. This artifact is not a phase closeout, and — unlike `D0`, which was a measurement record with incidental runs — it is the record of a **mutating** unit whose central content is executed gate output. **The case for classifying the whole file `EVIDENCE` is therefore stronger here than it was for `D0`, and it is considered rather than skipped.**

**Adjudication: `DESCRIPTIVE-CURRENT · CURRENT · FROZEN`, with the executed install probes at §10 carrying `EVIDENCE` at clause level.** Two reasons.

1. **The file's dominant function is a state report.** What a later reader needs from it is *what the active JS/TS workspace now is and how it is materialized* — which is exactly what `DEC-0035` §3.1 defines DESCRIPTIVE-CURRENT for: *"A statement of current repository or system state, safe to route from. Creates no authority."* The probes are the grounds for that statement, not the statement.
2. **Whole-file promotion on the strength of some clauses is the move `DEC-0035` §9.1 forbids** in the mirror direction — *"A whole file is therefore never promoted … because one of its clauses was ratified elsewhere."* The clause-level discipline `D0` applied is applied here for the same reason, not by imitation.

`FROZEN` follows the family. The body is never rewritten, and its accuracy is bounded by the canonical base declared in the header.

---

## 2. The original incoherence, established by execution rather than by reading

`D0` recorded the shape of this defect and was explicit that it had not probed it: *"**Whether `--frozen-lockfile` would fail on this today is `UNPROVEN — NOT PROBED`**"* (`PHASE-D-D0-ENGINEERING-QUALITY-BASELINE-R1` §9 and §12 item 1). **`D1` probed it. It fails.**

**The two halves of the contradiction, each re-derived at the base.**

| Half | What it declares | Established by | Class |
|---|---|---|---|
| `pnpm-workspace.yaml` | `packages:` = `"apps/*"`, `"packages/*"` | file contents at the base | `VERIFIED` |
| **what pnpm actually evaluates that to** | **four** projects: root, `apps/web`, `packages/orchestrator`, `packages/shared` | `pnpm -r list --depth -1` executed at the base — **not inferred from the YAML** | `VERIFIED` |
| `pnpm-lock.yaml` | **three** importers: `.`, `apps/web`, `packages/shared` | `importers:` block; `packages/orchestrator` absent | `VERIFIED` |

**The consequence, quoted verbatim from the failing run (Probe A, §10).**

```
Scope: all 4 workspace projects
 ERR_PNPM_OUTDATED_LOCKFILE  Cannot install with "frozen-lockfile" because pnpm-lock.yaml is not up to date with packages\orchestrator\package.json

    Failure reason:
    specifiers in the lockfile ({}) don't match specs in package.json ({"@types/node":"^20.19.0","typescript":"^5.7.3"})
```

> **`D1`'s finding, stated at the strength the evidence supports: at the canonical base a clean checkout of NOXUND could not install its own JavaScript dependencies by the reproducible command.** `pnpm install --frozen-lockfile` exits `1`. This is not a latent risk and not a style objection — it is a reproducibility failure on the repository's only JS/TS install path, and `DEC-0042` §D5 `Q5` is the domain it sits in. `VERIFIED` by execution.

**Which half was untrue is the whole of the disposition question**, and it is answered in §3 rather than assumed here. The lockfile is not wrong about the active workspace; the workspace declaration is wrong about what is active.

---

## 3. Workspace disposition — four options adjudicated

**Selected: OPTION B — EXPLICIT LEGACY EXCLUSION**, on empirical grounds stated below.

### The empirical precondition, tested before it was relied on

The writ permitted Option B *"only if you EMPIRICALLY VERIFY that pnpm 9.0.0 honours negation in `pnpm-workspace.yaml`"*. **It was verified by execution inside the authorized validation worktree, on pnpm 9.0.0, before the option was selected** — not read from documentation and not assumed.

```
packages:
  - "apps/*"
  - "packages/*"
  - "!packages/orchestrator"
```
```
$ pnpm -r list --depth -1
noxund@0.0.0 ...\noxund-d1-install-validation-author (PRIVATE)
web@0.0.0 ...\apps\web (PRIVATE)
@noxund/shared@0.0.0 ...\packages\shared (PRIVATE)
```

**Negation is honoured: three projects, `@noxund/orchestrator` gone.** `VERIFIED`. The probe edit was reverted to the committed base text immediately afterwards (§17).

**Option A was tested identically and also works** — `"apps/*"` + `"packages/shared"` yields the same three projects. **Both candidates were empirically capable**, so the choice between them rests on properties other than whether they function.

### The four options

| Option | Disposition | Ground — evidence, not preference |
|---|---|---|
| **A — explicit active workspace** (`"apps/*"` + `"packages/shared"`) | **REJECTED** | Functionally equivalent today (`VERIFIED` above), and rejected on **two forward properties**. (i) It is the **larger semantic change**: it replaces the declared rule *"every package under `packages/` is a member"* with an enumeration, silently redefining the default for every package added later. (ii) That redefinition makes **silent exclusion the default** — a new active package under `packages/` would join no workspace, no lockfile and no future `D2` signal, and nothing would say so. That is the **silent-surface** failure mode `DEC-0042` §D1 states Phase D exists to remove: *"a surface on which a change can land with no signal firing and no reader able to tell that nothing fired."* Choosing A would repair one silent surface by installing the mechanism for the next one |
| **B — explicit legacy exclusion** (`"packages/*"` + `"!packages/orchestrator"`) | **SELECTED** | **Smallest semantic delta**: the existing default is preserved and exactly one exception is stated. **Self-documenting at the point of the exclusion** — the negation line is the statement, and the comment sits against it, which is what the success invariant requires. **Fails safe forward**: a future active package under `packages/` joins the workspace automatically. Empirically verified on pnpm 9.0.0. Touches no file under `packages/orchestrator/**` |
| **C — add orchestrator to the active lockfile** | **REJECTED** | It is quality investment in a surface the phase excludes. `DEC-0042` §D11: a `LEGACY` surface receives *"no quality investment"*; §D4 ranks it **LEGACY / NON-AUTHORITATIVE** on `D0` §2's evidence — zero executable importers, zero workflow references. **No landed evidence was found permitting it**, and the ground is stronger than scope: adding its `@types/node` and `typescript` resolutions to the active lockfile would make an unreached legacy package a **live input to every future active-surface install**, which is the opposite of REDUCE (`DEC-0038` D1) |
| **D — modify orchestrator to fit** | **PROHIBITED — not exercised** | `DEC-0038` D3 in terms: *"No file under `packages/orchestrator/**` is deleted, moved, renamed, edited or emptied"*, and *"no future unit may cite this record as authorization to remove code."* `DEC-0042` §D11 repeats it. **No such file was opened for writing at any point**; §12 proves the tree is byte-identical |

### Why the root declaration was the thing to repair

`D0` §16's `D1` entry authorizes exactly this and no more: *"`D1` may reconcile active and root workspace configuration, **including deciding how the legacy package is represented by that root configuration**"*. The repair is a **root correction**: it makes the root declaration state truthfully that the legacy package is not an active pnpm workspace member. **It is not investment in the legacy package**, and it disposes of nothing — `DEC-0038`'s REDUCE disposition is consumed unchanged, never revisited.

> **`DECLARED ACTIVE WORKSPACE = LOCKFILE WORKSPACE = INTENDED PHASE-D ACTIVE SURFACE`** now holds, and §10 proves each equality by execution rather than by inspection.

---

## 4. Exact files changed

**One file. Repository-wide, at the toolchain candidate commit `4b54de0b4f97e9437b988cbf40a0d90285c9103f`:**

```
$ git diff --name-only 3110acff2225e5a5e8e2c5a5ccfebefaca4ec9ae..4b54de0b4f97e9437b988cbf40a0d90285c9103f
pnpm-workspace.yaml
```

| File | Change | Note |
|---|---|---|
| `pnpm-workspace.yaml` | the negation line, plus the explanatory comment block | the whole of the toolchain change |
| root `package.json` | **NOT CHANGED** | no concrete `D1` coherence defect requires it (§6, §7). Cosmetic edits are not authorized and none was made. Blob identical: `b00dd1ca7d38006ed527484909886bcc83d7d913` |
| `pnpm-lock.yaml` | **NOT CHANGED — byte-identical** | §8 |
| Node selectors | **NONE ADDED** | §6 |
| `apps/web/tsconfig.json` | **NOT CHANGED — deliberately, and the defect is not withdrawn** | §15 item 1 |

The result artifact and the two routing documents are the unit's other three files; they are accounted for at §17.

**The comment block is part of the deliverable, not decoration.** The success invariant requires a fresh operator to answer *"what is the active NOXUND JS/TS workspace, and how do I reproducibly materialize it?"* from repository state alone. The file now names the three active projects, names the one install command, names the Node and pnpm pins, states **why** the legacy package is excluded citing `DEC-0038` D1 and `DEC-0042` §D11, and states that **excluded is not removed** citing `DEC-0038` D3 — so the exclusion cannot later be misread as a licence to delete.

---

## 5. Final active JS/TS workspace

**As pnpm actually reports it at the candidate commit**, not as YAML suggests:

```
$ pnpm -r list --depth -1
noxund@0.0.0 C:\Adeptlabs\noxund-d1-install-validation-author (PRIVATE)
web@0.0.0 C:\Adeptlabs\noxund-d1-install-validation-author\apps\web (PRIVATE)
@noxund/shared@0.0.0 C:\Adeptlabs\noxund-d1-install-validation-author\packages\shared (PRIVATE)
```

| Member | Standing (`DEC-0042` §D4) | In lockfile |
|---|---|---|
| `.` (root) | **ACTIVE TOOLING** — scripts and pins only; lockfile importer `.: {}` | yes |
| `apps/web` | **ACTIVE PRODUCT** | yes |
| `packages/shared` | **ACTIVE-BUT-UNREACHED** | yes |
| `packages/orchestrator` | **LEGACY / NON-AUTHORITATIVE** (`DEC-0038` D1) | **no — by design, and now by declaration** |

**Three declared members, three lockfile importers, one install command.** `VERIFIED`.

---

## 6. Node policy

**`NO ADDITIONAL NODE SELECTOR REQUIRED IN D1`.**

`.nvmrc` reads `20` and is the **only** Node selector in the repository — re-derived at the base: no `.node-version`, no `.tool-versions`, no `mise.toml`, no Volta key in any manifest, and **no `.npmrc` anywhere in the tree**. `VERIFIED`. **No second selector was added**, and CI Node selection is left to `D2`.

**The calculation, with the legacy package excluded first as the writ requires.** `packages/orchestrator`'s `engines.node` of `>=22.6` is **not** an active-workspace constraint — it belongs to a package that is no longer a member. Over root, `apps/web`, `packages/shared` and the locked active direct dependencies, read from the materialized closure:

| Package | Version installed | Declared `engines.node` |
|---|---|---|
| `next` | 15.5.19 | `^18.18.0 \|\| ^19.8.0 \|\| >= 20.0.0` |
| `react` | 19.2.7 | `>=0.10.0` |
| `react-dom` | 19.2.7 | *(none)* |
| `typescript` | 5.9.3 | `>=14.17` |
| **`eslint`** | **9.39.4** | **`^18.18.0 \|\| ^20.9.0 \|\| >=21.1.0`** |
| **`@eslint/eslintrc`** | **3.3.5** | **`^18.18.0 \|\| ^20.9.0 \|\| >=21.1.0`** |
| `postcss` | 8.5.15 | `^10 \|\| ^12 \|\| >=14` |
| `eslint-config-next`, `tailwindcss`, `@tailwindcss/postcss` | 15.5.19 / 4.3.1 / 4.3.1 | *(none)* |

**`engines.node` was NOT changed, and one genuine finding is recorded rather than acted on.**

> **A narrow declared-constraint gap exists and is stated precisely.** Root `engines.node` is `>=20`, which admits Node **20.0.0 – 20.8.x**; `eslint` and `@eslint/eslintrc` declare `^20.9.0` within the 20 line. In that narrow band the root constraint is broader than a locked active devDependency's own declaration.

**Why `D1` does not tighten it, on three grounds.** (i) The writ's test is a **demonstrated active-surface incompatibility**, and this is a declared-constraint gap, **`UNPROVEN` as a runtime failure** — nothing was executed on Node 20.0.0. (ii) It is **enforced by nothing**: there is no `.npmrc` and no `engine-strict` setting, and the install emitted no engine warning. (iii) The canonical selector already avoids the band — `.nvmrc` `20` resolves to the newest 20.x, which satisfies `^20.9.0`. Tightening `>=20` on this evidence would be a change without a demonstrated incompatibility, which the writ forbids. **The finding is routed at §15, not absorbed and not withdrawn.**

**The version actually used, stated honestly.** Every command in §10 ran on **Node v24.15.0** — which satisfies `>=20` but is **not** the `.nvmrc` pin of 20. **No Node version manager is installed on this machine and no Node was installed by this unit.**

> **Whether the frozen install succeeds on Node 20 specifically is `UNPROVEN`.** It is not assumed in either direction.

---

## 7. pnpm policy

**`packageManager` declares `pnpm@9.0.0` and was not changed.** The version was recorded **inside the validation worktree**, not inferred from the primary checkout:

```
$ pnpm --version
9.0.0
$ corepack --version
0.34.6
```

**Exactly 9.0.0 executed every probe** — the coherence failure, the negation test, the successful install and the smoke checks. No result here is attributed to a pnpm other than the declared one. pnpm printed an update banner offering `11.22.0` during the install; **it was not acted on.** No upgrade, no `corepack prepare`, no dedupe.

---

## 8. Lockfile disposition — BYTE-IDENTICAL

**`pnpm-lock.yaml` was not regenerated, not edited and not touched.** The preferred outcome held, so none of the change-justification the writ would have required arises.

| Point | sha256 | git blob |
|---|---|---|
| canonical base | `9f013355c771fb6dcc5bea6266e75082e4c79f9234372c0fab6a274d0761d326` | `e183bdc8be1eec284cb0abc7f80b5e49bc55b589` |
| after the **failing** Probe A | *identical* | *identical* |
| candidate commit, before install | *identical* | *identical* |
| **after the successful Probe B install** | `9f013355c771fb6dcc5bea6266e75082e4c79f9234372c0fab6a274d0761d326` | `e183bdc8be1eec284cb0abc7f80b5e49bc55b589` |

**Zero importers changed, zero resolutions changed, zero versions changed** — the file is the same object throughout, so there is nothing to enumerate. pnpm confirmed it independently in the install output: **`Lockfile is up to date, resolution step is skipped`**. No churn occurred, so the `HOLD — LOCKFILE CHURN EXCEEDS D1 BOUNDARY` condition was never approached. `VERIFIED`.

**This is the load-bearing point of the whole unit.** The lockfile always described the active workspace correctly. Only the declaration was untrue, and repairing the declaration made the existing lockfile installable **without altering a single resolved dependency**.

---

## 9. The exact install command

```
pnpm install --frozen-lockfile --ignore-scripts --store-dir C:/Adeptlabs/noxund-d1-pnpm-store-author
```

`--store-dir` is validation isolation and is **not** part of the repository contract. **The contract a fresh operator inherits, and the one written into `pnpm-workspace.yaml`, is `pnpm install --frozen-lockfile`.** The `--ignore-scripts` boundary is stated at §13.

---

## 10. Author install proof — ten points

**Validation environment.** A **detached** worktree at `C:/Adeptlabs/noxund-d1-install-validation-author` and a dedicated store at `C:/Adeptlabs/noxund-d1-pnpm-store-author`, both explicitly authorized by the writ, both destroyed after the evidence was recorded (§17). **`node_modules` was never materialized in the primary checkout `c:\Adeptlabs\noxund`**, and the four `node_modules` trees already present there were neither deleted, refreshed nor used as evidence.

### Probe A — the UNMODIFIED canonical base `3110acff…`

Run first, exactly as the writ recommends, to settle `D0` §12 item 1.

```
$ git rev-parse HEAD
3110acff2225e5a5e8e2c5a5ccfebefaca4ec9ae
$ pnpm -r list --depth -1
noxund@0.0.0 ... / web@0.0.0 ...\apps\web / @noxund/orchestrator@0.0.0 ...\packages\orchestrator / @noxund/shared@0.0.0 ...\packages\shared
$ pnpm install --frozen-lockfile --ignore-scripts --store-dir C:/Adeptlabs/noxund-d1-pnpm-store-author
Scope: all 4 workspace projects
 ERR_PNPM_OUTDATED_LOCKFILE  Cannot install with "frozen-lockfile" because pnpm-lock.yaml is not up to date with packages\orchestrator\package.json
    Failure reason:
    specifiers in the lockfile ({}) don't match specs in package.json ({"@types/node":"^20.19.0","typescript":"^5.7.3"})
EXIT_CODE=1
```

**`D0` §12 item 1 is resolved: `UNPROVEN — NOT PROBED` → `VERIFIED`. It fails.** The failed install wrote nothing: the lockfile hashes were unchanged and `git status --porcelain --ignored=traditional` returned **empty** — no `node_modules` was created at all.

### Probe B — the candidate commit `4b54de0b4f97e9437b988cbf40a0d90285c9103f`

Same authorized worktree path, moved to the candidate by `git checkout --detach` — accounted for at §17.

| # | Requirement | Command | Result |
|---|---|---|---|
| **1** | clean detached checkout at the candidate | `git rev-parse HEAD` | `4b54de0b4f97e9437b988cbf40a0d90285c9103f` |
| **2** | Node version, in the worktree | `node --version` | `v24.15.0` |
| **3** | exact pnpm version, in the worktree | `pnpm --version` | `9.0.0` |
| **4** | membership from a real pnpm evaluation | `pnpm -r list --depth -1` | root · `web` · `@noxund/shared` — **three** |
| **5** | legacy not a member | `pnpm list -r --depth -1 --json \| grep -c orchestrator` | **`0`** |
| **6** | frozen install succeeds | *the §9 command* | **`EXIT_CODE=0`** |
| **7** | lockfile hash before ≡ after | `sha256sum` + `git hash-object` | identical (§8) |
| **8** | tree clean but for ignored materialization | `git status --porcelain` / `--ignored=traditional` | tracked **empty**; ignored = 3 `node_modules` |
| **9** | no legacy file changed | `git diff --stat <base>..<cand> -- packages/orchestrator` | **empty** (§12) |
| **10** | no package version changed | manifest + lockfile blob comparison | all identical (§12) |

**Point 6, tail of the output, verbatim:**

```
Scope: all 3 workspace projects
Lockfile is up to date, resolution step is skipped
Packages: +320
Progress: resolved 320, reused 0, downloaded 320, added 320, done
Done in 37.2s
```

**Point 8, verbatim:**

```
$ git status --porcelain
(empty)
$ git status --porcelain --ignored=traditional
!! apps/web/node_modules/
!! node_modules/
!! packages/shared/node_modules/
```

**Two honest notes on point 8.** First, the ignored set is **exactly three** `node_modules` trees and **no `packages/orchestrator/node_modules`** — independent confirmation that the install never reached the legacy package. Second, `git status --ignored` emitted four `warning: could not open directory … Filename too long` lines while walking a deeply nested `@typescript-eslint` path under `node_modules/.pnpm/`. **They are Windows path-length warnings from git's scan of ignored content, they concern no tracked file, and the tracked-status result is unaffected** — recorded rather than trimmed out of the quotation.

---

## 11. Observational smoke check

Run as **observation only**, after a successful install, on the minimum necessary surface. **`next build` was NOT run**, as the writ requires.

```
$ pnpm --filter web typecheck             # > tsc --noEmit
EXIT=0
$ pnpm --filter @noxund/shared typecheck  # > tsc --noEmit
EXIT=0
```

Both active TypeScript surfaces typecheck clean at the candidate, on Node v24.15.0 and pnpm 9.0.0. **This partially resolves `D0` §12 item 2** — `tsc --noEmit` on `apps/web` was `UNPROVEN — NOT PROBED` and is now `VERIFIED` as passing at this base **on this Node version**. `next build` and `next lint` remain `UNPROVEN — NOT PROBED`.

**Scope discipline stated so the result is not over-read.** These passes are **not** a quality gate, nothing was fixed on their account, and a failure would not have authorized any product-code change. **`apps/web` typechecks against its own weak local configuration**, not against `tsconfig.base.json` — see §15 item 1. A green `tsc --noEmit` here therefore says less than it appears to, which is exactly the reading `DEC-0042` §D10 requires be stated rather than left to inference.

`apps/web/tsconfig.json` sets `"incremental": true`, so `apps/web/tsconfig.tsbuildinfo` was written **inside the validation worktree**. It is gitignored (`.gitignore:27` — `*.tsbuildinfo`, confirmed by `git check-ignore -v`) and was destroyed with the worktree (§17).

---

## 12. Legacy-tree preservation proof

**Four independent checks, each named.**

```
$ git diff --stat 3110acff…..4b54de0b… -- packages/orchestrator
(empty)

$ git diff --name-only 3110acff…..4b54de0b…
pnpm-workspace.yaml

$ git rev-parse 3110acff…:packages/orchestrator   ->  7457f3f259ce8987e74ebe9f3db48172eabbd02b
$ git rev-parse 4b54de0b…:packages/orchestrator   ->  7457f3f259ce8987e74ebe9f3db48172eabbd02b

$ ls -d packages/orchestrator/node_modules
ls: cannot access 'packages/orchestrator/node_modules': No such file or directory
```

**The tree object is identical** — `7457f3f259ce8987e74ebe9f3db48172eabbd02b`, the same hash `context-map.md` §2 already carries for this tree — so preservation is proven by content identity, not merely by an empty diff. `packages/orchestrator/package.json` is blob-identical at `7d6de0c8c98e6b09dfd3fd4c5293511161ab1919`. **No file under `packages/orchestrator/**` was created, deleted, moved, renamed, edited or emptied, and none was opened for writing.** `VERIFIED`.

> **What `D1` did and did not do to that package.** It changed **how the root declares it**, and nothing else. The package is unchanged, still on `main`, still `PRESERVED`. **`NOT AN ACTIVE WORKSPACE MEMBER` is not `REMOVED`**, and `DEC-0038` D3 is neither cited as authorization for anything nor weakened.

---

## 13. Install-script safety

Every install ran with **`--ignore-scripts`**. Dependency lifecycle scripts were **never executed**, silently or otherwise.

**Inventory of the two packages in the installed closure that declare an install lifecycle script**, enumerated from the materialized store so the boundary is named rather than waved at:

| Package | Script |
|---|---|
| `sharp@0.34.5` | `install: node install/check.js \|\| npm run build` |
| `unrs-resolver@1.12.2` | `postinstall: node postinstall.js` |

**No `HOLD` arises.** The `HOLD — LIFECYCLE-SCRIPT EXECUTION REQUIRES PRODUCT-LEAD ADJUDICATION` condition triggers only if lifecycle execution were **necessary to establish the contract**, and it was not: the workspace/lockfile coherence question is fully answered by the `--ignore-scripts` install, and both typechecks passed without them.

> **Stated as a limit rather than glossed: whether a scripts-enabled `pnpm install --frozen-lockfile` succeeds is `UNPROVEN`.** Both scripts fetch or build native binaries. It is a `D2` input (§15), not a `D1` claim.

---

## 14. The ten core questions

| # | Question | Answer | Class |
|---|---|---|---|
| **1** | What packages constitute the ACTIVE JS/TS workspace? | Root, `apps/web`, `packages/shared` — three, as pnpm itself reports them (§5) | `VERIFIED` |
| **2** | Should legacy orchestrator remain a pnpm workspace member? | **No.** It is `LEGACY / NON-AUTHORITATIVE` (`DEC-0038` D1), receives no quality investment (`DEC-0042` §D11), and its membership is the sole cause of the install failure at §2 | `VERIFIED` on the facts; the disposition is the Product Lead's to ratify |
| **3** | Does the current lockfile exactly represent the intended active workspace? | **Yes.** Its three importers are exactly the intended active surface. **The lockfile was never the defect** | `VERIFIED` |
| **4** | Can `pnpm@9.0.0` consume it with `--frozen-lockfile`? | **At the base, no** — `ERR_PNPM_OUTDATED_LOCKFILE`, exit 1. **At the candidate, yes** — exit 0, 320 packages, *"Lockfile is up to date, resolution step is skipped"* | `VERIFIED` both ways |
| **5** | Does the active workspace contain any contradictory Node requirement? | **No contradiction.** Every active declared requirement is satisfiable together. One **narrow gap**: root `>=20` admits 20.0.0–20.8.x while `eslint`/`@eslint/eslintrc` declare `^20.9.0` (§6) | `VERIFIED` as a declared-constraint fact; **`UNPROVEN` as a runtime incompatibility** |
| **6** | Is root `engines.node >=20` itself a demonstrated coherence problem? | **No.** Nothing was demonstrated to fail on it; it is unenforced (no `.npmrc`, no `engine-strict`), and `.nvmrc` `20` resolves above the gap. **Not changed** | `VERIFIED` (that no incompatibility was demonstrated) |
| **7** | Is an additional Node-version selector actually required? | **No.** `NO ADDITIONAL NODE SELECTOR REQUIRED IN D1`. `.nvmrc` is the only selector and remains so; CI Node selection is `D2`'s | `VERIFIED` |
| **8** | Can a clean checkout reproduce the dependency graph without lockfile mutation? | **Yes, at the candidate.** Clean detached checkout → 320 packages → lockfile byte-identical (§8, §10). **On Node v24.15.0**; on Node 20 specifically, `UNPROVEN` | `VERIFIED` on the environment used |
| **9** | Is any dependency upgrade required? | **No.** Zero versions changed; the existing lockfile installs as-is. No dedupe, no normalization, no vulnerability remediation, no pnpm upgrade — the update banner was declined | `VERIFIED` |
| **10** | Can `D1` solve the problem without touching legacy package files? | **Yes — demonstrated.** One file changed repo-wide; the legacy tree hash is identical (§12) | `VERIFIED` |

---

## 15. Remaining unknowns and routed items

Recorded as `UNPROVEN` / `UNKNOWN` rather than assumed in either direction, and **routed rather than absorbed. Naming is not authorization.**

1. **`apps/web/tsconfig.json` — the compiler-configuration defect is NOT REPAIRED by this unit, and is NOT WITHDRAWN.** `D0` §16's `D1` entry names three problems and this is the third: *"`apps/web/tsconfig.json` violates the `extends` constraint its own README states"* — `apps/web/README.md:27` requires *"`tsconfig.json` deve estender `../../tsconfig.base.json`"*, and the file declares no `extends` key, losing `noUncheckedIndexedAccess`, `noImplicitOverride`, `verbatimModuleSyntax` and `forceConsistentCasingInFileNames` (`D0` §10.2 row 1). **The Product Lead's `D1` writ enumerates the authorized mutation surfaces — root/workspace/toolchain configuration, the lockfile if strictly necessary, at most one Node selector, this artifact and the two routing documents — and `apps/web/tsconfig.json` is not among them.** The divergence between the `D0` roadmap entry and the writ is recorded plainly here rather than argued away or acted on. **The file was not touched.** → **Routed to the Product Lead: it needs either an explicit scope extension to a `D1` follow-up round, or its own bounded authorized unit.** Note the interaction with §11: the green `tsc --noEmit` reported there ran against the weak local configuration, so it is not evidence that the strict settings would pass.
2. **Whether the frozen install succeeds on Node 20 specifically** — `UNPROVEN`. Only Node v24.15.0 was available and no Node was installed. → `D2`, which selects the CI Node version.
3. **Whether a scripts-enabled install succeeds** (`sharp`, `unrs-resolver`) — `UNPROVEN`; every probe used `--ignore-scripts` (§13). → `D2`.
4. **Whether `next build` and `next lint` pass** — `UNPROVEN — NOT PROBED`; `next build` is forbidden to this unit. `D0` §12 item 2 survives in part.
5. **The narrow `>=20` / `^20.9.0` declared-constraint gap** (§6) — real, unenforced, and not a demonstrated incompatibility. → Product Lead, or a later unit that can demonstrate an actual failure. **Not a `D1` repair on this evidence.**
6. **Whether `packages/shared` should be imported or retired** — unchanged from `D0` §17 item 6; a product-architecture question. `D1` changed nothing about it beyond keeping it an explicit workspace member.
7. **Whether the resolved closure is identical on Linux** — `UNKNOWN`. Only Windows was exercised. → `D2`.

**Deliberately not done, and each was in reach:** no CI or workflow file; no ruleset, `CODEOWNERS` or required check; no test framework and no test; no root `test`/`quality`/`check` script; no lint or typecheck unification; no product source change; no dependency upgrade; no new decision record; and no merge.

---

## 16. The `D2` dependency handed forward

`D0` §16 made `D1` the prerequisite of `D2` and was candid that the ordering rested on **coherence** rather than on a predicted failure, *"so the ordering rests on the coherence ground, not on a predicted failure"*.

> **That prerequisite is now stronger than `D0` could state it.** A `--frozen-lockfile` job written at the canonical base would have failed with `ERR_PNPM_OUTDATED_LOCKFILE` — **`VERIFIED`, no longer `UNPROVEN`**. The ordering was correct, and for a firmer reason than the one available when it was chosen.

**What `D2` may now rely on** — as established fact, never as authorization (`DEC-0042` §D16; `DEC-0040` D8):

1. A **reproducible install command** exists that exits 0 from a clean checkout and leaves the lockfile byte-identical: `pnpm install --frozen-lockfile`.
2. The **active workspace is exactly three projects**, declared truthfully, so a job scoped to them covers the JS/TS active surface without excluding a declared member by hand.
3. **Both active typechecks pass** at this base (§11) — a candidate first signal that is known to be green today rather than hoped to be.
4. **Three named `UNPROVEN` inputs `D2` must settle:** the CI Node version (§15 item 2), lifecycle scripts (item 3), and Linux closure identity (item 7).

**`D2` remains NOT AUTHORIZED and NOT STARTED** and requires its own explicit Product-Lead GO.

---

## 17. Mutation accounting

Per `DEC-0040` D13. **`OUTSIDE REPOSITORY ≠ OUTSIDE write_scope`**, and **a clean `git status` is not a `ZERO MUTATION` proof** — so the checks supporting every line are named.

| Surface | Finding | Class |
|---|---|---|
| **Repository files** | **Exactly four created or modified**, all inside the declared write scope: `pnpm-workspace.yaml`; this record; `current-state.md`; `context-map.md`. Checked by `git status --porcelain` in the primary checkout and by `git diff --name-only` across each commit. **`pnpm-lock.yaml`, root `package.json`, every workspace manifest, `.nvmrc` and `apps/web/tsconfig.json` are blob-identical to the base** (§8, §12) | `AUTHORIZED MUTATION` |
| **Branches** | **One created** — `chore/phase-d-d1-js-ts-toolchain-coherence`, from canonical `main` @ `3110acff…`. Checked by `git branch --show-current` and `git for-each-ref` | `AUTHORIZED MUTATION` |
| **Commits / pushes / pull requests** | **One branch, one pull request, left UNMERGED.** Every commit sits on that branch and touches only the four files above; every push targeted that branch alone. **No count is stated, deliberately** — a correction round adds a commit and a push, so a number written into a `FROZEN` record is falsified by the act of writing it (the rule `DEC-0042` §5 adopts, and the defect `D0` R4 had to repair in its own predecessor). Checked by `git log 3110acff..HEAD` with `git show --name-only` per commit; by `git branch -a --contains` on the first commit; by the branch reflog — **created from the canonical base, every entry a plain `commit:`, no amend, reset, rebase or force update**; and by `git for-each-ref refs/remotes/origin`, where `origin/main` still reads `3110acff…` | `AUTHORIZED MUTATION` |
| **Refs, tags, stash** | **None created, deleted or moved.** Checked by `git for-each-ref`, `git tag --list` and `git stash list` — **one pre-existing stash entry, untouched**. Any `refs/codex/…` harness refs present are outside this agent's control | `ZERO MUTATION` for this unit's own acts, on that named basis · harness refs `HARNESS / SYSTEM PERSISTENCE OUTSIDE AGENT CONTROL` |
| **Worktrees** | **One created and then destroyed, both authorized in advance by the writ.** `C:/Adeptlabs/noxund-d1-install-validation-author`, added detached at `3110acff…`, moved to `4b54de0b…` by `git checkout --detach` for the second probe — **the same authorized path used for both probes, accounted for here rather than left implicit** — then removed with `git worktree remove` and `git worktree prune`. Checked by `git worktree list` before and after. **The three pre-existing worktrees — `noxund` itself, `noxund-design-ref`, `noxund-p3c-execute-pre` — were not touched** | `AUTHORIZED MUTATION`, created **and** cleaned up |
| **Out-of-repository files — the pnpm store** | **One directory created and then deleted, authorized in advance:** `C:/Adeptlabs/noxund-d1-pnpm-store-author`, passed explicitly via `--store-dir` on every install so that no shared or default store was written. Removed after the evidence was recorded. **Cleanup here is completion of an authorized instruction, not concealment** — `DEC-0040` D13's *"cleanup is never retroactive authorization"* is respected because the writes were authorized before they occurred and are disclosed in full | `AUTHORIZED MUTATION`, created **and** cleaned up |
| **Dependency materialization** | **`node_modules` was NEVER created in the primary checkout `c:\Adeptlabs\noxund`.** All three trees (`.`, `apps/web`, `packages/shared`) were created **inside the validation worktree only** and destroyed with it. The **four pre-existing `node_modules` trees in the primary checkout — including `packages/orchestrator/node_modules` — were not deleted, not refreshed, not reused as evidence and not read as proof of anything.** Checked by `git status --porcelain --ignored=traditional` in both locations | `AUTHORIZED MUTATION` inside the authorized worktree; **`ZERO MUTATION` in the primary checkout**, on that named basis |
| **Temp, cache, sidecar, backup files** | **None created anywhere outside the two authorized surfaces.** One build artifact — `apps/web/tsconfig.tsbuildinfo`, written by `tsc` because `apps/web/tsconfig.json` sets `"incremental": true` — was created **inside the validation worktree**, is gitignored (`.gitignore:27`, confirmed by `git check-ignore -v`), and was destroyed with the worktree. **No backup, sidecar or `.orig` file was written.** The one temporary edit made anywhere was the Option-B negation probe to `pnpm-workspace.yaml` **inside the validation worktree**, reverted immediately by `git checkout -- pnpm-workspace.yaml` and confirmed clean by `git status --porcelain` before the worktree moved on | `AUTHORIZED MUTATION` within the authorized worktree, fully disclosed |
| **`/tmp` and system temp** | **Nothing written.** No command in this unit targeted `/tmp`, `%TEMP%` or any system temp path; no `mktemp`, no redirection outside the two authorized surfaces, and no tool was invoked that writes there | `ZERO MUTATION`, on that named basis |
| **Session scratchpad** | **Not used at any point.** No scratch file, note, helper script, intermediate result or pull-request-body file was created. **The pull-request body was passed inline**, and the commit message was passed via stdin, not via a file | `ZERO MUTATION`, on that named basis |
| **Memory files** | **None written, of any kind**, inside the repository or outside it. **`C:\Users\Miguel\.claude\...` was not written to** — no `MEMORY.md`, no project or session memory, no settings file | `ZERO MUTATION`, on that named basis |
| **External mutable systems** | **Zero writes, with one authorized read class.** No workflow was created, edited, enabled, disabled or dispatched; no ruleset, branch protection, required check, `CODEOWNERS`, Environment, secret, variable or repository setting was touched; no database, cloud or collection resource was reached; nothing was re-armed (`DEC-0033` §8; `DEC-0042` §D12). **The only network activity was registry reads downloading the 320 artifacts the frozen lockfile already identifies** — explicitly authorized, and **no publication, no registry mutation, no upgrade lookup used as an implementation input, and no telemetry or config change.** The pnpm update banner was declined. The one write to a hosted system is the branch push and the pull-request creation, accounted for above | `ZERO MUTATION` for external configuration, on that named basis |

**No breach is recognized by this Author.** Two judgment calls are disclosed rather than left for a reviewer to discover: the **temporary in-worktree edit** used to falsify the negation question before relying on it, and the **reuse of one authorized worktree path for both probes** rather than a delete-and-recreate cycle. Both are recorded above at the point they occurred.

---

## 18. Reviewer reproduction

> **`PENDING — INDEPENDENT REVIEWER`.**

**Not fabricated and not pre-filled.** A **distinct** task-scoped independent reviewer (`DEC-0037` D5, D7) will reproduce the two probes and record the outcome, either in a later authored round of this unit or in the Phase-D closeout. Until then, every install claim in this record carries **Author-produced `VERIFIED`** — which under `DEC-0040` D3 is **not** `ACCEPTED`, and **`ACCEPTED` is the Product Lead's word alone.**

**Minimum reproduction path**, so the reviewer need not reconstruct it: create a detached worktree at `3110acff…` and run the §9 command → expect `ERR_PNPM_OUTDATED_LOCKFILE`, exit 1; move it to the candidate commit and run the same command → expect exit 0 with *"Lockfile is up to date, resolution step is skipped"*; compare `sha256sum pnpm-lock.yaml` at both points against `9f013355c771fb6dcc5bea6266e75082e4c79f9234372c0fab6a274d0761d326`. **A reviewer on Node 20 would additionally settle §15 item 2**, which this Author could not.

---

*Current state is owned by [`current-state.md`](../product/current-state.md); routing by [`context-map.md`](../product/context-map.md); classification and precedence by [`DEC-0035`](../product/decisions/DEC-0035-canonical-context-v2-authority-lifecycle-supersession-model.md); the Phase-D charter is [`DEC-0042`](../product/decisions/DEC-0042-engineering-quality-phase-charter.md), and the baseline this unit executes against is [`PHASE-D-D0-ENGINEERING-QUALITY-BASELINE-R1`](PHASE-D-D0-ENGINEERING-QUALITY-BASELINE-R1.md).*
