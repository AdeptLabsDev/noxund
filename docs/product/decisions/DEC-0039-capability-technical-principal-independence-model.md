# DEC-0039 — Capability, technical principal and independence model

**Status:** ACTIVE (binding) · **Date:** 2026-08-21 · **Decision authority:** Product Lead
**Authority class:** INTERNAL-NORMATIVE · **Lifecycle:** ACTIVE / CURRENT · **Mutability:** FROZEN — the `docs/product/decisions/**` family default ([[DEC-0035]] §9), declared here under the fail-closed rule ([[DEC-0035]] §7).
**Drafted by:** a task-scoped Author, reviewed by a **distinct** task-scoped independent reviewer, under the Product-Orchestrator-coordinated topology that [[DEC-0037]] D5/D6 fixes, carried into this unit by the Product Lead's `C3` GO. **Ratification gate:** the Product Lead's manual merge of this record.
**Scope:** What technical capabilities and principals NOXUND actually has, which capabilities each governed actor may exercise, and which independence guarantees are process-only rather than technically enforceable. It fixes the separation of **role / execution instance / technical principal**, the four capability states, the treatment of generic CLI subagents, the current GitHub independence state, the principal-separation decision, and what approver provenance can and cannot currently prove. **Docs-only unit.**
**Negative scope — this record does not create or change:** any GitHub principal, App, bot, service account, token, credential or secret · any ruleset, branch protection, `CODEOWNERS` file, reviewer requirement, Environment, variable or repository setting · any workflow, workflow registration, CI check, validator, lint or hook · any agent registration, activation, contract, boundary, runtime handler, runtime allow-list or runtime wiring · `packages/orchestrator/**` in any respect, **including its disposition** · any preserved ref, branch, stash or archive · any database, SQL, migration, role or runner · any cloud resource · any collection arming state · any code file · any product scope, MVP admission, `OD-*` item or Axis-1 technical question · the `AgentResult` schema · any **mechanical** enforcement of anything stated here · memory content. **No principal is created, no agent is wired, no agent is registered, and no execution of any kind is authorized.**
**Extends:** [[DEC-0037]] §9 — supplying the **capability and principal limb** of the `C3` work that clause reserved, including *"the satisfiability of every identity-naming clause other than #12"* (§6 here); and [[DEC-0037]] D12, whose two `REPORTED` GitHub-configuration claims are **re-derived and promoted to `VERIFIED`** in §3. Through [[DEC-0037]] it reaches [[DEC-0035]] §12's reserved *capability matrix*, of which this record supplies the descriptive and normative limb only — **not** `AgentResult` V2, **not** a risk engine, and **not** any mechanical enforcement, which stay `C4` and `C5` under their own authorization.
**Narrows:** **nothing.** No clause of any file is narrowed, extended or reinterpreted by this record. §6 **reads** two clauses of `docs/agents/agent-review-matrix.md` at clause granularity ([[DEC-0035]] §11 step 1) and states a general satisfiability rule; that is a reading, not a narrowing, on the precedent [[DEC-0035]] §9's reading note set and [[DEC-0036]] §4 named — *a classification judgment, not a supersession*. **The single narrowing in this corpus remains [[DEC-0037]]'s, of item #12, and it is not extended by analogy to any other clause.**
**Does not edit:** any prior DEC. [[DEC-0001]] … [[DEC-0037]] all remain **frozen and additive-only**; [[DEC-0028]] and [[DEC-0033]] remain **byte-frozen** per [[DEC-0034]] §4. No prior record is declared obsolete, superseded, reopened or reinterpreted. **`DEC-0037` is the highest landed decision record on `main`** (§3, E21); **`DEC-0039` is a Product-Lead-reserved identifier for this unit, and the gap at `0038` is intentional and asserts nothing about any other unit or its work.** **No agent contract, boundary, registry entry or review matrix is edited — this unit touches no file under `docs/agents/**`.**
**Evidence base:** every configuration and repository claim below was re-derived in this unit at the canonical base and is marked `VERIFIED` in §3, with the command or file that produced it. Claims that could only be established by performing a forbidden action are marked `UNKNOWN — NOT PROBED` and are **not** resolved by assumption in either direction. Corpus surfaces read and not edited: `docs/agents/README.md`, `agent-registry.md`, `agent-boundaries.md`, `agent-review-matrix.md`, `product-orchestrator-agent.md`, `global-agent-rules.md`, `agent-conflict-resolution.md`, `orchestration-runtime.md`, `agent-onboarding-orchestration.md` §4 and §9; [[DEC-0035]] §3.1, §3.2, §4 P3/P4, §6, §7, §9, §10, §11, §12; [[DEC-0036]] §4; [[DEC-0037]] D1–D13, §6, §9, §10; `current-state.md` §D, §E; `context-map.md` §1–§3; `PHASE-B-CLOSEOUT-R1` §5.
**Canonical base:** `main` @ `45667387f74f92cf9aca532f786f9c8bd519d788`

---

## 1. Status

**ACTIVE — binding and prospective**, effective on the Product Lead's manual merge (§13). It is a capability and principal model. It creates no principal, grants no capability, removes none, registers no agent, and authorizes no unit.

---

## 2. The problem

[[DEC-0037]] fixed **who may act**. It did not fix **what any of them can technically do**, and it said so: D12 recorded the single-principal limitation from configuration it *"did not re-derive"*, and §9 routed the capability question to `C3`.

The gap that leaves is specific. The corpus describes agents by **contract** — what an identity owns, may decide, must escalate — and a fresh operator reads those contracts as though they described capability. They do not. A contract is a statement of authority; the machine grants capability, and the two have never been compared in one place. The result is that four different questions collapse into one word, *"can"*:

1. Does the documentation say this actor may do it?
2. Can the execution environment actually do it?
3. Does the current unit's authorization permit it?
4. Does GitHub, CI or the runtime technically prevent it?

Conflating them produces two errors in opposite directions. The first is **overclaiming safety**: describing a process rule as though it were a sandbox, or independent review as though GitHub enforced it. The second is **overclaiming danger**: reading a documented prohibition as a technical control that has failed, when nothing technical was ever in place. [[DEC-0037]] D7.7 already forbids the first for one case — *"the same GitHub credential does NOT constitute technical principal independence and must never be represented as such"*. This record generalizes that discipline into a model and, in §3, replaces the inherited assumption with measurement.

**One thing is not a problem and must not be treated as one.** That the Product Lead is a single principal is not a defect to be engineered away. It is the accurate shape of a one-person project, and [[DEC-0037]] D11 makes the Product Lead the final acceptor by design. The defect would be *describing* that arrangement as something it is not.

---

## 3. What was measured

Re-derived in this unit at the canonical base. Configuration values are a **dated observation**, not a rule: per the construction [[DEC-0037]] D12 used of itself, **the normative content of this record does not depend on any particular setting** — §4 forbids overstating separation rather than relying on a value. Volatile state is owned by `current-state.md`, which carries the freshness contract; this snapshot exists so §4's conclusions are anchored rather than asserted.

**No secret, token, key or credential value was read, and none is recorded here.** Only presence, absence and name.

### 3.1 GitHub — `VERIFIED`

| # | Fact | Source |
|---|---|---|
| E1 | Repository `AdeptLabsDev/noxund` is **public**, owner type **User** (not an organization), not archived; the authenticated principal holds `permissions.admin = true`. | `gh api repos/AdeptLabsDev/noxund` |
| E2 | The authenticated GitHub principal is **`AdeptLabsDev`**, user id `282037855`, `site_admin: false`. Token scopes: `gist`, `read:org`, `repo`, `workflow`. | `gh auth status`; `gh api user` |
| E3 | **Collaborators = exactly one**: `AdeptLabsDev`, role `admin`. There is no second GitHub identity with any access. | `gh api repos/.../collaborators` |
| E4 | Classic branch protection on `main` returns **`404 Branch not protected`**. Protection is implemented **by ruleset**, not by classic branch protection. | `gh api repos/.../branches/main/protection` |
| E5 | Three rulesets, all `enforcement: active`: **`19697151` Protect main**, **`20727975` Preserve recovery checkpoints**, **`20890207` Preserve authority evidence**. | `gh api repos/.../rulesets` |
| E6 | Ruleset **`19697151`** targets `refs/heads/main` and carries three rules: **`deletion`**, **`non_fast_forward`**, and **`pull_request`** with `required_approving_review_count: 0`, `required_reviewers: []`, `require_code_owner_review: false`, `require_last_push_approval: false`, `required_review_thread_resolution: true`, `require_extra_approval_for_unattributed_changes: true`, `allowed_merge_methods: ["merge"]`. Its **sole** bypass actor is User `282037855` with `bypass_mode: pull_request`, and GitHub's own computed field reads **`current_user_can_bypass: "pull_requests_only"`**. | `gh api repos/.../rulesets/19697151` |
| E7 | Rulesets **`20727975`** and **`20890207`** carry `deletion` + `non_fast_forward` + **`update`** over the eight named preserved refs, have **empty `bypass_actors`**, and read **`current_user_can_bypass: "never"`**. | `gh api repos/.../rulesets/<id>` |
| E8 | **No `CODEOWNERS` file exists** — not at `CODEOWNERS`, `.github/CODEOWNERS` or `docs/CODEOWNERS`, and no file of that name anywhere in the tree. | `git cat-file -e`; `git ls-tree -r --name-only HEAD` |
| E9 | Repository Actions **secrets = 0**, **variables = 0**, Dependabot secrets = 0. Environment `production-db` holds **0** secrets; `youtube-collection` holds **exactly one**, named `YOUTUBE_API_KEY`. | `gh api repos/.../actions/secrets`, `/actions/variables`, `/dependabot/secrets`, `/environments/<n>/secrets` |
| E10 | Both Environments carry a `branch_policy` rule and a `required_reviewers` rule. **The branch policy resolves to exactly one branch: `main`** — `custom_branch_policies: true`, `protected_branches: false`, and `deployment-branch-policies` returns `total_count: 1`, `[{name: "main", type: "branch"}]` for **both** Environments. The `required_reviewers` rule names **one** reviewer, `AdeptLabsDev` (User), and carries **`prevent_self_review: false`**. | `gh api repos/.../environments`; `gh api repos/.../environments/<n>/deployment-branch-policies` |
| E11 | Actions are `enabled`, `allowed_actions: all`, **`sha_pinning_required: true`**. | `gh api repos/.../actions/permissions` |
| E12 | The CI principal is restricted at repository level: **`default_workflow_permissions: "read"`** and **`can_approve_pull_request_reviews: false`**. | `gh api repos/.../actions/permissions/workflow` |
| E13 | **All eleven workflow files on `main` declare top-level `permissions: contents: read`.** Six DB-apply workflows are registry state `disabled_manually`; both collection workflows are `active`, `workflow_dispatch`-only, and bind an Environment. **The two numbers differ and the difference is stated, as E17 does:** the registry returns **12** rows against **11** files on `main`. The extra row is the known orphan registration `322938835`, registry-`active`, **whose file does not exist on `main`** — a registration is not a file, and with no file on `main` it is not dispatchable from `main`. **No conclusion here rests on the count**; the claim that matters is that no workflow on `main` grants the CI principal more than `contents: read`. | `git ls-tree -r HEAD -- .github/workflows/`; `.github/workflows/*.yml`; `gh workflow list --all` |
| E14 | **PRs #86, #87 and #88** — the three most recent governed landings, including `DEC-0037`'s own — each have `user: AdeptLabsDev`, `merged_by: AdeptLabsDev`, **`reviews: []`**, `requested_reviewers: []`, and zero comments. | `gh api repos/.../pulls/<n>` and `/reviews` |
| E15 | Merge commits are created server-side: `4566738` has `committer_login: "web-flow"` and `verification.verified: true` / `reason: "valid"`. Branch commits are `verified: false` / `reason: "unsigned"`; local signing config (`commit.gpgsign`, `gpg.format`, `user.signingkey`) is **unset**. | `gh api repos/.../commits/<sha>`; `git config --get` |

### 3.2 Repository and execution environment — `VERIFIED`

| # | Fact | Source |
|---|---|---|
| E16 | `.github/collection/` **does not exist** on `main`; both arming markers are absent, which *is* the disarmed state. | `git ls-tree -r HEAD -- .github/collection/` |
| E17 | `@noxund/orchestrator` is referenced by **22 files outside its own package, all under `docs/**` and all in prose**, by **zero** executable files outside the package, and by **zero** workflows. **Stated more precisely than the inherited phrasing:** [[DEC-0037]]'s evidence base records it as appearing *"in no file outside its own package"*; read as the **executable-reachability** claim it was made for, that holds exactly; read literally it would be falsified by documentation prose. The substance is unchanged — nothing executable reaches it. **This is a capability fact only; the disposition of `packages/orchestrator` is `C2`'s and is not touched here.** | `git grep -l "@noxund/orchestrator"` with path exclusions |
| E18 | **This unit's own execution instance is a generic CLI subagent, and it resolves `gh auth status` to the same principal `AdeptLabsDev` (E2).** It holds shell execution, filesystem read across the repository, filesystem write inside its worktree, and outbound network reach — every `gh api` call in this table was issued from inside that instance. | the commands in this unit |
| E19 | Local tooling: `aws`, `docker`, `node`, `pnpm`, `python`, `git`, `gh` on `PATH`; **`psql` absent**. `~/.aws/config` **present**; `~/.aws/credentials` **absent**; `~/.aws/sso/cache` directory **present**. **Zero** `AWS_*` and zero database-connection environment variable **names** are set. The Docker daemon is **not reachable**. | `command -v`; file existence; `env` name-only match |
| E20 | Git credential helper is `manager`; the local git identity is `Adeptlabs <adeptlabs.inc@gmail.com>` — the same account as E2. | `git config --get` |
| E21 | **`DEC-0037` is the highest landed decision record on `main`**, and **no `DEC-0039` file exists on any local or remote ref** other than this record — the collision-freedom this record's own identifier depends on, and a claim that **cannot decay**: a later `DEC-0039` elsewhere would be another unit's defect, not staleness here. **The claim is scoped deliberately.** An earlier revision of this row asserted the same of `DEC-0038` across all refs; that assertion was **true when made and is no longer true**, because unmerged branch refs move independently of `main`. **Nothing in this record rests on, characterizes or takes authority from any unlanded ref** — an unlanded artifact binds nothing ([[DEC-0035]] §3.2, §6), and landed authority is what this row is about. | `git ls-tree -r HEAD -- docs/product/decisions/`; `git ls-tree` over `git for-each-ref refs/heads refs/remotes` |

### 3.3 `UNKNOWN` — recorded as an outcome, not a gap to fill by assumption

| # | Question | Why it is UNKNOWN |
|---|---|---|
| U1 | **Whether any GitHub App, bot or machine installation has access to this repository.** | `gh api user/installations` returns `403` (the token is not App-authorized); `gh api repos/.../installation` returns `401` (requires a JWT). The enumeration is unavailable to this credential. **This is not evidence that no App exists**, and must never be reported as such. |
| U2 | **Whether any AWS principal is currently usable, and what it can reach.** | `~/.aws/config` and an SSO cache directory exist (E19), but establishing session validity or reach requires an AWS API call, which this unit is forbidden to make. `NOT PROBED — would require a forbidden action.` |
| U3 | **The operational effect of `require_extra_approval_for_unattributed_changes: true`.** | The field is `VERIFIED` as set (E6). Its behaviour for this repository could only be established by attempting a merge. `NOT PROBED.` |
| U4 | **Whether a direct push to `main` would in fact be rejected.** | Established from configuration plus GitHub's own `current_user_can_bypass` computation (E6), **not** from an attempted push — which would be a forbidden mutation. See §4 D10 for exactly what is and is not claimed. |
| U5 | **Whether a merge performed through the REST API by the same token would also produce a `web-flow`-signed commit.** | Would require performing a merge. `NOT PROBED.` Bears directly on §4 D6's provenance finding, which is stated conservatively because of it. |
| U6 | **Whether the CLI-subagent substrate would deny a write outside a unit's declared write scope.** | A permission layer is present in the harness, and **no capability was denied to this instance during this unit**. Whether it would deny an *unauthorized* mutation could only be established by attempting one. `NOT PROBED.` §4 D7 states the conclusion this forces. |

---

## 4. Decision

### D1 — Role, execution instance and technical principal are three things

```txt
LOGICAL ROLE   ≠   EXECUTION INSTANCE   ≠   TECHNICAL PRINCIPAL
```

- A **LOGICAL ROLE** is one of the seven actors [[DEC-0037]] D1 fixes. That taxonomy is permanent and is **adopted unchanged here**; no competing taxonomy is created.
- An **EXECUTION INSTANCE** is the concrete session, process or subagent that fills a role for one unit.
- A **TECHNICAL PRINCIPAL** is the identity a system authenticates and authorizes — a GitHub account, a CI token, a cloud principal, a database role.

The three are independent. One principal may carry many roles; one role may be filled by many instances; two instances may be entirely distinct and still authenticate as the same principal. **Separating roles separates responsibility. It does not separate principals, and it never does so by itself.**

### D2 — Four capability states, and the two invariants they exist to protect

Every capability claim is made on four axes, and a claim that does not say which axis it is on is malformed.

| Axis | Question |
|---|---|
| **DECLARED** | Does a documentation surface say this actor may or may not do it? |
| **TECHNICALLY AVAILABLE** | Can the current execution environment actually do it? |
| **PROCESS-AUTHORIZED** | Does the current unit's GO and writ permit it? |
| **MECHANICALLY RESTRICTED** | Does GitHub, CI or a runtime technically prevent it? |

State tokens, used throughout: **`AVAILABLE`** · **`NOT AVAILABLE`** · **`CONDITIONAL / GATED`** · **`UNKNOWN`**.

> **`TECHNICALLY POSSIBLE` ≠ `AUTHORIZED`.**
> **`DECLARED CAPABILITY` ≠ `AVAILABLE CAPABILITY`.**

`UNKNOWN` is a **required outcome**, not a failure. Where establishing availability would require performing a forbidden action, the honest record is `UNKNOWN — NOT PROBED`, never an assumption in either direction (§3.3).

### D3 — Capability dimensions

The dimensions in §5's table are the minimum needed to describe NOXUND accurately. They are a **descriptive vocabulary, not a permission system**: no dimension carries its own policy, no score is computed, and **no numeric capability score exists or may be introduced**. Authorization continues to come from the Product-Lead GO and the unit writ, exactly as [[DEC-0035]] §6 and [[DEC-0037]] D11 provide.

### D4 — Product-Lead-only actions: normative, not technical

**NORMATIVELY PRODUCT-LEAD-ONLY** — reserved by landed authority:

- issuing a scoped **GO** or **NO-GO** ([[DEC-0035]] §6; [[DEC-0037]] D11);
- the **final authority decision** on any escalated conflict or adjudication ([[DEC-0035]] §4 P3; [[DEC-0036]] §4);
- the **manual merge** that ratifies a governed record ([[DEC-0037]] D11);
- **acceptance** of a unit — the Product Orchestrator accepts nothing ([[DEC-0037]] D10);
- authorizing **agent provisioning, registration, activation or runtime wiring** (`docs/agents/README.md` §*Como adicionar um novo agente*, vinculante; [[DEC-0037]] D3);
- **human approval preceding any destructive mutation** (`agent-review-matrix.md` #11; `agent-onboarding-orchestration.md` §4);
- **re-arming** any write capability the Unit-D containment removed ([[DEC-0033]] §8).

**TECHNICALLY PRODUCT-LEAD-ONLY: none.** Every one of the above that has a technical expression — a merge, a ruleset change, enabling a workflow, writing a file — is executable by the same GitHub principal (E2, E14) and the same host session (E18). The GO has no technical expression at all: it is a human utterance in a session. **It cannot be forged by a mechanism only because it is not represented by one** — which is the same fact as its being unverifiable by a mechanism, and both halves must be stated together.

The exact classification for every action in the list above is therefore:

```txt
PROCESS / AUTHORITY RESERVED · NOT TECHNICALLY ISOLATED
```

**Do not represent any of them as technically enforced.** The reservation is real and binding; its enforcement is process, audit and the Product Lead's own conduct.

### D5 — The technical principal model

At this base NOXUND has **two** technical principals with repository reach, and one is genuinely constrained.

**Principal A — `AdeptLabsDev` (GitHub user `282037855`).** The Product Lead's account; the sole collaborator (E3); repository `admin` (E1); the identity behind `gh`, behind `git` via the `manager` credential helper (E20), and behind every governed merge (E14). **The Product Lead, the Product Orchestrator, and every task-scoped role instantiated in this environment act as Principal A.** It is also the sole `required_reviewers` reviewer on both Environments (E10) and the sole bypass actor on `19697151` (E6).

**Principal B — the CI identity (`GITHUB_TOKEN`).** Distinct, ephemeral, per-run, and **the only principal in NOXUND carrying any mechanical least-privilege at all**: repository default `read` and `can_approve_pull_request_reviews: false` (E12), reinforced by `permissions: contents: read` in all eleven workflow files **on `main`** (E13).

**Its two constraints are not equally strong, and the difference is stated rather than flattened.** `can_approve_pull_request_reviews: false` is a **repository-level setting a workflow cannot override** — Principal B **cannot approve a pull request**, full stop, and that is a genuine mechanical restriction. The contents restriction is **weaker than it looks**: `default_workflow_permissions: read` sets a *default*, and a workflow's own `permissions:` block may request more. So Principal B **cannot write repository contents under any workflow that exists on `main`** (E13) — but a new or modified workflow declaring `contents: write` would raise it. That is the same composite path D12 names, and it reinforces D12's conclusion rather than weakening it: **the durable constraint here is on approval, not on contents.**

**Other principal classes:** no database principal is reachable (`psql` absent, no connection variable set, no production successor exists — E19, `current-state.md` §C); no cloud principal is established as usable (`UNKNOWN`, U2); no GitHub App, bot or service account is established either way (`UNKNOWN`, U1 — **and absence is not to be inferred**); the only secret-bearing identity is Environment `youtube-collection` with one named secret (E9).

> **Consequence, stated plainly: `LOGICAL ROLE` and `TECHNICAL PRINCIPAL` are not aligned in NOXUND.** Seven roles map onto one repository principal, plus one constrained CI principal that holds no role at all.

### D6 — Logical independence versus technical independence

Where a task-scoped Author and a distinct task-scoped Reviewer both operate through Principal A, the exact and only permitted label is:

```txt
PROCESS-INDEPENDENT · PRINCIPAL-NOT-INDEPENDENT
```

Both halves are load-bearing. The process independence is **real**: [[DEC-0037]] D7's six checkable criteria are satisfiable and verifiable without any principal separation, and this record's own production depends on them. The principal non-independence is **also real**, and E14 shows it is not hypothetical — the last three governed PRs were authored and merged by the same principal with **zero** GitHub reviews recorded.

**Approver provenance.** The general question, asked without assuming `C2`'s answer: *if some future runtime must know that a Product-Lead approval is authentic, can this environment prove it technically?*

```txt
TECHNICAL APPROVER-PROVENANCE = NOT CURRENTLY SEPARABLE FROM SINGLE PRINCIPAL
```

**No**, and the reason is structural rather than incidental: the approval, the artifact and the agent all originate from one account and one host session. Two counter-facts are stated rather than omitted, and neither rescues the answer. First, merge commits carry a **server-side GitHub attestation** — `committer_login: web-flow`, `verified: true` (E15) — which a local push cannot forge, since the agent does not hold GitHub's signing key. But that distinguishes at most *merged server-side* from *pushed locally*; it does not distinguish *human* from *agent holding the same token*, and whether it survives an API-driven merge by that token is `UNKNOWN` (U5). Second, an Environment `required_reviewers` approval is a user-attributed, server-recorded event — but its reviewer is the same account, and the rule carries **`prevent_self_review: false`** with exactly one reviewer (E10), so the party that triggers a deployment may also approve it. **It is therefore an interaction gate, not a separation gate:** it attests that the **account** approved, never which **actor** behind it did, and it enforces no trigger ≠ approver separation even within that one account.

**The category of mechanism that would be required** — named, deliberately not designed and expressly not implemented: a **trust anchor whose private half the acting agent cannot use**. Three categories exist; choosing among them is not this record's work. (i) A distinct GitHub identity — App, bot or second human — whose credential is absent from the agent's host. (ii) A signing key held outside the agent's reach, with the consumer verifying signatures (local signing is currently unset — E15). (iii) An out-of-band approval channel not expressible by the agent's credential. **`C3` implements none of these** and D9 governs when any becomes a prerequisite.

### D7 — Generic CLI subagents

Represented as they are, from evidence.

- They are **technically available** and are the substrate on which every task-scoped role in this environment is instantiated.
- They are **not registered NOXUND agents**. [[DEC-0037]] D3 is applied unchanged: instantiating one creates no contract, no boundary, no runtime id, no registry entry, no standing permission, and it is never a `target_agent`. `ROLE NAMES DO NOT CREATE AGENTS` (`product-orchestrator-agent.md` §*Operational Invariants Summary*).
- They **inherit the host session's capabilities**, and this was measured rather than assumed: this unit's own instance resolved to the same GitHub principal, and held shell, filesystem and network reach (E18).

Therefore, and this is not softened:

```txt
ROLE SCOPING = AUTHORIZATION / PROCESS BOUNDARY, NOT TECHNICAL CAPABILITY SANDBOX
```

Assigning a task-scoped role restricts **what the instance is authorized to do**. On the evidence available it does **not** remove technical capability: no capability was denied to this instance during this unit. The honest limit of that observation is recorded at U6 — a permission layer exists in the harness, and whether it would deny an unauthorized mutation was not probed, because probing would require attempting one. **The conclusion is stated at the strength the evidence supports and no higher: role scoping must be relied on as a process boundary, and must never be described as sandboxing.**

### D8 — Registered-agent capability semantics

Carried forward operationally, and not modified:

```txt
REGISTERED  ≠  OPERATIONAL
ALLOWED ACTION IN CONTRACT  ≠  TECHNICALLY AVAILABLE ACTION
```

`docs/agents/README.md`'s three states stand unchanged: **zero registered NOXUND agents are REAL PRODUCT EXECUTORS**; `governance_integrity_agent` and `orchestration_runtime_engineering_agent` are `PROPOSED-NOT-OPERATIONAL / RUNTIME-NOT-WIRED` and bind nothing; the DevOps capability `apply_exact_remediation` is absent from the runtime allow-list at `agent-onboarding-orchestration.md` §9 and returns `needs_review` on any current invocation. An entry in a contract's `allowedActions` list is a **declared** capability under D2 and is evidence of nothing else. **No registry entry, contract or boundary is modified by this record, and no agent is represented as operational.**

### D9 — Principal separation: **OPTION P3 — HYBRID**, selected

**The decision.** Single-principal containment is **accepted for ordinary governed work** — analysis, decision records, reconciliation, routing, and the Product Lead's manual merge. A **second technical principal becomes a prerequisite** for exactly three narrowly defined things, none of which is currently in flight:

1. **Any representation that a GitHub approval was independent.** Until a second principal exists, no unit, record or report may describe review or merge independence as mechanical. This is a naming prohibition, not a capability gate, and it changes nothing about how work proceeds.
2. **Any reliance by a non-human consumer on the authenticity of an approval.** If a runtime, gate or automated step must *verify* that an approval is the Product Lead's, a trust anchor of the kind D6 names is a **prerequisite for that reliance** — not for the approval itself, and not for any work that does not rely on it.
3. **Any future automated actor that could perform an irreversible mutation without a human in the loop** — re-arming collection, applying a migration, provisioning cloud infrastructure. There the **acting** identity must be distinct from the **approving** identity, or the approval is self-issued. Today this is moot **in the sense that matters** — every such path is fail-closed (E16, E13), constrained to `main` and reviewer-gated (E10), and **none is authorized**. **Not because the existing gate would enforce it:** with one reviewer and `prevent_self_review: false`, the Environment gate is an interaction gate, not a separation gate (D6), so it would not by itself keep the acting identity distinct from the approving one. The protection today is that no such automated actor exists.

**`C3` provisions nothing.** No App, bot, account, token or credential is created, and the mechanism for any future second principal is left open (D6).

**Why P1 was rejected.** *Accept single-principal containment* is right about the present and silent about the one case where it genuinely fails. Item 3 above — an automated actor issuing its own approval — is not a theoretical neatness problem; it is the failure mode that makes an approval gate worthless, and P1 would leave it unnamed until the unit that builds it has to notice on its own. P1 is correct in substance for items outside that subset, which is why P3 keeps it there.

**Why P2 was rejected.** *Require a second principal* before high-risk capabilities count as mechanically independent fails on NOXUND's actual facts, in four ways. **Team size:** there is exactly one collaborator (E3), so a second *human* principal does not exist and cannot be conjured; requiring one would deadlock Product-Lead operation, which the decision criteria forbid. **Security cost is real, not neutral:** a bot or App is a new credential-bearing identity with a rotation and custody burden, added to a repository whose entire secret inventory is one Environment secret (E9) — it would *increase* attack surface against no current failure mode. **It misidentifies the current risk:** what is actually available to go wrong today is the *misrepresentation* of independence, which item 1 addresses at zero cost, not its absence. **And it would not fix F4b:** a second principal that is also an admin does not reduce tamper risk, while one that is not an admin cannot restore a deleted ruleset — so ruleset durability is not a second-principal problem at all (D11).

**Product-Lead final authority is preserved absolutely.** Nothing in P3 requires a second human, blocks the Product Lead from merging, or interposes any party between the Product Lead and acceptance.

### D10 — Current GitHub independence state — **F4a**, verified

> **F4a — REVIEW / MERGE PRINCIPAL SEPARATION GAP.** **Disposition: `ACCEPTED CURRENT LIMITATION`**, under D9 item 1's naming requirement, with detection candidates routed to `C5` (§8).

[[DEC-0037]] D12's two `REPORTED` claims are **re-derived and confirmed**, and are now `VERIFIED` (E6, E8): `required_approving_review_count` is `0`, `required_reviewers` is empty, `require_code_owner_review` is `false`, and no `CODEOWNERS` file exists. **Independent approval is not mechanically required, and the same principal may author and merge.** E14 promotes this from possibility to **observed practice** on the three most recent governed landings — including [[DEC-0037]]'s own. That is not a defect in those units; their independence was process-side and is not claimed to have been mechanical.

**What is NOT claimed, restated so it is not re-lost.**

```txt
DIRECT PUSH TO main = MECHANICALLY BLOCKED
```

[[DEC-0037]] D12 **permanently withdrew** the older claim that the `pull_request` bypass permits direct push to `main`. **The live read confirms the withdrawal and does not resurrect the claim**: ruleset `19697151` is `active`, its `pull_request` rule is present, its sole bypass actor is scoped `bypass_mode: pull_request`, and GitHub's own computed field reads `current_user_can_bypass: "pull_requests_only"` (E6). Repository `admin` does not itself confer ruleset bypass. **Three protections not previously recorded are also verified**: the `deletion` rule (`main` cannot be deleted), the `non_fast_forward` rule (`main` cannot be force-pushed), and `allowed_merge_methods: ["merge"]` (which is why every governed landing is a two-parent merge). The precise evidentiary limit is at U4: this rests on configuration plus GitHub's documented and computed semantics, **not** on an attempted push.

**The pull-request bypass, read honestly.** With `required_approving_review_count` already at `0`, the bypass adds little on the approval axis — there is no approval requirement for it to bypass. The operative fact is the count itself, not the bypass.

### D11 — Ruleset durability — **F4b**, kept distinct

> **F4b — PROTECTION DURABILITY / SINGLE-ADMIN TAMPER RISK.** **Disposition: `ACCEPTED CURRENT LIMITATION` + `DETECTION REQUIRED LATER`, routed to `C5`** (§8). **No second principal is required for it, and no ruleset is modified by this record.**

**F4a and F4b are distinct findings and are not merged.** F4a is about *who approves now*; F4b is about *whether the configuration survives*.

The risk is now stated precisely rather than generally. Three rulesets are `active` (E5). The two preservation rulesets are, in one respect, **stronger** than `Protect main`: they carry an `update` rule as well, their `bypass_actors` list is **empty**, and `current_user_can_bypass` reads **`never`** (E7) — the sole admin cannot push to, force-push, update or delete any of the eight preserved refs. **But the same principal can administer the ruleset itself.** That is the whole of F4b, and it is a **durability and tamper risk about the future**.

> **`CURRENT ENFORCEMENT` and `CONFIGURATION DURABILITY` are separate questions.** That an admin could alter a ruleset is **not** evidence that the ruleset is currently ineffective, and must never be reported as one. At this base every protection in E5–E7 is verified in force.

The proportionate response is **detection, not separation**: a periodic assertion that the observed configuration still matches the record. D9's reasoning applies — a second admin principal would not reduce this risk, and a second non-admin principal could not remedy it. Implementation is `C5`'s, under its own GO.

### D12 — Least privilege, as it actually stands

```txt
LOGICAL LEAST PRIVILEGE    = PRESENT
TECHNICAL LEAST PRIVILEGE  = PRESENT FOR THE CI PRINCIPAL ONLY
```

**Logical least privilege is real and functioning.** Each unit's GO and writ name a scope, exact paths and a write boundary; [[DEC-0037]] D8 makes staying inside them a checkable governance-review function. That is a genuine control and this record does not diminish it.

**Technical least privilege exists in exactly one place.** Principal B is mechanically constrained — read-only contents, no PR approval (E12, E13). Principal A is not constrained at all: it is repository `admin`, and the tools available to any instance acting as it are the full host session (E18).

**Do not describe process-only controls as sandboxing.** A writ that says *"do not write outside these paths"* is an instruction, not a mechanism. The distinction matters most where it is least visible: **the mechanical protections that do exist protect `main` and the preserved refs (E6, E7) — they do not constrain what an instance can do before a merge, or outside the repository.**

**One composite path is named rather than left to be discovered, and then stated at its true strength.** Workflow files are ordinary repository files, and `workflow_dispatch` is available; so the combination *modify a workflow → dispatch it* is the route by which an actor with Principal A could cause a workflow to read an Environment secret it would not otherwise read. **But that path is mechanically constrained, not merely process-gated, and saying otherwise would commit §2's second failure mode — overclaiming danger — on the most security-relevant path in this record.** Any job binding either Environment is subject to a **deployment branch policy resolving to exactly one branch, `main`** (E10): such a job **cannot run from a feature branch at all**. So the workflow must first reach `main`, and reaching `main` is itself mechanically gated by ruleset `19697151`'s `pull_request` rule (E6, D10) — direct push being blocked. Only then does the Environment's `required_reviewers` gate apply. **Three controls in series, two of them mechanical.** **The residual, stated exactly:** a single principal can satisfy all three alone — author the change, merge it, and approve the deployment — and the reviewer gate carries **`prevent_self_review: false`** with one reviewer (E10), so it does not enforce trigger ≠ approver even within the one account. **That is a single-principal residual, not an absence of mechanism**, and it is exactly what D9 item 3 governs prospectively. **Stated as a capability fact and `NOT PROBED`** — no workflow was created, modified or dispatched, and no deployment was approved. Detection is routed to `C5` (§8); nothing here authorizes acting on it.

### D13 — `C2` interface

The `C2` conditional consequences are set out in §7 and are binding as part of this decision. **`C3` does not decide `C2`, does not wait for `C2`, and remains valid under all three of its dispositions.**

### D14 — `C4` dependency

`C4` — the `AgentResult` V2 / result schema — is the natural carrier for capability and principal metadata. **This record identifies what that metadata must be able to express and does not design the schema**: no field names, types, cardinalities or validation are specified, and `C4` remains free to model it as it judges best. See §8.

### D15 — `C5` routing

Mechanical-enforcement candidates arising from this model are **routed and not implemented** (§8). **No workflow, ruleset, `CODEOWNERS` file, reviewer requirement, validator, lint, hook or CI check is created, modified or proposed for creation by this record**, and `C5` requires its own explicit Product-Lead GO.

### D16 — Effective on landing

Per §13. The model governs work commenced after this record's merge, retroactively validates and invalidates nothing, and creates no standing permission.

---

## 5. The capability surface

**Why this is embedded rather than a separate file, since the choice is a real one.** A separate `DESCRIPTIVE-CURRENT` matrix would be `EDITABLE` and create no authority — but this record is `FROZEN`, and **a FROZEN record must not depend on a mutable file for its normative content**. Splitting would force either that dependency or duplication of the normative rows. The volatile part is small (the §3.1 configuration snapshot), `current-state.md` §D/§E already owns volatile state under a freshness contract, and a third current-state-like surface would add a maintenance target and a staleness risk for no gain. The table is compact enough to embed, and [[DEC-0037]] D1 embeds its own taxonomy table on the same reasoning. **The table below is a dated observation; the rules that bind are in §4.**

**Read the columns exactly.** *Technically available* is asked of the **shared host session acting as Principal A** — which is the substrate for the Product Lead, the Product Orchestrator and every task-scoped role alike. **That one column answers for all of them is itself the finding**, not a simplification of it. *Mechanically restricted* is asked of GitHub, CI or a runtime. *Authorized* is what landed authority and a unit writ permit — never what the machine allows.

| Capability | Technically available (Principal A / shared session) | Mechanically restricted | Authorized to |
|---|---|---|---|
| Repository read | `AVAILABLE` | no | every actor |
| Working-tree write · file create / modify / delete | `AVAILABLE` | no | the Author, inside the unit's declared write scope only |
| Shell execution | `AVAILABLE` | no | as the unit requires; destructive commands need Product-Lead approval |
| Dependency installation | `AVAILABLE` | no | no one, absent an explicit GO (`mínimo necessário`, `global-agent-rules.md`) |
| Outbound network access | `AVAILABLE` (E18) | no | as the unit requires |
| Git branch creation · commit · push to a non-`main` branch | `AVAILABLE` | no | the Product Orchestrator, after review; never an Author unilaterally |
| **Direct push to `main`** | **`NOT AVAILABLE`** | **yes** — ruleset `19697151`, `pull_request` rule, bypass scoped `pull_requests_only` (E6) | no one |
| Force push · deletion of `main` | **`NOT AVAILABLE`** | **yes** — `non_fast_forward` + `deletion` rules (E6) | no one |
| Push · update · force-push · delete a **preserved ref** | **`NOT AVAILABLE`** | **yes** — rulesets `20727975` / `20890207`, `current_user_can_bypass: never` (E7) | no one |
| PR creation | `AVAILABLE` | no | the Product Orchestrator |
| PR review (a GitHub review object) | `AVAILABLE` | no — and **not required**: `required_approving_review_count: 0` (E6), zero reviews on recent PRs (E14) | any distinct reviewer; **never** the Author |
| **PR merge** | `AVAILABLE`, including merging one's own PR (E14) | no | **the Product Lead only** — `PROCESS / AUTHORITY RESERVED · NOT TECHNICALLY ISOLATED` |
| GitHub API read | `AVAILABLE` | no | as the unit's GO grants |
| GitHub API mutation | `AVAILABLE` | no | only where a GO names the exact mutation |
| **Ruleset administration** | `AVAILABLE` — `permissions.admin: true` (E1); **`NOT PROBED`**, no mutation attempted | no | **the Product Lead only**; `C5` is the venue for any change |
| Workflow file modification | `AVAILABLE` | no | no one, absent a GO — see D12's composite-path note |
| Workflow dispatch | `AVAILABLE` for `workflow_dispatch` workflows | partially — 6 DB-apply workflows are `disabled_manually`; collection workflows are fail-closed on absent markers (E13, E16) | no one, absent a GO |
| Repository / Environment **secret values** | `NOT AVAILABLE` — GitHub never returns secret values by API | **yes** for direct read; and the D12 composite path is **`CONDITIONAL / GATED` by mechanism**, not by process alone — a job binding either Environment can only run from **`main`** (E10 branch policy), reaching `main` requires the PR mechanism (E6), and the reviewer gate then applies. **Residual: one principal can satisfy all three, and `prevent_self_review: false`** | no one |
| Secret and variable **names**; Environment configuration | `AVAILABLE` | no | as the unit's GO grants — this unit read names only |
| Database access | `NOT AVAILABLE` — `psql` absent, no connection variable, no production successor exists (E19) | n/a — nothing to reach | no one |
| Cloud / AWS access | **`UNKNOWN`** — config present, credentials file absent, `NOT PROBED` (U2) | `UNKNOWN` | no one, absent a GO |
| Collection arming / re-arming | `AVAILABLE` as a file write; the markers are absent (E16) | no — **absence of the marker is the disarmed state, not a mechanism** | **no one** — requires its own Product-Lead decision ([[DEC-0033]] §8) |
| Artifact authority mutation — landing a DEC, editing a FROZEN record | `AVAILABLE` as a file write | no | the Author, inside write scope; **a FROZEN record is never edited** ([[DEC-0035]] §3.3) |
| Registered-agent registration · activation · runtime wiring | `AVAILABLE` as a file write | no | **no one** — registry-first gate, `docs/agents/README.md`; [[DEC-0037]] D3 |
| Destructive local filesystem operation | `AVAILABLE` | no | only under `agent-review-matrix.md` #11's sequence, whose capability is `PROPOSED-NOT-OPERATIONAL` |

**Principal B — the CI identity — separately, because it is genuinely different.**

| Capability | State |
|---|---|
| Repository contents write | `NOT AVAILABLE` **under every workflow that exists** — `default_workflow_permissions: read` (E12) and `permissions: contents: read` in all 11 files on `main` (E13). **A default, not a ceiling**: a workflow declaring `contents: write` would raise it (D5) |
| **Approve a pull request** | **`NOT AVAILABLE`** — `can_approve_pull_request_reviews: false` (E12), a repository setting **a workflow cannot override**. The one durable mechanical constraint on this principal |
| Read Environment secrets at run time | `CONDITIONAL / GATED` — only where a workflow binds the Environment, **the run is on `main`** (E10 branch policy), and the reviewer gate is satisfied (E10) |
| Any repository configuration mutation | `NOT AVAILABLE` |

> **The single most useful sentence a fresh operator can take from this table:** the mechanical protections in NOXUND guard **`main` and the preserved refs**. Everything else is guarded by authorization and by the Product Lead, and must be described that way.

---

## 6. `agent-review-matrix.md` — the identity-naming clauses [[DEC-0037]] §9 routed here

[[DEC-0037]] §6 narrowed item **#12** and nothing else, and routed *"the satisfiability of every identity-naming clause other than #12"* to `C3`. That routing is answered here — with a **general rule and a LIVE / LATENT classification**, not a clause-by-clause rewrite. **The matrix file is not edited by this unit.**

### 6.1 The general rule

> **An identity-naming clause binds when its trigger fires. Whether the named identity can satisfy it is a separate question with exactly three outcomes.**
>
> **The prior question, always asked first: does the trigger fire at this base?** A clause whose trigger cannot fire is **LATENT** and requires nothing of anyone. Latency is a fact about the world, never a disposition of the clause.
>
> 1. **The named identity is operational** → it satisfies the clause.
> 2. **It is not operational, and a landed decision has narrowed that clause to the function it was for** → the function satisfies it, on the terms that decision states. **This has happened exactly once, for #12 ([[DEC-0037]] D9), and is never extended to another clause by analogy.** Narrowing a clause requires its own landed record.
> 3. **It is not operational and no landed decision has narrowed the clause** → the unit returns **`HOLD` + `AGENT-CAPABILITY-GAP`** and escalates under [[DEC-0035]] §4 **P4**. **Never routed around** ([[DEC-0037]] D6).

This is [[DEC-0037]] D2 and D8 applied, not amended: `REGISTERED ≠ OPERATIONAL`, and an unavailable agent is never represented as operational to make a unit fit.

### 6.2 Item **#10** — *"Documentação que altera decisões → **Product Orchestrator**"* — **reconcilable at clause granularity; NOT a `HOLD — AUTHORITY-CONFLICT`**

This record is a decision record, so #10's trigger fires and the question is live for this unit's own production. It has to be answered, not stepped around.

**The reading that would create a conflict, stated at its strongest first.** #10's cell sits in a column headed **`Revisão obrigatória`**, and the Product Orchestrator appears in that column in four rows (#5, #6, #9, #10). Read that way, #10 makes the Product Orchestrator a **mandatory reviewer** of every decision record — which collides head-on with [[DEC-0037]] D10's *"may not: author · review · accept · merge"*, and would be a genuine [[DEC-0035]] §4 **P3** conflict between two CURRENT INTERNAL-NORMATIVE authorities. **That is the argument against the conclusion below, and it is not a weak one.**

**It nonetheless does not win, on the file's own text.** [[DEC-0035]] §11 step 1 requires classification **at clause granularity, not file or column level**, and three statements in the immediate context distinguish the Product Orchestrator's act from the reviews:

- the matrix's own *Fluxo de aplicação*: `aciona revisor(es) → revisor aprova/bloqueia → Product Orchestrator confirma todas as revisões → aprova/rejeita/pede ajuste` — the Product Orchestrator's act is **after** and **distinct from** the reviews;
- the matrix's own header: its function is to define which change triggers which review *"antes do 'aprovado' do Product Orchestrator"* — positioning that act as terminal, not as one of the reviews;
- `agent-registry.md`'s Product Orchestrator row, whose *Required reviews* cell reads **`É o aprovador`** — the approver, not a peer reviewer — with the counterpart at the Documentation row: *"**PO** quando o doc registra/altera decisão"*.

**And #10's own rationale settles it.** The *Por quê* cell reads *"Decisão só vale se registrada e aprovada"* — a statement about **when a decision becomes valid**, which [[DEC-0037]] D11 answers exactly: *a record is in force from that merge, not from being authored*.

**Conclusion.** #10 names the **decision-registration and gate-confirmation function** — routing the record to its ratification gate and confirming that every required review was actually held — which [[DEC-0037]] D10 **expressly grants** the Product Orchestrator ("routing, reconciliation, surfacing `HOLD`/`RED`, the final return"). It does **not** name an independent review function, which D10 expressly withholds. **The two authorities do not conflict, so P3 does not engage and no `HOLD` is returned.**

**The second counter-fact, which is the stronger one and is not omitted.** The *Fluxo de aplicação* line quoted above ends `→ **aprova**/rejeita/pede ajuste`, and `agent-registry.md`:84 reads *"O PO responde cada handoff com **aprovar** / rejeitar / pedir ajuste"*. **The corpus does use a verb of approval for the Product Orchestrator**, which cuts against guardrail (a) below and against [[DEC-0037]] D10's *"may not … accept"*. Two landed clauses in the Product Orchestrator's own contract dissolve it, and neither is a reading of mine:

- `product-orchestrator-agent.md`:397 — *Papéis operacionais*, the Product Orchestrator row: *"decompõe, delega, ordena dependências, reconcilia e reporta · **não substitui os papéis acima**"*. That phrase sits in the column headed *"Pode aceitar o próprio trabalho?"*, and the roles *acima* are Author, Technical Reviewer, Governance/Integrity Reviewer, Security/Data/Standards Reviewer and QA. **The Product Orchestrator is definitionally none of them** — which is the whole of the question #10 raises.
- `product-orchestrator-agent.md`:684 — *"O Orchestrator pode marcar uma unidade como `READY FOR PRODUCT LEAD REVIEW` quando os gates internos estiverem satisfeitos. **Ele não deve representar uma operação humana-required como finalmente aprovada antes da decisão humana**"*. The Product Orchestrator's *aprova* is therefore **explicitly not final approval**: it is the internal-gate confirmation that a unit is ready for the human decision, and the contract forbids representing it as anything more.

So the `aprova` token names a gate-confirmation act the same contract bounds, not the acceptance [[DEC-0037]] D10 withholds. **The residual tension with D10's *"may not … accept"* is pre-existing, not created here, and :684 already resolves it.**

Three guardrails, so this is not read as more than it is. **(a)** It gives the Product Orchestrator **no** power to accept or merge — the approval that makes a decision valid is the Product Lead's manual merge ([[DEC-0037]] D11). **(b)** It relaxes **nothing** in [[DEC-0037]] D5/D6: the independent technical and governance review functions remain mandatory and are held by distinct task-scoped reviewers. **(c)** Item **#12 applies independently** to any governance-sensitive decision record — including this one — so a distinct governance reviewer is required regardless of #10.

**This is a reading, not a narrowing.** #10 is unchanged, uncorrected and not declared wrong, on the precedent [[DEC-0035]] §9's reading note set and [[DEC-0036]] §4 named. It is also a **different operation** from [[DEC-0037]]'s treatment of #12: #12 was a **P4** divergence repaired at the authority end by narrowing; #10 is a reading question that needs no narrowing at all.

### 6.3 Item **#13** — *"Mudança de fronteira sensível a segurança → `security_agent`"* — **trigger does NOT fire for `C3`**

Established rather than assumed, and checkable by a reviewer against the diff.

A *fronteira* in this corpus is an **agent boundary** in the `agent-boundaries.md` sense — Mission / Owns / Can decide / Cannot decide / Must request review / Forbidden actions — and #13's rationale scopes it: *"Alteração de boundary pode expandir superfície de acesso/risco."* This unit changes none. It **edits no file under `docs/agents/**`**; it creates or alters **no** ruleset, `CODEOWNERS` file, reviewer requirement, permission, credential, secret, Environment, workflow, allow-list, capability grant, agent contract or runtime wiring. **It expands no access surface and no risk surface.** Describing a boundary is not changing one: a descriptive statement of state creates no authority and repeals none ([[DEC-0035]] §3.1, §4 P4).

```txt
C3 CHANGES NO BOUNDARY — #13 DOES NOT FIRE
```

**The forward flag, surfaced now rather than left for someone to trip over.** When #13's trigger *does* fire — a `C5` unit implementing an enforcement control, a unit provisioning a second principal under D9, or any change to a boundary file — outcome 3 of §6.1 applies: `security_agent` holds `FORMAL CONTRACT + FOUNDATION RUNTIME HANDLER` and **no REAL PRODUCT EXECUTOR exists**, which is a [[DEC-0035]] §4 **P4 STATE-AUTHORITY DIVERGENCE** to **surface and escalate**, never to route around ([[DEC-0037]] D6). **`C3` deliberately does not narrow #13 the way [[DEC-0037]] narrowed #12** — doing so on the strength of an analogy is precisely the routing-around D6 forbids, and it is not this unit's to do.

### 6.4 Every other identity-naming clause — LIVE / LATENT

| Clauses | Classification at this base | Basis |
|---|---|---|
| **#10** | **LIVE** — fires for any decision record | §6.2: satisfiable, no conflict, no narrowing needed |
| **#12** | **LIVE** | already narrowed to the function by [[DEC-0037]] D9; satisfied by a distinct `TASK-SCOPED GOVERNANCE REVIEWER` |
| **#13** | Can fire in principle; **does not fire for `C3`** | §6.3, with the forward flag |
| **#1–#9** and the entire *Gatilhos adicionais* table | **LATENT** | every trigger is Axis-1 product/engineering work — backend, schema, migrations, raw/computed, Score, frontend, deploy, marketing copy, collection, RLS, secrets. Axis 1 is paused with no authorized unit (`current-state.md` §B) |
| **#11** and the `apply_exact_remediation` chain | **LATENT** | the capability is `PROPOSED-NOT-OPERATIONAL / RUNTIME-NOT-WIRED` and **absent from the runtime allow-list** at `agent-onboarding-orchestration.md` §9 — re-derived here. [[DEC-0037]] §6 already classified it LATENT and it is untouched |
| **#14–#16** | **LATENT · CONDITIONAL ON `C2` DISPOSITION** | they trigger on control-plane changes to `@noxund/orchestrator`, whose author identity is `CONTRACT-PROPOSED / RUNTIME-NOT-WIRED / NOT-OPERATIONAL` and whose package is reached by no executable file and no workflow (E17). Whether they become LIVE is `C2`'s to determine — see §7 |
| Both **Bootstrap** sections | **LATENT** | their triggers are the initial definition, registration or first runtime activation of two agents. No registration, activation or wiring is authorized; the registry-first gate stays binding and unwaived ([[DEC-0037]] D3) |

**No clause is adjudicated one by one, and the matrix is not rewritten.** Where a genuine per-clause adjudication is later required, it is its own authorized unit.

---

## 7. `C2` interface / conditional consequences

`C2` is evaluating `packages/orchestrator` in parallel and will return **RESUME-AND-HARDEN**, **REDUCE** or **RETIRE**.

```txt
THIS RECORD IS VALID UNDER ALL THREE DISPOSITIONS
```

**`C3` does not decide `C2`, does not wait for it, and touches `packages/orchestrator` in no respect** — E17 is a capability observation and carries no disposition. The authority direction [[DEC-0037]] §9 fixes is inherited unchanged: **`C1 GOVERNANCE MODEL → RUNTIME IMPLEMENTATION`, never the reverse.** A runtime **implements** this model; no runtime behaviour amends it.

**If `C2` = RESUME-AND-HARDEN.** The runtime becomes both an **actor** and a **consumer of approvals**, which engages three things above. **D9 item 3** applies: the identity that *acts* must be distinct from the identity that *approves*, or the human-approval gate is self-issuable by the same credential. **D6 applies**: approver provenance is not currently separable from a single principal, so the hardening must either supply a trust anchor of the kind D6 names, or the gate must remain an *interaction* gate and be labelled as one — it may not be described as verifying provenance it cannot verify. **§6.4 applies**: items #14–#16 become LIVE, and #15's `security_agent` requirement then meets the same P4 divergence §6.3 flags. Any runtime allow-list entry is a **declared** capability under D2 and becomes available only through the registry-first gate.

**If `C2` = REDUCE.** The retained primitives that carry **principal semantics** are exactly four: the human-approval gate (`requires_human_approval`), the dispatcher's authorization check, the agent-registry allow-list, and any binding of an approval to a task. Whichever of these survives inherits D6's limitation and must state it in its own terms. Primitives that are pure schema validation, state tracking or logging **carry no principal semantics** and inherit nothing from this record.

**If `C2` = RETIRE.** Everything here about **human and GitHub** principals stands untouched and fully in force — D1–D12, F4a, F4b, the P3 decision and the capability surface. Only the *runtime-approver* limb loses a present referent, and even it survives as a standing rule: **any future automated approver requires a principal distinct from the acting one before its approval may be relied on** (D9 item 3). Retirement removes an implementation, not a principle.

---

## 8. `C4` and `C5` — identified and routed, not designed and not implemented

**`C4` — result schema.** The metadata a result must be **able to express**, so capability and principal claims are auditable after the fact. **Field names, types, cardinality, validation and the schema's shape are `C4`'s and are not specified here:**

logical role (one of [[DEC-0037]] D1's seven) · execution-instance identity, and whether it was a generic CLI subagent · the technical principal actually used · the authorizing GO or writ · reviewer independence type — `PROCESS-INDEPENDENT · PRINCIPAL-NOT-INDEPENDENT` versus principal-independent · capabilities actually exercised against those authorized, including the write scope actually touched · the evidence class of each load-bearing claim (`VERIFIED` / `REPORTED` / `UNKNOWN`).

**`C5` — mechanical enforcement.** Candidates, **routed only**. Nothing below is created, prototyped, scheduled or proposed for a particular mechanism, and each requires `C5`'s own explicit Product-Lead GO:

1. **Ruleset-configuration drift detection** — assert the three rulesets' rules, bypass scoping and enforcement are unchanged (**F4b**, D11).
2. **Fail-closed-state assertion** — `.github/collection/` remains absent; the six DB-apply workflows remain `disabled_manually`.
3. **CI-principal least-privilege assertion** — `default_workflow_permissions` stays `read`, `can_approve_pull_request_reviews` stays `false`, workflow `permissions:` blocks stay `contents: read` (D12).
4. **Detection for the composite workflow path** named in D12.
5. **Docs classification checks** for [[DEC-0035]] §7's fail-closed header rule — already routed by [[DEC-0035]] §12.
6. **Principal-aware gates** — meaningful only once a second principal exists; **conditional on D9's subset**, and not a reason to create one.

**Review-count enforcement, `CODEOWNERS`, reviewer thresholds and branch protection remain `C5`'s exclusively** ([[DEC-0037]] §9), and `C3` proposes no value for any of them.

---

## 9. Forward discoverability

[[DEC-0035]] §10 requires the forward-discoverability update to be created **in the same authorized unit** that creates the relation. Both edges this record creates are recorded in the relation table at `docs/product/context-map.md` §3:

1. `DEC-0039 EXTENDS DEC-0037 §9 · D12` — supplying the capability/principal limb `C3` reserved, and promoting D12's two `REPORTED` claims to `VERIFIED`. **[[DEC-0037]] is FROZEN and is not edited**; the external table is the mechanism §10 directs for that case.
2. `DEC-0039 REDIRECTS-TO agent-review-matrix.md #10 · #13` — reader-side discoverability for §6's readings. **`REDIRECTS-TO` asserts no supersession**, which is correct here: nothing is narrowed, and no in-file pointer is added, because §10's trigger — *supersedes, discharges, narrows or extends* — does not fire for a reading.

**This unit is incomplete without both rows.**

---

## 10. Reconciliation performed by this unit

Bounded to what this decision makes stale. Nothing historical is rewritten, and **no file under `docs/agents/**` is touched**.

1. **`docs/product/context-map.md`** — the two §3 relation rows required by §9; a §1 routing row for the capability and principal model; a scoped-reverification paragraph per that document's convention.
2. **`docs/product/current-state.md`** — §E's *"Process independence is not mechanical independence"* bullet is repaired where this unit's live read makes its provenance stale (the claims are now `VERIFIED`, not `REPORTED`) and where new verified protections are added; §B's Axis-2 ladder is repaired because **this unit's own landing** makes the `C2`…`C5` *"not started"* statement false for `C3`. A scoped-reverification paragraph is added. **`C2`-dependent facts are left conditional and are not resolved.**

**Deliberately left alone, and named rather than swept:** `agent-review-matrix.md` (read in §6, not edited); `agent-registry.md`, `agent-boundaries.md`, `docs/agents/README.md`, `product-orchestrator-agent.md`, `global-agent-rules.md` (whose rule 12 — *"Nenhum agente pode fazer push direto na `main`"* — is **confirmed by measurement**, D10, and needs no repair); `orchestration-runtime.md` (`PHASE-B-CLOSEOUT-R1` §5 row 2, still routed); `task-context-pack.md`; and the corpus-wide historical normalization residual (`PHASE-B-CLOSEOUT-R1` §5 row 1).

---

## 11. What this record does **not** decide

Named, so a reader does not mistake silence for an answer.

- **It does not decide `C2`** — not `packages/orchestrator`'s disposition, not whether any runtime is kept, reduced or retired, not runtime hardening, and not runtime-specific approval mechanics.
- **It does not create, choose or design a second principal.** D9 states *when* one becomes a prerequisite; the mechanism, timing and provisioning are a later authorized unit's.
- **It does not decide whether the current single-principal arrangement should change** for anything outside D9's three-item subset.
- **It does not design the `C4` schema** or specify any field of it.
- **It does not implement, prototype or specify any `C5` control**, and proposes no ruleset, reviewer threshold or `CODEOWNERS` content.
- **It does not narrow, extend or reinterpret any clause** of `agent-review-matrix.md` or any other file. §6 reads two clauses; #12's narrowing remains [[DEC-0037]]'s alone.
- **It does not resolve the `#13` P4 divergence** — it surfaces it for the unit whose trigger fires.
- **It does not decide test quality, dependency quality, performance budgets or engineering simplicity standards** — Phase D.
- **It does not design autonomous credential delegation, orchestration memory, automatic next-step execution, agent-DAG principal delegation or self-issued approvals** — Phase F, and D9 item 3 is a constraint on such work, never an authorization of it.
- **It does not establish** that any AWS principal exists or is usable (U2), or that no GitHub App is installed (U1). Both stay `UNKNOWN`.
- **It does not resolve any Axis-1 technical question**, re-arm anything ([[DEC-0033]] §8), or authorize any unit.

---

## 12. Explicit non-decisions

This record does **not** and must not be read to: create, register, rotate or delete any GitHub principal, App, bot, service account, token, credential or secret · create or change any ruleset, branch protection, `CODEOWNERS` file, reviewer requirement, Environment, variable or repository setting · create or change any workflow, workflow registration, CI check, validator, lint or hook · dispatch any workflow · register, wire, activate or promote any agent or capability · edit any agent contract, boundary, registry entry or review matrix · dispose of `packages/orchestrator` or materialize, build, test or port `151fb46` · define `AgentResult` V2, a risk engine or any mechanical enforcement · connect to any database or Supabase resource · call any AWS API or provision any cloud resource · arm or re-arm any collection path ([[DEC-0033]] §8) · mutate any preserved ref, branch, stash or archive · change product scope, MVP admission or any `OD-*` item · resolve the successor PostgreSQL architecture or any Axis-1 technical question · define improvement Phase D, E or F · classify, promote or demote any artifact · edit, supersede or reinterpret [[DEC-0035]], [[DEC-0037]] or any prior DEC · rewrite any historical artifact · authorize `C2`, `C4`, `C5`, or any commit, push, PR, merge or execution of any kind.

---

## 13. Effective and landing semantics

**In force from the Product Lead's manual merge of this record**, and prospective from that moment. Specifically:

- it governs governed work **commenced after landing**;
- it **does not retroactively validate or invalidate any earlier unit**, including its own production, which stands on the `C3` GO and on nothing in this record — **a record does not ratify itself**. In particular, PRs #86–#88 (E14) are **not** retrospectively defective: their independence was process-side, and no unit claimed otherwise;
- it creates **no standing permission**: every unit still requires its own explicit Product-Lead GO ([[DEC-0035]] §6);
- it is **FROZEN** ([[DEC-0035]] §9): its body is never rewritten, a change to this model requires a **later landed record**, and no GO, handoff, closeout or memory may amend it ([[DEC-0035]] §5, §6);
- **the §3 configuration snapshot is a dated observation, not a rule.** Configuration drifting from it is a fact to be reported — and, under [[DEC-0035]] §4 P4, either a `STATE-AUTHORITY DIVERGENCE` or a `STALE-DESCRIPTIVE` observation, never an amendment of §4. **The normative content of this record does not depend on any measured value**;
- imperative wording in any EVIDENCE artifact describing this model creates no obligation beyond what this record states ([[DEC-0035]] §3.1).

---

*Related: [[DEC-0037]] D1 (actor taxonomy, adopted unchanged), D3 (task-scoped roles are not agents), D7.7 (same credential is not principal independence), D10–D11 (Product-Orchestrator constraints; GO and merge), D12 (F4a / F4b, whose GitHub-configuration claims are promoted to `VERIFIED` in §3), §6 (#12 LIVE / #11 LATENT), §9 (`C3` routing, and the one-way authority direction); [[DEC-0036]] §4 (adjudication without supersession); [[DEC-0035]] §3.1 (imperative wording confers no class), §3.3 (FROZEN and byte-frozen), §4 P3/P4 (conflict versus divergence), §6 (GO versus durable authority), §9 (family defaults), §10 (forward discoverability), §11 (clause-level classification), §12 (Phase-C boundary); [[DEC-0033]] §8 (nothing re-arms). Agent surfaces read and **not edited**: [`agent-review-matrix.md`](../../agents/agent-review-matrix.md), [`README.md`](../../agents/README.md), [`agent-registry.md`](../../agents/agent-registry.md), [`agent-boundaries.md`](../../agents/agent-boundaries.md), [`product-orchestrator-agent.md`](../../agents/product-orchestrator-agent.md), [`global-agent-rules.md`](../../agents/global-agent-rules.md), [`agent-onboarding-orchestration.md`](../../agents/agent-onboarding-orchestration.md). Routing surfaces reconciled: [`current-state.md`](../current-state.md), [`context-map.md`](../context-map.md).*
