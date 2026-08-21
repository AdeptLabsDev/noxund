# DEC-0037 — Execution topology: role independence and the governance-review function

**Status:** ACTIVE (binding) · **Date:** 2026-08-21 · **Decision authority:** Product Lead
**Authority class:** INTERNAL-NORMATIVE · **Lifecycle:** ACTIVE / CURRENT · **Mutability:** FROZEN — the `docs/product/decisions/**` family default ([[DEC-0035]] §9), declared here under the fail-closed rule ([[DEC-0035]] §7).
**Drafted by:** a task-scoped Author, reviewed by a **distinct** task-scoped independent governance reviewer, under the Product-Orchestrator-coordinated topology authorized by the Product Lead's `C1` GO. That GO — **not** [[DEC-0035]] §14, which scoped itself to Phase B — is what carried the topology into this unit. **Ratification gate:** the Product Lead's manual merge of this record.
**Scope:** The permanent execution topology for governed NOXUND work — **HYBRID · PROCESS-FIRST · RUNTIME-AGNOSTIC**. It fixes the actor taxonomy, the minimum topology per risk class, what reviewer independence means in checkable terms, what a task-scoped role is and is not, and how a mandatory review function is satisfied when the agent identity a landed clause names is not operational. **Docs-only unit.**
**Negative scope — this record does not create or change:** any agent registration, activation, contract, boundary, runtime handler, runtime allow-list or runtime wiring · `packages/orchestrator/**` in any respect, including its disposition · any preserved ref, branch, stash or archive · any workflow, workflow registration, ruleset, branch protection, `CODEOWNERS` file, CI check, validator, lint or hook · any Environment, secret, variable, credential or remote connection · any database, SQL, migration, role or runner · any code file · any product scope, MVP admission, `OD-*` item or Axis-1 technical question · any capability matrix or `AgentResult` schema · any **mechanical** reviewer-count enforcement — see the note on §12 below · memory content. **No agent is wired, no agent is registered, and no execution of any kind is authorized.**
**Extends:** [[DEC-0035]] §12 — supplying the **execution-topology limb only** of the Phase-C work that clause reserved. **Stated plainly rather than by altered phrasing: §12 reserved a *reviewer-count policy*, and §D5 and §D13 supply exactly that policy.** What §12 reserved and this record does **not** supply is the capability matrix, `AgentResult` V2, the risk engine, and **any mechanical enforcement** — all of which stay Phase-C work under their own authorization (§9) — and [[DEC-0035]] §14, which recorded a temporary topology and expressly ratified no permanent one. [[DEC-0035]] is neither edited nor narrowed and remains **CURRENT**.
**Narrows:** `docs/agents/agent-review-matrix.md` item **#12**, at one exact point: the mandatory reviewer is the **independent governance-review function**, not the operational existence of the `governance_integrity_agent` identity. The independence requirement itself is untouched and, in §D9, reinforced. **No other clause of that file, and no other agent identity, is narrowed, extended or reinterpreted here.**
**Does not edit:** any prior DEC. [[DEC-0001]] … [[DEC-0036]] all remain **frozen and additive-only**; [[DEC-0028]] and [[DEC-0033]] remain **byte-frozen** per [[DEC-0034]] §4. No prior record is declared obsolete, superseded, reopened or reinterpreted. No agent contract is edited.
**Predecessor unit:** `PHASE-C-C0-AGENT-GOVERNANCE-V2-FOUNDATION-ASSESSMENT-R1` — an **unlanded in-session assessment**, defined by no canonical record on `main` and having no file path; following [[DEC-0033]] §8 it is named for provenance only and confers no standing. **Its historical disposition is `RED — VERIFIED AUTHORIZATION BREACH`** (unauthorized scratch-file creation; failure to stop on recognition; unauthorized self-remediation by deletion; failure to preserve available evidence; original self-certification as PASS despite the verified breach), blast radius **`LOW · ZERO REPOSITORY IMPACT · ZERO PERSISTENCE · SELF-DISCLOSED`** — **blast radius does not alter the classification**. The follow-on unit `PHASE-C-C0-POSTHOC-GOVERNANCE-REPAIR-R1` returned **PASS** and corrected the record, and the Product Lead adjudicated the governance finding **`CLOSED — REMEDIATED`**, expressly ruling that **the historical RED must not be rewritten to PASS** — `product-orchestrator-agent.md`:599, and :598 for a technically-accepted artifact carrying a historical governance finding under explicit Product-Lead acceptance. C0's substantive assessment evidence was preserved as usable **except one withdrawn claim** (§D12). **Every repository claim below was independently re-derived at the canonical base**; the two GitHub-configuration claims in §D12 were not, and are marked `REPORTED` there.
**Evidence base — re-derived at the canonical base:** `docs/agents/product-orchestrator-agent.md` §*Operating Protocol* (incl. the `ORCHESTRATOR ≠ AUTHOR` block), §*Authority*, §*Agent Interaction Model* (Papéis operacionais · Topologia mínima por risco · Independência contextual · Trust model · Falha de delegação), **§*Task Decomposition Contract* / *Regras de atribuição* — specifically :562, :563 and :565, the separation-of-duties clauses engaged in §D5** — §*Evidence, Provenance & Review Rules* (incl. :598 and :599 on historical findings), §*Operational Invariants Summary*; `docs/agents/README.md` §*Modelo de estado operacional*, §*Regras gerais*, §*Como adicionar um novo agente*; `docs/agents/agent-review-matrix.md` items #11–#13, both *Bootstrap* sections, §*Fluxo de aplicação*; `docs/agents/governance-integrity-agent.md` header (runtime wiring **DEFERIDO**; *identidade de contrato ≠ registro de runtime*); `docs/agents/devops-infra-agent.md`:14, :18 and `agent-boundaries.md`:202–208, :338–347 (`apply_exact_remediation`); `docs/agents/agent-onboarding-orchestration.md` §9 and `orchestration-runtime.md` — **neither names `apply_exact_remediation`**; `packages/orchestrator/**` — `@noxund/orchestrator` appears in **no** file outside its own package and in **no** workflow; the absence of any `CODEOWNERS` file anywhere in the tree; [[DEC-0032]] §8; [[DEC-0035]] §3.1, §3.2, §4 P3/P4, §6, §7, §9, §10, §11, §12, §14; [[DEC-0036]] §4 (adjudication without supersession); `current-state.md` §B, §E, §F; `context-map.md` §1–§3; `PHASE-B-CLOSEOUT-R1` §4, §5.
**Canonical base:** `main` @ `aff75d51ac40348fae041fe068953dc3dd288d38`

---

## 1. Status

**ACTIVE — binding and prospective**, effective on the Product Lead's manual merge (§10). It establishes a process topology. It registers no agent, wires no runtime, grants no execution permission, and authorizes no unit.

---

## 2. The problem

Governed work is being produced now, and the corpus does not say who may legitimately produce it.

The landed topology is written in terms of **registered agent identities** — `governance_integrity_agent`, `security_agent`, `devops_agent` — and the repository establishes that **no registered NOXUND agent is a REAL PRODUCT EXECUTOR** (`docs/agents/README.md`). Two of the named identities are `PROPOSED-NOT-OPERATIONAL / RUNTIME-NOT-WIRED` and bind nothing ([[DEC-0035]] §9). `@noxund/orchestrator` is landed and executable but reaches nothing: it is imported by no file outside its own package and referenced by no workflow, and its disposition is **DEFER-PHASE-C** ([[DEC-0032]] §8).

So the corpus contains a live gap of exactly one shape. `agent-review-matrix.md` is CURRENT INTERNAL-NORMATIVE, and its item **#12** makes the `governance_integrity_agent` a **mandatory reviewer** for any governance-sensitive artifact — including this one. Under [[DEC-0035]] §4 **P4** that is a **STATE-AUTHORITY DIVERGENCE**, not a P3 authority conflict: the descriptive fact (the identity is not operational) is **accurate and is not edited away**, and the normative requirement stays binding. Under P4 the only legitimate repairs are at the authority end, by decision — never by falsifying the fact, and never by quietly omitting the reviewer.

**Two failure modes are therefore already available to a fresh operator**, and this record closes both. The first is *deadlock*: reading #12 as unsatisfiable and concluding that no governance-sensitive work may proceed. The second is *drift*: satisfying #12 with an Author self-check, or with a reviewer labelled as the registered agent it is not.

The corpus already refuses both, in its own words. `agent-review-matrix.md`'s two **Bootstrap** sections face precisely this shape — a mandatory reviewer that cannot be the one named — and resolve it by naming **other** parties to carry the independent-review functions, with self-review *"explicitamente **não permitido**"*. That is the discipline this record generalizes, from *self-review deadlock* to *identity-not-operational*. It is not a new architecture.

---

## 3. Capability reality at this base

Stated as fact, and not editable by preference.

- **12 formal agent contracts exist. Zero registered NOXUND agents are REAL PRODUCT EXECUTORS.** The 10 preexisting agents hold FORMAL CONTRACT + FOUNDATION RUNTIME HANDLER, which validates an action and returns a plan or handoff and does **no** product work (`docs/agents/README.md`).
- `governance_integrity_agent` and `orchestration_runtime_engineering_agent` are `DRAFT / PROPOSED` ([[DEC-0035]] §9), state `PROPOSED-NOT-OPERATIONAL / RUNTIME-NOT-WIRED`. **They bind nothing.** The `governance-integrity-agent.md` header states it itself: *identidade de contrato ≠ registro de runtime*.
- The DevOps capability `apply_exact_remediation` is `PROPOSED-NOT-OPERATIONAL / RUNTIME-NOT-WIRED` and is **absent from the runtime allow-list** (`agent-onboarding-orchestration.md` §9) and from `orchestration-runtime.md`. By its own contract, any current invocation returns `needs_review` and performs no remediation.
- `packages/orchestrator/**` is landed and executable and **disconnected**. **This record does not decide its fate** — that is `C2` (§9).
- Generic CLI subagent instances are available. **They are not registered NOXUND agents** (§D3).

**The vehicle sentence, read at clause granularity.** `docs/agents/product-orchestrator-agent.md` §*Operating Protocol* opens by stating that the Product Orchestrator emits decisions and consumes `AgentResult` *"no runtime `@noxund/orchestrator`"*. Applying [[DEC-0035]] §11 step 1 — classify at clause level, not file level — that sentence **requires nothing of anyone**: it names the intended execution vehicle. **The counter-fact, stated rather than omitted: that section is headed `## Operating Protocol (vinculante)`, which makes this a materially harder case than [[DEC-0035]] §11's** — there the clause sat in a file already DESCRIPTIVE-CURRENT throughout. **The conclusion still holds**, because [[DEC-0035]] §3.1's test is what a clause *grants, requires, prohibits or constrains* within a declared scope, not the heading above it, and this one does none of those. Reading a factual sentence as normative because of its section heading is the exact mirror of the error §11 refuses — it *"did not read `Status: implementado` as a grant merely because it is phrased as a fact"* — and the mirror is no safer than the original. It is therefore the same *kind* of claim §11 classified **DESCRIPTIVE-CURRENT** for `orchestration-runtime.md`'s `Status: implementado` line, and stale in the same way and for the same reason. **This record newly identifies that residual and routes it.** It is **not** already routed: `PHASE-B-CLOSEOUT-R1` §5 row 2 names `orchestration-runtime.md` specifically, row 1 scopes to [[DEC-0035]] Annex A rows 1–11, and **`product-orchestrator-agent.md` appears in none of them**. Venue: **`C2`** (§9), which is where the vehicle sentence either becomes true or is repaired. The **binding** limbs of the same section — `ORCHESTRATOR ≠ AUTHOR / PRIMARY TECHNICAL REVIEWER / GOVERNANCE AUDITOR`, and the prohibition list — are untouched here and are carried forward in substance by §D10. `product-orchestrator-agent.md` remains INTERNAL-NORMATIVE within its declared agent-behaviour scope ([[DEC-0035]] §9); **this record classifies no file.**

**Consequence.** A disconnected vehicle is never a reason to reduce the topology, and never a reason to represent the runtime as operational. The functions in §D4–§D8 are satisfied by role separation and Product-Lead gating and **do not depend on any runtime being wired**.

---

## 4. Decision

### D1 — Actor taxonomy

Six actors. Nothing else acts in a governed unit.

| Actor | What it is | May it accept its own work? |
|---|---|---|
| **PRODUCT LEAD** | Human final authority: scoped GO, NO-GO, decisions, manual merge, escalation resolution. | n/a — the acceptor. |
| **PRODUCT ORCHESTRATOR** | Coordinator: canonical truth, decomposition, creating task-scoped roles, routing, reconciling, surfacing `HOLD`/`RED`, final return. | **No** — it accepts nothing (§D10). |
| **TASK-SCOPED AUTHOR** | Produces the artifact for one unit. | **No.** |
| **TASK-SCOPED INDEPENDENT REVIEWER** | Independent technical / correctness review for one unit. | Never the Author. |
| **TASK-SCOPED GOVERNANCE REVIEWER** | Independent governance / integrity review for one unit (§D8). | Never the Author; never audits its own execution. |
| **REGISTERED NOXUND AGENT** | An identity with a formal `docs/agents/*.md` contract, a registry entry and a compatible boundary. | Per its own contract. |

A **task-scoped role** exists only inside the unit that created it, carries no contract, no boundary, no domain authority and no standing permission, and expires with the unit. A **registered agent** may participate **only where it is genuinely operational**; a registered-but-not-operational identity may not be represented as participating, and **its name may never be attached to any result** (§D2).

### D2 — Registered ≠ operational ≠ participating

`docs/agents/README.md`'s three states — FORMAL CONTRACT · FOUNDATION RUNTIME HANDLER · REAL PRODUCT EXECUTOR — are carried forward unchanged, with one operational consequence made explicit:

> **A contract is not a capability, a runtime id is not a registration, and a registration is not an executor.**

Therefore: no unit may claim participation by an identity that is not operational; no result may be labelled with a registered agent's name unless that agent actually produced it; and no absence of an operational agent is repaired by relabelling something else with its name. Representing an unavailable agent as operational is a governance breach, not a routing convenience.

### D3 — Task-scoped roles are not agents

Instantiating a generic subagent creates **no** NOXUND agent. It confers no contract, no boundary, no runtime id and no registry entry, and it is **never** a `target_agent`. This is the existing invariant applied, not amended: `ROLE NAMES DO NOT CREATE AGENTS`; `NO EPHEMERAL / AD-HOC / UNREGISTERED AGENTS`; `TARGET_AGENT MUST HAVE A FORMAL docs/agents/*.md CONTRACT + REGISTRY ENTRY + COMPATIBLE BOUNDARY` (`product-orchestrator-agent.md` §*Operational Invariants Summary*).

The two protections that invariant exists to give are preserved in full. **No manufactured specialism:** a task-scoped role carries the **process-independence** functions — authorship, independent technical review, independent governance/integrity review — and **never** substitutes for a registered domain agent's veto where a landed clause names one (§D6). **No standing capability:** the role dies with the unit, and the vinculante registry-first provisioning model in `docs/agents/README.md` §*Como adicionar um novo agente* is **undisturbed and still binding**, with no step waived, shortened or deemed satisfied here.

### D4 — Read-only topology

For a unit that produces analysis and accepts **no** mutating artifact:

```txt
PRODUCT ORCHESTRATOR  (+ optional TASK-SCOPED SPECIALIST)
```

Where the question is one of canonical truth, routing or decomposition, the Product Orchestrator's own coordination reading answers it. Where it requires specialist technical investigation, that is delegated to a task-scoped specialist — the Product Orchestrator does not self-execute a delegable investigation (`product-orchestrator-agent.md` §*Operating Protocol*).

The output is a **RECOMMENDATION / ANALYSIS**, never an acceptance. **No mandatory reviewer is imposed on routine read-only work.** A read-only unit that begins proposing a mutating artifact for landing has become a §D5 unit and takes §D5's topology.

### D5 — Mutating topology (default)

For any mutating artifact proposed for landing:

```txt
PRODUCT ORCHESTRATOR
  → TASK-SCOPED AUTHOR
  → DISTINCT TASK-SCOPED INDEPENDENT REVIEWER
  → PRODUCT-LEAD MANUAL MERGE
```

> **Invariant: `AUTHOR ≠ REVIEWER`.**

**Reviewers are counted by function, not by headcount.** A unit's review functions are (a) independent technical / correctness review, (b) independent governance / integrity review, (c) independent domain review wherever a veto domain is touched. **The Author may never satisfy any of them.** One distinct reviewer may hold more than one function where no landed clause requires those functions to be separated and the domain requires no specialist separation.

This is the existing contract read on its own terms, not a relaxation of it. `product-orchestrator-agent.md` §*Papéis operacionais* bars one party from accumulating *"papéis **conflitantes**"* — not merely distinct ones — and its own conflict test for each review role is stated against **authorship and execution** (*"não é autor"*, *"não executa a mudança auditada"*), never against the other review role. A single non-Author reviewer holding both review functions passes that test; an Author holding either fails it.

**The clause most on point, engaged rather than avoided.** `product-orchestrator-agent.md`:565 requires that *"qualquer exceção à separação de funções requer decisão explícita do Product Lead e deve ser registrada como risco de governança"*. **It is not engaged here, and no exception is taken.** The separations that clause governs are the **three** the same list states immediately above it, and every one of them is stated against **production** — never between one review function and another: **Author ≠ reviewer** (:562, *"o reviewer de um artefato não deve ser a mesma identidade/sessão que o Author"*), **executor ≠ governance reviewer** (:563, *"o governance reviewer de uma operação não deve ser o executor da mesma operação"*), and **reviewer of a later stage ≠ producer of the stage under review** (:564, *"um agente pode revisar um estágio futuro somente se não houver conflito de função com o estágio que produziu"*). **All three hold absolutely under D5 and are strengthened by D7.** No landed clause separates one *review* function from another *review* function, so a single non-Author, non-executor party holding both is not an exception to any separation the contract states — it is the ordinary case the contract never partitioned. Consequently **no governance risk is registered under :565**, because registering one would assert an exception that is not being taken. Where a landed clause *does* require a specific separation, that separation governs — and **naming which separation each clause imposes is what keeps this precise.** Item #12 imposes **reviewer ≠ Author**; `agent-boundaries.md`:338 imposes **executor ≠ auditor**. **Neither separates one review function from another, so neither bars D5's merging** — which is why one distinct governance reviewer lawfully satisfies a governance-sensitive unit (§D6), as this record's own production did. What those clauses do bar is an Author reviewing its own artifact, or an executor auditing its own operation — and D5 bars both already.

### D6 — Sensitive and governance-sensitive topology

```txt
PRODUCT ORCHESTRATOR
  → TASK-SCOPED AUTHOR
  → DISTINCT DOMAIN / TECHNICAL REVIEWER   (where the domain requires one)
  → DISTINCT TASK-SCOPED GOVERNANCE REVIEWER
  → PRODUCT-LEAD MANUAL MERGE
```

A unit is **governance-sensitive** when its artifact changes what binds, what is authorized, what counts as evidence, or who may act — decision records; agent contracts and the cross-agent governance set; authority, classification and routing surfaces; preservation and evidence claims. **This record is itself governance-sensitive.**

**Domain vetoes are not absorbed.** Where the review matrix names a domain review (Security, Data/AI, Database, QA, DevOps), that function is held by a reviewer distinct from the Author and competent in the domain, and its `HOLD` is a veto that no majority overrides (`agent-conflict-resolution.md`; `product-orchestrator-agent.md` §*Sem votação majoritária*). Where a landed clause requires a **specific registered identity** for that domain and the identity is not operational, that is a P4 divergence to **surface and escalate** — not a gap to route around. **§D9's function-not-identity rule applies to item #12 and to nothing else**; every other identity-naming clause stands exactly as written until a Product-Lead decision says otherwise (§9, `C3`).

**Duplicate reviewers are not required where one independent reviewer legitimately satisfies both functions and existing authority permits it (§D5).** What is never permitted is the Author satisfying its own required review function, or a required function silently going unheld.

**If the required distinct topology cannot be instantiated**, the unit returns **`HOLD`** and reports **`AGENT-CAPABILITY-GAP`**, holding the dependent task at **`HOLD-PENDING-AGENT-DEFINITION`** and escalating to the Product Lead. **No new status vocabulary is created by this record** — `PASS` / `HOLD` / `RED` / `READY` / `GO` / `NEXT`, `AGENT-CAPABILITY-GAP` and `HOLD-PENDING-AGENT-DEFINITION` all already exist. The topology is never reduced to fit.

### D7 — Reviewer independence, in checkable terms

A review satisfies its function only if **all** of the following hold. Each is verifiable after the fact.

1. **Distinct instance, separate invocation.** The reviewer is not the Author's instance and is invoked separately. **The same underlying model or provider is permitted** and is not a defect.
2. **Direct access.** The reviewer receives the authorization, the artifact and the evidence **directly** — not only the Author's account of them.
3. **Independent inspection.** Load-bearing claims are re-derived by the reviewer from the source. The Author's self-check is `REPORTED`, never `VERIFIED` (`product-orchestrator-agent.md` §*Evidência load-bearing*, §*Trust model*).
4. **Own verdict, own reasons.** The reviewer returns its own `PASS` / `HOLD` / `RED`. Silence, deference and "looks fine" are not verdicts.
5. **No silent co-authorship.** A defect is **reported, not fixed**; correction requires a **new Author task**. A reviewer that edits the artifact has become a co-author, no longer satisfies the independent-review function for it, and a distinct reviewer is then required.
6. **Anchoring order.** Where technically possible the reviewer sees the artifact and the evidence **before** the Author's conclusion (`product-orchestrator-agent.md` §*Independência contextual*).
7. **Not principal independence.** **The same GitHub credential does NOT constitute technical principal independence and must never be represented as such** (§D12).

### D8 — The governance-review function

The function verifies that the unit stayed **inside its authorization** — scope, exact paths, write boundary, and no unauthorized scratch, temp, sidecar, cache or backup artifact; that evidence claimed as load-bearing is **verified rather than attested**; that every required review function was **actually instantiated and actually distinct**; that no verdict was upgraded (`REPORTED` → `ACCEPTED`) and no status vocabulary invented; and that dissent, `HOLD` and `RED` were preserved rather than harmonized away.

It verdicts `PASS` / `HOLD` / `RED`. It is **not** the technical review: a governance `PASS` states scope and integrity, never technical correctness (`product-orchestrator-agent.md` §*Trust model*). Missing evidence is `HOLD`, never *probably PASS*.

### D9 — `governance_integrity_agent`: the requirement is the function

> **The binding requirement of `agent-review-matrix.md` #12 is the independent governance-review FUNCTION, not the operational existence of one specific proposed agent identity.**

Consequently, and durably:

- an **operational** `governance_integrity_agent` **MAY** satisfy the function once it genuinely exists;
- **until then**, a **distinct `TASK-SCOPED GOVERNANCE REVIEWER` may satisfy it**;
- that reviewer **is not** the registered agent and **must never be labelled as it** — not in a header, a handoff, a result or a return;
- **no self-review**: the Author never satisfies it;
- **no silent omission**: the function is held, or the unit returns `HOLD` + `AGENT-CAPABILITY-GAP` (§D6).

**What this does not do.** It does not register, wire, activate or promote `governance_integrity_agent`; it stays `PROPOSED-NOT-OPERATIONAL / RUNTIME-NOT-WIRED` and still binds nothing. It does not weaken #12: the independence requirement is unchanged, and §D7 makes it checkable for the first time. It does not create a second governance architecture — it names, in the existing vocabulary, who holds a function the matrix already required.

**How the P4 divergence is resolved.** At the C1 base, #12 required an identity that does not operationally exist. Per [[DEC-0035]] §4 P4 the accurate descriptive fact is **not** rewritten to agree with authority, and it is not rewritten here — §3 restates it. The repair is made at the **authority** end, by this decision, which narrows the requirement to the function it was always for. That is the same operation [[DEC-0036]] §4 performed on a reserved question: an adjudication, not a supersession.

### D10 — Product-Orchestrator constraints

The Product Orchestrator **holds** canonical truth, decomposition, creation of task-scoped roles, routing, dependency ordering, reconciliation without erasing dissent, surfacing `HOLD`/`RED`, and the final return.

It **may not**: author · review · accept · merge · manufacture or infer a GO · represent an unavailable agent as operational (§D2) · label a task-scoped role as a registered agent (§D3) · self-execute a delegable specialist investigation · reduce a required topology to make a unit fit · convert `REPORTED` into `ACCEPTED` · override a veto domain by majority · create scratch, temp, sidecar, cache or backup artifacts as operational convenience. All of these are already binding in `product-orchestrator-agent.md`; **this record adds no orchestrator power and removes none.**

### D11 — Product Lead: GO and merge

A **scoped GO** authorizes one execution unit and expires with it; `NEXT` / `READY` / `RECOMMENDED` is not authorization ([[DEC-0035]] §6). A GO does not rewrite durable authority — that requires a landed record.

> **The PRODUCT LEAD MANUALLY MERGES EVERY GOVERNED PR**, unless and until changed by explicit Product-Lead authority.

**Represented accurately, this is a PROCESS / AUTHORITY GATE, not mechanically-enforced independent GitHub review** (§D12). It is the ratification instrument: a record is in force from that merge, not from being authored.

### D12 — The single-principal limitation, stated exactly

Two distinct findings. They must not be merged, and neither may be overstated.

**F4a — REVIEW / MERGE PRINCIPAL SEPARATION GAP.** Logical independence is **required** (§D5, §D7). **GitHub-principal independence is absent**: `required_approving_review_count` is `0`, `required_reviewers` is empty, `require_code_owner_review` is `false`, and **no `CODEOWNERS` file exists anywhere in the tree**. Independent approval is therefore **not mechanically required**, and the same GitHub principal may author and merge a PR. **Never represent process independence as mechanical independence.**

**F4b — PROTECTION DURABILITY / SINGLE-ADMIN TAMPER RISK.** The same admin principal may prospectively alter rulesets. This is a **durability and tamper** risk about the future. **It is not evidence that current protections are ineffective**, and it must not be reported as one.

**What is NOT claimed.** **Direct push to `main` is MECHANICALLY BLOCKED** under the currently observed ruleset `19697151`: its `pull_request` rule is active, and the sole bypass actor is scoped `bypass_mode: pull_request`, which by GitHub's documented semantics permits bypass **only in the pull-request context**, not direct pushes; repository `admin` does not itself confer ruleset bypass. **No actor currently pushes directly to `main`, and any statement to the contrary is withdrawn.**

**Provenance, marked honestly — including against the source.** The ruleset configuration and the review-requirement fields are **`REPORTED`** — established against live repository configuration by the C0 assessment and carried by the Product Lead; this unit holds no repository-configuration read authority and did **not** re-derive them. **Disclosed, not buried: the withdrawn direct-push claim above originated in that same C0 unit**, whose historical disposition is `RED — VERIFIED AUTHORIZATION BREACH`, `CLOSED — REMEDIATED` (header). A source with one withdrawn sibling claim is weaker evidence, which is why the two surviving claims are marked `REPORTED` rather than treated as verified, and why the paragraph below states that the normative content does not rest on them. The `CODEOWNERS` absence is **`VERIFIED`** here. **The normative content of D12 does not depend on the exact configuration**: it is fail-closed with respect to it, because it forbids overstating separation rather than relying on any particular setting. Mechanical enforcement is `C5` (§9).

### D13 — What this makes smaller

Checkable, so the claim is not decorative. The default governed unit is **three parties** — Author, one distinct reviewer, Product Lead — where the paper architecture read as four to five roles. Reviewers are counted **by function**, so a second reviewer appears only where a domain or a landed clause actually requires separation. **No new agent identity, no new status token, no new artifact class, no new runtime dependency, and no second governance architecture is created.** Every rule above is either an existing invariant applied, or the single narrowing named in the header.

---

## 5. Relationship to [[DEC-0035]] §14 — prospective only

[[DEC-0035]] §14 recorded that the Phase-A/B records were produced under a **temporary** topology and expressly ratified no permanent one. That record stands, unedited and **CURRENT**; this record does not contradict it, because §14 declined to ratify a permanent topology rather than forbidding one.

Stated prospectively, and only prospectively:

- the Phase-A/B topology was **temporary evidence of a shape that worked**, never standing authority;
- **C1 establishes the permanent topology**, from its landing forward;
- **C1 does NOT retroactively convert Phase-A/B practice into standing authority**, does not validate or invalidate any earlier unit, and confers nothing backwards in time;
- future governed work follows C1 **after landing**;
- **no historical Phase-A/B evidence is rewritten** by this record, and none may be rewritten on its authority.

The registry-first provisioning gate remains binding in full (§D3).

---

## 6. The affected review-matrix clauses — #12 is LIVE, #11 is LATENT

These are treated differently because they **are** different, and conflating them would sprawl the fix across a chain that cannot currently fire.

**Item #12 — LIVE, and narrowed.** Governance-sensitive artifacts are being produced right now, this record among them. #12's mandatory-reviewer cell is narrowed to the **function** (§D9), and the file carries the pointer (§7). Everything else in #12 — that the review is mandatory, that it is independent, and that it distinguishes verified from attested evidence — is unchanged.

**Item #11 and the `apply_exact_remediation` chain — LATENT, and untouched.** #11 is conditioned on a DevOps capability that is `PROPOSED-NOT-OPERATIONAL / RUNTIME-NOT-WIRED` and **absent from the runtime allow-list**, and whose contract returns `needs_review` on any current invocation. **Its trigger cannot fire at this base**, so no edit is made to #11, to `agent-boundaries.md`, to `devops-infra-agent.md`, or to `docs/agents/README.md`:84. When and if that capability is provisioned — which requires its own authorization and its own Product-Lead gate — **that** unit reconciles #11 against this record. Nothing here provisions it.

**The two Bootstrap sections — untouched, and cited as support.** They already resolve a mandatory-reviewer deadlock by naming other parties, and already forbid self-review. §D9 generalizes that discipline; it does not amend those sections, and their post-operational restoration clause (*"Depois que o Governance & Integrity estiver operacional, os requisitos normais … voltam a valer"*) is consistent with §D9 and preserved.

**Item #13 and every other identity-naming clause — not adjudicated here.** They stand exactly as written. Their satisfiability is a `C3` question (§9), and a clause that cannot be satisfied is escalated under P4, never routed around.

**No two CURRENT authorities are left apparently contradicting each other.** After this record, `agent-review-matrix.md` #12 and the capability reality of §3 agree on their face: the file states the function, names the identity as a future satisfier, and points at this record.

---

## 7. Forward discoverability

[[DEC-0035]] §10 requires the forward-discoverability update to be created **in the same authorized unit** that creates the relation. Both are created here:

1. `agent-review-matrix.md` is **EDITABLE** ([[DEC-0035]] §9), so it carries an **additive** pointer in-file, at item #12 and immediately below the matrix — the additive marker §10 permits, never a rewrite of any rule.
2. The external edges — `DEC-0037 NARROWS agent-review-matrix.md #12`, and `DEC-0037 EXTENDS DEC-0035 §12 · §14` — are recorded in the relation table at `docs/product/context-map.md` §3.

**This unit is incomplete without both.**

---

## 8. Reconciliation performed by this unit

Bounded to what this decision makes stale. Nothing historical is rewritten.

1. **`docs/agents/agent-review-matrix.md`** — item #12's mandatory-reviewer cell states the function, with the identity as a future satisfier; one additive note below the matrix records the narrowing, its exact limit, and the LIVE/LATENT split of §6. **No other reviewer rule is changed and no general cleanup is performed.** In Portuguese, matching that file.
2. **`docs/product/current-state.md`** — §E is repaired where C1 falsifies it (the manual-merge generalization; the `governance_integrity_agent` requirement; the temporary-topology line). §B's Axis-2 ladder and authority paragraph are repaired because **this unit's own landing** makes *"Phase C … has not started"* false; leaving it would be a `STALE-DESCRIPTIVE` defect created by this record. A scoped-reverification paragraph is added per that document's freshness convention. **§F is untouched** — its *"no state-authority divergence was found"* is scoped to B5/B6's verification, and the #12 divergence is resolved at the authority end by §D9 rather than left standing.
3. **`docs/product/context-map.md`** — the §3 relation rows required by §7; one §1 routing row for the execution topology, plus a pointer on the existing `docs/agents/**` row; the §2 `Phase A … Phase F` lifecycle cell repaired for the same reason as §B above; a scoped-reverification paragraph per that document's convention.

**Deliberately left alone, and named rather than swept:** `orchestration-runtime.md` (`PHASE-B-CLOSEOUT-R1` §5 row 2, still routed); `agent-registry.md`; `agent-boundaries.md`; `devops-infra-agent.md`; `docs/agents/README.md`; `handoff-template.md`; `agent-review-matrix.md` §*Fluxo de aplicação*, whose `HOLD`/`RED` vocabulary describes the **function's** verdicts and stays true of whoever holds it; and the corpus-wide historical normalization residual (`PHASE-B-CLOSEOUT-R1` §5 row 1).

---

## 9. Phase-C boundaries — what this record does not decide

`C2` … `C5` are Product-Lead-defined Phase-C unit labels; per [[DEC-0033]] §8 they are named to place work, never to confer standing, and **each requires its own explicit Product-Lead GO**.

- **`C2` — `packages/orchestrator` disposition** (resume · reduce · retire), and the preserved commit `151fb46`. **Not decided here, and untouched:** `PRESERVED ≠ ADOPTED` ([[DEC-0035]] §9). [[DEC-0032]] §8's **DEFER-PHASE-C** stands. **This topology holds under all three dispositions**, because it depends on role separation and Product-Lead gating, not on a runtime.
- **`C3` — capability matrix**, including the satisfiability of every identity-naming clause other than #12.
- **`C4` — `AgentResult` V2 / result schema.**
- **`C5` — mechanical enforcement**: validators, lint, hooks, CI, `CODEOWNERS`, rulesets, branch protection, review requirements. **Nothing in this record is mechanically enforced** (§D12).

**Authority direction is fixed and one-way:**

> **`C1 GOVERNANCE MODEL → RUNTIME IMPLEMENTATION`, never the reverse.** A runtime retained by `C2` **implements** this topology; it does not redefine it, and no runtime behaviour amends this record.

Agent registration, activation and runtime wiring remain gated by the vinculante registry-first model in `docs/agents/README.md`, untouched here.

---

## 10. Effective and landing semantics

**In force from the Product Lead's manual merge of this record**, and prospective from that moment. Specifically:

- it governs governed work **commenced after landing**;
- it **does not retroactively validate or invalidate any earlier unit**, including its own production, which stands on the `C1` GO and on nothing in this record — **a record does not ratify itself**;
- it creates **no standing permission**: every unit still requires its own explicit Product-Lead GO ([[DEC-0035]] §6);
- it is **FROZEN** ([[DEC-0035]] §9): its body is never rewritten, a change to this topology requires a **later landed record**, and no GO, handoff, closeout or memory may amend it ([[DEC-0035]] §5, §6);
- imperative wording in any EVIDENCE artifact describing this topology creates no obligation beyond what this record states ([[DEC-0035]] §3.1).

---

## 11. Explicit non-decisions

This record does **not** and must not be read to: register, wire, activate or promote any agent or capability · edit any agent contract · dispose of `packages/orchestrator` or materialize, build, test, port or cherry-pick `151fb46` · create or change any workflow, ruleset, branch protection, `CODEOWNERS`, CI check, validator, lint or hook · define a capability matrix, `AgentResult` V2 or a risk engine · mechanically enforce the reviewer-count policy it does supply (§D5, §D13) · re-arm anything ([[DEC-0033]] §8) · change product scope, MVP admission or any `OD-*` item · resolve the successor PostgreSQL architecture or any Axis-1 technical question · define improvement Phase D, E or F · adjudicate any review-matrix clause other than #12 · classify, promote or demote any artifact · edit, supersede or reinterpret [[DEC-0035]] or any prior DEC · rewrite any historical artifact · authorize `C2`, `C3`, `C4`, `C5`, or any commit, push, PR, merge or execution of any kind.

---

*Related: [[DEC-0035]] §3.1 (imperative wording confers no class), §4 P3/P4 (conflict versus divergence), §6 (GO versus durable authority), §7 and §9 (classification and family defaults), §10 (forward discoverability), §11 (clause-level classification of a status claim), §12 (Phase-C boundary), §14 (temporary Phase-B topology); [[DEC-0036]] §4 (adjudication without supersession); [[DEC-0032]] §8 (`packages/orchestrator` DEFER-PHASE-C); [[DEC-0033]] §8 (unlanded identifiers; nothing re-arms). Agent surfaces relied on and not edited: [`product-orchestrator-agent.md`](../../agents/product-orchestrator-agent.md), [`README.md`](../../agents/README.md), [`agent-conflict-resolution.md`](../../agents/agent-conflict-resolution.md), [`governance-integrity-agent.md`](../../agents/governance-integrity-agent.md). Surface narrowed and reconciled: [`agent-review-matrix.md`](../../agents/agent-review-matrix.md). Routing surfaces reconciled: [`current-state.md`](../current-state.md), [`context-map.md`](../context-map.md). Predecessor unit — unlanded, no file path: `PHASE-C-C0-AGENT-GOVERNANCE-V2-FOUNDATION-ASSESSMENT-R1` (historical disposition `RED`, `CLOSED — REMEDIATED`; see the header).*
