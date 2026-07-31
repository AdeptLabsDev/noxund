# DEC-0029 — PG-EXIT-P3A: OD-5 closed as REJECT SQITCH (atomicity falsification)

**Status:** ACTIVE (binding) · **Date:** 2026-07-31 · **Author:** Product Lead (ratified via Product Orchestrator)
**Scope:** Closes **OD-5** under NOXUND's specific requirements. **Docs-only unit** — no database, Compose, SQL, role, Sqitch install, workflow, Environment, secret, or remote connection is created or changed here. This record **points to** preserved evidence; it does **not** copy the evidence bundle.
**Extends:** [[DEC-0028]] §3 (Sqitch = candidate, adoption pending executable proof) and §8 (OD-5/OD-7 gated at PG-EXIT-P3). **Does not edit** DEC-0028 (frozen, additive-only).
**Predecessor units:** PG-EXIT-P3-DESIGN (spike design, delivered) → PG-EXIT-P3A (single fatal falsification experiment, executed).

---

## 1. Context

DEC-0028 §3 selected **Sqitch as the preferred candidate**, not an adoption, and required **executable proof on PostgreSQL 15** — requirement #2 being **atomicity between the change and the registry**. During P3-DESIGN a **blocking architectural divergence** was identified: on the PostgreSQL engine, Sqitch runs the deploy **script over an external `psql` connection** while the **registry is written over a separate DBI connection**, so the DDL and the registry record are **not** part of one transaction. Sqitch's documentation assumes each change is atomic; it does **not** promise joint DDL+registry atomicity.

The Product Lead authorized **only** a single fatal falsification experiment (**PG-EXIT-P3A**) — not the full P3 matrix — to test requirement #2 executably, on the principle that **no adoption may rest on documentation alone**.

## 2. Decision (binding)

1. **OD-5 is CLOSED as REJECT SQITCH.**
2. **Sqitch will NOT be NOXUND's authoritative migration runner.**
3. **Eliminatory reason:** the deploy SQL and the registry record are **not atomically confirmed** — a crash in the window `COMMIT(deploy) → registry-not-yet-written` leaves a committed schema object with **no** registry record, and Sqitch does not recover automatically.
4. **Scope of the rejection (explicit):** Sqitch is rejected **under NOXUND's specific requirements** (joint DDL↔registry atomicity as a non-negotiable). This is **not** a claim that Sqitch is universally inadequate; for projects that do not require joint atomicity it may be entirely appropriate.

## 3. Reproduced state (the falsification)

Deterministically reproduced (fatal window hit; independent-connection inspection):

- **`spike.atomicity_gap_probe` present** in the schema (DDL committed by the external psql).
- **`sqitch.changes` = 0 rows** for the change.
- **`sqitch.events` = 0** for the deploy (at kill time).
- **`sqitch status`** presented the change as **"Undeployed"** (registry is Sqitch's only truth; the committed object is invisible).
- A **new `sqitch deploy` attempted to reapply** the change and **failed** with `ERROR: relation "atomicity_gap_probe" already exists`.
- **`sqitch check` returned success** despite the drift (a false green).
- **No automatic repair** occurred (no adoption, no reconciliation).

This **directly violates the DDL↔registry atomicity requirement** (DEC-0028 §3 #2). Registry structurally intact; **0** prepared transactions; **0** orphan locks on `sqitch.changes`; **0** lingering backends — the killed DBI transaction (holding `LOCK TABLE changes`) was cleanly rolled back by PostgreSQL.

Per protocol, the **additional tests — verify, revert, concurrency, and the external SHA-256 manifest — were correctly halted** after this REJECT and were not run.

## 4. Root cause (architectural, source-confirmed)

In-image `App::Sqitch::Engine::pg` (v1.6.1): `run_file → _run('--file') → external psql` executes the DDL; `begin_work → $dbh->begin_work; LOCK TABLE changes IN EXCLUSIVE MODE` and `log_deploy_change` run over **DBI**. The DDL connection and the registry connection are **two connections / two transactions** by construction — the gap is structural, not incidental, and not configurable away.

## 5. Authoritative evidence (referenced, not copied to `main`)

The full transcript, timeline and dumps are preserved in the **spike branch commit** — this record points to it and does **not** duplicate the bundle onto `main`.

| Item | Value |
|---|---|
| Preserved branch | `spike/pg-exit-p3a-sqitch-atomicity` |
| Preserved commit | `8b36bd1` |
| Evidence path (in that commit) | `infra/postgres/spikes/p3a-sqitch-atomicity/` (`README.md`, `evidence/RESULT-timeline.md`, `psql-invocations.log`, `deploy.out.fatal-frozen`, `marker-DEPLOY_SQL_COMMITTED.ts`, `registry-*.csv`, `pg_dump-schema-only.sql`, `psql-wrap.sh`, `sqitch/`) |
| Sqitch | `v1.6.1` (official tag carries the `v`; bare `1.6.1` does not exist) |
| Sqitch image digest | `sha256:f247ab0e0b66e9c2d09a400864f7314358893f5cf209cddcc4f213f7d5bfe4d3` (running image == pinned digest) |
| PostgreSQL | `15.18` (`server_version_num = 150018`) |
| Killed-process exit | `137` (SIGKILL; `oom=false`) |
| Identity | `noxund_migrator` assuming `noxund_owner` — **no superuser** |
| Isolation | disposable project `noxund-p3a-*` (internal network, no host port); `noxund-local` untouched; teardown project-scoped, never `volume prune` |

No credentials appear in the bundle (ephemeral, internal-network-only; secret scan clean).

## 6. OD-7 — remains OPEN

The final form of change verification is **deferred to the successor runner**. To be decided **with** that runner (not now):

- **verify-per-migration** (invariants attached to each change);
- **cross-cutting SQL tests** (transversal/empirical contracts, e.g. the P2 `catalog_contract` + structural digest style);
- **reversal** (revert/undo strategy).

OD-7 must not be closed on Sqitch semantics, which no longer apply.

## 7. Next direction — candidates registered, NOT chosen

Recorded as candidates for evaluation; **none is adopted here**:

1. **Flyway Community.**
2. **A single-session, transactional psql-based runner** (one connection, DDL + ledger write in one PostgreSQL transaction).

Binding conditions on any successor:

- **Flyway must first pass the same fatal-interruption test** (the P3A atomicity falsification) before any consideration.
- **No adoption based on documentation alone** — executable proof on PostgreSQL 15 is mandatory.
- **Flyway Community's absence of undo/revert must be evaluated** explicitly (Community edition has no `undo`).
- **An own runner is acceptable ONLY if it stays thin, auditable, and free of any artisanal SQL parser.**

No P3B is created; nothing above is implemented.

## 8. Spike preservation (binding)

- **Do not** delete the spike branch (local or remote).
- **Do not** merge, rebase, or alter `8b36bd1`.
- **Do not** open a PR from the spike branch.
- **Do not** remove the evidence files.
- **Do not** repeat the test.
- **No manual DB intervention** is required: no `--log-only`, no repair, no manual registry insert, no adoption of the divergent state, no continuation of the P3 matrix, no new Sqitch tests.

## 9. Pareceres (multi-role review)

**Product Orchestrator.** The decision protects the thesis: a runner whose deploy and ledger can desynchronize would break the "every number traceable, reproducible" guarantee at the schema-provenance layer. Rejecting under our specific atomicity requirement — while explicitly not overclaiming universal unsuitability — is the correct, honest framing. OD-7 rightly waits for the successor. **APPROVE (docs-only).**

**Database.** The falsification is textbook: external-psql DDL + DBI registry = two transactions; a crash between them yields a committed object with no ledger row, which then wedges redeploy on the pre-existing object with no auto-repair. Joint atomicity is non-negotiable for a reproducible chain. A single-session transactional psql runner is the architecturally aligned candidate (one connection, one transaction for DDL+ledger). **APPROVE**; require the same fatal test for any successor.

**Security & Privacy.** Two hardening notes carried forward: (a) `sqitch check` returning success over a real drift is a **false-green** class we must not inherit — the successor's verify must fail-closed on ledger/schema divergence; (b) the experiment honored least-privilege (migrator→owner, no superuser), disposable isolation, no remote/Supabase, and produced a credential-free evidence bundle — the standard for any future runner trial. **APPROVE (docs-only).**

**DevOps/Infra.** Pinning discipline held (tool by version, image by digest, running==pinned). The rejection removes a CI trust risk (a runner that can leave a half-applied change). For candidates: Flyway must be pinned by image+digest and pass the identical interruption test; a bespoke runner must remain thin and parser-free to stay auditable in CI. **HOLD** any implementation until its own gated unit. **APPROVE** the direction.

**QA.** Verdict rests on observed facts only — object presence, `sqitch.changes`/`events` counts, exit codes (deploy killed 137; reapply 2; status 0; check 0), lock/prepared-xact state — not on documentation. Additional tests were correctly halted after REJECT. The evidence is reproducible from the preserved commit. **APPROVE.**

## 10. Out of scope (this unit)

Merge of this PR · any DB/remote/Supabase connection · `--log-only`/repair/manual registry insert/adoption of the divergent state · continuation of the P3 matrix · any new Sqitch test · **implementation** of Flyway or an own runner · creation of P3B · any edit to the spike branch or its evidence · any edit to prior DEC records or `context/` source-of-truth files.

---

*Related: [[DEC-0028]] (§3 Sqitch-candidate, §8 OD-5/OD-7). Preserved evidence: `spike/pg-exit-p3a-sqitch-atomicity` @ `8b36bd1`. OD-7 remains OPEN. Successor candidates (unchosen): Flyway Community; single-session transactional psql runner.*
