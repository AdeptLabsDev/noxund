# PG-EXIT-P3C-DESIGN-R3 — CLOSEOUT (TM-A binding)

**Unit:** design-only closeout (read-only; this file saved per explicit Product Lead instruction). **Base:** `4873ac713397cf47642d39b1ef17e48a9301511d`. **Authorizes nothing executable.** Identifiers below are a **design proposal**, not created objects.

> **Note on the R3 preservation file.** The earlier file `docs/result/03-PG-EXIT-P3C-DESIGN-R3.md` is **absent from disk** at closeout time (verified via `find`/`ls`), although the closeout instruction refers to it as an existing preservation file and the IDE reported it open. This closeout was **not** the cause (no delete/move performed). To avoid any loss, this file is made **self-contained** (it restates the retained design). The R3 file was **not** recreated or modified, per the "do not modify the authorized result-preservation file" instruction — please confirm whether its removal was intentional or whether the full R3 report should be re-saved.

---

## 1. Authorized Markdown save — not a scope violation

Confirmed. The Product Lead explicitly instructed saving the complete result to a `.md` file to avoid VS Code terminal truncation. That save (and this one) is an **authorized result-preservation action**, not an unauthorized scope change, and is **not** classified RED. No scope audit is applied to it.

## 2. TM-A is now binding

Confirmed. **TM-A — trusted migrator principal** is the binding trust boundary for PG-EXIT-P3C.
- **Trusted:** the runner implementation and process; the client-held manifest; the expected artifact checksum; the `noxund_migrator` credential; the authorized runner environment; PostgreSQL bootstrap/administrative authority.
- **Hostile / potentially malformed:** the **migration artifact** (may attempt transaction, role, session-state and ledger attacks).

## 3. TM-B and the `pgcrypto` signature proposal — removed from P3C

Confirmed removed. The R3 TM-B sketch (client-held signing key + public-key verification via `pgcrypto` + server-stored public key) is withdrawn. **Correction accepted:** PostgreSQL 15 `pgcrypto` does **not** provide a digital-signature (public-key sign/verify) mechanism — the R3 proposal assumed a capability that does not exist in `pgcrypto` 15. No silent substitute is adopted: **not** HMAC, **not** a symmetric server-held secret, **not** a custom GUC, `application_name`, a temporary object, an advisory lock, or a caller-supplied nonce — none of which is non-forgeable by the `noxund_migrator` principal. Any future principal-resistant migration-authorization model is a **separately authorized architectural unit** with its own threat model, trust anchor, key/secret custody, rotation contract, replay protection, canonical signed payload, and failure/recovery design. **TM-B is removed from PG-EXIT-P3C, not retained as a fallback.**

## 4. Corrected R3 decision and terminology

**PG-EXIT-P3C-DESIGN-R3 = PASS — viable candidate under the explicitly selected TM-A trusted-principal model.** This PASS is **design coherence only**; it does **not** prove runtime properties and does **not** authorize implementation or adoption.

**Accepted terminology (use):** trusted-principal model · artifact-resistant ledger · atomic and linear under TM-A · direct-principal invocation is an accepted limitation.

**Ledger described as:** atomic with the corresponding migration transaction · globally linear · append-only · resistant to transaction escape by the artifact · resistant to ledger alteration by the artifact · protected by server-enforced role/privilege boundaries · records at most one surviving entry per top-level transaction · **not** cryptographic proof against an independently malicious holder of the `noxund_migrator` credential.

**Must NOT be described as:** execution-proven · principal-resistant · cryptographic proof that the runner executed the migration · proof against credential compromise.

## 5. Accepted trust limitation (concise)

Under TM-A, a session authenticated as `noxund_migrator` can invoke `record_migration()` **directly, outside the trusted runner**, and — if head, predecessor and uniqueness checks pass — commit a structurally valid ledger row **without executing an artifact**. This is **technically possible and accepted** as outside the TM-A threat boundary. **Rationale:** `noxund_migrator` may already assume `noxund_owner` to execute application-schema DDL, so a compromised credential can alter the schema directly regardless of the ledger API; protecting only the ledger append would not protect the schema. Credential compromise is therefore an **operational-security** matter (secret custody, environment access, rotation, runner integrity, CI authorization, audit/incident response), **not** part of the hostile-artifact boundary P3C evaluates.

## 6. Final retained design (self-contained)

### 6.1 Transport & artifact
Semantic transport authority = libpq **`PQexecParams`** (extended protocol; server rejects >1 command — "at most one SQL command"). Zero-parameter artifacts still use the extended protocol; the **default parameterless psycopg `Cursor.execute()` path is rejected** (it uses the simple protocol → multi-statement). One artifact = exactly **one** server-accepted command; required command **tag = `DO`**; multi-operation migrations live inside **one** PL/pgSQL `DO` block; **no** SQL parser, regex blacklist, or home-built statement splitter.

### 6.2 Connection & transaction
One **fresh** connection per migration · one backend PID · one top-level transaction · one top-level XID · **no** automatic reconnect · **no** silent replacement transaction · connection **closed unconditionally** after success or failure · never reuse the backend.

### 6.3 Role graph
| Role | Attrs | Member of | Owns |
|---|---|---|---|
| `noxund_migrator` | LOGIN, NOINHERIT | **`noxund_owner`** only | nothing |
| `noxund_owner` | NOLOGIN, NOINHERIT | (none) | application schemas + migration-created app objects |
| `noxund_ledger` | NOLOGIN, NOINHERIT | (none) | ledger schema, `migration_head`, `migration_history`, types, functions |
| `noxund_app`, `sg8_compute_writer` (runtime) | per runtime contract | (none) | nothing ledger-related |

Only membership edge: `GRANT noxund_owner TO noxund_migrator`. `noxund_ledger` is granted to no one → reachable `SET ROLE` set of `session_user=noxund_migrator` = `{ noxund_migrator, noxund_owner }`, **excluding `noxund_ledger`**. Migration/runtime roles have **no** direct ledger DML/DDL. The P3B2 model (`noxund_migrator` owns the ledger) remains **rejected**.

### 6.4 Linear-ledger authority (retained)
```sql
CREATE TABLE noxund_migration_meta.migration_head (          -- singleton, owner noxund_ledger
    only_one         boolean PRIMARY KEY DEFAULT true CHECK (only_one),
    current_ordinal  bigint  NOT NULL DEFAULT 0,
    current_version  text,                                    -- NULL when empty
    current_checksum text
);  -- seeded once at bootstrap

CREATE TABLE noxund_migration_meta.migration_history (       -- append-only, owner noxund_ledger
    ordinal bigint NOT NULL, version text NOT NULL, checksum text NOT NULL,
    prev_version text,                                        -- NULL only for ordinal 1 (root)
    top_xid xid8 NOT NULL,                                    -- function-derived, top-level (F15)
    backend_pid integer NOT NULL, session_identity name NOT NULL,
    current_identity name NOT NULL, recorded_at timestamptz NOT NULL,   -- recorded_at = EVIDENCE ONLY
    CONSTRAINT mh_ordinal_key UNIQUE (ordinal),
    CONSTRAINT mh_version_key UNIQUE (version),
    CONSTRAINT mh_top_xid_key UNIQUE (top_xid),               -- ≤1 row per top-level tx
    CONSTRAINT mh_prev_key    UNIQUE NULLS NOT DISTINCT (prev_version),  -- ≤1 child per predecessor + single root (F18)
    CONSTRAINT mh_checksum_chk CHECK (checksum ~ '^[0-9a-f]{64}$'),
    CONSTRAINT mh_ordinal_pos  CHECK (ordinal >= 1)
);
```
`record_migration(p_version, p_checksum, p_prev_version)` — SECURITY DEFINER, owner `noxund_ledger`, `plpgsql`, VOLATILE, PARALLEL UNSAFE, `SET search_path = pg_catalog, noxund_migration_meta, pg_temp` — does, in order: (1) `session_user='noxund_migrator'` check (audit/defense-in-depth); (2) NULL/format validation of version & checksum (`22004`); (3) `SET LOCAL lock_timeout='3s'`; (4) **`SELECT … FROM migration_head WHERE only_one FOR UPDATE`** (the **authoritative serialization**, F19); (5) `current_version IS DISTINCT FROM p_prev_version` → `P0001` (head authority, **not** `recorded_at`); (6) **ordinal = current_ordinal + 1** (locked-head increment; **no sequence** — `nextval` is not rolled back); (7) INSERT one history row deriving `top_xid=pg_current_xact_id()` (top-level even in a subtransaction, F15), `backend_pid`, `clock_timestamp()`, identities — **no `ON CONFLICT`**; (8) UPDATE the head; (9) RETURN the record. Read-only accessors `current_state()` and `row_for_current_xact()` (no lock/mutation) let the runner verify prerequisites and the step-16 "exactly one row" check without direct `SELECT` on the ledger.

**Serialization:** the singleton `FOR UPDATE` is the authority; client advisory locks are **defense-in-depth only** and **must not** be required for linearity ("the system does not enforce their use", F20). **Fork proof:** concurrent appends serialize on the head lock; the loser waits, re-reads the advanced head, fails `prev`-check (`P0001`); `mh_prev_key` is the structural backstop (`23505`). Migration tx runs **READ COMMITTED**.

### 6.5 SECURITY DEFINER hardening (retained)
Dedicated `noxund_ledger` ownership · no dynamic SQL · no generic privileged-execution capability · fully schema-qualified references · secure function `search_path` with **`pg_temp` last** · `REVOKE ALL ON SCHEMA/FUNCTIONS FROM PUBLIC` in the creating transaction · `ALTER DEFAULT PRIVILEGES FOR ROLE noxund_ledger REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC` · minimum `USAGE`/`EXECUTE` to `noxund_migrator` only · **no `CREATE`** in the ledger schema for migrator/owner/runtime · **no** UPDATE/DELETE/TRUNCATE/arbitrary-mutation API. `record_migration()` is classified as a **narrow but privileged append capability** available to the trusted `noxund_migrator` principal.

### 6.6 Privilege matrix
| Grantee → | schema | `migration_head` | `migration_history` | `record_migration()` | accessors | type | app schemas/objects |
|---|---|---|---|---|---|---|---|
| `noxund_migrator` | USAGE (no CREATE) | none | none | EXECUTE | EXECUTE | USAGE | none direct |
| `noxund_owner` | none | none | none | none | none | none | OWNER |
| `noxund_ledger` | OWNER | OWNER | OWNER | OWNER | OWNER | OWNER | none |
| runtime roles | none | none | none | none | none | none | per app/P7 |
| PUBLIC | none | none | none | REVOKED | REVOKED | none | none |

## 7. TM-A-only eliminatory test inventory (future pre-gate — DO NOT RUN)

All under **TM-A**; **all TM-B / signature / `pgcrypto` cases removed.** Protocol claims require frontend-message trace evidence. Isolation per P3A/P3B (disposable, no-egress, project-scoped teardown, no volume prune).

**A. Transport & artifact** — A1 protocol trace Parse/Bind/Execute vs default psycopg `Query`; A2 multi-command rejection with **zero** params; A3 command-tag `DO` enforced (non-`DO` rejected); A4 transaction-control inside the `DO` rejected (`COMMIT/ROLLBACK/SAVEPOINT/…`).
**B. Connection/session** — B1 one fresh connection, unconditional close, no reuse; B2 backend PID + top-level XID stability, no reconnect; B3 session-state reassertion after artifact (`role`, `search_path`, `client_encoding`, `DateStyle`, `IntervalStyle`, `TimeZone`, `standard_conforming_strings`, `row_security`, timeouts); B4 artifact session advisory locks / `LISTEN` / `PREPARE` / temp objects neutralized by the fresh connection; B5 `application_name`/custom GUC are evidence-only and do not influence the ledger call.
**C. Role/privilege boundary** — C1 `SET ROLE noxund_ledger` denied from owner and reset-migrator (`42501`); C2 direct ledger DML denial `INSERT/UPDATE/DELETE/TRUNCATE` for migrator/owner/artifact (`42501`); C3 function replace/`ALTER`/`DROP` and schema `CREATE` denied (`42501`); C4 PUBLIC privileges absent on schema/functions; C5 full ACL/membership inventory matches §6.3/§6.6; C6 accessors are read-only, cannot lock/mutate.
**D. Linearity & head authority** — D1 two concurrent children of the same head → one commits, loser `P0001`/`23505`; D2 caller omits client advisory lock → still serialized by head `FOR UPDATE`; D3 different advisory-lock keys → head `FOR UPDATE` still serializes (proves F20 irrelevance); D4 `FOR UPDATE` wait/re-read/loser-reject; D5 predecessor-fork constraint (`mh_prev_key`, `23505`); D6 contiguous locked-head ordinal (monotonic, `UNIQUE(ordinal)`); D7 wall-clock reversal / equal `recorded_at` → order unaffected; D8 current-state correct after logical backup/restore; D9 `top_xid` guard incl. **nested subtransaction** → ≤1 row (F15); D10 rollback release of an aborted subtransaction's unique entry; D11 no two committed rows share a predecessor or ordinal.
**E. SECURITY DEFINER hardening** — E1 `search_path`/`pg_temp` Trojan resistance (shadow fn/operator has no effect).
**F. TM-A accepted-limitation (documentation, not a REJECT by itself)** — F1 a fresh `noxund_migrator` session invokes `record_migration()` **without** an artifact: the call is **technically allowed**; a structurally valid append **may commit** if head/predecessor/uniqueness checks pass; this **documents** the accepted trusted-principal limitation. It becomes a **REJECT only if** the direct call can: violate linearity; create two children of one predecessor; bypass ordinal constraints; create multiple rows in one top-level transaction; mutate or delete prior history; bypass role/ownership boundaries; or make head and history disagree.
**G. Process-death boundaries** — G1/G2/G3 kill before artifact / after DDL before ledger / after ledger before COMMIT → **no** committed DDL, **no** ledger row, **no** head advance (server auto-rollback).

## 8. Remaining UNPROVEN properties (pending executable falsification)

Exact Parse/Bind/Execute transport via the selected call path · multi-command rejection with zero parameters · one-command and `DO` command-tag enforcement · transaction-control resistance inside the `DO` · persistence and neutralization of role/session-state changes · inability of artifact-reachable roles to assume `noxund_ledger` · absence of direct ledger DML/DDL · `FOR UPDATE` wait/re-read/loser rejection · `UNIQUE NULLS NOT DISTINCT` fork prevention · top-level-XID behavior in nested subtransactions · rollback release of an aborted subtransaction's unique entry · contiguous locked-head ordinal · SECURITY DEFINER search_path/`pg_temp` resistance · default PUBLIC privilege removal · process-death rollback at every critical boundary · backend PID and top-level-XID stability · session-state reassertion · unconditional connection closure. *(U-TRUST is now resolved by the TM-A decision — an accepted limitation, not an unproven property. All TM-B/U-SIG items are removed.)*

## 9. Recommendation for the next gate

**Authorize (under a NEW explicit Product Lead GO) a scoped, read-mostly `PG-EXIT-P3C-EXECUTE-PRE`, operating exclusively under TM-A**, to run the §7 inventory (A–G) on an isolated, disposable, no-egress spike branch and convert the §8 properties from UNPROVEN to proven. The **full single-session runner spike** proceeds only if the pre-gate passes with **zero** REJECTs, under a further GO. **ESCALATE** (stop) only if a §7-D/C/E/G test reveals a fork, a boundary breach, or a non-rollback-safe boundary — do not weaken the linearity or least-privilege contract. No branch, implementation, commit, PR, container, DB connection, or executable gate is authorized now.

---

## Primary sources
F1/F3 (`protocol-flow`, `libpq-exec`) · F7 (`sql-do`) · F9/F10/F11 (`sql-set-role`) · F12 (`sql-set-session-authorization`) · F14 (`sql-createfunction`) · F15 (`functions-info`: `pg_current_xact_id()` top-level in subtransaction; `xid8` non-wrapping) · F16 (`sql-grant`: drop/alter inherent to owner) · F17 (`ddl-priv`: default PUBLIC EXECUTE; REVOKE in creating tx) · F18 (`sql-createtable`: `UNIQUE NULLS NOT DISTINCT`) · F19 (`explicit-locking`: `FOR UPDATE` wait/re-read) · F20 (`explicit-locking`: advisory locks not system-enforced). **Correction:** PostgreSQL 15 `pgcrypto` has no public-key digital-signature verify primitive (basis for removing TM-B).
