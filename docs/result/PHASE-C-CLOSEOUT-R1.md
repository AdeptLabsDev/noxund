# PHASE C — Agent Governance V2 · CLOSEOUT R1

**Status:** COMPLETE · **Date:** 2026-08-21 · **Author:** a task-scoped Author, reviewed by a **distinct** task-scoped Governance Reviewer, under the topology [`DEC-0037`](../product/decisions/DEC-0037-execution-topology-role-independence-governance-review-function.md) D5/D6 fixes, carried into this unit by the Product Lead's `C6` GO · **Ratification gate:** the Product Lead's manual merge
**Authority class:** DESCRIPTIVE-CURRENT · **Lifecycle:** CURRENT · **Mutability:** FROZEN (`DEC-0035` §7, §9 `docs/result/**`)
**Type:** Closeout record. **This is not a decision record** — it establishes no new authority, classifies no artifact, narrows no clause, resolves no open question, and authorizes no execution. It creates **no** `DEC`.
**Canonical base:** `main` @ `495f68e822d2234d8a506a9751b46b03f9ebd490` (PR #92 merge, landing [`DEC-0041`](../product/decisions/DEC-0041-mechanical-governance-enforcement.md))
**Units:** `C0` foundation assessment (unlanded) → `C1` execution topology → `C2` `packages/orchestrator` disposition → `C3` capability / technical principal / independence model → `C4` result, disposition and closeout contract → `C5` mechanical governance enforcement → `C6` closeout (this record).
**Method.** Every load-bearing claim below was **re-derived by this unit at the canonical base** from landed files and live read-only repository state. No prior closeout summary, no conversation claim and no memory content was used as proof (`DEC-0035` §5).

---

## 1. Disposition

> **PHASE C — AGENT GOVERNANCE V2: COMPLETE.**

Complete **as a bounded improvement-program phase**, with limitations that are explicit, truthful, fail-closed where required, and routed. §14 states exactly what the token means and what it does not.

---

## 2. Scope closed

Phase C was named — never independently defined as a landed phase record — by [`DEC-0032`](../product/decisions/DEC-0032-migration-runner-mechanism-rejections.md) §8, which routed `packages/orchestrator/**` and *"approver-provenance and consumption-ledger atomicity"* to it as **DEFER-PHASE-C**, and by [`DEC-0035`](../product/decisions/DEC-0035-canonical-context-v2-authority-lifecycle-supersession-model.md) §12, which reserved to it the wiring question, `AgentResult` V2, the capability matrix, the reviewer-count policy and **any mechanical enforcement** of the §7 classification rule.

**The intent behind it:** a fresh operator should be able to determine **who may legitimately act**, **what any of them can technically do**, **what a unit returns and what each part of it means**, and **which of those rules a machine actually binds** — without depending on conversation memory, and without mistaking process discipline for a technical control.

This record evaluates completion against that definition only.

---

## 3. Units — the `C0`–`C6` ledger

| Unit | Purpose | Landed artifact | Substantive outcome | Historical governance disposition | Finding lifecycle |
|---|---|---|---|---|---|
| **`C0`** | Agent Governance V2 foundation assessment | **none** — an unlanded in-session assessment; **no file on `main`**, named for provenance only (`DEC-0033` §8) | assessment evidence preserved as usable **except one withdrawn claim** — the direct-push claim, permanently withdrawn | **`RED` — verified authorization breach**: unauthorized scratch-file creation, failure to stop on recognition, self-remediation by deletion, failure to preserve evidence, and original self-certification as `PASS`. Blast radius `LOW · ZERO REPOSITORY IMPACT`, which **does not alter the classification** | **`CLOSED — REMEDIATED`**; the historical `RED` is **never rewritten to `PASS`** |
| **`C1`** | permanent execution topology, role independence, the governance-review function | [`DEC-0037`](../product/decisions/DEC-0037-execution-topology-role-independence-governance-review-function.md) — PR #88, merge `4566738` | seven-actor taxonomy; `AUTHOR ≠ REVIEWER`; task-scoped roles are not agents; reviewers counted **by function**; `agent-review-matrix.md` item #12 narrowed to the **function** | `PASS` | none recorded |
| **`C2`** | disposition of the landed control plane | [`DEC-0038`](../product/decisions/DEC-0038-packages-orchestrator-disposition-reduce-to-approval-integrity-primitives.md) — PR #89, merge `1e7e124` | **REDUCE**; broader control plane **NON-AUTHORITATIVE LEGACY**; four **candidate primitives, not adopted**; **zero code action** | `PASS` | none recorded |
| **`C3`** | capability, technical principal, independence | [`DEC-0039`](../product/decisions/DEC-0039-capability-technical-principal-independence-model.md) — PR #90, merge `cc0483d` | `ROLE ≠ EXECUTION INSTANCE ≠ TECHNICAL PRINCIPAL`; four capability states with `UNKNOWN` as a required outcome; principal separation **P3 — HYBRID**; `F4a` and `F4b` kept distinct | **two distinct units, each `RED`** — see §10 | both **`CLOSED — REMEDIATED`**; each unit's artifact holds a review `PASS` |
| **`C4`** | what a governed unit returns and what it means | [`DEC-0040`](../product/decisions/DEC-0040-governed-result-disposition-closeout-contract.md) — PR #91, merge `f88e5ca` | six non-collapsing axes; one `ROLE RESULT`; one fourteen-item `GOVERNED UNIT CLOSEOUT`; mutation accounting beyond the repository; the breach invariant made **unconditional, prospectively**; `AgentResult` classified `NON-AUTHORITATIVE LEGACY` | `PASS` | one disclosed low-impact coordinator process deviation, **explicitly adjudicated by the Product Lead as not justifying a separate corrective unit** — cited as process evidence only, never reopened (§10) |
| **`C5`** | mechanical enforcement | [`DEC-0041`](../product/decisions/DEC-0041-mechanical-governance-enforcement.md) — PR #92, merge `495f68e` | three binding control-strength tokens; **Limb A** locator debt repaired at the citing end; **Limb B** one deterministic reference-durability check; five candidates not bindable, one `DEFER / REJECT` | `PASS` | none recorded |
| **`C6`** | Phase-C closeout | **this record** | independent re-derivation of the whole chain; the closeout surfaces | proposed to the Product Lead | — |

**Verification of the ledger, re-derived rather than transcribed.** The **five** merge commits named above were read from `main`'s merge history at the canonical base — `C0` produced none, and `C6`'s is not yet made. **Phase C carries six merges in total**, the sixth being the intra-PR reconciliation merge inside PR #90; it lands no unit of its own and so has no row here. Each decision record was read in full, and the diff from the `C1` merge to this base shows exactly thirteen paths touched across `C2`–`C5` — four new decision records, the governance workflow, the checker and its suite, two files under `docs/agents/`, the two routing surfaces, and the two additive forward-status notes.

---

## 4. Landed authority chain

Every edge below is **explicit** and is recorded in the relation table at [`context-map.md`](../product/context-map.md) §3. **No edge is inferred, and chronology supersedes nothing** (`DEC-0035` §4 P2).

```txt
DEC-0035  §12          reserved the Phase-C work
   ├── DEC-0037  EXTENDS  DEC-0035 §12 · §14        NARROWS agent-review-matrix.md #12
   ├── DEC-0038  EXTENDS  DEC-0037 §9               DISCHARGES DEC-0032 §8
   ├── DEC-0039  EXTENDS  DEC-0037 §9 · D12         DISCHARGES DEC-0038 §13 · §15
   ├── DEC-0040  EXTENDS  DEC-0037 §9               DISCHARGES DEC-0038 D2 · §15
   │                                                DISCHARGES DEC-0039 D14 · §8
   └── DEC-0041  EXTENDS  DEC-0040 §9               DISCHARGES DEC-0040 D15 · §7
                                                    DISCHARGES DEC-0039 D11 · §8
```

**All five records are `INTERNAL-NORMATIVE · ACTIVE / CURRENT · FROZEN`**, each declaring its own class under the fail-closed rule (`DEC-0035` §7). **Exactly one narrowing exists in the whole corpus** — `DEC-0037` D9, of matrix item #12 — and it is never extended to another clause by analogy. **No prior decision-record body was edited by any Phase-C unit.** `DEC-0036` and `DEC-0037` each received a clearly-marked **additive forward-status note appended after the closing line**, the one mechanism `DEC-0035` §3.3 permits on a `FROZEN` record; both diffs are **strictly append-only with zero deletions**, re-derived here by `git diff --numstat`.

---

## 5. Key permanent outcomes

- **Who acts is settled, and it does not depend on a runtime.** Seven actors; `AUTHOR ≠ REVIEWER`; the Product Orchestrator coordinates and **accepts nothing**; the Product Lead manually merges every governed PR; reviewers are counted **by function, not by headcount** (`DEC-0037` D1, D5, D10, D11).
- **A required review function is never silently unheld.** Where a named identity is not operational and no landed record has narrowed the clause, the unit returns **`HOLD` + `AGENT-CAPABILITY-GAP`** and escalates — never routed around (`DEC-0037` D6; `DEC-0039` §6.1).
- **`REGISTERED ≠ OPERATIONAL ≠ PARTICIPATING`.** Task-scoped roles are not agents, and no result may carry a registered agent's name unless that agent produced it (`DEC-0037` D2, D3).
- **The control plane is decided.** `packages/orchestrator` is **REDUCE**: non-authoritative legacy, unchanged on `main`, imported by no file outside itself and run by no workflow. Four primitives are **retained as candidates and expressly not adopted** (`DEC-0038` D1, D2, D3).
- **Capability is separated from authority.** `TECHNICALLY POSSIBLE ≠ AUTHORIZED`; `DECLARED ≠ AVAILABLE`; `UNKNOWN` is a required outcome; **role scoping is an authorization boundary, never a sandbox** (`DEC-0039` D2, D7).
- **Provenance is answered honestly.** `TECHNICAL APPROVER-PROVENANCE = NOT CURRENTLY SEPARABLE FROM SINGLE PRINCIPAL`; `IDENTITY ≠ CONSUMPTION ≠ PROVENANCE`; **hashing is not attestation** (`DEC-0039` D6; `DEC-0038` §13).
- **A result can now say what actually happened.** Six axes that never collapse; `UNIT RED` beside `ARTIFACT PASS` is expressible under eight conditions; `CLOSED — REMEDIATED` never rewrites a historical `RED`; compound tokens are prohibited; **`NEXT CANDIDATE ≠ GO`** (`DEC-0040` D1, D6, D7, D8, D14).
- **Accounting covers what breaches actually look like.** `OUTSIDE REPOSITORY ≠ OUTSIDE write_scope`; a clean `git status` is not a `ZERO MUTATION` proof; **cleanup is never retroactive authorization** (`DEC-0040` D13).
- **Enforcement claims are bounded by vocabulary.** `PREVENTIVE` · `AUTOMATIC DETECTIVE` · `PROCESS ONLY`, with two binding invariants: a checklist is never called mechanical enforcement, and an Action is never called merge-blocking unless repository rules make its success required (`DEC-0041` D1).

---

## 6. Mechanical enforcement state — re-derived at this base

> **`AUTOMATIC DETECTIVE · NOT MECHANICALLY MERGE-BLOCKING`.**

| Fact | Evidence class |
|---|---|
| Three rulesets are `enforcement: active`. `Protect main`, id `19697151`, carries exactly `deletion`, `non_fast_forward` and `pull_request`. **There is no `required_status_checks` rule**, so **no CI check can block a merge on this repository** | `VERIFIED` — read-only GitHub API read at this base |
| `required_approving_review_count` is `0`, `required_reviewers` is empty, `require_code_owner_review` is `false`; the sole bypass actor is scoped `bypass_mode: pull_request`, and `current_user_can_bypass` reads `pull_requests_only` | `VERIFIED` — same read. **`F4a` stands exactly as landed** |
| The checker suite runs **40 tests, 0 failures**, standard-library only, offline, with bytecode writing disabled; the workflow asserts **exactly 40** fail-closed, so a discovery regression cannot pass silently | `VERIFIED` — executed locally at this base |
| The corpus audit reports **47 governed files and 11 findings**, matching `DEC-0041` §8 exactly | `VERIFIED` — executed read-only at this base |
| The `packages/orchestrator` tree is byte-identical across `C1` through `C5` — `7457f3f259ce8987e74ebe9f3db48172eabbd02b` at every one of the five merge commits. The preserved tree at commit `151fb46bd5f335d26a93fc85d4dc9209340c9294` is a **different** tree and is **not on `main`** | `VERIFIED` — object identity read at each commit |

**One control exists, against seven adjudicated candidates.** That is `DEC-0041` D2's decision — `FEWER REAL CONTROLS > MORE CONTROLS THAT DO NOT OBSERVE THE WORK` — not a shortfall. **The check detects citation *shape*; it does not verify meaning, does not judge load-bearingness, and deliberately does not detect drift.**

---

## 7. Accepted limitations — explicit, truthful, and not represented as solved

Each was checked against current documentation. **No landed surface claims stronger enforcement than exists**; had one done so, that would have been a material finding rather than an accepted limitation.

| # | Limitation | Standing |
|---|---|---|
| 1 | **Repository CI cannot universally detect out-of-repository writes** — session scratchpads, system temp directories, memory files, external systems. All three observed convenience-write incidents happened exactly there | `ACCEPTED` · `PROCESS ONLY` (`DEC-0041` D7) |
| 2 | **No technical sandbox exists.** Role scoping is an authorization boundary; a controlled executor is Phase-F work and is **routed, not built** | `ACCEPTED` · routed (`DEC-0039` D7; `DEC-0041` D8) |
| 3 | **Result-contract, required-field and status-axis validation is not mechanically universal** — the governed result is a chat artifact, `C1` through `C4` produced no result file, and `C4` chose a prose contract deliberately | `ACCEPTED` · `NOT MECHANICALLY BINDABLE` (`DEC-0041` D6) |
| 4 | **Independent GitHub review is not mechanically required**, and the same principal may author and merge — observed, not merely possible | `ACCEPTED CURRENT LIMITATION` — `F4a` (`DEC-0039` D10) |
| 5 | **Ruleset durability**: the single admin may prospectively alter a ruleset, and any in-repository baseline would be owned by that same admin. Detection must be **out-of-band** | `ACCEPTED CURRENT LIMITATION` + `DETECTION REQUIRED LATER` — `F4b`, re-routed (`DEC-0039` D11; `DEC-0041` D9) |
| 6 | **The `C5` checker checks reference shape and durability, not semantic truth** | `ACCEPTED` — stated at `DEC-0041` D4 and pinned by five tests that assert what it does **not** detect |
| 7 | **The governance check is not a required merge check** | `ACCEPTED` — `DEC-0041` D5, re-verified at §6 above |
| 8 | **No second technical principal exists, and none was provisioned.** Approver provenance stays technically open | `ACCEPTED` under **P3 — HYBRID** (`DEC-0039` D9) |
| 9 | **The `DEC-0035` §7 header-classification rule stays documentary** — no validator was built for it | `ACCEPTED` · routed and **not** authorized (`DEC-0041` §10) |
| 10 | **The retained primitives carry disclosed engineering debts** — single-process ledger only, a classify/verify ordering that fails open on one field, regex-based sensitivity heuristics. All are in **preserved, not-adopted** code that nothing reaches | `ACCEPTED` and disclosed (`DEC-0038` §18) |

**None of these is a blocker.** Each is stated at the strength the evidence supports, fails closed where a fail-closed route is required, and is routed rather than half-done.

---

## 8. Agent-capability gaps — every remaining named-agent requirement

Classified against exactly three outcomes. **`A` — authority conflict, a material blocker · `B` — capability gap with a fail-closed route · `C` — silent unsatisfiable requirement, a material blocker.**

| Requirement | Trigger at this base | Class |
|---|---|---|
| `agent-review-matrix.md` item **#12** — independent governance/integrity review | **LIVE** | **not a gap** — narrowed to the **function** by `DEC-0037` D9 and satisfied by a distinct `TASK-SCOPED GOVERNANCE REVIEWER` |
| item **#10** — documentation that alters decisions, routed to the Product Orchestrator | **LIVE** | **not a gap** — it names the decision-registration and gate-confirmation function `DEC-0037` D10 grants; reconcilable at clause granularity (`DEC-0039` §6.2) |
| item **#13** — security-sensitive boundary change, routed to `security_agent` | can fire; **does not fire** for a unit that changes no boundary — including **`C5`**, the one Phase-C unit landed authority named as a firing example, determined below | **B** — `security_agent` has no REAL PRODUCT EXECUTOR; when the trigger fires this is a `DEC-0035` §4 **P4** divergence to surface and escalate, never to route around |
| item **#11** and the `apply_exact_remediation` chain | **LATENT** — the capability is `PROPOSED-NOT-OPERATIONAL / RUNTIME-NOT-WIRED`, absent from the runtime allow-list, and returns `needs_review` on any current invocation | **B** |
| items **#14 through #16** — control-plane change reviews | **LATENT** — `REDUCE` means no control-plane code change and no wired runtime | **B** |
| items **#1 through #9** and the *Gatilhos adicionais* table | **LATENT** — every trigger is Axis-1 work, and Axis 1 is paused with no authorized unit | **B** |
| Both **Bootstrap** sections — initial definition, registration or first runtime activation of two agents | **LATENT** — no registration, activation or wiring is authorized; the registry-first gate stays binding and unwaived | **B** |

> **Zero `A` and zero `C`.** Every remaining requirement is either satisfiable today or latent with a **landed, general, fail-closed route**: `HOLD` + `AGENT-CAPABILITY-GAP`, held at `HOLD-PENDING-AGENT-DEFINITION`, escalated to the Product Lead (`DEC-0037` D6; `DEC-0039` §6.1 outcome 3). **No gap is closed by relabelling a generic subagent as a registered agent** — that is forbidden outright (`DEC-0037` D2, D3).

### 8.1 The `DEC-0039` §6.3 forward flag, followed to its other end

`DEC-0039` §6.3 planted a forward flag *"surfaced now rather than left for someone to trip over"*, naming three futures in which item **#13**'s trigger would fire — **"a `C5` unit implementing an enforcement control"**, a unit provisioning a second principal under D9, and any change to a boundary file. `C5` implemented an enforcement control. **An operator following that flag to its other end must find something there, so `C6` establishes the fact rather than leaving the flag dangling.** This is a **finding of fact**, identical in kind to §6.3's own `C3 CHANGES NO BOUNDARY — #13 DOES NOT FIRE` determination. **It narrows nothing** — narrowing #13 would require its own landed record and is never done by analogy (`DEC-0039` §6.1 outcome 2).

**The prior question `DEC-0039` §6.1 requires first: did the trigger fire?** Re-derived at the canonical base from the `C5` diff, from `agent-boundaries.md`, and from live read-only repository configuration.

| Test | Finding | Class |
|---|---|---|
| **Did `C5` change a *fronteira*?** §6.3 fixes the referent: an **agent boundary** in the `agent-boundaries.md` sense — Mission / Owns / Can decide / Cannot decide / Must request review / Forbidden actions | **No.** The `C5` diff touches **no file under `docs/agents/`** at all. No Mission, Owns, Can-decide, Cannot-decide, Must-request-review or Forbidden-actions text changed anywhere | `VERIFIED` |
| **Could the surface it did touch be a boundary?** | **No.** `agent-boundaries.md` contains **zero** occurrences of `.github` and of `workflows`; **no boundary in that file names the workflow surface**, so adding a workflow cannot alter boundary text | `VERIFIED` |
| **Did it expand the access surface?** #13's own rationale scopes the trigger — *"Alteração de boundary pode expandir superfície de acesso/risco"* | **No.** The one workflow added declares `permissions: contents: read`, **identical to all twelve workflows on `main`**; it binds **zero Environments** and references **zero secrets** — one of only two on `main` holding neither. The repository CI ceiling is unchanged: `default_workflow_permissions: read`, `can_approve_pull_request_reviews: false`. **No principal gains any capability** | `VERIFIED` |
| **Did it create any of the access-surface items §6.3 enumerates?** | **No ruleset, no `required_status_checks` rule, no `CODEOWNERS`, no reviewer threshold, no branch protection, no permission, credential, secret, Environment, allow-list, capability grant, agent contract or runtime wiring** (`DEC-0041` D10, §15; re-confirmed against the diff and against the live rulesets at §6 above) | `VERIFIED` |

```txt
C5 CHANGES NO BOUNDARY AND EXPANDS NO ACCESS SURFACE — #13 DOES NOT FIRE
```

**Why landed authority named `C5` anyway, stated rather than smoothed over.** The flag was written while `C5` was still defined by `DEC-0037` §9 as *"validators, lint, hooks, CI, `CODEOWNERS`, rulesets, branch protection, review requirements"* — and `CODEOWNERS`, rulesets, branch protection and review requirements are **precisely the access-surface items §6.3 enumerates**. `C3` was anticipating that shape of `C5`. **The `C5` that actually ran was forbidden to change rulesets and created none of those** (`DEC-0041` D10). A named example in a forward flag is an **anticipation, not an adjudication**, and §6.1 asks its prior question of the actual unit at its actual base: *"Latency is a fact about the world, never a disposition of the clause."*

**The one genuinely new thing, disclosed rather than buried.** `governance-checks.yml` is the **first workflow in this repository to execute on a docs/governance pull request** (`DEC-0041` §9 says so in terms), so it adds an **execution** surface where none existed. That is a real change, and it is **not** an access change: the trigger is `pull_request` — not `pull_request_target` — on GitHub-hosted runners, with a read-only token, no secret and no Environment, so the run can read the repository and report, and can reach nothing else. **Execution surface is not access surface**, and #13's rationale is scoped to the latter.

**Consequence.** `DEC-0041`'s silence on `security_agent`, #13, `AGENT-CAPABILITY-GAP` and `STATE-AUTHORITY` is **correct silence about a trigger that did not fire**, not a routed-around divergence. Had the trigger fired, §6.1 outcome 3 would have obliged `C5` to return `HOLD` + `AGENT-CAPABILITY-GAP` rather than land — and this record would be returning `HOLD` rather than reporting a finding.

---

## 9. Routed residual debt — routed, **not solved**, here

None of these blocks Phase-C closure. Each is real, each is reachable, and none is a `MATERIAL PHASE-C GAP`.

| # | Item | Classification |
|---|---|---|
| 1 | The locator debts `DEC-0040` escalated as `UNRESOLVED — LOCATOR ONLY` | **`CLOSED`** — repaired at the citing end by `C5` Limb A; verified append-only, each carrying stable path, named section and verbatim quotation |
| 2 | Out-of-repository and scratch-write detection; mutation-accounting enforcement; write-scope prevention | **`ROUTED — PHASE F`** — needs a controlled executor (`DEC-0041` D8) |
| 3 | `F4b` ruleset-drift detection | **`ROUTED — PHASE F`** — must be out-of-band (`DEC-0041` D9) |
| 4 | Result-contract, required-field and status-axis validation | **`ACCEPTED LIMITATION`** — no machine-observable result surface exists (`DEC-0041` D6) |
| 5 | A second technical principal or trust anchor | **`ROUTED — FUTURE CAPABILITY / PRINCIPAL`** — a prerequisite only for `DEC-0039` D9's three-item subset, none of which is in flight |
| 6 | The `DEC-0035` §7 header-classification check | **`NONBLOCKING DOCUMENTATION / MAINTENANCE`** — named so a later unit finds it; **not** thereby authorized |
| 7 | General agent-doc reconciliation — the stale status line in `orchestration-runtime.md`; the thirteen pre-existing `AgentResult` references `DEC-0040` counted across eight sections of the Product-Orchestrator contract; the runtime-operating prose in `agent-registry.md`, `agent-boundaries.md` and the ten agent contracts | **`NONBLOCKING DOCUMENTATION / MAINTENANCE`** — to the Product-Lead-authorized reconciliation unit `DEC-0038` §14 established |
| 8 | Of the **11** checker findings this unit re-derived, the **6 false positives** — prose descriptors, an intra-line back-reference, source-code citations sitting inside a decision record — and the **2 real but out-of-scope** references in `FROZEN` records. The remaining **3** are the historical enumerations at row 1, so the split is **3 + 6 + 2 = 11**, exactly as §11 states | **`NONBLOCKING DOCUMENTATION / MAINTENANCE`** — §11 answers the only question that matters about them |
| 9 | **Newly identified by `C6`, reported and not repaired:** the `C5` additive note on `DEC-0037`, and the matching relation row, describe that record's decision block as `D1–D16`; the record's body carries `D1–D13`. The over-inclusive range asserts that three non-existent items are untouched — **null in effect, and no conclusion depends on it**. `DEC-0037` and `DEC-0041` are `FROZEN` and outside this unit's write scope | **`NONBLOCKING DOCUMENTATION / MAINTENANCE`** |
| 10 | **Newly identified by `C6`, repaired here:** the `context-map.md` §2 `Phase A … Phase F` lifecycle cell still described `C5` as `NOT STARTED / NOT AUTHORIZED` while the adjacent identifier row recorded it `LANDED`. A `STALE-DESCRIPTIVE DEFECT` (`DEC-0035` §4 P4) that `C5` left behind, and one `C6` must edit that cell to correct in any event | **`CLOSED` by this record** |
| 11 | **Newly identified by `C6`, reported and not repaired:** the conditional phrasing of `RED` survives at **nine sites across three files**, counted by this unit at this base — `governance-integrity-agent.md` (**seven**: the §*Operating Protocol* blocking-power bullet, the §*Evidence rules* trigger line, the escalation clause inside §*HOLD conditions*, and four in §*RED conditions*), `agent-review-matrix.md` §*Fluxo de aplicação* (**one**) and `agent-boundaries.md` §*Governance & Integrity Agent* › §*Can decide* (**one**). **This is not an authority conflict** — every one of the nine defers to *"o gate governante"*, and `DEC-0040` D5 is that gate policy, now unconditional, so the condition is always satisfied. **The routing destination is already correct:** `DEC-0040` §11 names all three files under *deliberately left alone*. Files under `docs/agents/` are outside this unit's write scope | **`NONBLOCKING DOCUMENTATION / MAINTENANCE`** — with item 7 |
| 12 | Corpus-wide historical normalization; `OD-06` and the cross-series `OD-*` collisions; the `Entra no MVP` enumeration difference; classification of `infra/postgres/**`; sentinel residue on preserved refs; the local stash entry's lack of a durable target | **`ROUTED — PRODUCT / ENGINEERING AXIS`** or Product-Lead decision — inherited from [`PHASE-B-CLOSEOUT-R1`](PHASE-B-CLOSEOUT-R1.md) §5, **untouched and unabsorbed by Phase C** |
| 13 | Successor PostgreSQL architecture; provisioning; migration-runner selection; collection resumption; the exact Axis-1 resumption point | **`ROUTED — PRODUCT / ENGINEERING AXIS`** — §13 below; nothing here authorizes any of it |

---

## 10. Historical governance provenance

Recorded truthfully, and deliberately not turned into an incident log. **`UNIT DISPOSITION ≠ ARTIFACT VERDICT`** (`DEC-0040` D6), and **a closed finding does not erase a `RED`** (`DEC-0040` D7).

- **`C0`** — historical **`RED`**, finding **`CLOSED — REMEDIATED`**, no landed artifact. The `RED` **stays historical and is never rewritten to `PASS`**. Its assessment evidence is usable except one permanently withdrawn claim.
- **`C3`, twice, on two different shapes.** The original unit's `RED` grounds in an unauthorized out-of-repository memory-file write; the **unlanded** post-`C2` reconciliation unit's `RED` grounds in convenience writes outside its `write_scope`. **Both findings are `CLOSED — REMEDIATED`, and both units returned a `PASS` review verdict on what they produced**; the Product Lead explicitly accepted the unit/artifact separation. The second is **Product-Lead adjudication carried by `DEC-0040` §6, not a repository fact** — that unit has no file on `main` and is named for provenance only (`DEC-0033` §8). A reader reconstructing this from `main` alone will find one `C3` `RED`, and will be right about the repository and incomplete about the history.
- **`C4` R4** — a disclosed low-impact coordinator convenience write. **The Product Lead has decided it does not justify a separate corrective unit.** It is **not reopened here**, and is cited only as process evidence and as part of `C5`'s motivation.
- **Three shapes, one lesson.** Not one of these incidents was a repository-file breach, and in every case `git status` was clean while the unit was not. That is precisely why `DEC-0040` D13 enumerates out-of-repository surfaces, and why `DEC-0041` refuses to build a repository-only accounting check that would earn a meaningless green.
- **Artifact acceptance is represented independently throughout.** Every Phase-C decision record that landed did so on its own independent technical review and its own Product-Lead ratification. **A record does not ratify itself.**

---

## 11. Residual reference debt — the only question that matters

**Does any remaining reference defect materially prevent a fresh operator from determining current authority?**

> **NO.**

Re-derived by running the checker's audit read-only at this base: **11 findings across 47 governed files.** Three are the historical enumerations whose *references* `C5` Limb A repaired at the citing end — the frozen sentences keep their historical shape, which `DEC-0041` §8 records as the correct outcome and not an unfinished one. Six are false positives against durable identities the signal vocabulary does not recognise. **Two are genuinely bare and are real:** one negative clause naming a file the citing record expressly did **not** edit, and one measurement claim about a unit's own edit discipline at its own base. **Neither carries a routing proposition**, and both sit in `FROZEN` records outside any authorized repair scope here.

Every authority a fresh operator needs is reachable by **path plus named section**, from `current-state.md` §B, §E and §I, and from `context-map.md` §1 through §3. Routed as **nonblocking maintenance / future checker refinement**.

---

## 12. Phase boundaries — what Phase C did **not** authorize

Phase C was a **docs-plus-one-tool** program phase. It did **not**, and must not be read to have:

- **Phase D** — defined any documentation-quality standard, testing policy, code-quality policy, performance budget or engineering-simplicity standard. `C5`'s forty tests validate `C5`'s own implementation and create **no repository-wide testing policy**.
- **Phase E** — adopted, integrated, evaluated or referenced any external skill, package or capability. **No dependency installation and no third-party package**, in any unit. *(**Sourcing marker, because the three bullets are not sourced alike.** The Phase-D and Phase-F characterizations are carried by the Phase-C corpus itself — `DEC-0040` §9 and `DEC-0038` §15. The Phase-E content traces further back, to `DEC-0034` §*Phase-A boundary*, which reserves *"External Skills or Advanced Orchestration"* work to later phases. **What no landed record supplies is the letter assignment** — which of D, E and F carries which content is a Product-Lead program definition, exactly as `current-state.md` §B *Provenance* and `context-map.md` §4 both record. Nothing in this bullet depends on the letter: it is negative scope in a record that creates no authority, and it constrains nothing either way.)*
- **Phase F** — wired any runtime; created any orchestration loop, DAG, agent-state protocol, autonomous result chaining or persistent orchestration memory; authorized automatic `NEXT` execution; or resurrected anything from `packages/orchestrator`. **`DEC-0040` D8 is a constraint on such work, never an authorization of it**, and the controlled executor and the out-of-band observer are **named to route them, never to permit them**.
- registered, activated or wired **any** agent; created **any** principal, App, bot, token, credential, secret, trust anchor, ruleset, branch protection, required status check, reviewer threshold, `CODEOWNERS` file or Environment; dispatched **any** workflow; touched **any** database, Supabase or cloud resource; **re-armed anything** (`DEC-0033` §8); edited any prior decision-record body; rewritten any historical artifact; or mutated any preserved ref.

**The only machine execution Phase C landed** is the read-only governance-check workflow: `permissions: contents: read`, zero secrets, zero Environments, actions pinned by commit digest, standard-library only, and it re-arms and dispatches nothing.

---

## 13. Product / engineering axis — untouched

**Axis 1 is paused, not cancelled, and Phase C did not resume it.** No Axis-1 unit is authorized; the successor PostgreSQL architecture remains undecided and unprovisioned; the six DB-apply workflows remain `disabled_manually`; and both collection workflows remain **disarmed and fail-closed** on absent markers. The exact Axis-1 resumption point is **not decided** and requires its own explicit Product-Lead GO (`current-state.md` §B, §C, §D).

**The two axes are not one ladder.** The A–F program is the improvement overlay; it is not NOXUND's development lifecycle.

---

## 14. Phase-C exit statement — and the exact meaning of `PHASE C COMPLETE`

> **`PHASE C COMPLETE` means exactly: `DEVELOPMENT-SYSTEM IMPROVEMENT PROGRAM — PHASE C COMPLETE`.**
> **It does NOT mean `NOXUND DEVELOPMENT COMPLETE`.** It does not mean the product is built, the database exists, collection runs, or Axis 1 has advanced by one step.

Phase C closes because:

**WHO MAY ACT IS DETERMINABLE** — a seven-actor taxonomy, a minimum topology per risk class, checkable independence criteria, and a fail-closed route when a required function cannot be held.
**+ WHAT EACH ACTOR CAN TECHNICALLY DO IS MEASURED, NOT ASSUMED** — four capability axes, two named principals, `UNKNOWN` recorded as an outcome rather than filled by assumption, and process independence never described as mechanical.
**+ THE INTENDED ARCHITECTURE IS NAMED** — the disconnected control plane is non-authoritative legacy, its useful substrate preserved as candidate primitives and expressly not adopted.
**+ A RESULT CAN STATE WHAT ACTUALLY HAPPENED** — six axes that do not collapse, so a `RED` unit with a `PASS` artifact is sayable in one line instead of a paragraph, and history is never rewritten to match a verdict.
**+ ENFORCEMENT IS HONEST ABOUT ITS OWN EXTENT** — one real control, five refusals each with a stated reason, a binding vocabulary that forbids describing a checklist as a mechanism, and an enumerated list of what remains `PROCESS ONLY`.
**+ LIMITATIONS AND DEBT ARE ROUTED RATHER THAN HALF-DONE** — §7 and §9 above, each reachable, none silently absorbed, none misrepresented as solved.

---

## 15. What this record does **not** claim, and what `NEXT` means

It does not claim that governance is mechanically enforced, that reviewer independence is technically guaranteed, that any principal separation exists, that approver provenance is provable, that the corpus is normalized, that every artifact carries a classification header, that any `OD-*` item is closed, that any agent became operational, or that anything on either axis became authorized.

**Improvement Phase D is the `NEXT CANDIDATE` phase. It is NOT AUTHORIZED and NOT STARTED**, as are Phase E, Phase F and any Axis-1 resumption. Each requires its own explicit Product-Lead GO.

**Closing Phase C authorizes nothing.** `NEXT` / `READY` / `RECOMMENDED` is not execution authorization (`DEC-0035` §6; `DEC-0040` D8); naming a unit places it and never resumes it (`context-map.md` §4); and `DEC-0033` §8 stands unchanged — restoring any removed write capability requires its own explicit Product-Lead decision.

---

*Current state is owned by [`current-state.md`](../product/current-state.md); routing by [`context-map.md`](../product/context-map.md); classification and precedence by [`DEC-0035`](../product/decisions/DEC-0035-canonical-context-v2-authority-lifecycle-supersession-model.md). Convention follows [`PHASE-A-CLOSEOUT-R1`](PHASE-A-CLOSEOUT-R1.md), the family's first member, and [`PHASE-B-CLOSEOUT-R1`](PHASE-B-CLOSEOUT-R1.md).*
