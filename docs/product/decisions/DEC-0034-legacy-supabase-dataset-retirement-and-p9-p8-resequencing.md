# DEC-0034 — Legacy Supabase dataset retirement, and P9/P8 re-sequencing

**Status:** ACTIVE (binding) · **Date:** 2026-08-17 · **Author:** Product Lead (ratified via Product Orchestrator)
**Scope:** Minimal authority repair. Resolves exactly the two landed-authority conflicts identified by `SUPABASE-PERMANENT-RETIREMENT-PREFLIGHT-R1`, and nothing else. **Docs-only** — no database, SQL, Supabase resource, migration, workflow, workflow registration, ruleset, Environment, secret, variable, credential or remote connection is created, read or changed here.
**Discharges / supersedes:** [[DEC-0028]] §10 *Security & Privacy* binding condition — for the legacy dataset only; [[DEC-0033]] §5 — for the legacy Supabase retirement path only.
**Does not edit:** [[DEC-0028]] or [[DEC-0033]]. Both remain **byte-frozen** and additive-only. Neither is declared obsolete.
**Evidence base:** `docs/database/SUPABASE-LEGACY-STRUCTURAL-BRIEF-R0.md` (landed) and `SUPABASE-FINAL-STRUCTURAL-INSPECTION-HANDOFF-R1`. Referenced, not restated.
**Canonical base:** `main` @ `c38772fb4ce346665fb7f94f6500eee9980d0f3a`

---

## 1. Status

**ACTIVE — binding and prospective**, effective from this record's date. It confers no authority backwards in time and authorizes no execution of any kind (§5).

---

## 2. Context

The Product Lead has selected **permanent retirement of the legacy Supabase project `pwbkplzyzmortwjjpcbg`** as the route for terminating continued storage of the historical YouTube API dataset. The dataset will not be migrated.

That direction collides with two landed records. Neither collision is a defect in those records; both arise because the plan they were written under has changed.

- **[[DEC-0028]]** carries, in its §10 *Security & Privacy* parecer, the binding condition that *"the raw dataset stays protected until the destination proves parity + backup."* Retirement destroys the dataset with no destination and therefore no parity or backup proof, so the condition's trigger can never occur.
- **[[DEC-0033]] §5** makes successful **P9** completion a **precondition** for **P8**, and its closing provision requires *"an explicit later Product-Lead decision record that names it"* before that sequencing may be superseded. Per [[DEC-0028]] §9, **P9** is the *export/restore of the raw dataset to the self-hosted DB* and **P8** is *"Retire obsolete env/secrets/vars; re-point Environments …"*. Retirement makes P9 permanently impossible to complete, which would strand P8 — the Supabase credential, environment and reference hygiene that must follow deletion — behind a condition that can never be met.

The structural knowledge required for the successor design is already captured and landed; no further database inspection is justified.

---

## 3. Decision

### D1 — The legacy dataset will not migrate

The historical Supabase-hosted YouTube API dataset (collection run `f0485de6`) **will not be exported, restored, transferred or migrated** into the successor PostgreSQL system. It is intentionally retired with the legacy project.

The **exact historical snapshot is not regenerable**; re-collection would produce a new run under a new `run_id`. This decision accepts that loss deliberately.

### D2 — The P9 export/restore limb is withdrawn

The [[DEC-0028]] §9 **P9 export/restore limb is WITHDRAWN** for this legacy dataset. **P9 must not execute against the historical Supabase dataset.**

This withdrawal authorizes **no** new collection, **no** refresh, **no** replacement collection and **no** successor database work.

### D3 — The [[DEC-0028]] protection condition is discharged for this dataset

For the legacy dataset only, the [[DEC-0028]] §10 condition requiring continued preservation until destination parity and backup are proven is **explicitly discharged**.

> **PERMANENT PROJECT RETIREMENT IS THE SELECTED ACTION FOR TERMINATING CONTINUED STORAGE.**

**That condition was valid when issued.** It was the correct protection under the then-current plan to migrate the dataset, which [[DEC-0028]] §6.1 designates *critical patrimony*. It is **not** discharged because it was mistaken; it is discharged **prospectively**, because the plan it protected has been replaced by a decision to terminate storage rather than move it.

**This record does not state, and must not be read to state, that deletion retroactively cures historical over-retention.**

### D4 — [[DEC-0033]] §5 is explicitly superseded for this path

This record **explicitly names and supersedes [[DEC-0033]] §5 — P9-before-P8 sequencing** — as that record's closing provision requires.

For the legacy Supabase retirement path, **P8 no longer depends on successful P9 completion.** After permanent project deletion has been independently verified, Supabase credential, environment and reference hygiene **may proceed without P9 completion**.

The §5.1 rationale is satisfied rather than overridden. It rested on an asymmetric exposure — *"P8 executed early can destroy the landed path to data that cannot be recreated, while P8 executed after P9 loses nothing."* Once the dataset is deliberately retired under **D1**, there is no landed path left to protect and the asymmetry no longer exists.

**[[DEC-0033]] §6's credential clause follows §5 and is carried by this supersession.** Its final paragraph provides that *"the managed-provider database credentials remain retention-required until P9 completes"*, covering both the `production-db` and `youtube-collection` Environments — and states of itself that it is *"a direct consequence of §5 — introducing no separate authority."* It is named here so it cannot later be read as an independently surviving blocker that would re-strand P8 through the same never-triggering condition this decision exists to repair. **This is a clarification of D4's reach, not a separate supersession**; §6's security findings are untouched.

### D5 — [[DEC-0033]] §8 remains fully binding

Nothing in this record re-arms a workflow, re-enables a `disabled_manually` Actions registration, restores a collection sentinel, activates orphan registration `322938835`, authorizes YouTube collection, authorizes any database write, or authorizes **P8 before verified project deletion**.

**Every re-arming action continues to require its own explicit Product-Lead decision.**

---

## 4. Supersession and discharge — exact scope

| Instrument | Treatment |
|---|---|
| [[DEC-0028]] | **Byte-frozen. Not edited. Not obsolete.** Remains historical and architectural authority. Only the §10 *Security & Privacy* clause *"the raw dataset stays protected until the destination proves parity + backup"* is discharged, and only for the legacy dataset. The remainder of that parecer stands — including the prohibition on `session_replication_role=replica`. |
| [[DEC-0028]] §9 P9 | Export/restore limb **withdrawn** for this dataset (D2). The §9 plan is otherwise untouched. |
| [[DEC-0033]] | **Byte-frozen. Not edited. Not obsolete.** Remains binding. |
| [[DEC-0033]] §5 | **Superseded only** as to the P9-before-P8 precondition, and **only** for the legacy Supabase retirement path (D4). |
| [[DEC-0033]] §6, final paragraph | **Follows §5 by its own terms** and is carried by D4. Its credential retention-until-P9 clause self-declares as *"a direct consequence of §5 — introducing no separate authority."* Named so it is not read as an independently surviving blocker. **§6's security findings and epistemic class are untouched.** |
| [[DEC-0033]] §8 | **Fully binding, undisturbed** (D5). |

No other clause of any record is superseded, discharged, reinterpreted or reopened.

---

## 5. Explicit non-decisions

This record does **not** decide or authorize any of the following:

successor PostgreSQL major version · successor collation / ICU / libc policy · successor role topology · whether `ensure_rls` / `rls_auto_enable()` is reproduced or replaced · **OD-3** · P10 architecture ratification · P10 provisioning · P10-R5 execution · **P8 execution before verified Supabase deletion** · any new P9 execution · new YouTube collection · refresh of legacy YouTube API Data · targeted raw-row purge · trigger disablement · re-pause · backup export · database dump · **project deletion itself** · credential deletion · secret rotation · workflow re-arming.

**Permanent deletion requires a separate, explicit Product-Lead GO.** This record removes two authority blockers; it is not that GO. **P8 likewise remains *"design/impl on GO"* per [[DEC-0028]] §9** — removing its P9 precondition does not supply its GO, and nothing here may be read as self-authorizing P8 once deletion is verified.

---

## 6. Consequences

1. **Permanent retirement of `pwbkplzyzmortwjjpcbg` is no longer obstructed by landed authority.** It remains obstructed by the absence of a deletion GO, which this record does not supply.
2. **P8 / credential-and-reference hygiene is unstranded** — but only after verified deletion, and it must still census all remaining consumers before removing any secret, variable or reference. The `SUPABASE_DB_URL` → `NOXUND_DB_URL` rename stays under [[DEC-0032]] §8's `DEFER-POSTGRES-SUPABASE-HYGIENE` bucket and is not re-homed here.
3. **Credentials stay untouched until then:** `SUPABASE_DB_PASSWORD` kept, not reset, not rotated, not removed; `SUPABASE_ACCESS_TOKEN` kept unread and unused.
4. **The legacy-collation inventory gate no longer gates anything** — the PG-EXIT open item labelled `D3`, which is a separate identifier from decision **D3** of §3 above — its gating subject having been withdrawn under **D2**. The collation facts it demanded are captured in the landed brief and survive as design input to the open successor-collation decision.
5. **Migrations 0008 and 0009 are unaffected.** They remain unapplied repository artifacts routed to **P7** for vanilla redesign against the successor, exactly as [[DEC-0028]] provides.
6. **What is destroyed on deletion, and what survives**, is recorded in the landed structural brief and is not restated here.

---

## 7. Authority preserved

- [[DEC-0028]] and [[DEC-0033]] remain **frozen, additive-only and non-obsolete**. Their historical rationale is not rewritten.
- [[DEC-0033]] §8 remains **fully binding**: completing, withdrawing or superseding P9 re-arms **nothing**.
- The Fase 9 veto (`SEC-0001` §0) is untouched.
- No retroactive authorization is conferred by this record for any act, past or future.

**Phase-A boundary.** This decision exists solely to unblock completion of **Phase A — Reality & Repository Hygiene** by allowing retirement of the legacy Supabase surface under current Product-Lead direction. It introduces no Canonical Context V2, no CURRENT-AUTHORITY architecture, no governance compression, no risk engine, no reviewer-policy redesign, no Agent Governance V2, no Engineering Quality and no External Skills or Advanced Orchestration work. Those belong to later phases and are out of scope here.
