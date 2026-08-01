# DEC-0030 — PG-EXIT-P3B: Flyway rejected under NOXUND least-privilege contract

**Status:** ACTIVE (binding) · **Date:** 2026-08-01 (UTC; runs cross local midnight of 2026-07-31) · **Author:** Product Lead (ratified via Product Orchestrator)
**Scope:** Closes the Flyway Community candidacy under NOXUND's requirements. **Docs-only unit** — no database, Compose, SQL, role, workflow, Environment, secret, remote connection, or runner implementation is created or changed here. This record **points to** preserved evidence; it does **not** copy the bundle onto `main`.
**Extends:** [[DEC-0029]] §7 (successor candidates: Flyway Community; single-session transactional psql runner) and [[DEC-0028]] §3/§8 (migration-runner proof requirements; OD-5/OD-7). **Does not edit** prior DEC records (frozen, additive-only).
**Predecessor units:** PG-EXIT-P3B-EXECUTE (Flyway atomicity falsification) → PG-EXIT-P3B2 (metadata-schema + atomicity falsification, Option A restricted contract).

---

## 1. Context

DEC-0029 registered **Flyway Community** as one of two *unchosen* successor candidates after Sqitch was rejected (OD-5 = REJECT SQITCH), with the binding condition that any successor **prove itself executably on PostgreSQL 15** and honor NOXUND's non-negotiable least-privilege identity: a **login** role `noxund_migrator` (NOINHERIT, never superuser) that assumes the **NOLOGIN owner** `noxund_owner` only for the duration of a migration, so migration objects are owned by `noxund_owner` and the persistent CI credential never holds ownership or direct DDL on the application schemas.

Two executable spikes were authorized and run (isolated, disposable, no-egress; `noxund-local` untouched; no remote/Supabase; no superuser migration; no workaround):

- **P3B-EXECUTE** — Flyway `13.1.0` Community, identity via the approved `afterConnect` SQL callback (`SET ROLE noxund_owner`; `flyway.initSql` forbidden by the approved contract).
- **P3B2** — same, plus the Product Lead's **Option A restricted contract**: a dedicated control schema `noxund_migration_meta` where `noxund_migrator` holds **only** `USAGE, CREATE` (the ledger's home), with **no** direct DDL on `public`/`spike`/business schemas.

## 2. Decision (binding)

1. **Flyway Community is REJECTED as NOXUND's authoritative migration runner** — for **incompatibility with the least-privilege contract**, not for an atomicity failure.
2. **The fatal DDL↔`flyway_schema_history` atomicity test executed ZERO times.** Flyway's atomicity **remains UNTESTED.** An eliminatory requirement (least-privilege identity) failed **before** another eliminatory requirement (atomicity) could be reached — which is sufficient to close the candidate.
3. **The Product Lead declined to weaken the contract to accommodate the tool** (rejecting the alternative options A2/B). Adapting NOXUND's security posture to a tool's internal behavior inverts the architectural priority.
4. **Chosen successor candidate for evaluation: the single-session transactional psql runner** (§6) — registered as *candidate*, **not adopted**.

## 3. What was proven (executably)

| Fact | P3B | P3B2 |
|---|---|---|
| `afterConnect` callback discovered + executed (`SET ROLE noxund_owner`) | yes | yes |
| Ledger created under the contract | **NO** — metadata connection ran as `noxund_migrator`, which lacked CREATE on `public` → `flyway_schema_history` creation failed (`SQLSTATE 42501`) | **YES** — with the control schema, the metadata connection (as `noxund_migrator`) created `noxund_migration_meta.flyway_schema_history`, owned by `noxund_migrator` |
| Migration executed as `noxund_owner` | not reached | **NO** — V1 ran with `current_user=noxund_migrator`; the V1 fail-closed guard aborted (`SQLSTATE P0001`) |
| Fatal atomicity test | not reached | not reached |
| Superuser / excessive grant / workaround used | none | none |

**Common root cause (§4):** the approved `afterConnect SET ROLE noxund_owner` does **not govern** either the connection that creates the metadata ledger (P3B) or the transaction that executes the migration (P3B2).

The P3B2 control-schema half was otherwise **exactly correct**: schema owner `noxund_owner`; ACL `noxund_owner=UC` + `noxund_migrator=UC`; **no PUBLIC** grant; `noxund_app` and `sg8_compute_writer` with **no** schema privilege and **no** ledger access; `noxund_migrator` with **no** CREATE on `public`/`spike`; no extra superuser; `createSchemas=false`.

## 4. Root cause (source-observed)

Flyway 13's `afterConnect` callback runs `SET ROLE noxund_owner` on each connection (confirmed via `-X`), but the effect **does not persist into Flyway's migration transaction** — by migration time `current_user` has reverted to the login role `noxund_migrator` (`SET ROLE` is undone when its enclosing transaction is not retained). Consequently **Flyway executes migrations as the login role**, never as `noxund_owner`. Accommodating Flyway would require either making the persistent login role the object owner, or granting `noxund_migrator` direct DDL on the application schemas — both of which dissolve the separation between `noxund_migrator` and `noxund_owner` that the contract exists to enforce.

## 5. Authoritative evidence (referenced, not copied to `main`)

The full artifacts, transcripts and dumps live on the preserved spike branch — this record points to them and does **not** duplicate the bundle onto `main`.

| Item | Value |
|---|---|
| Preserved branch | `spike/pg-exit-p3b-flyway-atomicity` (local **and** `origin`, tip `e8c72f1`) |
| P3B execution (run SHA) | `68ede65` |
| P3B evidence | `3f6ce0f` |
| P3B return | `d391f2b` |
| P3B2 execution (run SHA) | `52c5613` |
| P3B2 evidence | `bd2fb50` |
| P3B2 return | `e8c72f1` |
| Flyway | `flyway/flyway:13.1.0@sha256:3cc7587dcb678b67ab822984197237f84dfc65e0b19b98c52ea84d6ef8be1f4a` — OSS/Community, JDK 21.0.11, driver `postgresql-42.7.12` (running == pinned) |
| PostgreSQL | `15.18` — `postgres:15.18-bookworm@sha256:b0c5bab0…` (running == pinned) |
| Identity | migrations attempted as `noxund_migrator`; **no superuser**; disposable project `noxund-p3b` (internal net, no host port); `noxund-local` untouched; teardown project-scoped, never `docker volume prune` |

No credentials appear in the bundle (secret scan clean; JDBC password masked in Flyway output).

## 6. Successor runner — candidate CHOSEN for evaluation (NOT adopted)

**Single-session transactional psql runner.** Registered as the candidate to evaluate next; **adoption is NOT recorded here.** Conceptual contract (all in **one** PostgreSQL session / **one** transaction):

```
one connection
  → advisory lock
  → verify ledger
  → SET LOCAL ROLE noxund_owner
  → run migration SQL
  → INSERT into the ledger
  → COMMIT   (joint rollback of DDL + ledger on ANY failure)
login role = noxund_migrator ; objects owned by noxund_owner ; NO artisanal SQL parser
```

By construction this eliminates the failure classes seen so far: no separate metadata connection, no identity callback that fails to persist, no accidental ownership by the CI login, and no external window between the migration and the ledger write.

## 7. Eliminatory risk for P3C (recorded, binding for the future design)

Before any P3C GO, the successor **design** must resolve — **without building an artisanal SQL parser**:

- migrations **must not** control their own transaction;
- migrations **must not** change connection;
- migrations **must not** execute shell metacommands;
- the design must prove how it prevents `COMMIT`, `ROLLBACK`, `\connect`, `\!` and equivalents from escaping the controlled transaction;
- **a documentation-only policy is NOT sufficient**;
- the runner **may not claim atomicity** if a migration file can terminate the external transaction.

This is an **eliminatory** condition of P3C.

## 8. Open decisions (kept explicitly OPEN)

Registered as open for the successor unit — **none decided here**:

- runner implementation: `psql` vs `libpq`/`psycopg` vs another thin client;
- exact ledger format;
- checksum and manifest strategy;
- locking and timeout;
- per-version application;
- reversal/undo strategy;
- **OD-7** (final form of verifies and cross-cutting/transversal tests) — remains OPEN, to be decided *with* the successor runner (never on Flyway or Sqitch semantics).

## 9. Spike preservation (binding)

- The Flyway spike branch is **published to `origin`** at tip `e8c72f1` after: confirming the tip, re-running the secret scan (no credentials/tokens/passwords/sensitive URLs), and with **no** rebase/amend/force-push and **no** PR opened from the spike branch.
- **Do not** delete, rebase, amend, force-push or merge the spike branch (local or remote).
- **Do not** open a PR from the spike branch.
- **No** manual DB intervention; no re-run; no new containers; no remote/Supabase connection.

## 10. Pareceres (multi-role review)

**Product Orchestrator.** The candidate is closed on the correct grounds: a runner that cannot honor the migrator→owner separation on its own connections is incompatible with our provenance/least-privilege posture, independent of atomicity. The honest record — *incompatibility, atomicity untested* — preserves analytical credibility and does not overclaim. Pivoting to the single-session transactional runner puts the architecture ahead of the tool. **APPROVE (docs-only).**

**Database.** Two connections + a non-persisting `SET ROLE` are structural in Flyway 13, not configuration noise. The single-session model (one connection, `SET LOCAL ROLE`, DDL + ledger + COMMIT together) is the architecturally aligned answer and the only way to get true joint atomicity with correct ownership. The P3C transaction-escape risk is real and must be answered by design, not prose. **APPROVE.**

**Security & Privacy.** Refusing A2/B is the right call: both would push ownership or direct DDL onto the persistent CI login, eroding the exact separation SEC-0001/§0 relies on. The spikes upheld least-privilege, no-egress isolation, and a credential-free evidence bundle; publishing the spike branch only after a clean secret scan is correct. **APPROVE (docs-only).**

**DevOps/Infra.** Pinning held throughout (tool+image by digest, running==pinned). Rejecting a runner that executes as its login role removes a CI trust risk. For P3C: the transaction-escape guard must be executable (the runner must make it impossible for a migration file to end the outer transaction), not a policy note. **HOLD** any implementation until a P3C GO. **APPROVE** the direction.

**QA.** The verdict rests on observed facts only: image edition/digests, control-schema ACL, LP-1 booleans, `SQLSTATE 42501` (P3B) and `P0001` guard with `current_user=noxund_migrator` (P3B2), exit codes, and a clean secret scan. The fatal atomicity test correctly ran zero times; both results reproduce from the referenced SHAs. **APPROVE.**

## 11. Out of scope (this unit)

Merge of this PR · any DB/remote/Supabase connection · any new container run · runner implementation (psql/libpq/other) · creation of P3C · any change to migrations, roles, Compose, workflows, Environments or secrets · any edit to the spike branch or its evidence · any edit to prior DEC records or `context/` source-of-truth files.

---

*Related: [[DEC-0028]] (§3/§8 runner proof, OD-5/OD-7), [[DEC-0029]] (REJECT SQITCH, successor candidates). Preserved evidence: `spike/pg-exit-p3b-flyway-atomicity` @ `e8c72f1` (local + origin). Successor candidate (unchosen for adoption): single-session transactional psql runner. OD-7 remains OPEN. Flyway's DDL↔ledger atomicity remains UNTESTED.*
