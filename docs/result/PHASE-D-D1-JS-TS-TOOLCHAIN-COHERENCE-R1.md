# PHASE D — `D1` JS/TS toolchain coherence and reproducible install · R1

**Status:** COMPLETE as an Author deliverable · **Date:** 2026-08-22 · **Author:** a task-scoped Author, **reviewed by a distinct task-scoped independent reviewer whose reproduction is recorded at §18** — function-independent in all three required functions, **not** principal-independent (§18.1) — under the topology [`DEC-0037`](../product/decisions/DEC-0037-execution-topology-role-independence-governance-review-function.md) D5 fixes, carried into this unit by the Product Lead's own explicit `D1` GO ([`DEC-0042`](../product/decisions/DEC-0042-engineering-quality-phase-charter.md) §D16) · **Ratification gate:** the Product Lead's manual merge ([`DEC-0037`](../product/decisions/DEC-0037-execution-topology-role-independence-governance-review-function.md) D11)
**Authority class:** DESCRIPTIVE-CURRENT · **Lifecycle:** CURRENT · **Mutability:** FROZEN
**Type:** Toolchain-coherence record for a **mutating** unit. **This is not a decision record** — it creates no authority, classifies no artifact, narrows no clause, sets no threshold and authorizes no execution. `D1` operates entirely under the landed charter [`DEC-0042`](../product/decisions/DEC-0042-engineering-quality-phase-charter.md) and **creates no new normative authority of its own.**
**Canonical base:** `main` @ `3110acff2225e5a5e8e2c5a5ccfebefaca4ec9ae` (PR #94 merge), working tree clean at unit start.
**Method.** Every load-bearing claim below was **re-derived by this unit at the canonical base**, by execution wherever execution was possible. The unit writ supplied a list of already-derived facts; **every one was treated as `REPORTED` and independently re-verified**, and the two that materially govern the outcome — pnpm's actual workspace membership, and whether `--frozen-lockfile` fails today — were established by running pnpm rather than by reading YAML. No conversation claim and no memory content was used as proof ([`DEC-0035`](../product/decisions/DEC-0035-canonical-context-v2-authority-lifecycle-supersession-model.md) §5).
**Evidence classes** are exactly the four of [`DEC-0040`](../product/decisions/DEC-0040-governed-result-disposition-closeout-contract.md) D3 — `REPORTED` · `VERIFIED` · `ACCEPTED` · `UNPROVEN`. `HOLD` and `RED` are unit-disposition values and are used nowhere here as evidence classes.
**Governance provenance, in the header because it must not be discoverable only by reading to the end.** The D1 **unit** carries a permanent historical **`UNIT GOVERNANCE DISPOSITION = RED — VERIFIED AUTHORIZATION BREACH`**, arising from the independent **Reviewer's** conduct after this record's R2 commit — **not** from this Author's conduct, and **not** from the artifact. Findings **`G-1`** and **`G-1b`** are both **`CLOSED — REMEDIATED`**, which **never rewrites the historical `RED`** (`DEC-0040` D7). The **technical artifact verdict is `PASS`** and survives, the Product Lead having **explicitly accepted the unit/artifact separation** (`DEC-0040` D14 condition 7). **Final ratification is still pending and is the Product Lead's manual merge of PR #95.** Full account at **§20**. **None of it is this Author's to decide, and it is recorded here as the Product Lead's ruling and the reviewers' findings, not as this Author's conclusions.**
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

**The consequence — the operative lines of the failing run. This is a MARKED EXCERPT, not the untrimmed output:** two Node deprecation lines and pnpm's CI advisory are elided at the marks below, and **§10 Probe A carries the run in full.** *(R1 introduced this block with the word "verbatim" over a silent elision, while §10 point 8 preserved comparable noise expressly "rather than trimmed out of the quotation" — two standards in one record. R2 keeps the untrimmed output at §10 and marks the elision here.)*

```
Scope: all 4 workspace projects
[… two Node `[DEP0169] DeprecationWarning: url.parse()` lines elided — §10 …]
 ERR_PNPM_OUTDATED_LOCKFILE  Cannot install with "frozen-lockfile" because pnpm-lock.yaml is not up to date with packages\orchestrator\package.json

[… pnpm's "Note that in CI environments this setting is true by default…" advisory elided — §10 …]

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
| `apps/web/tsconfig.json` | **CHANGED IN R3 — one line, under the Product Lead's explicit scope extension.** In R1 and R2 it was **NOT CHANGED**, deliberately, because the original writ did not authorize it; the Product Lead has since ruled that omission a **writ defect rather than an Author failure** | §19 — the T1 adjudication. The R1/R2 position is preserved at §15 item 1 |

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

**The install output below is untrimmed** — every line pnpm and Node emitted, including the deprecation pair and the CI advisory that R1 silently dropped (repaired in R2; §2 now carries a marked excerpt and points here).

```
$ git rev-parse HEAD
3110acff2225e5a5e8e2c5a5ccfebefaca4ec9ae
$ pnpm -r list --depth -1
noxund@0.0.0 ... / web@0.0.0 ...\apps\web / @noxund/orchestrator@0.0.0 ...\packages\orchestrator / @noxund/shared@0.0.0 ...\packages\shared
$ pnpm install --frozen-lockfile --ignore-scripts --store-dir C:/Adeptlabs/noxund-d1-pnpm-store-author
Scope: all 4 workspace projects
(node:73772) [DEP0169] DeprecationWarning: `url.parse()` behavior is not standardized and prone to errors that have security implications. Use the WHATWG URL API instead. CVEs are not issued for `url.parse()` vulnerabilities.
(Use `node --trace-deprecation ...` to show where the warning was created)
 ERR_PNPM_OUTDATED_LOCKFILE  Cannot install with "frozen-lockfile" because pnpm-lock.yaml is not up to date with packages\orchestrator\package.json

Note that in CI environments this setting is true by default. If you still need to run install in such cases, use "pnpm install --no-frozen-lockfile"

    Failure reason:
    specifiers in the lockfile ({}) don't match specs in package.json ({"@types/node":"^20.19.0","typescript":"^5.7.3"})
EXIT_CODE=1
```

**The advisory is quoted rather than dropped because it is the one elided line that could mislead a later reader**: pnpm proposes `--no-frozen-lockfile` as the way out. **That is not the repair `D1` chose and would have been the wrong one** — it would have let the install proceed by re-resolving against the untrue declaration, mutating the lockfile to add the legacy importer, and delivering exactly the Option-C outcome §3 rejects.

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

**Point 6 — the decisive lines. A MARKED SELECTION, not a contiguous tail:** the same deprecation pair, pnpm's update banner and roughly two dozen incremental `Progress:` lines sit between these and are elided at the marks. *(R1 called this "tail of the output, verbatim"; it was a selection, and R2 says so. The banner is quoted at §7, where declining it is the load-bearing fact.)*

```
Scope: all 3 workspace projects
[… two Node `[DEP0169] DeprecationWarning` lines elided …]
Lockfile is up to date, resolution step is skipped
Progress: resolved 1, reused 0, downloaded 0, added 0
Packages: +320
[… progress bar, pnpm's "Update available! 9.0.0 → 11.22.0" banner, and ~24 incremental `Progress:` lines elided — see §7 …]
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

### Probe C — re-verification at commit `434411d78a8b341fd10700af7fecc2a29cc6d687`

**Why it exists.** Probe B ran at `4b54de0b…`, the commit carrying the toolchain change alone. `434411d7…` additionally carries this record and the two routing documents. Those are documentation and **cannot** affect an install, but the claim is **re-established on them rather than argued to carry forward.**

> **`434411d7…` IS NOT THE BRANCH HEAD, and R1's heading said it was. Corrected here rather than left standing.** `434411d7…` was the head **at the moment this probe ran**; the very commit that recorded the probe (`d0432df…`) displaced it, and R2 displaces it again. **R1 applied the self-falsification discipline to commit counts at §17** — *"a number written into a `FROZEN` record is falsified by the act of writing it"* — **and failed to apply the identical discipline to a head SHA.** A `FROZEN` record cannot name its own head: **any commit that records the naming falsifies it.** This is the same defect class `D0` R4 repaired in its own predecessor's push count, and the repair is the same — state what actually happened and stop asserting a self-falsifying value.

**What this probe does and does not establish.** It establishes that the install outcome is unchanged on a commit carrying the documentation as well as the toolchain change. **It does not establish the outcome at the branch head**, and no Author probe in this record does. **That verification is discharged by the independent Reviewer's Probe B at `46d83d4b87c180b69eea3b61ddc197e3b25a519e`, recorded at §18** — which was the branch head at the time of that review, and which is likewise not asserted here to be the final head. **No new Author probe was invented at the true head to paper over this**, and Probe C is not deleted.

```
$ git rev-parse HEAD
434411d78a8b341fd10700af7fecc2a29cc6d687
$ pnpm -r list --depth -1
noxund@0.0.0 ... / web@0.0.0 ...\apps\web / @noxund/shared@0.0.0 ...\packages\shared
$ pnpm install --frozen-lockfile --ignore-scripts --store-dir C:/Adeptlabs/noxund-d1-pnpm-store-author
Lockfile is up to date, resolution step is skipped
Already up to date
Done in 708ms
$ sha256sum pnpm-lock.yaml
9f013355c771fb6dcc5bea6266e75082e4c79f9234372c0fab6a274d0761d326 *pnpm-lock.yaml
$ git status --porcelain
(empty)
```

**Three projects, exit 0, lockfile byte-identical, tracked tree clean — unchanged from Probe B.** `Already up to date` also confirms the second install was idempotent against the store rather than a fresh resolution. `VERIFIED` **at `434411d7…`, and scoped to that commit.**

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

**Scope discipline stated so the result is not over-read.** These passes are **not** a quality gate, nothing was fixed on their account, and a failure would not have authorized any product-code change. **`apps/web` typechecks against its own weak local configuration**, not against `tsconfig.base.json` — see §15 item 1. A green `tsc --noEmit` here therefore says less than it appears to, which is exactly the reading `DEC-0042` §D10 requires be stated rather than left to inference. **`HISTORICAL — TRUE OF R1 AND R2 ONLY.` R3 repaired exactly this**: `apps/web/tsconfig.json` now extends the base, and the R3 typecheck at §19.5 runs against the inherited strict settings. **The caveat is preserved rather than deleted because it was the honest reading of the R1/R2 evidence and is why that evidence must not be re-read as stronger than it was.**

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

1. **`apps/web/tsconfig.json` — `RESOLVED IN R3`. The paragraph below is `HISTORICAL — THE R1 AND R2 POSITION`, preserved because it records why the deferral was correct at the time; the resolution is at §19.** The Product Lead subsequently ruled that the original writ's omission of this file was a **writ defect, not an Author failure**, extended scope explicitly, and R3 adjudicated it to **T1 — ALIGN**. **As written in R1/R2:** *the compiler-configuration defect is NOT REPAIRED by this unit, and is NOT WITHDRAWN.* `D0` §16's `D1` entry names three problems and this is the third: *"`apps/web/tsconfig.json` violates the `extends` constraint its own README states"* — `apps/web/README.md:27` requires *"`tsconfig.json` deve estender `../../tsconfig.base.json`"*, and the file declares no `extends` key, losing `noUncheckedIndexedAccess`, `noImplicitOverride`, `verbatimModuleSyntax` and `forceConsistentCasingInFileNames` (`D0` §10.2 row 1). **The Product Lead's `D1` writ enumerates the authorized mutation surfaces — root/workspace/toolchain configuration, the lockfile if strictly necessary, at most one Node selector, this artifact and the two routing documents — and `apps/web/tsconfig.json` is not among them.** The divergence between the `D0` roadmap entry and the writ is recorded plainly here rather than argued away or acted on. **The file was not touched.** → **Routed to the Product Lead: it needs either an explicit scope extension to a `D1` follow-up round, or its own bounded authorized unit.** Note the interaction with §11: the green `tsc --noEmit` reported there ran against the weak local configuration, so it is not evidence that the strict settings would pass.
2. **No decision record was produced, and `D0` §16 expected one — disclosed here so the divergence account is symmetric.** `D0` §16's `D1` entry states the expected artifact is *"Coherent manifests, lockfile and compiler configuration, **plus a decision record for the choices made**."* **`D1` produced no `DEC-00NN`.** Nothing is misstated by that — **the writ governs, not the roadmap** (`DEC-0042` §D16): it directed `D1` to operate under the landed charter, enumerated a write scope containing no decision record, and instructed that if a genuinely new normative policy were required the unit must **stop and escalate** rather than create one. **No new normative policy was required**, so none was created; the workspace disposition is an application of `DEC-0038` D1 and `DEC-0042` §D11, not a new rule. **The adjudication a decision record would have carried is at §3** — four options, the ground each was rejected on, and the empirical precondition tested before Option B was relied on. **Why this is stated at all:** item 1 already discloses one shortfall against that same `D0` line (compiler configuration), and R1 disclosed only that one while listing "no new decision record" at the foot of this section as merely deliberately-not-done. **Disclosing one half of a two-part divergence and not the other is the asymmetry repaired here.** → **Routed to the Product Lead**, who may judge that the config-plus-evidence form is sufficient, or may direct that a `DEC-00NN` be authored under a separately authorized unit. **`D1` does not decide that question and does not treat its own silence as an answer.**
3. **Whether the frozen install succeeds on Node 20 specifically** — `UNPROVEN`. Only Node v24.15.0 was available and no Node was installed. → `D2`, which selects the CI Node version.
4. **Whether a scripts-enabled install succeeds** (`sharp`, `unrs-resolver`) — `UNPROVEN`; every probe used `--ignore-scripts` (§13). → `D2`.
5. **Whether `next build` and `next lint` pass** — `UNPROVEN — NOT PROBED`; `next build` is forbidden to this unit. `D0` §12 item 2 survives in part.
6. **The narrow `>=20` / `^20.9.0` declared-constraint gap** (§6) — real, unenforced, and not a demonstrated incompatibility. → Product Lead, or a later unit that can demonstrate an actual failure. **Not a `D1` repair on this evidence.**
7. **Whether `packages/shared` should be imported or retired** — unchanged from `D0` §17 item 6; a product-architecture question. `D1` changed nothing about it beyond keeping it an explicit workspace member.
8. **Whether the resolved closure is identical on Linux** — `UNKNOWN`. Only Windows was exercised. → `D2`.

**Deliberately not done, and each was in reach:** no CI or workflow file; no ruleset, `CODEOWNERS` or required check; no test framework and no test; no root `test`/`quality`/`check` script; no lint or typecheck unification; no product source change; no dependency upgrade; **no new decision record — item 2 above, not merely a line in this list**; and no merge.

---

## 16. The `D2` dependency handed forward

`D0` §16 made `D1` the prerequisite of `D2` and was candid that the ordering rested on **coherence** rather than on a predicted failure, *"so the ordering rests on the coherence ground, not on a predicted failure"*.

> **That prerequisite is now stronger than `D0` could state it.** A `--frozen-lockfile` job written at the canonical base would have failed with `ERR_PNPM_OUTDATED_LOCKFILE` — **`VERIFIED`, no longer `UNPROVEN`**. The ordering was correct, and for a firmer reason than the one available when it was chosen.

**What `D2` may now rely on** — as established fact, never as authorization (`DEC-0042` §D16; `DEC-0040` D8):

1. A **reproducible install command** exists that exits 0 from a clean checkout and leaves the lockfile byte-identical: `pnpm install --frozen-lockfile`.
2. The **active workspace is exactly three projects**, declared truthfully, so a job scoped to them covers the JS/TS active surface without excluding a declared member by hand.
3. **Both active typechecks pass** at this base (§11) — a candidate first signal that is known to be green today rather than hoped to be.
4. **Three named `UNPROVEN` inputs `D2` must settle:** the CI Node version (§15 item 3), lifecycle scripts (item 4), and Linux closure identity (item 8).

**`D2` remains NOT AUTHORIZED and NOT STARTED** and requires its own explicit Product-Lead GO.

---

## 17. Mutation accounting

Per `DEC-0040` D13. **`OUTSIDE REPOSITORY ≠ OUTSIDE write_scope`**, and **a clean `git status` is not a `ZERO MUTATION` proof** — so the checks supporting every line are named.

| Surface | Finding | Class |
|---|---|---|
| **Repository files** | **Exactly four created or modified across the whole unit**, all inside the declared write scope: `pnpm-workspace.yaml`; this record; `current-state.md`; `context-map.md`. **R2 touched two of those four and created nothing new** — this record and `pnpm-workspace.yaml`; `current-state.md` and `context-map.md` were **not** reopened in R2, the Reviewer having verified both as accurate and minimal (§17.1). **R3 raised the total to five** by adding **`apps/web/tsconfig.json`**, authorized by the Product Lead's explicit R3 scope extension and by nothing earlier (§19). **`apps/web/README.md` was NOT touched** — the grant permitted that file **or** the config, not both, and T1 needs only the config. Checked by `git status --porcelain` in the primary checkout and by `git diff --name-only` across each commit and across `3110acff..HEAD`. **`pnpm-lock.yaml`, root `package.json`, every workspace manifest, `.nvmrc` and `apps/web/tsconfig.json` are blob-identical to the base** (§8, §12) | `AUTHORIZED MUTATION` |
| **Branches** | **One created** — `chore/phase-d-d1-js-ts-toolchain-coherence`, from canonical `main` @ `3110acff…`. Checked by `git branch --show-current` and `git for-each-ref` | `AUTHORIZED MUTATION` |
| **Commits / pushes / pull requests** | **One branch, one pull request, left UNMERGED.** Every commit sits on that branch and touches only the four files above; every push targeted that branch alone. **No count is stated, deliberately** — a correction round adds a commit and a push, so a number written into a `FROZEN` record is falsified by the act of writing it (the rule `DEC-0042` §5 adopts, and the defect `D0` R4 had to repair in its own predecessor). Checked by `git log 3110acff..HEAD` with `git show --name-only` per commit; by `git branch -a --contains` on the first commit; by the branch reflog — **created from the canonical base, every entry a plain `commit:`, no amend, reset, rebase or force update**; and by `git for-each-ref refs/remotes/origin`, where `origin/main` still reads `3110acff…` | `AUTHORIZED MUTATION` |
| **Refs, tags, stash** | **None created, deleted or moved.** Checked by `git for-each-ref`, `git tag --list` and `git stash list` — **one pre-existing stash entry, untouched**. Any `refs/codex/…` harness refs present are outside this agent's control | `ZERO MUTATION` for this unit's own acts, on that named basis · harness refs `HARNESS / SYSTEM PERSISTENCE OUTSIDE AGENT CONTROL` |
| **Worktrees** | **One created and then destroyed, both authorized in advance by the writ.** `C:/Adeptlabs/noxund-d1-install-validation-author`, added detached at `3110acff…`, then moved to `4b54de0b…` and to `434411d7…` by `git checkout --detach` for the later probes — **one authorized path reused for all three probes, accounted for here rather than left implicit.** Checked by `git worktree list` before and after; the three pre-existing worktrees — `noxund` itself, `noxund-design-ref`, `noxund-p3c-execute-pre` — **were not touched. Cleanup did not go as scripted, and the deviation is reported rather than smoothed:** `git worktree remove --force` **deregistered the worktree but exited 255 with `error: failed to delete '…': Filename too long`**, leaving the directory on disk — the same Windows path-length limit that produced the point-8 warnings, hit here on the nested `@typescript-eslint` paths under `node_modules/.pnpm/`. `git worktree prune` then cleaned the administrative entry, and **the directory was deleted with PowerShell `Remove-Item -Recurse -Force` against the `\\?\` long-path form of the same path.** Confirmed by `Test-Path` returning `False` and by `git worktree list` showing only the three pre-existing entries. **Nothing outside that one directory was targeted or removed.** **R3 repeated this pattern with its own separately authorized pair and the identical failure and fallback — see §17.2** | `AUTHORIZED MUTATION`, created **and** cleaned up |
| **Out-of-repository files — the pnpm store** | **One directory created and then deleted, authorized in advance:** `C:/Adeptlabs/noxund-d1-pnpm-store-author`, passed explicitly via `--store-dir` on **every** install so that no shared or default pnpm store was written. Deleted after the evidence was recorded, by the same `\\?\` long-path `Remove-Item` used for the worktree; confirmed absent by `Test-Path`. A listing of `C:\Adeptlabs` afterwards shows **neither authorized artifact remains**, and the many pre-existing `noxund-p3c-*` sibling directories from earlier PG-EXIT work were **neither read, modified nor removed**. **Cleanup here is completion of an authorized instruction, not concealment** — `DEC-0040` D13's *"cleanup is never retroactive authorization"* is respected because both writes were authorized **before** they occurred, are disclosed in full, and the evidence they produced is recorded above rather than destroyed with them. **R3's own store is accounted for at §17.2** | `AUTHORIZED MUTATION`, created **and** cleaned up |
| **Dependency materialization** | **`node_modules` was NEVER created in the primary checkout `c:\Adeptlabs\noxund`.** All three trees (`.`, `apps/web`, `packages/shared`) were created **inside the validation worktree only** and destroyed with it. The **four pre-existing `node_modules` trees in the primary checkout — including `packages/orchestrator/node_modules` — were not deleted, not refreshed, not reused as evidence and not read as proof of anything.** Checked by `git status --porcelain --ignored=traditional` in both locations | `AUTHORIZED MUTATION` inside the authorized worktree; **`ZERO MUTATION` in the primary checkout**, on that named basis |
| **Temp, cache, sidecar, backup files** | **None created anywhere outside the two authorized surfaces.** One build artifact — `apps/web/tsconfig.tsbuildinfo`, written by `tsc` because `apps/web/tsconfig.json` sets `"incremental": true` — was created **inside the validation worktree**, is gitignored (`.gitignore:27`, confirmed by `git check-ignore -v`), and was destroyed with the worktree. **No backup, sidecar or `.orig` file was written.** The one temporary edit made anywhere was the Option-B negation probe to `pnpm-workspace.yaml` **inside the validation worktree**, reverted immediately by `git checkout -- pnpm-workspace.yaml` and confirmed clean by `git status --porcelain` before the worktree moved on | `AUTHORIZED MUTATION` within the authorized worktree, fully disclosed |
| **`/tmp` and system temp** | **No command this unit issued wrote there**, and that is the exact scope of the claim: no command targeted `/tmp`, `%TEMP%` or any system temp path, no `mktemp` was used, no redirection left the two authorized surfaces, and no tool was invoked for the purpose of writing there. **R1 said "Nothing written", which reaches past what that check supports** — it is a statement about the agent's own acts, not a path-level guarantee about a directory the harness also uses. **The independent Reviewer's path-level check found two GUID-named system-temp files timestamped inside the unit window**; they are harness-owned housekeeping, not agent writes (§18) | **`ZERO MUTATION` for this unit's own acts**, on that named basis · the observed residue `HARNESS / SYSTEM PERSISTENCE OUTSIDE AGENT CONTROL` |
| **Session scratchpad** | **Not used at any point, and this one is provable at path level.** No scratch file, note, helper script, intermediate result or pull-request-body file was created. **The pull-request body was passed inline**, and every commit message was passed via stdin, not via a file. Checked by enumerating the session scratchpad directory: **`find … -type f` returns `0`** — the directory exists, created by the harness, and is **empty**. The independent Reviewer confirmed the same (§18) | `ZERO MUTATION`, on that named basis |
| **Memory files** | **No memory file was written, of any kind**, inside the repository or outside it — **no `MEMORY.md`, no project or session memory file, no settings file, and no `CLAUDE.md`.** Checked at path level by mtime rather than asserted: the newest file under the project memory directory is `MEMORY.md` at **`2026-08-21 12:52:34`**, and `.claude/settings.json` at `2026-08-19 21:20:32` — **both predate this unit's window**, and the Reviewer independently reproduced that finding (§18). **R1's broader phrasing — that `C:\Users\Miguel\.claude\...` "was not written to" — reaches past that check and is narrowed here.** Several paths **under** that root do carry mtimes inside the window: `.last-cleanup`, and the `session-env`, `sessions`, `shell-snapshots` and `backups` directories. **None is a memory file, a settings file or an agent write** — they are harness housekeeping this Author neither chose, requested nor could prevent, and **naming them is not a concession that a memory write occurred; none did** | **`ZERO MUTATION` for memory content**, on the named mtime basis · the harness housekeeping paths `HARNESS / SYSTEM PERSISTENCE OUTSIDE AGENT CONTROL` |
| **External mutable systems** | **Zero writes, with one authorized read class.** No workflow was created, edited, enabled, disabled or dispatched; no ruleset, branch protection, required check, `CODEOWNERS`, Environment, secret, variable or repository setting was touched; no database, cloud or collection resource was reached; nothing was re-armed (`DEC-0033` §8; `DEC-0042` §D12). **The only network activity was registry reads downloading the 320 artifacts the frozen lockfile already identifies** — explicitly authorized, and **no publication, no registry mutation, no upgrade lookup used as an implementation input, and no telemetry or config change.** The pnpm update banner was declined. The one write to a hosted system is the branch push and the pull-request creation, accounted for above | `ZERO MUTATION` for external configuration, on that named basis |

> **`HISTORICAL PRE-BREACH STATE` — true when written, incomplete now. Preserved rather than rewritten; the later adjudication is appended at §20.** The sentence as it stood read: **"No breach is recognized by this Author, and the independent Reviewer recorded no verified authorization breach — `DEC-0040` D5 is not engaged (§18)."** **The first half stands unqualified and was never disturbed: this Author caused no breach, and the Product Lead has said so expressly.** The second half was overtaken by events **after** this record's R2 commit — the independent Reviewer itself subsequently committed a verified authorization breach (`G-1`), so **`DEC-0040` D5 IS engaged for the unit**, and the D1 **unit** disposition is a permanent historical **`RED`**. **That is a finding about the Reviewer's conduct inside the governed unit, not about this Author's, and not about the artifact** (§20).

 Three judgment calls are disclosed rather than left for a reviewer to discover: the **temporary in-worktree edit** used to falsify the negation question before relying on it; the **reuse of one authorized worktree path for all three probes** rather than a delete-and-recreate cycle, which the writ permitted provided each use was accounted for; and the **fallback deletion mechanism** — a PowerShell long-path `Remove-Item` — used only after `git worktree remove` failed on a Windows path-length limit, and targeted only at the one authorized directory. Each is recorded above at the point it occurred.

### 17.1 Correction rounds

**Later rounds, same unit, same Product-Lead GO and same canonical base.** This record was produced in R1 and revised in the rounds below. **No round count is written into this sentence** — a further round would falsify one, which is the same self-falsification rule §17 applies to push counts and which R2 had to extend to head SHAs (§10 Probe C). **The canonical base never moved:** every round was authored and pushed against `main` @ `3110acff2225e5a5e8e2c5a5ccfebefaca4ec9ae`, and **no round touched a file outside the four in the write scope above.**

| Round | What it did |
|---|---|
| **R1** | Produced this record and the `pnpm-workspace.yaml` repair, ran the three Author probes, and performed the routing reconciliation in `current-state.md` and `context-map.md`. Within R1, one self-correction was already made and disclosed rather than quietly absorbed: the cleanup account was rewritten once the scripted `git worktree remove` failed on a Windows path limit |
| **R2** | This round, on the independent Reviewer's return of **`ARTIFACT VERDICT = PASS`** with **no verified authorization breach** and **five non-material defects**, plus one completeness gap the Orchestrator raised against the writ. **Write scope: two files — this record and `pnpm-workspace.yaml`.** It (i) **replaced §18** — which R1 left `PENDING — INDEPENDENT REVIEWER` and which would have landed permanently empty in a `FROZEN` record — with the Reviewer's actual reproduction, attributed and not promoted; (ii) **repaired a false head SHA** at §10 Probe C, applying to head SHAs the self-falsification discipline R1 had applied only to counts; (iii) **made the divergence disclosure symmetric** by adding §15 item 2, the absent decision record `D0` §16 anticipated; (iv) **marked or removed three elisions** made under the word *verbatim* at §2 and §10; (v) **narrowed three over-broad negatives** in this table to what their checks actually support, classifying the harness residue `HARNESS / SYSTEM PERSISTENCE OUTSIDE AGENT CONTROL`; (vi) **disambiguated the two senses of "importer"** in the `pnpm-workspace.yaml` comment, the one file a fresh operator consults for the success invariant; and **(vii) repaired the header status line** from *"to be reviewed by a distinct… reviewer"* to *"reviewed by…"*, so the header would not contradict a §18 that had just been filled with a completed review. **`N-2`, repaired in R3: R2 wrote this cell enumerating six edits when it had in fact made seven — the header repair was disclosed in R2's `ROLE RESULT` but omitted from this table, and this table is the surface that lands. The set above is now the actual one.** **No probe was re-run and none was invented** — R2 required no execution. **`current-state.md` and `context-map.md` were deliberately not reopened.** No lockfile, manifest, `.nvmrc`, workflow or `packages/orchestrator` file was touched, the `packages:` list itself was not altered, and the pull request stayed open and unmerged |
| **R3** | **Authorized under a NEW explicit Product-Lead GO**, and the only round carrying a substantive technical extension. Five parts. **(1) `G-2` — governance provenance reconciliation** (§20): this record predates the Reviewer's breach and therefore carried statements that were true when written and incomplete afterwards. They are **preserved and marked `HISTORICAL PRE-BREACH STATE`**, with the later adjudication **appended** — history is not rewritten. **(2) `N-1` and `N-2`** — the §18.5 heading's surviving current-head claim, and this table's incomplete R2 enumeration, both repaired above. **(3) The TypeScript configuration adjudication** (§19), under a Product-Lead scope extension that ruled the original writ's omission of `apps/web/tsconfig.json` a **writ defect rather than an Author failure**. Adjudicated **T1 — ALIGN**; one line added to `apps/web/tsconfig.json`; `apps/web/README.md` deliberately not touched. **(4) The final-head reproducible-install confirmation** (§21). **(5) Routing-document review** (§20.6). **Every R1/R2 statement this work falsified is reconciled in place rather than left standing** — §4, §11, §15 item 1, §17, §18.6 and §18.7. **The workspace decision was not reopened**: OPTION B, pnpm 9.0.0, the Node policy, lockfile byte identity, zero dependency upgrades and the legacy exclusion all stand untouched and independently verified |

**Why this is disclosed rather than omitted.** §17 exists so a later reader can reconstruct what this unit did, and `docs/result/**` is `FROZEN` on landing — anything missing here stays missing. Silent about its own rounds, this record would read as a single-pass unit. It was not one.

### 17.2 R3 mutation increment

**R3 executed, so it carries its own accounting rather than inheriting R1's.**

| Surface | Finding | Class |
|---|---|---|
| **Repository files** | **One new file entered the write scope — `apps/web/tsconfig.json`** — authorized by the Product Lead's explicit R3 scope extension and by nothing earlier, bringing the unit total to **five**. R3 also modified this record, `current-state.md` and `context-map.md`. **`apps/web/README.md` was NOT touched**, so the "one, not both" grant was not consumed at its limit. **No product source, no `packages/orchestrator/**` file, no lockfile, no manifest, no `.nvmrc`, no workflow.** Checked by `git status --porcelain` and by `git diff --name-only` across the branch, which lists exactly five paths | `AUTHORIZED MUTATION` |
| **Worktree** | `C:/Adeptlabs/noxund-d1-r3-validation-author`, added **detached** at `df558694…`, later moved to `684c9af8…` with `git checkout --force --detach`. **`git worktree remove --force` again failed — exit 255, `error: failed to delete '…': Filename too long`** — the same Windows path-length limit R1 hit and the writ anticipated. Completed with the PowerShell `\?\` long-path `Remove-Item`, then `git worktree prune`. **Confirmed absent by `Test-Path` → `False`; `git worktree list` shows only the three pre-existing entries and `.git/worktrees` holds no stale registration** | `AUTHORIZED MUTATION`, created **and** cleaned up |
| **pnpm store** | `C:/Adeptlabs/noxund-d1-r3-pnpm-store-author`, passed via `--store-dir` on **every** R3 install so no shared or default store was written. Deleted by the same long-path removal; `Test-Path` → `False`. **The R1 pair was re-checked in the same operation and both remain absent** | `AUTHORIZED MUTATION`, created **and** cleaned up |
| **Dependency materialization** | **`node_modules` was again NEVER created in the primary checkout.** All three trees existed only inside the R3 worktree and died with it | **`ZERO MUTATION` in the primary checkout**, on that named basis |
| **Temp, cache, sidecar, backup** | One `apps/web/tsconfig.tsbuildinfo`, written by `tsc` inside the R3 worktree because `incremental: true` is set; **deliberately deleted twice before typechecking** so that neither green result could be a cached pass, and destroyed with the worktree. Gitignored at `.gitignore:27`. **No other temp, backup or sidecar file anywhere** | `AUTHORIZED MUTATION` within the authorized worktree |
| **The preserved breach evidence** | `wsp_46d83d4b….yaml` and `wsp_df558694….yaml` under system temp. **Confirmed present by directory listing at the start and at the end of R3 — identical sizes and identical `2026-08-22 02:14:18` timestamps.** **Not deleted, edited, renamed, moved, recreated or opened** | **`PRESERVED — NOT THIS AUTHOR'S TO DISPOSE OF`**; untouched |
| **`/tmp` and system temp** | **No command this round issued wrote there.** The one interaction with system temp was the **read-only listing** above. **The `>` redirection hazard that caused `G-1` was specifically guarded against**: every comparison in R3 used shell variables and `diff <(…) <(…)` process substitution, and **no `>`, `>>`, `tee`, `-o`, `--output`, `mktemp` or file-landing heredoc was used at any point** | **`ZERO MUTATION` for this unit's own acts**, on that named basis |
| **Session scratchpad** | **Still empty at path level** — `find … -type f` returns **`0`**, re-checked after R3's work. No scratch file, helper script or PR-body file; the PR body was passed inline in R1 and commit messages via stdin | `ZERO MUTATION`, on that named basis |
| **Memory files** | **None written.** `C:/Users/Miguel/.claude/…` was not written to by this round; the harness housekeeping paths named in the main table remain outside this agent's control | `ZERO MUTATION` for memory content · harness paths `HARNESS / SYSTEM PERSISTENCE OUTSIDE AGENT CONTROL` |
| **External mutable systems** | **Zero configuration writes.** Network activity was registry reads for the artifacts the frozen lockfile already identifies. **No workflow, ruleset, required check, `CODEOWNERS`, Environment, secret or repository setting; no database or cloud resource; nothing re-armed.** `docs/agents/product-orchestrator-agent.md` **not edited**; Phase C **not reopened**. The only hosted writes are commits pushed to the existing branch and PR #95, **which stays open and unmerged** | `ZERO MUTATION` for external configuration, on that named basis |

**No breach is recognized by this Author in R3.** One judgment call is disclosed: the **temporary in-worktree edit to `apps/web/tsconfig.json`** used to capture the `tsc --showConfig` "before" and "after" states, applied and reverted twice inside the authorized worktree before the change was made in the primary checkout. It touched no file outside that worktree.

---

## 18. Reviewer reproduction — the independent Reviewer's own record

**Transcribed, not authored here.** Everything in this section is what the **distinct task-scoped independent Reviewer** reported on returning from its own round. **It is the Reviewer's evidence, not the Author's**, it is set down as the Reviewer stated it, and it is **not promoted a step beyond that**. R1 left this section `PENDING — INDEPENDENT REVIEWER`, which was correct only while no reviewer existed; one now has, and `docs/result/**` lands `FROZEN`, so leaving it pending would have permanently omitted content the writ requires.

### 18.1 Independence — held in three functions, and one limitation not softened

The Reviewer held **all three required review functions** — independent technical/toolchain, independent reproducibility, and independent governance/scope — under `DEC-0037` D5 and D8, and is **distinct from this Author**.

> **The Reviewer expressly did NOT claim principal independence, and it is recorded here at full strength rather than smoothed.** **`TECHNICAL PRINCIPAL: UNKNOWN / NOT INDEPENDENT`** — the review ran on the **same machine** and under the **same GitHub credential** as this Author. `DEC-0037` D7.7 and D12 forbid representing that arrangement as principal independence. **Function independence was satisfied; principal independence was not**, and nothing in this section should be read as supplying it.

### 18.2 The Reviewer's own surfaces, and the isolation between them and the Author's

- Detached worktree `C:/Adeptlabs/noxund-d1-install-validation-reviewer`, with store `C:/Adeptlabs/noxund-d1-pnpm-store-reviewer` passed via `--store-dir` on **every** install.
- **The Author's store was never used, read or touched** — so the Reviewer's install downloaded its own closure rather than inheriting a warm store from the unit under review.
- **`node_modules` was never materialized in the primary checkout**; the four pre-existing trees there were untouched and **not used as evidence**.
- Both surfaces **created and cleaned up**. Afterwards `git worktree list` shows only the three pre-existing entries, and `.git/worktrees` holds **no stale registration**.

### 18.3 Environment, measured inside the Reviewer's worktree

`node --version` → **`v24.15.0`** · `pnpm --version` → **`9.0.0`** (exact — **the declared `packageManager` contract is what executed**) · `corepack --version` → **`0.34.6`**.

### 18.4 Probe A, unmodified canonical base `3110acff…` — reproduced as failing

`pnpm -r list --depth -1` returned **four** projects, including `@noxund/orchestrator@0.0.0`. The §9 command exited **`1`**:

```
ERR_PNPM_OUTDATED_LOCKFILE  Cannot install with "frozen-lockfile" because pnpm-lock.yaml is not up to date with packages\orchestrator\package.json
specifiers in the lockfile ({}) don't match specs in package.json ({"@types/node":"^20.19.0","typescript":"^5.7.3"})
```

Lockfile sha256 and git blob **unchanged**; `git status --porcelain` **empty**; **no `node_modules` created**.

### 18.5 Probe B, at commit `46d83d4b87c180b69eea3b61ddc197e3b25a519e` — reproduced as passing

**This is the head-state verification no Author probe in this record supplies** (§10 Probe C). `46d83d4b…` was the branch head **at the time of that review**; consistent with §10's correction, it is **not asserted to be the final head**.

- `pnpm -r list --depth -1` → **three** projects: `noxund`, `web`, `@noxund/shared`
- `pnpm list -r --depth -1 --json | grep -c orchestrator` → **`0`**
- the §9 command exited **`0`** — `Scope: all 3 workspace projects` / `Lockfile is up to date, resolution step is skipped` / `Packages: +320` / `Done in 39.5s`
- lockfile **sha256 `9f013355c771fb6dcc5bea6266e75082e4c79f9234372c0fab6a274d0761d326`** and **blob `e183bdc8be1eec284cb0abc7f80b5e49bc55b589`**, **identical before and after**
- `git status --porcelain` **empty**; ignored set exactly the three expected `node_modules` trees; **`packages/orchestrator/node_modules` absent**

### 18.6 What the Reviewer re-derived rather than accepted

- **pnpm 9.0.0 negation support was independently verified by the Reviewer's own execution** — **not** accepted on this Author's word. This matters more than the other items, because it is the single empirical premise the selected workspace disposition rests on (§3).
- **Both typechecks reproduced at exit 0**, and the Reviewer independently confirmed that the `apps/web` pass **genuinely runs against the weak local `tsconfig.json`** — so the caveat at §11 and §15 item 1 is **correct and necessary**, not defensive hedging. **This finding is what the Product Lead's R3 scope extension acted on, and R3 removed its cause** (§19) — the Reviewer's corroboration is therefore preserved as the evidence that justified the repair, not withdrawn by it.
- **The `engines.node` table at §6 matches the Reviewer's own closure exactly** — `eslint@9.39.4` and `@eslint/eslintrc@3.3.5` → `^18.18.0 || ^20.9.0 || >=21.1.0`; `next@15.5.19` → `^18.18.0 || ^19.8.0 || >= 20.0.0`; `typescript@5.9.3` → `>=14.17`.
- **The install-lifecycle inventory at §13 matches exactly** — `sharp@0.34.5` and `unrs-resolver@1.12.2`, and no others.

### 18.7 The Reviewer's verdict, and the boundary on it

> **`ARTIFACT VERDICT = PASS`**, scoped to the four-file diff, this record, the toolchain outcome at the candidate head, and the unit's authorization boundary and mutation accounting. **No verified authorization breach — `DEC-0040` D5 not engaged.** **Five non-material defects**, all repaired in R2 and listed at §17.1.

> **`HISTORICAL PRE-BREACH STATE`, preserved verbatim above and qualified here rather than rewritten.** The Reviewer's *"no verified authorization breach"* was a finding **about the review target — this Author's conduct** — and **as such it still stands.** It was **not** a statement about the Reviewer's own subsequent conduct, which at the time had not occurred: this section was authored in the R2 commit `df558694…` at **02:11:13**, and the breach artefacts were created at **02:14:18**, roughly three minutes later. **The record was accurate when written and is incomplete now**, which is precisely why it is qualified and not deleted. **`DEC-0040` D5 is now engaged for the unit** — see §20. **The `ARTIFACT VERDICT = PASS` is unaffected and survives** (`DEC-0040` D14), and the Product Lead has explicitly accepted the unit/artifact separation (§20.4).

**On the material question the Reviewer was asked** — whether any material toolchain incoherence remains unresolved — the Reviewer answered **yes, one: `apps/web/tsconfig.json`**, and judged it **correctly deferred as outside the writ, honestly recorded, genuinely untouched, and requiring its own Product-Lead routing** (§15 item 1). **That routing then happened:** the Product Lead extended scope explicitly, and **R3 resolved the one material incoherence the Reviewer identified** (§19). **The Reviewer's judgement is not overturned by this — it is discharged.** By contrast the Reviewer classified the `engines.node` `>=20` versus `^20.9.0` gap as a **correctly-deferred item and not a material incoherence** — enforced by nothing (no `.npmrc` anywhere), avoided by `.nvmrc` `20` resolving to the newest 20.x, and **tightening it without a demonstrated failure mode would violate `DEC-0042` §D6** (§15 item 6).

### 18.8 The Reviewer's own `UNPROVEN` / `UNKNOWN` set

Recorded because a reviewer's limits bound its verdict: **Node 20 specifically** · **scripts-enabled install** · **Linux closure identity** · **`next build` / `next lint`** · **live GitHub ruleset and workflow configuration** — not re-derived, on the ground that no committed change touches `.github/**` · and **this Author's execution process itself**, which the Reviewer classified `REPORTED` while reproducing every outcome it produced.

### 18.9 The classification discipline this section does not relax

> **Reviewer `VERIFIED` is still not `ACCEPTED`.** `DEC-0040` D3 keeps the classes distinct, and **`ACCEPTED` is the Product Lead's word alone** — reached only after the applicable gates, and never by an Author transcribing a reviewer, nor by a reviewer's `PASS`. **`ARTIFACT VERDICT` is Axis D and settles no unit disposition** (Axis C), which is the independent governance function's to state and the Product Lead's to ratify (`DEC-0040` D4, D6, D18). **This Author states neither.**

---

## 19. TypeScript configuration adjudication — R3, under a Product-Lead scope extension

**Authorization, stated first because it is the whole reason this section exists.** R1 and R2 left `apps/web/tsconfig.json` untouched and routed it, because the original `D1` writ did not authorize it. **The Product Lead has since ruled that omission a writ defect rather than an Author failure**, and extended scope explicitly to adjudicate the discrepancy across `apps/web/tsconfig.json`, `apps/web/README.md` and `tsconfig.base.json`, with **mutation granted to one of the first two, not both.** All three files were re-read and every fact below re-derived at this base.

### 19.1 The discrepancy, stated exactly

| Source | What it asserts | Class |
|---|---|---|
| `apps/web/README.md:27` | *"`tsconfig.json` deve estender `../../tsconfig.base.json`"* — normative language, under a heading *"Restrições (ver docs/agents/)"* | `VERIFIED` |
| `apps/web/tsconfig.json` | **declares no `extends` key at all** | `VERIFIED` |

**They contradict each other, and exactly one of them had to be corrected.** `D0` §10.2 row 1 classified this `VERIFIED` and named the consequence: *"The one surface a root command can reach runs the weakest settings; the two packages carrying the strict settings are unreachable from root."* The independent Reviewer, asked whether any material toolchain incoherence remained, named **this and only this** (§18.7).

### 19.2 Which representation is coherent with the active architecture

**The instruction was not to trust `deve`, and not to trust a passing typecheck. Both were tested.**

1. **Every other TypeScript workspace extends the base.** `packages/shared/tsconfig.json` and `packages/orchestrator/tsconfig.json` both open with `"extends": "../../tsconfig.base.json"`. **`apps/web` — the sole `ACTIVE PRODUCT` surface — is the only one that does not.** `VERIFIED`.
2. **`tsconfig.base.json` is a pure base, useless unless extended.** It carries no `include` and no `files`; it exists solely to be inherited. `VERIFIED`.
3. **A second, independent document says apps extend it too.** `docs/foundation/monorepo-structure.md:30` annotates the file *"Config TS base (apps/packages estendem)"* — **`apps`, not only `packages`.** This matters because it is not the same document as the README, so the requirement is not one stray line. `VERIFIED`.
4. **The current file is unreconciled scaffold output, not a considered standalone design.** Its contents are the stock `create-next-app` template — `target: ES2017`, `lib: ["dom","dom.iterable","esnext"]`, `allowJs`, `jsx: preserve`, `plugins: [{"name":"next"}]`, `paths: {"@/*": ["./src/*"]}`, and an `include` naming `next-env.d.ts`. **`apps/web/README.md:20` documents the very command that produced it.** **Nothing in the tree records a decision to keep it standalone.** `VERIFIED`.
5. **What does NOT support the requirement — recorded because it cuts against the case and omitting it would be dishonest.** The README's own pointer, *"ver docs/agents/"*, **does not resolve**: a search of `docs/agents/` returns no `extends` or `estender` constraint. And `DEC-0001` §3, which names *"`tsconfig.base.json` compartilhado"* as a foundation element, is **`DRAFT / PROPOSED` and binds nothing** under `DEC-0035` §3.2 and §9. **There is therefore NO landed `INTERNAL-NORMATIVE` record requiring the `extends`.** `VERIFIED`.

> **What item 5 changes, and what it does not.** It removes any claim that a binding decision record compels T1 — none does, and none is invented here. **It does not rescue T2**, because the question is not *"is inheritance mandated"* but *"which of two contradictory representations is coherent with the active architecture"*. On that question items 1–4 point one way and item 5 is silent.

### 19.3 The adjudication

| Option | Disposition | Ground |
|---|---|---|
| **T1 — ALIGN** | **SELECTED** | The config was the untrue half. Inheritance is what every sibling does, what the base exists for, and what two independent documents describe. The change is **one line**, adds only strictness, and **makes the existing README statement true without editing it** |
| **T2 — DECLARE STANDALONE** | **REJECTED** | It required proving the active web surface **should not** inherit the shared strictness contract. **No such evidence exists** — not a decision record, not a comment, not a README line, not a workflow. The only affirmative evidence about intent points the other way. **T2 would also have required editing `apps/web/README.md` to make a constraint false**, weakening documentation to match an unreconciled scaffold. **It was not chosen merely because it avoids change, and it was not chosen at all** |
| **T3 — other minimal reconciliation** | **NOT REACHED** | Available only if T1 and T2 were both technically wrong. **T1 is technically right** — §19.4 and §19.5 establish it by measurement rather than argument |

**Files mutated: exactly one — `apps/web/tsconfig.json`.** `apps/web/README.md` was **not** touched, so the "one, not both" grant is satisfied with room to spare. **`tsconfig.base.json` was read and not modified.** **No product source under `apps/web/src/` was touched.**

**Explicitly not repaired here:** `apps/web/README.md:3`'s stale *"placeholder. Não scaffoldado ainda"* status line. It is a `D0` §10.2 row 2 finding **routed to `D3`**, it is **not entailed by T1** — which touches no README — and it is left standing.

### 19.4 Effective-configuration delta — measured with `tsc --showConfig`, not reasoned about

Captured **before and after** inside the authorized isolated worktree, parsed, and compared as key sets rather than eyeballed as text — the raw textual diff is dominated by key reordering, which would have hidden the real answer.

```
=== compilerOptions ADDED by extends ===
  + declaration                      = true
  + forceConsistentCasingInFileNames = true
  + noImplicitOverride               = true
  + noUncheckedIndexedAccess         = true
  + verbatimModuleSyntax             = true
=== compilerOptions REMOVED ===          (none)
=== compilerOptions CHANGED IN VALUE === (none)
=== file set identical? ===  before=4 after=4 identical=True
=== include/exclude ===
  include  before=["next-env.d.ts","**/*.ts","**/*.tsx",".next/types/**/*.ts"]  after=(identical)
  exclude  before=["node_modules"]                                             after=(identical)
```

**Five options added. Nothing removed. Nothing changed in value. The program's file set is the same four files.**

**The two named hazards, both tested rather than assumed — and both neutralized by overrides the child already carried:**

| Hazard | Outcome | Why |
|---|---|---|
| Inheriting the base's `lib: ["ES2022"]` would **strip DOM types** | **DID NOT OCCUR** | the child declares its own `lib`, and `lib` is replaced by the child rather than merged. Effective `lib` unchanged |
| Inheriting the base's `exclude`, which lists **`.next`**, would drop `.next/types/**/*.ts` because **`exclude` beats `include`** | **DID NOT OCCUR** | the child declares its own `exclude: ["node_modules"]`, replacing the parent's entirely. **Proven by the file set being identical** — the direct observable, not inferred from the merge rule |

**`declaration: true` alongside `noEmit: true` is accepted by TypeScript 5.9.3.** This needed no speculation: **`packages/shared` has shipped exactly that pairing since before this unit**, extending the same base and setting `noEmit`, and its typecheck passes. The R3 run confirms it again at exit 0.

**`target` stays `ES2017`** — the child keeps its own, as a Next.js app legitimately may. **`jsx`, `incremental`, `plugins`, `paths` and `allowJs` are untouched. No unrelated compiler option was normalized.**

### 19.5 Typecheck under T1 — verbatim

Run **only inside the authorized isolated worktree**, never in the primary checkout.

```
$ find apps/web -maxdepth 1 -name "*.tsbuildinfo" -print -delete
(nothing listed — no stale incremental cache existed, so this was a FULL check)

$ pnpm --filter web typecheck
> web@0.0.0 typecheck C:/Adeptlabs/noxund-d1-r3-validation-author/apps/web
> tsc --noEmit
EXIT_CODE=0
```

**Zero type errors.** The stale-cache deletion is recorded because `incremental: true` makes a green run meaningless if a prior `.tsbuildinfo` is reused; **none existed, and the check was full.**

**Control, run to show the change is confined:** `pnpm --filter @noxund/shared typecheck` → **exit 0**, unchanged.

> **The `HOLD` branch was real and is not glossed over.** Had T1 produced type errors, **no product-source fix was authorized** and the honest return would have been `HOLD`. **It produced none**, so the question of whether such errors would have invalidated T1 or exposed a deeper defect **does not arise** — recorded so a reader can see the branch existed rather than assuming a clean result was the only possible outcome.

### 19.6 What T1 does NOT establish

- **`next build` and `next lint` under the new configuration** — `UNPROVEN`. `next build` is forbidden to this unit and was not run. The five added options are type-checking options and `noEmit` is set, so no emit path is exercised by them — **but that is reasoning, not evidence.**
- **Whether Next.js would rewrite `tsconfig.json` on a future `next dev` or `next build`** — `UNPROVEN`. Next normalizes tsconfig against the **effective** configuration, and every option Next requires is already declared explicitly in the child, so nothing is obviously missing for it to add. **Not verified, because verifying it requires running Next.**
- **That no landed normative record compels the `extends`** — established at §19.2 item 5 and **not** papered over.

### 19.7 Does T1 falsify any load-bearing `D1` fact?

**No — checked deliberately, because the instruction was to stop and say so if it did.** `apps/web/tsconfig.json` is **not** a pnpm workspace declaration, does **not** appear in `pnpm-lock.yaml`, and carries **no** dependency, engine or package-manager constraint. The workspace disposition, lockfile byte identity, Node policy, pnpm policy and legacy exclusion are **all untouched**, and §21 re-confirms the install outcome after this change. **Nothing in §3 through §14 is reopened.**

---

## 20. Governance provenance — `G-2`

**Every ruling in this section is the Product Lead's, and every verdict is a reviewer's. None is this Author's, and none is restated as though it were.**

### 20.1 Why this section exists

This record was written across R1 and R2. **The R2 commit `df558694b2a5242cbf6af6c6e50c6f4bb86c3e45` is timestamped `2026-08-22 02:11:13 -0300`.** After it, the independent Reviewer committed a verified authorization breach. **The record was therefore accurate when written and incomplete afterwards** — and `docs/result/**` lands `FROZEN`, so statements such as §18.7's *"No verified authorization breach"* must not land unqualified. **They are preserved, marked `HISTORICAL PRE-BREACH STATE`, and the adjudication is appended. Nothing is silently rewritten** — the disposition the fresh independent governance reviewer ruled permissible.

### 20.2 What happened, as adjudicated

| Finding | What it is | Classification | Lifecycle |
|---|---|---|---|
| **`G-1`** | The independent **Reviewer** intentionally created **two files under system temp, outside its `write_scope`**, via a stray shell redirection left in a command from an earlier draft | **`UNAUTHORIZED MUTATION`** (`DEC-0040` D13) | **`CLOSED — REMEDIATED`** |
| **`G-1b`** | The Reviewer **recognized the breach contemporaneously but did not immediately stop substantive execution** — approximately **fourteen further read-only review operations** followed before stop and escalation. **No further mutation occurred** | procedural | **`CLOSED — REMEDIATED`** |

**The Reviewer self-reported, did not delete the files, and they are preserved.** **`DEC-0040` D13 is satisfied in the respect that matters most**: cleanup is never retroactive authorization, and **deleting the evidence would have compounded the breach** exactly as it did in `C0`. **Not deleting was the correct act.**

### 20.3 The unit disposition, and what closure does not do

> **`PHASE-D-D1-…-R1` UNIT GOVERNANCE DISPOSITION = `RED — VERIFIED AUTHORIZATION BREACH`. Historical and PERMANENT. It must never be rewritten to `PASS`.**

`DEC-0040` D5 is unconditional — *"`ANY VERIFIED AUTHORIZATION BREACH IN A GOVERNED UNIT => UNIT RED`"* — and the breach occurred **inside the governed unit**, so the unit is `RED` even though the breaching participant was not the Author.

> **`CLOSED — REMEDIATED` never rewrites a historical `RED`** (`DEC-0040` D7). Both findings are closed **and** the `RED` stands. They are different axes, and collapsing them is what `DEC-0040` D1 prohibits.

**The Product Lead has stated that this Author caused no breach.** That is recorded because it is the Product Lead's finding — **not** as a defence this Author is entitled to mount on its own behalf — and it does not soften the unit `RED` by one degree.

### 20.4 Unit versus artifact — the separation, and who accepted it

> **`UNIT DISPOSITION ≠ ARTIFACT VERDICT`** (`DEC-0040` D6). **The technical `ARTIFACT VERDICT = PASS` survives**, and the **Product Lead has explicitly accepted the unit/artifact separation** — `DEC-0040` D14 condition 7, which requires express acceptance in the record and is **never** satisfied by silence or by proceeding.

The grounds the Product Lead recorded for non-contamination (D14 condition 3), each a matter of sequence and fact rather than judgement:

- the temp files were created at **`02:14:18`**, **after** the R2 artifact commit at **`02:11:13`** — the artifact could not have been influenced by them;
- they were **never read as evidence** and **contributed no bytes** to this record;
- they **altered no repository, dependency or external state**;
- the adjacent technical conclusion was **independently re-derived without them**.

> **This is not artifact ratification.** `DEC-0040` D14 condition 8 is separate from condition 7, and **accepting a separation is not accepting an artifact**. **Ratification remains the Product Lead's manual merge of PR #95** (`DEC-0037` D11), after this round passes independent review. **Nothing in this record advances that step, and this Author cannot.**

### 20.5 The preserved evidence — untouched

The two files sit at the Windows system-temp location, named `wsp_46d83d4b….yaml` and `wsp_df558694….yaml`. **This Author did not delete, edit, rename, move, recreate or open them.** Their existence and timestamps were confirmed by a **directory listing only** — both `2026-08-22 02:14:18`, independently corroborating the sequence at §20.4. **Their cleanup is not required for `D1` completion and no task is authorized to dispose of them.** Inert preserved process evidence.

### 20.6 Routing documents, and `O-1` / `O-2`

**`current-state.md` and `context-map.md` were reviewed in R3 against the landing semantics** — `D1` technical objective COMPLETE, historical unit `RED`, findings `CLOSED — REMEDIATED`, artifact `PASS`, `D2` NOT AUTHORIZED. The outcome is recorded at §21.3. **They are deliberately NOT loaded with incident detail: this record is the canonical provenance surface, and they route to it.**

**`O-1` and `O-2` are recorded as `ROUTED — NONBLOCKING GOVERNANCE AUTHORITY MAINTENANCE`** for a future **separately authorized** unit. **`docs/agents/product-orchestrator-agent.md` was not edited and Phase C was not reopened.**

The Product Lead's interpretation applied for `D1` purposes, **recorded as the Product Lead's and not as a repository rule this Author derived**:

> *A breaching participant must immediately stop and report a `RED`-triggering authorization breach condition; it does not self-ratify the final Axis-C unit disposition. The independent governance function establishes the formal unit disposition.*

**This is why `G-1b` is a finding at all**: the stop obligation attaches at recognition, not at convenience. **Naming `O-1` and `O-2` places them and authorizes nothing** (`DEC-0033` §8; `DEC-0040` D8).

---

## 21. Final reproducible-install confirmation — R3

**Purpose.** To confirm that the `apps/web/tsconfig.json` change of §19 disturbs nothing the earlier rounds established. **This is a confirmation, not a new design round**, and it reopened no decision.

### 21.1 Where it ran, and the wording that cannot be falsified by a later round

It ran at commit **`684c9af85e58caab7196ba317aed9cda6c885ad6`**, in the authorized isolated worktree, on the same `9.0.0` / `v24.15.0` toolchain measured inside it.

> **That commit is NOT asserted to be the branch head.** §10 Probe C had to be repaired in R2 for exactly that error, and the principle it established governs here: **a `FROZEN` record cannot name its own head, because the commit that records the naming displaces it.** `684c9af8…` was the head **when this confirmation ran**; the commit carrying this section necessarily follows it.
>
> **Why the confirmation nonetheless holds at whatever the head is** — by construction rather than by assertion. **Every commit after `684c9af8…` on this branch modifies this result record and nothing else.** No manifest, no lockfile, no `pnpm-workspace.yaml`, no `tsconfig`, no `.nvmrc` — **no input pnpm or `tsc` reads**. A reader can verify that claim directly with `git diff --name-only 684c9af8..HEAD`, which is a check on the landed tree rather than a promise from this Author.

### 21.2 Result — every required invariant

| Requirement | Observed | Class |
|---|---|---|
| **exactly the intended active workspace** | `pnpm -r list --depth -1` → **three**: `noxund`, `web`, `@noxund/shared`. `pnpm list -r --depth -1 --json \| grep -c orchestrator` → **`0`** | `VERIFIED` |
| **`pnpm install --frozen-lockfile --ignore-scripts` exits 0** | `Scope: all 3 workspace projects` / `Lockfile is up to date, resolution step is skipped` / `Already up to date` / `Done in 637ms` · **`EXIT_CODE=0`** | `VERIFIED` |
| **`pnpm-lock.yaml` byte-identical** | sha256 `9f013355c771fb6dcc5bea6266e75082e4c79f9234372c0fab6a274d0761d326` and blob `e183bdc8be1eec284cb0abc7f80b5e49bc55b589` — **identical before and after, and equal to the canonical-base values** | `VERIFIED` |
| **`packages/orchestrator/**` untouched** | tree object **`7457f3f259ce8987e74ebe9f3db48172eabbd02b`**, unchanged from the canonical base; `git diff --stat base..candidate -- packages/orchestrator` **empty**; **no `packages/orchestrator/node_modules` materialized** | `VERIFIED` |
| **tracked tree clean** | `git status --porcelain` **empty**; ignored set is the three `node_modules` trees plus the expected `apps/web/tsconfig.tsbuildinfo` | `VERIFIED` |

**`Already up to date` rather than a re-resolution** additionally shows the install was idempotent against the R3 store: the `tsconfig` change altered no dependency input, which is the point of the confirmation.

**Both typechecks re-run at this same commit, with the incremental cache deleted first so neither was a cached pass:** `pnpm --filter web typecheck` → **exit 0** (now against the inherited strict settings), `pnpm --filter @noxund/shared typecheck` → **exit 0**.

### 21.3 Routing documents

`current-state.md` and `context-map.md` were **reviewed against the landing semantics and updated minimally**, because both described `D1` in terms that R3 makes incomplete. Each now records that the **technical objective is COMPLETE** while the **unit disposition is a permanent historical `RED`**, that findings are **`CLOSED — REMEDIATED`**, that the **artifact verdict is `PASS`** on a separate axis, that **ratification has not occurred**, and that **`D2` remains NOT AUTHORIZED and NOT STARTED**. **Neither carries incident detail** — they route here, which is the canonical provenance surface (§20).

### 21.4 Branch surface

**Five repository files changed across the whole unit**, and no others: `pnpm-workspace.yaml` · `apps/web/tsconfig.json` · this record · `current-state.md` · `context-map.md`.

---

*Current state is owned by [`current-state.md`](../product/current-state.md); routing by [`context-map.md`](../product/context-map.md); classification and precedence by [`DEC-0035`](../product/decisions/DEC-0035-canonical-context-v2-authority-lifecycle-supersession-model.md); the Phase-D charter is [`DEC-0042`](../product/decisions/DEC-0042-engineering-quality-phase-charter.md), and the baseline this unit executes against is [`PHASE-D-D0-ENGINEERING-QUALITY-BASELINE-R1`](PHASE-D-D0-ENGINEERING-QUALITY-BASELINE-R1.md).*
