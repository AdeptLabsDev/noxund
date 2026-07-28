# HANDOFF — SG-8 R0 Preflight (READ-ONLY, pre-0008)

**From:** Product Orchestrator · **Unit:** SG-8 remote promotion, gate R0 (author-only)
**Authorization:** DEC-0027 (GO R0-AUTHOR) · **Base:** main @ `be9012c` · **Date:** 2026-07-28
**Status:** authored; PR open; **NOT merged, NOT dispatched, no remote connection.**

## What this delivers

A single PR authoring the remote **read-only** preflight that must pass **before** any SG-8
migration is applied to `production-db`. It applies nothing and connects to nothing during authoring.

| Artifact | Path |
|---|---|
| R0 workflow (gated, production-db, read-only; **tip-of-main** + **backup RED-default**) | `.github/workflows/sg8-r0-preflight-production-db.yml` |
| R0 preflight SQL (single READ ONLY snapshot; ROLLBACK) | `supabase/remote/sg8_r0_preflight_pre_0008.sql` |
| Shared evaluator (ledger-set + backup gate + verdict + digest) | `supabase/remote/r0_evaluate.sh` |
| DB-free evaluator unit test (runs without Docker) | `supabase/remote/tests/r0_evaluate_unit_test.sh` |
| Docker integration test (disposable local stack) | `supabase/remote/tests/r0_preflight_local_test.sh` |
| Executable evidence (unit test transcript, 9/9) | `docs/agents/reviews/SG8-R0-evaluate-unit-test-evidence.md` |
| Report format + backup RED-default semantics + tip-of-main | `docs/data/DATA-SG8-001-R0-preflight-report-format.md` |
| Decision record (authorization + rejections + open decisions + corrective §7) | `docs/product/decisions/DEC-0027-sg8-remote-promotion-r0-preflight.md` |
| Directory contract | `supabase/remote/README.md` |
| Six-role review (posted as immutable PR comment on the final SHA) | PR #65 comment |

## Acceptance criteria (R0-AUTHOR)

- Workflow: `workflow_dispatch` only · Environment `production-db` **exclusively** · `permissions:
  contents: read` · main-only (ref assert + Environment branch policy + `target_sha ∈ main`) ·
  `target_sha` + confirm phrase · `HEAD == target_sha` assert · pinned actions · finite timeout ·
  serial concurrency `cancel-in-progress: false` · required reviewer inherited · **no** second
  Environment · **no** new secret · **no** migration/repair/push/apply/DDL · **no** URL/password logging.
- SQL: single session `BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY` + `SET LOCAL`
  statement/lock/idle timeouts · proves `transaction_read_only='on'` · write probe fails (25006) ·
  ends **only** in `ROLLBACK` · same identity the future gates use (diagnoses real executor capability).
- Verdict: GREEN xor RED; never "GREEN with observations"; partial object ⇒ RED + inventory; major must be 15.

## Deferred (needs fresh GO)

R1 (apply 0008) · R2 (verify 0008) · R2.5 (preflight 0009) · R3 (apply 0009) · R4 (verify 0009) ·
R5 (Environment `sg8-compute`) · R6 (variables + secret slot) · R7 (atomic activation). Open decisions
OD-1..OD-5 in DEC-0027 §4.

## How to run later (only under GO R0-DISPATCH)

Dispatch `SG-8 · R0 Preflight` from **main**, input `target_sha` (this PR's head after merge) and the
confirm phrase; approve the `production-db` required reviewer. Read GREEN/RED + digest in the run summary.
Complete the **manual backup checklist** with operator evidence independently. **Not authorized now.**
