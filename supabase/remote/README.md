# `supabase/remote/` — READ-ONLY remote diagnostics (SG-8 promotion)

This directory holds **read-only** SQL that a gated workflow runs against the
**remote** `production-db` for the SG-8 promotion sequence. Nothing here applies
migrations, repairs the ledger, or issues DDL.

| File | Purpose | Boundary |
|---|---|---|
| `sg8_r0_preflight_pre_0008.sql` | R0 preflight: diagnose the remote **before** migration 0008 | single session, `REPEATABLE READ READ ONLY`, ends in `ROLLBACK`; a write probe proves the boundary (SQLSTATE 25006) |
| `r0_evaluate.sh` | Shared evaluator: parse preflight output → ledger-set + backup gate → FINAL verdict + deterministic digest | pure text; no DB, no secret, no network |
| `tests/r0_evaluate_unit_test.sh` | **DB-free** unit test of `r0_evaluate.sh` (runs without Docker) | synthetic fixtures; loopback-irrelevant |
| `tests/r0_preflight_local_test.sh` | Integration test of SQL+evaluator on a **disposable local** stack (pre-0008 GREEN + full RED) | loopback only; no remote, no secrets; **needs Docker + pinned Supabase CLI + PG15** |

**Runner:** `.github/workflows/sg8-r0-preflight-production-db.yml` (workflow_dispatch,
Environment `production-db` only, `permissions: contents: read`, main-only,
required-reviewer-gated). It builds a **masked** DB URL from the Environment
secret/vars and runs the SQL with `psql` — **no `supabase` CLI**, no `link`, no
`db push`, no `db reset`, no migration/repair command.

**Verdict discipline:** `GREEN` (environment exactly compatible **and** SG-8
objects absent) or `RED` (concrete divergence). Never "GREEN with observations"
for preconditions. A partial SG-8 object ⇒ `RED` + full inventory; never removed
or normalized here.

R1–R7 remain **blocked**; each future gate needs a fresh GO. See
`docs/product/decisions/DEC-0027-sg8-remote-promotion-r0-preflight.md`.
