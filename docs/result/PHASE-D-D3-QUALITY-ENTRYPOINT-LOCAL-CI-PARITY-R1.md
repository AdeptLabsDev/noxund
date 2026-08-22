# PHASE D — `D3` Quality entrypoint and local/CI parity · R1

**Unit:** `PHASE-D-D3-QUALITY-ENTRYPOINT-LOCAL-CI-PARITY-R2`
**Artifact revision:** `R1` — the first substantive `D3` artifact. The unit
attempt number and the artifact revision are **different counters**, and the
landed `D2` record is the precedent: its unit attempt was `R2` and its landed
file is `-R1.md`.
**Class:** `DESCRIPTIVE-CURRENT` — an entrypoint-and-parity record for a
**mutating** unit. **Not** a phase closeout, **not** a decision record. **It
creates no authority and `D3` lands no `DEC-00NN`.**
**Authority executed:** [`DEC-0042`](../product/decisions/DEC-0042-engineering-quality-phase-charter.md),
under the Product Lead's own explicit `D3` GO, which expires with this unit.

> **This record states no unit disposition and no artifact verdict.** Both are
> void from an Author ([`DEC-0040`](../product/decisions/DEC-0040-governed-result-disposition-closeout-contract.md) D11).
> **`AUTHOR PASS = REPORTED, NOT ACCEPTED`.** An independent Reviewer
> adjudicates this work, and ratification is the Product-Lead merge.

---

## 1. Canonical base

| Fact | Value | Class |
|---|---|---|
| `origin/main` at start | `5dba1130ad894013da76fa64a7b994b172a97f00` | `VERIFIED` — `git rev-parse origin/main` after `git fetch --prune`, cross-checked against the GitHub branches API, which returned the identical SHA and `protected: true` |
| Working tree at start | clean | `VERIFIED` — `git status --porcelain` empty |
| What that base is | the two-parent merge of PR #96, landing `D2` | `VERIFIED` — `git log --oneline` |
| Branch | `chore/phase-d-d3-r2-quality-entrypoint-local-ci-parity`, created fresh from `origin/main` | `VERIFIED` |

**A stale local branch from the `R1` attempt exists** — `chore/phase-d-d3-quality-entrypoint-local-ci-parity`, sitting at the canonical base with **zero commits of its own**. It was **not used, not deleted, not renamed and not pushed**. Its existence is recorded here so nobody mistakes it for this unit's work.

---

## 2. The `D2` landed precondition

`D0` §16 makes `D2` the declared prerequisite of `D3`. It is landed, and this unit re-derived the parts it depends on rather than inheriting them:

| Precondition | Observation | Class |
|---|---|---|
| `js-ts-quality.yml` exists on `main` and is the JS/TS signal | present, one `typecheck` job | `VERIFIED` |
| Root `typecheck` observed only `web` | root script read `pnpm --filter web typecheck` | `VERIFIED` |
| CI separately invoked `web` and `@noxund/shared` | two distinct workflow steps, each a direct package-script call | `VERIFIED` |
| `D2` §15 handed `D3` an unrepaired defect, deliberately | *"That is a workaround inside the workflow, not a repaired entry point"* | `VERIFIED` — quoted from the landed record |
| `D2` Q3 answers must not be reopened | both surfaces `BEHAVIORAL TEST SUITE NOT JUSTIFIED ON CURRENT SURFACE` | `VERIFIED`, and **not reopened by this unit** |

---

## 3. `D3` attempt `R1` — historical, and preserved as such

> **`D3` attempt `R1` terminated before implementation as `RED — VERIFIED AUTHORIZATION BREACH`. `D3-G-1` was later `CLOSED — REMEDIATED` after independent governance review and Product-Lead adjudication. No `D3` `R1` technical artifact existed.**

Stated exactly, because the two facts are routinely collapsed and must not be:

- The `R1` Author created a file outside the exhaustive write scope, in system temp, while preparing mutation accounting. Independent governance review verified the occurrence.
- **Closure does not rewrite `R1` `RED`** ([`DEC-0040`](../product/decisions/DEC-0040-governed-result-disposition-closeout-contract.md) D7). The historical disposition is permanent.
- **No substantive `D3` implementation occurred in `R1`.** It produced no branch, no pull request, no CI run, no repository mutation and **no reusable technical conclusion**. This unit re-derived everything from canonical main and inherited nothing from it.
- The preserved `R1` file is `PRESERVED PROCESS EVIDENCE · NO CURRENT CLEANUP REQUIRED`. This unit did **not** delete, edit, rename, move, recreate or cite it as evidence. **Its continued presence does not contaminate `R2`.**

> **Do not read this section as saying the `D3` technical artifact is `RED`.** It says the `R1` **unit** carries a historical `RED`. `UNIT DISPOSITION ≠ ARTIFACT VERDICT` ([`DEC-0040`](../product/decisions/DEC-0040-governed-result-disposition-closeout-contract.md) D6).

---

## 4. Active and relevant surface matrix

Re-derived at this base, not copied forward. Standings are `DEC-0042` §D4's four.

| Surface | Standing | `D3` treatment |
|---|---|---|
| `apps/web/**` | `ACTIVE PRODUCT` | canonical entrypoint + documentation repair |
| `services/data-engine/src/**`, its tests | `ACTIVE PRODUCT` | canonical entrypoint + documentation repair |
| `packages/shared/**` | `ACTIVE-BUT-UNREACHED` | made coherent — reached by the canonical entrypoint, documentation repaired. **No machinery built around it** |
| `tools/governance/**` | `ACTIVE TOOLING` | canonical entrypoint |
| `infra/postgres/**` | `ACTIVE TOOLING · LOCAL ONLY` | **documented truthfully; not modified; no CI created** — §10 |
| `.github/workflows/**` | `ACTIVE TOOLING` | three workflows edited **only** to invoke canonical entrypoints |
| `packages/orchestrator/**` | `LEGACY / NON-AUTHORITATIVE` | **zero investment.** Not typechecked, not tested, not linted, not edited. **EXCLUDED IS NOT REMOVED** |
| `supabase/**` | `HISTORICAL / PRESERVED` | **zero investment, zero edits** |

---

## 5. The pre-`D3` entrypoint / parity matrix

The state this unit found, per surface. **This is the BEFORE side of every claim below.**

| Surface | Existing developer command | Existing CI command | Logic duplicated in YAML? | Docs named it? | OS-specific transcription? |
|---|---|---|---|---|---|
| `apps/web` | root `pnpm typecheck` → `pnpm --filter web typecheck` | `pnpm --filter web --fail-if-no-match typecheck` | **YES** — CI encoded its own invocation because the root script was insufficient | README said the package was an unscaffolded placeholder and named **no** quality command | no |
| `packages/shared` | **NONE reachable from root.** A working package script that no root command invoked | `pnpm --filter @noxund/shared --fail-if-no-match typecheck` | **YES** | README said *"placeholder. Não scaffoldado ainda"* and named **no** quality command | no |
| `services/data-engine` unit suite | README gave a PowerShell-only transcription setting `PYTHONPATH` then calling `unittest discover` | inline shell loop: ×2, count-asserted | **YES — wholly.** The count, the repetition and the assertions existed **only** in YAML | README named a command, but a **different, weaker** one — no ×2, no count assertion | **YES** — the README block was PowerShell-only |
| `services/data-engine` repro harness | not documented anywhere | inline shell loop: ×2, count-asserted | **YES — wholly** | **NO** | n/a |
| `services/data-engine` golden digest | not documented anywhere | a long inline `python -c` one-liner under `PYTHONPATH: src:tests` | **YES — wholly** | **NO** | **YES** — `:` is POSIX-only and **fails on Windows** |
| collection-driver contract | not documented anywhere | hash-pinned `pip install` + version assertion | n/a — it *is* the contract | **NO** | no |
| `tools/governance` | not documented anywhere | inline shell: count-asserted at 40 | **YES — wholly** | **NO** | no |
| `infra/postgres` | `infra/postgres/scripts/*-local` | **none — no CI exists** | n/a | **YES** — its own README documents them | n/a (bash + WSL 2 by design) |

> **Five of eight rows had their substantive quality logic living only inside workflow YAML.** That is the exact condition `D0` §16 assigned to `D3`, and `DEC-0042` §D17 condition 4 requires be closed or recorded as an accepted limitation.

---

## 6. Selected entrypoints

### 6.1 JS/TS — root `pnpm typecheck`

Root `package.json` `typecheck` now reads, in full:

```
pnpm --filter web --fail-if-no-match typecheck && pnpm --filter @noxund/shared --fail-if-no-match typecheck
```

**Why this shape and not another.** It is **two separate, individually-required invocations**, each naming one package literally and each carrying its own `--fail-if-no-match`. It is **deliberately not** a union or multi-filter form, which could match one project, exit 0 and stay green with a required package gone. The `&&` chain short-circuits, so **either package disappearing fails the command**.

**Honesty.** The name is `typecheck` and the mechanism is `tsc --noEmit` on both packages — **type correctness only**. It does not build, lint, test, or touch Python. **No root `test` was added. No `quality` or `check-all` was created**, and no lint or build limb was folded into `typecheck` (`DEC-0042` §D10; the `D3` writ's root-script boundary).

### 6.2 Data engine — `python services/data-engine/run_quality_checks.py`

One thin, checked-in, **stdlib-only** runner. No pytest, no tox, no nox, no Make, no just, no third-party CLI framework, and **no new Python dependency**. Three limbs, individually invocable — `suite`, `repro`, `digest` — with `all` the default.

It owns: the expected counts, the ×2 **independent-process** repetition, the digest assertions, its own import path, and its own bytecode suppression.

### 6.3 Governance — `python tools/governance/run_quality_checks.py`

The same shape, one limb: the checker's own suite at exactly its expected size, fail-closed. **It deliberately does not run the checker over the corpus** — `check` needs a pull-request base SHA and `audit` is explicitly never a gate, so both stay directly invoked with their GitHub event context in the workflow.

### 6.4 What was deliberately **not** built

**No cross-language mini CI framework.** There is no root command that runs everything, and that is a decision, not an omission: a root `quality` spanning three languages would assert coverage no mechanism delivers. **Surface ownership** is preserved — the JS/TS entrypoint lives in root `package.json`, the data-engine runner under `services/data-engine/`, the governance runner under `tools/governance/`, each owned by its surface.

---

## 7. `infra/postgres` — `LOCAL ONLY`, and it stays that way

| Question | Answer | Class |
|---|---|---|
| Does a local entrypoint exist? | **Yes.** `infra/postgres/scripts/verify-local`, whose own header describes it as a *"fail-closed assertion runner against a RUNNING local instance"*, alongside `prepare-local`, `start-local`, `status-local`, `logs-local`, `stop-local` and the guarded destructive `reset-local` | `VERIFIED` — file present and read at this base |
| Does it run in CI? | **No, and none was created.** `D3` created no workflow for this surface | `VERIFIED` |
| Does it work? | **`UNPROVEN — NOT PROBED.`** It requires Docker Desktop + WSL 2 and asserts against a live database. Executing it would touch a database, which this unit is forbidden to do | `UNPROVEN` |
| Was it modified? | **No.** Zero files under `infra/postgres/**` were changed — no semantic modification of any integration script | `VERIFIED` |

**Its local entrypoint is not materially broken so far as this unit can establish**, because this unit could not establish either way without executing it. **The honest statement is that its existence and its documented purpose are verified and its runtime behaviour is not**, and that is what the documentation now says. It is named in the new quality-entrypoint index as `LOCAL ONLY · no CI` so a fresh maintainer finds it without reading workflow YAML.

---

## 8. Workflow before → after, command by command

**Only the substantive command lines are shown.** Triggers, permissions, concurrency, timeouts, action pins and job structure are unchanged — see §9.

### `js-ts-quality.yml` — job `typecheck`

| | Command |
|---|---|
| **BEFORE** | step 7: `pnpm --filter web --fail-if-no-match typecheck` · step 8: `pnpm --filter @noxund/shared --fail-if-no-match typecheck` |
| **AFTER** | one step: `pnpm typecheck` |

The two leaf invocations are **not deleted** — they moved into root `package.json`, which the workflow now calls. **The workflow retains no second implementation.**

### `data-engine-tests.yml`

| Job | BEFORE | AFTER |
|---|---|---|
| `resolver-tests` | `working-directory: services/data-engine`, `PYTHONPATH: src`, an inline bash `for attempt in 1 2` loop running `python -m unittest discover -s tests -p 'test_*.py' -v`, grepping `^Ran 276 tests in `, erroring on mismatch | `python services/data-engine/run_quality_checks.py suite` |
| `repro-harness`, step 1 | the same inline loop with `-p test_repro_harness.py` and `^Ran 21 tests in ` | `python services/data-engine/run_quality_checks.py repro` |
| `repro-harness`, step 2 | `PYTHONPATH: src:tests` plus a single-line inline `python -c` computing the digest twice and `sys.exit(...)`-ing on either mismatch | `python services/data-engine/run_quality_checks.py digest` |
| `collection-driver-contract` | hash-pinned `pip install --require-hashes --only-binary=:all:` then a `psycopg.__version__` assertion | **UNCHANGED — deliberately.** See §11 |

### `governance-checks.yml`

| Job | BEFORE | AFTER |
|---|---|---|
| `checker-tests` | inline bash running `python -m unittest discover -s tools/governance/tests -p 'test_*.py' -v`, grepping `^Ran 40 tests in `, erroring on mismatch | `python tools/governance/run_quality_checks.py` |
| `reference-durability` | `check --base "${BASE_SHA}"` on pull request · `audit --repo-root .` on manual dispatch | **UNCHANGED — deliberately.** GitHub event plumbing, which the writ permits staying outside the quality artifact |

---

## 9. What the workflow edits preserved

Re-derived after editing, not assumed. Every `D2` guarantee is intact:

| Guarantee | State |
|---|---|
| Node selector — `node-version-file: '.nvmrc'` | unchanged |
| pnpm from the repository pin, both asserted fail-closed | unchanged |
| `pnpm install --frozen-lockfile --ignore-scripts` | unchanged |
| `permissions: contents: read` | unchanged, all three workflows |
| Action SHA pins | **unchanged — zero `uses:` lines differ**, confirmed by diffing for them explicitly. No repinning |
| Path filters and triggers | **zero trigger or path lines changed in any workflow** — §12 |
| Workflow self-trigger | unchanged |
| No cache | unchanged |
| Zero secret / Environment / database / cloud | unchanged |
| Pre-existing `workflow_dispatch` | **preserved** on both workflows that had it. None added, none removed |
| Job structure | **unchanged** — `typecheck`; `resolver-tests` + `repro-harness` + `collection-driver-contract`; `checker-tests` + `reference-durability`. All three files parse, verified with a YAML parse of each |
| Control strength | **`AUTOMATIC DETECTIVE · NOT MECHANICALLY MERGE-BLOCKING`** — unchanged and not upgraded. No ruleset, branch protection, required check, `CODEOWNERS` or reviewer threshold was read for modification or modified |

---

## 10. Fail-closed assertions — BEFORE → AFTER, so nothing is lost silently

**`D3` moves logic. It does not simplify protections away.** Every assertion that existed before exists after, in exactly one place.

| # | Assertion | BEFORE (location) | AFTER (location) | Preserved? |
|---|---|---|---|---|
| 1 | unit suite: non-zero unittest exit fails the run | workflow YAML | data-engine runner | **YES** |
| 2 | unit suite: exactly 276 discovered tests | workflow YAML | data-engine runner, `EXPECTED_SUITE_TESTS` | **YES** |
| 3 | unit suite: two runs, **independent processes** | workflow YAML `for` loop | data-engine runner, `DETERMINISM_RUNS`, each attempt a real `subprocess.run` of a fresh interpreter | **YES** — deliberately subprocesses, never two passes in one interpreter |
| 4 | unit suite: **both** runs must satisfy 1 and 2 | workflow YAML | data-engine runner | **YES** |
| 5 | repro harness: non-zero exit fails | workflow YAML | data-engine runner | **YES** |
| 6 | repro harness: exactly 21 discovered tests | workflow YAML | data-engine runner, `EXPECTED_REPRO_TESTS` | **YES** |
| 7 | repro harness: two independent processes | workflow YAML | data-engine runner | **YES** |
| 8 | digest: the two computations are byte-identical | workflow YAML one-liner | data-engine runner | **YES** |
| 9 | digest: equals the locked `GOLDEN_DIGEST` | workflow YAML one-liner | data-engine runner | **YES** |
| 10 | digest: non-zero exit on either mismatch | workflow YAML one-liner | data-engine runner, via `main` returning 1 | **YES** |
| 11 | driver contract: hash-pinned, binary-only install | workflow YAML | **workflow YAML — unchanged** | **YES**, as a documented CI-only exception |
| 12 | driver contract: resolved `psycopg` version equals the pin | workflow YAML | **workflow YAML — unchanged** | **YES**, same exception |
| 13 | governance: non-zero unittest exit fails | workflow YAML | governance runner | **YES** |
| 14 | governance: exactly 40 discovered tests | workflow YAML | governance runner, `EXPECTED_CHECKER_TESTS` | **YES** |
| 15 | governance: bytecode suppressed | workflow YAML `env:` | **both** — the runner sets it for its child, and the job-level `env:` is kept | **YES, strengthened** |
| 16 | reference durability: prospective check on PR-added lines | workflow YAML | **workflow YAML — unchanged** | **YES** |
| 17 | reference durability: corpus audit on manual dispatch | workflow YAML | **workflow YAML — unchanged** | **YES** |
| 18 | JS/TS: `web` filter matching zero projects fails | workflow YAML | **root `package.json`** | **YES** |
| 19 | JS/TS: `@noxund/shared` filter matching zero projects fails | workflow YAML | **root `package.json`** | **YES** |

> **Nothing on this list was dropped, weakened or merged.** Two were **added** rather than moved: the runners each suppress bytecode internally, so the guarantee no longer depends on the caller setting an environment variable.

---

## 11. The one specialized CI contract, classified and kept

`D3`'s writ requires every current data-engine quality limb be classified. The classification, with the evidence:

| Limb | Classification | Evidence |
|---|---|---|
| Core unit suite, 276 ×2 | **`DEVELOPER/CI PARITY TARGET`** | stdlib-only, needs no environment change, ran locally on this Windows host at 276/276 ×2 |
| Repro harness, 21 ×2 | **`DEVELOPER/CI PARITY TARGET`** | same; ran locally at 21/21 ×2 |
| Golden digest | **`DEVELOPER/CI PARITY TARGET`** | same; ran locally, byte-identical and equal to the locked value. **This is the limb that carried the parity defect**, so consolidating it is the whole point |
| Collection driver contract | **`SPECIALIZED CI CONTRACT` + `ENVIRONMENT-SPECIFIC`** | it exists to prove that a **real hash-pinned install** imports at its pinned version. That assertion **cannot be made without performing the install**, and performing it would install `psycopg` into a developer's environment — a material local change the rest of this entrypoint never makes. The core declares `dependencies = []` deliberately |

> **The exception is recorded, not hidden.** It is stated in the workflow header, in the data-engine runner's own docstring, in the data-engine README and here — four places, because `DEC-0042` §D17 condition 4 requires a difference between local and CI invocation be *"recorded as an accepted limitation with its reason"*. **It was not forced into the default local command**, which is exactly what the writ warned against.

The `reference-durability` job is the analogous governance case: its `check` mode needs a pull-request base SHA and its `audit` mode is explicitly never a gate. **Both are GitHub platform plumbing, and parity does not require identical environment metadata** — the invariant is that the substantive logic lives in one checked-in artifact, and the checker already is one.

---

## 12. The cross-platform repair

**The defect, reproduced at this base rather than inherited.** `D0` recorded a real local/CI parity defect: the golden-digest step set `PYTHONPATH: src:tests`, whose `:` separator is POSIX-only.

| Probe, run on this Windows host at this base | Result | Class |
|---|---|---|
| the CI one-liner verbatim, with `PYTHONPATH='src:tests'` | `ModuleNotFoundError: No module named 'test_repro_harness'` | `VERIFIED` — **the defect still existed at this base** |
| the same one-liner with `PYTHONPATH='src;tests'` | digest computed twice, both `c8e33fe85034e2c406bb189249ff829d8928a5b085d192c73220afcb89674ca8`, equal to the locked value | `VERIFIED` |

**The repair, and why it is a repair rather than a workaround.** The writ's preferred property was that *the checked-in Python entrypoint establishes its import path internally*, and that is what was built. Both runners resolve their own directory from `__file__` and construct the child `PYTHONPATH` with **`os.pathsep`** — `;` on Windows, `:` on POSIX — so:

- there is **no `PYTHONPATH` for a developer to set**;
- there is **no separator for a developer to know**;
- there is **no working directory a developer must be in**;
- **`PYTHONPATH: src:tests` is gone from the workflow entirely.**

**This was explicitly not solved by documenting two commands.** One artifact owns the path, and the canonical invocation is a single OS-neutral line. An inherited `PYTHONPATH` is prepended to rather than replaced, so a developer with their own entries keeps them.

---

## 13. Local validation actually performed

All on the current Windows host, CPython 3.11.9, at this base. **No dependency was installed. No worktree was created.**

| # | What was run | Result | Class |
|---|---|---|---|
| 1 | BEFORE: full unit suite, CI command shape | `Ran 276 tests` · `OK` | `VERIFIED` |
| 2 | BEFORE: repro harness | `Ran 21 tests` · `OK` | `VERIFIED` |
| 3 | BEFORE: golden digest, POSIX separator | `ModuleNotFoundError` — defect reproduced | `VERIFIED` |
| 4 | BEFORE: golden digest, Windows separator | digest ×2 identical and equal to the locked value | `VERIFIED` |
| 5 | BEFORE: governance checker suite | `Ran 40 tests` · `OK` | `VERIFIED` |
| 6 | AFTER: `python services/data-engine/run_quality_checks.py`, **no `PYTHONPATH` set**, from the repository root | `276/276` ×2, `21/21` ×2, digest ×2 identical and equal to the locked value, `PASSED limbs: suite, repro, digest`, exit 0 | `VERIFIED` |
| 7 | AFTER: the same runner's `digest` limb invoked **from a foreign working directory**, by absolute path | identical digest, exit 0 — the entrypoint genuinely needs no `cd` | `VERIFIED` |
| 8 | AFTER: `python tools/governance/run_quality_checks.py` from the repository root | `OK - 40/40`, exit 0 | `VERIFIED` |
| 9 | AFTER: the same, from a foreign working directory | `OK - 40/40`, exit 0 | `VERIFIED` |
| 10 | **Fail-closed probe**: the runner's unittest limb driven with a deliberately wrong expected count | returned failure and emitted an `::error::` annotation | `VERIFIED` |
| 11 | **Fail-closed probe**: the same limb with a discovery pattern matching **zero** test modules | returned failure and emitted an `::error::` annotation — **the silent-green under-discovery hazard is genuinely closed** | `VERIFIED` |
| 12 | Root script text read back from `package.json` | exactly the two chained, individually-filtered invocations | `VERIFIED` |
| 13 | `--fail-if-no-match` with a filter matching **zero** projects | **exit 1**, `No projects matched the filters` | `VERIFIED` |
| 14 | The identical filter **without** the flag | **exit 0** — the silent-green hazard, demonstrated directly | `VERIFIED` |
| 15 | Each real filter resolves to its package | both exit 0 | `VERIFIED` |
| 16 | All three edited workflows parsed | all parse; job structure unchanged | `VERIFIED` |

> **Probes 13 and 14 upgrade an evidence class `D2` could not.** The landed `D2` record states its zero-match fail-closed *behaviour* rested on pnpm's documented contract — *"`ACCEPTED`, not `VERIFIED`"* — because demonstrating it *"would have required a deliberately-failing probe commit"*. It does not: a throwaway filter name against the live workspace demonstrates both halves, with **no commit, no mutation and no write**. **The behaviour is now `VERIFIED` on pnpm 9.0.0 on this host.**

**One deliberate abstention, disclosed.** `pnpm typecheck` was **not** executed locally. `apps/web/tsconfig.json` sets `incremental: true`, so `tsc` would write a `.tsbuildinfo` — a persistent write, gitignored but real, and this unit declines convenience writes it does not need. The writ assigns JS/TS terminal evidence to **live CI**, which supplies it at §14. The wiring was instead proven by the zero-write probes above. **After all probes, the pre-existing `.tsbuildinfo` retained its original timestamp and no new one appeared.**

---

## 14. Live CI evidence

*Recorded after the pull request opened and CI ran automatically. **No manual dispatch was used to manufacture any of it.***

Pull request **#97**, `https://github.com/AdeptLabsDev/noxund/pull/97`, head `c0bc553a27d109c52d9c8ee67de91c19da1a386f`.

**Every workflow `D3` changed executed automatically on the pull request, and every one passed.**

| Run | Workflow | Event | Conclusion |
|---|---|---|---|
| `32593932537` | JS/TS Quality | `pull_request` | **success** |
| `32593932557` | Data Engine · Resolver Tests | `pull_request` | **success** |
| `32593932611` | Governance · Reference Durability | `pull_request` | **success** |
| `32593911038` | Data Engine · Resolver Tests | `push` | **success** |
| `32593932613` | SG-8 Integration · Local E2E | `pull_request` | **success** — **not changed by `D3`**; it fires on the same `services/data-engine/**` filter and is recorded because an adjacent workflow passing is part of showing nothing was broken |

Run URLs follow the form `https://github.com/AdeptLabsDev/noxund/actions/runs/<run id>`.

> **This enumeration is terminating, not count-bound, and the distinction is deliberate.** Every push to this branch creates a further set of runs, so any fixed list is one push behind by the time it is written — including the commit that writes it. **The invariant claimed here is not a run total.** It is: *every workflow `D3` changed fires automatically on this pull request, and on every head of this branch every such run has concluded `success`.* The identifiers above are the round whose step output is quoted below, recorded so the quotations are traceable to a specific run rather than asserted in the abstract. **A reviewer should re-derive the current state from the pull request rather than trust a number here**, and the runs on the final head are named at §14.3.

### 14.1 The canonical entrypoints actually ran — step names and output

**JS/TS.** The job now carries **one** typecheck step, *"Typecheck the active JS/TS surface through the canonical root entrypoint"*, and its output shows the single `pnpm typecheck` call reaching **both** packages:

```
Scope: all 3 workspace projects
> web@0.0.0 typecheck /home/runner/work/noxund/noxund/apps/web
> tsc --noEmit
> @noxund/shared@0.0.0 typecheck /home/runner/work/noxund/noxund/packages/shared
```

The `D2` contract is intact in the same run — `node --version = v20.20.2`, satisfying the `.nvmrc` pin; `pnpm --version = 9.0.0`, exactly the repository pin; frozen script-free install green.

> **This is the parity claim, discharged.** One step, one command, and it is the command a developer runs. **There is no longer a second encoding of the two leaf invocations in the workflow.**

**Data engine.** Three steps, all through the checked-in entrypoint:

```
== suite: full unit suite, x2 ==
  attempt 1/2: 276/276 OK
  attempt 2/2: 276/276 OK
OK - data-engine unit suite: 276/276 across 2 independent processes.

== repro: P5-REPRO-01 harness, x2 ==
  attempt 1/2: 21/21 OK
  attempt 2/2: 21/21 OK
OK - P5-REPRO-01 repro harness: 21/21 across 2 independent processes.

== digest: pipeline digest over the golden snapshot ==
  digest#1 c8e33fe85034e2c406bb189249ff829d8928a5b085d192c73220afcb89674ca8
  digest#2 c8e33fe85034e2c406bb189249ff829d8928a5b085d192c73220afcb89674ca8
OK - digest byte-identical x2 and equal to the locked GOLDEN_DIGEST.
```

The unchanged `collection-driver-contract` job passed alongside them — `driver contract OK — psycopg 3.3.4 (pinned, hash-verified)` — confirming the CI-only exception still works and was not disturbed.

**Governance.** `OK - 40/40.` through the checked-in entrypoint, and the untouched prospective job reported `prospective check over 447 added/changed line(s) on governed surfaces` · `OK - no malformed reference shape introduced` — so this record's own citations satisfy the durability rule it is governed by.

### 14.2 Outcomes preserved, BEFORE → AFTER

| Property | BEFORE (landed `main`) | AFTER (this PR, live) | Preserved? |
|---|---|---|---|
| Unit suite count, per run | 276 | 276 | **YES** |
| Unit suite independent runs | 2 | 2 | **YES** |
| Repro harness count, per run | 21 | 21 | **YES** |
| Repro harness independent runs | 2 | 2 | **YES** |
| Golden digest value | `c8e33fe8…4ca8` | `c8e33fe8…4ca8` | **YES — unchanged** |
| Digest computed twice, identical | yes | yes | **YES** |
| Governance test count | 40 | 40 | **YES** |
| Driver contract | pinned, hash-verified | pinned, hash-verified | **YES** |
| JS/TS packages typechecked | 2, via two steps | 2, via one entrypoint | **YES — same coverage, one command** |
| Node / pnpm in force | v20.20.2 / 9.0.0 | v20.20.2 / 9.0.0 | **YES** |

> **Cross-platform determinism is demonstrated end to end.** The digest this Author computed on **Windows** through the new entrypoint and the digest Linux CI computed through the **same** entrypoint are **byte-identical** and both equal the locked constant. The repair did not merely make the command runnable on Windows — it produced the same value there.

**No path filter prevented any changed entrypoint or workflow from exercising itself**, so no `HOLD` arose on that ground: the JS/TS workflow watches root `package.json` and its own file, the data-engine workflow watches `services/data-engine/**`, and the governance workflow watches `tools/governance/**` and `docs/result/**`. **All three were verified to already cover the new paths, so no trigger was modified.**

### 14.3 The commit that records this evidence, and the round after it

Recording live CI evidence inside the branch it describes advances the branch, which produces one further round of runs. Rather than leave that unstated, it is named:

| Run | Workflow | Conclusion |
|---|---|---|
| `32594244537` | JS/TS Quality | **success** |
| `32594244526` | Data Engine · Resolver Tests | **success** |
| `32594244533` | Governance · Reference Durability | **success** |
| `32594244527` | SG-8 Integration · Local E2E — again, **not changed by `D3`** | **success** |

**Every workflow `D3` changed passed on that head as well.** This §14.3 commit is itself a further head, and it will produce one more such round — **which is inherent to recording evidence in the artifact it describes, not a defect and not an omission.** The claim being made is the terminating one stated above, and a reviewer verifies it against the pull request rather than against any list.

---

## 15. Documentation repaired

| File | What was wrong | What it says now |
|---|---|---|
| `apps/web/README.md` | status read *"placeholder. Não scaffoldado ainda (sem dependências instaladas)"* for a package with eleven declared devDependencies; carried a copy-pasteable `pnpm create next-app@latest apps/web` targeting an already-populated directory; named no quality command | truthful minimal-scaffold description with the actual file inventory; **the scaffold command is removed rather than re-guarded**; names `pnpm typecheck` as canonical and says CI runs the same command; states `next build` is `UNPROVEN` and not claimed; records the `D2` `Q3` answer as temporal |
| `packages/shared/README.md` | status read *"placeholder. Não scaffoldado ainda"* for a package with source, a manifest and a working typecheck script | truthful state — four exported string constants; `ACTIVE-BUT-UNREACHED` standing stated with its rule; names `pnpm typecheck` and explains that this package is required **individually**; records the `Q3` answer as temporal. **Not turned into product-architecture authority** |
| `services/data-engine/README.md` | a PowerShell-only transcription setting `PYTHONPATH` then calling a **weaker** command than CI ran — no ×2, no count assertion | names the canonical OS-neutral entrypoint and its three limbs; states CI invokes the same file; points at the runner's own docstring for scope rather than duplicating it; records the driver-contract exception |
| `docs/foundation/monorepo-structure.md` | claimed the foundation was *"buildável"* and that `apps/web` *"compila"*; called the data engine a scaffold; layout tree omitted `tools/`, `infra/` and the legacy package and misdescribed the workspace globs; the *"Próximo passo técnico"* list still instructed `git init`, scaffolding `apps/web`, `supabase init` and bootstrapping the data engine — all long done | the unsupported build claim is **narrowed, not restated**: typecheck is verified, `next build` is `UNPROVEN`; layout corrected with standings; the obsolete next-step list is **replaced by a quality-entrypoint index** — one table mapping each surface to its canonical command and whether CI invokes it, plus the two documented exceptions and an explicit *"what is verified by nothing"* list |

**Discoverability, checked against the writ's test.** From repository documentation alone a fresh maintainer can now determine: how to typecheck all active JS/TS; how to run the data-engine quality path; how to run governance quality tests; what remains local-only; and what CI invokes. **None of it requires reading workflow YAML.** No document reproduces a runner's internal implementation — each names the entrypoint and points at the artifact.

**No new operational document was created.** The index went into an existing foundation document rather than a new file, because the writ permits a new one only *if the existing package documentation cannot provide a coherent index*, and it could.

---

## 16. Documentation deliberately **not** touched

| File | Why |
|---|---|
| **root `README.md`** | **Out of scope, explicitly.** Its `packages/orchestrator` architecture misdescription is separate `DEC-0038` / governance debt. **`D3` completed without needing to touch it**, so no `HOLD — ROOT README INTERACTION` arose. It was **not** opportunistically cleaned up |
| `infra/postgres/README.md` | not in the authorized mutation set. The surface is documented from the new index instead, and **no semantic modification** of that surface occurred |
| `supabase/**`, `packages/orchestrator/**` | `HISTORICAL / PRESERVED` and `LEGACY` — **zero investment**, and neither deleted, emptied, moved nor edited |
| every other document | outside the small-diff principle: no mutation was made that does not answer *canonical entrypoint*, *workflow invoking one*, *stale build/quality-path documentation*, or *result and routing artifact* |

---

## 17. Remaining exceptions, unknowns and routed items

Named so a later unit finds them. **Naming is not authorization.**

| # | Item | Standing |
|---|---|---|
| 1 | **Collection-driver contract remains CI-only** | **ACCEPTED LIMITATION**, documented in four places. Not a gap |
| 2 | **`reference-durability` remains invoked directly** | **BY DESIGN** — GitHub event plumbing, permitted to stay outside the quality artifact |
| 3 | **`infra/postgres` runtime behaviour** | `UNPROVEN — NOT PROBED`. Needs Docker + WSL 2 and a live database. **No CI created, none recommended by this unit** |
| 4 | **`next build` / `Q1` for `apps/web`** | `UNPROVEN — NOT PROBED`, **routed, not waived**. `D3` did not execute it, did not add it to CI and did not add it to any canonical command. **No build evidence was manufactured** |
| 5 | **Naming tension on the Python runners, disclosed rather than smoothed** | Both are named `run_quality_checks.py`, following the writ's own vocabulary. A reader could take *"quality"* more broadly than the mechanism — so each file's docstring, each workflow header and the new index state the exact covered set and the exclusions. **Flagged here for the Reviewer to adjudicate rather than left to be discovered** |
| 6 | **Root `lint` and `build` scripts still lack `--fail-if-no-match`** | **Deliberately untouched.** Neither is a `D3` subject, and editing them answers none of the four small-diff questions. Routed, not fixed in passing |
| 7 | **Ruff configured, suppressed against, never run** | `D4`. Untouched |
| 8 | **`target: ES2017` in `apps/web`** | `D1` left it deliberately; unchanged here |

---

## 18. `D4` handoff facts

Handed forward **as established fact, never as authorization**. **`D4` remains `NOT AUTHORIZED` and `NOT STARTED`.**

1. **Three canonical entrypoints now exist and CI invokes each.** `D4` has somewhere to put a static-analysis limb if it adjudicates one is warranted — but **adding a limb to a runner is a `D4` act needing `D4`'s own GO**, which `D3` does not pre-authorize.
2. **`D3` adopted no static checker.** Not ESLint, not `next lint`, not Ruff, not shellcheck, not actionlint, not a SQL linter, not a YAML linter. **Every `D4` adjudication is fully open**, and the `D0` finding that ruff is configured and suppressed against but never run is unchanged.
3. **`D3` added no quality domain.** The signals are the same ones that existed before; only their invocation path changed.
4. **The runners are stdlib-only and dependency-free by design.** A `D4` adoption that requires a third-party tool would be the first dependency either file has ever needed, and that is a decision, not a detail.
5. **Control strength is unchanged** — `AUTOMATIC DETECTIVE · NOT MECHANICALLY MERGE-BLOCKING`. Nothing `D3` did makes any check required for merge.

---

## 19. Mutation accounting

Per [`DEC-0040`](../product/decisions/DEC-0040-governed-result-disposition-closeout-contract.md) D13. **`OUTSIDE REPOSITORY ≠ OUTSIDE write_scope`, and a clean `git status` is not a zero-mutation proof — every `ZERO` below names the check supporting it.**

**Derived in command output and session context only. No accounting snapshot was written to disk at any point**, which is the specific discipline `R1` failed.

### 19.1 Repository, inside write scope

Ten files, every one inside the authorized mutation set:

| Path | Change |
|---|---|
| `package.json` | one script value — root `typecheck` |
| `services/data-engine/run_quality_checks.py` | **added** |
| `tools/governance/run_quality_checks.py` | **added** |
| `.github/workflows/js-ts-quality.yml` | two steps → one; header note |
| `.github/workflows/data-engine-tests.yml` | three steps replaced; header note |
| `.github/workflows/governance-checks.yml` | one step replaced; header note |
| `apps/web/README.md` | stale-documentation repair |
| `packages/shared/README.md` | stale-documentation repair |
| `services/data-engine/README.md` | stale-documentation repair |
| `docs/foundation/monorepo-structure.md` | stale-documentation repair + entrypoint index |

Plus this record and the two routing documents.

### 19.2 Repository, outside write scope — `ZERO`

Supported by `git status --porcelain` **and** by an explicit diff of the staged change set, which lists exactly the paths above and no others. **Specifically zero** changes to: root `README.md`; any product source under `apps/web/src/**` or `packages/shared/src/**`; any test file; any test framework or dependency; `pnpm-lock.yaml`; any `package.json` other than the root; `.nvmrc`; any `tsconfig`; `pnpm-workspace.yaml`; `pyproject.toml`; either requirements file; `packages/orchestrator/**`; `supabase/**`; `infra/postgres/**`; any workflow other than the three named; any ruleset, `CODEOWNERS` or required check.

### 19.3 Branches, commits, pushes, pull requests

One branch created from `origin/main`. Commits and one pull request as recorded at §14. **The stale `R1` branch was not used, deleted, renamed or pushed** — verified by `git branch` listing it unchanged at the base with zero commits.

### 19.4 Refs, tags, worktrees, stash — `ZERO` created or modified

`git worktree list` shows **three** worktrees, all **pre-existing**: the main checkout and two long-standing ones dating from earlier units. **This unit created none and removed none.** `git stash list` shows **one** pre-existing entry, from an unrelated branch; **this unit created no stash and dropped none.** No tag was created. No ref was force-updated.

### 19.5 Temp and system temp

**One out-of-repository directory was created, and it is the exact path the writ pre-authorizes:** `C:/Adeptlabs/noxund-d3-r2-runtime-temp-author`.

- **Why it was genuinely required:** exactly one data-engine test module uses `tempfile.mkstemp()` — verified by searching the suite. It is the module `D0` had to exclude, which is why `D0` could only run 237 of 276 locally. Running the **full** suite is load-bearing here: the writ requires the cross-platform repair be validated on this host, and requires an independent BEFORE → AFTER comparison of the **expected discovered-test count**, which is 276. A 237-test local run could not have established that the runner's count assertion holds at its real value.
- **How it was contained:** `TEMP`, `TMP` and `TMPDIR` were set to that exact directory, and `tempfile.gettempdir()` was **verified** to resolve inside it before any suite ran.
- **Residue:** the directory is **empty** after all runs — the test cleans up after itself. Cleanup of the directory itself is planned per the writ.
- **`ZERO` generic system temp.** No `/tmp` file, no `%TEMP%` file, no `mktemp`, no arbitrary system-temp path. **No accounting snapshot, ledger, diff store or evidence-staging file was created anywhere** — the `R1` failure mode.
- **`ZERO` shell redirection.** No `> file`, `>> file`, `tee`, `Out-File`, `Set-Content` or helper snapshot file was used for any purpose. The pull-request body was passed on **stdin**, never through a file.

### 19.6 Bytecode and build artifacts — `ZERO` written

Not inferred from `git status` — established directly. Three `__pycache__` directories exist under `services/`; **all three are dated 2026-07-25, all are gitignored, and a search for any file inside them newer than this session's start returned nothing.** Every Python invocation ran under `-B`, `PYTHONDONTWRITEBYTECODE=1` or `sys.dont_write_bytecode`, and the runners set it themselves. The pre-existing `.tsbuildinfo` retains its original June timestamp; **no new one was created**, because `pnpm typecheck` was deliberately not run locally.

### 19.7 Session scratchpad — `ZERO`

The session scratchpad directory was **never written to**. No scratch file, no note, no intermediate result, no helper script was created there or anywhere else.

### 19.8 Memory and configuration — `ZERO`

**No memory file of any kind was written, read for modification, or edited** — `MEMORY.md` and every project or session memory file is untouched. No `CLAUDE.md`, no settings file, no permission configuration, no git config, no `gh` config was changed.

### 19.9 GitHub control plane — `ZERO` writes

Every GitHub interaction was **read-only** except the authorized branch push and pull-request creation. **Zero** rulesets, branch-protection settings, required status checks, `CODEOWNERS` files, reviewer thresholds, Environments, secrets, variables or workflow-permission settings were read for modification or modified. **No workflow was manually dispatched** — every CI run at §14 fired automatically from the pull request. **No workflow was enabled, disabled or re-armed.**

### 19.10 Axis 1 — `ZERO`

**No Axis-1 surface was touched.** No collection resumed, no migration authored or applied, no database, cloud resource or Environment contacted, no phase unlocked, nothing re-armed. The disabled apply workflows and the disarmed collection workflows are **unchanged and were not read for modification**.

### 19.11 `UNKNOWN MUTATION STATE` — one, disclosed

**Harness persistence outside participant control.** One broad `grep` over `docs/product/current-state.md` returned ~31.5 KB and the harness persisted it to a tool-results file outside the repository. **This was avoidable** — the pattern was wider than needed, and the writ requires bounded reads precisely to prevent it. It is classified **`HARNESS / SYSTEM PERSISTENCE OUTSIDE AGENT CONTROL`**, disclosed rather than concealed, and **the participant states plainly that working differently would have avoided it.** Every subsequent read was narrowed and no further spill occurred. **It is not offered as cover for any deliberate write, and no deliberate write occurred.**

No other surface is in an unknown state.

---

## 20. What this unit deliberately did not do

- **No new `DEC`.** `D3` executes existing `DEC-0042` authority. No new normative policy question arose, so no `HOLD — NEW NORMATIVE AUTHORITY REQUIRED` was returned.
- **No threshold, no score, no coverage figure, no target.**
- **No new quality domain, no new tool, no task runner, no dependency.**
- **No test, no test framework, no root `test` script.**
- **No `next build`, and no manufactured build evidence.**
- **No `D4` work.** No linter adopted, invoked or configured.
- **No control-strength change**, no ruleset, no required check, no action repinning.
- **No trigger redesign.** Existing path filters already covered every new entrypoint, so **trigger configuration was left alone**, and pre-existing `workflow_dispatch` was preserved.
- **No worktree**, no local dependency installation, no validation surface beyond the one pre-authorized runtime-temp directory.
- **No Axis-1 action**, no Phase E or F work, no `packages/orchestrator` or `supabase` edit.
