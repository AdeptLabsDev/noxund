# DEC-0027 — SG-8 Remote Promotion: R0-AUTHOR + rejected apply/verify mechanisms

**Status:** ACTIVE (binding) · **Date:** 2026-07-28 · **Author:** Product Lead (ratified via Product Orchestrator)
**Scope:** SG-8 remote promotion sequence (migrations 0008 + 0009), gate **R0** authoring only.
**Supersedes/extends:** promotion package reviewed under [[DEC-0026]] closeout (main @ `be9012c`).

---

## 1. Context

Migrations 0008 (`sg8_reconciliation_session`) and 0009 (`sg8_runtime_identity_grants_rls`)
are **closed in code and NOT applied remotely** (main @ `be9012c`). The gate order
`R0 → R1 → R2 → R2.5 → R3 → R4 → R5 → R6 → R7` is accepted. The **apply and verify
mechanisms are NOT approved.** Only **R0-AUTHOR** is authorized.

## 2. Authorization (this unit)

**GO — R0-AUTHOR only:** author the remote **read-only** preflight prior to 0008 as a
single PR, **no merge, no dispatch, no remote connection**. Deliverables:

- `.github/workflows/sg8-r0-preflight-production-db.yml` — workflow_dispatch, Environment
  `production-db` only, `permissions: contents: read`, main-only, `target_sha` + confirm
  phrase, `HEAD == target_sha` assert, pinned actions, finite timeout, serial concurrency
  (`cancel-in-progress: false`), required reviewer inherited from the Environment, **no
  other Environment, no new secret, no migration/repair/push/apply/DDL, no logging of the
  connection string or password.**
- `supabase/remote/sg8_r0_preflight_pre_0008.sql` — one session/snapshot
  (`BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY` + `SET LOCAL` timeouts), proves
  `transaction_read_only = 'on'`, a write probe **must fail**, ends **only** in `ROLLBACK`.
- `supabase/remote/tests/r0_preflight_local_test.sh` — disposable **local** validation.
- report format + manual backup checklist (`docs/data/DATA-SG8-001-R0-preflight-report-format.md`).

## 3. REJECTED / NOT AUTHORIZED (binding)

1. **`psql` migration → manual `INSERT` into `supabase_migrations.schema_migrations`.**
   The two-step "apply file then hand-insert the ledger row" is **rejected** as the apply mechanism.
2. **`ON CONFLICT DO NOTHING` on the ledger.** Rejected — it silently masks a divergent/pre-existing
   ledger row instead of failing closed.
3. **Double transactional wrapper for the verifies** — combining `psql -1`, an external
   `BEGIN/ROLLBACK`, and the verify's own internal transactional control. Rejected — nested/overlapping
   transaction control is ambiguous and unsafe.

These three are recorded so no future unit silently re-introduces them.

## 4. OPEN DECISIONS (deferred; each needs its own ruling before the relevant gate)

- **OD-1 — Official file-scoped apply mechanism (R1/R3).** How exactly one authorized `.sql` is applied
  to the remote without `db push`/`migration up` (both would apply 0008 **and** 0009, since both are pending).
- **OD-2 — Atomicity of schema + ledger.** How the DDL apply and its ledger record become a single
  fail-closed unit **without** manual insert or `ON CONFLICT DO NOTHING` (both rejected in §3).
- **OD-3 — Single transactional boundary for R2/R4 verifies.** The one, unambiguous transactional model
  for the remote verifies (given §3.3 rejection of the double wrapper).
- **OD-4 — Secure password channel for R7.** How the generated password reaches `ALTER ROLE … LOGIN`
  and the secret store without ever being printed/logged.
- **OD-5 — CA for `verify-full`.** Provisioning the CA so `SG8_COMPUTE_DB_SSLMODE=verify-full` is enforceable.

## 5. Out of scope (this unit)

Remote connection · dispatch · apply · ledger repair · any change to migrations 0008/0009 ·
new Environment · variables or secrets · LOGIN or password · runtime workflow · compute.

## 6. R0 verdict discipline

`GREEN` = environment exactly compatible **and** SG-8 objects absent. `RED` = concrete divergence.
**Never "GREEN with observations"** for preconditions. Any partial SG-8 object ⇒ `RED` + full inventory,
never removed or normalized. Remote **major must equal 15** (the major validated by the 0008/0009 harness);
otherwise `RED`, no migration authorized, and a new hermetic validation on the remote major is escalated.

Related: [[DEC-0026]] · [[DEC-0025]] · [[DEC-0024]] · `docs/agents/handoffs/HANDOFF-SG8-R0-PREFLIGHT.md`.
