# DEC-0028 · Traceability addendum — provenance of the two historical DEC-0027 references, and their successor authority

- **Date:** 2026-08-15
- **Status:** **Registered.** Additive to `DEC-0028` (does **not** alter the decision, its body, or any artifact it froze). Interpretation-only. **No new decision is introduced by this addendum** — the current normative content lives in [[DEC-0032]].
- **Decisor:** Product Lead · registered by the Product Orchestrator
- **Scope:** the meaning of the two pre-existing references to the identifier `DEC-0027` inside the frozen `DEC-0028` body. **Does not** authorize any migration, workflow, environment, runtime, database or Supabase change; **does not** promote any historical artifact to canonical authority.
- **Canonical base:** `main` @ `27518b86dbe830551a61dea2607e64351d7ab890`
- **Relates:** `DEC-0028-pg-exit-p1-supabase-removal-postgres-vanilla.md` (frozen body, blob `29f7a387d62284b90a763d9afc2b7c2d0cdad2e2`) · [[DEC-0032]] (successor authority) · [[DEC-0029]] · [[DEC-0030]] · `DEC-0024-ADDENDUM-migration-ordering-policy.md` (addendum convention precedent)

---

## Context

`DEC-0028` contains **exactly two** references to the identifier `DEC-0027`:

| Location | Reference |
|---|---|
| **Line 5** (`Supersedes/extends`) | *"Neutralizes the remote-apply intent of … (SG-8 R0 remote promotion) — its apply/verify path targeted managed Supabase and is now moot."* |
| **Line 141** (`Related` footer) | listed among the related decisions, alongside that record's note of frozen artifacts and PR #65 |

No decision record bearing that identifier has ever existed on `main`. Read literally and without context, those two references appear to point at current authority that cannot be found — which risks either a reader concluding the record was lost, or a future unit "repairing" the gap by landing the historical document and thereby creating a second active decision identity.

`DEC-0028` is **frozen and additive-only** — a discipline `DEC-0029` and `DEC-0030` each restated explicitly. It is therefore **not edited** to resolve this. This addendum adjudicates the meaning of the two references instead.

## Registered interpretation

1. **Both references are HISTORICAL PROVENANCE, not current authority.** They denote the immutable historical object:
   `2d0fbcd1eec1bf8f79451e0aa106c7b0a857dba7:docs/product/decisions/DEC-0027-sg8-remote-promotion-r0-preflight.md`

2. **The historical record was never merged.** Its pull request, **PR #65** (head `2d0fbcd1eec1bf8f79451e0aa106c7b0a857dba7`, branch `feat/sg8-r0-preflight-author-production-db`), is `state: closed`, `merged: false`, closed `2026-07-30T12:25:01Z` as `SUPERSEDED — NOT MERGED`.

3. **The two references do NOT imply that record exists as canonical authority on `main`.** It remains **HISTORY-ONLY-NO-LAND** and **NON-CANONICAL**. It must be cited only by the full commit SHA and exact path above — never as a resolvable current decision link.

4. **`DEC-0028`'s neutralization is scoped to the managed-Supabase remote apply/verify promotion intent** — the path that targeted the managed project and is moot after the PostgreSQL exit. It was **not** a neutralization of that record's architecture-neutral §3 mechanism rejections.

5. **Those three §3 mechanism rejections are now current through [[DEC-0032]]**, restated as architecture-neutral, fail-closed negative constraints: (a) no apply-then-hand-insert migration-ledger success path; (b) no `ON CONFLICT DO NOTHING` success-masking on the migration ledger; (c) no overlapping or ambiguous ownership of a single transaction boundary.

6. **Readers seeking current migration-runner negative constraints must use [[DEC-0032]]**, not the historical record. `DEC-0028` §3's proof requirements and the rulings of [[DEC-0029]] and [[DEC-0030]] continue to apply unchanged.

7. **Open-decision namespaces are distinct.** The historical record's §4 used labels `OD-1`…`OD-5` with SG-8-remote-promotion meanings. `DEC-0028` independently uses the same `OD-N` label space with different meanings — its §8 open-decision table enumerates `OD-2`…`OD-7`, while `OD-1` appears in its §4 as a **decided** identity item rather than an open decision. The two sets are **not** the same identifiers and must never be conflated. **`DEC-0028` remains the current `OD-N` namespace** where applicable, as amended by [[DEC-0029]] (OD-5 closed) and [[DEC-0030]]. No historical §4 open decision is promoted or closed by this addendum.

8. **`DEC-0028`'s body remains authoritative and byte-frozen.** This addendum adds interpretation; it removes, rewrites and supersedes nothing. The two references stay exactly as written, as the record of what was true on 2026-07-30.

## Consequences

- The two unresolved references inside `DEC-0028` are **expected and permanently classified**. Reference-integrity checks over `docs/product/decisions/**` must treat them as **classified historical provenance**, not as defects, and must **not** be "fixed" by introducing a current record under that identifier.
- The correct invariant for future checks is therefore: *unclassified* unresolved decision references = **0**; the two classified references inside the frozen `DEC-0028` body are permitted, and no new reference of that kind may be introduced anywhere.
- No file is modified by this addendum. It is additive, in the form already established by `DEC-0024-ADDENDUM-migration-ordering-policy.md`.
