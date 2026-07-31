# NOXUND — local PostgreSQL 15 (vanilla)

PG-EXIT-P2 (DEC-0028). Hermetic, loopback-only PostgreSQL 15 for **dev + CI**.
No Supabase, no Adminer/pgAdmin, no remote. Image is **digest-pinned**. Lifecycle
is **deliberate** (`restart: "no"`) and the destructive reset is a separate,
guarded command — nothing here hides a destructive step.

## Requirements
- Windows 11 + WSL 2 (Ubuntu) + Docker Desktop (WSL 2 backend)
- `docker` + `docker compose` on PATH; `psql` 15.x for host-side use (optional —
  the scripts also run psql inside the container)
- Bash (run the scripts from WSL 2 / Ubuntu)

## One-time
```bash
infra/postgres/scripts/prepare-local     # creates ./.local-secrets/* (0600, gitignored). NEVER prints values.
```
Secrets are **Docker Compose secrets** (files under `.local-secrets/`), never
passed via `environment:`/`env_file:`. Recommended: keep `.local-secrets/` at
`0700` and each file at `0600` (prepare-local enforces this).

## Lifecycle
```bash
scripts/start-local     # up + wait healthy + FAIL-CLOSED marker/roles check (no auto-repair)
scripts/status-local    # state / health / loopback publish
scripts/logs-local      # tail logs (server never logs passwords)
scripts/verify-local    # full assertion suite + canonical structural digest
scripts/stop-local      # teardown container/network; PRESERVES the data volume
scripts/reset-local RESET-NOXUND-LOCAL   # DESTRUCTIVE: removes THIS project's volume; re-init on next start
```
- **Connection (host):** `postgresql://noxund_app@127.0.0.1:5433/noxund` (password
  from `.local-secrets/noxund_app_password`; use `~/.pgpass` or a prompt).
- **CI:** set a distinct `COMPOSE_PROJECT_NAME` to isolate runs — scripts discover
  the container/volume/network/port from Compose (nothing hardcoded).

## Identities (DEC-0028)
- `postgres` — image bootstrap superuser; **admin/break-glass only**, never the app.
- `noxund_owner` — NOLOGIN; owns db/schemas/objects; never runtime.
- `noxund_migrator` — LOGIN; controlled member of `noxund_owner`; `SET ROLE noxund_owner` only during migrations (never a permanent owner).
- `noxund_app` — LOGIN runtime; no ownership, no `BYPASSRLS`, no table grants yet.
- `sg8_compute_writer` — NOLOGIN, no password, no grants until P7.

## Bootstrap marker
The init writes a canonical marker `noxund-bootstrap:p2-v1`. `start-local` refuses
a volume that is missing the marker, carries a divergent marker, has divergent
roles, or an incomplete bootstrap — **it never auto-repairs**.

## Locale (P2, binding)
`initdb --encoding=UTF8 --locale=C.UTF-8 --data-checksums --auth-host=scram-sha-256`;
`timezone`/`log_timezone` = UTC; `password_encryption=scram-sha-256`. **No ICU in
P2.** No claim of textual-ordering parity with the legacy Supabase collation — the
legacy collation is inventoried before P9 (see `db/legacy-map.md`).

## Out of scope here
Sqitch, ledger, vanilla migrations, `noxund_identity`, data export, remote/prod.
Those are P3+ units.
