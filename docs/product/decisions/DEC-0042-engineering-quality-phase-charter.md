# DEC-0042 — Engineering quality: Phase-D charter

**Status:** ACTIVE (binding) · **Date:** 2026-08-21 · **Decision authority:** Product Lead
**Authority class:** INTERNAL-NORMATIVE · **Lifecycle:** ACTIVE / CURRENT · **Mutability:** FROZEN — the `docs/product/decisions/**` family default ([[DEC-0035]] §9), declared here under the fail-closed rule of [[DEC-0035]] §7. **Verified rather than copied:** that family row's named exceptions are [[DEC-0028]] and [[DEC-0033]] (byte-frozen, `PARTIALLY-SUPERSEDED`), [[DEC-0005]] and [[DEC-0021]] (`SUPERSEDED`), [[DEC-0001]] (`DRAFT / PROPOSED`) and [[DEC-0003]] (mixed at clause level); this record is none of them, so the default applies unmodified.
**Drafted by:** a task-scoped Author, reviewed by a **distinct** task-scoped independent reviewer, under the topology [[DEC-0037]] D5 fixes. The Product Lead's own explicit **Phase-D** and **`D0`** GO — not any earlier phase GO — is what authorized this unit ([[DEC-0035]] §6). **Ratification gate:** the Product Lead's manual merge of this record ([[DEC-0037]] D11).
**Scope:** The charter of improvement **Phase D — engineering quality**. It fixes the purpose of the phase, the surfaces it may act on, the quality domains it recognises, the evidentiary standard a quality requirement must meet before it may bind, the vocabulary in which a control's strength is stated, the boundaries against Phases C, E and F and against Axis 1, the authorization semantics of every `D` unit, and the condition under which the phase may close. **Docs-only unit.**
**Negative scope — this record does not create or change:** any threshold, budget, percentage, limit or numeric target of any kind · any lint, formatter, type-checker, test framework, coverage tool, scanner or other tool adoption · any workflow, workflow registration, ruleset, branch protection, required status check, reviewer threshold, `CODEOWNERS` file, Environment, secret, variable, credential, App, bot or principal · any package manifest, lockfile, compiler configuration, dependency or engine constraint · any file under `apps/**`, `packages/**`, `services/**`, `tools/**`, `infra/**`, `db/**`, `supabase/**`, `.github/**`, `docs/agents/**` or `context/**` · any agent registration, activation, contract, boundary or runtime wiring · `packages/orchestrator/**` in any respect, including its **REDUCE** disposition · any database, SQL, migration, role, runner, cloud or collection state · any product scope, MVP admission or `OD-*` item · memory content. **Nothing is installed, nothing is dispatched, nothing is re-armed ([[DEC-0033]] §8), and no execution of any kind is authorized.**
**Extends:** [[DEC-0041]] §10 *Boundaries*, which named this venue in terms — *"Documentation-quality standards, general testing policy and code-quality policy are Phase D"*. **The limit is stated rather than left to be assumed: this record opens that venue and expressly does not supply its content.** No standard, policy, threshold or tool named by that clause is set here; each remains the subject of a later `D` unit under its own GO (§D6, §D16). [[DEC-0041]] is neither edited nor narrowed and remains **CURRENT**.
**Does not edit:** any prior DEC body. [[DEC-0001]] … [[DEC-0041]] all remain **frozen and additive-only**; [[DEC-0028]] and [[DEC-0033]] remain **byte-frozen** per [[DEC-0034]] §4. **No forward-status note is appended to any of them** — this unit is not authorized to append one. No prior record is declared obsolete, superseded, reopened or reinterpreted, and no file under `docs/agents/**` is touched.
**Evidence base — re-derived at the canonical base, not inherited:** the executed offline runs and read-only repository and GitHub reads recorded in [`PHASE-D-D0-ENGINEERING-QUALITY-BASELINE-R1`](../../result/PHASE-D-D0-ENGINEERING-QUALITY-BASELINE-R1.md) §*Commands executed*, on whose findings this charter's reasons rest; [[DEC-0035]] §3.1, §4 P4, §6, §7, §9, §10; [[DEC-0037]] D1, D5, D8, D11; [[DEC-0038]] D1, D3; [[DEC-0039]] D4, D7, D12; [[DEC-0040]] D3, D8, D13, D15; [[DEC-0041]] D1, D2, D5, D10, D11 and §10; [`PHASE-C-CLOSEOUT-R1`](../../result/PHASE-C-CLOSEOUT-R1.md) §7, §12, §13; `current-state.md` §B and §E; `context-map.md` §1 through §4.
**Canonical base:** `main` @ `9f12680d329a6107693bdd9f1b077fdfb17dd0dc`

---

## 1. Status

**ACTIVE — binding and prospective**, effective on the Product Lead's manual merge (§11). It is a charter: it governs how Phase-D units are scoped, argued and bounded. It authorizes no unit, adopts no tool, sets no threshold, changes no configuration and confers nothing backwards in time.

---

## 2. Why this record exists

Phase C closed with the governance system determinable: who may act, what each actor can technically do, what a result means, and how much of it a machine actually enforces. **What Phase C deliberately did not touch is whether the code itself is any good, and whether anything would tell us if it stopped being so.** [[DEC-0041]] §10 said as much and routed it here.

The `D0` baseline found a repository that is **not uniformly weak and not uniformly strong** — which is precisely why a charter is needed rather than a cleanup sprint. One half of the codebase carries genuinely disciplined engineering: hash-locked dependency pins, byte-identical determinism reproduced across two platforms, fail-closed count assertions in CI, and error handling with no bare exception handler anywhere in the tree. The other half has never had a single automated check run against it, in the entire history of the repository.

A phase facing that asymmetry can fail in three ways, and this charter exists to make each one hard.

- **It can spend its effort where the code is, rather than where the risk is.** The largest single body of source in the tree is legacy that nothing imports and no workflow runs.
- **It can adopt thresholds because they are conventional rather than because a measured failure justifies them.** A coverage percentage chosen by reputation is a number nobody can defend when it starts blocking work.
- **It can produce green signals that mean less than they appear to.** The repository already contains one instance of this shape: a linter is configured, its suppression codes are written into source, and it is installed and invoked nowhere. That is not a small thing. It is a control that reads as present and is absent, and [[DEC-0041]] D1 already forbids describing such a thing as enforcement.

This charter answers those three, and stops.

---

## 3. What this record is not

It is **not** an engineering-quality standard. It sets no coverage percentage, no lint-warning budget, no complexity or file-length limit, no bundle size, no performance target and no dependency-age rule. Where a threshold appears warranted, §D6 states what must be established first and §D16 states who may authorize the unit that establishes it.

It is **not** an adoption decision. No linter, formatter, type-checker, test framework, scanner or CI mechanism is selected, installed, configured or recommended into existence here.

**External standards inform; they never bind.** No requirement below rests on a practice being conventional, popular or recommended elsewhere. Each answers one question instead: *what observed NOXUND engineering failure or risk does this prevent or expose?* A requirement that cannot answer it does not belong in this record, and none is included that could not.

---

## 4. Decision

### D1 — Purpose of Phase D

> **Phase D exists to make the engineering quality of NOXUND's active code observable, and to make its defects detectable before they reach `main` — not to raise a quality score.**

The objective is the **absence of silent surfaces**: a surface on which a change can land with no signal firing and no reader able to tell that nothing fired.

**The reason, from evidence rather than principle.** The baseline established that an entire language half of the repository has never been exercised by any automated check at any point in the repository's history, and that a pull request touching it displays no checks at all — not a failing check, not a skipped check, **no checks**. The hosting platform raises no warning for that state, so its rendering is indistinguishable from a clean pass to any reader who does not already know which paths are covered. **A confident absence is worse than a visible gap**, and removing that specific failure mode is what Phase D is for.

### D2 — Scope

Phase D may act on:

1. **Toolchain coherence** on active surfaces — manifests, lockfiles, engine constraints, compiler configuration, and the agreement between them and the documents that describe them.
2. **Quality signals** — automated checks that observe an active surface and report deterministically.
3. **Invocability and parity** — that a developer and CI can run the *same* command against the same surface, rather than two transcriptions of one intent.
4. **Adjudication of static analysis** per active surface, including the decision **not** to adopt one.
5. **Documentation that describes a build, test or quality path**, where it is stale or would mislead a reader into a destructive action.
6. **The routing of quality debt** that a later unit or a later phase must own.

Each of the six is a category, not a task list. A `D` unit takes a bounded slice of one or more and requires its own GO (§D16).

### D3 — Non-scope

Phase D does **not**: build product features, resume Axis 1, or advance the MVP by one step (§D12) · redesign agent governance (§D13) · adopt external skills or capability packages (§D14) · create autonomous or self-remediating machinery (§D15) · change any ruleset, required status check, reviewer requirement or `CODEOWNERS` file, each of which is an **authority interaction** out of any `D` unit's reach absent its own explicit Product-Lead decision ([[DEC-0041]] D10) · delete, port, adopt or resurrect anything under `packages/orchestrator/**`, whose **REDUCE** disposition stands untouched ([[DEC-0038]] D1, D3) · re-arm any write capability the Unit-D containment removed ([[DEC-0033]] §8).

### D4 — Active-surface-first rule

> **Quality effort is proportional to a surface's current standing. Containing code earns a surface nothing.**

Every `D` unit states, for each surface it proposes to touch, which of four standings that surface holds — and the standing governs what may be spent on it.

| Standing | Meaning | Phase-D treatment |
|---|---|---|
| **ACTIVE PRODUCT** | reached by a current execution path, or by the intended one | full quality investment |
| **ACTIVE TOOLING** | supports development or governance and is genuinely run | investment proportionate to what breaks if it fails silently |
| **ACTIVE-BUT-UNREACHED** | declared and maintained, currently imported by nothing | make it coherent; do not build machinery around it |
| **LEGACY / PRESERVED / HISTORICAL** | landed but non-authoritative, or retained as evidence | **no quality investment** (§D11) |

**The reason.** The single largest body of source in the tree is the legacy control plane, which [[DEC-0038]] D1 reduced to *"NON-AUTHORITATIVE legacy"* and which the baseline re-confirmed is imported by no executable file and referenced by no workflow. Ranking work by volume would have put it first. Ranking by standing puts it out of scope, which is the correct answer — and stating the rule in advance is what prevents the wrong one being reached by accident later.

### D5 — Quality-domain taxonomy

Phase D recognises **ten** domains. They are durable categories for organising work and reporting state; **they carry no threshold, no target and no score, and none may be introduced by naming one.**

| # | Domain | The question it asks |
|---|---|---|
| **Q1** | **Build integrity** | Does every active surface build or load by a defined, repeatable command? |
| **Q2** | **Type and static correctness** | Is each active surface checked against the strictest configuration it actually declares, and does the configuration it declares match the one documented for it? |
| **Q3** | **Automated test surface** | Does a suite exist that exercises the behaviour the surface is relied on for? |
| **Q4** | **CI coverage** | Does a change to this surface cause any automated signal to fire? |
| **Q5** | **Dependency, lock and install reproducibility** | Does the same declared input install the same resolved closure, on every workspace, every time? |
| **Q6** | **Quality-gate consistency** | Can the repository state one minimum pre-merge expectation per active surface, and is that expectation the same one a developer can run? |
| **Q7** | **Maintainability and simplicity** | Is the structure legible, layered and free of accidental duplication? |
| **Q8** | **Error and failure semantics** | Does failure surface, or is it swallowed? |
| **Q9** | **Output determinism** | Do identical inputs produce byte-identical outputs, across processes and across platforms? |
| **Q10** | **Quality observability** | Can a reader tell what ran, what passed, and — decisively — what did not run at all? |

**Q5 and Q9 are deliberately separate domains and must not be merged.** Q5 asks whether the *inputs* are reproducible; Q9 asks whether the *outputs* are. The baseline found this repository strong on one and uneven on the other **on the same surfaces**, which is a fact that is only sayable if the two are kept apart.

**No measurement appears in this record** (§5).

### D6 — Evidence-before-threshold rule

> **A threshold binds nothing until the evidence for it is on the record. Absent any element below, the question is routed, not decided.**

Before any numeric threshold, budget, percentage or limit may be adopted by a `D` unit, that unit must establish and record all six:

1. **a measured baseline** — what the value is now, on the surface it would govern;
2. **a concrete failure mode** — what goes wrong when it is breached, stated as a defect that could actually occur here;
3. **the expected benefit** — what the threshold detects that nothing currently detects;
4. **the enforcement mechanism**, classified under §D8 — and where it is `PROCESS ONLY`, said so;
5. **the maintenance cost** — who updates it, when, and what happens when it drifts;
6. **a false-positive analysis** — what legitimate work it would block, and what remedy the author has.

**The reason.** [[DEC-0041]] D2 established the governing preference in the enforcement domain — *"FEWER REAL CONTROLS > MORE CONTROLS THAT DO NOT OBSERVE THE WORK"* — and it transfers directly. A threshold with no measured baseline cannot be known to be either achievable or demanding; a threshold with no false-positive analysis produces authors who learn to route around it. **Both outcomes are worse than the absence they replace.** This rule is also why this record sets no threshold at all: `D0` measured, and measurement alone satisfies one element of six.

### D7 — Tests, CI and static checks are three different things

> **`TESTS EXIST` ≠ `TESTS COVER CURRENT ACTIVE BEHAVIOR` ≠ `TESTS RUN IN CI`.**

Every Phase-D statement about testing names which of the three it asserts. A claim that does not is **malformed** and must be restated.

**The reason.** All three states occur in this repository simultaneously, on different surfaces, and the baseline had to separate them in order to describe any of them accurately. One suite exists, covers current behaviour and runs in CI. Another exists, covers its target, and has never run in CI because it sits on a surface no workflow watches. A third exists against a surface [[DEC-0038]] D1 reduced to legacy, so it covers behaviour nothing relies on. **Collapsing the three would make each of those look like the others**, and the most dangerous collapse is the one that reads existence as coverage.

The same discipline applies to static analysis, for a reason the baseline found in the tree rather than in theory: **a configured linter that is installed nowhere and invoked by nothing is not a static-analysis surface**, however many suppression comments for it are written into source.

### D8 — Control strength: detective versus merge-blocking

[[DEC-0041]] D1's vocabulary is **inherited unchanged and is binding on every Phase-D record, unit writ and unit result**: a control is **`PREVENTIVE`** (*"The action cannot proceed while the control rejects it"*), **`AUTOMATIC DETECTIVE`** (*"Checked automatically, deterministic signal, visible without being asked — but the action can still proceed"*) or **`PROCESS ONLY`** (*"The rule exists; no machine binds it"*). Nothing is added to that vocabulary and nothing is removed from it.

> **No Phase-D control may be described as merge-blocking unless repository rules actually make its success required.**

**The reason, re-derived at this base rather than inherited:** the `main` protection ruleset carries a pull-request rule, a deletion rule and a non-fast-forward rule, and **no required-status-checks rule**; its required approving review count is zero. **Every check any `D` unit adds is therefore `AUTOMATIC DETECTIVE` and nothing stronger**, and will remain so until a separately authorized unit changes repository rules — which is an authority interaction no `D` unit holds (§D3).

### D9 — Reproducibility principle

> **A quality signal that cannot be reproduced on demand is an anecdote.**

Every Phase-D control must be **deterministic** (same input, same verdict), **locally reproducible** (a developer can run it and get what CI got), and **honest about its inputs** (a check that depends on an unpinned resolution says so).

**The reason, and it is the strongest positive evidence in the baseline:** this repository already demonstrates the standard on part of its surface. Its Python dependency pins are exact and hash-locked, with installation constrained so that an unpinned or hash-mismatched artifact is refused; and its pipeline digest was re-derived at this base on a different operating system from the one CI locked it against, and matched byte for byte. **Phase D therefore does not introduce a reproducibility requirement. It extends one the repository already meets, to the surfaces that do not meet it.**

### D10 — Quality-gate honesty rule

> **A gate must not claim a surface it does not validate. A name broader than its mechanism is a defect, not a convenience.**

A Phase-D control's name, its job name, its step names and every document describing it must be true of what it actually observes. Where a check covers a subset of the surface its name suggests, the writ and the record say which subset.

**The reason.** [[DEC-0041]] §6 refused a buildable control on exactly this ground — that a green *"no scratch files"* signal *"invites exactly the inference that no convenience writes occurred"* when the writes that actually happen are invisible to it — and concluded that **a control whose green is more misleading than its absence is a net negative**. Phase D operates where that hazard is larger, not smaller: it will add checks that genuinely cover *some* of the currently unchecked code, and a name suggesting they cover all of it would manufacture the very confident-absence problem §D1 exists to remove.

### D11 — Legacy and preserved surfaces

Surfaces classified **LEGACY**, **PRESERVED** or **HISTORICAL** receive **no quality investment**: no tests added, no linter pointed at them, no CI job created for them, and no refactor.

They are, equally, **not deleted, emptied, moved or edited by any `D` unit**. [[DEC-0038]] D3 is unchanged and is repeated here so it cannot be mislaid: *"REDUCE is a status decision, never a deletion instruction, and no future unit may cite this record as authorization to remove code."* **`PRESERVED` is not `ADOPTED`, and `NOT INVESTED IN` is not `TO BE REMOVED`.**

**One thing a `D` unit may do**, and it is a documentation act rather than a code act: where a document presents a legacy surface as the active architecture, correcting that document is in scope, because [[DEC-0038]] D1 requires that *"no document may present it as such"*. Correcting a description changes no code and disposes of nothing.

### D12 — Axis-1 boundary

**Phase D is Axis 2 and touches Axis 1 nowhere.** No `D` unit may resume collection, decide or provision the successor PostgreSQL architecture, apply or author a migration, touch a database, cloud resource or Environment, dispatch or re-enable any workflow, or advance any product feature.

The database-apply workflows stay disabled at platform level; the collection workflows stay disarmed and fail-closed on an absent marker; nothing is re-armed ([[DEC-0033]] §8). **Where Phase-D work would improve an Axis-1 asset, the improvement is routed to Axis 1 and not performed** — `current-state.md` §B *"Two axes — do not conflate them"* governs, and the exact Axis-1 resumption point remains a Product-Lead decision.

### D13 — Phase-C interaction

Phase D **consumes** the Phase-C system and does not amend it: the actor taxonomy and topology ([[DEC-0037]] D1, D5), the capability and technical-principal model ([[DEC-0039]] D7, D12), the result and disposition contract ([[DEC-0040]] D3, D13), and the enforcement vocabulary and the one landed governance check ([[DEC-0041]] D1, §8).

No `D` unit may **redesign agent roles**, revisit the **REDUCE** disposition, change the **P3 — HYBRID** principal decision, alter `RED` semantics or any other status axis, introduce principal separation, or expand governance enforcement beyond what [[DEC-0041]] landed.

> **Where a quality proposal would materially change agent governance, it is not a Phase-D unit. It is routed as an authority interaction and escalated to the Product Lead.**

**The reason.** The two systems meet at real points: a required status check would change what `AUTOMATIC DETECTIVE` means for the governance check; a `CODEOWNERS` file would change the review topology; a wrapper enforcing write scope is the controlled executor [[DEC-0041]] D8 expressly refused to build. **Each of those is an engineering change with a governance consequence**, and letting a quality unit make one incidentally is exactly how a governance model gets amended by a side effect rather than by a decision.

### D14 — Phase-E boundary

External skills, capability packages, agent tooling and third-party orchestration integrations are **Phase-E candidates**. No `D` unit adopts, integrates, evaluates or pilots one, and naming one places it without authorizing it ([[DEC-0033]] §8).

**The distinction that keeps this workable, stated so it is not over-applied:** an ordinary engineering dependency genuinely necessary to a later `D` unit — a linter that unit adjudicates and adopts, a test runner it selects on stated grounds — **is not thereby a Phase-E item.** Phase E concerns *external capability acquired into the development system*; Phase D concerns *the engineering of NOXUND itself*. **What makes such an adoption a `D` act is that a `D` unit argued it under §D6 and the Product Lead authorized that unit.** Absent that, it is neither a `D` act nor an `E` act; it is unauthorized.

### D15 — Phase-F boundary

No `D` unit may create an autonomous loop, a self-fixing agent, a persistent orchestrator, automatic remediation, automatic merge, automatic GO, or a sandbox or controlled-executor architecture.

[[DEC-0040]] D8 governs, and here it is a constraint rather than a permission: *"NEXT CANDIDATE is not GO. NEXT is not GO. READY is not GO. RECOMMENDED is not GO."* A Phase-D check reports; a human decides what follows. **A control that repairs what it detects has stopped being a control and become an actor**, and creating one requires an authority this charter neither holds nor confers.

### D16 — `D`-unit authorization semantics

> **Every Phase-D unit requires its own explicit Product-Lead GO, scoped to that unit and expiring with it** ([[DEC-0035]] §6; [[DEC-0037]] D11).

A roadmap position, a prerequisite ordering, a `NEXT CANDIDATE` nomination and a named unit label are **placements, never permissions** ([[DEC-0033]] §8; [[DEC-0040]] D8).

> **Landing this charter authorizes nothing.** It does not authorize `D1` or any later `D` unit, does not authorize Phase E or Phase F, does not authorize any Axis-1 resumption, and re-arms nothing.

### D17 — Proposed closeout condition for Phase D

**Proposed, not self-executing.** Phase D closes when the Product Lead accepts that all five hold, and that acceptance is the Product Lead's alone ([[DEC-0039]] D4).

1. **Every active surface has a stated minimum quality expectation**, or a recorded decision that it has none, with the reason.
2. **Every active surface has at least one automatic signal**, or a recorded adjudication that none is justified on that surface.
3. **Every quality gate is classified** `PREVENTIVE` / `AUTOMATIC DETECTIVE` / `PROCESS ONLY`, and none is described as stronger than its mechanism (§D8, §D10).
4. **Local and CI invocation of each active surface's quality command are the same command**, or the difference is recorded as an accepted limitation with its reason.
5. **Remaining quality debt is routed** — to a later unit, to Phase E or F, or to Axis 1 — and none of it is represented as solved.

**Deliberately absent from that list:** any coverage figure, any defect count, any tool inventory and any score. **Phase D closes on observability and honesty, not on a number** — and a closeout condition expressed as a number would have been the first violation of §D6.

---

## 5. Two constraints on this record itself

**No transient counts.** Test totals, file counts, workflow counts, finding counts and volume figures are measurements of a moving repository and are recorded in [`PHASE-D-D0-ENGINEERING-QUALITY-BASELINE-R1`](../../result/PHASE-D-D0-ENGINEERING-QUALITY-BASELINE-R1.md), never here.

**The justification is in-repository and was re-derived rather than assumed.** [[DEC-0041]] §8 recorded a governed-file count for the reference-durability audit, measured at that record's own base. Running the same audit at this base returns a governed-file count **one higher**, with the finding list unchanged — because unit `C6` added a governed file after that record was written. **Nothing failed.** The corpus grew exactly as intended, and a number frozen into a `FROZEN` record went stale on the very next unit. **A `FROZEN` normative record must not depend on a number that ordinary correct work changes.** This record therefore states no new one, and deliberately restates neither figure, because doing so while explaining the rule would reproduce the defect being described.

**No threshold.** Stated at §D6 and applied to this record without exception: no percentage, count, limit, budget or target of any kind appears in §4.

**No external authority.** Stated at §3. Every requirement in §4 answers to an observed NOXUND finding recorded in the `D0` baseline; none rests on a practice being conventional elsewhere.

---

## 6. Forward discoverability

[[DEC-0035]] §10 requires the forward-discoverability update to be created **in the same authorized unit** that creates the relation. [[DEC-0041]] is `FROZEN` and is not edited, so the edge is created externally, in the relation table at `docs/product/context-map.md` §3 — the mechanism that clause directs for this case.

1. **`DEC-0042 EXTENDS DEC-0041 §10`** — opening the Phase-D venue that clause named, **without supplying its content**. `EXTENDS` rather than any supersession grade: §10 stated a boundary and reserved work for a later phase; nothing in [[DEC-0041]] is replaced, narrowed or declared wrong, and its rule that each unit requires its own explicit Product-Lead GO is restated at §D16 rather than relaxed.

**This unit is incomplete without that row**, and without the §1 index rows and the §2 registry entries recording that Phase D now has a landed defining record.

---

## 7. Reconciliation performed by this unit

Bounded to what landing this record makes true. **No wider sweep.**

1. **`current-state.md` §B** — the Axis-2 ladder records Phase D as **STARTED** with `D0` complete, and the *Provenance* and *Authority* paragraphs record that D now has a landed defining record while **E and F do not**, and that landing it authorizes nothing further.
2. **`current-state.md` freshness contract** — a scoped-reverification paragraph naming this unit's base and stating exactly what was re-derived and what still rests on earlier verifications.
3. **`context-map.md` §1** — index rows for this record and for the `D0` baseline record.
4. **`context-map.md` §2** — the `Phase A … Phase F` lifecycle cell, and a new `D0` unit-family row.
5. **`context-map.md` §3** — the relation row §6 requires.
6. **`context-map.md` §4** — the known-false-assumption bullet stating that D, E and F have no independently landed phase record, corrected for **D only**.

**Every other claim in both documents still rests on the earlier verifications named in their own freshness paragraphs**, and nothing wider should be inferred.

---

## 8. What this record does not decide

It does not decide: which linter, formatter, type-checker, test framework or scanner NOXUND adopts, if any · what any surface's minimum expectation is · whether any check ever becomes required · what `apps/web` should contain · whether `packages/shared` should be imported or removed · how the Node-version and lockfile inconsistencies are resolved, only that a unit must resolve them coherently · whether the unregistered-file workflow registration is removed · whether a `CODEOWNERS` file is ever created · anything about `packages/orchestrator` beyond restating [[DEC-0038]] · anything on Axis 1 · the ordering or content of Phases E and F.

---

## 9. Explicit non-decisions

This record does **not** and must not be read to: adopt, install or configure any tool · set any threshold, budget or target · create or change any workflow, ruleset, branch protection, required status check, reviewer requirement, `CODEOWNERS` file, Environment, secret, credential or principal · modify any manifest, lockfile, compiler configuration or engine constraint · create, delete, move or edit any file outside this unit's four declared paths · register, wire, activate or promote any agent or capability · edit, supersede, narrow or reinterpret any prior DEC · append a forward-status note to any prior DEC · rewrite any historical artifact or any historical disposition · re-arm anything ([[DEC-0033]] §8) · change product scope, MVP admission or any `OD-*` item · resolve the successor PostgreSQL architecture or any Axis-1 question · authorize `D1`, any later `D` unit, Phase E, Phase F, or any commit, push, merge or execution of any kind.

---

## 10. Known weak points, disclosed by the Author

Stated here rather than left for a reviewer to find.

1. **The ten-domain taxonomy at §D5 is a judgment, not a derivation.** Each domain was chosen because it was separately answerable at the `D0` base, and because splitting Q5 from Q9 was forced by the evidence. A different repository would want different cuts, and nothing here proves these ten are complete.
2. **§D6 raises the cost of adopting any threshold, deliberately.** The honest risk is the mirror of the one it prevents: a `D` unit may decline a genuinely useful threshold because assembling six pieces of evidence is expensive. **That trade is accepted knowingly** — an unjustified threshold binds work for as long as it stands, while a deferred one costs only the delay.
3. **§D14's boundary between an ordinary engineering dependency and a Phase-E capability is a principle, and it will need adjudication at least once.** The test given is procedural rather than substantive, and a genuinely ambiguous case is escalated rather than decided by the acquiring unit.
4. **This charter is enforced by nothing mechanical.** Every rule in §4 is `PROCESS ONLY` under §D8's own vocabulary, and saying otherwise would breach [[DEC-0041]] D1 on the first page of the record that inherits it.

---

## 11. Effective and landing semantics

**In force from the Product Lead's manual merge of this record**, and prospective from that moment. Specifically:

- it governs Phase-D work **commenced after landing**;
- it **does not retroactively validate or invalidate any earlier unit**, including `D0`, which stands on the Product Lead's own Phase-D and `D0` GO and on nothing in this record — **a record does not ratify itself**;
- it creates **no standing permission**: every unit still requires its own explicit Product-Lead GO ([[DEC-0035]] §6);
- it is **FROZEN** ([[DEC-0035]] §9): its body is never rewritten, a change to this charter requires a **later landed record**, and no GO, handoff, closeout, result or memory may amend it ([[DEC-0035]] §5, §6);
- imperative wording in any EVIDENCE or DESCRIPTIVE-CURRENT artifact describing Phase D creates no obligation beyond what this record states ([[DEC-0035]] §3.1).

---

*Related: [[DEC-0035]] §3.1 (imperative wording confers no class), §4 P4 (divergence versus stale-descriptive defect), §6 (GO versus durable authority), §7 and §9 (classification and family defaults), §10 (forward discoverability); [[DEC-0037]] D1 (actor taxonomy), D5 (mutating topology), D8 (the governance-review function), D11 (GO and merge); [[DEC-0038]] D1 and D3 (`REDUCE`; zero code action); [[DEC-0039]] D4 (Product-Lead-only actions), D7 (role scoping is not a sandbox), D12 (least privilege as it stands); [[DEC-0040]] D3 (evidence classes), D8 (`NEXT` is never authorization), D13 (mutation accounting), D15 (evidence-reference durability); [[DEC-0041]] D1 (control-strength vocabulary), D2 (fewer real controls), D5 (not merge-blocking), D10 (no configuration touched), D11 (what stays `PROCESS ONLY`), §10 (the Phase-D boundary this record extends). Baseline evidence: [`PHASE-D-D0-ENGINEERING-QUALITY-BASELINE-R1`](../../result/PHASE-D-D0-ENGINEERING-QUALITY-BASELINE-R1.md). Phase-C terminal state: [`PHASE-C-CLOSEOUT-R1`](../../result/PHASE-C-CLOSEOUT-R1.md). Routing surfaces reconciled: [`current-state.md`](../current-state.md), [`context-map.md`](../context-map.md).*
