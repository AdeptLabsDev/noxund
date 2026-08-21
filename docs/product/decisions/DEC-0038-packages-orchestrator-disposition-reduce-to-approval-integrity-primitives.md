# DEC-0038 — `packages/orchestrator` disposition: REDUCE to approval-integrity primitives

**Status:** ACTIVE (binding) · **Date:** 2026-08-21 · **Decision authority:** Product Lead
**Authority class:** INTERNAL-NORMATIVE · **Lifecycle:** ACTIVE / CURRENT · **Mutability:** FROZEN — the `docs/product/decisions/**` family default ([[DEC-0035]] §9), declared here under the fail-closed rule ([[DEC-0035]] §7).
**Drafted by:** a `TASK-SCOPED AUTHOR` ([[DEC-0037]] D1), reviewed by a **distinct** task-scoped reviewer holding **both** the independent technical-review and the independent governance-review functions — permitted by [[DEC-0037]] D5 because no landed clause separates one *review* function from another, and required to be non-Author by D5's `AUTHOR ≠ REVIEWER` invariant. Unit `PHASE-C-C2-PACKAGES-ORCHESTRATOR-DISPOSITION-R1`, under the Product-Orchestrator-coordinated topology authorized by the Product Lead's `C2` GO. This record is **governance-sensitive** ([[DEC-0037]] D6): it changes what binds and what counts as the intended architecture. **Ratification gate:** the Product Lead's manual merge of this record.
**Scope:** The disposition of the landed `packages/orchestrator` control-plane foundation — **REDUCE**. It decides what the package *is* after this record, names the exact surfaces retained as non-authoritative candidate primitives and the exact surfaces reduced to legacy, and discharges the [[DEC-0032]] §8 deferral. **Docs-only unit.**
**Negative scope — this record does not create or change:** any file under `packages/orchestrator/**` — **no code is deleted, moved, renamed, edited, ported, cherry-picked or adopted** · the preserved commit `151fb46bd5f335d26a93fc85d4dc9209340c9294` or any other ref, branch, stash or archive · any agent registration, activation, contract boundary, runtime handler, runtime allow-list or runtime wiring · the `AgentResult` schema or any result contract (`C4`) · any workflow, ruleset, branch protection, `CODEOWNERS`, CI check, validator, lint or hook (`C5`) · any GitHub identity, principal or token (`C3`) · any Environment, secret, credential or remote connection · any database, SQL, migration, role or runner · any product scope, MVP admission, `OD-*` item or Axis-1 question · memory content. **No agent is wired, no agent is registered, no executor is activated, and no execution of any kind is authorized.**
**Extends:** [[DEC-0037]] §9 — supplying the **`C2` limb only** of the Phase-C work that clause reserved (*"`C2` — `packages/orchestrator` disposition (resume · reduce · retire) … Not decided here"*). [[DEC-0037]] is neither edited nor narrowed and remains **CURRENT**; its topology was already declared to hold under all three dispositions, so this record confirms rather than disturbs it.
**Discharges — by satisfaction, not by replacement:** the **DEFER-PHASE-C** routing in [[DEC-0032]] §8, which placed `packages/orchestrator/**` and *"approver-provenance and consumption-ledger atomicity"* out of scope and reserved them for Phase C. See §3 and §11 for the exact limits of that discharge, including the limb this record answers by **assignment** rather than by solution.
**Does not edit:** any prior DEC. [[DEC-0001]] … [[DEC-0037]] all remain **frozen and additive-only**; [[DEC-0028]] and [[DEC-0033]] remain **byte-frozen** per [[DEC-0034]] §4. No prior record is declared obsolete, superseded, reopened or reinterpreted.
**Reconciles:** `docs/agents/product-orchestrator-agent.md` — **exactly two clauses, which are the only two in that file naming `@noxund/orchestrator` as the execution vehicle**: the §*Operating Protocol* clause [[DEC-0037]] §3 newly identified and routed to `C2`, and the §*Output Format* opening at `:726`, which this unit's own repair would otherwise leave contradicting it (§14). The file family is **EDITABLE** ([[DEC-0035]] §9) and both repairs are minimal and additive. **No other clause of that file — including its binding limbs and the entire `OrchestratorDecision` format contract — and no other agent document, is touched.**
**Canonical base:** `main` @ `45667387f74f92cf9aca532f786f9c8bd519d788`

---

## 1. Status

**ACTIVE — binding and prospective**, effective on the Product Lead's manual merge (§17). It decides an architectural disposition and a documentation boundary. It registers no agent, wires no runtime, deletes no code, adopts no preserved file, and authorizes no unit.

---

## 2. The problem

`packages/orchestrator` is landed on `main`, executable, fully green, and reaches nothing.

[[DEC-0032]] §8 placed it out of scope as **DEFER-PHASE-C** and left it there. [[DEC-0035]] §9 recorded that **preservation is not adoption**. [[DEC-0037]] §3 established that the governance functions NOXUND actually needs *"are satisfied by role separation and Product-Lead gating and **do not depend on any runtime being wired**"*, and §9 expressly declined to decide the package's fate, reserving it for `C2`.

So the corpus carries a landed executable artifact with **no decided architectural status**. That is not a neutral condition. An artifact that is landed, green and undecided reads to a fresh operator as *the intended architecture, merely unfinished* — and the repository contains prose that says exactly that, including a `## Operating Protocol (vinculante)` clause naming `@noxund/orchestrator` as the vehicle the Product Orchestrator operates in. Meanwhile a separate body of preserved work at `151fb46` materially improves the package's weakest security property and has never been adjudicated either.

Leaving this undecided has a specific cost, and it is the failure mode the corpus already names: **paper governance that is never the system in use**. A control plane nobody runs, described in binding-sounding prose as the operating vehicle, is an instance of that failure mode rather than a defence against it.

---

## 3. What [[DEC-0032]] §8 deferred

Verbatim, the routed items: *"`packages/orchestrator/**`, approver-provenance and consumption-ledger atomicity (**DEFER-PHASE-C**)"*.

Three limbs, and they are not the same kind of question:

1. **The package's disposition** — an architectural choice. This record answers it (§8).
2. **Consumption-ledger atomicity** — a technical property. This record adjudicates its status against executed evidence and assigns it (§7 Q10, §13).
3. **Approver provenance** — a technical problem that **cannot be solved inside this repository's current trust model at all** (§13). This record answers it by **assignment to `C3`**, not by solution, and says so plainly.

**The precise sense of the discharge, so it is not overclaimed.** §8 deferred a **decision** to Phase C. A deferral is discharged when the deferred decision is *made*, not when every technical problem it names is *solved*. This record makes the decision for all three limbs — retaining the package's reduced status, characterizing ledger atomicity against evidence, and assigning provenance a venue. **Limbs 2 and 3 remain technically open**, and this record does not represent them as fixed.

---

## 4. Predecessor evidence and its standing

- **`C0`** (`PHASE-C-C0-AGENT-GOVERNANCE-V2-FOUNDATION-ASSESSMENT-R1`) is an **unlanded in-session assessment with no file on `main`**, whose historical disposition is `RED — VERIFIED AUTHORIZATION BREACH`, adjudicated **`CLOSED — REMEDIATED`** ([[DEC-0037]] header). Per [[DEC-0033]] §8 it is named for provenance only and confers no standing. **Every C0 characterization relied on below was independently re-derived at the canonical base by this unit** and is cited as this unit's finding, never as C0's.
- **`C1`** ([[DEC-0037]]) is **LANDED**. Its §3, §9 and D1–D13 are relied on as current binding authority.
- **The preserved commit `151fb46`** is `EVIDENCE / HISTORICAL` under [[DEC-0035]] §9's preserved-Git-evidence row. **`PRESERVED ≠ ADOPTED`.** Nothing in it is on `main`, and nothing in this record puts it there.

---

## 5. Current-main runtime state — re-derived at `45667387`

`packages/orchestrator` tree = `7457f3f259ce8987e74ebe9f3db48172eabbd02b`.

| Property | Finding | Class |
|---|---|---|
| Tests | `node --test` → **36 pass, 0 fail**, zero install (Node v24 type-stripping) | VERIFIED |
| Typecheck | `tsc --noEmit` → **exit 0** | VERIFIED |
| Handlers | **Ten** registered agents, each built by `defineAgent` | VERIFIED |
| Handler nature | **47 registered actions. Every one of the four registered *sensitive* actions** — `change_db_schema`, `run_migration`, `deploy`, `configure_env` — **resolves to `planningHandler`**, which returns a structured plan/handoff and performs no mutation; its own source states this and states that report numbers are never generated. **Stated precisely, because the blanket form would be false: 42 of 47 actions use `planningHandler` and 5 use bespoke handlers** — `review_authz_contract`, `define_scoring_methodology`, `design_schema`, `plan_migration`, `define_rls_policy`. **All five are equally pure**: no file under `src/agents/` references `node:fs`, `child_process`, `exec`, `spawn` or `fetch`, so no registered action can perform an external side effect | VERIFIED |
| Registry ↔ allow-list | **Consistent by construction, not by discipline**: `allowedActions` is derived as `Object.keys(def.handlers)`, so the allow-list and the executor cannot drift | VERIFIED |
| Code importers outside the package | **Zero.** Searched every tracked `.ts/.tsx/.js/.mjs/.cjs/.json/.yml/.yaml` file outside `packages/orchestrator/` for `@noxund/orchestrator` and `packages/orchestrator` — no hit. Every occurrence in the corpus is documentation prose | VERIFIED |
| CI / workflow execution | **Zero.** No file under `.github/` mentions the package; none of the eleven workflows references or runs it | VERIFIED |
| Root wiring | Root `package.json` scripts (`dev`/`build`/`lint`/`typecheck`) all target `--filter web`. The package is a `pnpm-workspace` member and nothing else | VERIFIED |

**Disposition of the C0 characterization `LANDED · EXECUTABLE · GREEN · DISCONNECTED`: CONFIRMED on all four limbs**, on this unit's own re-derivation.

---

## 6. The approval-gate defect — reproduced, not summarized

Reproduced by execution against current-main `src/core/safety.ts` and `src/core/dispatcher.ts`. `Approval` is `{ approved_by, note?, granted_at }`; the gate at `dispatcher.ts` step 4 is `if (sensitivity.sensitive && !options.approval)`.

That is a **presence check on an object reference**. It examines no field of the approval it accepts.

| Property claimed | Verdict | Evidence |
|---|---|---|
| **UNBOUND** — approval not bound to one exact command | **CONFIRMED** | An approval object annotated for `run_migration` released `devops_agent`/`deploy`. `Approval` carries no `task_id`, `target_agent`, `action` or payload reference; nothing is compared |
| **REPLAYABLE** — no durable single-use consumption | **CONFIRMED** | The same object released three separate sensitive dispatches, across two different agents and two different actions. No ledger, nonce or consumed-flag exists anywhere in `src/` |
| **UNAUTHENTICATED** — approver identity caller-declared | **CONFIRMED, AND STRONGER THAN CLAIMED** | `createApproval(approvedBy: string)` takes an unverified string, and `approved_by` is only ever read for a log field. Beyond that: a **bare `{}` released the gate**, because presence is the whole test. The gate does not merely trust a claimed approver — it never looks at one |
| **NON-EXPIRING** — `granted_at` recorded, never enforced | **CONFIRMED** | `granted_at` is written by `createApproval` and, by exhaustive search of `src/`, **read nowhere**. An approval stamped `2000-01-01T00:00:00.000Z` was accepted |

**Latency, stated precisely.** The defect is **LATENT — UNREACHABLE AT THIS BASE**, and this is a conjunction of two independent facts, not one:

1. **Nothing drives the runtime.** No code outside the package imports it; no workflow runs it. There is no execution path from any NOXUND process to `dispatch()`. The gate cannot be bypassed because it is never reached.
2. **Even if reached, no handler can perform a destructive act.** Every one of the ten agents' sensitive actions — `run_migration`, `change_db_schema`, `deploy`, `configure_env` — resolves to `planningHandler`, which writes a plan object. The maximum consequence of a total gate bypass at this base is a JSON plan under `.runtime/`.

**This is not a mitigation and must not be read as one.** It is a statement about *reachability at this base only*, and it is exactly why the defect must be resolved **before** anything is wired, never after. Both conditions are removable by a single future wiring unit, and they are removable independently.

---

## 7. Preserved evidence state — `151fb46`, validated, not adopted

`packages/orchestrator` tree at the preserved commit = `28009403c74a0f96a4ba3f8349f30b66fee2f51e`. Validation was performed in a **detached, read-only worktree** pinned to that commit; nothing was committed, branched, pushed or copied out, and **no dependency was installed** (§9).

**The 20 validation questions.** `VERIFIED` = established by execution or by direct reading at the preserved base by this unit.

| # | Question | Answer | Class |
|---|---|---|---|
| 1 | Does it typecheck? | Yes — `tsc --noEmit` exit 0 | VERIFIED |
| 2 | Do its tests pass? | Yes — **75 pass, 0 fail, 1 skipped**. The skip is `provenance of approved_by is authenticated`, marked `TODO-BY-DESIGN` with `APPROVER-PROVENANCE-GAP = OPEN-BLOCKING-OPERATIONAL` | VERIFIED |
| 3 | Does it introduce dependencies? | **No.** `package.json` is unchanged between the two trees. The one new module imports `node:crypto` only; the changed modules introduce no import that current `main` does not already have — `project-state.ts` already imports `node:fs` and `node:path` on `main`. **Zero third-party additions, and zero new `node:` builtins beyond `node:crypto`** | VERIFIED |
| 4 | Is command identity deterministic? | Yes. SHA-256 over a canonical serialization, with hard-coded golden digest vectors in the suite. Independently confirmed **identical across two separate Node processes** | VERIFIED |
| 5 | Is identity bound to the semantics that matter? | Bound to `{task_id, target_agent, action, payload}` — the authority-bearing subset — and it **deliberately omits** `requires_human_approval`, `success_criteria`, `reason` and `priority`. **Omitting them is correct, but not for the obvious reason, and the obvious reason is wrong:** `requires_human_approval` is *not* merely descriptive — it is an input to `assessSensitivity`, so flipping it `true → false` on an otherwise benign command changes whether the gate runs **at all**. Reproduced by execution against the preserved tree: with the flag `false`, the command **executed with no approval and consumed nothing**, while command identity was **byte-identical** to the `true` form. **Binding the field into identity would nevertheless be inert**, because the dispatcher skips the whole gate on `!sensitivity.sensitive` and therefore never reaches the identity comparison on that path. **The real residual is an ordering property, not a binding property** — see §18 weak point 1 | VERIFIED (binding) · VERIFIED (residual, by execution) |
| 6 | Does an approval for A fail for B? | Yes — four passing tests, one per mutable field: payload, action, `task_id`, `target_agent`. All reject with `COMMAND_IDENTITY_MISMATCH`, recomputed live from the command about to run | VERIFIED |
| 7 | Does replay fail? | Yes — `single-use: first consume executes, replay is rejected, handler runs at most once` | VERIFIED |
| 8 | Does expiry fail closed? | Yes — injected gate clock; boundary is **exclusive** (`now >= expires_at` is expired); before, at and after the boundary are all tested | VERIFIED |
| 9 | Does a missing ledger fail closed? | Yes — `no ledger configured → sensitive approved task fails closed (no execution)`, rejecting `NO_CONSUMPTION_LEDGER`. **Absence of the anti-replay mechanism refuses execution rather than permitting it** | VERIFIED |
| 10 | Is consumption atomic enough for the runtime's actual persistence model? | **Yes for that model, and only that model.** The runtime persists via synchronous `writeFileSync` in one process; the ledger matches it — synchronous test-and-set with no `await` between check and insert, durable write-through before returning, and rollback of the in-memory claim if the durable write throws. Multi-process safety is **not** claimed and **not** provided: no file lock, no `O_EXCL`, no CAS. The test is honestly named *"single-process atomicity"* | VERIFIED (single-process) · **UNPROVEN (multi-process)** |
| 11 | Can malformed/unsupported payloads bypass canonical identity? | **No.** Canonicalization throws on the entire out-of-domain value space — `undefined`, functions, symbols, `bigint`, `NaN`, `±Infinity`, `Date`/`Map`/`Set`/class instances, circular structures, array holes, and object keys mapping to `undefined`. The dispatcher catches this and rejects `UNCANONICALIZABLE_PAYLOAD`. **Nothing is silently coerced or dropped** | VERIFIED |
| 12 | Can different property ordering produce different identities? | **No.** Keys are emitted in ascending UTF-16 code-unit order (JCS / RFC 8785-compatible); the permutation test passes; array order is preserved as semantically significant; `-0` collapses to `0`; Unicode compositions are deliberately **not** normalized, so NFC/NFD stay distinct. Independently reconfirmed | VERIFIED |
| 13 | Does validation happen before handler execution? | **Yes, strictly.** Order is shape → agent registered → action allowed → identity recompute → verify → ledger present → consume → *then* `agent.handle`. A spy test asserts the handler is **never** invoked on any rejection path | VERIFIED |
| 14 | Consumption without execution, or execution without consumption? | **Execution without consumption: impossible** for a sensitive task — consumption gates the handler. **Consumption without execution: possible and deliberate** — if the handler throws after consumption the approval stays consumed, documented as an accepted fail-safe (no auto-retry; a fresh approval is required). Non-sensitive tasks consume nothing, correctly | VERIFIED |
| 15 | Is replay protection durable across process restart? | Yes — the ledger rehydrates from disk on construction, and a restart test rejects the replay. A corrupt ledger file **throws** on construction rather than silently presenting an empty consumed-set, closing the silent-replay window | VERIFIED |
| 16 | Is authenticated approver provenance still genuinely open? | **Yes — and disclosed rather than obscured.** `approved_by` is documented in the type as a **claimed identity only**; the module states it is *"NOT a signature, NOT a MAC, and proves NOTHING about WHO produced the command or the approval"*; the provenance test is skipped **by design** with the gap named `OPEN-BLOCKING-OPERATIONAL` | VERIFIED (open) |
| 17 | Does it assume a topology contradicted by [[DEC-0037]]? | **No — and on one point it affirmatively agrees.** Its registry is a closed allow-list keyed to registered agent ids, matching `TARGET_AGENT MUST HAVE A FORMAL CONTRACT + REGISTRY ENTRY` and D3's rule that a generic instance is never a `target_agent`. What it does **not** model is the task-scoped role set of D1 — but that is an **absence, not a contradiction**, and [[DEC-0037]] §9 already states the topology holds under all three dispositions. Correctly stated: the preserved work is **topology-compatible but topology-unaware** | VERIFIED |
| 18 | Does it assume a registered executor capability that does not exist? | **No.** Its own source states the handlers are foundation executors and that real product work is *"wired in later"*. It encodes the capability absence accurately. **The converse is the real finding:** because no handler can perform any destructive act, its hardened gate currently guards nothing executable (§6) | VERIFIED |
| 19 | Can the primitives be separated from the runtime? | **Yes, cleanly.** `command-identity.ts` imports **only** `node:crypto` — zero coupling to registry, dispatcher, orchestrator, logger or state. The mint/verify pair needs only a command-shaped object. The ledger factory needs only `node:fs`/`node:path`. The seams are real, not aspirational | VERIFIED |
| 20 | Any reason to reject it **on merit**? | **Not the primitives.** Known limits — single-process-only atomicity, non-atomic `writeFileSync` (no temp-file-plus-rename), unbounded ledger growth with a full-file rewrite per consume, and the Q5 unbound descriptive fields — are real engineering debts, each of which **fails loud or fails closed** rather than open. None is a merit-level rejection. **The merit objection is to the orchestration abstraction, not to these primitives** (§8, §11) | VERIFIED |

---

## 8. Decision

### D1 — Disposition: **REDUCE**

`packages/orchestrator` is **NOT selected as the Agent Governance V2 runtime foundation.** The broader multi-agent orchestration control plane is **reduced to NON-AUTHORITATIVE legacy**: it remains on `main` exactly as it is, it is not the intended architecture, and no document may present it as such.

A precisely-named subset is **retained as a non-authoritative candidate primitive set** for a later, separately-authorized unit.

**Retention is not adoption.** Naming a primitive below confers no authority, activates nothing, wires nothing, and creates no obligation on any future unit to use it. It records that this unit examined the surface, found it valuable, and did not discard the finding.

### D2 — The exact boundary

**Retained — `CANDIDATE PRIMITIVE · NON-AUTHORITATIVE · NOT ADOPTED`:**

| Surface | Where it exists today | Status |
|---|---|---|
| **Command identity / JCS canonicalization** — content-addressed identity for an authority-bearing command | **Preserved only**, `151fb46:packages/orchestrator/src/core/command-identity.ts`. **Not on `main`** | Candidate |
| **Approval binding and verification semantics** — mint against a concrete command; verify against a live recompute; reject unbound tokens with no compatibility fallback; exclusive expiry boundary | **Preserved only**, `151fb46` `src/core/safety.ts`. **Not on `main`** | Candidate |
| **Single-use consumption-ledger semantics** — durable write-through, test-and-set, fail-closed when absent, fail-loud when corrupt | **Preserved only**, `151fb46` `src/core/project-state.ts`. **Not on `main`** | Candidate |
| **Safety classification** — `assessSensitivity`, the sensitive-action set and the destructive-payload heuristics | **Landed on `main`**, `src/core/safety.ts` | Candidate |

**Reduced to legacy — `NON-AUTHORITATIVE · LANDED · UNCHANGED · NOT THE INTENDED ARCHITECTURE`:** `src/core/orchestrator.ts` (the run loop and `bootstrap()`); `src/core/dispatcher.ts` (routing); `src/core/agent-registry.ts` and all ten `src/agents/*`; `src/core/decision-schema.ts` and `src/core/decision-validator.ts`; the project-state reducers and store in `src/core/project-state.ts`; `src/core/logger.ts`; `src/core/ids.ts`; `examples/delegate-task.ts`.

**Routed elsewhere, not decided here:** `src/core/result-schema.ts` and the `AgentResult` envelope are **`C4`'s** subject. This record takes no position on them and does not retain them as a `C2` primitive.

### D3 — Zero code action

`C2` decides; it does not implement.

> **No file under `packages/orchestrator/**` is deleted, moved, renamed, edited or emptied by this record.** Nothing from `151fb46` is copied, cherry-picked, ported or adopted. The preserved ref is untouched. `REDUCE` is a **status decision**, never a deletion instruction, and no future unit may cite this record as authorization to remove code.

---

## 9. Validation performed

All work was read-only with respect to every ref. **Nothing was installed.**

- **Primary checkout** (`c:\Adeptlabs\noxund`, at canonical-main content for this path): `node --test "tests/**/*.test.ts"` → 36/36; `tsc --noEmit` via the package's already-present `node_modules/.bin/tsc` → exit 0; corpus-wide importer and workflow searches over tracked files; an inline, file-free executable probe reproducing the four approval-gate properties (§6).
- **Detached validation worktree** pinned to `151fb46`, no branch, no ref mutation, nothing copied out: `node --test` → 75 pass / 0 fail / 1 skipped-by-design; typecheck by invoking the **primary checkout's already-installed** `tsc` against the worktree's `tsconfig.json` with `--typeRoots` pointed at the primary checkout's `@types` → exit 0. `tsconfig.base.json` is byte-identical across the two trees and sets no `incremental`, so `--noEmit` wrote nothing. An inline, file-free probe independently confirmed cross-process identity determinism and key-order invariance.
- **Dependency policy outcome:** the zero-install path succeeded for both execution and typecheck. `pnpm install --offline` was **never invoked**, no lockfile was read or written, no network request was made, and no lifecycle script ran. **`UNKNOWN — PRESERVED EXECUTABILITY NOT ESTABLISHED` was not reached and is not claimed.**
- **No scratch, temp, sidecar, cache or backup file was created at any point**, in either checkout.

---

## 10. Decision matrix

Criteria applied identically to all three options. **Code volume already written is not a criterion and was not used.**

| Criterion | **A — RESUME-AND-HARDEN** | **B — REDUCE** *(selected)* | **C — RETIRE** |
|---|---|---|---|
| [[DEC-0037]] compatibility | Compatible; §9 holds under all three | Compatible | Compatible |
| Actual current NOXUND need | **None demonstrated** — §12 | Primitives only | Correctly finds none for the runtime |
| Governance risk reduced | **Negative** — institutionalizes a runtime nobody runs | Positive — names the intended architecture and preserves the useful substrate | Positive on the abstraction; **loses the substrate** |
| Complexity introduced | High — commits to maintaining and DEC-0037-adapting a control plane with no consumer | Low — a status decision plus a named inventory | Lowest |
| Existing verified implementation value | Overvalues it as a runtime | **Values it correctly, as primitives** | Undervalues it |
| Dependence on nonexistent registered executors | **High** — its value proposition presumes executors that do not exist and are not being created | None — primitives need no executor | None |
| Dependence on a second GitHub principal | None, and it cannot supply one | None; correctly routes provenance to `C3` | None |
| Ease of fail-closed behaviour | Good in the preserved design | Good — the retained primitives are the fail-closed parts | n/a |
| Approval / provenance correctness | Identity and consumption repairable; **provenance unsolvable here** | Same, with provenance explicitly assigned | n/a |
| Testability | Demonstrated | Demonstrated, and better in isolation | n/a |
| Maintainability | Poor — unused surface rots silently | Good | Best |
| Runtime-agnosticism | **Violates it in spirit** — makes one specific TS runtime the foundation | Preserved — primitives are libraries | Preserved |
| Risk of drifting into Phase-F orchestration | **High** — wiring it *is* runtime-mediated execution | Low | Lowest |
| Cost of future implementation | High and speculative | Low, and incurred only when a real need appears | Re-derivation cost if the need appears |
| Preserves Product-Lead GO semantics | Neutral | Neutral | Neutral |
| **F1** generic subagent misrepresented as registered agent | **No** — a runtime polices only what it mediates, and governed work does not flow through it | No — correctly left to [[DEC-0037]] D1–D3 | No |
| **F3** approval gate bypassable | **Partly, and for the wrong gate** — NOXUND's real approval gates are Product-Lead merge and GitHub rulesets, not this dispatcher | **Yes, at the primitive level** — identity and consumption are the reusable substrate wherever the gate lives | **No** — discards the one asset on point |
| **F6** paper governance never the system in use | **Makes it worse** — the package is itself an instance of F6 | **Yes** — stops presenting a disconnected runtime as the architecture | Yes |
| **F7** author PASS promoted to ACCEPTED | No — role separation ([[DEC-0037]] D5/D6) and `C5` enforcement | No — same | No |
| **F11** results lack evidence provenance | No — that is `C4`'s schema question | No — routed to `C4` | No |

---

## 11. Rejected alternatives

**A — RESUME-AND-HARDEN is rejected**, and not because the code is poor. The preserved hardening is the best-engineered artifact this unit examined. A fails on its own stated conditions:

- It requires that the package *"solves a real near-term governance problem."* It does not. [[DEC-0037]] §3 states the governance functions do not depend on a runtime, and §12 below finds no Phase-C problem that needs one.
- It requires that the disconnected state be *"a wiring gap rather than evidence the abstraction is unnecessary."* The evidence points the other way, and it is stronger than a two-phase observation: searching **every ref and the entire repository history**, **no code file has ever imported `@noxund/orchestrator` at any point** — not once, on any branch, in any commit. The package has been landed, green and importable throughout Phases A and B and was never reached. That is a sustained record of non-use, not an unfinished integration.
- It requires that the useful foundation *"materially exceeds maintenance cost."* The genuinely useful foundation is the primitive set, which B retains at a fraction of the cost.
- Wiring governed work through a TS dispatcher is **runtime-mediated agent execution**, which is Phase-F territory and out of scope for Phase C.
- **The decisive point:** adopting A would assert that a disconnected runtime is the intended architecture on the strength of the work already inside it. Sunk work is not an architectural criterion, and this record refuses to treat it as one.

**C — RETIRE is rejected on one point only, and it is a real one.** C is right about the abstraction and wrong about the residue. Its condition is that *"the abstraction solves no currently-justified problem"* — true, and B agrees. But C would sweep the primitives out with it, and the primitives are the exact subject-matter [[DEC-0032]] §8 named when it deferred *"approver-provenance and consumption-ledger atomicity"*. Retiring wholesale would discharge that deferral by discarding the only verified work addressing two of its three limbs, and would leave the third with no stated home. **C was not rejected because a real executor does not exist** — that is a capability fact, not a verdict, and it argues against A rather than for C.

**On the charge that B is a hedge.** B is falsifiable and was tested in both directions. Had the primitives been unverifiable, redundant or dependency-heavy, this record would say **RETIRE**. Had any Phase-C objective actually required a dispatcher, a registry or a run loop, it would say **RESUME**. Neither held, and B names its boundary at file granularity in D2 rather than gesturing at one.

---

## 12. The critical question — what Phase-C problem requires an in-repository orchestration runtime?

> **None.**

Phase C's problems, taken one at a time: **who may legitimately act** is `C1`, answered by process — role separation and Product-Lead gating, explicitly runtime-independent ([[DEC-0037]] §3). **Which identity-naming clauses are satisfiable** is `C3`, a question about GitHub principals, `CODEOWNERS` and rulesets — a runtime cannot create a second trusted principal. **Whether results carry evidence provenance** is `C4`, a schema question. **Mechanical enforcement** is `C5`, which lives in CI, hooks and branch protection — surfaces that constrain the repository whether or not any TS process runs.

Not one of these is a runtime problem, and a runtime could not reach three of them.

The nearest thing to a runtime-shaped need is **approval integrity**, and inspection shows it is not runtime-shaped either. Binding an authorization to one exact command, and consuming that authorization exactly once, are **library** concerns. They need a hash function, a canonical serialization and a durable set. They need no dispatcher, no agent registry and no orchestration loop. That is precisely why B retains them as primitives and reduces the runtime around them.

**Stated against NOXUND's actual failure modes:** F1, F7 and F11 are answered by process and by schema; F6 is *worsened* by retaining an unused runtime; and F3 — the only one with a technical core — is answered by primitives that are not a runtime. **"It already exists" is not an answer, and this record does not use it as one.**

---

## 13. Identity, consumption, provenance — three things that must not collapse

| | Question | Status after this record |
|---|---|---|
| **COMMAND IDENTITY** | *What exact command is authorized?* | **Solved in preserved work, verified by this unit, retained as a candidate primitive.** Content-addressed, deterministic across processes, JCS-compatible, domain-separated, `0x1F`-framed against field-boundary collisions, fail-closed across the whole out-of-domain value space. **Not landed** |
| **APPROVAL CONSUMPTION** | *Has that authorization already been used?* | **Solved for the single-process model, verified by this unit, retained as a candidate primitive.** Durable across restart; fails closed when the ledger is absent; fails loud when it is corrupt. **Multi-process atomicity is UNPROVEN and is not claimed.** **Not landed** |
| **APPROVER PROVENANCE** | *Who actually had authority to authorize it?* | **OPEN. Routed to `C3`. Not solved here, and not solvable here.** |

**The load-bearing distinction, stated so it cannot be lost:**

> **A content-addressed approval is not authenticated merely because it is well-bound.** Identity answers *what*; consumption answers *how many times*; **neither answers *who***. A perfectly bound, single-use, unexpired approval naming `product_lead` proves only that someone who could call `mintApproval` typed that string. Hashing is not attestation.

Authenticated provenance requires a **second technical principal or an external trust mechanism** — a distinct GitHub identity, `CODEOWNERS`-enforced review, a signing key, or an equivalent. Every one of those is `C3`'s subject, and the repository currently has none of them: no `CODEOWNERS` file exists anywhere in the tree, and the same principal may author and merge. **`C2` does not solve `C3`**, and no primitive retained in D2 may ever be represented as supplying provenance.

---

## 14. Reconciliation performed

**`docs/agents/product-orchestrator-agent.md`** — mutability class established first: `docs/agents/**` agent contracts are INTERNAL-NORMATIVE within their declared agent-behaviour scope and **EDITABLE** ([[DEC-0035]] §9). [[DEC-0037]] §3 classified the vehicle clause as **descriptive** — it names an execution vehicle and requires nothing of anyone — and routed it to `C2` as *"where the vehicle sentence either becomes true or is repaired."* Under D1 it does not become true. It is therefore **repaired, minimally and additively**: the `@noxund/orchestrator` vehicle reference is removed from that one sentence and replaced by a short marked reconciliation note pointing here. **The binding limbs of the same section — `ORCHESTRATOR ≠ AUTHOR / PRIMARY TECHNICAL REVIEWER / GOVERNANCE AUDITOR` and the prohibition list — are untouched.**

**A second clause in the same file, repaired for the same reason.** §*Output Format* at `:726` opened *"Operando dentro do runtime `@noxund/orchestrator`, a decisão canônica … é UM `OrchestratorDecision` em JSON por vez"*. Verified as **the only other vehicle reference in the file** — the remaining `runtime` occurrences are generic. Repairing only the first clause would have left **one INTERNAL-NORMATIVE file asserting both positions**, a contradiction **this unit would itself have created**: before the repair both clauses were consistently stale. **Reconciled rather than routed**, on three grounds: the file is EDITABLE; a defect created by this unit is this unit's to close, not a residual to hand onward; and the repair is **strictly smaller** than the first one, because the execution vehicle and the decision *format* are independent — deleting the vehicle preposition leaves the binding sentence intact and **drags in none of the `OrchestratorDecision` / `TaskCommand` format machinery**, which is untouched in whole. A one-line parenthetical points to the §*Operating Protocol* note rather than duplicating it.

**`docs/product/current-state.md`** and **`docs/product/context-map.md`** — reconciled **only** where this unit's landing changes current truth or routing, under each file's scoped-reverification convention, with a scoped-reverification paragraph recording exactly what was and was not re-read.

**Deliberately not done, and routed rather than silently skipped:** `docs/agents/orchestration-runtime.md` still describes the package as an implemented runtime and carries the stale `Status: implementado` line; `docs/agents/README.md`, `agent-registry.md`, `agent-boundaries.md`, `agent-review-matrix.md` item #14, `agent-onboarding-orchestration.md` and the ten agent contracts each contain runtime-operating prose; `orchestration-runtime-engineering-agent.md` describes a contract for implementing this control plane. **None is edited here.** General agent-doc cleanup, registry cleanup, `orchestration-runtime.md` cleanup and historical normalization are outside this unit's authorization and are **routed to a Product-Lead-authorized reconciliation unit**, alongside the `orchestration-runtime.md` residual already routed by [[DEC-0035]] §11 step 4 and left unsolved by B5.

---

## 15. Relationship to [[DEC-0037]] and the boundaries this record respects

[[DEC-0037]] §9 fixes the authority direction one-way: **`C1 GOVERNANCE MODEL → RUNTIME IMPLEMENTATION`, never the reverse.** This record is an instance of that direction, not an exception to it. The governance model was decided first and independently; this record decides only what the runtime *is*, and it does not amend, narrow or reinterpret any part of [[DEC-0037]]. Because §9 already declared the topology to hold under all three dispositions, selecting `REDUCE` **confirms** [[DEC-0037]] and disturbs nothing in it.

- **`C3` dependency.** Authenticated approver provenance (§13) is `C3`'s, together with the satisfiability of every identity-naming clause other than item #12. **This record neither solves nor pre-empts it**, and creates no expectation that `C3` will adopt any retained primitive.
- **`C4` dependency.** The `AgentResult` envelope and result-schema V2 are `C4`'s. D2 deliberately does **not** retain `result-schema.ts` as a `C2` primitive, so `C4` inherits an unconstrained field.
- **`C5` dependency.** All mechanical enforcement — validators, lint, hooks, CI, `CODEOWNERS`, rulesets, branch protection — is `C5`'s. **Nothing in this record is mechanically enforced**, and no primitive retained in D2 enforces anything.
- **Phase-F boundary.** Wiring any runtime to mediate agent execution, DAGs, unattended loops, automatic `NEXT` and persistent orchestration memory are **Phase F**. `REDUCE` deliberately reduces the exposure to that drift, and **this record authorizes no step toward it.**
- **Axis-1 boundary.** Nothing here touches the product/engineering axis, the database, Supabase, AWS, collection, or any re-arming. **Nothing is re-armed.**

---

## 16. Migration and implementation implications

- **Nothing to migrate at this base.** No consumer exists to break: zero code importers, zero workflows. The `REDUCE` decision has **no runtime blast radius**, which is exactly why it can be taken as a docs-only unit.
- **Any future use of a retained primitive requires its own explicit Product-Lead GO.** A later unit that wants command identity or the consumption ledger **implements it under that GO**, starting from the preserved design as *evidence of a validated approach* — never by citing this record as authorization, and never by treating `151fb46` as adopted.
- **If any surface reduced to legacy is ever revisited**, that requires a **later landed decision record**, not a reading of this one.
- **Removal is not implied.** Should the Product Lead later want the legacy surface deleted, that is a separate authorized unit with its own GO. **This record is not that authorization** (D3).
- **The approval defect stays open and stays disclosed.** It is not fixed here, and it must be resolved **before** any wiring, never after — the latency in §6 is a property of the current base, not a durable protection.

---

## 17. Effective and landing semantics

**In force from the Product Lead's manual merge of this record**, and prospective from that moment. Specifically:

- it decides a disposition and a documentation boundary; it **changes no code and no runtime behaviour**, because the runtime has no behaviour anything reaches;
- it **does not retroactively validate or invalidate any earlier unit**, including its own production, which stands on the `C2` GO and on nothing in this record — **a record does not ratify itself**;
- it creates **no standing permission**: every unit still requires its own explicit Product-Lead GO ([[DEC-0035]] §6). **Landing this record authorizes nothing further** — not `C3`…`C5`, not any implementation of a retained primitive, not any deletion, and no Axis-1 resumption;
- it is **FROZEN** ([[DEC-0035]] §9): its body is never rewritten, a change to this disposition requires a **later landed record**, and no GO, handoff, closeout or memory may amend it ([[DEC-0035]] §5, §6);
- **no preserved file becomes landed by this record.** `151fb46` remains `EVIDENCE / HISTORICAL`, and every primitive marked *Preserved only* in D2 is **not on `main`**;
- imperative wording in any EVIDENCE artifact describing this disposition creates no obligation beyond what this record states ([[DEC-0035]] §3.1).

---

## 18. Known weak points, disclosed by the Author

Stated so the record is honest about its own limits rather than leaving them to be found:

1. **A disclosed residual in a retained primitive: the gate's classify/verify ordering fails *open* for one field.** Every field bound into command identity fails **closed** when mutated — `action`, `payload`, `task_id`, `target_agent` all reject with `COMMAND_IDENTITY_MISMATCH`. **`requires_human_approval` fails *open***: flipping it `true → false` on an otherwise benign command makes `assessSensitivity` return not-sensitive, the dispatcher skips the entire gate, and the command executes **with no approval and no consumption** — identity byte-identical either way (§7 Q5, reproduced by execution). **Binding the field into identity would not fix this**, because on the not-sensitive path identity is never compared. The fix is **ordering** — verify before classify — **or binding the sensitivity verdict itself**, and it belongs to whichever future unit adopts these primitives. **This changes no decision here**: the affected code is preserved, explicitly **NOT ADOPTED**, and unreachable at this base (§6). It is recorded so that a future adopting unit cannot mistake *well-bound* for *fully gated*.
2. **The multi-process ledger limit is a real ceiling.** Should any future design run two processes against one ledger file, the retained consumption primitive is **insufficient as it stands** and would need locking or a compare-and-swap. This is recorded, not solved.
3. **The "sustained non-use" argument in §11 is inductive.** Two phases of non-use is strong evidence that the abstraction is unnecessary, but it is not proof; a future phase could produce a genuine need. The mitigation is that `REDUCE` deletes nothing, so that need remains serviceable.
4. **`assessSensitivity`'s destructive-payload heuristics are regex-based and evadable.** They are shared by both trees and are not introduced by the preserved work, but a primitive retained in D2 must not be mistaken for a robust classifier.
5. **The boundary in D2 is drawn at file granularity, and two files are mixed.** `safety.ts` contains both a retained classifier and retained approval semantics; `project-state.ts` contains a retained ledger alongside reduced state reducers. A future implementing unit must split them rather than adopt either file whole.

---

*Related: [[DEC-0032]] §8 (the discharged deferral), [[DEC-0035]] §9 (family defaults; `PRESERVED ≠ ADOPTED`), §10 (forward-discoverability), [[DEC-0037]] §3, §9, D1–D6 (execution topology; the `C2` reservation; the vehicle-clause routing). Preserved evidence, cited by exact SHA and **not adopted**: `151fb46bd5f335d26a93fc85d4dc9209340c9294`, `packages/orchestrator` tree `28009403c74a0f96a4ba3f8349f30b66fee2f51e`. Current-main `packages/orchestrator` tree: `7457f3f259ce8987e74ebe9f3db48172eabbd02b`. Forward-discoverability: the `DEC-0038` rows in `docs/product/context-map.md` §3.*
