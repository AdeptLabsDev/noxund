# DEC-0040 — Governed result, disposition and closeout contract

**Status:** ACTIVE (binding) · **Date:** 2026-08-21 · **Decision authority:** Product Lead
**Authority class:** INTERNAL-NORMATIVE · **Lifecycle:** ACTIVE / CURRENT · **Mutability:** FROZEN — the `docs/product/decisions/**` family default ([[DEC-0035]] §9), declared here under the fail-closed rule ([[DEC-0035]] §7).
**Drafted by:** a `TASK-SCOPED AUTHOR` ([[DEC-0037]] D1), reviewed by a **distinct** task-scoped independent reviewer, under the Product-Orchestrator-coordinated topology [[DEC-0037]] D5/D6 fixes, carried into this unit by the Product Lead's `C4` GO. Unit `PHASE-C-C4-RESULT-AND-DISPOSITION-CONTRACT-R1`. This record is **governance-sensitive** ([[DEC-0037]] D6): it changes what counts as evidence, what a verdict means, and how a unit is closed. **Ratification gate:** the Product Lead's manual merge of this record.
**Scope:** What a governed NOXUND unit **returns**, and what each part of that return means. It fixes six semantic axes that the corpus currently mixes into one vocabulary; the smallest useful `ROLE RESULT` an Author or Reviewer returns; the single `GOVERNED UNIT CLOSEOUT CONTRACT` a unit presents to the Product Lead; the mutation-accounting contract; the conditions under which a technically accepted artifact may survive a historical unit `RED`; the durability rule for evidence references; and the standing of the landed `AgentResult` envelope. **Process-first and runtime-agnostic** ([[DEC-0037]] header), matching the topology it serves. **Docs-only unit.**
**Negative scope — this record does not create or change:** any file under `packages/orchestrator/**` — **no code is created, deleted, moved, renamed, edited, ported, cherry-picked or adopted**, and **no `AgentResult` V2 is written in TypeScript or any other language** · `src/core/decision-schema.ts`, `src/core/task-schema.ts` or the `TaskCommand` shape · the preserved commit `151fb46bd5f335d26a93fc85d4dc9209340c9294` or any other ref, branch, stash or archive · any agent registration, activation, contract boundary, registry entry, review-matrix item, runtime handler, runtime allow-list or runtime wiring · any GitHub principal, App, bot, service account, token, credential or secret · any workflow, ruleset, branch protection, `CODEOWNERS`, CI check, validator, lint or hook (`C5`) · any Environment, variable or repository setting · any database, SQL, migration, role or runner · any cloud resource · any collection arming state · any product scope, MVP admission, `OD-*` item or Axis-1 technical question · memory content of any kind. **No agent is wired, no agent is registered, no principal is provisioned, no executor is activated, and no execution of any kind is authorized.**
**Extends:** [[DEC-0037]] §9 — supplying the **`C4` limb only** of the Phase-C work that clause reserved (*"`C4` — `AgentResult` V2 / result schema"*). **Stated plainly rather than by quiet substitution: §9 named that limb by the shape it expected — a schema — and this record supplies the limb as a *process contract* instead.** That is the answer the evidence supports, not a redefinition of the reservation: [[DEC-0038]] D1 reduced the runtime that would have hosted a schema to **NON-AUTHORITATIVE legacy**, and [[DEC-0037]] itself is `HYBRID · PROCESS-FIRST · RUNTIME-AGNOSTIC`, so a governance contract that only exists as TypeScript would bind nothing and reach nothing (§8). [[DEC-0037]] is neither edited nor narrowed and remains **CURRENT** and **FROZEN**; its D1 actor taxonomy, D5/D6 topology, D7 independence criteria, D10 orchestrator constraints and D11 GO/merge semantics are consumed unchanged.
**Discharges — by satisfaction, not by replacement:** (i) the **`C4` routing** [[DEC-0038]] D2 and §15 made — *"`src/core/result-schema.ts` and the `AgentResult` envelope are `C4`'s subject"*, *"D2 deliberately does not retain `result-schema.ts` as a `C2` primitive, so `C4` inherits an unconstrained field"* — answered at D16 and §8; and (ii) the **`C4` metadata assignment** [[DEC-0039]] D14 and §8 made — *"`C4` … is the natural carrier for capability and principal metadata"*, with the list of what a result must be **able to express** — consumed at D10, D11 and D12. **`DISCHARGES` is the exact token in both cases:** each was a *question assigned for adjudication*, discharged by being answered, which is the distinction [[DEC-0038]] §3 draws about its own discharge of [[DEC-0032]] §8 and [[DEC-0039]] repeats about [[DEC-0038]] §13. **No supersession token applies:** neither record is edited or narrowed, [[DEC-0038]]'s **REDUCE** disposition and [[DEC-0039]]'s **P3 — HYBRID** decision are neither rewritten nor reopened, and both stay **CURRENT** and **FROZEN**.
**Narrows:** **nothing.** No clause of any file is narrowed. The one narrowing in this corpus remains [[DEC-0037]]'s, of `agent-review-matrix.md` item #12, and it is not extended by analogy here.
**Does not edit:** any prior DEC. [[DEC-0001]] … [[DEC-0039]] all remain **frozen and additive-only**; [[DEC-0028]] and [[DEC-0033]] remain **byte-frozen** per [[DEC-0034]] §4. **[[DEC-0037]] is FROZEN and is not edited by this record — including where §7 finds one of its line-number citations has drifted.** No prior record is declared obsolete, superseded, reopened or reinterpreted, and **no historical disposition of any earlier unit is revisited, upgraded, downgraded or rewritten**.
**Reconciles:** `docs/agents/product-orchestrator-agent.md` — **seven exact points**, each one made incomplete or misleading by this record and by nothing else: the §*Operating Protocol* result reference; the §*Trust model* heading and two of its bullets; §*Stage-Gate Discipline*'s historical-finding clause, which gains a pointer; §*Evidence, Provenance & Review Rules*, whose mandatory-classification list is the axis-collapse site (D3); §*Governance breach* item 3, whose conditional `RED` this unit's own D5 would otherwise contradict; the §*Operational Invariants Summary* breach line; and **§*Output Format*, which gains one new `###` subsection carrying D17's three-artifact boundary — the largest additive block this unit makes to the file, and the only new subsection**. **The binding limbs of that file are untouched** — `ORCHESTRATOR ≠ AUTHOR / PRIMARY TECHNICAL REVIEWER / GOVERNANCE AUDITOR`, both prohibition lists, the registry-first provisioning model, the entire `OrchestratorDecision` / `TaskCommand` format contract — **which the new §*Output Format* subsection sits beside and expressly disclaims changing** — and [[DEC-0038]] §14's two reconciliation notes, which are preserved verbatim. `docs/agents/handoff-template.md` — `DESCRIPTIVE-CURRENT`, a format aid and not a handoff ([[DEC-0035]] §9) — is restructured to carry this contract so a fresh operator can produce a compliant return without consulting a past prompt; **its pre-existing scope-impact gate, cross-review triggers, acceptance-criterion, validation and risk sections are retained as conditional sections rather than dropped** (§11). **No other file under `docs/agents/**` is touched**; the general agent-doc cleanup [[DEC-0038]] §14 routed to a separate Product-Lead-authorized reconciliation unit stays there, and §11 adds this unit's residuals to it rather than sweeping them.
**Canonical base:** `main` @ `cc0483dda0c9cb4a7dd593e81c7800ff6c6be3ae`

---

## 1. Status

**ACTIVE — binding and prospective**, effective on the Product Lead's manual merge (§14). It fixes governance semantics. It creates no status vocabulary beyond what the corpus already uses, registers no agent, wires no runtime, writes no code, provisions no principal, and authorizes no unit.

---

## 2. The problem

NOXUND says `PASS` and means nine different things.

The corpus currently expresses, in one undifferentiated vocabulary: runtime execution status · an Author's self-report · a Reviewer's verdict · the evidence class of a claim · a unit's governance disposition · acceptance of an artifact · the lifecycle of a governance finding · the Product Lead's ratification · and a `NEXT` recommendation. The most visible instance is landed and normative: `product-orchestrator-agent.md` §*Evidence, Provenance & Review Rules* lists `HOLD` and `RED` inside the same *"classificação obrigatória de afirmações"* as `REPORTED`, `VERIFIED`, `ACCEPTED` and `UNPROVEN` — mixing **how well a claim is established** with **what happened to a unit**. They are not the same question and cannot share an axis.

**This is not a theoretical tidiness problem. Phase C proved it twice, in production, on this repository.**

`C0` was `RED — VERIFIED AUTHORIZATION BREACH` for unauthorized scratch-file creation, failure to stop on recognition, and unauthorized self-remediation by deletion — while its substantive assessment evidence was **preserved as usable** and its governance finding was later adjudicated `CLOSED — REMEDIATED` **without the historical `RED` being rewritten to `PASS`** ([[DEC-0037]] header). `C3` did it again with a different shape: `C3 UNIT = HISTORICAL RED` for an unauthorized out-of-repository `MEMORY.md` write, `C3 GOVERNANCE FINDING = CLOSED — REMEDIATED`, `ARTIFACT INDEPENDENT TECHNICAL REVIEW = PASS`, and an explicit Product-Lead acceptance of the unit/artifact separation — with [[DEC-0039]] landing as current authority and its `RED` preserved ([[DEC-0039]] header).

Both outcomes are correct. **Neither is expressible in a vocabulary with one axis.** A single-axis reader has exactly two bad options: call the unit `PASS` and lose the breach, or call the artifact `RED` and lose a sound record. Both units survived only because a human held the distinction in their head and wrote it out by hand, in prose, differently each time. The second failure mode is worse than the first: the distinction that saved `C3` is currently reachable only by reading two clauses of an agent contract that a landed `FROZEN` record cites **by a line number that has since moved** (§7).

Two further defects follow from the same root, and both were also observed rather than imagined. **Every governed unit so far has invented its own return contract** — bespoke, 40-to-60-field, unrepeatable, and impossible to check mechanically because no two are the same shape. And **mutation accounting has been repository-shaped while the breaches were not**: `C0`'s breach was a scratch file, `C3`'s was a file outside the repository entirely. In both cases `git status` was clean and the unit was not.

This record separates the axes, fixes one return contract for a role and one for a unit, and makes the accounting cover what actually gets written.

---

## 3. Cross-adjudication and evidence, re-derived at the canonical base

`C2` and `C3` executed in parallel and landed in sequence — PR #89 at `1e7e124a2374917c95bffbb56f5f515d95132ee2`, PR #90 at this base. `C4` is the first unit to run with **both** landed, so it is the first that must be adjudicated against both. Every claim below was established by this unit at `cc0483dd`, not inherited.

**E1 — [[DEC-0038]] is landed and its disposition is `REDUCE`.** `VERIFIED`. The orchestration control plane is **NON-AUTHORITATIVE legacy** (D1); a named subset is retained as **candidate primitives, not adopted** (D2); **zero code action** (D3).

**E2 — `result-schema.ts` was deliberately *not* retained.** `VERIFIED`. [[DEC-0038]] D2's *"Routed elsewhere, not decided here"* row names `src/core/result-schema.ts` and the `AgentResult` envelope as `C4`'s subject and states that this record *"takes no position on them and does not retain them as a `C2` primitive"*; §15 adds that *"`C4` inherits an unconstrained field"*. **So the envelope carries no `C2` retention, no adoption and no authority.**

**E3 — [[DEC-0039]] is landed and its principal-separation decision is `OPTION P3 — HYBRID`.** `VERIFIED`. D9 accepts single-principal containment for ordinary governed work and makes a second principal a prerequisite for exactly three things, none of which is in flight. **`C4` is ordinary governed work and requires no second principal.**

**E4 — [[DEC-0039]] materially constrains what a result may say about identity.** `VERIFIED`. D1 fixes `LOGICAL ROLE ≠ EXECUTION INSTANCE ≠ TECHNICAL PRINCIPAL`; D2 makes `UNKNOWN` a **required outcome** rather than a failure; D6 fixes the exact and only permitted label for this environment, `PROCESS-INDEPENDENT · PRINCIPAL-NOT-INDEPENDENT`; D7 forbids describing role scoping as sandboxing; D9 item 1 forbids any representation that a GitHub approval was independent. D14 names `C4` the carrier and §8 lists what the metadata must be **able to express** while leaving the shape to `C4`.

**E5 — no `HOLD — AUTHORITY-CONFLICT` exists among [[DEC-0037]], [[DEC-0038]] and [[DEC-0039]].** `VERIFIED`, and tested rather than assumed. [[DEC-0035]] §4 **P3** engages only where two CURRENT INTERNAL-NORMATIVE authorities genuinely conflict with no explicit edge. Here every edge is explicit, recorded in `context-map.md` §3, and **one-way**: `DEC-0038 EXTENDS DEC-0037 §9`, `DEC-0038 DISCHARGES DEC-0032 §8`, `DEC-0039 EXTENDS DEC-0037 §9 · D12`, `DEC-0039 DISCHARGES DEC-0038 §13 · §15`. [[DEC-0039]] §11 states in terms that it does not decide, revisit or reopen `C2`. **P3 does not engage and no `HOLD` is owed.**

**E6 — `C4` does not depend on `packages/orchestrator` as a runtime foundation.** `VERIFIED`. [[DEC-0037]] §3 establishes that the governance functions *"are satisfied by role separation and Product-Lead gating and do not depend on any runtime being wired"*; [[DEC-0038]] §5 re-derived by execution that the package has **zero code importers outside itself and zero workflow references**, and §11 that **no file has ever imported it at any point in the repository's history**. A contract that lived only inside it would reach nothing. **`C4` is runtime-agnostic by necessity, not by preference.**

**E7 — the landed `AgentResult` envelope, read field by field.** `VERIFIED` by direct reading of `packages/orchestrator/src/core/result-schema.ts` at this base: `{ task_id, agent, status, summary, artifacts[], errors[], next_recommendation }`, with `status` one of `completed | failed | needs_review | blocked`, and `validateResultShape` requiring `task_id`, `agent`, `summary` to be strings, `status` to be one of the four, and `artifacts` and `errors` to be arrays. Analysis at §8.

**E8 — the four execution-state tokens have a landed home that is not the code.** `VERIFIED`. `product-orchestrator-agent.md` §*Decision sequencing* states normatively that *"`completed` do Author não significa 'aceito'; significa 'pronto para revisão' quando review é obrigatório"*, that *"`needs_review` deve ser roteado ao reviewer adequado"*, and that *"`blocked`/`failed` deve ser tratado ou re-delegado; nunca forçado"*. **The tokens' normative force comes from an INTERNAL-NORMATIVE agent contract, not from `result-schema.ts`**, which merely mirrors them — so D2 retains the vocabulary without retaining the envelope.

**E9 — the evidence-class list is the axis-collapse site, and it is landed and normative.** `VERIFIED` by direct reading of §*Evidence, Provenance & Review Rules*. Repaired at D3 and §11.

**E10 — the current breach invariant is conditional in two places.** `VERIFIED`. §*Operational Invariants Summary*: `ANY VERIFIED AUTHORIZATION BREACH => UNIT RED WHEN THE GATE POLICY REQUIRES RED.` §*Governance breach* item 3: *"retornar `RED` quando a política da unidade assim exigir"*. Adjudicated at D5.

**E11 — line-number citations into `product-orchestrator-agent.md` have drifted across four landed records.** `VERIFIED` by re-derivation at two bases. Full finding at §7.

---

## 4. Decision

### D1 — Six axes, and they do not collapse

A governed result speaks on **six independent axes**. Every axis answers a different question, and a statement that does not say which axis it is on is **malformed**.

| Axis | Question it answers | Values | Who may state it |
|---|---|---|---|
| **A — EXECUTION / CONTRIBUTION STATE** | What happened to *one participant's contribution*? | `completed` · `failed` · `needs_review` · `blocked` | the participant |
| **B — EVIDENCE CLASS** | How well is *this claim* established? | `REPORTED` · `VERIFIED` · `ACCEPTED` · `UNPROVEN` | per claim; `ACCEPTED` only via the gates and the Product Lead |
| **C — UNIT GOVERNANCE DISPOSITION** | Did *the unit* stay inside its authorization and satisfy its gates? | `PASS` · `HOLD` · `RED` | the governance-review function; ratified by the Product Lead |
| **D — ARTIFACT / REVIEW VERDICT** | Is *the artifact* technically sound within one review function's scope? | `PASS` · `HOLD` · `RED`, **or the axis is omitted** | the reviewer holding that function |
| **E — GOVERNANCE FINDING LIFECYCLE** | Is *the finding* still open, or has it been remediated? | `OPEN` · `CLOSED — REMEDIATED` | the Product Lead, on independent adjudication |
| **F — NEXT / AUTHORIZATION** | What is recommended next, and what is authorized? | a `NEXT CANDIDATE`; and separately an explicit Product-Lead `GO` | recommendation by anyone; **authorization by the Product Lead alone** |

> **No axis may be inferred from another, and no compound token may be minted to join two.**
> **`PASS-WITH-RED`, `RED-BUT-ACCEPTED`, `CONDITIONAL PASS` and every construction of that family are prohibited.** Where two axes disagree, that is the contract working: state both values, on their own axes, and let them disagree in the open.

**No new status vocabulary is created by this record.** `PASS` / `HOLD` / `RED` / `READY` / `GO` / `NEXT`, `REPORTED` / `VERIFIED` / `ACCEPTED` / `UNPROVEN`, `completed` / `failed` / `needs_review` / `blocked`, `OPEN` / `CLOSED — REMEDIATED`, `AGENT-CAPABILITY-GAP`, `HOLD-PENDING-AGENT-DEFINITION`, `HOLD — AUTHORITY-CONFLICT`, `STATE-AUTHORITY DIVERGENCE` and `STALE-DESCRIPTIVE` all already exist in landed authority. **This record assigns them to axes; it does not add to them** ([[DEC-0037]] D6).

### D2 — Axis A: execution / contribution state is descriptive, never acceptance

```txt
EXECUTION STATE = DESCRIPTIVE / TRANSPORT STATE
EXECUTION STATE ≠ UNIT ACCEPTANCE
```

The four tokens describe **what became of one participant's attempt**, and nothing else. They are retained because they are already normative in an agent contract independent of any runtime (E8), and **not** because `result-schema.ts` defines them (D16). No further status is invented; three of the four already carry landed routing consequences, and the fourth is defined by the contract as *ready for review*, not *accepted*.

- `completed` — the participant finished its contribution. Where review is mandatory this means **ready for review**, never accepted.
- `needs_review` — routed to the appropriate reviewer.
- `blocked` — a dependency or authorization is missing; handled or re-delegated, never forced.
- `failed` — the contribution did not complete; handled or re-delegated, never forced.

**A participant that recognizes a breach returns its execution state honestly and reports the breach; it does not select a token to soften it.** Axis A carries no verdict, so nothing is gained by shading it, and shading it is itself a finding.

### D3 — Axis B: evidence class, restored to four values

`REPORTED` · `VERIFIED` · `ACCEPTED` · `UNPROVEN`, with the existing meanings unchanged and the existing prohibition unchanged: **never convert `REPORTED` directly into `ACCEPTED`.**

> **`REPORTED` ≠ `VERIFIED` ≠ `ACCEPTED`.**

Three consequences the corpus needs stated:

1. **Evidence class is per claim, not per unit.** A single load-bearing claim may be `VERIFIED` while the unit containing it is `HOLD` or `RED`. Nothing about the unit's disposition promotes or demotes a claim, and nothing about a claim's class settles the unit.
2. **`ACCEPTED` is the Product Lead's word.** A claim reaches `ACCEPTED` only after the applicable gates and, where required, the Product Lead — who is the sole acceptor ([[DEC-0039]] D4; [[DEC-0037]] D10, which states that the Product Orchestrator accepts nothing).
3. **`HOLD` and `RED` are removed from this axis.** They were listed here and they do not belong: they answer *what happened to the unit*, which is Axis C. **The substance of both clauses is preserved in full and moves nowhere** — missing evidence still produces `HOLD` (D4) and a verified breach still produces `RED` (D5). Only the axis changes. `product-orchestrator-agent.md` §*Evidence, Provenance & Review Rules* is reconciled accordingly (§11), with an in-file note recording that nothing was revoked.

### D4 — Axis C: unit governance disposition

Exactly three values, and they are **fail-closed**.

- **`PASS`** — the unit satisfied its Product-Lead authorization and every gate required of it at the current stage: it stayed inside its declared scope and write boundary, every required review function was actually instantiated and actually distinct, load-bearing evidence was verified rather than attested, and no required `HOLD` or `RED` is unresolved.
- **`HOLD`** — insufficient evidence · an unresolved required condition · an unheld required review function or `AGENT-CAPABILITY-GAP` · a veto from a domain owner · an unresolved authority conflict · an `UNKNOWN` mutation state (D13) · or a Product-Lead decision required before the unit can close. **`HOLD` is the default under uncertainty:** *missing evidence is `HOLD`, never "probably `PASS`"* — the existing rule, restated because it is the one this axis most needs.
- **`RED`** — a verified authorization or governance breach (D5).

> **`HOLD` is not failure and `RED` is not artifact rejection.** `HOLD` says the unit cannot yet be closed; `RED` says the unit's *conduct* breached its authorization. Neither is a statement about whether the artifact is any good — that is Axis D, and D6 keeps them apart.

**Who states it.** The unit's disposition is stated by the **independent governance-review function** ([[DEC-0037]] D8), never by the Author, and never by the Product Orchestrator, which coordinates and accepts nothing ([[DEC-0037]] D10). The Product Lead ratifies (D18).

### D5 — The authorization-breach invariant becomes unconditional, prospectively

> **`ANY VERIFIED AUTHORIZATION BREACH IN A GOVERNED UNIT => UNIT RED.`**

**What changes.** The landed form was conditional in two places (E10): `ANY VERIFIED AUTHORIZATION BREACH => UNIT RED WHEN THE GATE POLICY REQUIRES RED`, and *"retornar `RED` quando a política da unidade assim exigir"*. **The condition is removed.**

**Why, on the evidence rather than on taste.** The conditional form makes the corpus's most serious classification depend on whether a writ **remembered to state a `RED` condition** — which is a fail-open default in a model that is fail-closed everywhere else ([[DEC-0035]] §7; D4 above). A writ is written before the unit runs and cannot enumerate the breaches it did not anticipate; both actual Phase-C breaches were of kinds their writs had named, but nothing in the conditional form guaranteed that, and a future writ that is merely silent would leave the classification arguable. **`HOLD` already binds unconditionally** (`ANY REQUIRED DOMAIN HOLD => UNIT HOLD`), so the conditional `RED` was also internally asymmetric: the weaker verdict was mandatory and the stronger one was optional.

**What does not change, stated so it cannot be misread.**

1. **The trigger is unchanged.** It fires on a **verified** breach of the unit's authorization — not on a suspected one, not on a technical defect, not on a disappointing result. Unverified suspicion is `HOLD` (D4).
2. **This is prospective only**, from this record's landing (§14). `C0` and `C3` were `RED` under writs that stated the condition, and their historical dispositions are **exactly as they were**. This record confers nothing backwards, revisits no earlier unit, and creates no re-examination duty.
3. **`RED` is still not artifact rejection** (D6, D14), and **`RED` is still never rewritten to `PASS`** (D7).
4. **Blast radius does not alter the classification** ([[DEC-0037]] header) — a breach with zero repository impact is still a breach.

`product-orchestrator-agent.md` is reconciled at both sites, minimally and explicitly, with the prospectivity stated in file (§11).

### D6 — Axis D: artifact / review verdict, and the invariant that keeps it separate

> **`UNIT DISPOSITION ≠ ARTIFACT VERDICT`.**

An artifact verdict is `PASS` / `HOLD` / `RED` **scoped to one review function** (D9), or the axis is **omitted entirely** where the unit produced no artifact and reviewed no target. Omission is a legitimate, informative outcome; a placeholder is not (D12).

All three of these must be representable, and are:

| Case | Axis C | Axis D | Conditions |
|---|---|---|---|
| Ordinary success | `PASS` | `PASS` | the normal path |
| Breach outside the artifact | `RED` | `PASS` | **only** under D14's eight conditions, including independent artifact review and explicit Product-Lead acceptance of the separation. This is the landed `C3` / [[DEC-0039]] case |
| Defective artifact, no breach | `HOLD` | `HOLD` | technical defect, correction by a **new Author task** — a reviewer that fixes it has become a co-author ([[DEC-0037]] D7.5) |

**No compound status.** The two-axis statement *is* the answer; there is no third token that means both.

### D7 — Axis E: governance finding lifecycle

`OPEN` · `CLOSED — REMEDIATED`.

> **`CLOSED — REMEDIATED` DOES NOT REWRITE A HISTORICAL `RED`.**

The two axes answer different questions and are independently queryable, permanently:

- the **historical disposition** records **what happened** — it is a fact about a past unit and is never edited;
- the **finding lifecycle** records **whether the current remediation state is satisfactory** — it moves, and moving it changes nothing about the history.

This is not new authority. It is the landed rule of `product-orchestrator-agent.md` §*Stage-Gate Discipline*, in its own words: *"artefato tecnicamente aceito pode continuar com um finding de governança histórico, desde que o gate atual permita e o Product Lead aceite explicitamente essa separação"*, and *"RED histórico não deve ser reescrito para PASS; closeout resolve o finding atual, não altera a história."* **Cited by section and quotation, per D15** — those two clauses sit at `:600` and `:601` at this canonical base, and the number is a locator only.

Additional binding limbs, carried forward from §*Governance breach*: the party that caused a breach **must not be the sole governance auditor of its own closeout**, and closeout/remediation is delegated to an independent function wherever one is available.

### D8 — Axis F: `NEXT` is never authorization

> **`NEXT CANDIDATE ≠ GO`. `NEXT ≠ GO`. `READY ≠ GO`. `RECOMMENDED ≠ GO`.**
> **No status field on any axis may auto-authorize another stage.**

A `NEXT` is a recommendation and describes sequence, never permission ([[DEC-0035]] §6; [[DEC-0037]] D11). A Product-Lead **GO** is a separate authority event, scoped to one unit, and expires with it.

**The one form of `NEXT` that is self-executing is a `NEXT` that routes control to the Product Lead** — *"the exact next action is: the Product Lead reviews this"*. That is not an exception, because the party it authorizes to act is the one who authorizes. Every other `NEXT` names a candidate and stops.

**Landing this record authorizes nothing further** — not `C5`, not any implementation of anything named here, not any Axis-1 resumption, and no re-arming ([[DEC-0033]] §8).

### D9 — Review verdicts are scoped, and functions are counted rather than heads

```txt
TECHNICAL REVIEW PASS    ≠  GLOBAL UNIT PASS
GOVERNANCE REVIEW PASS   ≠  TECHNICAL CORRECTNESS
DOMAIN REVIEW PASS       ≠  ANY OTHER DOMAIN PASS
```

Each verdict is valid **only within the function that produced it** and is stated with that scope attached. A governance `PASS` states scope and integrity, never technical correctness; a technical `PASS` states correctness, never that the unit stayed inside its authorization.

**A required `HOLD` or `RED` in any veto domain is load-bearing and blocks the unit. There is no majority vote, no confidence average and no "two against one"** (`product-orchestrator-agent.md` §*Sem votação majoritária*; `agent-conflict-resolution.md`). Dissent is preserved, never harmonized away.

**Review functions, not reviewer headcount.** [[DEC-0037]] D5 is consumed unchanged and **is not reopened**: a single distinct non-Author reviewer **may** hold more than one review function where no landed clause requires those functions to be separated. The result contract therefore records **`REVIEW FUNCTIONS HELD`** — an explicit list — and never invites a reader to infer coverage from the number of participants. The Author may never satisfy any review function, and a required function may never silently go unheld: it is held, or the unit returns `HOLD` + `AGENT-CAPABILITY-GAP` ([[DEC-0037]] D6).

### D10 — Role, execution instance and technical principal in a result

[[DEC-0039]] D1 is consumed unchanged:

```txt
LOGICAL ROLE  ≠  EXECUTION INSTANCE  ≠  TECHNICAL PRINCIPAL
```

A result **may** distinguish all three, and **must** where the distinction is load-bearing for a claim it makes. The rules that govern how:

1. **Role is always stated**, as one of [[DEC-0037]] D1's seven actors. A task-scoped role is named as a task-scoped role and **never** labelled with a registered agent's name ([[DEC-0037]] D2, D3; [[DEC-0039]] D9 item 1).
2. **Instance is stated where the environment makes one identifiable**, and otherwise `UNKNOWN`.
3. **Principal is stated only where it is load-bearing and actually known.** Where it is not, the entry is `UNKNOWN` — which is a **required outcome, not a gap to fill by assumption** ([[DEC-0039]] D2). **Identity is never invented to complete a field.**
4. **Independence type is stated with the exact permitted label.** In this environment, where an Author and a distinct Reviewer both act as Principal A, the only permitted label is `PROCESS-INDEPENDENT · PRINCIPAL-NOT-INDEPENDENT` ([[DEC-0039]] D6). Both halves are load-bearing and neither may be dropped.
5. **Principal separation is never inferred from instance separation.** Two distinct subagent instances are two instances, not two principals ([[DEC-0039]] D6, D7; [[DEC-0037]] D7.7). **Role scoping is an authorization boundary, not a technical capability sandbox**, and must never be described as sandboxing ([[DEC-0039]] D7).
6. **No field of any result proves Product-Lead identity.** `HASHING IS NOT ATTESTATION` ([[DEC-0038]] §13). A result may carry a *claimed* logical role, a *known* principal and a provenance *classification*; it may never represent any of these as authenticated. Approver provenance remains [[DEC-0039]] D9's, answered there as `TECHNICAL APPROVER-PROVENANCE = NOT CURRENTLY SEPARABLE FROM SINGLE PRINCIPAL`. **`C4` provisions no principal and does not reopen that question.**

### D11 — The `ROLE RESULT` — what one participant returns

The smallest useful core. An Author or a Reviewer returns this to the Product Orchestrator; it is **one participant's contribution**, never a unit outcome.

> **`AUTHOR PASS = REPORTED, NOT ACCEPTED`.**
> An Author's result carries **no Axis-C value and no Axis-D value.** It reports what it did and what it claims; the unit's disposition and the artifact's verdict are produced by parties that are not the Author. **An Author that states a unit disposition has overstepped, and the statement is void.**

| # | Item | Required? |
|---|---|---|
| 1 | **`UNIT / TASK ID`** | always |
| 2 | **`LOGICAL ROLE`** — one of [[DEC-0037]] D1's seven, named as task-scoped where it is (D10.1) | always |
| 3 | **`EXECUTION INSTANCE`** — where identifiable; otherwise `UNKNOWN` | always, value may be `UNKNOWN` |
| 4 | **`TECHNICAL PRINCIPAL`** — only where load-bearing and actually known; otherwise `UNKNOWN` (D10.3) | conditional |
| 5 | **`EXECUTION STATE`** — Axis A (D2) | always |
| 6 | **`SUMMARY`** — concise, honest, no self-certification | always |
| 7 | **`ARTIFACTS / EFFECTS`** — what was produced, with exact paths | where any exist |
| 8 | **`EVIDENCE PRODUCED`** — each load-bearing claim carrying its Axis-B class (D3) | where any load-bearing claim is made |
| 9 | **`FINDINGS / ERRORS`** — including any breach the participant recognized in itself | where any exist |
| 10 | **`REVIEW TARGET` · `REVIEW FUNCTIONS HELD` · `ROLE VERDICT`** — Axis D, scoped per D9 | reviewer roles only; **omitted for an Author** |
| 11 | **`MUTATION ACCOUNTING`** — per D13 | any role holding a write scope or able to cause a side effect; a read-only role states `ZERO MUTATION` **with the basis on which it knows** |
| 12 | **`NEXT RECOMMENDATION`** — Axis F; a recommendation, never authorization (D8) | optional |

**A participant that cannot complete an item states why, rather than omitting it silently.** Silence about a required item is itself a finding.

### D12 — The `GOVERNED UNIT CLOSEOUT CONTRACT` — what a unit returns to the Product Lead

One contract, for every ordinary governed unit, after the required Author and reviewer rounds.

> **This replaces the practice of inventing a bespoke 40-to-60-field return contract per unit.** A unit writ **MAY** add domain-required fields; it **MUST NOT** redefine, rename, merge or reorder the axes of D1, and it **MUST NOT** require a field that has no referent in the unit.

**Mandatory core — fourteen items.**

| # | Item |
|---|---|
| 1 | **`UNIT ID`** |
| 2 | **`CANONICAL BASE`** and the authority the unit worked from |
| 3 | **`PRODUCT-LEAD AUTHORIZATION`** and the **current gate** |
| 4 | **`TOPOLOGY ACTUALLY USED`** — not the topology required in the abstract, the one actually instantiated |
| 5 | **`PARTICIPANTS AND ROLES`**, with `REVIEW FUNCTIONS HELD` (D9) and independence type (D10.4) |
| 6 | **`UNIT GOVERNANCE DISPOSITION`** — Axis C (D4) |
| 7 | **`ARTIFACT VERDICT(S)`** — Axis D, scoped per review function (D6, D9) |
| 8 | **`EVIDENCE / LOAD-BEARING FINDINGS`**, each with its Axis-B class (D3) |
| 9 | **`GOVERNANCE FINDINGS`** and their lifecycle — Axis E (D7) |
| 10 | **`MUTATION ACCOUNTING`** (D13) |
| 11 | **`REMAINING UNKNOWNS / AUTHORITY GAPS`** — including every `UNKNOWN` recorded under D10 |
| 12 | **`ARTIFACT / PR / LANDING STATE`** |
| 13 | **`RECOMMENDED NEXT CANDIDATE`** — Axis F (D8) |
| 14 | **`EXACT NEXT`** — the precise next action, and by whom |

**The omission rule, stated so completeness is not confused with ceremony.**

> **An item with no referent in the unit is OMITTED. It is not filled with `N/A`, not padded, not invented, and not answered by restating the question.** An omission carries meaning: it says *this unit had no such thing*.

**Six items may never be omitted, whatever the unit did:** **1** Unit ID · **2** canonical base · **3** authorization and gate · **6** unit disposition · **10** mutation accounting · **14** exact `NEXT`. Every other item is omitted where it has no referent — a unit with no artifact omits **7** and **12**; a unit with no governance finding omits **9**; a unit with nothing unknown omits **11**.

**A closeout is a proposal for ratification, never a ratification** (D18).

### D13 — Mutation accounting

`C0` and `C3` established, by two independent breaches, that **repository-shaped accounting does not cover the shapes breaches actually take**.

> **`OUTSIDE REPOSITORY ≠ OUTSIDE write_scope`.**
> **A clean `git status` is NOT a `ZERO MUTATION` proof.** It is evidence about tracked repository content and nothing else — it says nothing about ignored files, files outside the repository, session scratch space, memory, or external systems. **A `ZERO MUTATION` claim must name the checks that support it**, and a claim resting on `git status` alone is `UNPROVEN`, not `ZERO`.

**Surfaces the accounting must cover**, wherever the unit could reach them: repository files · branches · commits · pushes · pull requests · refs, tags, worktrees and stash entries · temp, cache, sidecar and backup files · `/tmp` and any system temp directory · session scratchpad directories · **project and session memory files of any kind** · any other out-of-repository file · and external mutable systems — GitHub configuration, workflows, Environments, secrets, databases, cloud resources.

**Four classes, and every observed write falls into exactly one.**

| Class | Meaning | Consequence |
|---|---|---|
| **`AUTHORIZED MUTATION`** | inside the unit's declared `write_scope` | none; it is reported |
| **`UNAUTHORIZED MUTATION`** | outside it, whether intentional or not | **`UNIT RED`** (D5) |
| **`HARNESS / SYSTEM PERSISTENCE OUTSIDE AGENT CONTROL`** | a write the execution environment performs that the participant did not choose and could not prevent | reported, never concealed; **never a cover for a deliberate write**, and a participant that could have avoided it by working differently must say so |
| **`UNKNOWN MUTATION STATE`** | the participant cannot establish whether a write occurred | **`UNIT HOLD`** (D4) — never resolved by assuming none |

**Cleanup is never retroactive authorization.**

> Deleting an unauthorized artifact is a **second** unauthorized act. It destroys the evidence of the first and **compounds the breach** — which is precisely what happened in `C0`, where the deletion was itself part of the finding ([[DEC-0037]] header).

On recognizing a breach the participant **stops the unit, preserves available evidence, does not self-repair, and reports it completely** (`product-orchestrator-agent.md` §*Governance breach*). Remediation is a separate, authorized task held by an independent function (D7).

### D14 — Breach / artifact separation: eight conditions, no automatic outcome

A technically accepted artifact **MAY** survive a historical unit `RED` — and only when **all eight** hold. This codifies what `C0` and `C3` demonstrated; it invents nothing.

1. **The breach is explicitly recorded** — what was done, when it was recognized, and what evidence survived.
2. **The unit `RED` is preserved historically** and is never rewritten (D7).
3. **The breach did not materially contaminate the artifact or the evidence relied upon.** This is a finding to be established, not an assumption — and where it cannot be established, it is `HOLD`, never `PASS`.
4. **Independent artifact review exists** — a distinct non-Author reviewer, satisfying [[DEC-0037]] D7's six criteria.
5. **Independent governance adjudication exists** where required, held by a party that is not the one that caused the breach (D7).
6. **The current governance finding is `CLOSED — REMEDIATED`**, or is otherwise explicitly adjudicated by the Product Lead.
7. **The Product Lead explicitly accepts the unit/artifact separation** — expressly, in the record, not by silence and not by proceeding.
8. **The Product Lead separately ratifies or merges the artifact** where applicable (D18). Condition 7 is not condition 8; accepting a separation is not accepting an artifact.

> **No automatic salvage.** Failing any condition leaves the artifact unaccepted; the default is not rescue.
> **No automatic rejection.** An artifact is not rejected *merely* because the unit's conduct was `RED`; contamination must be shown, not presumed.
> **No rewriting `RED` to `PASS`**, under any combination of the eight.

### D15 — Evidence-reference durability

A reference that a decision leans on must survive ordinary editing of the file it points into.

**Required form.** A load-bearing reference identifies its target by **(i)** the stable document path, **(ii)** a stable named anchor — a section heading, a decision id such as `D5`, a numbered item, or a named invariant — and **(iii)** a short verbatim quotation wherever the exact clause is what the argument turns on.

**Line numbers are `LOCATOR / CONVENIENCE` only.** They may accompany the above and are useful for finding a clause quickly. **A line number is never the sole semantic identity of an authority**, and a reference consisting only of a path and a number is malformed for load-bearing use.

**How to read a landed citation whose number has drifted.**

> **The quoted text and the named clause govern. The number is a stale locator, not an authority defect.**

A drifted locator does **not** weaken, reopen or invalidate the citing record; it is **not** a `STATE-AUTHORITY DIVERGENCE` ([[DEC-0035]] §4 P4), because no normative requirement and no descriptive claim is in tension — only a pointer moved. **A `FROZEN` record is never edited to repair a locator**, and the cited file is never edited to make an old number true again.

Where a citing record supplies **no** quotation and **no** named anchor, and the number no longer resolves to the proposition it was cited for, the reference is **`UNRESOLVED — LOCATOR ONLY`**: it is reported and escalated, and repaired at the **citing** end by a later authorized unit, never by editing either endpoint to fit.

**This rule creates no general citation framework** and imposes no retroactive obligation: no existing record is required to be re-cited, and §7 repairs nothing in any `FROZEN` record. A mechanical staleness check is routed to `C5` (§9).

### D16 — `AgentResult` / `result-schema.ts`: **OPTION B — legacy transport projection, non-authoritative**

> **`packages/orchestrator/src/core/result-schema.ts` and the `AgentResult` envelope are `NON-AUTHORITATIVE LEGACY`.** The envelope is a **partial transport projection** of a `ROLE RESULT` (D11): it can carry a fragment of one participant's contribution, and it **cannot express a unit disposition, an artifact verdict, an evidence class, a finding lifecycle, mutation accounting, review functions held, or the role / instance / principal separation**. **It is not the governance result contract, and no unit satisfies this record by returning it.**

**Why B and not A or C**, on the evidence of §8: the envelope is not merely *insufficient* — it is **mis-shaped for the current actor taxonomy**, because its required `agent: string` field asserts a registered agent identity that [[DEC-0037]] D2/D3 forbid a task-scoped role from claiming. Retaining it as a neutral *transport envelope* (option A) would understate that; discarding the observation entirely (option C) would lose a mapping a future unit may need. **B states exactly what it can and cannot carry, and stops there.**

**Consequences.**

- The envelope sits inside the control plane [[DEC-0038]] D1 reduced to **NON-AUTHORITATIVE legacy**. [[DEC-0038]] D2 declined to retain it as a `C2` candidate primitive; **this record does not retain it either.** No adoption, no promotion, no obligation on any future unit.
- **Zero code action**, carrying [[DEC-0038]] D3's discipline forward: **no file under `packages/orchestrator/**` is created, deleted, moved, renamed, edited or emptied**, nothing from `151fb46` is ported, and **no `AgentResult` V2 is written in TypeScript**. The `ROLE RESULT` of D11 is a **process contract in prose**, which is what a runtime-agnostic topology requires (E6).
- **Where the two meet.** A future authorized unit that wants a machine-readable result may use the mapping in §8 as evidence of what a projection can and cannot carry. It would need its own explicit Product-Lead GO, and it may not cite this record as authorization.
- **Removal is not implied.** Should the Product Lead later want this surface deleted, that is a separate authorized unit ([[DEC-0038]] §16).

### D17 — `OrchestratorDecision`, `ROLE RESULT` and `GOVERNED UNIT CLOSEOUT` are three different artifacts

They are produced by different parties, at different moments, for different readers, and **must not be conflated**.

| Artifact | Produced by | For | Answers |
|---|---|---|---|
| **`OrchestratorDecision`** | the Product Orchestrator | the routing loop | *What is the next control action?* — `delegate_task` · `request_human_approval` · `escalate` · `no_action` |
| **`ROLE RESULT`** (D11) | one participant | the Product Orchestrator | *What did this participant contribute, and how well is it established?* |
| **`GOVERNED UNIT CLOSEOUT`** (D12) | the unit, consolidated | the **Product Lead** | *What is the unit's disposition, and what is being asked of the Product Lead?* |

**The existing `OrchestratorDecision` contract is preserved intact and unchanged.** Its four decision types keep their meanings, `TaskCommand` is not redesigned, and the `payload` governance fields are untouched. **No conflict was found**, and the boundary is stated because the two contracts are complementary rather than competing: `TaskCommand.payload` carries the **authorization** side of a unit — `role`, `gate`, `review_target`, `independence_from`, `read_scope`, `write_scope`, `prohibited_actions`, `evidence_contract`, `hold_conditions`, `red_conditions` — and D11/D12 carry the **accounting** side of the same unit. `write_scope` is declared there and accounted for here (D13). One authorizes; one reports. Neither replaces the other, and **a routing decision is never a closeout**.

`product-orchestrator-agent.md` §*Output Format* carries one new `###` subsection recording this table and nothing more — declared at §11, the §*Output Format* row, and counted in the header's seven reconciliation points.

### D18 — Product-Lead ratification semantics

> **A closeout is a PROPOSAL FOR RATIFICATION. It ratifies nothing.**

Ratification is the Product Lead's **manual merge** ([[DEC-0037]] D11), and it is the only instrument that ratifies. On receiving a closeout the Product Lead may: ratify · `HOLD` · reject · request changes · accept an artifact while preserving a historical unit `RED` under D14 · or decline that separation. **All six are available, and the closeout must not be written as though only the first is.**

Three limits:

1. **`PRODUCT-LEAD ACCEPTANCE ≠ ANY REVIEWER PASS`.** No number of reviewer `PASS` verdicts produces acceptance; only the Product Lead moves a claim to Axis-B `ACCEPTED` ([[DEC-0039]] D4; [[DEC-0037]] D10).
2. **Ratifying a record ratifies the record.** It does not convert unit conduct to `PASS`, does not close a governance finding that has not been separately adjudicated, and confers nothing on any other unit.
3. **Ratification is not retroactive.** A landed record governs work commenced after it lands, and **a record does not ratify itself** ([[DEC-0037]] §10; [[DEC-0038]] §17; [[DEC-0039]] §13).

**Represented accurately, the merge gate is a PROCESS / AUTHORITY GATE, not mechanically-enforced independent review** ([[DEC-0037]] D12; [[DEC-0039]] D10, F4a `ACCEPTED CURRENT LIMITATION`). No closeout may describe it as mechanical (D10.6).

---

## 5. The six axes, read together

One unit, six answers, none derivable from another:

```txt
AXIS A  EXECUTION STATE        completed | failed | needs_review | blocked
AXIS B  EVIDENCE CLASS         REPORTED | VERIFIED | ACCEPTED | UNPROVEN     (per claim)
AXIS C  UNIT DISPOSITION       PASS | HOLD | RED
AXIS D  ARTIFACT VERDICT       PASS | HOLD | RED | (omitted)                 (per review function)
AXIS E  FINDING LIFECYCLE      OPEN | CLOSED — REMEDIATED
AXIS F  NEXT / AUTHORIZATION   NEXT CANDIDATE  ·  PRODUCT-LEAD GO            (separate instruments)
```

**The reading order that avoids every collapse this record exists to prevent:** Axis A is transport and settles nothing. Axis B is per claim and settles nothing about the unit. Axis C is the unit's conduct. Axis D is the artifact's quality. Axis E is the current remediation state of a finding, and moving it never edits history. Axis F recommends, and only a Product-Lead GO authorizes.

---

## 6. Worked proof cases — Phase C in six axes

**Read-only illustration.** These rows **assert nothing new about any unit**, rewrite nothing, and re-adjudicate nothing. They exist to demonstrate that the axes express the outcomes NOXUND has actually had. **`C4` is not a history-cleanup unit** — every value below is transcribed from a landed record at this base, and where the record is silent the cell says so.

| Unit | A | C — unit | D — artifact | E — finding | Source |
|---|---|---|---|---|---|
| `C0` — foundation assessment (unlanded; no file on `main`) | `completed` | **`RED`** — verified authorization breach, blast radius `LOW · ZERO REPOSITORY IMPACT` | *(no landed artifact; axis omitted)* | **`CLOSED — REMEDIATED`**, historical `RED` **not** rewritten | [[DEC-0037]] header |
| `C1` — execution topology | `completed` | `PASS` | `PASS` → [[DEC-0037]] landed | *(none recorded)* | [[DEC-0037]]; `current-state.md` §B |
| `C2` — `packages/orchestrator` disposition | `completed` | `PASS` | `PASS` → [[DEC-0038]] landed, **REDUCE** | *(none recorded)* | [[DEC-0038]]; `current-state.md` §B |
| `C3` — capability / principal model | `completed` | **`RED`** — unauthorized out-of-repository `MEMORY.md` write, outside the `C3` write scope | **`PASS`** — independent technical review, completed read-only **before** that action, on an artifact it could not reach | **`CLOSED — REMEDIATED`**; Product Lead **explicitly accepted the unit/artifact separation** | [[DEC-0039]] header |
| [[DEC-0039]] as artifact | — | — | `PASS`, **landed authority** | — | [[DEC-0039]] header; `context-map.md` §2 |

**What the table demonstrates.** Row `C3` is the D6 case — `UNIT = RED` beside `ARTIFACT = PASS` — and it is not an anomaly to be explained away but a correctly-reported outcome that a one-axis vocabulary cannot state at all. Row `C0` shows Axis E moving while Axis C stands still, which is D7. **Both are landed facts, and this record is what makes them sayable in one line instead of a paragraph.**

**One honest limit on this table, disclosed rather than smoothed.** The `C4` writ referred to a *second* `C3` historical `RED` arising from a reconciliation round. **The repository at this base records exactly one `C3` `RED`** — the `MEMORY.md` write, in the [[DEC-0039]] header, `current-state.md` §B and `context-map.md` §2. This record therefore **asserts one**, and the `C3` row is written so that it holds whether the unit incurred one such finding or more. Nothing here denies a second; it is simply **not established by the repository**, and inventing it would be exactly the failure D3 forbids (§15 weak point 3).

---

## 7. Evidence-reference durability — the verified drift finding

**Re-derived by this unit at two bases**, and cited as this unit's finding.

`C2`'s reconciliation inserted a two-line note near the top of `docs/agents/product-orchestrator-agent.md` — the file goes from **857 lines** at `aff75d51` to **859 lines** at this base — **shifting every subsequent line by exactly +2**. That single minimal, correct, well-executed edit silently invalidated **every line-number citation into that file across the entire landed corpus**.

| Citing record | Cites | Proposition now at | Consequence at this base |
|---|---|---|---|
| [[DEC-0037]] header | `:598`, `:599` | `:600`, `:601` | **`:598` / `:599` now resolve to *different* clauses** — *"operação sensível requer `requires_human_approval=true`"* and *"evidência incompleta = HOLD"* |
| [[DEC-0037]] evidence base · D5 | `:562`, `:563`, `:564`, `:565` | `:564` … `:567` | **`:565` — the clause D5's whole argument turns on** (*"qualquer exceção à separação de funções…"*) — now resolves to *"o governance reviewer de uma operação não deve ser o executor da mesma operação"* |
| [[DEC-0035]] §9 reading note | `:128` | `:130` | `:128` now resolves to the `## Source of Truth` heading |
| [[DEC-0036]] §Scope, §2, D2 | `:167` | `:169` | `:167` now resolves to the `WTP` scope bullet — **rescued: D2 quotes it twice** |
| [[DEC-0036]] evidence base · **D2's *a fortiori* argument** | `:40`, `:128`, `:152–167`, `:384`, `:790` | `:42`, `:130`, `:154–169`, `:386`, `:792` | **The worst case in this table.** D2 cites *"lines 40, 128, 384 and 790"* as the same *find-the-full-version-here* idiom. **Only `:40` carries a quotation** (*"segue o protocolo completo em `agent-onboarding-orchestration.md`"*) and is rescued. **`:128`, `:384` and `:790` are bare numbers with no quotation and no named anchor**, and now resolve to the `## Source of Truth` heading, the `## Agent Interaction Model` heading, and *"não ocultar `HOLD`, `RED`, dissent ou evidência ausente…"* — **none of which is the idiom the argument rests on**. Classified **`UNRESOLVED — LOCATOR ONLY`** (D15) and escalated below |
| `task-context-pack.md` **§6 *Routed here, not solved here*** | `:167` | `:169` | same drift; **EDITABLE, outside this unit's write scope — routed, not repaired** (§11) |
| [[DEC-0038]] §14 | `:726` | `:726` | **correct here** — but at [[DEC-0038]]'s own declared canonical base `45667387` that clause sat at `:724`. The citation indexes the file *after* its own repair. **Not a defect** — and it shows a bare number does not even say *which base* it indexes |
| [[DEC-0039]] header, §6.2 | `:399`, `:600`, `:601`, `:686` | unchanged | correct at this base |
| `current-state.md` §B · `context-map.md` §2 | `:600–:601` | unchanged | correct at this base |

**The classification, applied rather than asserted.** Under D15 every drifted row above is a **stale locator, not an authority defect**. [[DEC-0037]], [[DEC-0035]] and [[DEC-0036]] are all **`FROZEN` and are not edited**. **Most rows are rescued by quotation** — the quoted text and the named clause govern, and the reference resolves.

**Four are not, and they are reported here rather than left to be found.**

> **`UNRESOLVED — LOCATOR ONLY` (D15) — escalated to the Product Lead, repaired by nothing here.**
> **[[DEC-0036]] D2 `:128`, `:384`, `:790`** — three bare numbers carrying the *a fortiori* limb of D2's argument, none quoted, none anchored, all now resolving to the wrong content.
> **[[DEC-0037]] evidence-base header `:565`** — cited *with* its quotation in D5's body, but **bare in the header**, where `:565` now resolves to a different clause.

**Why this unit reports rather than repairs.** D15 directs repair at the **citing** end — and here **both citing records are `FROZEN`**, so this unit cannot perform it. Two venues exist and **choosing between them is the Product Lead's, not this record's**: an **additive forward note** on each citing record, which [[DEC-0035]] §3.3 permits for `FROZEN`-but-not-byte-frozen records under a separate authorization; or the **`C5` mechanical staleness check** (§9 item 5). **`C4` does neither** — it reports and escalates, which is exactly what D15 requires of the class. **Stated plainly: this is a live residual, not a closed one**, and the round-1 draft of this record asserted only one exposed case where there are four (§15 weak point 4).

**What this unit did about it, so the rule is demonstrated and not merely written.**

> **Every edit this unit makes to `product-orchestrator-agent.md` at or above line `:686` is LINE-COUNT NEUTRAL** — text is replaced in place, never inserted — **and every line this unit adds sits below `:686`.** Measured, and stated as the measurement rather than as a rounder claim: the file is **859 lines at the canonical base and 881 after this unit — `+22`, all of them below `:686`**, in §*Output Format* (`+12`, D17's boundary subsection, first inserted line `:758`) and §*Operational Invariants Summary* (`+10`). Consequently **every citation that resolves correctly at this base still resolves after this unit lands**: [[DEC-0039]]'s `:399` / `:600` / `:601` / `:686` in a `FROZEN` record and the `:600–:601` references in `current-state.md` and `context-map.md` are all above the first insertion point and are **unmoved**, and [[DEC-0038]] §14's `:726` is below `:686` but **above `:758`** and is therefore also unmoved. **One already-broken citation moves further and none that worked breaks:** [[DEC-0036]]'s `:790` shifts to `:792`, and it did not resolve at this base either way (table row 5). **This unit introduces zero new drift**, and that is checkable by measurement rather than by trust — `wc -l` at both commits, and the four anchors re-read.

A mechanical staleness check is routed to `C5` (§9). **No general citation framework is created, and no existing record is required to be re-cited.**

---

## 8. `AgentResult` / `result-schema.ts` — the analysis behind D16

Read at this base: `{ task_id, agent, status, summary, artifacts[], errors[], next_recommendation }`, `status ∈ { completed, failed, needs_review, blocked }`, with `validateResultShape` requiring `task_id`, `agent` and `summary` to be strings, `status` to be one of the four, and `artifacts` and `errors` to be arrays.

**What it can project of a `ROLE RESULT` (D11).**

| Envelope field | `ROLE RESULT` item | Fidelity |
|---|---|---|
| `task_id` | 1 — unit / task id | full |
| `agent` | 2 — logical role | **corrupted, see below** |
| `status` | 5 — execution state (Axis A) | full |
| `summary` | 6 — summary | full |
| `artifacts[]` | 7 — artifacts / effects | partial — no write-scope accounting |
| `errors[]` | 9 — findings / errors | partial — no breach semantics, no severity axis |
| `next_recommendation` | 12 — next recommendation | partial — carries no `NEXT ≠ GO` marking |

**What it structurally cannot express, at all.** Item 3 execution instance · item 4 technical principal · item 8 evidence class per claim (**Axis B is entirely absent**) · item 10 review target, review functions held and role verdict (**Axis D is entirely absent**) · item 11 mutation accounting · the unit governance disposition (**Axis C**) · the governance finding lifecycle (**Axis E**) · the authorizing GO · the write scope actually touched · reviewer independence type. **Six of D12's fourteen closeout items and four of the six axes have no field and no place to go.**

**The decisive defect is not absence, it is mis-shape.** `agent: string` is **required** — `validateResultShape` rejects a result without it — so **every conforming `AgentResult` asserts a registered agent identity**. [[DEC-0037]] D2 states that *"no result may be labelled with a registered agent's name unless that agent actually produced it"*, and D3 that instantiating a generic subagent *"confers no contract, no boundary, no runtime id and no registry entry"*. A `TASK-SCOPED AUTHOR` — the actor that produces essentially all current governed work ([[DEC-0039]] D7) — therefore **cannot return a valid `AgentResult` without either claiming an identity it does not have or writing a non-identity into a field typed as one**. The envelope does not merely fail to carry the new contract; **it encodes an actor model the corpus has since replaced.**

**Options weighed.**

- **A — retain as a legacy transport envelope.** Correct that it stays on `main` untouched and may have compatibility value; **understates the `agent` finding**, which is a semantic incompatibility rather than a gap.
- **B — legacy transport *projection*, non-authoritative. SELECTED.** States exactly what it can carry, exactly what it cannot, and why it is not merely incomplete. Preserves the mapping above for a future unit that wants it, adopts nothing, and touches no code.
- **C — declare it irrelevant and say nothing.** Discards a mapping produced at real cost, and would leave [[DEC-0038]] §15's *"unconstrained field"* unanswered — which is the routed question this record exists to discharge.

**Nothing follows for the code.** [[DEC-0038]] D3's zero-code-action discipline governs: the file stays exactly as it is, and **no future unit may cite this record as authorization to change or remove it**.

---

## 9. Boundaries — `C3`, `C5`, Phase D and Phase F

**`C3` — approver provenance is not reopened.** [[DEC-0039]] D9's **P3 — HYBRID** governs. A result may carry a *claimed* logical role, a *known* technical principal and a provenance *classification*; **no field of any result proves Product-Lead identity**, and `HASHING IS NOT ATTESTATION` ([[DEC-0038]] §13). **`C4` provisions no principal, selects no trust anchor, and creates no expectation that any future unit will.**

**`C5` — mechanical enforcement candidates, ROUTED AND NOT IMPLEMENTED.** Nothing below is created, prototyped, scheduled or bound to a mechanism, and each requires `C5`'s own explicit Product-Lead GO. **No workflow, ruleset, `CODEOWNERS`, validator, lint, hook, CI check or sandbox is created or proposed for creation here.**

1. **Result-contract validator** — a `ROLE RESULT` (D11) or `GOVERNED UNIT CLOSEOUT` (D12) carries its required items.
2. **Required-field check** — D12's six never-omitted items are present, and omitted items are genuinely referent-free rather than skipped.
3. **Status-axis consistency check** — no compound token (`PASS-WITH-RED` and family); `HOLD` / `RED` not used as an evidence class; an Author result carrying no Axis-C or Axis-D value (D11).
4. **Mutation-accounting check** — every write classified into exactly one D13 class; a `ZERO MUTATION` claim naming its supporting checks rather than resting on `git status`.
5. **Stale reference / citation check** — the D15 residual: detect line-number citations that no longer resolve to the proposition they were cited for (§7).
6. **Detection of scratch, temp and out-of-`write_scope` writes** where technically possible.

**Phase D — not this record.** Documentation-quality standards, testing policy and general code-quality policy are Phase D. `C4` defines what a result **means**, never how good the work behind it must be.

**Phase F — not this record, and expressly constrained by it.** Machine orchestration protocol, autonomous result chaining, automatic `NEXT` execution and persistent agent-state protocol are Phase F. **D8 is a constraint on such work, never an authorization of it:** no status field may auto-authorize a stage, and a Product-Lead GO has no automated substitute.

**Axis-1 — untouched.** Nothing here reaches the product/engineering axis, the database, Supabase, AWS or collection. **Nothing is re-armed** ([[DEC-0033]] §8).

---

## 10. Forward discoverability

[[DEC-0035]] §10 requires the forward-discoverability update to be created **in the same authorized unit** that creates the relation. **Three** edges are created here and are recorded in the relation table at `docs/product/context-map.md` §3:

1. **`DEC-0040 EXTENDS DEC-0037 §9`** — supplying the `C4` limb, as a process contract rather than the schema §9's label anticipated. **[[DEC-0037]] is `FROZEN` and is not edited**; the external table is the mechanism §10 directs for that case.
2. **`DEC-0040 DISCHARGES DEC-0038 D2 · §15`** — by satisfaction: the `result-schema.ts` / `AgentResult` routing, answered at D16. **[[DEC-0038]] is `FROZEN` and is not edited**; its **REDUCE** disposition is neither rewritten nor reopened.
3. **`DEC-0040 DISCHARGES DEC-0039 D14 · §8`** — by satisfaction: the capability and principal metadata `C4` was named to carry, consumed at D10–D12. **[[DEC-0039]] is `FROZEN` and is not edited**; **P3 — HYBRID** is neither rewritten nor reopened.

`docs/agents/product-orchestrator-agent.md` is **EDITABLE** ([[DEC-0035]] §9) and therefore also carries in-file pointers at the reconciled points (§11) — the additive markers §10 permits, never a rewrite of any rule.

**This unit is incomplete without all three rows.**

---

## 11. Reconciliation performed by this unit

Bounded to what this decision makes stale. **Nothing historical is rewritten**, and no file outside the five named below is touched.

**1. `docs/agents/product-orchestrator-agent.md` — seven exact points.** Mutability established first: `docs/agents/**` agent contracts are INTERNAL-NORMATIVE within their declared agent-behaviour scope and **EDITABLE** ([[DEC-0035]] §9).

| Point | Repair |
|---|---|
| §*Operating Protocol* | the result the Product Orchestrator consumes is named as the `ROLE RESULT` contract (D11), with `AgentResult` identified as the **legacy** TypeScript name and **not** the governance contract (D16). One sentence, in place |
| §*Trust model para `AgentResult`* | heading renamed to the role result, keeping the legacy name visible so every other occurrence in the file stays readable; two bullets gain pointers to D2/D9/D11 and D5. **All six trust-model clauses keep their meaning** |
| §*Stage-Gate Discipline* | the historical-finding clause gains a pointer to D7 and D14 — the clauses [[DEC-0039]] relies on, now with a named anchor |
| §*Evidence, Provenance & Review Rules* | **the axis-collapse repair (D3):** the mandatory-classification list is restored to its four evidence classes, and a marked reconciliation note records that `HOLD` and `RED` keep their full force on Axis C and that **nothing is revoked** |
| §*Governance breach* item 3 | conditional `RED` → unconditional, per D5, prospectivity stated |
| §*Operational Invariants Summary* | the breach line becomes `ANY VERIFIED AUTHORIZATION BREACH IN A GOVERNED UNIT => UNIT RED`, with the D1 non-collapse invariant and the D13 accounting invariant added, plus a marked reconciliation note carrying D5's reasoning and prospectivity (`+10` lines) |
| §*Output Format* | **one new `###` subsection** — *"Fronteira: decisão ≠ resultado de papel ≠ closeout de unidade"* — carrying D17's three-artifact table (`+12` lines, first inserted line `:758`). **This is the largest additive block this unit makes to the file and the only new subsection**, and it is named here rather than folded into another row. **It changes nothing it sits beside:** the four `decision_type` values, `TaskCommand` and the `payload` governance fields are untouched, and the block says so in its own text |

**Two disciplines observed while doing it.** *(a)* **The `RED` repair at §*Governance breach* item 3 is not scope creep — it closes a contradiction this unit would itself have created.** Repairing only the invariants summary would have left one INTERNAL-NORMATIVE file asserting both a conditional and an unconditional `RED`. That is exactly the reasoning [[DEC-0038]] §14 applied to its own second repair: *"a defect created by this unit is this unit's to close, not a residual to hand onward"*. *(b)* **Every edit at or above `:686` is line-count neutral, and lines are inserted only below it**, so no currently-resolving citation is broken (§7). **[[DEC-0038]] §14's two reconciliation notes are preserved verbatim.** **No general cleanup is performed**, and the binding limbs, prohibition lists, registry-first model and the whole `OrchestratorDecision` / `TaskCommand` format contract are untouched.

**2. `docs/agents/handoff-template.md`** — `DESCRIPTIVE-CURRENT`, a format aid and **not** a handoff ([[DEC-0035]] §9), and therefore the correct editable surface for applying this contract. Restructured into **`NÚCLEO OBRIGATÓRIO`** / **`SEÇÕES CONDICIONAIS`** / **`EXTENSÕES ESPECÍFICAS DA UNIDADE`**, carrying the `ROLE RESULT` and the `GOVERNED UNIT CLOSEOUT` with the omission rule stated in file. **Kept in Portuguese to match the file, and kept short**: a fresh operator produces a compliant return from it without consulting any past prompt, and without a ceremony template.

**What happened to the file's pre-existing content, stated rather than left to a diff.** The round-1 draft of this unit **replaced the whole eleven-section template**, silently dropping five sections this record does **not** make stale: §3 *Critério de aceite*, §6 *Impacto no escopo* (the MVP scope-lock and non-negotiable questions), §7 *Validação executada*, §8 *Riscos*, and §9 *Revisões necessárias* (the Data/AI · Security · Database/Data Integrity · QA · Product-Lead trigger checklist). **That was a defect in this unit's own reconciliation, and it is corrected here by restoring them as conditional sections** — items 13–15 of the `ROLE RESULT`, and one `### Gates de escopo e revisão cruzada` block in Part 2. **Restoration rather than mere disclosure, on the merits:** `product-orchestrator-agent.md` §*Definition of Done* requires a domain-review determination *"quando a tarefa toca número, banco, auth, segurança, produção, infra ou copy pública"* **and names this template as the vehicle**, so dropping the trigger list opened a gap between a landed INTERNAL-NORMATIVE requirement and the format aid it points at. **Nothing normative was ever at risk** — this file is `DESCRIPTIVE-CURRENT` and grants nothing, and the triggers' actual authority is `agent-review-matrix.md` and `agent-boundaries.md`, which are untouched; the restored block says so in file. **The remaining six sections are deliberately superseded in form**, their content carried by the new cores: §1 *Identificação* → `ROLE RESULT` 1–4 and closeout 1–5; §2 *Objetivo* and §4 *Resultado* → `ROLE RESULT` 5–6; §5 *Arquivos alterados* → items 8 and 11, strengthened by D13's mutation accounting; §10 *Próximos passos* → item 12 and closeout 13–14, now marked `NEXT ≠ GO`; §11 *Open decisions / bloqueios* → closeout 9 and 11.

**3. `docs/product/current-state.md`** and **4. `docs/product/context-map.md`** — reconciled **only** where this unit's own landing changes current truth or routing, each under its own scoped-reverification convention, naming the base and exactly what was and was not re-read.

**Deliberately left alone, and named rather than swept.** `docs/agents/orchestration-runtime.md`; `README.md`; `agent-registry.md`; `agent-boundaries.md`; `agent-review-matrix.md`; `global-agent-rules.md`; `agent-onboarding-orchestration.md`; the ten agent contracts and `orchestration-runtime-engineering-agent.md`; and the corpus-wide historical-normalization residual (`PHASE-B-CLOSEOUT-R1` §5 row 1). **Three residuals this unit newly identifies are routed to the same Product-Lead-authorized reconciliation unit [[DEC-0038]] §14 already established, and are not swept into `C4`:**

**(i)** `docs/product/task-context-pack.md` **§6 *Routed here, not solved here*** — its `:167` citation, drifted by the same `+2` (§7). EDITABLE, but outside this unit's write scope.

**(ii) The surviving `AgentResult` references, counted rather than gestured at.** The file carries **15 occurrences** of the token after this unit's edits. **Two are this unit's own** and name it explicitly as the legacy term (§*Operating Protocol* `:13`; the renamed §*Trust model* heading `:483`). **Thirteen are pre-existing, across eight sections:** §*Operating Protocol* `:35`, `:40` · §*Role* `:60` · §*Agent Registry & Capability-Gap Protocol* `:221`, `:352` · §*Agent Interaction Model* `:453` · §*Stage-Gate Discipline* `:597` · §*Definition of Done* `:672` · §*Escalation Rules* `:717` · §*Output Format* `:774`, `:780`, `:783`, `:786`. Of these, **`:221` is a catalogue row describing a `PROPOSED-NOT-OPERATIONAL` agent's specialization** and is a different kind of reference from the other twelve, which are orchestrator-loop references. **The strongest one is named rather than buried: `:35`, inside the section headed `## Operating Protocol (vinculante)`, still reads *"**consome** `AgentResult` de agentes especializados … para decidir o próximo passo"*.** **This is not a live normative conflict** — the renamed §*Trust model* heading supplies the `AgentResult` → `ROLE RESULT` mapping for the whole file, and D16 settles the envelope's standing — so it is a **terminology residual**, routed on [[DEC-0038]] §14's own precedent of routing rather than sweeping. **The round-1 draft of this record named only two of the eight sections; the full set is stated here.**

**(iii)** The four **`UNRESOLVED — LOCATOR ONLY`** citations of §7 — [[DEC-0036]] D2's `:128`, `:384`, `:790` and [[DEC-0037]]'s header `:565`. **Both citing records are `FROZEN`, so neither this unit nor a documentation-reconciliation unit may repair them in file**; the venue is a Product-Lead decision between an additive forward note ([[DEC-0035]] §3.3) and the `C5` staleness check (§9 item 5). **Reported and escalated, not closed.**

---

## 12. What this record does **not** decide

Named, so silence is not mistaken for an answer.

- **It does not design a machine-readable schema.** No field names, types, cardinalities, JSON shapes or validation rules are specified, and D11/D12 are prose contracts. A future unit that wants a schema needs its own GO.
- **It does not reopen [[DEC-0037]] D5.** One distinct non-Author reviewer may still hold multiple review functions where no landed clause separates them.
- **It does not decide reviewer counts, thresholds or `CODEOWNERS` content** — `C5`'s, exclusively ([[DEC-0037]] §9).
- **It does not solve approver provenance** or select any trust anchor (§9).
- **It does not re-adjudicate `C0`, `C1`, `C2`, `C3` or any earlier unit.** §6 transcribes; it does not decide.
- **It does not repair any citation inside any `FROZEN` record**, and imposes no re-citation duty on the existing corpus (D15).
- **It does not classify, promote or demote any artifact.**
- **It does not decide documentation quality, testing policy or code-quality standards** — Phase D.
- **It does not define orchestration protocol, autonomous chaining or persistent agent state** — Phase F.
- **It does not resolve any Axis-1 technical question**, re-arm anything ([[DEC-0033]] §8), or authorize any unit.

---

## 13. Explicit non-decisions

This record does **not** and must not be read to: create, edit, delete, move, rename, port or adopt any file under `packages/orchestrator/**` · write an `AgentResult` V2 in any language · redesign `TaskCommand` or any `OrchestratorDecision` type · register, wire, activate or promote any agent or capability · edit any agent contract, boundary, registry entry or review-matrix item other than the seven named reconciliation points in `product-orchestrator-agent.md` · create, rotate or delete any GitHub principal, App, bot, service account, token, credential or secret · create or change any ruleset, branch protection, `CODEOWNERS`, reviewer requirement, Environment, variable or repository setting · create, modify, register or dispatch any workflow, CI check, validator, lint or hook · implement any `C5` control · connect to any database or Supabase resource · call any cloud API or provision any resource · arm or re-arm any collection path ([[DEC-0033]] §8) · mutate any preserved ref, branch, stash or archive · create any scratch, temp, sidecar, cache, backup or memory artifact · change product scope, MVP admission or any `OD-*` item · resolve the successor PostgreSQL architecture or any Axis-1 technical question · define improvement Phase D, E or F · edit, supersede or reinterpret [[DEC-0035]], [[DEC-0037]], [[DEC-0038]], [[DEC-0039]] or any prior DEC · rewrite any historical artifact or disposition · authorize `C5`, or any commit, push, PR, merge or execution of any kind.

---

## 14. Effective and landing semantics

**In force from the Product Lead's manual merge of this record**, and prospective from that moment. Specifically:

- it governs governed work **commenced after landing**;
- it **does not retroactively validate or invalidate any earlier unit**, including its own production, which stands on the `C4` GO and on nothing in this record — **a record does not ratify itself**. **D5's unconditional breach invariant is prospective in the strictest sense: no past disposition is re-examined, upgraded or downgraded on its authority**;
- it creates **no standing permission**: every unit still requires its own explicit Product-Lead GO ([[DEC-0035]] §6). **Landing this record authorizes nothing further** — not `C5`, not any schema, not any validator, and no Axis-1 resumption;
- it is **FROZEN** ([[DEC-0035]] §9): its body is never rewritten, a change to this contract requires a **later landed record**, and no GO, handoff, closeout or memory may amend it ([[DEC-0035]] §5, §6);
- **it is enforced by nothing mechanical.** Every rule here is process, held by role separation, independent review and the Product-Lead gate. Mechanical enforcement is `C5`'s, under its own GO (§9);
- imperative wording in any EVIDENCE artifact describing this contract creates no obligation beyond what this record states ([[DEC-0035]] §3.1).

---

## 15. Known weak points, disclosed by the Author

Stated so the record is honest about its own limits rather than leaving them to be found.

1. **This contract is unenforced, and the unenforced version is the one that has historically failed.** Every rule here depends on participants writing honestly and on a reviewer checking. **`F6` — paper governance that is never the system in use** ([[DEC-0038]] §10) is the live risk against this very record, and `C4` cannot close it: mechanical enforcement is `C5`'s and requires its own GO. The mitigation is real but partial — the contract is now *checkable*, which is a precondition for enforcement rather than a substitute for it.
2. **The D5 change is prospective, so the asymmetry it fixes remains readable in the history.** A reader comparing `C0`'s and `C3`'s writs against the new invariant will find the old conditional form. That is correct and deliberate — rewriting history to match a new rule is precisely what D7 forbids — but it means the corpus permanently contains two forms of the same invariant, distinguished only by date.
3. **§6's `C3` row asserts one historical `RED` because the repository records one.** The `C4` writ referred to a second, from a reconciliation round. **This unit did not find it on `main` and does not assert it.** If a second finding exists in Product-Lead records that did not land, this table is incomplete rather than wrong — and the row is phrased to survive either way. **The Product Lead should confirm.**
4. **The line-count-neutral edit discipline (§7) is a convention this unit chose, not a landed rule, and nothing enforces it on the next unit.** The very next edit to `product-orchestrator-agent.md` can break every citation again. D15 makes such breakage harmless *where a quotation exists*; **it does nothing for a bare-number citation, and there are four already broken** — [[DEC-0036]] D2's `:128`, `:384` and `:790`, and [[DEC-0037]]'s evidence-base `:565` (§7). **Both citing records are `FROZEN`, so D15's "repair at the citing end" has no available performer**, which is a real gap in D15 rather than an oversight in those records: the rule assumes an editable citing surface and this corpus's most-cited surfaces are frozen. The two candidate venues — an additive forward note ([[DEC-0035]] §3.3) or the **`C5` staleness check (§9 item 5)** — are both **routed and not built**, and choosing between them is the Product Lead's.
5. **D12's fourteen-item core is a judgment, and a judgment about a small sample.** It was derived from four Phase-C units, all docs-only, all Axis 2. A code, migration or infrastructure unit may find the core under-specified — most plausibly around validation evidence and rollback state. **The extension mechanism exists for exactly that** (unit-specific extensions), but the core has not been tested against a mutating-code unit and this record does not pretend otherwise.
6. **D13 cannot make an agent omniscient about its own side effects.** A participant reports what it can observe. Where the execution environment writes on its behalf, the honest classification is `HARNESS / SYSTEM PERSISTENCE OUTSIDE AGENT CONTROL`, and **that class is the most abusable thing in this record** — it is the one place where a deliberate write could be misfiled as unavoidable. The check is a reviewer's judgment, and it is weak.
7. **The `AgentResult` mapping in §8 may age badly.** It describes a file inside a control plane [[DEC-0038]] reduced to legacy and that nothing runs. If that file is ever deleted under a separate authorization, §8 becomes a description of something absent — **harmless, because D16 adopts nothing from it, but stale**.

---

*Related: [[DEC-0037]] D1 (actor taxonomy, consumed unchanged), D5/D6 (topology; review functions not headcount), D7 (checkable independence), D8 (the governance-review function), D10 (the Product Orchestrator accepts nothing), D11 (GO versus merge), D12 (F4a / F4b; process ≠ mechanical independence), §9 (the `C4` reservation this record supplies), §10 (landing semantics); [[DEC-0038]] D1–D3 (`REDUCE`; the retained/legacy inventory; zero code action), D2 and §15 (the `result-schema.ts` routing this record discharges), §13 (`IDENTITY ≠ CONSUMPTION ≠ PROVENANCE`; hashing is not attestation), §14 (the reconciliation precedent applied at §11), §18 (disclosed weak points); [[DEC-0039]] D1 (`ROLE ≠ INSTANCE ≠ PRINCIPAL`), D2 (`UNKNOWN` as a required outcome), D4 (Product-Lead-only actions are process-reserved, not technically isolated), D6 (`PROCESS-INDEPENDENT · PRINCIPAL-NOT-INDEPENDENT`), D7 (role scoping is not a sandbox), D9 (**P3 — HYBRID**; the naming prohibition), D14 and §8 (the `C4` metadata assignment this record discharges); [[DEC-0036]] §4 (adjudication without supersession); [[DEC-0035]] §3.1 (imperative wording confers no class), §4 P3/P4 (conflict versus divergence), §6 (GO versus durable authority), §7 and §9 (fail-closed classification; family defaults; `handoff-template.md` is a format aid), §10 (forward discoverability), §12 (Phase-C boundary); [[DEC-0033]] §8 (unlanded identifiers; nothing re-arms). Agent surfaces reconciled: [`product-orchestrator-agent.md`](../../agents/product-orchestrator-agent.md), [`handoff-template.md`](../../agents/handoff-template.md). Agent surfaces read and **not edited**: [`README.md`](../../agents/README.md), [`agent-registry.md`](../../agents/agent-registry.md), [`agent-review-matrix.md`](../../agents/agent-review-matrix.md), [`agent-conflict-resolution.md`](../../agents/agent-conflict-resolution.md). Routing surfaces reconciled: [`current-state.md`](../current-state.md), [`context-map.md`](../context-map.md). Code surfaces read and **not edited**: `packages/orchestrator/src/core/result-schema.ts`, `src/core/decision-schema.ts`.*
