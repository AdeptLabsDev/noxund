# SG-8 · R0 — executable evidence (DB-free evaluate unit test)

Runner-side evaluation logic (`supabase/remote/r0_evaluate.sh`) exercised with synthetic
psql-output fixtures. No Docker, no DB, no network. This proves the gap-fix behaviors that live
in the evaluator; the Docker-backed supabase integration test (`r0_preflight_local_test.sh`)
is deferred to a Docker + pinned-Supabase-CLI + PG15 host (QA-1/DO-1).

## Environment
```
host: Windows 11 (git-bash / cygwin) — no Docker/Supabase/psql available here
GNU bash, version 5.3.9(1)-release (x86_64-pc-cygwin)
sha256sum (GNU coreutils) 8.32
GNU Awk 5.4.0, API 4.1, PMA Avon 8-g1, (GNU MPFR 4.2.2, GNU MP 6.3.0)
git branch: feat/sg8-r0-preflight-author-production-db
working-tree parent commit: 81faa7920236ae152401a417cb87e2a3833d8461
```

## Command
```
bash supabase/remote/tests/r0_evaluate_unit_test.sh
```

## Transcript
```
  PASS: T1 GREEN (pre-0008 + backup ok)
  PASS: T2 backup missing ⇒ RED (no TECHNICAL_GREEN authorization)
  PASS: T3 0008-in-ledger ⇒ RED
  PASS: T4 unrelated pending (0007) ⇒ RED
  PASS: T5 unknown-remote ⇒ RED
  PASS: T6 db_verdict=RED ⇒ RED
  PASS: T7 digest identical ×2 (13001db104984073502e5a7df98be7f39bb909f203eb61df0102375c7e801c09)
  PASS: T8 digest independent of backup input
  PASS: T9 output sanitized (no URL/password/token)

r0_evaluate unit: PASS=9 FAIL=0
exit_code=0
```

## Coverage
- T1 pre-0008 + backup complete → **GREEN**
- T2 backup absent → **RED** (RED-default; no TECHNICAL_GREEN authorization)
- T3 0008 in ledger → **RED**
- T4 unrelated pending migration (0007) → **RED**
- T5 unknown remote version → **RED**
- T6 DB-side RED → **RED**
- T7 digest identical ×2 (same state) · T8 digest independent of backup input
- T9 evaluator output sanitized (no URL/password/token)

_Deferred (needs Docker): transaction_read_only=on, write-probe SQLSTATE 25006 caught without
aborting, real object GREEN (pre-0008) / RED (full) — covered by r0_preflight_local_test.sh._
