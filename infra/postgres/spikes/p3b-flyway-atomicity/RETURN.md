# PG-EXIT-P3B2 — RETURN

**Verdict:** `ESCALATE — LP-1 CONTRACT NOT SUPPORTED`
**Status:** halted at the LP-1 eliminatory gate. The fatal atomicity test was **not reached** and ran **zero** times.
**Awaiting a new GO from the Product Lead. Nothing advances.**

> **Scope (read carefully):** this is **NOT** a REJECT of Flyway on atomicity — LP-1 gated the fatal test.
> Flyway's DDL↔ledger atomicity remains **UNTESTED** (untested in P3B and again in P3B2). The finding is
> about the **identity mechanism**: Flyway 13's `afterConnect SET ROLE` does not persist into its migration
> transaction, so migrations execute as the login role `noxund_migrator`, never `noxund_owner`.
>
> *(Predecessor P3B return preserved at commit `d391f2b`.)*

---

## 1. Coordinates

| Item | Value |
|---|---|
| Branch | `spike/pg-exit-p3b-flyway-atomicity` (local only; no PR/merge/push) |
| P3B2 artifacts commit (**run SHA**) | `52c561307c2c95401ea88e2d510011bfea00c878` |
| P3B2 evidence commit | `bd2fb50df991f06689f7eeb1fcaeadaaf26fbecc` |
| Preserved prior commits | `3e04180` · `68ede65` · `3f6ce0f` · `d391f2b` (no amend/rebase/force-push) |
| Base | `main @ dfac2b43…` (main untouched; Sqitch spike untouched) |

## 2. Diff (P3B2 artifact commit `52c5613`, vs parent `d391f2b`)

```
flyway/conf/flyway.conf        |   8 +-   (defaultSchema+schemas=noxund_migration_meta, table=flyway_schema_history, createSchemas=false)
harness/instrument.sql         |   2 +-   (BEFORE INSERT trigger -> noxund_migration_meta.flyway_schema_history)
harness/run-p3b.sh             | ~192     (LP-0 -> LP-1; meta ledger refs; exact grant capture; ESCALATE/REJECT classifier)
init/10_bootstrap_spike.sh     |  16 +    (control schema + grants; runtime roles noxund_app/sg8_compute_writer for LP-1 checks)
README.md                      |  42 +-   (P3B2 addendum; LP-1)
```

## 3. Version / pinning / edition (running == pinned)

`flyway/flyway:13.1.0@sha256:3cc7587dcb678b67ab822984197237f84dfc65e0b19b98c52ea84d6ef8be1f4a` — **OSS (Community)**,
OpenJDK 21.0.11, driver `postgresql-42.7.12.jar` · PostgreSQL `15.18` @ `sha256:b0c5bab0…`.

## 4. Exact grants of the control schema (`noxund_migration_meta`)

```
owner   = noxund_owner
nspacl  = noxund_owner=UC/noxund_owner | noxund_migrator=UC/noxund_owner
migrator USAGE=t  CREATE=t
app      USAGE=f  CREATE=f
sg8      USAGE=f  CREATE=f
migrator CREATE on public = f
migrator CREATE on spike  = (no spike created — V1 never applied)
```

Matches the DEC exactly: `noxund_migrator` has **only** USAGE+CREATE on `noxund_migration_meta`; no PUBLIC entry; no
`noxund_app`/`sg8_compute_writer` access; no equivalent grant in `public`.

## 5. LP-1 result

| Check | Result |
|---|---|
| history present, in `noxund_migration_meta` | ✅ t / t |
| **history owned by `noxund_migrator`** | ✅ noxund_migrator |
| migrator cannot create in `public` / `spike` | ✅ t / t |
| migrator CREATE + USAGE on `noxund_migration_meta` | ✅ t / t |
| `noxund_app` / `sg8_compute_writer` no schema priv | ✅ t / t |
| `noxund_app` / `sg8_compute_writer` no ledger access | ✅ t / t |
| no extra superuser · meta owner = owner · `createSchemas=false` | ✅ t / t / t |
| **V1 migrate exit** | ❌ 1 |
| **V1 executed as `noxund_owner`** | ❌ ran as `noxund_migrator` |
| V1 objects (`spike`) owned by `noxund_owner` | ❌ spike never created |

**LP-1 = FAIL** (only on the executor-identity requirement) ⇒ ESCALATE. Per Bloco: no privilege expansion, no
`postgres` identity, no trigger, no V2, no auto-rerun.

## 6. Owners (history + V1 objects)

- `noxund_migration_meta.flyway_schema_history` → **owned by `noxund_migrator`** (metadata connection created it as migrator — the control-schema fix works).
- V1 objects → **none** (`spike` schema never created; V1 aborted at its own guard).

## 7. Root cause (proven executably)

The `afterConnect` callback runs `SET ROLE noxund_owner` (confirmed in the `-X` trace, on each Flyway connection),
but it does **not persist into Flyway's migration transaction**. The V1 fail-closed guard observed:

```
ERROR: P3B least-privilege contract violated: session_user=noxund_migrator, current_user=noxund_migrator
```

So Flyway 13 executes migrations as the **login role** `noxund_migrator`, never `noxund_owner`. This is the same
`afterConnect SET ROLE` non-persistence seen in P3B (there it broke ledger creation on the metadata connection;
here, with the ledger relocated to `noxund_migration_meta`, it breaks the **executor** connection). Making Flyway
run migrations as owner under this mechanism is not achievable without either a different identity mechanism (the
approved contract forbids `flyway.initSql`) or granting `noxund_migrator` direct DDL on the application schemas
(a REJECT condition — no workaround attempted).

## 8. Not reached (correctly gated by LP-1)

Instrumentation install · PID/XID equality proof · `info`/`validate`/fresh-migrate · locks / sessions /
prepared-xacts inspection · the SIGKILL fatal step. **The fatal atomicity test ran zero times.**

## 9. Timeline (UTC, run @ 52c5613)

```
01:21:14 postgres up (internal net, no ports)
01:21:22 postgres healthy; control-schema grants captured (all correct)
01:21:27 LP-1: flyway migrate -target=1
01:21:30 V1 migrate exit=1  (ledger created in meta as migrator; V1 guard: current_user=noxund_migrator)
01:21:36 VERDICT: ESCALATE — LP-1 CONTRACT NOT SUPPORTED  (no trigger, no V2, no privilege expansion)
```

Exit codes: V1 migrate = **1**; harness = **4** (ESCALATE-LP1).

## 10. Isolation / safety / hygiene

Project `noxund-p3b`, DB `flyway_spike`, network `internal: true` (no egress), no published port, disposable
volume. `noxund-local` untouched. Secret only via Compose secret; **no secret in the evidence bundle** (scanned).
`REDGATE_DISABLE_TELEMETRY=true`; no Redgate token/login. Teardown project-scoped only (never `docker volume prune`).
Working tree clean; disposable secrets removed.

## 11. Evidence bundle (`evidence/`, committed @ bd2fb50)

`VERDICT.txt` · `LP1-FAIL-rootcause.md` · `lp1-checks.out` · `lp1-rootcause-flyway.txt` · `control-schema-grants.txt` ·
`flyway-v1-migrate.out` · `image-identity.txt` · `run-transcript.log`.

## 12. Pareceres (multi-role)

**Product Orchestrator.** Option A closed the ledger-creation gap exactly as intended (ledger isolated in
`noxund_migration_meta`, migrator scoped, runtime roles walled off), but exposed the load-bearing fact: under the
approved `afterConnect SET ROLE` mechanism Flyway runs **every migration as the login role**. The contract requires
the executor to be `noxund_owner`; Flyway cannot honor that here without a mechanism change or an excessive grant.
Honest framing: still **not** an atomicity result. **ESCALATE.**

**Database.** `SET ROLE` is session-scoped but reverts if its transaction is rolled back; Flyway's callback/transaction
handling leaves `current_user=noxund_migrator` at migration time. The ledger now lives correctly in the control schema
owned by migrator, but the executor identity is wrong. A mechanism that survives into the migration transaction (or a
role model where the login role IS the intended object owner) would be needed. **ESCALATE.**

**Security & Privacy.** The restricted contract held perfectly: migrator confined to `noxund_migration_meta`, zero
DDL on `public`/`spike`, runtime roles with no ledger access, no superuser, no-egress, secret-clean bundle. The guard
fail-closed exactly as designed. Refusing to widen grants to force success is the correct call. **ESCALATE.**

**DevOps/Infra.** Pinning held (running==pinned); `createSchemas=false` verified; sentinel + secret wrapper intact.
An engine that only runs migrations as its login role constrains the whole least-privilege story for CI — material
for the Lead's mechanism decision. **ESCALATE**; hold implementation.

**QA.** Facts only: control-schema ACL, LP-1 booleans, V1 exit=1, SQLSTATE P0001 guard message
(`current_user=noxund_migrator`), harness exit 4. Fatal test correctly not run; reproducible from `52c5613`. **ESCALATE.**

## 13. Options for the Lead (NOT chosen — require a new GO)

1. **Change the identity mechanism** so the owner role governs the migration transaction (e.g. a role model where the
   Flyway login role directly owns migration objects in the application schemas under a tightly-scoped grant; or a
   Flyway mechanism other than `afterConnect SET ROLE`). Note the approved contract forbids `flyway.initSql`.
2. **Accept that Flyway executes as the login role** and redesign the least-privilege model around that (login role =
   constrained object owner) — a contract change requiring approval.
3. **Pivot to the single-session transactional psql runner** (DEC-0029 §7 #2): one connection / one identity / one
   transaction — no callback-persistence problem and no metadata/executor split.

**Flyway's DDL↔ledger atomicity remains untested. No REJECT, no adoption, no P3C. Awaiting a new GO.**
