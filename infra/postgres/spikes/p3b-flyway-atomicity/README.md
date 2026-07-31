# PG-EXIT-P3B — Flyway Community atomicity falsification (spike)

**Unit:** PG-EXIT-P3B-EXECUTE · **Status:** single fatal test · **Authorized by:** Product Lead (P3B-DESIGN accepted with binding corrections)
**Base:** `main @ dfac2b43adf22e642ef1f8a078c5a3161bac8a77` · **Branch:** `spike/pg-exit-p3b-flyway-atomicity`
**Predecessor:** [[DEC-0029]] closed OD-5 as **REJECT SQITCH** (joint DDL↔registry atomicity falsified). Flyway is a registered, **unchosen** successor candidate.

> A **PASS here authorizes only a future full evaluation — never adoption** (DEC-0029 §7).
> This unit runs **only** the fatal atomicity test — not the full Flyway matrix.

---

## What is under test

The single eliminatory requirement inherited from DEC-0028 §3 #2: **is a change's DDL atomic with its
`flyway_schema_history` row?** If a crash between "DDL committed" and "history written" can leave a
committed schema object with no registry row (the Sqitch failure mode), Flyway is **REJECT** under
NOXUND's requirements. If the DDL and the history row share one transaction and roll back together,
it is **PASS ATOMICITY**.

## Design (why it is deterministic, not a race)

1. **Least-privilege identity.** Flyway connects as `noxund_migrator` (LOGIN, **NOINHERIT**, never
   superuser). The **Flyway-13 correction (binding)**: no `flyway.initSql`; instead the SQL callback
   `callbacks/afterConnect__set_noxund_owner.sql` runs `SET ROLE noxund_owner;` after every connect.
   The callback has its **own boundary** — that it holds on **all** internal Flyway connections is
   **not assumed**, it is **proven** by LP-0.
2. **LP-0 (eliminatory).** Apply **V1** only. V1 carries a fail-closed guard
   (`session_user=noxund_migrator`, `current_user=noxund_owner`). Then prove, from the catalog:
   owner is NOLOGIN, migrator is NOINHERIT & minimal-privilege, no extra superuser, and
   `public.flyway_schema_history` **and** the `spike` schema are **owned by `noxund_owner`** — the
   latter two proving the callback reached both the history-management and migration connections.
   **Any LP-0 failure ⇒ `ESCALATE — LEAST-PRIVILEGE CONTRACT NOT SUPPORTED`**: no `postgres`, no
   trigger, no V2, no workaround.
3. **Instrumentation** (harness superuser; instrumentation only, never a migration):
   - an **event trigger** logs `PID/XID` of the **V2 `CREATE TABLE`** (fires inside V2's tx);
   - a **BEFORE INSERT** trigger on `flyway_schema_history` logs `PID/XID` of the V2 history row,
     then **blocks on an advisory lock the controller already holds** — a deterministic window.
   Both write via `RAISE LOG` (server log = durable, rollback-proof).
4. **Fatal step.** Launch `flyway migrate` for V2 (detached). It executes the `CREATE TABLE`, then
   blocks at the history INSERT. Once the trigger log **and** the blocked backend are observed,
   **SIGKILL the Flyway container only** — **PostgreSQL stays up**. Inspect via an **independent
   connection**.

## Binding proof

Not "one `BEGIN` for the whole command", but specifically:

```
PID(CREATE TABLE V2) == PID(INSERT history V2)
XID(CREATE TABLE V2) == XID(INSERT history V2)
```

## Verdicts

- **PASS ATOMICITY** — table absent, V2 history row absent, same PID, same XID, no `success=false`,
  0 prepared xacts, 0 orphan locks, 0 idle-in-transaction, `info`/`validate` coherent, a fresh
  `migrate` applies V2 with **no repair**. *(Authorizes a future full evaluation only.)*
- **REJECT FLYWAY** — table⊕history mismatch, divergent PID/XID, a failed state needing repair, a
  false-green over drift, or a migration outside the least-privilege model. Stop; preserve; no recovery.
- **ESCALATE** — tag/image unavailable, LP-0 fails, callback does not sustain the contract, or the
  window is not hit deterministically. No automatic re-run.

## Isolation & safety (binding)

- Compose project **`noxund-p3b`**, DB **`flyway_spike`**, network **`internal: true` (no egress)**,
  **no published port**, disposable project-scoped volume. `noxund-local` is never touched.
- Password only via **Compose secret** at `/run/secrets/noxund_migrator_password`; the flyway
  entrypoint reads it at exec, never prints/persists it, refuses symlink/insecure perms. Never in
  Compose, `docker inspect`, transcript, or Git.
- `REDGATE_DISABLE_TELEMETRY=true`; no token/PAT/login/licence. Images pinned by **tag + digest**.
- **Executable sentinel** (flyway entrypoint) refuses `clean|repair|baseline|undo`; `cleanDisabled=true`.

## Run

```bash
bash harness/run-p3b.sh      # one deterministic fatal test; writes ./evidence + VERDICT.txt
bash harness/teardown.sh     # project-scoped teardown ONLY (never `docker volume prune`)
```

Pinned images: `postgres:15.18-bookworm@sha256:b0c5bab0…`, `flyway/flyway:13.1.0@sha256:3cc7587d…`.
