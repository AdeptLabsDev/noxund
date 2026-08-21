# NOXUND — Compact Current State

**Authority class:** DESCRIPTIVE-CURRENT · **Lifecycle:** CURRENT · **Mutability:** EDITABLE
**This is not a decision record; it creates no authority.** It does two things: report current reality and route to authority. Ambiguity about classification, precedence or supersession is governed by `DEC-0035` (§I).

**Freshness contract.** LAST VERIFIED AGAINST CANONICAL MAIN = `fae24ba7551a5d9469e7b1d62aa175a1ebf7a90c`, verification date **2026-08-20** (B5 reverification). If `origin/main` advances past that SHA, this document is **STALE-UNTIL-REVERIFIED** for current-state purposes — which does **not** mean every merge changes its content: reverification may conclude **NO CONTENT CHANGE REQUIRED**, updating only this metadata under an authorized maintenance unit. **The SHA is freshness provenance, not normative authority**, and **`STALE ≠ WRONG`**. B5 re-read §A–§F at that base and repaired only the Phase-B unit state (§B, §G, §H, §I): between B2's `a11bd169…` base and this one, the only files that changed are the three Phase-B artifacts themselves, so no claim here about any other file was disturbed. **The SHA records the base actually verified; the §B / §G unit state records what the B5 merge itself makes true.** That merge advances `main` past this SHA and so recreates the staleness condition on landing — inherent to the contract, **not a defect**.

**Scoped reverification — `351a73f99c7f8b103faa0a993ef9094e77f74305`, 2026-08-20, B6 (Phase-B closeout).** That base is the descendant merge of the `fae24ba7…` base above (PR #86, landing `DEC-0036`). B6 established from the repository that **the only files changed between `fae24ba7…` and this base are the three Phase-B routing artifacts, `DEC-0036` and `scope-guardrails.md`** — so every §A–§F claim here still rests on B5's verification, undisturbed. B6 therefore reverified and repaired **only the Phase-B terminal state** (§B, §G, §H, §I) and made no wider sweep. **This revision states what its own merge makes true**; the Product-Lead manual merge is the ratification gate (§E), and that merge recreates the ordinary `STALE-UNTIL-REVERIFIED` condition — inherent, not a defect.

**Scoped reverification — `aff75d51ac40348fae041fe068953dc3dd288d38`, 2026-08-21, `C1` (execution topology).** That base is the descendant merge of the `351a73f9…` base above (PR #87, landing the Phase-B closeout). C1 reverified and repaired **only what its own decision makes stale** — the Axis-2 ladder and the authority paragraph in §B, and §E in whole — resting on agent-capability and `packages/orchestrator` facts it re-derived from the repository at this base. **Every other claim here still rests on the B5 / B6 verifications and nothing wider should be inferred:** this was a bounded governance-topology unit, not a reverification sweep. **§F is deliberately untouched** — its *"no state-authority divergence was found"* is scoped to those verifications, and the one divergence C1 addressed (`agent-review-matrix.md` #12) is resolved at the authority end by [`DEC-0037`](decisions/DEC-0037-execution-topology-role-independence-governance-review-function.md) D9 rather than left standing. `STALE ≠ WRONG` applies unchanged, and this revision's own merge recreates the condition — inherent, not a defect.

**Scoped reverification — `45667387f74f92cf9aca532f786f9c8bd519d788`, 2026-08-21, `C3` (capability and principal model).** That base is the descendant merge of the `aff75d51…` base above (PR #88, landing `DEC-0037`). C3 reverified and repaired **only what its own decision makes stale** — the Axis-2 ladder and the authority paragraph in §B, and the agent/governance bullets in §E that report the independence and protection state, which C3 re-derived **directly from live repository configuration** and promoted from `REPORTED` to `VERIFIED`. **Every other claim here still rests on the B5 / B6 verifications and nothing wider should be inferred:** this was a bounded capability/principal unit, not a reverification sweep. **§D was re-derived incidentally and is confirmed unchanged**; **§F is deliberately untouched**, its scoping unaffected. **`C2` is a separate unit running in parallel and its outcome is deliberately not recorded here.** `STALE ≠ WRONG` applies unchanged, and this revision's own merge recreates the condition — inherent, not a defect.

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

**State:** the substantive product-build work. It **predates** the A–F program, is substantial and **incomplete as a whole**. It is **not the current active execution focus** — nothing is, at this base — and it was **not globally completed or superseded** by the improvement program. **Repository evidence does not establish the causal reason for the pivot**; any account of it is Product-Lead orientation, not repository fact. Unsettled and relevant here: **the exact resumption point and the next technical unit**.

**Plan, not present fact and not authorization:** it is to be **re-established from canonical repository truth, re-adjudicated as necessary, and resumed under Product-Lead GO**. The exact next post-improvement unit is **not decided**.

One orientation anchor — not a lineage, not to be reconstructed here: successor-database work is unadopted. The P3C review-round variants `R10-R1` / `R10-R2` are **TECHNICAL-ADOPTION-UNDECIDED**, and they and the P3C `POSTHOC-AUDIT-HOLD-REINSPECTION-REQUIRED` disposition are **defined by no canonical record on `main`**, named to withhold endorsement, never to assert current force (`DEC-0032` §5, §8; `DEC-0033` §8).

Collection-track evidence is landed on `main`; this document neither enumerates nor grades it (§I).

### Axis 2 — development-system improvement program (current model: A–F)

An **overlay** that improves the context, governance, agent, engineering and orchestration system used to develop NOXUND.

- **A — Reality & Repository Hygiene:** **COMPLETE**
- **B — Canonical Context V2:** **COMPLETE** (B0–B6 all complete — §G)
- **C — agent-governance / runtime redesign:** **STARTED, not complete.** Its landed units are **C1**, the execution topology ([`DEC-0037`](decisions/DEC-0037-execution-topology-role-independence-governance-review-function.md)), and **C3**, the capability / technical principal / independence model ([`DEC-0039`](decisions/DEC-0039-capability-technical-principal-independence-model.md)); its predecessor `C0` was an unlanded in-session assessment with **no file on `main`**, carrying a historical `RED` disposition adjudicated `CLOSED — REMEDIATED` — never routed from as clean evidence (`DEC-0037` header). `C2`, `C4` and `C5` are Product-Lead-defined unit labels; `C4` and `C5` are **not** started, and **`C2` is a separate unit whose state the C3 landing does not record** (`DEC-0037` §9; `DEC-0039` §7).
- **D · E · F:** **NOT STARTED**

**F is the final currently-defined phase of this improvement program — not the final phase of NOXUND development.**

**Provenance.** A–F is the **current Product-Lead improvement-program model**, not a landed ladder. Repository-landed records establish **A–C**; **D–F are Product-Lead-defined future program phases, not yet independently defined as landed phase records**, and the complete six-phase sequence is defined by no canonical record on `main`. Per `DEC-0033` §8, such identifiers are named to place them, never to confer standing.

**State:** B6 was the terminal Phase-B unit and **Phase B is closed** — its terminal record is [`PHASE-B-CLOSEOUT-R1`](../result/PHASE-B-CLOSEOUT-R1.md). **Phase C has begun and is incomplete.** No Phase-C closeout record exists, and the phase as a whole is defined by no canonical record on `main`.

**Authority:** **each Phase-C unit requires its own explicit Product-Lead GO**; the C1 GO authorized C1 and the C3 GO authorized C3, and each expired with its unit (`DEC-0035` §6). **Landing C1 or C3 authorizes nothing further** — not `C2`, `C4` or `C5`, not any Axis-1 resumption, and no re-arming (`DEC-0033` §8). **Closing Phase B likewise authorized nothing.** No successor unit is authorized on either axis at this base.

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
- The **Product Lead is the final authority**; a landed record is ratified by their **manual merge** (`DEC-0035` header; [`DEC-0037`](decisions/DEC-0037-execution-topology-role-independence-governance-review-function.md) D11).
- `NEXT` / `READY` / `RECOMMENDED` is **not execution authorization**; mutation needs an explicit Product-Lead GO.
- An Author **must not** review or accept their own work; the Reviewer is a distinct party — `AUTHOR ≠ REVIEWER` (`DEC-0037` D5, with checkable independence criteria at D7).
- **The execution topology is landed authority, no longer practice.** `DEC-0037` fixes the actor taxonomy, the minimum topology per risk class, and that **the Product Lead manually merges every governed PR** until changed by explicit Product-Lead authority.
- **`agent-review-matrix.md` item #12 is narrowed** by `DEC-0037` D9: the mandatory reviewer is the independent governance-review **function**, satisfiable by a distinct `TASK-SCOPED GOVERNANCE REVIEWER` — never by the Author, never silently omitted, and never labelled as the registered agent. **No other item of that matrix is changed**; #11 is latent and untouched.
- **Capability is separated from authority.** [`DEC-0039`](decisions/DEC-0039-capability-technical-principal-independence-model.md) fixes that `ROLE ≠ EXECUTION INSTANCE ≠ TECHNICAL PRINCIPAL`, that `TECHNICALLY POSSIBLE ≠ AUTHORIZED` and `DECLARED ≠ AVAILABLE`, and that **assigning a task-scoped role is an authorization boundary, not a technical capability sandbox** (D7). Every Product-Lead-only action is `PROCESS / AUTHORITY RESERVED · NOT TECHNICALLY ISOLATED` (D4). Its principal-separation decision is **P3 — HYBRID** (D9): single-principal containment accepted for ordinary governed work, with a second principal a prerequisite only for claiming mechanical independence, for any non-human reliance on an approval's authenticity, and for any future automated actor that could mutate irreversibly without a human in the loop. **`DEC-0039` provisions no principal and edits no file under `docs/agents/**`**; its §6 *reads* matrix items #10 and #13 without narrowing either.

**State:**
- **Zero registered NOXUND agents are REAL PRODUCT EXECUTORS.** `governance_integrity_agent` is **PROPOSED-NOT-OPERATIONAL / RUNTIME-NOT-WIRED**; it binds nothing, and `DEC-0037` neither registers nor wires it.
- **Task-scoped roles are not agents**: instantiating one creates no registration, no boundary and no standing permission (`DEC-0037` D3). The registry-first provisioning gate in [`docs/agents/README.md`](../agents/README.md) is undisturbed.
- **Process independence is not mechanical independence — now measured, not inherited.** `C3` re-derived the live configuration and **promoted `DEC-0037` D12's two `REPORTED` claims to `VERIFIED`** (`DEC-0039` §3). No `CODEOWNERS` file exists; `required_approving_review_count` is `0` and `required_reviewers` is empty, so **independent approval is not mechanically required** and the same GitHub principal may author and merge — which PRs #86–#88 show is not merely possible but what happened, with zero GitHub reviews recorded (**F4a**, `ACCEPTED CURRENT LIMITATION`). A single admin may also prospectively alter rulesets (**F4b**, `ACCEPTED` + detection routed to `C5`). **Neither fact means current protections are ineffective, and `CURRENT ENFORCEMENT` is a separate question from `CONFIGURATION DURABILITY`:** three rulesets are active, **direct push to `main` is mechanically blocked**, `main` cannot be force-pushed or deleted, and the eight preserved refs are protected against update, force-push and deletion **with no bypass actor at all**. Mechanical enforcement remains Phase-C unit `C5`.
- **Two technical principals exist, and only one is mechanically least-privileged.** The Product Lead, the Product Orchestrator and every task-scoped role act as the **same** GitHub principal — the sole collaborator, holding repository `admin`. The **CI identity** is separate and partly constrained: **`can_approve_pull_request_reviews: false`** is a repository setting no workflow can override, so that principal **cannot approve a PR**; its contents restriction (repository-default `read`, `contents: read` in all eleven workflow files **on `main`**) is a **default rather than a ceiling** and holds for the workflows that exist, not for any conceivable one. Whether any GitHub App or bot has access is **UNKNOWN** — the enumeration is unavailable to the current credential, and that is **not** evidence that none exists (`DEC-0039` §3.3).
- **Approver provenance cannot currently be proven technically.** Under one principal a runtime could not distinguish an authentic Product-Lead approval from an agent-produced one; `DEC-0039` D6 records this and names the *category* of trust anchor that would be required, implementing none.
- Substantive `packages/orchestrator` work remains **improvement Phase C** (`C2`), and the topology is **runtime-agnostic** — it holds whether that runtime is resumed, reduced or retired.
- The Phase-A/B docs-only topology was a **temporary exception** (`DEC-0035` §14). `DEC-0037` establishes the permanent topology **prospectively** and does **not** retroactively convert Phase-A/B practice into standing authority.

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

- **B0** foundation assessment — an **unlanded in-session assessment** accepted by the Product Lead; **no file exists on `main`** and none should be searched for (`DEC-0035` header)
- **B1** authority / lifecycle / supersession model — **LANDED** (`DEC-0035`)
- **B2** compact current state — **this artifact**
- **B3** context index — **LANDED** ([`context-map.md`](context-map.md))
- **B4** task context pack — **LANDED** ([`task-context-pack.md`](task-context-pack.md))
- **B5** bounded context reconciliation — **LANDED** (PR #85, merge `262c71907f24375196d13dc6901f64aa354acfad`); it reconciled §B, §G, §H and §I here and the stale routing claims in `context-map.md`
- **B6** Phase-B closeout — **COMPLETE**; its output is [`PHASE-B-CLOSEOUT-R1`](../result/PHASE-B-CLOSEOUT-R1.md) plus this revision's terminal-state maintenance

**Phase B is CLOSED.** Closing it **creates no authority and starts nothing** — see §B *Authority*.

Unlanded identifiers (§B): `DEC-0035` names B0, B1, B3 and B5; **B2, B4 and B6 are defined by no canonical record on `main`** — `task-context-pack.md` is the artifact B4 produced and `PHASE-B-CLOSEOUT-R1` the artifact B6 produced, neither being a record defining its unit — and B2, B4, B5 and B6 each stood on their own authorizing GO. Phase B is no more complete than this.

**Implemented by B3.** The two-axis separation this document required of the index — **improvement-program routing** kept distinct from **product/engineering-trajectory routing**, so the index does not treat A–F as NOXUND's only historical axis — is carried by [`context-map.md`](context-map.md) §2, which assigns every ladder it registers to Axis 1 or Axis 2.

**B5 closed complete, and the one question it left open is now closed by decision — not by B5.** The authority class of `docs/product/scope-guardrails.md` stood at `HOLD — PRODUCT-LEAD ADJUDICATION REQUIRED`, which no DESCRIPTIVE-CURRENT surface may resolve. The Product Lead adjudicated it, and [`DEC-0036`](decisions/DEC-0036-scope-guardrails-authority-class-descriptive-current.md) landed the result: **`DESCRIPTIVE-CURRENT · CURRENT · EDITABLE`, carrying no INTERNAL-NORMATIVE authority of its own** — route to the governing source, not to the compilation (`context-map.md` §1). That record **discharges the `DEC-0035` §9 deferral by satisfaction; it supersedes nothing and edits no DEC.** It is a decision unit of its own, **not** a retroactive part of B5 and **not** a Phase-B unit label.

*Verified for this paragraph only against `262c71907f24375196d13dc6901f64aa354acfad`, 2026-08-20 (`DEC-0036` unit) — the descendant merge of this document's declared base. No other claim in this document was reverified at that base.*

---

## H. Open and deferred headlines

Headlines only, not an inventory. **Successor PostgreSQL architecture undecided**, **provisioning unexecuted**. **Agent-governance / runtime redesign is improvement Phase C.** **Historical context normalization is open with no successor venue** — B5 was a *bounded* reconciliation, not a corpus-wide normalization, and Phase B closed without it (`DEC-0035` Annex A rows 1–11 stay routed and not solved). It is **not** carried by any open phase; assigning it one is a Product-Lead decision. **The product / engineering trajectory is paused and incomplete** (§B). The `OD-*` namespace and its cross-series collisions are **not** inventoried here — B3 inventoried the six families in [`context-map.md`](context-map.md) §2; the open `OD-*` items themselves stay open and close only by Product-Lead decision.

**What B5 pruned, so pruned is not mistaken for overlooked.** `DEC-0035` Annex A rows 1–11 and its §11 step 4 routing of `docs/agents/orchestration-runtime.md`'s stale `Status: implementado` line were **considered and deliberately left out** of this bounded unit as historical normalization: Annex A is expressly *"NOT normative"* and *"creates NO obligation to edit any file listed below"*, and permits B5 to *"add to or prune this list"*. They remain **routed and not solved** — the `orchestration-runtime.md` warning is live in `task-context-pack.md` §5 case D.

---

## I. Routing

- Authority model, precedence, supersession → [`DEC-0035`](decisions/DEC-0035-canonical-context-v2-authority-lifecycle-supersession-model.md)
- Phase-A terminal state → [`PHASE-A-CLOSEOUT-R1`](../result/PHASE-A-CLOSEOUT-R1.md)
- Phase-B terminal state; Phase-B routed residuals → [`PHASE-B-CLOSEOUT-R1`](../result/PHASE-B-CLOSEOUT-R1.md)
- Decision records → `docs/product/decisions/**`
- Agent governance and contracts → `docs/agents/**`
- Locked product scope → [`context/01_MVP_Scope_PRD.md`](../../context/01_MVP_Scope_PRD.md)
- Topic-level routing; identifier disambiguation and namespace collisions; explicit relations; preserved evidence → [`context-map.md`](context-map.md)
- Assembling minimum sufficient context for one bounded task → [`task-context-pack.md`](task-context-pack.md) — a format aid; it grants no execution authority
