# SUPABASE LEGACY STRUCTURAL BRIEF — R0

**Status:** DURABLE STRUCTURAL RECORD — docs-only, non-authority
**Subject:** Supabase project `pwbkplzyzmortwjjpcbg` (legacy NOXUND source database)
**Purpose:** Final live structural inventory of the source database, and successor-design input
**Created:** 2026-08-16
**Supersedes:** nothing. **Modifies:** nothing. **Authorizes:** nothing.

---

## 0. WHAT THIS DOCUMENT IS, AND WHAT IT IS NOT

This is the durable, policy-safe, NOXUND-native record of the **live structural
state** of the legacy Supabase source database, captured immediately before that
project's intended permanent retirement.

It exists because the source is intended not to survive. Once the project is
deleted, the facts recorded here become unobtainable: no exported dump, no
off-platform copy and no second live instance exists. The only residual copy is the
platform-held pre-pause logical backup, which terminates with the project (§5,
§9.2-A) and which this inspection neither read nor downloaded.

**This document is not a decision record.** It does not modify, supersede or
reinterpret DEC-0028 or DEC-0033. It ratifies no architecture, selects no successor
version, adopts no collation policy, and authorizes no deletion. Where a design
choice is implied by an observation, that choice is recorded in §8 as an **open**
decision belonging to a future unit, not resolved here.

**This document deliberately contains no YouTube API data.** See §10.

### 0.1 Relationship to the repository migrations, and the exact scope of the match

Migrations `0001`–`0006` under `supabase/migrations/` are, and remain, the
**authoritative DDL** for the NOXUND application schema.

**What the inspection verified.** The live database corresponds to those six
migrations element-for-element at every level inspected: 19/19 relations (§2.6),
the applied ledger (§2.14), the constraint census (§2.7, with its reconciliation),
the index census (§2.8, with its reconciliation), the function census (§2.12.1 —
14 of 15 correspond), the trigger census (§2.12.2), the enum set (§2.5), RLS state
and policy count (§2.9), and the **`revoke` half** of the table ACLs (§2.10).

**What the inspection did not verify.** No column-by-column reconciliation of type,
nullability or default expression was performed against the migration text. Column
facts were read from the live catalog (§2.6.1) but were not diffed statement-by-statement
against the DDL.

**What does not correspond at all.** Two things.

1. The function `public.rls_auto_enable()` and the event trigger `ensure_rls` have no
   counterpart in source control (§2.13.1, D-4).
2. **The `service_role` table ACL entry corresponds to no migration statement** (D-18).
   Migrations 0001–0006 contain zero `GRANT … ON TABLE`; their only table-level
   privilege statements are the 19 `revoke all … from anon, authenticated`, which *are*
   reflected exactly. **The origin of the `service_role=Dxtm/postgres` entry is not
   established**, and its *shape* is itself unexplained — see D-18.

**A third possible divergence cannot be excluded:** `pg_default_acl` and the `public`
schema ACL are declared by no migration and were never inspected, so whether they held
anything at all is unknown (§9.2-D-1, §9.3). An uninspected catalog cannot be shown not
to correspond, so it is recorded here as an open question rather than as a divergence.

Items 1 and 2 alone establish that state reached this database through at least one
channel outside the migration ledger, producing objects owned by, and grants recorded
with the grantor, `postgres`. **Which identity executed that DDL is not determined**
(§2.13.1). Consequently, "the migrations are authoritative" is a statement about the
application schema as verified above — **not** an unconditional guarantee that nothing
else was ever executed.

Subject to those bounds, this brief does not duplicate the migration DDL. Its value
is confined to what the repository cannot contain: live server, locale and collation
identity; live ownership, privilege and RLS enforcement reality; objects present
live but absent from source control; the applied-migration ledger state; population
verdicts; the exact Supabase coupling surface; and the divergences between what the
repository assumes and what was actually running.

---

## 1. PROVENANCE OF THIS RECORD

| | |
|---|---|
| Source inspection | `SUPABASE-FINAL-STRUCTURAL-INSPECTION-EXECUTION-R1` |
| Handoff of record | `SUPABASE-FINAL-STRUCTURAL-INSPECTION-HANDOFF-R1` |
| Access path | Supabase Dashboard SQL Editor, Product-Lead operated |
| Session identity | `postgres` (`current_user` = `session_user`) |
| Enforcement | every statement wrapped `BEGIN; SET TRANSACTION READ ONLY; SET LOCAL statement_timeout='60s'; … ROLLBACK;` |
| Statements issued | 26 (25 succeeded; 1 failed harmlessly inside a read-only transaction and was reissued strictly narrower — it referenced `lc_collate`/`lc_ctype`, removed as server variables in PostgreSQL 16, which is the one point where the inspection's own assumption was pre-16 while the server was 17.6) |
| COMMIT / DDL / DML | **0 / 0 / 0** |
| Exports / dumps / backup downloads | **0 / 0 / 0** |
| Product-Lead-adjudicated query deviations | 4 — `Q1-ALIAS-CORRECTION` (output labels only); `Q1-SUPPLEMENT` (locale provider, locale, collation version); `Q15-C` (the five `public` tables the original probe set omitted, which is what makes §2.15's "all 19 measured" true); `Q9-SUPPLEMENT` (`pg_event_trigger`, without which §2.13 would not exist) |
| Product-Lead scope decision | `SKIP-NONPUBLIC-DETAIL` (§9.2-D-4) |
| Project state during and after | RESUMED / HEALTHY, unmutated |

The inspection was preceded by `SUPABASE-FINAL-STRUCTURAL-INSPECTION-ACCESS-PATH-PREFLIGHT-R1`,
which established the Dashboard SQL Editor as the access path requiring no database
credential, and which recorded that no local PostgreSQL client tooling exists on the
operator workstation.

**The source database is not to be queried again** unless the Product Lead
separately reopens that authority.

---

## 2. OBSERVED LIVE FACTS

Everything in this section was read directly from the live source database, except
where a statement is explicitly marked as non-observed context.

### 2.1 Server and database identity

| Fact | Observed value |
|---|---|
| Server version | **PostgreSQL 17.6** on `x86_64-pc-linux-gnu`, compiled by gcc 15.2.0, 64-bit |
| Database name | `postgres` |
| Database owner | `postgres` |
| `datconnlimit` | `-1` (unlimited) |
| Database comment | `default administrative connection database` (stock PostgreSQL text, never customised) |
| Default tablespace | `pg_default` — **derived, see caveat** |

> **Caveat on default tablespace.** The issuing query cast `dattablespace::regclass`,
> which resolves against `pg_class` and is the wrong catalog for a tablespace OID. It
> therefore returned the bare OID `1663`. That is PostgreSQL's fixed, well-known OID
> for `pg_default`, so the name is recovered from OID stability rather than read
> correctly. Consequence is nil; the caveat is recorded because this value can never
> be re-checked.

The NOXUND schema lives in the **`postgres` administrative database**. No
purpose-named database was ever created. This is Supabase platform convention, not a
NOXUND design decision.

### 2.2 Encoding, timezone, locale and collation

| Fact | Observed value |
|---|---|
| `server_encoding` | **UTF8** |
| Timezone | **UTC** |
| `datcollate` | `en_US.UTF-8` |
| `datctype` | `en_US.UTF-8` |
| **Locale provider (`datlocprovider`)** | **`i` — ICU** |
| **Locale (`datlocale`)** | **`en-US`** |
| **Collation version (`datcollversion`)** | **`153.121`** |
| ICU rules (`daticurules`) | `NULL` — no custom tailoring |

**These facts must be read together, not separately.** Because the provider is ICU,
`datcollate` and `datctype` name a libc locale that does **not** govern the
database's default sort order. The effective default collation is **ICU `en-US`** at
collator version `153.121`, with no custom rules.

Further observed: **every text column in the application schema uses the database
default collation.** No column overrides it; there is no `COLLATE "C"` anywhere,
including on opaque identifier columns. Three `UNIQUE` indexes are built over
`lower()` of text columns (§2.8), which makes their uniqueness semantics dependent on
the collation's case-mapping rules for non-ASCII input.

> **Precision limit on what these facts pin.** `datcollversion` is the value
> PostgreSQL compares to detect *collation* (sort-order) version drift. It does **not**
> specify ICU **case-mapping** behaviour, which is what the three `lower()` indexes
> actually depend on, and ICU integration differs across PostgreSQL major versions.
> The recorded facts are therefore sufficient to **identify** the source's semantics,
> not necessarily to guarantee their reproduction.

> **These are recorded as observed source facts only.** This brief does **not** ratify
> reproducing these semantics in the successor. Successor collation policy is an open
> decision — §8, OD-B.

### 2.3 Schema census — 11 schemas

| Schema | Owner | Class |
|---|---|---|
| `public` | `pg_database_owner` | **NOXUND application schema** |
| `auth` | `supabase_admin` | Supabase-managed |
| `storage` | `supabase_admin` | Supabase-managed |
| `realtime` | `supabase_admin` | Supabase-managed |
| `vault` | `supabase_admin` | Supabase-managed |
| `graphql` | `supabase_admin` | Supabase-managed (scaffolding) |
| `graphql_public` | `supabase_admin` | Supabase-managed (scaffolding) |
| `information_schema` | `supabase_admin` | core PostgreSQL, owner reassigned by platform |
| `extensions` | `postgres` | Supabase platform convention |
| `supabase_migrations` | `postgres` | Supabase migration ledger |
| `pgbouncer` | `pgbouncer` | pooler infrastructure |

`public` is owned by **`pg_database_owner`** — the PostgreSQL 14+ default — which
resolves ownership dynamically to whoever owns the database, rather than to a named
role. **All NOXUND objects live in `public`; no NOXUND-specific schema was ever
created.**

**Taxonomy used consistently throughout this brief:** 6 Supabase-managed schemas
(`auth`, `storage`, `realtime`, `vault`, `graphql`, `graphql_public`); 3 further
non-NOXUND schemas retired with the project (`extensions`, `supabase_migrations`,
`pgbouncer`) — **9 schemas retired in total** (§5); plus `information_schema` (core
PostgreSQL) and `public` (the application schema).

### 2.4 Extension census — 5 extensions

| Extension | Version | Schema | Portability |
|---|---|---|---|
| `plpgsql` | 1.0 | `pg_catalog` | core |
| `pg_stat_statements` | 1.11 | `extensions` | standard contrib |
| `pgcrypto` | 1.3 | `extensions` | standard contrib |
| `uuid-ossp` | 1.1 | `extensions` | standard contrib |
| **`supabase_vault`** | **0.3.1** | `vault` | **Supabase-proprietary** |

`supabase_vault` is the only non-portable extension, and **no NOXUND object
references it**.

**Absent** — recorded because absence bounds the exit surface: `pg_cron`, `pg_net`,
`pg_graphql`, `pgsodium`, `pgjwt`, `postgis`, `vector`.

`gen_random_uuid()` — the default on every NOXUND primary key — is a **core
`pg_catalog` function on PostgreSQL 13+** and does not require `pgcrypto`. The
historical grant question surrounding it was a packaging artifact of this platform.

### 2.5 Type census

- **9 enum types**, all in `public`, all NOXUND product taxonomy:
  `report_run_status`, `report_status`, `application_status`, `producer_status`,
  `entity_candidate_status`, `audit_actor_type`, `artist_alias_source`,
  `video_artist_method`, `competition_level`.
  Label sets are recorded in the migrations. **No enum label is derived from API data.**
- **0 domains** in `public`.
- **0 user-defined composite types** in `public` beyond the implicit row type
  PostgreSQL creates per relation.

`report_run_status` confirms run state is enum-enforced rather than CHECK-enforced.
Both `video_artist_method` and `artist_alias_source` carry an `llm_assisted` label,
consistent with the decoupling history recorded elsewhere.

### 2.6 `public` relation census — 19 tables

Every relation in `public` is `relkind = 'r'` (ordinary table) and
`relpersistence = 'p'` (permanent — no unlogged or temporary tables). **There are no
views, no materialized views, no partitioned tables and no foreign tables in the
application schema.**

| # | Table | Migration | Class | Population |
|---|---|---|---|---|
| 1 | `producers` | 0001 | first-party product | **EMPTY** |
| 2 | `applications` | 0001 | first-party product | **EMPTY** |
| 3 | `admin_users` | 0001 | first-party identity control | **EMPTY** |
| 4 | `audit_events` | 0001 | append-only audit | **EMPTY** |
| 5 | `rubric_versions` | 0002 | versioned config | **EMPTY** |
| 6 | `outcome_weight_versions` | 0002 | versioned config | **EMPTY** |
| 7 | `report_runs` | 0003 | provenance anchor | **NONEMPTY — 1 row** |
| 8 | `artists` | 0003 | canonical entity | **EMPTY** |
| 9 | `artist_aliases` | 0003 | canonical entity | **EMPTY** |
| 10 | `raw_youtube_search_pages` | 0004 | **restricted raw** | **NONEMPTY (boolean only)** |
| 11 | `raw_youtube_videos` | 0004 | **restricted raw** | **NONEMPTY (boolean only)** |
| 12 | `raw_youtube_channels` | 0004 | **restricted raw** | **NONEMPTY (boolean only)** |
| 13 | `video_artist_mappings` | 0005 | computed | **EMPTY** |
| 14 | `channel_eligibility` | 0005 | computed | **EMPTY** |
| 15 | `artist_metrics` | 0005 | computed | **EMPTY** |
| 16 | `artist_metric_videos` | 0005 | computed provenance | **EMPTY** |
| 17 | `reports` | 0005 | snapshot | **EMPTY** |
| 18 | `report_items` | 0005 | snapshot | **EMPTY** |
| 19 | `entity_resolution_candidates` | 0006 | mutable staging | **EMPTY** |

**19 live tables against 19 declarations across migrations 0001–0006 — an exact
element-for-element match.**

For the three restricted raw tables, **only a boolean NONEMPTY verdict is recorded**.
Their cardinalities were deliberately never retrieved and are not recorded here — §10.

#### 2.6.1 Column-level facts

- **No generated columns and no identity columns anywhere in `public`.**
- Every primary key is `uuid NOT NULL DEFAULT gen_random_uuid()`.
- Every text column resolves to the database default collation (§2.2).
- `producers` declares the first-party PII surface — `email`, `display_name`,
  `youtube_url`, `portfolio_url`, `niche` — **and holds zero rows** (§2.15.1).
- The raw tier stores API-origin values **twice per row**: once verbatim in a `jsonb`
  column, and once projected into typed columns (D-6). Column *names* and types are in
  migration 0004; no value of any kind is recorded here.

### 2.7 Constraint census — 68 constraints in `public`

| Class | Count |
|---|---|
| PRIMARY KEY | **19** (one per table) |
| UNIQUE constraints | **9** |
| FOREIGN KEY | **28** |
| CHECK | **12** |

**Reconciliation against source control:** migrations 0001–0006 declare 28 foreign keys
(5 + 0 + 1 + 3 + 16 + 3) and 12 CHECK constraints (1 + 0 + 1 + 3 + 3 + 4), plus 19 primary
keys and 9 UNIQUE constraints. **19 + 9 + 28 + 12 = 68**, matching the live census exactly.
Recorded for the same reason as §2.8's index arithmetic: it is the durable proof of the
constraint half of §0.1 and cannot be recomputed once the source is gone.

All constraints are `convalidated = true` (none `NOT VALID`), `condeferrable = false`
(**foreign-key checks cannot be deferred inside a transaction**), and
`confmatchtype = 's'` — MATCH SIMPLE, meaning a composite foreign key is **not
enforced when any of its columns is NULL**. That last property is live for
`report_items_example_raw_fk`, whose `example_video_id` is nullable. Consequence is
nil in the observed state: every referencing table is empty.

#### 2.7.1 Referential topology of the raw tier — 5 edges, all RESTRICT

`artist_metric_videos`, `channel_eligibility`, `entity_resolution_candidates`,
`report_items` (via `example_video_id`) and `video_artist_mappings` each hold a
composite foreign key into a raw table, **all `ON DELETE RESTRICT`**. **All five
referencing tables are EMPTY**, so no foreign key constrains any raw row in the
observed state.

#### 2.7.2 Referential topology of the provenance anchor — 8 edges, all RESTRICT

Eight foreign keys target `report_runs(id)`, all `ON DELETE RESTRICT`. Five originate
in empty tables; **three originate in the three NONEMPTY raw tables**.

#### 2.7.3 The SEC-F08 credential guards

All three raw tables carry, live and validated:

```sql
CHECK (NOT (raw_json ?| ARRAY['config','request','headers','authorization','key']))
```

(`response_json` in place of `raw_json` on `raw_youtube_search_pages`.) The `?|`
operator tests **top-level keys only**; a credential nested one level deeper would
satisfy this check.

**No breach is indicated:** the constraint is `convalidated = true`, so every stored row
satisfied **this predicate** at insert. That is emphatically *not* a statement that the
payload is credential-free at any depth — **the payload itself was never inspected**
(§10.1). This records the guard's depth as an assumption not to inherit (D-10).

#### 2.7.4 Function-backed CHECK constraints

Two CHECK constraints are backed by functions: `artist_metrics_detail_complete(metrics_detail_json)`
on `artist_metrics`, and `report_item_reason_complete(selection_reason_json)` on
`report_items`. Both functions are `IMMUTABLE`, which is the correct volatility for a
constraint predicate.

### 2.8 Index census — 52 indexes in `public`

**Reconciliation against source control:** migrations 0001–0006 declare 24 explicit
`CREATE [UNIQUE] INDEX` statements; the 19 primary keys and 9 unique constraints
(§2.7) contribute one backing index each. **24 + 19 + 9 = 52**, matching the live
count exactly. This arithmetic is the durable proof of the index half of §0.1 and is
recorded because it cannot be recomputed once the source is gone.

Structurally significant members:

- **Bare composite unique indexes serving as foreign-key targets** —
  `raw_youtube_videos_run_video_uidx (run_id, video_id)`,
  `raw_youtube_channels_run_channel_uidx (run_id, channel_id)`,
  `video_artist_mappings_run_video_uidx`, `channel_eligibility_run_channel_uidx`.
  These are `CREATE UNIQUE INDEX`, **not** unique constraints (D-7).
- **Three `UNIQUE` indexes over `lower()`** — `artists_canonical_name_lower_uidx`,
  `artist_aliases_alias_lower_uidx`, `producers_email_lower_uidx` (D-3).
- **Partial indexes encoding business invariants** —
  `applications_one_open_per_producer_uidx` (`WHERE status IN ('submitted','under_review')`);
  `entity_resolution_candidates_pending_uidx (run_id, video_id) WHERE status='pending'`;
  `entity_resolution_candidates_pending_queue_idx`;
  `entity_resolution_candidates_artist_idx WHERE artist_id IS NOT NULL`.
- **`raw_youtube_search_pages_run_page_uidx ON (run_id, COALESCE(page_token, ''))`** —
  an expression index solving the nullable-first-page problem.
- **Zero GIN indexes on any `jsonb` column**, consistent with an archival-by-design
  raw tier (D-13).

### 2.9 Ownership, RLS and enforcement reality

**All 19 `public` tables are owned by `postgres`.** No dedicated application-owner
role exists; ownership was never separated from the platform's primary role.

By contrast, the platform practises the separation the application schema never
adopted. Relation-level ownership was observed across all schemas: `auth` relations
are owned by `supabase_auth_admin`, `storage` relations by `supabase_storage_admin`,
and `realtime` relations by `supabase_realtime_admin` except
`realtime.schema_migrations`, which is owned by `supabase_admin`.

| Measure | Observed |
|---|---|
| Tables with RLS **enabled** | **19 / 19** |
| Tables with **`FORCE ROW LEVEL SECURITY`** | **0 / 19** |
| **RLS policies in `public`** | **0** |

**Reconciliation against source control:** migrations 0001–0006 declare **19**
`enable row level security` statements (4 + 2 + 3 + 3 + 6 + 1), one per table, matching
the live 19/19, and **zero** `force row level security` statements, matching the live
0/19. Recorded in the same form as §2.7, §2.8, §2.12.1 and §2.12.2 — and load-bearing,
because §2.13.1's weight assessment for the existing 19 tables rests on it.

**Zero policies is the specification, not an omission.** Migrations 0001–0006 declare
no `create policy` statements, deliberately, with the reasoning recorded inline in
the migration source: default-deny, RLS enabled plus `revoke`, with the
producer-facing surface held under an explicit security veto.

The resulting model is **binary**: against any role that is neither the table owner
nor a holder of `BYPASSRLS`, RLS here is not weakly enforced but *maximally* enforced
— nothing is reachable. Against the owner, it is not enforced at all.

### 2.10 Privilege reality

**Table ACLs are uniform across all 19 tables:**

```
{postgres=arwdDxtm/postgres, service_role=Dxtm/postgres}
```

- `postgres` holds `a r w d D x t m` — INSERT, SELECT, UPDATE, DELETE, TRUNCATE,
  REFERENCES, TRIGGER, MAINTAIN.
- **`service_role` holds `D x t m` — TRUNCATE, REFERENCES, TRIGGER, MAINTAIN.** It has
  no table-level SELECT, INSERT, UPDATE or DELETE.
- **`anon` and `authenticated` have no table ACL entry at all** — the `revoke all` in
  the migrations is reflected exactly.
- **There is no `PUBLIC` grantee entry** on any of the 19 tables.
- The grantor is `postgres` throughout (`/postgres`), which constrains who may issue a
  matching `REVOKE`.

**Scope of these statements:** they describe **table-level** ACLs (`pg_class.relacl`).
Column-level ACLs (`pg_attribute.attacl`) and function ACLs (`pg_proc.proacl`) were
**not enumerated** — see §9.2-D.

**`service_role`'s retained bits are not all benign.** `m` (MAINTAIN) is administrative;
`x` (REFERENCES) permits pinning schema evolution through new foreign keys; and
**`t` (TRIGGER) permits attaching triggers to all 19 tables, including the
immutability-guarded raw tier.** `D` (TRUNCATE) is the residual documented in the
migration *comments* but **granted by no migration statement** (D-18; repository-derived —
see the non-observed-context note at the end of §2.11). It is unguarded on the eight
trigger-free tables; `artist_metrics` is likewise unguarded but is **blocked by the
referential topology** (§2.12.2), so it is not truncatable in the observed state.
**Consequence is nil in the observed state:** every one of those tables is empty.

**`m` (MAINTAIN) exists only from PostgreSQL 17.** The observed ACL string is
therefore not directly replayable against a successor on an older major version
(relates to OD-A).

### 2.11 Role reality

| Role | `rolsuper` | `rolbypassrls` | `rolcanlogin` | `rolinherit` | Member of |
|---|---|---|---|---|---|
| `postgres` | **false** | **true** | true | true | `pg_monitor`, `pg_signal_backend`, `pg_read_all_data`, `pg_create_subscription`, `anon`, `authenticated`, `service_role`, `authenticator`, `supabase_privileged_role` |
| `supabase_admin` | **true** | true | true | true | — |
| `service_role` | false | **true** | **false** | true | — |
| `supabase_etl_admin` | false | **true** | true | true | `pg_monitor`, `pg_read_all_data`, `supabase_privileged_role` |
| `supabase_read_only_user` | false | **true** | **true** | true | `pg_monitor`, `pg_read_all_data` |
| `authenticator` | false | false | **true** | **false** | `anon`, `authenticated`, `service_role` |
| `anon` | false | false | false | true | — |
| `authenticated` | false | false | false | true | — |
| `supabase_auth_admin` | false | false | true | false | — |
| `supabase_storage_admin` | false | false | true | false | `authenticator` |
| `supabase_realtime_admin` | false | false | false | false | — |
| `supabase_replication_admin` | false | false | true | true | — |
| `supabase_privileged_role` | false | false | false | true | — |
| `pgbouncer` | false | false | true | true | — |
| `dashboard_user` | false | false | false | true | — |

**Five roles hold `BYPASSRLS`:** `postgres`, `service_role`, `supabase_admin`,
`supabase_etl_admin`, `supabase_read_only_user`. `supabase_admin` is the only
superuser.

**`postgres` is not a superuser but bypasses RLS by two independent mechanisms
simultaneously:** table ownership without `FORCE RLS`, and the `BYPASSRLS` attribute.
It additionally inherits `pg_read_all_data`. **Removing either mechanism alone would
change nothing.**

**The externally reachable privilege chains in the observed state** are worth stating
assembled, because they are split across three catalogs. `service_role` cannot log in
(`rolcanlogin = false`), but `authenticator` — the PostgREST login role — is a member of
it and, having `rolinherit = false`, reaches it by explicit `SET ROLE`. **`supabase_storage_admin`
is also `rolcanlogin` and is in turn a member of `authenticator`**, so two login-capable
roles reach `service_role` by `SET ROLE`. The resulting identity holds `BYPASSRLS` plus
TRUNCATE / REFERENCES / TRIGGER / MAINTAIN on all 19 tables, and **no SELECT**. Note that
this works precisely *because* it routes through `SET ROLE` rather than inheritance:
`BYPASSRLS` is a role attribute and is not inherited.

> **Non-observed context.** That the collection pipeline authenticated as `postgres`,
> and that the `service_role` TRUNCATE residual was knowingly documented in the
> migrations, are established from repository and credential history — **not** from this
> inspection. What the inspection observed is that the Dashboard SQL Editor session ran
> as `postgres`, and that against that identity the §2.9 regime provided no constraint.

### 2.12 Behavioural objects

#### 2.12.1 Function census — 15 functions in `public`

| Property | Observed |
|---|---|
| Total | **15** |
| Owner | `postgres` (all) |
| `SECURITY DEFINER` | **5** — `is_admin`, `artist_metrics_published_guard`, `artist_metric_videos_published_guard`, `report_items_snapshot_guard`, `rls_auto_enable` |
| `search_path` pinned | **15 / 15** — 14 as `search_path=''`, `rls_auto_enable` as `search_path=pg_catalog` |
| `auth.uid()` call sites | **1** — `is_admin` |
| `auth.jwt()` call sites | **0** |
| Functions referencing `anon`/`authenticated`/`service_role`/`authenticator` | **0** |
| IMMUTABLE constraint-backing functions | **2** (§2.7.4) |
| **Function EXECUTE ACLs (`proacl`)** | **NOT ENUMERATED** — §9.2-D |

Fourteen of the fifteen correspond to migrations 0001–0006. The fifteenth,
`rls_auto_enable`, does not — §2.13.1.

`search_path` hardening was applied without exception across every
migration-declared function, closing the search-path hijack vector.

`is_admin` is `LANGUAGE sql` and **`STABLE`** — relevant because volatility governs
whether the planner may cache it inside a policy, which is what the vetoed Fase 9 surface
intended it for.

> **Repository-derived, not observed** (the live `proacl` was **not enumerated** — §9.2-D-2):
> `is_admin` is the only function carrying a GRANT in any migration —
> `revoke all on function public.is_admin() from public;` followed by
> `grant execute on function public.is_admin() to authenticated, service_role;` (0001).
> The other fourteen carry no GRANT or REVOKE in any migration, so their live EXECUTE ACL
> was **determined by no migration; its contents and origin are both unknown** (§9.3).
> Note that PostgreSQL's own default grants `EXECUTE` on a function to `PUBLIC` unless
> revoked, so "no migration touched it" points at the server default at least as strongly
> as at any platform action.

**Reconciliation against source control:** migrations 0001–0006 declare 14 functions
(2 + 1 + 2 + 2 + 7 + 0). The live census is 15. The fourteen that correspond are
`is_admin`, `audit_events_immutable`, `versioning_row_immutable`, `report_runs_row_guard`,
`report_runs_no_truncate`, `raw_youtube_immutable`, `raw_youtube_no_truncate`,
`artist_metrics_detail_complete`, `artist_metrics_published_guard`,
`artist_metric_videos_published_guard`, `reports_snapshot_guard`,
`report_snapshot_no_truncate`, `report_items_snapshot_guard` and
`report_item_reason_complete`. **`rls_auto_enable` is the fifteenth and corresponds to
nothing.** This list is recorded because it is what makes "the fifteenth does not
correspond" checkable once the source is gone.

**All 15 function bodies were read in full and verified free of embedded real YouTube
data literals.** The only string literals present are enum values, column names,
JSONB *key* names, schema names and human-readable error text. JSONB key names are
schema, not data.

> **Note on error-message text.** The migration-declared functions raise
> Portuguese-language exceptions. That text must be sourced from
> `supabase/migrations/`. It is deliberately not reproduced here: the inspection's CSV
> export path rendered UTF-8 as Latin-1, and transcribing from that path would embed
> mojibake into the durable record.

#### 2.12.2 Table trigger census — 21 triggers, all enabled

**Every table trigger reads `tgenabled = 'O'` (enabled). None is disabled.** The
raw-table immutability regime was confirmed intact and in force: each of the three raw
tables carries both a row guard (`BEFORE DELETE OR UPDATE … FOR EACH ROW`) and a
statement guard (`BEFORE TRUNCATE … FOR EACH STATEMENT`), all enabled.

**Reconciliation against source control:** migrations 0001–0006 declare 21 triggers
(2 + 4 + 2 + 6 + 7 + 0), matching the live census exactly. Recorded for the same reason as
§2.7 and §2.8: it cannot be recomputed once the source is gone.

Guards are also present and enabled on `report_runs`, `audit_events`, `reports`,
`report_items`, `artist_metrics`, `artist_metric_videos`, `rubric_versions` and
`outcome_weight_versions`. The eight tables carrying no triggers are exactly those the
migrations declare mutable or reconstructible. **Trigger coverage matches declared
design intent.**

**One asymmetry:** `artist_metrics` has a row-level guard but **no TRUNCATE guard**,
unlike every other protected table. It is not exploitable in the observed state.
PostgreSQL refuses to truncate a table targeted by foreign keys unless the referencing
tables are named in the same statement **or `CASCADE` is specified**; in both cases the
referencing tables' `BEFORE TRUNCATE` guards fire and raise, and both referencing
tables (`artist_metric_videos`, `report_items`) carry one. **The protection therefore
holds through the referential topology rather than by specification** (D-8).

**Reconstruction hazard:** `pg_get_triggerdef` renders function references
*unqualified*, resolved against the session `search_path`. The live binding is by OID
and is exact; the serialized text is not safely replayable. Any reconstruction must
schema-qualify every function reference (D-9).

### 2.13 Event-trigger topology — 7 event triggers, all enabled

| Event trigger | Owner | Event | Tags | Enabled | Function |
|---|---|---|---|---|---|
| **`ensure_rls`** | **`postgres`** | `ddl_command_end` | `CREATE TABLE`, `CREATE TABLE AS`, `SELECT INTO` | `O` | `rls_auto_enable()` |
| `issue_graphql_placeholder` | `supabase_admin` | `sql_drop` | `DROP EXTENSION` | `O` | `set_graphql_placeholder()` |
| `issue_pg_cron_access` | `supabase_admin` | `ddl_command_end` | `CREATE EXTENSION` | `O` | `grant_pg_cron_access()` |
| `issue_pg_graphql_access` | `supabase_admin` | `ddl_command_end` | `CREATE EXTENSION` | `O` | `grant_pg_graphql_access()` |
| `issue_pg_net_access` | `supabase_admin` | `ddl_command_end` | `CREATE EXTENSION` | `O` | `grant_pg_net_access()` |
| `pgrst_ddl_watch` | `supabase_admin` | `ddl_command_end` | **NULL — all DDL** | `O` | `pgrst_ddl_watch()` |
| `pgrst_drop_watch` | `supabase_admin` | `sql_drop` | **NULL — all drops** | `O` | `pgrst_drop_watch()` |

**Six are owned by `supabase_admin`. One — `ensure_rls` — is owned by `postgres`
(§2.13.1).**

#### 2.13.1 `rls_auto_enable()` / `ensure_rls` — LIVE-ONLY OBJECT

**Classification: LIVE-ONLY SECURITY BEHAVIOUR / SUCCESSOR EXPLICIT-DESIGN DECISION REQUIRED.**

| Property | Observed |
|---|---|
| Function | `public.rls_auto_enable()`, returns `event_trigger` |
| Language | `plpgsql` |
| Security | **`SECURITY DEFINER`** |
| `search_path` | `pg_catalog` — the only function in `public` not pinned to `''` |
| Owner (function and trigger) | **`postgres`** |
| Attached | **yes**, via event trigger `ensure_rls`, **enabled** (`O`) |
| Present in NOXUND source control | **NO** — absent from `supabase/migrations/` and from the entire repository |
| Present in the applied migration ledger | **NO** |
| Provenance | **UNRESOLVED — MIGRATION CHANNEL EXCLUDED** |

**Verbatim body**, preserved because a paraphrase cannot settle a `SECURITY DEFINER`
DDL hook's quoting and filter semantics, and because this text becomes unobtainable on
deletion. It is platform-shaped ASCII, so the mojibake caveat of §2.12.1 does not apply
to it.

> **Recorded verbatim for the durable record. This is not a deployment artifact** —
> see §7 and §8 OD-C.

```sql
CREATE OR REPLACE FUNCTION public.rls_auto_enable()
 RETURNS event_trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$
```

**Behaviour.** For qualifying `CREATE TABLE` commands in `public`, it enables row-level
security on the new table. Failures are caught by `EXCEPTION WHEN OTHERS` and only
written to the server log. **It can never block a `CREATE TABLE`, and a failure to
enable RLS would be visible only in logs.** The behaviour is best-effort, not
guaranteed.

**Quoting: favourable.** The `format('… %s …', cmd.object_identity)` call is safe. PostgreSQL emits `object_identity` already schema-qualified with each identifier
quoted as necessary, so `%s` introduces no injection vector. This rests only on the
preserved body plus documented behaviour.

**Invocation surface: CANNOT BE ESTABLISHED.** Who could execute a qualifying
`CREATE TABLE` in `public` depends on who held `CREATE` on that schema — which is
`nspacl`, **never inspected** (§9.2-D-1). Under the stock PostgreSQL 15+ default no role
but the owner and superusers holds `CREATE` there, which would leave this
`SECURITY DEFINER` hook a very small non-owner invocation surface; but Supabase's platform
bootstrap is widely reported to issue schema-level grants on `public` (**vendor behaviour,
not observed here**), and the migrations issue none either way. **That is an assumption,
not an observation, and OD-C must be decided knowing it.**

**Provenance, stated exactly.** This object is recorded as **neither NOXUND-authored
nor Supabase-provisioned**. Both determinations are unproven. The evidence bounds the
question as follows:

- The applied ledger contains exactly six entries, matching repository filenames.
  **It did not arrive through the migration channel.**
- The other six event triggers are all owned by `supabase_admin`; `ensure_rls` is owned
  by `postgres`. **A different creation channel is indicated.**
- The Product Lead does not recall any session running an auto-enable-RLS snippet in
  this project's SQL Editor, and cannot exclude it from memory alone.

Two candidate explanations are preserved, neither established:

1. out-of-band DDL executed as `postgres` (SQL Editor or a direct connection);
2. a Supabase provisioning or dashboard action executing as `postgres` rather than
   `supabase_admin`.

> **Bounded structural note, recorded neutrally.** In stock PostgreSQL,
> `CREATE EVENT TRIGGER` is superuser-only, and `ALTER EVENT TRIGGER … OWNER TO`
> requires the new owner to be a superuser — yet this trigger is owned by `postgres`,
> observed `rolsuper = false`. This implies either that superuser privilege was
> involved at creation time or that platform rules differ from stock.
>
> **Critically: superuser status is mutable and its effect is not retroactive.**
> `postgres` may have held superuser when the object was created and been demoted since;
> PostgreSQL does not re-validate object ownership on demotion. The present
> `rolsuper = false` observation therefore does **not** weaken the possibility that
> `postgres` created it.
>
> **This note does not discriminate between the two candidate explanations** and must
> not be read as favouring either.

**PostgreSQL records no author and no creation timestamp for event triggers.** This
question is not answerable by any further query, and re-inspecting the source would not
advance it.

**Consequence if the successor is rebuilt from migrations alone:** automatic RLS
enablement on newly created `public` tables is **silently lost**. Any table created
thereafter has RLS off unless its own migration says otherwise. No error is raised and
no artifact records the loss.

**Weight — stated with its limit, so OD-C is decided on neither more nor less than the
evidence supports.**

*For the 19 existing tables* the assessment is provable and the hook was not load-bearing.
The decisive reason is redundancy: **migrations 0001–0006 enable RLS on all 19 tables
themselves** (§2.9), so for this population the hook could not have been load-bearing
whatever the privilege posture was. Independently, RLS was void against the acting
identity by owner exemption plus `BYPASSRLS`, with zero policies, and neither `anon` nor
`authenticated` held any table-level ACL entry.

*For newly created tables* — **the only population this hook actually governs** — the
assessment **cannot be made**. It would require knowing the grant posture applied to a new
table, which is exactly `pg_default_acl`, never inspected (§9.2-D-1). If default privileges
auto-granted new tables to `anon`/`authenticated`, this hook would have been the only thing
standing between a new table and readability. **That question is closed to us**, and OD-C
must be decided knowing it is closed rather than on an assumption either way.

> **This brief does not recommend transplanting this object.** Its unresolved provenance
> is itself an argument for deliberate re-derivation rather than transplant. See §7 and
> §8, OD-C.

#### 2.13.2 DDL is never side-effect-free on this platform

`pgrst_ddl_watch` and `pgrst_drop_watch` carry `evttags = NULL`, meaning **no tag
filter: they fire on every DDL command and every drop.** Their bodies were not read;
PostgREST's documented behaviour is a schema-cache reload `NOTIFY`. Recorded because it
falsifies any assumption that DDL against this source is inert.

### 2.14 Migration ledger

`supabase_migrations.schema_migrations` contains **exactly six entries**, matching the
repository filenames one-for-one:

| Version | Name |
|---|---|
| `20260620000001` | `phase1_core_identity_access` |
| `20260620000002` | `phase2_versioning` |
| `20260620000003` | `phase3_runs_artists` |
| `20260620000004` | `phase4_raw_youtube_snapshots` |
| `20260620000005` | `phase5_computed_metrics_reports` |
| `20260620000006` | `entity_resolution_candidates` |

**No unexpected entries.** The `statements` column is populated for all six; it was
deliberately not read, being redundant with the repository.

**Migration `0008` — file exists in the repository, NOT APPLIED.**
**Migration `0009` — file exists in the repository, NOT APPLIED.**

Non-application is established **five independent ways**: no `sg8_*` composite types;
no `sg8_*` relations; zero RLS policies (all nine policies declared by 0009 target
`sg8_*` tables); the role `sg8_compute_writer` declared by 0009 is absent from
`pg_roles`; and the ledger holds no corresponding entry.

### 2.15 Population verdict — all 19 tables measured

| Verdict | Tables |
|---|---|
| **EMPTY** | `audit_events`, `artists`, `artist_aliases`, `video_artist_mappings`, `channel_eligibility`, `artist_metrics`, `artist_metric_videos`, `reports`, `report_items`, `entity_resolution_candidates`, `producers`, `applications`, `admin_users`, `rubric_versions`, `outcome_weight_versions` — **15 tables** |
| **NONEMPTY (boolean only)** | `raw_youtube_search_pages`, `raw_youtube_videos`, `raw_youtube_channels` — **3 tables** |
| **NONEMPTY — 1 row** | `report_runs` |
| **NOT ESTABLISHED** | none |

**Four of nineteen tables hold data.**

#### 2.15.1 First-party product data

> **NOXUND FIRST-PARTY PRODUCT TABLES HOLD NO USER, APPLICANT OR ADMIN RECORDS.**
>
> `producers = 0` · `applications = 0` · `admin_users = 0`.

This statement is deliberately scoped. **The inspection did not inspect the raw YouTube
payload contents**, which may contain third-party metadata relating to natural persons.
Any privacy or LGPD analysis of that payload is a separate matter and is **not**
addressed or foreclosed *by this brief* — but see §10.1, which records that the
retirement recorded at §9.1 does foreclose it.

#### 2.15.2 `audit_events`

**EMPTY.** This closes a standing unknown. `audit_events` is simultaneously the table
whose only pipeline writer would stamp an identifier into `after_json`, and the table
made immutable against `UPDATE`, `DELETE` and `TRUNCATE` by trigger — the hardest place
in the database from which to remove anything. It holds zero rows. No content probe was
required and none was designed.

#### 2.15.3 `report_runs` — the provenance anchor

One row, `status = 'collecting'`. The run was advanced one step from the column default
(`'created'`) and never further.

Its `created_at` is **`2026-07-15T19:59:01.742229Z`** (server clock, UTC, NOXUND-native,
containing no API-derived value). **This is an operational anchor for the collection
run. It is not the expiry timestamp of any individual stored API object** — individual
raw objects were written at slightly later times during the run.

**The only durable retention conclusion recorded here is:** the historical API dataset
is **beyond the applicable 30-day unrefreshed storage window**.

The following `report_runs` columns are **deliberately not recorded, restated or
characterised** in this brief: `youtube_quota_used`, `collected_video_count` and
`target_video_count` — all are scale or quota values adjacent to the held raw-table
cardinalities (§10). The observed row's values for `keyword` and `vertical` were
likewise not retrieved and are not asserted here; those two columns carry compile-time
NOXUND defaults declared in migration 0003.

#### 2.15.4 The compute chain never executed against real data

Established four independent ways: `report_runs.status = 'collecting'`; nine empty
pipeline tables; `rubric_versions = 0`, so no rubric was ever versioned; and
`artist_metrics` structurally provisioned with its full scoring column set but never
populated.

Prior evidence for this was repository-derived and carried an explicit caveat that
repository evidence cannot exclude ad-hoc DML against the live database. **That caveat
is now retired by direct observation.**

---

## 3. SUPABASE COUPLING GRAPH

The complete live dependency surface from NOXUND objects into Supabase-managed
features.

### 3.1 `auth.users` foreign-key edges — 4 edges, 3 tables

| Referencing table | Column | Referenced | Action |
|---|---|---|---|
| `public.admin_users` | `auth_user_id` | `auth.users(id)` | `ON DELETE CASCADE` |
| `public.admin_users` | `granted_by` | `auth.users(id)` | `ON DELETE SET NULL` |
| `public.applications` | `reviewed_by` | `auth.users(id)` | `ON DELETE SET NULL` |
| `public.producers` | `auth_user_id` | `auth.users(id)` | `ON DELETE SET NULL` |

**All three referencing tables are EMPTY.**

### 3.2 Complete coupling summary

| Coupling vector | Extent | Data involved |
|---|---|---|
| `auth.users` FK edges | **4**, across 3 tables | none — all empty |
| `auth.uid()` call sites | **1** — `public.is_admin()` | none |
| `auth.jwt()` call sites | **0** | — |
| `public` functions referencing `anon` / `authenticated` / `service_role` / `authenticator` | **0** | — |
| RLS policies referencing Supabase roles | **0** | — |
| `storage` dependencies | **0** | — |
| `realtime` dependencies | **0** | — |
| `vault` dependencies | **0** — `supabase_vault` installed but unreferenced | — |
| Cross-schema view/rule dependency edges | **0** | — |
| **Inbound edges into `public` from any Supabase schema** | **0** | — |

**The coupling is strictly one-directional and touches no data.** No Supabase-managed
schema holds any dependency on a NOXUND object, so retiring the platform severs
outbound references only.

**The YouTube collection pipeline has zero Supabase identity coupling.** All four FK
edges sit in the first-party identity and onboarding surface.

### 3.3 Minimum coupling set the successor must replace

1. **The identity target** — `auth.users(id)`, referenced by 4 foreign keys across 3
   empty tables.
2. **`auth.uid()`** — one call site, in one `SECURITY DEFINER` function that is
   **currently inert**: no policy or trigger invokes it and `admin_users` is empty, so
   it can only return false. *Inert is not unreachable* — function-level EXECUTE ACLs
   were not enumerated (§9.2-D), and migration 0001 does grant
   `EXECUTE ON FUNCTION public.is_admin() TO authenticated, service_role`.

**`ensure_rls` is deliberately not listed here.** It is not a dependency into a
Supabase-managed feature; it is a live-only object of *unresolved* provenance, and
listing it as coupling would imply the platform origin §2.13.1 forbids asserting. Its
reproduce-or-drop decision is carried at §7 and §8 OD-C.

### 3.4 What the coupling record does **not** capture

Recorded so §3 is not read as complete:

- **The `auth.uid()` contract itself** — what it returns, by what mechanism, and its
  behaviour for an unauthenticated session — was not captured. `SKIP-NONPUBLIC-DETAIL`
  meant the `auth` schema's internals were never read. A successor identity designer
  must obtain this from Supabase's public documentation; **it is not recoverable from
  this database.**
- **`auth.users` delete semantics.** `admin_users.auth_user_id` carries
  `ON DELETE CASCADE`; whether that cascade would ever fire depends on GoTrue's
  deletion behaviour, which was not inspected.
- **The referenced column's type is not at risk** — `auth.users(id)` is `uuid`,
  derivable from the referencing column declarations in migration 0001 plus
  PostgreSQL's requirement of a compatible unique index on the referenced side.

---

## 4. REPOSITORY-vs-LIVE DIVERGENCES

Each divergence is classified **MUST CARRY INTO SUCCESSOR DESIGN** or
**SUPABASE-SPECIFIC / RETIRE WITH PROJECT**.

| # | Divergence | Classification |
|---|---|---|
| D-1 | **The live source ran PostgreSQL 17.6.** Repository references to PostgreSQL 15 describe the intended successor or the local Docker spike; none was ever an observation of this server. | **MUST CARRY** |
| D-2 | **Default collation is ICU `en-US`, collation version `153.121`** — not libc. `datcollate`/`datctype` name a libc locale that does not govern ordering. | **MUST CARRY** |
| D-3 | **Every text column uses the database default collation**; no `COLLATE "C"` anywhere. Three `UNIQUE` indexes over `lower()` make uniqueness itself dependent on case-mapping rules for non-ASCII input. | **MUST CARRY** |
| D-4 | **`rls_auto_enable()` / `ensure_rls` exist live only**, with unresolved provenance. A migrations-only rebuild silently loses automatic RLS enablement. | **MUST CARRY** |
| D-5 | **All 19 tables owned by `postgres`**, which holds `BYPASSRLS` and is a member of every API role; **`FORCE RLS` set nowhere** → two independent bypass paths against the acting identity. | **MUST CARRY** |
| D-6 | **API-origin values are stored twice per row** in the raw tier — once verbatim in `jsonb`, once projected into typed columns. Any future handling of that data class must treat both. | **MUST CARRY** |
| D-7 | **Composite FK targets are backed by bare `CREATE UNIQUE INDEX`, not unique constraints.** Index creation must precede FK creation on rebuild; they are not manipulable via `ALTER TABLE … CONSTRAINT`. | **MUST CARRY** |
| D-8 | **`artist_metrics` lacks a TRUNCATE guard**, protected in the observed state only by the referential topology. | **MUST CARRY** |
| D-9 | **`pg_get_triggerdef` output renders function references unqualified** — captured trigger DDL is not safely replayable without schema qualification. | **MUST CARRY** |
| D-10 | **The SEC-F08 credential CHECK constraints test top-level JSONB keys only** (`?|`); guard depth is one. No breach is indicated — this records an assumption not to inherit. | **MUST CARRY** |
| D-11 | **The schema lives in the `postgres` administrative database**, and `public` is owned by `pg_database_owner` rather than a named role. | **MUST CARRY** (as anti-pattern) |
| D-12 | **Migrations 0008 and 0009 are unapplied repository files** whose target environment will cease to exist. | **MUST CARRY** (re-scope) |
| D-13 | **The Phase 9 producer-facing view was designed and never created**; **no GIN index exists on any `jsonb` column**, consistent with an archival-by-design raw tier. | **MUST CARRY** (design intent) |
| D-14 | **`MAINTAIN` (`m`) is a PostgreSQL 17+ privilege.** The observed ACL string is not replayable against a pre-17 successor. | **MUST CARRY** |
| D-15 | Supabase platform surface: 9 non-NOXUND schemas retired (§5), of which 6 are Supabase-managed (§2.3); 6 platform event triggers; PostgREST cache-invalidation hooks; `graphql` scaffolding; `supabase_vault`; `pg_cron`/`pg_net` grant plumbing. | **RETIRE WITH PROJECT** |
| D-16 | Supabase role topology: `anon`, `authenticated`, `service_role`, `authenticator`, `supabase_admin`, `supabase_auth_admin`, `supabase_storage_admin`, `supabase_realtime_admin`, `supabase_replication_admin`, `supabase_etl_admin`, `supabase_read_only_user`, `supabase_privileged_role`, `pgbouncer`, `dashboard_user` (§2.11). | **RETIRE WITH PROJECT** |
| D-17 | `supabase_migrations.schema_migrations` as the migration-tracking mechanism. | **RETIRE WITH PROJECT** (successor requires its own ledger) |
| D-18 | **The `service_role=Dxtm` table ACL is granted by no migration, and its shape is unexplained.** Migrations 0001–0006 contain zero `GRANT … ON TABLE`. Its **origin is not established** — the ACL grantor field records `postgres`, the same catalog signature as `ensure_rls` (§2.13.1); platform default privileges (`pg_default_acl`, never inspected — §9.2-D-1) are a candidate mechanism, **not a finding**. The *shape* is separately unaccounted for: had the platform granted `service_role` its usual full set the entry would read `arwdDxtm`, yet `a r w d` are absent, and the migrations' 19 `revoke all` statements name only `anon` and `authenticated`. **No captured statement explains why `service_role` holds `Dxtm` rather than `arwdDxtm`.** A migrations-only rebuild reproduces the 19 `revoke`s but not this grant; it is also structurally unreconstructible from any pre-17 migration text, since `MAINTAIN` did not exist before PostgreSQL 17 (D-14). | **MUST CARRY** (as a residual to drop, not to reproduce) |

---

## 5. SUPABASE-SPECIFIC OBJECTS TO RETIRE

These exist only because the source was a managed Supabase project. They carry no
NOXUND design intent and are **not** to be reproduced.

- **Schemas (9):** `auth`, `storage`, `realtime`, `vault`, `graphql`, `graphql_public`,
  `pgbouncer`, `extensions`, `supabase_migrations`.
- **Extension:** `supabase_vault 0.3.1` (unreferenced by any NOXUND object).
- **Event triggers (6):** `issue_graphql_placeholder`, `issue_pg_cron_access`,
  `issue_pg_graphql_access`, `issue_pg_net_access`, `pgrst_ddl_watch`,
  `pgrst_drop_watch`.
- **Roles:** the complete list at D-16.
- **The migration ledger mechanism** (`supabase_migrations.schema_migrations`).
- **The platform-held pre-pause logical backup and its restore window**, which
  terminate with the project.

`graphql` and `graphql_public` exist without the `pg_graphql` extension because the
`issue_graphql_placeholder` event trigger actively maintains a placeholder. They are
platform scaffolding with a cause, not unexplained residue.

**`ensure_rls` / `rls_auto_enable()` is not in this list.** Its provenance is
unresolved and it is handled as an open successor decision (§7, §8 OD-C).

---

## 6. SUCCESSOR DESIGN INPUTS

Observations a successor design should account for. **None is a ratified decision.**
Architecture, version and policy selection belong to `P10-R5` and the successor
schema-design unit.

### 6.1 Privilege and enforcement

1. Breaking only one of the two RLS bypass paths would leave the other in force:
   setting `FORCE RLS` alone would be insufficient against the observed arrangement,
   because `BYPASSRLS` is independent of ownership.
2. `public` owned by `pg_database_owner` resolves ownership dynamically. An explicit
   named owner role is the alternative.
3. Two patterns from the legacy platform are worth *considering* deliberately:
   `authenticator`'s `rolinherit = false` (a role whose purpose is identity switching
   does not passively inherit), and the **absence** of `SELECT` from `service_role`'s
   grants — RLS bypass cannot manufacture a privilege that was never granted, so an
   ungranted privilege is a stronger control than any policy. The principle is what
   carries forward, not an attributed act: **`service_role` holds no table-level
   `SELECT`, however that arose (D-18)** — no migration granted or revoked any *table*
   privilege for that role. Its only migration-declared grant is `EXECUTE` on
   `is_admin()` (§2.12.1, §3.3). **The rest of its posture is not a pattern to
   preserve:** the retained `TRIGGER`, `REFERENCES`, `MAINTAIN` and `TRUNCATE` bits
   (§2.10) are residuals a successor need not carry.
4. Default-deny — RLS enabled with zero policies — was a coherent posture while the
   producer-facing surface was vetoed. **Its completeness is not verified**, because
   `pg_default_acl` and the `public` schema ACL were not captured (§9.2-D), so what
   would have happened to a *newly created* table's grants is unknown.

### 6.2 Structural and rebuild-order

5. `artist_metrics`'s TRUNCATE protection rests on referential coincidence rather than
   specification (D-8); an explicit guard is the alternative.
6. **Rebuild order has at least four constraints**, two of which are easy to miss:
   enum types must precede the tables using them; **the two CHECK-backing functions
   must precede the tables whose constraints call them** (both are declared earlier in
   0005 than their tables); **unique indexes must precede the foreign keys targeting
   them** (D-7); and trigger definitions must schema-qualify their function references
   (D-9).
7. **Relocating the schema out of `public` is not a rename.** Migrations 0001–0006
   hard-code `public.` on **exactly 226 references** (0001:40, 0002:18, 0003:26,
   0004:33, 0005:93, 0006:16), and 14 of 15 functions are pinned `search_path = ''`,
   which *requires* full qualification. Departing from the D-11 arrangement therefore
   forces a rewrite of every qualified reference inside every function body, CHECK
   constraint and trigger definition. Named here so the cost is visible before it is
   incurred.
8. **The immutability triggers collide with an owner/runtime split.** Triggers fire
   regardless of privilege, so the raw-tier row and statement guards block `UPDATE`,
   `DELETE` and `TRUNCATE` for **everyone, including the table owner**. Any future
   migration that must touch the raw tier requires `ALTER TABLE … DISABLE TRIGGER`,
   which requires **table ownership**. A successor that separates the runtime identity
   from the owner must therefore place that capability somewhere deliberately, or the
   archival tier becomes unmigratable. *(Successor migrations only; no change to the
   legacy source is proposed or authorized — §9.1, §11.)*
9. **Reproducing `ensure_rls` has a hard feasibility constraint**, should OD-C resolve
   that way: an event trigger must be **created by** a superuser and can only be
   **assigned to** one. The constraint binds at creation and at `ALTER … OWNER TO`, **not
   perpetually** — ownership survives a later demotion of that role, which is **one way**
   the live object could come to be owned by a non-superuser. §2.13.1 preserves both
   candidate explanations for that ownership and this note favours neither. That sits
   awkwardly with a least-privilege successor and must be costed as part of OD-C, not
   discovered afterwards.
10. The partial and expression indexes encode genuine business invariants at the
   database layer — one open application per producer; one pending resolution candidate
   per video per run; nullable-first-page uniqueness via `COALESCE(page_token, '')`.
   **This is durable design knowledge worth carrying forward**, unlike the ownership and
   enforcement arrangements.
11. `artist_metrics_detail_complete` enforces at the database layer that every stored
   metric carries complete, replayable evidence, including non-empty effective versions
   and overrides that preserve their natural key. The invariant is worth preserving; the
   function-backed CHECK mechanism carries known fragility (a function can be redefined
   without constraint revalidation, and dump/restore ordering can break it) and should
   be re-examined rather than copied.
12. The raw tier was designed as a write-once verbatim archive: no GIN indexes on
    `jsonb`, immutability enforced by trigger. A successor should not reflexively add
    query indexes to a tier whose design intent is archival.
13. `COLLATE "C"` for opaque identifier columns is worth evaluating, since linguistic
    collation is semantically inappropriate and slower for them; the legacy schema
    applied the database default only because nothing else was specified. **Input to
    OD-B, not a selection.**

### 6.3 Version and locale

14. **The source ran PostgreSQL 17.6 with ICU `en-US` (collator `153.121`).**
    PostgreSQL does not guarantee that `pg_dump` output can be loaded into an older
    major server, so a 17-origin logical dump cannot be treated as a supported or
    guaranteed migration path into PostgreSQL 15.

    **However, no historical YouTube dataset migration is currently intended.** The
    source version is therefore recorded as a **successor-design input, not a
    requirement that the successor use PostgreSQL 17.** Version selection remains open
    — §8, OD-A.

15. Successor collation policy is likewise **open** (§8, OD-B). The observed source
    semantics are recorded in §2.2 so the decision can be made with knowledge of what
    the legacy system actually did; they are not ratified as the target, and §2.2's
    precision limit applies.

---

## 7. FACTS THAT MUST BE RE-DERIVED RATHER THAN TRANSPLANTED

| Item | Why re-derivation is required |
|---|---|
| **`rls_auto_enable()` / `ensure_rls`** | Recorded as **neither NOXUND-authored nor Supabase-provisioned**; both determinations are unproven and two candidate explanations remain open (§2.13.1). Its `EXCEPTION WHEN OTHERS` handler makes the behaviour best-effort and silent on failure. Transplanting an object of unknown authorship would import an unaudited `SECURITY DEFINER` DDL hook into a least-privilege successor — and reproducing it at all carries the superuser feasibility constraint at §6.2 item 9. |
| **Table ownership and privilege topology** | The legacy arrangement concentrates ownership, `BYPASSRLS` and every API-role membership in a single role that the runtime authenticates as. It is the specific thing the successor exists to replace. |
| **Collation configuration** | ICU `en-US` at collator `153.121` is what the source *did*, not necessarily what the successor *should* do. Reproduction and deliberate change are both legitimate outcomes of OD-B. |
| **Function-backed CHECK constraints** | The invariant is valuable; the mechanism is fragile. Re-examine before reuse. |
| **Serialized trigger DDL** | Not safely replayable as captured (D-9). |
| **Migration ledger mechanism** | Supabase-specific; the successor requires its own. |

---

## 8. OPEN FUTURE DESIGN DECISIONS

| ID | Open decision | Owner unit | Status |
|---|---|---|---|
| **OD-A** | Successor PostgreSQL major version | `P10-R5` / successor schema design | **OPEN — deliberately deferred.** Not a retirement prerequisite. Required inputs (source version, extension set) are captured. |
| **OD-B** | Successor locale provider and collation policy | `P10-R5` / successor schema design | **OPEN — deliberately deferred.** Not a retirement prerequisite. Source identity captured (§2.2, with its precision limit); the three `lower()`-indexed tables are empty, so no data-dependent evidence is destroyed. |
| **OD-C** | Reproduce or drop the `ensure_rls` automatic-RLS behaviour | successor security design | **OPEN — deliberately deferred.** Not a retirement prerequisite. **Deferred on incomplete evidence:** the object itself is fully captured including its verbatim body (§2.13.1), but the *privilege* half of "what happens to a newly created `public` table" is not, because `pg_default_acl` was never inspected (§9.2-D-1) — which is also why its weight for new tables cannot be assessed (§2.13.1). If resolved as *reproduce*, the superuser feasibility constraint at §6.2 item 9 applies. |
| **OD-D** | Disposition of `supabase/migrations/0008` and `0009` (unapplied; target environment ceasing to exist) | successor schema design | **OPEN** |
| **OD-E** | Producer-facing projection layer (the Phase 9 view designed but never created) | product / successor design | **OPEN** |

**`OD-3` is not reopened by this brief.**

---

## 9. RETIREMENT CONSEQUENCES

### 9.1 Product-Lead adjudication of record

**Permanent deletion of Supabase project `pwbkplzyzmortwjjpcbg` is the selected action
for terminating continued storage of the legacy YouTube API dataset.** No targeted row
purge will precede it.

The reasoning of record: the project is not to be preserved, and a targeted purge would
add DDL and DML — and their operational risk — to a database that will immediately be
retired.

**Wording is exact and deliberate:**

> **TERMINATES CONTINUED STORAGE / REMEDIATION ACTION SELECTED.**

**This brief does not claim that deletion retroactively cures the historical
over-retention.** It records the action selected and its forward effect.

**Deletion is not authorized by this document.** See §9.4.

### 9.2 What is lost, by class

**A — Intentionally lost, no longer needed**
All Supabase-managed schemas and their contents; the complete platform role topology;
`supabase_vault`; the six platform event triggers; PostgREST cache-invalidation hooks;
`graphql` scaffolding; `pg_cron`/`pg_net` grant plumbing; the
`supabase_migrations` ledger mechanism; the platform-held pre-pause logical backup and
its restore window.

**B — Archival / historical loss**
The 2026-07-15 raw YouTube snapshot in all three raw tables. **Binding distinction:
RE-COLLECTABLE = YES; the exact historical snapshot REGENERABLE = NO.**

Also the `report_runs` anchor row. Its disposition is settled:

> **`report_runs` PHYSICAL ROW = INTENTIONALLY RETIRED WITH LEGACY PROJECT.**

Its policy-safe provenance value is carried by this durable record instead (§2.15.3),
within the limits of §10.

**C — Structural knowledge already captured**
Everything in §2 through §7.

**D — Still uncaptured (item 3 excepted, which is recoverable from vendor documentation)**

1. **`pg_default_acl` (default privileges) and the `public` schema ACL (`nspacl`).**
   Migrations 0001–0006 contain no `alter default privileges` and no schema-level
   `grant`/`revoke`, so whatever state existed — if any — was declared by no NOXUND source
   control and was live-only. Its contents, and its origin, are both unknown (§9.3).
   **Note this is a `public`-schema fact and is therefore *not* covered by the
   `SKIP-NONPUBLIC-DETAIL` scope decision.** Its absence is what limits §6.1 item 4 and
   OD-C (§8).
2. **Function EXECUTE ACLs (`pg_proc.proacl`) for the 15 `public` functions**, and
   **column-level ACLs (`pg_attribute.attacl`)**. Migration 0001 grants EXECUTE on
   `is_admin()` to `authenticated` and `service_role`; the other fourteen functions
   carry no GRANT or REVOKE in any migration, so their live EXECUTE ACL was **determined
   by no migration; its contents and origin are both unknown** (§9.3) — and PostgreSQL's
   own default (`EXECUTE` to `PUBLIC` unless revoked) is at least as likely an
   explanation as any platform action. Five of the fifteen are `SECURITY DEFINER`.
   *Consequence is bounded: four of those five return `trigger` or `event_trigger` and
   cannot be invoked from SQL at all; `is_admin` is the one directly callable one and
   migration 0001 revokes it from `PUBLIC` before granting it.*
3. **The `auth.uid()` behavioural contract and `auth.users` delete semantics** (§3.4).
   Obtainable from Supabase's public documentation, not from this database.
4. **Non-`public` schema internals** — column, constraint, index and ACL detail for
   `auth`, `storage`, `realtime`, `vault`, `extensions`, `supabase_migrations`.
   **Deliberately skipped by Product-Lead decision** (`SKIP-NONPUBLIC-DETAIL`); relation-level
   ownership *was* observed and is recorded at §2.9. A recorded scope boundary, not an
   oversight.
5. **`ensure_rls` provenance** — not answerable by any query (§2.13.1).
6. **Internal referential-integrity trigger enablement**, excluded by the
   `NOT tgisinternal` filter. Note that `convalidated = true` does **not** discharge this
   — `ALTER TABLE … DISABLE TRIGGER ALL` would set `tgenabled = 'D'` on internal RI
   triggers without altering `convalidated`. The consequence is nil, but that conclusion
   rests **solely on the referencing tables being empty**, not on constraint validity.
   *(Stated as a limit on inference, not as a proposed action.)*

### 9.3 Will the source be needed again for any known structural fact?

> ## NO — for the successor design, on the reasoning below.

This is a reasoned judgement, not a claim of total capture. §9.2-D lists six things that
were **not** captured; five of them will be permanently unrecoverable. None is needed:

- **Items 1 and 2** are platform privilege state. **Their contents are unknown** — this
  brief does not characterise what an uninspected catalog contained, and `pg_default_acl`
  could equally have held defaults for other roles, for FUNCTIONS/TYPES/SEQUENCES rather
  than TABLES, or nothing at all. The dismissal does not rest on any assumption about
  their contents; it rests on structure: **the successor inherits no Supabase role
  topology and designs its privilege model from first principles**, precisely because the
  legacy one is the thing being replaced. Whatever those catalogs held would inform an
  archaeology of the platform, not a build. Their absence is nonetheless recorded against
  every site that depends on them (§0.1, §6.1 item 4, §2.13.1 — both its invocation-surface
  and weight assessments, D-18 and OD-C), so that none of them is decided on an assumption
  of completeness.
- **Item 3** is recoverable from Supabase's public documentation.
- **Item 4** was a deliberate Product-Lead scope decision about schemas being abandoned.
- **Item 5** is unanswerable by any query, so re-inspection could not help.
- **Item 6** has nil consequence under the observed empty-table state.

**No return visit would yield anything the successor design requires.** Independently,
the standing instruction is that the source is not to be queried again unless the
Product Lead reopens that authority.

### 9.4 Prerequisites before permanent deletion

Recorded, not discharged. **This document authorizes none of them.**

1. This brief landed on `main` by manual Product-Lead merge.
2. `PERMANENT-SUPABASE-RETIREMENT-PREFLIGHT` completed.
3. A separate, explicit Product-Lead GO for deletion.
4. Deletion performed manually by the Product Lead via the Supabase Dashboard — never
   by an agent, never via the Management API.
5. `POST-DELETE VERIFICATION`.
6. `SUPABASE-CREDENTIAL-AND-REFERENCE-HYGIENE` (§9.5).

### 9.5 Credential sequencing

**Before deletion:** do **not** rotate, reset or remove any Supabase credential.
Password reset remains forbidden.

**After permanent deletion is independently verified:** a separate
`SUPABASE-CREDENTIAL-AND-REFERENCE-HYGIENE` unit is required. It must census all
remaining consumers before removing `SUPABASE_DB_PASSWORD`, `SUPABASE_ACCESS_TOKEN` and
Supabase-specific variables and configuration references.

*(Credential storage locations recorded during the access-path preflight — GitHub
Environments `production-db` and `youtube-collection` — are **not** verified by this
unit and must be re-censused by the hygiene unit rather than taken from here.)*

**No secret mutation is authorized by this document.**

---

## 10. CONTENT FIREWALL — WHAT THIS DOCUMENT DELIBERATELY DOES NOT CONTAIN

This brief contains **zero** of the following, by construction:

- raw YouTube API row bodies, in whole or in part;
- real video identifiers, channel identifiers, titles or descriptions;
- real view, like, comment, subscriber, upload or view-count statistics;
- page tokens;
- **raw-table cardinalities**, which remain under compliance classification HOLD — the
  three raw tables are recorded by **boolean NONEMPTY verdict only**;
- **any `report_runs` count or quota column value**, including `youtube_quota_used`,
  `collected_video_count` and `target_video_count`, which are scale values adjacent to
  the held raw-table cardinalities;
- any hash, digest or content fingerprint computed over API data;
- any substitute or partial reconstruction of the historical dataset.

**Held values were not newly reproduced here merely because older historical documents
may already contain them.**

The three raw tables are represented by their table names, their column *names* and
types (available in migration 0004), their trigger and constraint structure, and a
boolean population verdict. **Nothing in this document, alone or combined with the
repository, reconstitutes any part of the historical YouTube dataset.**

### 10.1 Privacy scope statement

This document states that **NOXUND first-party product tables hold no user, applicant
or admin records** (`producers`, `applications`, `admin_users` all empty).

It **does not** state, and must not be read to state, that no personal data exists in
the database. **The raw API payload was deliberately not inspected** and may contain
third-party metadata relating to natural persons. Privacy and LGPD analysis of that
payload is a separate matter, outside this brief's scope and unaffected by it.

**One consequence must be stated plainly rather than left to inference.** The retirement
recorded at §9.1 destroys the raw tier, and no dump, export or off-platform copy
exists (§0). **After deletion, payload-based privacy analysis becomes impossible** — the
separateness of that question is jurisdictional, not evidential: it belongs to another
unit's authority, not to another body of evidence. This is not an argument
for preserving the payload: preservation is not proposed here and would not be
permissible, because the dataset is already beyond the applicable 30-day unrefreshed
storage window (§2.15.3). It is recorded so that no future reader mistakes "separate
matter" for "still answerable."

---

## 11. STANDING

This document is a **structural record and design input**. It is not a decision record.

- It does not modify, supersede or reinterpret **DEC-0028** or **DEC-0033**.
- It ratifies no successor architecture and reopens no closed decision, including
  **OD-3**.
- It authorizes no Supabase access, no database query, no deletion, no secret mutation
  and no repository change beyond its own landing.
- The source database is **not to be queried again** unless the Product Lead separately
  reopens that authority.

Any decision arising from the observations recorded here requires its own unit and its
own Product-Lead authorization.
