# PG-EXIT-P3C-EXECUTE-PRE — falsification harness (IMPLEMENTED, NOT EXECUTED)

**Status:** `IMPLEMENTED, NOT EXECUTED` · `PROVISIONING HOLD`. Every runtime property remains **UNPROVEN**. The rejected R0 harness is not ready for execution or renewed technical review.

**Unit:** PG-EXIT-P3C-EXECUTE-PRE-IMPLEMENT (implementation only).
**Branch/worktree:** `spike/pg-exit-p3c-execute-pre` @ base `4873ac713397cf47642d39b1ef17e48a9301511d`, linked worktree `C:/Adeptlabs/noxund-p3c-execute-pre`.
**Design source:** the accepted TM-A candidate (`docs/result/03-PG-EXIT-P3C-DESIGN-result.md` in the main worktree — **not** copied here, not modified).

> **This unit implemented files only.** Nothing was installed, built, pulled, started, connected, bootstrapped, traced or run. No container, no database, no migration, no attack fixture, no fault injection. The words `PASS`/`GREEN`/`verified` are **not** used for anything in this tree — see `docs/expected-outcomes.md`, whose cells are *expected* outcomes for the future run, not observed results.

## Binding trust model — TM-A (trusted migrator principal)

- **Trusted:** the runner implementation & process; the `noxund_migrator` credential; the authorized runner environment; the client-held manifest & expected checksums; PostgreSQL bootstrap/admin authority.
- **Hostile / potentially malformed:** the **migration artifact** only.
- A direct call of `record_migration()` by an authenticated `noxund_migrator` session (outside the runner) is an **accepted TM-A limitation**, *not* a REJECT by itself (see test group **F**). There are **no** TM-B / signature / `pgcrypto` / HMAC / principal-resistant cases anywhere in this harness.

## What is server-enforced here (the properties to falsify)

- Transport: libpq `PQexecParams` (via `psycopg.pq.PGconn.exec_params`) — extended protocol, one command per Parse; the default parameterless `Cursor.execute()`/`ClientCursor`/`psql`/`PQexec` paths are **not** used as the migration transport.
- Artifact = exactly one server-accepted command, command tag **`DO`**, one `plpgsql` `DO` block, executed inside the runner-owned transaction; classification is by the **server command tag**, never by pre-parsing.
- Role graph: `noxund_migrator` (LOGIN, NOINHERIT, member only of `noxund_owner`) / `noxund_owner` (NOLOGIN, owns app objects) / `noxund_ledger` (NOLOGIN, owns the ledger, granted to no one → unreachable via `SET ROLE`).
- Linear ledger: singleton `migration_head` locked `SELECT … FOR UPDATE` **inside** the SECURITY DEFINER `record_migration()`; locked-head increment ordinal (no sequence, no `recorded_at` authority); `UNIQUE(ordinal/version/top_xid)` + `UNIQUE NULLS NOT DISTINCT(prev_version)`.

## Layout

```
README.md                     — this operator contract
compose.spike.yml             — disposable PG 15.18 env (digest-pinned, internal net, NO published port)
.gitignore                    — ignore ephemeral secrets & evidence
env/gen-ephemeral-credentials.sh — runtime-only ephemeral credential generation (never tracked)
bootstrap/00_bootstrap.sql    — single trusted transaction: roles, ledger, functions, ACLs, app schema, runtime roles
bootstrap/README.md           — bootstrap ordering & default-privilege contract
runner/                       — thin PQexecParams runner prototype (pq_transport, session_state, manifest, runner)
fixtures/migrations/          — valid one-DO-block migrations + manifest + CHECKSUMS.sha256
fixtures/attacks/             — adversarial artifacts (one file per attack, mapped to A–G)
harness/                      — cases registry, expected matrix, evidence, concurrency (D), fault injection (G), orchestrator, teardown
tools/secret-scan.sh          — diff/tree secret scan using already-present tools (no install)
docs/                         — test plan (A–G↔file), operator contract, expected-outcomes matrix
```

## Hard no-execution guard

Every runnable entrypoint (`harness/run_pre_gate.py`, `harness/concurrency.py`, `runner/runner.py`) refuses to do any side-effecting work unless `NOXUND_P3C_EXECUTE_GATE=AUTHORIZED` is set **and** a later Product Lead GO exists. That variable is **not** set anywhere in this tree. Absent it, they print `IMPLEMENTED, NOT EXECUTED` and exit non-zero.

## Execution architecture: HOLD

There is deliberately no executable command sequence in this tree. The
repository contains neither an approved digest-pinned client image nor a local
hash-verified offline dependency closure for Psycopg. The former PostgreSQL
server-image client and runtime installation proposal were removed because they
could not run the harness on the internal no-egress network.

`compose.spike.yml` therefore defines no client service.
`runner/requirements.txt` is a non-installable HOLD notice. Do not invent an
image digest, use a mutable tag, install at gate time, or substitute an ambient
host Python environment.

The exact prerequisite is documented in
`docs/PG-EXIT-P3C-EXECUTE-PRE-PROVISION.md`. A new Product Lead GO must complete
and independently review that provisioning unit before correction work resumes.