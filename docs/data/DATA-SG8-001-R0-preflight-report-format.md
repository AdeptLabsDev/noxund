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

## 3. Deterministic digest

`sha256( sorted-canonical-vector + LEDGER=<versions> + LEDGER_SET_OK=<bool> + DB_VERDICT=<v> )`.
Stable across repeated runs against the same remote state; the same digest ⇒ the same decision inputs.

## 4. Final verdict (fail-closed)

`GREEN` **iff** DB-side `R0_VERDICT=GREEN` **and** the runner ledger-set checks pass:
0008 absent · 0009 absent · no unknown remote version · nothing pending outside `{0008,0009}`.
Otherwise `RED`. **Never "GREEN with observations."** `pg_major ≠ 15` ⇒ `RED` (+ escalate a new
hermetic validation on the remote major).

## 5. Manual backup checklist (SEPARATE — cannot be GREEN without operator evidence)

This checklist is **out of the automated preflight** (DEC-0027: no new Management-API token/call in
this unit). It is marked GREEN **only** with external evidence supplied by the operator, attached to
the R0 record:

- [ ] **PITR or backup available** — evidence: _______________________
- [ ] **Last backup timestamp** — value: _______________________
- [ ] **Restore procedure** — link/reference: _______________________
- [ ] **Decision owner** (who authorizes apply) — name: _______________________
- [ ] **Operational window** (agreed maintenance window) — value: _______________________

Until every box has attached evidence, the backup checklist is **NOT GREEN**, and R1 stays blocked
independently of the automated R0 result.
