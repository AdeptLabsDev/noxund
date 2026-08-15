# DEC-0033 — Unit-D closeout: canonical record of the pre-P9 containment chain, and P9-before-P8 execution sequencing

**Status:** ACTIVE (binding) · **Date:** 2026-08-15 · **Author:** Product Lead (ratified via Product Orchestrator)
**Scope:** (a) canonical memorialization of the **verified outcomes** of the Phase-A Unit-D chain — D-S1, D-S2, D-X1a, D-X1b, D-X2; (b) a **prospective execution-sequencing decision** making PG-EXIT **P9** a precondition for **P8**. **Docs-only unit** — no database, Compose, SQL, role, runner, migration, workflow, workflow registration, ruleset, Environment, secret, variable, GitHub App, Supabase resource, collection sentinel, branch cleanup or remote connection is created or changed here.
**Extends:** [[DEC-0028]] §6 (critical patrimony), §7 (PR #65 / run `30450421392` preservation) and §9 (plan P2–P10). **Does not edit** [[DEC-0028]], [[DEC-0029]], [[DEC-0030]], [[DEC-0031]] or [[DEC-0032]] — all remain frozen and additive-only.
**Predecessor units:** UNIT-D R0 (read-only PostgreSQL/Supabase hygiene audit) → UNIT-D-S12 (D-S2, D-S1) → UNIT-D-X1a → UNIT-D-X1b → UNIT-D-X2 — all closed before this record was authored.
**Canonical base:** `main` @ `84dadcfb5fc9580a11efc2521e6caf67406224f7`

---

## 1. Governance gaps this record closes

Two gaps were identified against canonical `main` and verified directly, not inferred:

**GAP-1 — sequencing authority not landed.** The Product Lead's operational rule *"P9 before P8"* governs current execution, but no landed repository record states it. On this record's canonical base, the token `P8` occurs **exactly once** in the entire repository — the [[DEC-0028]] §9 plan table — and `P9` occurs **exactly once** across `docs/**` + `context/**` (same table; **four further occurrences, across three files**, exist outside those trees — `db/legacy-map.md` lines 17 and 18, `infra/postgres/compose.local.yml` line 22, `infra/postgres/README.md` line 52 — all referring to a legacy-collation inventory owed *before* P9, none establishing order relative to P8). §9 lists the **P8 row before the P9 row**.

**GAP-2 — Unit-D outcomes not landed.** No canonical record covers the Unit-D chain. On this record's canonical base, the tokens `D-S1`, `D-S2`, `D-X1a`, `D-X1b`, `D-X2`, `UNIT-D` and every load-bearing platform identifier used below (ruleset `20890207`, installation `136198973`, preservation commit `be83d455…`) return **zero matches** across all 333 tracked paths.

The Unit-D operations were **valid, explicitly Product-Lead-authorized and independently verified at the time they were performed**. The missing record never invalidated them. What was missing was a canonical home for their outcomes.

## 2. What this record is, and what it is not

**It is** an additive canonical record that (a) memorializes verified outcomes already produced under prior explicit Product-Lead authorization, and (b) establishes **new prospective sequencing authority** effective from its date.

**It is not** a retroactive authorization. This record did **not** authorize D-S1, D-S2, D-X1a, D-X1b or D-X2. Each was authorized before it was performed, through the Product Lead's explicit decisions — notably the binding Unit-D R0 answers **Q1–Q6**, which are **session-authoritative and not landed on `main`**; they are named here as the historical authorization basis, never as landed authority, and this record does not land them. Each unit executed under its own declared mutation budget and was independently verified at the time. Nothing here may be read as conferring authority backwards in time.

**Three registers are kept distinct.** §3 is *existing landed authority* (unchanged by this record). §4 is *verified historical platform outcomes* (facts, memorialized). §5 is *new Product-Lead authority* (established now, prospective only). §6–§9 are consequences and boundaries of those three: a forward obligation there derives from §5, a restated constraint points at the landed record that carries it, and a withheld permission restates the default fail-closed posture. None of the three introduces separate authority.

## 3. Existing landed authority — referenced, unchanged

| Record | Standing after this decision |
|---|---|
| [[DEC-0028]] | **Unchanged and byte-frozen** (blob `29f7a387d62284b90a763d9afc2b7c2d0cdad2e2`). Architectural direction, §6 patrimony, §7 preservation orders and §9 plan all remain as written. |
| `DEC-0028-ADDENDUM-dec0027-provenance-and-successor.md` | Unchanged. The two `DEC-0027` references inside the frozen [[DEC-0028]] body remain **classified historical provenance**. |
| [[DEC-0029]] · [[DEC-0030]] | Unchanged. OD-5 = REJECT SQITCH; Flyway rejected for least-privilege incompatibility. |
| [[DEC-0031]] | Unchanged. Phase-2 authority reconciliation. |
| [[DEC-0032]] | Unchanged. **Negative-constraint authority only** — it establishes no positive future migration runner, and this record establishes none either. |
| `SEC-0027-phase2-verify-parity-erratum.md` | Unchanged. Phase-2 verify-parity erratum. |
| `SEC-0008` / `SEC-0009` additive banners | Unchanged and still load-bearing. |

A historical decision record bearing the identifier `DEC-0027` remains **HISTORY-ONLY-NO-LAND / NON-CANONICAL**, citable only as `2d0fbcd1eec1bf8f79451e0aa106c7b0a857dba7:docs/product/decisions/DEC-0027-sg8-remote-promotion-r0-preflight.md`. The absence of a `DEC-0027` file on `main` is deliberate and permanent; this record does not fill it.

## 4. Unit-D verified outcome chain (memorialized facts)

### 4.1 D-S1 — collection write paths disarmed on canonical `main` · CLOSED

Both arming sentinels were removed from canonical `main`:

- `.github/collection/youtube-collection.armed`
- `.github/collection/video-collection.armed`

Landed via **PR #73**, merged manually by the Product Lead as a two-parent merge commit; canonical `main` after D-S1 = `84dadcfb5fc9580a11efc2521e6caf67406224f7`.

Arming is a **tracked-file marker**, not a configuration variable: each workflow's guard resolves the sentinel path and treats its **absence** as the disarmed state, failing closed before any credential is reached. With both markers absent from canonical `main`, **canonical-main collection write capability is DISARMED / FAIL-CLOSED.**

Boundaries: both collection **workflow files were preserved** — only the sentinels were removed. Both collection **workflow registrations remain `active` by design**; an active registration is **not** armed write capability. Historical branches were **not** cleaned (see §7-A). Re-arming is **not** authorized by P9 completion and requires a separate explicit Product-Lead decision.

### 4.2 D-S2 — historical remote-apply workflow registrations disabled · CLOSED

Exactly six registrations were set `active` → **`disabled_manually`**, with **files, registrations and run history all preserved** (GitHub exposes no delete endpoint for a workflow registration, so preservation is platform-guaranteed):

| Path | Workflow id |
|---|---|
| `.github/workflows/phase1-db-apply.yml` | `300187268` |
| `.github/workflows/phase2-db-apply.yml` | `301698786` |
| `.github/workflows/phase3-db-apply.yml` | `302655094` |
| `.github/workflows/phase4-db-apply.yml` | `303041175` |
| `.github/workflows/phase5-db-apply.yml` | `303400793` |
| `.github/workflows/entity-db-apply.yml` | `303792662` |

Classification: **DISABLED-MANUALLY / HISTORICAL FILES + HISTORY PRESERVED**. These workflow files are **RETAIN-FROZEN** — they must not be deleted as dead code. Workflow ids are **not** in path order; always match by path.

### 4.3 D-X1a — authority-evidence refs protected · CLOSED

Repository ruleset **`20890207` "Preserve authority evidence"** — `active`, `target: branch`, `bypass_actors` empty (`current_user_can_bypass: never`), **exactly four fully-qualified includes, zero excludes, no wildcard**; rules `deletion` + `non_fast_forward` + `update` with `updateAllowsFetchAndMerge = false`.

| Protected ref | Pinned commit |
|---|---|
| `refs/heads/feat/sg8-r0-preflight-author-production-db` | `2d0fbcd1eec1bf8f79451e0aa106c7b0a857dba7` |
| `refs/heads/spike/pg-exit-p3a-sqitch-atomicity` | `8b36bd1bb10ce64b532e3114100847216c65852c` |
| `refs/heads/spike/pg-exit-p3b-flyway-atomicity` | `e8c72f1c4419d2fb7c30033d892be02355557b32` |
| `refs/heads/wip/phase6-producer-events-preservation` | `a1ec48342a9471a8044ae46c5e9e7c4078896ae7` |

**EXACT-REF-ONLY** — never broad `spike/**` or `wip/**` wildcards. Branch contents were unchanged and all four commits unmoved.

**PROTECTION ≠ ADOPTION (binding).** The ruleset preserves evidence cited by [[DEC-0028]] §7, [[DEC-0029]] and [[DEC-0030]]. It does **not** approve those branches' contents as future architecture, does not canonize the historical `DEC-0027`, and does not make the Phase-6 WIP content reviewed or adopted.

Protection class: **RULESET-PROTECTED / OWNER-REVERSIBLE-BY-RULESET-REMOVAL** — never describe it as absolute immutability.

*API-representation note:* REST omits `parameters` on an `update` rule, returning a bare `{"type":"update"}`. The stored `updateAllowsFetchAndMerge = false` is visible only via GraphQL. Never read the bare REST echo as a missing parameter.

### 4.4 D-X1b — Actions-run evidence preserved outside Actions retention · CLOSED

[[DEC-0028]] §7 orders preservation of failed run **`30450421392`**. Actions log retention is finite, so the run's logs were preserved in a dedicated repository:

**`AdeptLabsDev/noxund-unitd-x1b-run-30450421392-preservation`** — `PRIVATE` · `ARCHIVED` · not a fork · read-only in normal operation · **owner-reversible**. Single **root commit `be83d455550b45da82f1f1ddc34785436fe66b5b`**, **tree `9bcd77a34723a1fa611021fd20e77672f0153531`**, **0 parents**, 11 byte-hashed files, no `.github/**`, zero workflows, zero Actions runs.

**PRESERVATION-NOT-ADOPTION (binding).** This repository is **evidence storage only**. It must **not** become a product, runtime, build or CI dependency of NOXUND. It does not canonize the historical `DEC-0027`, adopt the historical implementation, re-open PR #65, or authorize any migration or Supabase execution. It is durable, **not absolutely immutable** — an owner can unarchive or delete it.

### 4.5 D-X2 — NOXUND↔Supabase GitHub integration removed · CLOSED

The integration was removed through the **minimum safe planes only**. **Exactly two external control-plane writes occurred, both performed manually by the Product Lead**, in this order:

1. **Supabase plane (A/B)** — deleted the organization's GitHub project connection `noxund ↔ AdeptLabsDev/noxund`.
2. **GitHub plane (C)** — updated Supabase App installation **`136198973`** repository access: **removed** `AdeptLabsDev/noxund`, **kept** `AdeptLabsDev/adeptlabs` (mode remains *Only select repositories*).

**Planes deliberately NOT used, and forbidden under least-removal:** **plane D** — account-level Supabase↔GitHub OAuth revocation; **plane E** — whole-App uninstall. The installation was proven non-exclusive, so neither was necessary.

**Final state — PRESERVED, never claim otherwise:**

| Asset | State |
|---|---|
| Supabase project `noxund` (ref `pwbkplzyzmortwjjpcbg`) | **PRESERVED · PAUSED** — never resumed, never deleted |
| The production database | **PRESERVED · NOT ACCESSED** (zero access in Unit D) |
| Account-level Supabase↔GitHub OAuth | **PRESERVED** |
| Supabase App installation `136198973` | **PRESERVED** (still exists globally) |
| Installation `136198973` selected repositories | **`AdeptLabsDev/adeptlabs` only**; `AdeptLabsDev/noxund` **not selected** |
| `AdeptLabsDev/adeptlabs` | **UNTOUCHED** |
| Both GitHub Environments, and every secret/variable name | **PRESERVED** |
| Historical Supabase check suites | **PRESERVED / undeleted** |

**Epistemic basis — `PL-UI-AUTHORITATIVE / AGENT-CORROBORATED / ZERO-CONTRADICTION`.** The decisive Supabase-side connection state and the GitHub installation membership are **not readable at any read-only scope available to this project's automation**. The control-plane membership above is therefore recorded on the Product Lead's direct UI observation, corroborated by agent-side evidence with zero contradiction. It **MUST NOT** be described as *API-proven* or *agent-proven*.

**Project-level integration toggles** (working directory, production branch, automatic branching, supabase-changes-only, deploy-to-production) remain **`UNKNOWN-PRE-REMOVAL`** — the project was paused and resume was never authorized. They must **never** be retroactively recorded as having been off.

## 5. Decision — P9 completion is a precondition for P8

**Binding, prospective, effective from this record's date:**

> **PG-EXIT P9 MUST COMPLETE SUCCESSFULLY BEFORE PG-EXIT P8 MAY BEGIN.**

This is a **precondition**, not a listing order. P8 may not begin, in whole or in part, until P9 has completed and its success has been accepted by the Product Lead.

### 5.1 Rationale

**P9**, quoted verbatim from [[DEC-0028]] §9: *"Inventory + export/restore of the raw dataset (`f0485de6`, 500/146) to the self-hosted DB, with reinforced counts + digests and destination §7 re-verify"* — nature *"gated window"*. The **§7 re-verify** pointer is load-bearing and is not to be paraphrased away: destination acceptance is the same completeness gate the dataset already passed at source. That gate is landed — `DATA-COLLECT-001-youtube-collection-spec.md` **§7** (*Gate de completude do snapshot*) and `DATA-COLLECT-002-channel-data-collection-spec.md` **§7** (*Gate de completude do snapshot de canais*) — and the dataset is recorded as having passed **both**, i.e. *double-§7-passed*.

**P8**, quoted verbatim from [[DEC-0028]] §9: *"Retire obsolete env/secrets/vars; re-point Environments (`production-db`→self-hosted; `youtube-collection` keeps `YOUTUBE_API_KEY`)"* — nature *"design/impl on GO"*.

The dataset is reachable through the repository's **only landed** access path: the Environment-held credentials and Environment configuration that P8 exists to retire and re-point. Executing P8 first would remove or alter the prerequisites required to safely export, restore, validate and preserve data that [[DEC-0028]] §6.1 designates **critical patrimony** and §1 identifies as *"the only irreplaceable business data"* — **non-regenerable**, because *"recollection = new `run_id`"*. The exposure is unrecoverable and asymmetric: P8 executed early can destroy the landed path to data that cannot be recreated, while P8 executed after P9 loses nothing.

This is the ordering consequence of the security condition already carried by [[DEC-0028]] §10 — *the raw dataset stays protected until the destination proves parity + backup* — and of §6.4's *no export in this unit*. Those clauses established the protection; they did not establish the order. This record establishes the order.

### 5.2 Relationship to DEC-0028 §9 — precedence

Stated exactly, so nothing is over-read:

1. **[[DEC-0028]] remains historically intact and byte-frozen.** This record does **not** rewrite, amend or re-order §9.
2. **[[DEC-0028]] §9 lists the P8 row before the P9 row.** That is what it says, and this record does not claim otherwise. **[[DEC-0028]] did not originally require P9 before P8.**
3. §9 is captioned *"proposal — nothing executed; each gated docs/design→GO"*. It is a plan table, not an execution-order guarantee.
4. **For all execution from this record's date forward, §5's rule governs sequencing.** Where §9's row ordering could be read as permitting P8 first, this newer Product-Lead sequencing decision controls — **for future execution sequencing only**, and for nothing else in [[DEC-0028]].

### 5.3 What P9 must preserve

P9 must preserve the **current authoritative raw dataset before P8 begins**. Its identity is landed on `main` and is not restated from session memory: run `f0485de6-0d34-41cf-ab48-d46e483aa558` — **500 videos, 146 channels** ([[DEC-0028]] §1 and §6.1; corroborated by `docs/data/SG-V7-data-collect-001-first-collection-closeout.md`, `docs/data/SG-6-data-collect-002-channel-collection-closeout.md` and `docs/data/DATA-SG8-001-sg8-design-contract.md`, which record the frozen, double-§7-passed dataset consumed by both SG-8 rounds).

The [[DEC-0028]] §6 conditions continue to bind P9 unchanged: full inventory before any export; reinforced counts and digests on the raw subset; and **`session_replication_role = replica` is NOT authorized**.

**No part of P9 or P8 is executed by this record.** It defines sequencing; it does not perform it.

## 6. Security consequence of Unit D

Recorded without inflation.

Before D-X2, the Supabase GitHub App held repository capability over NOXUND including `actions:write`, `checks:write`, `pull_requests:write`, `workflows:write`, `contents:read` and `metadata:read`. By removing `AdeptLabsDev/noxund` from installation `136198973`'s repository-access set, **NOXUND no longer carries that Supabase-App capability surface through that installation.**

This consequence inherits **§4.5's epistemic class in full** — `PL-UI-AUTHORITATIVE / AGENT-CORROBORATED / ZERO-CONTRADICTION`. The installation-membership fact it rests on is not readable at any read-only scope available to this project's automation, so this paragraph must **never** be re-stated as API-proven or agent-proven either.

This mattered because the GitHub↔Supabase integration was a **separate automation lane** — a third-party path capable of acting on the repository and of driving migrations on merge. UNIT-D-S12's containment covered **GitHub Actions only** and never reached it. D-S1 and D-S2 closed the Actions-side write paths; D-X2 closed the integration lane. Together they establish the pre-P9 containment posture.

**Explicitly NOT claimed:** that Supabase is globally removed; that all Supabase credentials are retired; that the Supabase project is deleted; that all historical Supabase artifacts are removed; that P8 occurred; that P9 occurred.

As a direct consequence of §5 — introducing no separate authority — the managed-provider database credentials remain **retention-required until P9 completes**. This covers **both** Environments that hold them: `production-db` **and** `youtube-collection`, the latter of which also carries database credentials reaching the same managed instance. Naming only one would imply, by omission, that the other is retirable early.

## 7. Nonblocking residuals — carried forward, not repaired here

**A. `HISTORICAL-ARMING-SENTINEL-BRANCH-RESIDUE` — CLEANUP-CANDIDATE / NONBLOCKING.** 18 of 52 remote branches still contain `.github/collection/*.armed`. **Canonical `main` is clean.** Safety is fail-closed three-deep: (1) sentinel absence on canonical `main`; (2) the `SEC-F18` main-ref guard in both collection workflows; (3) the GitHub Environment branch policy restricted to `main` plus a required Product-Lead reviewer. **Not cleaned here** — several of those branches are checkpoint or evidence surfaces and must not be casually rewritten. Any future cleanup requires its own authorized unit.

**B. Orphan workflow registration `322938835`** (historical path `.github/workflows/sg8-r0-preflight-local-test.yml`; backing file absent from `main`) — **KEEP-HARMLESS-REGISTRY-RESIDUE**. Not disabled, deleted or edited here, and not a Unit-D target. Its trigger is `pull_request` only, so it is not dispatchable.

**C. Deferred zero-cost D-X2 corroboration.** At the **next legitimate** push to `AdeptLabsDev/noxund`, the naturally-created new commit SHA may be checked for the absence of any check suite with `app.id == 330661`. This is **optional observational confirmation, not a D-X2 blocker** — D-X2 is closed. **No synthetic commit, branch, PR, push or workflow dispatch may be created to test it.**

## 8. Non-decisions (explicit carve-outs)

**Convention on unlanded identifiers.** Some identifiers below are **not yet defined by any canonical record on `main`** — they are carried in the Product Lead's operating record. Following the precedent [[DEC-0032]] §5 sets for `R10-R1`/`R10-R2`, they are named here **only to withhold clearance or endorsement, never to confer landed standing** on them. Naming an identifier in this section neither lands it nor asserts its current force. The identifiers in this class are: `POSTHOC-AUDIT-HOLD-REINSPECTION-REQUIRED`, the *"104/104 evidence"*, `D-BC` and `D-A`.

**Identifier-collision warning — `D-A`.** The label `D-A` as used here denotes a **Unit-D successor unit**. It is **not** the same identifier as [[DEC-0023]] **§D-A** (the percentile-method ratification, landed and cited downstream by `DATA-CONST-001` and `DATA-SCORING-001`). Per `DEC-0028-ADDENDUM-dec0027-provenance-and-successor.md`, *Registered interpretation* ¶7, same-label reuse across namespaces must **never** be conflated. Any future unit adopting the `D-A` label must disambiguate it or rename it.

This record does **not**, by any reading:

- adopt `R10-R1`; adopt `R10-R2`; or resolve `R10-R1` vs `R10-R2` — **TECHNICAL-ADOPTION-UNDECIDED** per [[DEC-0032]] §5 and §8;
- clear, weaken, confirm or adjudicate the PG-EXIT-P3C **`POSTHOC-AUDIT-HOLD-REINSPECTION-REQUIRED`** disposition — this record does not touch it in either direction;
- reinterpret, validate or adjudicate the *"104/104 evidence"* — **EVIDENCE-PROVENANCE-REQUIRES-LATER-ADJUDICATION**;
- convert the D-X1b preservation repository into an adoption, or into any product, runtime, build or CI dependency;
- make the D-X1a protected branches adopted product architecture;
- delete, resume, modify or access the Supabase project or its database;
- retire, rotate or re-point any Supabase-era credential, secret, variable or Environment;
- execute P9; execute P8;
- select or endorse a final migration runner — [[DEC-0032]] remains negative-constraint-only and **OD-7 remains OPEN**;
- activate, wire or endorse `infra/postgres/**`;
- rename any active runtime DSN. `SUPABASE_DB_URL` → `NOXUND_DB_URL` remains deferred under the landed **`DEFER-POSTGRES-SUPABASE-HYGIENE`** bucket of [[DEC-0032]] §8, carried forward into `D-BC`; this record neither moves nor re-homes that deferral;
- **restore any write capability that Unit D removed.** Re-enabling, re-registering or otherwise reactivating any of the six `disabled_manually` registrations of §4.2; re-arming the collection sentinels of §4.1; or activating orphan registration `322938835` each requires its **own explicit Product-Lead decision**. None of them is authorized by this record, by P9, or by P8 — completing P9 does **not** re-arm anything;
- re-open PR #65, or land any artifact from the historical branches of §4.3;
- begin `D-BC`; begin `D-A`; begin Phase B; begin Phase C;
- clean, rewrite or delete any historical branch;
- modify orphan workflow registration `322938835`;
- authorize any commit, push, PR, merge, dispatch or ruleset change beyond the docs-only landing of this record itself.

## 9. Next gate

With this record landed, the Unit-D authority and governance closeout is complete.

**The next technical unit is PG-EXIT P9** — inventory + export/restore of the raw dataset per [[DEC-0028]] §6 and §9, under §5 above. It requires its own explicit Product-Lead GO and its own gated unit; nothing here starts it. **P8 follows only after P9 succeeds.** `D-BC` and `D-A` remain **undecided in detail and unsequenced by this record** — §5 orders P9 and P8 only.

## 10. Change control

This record is **additive and frozen on landing**, under the established NOXUND doctrine — [[DEC-0022]] *Alternativas consideradas* (*"decisões são histórico; nada de reescrita retrospectiva"*) and [[DEC-0023]] §D-F (additive addenda that preserve the historical body intact), with the mechanism precedents `DEC-0024-ADDENDUM-migration-ordering-policy.md` and `DEC-0028-ADDENDUM-dec0027-provenance-and-successor.md`. Corrections land as an additive prefix banner or a companion addendum, **never as a rewrite of this body**.

Superseding §5's sequencing rule requires an explicit later Product-Lead decision record that names it. Until such a record exists, **P9-before-P8 is landed repository authority**, not merely an operational convention.

---

*Related: [[DEC-0028]] (§6 patrimony, §7 preservation, §9 plan P2–P10, §10 security condition) · `DEC-0028-ADDENDUM-dec0027-provenance-and-successor.md` · [[DEC-0029]] · [[DEC-0030]] · [[DEC-0031]] · [[DEC-0032]] (negative constraints only) · `SEC-0027-phase2-verify-parity-erratum.md`. Dataset provenance: `docs/data/SG-V7-data-collect-001-first-collection-closeout.md`, `docs/data/SG-6-data-collect-002-channel-collection-closeout.md`, `docs/data/DATA-SG8-001-sg8-design-contract.md`. Historical provenance (non-canonical, do-not-land): `2d0fbcd1eec1bf8f79451e0aa106c7b0a857dba7:docs/product/decisions/DEC-0027-sg8-remote-promotion-r0-preflight.md`, PR #65 closed/unmerged.*
