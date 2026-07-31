# Legacy (Supabase) → Vanilla PostgreSQL — change map

**Status:** placeholder (PG-EXIT-P2). The vanilla schema chain does not exist yet
(P4/P5+). This file will map each **new** vanilla change to the **frozen legacy**
migration it reproduces, so the port is auditable 1:1.

> The legacy files in `supabase/migrations/` (0001–0006 applied; 0008/0009
> design-only) are **frozen history** (DEC-0028 §5) — never edited or renumbered.
> The vanilla chain under `db/` gets **new files, new checksums, a new namespace**.

| Vanilla change (`db/deploy/…`) | Reproduces legacy | Notes |
|---|---|---|
| _(none yet)_ | `supabase/migrations/20260620000001…` | identity: `auth.users` → `noxund_identity.users`; `auth.uid()` → transaction-local actor (P4) |
| _(none yet)_ | `…0002…0006` | mechanical: drop `anon/authenticated` grantees (P5) |
| _(none yet)_ | `…0008/0009` (SG-8) | 0008 ~intact; 0009 rewritten for the vanilla role model (P7 / OD-2) |

## Pre-P9: legacy collation inventory (TODO, binding)
Before the raw-data export/restore (P9), inventory the **legacy database/columns
collation** (`datcollate`/`datctype` and any per-column `COLLATE`) of the managed
Supabase project, and record it here. The local vanilla stack uses `C.UTF-8`
(P2) and makes **no claim** of textual-ordering parity — the export path must
reconcile or explicitly document any re-ordering for `run_id f0485de6…`.
