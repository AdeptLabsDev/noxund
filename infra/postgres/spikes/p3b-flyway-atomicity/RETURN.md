# PG-EXIT-P3B-EXECUTE — RETURN

**Verdict:** `ESCALATE — LEAST-PRIVILEGE CONTRACT NOT SUPPORTED`
**Status:** halted at the LP-0 eliminatory gate. The fatal atomicity test was **not reached** and ran **zero** times.
**Awaiting a new GO from the Product Lead. Nothing advances from here.**

> **Scope of this result (read carefully):** this is **NOT** a REJECT of Flyway on atomicity grounds.
> Flyway's DDL↔history atomicity was **never tested** — LP-0 gated it off first. The finding is narrower
> and specific to **NOXUND's exact least-privilege contract**.

---

## 1. Coordinates

| Item | Value |
|---|---|
| Branch | `spike/pg-exit-p3b-flyway-atomicity` |
| Artifacts commit | `3e0418020561eba17969f8034fe024334b5453a9` |
| Rig reporting fix | `68ede6552c5ab4a97f923b89c96d57f33eac846b` (definitive run SHA) |
| Evidence commit | `3f6ce0f0f8810ca03ca30c940add53c6790580cb` |
| Base | `main @ dfac2b43adf22e642ef1f8a078c5a3161bac8a77` |

## 2. Version / pinning / edition

| Item | Value |
|---|---|
| Flyway tag | `flyway/flyway:13.1.0` (latest versioned 13.x; `latest`/`13` refused) |
| Flyway digest | `sha256:3cc7587dcb678b67ab822984197237f84dfc65e0b19b98c52ea84d6ef8be1f4a` (running == pinned) |
| Edition | **OSS (Community)** — "Flyway OSS Edition 13.1.0 by Redgate" |
| Runtime / driver | OpenJDK 21.0.11 (Temurin) · `postgresql-42.7.12.jar` |
| PostgreSQL | `15.18` — `postgres:15.18-bookworm@sha256:b0c5bab0…` (running == pinned) |

## 3. LP-0 result

| Check | Result |
|---|---|
| `noxund_owner` NOLOGIN | ✅ t |
| `noxund_migrator` NOINHERIT | ✅ t |
| owner / migrator not superuser | ✅ t / t |
| migrator minimal (no createdb/createrole/super/replication/bypassrls) | ✅ t |
| no extra superuser beyond bootstrap `postgres` | ✅ t (0) |
| V1 migrate exit | ❌ 1 |
| `public.flyway_schema_history` owned by `noxund_owner` | ❌ table never created |
| `spike` schema owned by `noxund_owner` | ❌ V1 never applied |

**LP-0 = FAIL** ⇒ ESCALATE. Per Bloco 2/3: no `postgres` migration identity, no trigger, no V2, **no workaround**, no auto-rerun.

## 4. Callback

The **Flyway-13 correction was honored**: no `flyway.initSql`; identity established by
`callbacks/afterConnect__set_noxund_owner.sql` = `SET ROLE noxund_owner;`. The callback **is** discovered and
executed (`Executing SQL callback: afterConnect - set noxund owner`).

## 5. Root cause (the callback boundary the Lead flagged — proven executably)

Flyway 13 creates `public.flyway_schema_history` on its **metadata-table connection**, and the `afterConnect`
`SET ROLE noxund_owner` is **not in force there**. The history table is therefore created as `noxund_migrator`,
which — by the least-privilege contract — holds **no direct CREATE on `public`**:

```
Executing SQL callback: afterConnect - set noxund owner
Creating Schema History table "public"."flyway_schema_history" ...
SQL State : 42501
Message   : ERROR: permission denied for schema public
```

Independently proven on the same stack:
- `SET ROLE noxund_owner` **does** work and owner **can** create in `public` (`owner_create_public = t`);
- `noxund_migrator` has **no** direct create (`migrator_direct_create_public = f`).

The only way to make Flyway create its own history table here is to grant `noxund_migrator` a **direct DDL
privilege on `public`** — exactly the "privilégio direto excessivo" the contract forbids. That is a **contract
change**, not a runner test, so it is **not** attempted (no workaround).

## 6. Not reached (correctly gated by LP-0)

PID/XID equality proof · prepared xacts / orphan locks / idle-in-transaction inspection · `info` / `validate` /
fresh-migrate · the SIGKILL fatal step. **The fatal atomicity test ran zero times.**

## 7. Timeline (UTC, run @ 68ede65)

```
19:50:21 postgres up (internal net, no ports)
19:50:29 postgres healthy
19:50:29 LP-0: flyway migrate -target=1
19:50:41 V1 migrate exit=1  (CREATE flyway_schema_history -> 42501 permission denied)
19:50:45 VERDICT: ESCALATE — LEAST-PRIVILEGE CONTRACT NOT SUPPORTED
         (no trigger, no V2, no workaround)
```

## 8. Isolation / safety / hygiene

Project `noxund-p3b`, DB `flyway_spike`, network `internal: true` (no egress), no published port, disposable
project-scoped volume. `noxund-local` untouched. Secret only via Compose secret; **no secret in the evidence
bundle** (scanned); Flyway masked the DB/password. `REDGATE_DISABLE_TELEMETRY=true`; no token/PAT/login/licence.
Teardown project-scoped only (never `docker volume prune`). Sentinel refused `clean` (exit 90) in review. Working
tree clean.

## 9. Evidence bundle (`evidence/`, committed @ 3f6ce0f)

`VERDICT.txt` · `ESCALATE-rootcause.md` · `lp0-checks.out` · `lp0-rootcause-flyway.txt` ·
`flyway-v1-migrate.out` · `image-identity.txt` · `run-transcript.log`.

## 10. Pareceres (multi-role)

**Product Orchestrator.** The thesis is protected: a runner that cannot even create its own ledger under our
non-negotiable least-privilege identity (runtime never owner, minimal migrator) is not adoptable as-is, and no
number/provenance guarantee should rest on relaxing that identity silently. The honest framing matters —
**this is a contract-support failure, not an atomicity falsification**; Flyway's atomicity is still **unknown**.
**ESCALATE.** Awaiting Lead decision; no advance.

**Database.** Correct and reproducible. Flyway splits work across a metadata connection and a user-objects
connection; `SET ROLE` from `afterConnect` did not govern the metadata DDL, so the history table create ran as
the login role. Owner-owned `public` + minimal migrator is a sound model; Flyway's ledger bootstrap simply does
not fit it without a direct grant. **ESCALATE.**

**Security & Privacy.** Posture held throughout: least-privilege proven (owner NOLOGIN, migrator
NOINHERIT/minimal, no superuser migration), no-egress network, secret never exposed (bundle scan clean, JDBC
masked), disposable isolation, no Redgate identity. The refusal to grant the migrator direct DDL to "make it
work" is the right fail-closed call. **ESCALATE.**

**DevOps/Infra.** Pinning discipline held (tag+digest, running==pinned for both images); `latest`/floating
refused; no bespoke image. The executable sentinel (clean/repair/baseline/undo) and the secret wrapper behaved.
A runner that needs elevated DDL to self-bootstrap is a CI trust cost to weigh. **ESCALATE**; hold any further
implementation for a new gated unit.

**QA.** Verdict rests on observed facts only: `flyway -v` edition, image digests, LP-0 catalog booleans,
V1 exit=1, SQLSTATE 42501, and the two `has_schema_privilege` probes. The fatal test was correctly **not** run.
The first run (exit 1) was a harness *reporting* defect, fixed at `68ede65`; the definitive run reproduces the
ESCALATE deterministically. **ESCALATE.**

## 11. Options for the Lead (NOT chosen here — require a new GO)

1. **Amend the least-privilege contract for Flyway** in a controlled way (e.g. a dedicated `flyway`-owned
   history schema, or a scoped CREATE grant limited to a single history schema) and re-run P3B — this is a
   **contract change** and needs explicit approval.
2. **Test Flyway with a different identity mechanism** (still no `initSql`) — needs approval; the current
   approved `afterConnect` mechanism is falsified for the metadata connection.
3. **Pivot to the single-session transactional psql runner** candidate (DEC-0029 §7 #2), which by construction
   uses one connection / one identity / one transaction — no metadata-connection split.

**Flyway's DDL↔registry atomicity remains untested. No REJECT, no adoption, no P3C. Awaiting a new GO.**
