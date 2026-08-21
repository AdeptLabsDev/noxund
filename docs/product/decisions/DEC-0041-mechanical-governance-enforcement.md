# DEC-0041 — Mechanical governance enforcement

**Status:** ACTIVE (binding) · **Date:** 2026-08-21 · **Decision authority:** Product Lead
**Authority class:** INTERNAL-NORMATIVE · **Lifecycle:** ACTIVE / CURRENT · **Mutability:** FROZEN — the `docs/product/decisions/**` family default ([[DEC-0035]] §9), declared here under the fail-closed rule ([[DEC-0035]] §7). **Verified rather than copied:** §9's named exceptions for that family are [[DEC-0028]] and [[DEC-0033]] only, and this record is neither, so the default applies unmodified.
**Drafted by:** a task-scoped Author, reviewed by a **distinct** task-scoped independent reviewer, under the topology [[DEC-0037]] D5 and D6 fix. That unit's own explicit Product-Lead `C5` GO — not any earlier `C*` GO — is what authorized it ([[DEC-0035]] §6). **Ratification gate:** the Product Lead's manual merge of this record.
**Scope:** The `C5` limb of improvement Phase C. It fixes what **mechanical enforcement** means in this repository, adjudicates **seven** routed enforcement candidates, lands **one** implemented control and the repair of an existing citation debt, and records — as findings, not as apologies — which candidates the current substrate cannot bind. **Docs-plus-one-tool unit.**
**Negative scope — this record does not create or change:** any GitHub ruleset, branch protection, required status check, reviewer threshold, `CODEOWNERS` file, Environment, secret, variable, credential, App, bot, principal or trust anchor · any agent registration, activation, contract, boundary or runtime wiring · `packages/orchestrator/**` in any respect · any preserved ref, branch, stash or archive · any database, SQL, migration, role or runner · any `AgentResult` V2, machine-readable result schema, `TaskCommand` redesign or result DSL · any product scope, MVP admission, `OD-*` item or Axis-1 question · memory content. **No agent is wired, no principal is created, nothing is re-armed, and no execution of any kind is authorized.**
**Extends:** [[DEC-0040]] §9 — supplying the `C5` limb that clause routed, as an adjudication of six named candidates rather than as six validators. [[DEC-0040]] is neither edited nor narrowed and remains **CURRENT**.
**Discharges — by satisfaction, not by replacement:** [[DEC-0040]] §7's Product-Lead routing decision `EXISTING LOCATOR DEBT → C5 ADDITIVE-FORWARD-NOTE REPAIR (LIMB A)` and `FUTURE LOCATOR DRIFT → C5 MECHANICAL CHECK (LIMB B)`, together with [[DEC-0040]] D15's closing residual (*"A mechanical staleness check is routed to `C5`"*). See §7 and §8. Also [[DEC-0039]] D11 and §8's assignment of the enforcement candidates to `C5` — **discharged as an adjudication venue, not as a delivered detection**: §6 candidate 7 explains why the detection D11 called for is not buildable here and re-routes it.
**Does not edit:** any prior DEC body. [[DEC-0001]] … [[DEC-0040]] all remain **frozen and additive-only**; [[DEC-0028]] and [[DEC-0033]] remain **byte-frozen** per [[DEC-0034]] §4. [[DEC-0036]] and [[DEC-0037]] receive **clearly-marked additive forward-status notes appended at the end**, the one mechanism [[DEC-0035]] §3.3 permits on a `FROZEN` record — **no historical sentence is rewritten and no old line number is replaced in place**. No prior record is declared obsolete, superseded, reopened or reinterpreted. No file under `docs/agents/**` or `context/**` is touched.
**Evidence base — re-derived at the canonical base, not inherited:** the live GitHub configuration read through `gh api` — `repos/AdeptLabsDev/noxund/rulesets`, ruleset `19697151` in full, `repos/AdeptLabsDev/noxund/collaborators`, `repos/AdeptLabsDev/noxund/actions/permissions/workflow`; the `on:` block of all eleven workflow files on `main`; the whole of `docs/agents/product-orchestrator-agent.md` §*Source of Truth*, §*Agent Interaction Model*, §*Task Decomposition Contract* › §*Regras de atribuição*, §*Stage-Gate Discipline* and §*Output Format* › §*Decision sequencing*; the contents of `docs/result/`; a corpus-wide count of `path:NNN`-shaped locator tokens across `docs/` and `context/`; a search of the working tree and of every reachable Git ref for the `C4` R4 process-deviation artifact; [[DEC-0035]] §3.3, §4 P4, §6, §7, §8, §9, §10, §12; [[DEC-0036]] D2 and its evidence base; [[DEC-0037]] D5, its evidence base and §9; [[DEC-0038]] D1, D3 and §14; [[DEC-0039]] D7, D9, D11, D12 and §8; [[DEC-0040]] D5, D11, D12, D13, D15, §7 and §9; `current-state.md` §B and §E; `context-map.md` §3.
**Canonical base:** `main` @ `f88e5ca84bc510adb7f9717e2e20296c8830b2d8`

---

## 1. Status

**ACTIVE — binding and prospective**, effective on the Product Lead's manual merge (§16). It authorizes no unit, wires no agent, provisions no principal and changes no GitHub setting. It lands one deterministic control, one completed repair, and five adjudicated refusals.

---

## 2. The problem

Phase C produced a governance model of real precision — a topology ([[DEC-0037]]), a disposition ([[DEC-0038]]), a capability and principal model ([[DEC-0039]]) and a result contract ([[DEC-0040]]). **Every clause of it is enforced by nothing but the reader's diligence.** [[DEC-0040]] itself closes with *"`DEC-0040` writes no code, provisions no principal, and is enforced by nothing mechanical — that remains `C5`"*.

The temptation this unit exists to resist is the obvious one: convert the rules into validators, count the validators, and call the phase enforced. That would be worse than doing nothing, because a checker that observes the wrong surface produces a **green signal that means nothing while reading as though it means everything** — the precise failure [[DEC-0039]] D12 names when it warns *"do not describe process-only controls as sandboxing"*.

So the first question this record answers is not *what can we build* but *what can a machine in this repository actually observe*. On the evidence, the answer is: **much less than the governance model covers.** Five of the seven routed candidates target artefacts and events that live outside anything repository CI can see. Naming that is the finding; building around it would be the failure.

---

## 3. What `MECHANICAL` means here

> **A control is `MECHANICAL` only where a machine actually checks or restricts the action or state. A rule a person is expected to follow is not a control, however well written.**

Three strengths, and every control in this repository must be classified as exactly one.

| Strength | Meaning | Test |
|---|---|---|
| **`PREVENTIVE`** | The action cannot proceed while the control rejects it. | Something is *blocked*. |
| **`AUTOMATIC DETECTIVE`** | Checked automatically, deterministic signal, visible without being asked — but the action can still proceed. | Something *runs by itself and reports*. |
| **`PROCESS ONLY`** | The rule exists; no machine binds it. | A person must remember. |

Two invariants follow, and they are binding on every future record and every future unit result.

> **A process checklist is never described as mechanical enforcement.**
> **A GitHub Action is never described as merge-blocking unless repository rules actually make its success required.**

**`PROCESS ONLY` is not a demotion.** [[DEC-0039]] D12 established that logical least privilege *"is real and functioning"* — each unit's GO names a scope, exact paths and a write boundary, and [[DEC-0037]] D8 makes staying inside them a checkable review function. Classifying a control `PROCESS ONLY` records how it binds, not whether it matters.

---

## 4. Substrate, re-derived at the canonical base

Every claim below was re-derived by this unit and carries its evidence class ([[DEC-0040]] D3).

1. **No CI check can block a merge on `main` today. `VERIFIED`.** Three rulesets are `active`. `Protect main` (id `19697151`) carries exactly three rules — `deletion`, `non_fast_forward`, `pull_request`. **There is no `required_status_checks` rule.** `C5` is forbidden to change rulesets, so **every workflow this unit adds is `AUTOMATIC DETECTIVE` and nothing stronger.**
2. **The approval surface is unchanged from what [[DEC-0039]] D10 measured. `VERIFIED`.** The `pull_request` rule carries `required_approving_review_count: 0`, `required_reviewers: []`, `require_code_owner_review: false`, `required_review_thread_resolution: true`, `require_extra_approval_for_unattributed_changes: true`, `allowed_merge_methods: ["merge"]`. The sole bypass actor is user `282037855` = `AdeptLabsDev`, mode `pull_request`; `current_user_can_bypass` reads `pull_requests_only`. The sole collaborator is `AdeptLabsDev`, role `admin`. **F4a stands exactly as [[DEC-0039]] D10 landed it.**
3. **Nothing runs on a governance PR today. `VERIFIED`, with a correction to the briefing this unit worked from.** Of the eleven workflows on `main`, **two** — not one — carry a `pull_request` trigger: `data-engine-tests.yml` and `sg8-integration-local.yml`. **Both are path-filtered away from every governance surface** (`services/data-engine/**`, and for the second also `supabase/migrations/**`). The load-bearing conclusion is unchanged and is the one that matters: **there is no always-running workflow to reuse, and a docs/governance PR currently triggers no CI at all.** The correction is recorded rather than absorbed, because a claim of *"only one workflow"* would have been false.
4. **The default `GITHUB_TOKEN` cannot read repository rulesets. `REPORTED`, and deliberately not upgraded.** The GitHub Actions `permissions:` vocabulary contains no `administration` scope, and the rulesets REST endpoint requires administration-level read. Establishing this by execution would mean creating and dispatching a workflow to observe it fail — a mutation this unit is not authorized to make and would not make to prove a negative. It is therefore `REPORTED`, and §6 candidate 7 is built so that **its disposition does not depend on this claim being upgraded**: the candidate fails on an independent and decisive ground.
5. **There is no universal machine-observable unit-result surface. `VERIFIED`.** `docs/result/` contains exactly two files, `PHASE-A-CLOSEOUT-R1.md` and `PHASE-B-CLOSEOUT-R1.md`, both phase closeouts. **Units `C1` through `C4` produced no result file at all** — each unit's output was a DEC, and its closeout was a chat artifact returned to the Product Lead. **The governed result [[DEC-0040]] D11 and D12 define is not a repository object.**
6. **Every observed convenience-write incident was invisible to repository CI. `VERIFIED`.** The `C4` R4 process deviation named a scratchpad file that exists nowhere in the working tree and in **no** reachable Git object across all 229 commits on all refs. The `C0` incident was a memory-file write outside the repository; the `C3` R2 incident was four session-scratchpad files, four `/tmp` files and one `/tmp` directory. **All three took place where no repository check could ever have seen them.** This is the single most load-bearing finding in this record, and §6 candidate 6 turns on it.
7. **Language substrate. `VERIFIED`.** Python 3.11 with the standard library and `unittest`, actions SHA-pinned, `permissions: contents: read`, zero `pip install` in the test jobs — the idiom `data-engine-tests.yml` establishes. Node 20 / pnpm serves `apps/*` and `packages/*` and is not used here.
8. **Citation-corpus magnitude. `VERIFIED`.** Exactly **177** `path:NNN`-shaped locator tokens across **12** files under `docs/` and `context/`. **144 of them — 81% — sit in one file**, `docs/data/DATA-AUDIT-001-determinism-conformance.md`, and are **source-code citations** (`opportunity.py` and its tests, cited by position for audit reproduction). That is a different genre from an authority citation, and it is why §8 scopes the control by governed surface rather than by token shape.

---

## 5. Decision

### D1 — The three strengths are binding vocabulary

§3's table and its two invariants are normative. **Every future record, unit writ and unit result that describes a control must classify it as `PREVENTIVE`, `AUTOMATIC DETECTIVE` or `PROCESS ONLY`**, and must not describe a control as stronger than the mechanism that carries it. These are strength classifications for controls; they are **not** a new status axis and do not touch the six axes of [[DEC-0040]] D1.

### D2 — `C5` implements exactly one control

**One deterministic control is landed: the reference-durability check (§8).** Five candidates are found not bindable on the current substrate and one is rejected outright (§6).

> **`FEWER REAL CONTROLS > MORE CONTROLS THAT DO NOT OBSERVE THE WORK`.**

This is the decision, not a shortfall against a target. No candidate is implemented because it appeared in a routing list, and **completing the list was never the objective**.

### D3 — The existing locator debt is repaired and closed

Limb A is performed (§7). The four `UNRESOLVED — LOCATOR ONLY` references [[DEC-0040]] §7 escalated now carry durable identity — stable path, stable named section, verbatim quotation — supplied by additive forward-status notes appended to [[DEC-0036]] and [[DEC-0037]]. **`UNRESOLVED — LOCATOR ONLY` is discharged for those references.** No other reference in the corpus is repaired, and none is required to be.

### D4 — The reference-durability control, and the limits it is never described past

The control landed at `tools/governance/check_reference_durability.py` is **prospective, deterministic, repository-local, network-free, secret-free and Python-3.11-stdlib-only**. It detects **citation shape** on governed surfaces.

> **It detects shape. It does not verify meaning.**
> It cannot determine whether a reference is load-bearing; it cannot check that a named anchor actually names the cited clause; and **it deliberately does not detect drift**, because under [[DEC-0040]] D15 a drifted locator carrying a durable anchor is a stale locator and **not** an authority defect. It never opens the cited file.

**A green result means one thing only: no malformed reference *shape* was introduced.** Describing it as citation verification would breach D1.

### D5 — Binding status of everything this unit adds to CI

> **`AUTOMATIC DETECTIVE · NOT MECHANICALLY MERGE-BLOCKING`.**

No ruleset is read, created or modified; no `required_status_checks` rule is added; no reviewer threshold is changed; no `CODEOWNERS` file is created. The workflow reports on a PR and cannot stop one. **Any later statement that this check gates `main` is false unless a separate, explicitly authorized unit adds a `required_status_checks` rule** — which this record neither performs nor recommends into existence.

### D6 — Result-contract, required-field and status-axis validators: the surface does not exist

Candidates 1, 2 and 3 are **`NOT MECHANICALLY BINDABLE WITH CURRENT SUBSTRATE`** (1 and 2) and **`DEFER / REJECT`** (3). The reasoning is at §6 and turns on §4 item 5: the governed result is a chat artifact, `C1`–`C4` produced no result file, and [[DEC-0040]] D16 deliberately classified `AgentResult` **`NON-AUTHORITATIVE LEGACY`** while choosing a **prose** contract.

> **No `AgentResult` V2 is created. No machine-readable result schema, envelope or DSL is created, proposed or required.**
> **A validator that checks an optional template while being described as enforcing actual unit results is prohibited by D1**, and none is built.

### D7 — Mutation accounting cannot be mechanically enforced, and the limit is stated rather than hidden

Candidate 4 is **`NOT MECHANICALLY BINDABLE WITH CURRENT SUBSTRATE`**.

> **A checker that sees only repository files must never be called mutation-accounting enforcement.**

[[DEC-0040]] D13 requires accounting across repository files, branches, commits, refs, worktrees, stash, temp, cache, sidecar and backup files, system temp directories, session scratchpads, **memory files of any kind**, other out-of-repository files, and external mutable systems. Repository CI observes a strict subset of the first group and **none** of the rest — and §4 item 6 establishes that **all three observed breaches occurred entirely outside that subset**. A control covering only the surface where nothing has ever gone wrong would earn a green that means nothing. **`OUTSIDE REPOSITORY ≠ OUTSIDE write_scope` remains enforced by the review function, not by a machine.**

### D8 — Scratch and out-of-scope writes: prevention requires an executor this unit may not build

Candidate 6 is **`NOT MECHANICALLY BINDABLE WITH CURRENT SUBSTRATE`**, and its one buildable sub-limb is **`DEFER / REJECT`** on its own merits (§6).

[[DEC-0039]] D7 governs and is applied unchanged:

> **`ROLE SCOPING = AUTHORIZATION / PROCESS BOUNDARY, NOT TECHNICAL CAPABILITY SANDBOX`.**

Real prevention would need a controlled executor, wrapper or sandbox that mediates every write an instance makes. **That boundary is routed, not built.** This record creates no wrapper — an unenforced wrapper nobody is required to use is `PROCESS ONLY` wearing a mechanical costume, and would breach D1 — and it resurrects nothing from `packages/orchestrator`, whose **REDUCE** disposition ([[DEC-0038]] D1, D3) is untouched.

### D9 — Ruleset-drift detection is not buildable here, and the reason is structural

Candidate 7 — [[DEC-0039]] D11's **F4b** detection — is **`NOT MECHANICALLY BINDABLE WITH CURRENT SUBSTRATE`**. Two independent grounds, and **the second alone is sufficient**, so the disposition does not rest on the `REPORTED` claim at §4 item 4.

1. In-CI access to the rulesets API needs an admin-scoped token stored as a secret. **`C5` is forbidden to create a secret or a principal.**
2. **The control would be defeated by exactly the actor it exists to detect.** F4b is a *single-admin tamper risk*. Any expected-state file committed to the repository is an ordinary repository file, editable by that same admin **in the same pull request** that alters the ruleset. A tamper detector whose baseline the tamperer owns detects nothing.

**F4b's disposition is unchanged and is not weakened:** it remains `ACCEPTED CURRENT LIMITATION` + `DETECTION REQUIRED LATER` ([[DEC-0039]] D11). What this record adds is that **the detection must be out-of-band** — held by a principal or observer the single admin does not control — and is therefore a Phase-F question, not a repository-CI one. **`CURRENT ENFORCEMENT` and `CONFIGURATION DURABILITY` remain separate questions**, and §4 item 2 re-verifies that every protection [[DEC-0039]] recorded is still in force.

### D10 — No GitHub configuration is touched, and none is proposed

No ruleset is created, modified or deleted. No `required_status_checks` rule, reviewer threshold, `CODEOWNERS` file, Environment, secret, variable, App, bot or principal is created or changed. Nothing is re-armed ([[DEC-0033]] §8), no `workflow_dispatch` is fired, and the six DB-apply workflows remain exactly as they are.

### D11 — What remains `PROCESS ONLY`, enumerated rather than implied

After this record, the following bind by authority and review alone. **The list is stated so that no reader mistakes silence for coverage.**

* Whether a unit result carries its required items, its correct axes and no compound token ([[DEC-0040]] D11, D12, and the `PASS-WITH-RED` family prohibition).
* Whether every write a participant made is accounted for and correctly classified ([[DEC-0040]] D13).
* Whether a participant stayed inside its `write_scope`, in the repository or anywhere else.
* Whether `AUTHOR ≠ REVIEWER` and the reviewer-independence criteria actually held ([[DEC-0037]] D5, D7).
* Whether a `ZERO MUTATION` claim named the checks supporting it.
* Whether a new artifact declares its authority class ([[DEC-0035]] §7) — **still documentary in V2**, and expressly not implemented here.
* Whether an existing citation still resolves — **drift detection is refused by D4, not overlooked.**

### D12 — Effective on landing

Binding and prospective from the Product Lead's manual merge (§16). It re-examines no earlier unit and confers nothing backwards.

---

## 6. The seven-candidate decision matrix

Six candidates from [[DEC-0040]] §9 and one from [[DEC-0039]] §8, all adjudicated against the same criteria: does it address an observed NOXUND failure · can it observe the actual execution medium · deterministic · secret-free · without a second principal · without resurrecting `packages/orchestrator` · false-positive and false-negative risk · maintenance burden · bypassability · preventive or merely detective · does it create a new schema or DSL · does Phase D or F own the real problem · useful at current project size.

| # | Candidate | Disposition | The decisive reason |
|---|---|---|---|
| 1 | **Result-contract validator** ([[DEC-0040]] D11, D12) | `NOT MECHANICALLY BINDABLE WITH CURRENT SUBSTRATE` | **There is no artifact to validate.** `C1`–`C4` produced no result file; `docs/result/` holds two phase closeouts and nothing else. `C4` chose a **prose** contract and expressly declined a machine-readable one ([[DEC-0040]] D16). A validator could only check an optional template while the real result travelled past it in chat. |
| 2 | **Required-field check** ([[DEC-0040]] D12's six never-omitted items) | `NOT MECHANICALLY BINDABLE WITH CURRENT SUBSTRATE` | Same missing surface as 1, plus a second defect of its own: D12's **omission rule** makes absence semantically load-bearing — *"an item with no referent is OMITTED … an omission carries meaning"*. A presence checker cannot tell a meaningful omission from a skipped one, so even with a file it would enforce ceremony rather than the rule. |
| 3 | **Status-axis consistency check** | `DEFER / REJECT` | Two limbs, both fail. Against results: same missing surface as 1. Against repository text: the corpus contains **four** occurrences of `PASS-WITH-RED` and **every one is a prohibition or a citation of the prohibition** — in `handoff-template.md`, in [[DEC-0040]] D2's own prohibition, and in [[DEC-0040]] §9's routing of this very candidate. A lexical ban would flag the records that forbid the token and nothing else. Separating **mention from use** is semantic, and the defect has occurred **zero** times in repository text. |
| 4 | **Mutation-accounting check** ([[DEC-0040]] D13) | `NOT MECHANICALLY BINDABLE WITH CURRENT SUBSTRATE` | Repository CI cannot observe session scratchpads, system temp directories, memory files, out-of-repository files or external systems — and §4 item 6 verifies that **all three observed breaches happened only there**. Building it would create a false sense of sandboxing, which [[DEC-0039]] D12 forbids. See D7. |
| 5 | **Stale-reference / citation check** ([[DEC-0040]] D15) | **`IMPLEMENT NOW`** | The one candidate whose entire subject matter — written references on repository surfaces — is fully visible to a repository check, deterministically, with no secret and no second principal. It addresses a **verified, already-realised** NOXUND failure ([[DEC-0040]] §7). Landed at §8. |
| 6 | **Scratch / temp / out-of-`write_scope` detection** | `NOT MECHANICALLY BINDABLE WITH CURRENT SUBSTRATE` | Three sub-questions, answered separately below the table. |
| 7 | **Ruleset / protection-durability drift** ([[DEC-0039]] D11, **F4b**) | `NOT MECHANICALLY BINDABLE WITH CURRENT SUBSTRATE` | Needs an admin-scoped secret `C5` may not create; and, independently and decisively, **its baseline would be owned by the single admin it exists to detect**. See D9. |

### Candidate 6, split into the three questions it actually contains

* **(a) Repository-local writes outside a declared `write_scope`.** Not bindable, and the obstacle is not technical. **The `write_scope` lives in a Product-Lead writ, which is a chat artifact — there is no machine-readable scope declaration anywhere in the repository.** Creating one would mean inventing a schema (prohibited by D6), and it would be **written by the same participant it constrains**, making it self-certifying. **A control an author fills in about itself is not a control.**
* **(b) Committed scratch, temp, backup and sidecar files.** Technically buildable, cheap, near-zero false positives — and **`DEFER / REJECT`** all the same. It has **never fired**: no such file has ever been committed, and none of the three observed incidents took that path. Its real cost is not maintenance but **misreading**: a green *"no scratch files"* check sitting on a governance PR invites exactly the inference that no convenience writes occurred, when the writes that actually happened were invisible to it. **A control whose green is more misleading than its absence is a net negative**, and this record declines to trade a true silence for a false reassurance.
* **(c) Arbitrary session-scratchpad, system-temp and out-of-repository writes.** Not observable by any repository check, at any cost. **Routed, not built** — see D8.

---

## 7. Limb A — the locator repair, performed

[[DEC-0040]] §7 verified that `C2`'s two-line reconciliation note shifted every line of `docs/agents/product-orchestrator-agent.md` below its insertion point by `+2`, invalidating line-number citations across the landed corpus, and escalated four references as **`UNRESOLVED — LOCATOR ONLY`**. The Product Lead routed the repair here, ordered before Limb B.

**Both citing records are `FROZEN` but neither is byte-frozen** — [[DEC-0035]] §3.3 reserves that grade to [[DEC-0028]] and [[DEC-0033]] — so each may receive *"a clearly-marked additive forward-status note … appended by an authorized unit"*. One note is appended to [[DEC-0036]] and one to [[DEC-0037]], each at the very end of the file, **after the existing closing `Related` line, so that nothing already there shifts**.

**Each intended proposition was re-derived by this unit directly from the cited file at the canonical base**, not taken on trust from the routing.

| Citing record | Historical / stale locator | Durable identity now supplied |
|---|---|---|
| [[DEC-0036]] header · D2 | `:128` | §*Source of Truth*, opening paragraph — quoted in the note |
| [[DEC-0036]] header · D2 | `:384` | §*Agent Interaction Model*, opening paragraph — quoted in the note |
| [[DEC-0036]] header · D2 | `:790` | §*Output Format* › §*Decision sequencing*, closing line — quoted in the note |
| [[DEC-0037]] evidence-base header | `:565` | §*Task Decomposition Contract* › §*Regras de atribuição*, the exception clause — quoted in the note |

**A correction to the routed scope, recorded rather than absorbed.** [[DEC-0040]] §7 escalated the [[DEC-0037]] instance as `:565`. Re-derivation found the header's enumeration to be **three** bare locators in one sentence, not one. **All three are repaired**, because they are a single enumeration and repairing a third of it would leave the same defect standing. **This corrects the extent of a finding [[DEC-0040]] reported; it revises no adjudication, and [[DEC-0040]] is not edited.** The header's `:598` and `:599` drift is **reported for discoverability only** in the same note — [[DEC-0040]] §7 did not classify it `UNRESOLVED`, and this record does not either.

**The four rules that governed the repair, each observed:** no historical DEC text was rewritten; no old line number was replaced in place; `docs/agents/product-orchestrator-agent.md` was **not** edited to make an old number true again; and each note records that the drift is a **stale locator, not an authority defect** ([[DEC-0040]] D15), that nothing in the record's body is revoked, weakened or reopened, and that the record remains **`FROZEN`** and **`ACTIVE / CURRENT`**.

**Verified, not assumed: neither note is exempted from Limb B.** Both were run through the §8 control and pass **on their merits**, because each supplies a named section anchor and a verbatim quotation in the same context as the locator. **No baseline exception exists anywhere in the implementation, and none may be added.**

---

## 8. Limb B — the reference-durability control

**Implementation.** `tools/governance/check_reference_durability.py`, with `tools/governance/tests/test_check_reference_durability.py`. Python 3.11, standard library only, `unittest`. No third-party package, no Markdown parser, no network, no secret. It is not under `packages/**` — a pnpm workspace glob — and touches nothing in `packages/orchestrator`.

**The invariant it protects**, from [[DEC-0040]] D15:

> **`LINE NUMBER = LOCATOR / CONVENIENCE ONLY`.** A load-bearing reference must not rest on a line number as its sole semantic identity.

**Two rules.**

1. **`LOCATOR-ENUMERATION`, unconditional.** Three or more locators offered as one run with nothing but separators between them. A run is *defined* as breaking on anything else — a quotation, a parenthetical, an anchor — so a run carries no interleaved identity by construction, and **one nearby anchor cannot durably identify three distinct propositions**. No surrounding signal rescues it. This is the exact shape of both debts §7 repairs.
2. **`BARE-LOCATOR`, windowed.** One or two locators with **no** durability signal within 240 characters — no verbatim quotation, no `§` section anchor, no `D`-numbered decision id, no item, row or annex anchor. The threshold of three for rule 1 is deliberate: an adjacent pair is routinely one proposition that a single anchor can carry, and both boundaries are tested.

**Two distinctions the control keeps, and one it cannot.**

* **`MALFORMED REFERENCE`** — a locator is the sole semantic identity. Mechanically detectable; this is what fails.
* **`DRIFTED BUT DURABLE REFERENCE`** — the line moved, an anchor or quotation still identifies the proposition. Per [[DEC-0040]] D15 this is **not an authority defect** and **must not fail**. The control never opens the cited file, so it cannot fail on drift even in principle.
* **`MENTION versus USE`** — a locator run lying wholly inside a verbatim quotation is being *quoted*, not *made*, and is skipped. [[DEC-0040]] §7 quotes [[DEC-0036]]'s malformed enumeration in order to report it; flagging that would pressure an author into altering quoted historical text, which this corpus forbids outright.
* **What it cannot do** is stated at D4 and is not softened anywhere: it detects shape, judges no load-bearingness, and verifies no anchor semantically.

**Governed surfaces, and why.** `docs/product/decisions/**`, `docs/result/**`, `context-map.md`, `current-state.md`, `task-context-pack.md` — the INTERNAL-NORMATIVE decision corpus plus the routing surfaces an operator establishes authority from. **Out of scope, deliberately:** `docs/data/**` and the other evidence families, whose locator tokens are **source-code citations** (§4 item 8: 144 of 177 tokens, one file) — a genre that cites executable code by position for audit reproduction, not an authority proposition; `docs/agents/**` and `context/**`, which are cited *into* rather than citing, and are outside this unit's write scope in any case.

**Prospective only.** In `check` mode the control evaluates **only lines a pull request adds or changes**. No existing line is judged. This is not leniency — it is [[DEC-0040]] D15 applied exactly: the rule *"creates no general citation framework"* and *"imposes no retroactive obligation"*. **There is no baseline-exception list, and the design deliberately provides no mechanism to add one.** An `audit` mode exists for a maintainer to read the whole corpus; it is reporting, never a gate.

**Current-corpus baseline, run before enabling.** Over the **46** governed files at the canonical base the audit reports **13** findings. **None is silently baselined**, and each is classified:

| Classification | Count | Which |
|---|---|---|
| Within `C5` repair authority — **repaired by Limb A** | 3 | the two enumerations in [[DEC-0036]] and the one in [[DEC-0037]] |
| **False positive** — a durable identity the signal vocabulary does not recognise | 8 | named task labels (`C1 · DevOps`, `C5 = doc-only`) standing in for anchors; prose descriptors (*"the in-file note at …"*, *"(`Related` footer)"*); an intra-line back-reference to a clause quoted 1,200 characters earlier on the same line; and two **source-code** citations sitting inside a decision record, which the file-level scope filter cannot separate by genre |
| **Routed existing debt** — real, not escalated by [[DEC-0040]], outside `C5`'s write scope | 2 | one reference each in [[DEC-0037]] and [[DEC-0040]], both `FROZEN` |

**After this unit: 47 governed files and 11 findings, and the arithmetic is disclosed rather than presented as a better baseline.** The control **fired on `C5`'s own reconciliation diff** — three times. One was a bare back-reference this unit had just written in `current-state.md`; two were pre-existing `context-map.md` §2 citations that entered prospective scope **because this unit edited the line they sit on**, which is the intended behaviour of line-granular scope. **All three were fixed by supplying anchors, none by an exemption**, and that is why the false-positive row falls from 8 to 6. **The control catching its own author is the most useful evidence in this section**, and it is recorded as such.

**Read the first row correctly.** Limb A repairs the *reference* by supplying durable identity at the citing end; it does **not** rewrite the frozen sentence, so those three lines still carry their historical shape and the audit still reports them. **That is the correct outcome, not an unfinished one** — and it costs nothing, because prospective scope never evaluates an existing line, so no exception is needed and none exists.

**Thirteen findings across the whole corpus is small enough that no cleanup is implied, and none is authorized.** `C5` is not historical normalization. **If this ever became noisy, the correct response is to narrow the governed scope — never to add exceptions.**

**Testing.** Forty `unittest` cases: the malformed shapes that must fail, the durable shapes that must pass, both enumeration boundaries at two and three, mention-versus-use, false-positive guards, diff parsing and line numbering, governed-scope membership, the CLI exit codes, and the current corpus. **Four cases assert what the control does *not* detect** — drift, anchor semantics, load-bearingness, and a meaningless token accepted as an anchor — and **a fifth pins the false positives it *does* produce** on colon-numbers that are not locators at all (§13 item 5), asserting the actual behaviour rather than the desired one. **The limits at D4 are therefore enforced by the suite, not only by this prose**, and a future change to detection semantics has to break a test deliberately rather than quietly.

---

## 9. CI binding status

One workflow is added: `.github/workflows/governance-checks.yml`. **It is the first workflow in this repository that runs on a governance pull request** (§4 item 3).

> **`AUTOMATIC DETECTIVE · NOT MECHANICALLY MERGE-BLOCKING`** — and this is not a caveat, it is the classification.

`permissions: contents: read`. Zero secrets, zero Environments, zero database or cloud access, zero `pip install`. Both actions SHA-pinned, matching the `data-engine-tests.yml` idiom. Its `workflow_dispatch` trigger takes no input and has no side effect: it runs the reporting audit. It re-arms nothing.

**Why it cannot block:** §4 item 1 — `Protect main` has no `required_status_checks` rule, and `C5` is forbidden to add one. A failing run is a red mark on the PR that the Product Lead can see and merge past. **Recording that plainly is the point of D1.**

---

## 10. Boundaries

**Phase D — not this record.** Documentation-quality standards, general testing policy and code-quality policy are Phase D. The forty tests here validate `C5`'s own implementation and **create no repository-wide testing policy**. The `docs/product/decisions/**` header-classification check that [[DEC-0035]] §12 already routes, and which [[DEC-0039]] §8 lists as its own candidate, is **observed as adjacent and deliberately not implemented**: it was not among the seven this unit was authorized to adjudicate, [[DEC-0035]] §7 keeps the rule documentary in V2, and D2 prefers fewer controls to more. It is named here so a later unit finds it, and it is **not** thereby authorized.

**Phase F — not this record, and constrained by it.** The controlled executor, wrapper or sandbox that D8 says real write-scope prevention would require is **Phase F**, as is the out-of-band observer D9 says F4b detection would require. **Naming them routes them; it authorizes nothing**, and no future unit may cite this record as permission to build either. [[DEC-0040]] D8 continues to govern: no status field auto-authorizes a stage, and a Product-Lead GO has no automated substitute.

**Axis 1 — untouched.** Nothing here reaches the product or engineering axis, the database, Supabase, AWS or collection. Nothing is re-armed ([[DEC-0033]] §8).

**`packages/orchestrator` — untouched.** Its **REDUCE** disposition stands ([[DEC-0038]] D1); no file under it is read into use, adopted, edited or deleted (D3), and no preserved primitive is resurrected.

---

## 11. Forward discoverability

[[DEC-0035]] §10 requires the forward-discoverability update to be created **in the same authorized unit** that creates the relation. [[DEC-0039]] and [[DEC-0040]] are `FROZEN` and are not edited, so the edges are created externally, in the relation table at `docs/product/context-map.md` §3 — the mechanism §10 directs for that case.

1. **`DEC-0041 EXTENDS DEC-0040 §9`** — supplying the `C5` limb §9 routed. `EXTENDS` rather than any supersession grade: §9 reserved work for a later authorized unit and this record supplies it; nothing in [[DEC-0040]] is replaced, narrowed or declared wrong, and §9's own statement that each candidate *"requires `C5`'s own explicit Product-Lead GO"* remains exactly true.
2. **`DEC-0041 DISCHARGES DEC-0040 D15 · §7`** — by satisfaction, both limbs of the routing decision. `DISCHARGES` rather than `EXTENDS` because §7 stated a **requirement to perform**, and performance spends it: Limb A is done and Limb B is landed.
3. **`DEC-0041 DISCHARGES DEC-0039 D11 · §8`** — by satisfaction of the **venue**, and the scope column says so precisely: `C5` was assigned to adjudicate the enforcement candidates and has adjudicated them. **F4b's detection requirement is not satisfied** — it is re-routed out-of-band by D9 — and D11's `ACCEPTED CURRENT LIMITATION` disposition is neither rewritten nor reopened.
4. **`DEC-0041 REDIRECTS-TO DEC-0036 · DEC-0037`** — reader-side only, in the [[DEC-0039]] idiom: a reader arriving at either record's line-number citations should read the `C5` additive forward-status note at the end of that file for the durable identity. **`REDIRECTS-TO` rather than `NARROWS`**, because nothing in either record is narrowed — a locator was repaired, and D1–D6 and D1–D16 respectively are untouched.

**This unit is incomplete without all four rows.**

---

## 12. Reconciliation performed by this unit

Bounded to what this decision makes stale. Scoped, dated, additive where the surface is historical.

1. **`current-state.md` §B** — the Axis-2 ladder records `C5` as landed and the authority paragraph records that landing it authorizes nothing further.
2. **`current-state.md` §E** — the bullets this decision makes stale: the `F4b` detection routing, the *"mechanical enforcement remains Phase-C unit `C5`"* claim, the `AgentResult` and result-contract statements as they bear on a validator, and the drift bullet's account of the four unrepaired citations.
3. **`current-state.md` freshness contract** — a scoped-reverification paragraph naming this unit's base, stating what was re-derived and what still rests on earlier verifications.
4. **`context-map.md` §3** — the four relation rows §11 requires. **`context-map.md` §1 and §2** carry the `C5` state where they route it.

**No wider sweep.** Every other claim in both documents still rests on the `B5` / `B6` / `C1` / `C2` / `C3` / `C4` verifications.

---

## 13. Known weak points, disclosed by the Author

Stated here rather than left for a reviewer to find.

1. **The 240-character window and the threshold of three are judgment calls.** Both are tested at their boundaries and documented at the point of definition, but neither is derived from a principle — they are tuned against this corpus, and a differently-written corpus would want different values.
2. **The control's false-positive rate on the current corpus is 8 in 13 at the canonical base, 6 in 11 after this unit.** Every one is a reference whose durable identity exists in a form the signal vocabulary does not recognise — a prose descriptor, an intra-line back-reference, a genre the file-level filter cannot separate. **Prospective scope means none of them gates anything today**, but an author writing in those styles on a governed surface will meet a false failure — as this unit did, three times, on its own diff. The remedy available to them is to add an anchor, which is the behaviour the control exists to encourage; the remedy prohibited to them is an exception.
3. **`§` is a very common token in this corpus**, so rule 2 rarely fires inside ordinary prose paragraphs and does most of its work on terse bullets and table cells. Rule 1 carries the load against the shape that actually caused the failure.
4. **The `REPORTED` claim at §4 item 4 was not upgraded to `VERIFIED`.** D9 is built so the disposition does not depend on it, but the claim itself remains unproven by execution in this unit.
5. **Any colon-number on a path-bearing line is read as a locator, and the guard against this is far weaker than `C5` first described it.** The colon form requires a path token earlier on the line. **`R1` claimed that requirement *"excludes clock times, ratios and stray numerals from ever being read as citations"*. That claim was false, and the independent reviewer falsified it.** The requirement removes the **no-path class only**. On a line that names a file — which is most lines on a governed surface — **`postgres:15`, `09:45`/`11:20`, `4:0` and `3:1` are all flagged `BARE-LOCATOR`**, verified by execution. Only a line with **no** path token at all is genuinely excluded.
   **The correction is a disclosure, not a behaviour change.** Detection semantics are untouched: narrowing the colon form is a separate decision with its own false-negative cost, and it is **not** taken here. The class is now pinned by an explicit test asserting the **actual** behaviour, so it cannot be described as excluded again and cannot be quietly widened away. **Prospective scope means it gates nothing today, and the remedy for an author who meets it is an anchor — never an exception.**
   **This mattered enough to be material:** D1 makes it binding that a control is never described as stronger than the mechanism carrying it, and `R1` committed exactly that error inside the delivered control's own documentation.
6. **One control against seven candidates will read as thin to anyone counting.** That is D2's decision and not an accident, and §6 gives the reason for each refusal individually rather than as a blanket.

---

## 14. What this record does **not** decide

The class of any artifact other than what §5 classifies · any `OD-*` item · any product-scope question · whether any future unit should build the Phase-F executor or the out-of-band ruleset observer · the header-classification check [[DEC-0035]] §12 routes · any reviewer-count value, `CODEOWNERS` content or branch-protection setting · the disposition of `packages/orchestrator`, which is landed and is **REDUCE**.

---

## 15. Explicit non-decisions

This record does **not** and must not be read to: create or modify any GitHub ruleset, required status check, branch protection, reviewer threshold, `CODEOWNERS` file, Environment, secret, variable, credential, App, bot, account, principal or trust anchor · register, activate, wire or configure any agent · create an `AgentResult` V2, a machine-readable result schema, a result DSL or a `TaskCommand` redesign · adopt, port, copy, edit or delete anything under `packages/**` · edit any prior DEC body, or anything under `docs/agents/**` or `context/**` · describe any control as preventive or merge-blocking · authorize Phase D, Phase E or Phase F work · authorize any successor unit on either axis · resume Axis 1 · re-arm anything · authorize any commit, push, PR, merge, dispatch or execution of any kind.

---

## 16. Effective and landing semantics

**Effective on the Product Lead's manual merge of this record**, and prospective from that moment. Landing it authorizes **no** further unit: `C5` is the sixth `C*` unit and, like every one before it, its GO expired with it ([[DEC-0035]] §6). **`NEXT` is never authorization** ([[DEC-0040]] D8). A `C6`, a Phase-C closeout, Phase D and Phase F all require their own explicit Product-Lead GO.

**The control lands in the state this record describes and no other.** If a later reader finds it gating a merge, that is a change some other unit made, and this record does not sanction it.

---

*Related: [[DEC-0040]] D5 (the unconditional breach invariant), D11 and D12 (the result contracts a validator would have needed), D13 (mutation accounting), D15 and §7 (evidence-reference durability and the verified drift finding), §9 (the six routed candidates); [[DEC-0039]] D7 (role scoping is not a sandbox), D9 (P3 — HYBRID), D11 (F4b), D12 (least privilege as it stands), §8 (the seventh candidate); [[DEC-0038]] D1 and D3 (REDUCE, zero code action); [[DEC-0037]] D5 (`AUTHOR ≠ REVIEWER`), D8, §9; [[DEC-0036]] and its `C5` additive forward-status note; [[DEC-0035]] §3.3 (FROZEN admits an additive note), §6 (GO versus durable authority), §7 (fail-closed classification, documentary in V2), §9 (family defaults), §10 (forward discoverability), §12 (Phase-C boundary). Routing surfaces reconciled: [`context-map.md`](../context-map.md), [`current-state.md`](../current-state.md).*
