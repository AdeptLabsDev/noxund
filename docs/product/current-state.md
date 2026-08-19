# NOXUND — Compact Current State

**Authority class:** DESCRIPTIVE-CURRENT · **Lifecycle:** CURRENT · **Mutability:** EDITABLE
**This is not a decision record; it creates no authority.** It does two things: report current reality and route to authority. Ambiguity about classification, precedence or supersession is governed by `DEC-0035` (§I).

**Freshness contract.** LAST VERIFIED AGAINST CANONICAL MAIN = `a11bd169702e1539432ebf8ac140b296ba5fe29b`, verification date **2026-08-17**. If `origin/main` advances past that SHA, this document is **STALE-UNTIL-REVERIFIED** for current-state purposes — which does **not** mean every merge changes its content: reverification may conclude **NO CONTENT CHANGE REQUIRED**, updating only this metadata under an authorized maintenance unit. **The SHA is freshness provenance, not normative authority.**

**Reading convention.** `State:` = factually true now. `Authority:` = what a landed normative record requires. Never merged; a fact is never rewritten to fit a rule.

---

## A. Product identity — locked MVP

**State:** the MVP is the **Hotspot Artists Report**, a closed manual-assisted validation product on real data — **not** a marketplace. Initial vertical **Chicago Drill**; locked keyword `chicago drill type beat`. Locked cardinalities: **two fixed reports**, **10 artists each**, **2 `HOT` each**, **30-day window**, **~500 videos per collection run**.

**Authority:** numbers are deterministic — generative AI never produces Score, Velocity, Signals, Competition, ranking or Example; raw YouTube API data is immutable and never overwritten; computed is reconstructible from raw; deliveries are traceable. Sources: [`docs/agents/README.md`](../agents/README.md) §*Regras gerais* 2–4 (INTERNAL-NORMATIVE, `DEC-0035` §9) and `context/03_Data_AI_Agents_Methodology.md`.

Full scope and thresholds: [`01_MVP_Scope_PRD.md`](../../context/01_MVP_Scope_PRD.md).

---

## B. Two axes — do not conflate them

NOXUND runs on **two distinct axes**. The A–F ladder is only the second, and it is **not** NOXUND's development lifecycle.

### Axis 1 — product / engineering trajectory

**State:** the substantive product-build work. It **predates** the A–F program, is substantial and **incomplete as a whole**. It is **not the current active execution focus** while improvement Phase B is current, and it was **not globally completed or superseded** by the improvement program. **Repository evidence does not establish the causal reason for the pivot**; any account of it is Product-Lead orientation, not repository fact. Unsettled and relevant here: **the exact resumption point and the next technical unit**.

**Plan, not present fact and not authorization:** it is to be **re-established from canonical repository truth, re-adjudicated as necessary, and resumed under Product-Lead GO**. The exact next post-improvement unit is **not decided**.

One orientation anchor — not a lineage, not to be reconstructed here: successor-database work is unadopted. The P3C review-round variants `R10-R1` / `R10-R2` are **TECHNICAL-ADOPTION-UNDECIDED**, and they and the P3C `POSTHOC-AUDIT-HOLD-REINSPECTION-REQUIRED` disposition are **defined by no canonical record on `main`**, named to withhold endorsement, never to assert current force (`DEC-0032` §5, §8; `DEC-0033` §8).

Collection-track evidence is landed on `main`; this document neither enumerates nor grades it (§I).

### Axis 2 — development-system improvement program (current model: A–F)

An **overlay** that improves the context, governance, agent, engineering and orchestration system used to develop NOXUND.

- **A — Reality & Repository Hygiene:** **COMPLETE**
- **B — Canonical Context V2:** **CURRENT improvement phase** (B1 complete — §G)
- **C · D · E · F:** **NOT STARTED**

**F is the final currently-defined phase of this improvement program — not the final phase of NOXUND development.**

**Provenance.** A–F is the **current Product-Lead improvement-program model**, not a landed ladder. Repository-landed records establish **A–C**; **D–F are Product-Lead-defined future program phases, not yet independently defined as landed phase records**, and the complete six-phase sequence is defined by no canonical record on `main`. Per `DEC-0033` §8, such identifiers are named to place them, never to confer standing.

**State:** the next candidate unit after B2 is **B3 — Context Index** — roadmap sequence, not landed order (§G).

**Authority:** B3 is **not authorized**; it requires its own explicit Product-Lead GO.

---

## C. Database and infrastructure reality

**State:**
- Legacy Supabase is **permanently retired**.
- **No production successor PostgreSQL exists.** **P10 (remote production PostgreSQL provisioning, `DEC-0028` §9) has not occurred.**
- `infra/postgres` is **local/dev plus design and spike material**, not a deployed production successor.
- Migrations **0001–0006** belonged to the retired Supabase schema. **0008/0009 were never applied.**
- **No current code path reaches a real production successor database.**

**Undecided, not decided here:** PostgreSQL version, RDS vs self-managed, collation, role topology, backup/PITR, migration runner, P10 architecture.

---

## D. Collection and write capability

**State:**
- The six DB-apply workflows (`phase1`–`phase5`, `entity`) are registry state **`disabled_manually`**.
- `.github/workflows/youtube-collection.yml` and `.github/workflows/video-collection.yml` are registry state **`active`** and **`workflow_dispatch`-only**, but are **DISARMED and FAIL-CLOSED**: their `guard` jobs abort every dispatch because the arming markers `.github/collection/youtube-collection.armed` and `.github/collection/video-collection.armed` are **ABSENT**. The `.github/collection/` directory does not exist on `main`. **Marker absence is the disarmed state, by design.**
- Repository-level Actions **secrets = 0** and **variables = 0**. At environment level, `youtube-collection` retains exactly one secret, `YOUTUBE_API_KEY`, and `production-db` is empty (`PHASE-A-CLOSEOUT-R1` §2B).

Registry-active is **not** armed, and neither collection workflow is disabled: both are **intentionally disarmed / inert — not dead**.

**Authority:** nothing was re-armed. Restoring any write capability the Unit-D containment removed — including re-enabling any of the six registrations and re-arming either collection sentinel — requires its **own explicit Product-Lead decision**, per [`DEC-0033`](decisions/DEC-0033-unit-d-closeout-p9-before-p8-sequencing.md) §8.

---

## E. Agent and governance reality

**Authority:**
- The **Product Lead is the final authority**; a landed record is ratified by their **manual merge** (`DEC-0035` header; §14 for Phase-B units).
- `NEXT` / `READY` / `RECOMMENDED` is **not execution authorization**; mutation needs an explicit Product-Lead GO.
- An Author **must not** review or accept their own work; the Reviewer is a distinct party.

**State:**
- Product-Lead manual merge of **every** PR is current practice; no landed record generalizes it beyond the gates above.
- `governance_integrity_agent` is **PROPOSED-NOT-OPERATIONAL / RUNTIME-NOT-WIRED**; it binds nothing.
- Substantive `packages/orchestrator` work remains **improvement Phase C**.
- The Phase-B docs-only topology is **temporary**: task-scoped Author + distinct independent Reviewer + manual Product-Lead merge; it wires no agent and grants no standing permission.

---

## F. Authority model — bootstrap minimum

Binding authority is determined under `DEC-0035`. The minimum to act correctly:

- **Authority class, lifecycle and mutability are three independent axes.** `SUPERSEDED` is a lifecycle value, never an authority class.
- **Chronology does not silently supersede.** Date, number and commit order are irrelevant alone; **explicit supersession is required**.
- Two conflicting **CURRENT INTERNAL-NORMATIVE** authorities with no explicit edge → **`HOLD — AUTHORITY-CONFLICT`**: state both readings and escalate. The winner is never inferred.
- **Memory is NON-AUTHORITATIVE.** On conflict, the repository wins.
- **Current-state reporting never overrides normative authority.** On disagreement `DEC-0035` §4 gives two outcomes: an accurate fact is a **STATE-AUTHORITY DIVERGENCE** — escalated, never edited away; a wrong or outdated statement here is a **STALE-DESCRIPTIVE DEFECT**, repaired in this document.

Adjudicate from `DEC-0035`, not this summary. **At the verification base, no state-authority divergence was found.**

---

## G. Improvement Phase B — Canonical Context V2 unit state

These `B*` labels are **Phase-B units**, **not** the `B1`/`B2`/`B3` Phase-A *blocker* labels of `PHASE-A-CLOSEOUT-R1` §1.

- **B1** authority / lifecycle / supersession model — **LANDED** (`DEC-0035`)
- **B2** compact current state — **this artifact**
- **B3** context index — **NOT YET IMPLEMENTED**
- **B4** task context pack — **NOT YET IMPLEMENTED**
- **B5** bounded reconciliation — **NOT YET EXECUTED**
- **B6** closeout — **NOT STARTED**

Unlanded identifiers (§B): `DEC-0035` names B0, B1, B3 and B5; **B2, B4 and B6 are defined by no canonical record on `main`** (B2 stands on its authorizing GO). Phase B is no more complete than this.

**Recorded for B3, not implemented:** a two-axis repository leaves B3 needing to separate **improvement-program routing** from **product/engineering-trajectory routing**, so the index does not treat A–F as NOXUND's only historical axis.

---

## H. Open and deferred headlines

Headlines only, not an inventory. **Successor PostgreSQL architecture undecided**, **provisioning unexecuted**. **Agent-governance / runtime redesign is improvement Phase C.** **Historical context normalization** remains improvement Phase-B work where scoped. **The product / engineering trajectory is paused and incomplete** (§B). The `OD-*` namespace and its cross-series collisions are **not** inventoried here — owned by **B3**.

---

## I. Routing

- Authority model, precedence, supersession → [`DEC-0035`](decisions/DEC-0035-canonical-context-v2-authority-lifecycle-supersession-model.md)
- Phase-A terminal state → [`PHASE-A-CLOSEOUT-R1`](../result/PHASE-A-CLOSEOUT-R1.md)
- Decision records → `docs/product/decisions/**`
- Agent governance and contracts → `docs/agents/**`
- Locked product scope → [`context/01_MVP_Scope_PRD.md`](../../context/01_MVP_Scope_PRD.md)
- Topic-level routing → **B3 context index, not yet landed**
