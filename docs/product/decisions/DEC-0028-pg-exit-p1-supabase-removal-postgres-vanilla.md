# DEC-0028 — PG-EXIT-P1: Supabase removal & adoption of vanilla PostgreSQL (documental ratification)

**Status:** ACTIVE (binding) · **Date:** 2026-07-30 · **Author:** Product Lead (ratified via Product Orchestrator)
**Scope:** Architectural direction of NOXUND's authoritative database. **Docs-only unit** — no Compose, SQL, roles, Sqitch, export, workflow, Environment, secret, or remote connection is created or changed here.
**Supersedes/extends:** [[DEC-0005]] (Auth = Supabase), [[DEC-0021]] (RO-1 Supabase auto-pause mitigation), and the Supabase-managed portions of `context/02_Stack_Infra_Architecture.md`. Neutralizes the remote-apply intent of [[DEC-0027]] (SG-8 R0 remote promotion) — its apply/verify path targeted managed Supabase and is now moot.
**Predecessor unit:** PG-EXIT-P0 (read-only repository audit) — accepted as complete.

---

## 1. Context

PG-EXIT-P0 established, from repository evidence only (no remote connection), that:

- **Supabase is used exclusively as (a) managed PostgreSQL and (b) migration/harness tooling (the CLI).** There is **zero** `@supabase/*`, `createClient`, `supabase.auth/.storage/.from`, or `supabase-js` in the code. Auth, Storage, Realtime, Edge Functions and PostgREST were **never integrated**; the only Supabase coupling is at the **schema level** (`auth.users` FKs, `auth.uid()`, roles `anon/authenticated/service_role/authenticator`, the `supabase_migrations` ledger).
- Migrations **0001–0006 are applied and verified LIVE** on the managed project `pwbkplzyzmortwjjpcbg` (DEC-0008/0010/0009/0011/0012/0015). **0007** is parked (off `main`). **0008/0009 are design-only, never applied.**
- The only irreplaceable business data on the remote is the frozen raw dataset of `run_id f0485de6-…` (500 videos + 146 channels) — sacred and non-regenerable (recollection = new `run_id`).

This unit ratifies the exit **on paper only**. Nothing is implemented.

## 2. Architectural decision (binding)

1. **Managed Supabase will be removed** from NOXUND's future architecture.
2. **PostgreSQL remains the authoritative database.**
3. **Development and CI will use vanilla PostgreSQL 15 in Docker.**
4. **Future production will run on remote PostgreSQL outside Supabase.**
5. **SQLite will NOT be the authoritative database.**
6. **Auth, Storage, Realtime, Edge Functions and PostgREST need NO replacement** — they were never integrated (P0 finding). Only the schema-level coupling (`auth.users`/`auth.uid()`/Supabase roles/ledger) must be ported.
7. **Applied Supabase migrations and design-only artifacts remain frozen as history** (see §5).

## 3. Sqitch — binding correction (NOT an adoption)

Overriding the P0 return's tentative phrasing:

- **Sqitch is the PREFERRED CANDIDATE selected for the PG-EXIT-P3 spike — not a definitive adoption.**
- **Final adoption depends on executable proof on PostgreSQL 15.**
- Sqitch's registry is a **candidate** to replace `supabase_migrations.schema_migrations`, **but is NOT yet approved** — the ledger open decision is **NOT closed**.
- The **full-verify vs. Sqitch light-verify** strategy stays **OPEN until P3**.
- **No artisanal ledger and no bespoke psql runner is authorized** in this or any unit until P3 rules.

**P3 must prove (all, executably, on PG15, locally AND in CI):**

| # | Requirement |
|---|---|
| 1 | Deploy of an exact change |
| 2 | Atomicity between the change and the registry |
| 3 | Behavior on failure **before** and **after** the registry write |
| 4 | Checksum and immutability |
| 5 | Explicit dependencies |
| 6 | Revert |
| 7 | Redeploy |
| 8 | Fail-closed verify |
| 9 | Concurrency |
| 10 | Tool **and** image pinned |
| 11 | PostgreSQL 15 |
| 12 | Local **and** CI execution |
| 13 | **No automatic repair** operation |

## 4. Identity — OD-1 (decision)

1. **`noxund_identity.users` is the canonical internal identity.**
2. **Business FKs reference ONLY its internal UUID** (never an external provider id).
3. **External identities will be mapped later by a SEPARATE table** (internal UUID ↔ external subject).
4. **The authentication provider remains OPEN** (Auth.js/Clerk/WorkOS/other — future decision).
5. **No login system is implemented in P1.**
6. **No password, session, token or OAuth is created** in P1.
7. **`auth.uid()` will later be replaced by a transaction-local actor** (e.g. a session GUC set by the handler) — not implemented here.
8. **Runtime is NEVER owner and NEVER `BYPASSRLS`.**
9. **A missing or invalid actor MUST deny access** (fail-closed).

This supersedes [[DEC-0005]] (Auth = Supabase). Cost of decoupling now is minimal: zero producers onboarded.

## 5. Migrations (frozen legacy vs. new vanilla chain)

1. **`supabase/migrations/0001–0006` are applied legacy and frozen.**
2. **0008/0009 remain preserved as artifacts of the prior Supabase architecture.**
3. **None of these files will be edited, renumbered or reinterpreted.**
4. **The vanilla PostgreSQL chain will have NEW files, NEW checksums and a NEW namespace.**
5. **An explicit legacy → vanilla map will be authored later** (which legacy change each vanilla change reproduces).

## 6. Data (critical patrimony)

1. Critical patrimony: **run `f0485de6-0d34-41cf-ab48-d46e483aa558`** — **500 videos**, **146 channels**.
2. **All schemas and application data will be inventoried before any export.**
3. **The raw subset receives reinforced counts and digests.**
4. **No export in this unit.**
5. **`session_replication_role = replica` is NOT authorized** (no trigger-bypass restore path is sanctioned here).

## 7. PR #65 handling

**During P1:**
- Keep frozen at `2d0fbcd1eec1bf8f79451e0aa106c7b0a857dba7`.
- Preserve failed run `30450421392`.
- No rerun, correction, merge or dispatch.

**After the manual merge of P1:**
- Close PR #65 as **SUPERSEDED — NOT MERGED**.
- Add a comment pointing to this decision (**DEC-0028 / PG-EXIT-P1**).
- Preserve branch, commits, logs and evidence.

## 8. Open decisions (kept explicitly OPEN after P1)

| OD | Question | Gate |
|---|---|---|
| **OD-2** | Vanilla design of the former 0009 (dedicated write identity + grants + policies, minus the `service_role`/`authenticator` revoke choreography, which has no subject in vanilla) | before porting the SG-8 identity unit |
| **OD-3** | Own VM vs. managed non-Supabase PostgreSQL for production | PG-EXIT-P10 |
| **OD-4** | Legacy `supabase/` layout vs. new `db/` layout | PG-EXIT-P2/P3 |
| **OD-5** | Definitive approval of Sqitch **and** its registry (as ledger replacement) | PG-EXIT-P3 (proof) |
| **OD-6** | Future authentication provider **and** mechanism | after identity table lands |
| **OD-7** | Final form of verifies under the Sqitch model (full vs. light) | PG-EXIT-P3 |

## 9. Plan P2–P10 (proposal — nothing executed; each gated docs/design→GO)

| Unit | Object | Nature |
|---|---|---|
| **P2** | `docker-compose.yml` PG15 vanilla (loopback-only, named volume, healthcheck) + `init` role bootstrap (model §candidate roles) | design/impl on GO |
| **P3** | **Sqitch spike** proving the 13 requirements of §3 on PG15 (local + CI); rules OD-5/OD-7 and the ledger | executable spike |
| **P4** | Port legacy 0001 → vanilla: `noxund_identity.users`, `is_admin()` via transaction-local actor, drop Supabase-role grants; Security re-review | design/impl on GO |
| **P5** | Port legacy 0002–0006 → vanilla (mechanical: remove `anon/authenticated` grantees); verifies updated | design/impl on GO |
| **P6** | Rewrite hermetic CI harness without the Supabase CLI (Compose + Sqitch), preserving loopback-only / no-secrets / SHA-pin / always-destroy invariants | design/impl on GO |
| **P7** | Vanilla design of the SG-8 units (former 0008 ~intact; former 0009 rewritten per OD-2). **Resolves PR #65's destination.** | design/impl on GO |
| **P8** | Retire obsolete env/secrets/vars; re-point Environments (`production-db`→self-hosted; `youtube-collection` keeps `YOUTUBE_API_KEY`) | design/impl on GO |
| **P9** | Inventory + export/restore of the raw dataset (`f0485de6`, 500/146) to the self-hosted DB, with reinforced counts + digests and destination §7 re-verify | gated window |
| **P10** | Remote production PostgreSQL: host + TLS (`verify-full`) + backup/PITR + monitoring + cutover/rollback | design/impl on GO |

## 10. Pareceres (multi-role review of this ratification)

**Product Orchestrator.** The decision holds the MVP thesis intact: the pipeline stays deterministic, auditable and reproducible; the raw remains sacred; no Fase-2/marketplace surface is introduced; the closed-access posture is unaffected. Removing an unused managed surface (Auth/Storage/Realtime/Edge/PostgREST) reduces the attack/complexity surface with no product regression. **APPROVE.**

**Database.** Portability is high: 0002–0006 are vanilla-clean once the non-existent `anon/authenticated` grantees are dropped; `gen_random_uuid()` is core in PG15 (no pgcrypto). The real work is concentrated in 0001 (identity) and the former 0009 (role model), both correctly deferred to gated units (P4/P7) with a fresh checksum namespace so nothing already-reviewed is silently reinterpreted. Freezing legacy files and authoring an explicit legacy→vanilla map is the correct integrity discipline. **APPROVE** with the standard condition that every ported DDL gets a Database + Security re-review before any apply.

**Security & Privacy.** Net posture improves: default-deny RLS and the trigger-enforced immutability are PostgreSQL-native and survive the move; the OD-1 guarantees (runtime never owner, never `BYPASSRLS`, fail-closed on missing/invalid actor) are exactly the invariants SEC-0001/§0 requires, now made explicit. The `service_role` bypass path disappears entirely, which is a hardening, not a risk. Fase 9 veto (SEC-0001 §0) remains standing; no auth/login/secret is created in P1. Binding conditions carried forward: no export and **no `session_replication_role=replica`** in this unit; the raw dataset stays protected until the destination proves parity + backup. **APPROVE (docs-only).**

**DevOps/Infra.** The Sqitch correction is the right call — no tool is adopted without executable proof on PG15, and the 13-point P3 matrix (atomicity, fail-before/after-registry, checksum, concurrency, no auto-repair, pinned tool+image) is the correct bar before trusting any migration engine in CI. Eliminating the Supabase CLI also removes the guard false-positive class that failed PR #65's run `30450421392`. The hermetic-harness invariants (loopback-only, no secrets, SHA-pin, always-destroy) must be preserved in P6. **APPROVE** the direction; **HOLD** any harness/Compose implementation until its own gated unit.

## 11. Out of scope (this unit)

Remote connection · export · `pg_dump`/restore · Docker Compose · role creation · Sqitch install/plan · any SQL/migration/rollback/verify · any workflow/Environment/secret/variable change · any edit to migrations 0001–0009 · any edit to `context/` source-of-truth files (a later docs unit reconciles `02_Stack_Infra_Architecture.md`) · **merge of this PR**.

---

*Related: [[DEC-0005]], [[DEC-0021]], [[DEC-0027]], [[DEC-0026]]. Predecessor: PG-EXIT-P0 read-only audit. Frozen artifacts: `supabase/migrations/2026062000000{1..6,8,9}`, PR #65 @ `2d0fbcd`.*
