# NOXUND — Task Context Pack

**Authority class:** DESCRIPTIVE-CURRENT · **Lifecycle:** CURRENT · **Mutability:** EDITABLE
**This is not a decision record; it creates no authority.** It is a **format aid**, the class [`DEC-0035`](decisions/DEC-0035-canonical-context-v2-authority-lifecycle-supersession-model.md) §9 assigns to `docs/agents/handoff-template.md` (*"not a handoff — class: DESCRIPTIVE-CURRENT, a format aid"*). That template is the **return** format; this is the **supply** format.
**Freshness.** Verified against canonical main `3a1c986570e1e7aa767c89a031b64a6a39c7009a`, 2026-08-19. Once `origin/main` advances past that SHA this document is `STALE-UNTIL-REVERIFIED` for its repository-state citations — **the SHA is provenance, not normative authority**, and `STALE ≠ WRONG`.

**Every rule here about NOXUND authority is derived from a landed record and cited to it, and this artifact introduces no authority model beyond `DEC-0035`** — the sole exception being statements that define this format's own fields, which are definitional, inert and bind nothing, on the `handoff-template.md` format-aid precedent (`DEC-0035` §9). Current state is owned by [`current-state.md`](current-state.md); routing and identifier disambiguation by [`context-map.md`](context-map.md) — a pack **points first and quotes only what the task acts on**, never maintaining a copy of either. **What this is:** a template plus a repeatable selection method for assembling **minimum sufficient context** for one bounded task. **What it is not:** a universal prompt, a roadmap, a DEC inventory, a set of pre-built per-track packs, or any executable mechanism (§6).

---

## 1. Three objects — `BOOTSTRAP ≠ CONTEXT PACK ≠ WRIT`

| Object | Answers | Where it lives | What it grants | Lifetime |
|---|---|---|---|---|
| **Role / session bootstrap** | *Who am I, and what standing rules bind my behaviour?* | `docs/agents/<role>-agent.md`, `global-agent-rules.md`, `docs/agents/README.md` §*Regras gerais* | Standing behavioural obligation, INTERNAL-NORMATIVE **within its declared agent-behaviour scope** (`DEC-0035` §9) | Persists across tasks |
| **Task Context Pack** (this format) | *What must this task know to reason correctly?* | Assembled per task from the sources below | **Zero.** DESCRIPTIVE-CURRENT creates no authority (`DEC-0035` §3.1) | One task |
| **Task / execution writ** | *What is authorized now, what may mutate, what is prohibited, what must be returned?* | The explicit **Product-Lead GO** for the named unit | Execution permission, with the scope it names, expiring with that unit (`DEC-0035` §6) | One unit |

**`writ` names an instrument that already exists.** It is a naming convention for the explicit Product-Lead GO of `DEC-0035` §6 — not a new instrument, not a new class, not a new gate. **A GO does not rewrite, supersede or discharge durable landed authority**; where durable authority must change, the landed-record mechanism must *also* be satisfied (`DEC-0035` §6). **Terminology collision, flagged not resolved:** the repository already uses *bootstrap* in a different sense — the separate Product-Lead **runtime-activation** gate (`docs/agents/agent-registry.md`: `INITIAL-RUNTIME-ACTIVATION = REQUIRES-SEPARATE-PRODUCT-LEAD-BOOTSTRAP-GATE`) — and `current-state.md` §F uses it for a minimum authority summary. **Role/session bootstrap in this document is neither of those.** Naming is not adjudicated here.

### 1.1 Why a pack cannot silently become a writ — five derived containments

1. **Class.** A pack is DESCRIPTIVE-CURRENT. DESCRIPTIVE-CURRENT **can never supersede, repeal or relax** INTERNAL-NORMATIVE (`DEC-0035` §4 P4), and creates no authority at all (§3.1).
2. **Quotation.** Imperative wording on a non-normative surface **creates no standing obligation**; quoted "must" text carries only the authority of its cited source (`DEC-0035` §3.1, §4 P4). A pack therefore always names the source of any imperative it carries.
3. **Routing.** `NEXT` / `READY` / `RECOMMENDED` **is not execution authorization** (`DEC-0035` §6); *naming is not authorization* (`context-map.md` §4). A pack places a unit; it never resumes one.
4. **Structure.** Every pack carries field **§9 Authority boundary** verbatim, and field **§10** **names** its writ without ever containing the authorization. A pack missing either is malformed and must not be acted on — definitional to this format, binding nothing beyond it (`DEC-0035` §3.1, §9).
5. **Fail-closed header.** A pack is a new context artifact and **must declare its authority class**; absent that declaration it fails closed as NON-AUTHORITATIVE until classified (`DEC-0035` §7). The rule is documentary — no validator exists or is created (`DEC-0035` §12; §6 below).

---

## 2. The template

```md
# Task Context Pack — <TASK-ID>

**Authority class:** DESCRIPTIVE-CURRENT · **Lifecycle:** CURRENT · **Mutability:** EDITABLE
**This pack creates no authority and authorizes no execution.**

## 1. Task identity
- **Task / unit id:** · **Purpose class:** · **Owning program / track:**
- **Axis:** Axis 1 (product / engineering) | Axis 2 (development-system improvement) — `current-state.md` §B
- **Position:** <phase / gate / unit, named together with the ladder it belongs to>

## 2. Provenance and freshness
- **Assembled against canonical main:** <SHA> · **Assembly date:** <YYYY-MM-DD>
- **Freshness condition:** STALE-UNTIL-REVERIFIED once `origin/main` advances past that SHA.
  **The SHA is provenance, not normative authority.**
- **Per-source flags:** <source — CURRENT / VERIFIED AGAINST <SHA> | STALE-UNTIL-REVERIFIED | known stale clause>

## 3. Current-truth slice
<Only the materially relevant DESCRIPTIVE-CURRENT facts. Point to the section in `current-state.md`; restate only the minimum that makes the routing actionable, never as a maintained copy.>

## 4. Governing authority
| Source (clause-level) | Class · lifecycle · mutability | What it constrains here |
|---|---|---|

## 5. Routing used
<Only the `context-map.md` rows actually needed: §1 destinations, §2 identifiers/collisions, §3 relations, §4 guards.>

## 6. Historical / preserved evidence
<Only where provenance reconstruction, prior-failure analysis or supersession reasoning genuinely requires it.
Exact ref + SHA. Labelled EVIDENCE / HISTORICAL · PRESERVED-NOT-ADOPTED.>

## 7. Open uncertainty / HOLD · orientation
<Unknowns, authority conflicts, evidence limits. UNKNOWN is a valid value.
Product-Lead orientation belongs here, labelled as orientation — never in §3.>

## 8. Exclusions
<Adjacent context deliberately left out, one line each, with the reason.>

## 9. Authority boundary
This pack supplies context only. It grants **zero execution authority**, creates no obligation, and
authorizes no mutation, commit, push, PR, merge, provisioning, arming or run. Execution requires a
separate, valid, Product-Lead-authorized writ (`DEC-0035` §6). Where this pack quotes imperative
wording, that wording carries only the authority of its cited source (`DEC-0035` §3.1, §4 P4).

## 10. Writ
<Named by reference only: which writ is required and where its authorization comes from.
Never the authorization itself, and never evidence that one exists.>
```

### 2.1 Field rules

- **§1 Axis is load-bearing, not decoration.** `context-map.md` §2 records **nine distinct ladders** and heavy identifier collision (`Fase 1–9` vs `Fase A–D` vs `Phase A–F`; `U1` in two namespaces; `P5` in three; six independent `OD-*` series). An unresolved axis is an **UNKNOWN**, never a guess.
- **§2 freshness is a provenance concern, and `STALE ≠ WRONG`.** A source may be `STALE-UNTIL-REVERIFIED` and still fully accurate; reverification may conclude *no content change required* (`current-state.md` freshness contract). Flag the condition; do not discard the source, and never repair a source from inside a pack.
- **§3 / §5 point first.** Always give the section pointer; **restate only the minimum that makes the routing actionable, never as a maintained copy.** A fuller copy of `current-state.md` or `context-map.md` ages independently — the **STALE-DESCRIPTIVE DEFECT** of `DEC-0035` §4 P4.
- **§4 classifies at clause granularity**, carrying all three `DEC-0035` axes. **All five authority classes are admissible** — INTERNAL-NORMATIVE · **EXTERNAL-CONSTRAINT** · DESCRIPTIVE-CURRENT · EVIDENCE · NON-AUTHORITATIVE (`DEC-0035` §3.1). *Prompt:* does the task touch a provider, platform or vendor constraint NOXUND must respect but cannot internally repeal — the YouTube-dependent collection track being the live case? **No landed EXTERNAL-CONSTRAINT artifact exists on `main` at this base**, so the class must be **representable, never pre-populated**. A file is never promoted because one of its clauses was ratified elsewhere (§9.1, §11), and **chronology supersedes nothing absent an explicit edge** (§4 P2).
- **§6 `PRESERVED ≠ ADOPTED`; `HISTORICAL EVIDENCE ≠ CURRENT AUTHORITY`** (`DEC-0035` §9; `DEC-0033` §8). Route only to durable identifiers — never to machine-local mutable ones such as a stash ordinal, for the reason `context-map.md` §5 already gives.
- **§7 unknown is allowed. Never manufacture certainty to fill a field.** Two CURRENT INTERNAL-NORMATIVE authorities in genuine conflict with no explicit edge → **`HOLD — AUTHORITY-CONFLICT`**, both readings stated, escalated; the winner is never inferred (`DEC-0035` §4 P3). **P5 branch:** an internal record that appears to grant what an EXTERNAL-CONSTRAINT forbids is likewise a **P3-class escalation to the Product Lead, never a self-executed override** (`DEC-0035` §4 P5).
- **Memory may assist recall, orientation and routing — and nothing more** (`DEC-0035` §5). It is **NON-AUTHORITATIVE**: a pack may never source current Git state, repository state, durable authority, supersession or exact historical status from it. Every material claim is independently established from the repository, and on conflict **the repository wins**.
- **Product-Lead orientation is admissible as orientation, labelled as such** — never as repository fact. `current-state.md` §B applies exactly this discipline to the Axis-1 pivot.

---

## 3. Selection method

**S1 — Identify.** Task id, axis, owning program/track, position on its ladder, objective class.
**S2 — Load the smallest current-truth surface.** Normally `current-state.md`, by section.
**S3 — Route.** `context-map.md` §1 for destinations, §2 for identifier disambiguation, §3 for explicit relations, §4 for the known-false assumptions this task is exposed to.
**S4 — Constrain.** Add only authority that **materially** constrains the task, at clause granularity, carrying class · lifecycle · mutability.
**S5 — Add history only where reasoning would otherwise be unsafe.** Provenance reconstruction, prior-failure analysis, preserved evidence, supersession reasoning. Label it historical.
**S6 — Surface uncertainty.** Unknowns, conflicts, evidence limits, unresolved HOLDs.
**S7 — Stop expanding.** Apply the compression test, then stop.

**Compression test — two directions, both mandatory.**

- **Cut:** *if this source were removed, could the task still be performed safely and correctly?* If yes, **cut it**.
- **Gap:** *is any required source missing only because the pack was optimised for brevity?* If yes, the pack is **under-contextualised** — restore it.

The target is **minimum sufficient context, not minimum bytes.** A pack that passes the cut test and fails the gap test is not lean; it is defective.

### 3.1 The two failure modes

**UNDER-CONTEXT** — omits load-bearing current state, a governing authority, a collision or routing warning, material history, an unresolved HOLD, or a known uncertainty. *Symptom:* the task proceeds confidently on a false assumption; `context-map.md` §4 is the catalogue of those assumptions. **This is the dangerous mode, because an under-contextualised pack looks lean.**

**OVER-CONTEXT** — unrelated history, repository dumps, DECs that do not constrain the task, every program and track, giant stale bootstrap material. *Symptom:* the reader cannot tell which three lines actually govern.

### 3.2 Anti-growth mechanism

1. **One task, one pack; packs are disposable.** They are not maintained as standing documents. Precedent, as a format convention: `handoff-template.md` §*Notas de uso* — *"Um handoff por tarefa. Tarefas grandes devem ser quebradas antes, não resumidas depois."*
2. **No standing or pre-built per-track packs**, and **cite by link, quoting only what the task acts on** — never a maintained copy of `current-state.md` or `context-map.md`. A pre-built pack ages into exactly the giant stale bootstrap this format exists to replace.
3. **Ceiling.** The §4 example is the reference size. Anything materially larger is over-context until every added source has passed the cut test individually.
4. **Exclusions (§8) are a required field of this format**, not an optional one — definitional, binding nothing beyond the format (`DEC-0035` §9). Growth must then argue against an explicit prior decision instead of accumulating quietly.
5. **Split rule.** If a pack cannot be assembled at roughly the size of the §4 example, the **task** is too broad — split the task, not the pack.

---

## 4. Worked example — a future PostgreSQL successor task

**Illustrative only. No such unit is authorized, and this example is not one.** It is shown because it exercises the hardest property: reaching real Axis-1 constraints while refusing every historical `NEXT` label that looks like permission.

```md
# Task Context Pack — <PG-SUCCESSOR-ASSESSMENT-EXAMPLE>

## 1. Task identity
Purpose class: design assessment of the successor PostgreSQL architecture · Program: PG-EXIT (`P0`…`P10`)
Axis: **Axis 1 — product / engineering trajectory** (`current-state.md` §B)
Position: provisioning sits at `P10`; runner selection sits under `P3`

## 2. Provenance and freshness
Assembled against canonical main `3a1c9865…` · 2026-08-19 · STALE-UNTIL-REVERIFIED past that SHA.
**The SHA is provenance, not normative authority.** Flags: `current-state.md` = **STALE-UNTIL-REVERIFIED**
(declares base `a11bd169…`), its §C facts re-read at this base and not contradicted; `context-map.md` =
`13d3777…` base plus an additive B4 clause.

## 3. Current-truth slice — read `current-state.md` §C; not copied here
The three facts that change this task's reasoning: **no production successor PostgreSQL exists** · `P10` has not
occurred · `infra/postgres` is local/dev plus design and spike material, not a deployed successor. §C's own
"Undecided" list is this task's subject matter — read it there; do not mirror it here.

## 4. Governing authority
| Source (clause-level) | Class · lifecycle · mutability | What it constrains here |
|---|---|---|
| `DEC-0028` §9 | INTERNAL-NORMATIVE · PARTIALLY-SUPERSEDED · byte-frozen | Defines P2–P10 as a proposal; each item is gated docs/design → GO. |
| `DEC-0029` · `DEC-0030` · `DEC-0032` §5 | INTERNAL-NORMATIVE · CURRENT · FROZEN | Sqitch and Flyway rejected; **no runner adopted**; §5 authorizes nothing positively. |
| `DEC-0033` §8 | INTERNAL-NORMATIVE · CURRENT (the *record* is PARTIALLY-SUPERSEDED; §8 is expressly *"fully binding, undisturbed"* — `DEC-0034` §4) · byte-frozen | Nothing re-armed; restoring removed write capability needs its own Product-Lead decision. |
| `DEC-0035` §6 | INTERNAL-NORMATIVE · CURRENT · FROZEN | GO ≠ durable authority; `NEXT`/`READY`/`RECOMMENDED` is not authorization. |
| `SEC-0001` §0 | EVIDENCE · CURRENT as record · FROZEN | If the task touches RLS/Fase 9: the veto stands until mitigation — it binds by the grant in `agent-conflict-resolution.md`, **not** by sitting in a SEC file (`DEC-0035` §3.1). |

## 5. Routing used — `context-map.md`
§1 rows *PostgreSQL successor material* (**classification OPEN**) and *Data model, migration ladder* · §2 rows
`P0…P10` and `P3A/P3B/P3B2/P3C` plus the PG-EXIT per-item qualifier table · §3 rows `P8 DEPENDS-ON P9` and
`DEC-0034 → DEC-0033 §5` · §4 guards *no production successor exists*, *prepared ≠ executed*, *naming is not authorization*.

## 6. Historical / preserved evidence — prior-failure analysis only
`spike/pg-exit-p3a-sqitch-atomicity` @ `8b36bd1` · `spike/pg-exit-p3b-flyway-atomicity` @ `e8c72f1`
(`context-map.md` §5). **EVIDENCE / HISTORICAL · PRESERVED-NOT-ADOPTED** — citable by exact SHA,
never routed from as current state or current authority (`DEC-0035` §9).

## 7. Open uncertainty / HOLD · orientation
Migration-runner selection **OPEN** — three mechanisms rejected, none adopted. P10 architecture, version,
collation, role topology, backup/PITR — **UNKNOWN at this base**; not filled from memory. No
`HOLD — AUTHORITY-CONFLICT`: the `P8`→`P9` precondition and its `DEC-0034` §4 narrowing carry an **explicit**
edge, so `DEC-0035` §4 P1 governs and P3 does not engage.

## 8. Exclusions
Frontend, marketing/GTM, report copy — no bearing · `SG-6`/`SG-8`/`SG-V*` and video ladders — different tracks ·
improvement Phase A–F unit history — different axis · the full `OD-*` inventory — only PG-EXIT `OD-1…OD-7` bear ·
`packages/orchestrator` and agent runtime — Phase C.

## 9. Authority boundary
<verbatim, per §2 of the format>

## 10. Writ
**Required and not present.** No PG-EXIT unit is authorized by this pack. Authorization for any successor-database
unit comes only from an explicit Product-Lead GO naming that unit (`DEC-0035` §6). This pack neither contains
such a GO nor evidences one.
```

---

## 5. Four-case differential

Demonstration of the mechanism, **not** execution of any of these tasks.

| Case | Axis | Included beyond the mandatory header | Deliberately excluded | The one trap |
|---|---|---|---|---|
| **A — routine Phase-B docs task** | 2 | `current-state.md` §B, §G · `DEC-0035` §3, §4, §7, §9 (`docs/product/*.md` row), §14 topology · `context-map.md` §1 and its §2 `B0…B6` row | Every Axis-1 track and ladder · all preserved refs · PG-EXIT · collection · agent runtime | `current-state.md` §B, §G and §I still read *"B3 is **not authorized**"* / *"B3 context index — **NOT YET IMPLEMENTED**"* / *"not yet landed"* while B3 has landed. That is a **STALE-DESCRIPTIVE DEFECT** (`DEC-0035` §4 P4): flag it in field §2, act on the landed reality, and **do not repair it from inside a pack** — see §6. **Smallest of the four packs.** |
| **B — future PostgreSQL successor task** | 1 | §4 above, in full | Frontend · GTM · SG and video ladders · Axis-2 unit history · non-PG `OD-*` series | Treating a historical PG-EXIT `NEXT`, *"required next gate"* or *"recommended"* label — in memory or inside preserved P3C material — as current authorization. It is not (`DEC-0035` §6; `context-map.md` §4 *Naming is not authorization*). |
| **C — historical P3C / `S1-PREP-R*` investigation** | 1 (historical) | `context-map.md` §5 preserved rows and the P3C preserved design-set note (`checkpoint/phase-a-primary-2026-08-11`; 15 files; `S1-PREP-R1`–`R5`, `R7`–`R9`, **`R6` absent**) · §2 rows `P3A/P3B/P3B2/P3C` and `S1-PREP-R*` · `DEC-0029` / `DEC-0030` / `DEC-0032` §5 for what was concluded | Current-state §A, §D, §E · improvement-program history · anything needed to *adopt* a runner rather than to *read* what was falsified | Letting preserved material read as current design or as authority. `PRESERVED ≠ ADOPTED`; `HISTORICAL EVIDENCE ≠ CURRENT AUTHORITY` (`DEC-0035` §9; `DEC-0033` §8). Also: the four archives named in `context-map.md` §5 are absent from every ref and are **not** inspection targets. **Deepest history of the four; almost no current-truth slice.** |
| **D — future Phase-C agent-governance task** | 2 (not started) | `current-state.md` §E · `DEC-0032` §8 (`packages/orchestrator` **DEFER-PHASE-C**) · `DEC-0035` §12 Phase-C boundary and its §11 worked case · `PHASE-A-CLOSEOUT-R1` §4 Phase-C row · `docs/agents/README.md` (INTERNAL-NORMATIVE *Regras gerais* plus the *vinculante* registry-first provisioning gate; DESCRIPTIVE-CURRENT three-state model) · `context-map.md` §1 agents row | All Axis-1 tracks · DB and PG-EXIT · collection · preserved refs | **Locating Phase-C context and then designing Phase C.** A pack locates; it decides nothing. Phase C is NOT STARTED and needs its own GO. Note also the known stale `orchestration-runtime.md` `Status: implementado` line (`DEC-0035` §11, Annex A row 8) — flag, do not repair. |

**Why these are materially different, not four dressings of one pack:** different axes (2 · 1 · 1 · 2), different current-truth surfaces (§B/§G · §C · almost none · §E), authority sets and routing rows that overlap only partially (B and C share `DEC-0029`/`DEC-0030`/`DEC-0032` §5 and the `P3A/P3B/P3B2/P3C` row; A and D share `current-state.md` and `DEC-0035`), and history depth ranging from none (A, D) through two spike refs (B) to a full preserved design set (C).

---

## 6. Routed here, not solved here

- **B5 candidates discovered — recorded, not executed. B4 edits neither file.** **(i) STALE-DESCRIPTIVE DEFECT** (`DEC-0035` §4 P4): `current-state.md` §B (*"B3 is **not authorized**"*), §G (*"B3 context index — NOT YET IMPLEMENTED"*) and §I (*"not yet landed"*) are overtaken by B3 landing. **(ii) Freshness-metadata condition — not a defect:** `current-state.md`'s declared base `a11bd169…`. The statement *"LAST VERIFIED AGAINST …"* is **true**; the verification is stale, not the claim (`STALE ≠ WRONG`; its own contract; `context-map.md` §1 `†`, on its surviving clause *"a freshness-metadata condition, not a content defect"*). Routed to an authorized **maintenance / reverification** unit, which may conclude *no content change required*. The identical condition applies to this document the moment `main` advances past `3a1c9865…`. **(iii) STALE-DESCRIPTIVE DEFECT:** `context-map.md`'s `†` note asserts *"the only intervening commits are B2's own … and the only file they touch is that document itself"* and *"no fact in it is known-wrong"* — both false at this base: B3's commits intervene, touch that map, and produced (i). **B4 did not reverify that note and does not repair it.** **(iv) STALE-DESCRIPTIVE DEFECT on landing:** `current-state.md` §G *"B4 task context pack — NOT YET IMPLEMENTED"* is falsified by B4's own landing — the forward-discoverability discipline `DEC-0035` §10 establishes going forward. `DEC-0035` Annex A is a planning list, not authorization; B5 requires its own explicit Product-Lead GO.
- **Automation is not B4.** Any generator, loader, retrieval service, validator, lint or CI check for this format is **Phase C** and requires its own authorization (`DEC-0035` §12). This artifact is static and creates none of them.
- **Not adjudicated here.** The two classification questions `DEC-0035` routed to B3 and B3 declined (the `/context` blanket-versus-table ambiguity; the class of `scope-guardrails.md`) stay open. A pack cites their open status; it does not close them.

---

*Governed by [`DEC-0035`](decisions/DEC-0035-canonical-context-v2-authority-lifecycle-supersession-model.md). Current state is owned by [`current-state.md`](current-state.md); routing by [`context-map.md`](context-map.md). The return-side format remains [`handoff-template.md`](../agents/handoff-template.md), unmodified.*
