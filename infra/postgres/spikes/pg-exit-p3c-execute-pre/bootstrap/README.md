# bootstrap — trusted, single-transaction (IMPLEMENTED, NOT EXECUTED)

`00_bootstrap.sql` is the **entire** ledger/role provisioning, in **one** transaction, run by the future gate as the image bootstrap superuser (TM-A: trusted). It is **not** applied in this unit.

## Ordering & why

1. **Roles** — created by the superuser. Only edge: `GRANT noxund_owner TO noxund_migrator`. `noxund_ledger` is granted to no one ⇒ the reachable `SET ROLE` set of `session_user=noxund_migrator` is `{noxund_migrator, noxund_owner}`, excluding `noxund_ledger`.
2. **Ledger schema** — `CREATE SCHEMA … AUTHORIZATION noxund_ledger`; then `ALTER DEFAULT PRIVILEGES FOR ROLE noxund_ledger …` **before** any function/table is created, so the default-privilege target matches the **actual creator**.
3. **Ledger objects** — created under `SET ROLE noxund_ledger` (so `noxund_ledger` is the creator/owner and the default privileges apply). Types, singleton `migration_head` (seeded once), append-only `migration_history`, `record_migration()`, and the two read-only accessors.
4. **ACLs** — explicit `REVOKE … FROM PUBLIC` (functions **and** the three composite/rowtypes — `USAGE` on types is a PUBLIC default) in the same transaction; minimum `USAGE`/`EXECUTE` to `noxund_migrator` only.
5. **Application schema** — `CREATE SCHEMA … AUTHORIZATION noxund_owner`; migrations create objects here via `SET LOCAL ROLE noxund_owner`.

## Credential handling

`00_bootstrap.sql` currently consumes psql variables
(`:migrator_password`, `:app_password`), but the rejected R0 argv-based example
has been removed. No approved bootstrap invocation exists while provisioning is
on HOLD. The provisioning/correction sequence must define a reviewed mechanism
that reads mounted secret files without putting secret values in argv, logs,
evidence or exception text. Do not improvise a command from this document.
## Notes matched to the binding requirements
- `current_user` inside `record_migration()` is the **definer** (`noxund_ledger`); stored as `definer_identity`, never named "invoker".
- `record_migration()` has a fixed `search_path = pg_catalog, noxund_migration_meta, pg_temp` (`pg_temp` **last**), no dynamic SQL, no name arguments, one append only.
- The singleton `FOR UPDATE` is the authoritative serialization; client advisory locks are defense-in-depth only.
