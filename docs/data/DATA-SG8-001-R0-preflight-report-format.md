# DATA-SG8-001 · R0 Preflight — report format & manual backup checklist

**Unit:** SG-8 remote promotion · gate **R0** (read-only, pre-0008). **Authoring:** DEC-0027.
**Producer:** `.github/workflows/sg8-r0-preflight-production-db.yml` + `supabase/remote/sg8_r0_preflight_pre_0008.sql`.

The R0 workflow emits a **sanitized report** to the job step summary and a **deterministic
digest**. Neither ever contains a connection string, password, token, or secret value.

## 1. Report sections (sanitized)

| § | Content |
|---|---|
| §1 Environment | database · current_user · session_user · observed vs expected project ref · expected hostname · observed server IP/port · full PG version · **pg_major** · search_path · relevant extensions |
| §2 Executor capabilities *(reported, never used)* | `rolsuper/rolcreatedb/rolcreaterole/rolcanlogin/rolbypassrls/rolreplication` · DB `CREATE` · schema `public` USAGE/CREATE — segmented by future gate (R1/0008, R3/0009, R7/ALTER ROLE) |
| §3 Ledger | existence · owner · RLS · columns (type/nullability/default) · constraints · indexes · grants · **full ordered content** · repo-pinned Supabase CLI version (recorded by the runner) |
| §4 SG-8 objects absent | 4 tables · enum · 3 guard functions · triggers · policies · `reports_id_run_key` · role `sg8_compute_writer` — by exact name, schema-scoped; plus a residue inventory (expected **zero** rows) |
| §5 UUID | `pg_catalog.gen_random_uuid()` present · OID · owner · no shadowing · PUBLIC EXECUTE + ACL origin. R0 does **not** claim to prove the 0008 default (evidence table absent yet) — deferred to R2/R2.5 |

## 2. Machine blocks (single session)

- `R0-CANON-START … R0-CANON-END` — sorted `key=value` **decision vector**, volatile-free
  (no pid/now/ip/port/version-string). Hashed for the deterministic digest.
- `R0-LEDGER-START … R0-LEDGER-END` — remote ledger versions (one per line) for the
  runner's set comparison against the checkout migrations.
- `R0_VERDICT=GREEN|RED` — DB-side verdict.

Computed by the shared evaluator `supabase/remote/r0_evaluate.sh` (single source of truth for the
workflow **and** the tests): `sha256( sorted-canonical-vector + LEDGER=<versions> + LEDGER_SET_OK=<bool>
+ DB_VERDICT=<v> )`. It is a function of **remote DB state + checkout ledger set ONLY** — it **excludes**
the operator backup input and every volatile field (pid/now/ip/port/version-string). Same state ⇒ same
digest (proven `×2` by the tests).

## 4. Final verdict (fail-closed) — separated inputs, single GREEN/RED

The report **separates** the *technical automated result* from the *operator backup evidence*, but the
**canonical FINAL verdict is only `GREEN` or `RED`**:

`FINAL = GREEN` **iff** **(i)** technical GREEN — DB-side `R0_VERDICT=GREEN` **and** runner ledger-set
checks pass (0008 absent · 0009 absent · no unknown remote version · nothing pending outside `{0008,0009}`)
— **and (ii)** backup evidence complete (§5). Otherwise `RED`.

- **Never `GREEN WITH NOTES`.** **Never `TECHNICAL_GREEN` as authorization.** `pg_major ≠ 15` ⇒ `RED`
  (+ escalate a new hermetic validation on the remote major). A partial SG-8 object ⇒ `RED` + inventory.

## 5. Backup evidence — RED-default, operator-supplied at dispatch (no Management API)

The 5 backup facts are **not** self-attested by the workflow and are **not** an external call. They are
**dispatch inputs** the operator fills in, and the **human `production-db` reviewer validates the
referenced evidence before approving the run**. Any empty/placeholder value ⇒ `backup_ok=false` ⇒ FINAL
`RED`. An empty checklist can **never** yield GREEN.

| Input | Meaning | RED if |
|---|---|---|
| `backup_pitr_available` (`yes`/`no`, default `no`) | PITR or a verified backup exists | ≠ `yes` |
| `backup_timestamp` | date/time of the last backup | empty / placeholder |
| `restore_procedure_ref` | link/reference to the restore procedure | empty / placeholder |
| `backup_responsible` | who owns the apply decision | empty / placeholder |
| `operational_window` | agreed maintenance window | empty / placeholder |

**How evidence is referenced/validated at the future dispatch:** the operator pastes the values (and a
reference in `restore_procedure_ref`, e.g. a runbook/ticket URL) into the dispatch form; the required
`production-db` reviewer confirms the reference matches real backup/restore evidence before approving.
The workflow records the values in the sanitized summary and gates FINAL on their completeness — it does
**not** fetch or vouch for them itself.

## 6. Tip-of-main dispatch rule

At dispatch the workflow requires `target_sha == the CURRENT origin/main tip` (fetched live), not merely
an ancestor of main. Any advance of main between authorization and dispatch invalidates the gate; a stale
ancestor SHA is rejected. The preflight is thus bound to the exact bytes that R1 would apply next.
`github.ref` must also be `refs/heads/main` (belt-and-suspenders with the Environment branch policy).
