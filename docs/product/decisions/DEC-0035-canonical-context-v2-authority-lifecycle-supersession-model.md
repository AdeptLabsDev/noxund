# DEC-0035 — Canonical Context V2: authority / lifecycle / supersession model

**Status:** ACTIVE (binding) · **Date:** 2026-08-17 · **Decision authority:** Product Lead · **Drafted by:** a task-scoped Author, reviewed by a distinct task-scoped independent Reviewer, under the authorized Product-Orchestrator-coordinated process (§14) · **Ratification gate:** the Product Lead's manual merge of this record
**Scope:** The minimum durable semantic model for how NOXUND context artifacts carry — or fail to carry — authority. Establishes three independent classification axes, a precedence order, a memory ruling, a fail-closed rule for new artifacts, a non-retroactive rule for the legacy corpus, family-level defaults, and forward-supersession semantics. **Docs-only unit.**
**Negative scope — this record does not create or change:** any database, SQL, migration, role, runner, Compose file, workflow, workflow registration, ruleset, Environment, secret, variable, credential, remote connection, code file, agent runtime wiring, `packages/orchestrator/**`, task pack, context index, current-state document, supersession table, classification header on any existing file, or memory content. **No agent is wired and no execution of any kind is authorized.**
**Extends:** [[DEC-0032]] §8 (which routed *Canonical Context V2 and `context/**`* to **Phase B — NOT STARTED**); the additive-only doctrine of [[DEC-0022]] §4, [[DEC-0023]] §D-F and [[DEC-0031]]; [[DEC-0034]] §7 *Phase-A boundary* (which reserved Canonical Context V2 to a later phase).
**Does not edit:** any prior DEC record. [[DEC-0001]] … [[DEC-0034]] all remain **frozen and additive-only**. [[DEC-0028]] and [[DEC-0033]] remain **byte-frozen** per [[DEC-0034]] §4. No prior record is declared obsolete, reopened or reinterpreted here.
**Predecessor unit:** `PHASE-B-B0-CANONICAL-CONTEXT-V2-FOUNDATION-ASSESSMENT-R1` — an **unlanded in-session assessment**, accepted by the Product Lead and carried in the Product Lead's operating record. It is **not defined by any canonical record on `main` and has no file path**. Following the convention [[DEC-0033]] §8 sets for unlanded identifiers, it is named here for provenance only, never to confer landed standing. **No binding claim in this record rests on that assessment** — every §9 and Annex assertion was independently re-derived from the repository at the canonical base; a fresh agent must not attempt to locate it.
**Canonical base:** `main` @ `b45bde6a4c8c8f7223b6cd556d2707f865425dee`

---

## 1. Status

**ACTIVE — binding and prospective**, effective from this record's date. It is a classification and precedence model. It confers no authority backwards in time, promotes no artifact, demotes no artifact, and authorizes no execution.

---

## 2. Why this record exists

**No landed record ratifies a latest-wins precedence rule.** A precedence-and-escalation rule does already exist in landed binding form — but it is **scoped**. `docs/agents/product-orchestrator-agent.md` §*Source of Truth* ranks the named `/context` sources against one another (*"Hierarquia em conflito: decision log → PRD → metodologia/banco → stack/GTM/execução/riscos → arquitetura/estratégia. Conflito real entre níveis = `OPEN DECISION` + escalation"*) and governs agent conclusions against those sources (*"Uma conclusão de agente não supera a fonte de verdade … o Orchestrator preserva as duas leituras e escala o conflito; não escolhe silenciosamente a mais conveniente"*). `docs/agents/global-agent-rules.md` — self-declared *"Status: vinculante"* — binds the same escalation behaviour for every agent (*"conflito de documentos … → parar e marcar `OPEN DECISION`"*; *"Conflito não resolvido → `OPEN DECISION` + Product Lead"*), and `docs/product/context-index.md` restates the same `/context` hierarchy.

**What no landed record states is the general rule.** Those surfaces rank the ten `/context` files they name against each other; they say nothing about how a decision record relates to a security review, a handoff, a phase closeout, agent memory, or an external constraint — which is most of the corpus and nearly all of the traffic. Outside the `/context` ranking a fresh agent must still infer precedence, and the most available inference is *the newest file wins*.

**This record therefore generalizes an existing scoped rule; it does not invent precedence from nothing.** P3's *escalate, never infer the winner* is continuous with the escalation behaviour those surfaces already bind, extended to the whole corpus. Equally, those surfaces do **not** establish the three-axis model of §3 — no landed record separates authority class from lifecycle from mutability, and that separation is new here. The gap shows up as three distinct questions the repository has been conflating into one:

1. **Does this document bind me?** (authority)
2. **Is it still in force?** (lifecycle)
3. **May it be edited?** (mutability)

Treating these as one dimension produces two failure modes already present in the corpus. First, a document is called `SUPERSEDED` as if that were its authority class, which erases the fact that a superseded decision remains **INTERNAL-NORMATIVE in kind** and merely no longer **CURRENT**. Second, byte-frozen authority ([[DEC-0028]], [[DEC-0033]]) cannot record its own supersession, so a reader of the file alone sees an obligation that a later record has already discharged.

This record separates the three questions and fixes the precedence order between them. It is a rule document, not a survey; the survey was the unlanded B0 assessment named in the header.

---

## 3. Decision — three independent axes

**D1.** Authority class, lifecycle status and mutability are **three independent axes**. Every classified artifact carries one value on each. A document may be, simultaneously, `INTERNAL-NORMATIVE` + `PARTIALLY-SUPERSEDED` + `FROZEN` — as [[DEC-0028]] is.

**`SUPERSEDED` and `PARTIALLY-SUPERSEDED` are lifecycle values, never authority classes.** Any statement of the form *"this document's authority class is superseded"* is malformed under this model and must be rewritten as a lifecycle assertion naming the superseding instrument and the superseded scope.

### 3.1 Axis A — authority class (minimum five)

| Token | Meaning | May bind a current decision? |
|---|---|---|
| **INTERNAL-NORMATIVE** | NOXUND-created durable authority that binds current decisions **within its declared scope**: ACTIVE decision records; agent contracts within their declared agent-behaviour scope; other explicitly-ratified normative surfaces. | Yes, within declared scope. |
| **EXTERNAL-CONSTRAINT** | Externally-created constraint NOXUND must respect but does not author and cannot internally repeal — provider/platform policy, applicable external rules, vendor terms. An internal record may **interpret** or **respond to** one; it cannot make it cease to exist. Represented here semantically only. | Yes, as a boundary on internal decisions. |
| **DESCRIPTIVE-CURRENT** | A statement of current repository or system state, safe to route from. Creates **no** authority. Phase closeouts and current-state material sit here. | No. |
| **EVIDENCE** | Proof or report of what happened or was observed: security reviews, handoffs, closeouts, audit results, run evidence, preserved refs. | No. |
| **NON-AUTHORITATIVE** | Assists reasoning, never binds: agent memory, session summaries, brainstorming, drafts (unless separately ratified). | No. |

**Imperative wording inside an EVIDENCE artifact creates no standing obligation.** A review that writes *"this must be fixed before apply"* records a finding, not a rule. The obligation exists only where an INTERNAL-NORMATIVE surface grants it, and that grant is separate from the evidence document that exercises it. The `SEC-0001` §0 Fase 9 veto is the corpus example: the veto **power** is granted by `docs/agents/agent-conflict-resolution.md` (*"Bloqueio de segurança não é 'voto' — é veto até mitigação"*), which `SEC-0001`'s own header cites as its authority (*"veto — `agent-conflict-resolution.md`, matriz #3"*); [[DEC-0028]] §10 and [[DEC-0031]] carry it forward as standing; [[DEC-0034]] §7 leaves it **untouched**. Untouched presupposes standing force — it does not confer it.

### 3.2 Axis B — lifecycle status

| Token | Meaning |
|---|---|
| **CURRENT** | In force. No later instrument has superseded it in whole or in relevant part. |
| **SUPERSEDED** | Wholly replaced by a named later instrument. Retains its authority class and its historical value; binds nothing prospectively. |
| **PARTIALLY-SUPERSEDED** | Named clauses replaced, narrowed or discharged; the remainder stays CURRENT. The superseded scope must be stated at clause granularity. |
| **HISTORICAL** | Never landed as current authority, or deliberately retained as record only. Citable by exact provenance; never routed from. |
| **DRAFT / PROPOSED** | Authored but not ratified. Carries the authority class it *would* carry on ratification, and binds nothing until ratified. |

### 3.3 Axis C — mutability

| Token | Meaning |
|---|---|
| **EDITABLE** | May be revised in place by an authorized unit. |
| **FROZEN** | The body is immutable and is never rewritten. A clearly-marked **additive** forward-status note may be appended by an authorized unit. This is the corpus default for landed decision and security records, per [[DEC-0022]] §4 and [[DEC-0023]] §D-F. |
| **FROZEN (byte-frozen)** | A strict grade of FROZEN admitting **no in-file change of any kind**, additive notes included. Applies where a landed record declares it — [[DEC-0028]] and [[DEC-0033]] per [[DEC-0034]] §4. |

**Consequence (binding).** Byte-frozen authority stays immutable even once superseded. Its lifecycle and supersession information therefore **must** live in an **external forward-reference mechanism**, not in the file. Until that mechanism exists (§9), such edges live only in the superseding record's own supersession table.

---

## 4. Precedence

**Implicit latest-wins is REJECTED.** A later date, a higher record number and a newer commit are all irrelevant to precedence on their own. The following order is binding.

**P1 — EXPLICIT SUPERSESSION GOVERNS.** Where an INTERNAL-NORMATIVE artifact explicitly supersedes, discharges, narrows or extends another **within a stated scope**, that explicit relationship governs that scope. Outside the stated scope the earlier instrument is undisturbed.

**P2 — NO SILENT SUPERSESSION.** Chronology alone supersedes nothing. Absent an explicit edge, two records both remain in force and must be reconciled on their merits, not by age.

**P3 — UNRESOLVED NORMATIVE CONFLICT.** Where two **CURRENT INTERNAL-NORMATIVE** authorities genuinely conflict and no explicit supersession, discharge or precedence edge exists, the agent returns **`HOLD — AUTHORITY-CONFLICT`**, states both readings, and escalates to the Product Lead. **The winner is never inferred** — not from date, not from number, not from specificity, not from tone.

**P4 — CROSS-CLASS PRECEDENCE.** EVIDENCE proves facts but **cannot create standing authority through imperative language**. NON-AUTHORITATIVE **never participates** in normative precedence at all.

INTERNAL-NORMATIVE states what NOXUND requires, authorizes, prohibits or constrains within its declared scope. DESCRIPTIVE-CURRENT states what is factually true now. **DESCRIPTIVE-CURRENT can never supersede, repeal or relax INTERNAL-NORMATIVE** — reality does not amend a rule by diverging from it.

**But a disagreement between the two does not, by itself, determine which statement is defective.** That depends on which one the evidence supports, and there are two distinct, named outcomes:

- **STATE-AUTHORITY DIVERGENCE** — the descriptive statement is accurate, and actual repository or system state is **not compliant** with applicable normative authority. The normative requirement remains binding. The descriptive observation remains factual. **The descriptive statement must not be rewritten to agree with authority.** The divergence is surfaced and routed to HOLD, escalation or remediation according to the owning process.
- **STALE-DESCRIPTIVE DEFECT** — the descriptive artifact is itself outdated or factually wrong. Here the descriptive surface is repaired.

**Reality is never falsified to conform to authority.** Where normative authority requires a workflow to remain disarmed and the observed state is that it is armed, the observation stands as fact, the requirement stands as binding, and the gap is a **STATE-AUTHORITY DIVERGENCE** to be escalated — never a documentation error to be edited away.

Neither outcome is a P3 conflict: **P3 is reserved for two CURRENT INTERNAL-NORMATIVE authorities.** How a divergence is detected, tracked or gated is **Phase C** and is not defined here (§12).

**P5 — EXTERNAL BOUNDARY.** An INTERNAL-NORMATIVE decision must operate **within** applicable EXTERNAL-CONSTRAINTS. Internal authority determines NOXUND's response to an external constraint; it does not supersede the external source. An internal record that appears to grant what an external constraint forbids is a P3-class escalation to the Product Lead, never a self-executed override.

---

## 5. Memory ruling (binding)

**Persistent and session agent memory is `NON-AUTHORITATIVE CONTEXT`.**

It **may** assist recall, orientation and routing. It **may not**: create durable authority; supersede repository authority; override repository current state; or create obligations through imperative wording, including routing lines phrased as commands.

**On any conflict between memory and the canonical repository, the repository wins** — its landed authority for normative questions, its current state for factual ones. An agent that finds memory contradicting `main` reports the divergence and proceeds from `main`.

**This record does not modify, repair, correct or re-write memory content.** Memory hygiene is not in scope here, and no unit is authorized by this record to perform it.

---

## 6. Product-Lead GO versus durable authority

These are **distinct instruments** and must not be substituted for one another.

An explicit **Product-Lead GO** authorizes the **currently-scoped execution unit**. It is an execution permission with the scope it names, and it expires with that unit.

A **GO does not automatically rewrite, supersede or discharge durable landed authority.** Where a change to durable authority is required, the durable-authority mechanism must **also** be satisfied — the landed record, with its explicit supersession scope, as [[DEC-0034]] did for [[DEC-0033]] §5 and as [[DEC-0033]] §10 *Change control* required.

The existing rule is preserved unchanged: **`NEXT` / `READY` / `RECOMMENDED` is not execution authorization.** A routing label describes sequence, never permission.

---

## 7. New-artifact rule — fail closed

From this record's date, **a new context or governance artifact that can carry classification metadata must declare its authority class** in its header block.

**If the declaration is absent, the artifact fails closed as `NON-AUTHORITATIVE` until it is classified.** It binds nothing in the interim. Classification is a repair, not a promotion: classifying an artifact records the class it was authored to carry; it does not confer authority the authoring unit lacked.

This rule is **documentary in V2**. No mechanical validation, lint, hook or CI check is created here (§12).

---

## 8. Legacy-corpus rule — non-retroactive

**The §7 fail-closed rule is prospective only. `Unclassified = NON-AUTHORITATIVE` must NOT be applied retroactively to the existing corpus.** Doing so would silently strip standing from landed authority whose only defect is that its format predates this model — which is precisely the failure this record exists to prevent.

Legacy artifacts acquire status through exactly four routes:

1. **family-default classification** (§9);
2. **explicit per-file override**, recorded by an authorized unit;
3. **existing landed authority** — anything a landed record already declares keeps that declaration, ahead of any default;
4. the **future B3 index and supersession table**, once it exists.

**No legacy artifact loses standing merely because it carries no V2 header.** Where a family default and existing landed authority disagree, landed authority governs and the default yields.

---

## 9. Family defaults

Defaults, not adjudications. A default is the starting classification for an unclassified member of the family; it is overridden by any of §8's routes 2–4. **Mixed families take the conservative default with named exceptions**, never a blanket promotion.

| Family | Default class | Typical lifecycle | Typical mutability | Named exceptions |
|---|---|---|---|---|
| `docs/product/decisions/**` | INTERNAL-NORMATIVE | CURRENT unless explicitly superseded | FROZEN | [[DEC-0028]] and [[DEC-0033]] — *mutability:* **byte-frozen**; *lifecycle:* **PARTIALLY-SUPERSEDED**, per [[DEC-0034]] §4. [[DEC-0005]] and [[DEC-0021]] — *lifecycle:* **SUPERSEDED** by [[DEC-0028]]. **[[DEC-0001]] — *lifecycle:* `DRAFT / PROPOSED`** (*"Status: Proposta (aguarda confirmação do Product Lead)"*; the Product Lead checkbox is unticked and its follow-up still says *"Após confirmado, mudar status para Aprovada"*), so it binds nothing under §3.2 despite 34 records of de facto practice. **[[DEC-0003]] — *lifecycle:* mixed at clause level**, per §9.1's discipline: its ratified items (`OD-DB-01`/`04`/`06`/`07`, ratified by Data/AI) are **CURRENT**; its items conditioned on Security and Backend are **DRAFT / PROPOSED** until those reviews land. Its *"Aprovada (parcial)"* status is **not** `PARTIALLY-SUPERSEDED` — nothing superseded it; part of it was never ratified. The family default of CURRENT + INTERNAL-NORMATIVE therefore does **not** apply unqualified to these two — a worked instance of §8 route 3, where an artifact's own landed declaration overrides the family default. `DEC-0024-ADDENDUM-migration-ordering-policy.md` is a normative addendum to its base record, not an independent decision. |
| `context/**` | **No blanket class.** Authority is exactly what `docs/agents/product-orchestrator-agent.md` §*Source of Truth* grants to the files its table names, in the hierarchy it states: decision log → PRD → methodology/DB → stack/GTM/execution/risks → architecture/strategy. Named files carry INTERNAL-NORMATIVE weight **for their unsuperseded clauses only**; descriptive and strategic material in the same files is DESCRIPTIVE-CURRENT or NON-AUTHORITATIVE. See the reading note below the table. | Mixed at clause level | EDITABLE | `02_Stack_Infra_Architecture.md` — Supabase stack portions carry a landed Phase-A supersession note pointing at [[DEC-0034]]; those clauses are *lifecycle:* **SUPERSEDED**. `00_Product_Lead_Decision_Log.md` §12 — carries a landed supersession note pointing at [[DEC-0028]] and [[DEC-0034]]; that section is *lifecycle:* **SUPERSEDED**. `Relatório Estratégico de Posicionamento — NOXUND.md` — *class:* **NON-AUTHORITATIVE** strategic context; expressly cannot reopen locked scope. `README.md` — package cover and reading order; *class:* **DESCRIPTIVE-CURRENT**, treated as the package entry point by `context-index.md` §1, which also records that its *"Fonte de verdade do pacote"* list names external files absent from this repository. `Head of Product.md` — empty file; *class:* **NON-AUTHORITATIVE**. |
| `docs/product/*.md` (non-decision) | DESCRIPTIVE-CURRENT | Mixed; several are stale | EDITABLE | `scope-guardrails.md` carries derived scope-admission weight only to the extent the §*Source of Truth* hierarchy grants it, and is the origin of the inherited `OD-02` / `OD-03` / `OD-04` labels per `docs/database/mvp-data-model.md`; its class requires explicit B3 adjudication. |
| `docs/security/**` (`SEC-*`) | EVIDENCE | CURRENT as record | FROZEN | `SEC-0001` §0 — the Fase 9 veto binds by the grant in `docs/agents/agent-conflict-resolution.md`, carried forward as standing by [[DEC-0028]] §10 and [[DEC-0031]] and left untouched by [[DEC-0034]] §7 — **not** by virtue of being written in a SEC file (§3.1). `SEC-0027` is the canonical seat of the Phase-2 verify-parity correction per [[DEC-0031]]. |
| `HANDOFF-*` (across `docs/database/`, `docs/infra/`, `docs/data/`, `docs/backend/`, `docs/agents/handoffs/`) | EVIDENCE | CURRENT as record; operationally HISTORICAL | FROZEN | None. Imperative "next steps" inside a handoff bind nothing (§3.1). `docs/agents/handoff-template.md` is not a handoff — *class:* **DESCRIPTIVE-CURRENT**, a format aid. |
| `DATA-*` and pipeline specs (`docs/data/**`) | EVIDENCE | Mixed at clause level | FROZEN | See §9.1. |
| `docs/agents/**` | Mixed — **agent contracts** (`*-agent.md`) are INTERNAL-NORMATIVE **within their declared agent-behaviour scope**; the cross-agent governance set (`agent-registry.md`, `global-agent-rules.md`, `agent-boundaries.md`, `agent-review-matrix.md`, `agent-conflict-resolution.md`) is INTERNAL-NORMATIVE for agent behaviour | CURRENT | EDITABLE | **`README.md` is MIXED at clause level, not a blanket descriptive surface** — *class:* **INTERNAL-NORMATIVE** for its §*Regras gerais para todos os agentes* (six numbered rules: locked scope, deterministic numbers, raw is sacred, traceability, cross-review, escalation) and for its §*Como adicionar um novo agente*, which declares itself a *"Modelo **vinculante** registry-first"* and closes with the rule that a newly created agent may not execute the dependent task during its own provisioning gate; *class:* **DESCRIPTIVE-CURRENT** for its file catalogue and its three-state operational-status sections. `orchestration-runtime.md` — *class:* **DESCRIPTIVE-CURRENT** throughout; an implementation-state surface, not a normative grant (§11). `governance-integrity-agent.md` and `orchestration-runtime-engineering-agent.md` — *lifecycle:* **DRAFT / PROPOSED**, `PROPOSED-NOT-OPERATIONAL` / `RUNTIME-NOT-WIRED`; they bind nothing. `agent-onboarding-orchestration.md` — *class:* **DESCRIPTIVE-CURRENT**. |
| `docs/database/**`, `docs/infra/**`, `docs/backend/**` (non-`HANDOFF`) | EVIDENCE | Mixed | FROZEN | `SUPABASE-LEGACY-STRUCTURAL-BRIEF-R0.md` — landed *class:* **EVIDENCE**, relied on by [[DEC-0034]]. `migration-plan.md`, `mvp-data-model.md` and `RUNBOOK-channel-data-collection.md` — design and runbook surfaces whose Supabase-era clauses are *lifecycle:* **SUPERSEDED** by [[DEC-0028]] / [[DEC-0034]]. |
| `docs/result/**` | DESCRIPTIVE-CURRENT (phase closeouts) | CURRENT | FROZEN | `PHASE-A-CLOSEOUT-R1.md` — the only member on this base — self-declares *"This is not a decision record"*: *class:* **DESCRIPTIVE-CURRENT**, safe to route from, establishes no authority. **Anticipatory:** should this family later carry run or gate outputs, those take *class:* **EVIDENCE**; no such member exists yet and none is assumed. |
| `docs/foundation/**` | DESCRIPTIVE-CURRENT | CURRENT | EDITABLE | None. |
| Memory and session context | NON-AUTHORITATIVE | n/a | n/a | None (§5). |
| Preserved Git evidence — `checkpoint/*`, `spike/*`, `wip/*` refs, the stash entry, the external preservation repository | EVIDENCE | HISTORICAL | FROZEN | **Preservation is not adoption.** A preserved ref is citable by exact SHA and is never routed from as current state. |

**Reading note on `context/**` (flagged for B3, not narrowed here).** `docs/agents/product-orchestrator-agent.md`:128 states blanket that *"Os documentos em `/context` são a fonte da verdade"*, while the table immediately below it names ten specific files and assigns each a distinct use and rank. **This record reads the named table as the operative grant**, because the blanket sentence assigns no scope, no rank and no conflict rule, whereas the table does — and §3.1 requires INTERNAL-NORMATIVE authority to have a declared scope. That reading is a **classification judgment, not a supersession**: the blanket sentence is not edited, narrowed or declared wrong, and the residual ambiguity is routed to **B3** for adjudication.

Executable surfaces — `packages/**`, `apps/**`, `services/**`, `supabase/**`, `.github/**` — are **outside** this classification model. V2 classifies context and governance artifacts. Code authority is settled by the decision records that govern it.

### 9.1 `DATA-*` — clause-level normativity (binding clarification)

Several `DATA-*` files carry, in one document, both durable constants incorporated by DEC authority — rubric weights and `score_rubric_2026_06_v1`, `rule_hash`, the `channel-filter-v1` rules ratified across [[DEC-0017]], [[DEC-0019]], [[DEC-0022]] and [[DEC-0023]] — **and** historical operational narrative.

The binding rule:

> **A ratified clause is normative by virtue of the decision record that ratified it, and only within the scope that record states. The containing file's default remains EVIDENCE.**

A whole file is therefore **never** promoted to INTERNAL-NORMATIVE because one of its clauses was ratified elsewhere. When citing a constant, cite the ratifying decision record; the `DATA-*` file is the design source and the evidence of derivation, not the authority. Where the file and the ratifying record diverge, the record governs and the divergence is a defect in the file.

---

## 10. Forward-supersession semantics — rule only

**For EDITABLE artifacts.** A short forward supersession/status pointer — naming the superseding instrument and the superseded scope — may be added by a later **bounded reconciliation unit (B5)**. It is an additive marker, never a rewrite of the described position.

**For FROZEN artifacts.** The body is never edited to record supersession. Where the FROZEN grade permits it, an authorized unit may append a clearly-marked additive note. Where the artifact is **byte-frozen**, no in-file change is permitted at any grade, and the forward edge exists **only externally** — eventually in **B3**'s index and supersession mechanism, and until then only inside the superseding record's own supersession table.

**Normative rule going forward.** Every future normative artifact that supersedes, discharges, narrows or extends earlier authority **must create the forward-discoverability update in the same authorized unit that creates the supersession** — an additive pointer where permitted, an external table entry where not. Supersession that is discoverable only by reading the superseding record is an incomplete unit.

**B1 defines this rule and applies no pointers.** No forward marker, banner or table entry is created by this record.

---

## 11. Worked example — the agent-runtime status case

A fresh agent reading `main` encounters an apparent contradiction:

- `docs/agents/orchestration-runtime.md` opens with `**Status:** implementado (fundação executável)` and presents a 10-agent contract-to-runtime-id mapping as operational fact.
- `docs/agents/README.md` states the accurate three-state model — **FORMAL CONTRACT** / **FOUNDATION RUNTIME HANDLER** / **REAL PRODUCT EXECUTOR** — records that the 10 preexisting agents hold the first two, that **no REAL PRODUCT EXECUTOR exists**, and that Governance & Integrity and Orchestration Runtime Engineering are `PROPOSED-NOT-OPERATIONAL` / `RUNTIME-NOT-WIRED`.
- [[DEC-0032]] §8 places `packages/orchestrator/**` under **DEFER-PHASE-C**.

**Resolution under this model.**

1. **Classify at clause level, not file level.** Neither file is an agent contract, and `README.md` is not uniformly descriptive — per §9 it is MIXED, carrying INTERNAL-NORMATIVE clauses in its *Regras gerais* and its vinculante registry-first provisioning model. **The two clauses actually in tension here are not those.** The `README.md` clause in play is its three-state operational statement — a claim about how far the runtime is built: *class:* **DESCRIPTIVE-CURRENT**. The `orchestration-runtime.md` clause in play is its `**Status:** implementado` line — the same kind of claim: *class:* **DESCRIPTIVE-CURRENT**. Classifying at file level would have obscured this; classifying at clause level is what makes the case resolvable, and it is the same discipline §9.1 applies to `DATA-*`. Neither clause confers a capability on any agent.
2. **Apply P4.** DESCRIPTIVE-CURRENT creates no authority. The disagreement is about **how operational the runtime is**, a question of fact, not about any rule. It is therefore **not a normative conflict**, and P3 does not engage. Of P4's two outcomes this is the **STALE-DESCRIPTIVE DEFECT** branch, not a **STATE-AUTHORITY DIVERGENCE**: the `Status: implementado` line is genuinely outdated, not an accurate report of state failing a normative requirement. Note what is *not* in tension: `README.md`'s INTERNAL-NORMATIVE clauses — the *Regras gerais* and the vinculante registry-first provisioning gate — are untouched by this case and remain fully binding.
3. **Locate the governing surface.** The INTERNAL-NORMATIVE instrument that actually governs the disposition of `packages/orchestrator` is [[DEC-0032]] §8: **DEFER-PHASE-C**. That answers the question a fresh agent actually needs answered.
4. **Outcome.** Resolved by class, at clause granularity. **No `HOLD — AUTHORITY-CONFLICT` is required.** The residual defect is a single stale DESCRIPTIVE-CURRENT status line in `docs/agents/orchestration-runtime.md`, routed to **B5** as a documentation repair. **Neither file is edited by this record.**

**What the model deliberately did not do.** It did not pick the newer file. It did not prefer the more confident tone. It did not read `**Status:** implementado` as a grant merely because it is phrased as a fact. Had both surfaces genuinely been INTERNAL-NORMATIVE with no explicit edge between them, the required output would have been **`HOLD — AUTHORITY-CONFLICT` and escalation under P3** — never *"newest wins"*.

---

## 12. Phase-C boundary

This record does **not**: wire `governance_integrity_agent` (which remains `PROPOSED-NOT-OPERATIONAL` / `RUNTIME-NOT-WIRED`); modify `packages/orchestrator` (which remains **DEFER-PHASE-C** per [[DEC-0032]] §8); ratify Agent Governance V2; define `AgentResult` V2; create a risk engine, capability matrix or reviewer-count policy; or provide **any mechanical enforcement** of §7.

**The classification rule is documentary in V2.** Any validator, lint, hook, schema or CI gate that enforces it belongs to **Phase C** and requires its own authorization.

---

## 13. Explicit non-decisions

This record does **not** and must not be read to: rewrite any historical artifact · change current product scope · resolve the PostgreSQL successor architecture · resolve any open decision (`OD-*`) · modify Supabase history · modify any workflow · modify any code · modify the agent runtime · implement task packs · implement the context index · implement current-state V2 · apply any supersession banner or status marker · repair memory content · authorize B3 · authorize B5 · authorize any commit, push, PR or merge.

---

## 14. Execution topology under which this record was produced

This record was authored under a **temporary Phase-B execution topology**: a task-scoped Author, a distinct task-scoped independent Reviewer, and manual Product-Lead merge.

That topology is a **temporary Phase-B exception**. It **wires no agent**, registers no agent, ratifies no permanent topology, and creates no standing permission. The vinculante registry-first provisioning model in `docs/agents/README.md` — INTERNAL-NORMATIVE per §9 — is **undisturbed and still binding**; no step of its nine-step gate is waived, shortened or deemed satisfied by this record. Nothing here permits an author to review or accept their own work.

---

## Annex A — B5 reconciliation targets (NON-NORMATIVE PLANNING OUTPUT)

**This annex is a planning output. It is NOT normative, it is NOT authorization to execute B5, and it creates NO obligation to edit any file listed below.** It exists to give B5 a finite scope so that unit is not framed as a repository-wide sweep. B5 requires its own explicit Product-Lead GO, and may add to or prune this list on the evidence available to it.

**Selection criterion used.** A record was included only where all three hold: (a) the artifact is reachable by a fresh agent through a documented route — the decision log, the §*Source of Truth* hierarchy, `context-index.md`, or `docs/agents/README.md`; (b) it asserts something a fresh agent could act on that landed authority has since changed; and (c) the defect is a **missing forward edge or a stale descriptive claim**, not a substantive re-decision. Anything requiring a new decision was excluded.

| # | Target | Defect | Route |
|---|---|---|---|
| 1 | `DEC-0005-auth-provider-supabase.md` | Status reads *"Aprovada — confirmada pelo Product Lead"*; superseded by [[DEC-0028]]; contains **zero** forward references to it. | Additive forward note (FROZEN, not byte-frozen) or B3 table entry. |
| 2 | `DEC-0021-ro1-supabase-auto-pause-mitigation.md` | RO-1 mitigation superseded by [[DEC-0028]]; **zero** forward references. | As above. |
| 3 | `DEC-0009-phase3-apply-completed.md` and `DEC-0010-phase2-apply-completed.md` | The phase-3/phase-2 numbering-identity anomaly reconciled by [[DEC-0031]]; both contain **zero** forward references to it. [[DEC-0031]] expressly states it alters neither file. | **B3 external table only** — B5 must not edit either file. |
| 4 | [[DEC-0028]] §9 plan ordering and §10 *Security & Privacy* binding condition | Narrowed / discharged by [[DEC-0033]] and [[DEC-0034]]. Record is **byte-frozen**. | **B3 external table only.** Never into the file. |
| 5 | [[DEC-0033]] §5 and §6 (final paragraph) | Superseded for the legacy Supabase retirement path by [[DEC-0034]] §4. Record is **byte-frozen**. | **B3 external table only.** |
| 6 | `docs/product/product-operating-system.md` | Stale operational narrative (Sprint 0–3; *"configurar Supabase/Vercel"*) plus an inline `OPEN DECISION` on where decisions live. That question is `OD-06`, which **remains formally open** (row 9). No status marker. | Forward status marker on the stale Supabase/Vercel narrative (EDITABLE). **Do not close `OD-06`.** |
| 7 | `docs/product/mvp-backlog.md` (~22.8 KB) | Same class: Supabase-era operational content, no status marker. | Forward status marker. |
| 8 | `docs/agents/orchestration-runtime.md` | Stale DESCRIPTIVE-CURRENT status line — the §11 case. | Status-line correction. |
| 9 | `docs/product/decision-log-template.md` | Carries an inline `OPEN DECISION (OD-06)` on where decisions are recorded. **`OD-06` is genuinely OPEN**: [[DEC-0001]] §4 *proposed* `docs/product/decisions/<id>.md` but is itself `DRAFT / PROPOSED` (§9), and `docs/product/scope-guardrails.md` still records `OD-06` as *"Proposto … (DEC-0001) · Confirmar com Product Lead."* Practice has followed the proposal for 34 records; **no ratification landed.** The label also collides by name with [[DEC-0028]] §8's still-open `OD-6` (future authentication provider). | Record the accurate open/proposed status and the de facto practice; **do not close `OD-06`** and **do not renumber** either identifier. **Closing `OD-06` requires a Product-Lead decision and is expressly outside B5's remit.** |
| 10 | `docs/product/context-index.md` | Self-declares *"vivo (atualizar sempre que `/context` mudar)"*; indexes only the 12 `context/` entries; silent about the 169 markdown artifacts under `docs/**` (count inclusive of this record). | Scope statement; full index is **B3**, not B5. |
| 11 | `context/**` forward markers | 10 of 12 files carry no forward status marker. `00_Product_Lead_Decision_Log.md` and `02_Stack_Infra_Architecture.md` already carry landed Phase-A additive notes. | Prioritise the files named in the §*Source of Truth* hierarchy. |
| 12 | `docs/product/scope-guardrails.md` | Class ambiguous under §9; origin of the inherited `OD-02` / `OD-03` / `OD-04` labels. | Classification adjudication (**B3**), not an edit. |

**Discovered defect — routed, not solved here.** The `OD-*` identifier space has collided across independent namespaces: `OD-2` (open, [[DEC-0028]] §8) versus `OD-02` (closed by [[DEC-0005]]); `OD-5` (closed by [[DEC-0029]]) versus `OD-05` (`docs/foundation/monorepo-structure.md`, FastAPI in Fase 2); `OD-6` (open, [[DEC-0028]] §8) versus `OD-06` (**also open**, per row 9); plus the independent `OD-A`…`OD-E`, `OD-DB-01`…`OD-DB-08`, `OD-PROV-02`, `OD-V1` and `OD-V2` series. [[DEC-0032]] §6 binds non-conflation for **one pair only** — the historical `DEC-0027` §4 `OD-N` labels versus [[DEC-0028]] §8's `OD-N` — and names [[DEC-0028]] §8 as the current namespace where applicable; it does **not** bind a general cross-series rule covering the others listed here. **This record neither fixes, closes nor renumbers any of them**; disambiguation is a **B3** indexing problem.

---

*Related: [[DEC-0032]] §8 (Canonical Context V2 routed to Phase B), [[DEC-0032]] §6 (`OD-N` separation, two namespaces only), [[DEC-0022]] §4 and [[DEC-0023]] §D-F (additive-only doctrine), [[DEC-0031]] (additive authority reconciliation precedent), [[DEC-0033]] §8 (unlanded-identifier convention; nothing re-arms) and §10 (change control), [[DEC-0034]] §4 (byte-frozen supersession scoping) and §7 (Phase-A boundary). Predecessor unit — unlanded, no file path: `PHASE-B-B0-CANONICAL-CONTEXT-V2-FOUNDATION-ASSESSMENT-R1`.*
