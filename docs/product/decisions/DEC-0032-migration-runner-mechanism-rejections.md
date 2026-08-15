# DEC-0032 — Migration-runner mechanism rejections (successor authority for the durable content of historical DEC-0027 §3)

**Status:** ACTIVE (binding) · **Date:** 2026-08-15 · **Author:** Product Lead (ratified via Product Orchestrator)
**Scope:** Negative constraints on any NOXUND migration apply/verify mechanism. **Docs-only unit** — no database, Compose, SQL, role, runner install, workflow, Environment, secret, or remote connection is created or changed here.
**Extends:** [[DEC-0028]] §3/§8 (migration-runner proof requirements; OD namespace), [[DEC-0029]] (OD-5 = REJECT SQITCH), [[DEC-0030]] (Flyway rejected for least-privilege incompatibility). **Does not edit** any prior DEC record — all remain frozen and additive-only.
**Canonical base:** `main` @ `27518b86dbe830551a61dea2607e64351d7ab890`

---

## 1. Context and provenance

A historical decision record, authored 2026-07-28 for the SG-8 remote-promotion R0 preflight, recorded three binding mechanism rejections and closed them with the sentence *"These three are recorded so no future unit silently re-introduces them."*

That record **never landed on `main`**. It exists only as an immutable historical object:

> `2d0fbcd1eec1bf8f79451e0aa106c7b0a857dba7:docs/product/decisions/DEC-0027-sg8-remote-promotion-r0-preflight.md`

Its pull request, **PR #65** (head `2d0fbcd1eec1bf8f79451e0aa106c7b0a857dba7`, branch `feat/sg8-r0-preflight-author-production-db`), was **closed without merge** — `state: closed`, `merged: false`, closed `2026-07-30T12:25:01Z` — as `SUPERSEDED — NOT MERGED` under [[DEC-0028]].

[[DEC-0028]] neutralized that record's **remote-apply/verify intent**, because its apply/verify path targeted **managed Supabase**, which NOXUND is exiting. That neutralization is correct and remains in force.

**But the neutralization was scoped to the managed-Supabase execution path — not to the three architecture-neutral safety lessons in that record's §3.** Those three rejections are independent of Supabase, remain technically valid under vanilla PostgreSQL, and are directly load-bearing for the migration-runner work now in progress ([[DEC-0029]], [[DEC-0030]] and the PG-EXIT-P3C design line). Because the historical record is not on `main`, those constraints currently have **no canonical home**. This decision gives them one.

## 2. What this decision does and does not do

**Re-binds:** exactly the three architecture-neutral mechanism rejections of the historical record's §3, restated below as Rules 1–3, normalized to remove Supabase-specific nouns from their normative scope.

**Does not re-bind, import, promote or make canonical:**

- the historical record itself — it remains **HISTORY-ONLY-NO-LAND** and **NON-CANONICAL**, citable only by the commit SHA and path above;
- its §2 R0-AUTHOR deliverables, §5 out-of-scope list, §6 R0 verdict discipline as applied to the remote preflight, or §7 corrective — all bound to managed Supabase;
- its §4 open decisions (see §6 below);
- any executable artifact from its branch.

## 3. The three binding negative constraints

These are **negative, fail-closed constraints**. They bind **any** migration mechanism NOXUND may later adopt.

### Rule 1 — An apply mechanism must not be "apply, then hand-insert the ledger row"

A migration apply mechanism **MUST NOT** be defined as: execute the schema/migration change first, then — **outside a single jointly-committed transaction** — manufacture or insert its migration-ledger success record.

The schema effect and the authoritative migration-ledger record **MUST NOT** be split into an apply-then-hand-insert success path, in which the ledger row is produced by a distinct, manually-issued operation whose success is asserted rather than jointly guaranteed.

*Historical form (provenance only):* the rejected two-step was `psql` migration followed by a manual `INSERT` into `supabase_migrations.schema_migrations`. The Supabase-specific ledger table is **not** the normative scope; the rejected **mechanism shape** is.

### Rule 2 — The migration ledger must not treat a conflicting row as success

`ON CONFLICT DO NOTHING` (or any semantically equivalent construct) **MUST NOT** be used on the migration ledger as a means of treating a pre-existing or divergent ledger row as success.

Such a construct **silently masks** a divergent or pre-existing ledger state instead of failing closed. Divergence between the schema and its ledger **MUST** surface as a failure, never be absorbed into a green result.

### Rule 3 — Transaction ownership must be explicit and non-overlapping

An apply or verify design **MUST NOT** rely on overlapping, doubled or ambiguous ownership of the **same** transactional boundary — for example a client-level transaction wrapper, an external `BEGIN`/`ROLLBACK`, and the script's own internal transactional control all attempting to own one boundary.

Transaction ownership **MUST** be explicit and singular for any given boundary.

*Historical form (provenance only):* the rejected combination was `psql -1` + an external `BEGIN`/`ROLLBACK` + the verify's own internal transactional control.

## 4. What these rules do NOT say

Stated explicitly so the constraints are not over-read:

1. **Rule 1 is not** a prohibition on issuing more than one SQL statement, nor on ledgers generally. Its scope is the **apply mechanism plus authoritative migration-ledger semantics** — specifically the apply-then-hand-insert success shape.
2. **Rule 2 is not** a repository-wide ban on PostgreSQL `ON CONFLICT DO NOTHING`. That construct remains perfectly legitimate elsewhere. Its prohibition here is confined to **migration-ledger authority semantics**, where masking a conflict destroys fail-closed behaviour.
3. **Rule 3 is not** a ban on nested code abstractions, helper functions, or savepoints as such. It prohibits **overlapping ownership of the same transaction boundary** — the ambiguity, not the nesting.

## 5. No positive authorization

This decision is **negative-constraint only**. It authorizes nothing.

In particular it does **NOT** select, approve or endorse: `psql` as the final runner; Sqitch; Flyway; any other migration framework; any particular ledger schema; any particular transactional implementation; any PostgreSQL role model; any PG-EXIT-P3C implementation; nor the P3C review-round variants carried in the Product Lead's backlog as `R10-R1` / `R10-R2` (identifiers not yet defined by any canonical record on `main`; named here only to withhold endorsement, never to confer it).

**TECHNICAL ADOPTION = UNCHANGED / UNDECIDED WHERE ALREADY UNDECIDED.** Restating three rejections does not constitute approval of whatever remains. Every candidate mechanism must still satisfy [[DEC-0028]] §3's proof requirements on PostgreSQL 15 and must additionally honour Rules 1–3 above. [[DEC-0029]] §7 and [[DEC-0030]] continue to govern the successor-candidate status; **OD-7 remains OPEN**.

## 6. Open-decision namespace — historical vs current

The historical record's §4 used labels `OD-1` … `OD-5` with meanings **specific to the SG-8 remote-promotion sequence**. [[DEC-0028]] independently uses the same `OD-N` label space with **entirely different meanings**: its §8 open-decision table enumerates `OD-2` … `OD-7`, while `OD-1` appears in its §4 as a **decided** identity item, not an open decision.

Binding clarification:

1. The historical §4 `OD-N` labels are **HISTORICAL ONLY**.
2. They are **NOT** the same identifiers as [[DEC-0028]] §8's `OD-N`, and must never be conflated with them.
3. **No historical §4 open decision is promoted, adopted, closed or re-opened by this decision.** In particular, the historical `OD-4` secure-password-channel concern is **not** closed here; where relevant it remains **DEFER-POSTGRES-SUPABASE-HYGIENE**.
4. **[[DEC-0028]] §8 is the current `OD-N` namespace** where applicable, as amended by [[DEC-0029]] (OD-5 closed) and [[DEC-0030]].

## 7. Historical artifacts that remain non-canonical

None of the following is imported, restored or made current by this decision:

- the historical decision record itself (`2d0fbcd1eec1bf8f79451e0aa106c7b0a857dba7:docs/product/decisions/DEC-0027-sg8-remote-promotion-r0-preflight.md`);
- the historical R0 preflight report-format file at `2d0fbcd1eec1bf8f79451e0aa106c7b0a857dba7:docs/data/DATA-SG8-001-R0-preflight-report-format.md` — **historical, non-canonical, DO-NOT-LAND**. It must never be referred to by its bare record identity, because that identity already resolves on `main` to a **different** canonical record, `docs/data/DATA-SG8-001-sg8-design-contract.md`. Landing it would create a record-identity collision;
- the historical R0 workflows, `supabase/remote/**` artifacts, and SG-8 R0 handoff/review material — all **DO-NOT-LAND**, belonging to the exited managed-Supabase execution path.

## 8. Out of scope (this decision)

Any PostgreSQL/Supabase operational hygiene — workflows, migrations, rollbacks, verify scripts, environment files, `SUPABASE_DB_URL` naming, collector runtime, GitHub App configuration or the installed Supabase GitHub App (**DEFER-POSTGRES-SUPABASE-HYGIENE**) · `packages/orchestrator/**`, approver-provenance and consumption-ledger atomicity (**DEFER-PHASE-C**) · R10-R1 vs R10-R2 (**TECHNICAL-ADOPTION-UNDECIDED**) · Canonical Context V2 and `context/**` (**Phase B — NOT STARTED**) · any edit to [[DEC-0028]], [[DEC-0029]], [[DEC-0030]] or [[DEC-0031]] · any commit, push, PR or merge authorization.

---

*Related: [[DEC-0028]] (§3 runner proof requirements, §8 OD namespace), [[DEC-0029]] (REJECT SQITCH), [[DEC-0030]] (Flyway rejected — least-privilege). Historical provenance (non-canonical): `2d0fbcd1eec1bf8f79451e0aa106c7b0a857dba7:docs/product/decisions/DEC-0027-sg8-remote-promotion-r0-preflight.md`, PR #65 closed/unmerged. Companion: `DEC-0028-ADDENDUM-dec0027-provenance-and-successor.md`.*
