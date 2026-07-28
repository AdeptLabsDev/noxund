# SG-8 · R0 Preflight — Six-role review

**Reviewed content SHA (exact):** `7f20d95827078d7df0ecfcfc604008193e569ae0`
**Unit:** SG-8 remote promotion, gate R0 (author-only) · **Authorization:** DEC-0027
**Base:** main @ `be9012c` · **Date:** 2026-07-28 · **Posture:** read-only review of authored artifacts (no dispatch, no remote)

> All six reviews below are bound to the content commit `7f20d958…`. This review file is committed on
> top of it; it reviews the artifacts as of `7f20d958…`.
>
> **Cross-cutting honest finding (all roles):** the disposable-DB test
> `supabase/remote/tests/r0_preflight_local_test.sh` was **authored but NOT executed** in the authoring
> session (no Docker/Supabase/psql on the authoring host). Static validation was done (YAML parses; SQL
> markers balanced; single `READ ONLY` transaction ending in `ROLLBACK`; write-probe present; no
> `supabase` CLI / no DDL/apply in the workflow). **Every approval below is contingent on the local test
> passing in a Docker-capable environment BEFORE any future R0 dispatch.** This is a gating follow-up, not
> a merge blocker for author-only.

---

## 1. Database — verdict: APPROVE-WITH-NOTES

- Object-absence checks are **schema-scoped and name-exact** (4 tables via `to_regclass('public.…')`,
  enum `public.sg8_session_status`, the 3 guard functions by identity, `reports_id_run_key` on
  `public.reports`, role `sg8_compute_writer`) — not global prefix counts. Matches the 0008 inventory.
- Residue inventory (relations/types/routines/role `sg8\_%`) returns rows only if a **partial** object
  exists → RED + inventory, never removed/normalized. Correct.
- `pg_major == 15` is a hard GREEN gate mirroring the 0008/0009 harness. Correct.
- **Note D-1:** ledger `owner`/`RLS` are **reported** but not part of the GREEN gate. Acceptable for a
  pre-0008 preflight; if a hardened posture later wants ledger-owner assertions, that is a follow-up.
- **Note D-2:** R0 correctly does **not** claim to prove the 0008 `evidence.id` default (table absent);
  deferred to R2/R2.5. Good separation.

## 2. Data Integrity — verdict: APPROVE-WITH-NOTES

- **No mutation possible:** `BEGIN … READ ONLY`, `transaction_read_only='on'` asserted, a write probe
  (`CREATE TEMPORARY TABLE`) must fail with SQLSTATE 25006, and the script ends **only** in `ROLLBACK`.
  Ledger is **read** (full ordered content) and never inserted/repaired/altered.
- Deterministic digest excludes volatile fields (pid/now/ip/port/version-string) → same remote state ⇒
  same digest. Sound for an auditable decision input.
- **Note DI-1:** `env_ref_ok` derives the observed project ref from `current_user` (`postgres.<ref>` pooler
  form). If ops ever connects **directly** (`current_user='postgres'`, no ref), R0 goes RED on identity —
  a correct fail-closed, but flag it so a connection-mode change is a conscious decision.
- **Note DI-2:** the manual backup checklist is correctly **outside** the automated verdict and cannot be
  GREEN without operator evidence.

## 3. Data/AI Pipeline — verdict: APPROVE

- Preflight is deterministic-zone only; **zero** LLM/provider surface; consistent with DEC-0025.
- `gen_random_uuid()` handling is correct: `pg_catalog` presence, anti-shadowing
  (`to_regprocedure('gen_random_uuid()')` vs the qualified builtin), and PUBLIC EXECUTE resolved via
  `coalesce(proacl, acldefault('f', proowner))` + `aclexplode` (grantee 0) — the same technique 0009 §3
  relies on. No claim about the 0008 default, as required.
- Nothing here touches scoring, rubric, or the canonical report surface.

## 4. QA — verdict: APPROVE-WITH-NOTES (contingent)

- Positive/negative coverage is designed: pre-0008 ⇒ GREEN, full ⇒ RED, plus the read-only boundary
  assertion. Verdict discipline is GREEN-xor-RED (never "GREEN with observations").
- **Blocking follow-up QA-1:** execute `r0_preflight_local_test.sh` in a Docker-capable env and attach the
  transcript to the R0 record **before** any R0 dispatch. Not run in this session (host lacks Docker).
- **Note QA-2:** the write-probe relies on PostgreSQL disallowing `CREATE` in a READ ONLY txn (SQLSTATE
  25006). Validated by reasoning; the local test will confirm empirically (assert `fronteira enforçada`).
- **Note QA-3:** `git fetch --depth=200` in the ancestry check assumes target_sha is within ~200 commits
  of main tip. True for this PR's head; note as a robustness caveat if ever dispatched against an old SHA.

## 5. Security — verdict: APPROVE-WITH-NOTES

- `permissions: contents: read` only; **exactly one** Environment (`production-db`, required reviewer +
  main-only branch policy inherited); **no** new secret; **no** id-token; every `uses:` SHA-pinned;
  no `supabase` CLI, no `link`, no migration/repair/push/apply/DDL. Faithful least-privilege mirror of
  the phase5/entity apply governance **minus every write path**.
- **Secret hygiene:** DB URL built from Environment secret/vars and `::add-mask::`-ed; SQL output carries
  no password; the raw `r0_output.txt` is ephemeral and **not** uploaded as an artifact. Report to step
  summary is sanitized.
- **Read-only under a privileged identity:** running as the real (possibly high-privilege) executor is
  **required** to diagnose capabilities; the transaction-level `READ ONLY` prevents writes regardless of
  role, and capabilities are only reported, never exercised. Acceptable.
- **Note S-1:** main-only is enforced three ways (Environment branch policy + `github.ref` assert +
  `target_sha ∈ origin/main`) — defense-in-depth; good. Keep the Environment branch policy authoritative.
- **Note S-2:** confirm phrase `PREFLIGHT-SG8-R0-READONLY-NO-WRITES` is a human speed-bump, not a
  security control; the Environment reviewer approval is the real gate. Documented as such.

## 6. DevOps — verdict: APPROVE-WITH-NOTES

- `workflow_dispatch` only; serial concurrency `cancel-in-progress: false`; finite `timeout-minutes: 15`;
  pinned `actions/checkout@34e1148…` (v4.3.1); psql via apt (mirrors the hermetic harness). No second
  Environment, no artifact-upload action (report via `$GITHUB_STEP_SUMMARY`) — minimal surface.
- Pure-bash percent-encoding of the password avoids a `jq` dependency and keeps the secret off the
  process args; URL masked before use.
- **Blocking follow-up DO-1 (== QA-1):** run the disposable-DB test in CI/Docker and attach evidence
  before dispatch.
- **Note DO-2:** consider raising `fetch --depth` (or `--shallow-since`) if R0 is ever dispatched against
  a SHA far behind main; not an issue for the immediate head.
- **Note DO-3:** `apt-get install postgresql-client` is unpinned (consistent with existing workflows);
  acceptable, revisit if the org adopts pinned apt.

---

## Consolidated

| Role | Verdict |
|---|---|
| Database | APPROVE-WITH-NOTES |
| Data Integrity | APPROVE-WITH-NOTES |
| Data/AI Pipeline | APPROVE |
| QA | APPROVE-WITH-NOTES (contingent on QA-1) |
| Security | APPROVE-WITH-NOTES |
| DevOps | APPROVE-WITH-NOTES (contingent on DO-1) |

**Net:** the R0 authoring is sound for **author-only** (no merge, no dispatch). The single blocking
follow-up before any future R0 **dispatch** is executing the disposable-DB local test in a Docker-capable
environment (QA-1/DO-1). All notes are recorded; open decisions OD-1..OD-5 live in DEC-0027 §4.
