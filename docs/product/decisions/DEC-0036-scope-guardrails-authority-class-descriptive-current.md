# DEC-0036 — `docs/product/scope-guardrails.md`: authority class DESCRIPTIVE-CURRENT

**Status:** ACTIVE (binding) · **Date:** 2026-08-20 · **Decision authority:** Product Lead · **Drafted by:** a task-scoped Author, reviewed by a distinct task-scoped independent Reviewer, under the temporary Phase-B execution topology ([[DEC-0035]] §14) · **Ratification gate:** the Product Lead's manual merge of this record
**Scope:** One classification. Adjudicates the authority class, lifecycle and mutability of `docs/product/scope-guardrails.md`; the treatment of the pointer to it from `docs/agents/product-orchestrator-agent.md`:167; the meaning of the phrase *derived scope-admission weight* used in [[DEC-0035]] §9; and the class of the `OD-01`…`OD-07` register embedded in that file. **Docs-only unit.**
**Negative scope — this record does not create or change:** any product scope, MVP admission or exclusion, `OD-*` resolution, database, SQL, migration, role, runner, Compose file, workflow, workflow registration, ruleset, Environment, secret, variable, credential, remote connection, code file, agent contract, agent runtime wiring, `packages/orchestrator/**`, or memory content. It classifies no artifact other than the one it names, promotes none, and demotes none. **No agent is wired and no execution of any kind is authorized.**
**Extends:** [[DEC-0035]] §9 (the `docs/product/*.md` non-decision family row) and [[DEC-0035]] Annex A row 12 — supplying the explicit adjudication both reserved.
**Discharges — by satisfaction, not by replacement:** the classification deferral [[DEC-0035]] §9 left open for this one artifact (*"its class requires explicit B3 adjudication"*). See §4.
**Does not edit:** [[DEC-0035]] or any prior DEC. [[DEC-0001]] … [[DEC-0035]] all remain **frozen and additive-only**; [[DEC-0028]] and [[DEC-0033]] remain **byte-frozen** per [[DEC-0034]] §4. No prior record is declared obsolete, superseded, reopened or reinterpreted here.
**Evidence base — re-derived at the canonical base, not inherited:** `docs/agents/product-orchestrator-agent.md` lines 40, 128, 152–167, 384, 790; `docs/agents/agent-registry.md`:5–7; `docs/agents/README.md`:101; `docs/product/scope-guardrails.md` — its `Mantido por` / `Função` / `Fonte` header lines and its `OPEN DECISIONS conhecidas` table (cited by content, not by line: this unit edits that file, §6.4); [[DEC-0035]] §3.1, §3.2, §3.3, §4, §8, §9, §9.1, §10, Annex A rows 9 and 12; [[DEC-0028]] §8; `context-map.md` §1–§3; `current-state.md` §C and §G. Referenced, not restated.
**Canonical base:** `main` @ `262c71907f24375196d13dc6901f64aa354acfad`

---

## 1. Status

**ACTIVE — binding and prospective**, effective from this record's date. It is a classification, not a grant. It confers no authority on any artifact, withdraws none from any artifact, resolves no `OD-*` item, and authorizes no execution.

---

## 2. Why this record exists

[[DEC-0035]] §9 withheld the `docs/product/*.md` family default from exactly one file, recording that `scope-guardrails.md` *"carries derived scope-admission weight only to the extent the §Source of Truth hierarchy grants it"* and that *"its class requires explicit B3 adjudication"*. Annex A row 12 routed the same question to B3 as a **classification adjudication, not an edit**.

The class does not follow mechanically from landed authority. The `docs/agents/product-orchestrator-agent.md` §*Source of Truth* hierarchy ranks the ten `/context` files it names, and this file is not one of them; meanwhile two `docs/agents/**` surfaces point at it — `product-orchestrator-agent.md`:167 and `agent-registry.md`:7. Whether those pointers confer derived weight on the whole file, on one section, or on nothing is precisely the judgment [[DEC-0035]] reserved. B3 declined it; B5 declined it; `context-map.md` §1 recorded it as `HOLD — PRODUCT-LEAD ADJUDICATION REQUIRED`, escalated and unresolved, because neither unit may supply a classification from a DESCRIPTIVE-CURRENT surface.

**The Product Lead has adjudicated.** This record lands that adjudication and reconciles the surfaces it makes stale.

---

## 3. Decision

### D1 — Classification

`docs/product/scope-guardrails.md` is **`DESCRIPTIVE-CURRENT · CURRENT · EDITABLE`** on the three axes of [[DEC-0035]] §3. **It carries no INTERNAL-NORMATIVE authority of its own.**

This is what the artifact declares itself to be. Its own header names its sources — *"Fonte: `00_Product_Lead_Decision_Log.md`, `01_MVP_Scope_PRD.md` §9/§11, `02_...` §11, `06_...` §6, `07_...` §5"* — which is the signature of a **compilation of rules authored elsewhere**, not of an originating authority. Its `Função` line, *"Em dúvida, este arquivo + o decision log decidem"*, is **imperative wording inside a descriptive artifact and confers no class** ([[DEC-0035]] §3.1): a document does not acquire authority by asserting that it decides. The operative half of that sentence is the decision log, which holds its authority independently of being cited here.

### D2 — The pointer performs no normative incorporation

`docs/agents/product-orchestrator-agent.md`:167 reads: *"Tudo que não está nesta lista está fora do MVP até decisão registrada. Lista completa de fora-de-escopo em `docs/product/scope-guardrails.md`."*

**Sentence 1 is a self-contained rule.** It operates by complement over the PO agent's **own** locked MVP Scope list immediately above it, and is complete without reading any other file. **Sentence 2 is a nominal locative clause** — a noun phrase, a preposition and a path, carrying no verb of incorporation. The contract uses the same *find-the-full-version-here* idiom at lines 40, 128, 384 and 790, and **the comparison holds a fortiori**: four of those five are, like `:167`, purely nominal, while line 40 (*"segue o protocolo completo em `agent-onboarding-orchestration.md`"*) carries a **verb of adherence that `:167` does not** — and [[DEC-0035]] §9 still classifies that target **DESCRIPTIVE-CURRENT**. `context-index.md` is likewise DESCRIPTIVE-CURRENT, and `docs/agents/README.md`'s normative clauses are classified by [[DEC-0035]] §9's **named exception** for that file, which seats them on **its own** self-declaration (*"Modelo vinculante registry-first"*) — not on the pointer at line 384 that names it. (§8 route 3 is the general principle that landed authority outranks a family default; §9 is the actual seat.) **No target of this idiom has ever been promoted by being pointed at.** `agent-registry.md`:7 (*"Ver `docs/product/scope-guardrails.md`"*) is weaker still — a bare pointer, in a file that expressly calls itself *"um **mapa**, não a fonte das regras"*.

The reference is therefore **routing / locative**. It does **not**: (a) incorporate the whole file as normative authority; (b) incorporate the *Não entra no MVP* section as independent normative authority; (c) delegate authority to the file; or (d) create a second normative seat for rules compiled there.

### D3 — `derived scope-admission weight` creates no additional authority class

The phrase in [[DEC-0035]] §9 **introduces no sixth token** alongside the five classes of §3.1. It means only that the file may be **operationally useful for discovering, compiling, navigating and applying** scope constraints whose actual authority originates elsewhere.

> **Required invariant: `DERIVED PRACTICAL / ROUTING WEIGHT ≠ DERIVED NORMATIVE AUTHORITY`.**

**A rule does not become authoritative merely because it is copied, summarized, paraphrased or cited inside `scope-guardrails.md`.** Usefulness is not authority, and neither is completeness, tone, or the fact that another surface routes to it.

### D4 — Authority remains at the governing source

Where the file restates a rule originating in an INTERNAL-NORMATIVE `/context` source, a DEC, or another valid normative authority, **the rule binds because of that original authority**; the restatement acquires no INTERNAL-NORMATIVE class. Operators route to and cite the **governing source**, not the compilation.

**Where compilation and source diverge, do not create an authority conflict.** Only one of the two carries authority, so [[DEC-0035]] §4 P3 does not engage. The compilation is treated as potentially **`STALE-DESCRIPTIVE`** and reconciled through an authorized context-maintenance unit — subject to [[DEC-0035]] §4 P4's prior question, which is whether the descriptive statement is *wrong* or is accurately reporting a state that authority does not endorse. Reality is never falsified to conform to authority.

### D5 — [[DEC-0035]] §9.1 is expressly not generalized

**This record does not establish that "any clause that restates normative authority becomes independently INTERNAL-NORMATIVE inside its containing descriptive file."** §9.1's clause-level mechanism stays scoped to what it addresses — ratified constants inside `DATA-*` files, normative by virtue of the decision record that ratified them — and **no general authority-copy mechanism is created here, for `scope-guardrails.md` or for any other artifact.**

Note the direction §9.1 actually runs: it exists to stop a *whole file* being promoted because one clause of it was ratified elsewhere. Read correctly it reinforces D1; read as a general rule it would invert into the promotion mechanism this record refuses.

### D6 — The embedded `OD-01`…`OD-07` register

The register **travels with the file's `DESCRIPTIVE-CURRENT` class**, unless an individual `OD` row has an independent authoritative source establishing something more specific for that row. It is **not** promoted wholesale to INTERNAL-NORMATIVE, and **not** to EVIDENCE.

Any normative consequence an `OD` row represents must be traced to its **actual governing source** — the record that decided it, not the row that reports it. A stale row is a **descriptive reconciliation problem, not automatically an authority conflict**. In particular, **historical or stale Supabase-era content does not regain force merely by remaining in the register** (§6.4). The two-digit `OD-0N` series remains distinct from every other `OD` namespace per `context-map.md` §2; this record renumbers nothing and closes nothing.

---

## 4. Lifecycle — discharged by satisfaction, not superseded

[[DEC-0035]] §9 did not decide this class and then have that decision replaced. It **withheld** the family default, **reserved** the question, and **required** an explicit adjudication. This record supplies exactly the adjudication §9 called for. §9 named **B3** as the venue and B3 declined; that does not strand the question, because [[DEC-0035]] §8 route 2 defines the mechanism as *"explicit per-file override, recorded by **an authorized unit**"* — an authorized unit, not that unit.

**[[DEC-0035]] is therefore neither SUPERSEDED nor PARTIALLY-SUPERSEDED by this record, and its lifecycle remains CURRENT.**

**The clause that appears to cut the other way, addressed directly.** [[DEC-0035]] §3.2 defines `PARTIALLY-SUPERSEDED` as *"Named clauses replaced, narrowed **or discharged**; the remainder stays CURRENT"*, and this record's own header field reads *Discharges*. **The token matches; the mechanism does not.** The discharge §3.2 contemplates is of a clause's **prospective force** — what [[DEC-0034]] §4 did to [[DEC-0028]] §10's binding condition, whose trigger can now never occur — not the **satisfaction of a requirement to adjudicate**. §9's clause is not spent by being answered: after this record it remains exactly true that this one file takes no `docs/product/*.md` family default and takes its class by explicit adjudication instead. That is precisely the test §3.2's *"the remainder stays CURRENT"* presupposes, and here **nothing was removed for a remainder to be left of**.

**The precedent is landed, and it is [[DEC-0035]]'s own.** §9's reading note resolves the `/context` blanket-versus-table ambiguity and classifies its own result as *"a classification judgment, not a supersession"*, adding that *"the blanket sentence is not edited, narrowed or declared wrong"*. The record being discharged here therefore already establishes **adjudication-without-supersession** as a distinct operation in this model. This record does the same thing to §9 that §9 did to the blanket sentence: answers a classification question, edits nothing, narrows nothing, and declares nothing wrong.

---

## 5. Forward discoverability

[[DEC-0035]] §10 requires every record that discharges earlier authority to **create the forward-discoverability update in the same authorized unit**. [[DEC-0035]] is **FROZEN** and this unit is not authorized to append to it, so the pointer is created **externally**, as §10 directs for that case: a `DEC-0036 → DEC-0035` row in the relation table at `docs/product/context-map.md` §3, scoped to this discharge. **This unit is incomplete without that row.**

---

## 6. Reconciliation performed by this unit

Bounded to what this decision makes stale. Additive where the surface is historical; no history is rewritten.

1. **`context-map.md`** — the §1 routing row and the §2 `OD-01`…`OD-07` row now carry the landed class; the §1 adjudication bullet, which described `:167` as incorporating the out-of-scope list *by reference*, is corrected to D2; the §3 relation-table row required by §5 is added.
2. **`current-state.md`** §G — the `HOLD — PRODUCT-LEAD ADJUDICATION REQUIRED` paragraph is replaced by the landed outcome. §H recorded no such open item and is untouched.
3. **`task-context-pack.md`** §6 — noted **additively**, so that packs cite the resolved status rather than the open one. B4's body is not rewritten.
4. **`scope-guardrails.md`** — two bounded repairs. EDITABLE mutability says an **authorized** unit may revise the file; it is not itself the authorization, so each repair is justified on the *materially misroutes* finding that admits it. (a) A classification header stating what D1 lands, and that the `Função` line — *"Em dúvida, este arquivo + o decision log decidem"* — confers no authority. **This decision is what makes that line misroute:** a reader arriving at the file directly, without `context-map.md`, would take a file just classified as carrying no authority of its own to be one that decides. Leaving the single most misrouting sentence unmarked while repairing a lesser one would not be restraint. (b) an **additive** forward note on the `OD-02` row, whose *"Resolvida → Supabase Auth (DEC-0005)"* text is preserved verbatim while pointing at [[DEC-0028]] — under which [[DEC-0005]] is SUPERSEDED ([[DEC-0035]] §9) and Supabase is permanently retired (`current-state.md` §C) — and at [[DEC-0028]] §8 `OD-6` (*future authentication provider and mechanism*), which is **open**. The note **reopens nothing, closes nothing and selects no provider**; it exists so that a retired resolution does not read as current.

---

## 7. Routed, not solved here

**The `Entra no MVP` enumeration difference.** `scope-guardrails.md` lists *"Admin mínimo"* and *"Observabilidade: eventos de produto + erros técnicos (Sentry)"*; neither appears in the PO agent's locked MVP Scope list, whose sentence 1 places anything absent from that list *"fora do MVP até decisão registrada"*.

**This is not an authority conflict — and the two entries are not grounded alike, which this record states rather than smooths over.** **Sentry is grounded in a declared source:** the `Fonte:` line declares `00_Product_Lead_Decision_Log.md` **without section restriction**, and it carries *"**Observabilidade:** Sentry primeiro"* (:228). **`Admin mínimo` is not.** Its nearest support sits at `02_Stack_Infra_Architecture.md` **§7** (*API surface do MVP*) and `06_Execution_RACI_Backlog.md` **§3** (*Backlog MVP* — PL-003, Epic 5), and **neither section is declared**: the `Fonte:` line restricts `02` to §11 and `06` to §6. The declared PRD grounds neither entry — `01_MVP_Scope_PRD.md` contains **no occurrence** of *admin*, *Sentry* or *observabilidade*.

**The disposition is unchanged: no demonstrable stale-descriptive defect, no edit, and the question is routed, not decided.** An entry that falls outside the compilation's declared sources is not thereby wrong — the declaration bounds what the file claims to compile, not what the Product Lead has decided. Whether the PO agent's locked list under-enumerates, or the compilation over-includes, is a **product-scope question reserved to the Product Lead**, not a documentation repair. Under D1 and D4 the compilation binds nothing either way; sentence 1 governs on its own terms.

**Structural observation for whoever takes that question — the asymmetry, not either entry, is the finding.** **Every section-restricted source the `Fonte:` line declares is an exclusion or deferral section**: `01` §9 *Fora de escopo do MVP*, `01` §11 *Fase 2 prevista, mas não construída agora*, `02` §11 *O que NÃO entra na infra do MVP*, `06` §6 *P2 / Fase 2*, `07` §5 *Decisões futuras condicionadas*. Consequently the file's `Não entra` and `Entra apenas na Fase 2` lists rest on **five declared section sources**, while its **`Entra no MVP` list rests on `00_…` alone** — the one source declared without restriction. The compilation is far better sourced on what it excludes than on what it admits.

**Not adjudicated here:** the class of any other `docs/product/*.md` artifact; any `OD-*` resolution; the `/context` blanket-versus-table reading ([[DEC-0035]] §9 reading note), which `context-map.md` §1 records as carrying no residual routing consequence.

---

## 8. Explicit non-decisions

This record does **not** and must not be read to: change product scope · admit or exclude any MVP item · close, reopen or renumber any `OD-*` identifier · classify, promote or demote any artifact other than the one it names · establish a general authority-copy mechanism (D5) · edit, supersede or reinterpret [[DEC-0035]] or any prior DEC · edit anything under `docs/agents/**` · authorize B6 · close Phase B · authorize any Phase-C work · authorize any commit, push, PR, merge or execution of any kind.

---

*Related: [[DEC-0035]] §9 and Annex A row 12 (the reserved adjudication), §3.1 (imperative wording confers no class), §3.2 (lifecycle vocabulary), §4 P3/P4 (conflict versus divergence), §9.1 (clause-level normativity, not generalized), §10 (forward discoverability); [[DEC-0028]] §8 `OD-6` (future authentication provider, open); [[DEC-0034]] §4 (byte-frozen supersession scoping). Routing surfaces reconciled: [`context-map.md`](../context-map.md), [`current-state.md`](../current-state.md), [`task-context-pack.md`](../task-context-pack.md).*

---

## Additive forward-status note — appended by `C5` Limb A, 2026-08-21

**This is a clearly-marked additive forward-status note, appended by an authorized unit under [[DEC-0035]] §3.3** — which permits exactly that on a `FROZEN` record, and reserves the stricter **byte-frozen** grade to [[DEC-0028]] and [[DEC-0033]] alone. It is appended by `PHASE-C-C5-MECHANICAL-ENFORCEMENT-R1` and carried by [[DEC-0041]] §7. **Nothing above this line is edited, rewritten, revoked, weakened, narrowed or reopened.** D1–D6 stand exactly as landed, and this record remains **`FROZEN`** and **`ACTIVE / CURRENT`**.

### What this repairs — and what it refuses to do

[[DEC-0040]] §7 verified that `C2`'s two-line reconciliation note shifted every line of `docs/agents/product-orchestrator-agent.md` below its insertion point by `+2`, and [[DEC-0040]] §9 routed the repair to `C5` Limb A. **The defect is a stale locator, not an authority defect** ([[DEC-0040]] D15): a pointer moved, no normative requirement and no descriptive claim is in tension, and this is therefore **not** a `STATE-AUTHORITY DIVERGENCE` ([[DEC-0035]] §4 P4). D15 directs repair at the **citing** end, and that is what this note is. **Neither endpoint is edited to fit:** this record's body is untouched, and the cited file is never edited to make an old number true again.

### The three references, given durable identity

§*Evidence base* (header) and **D2** cite `docs/agents/product-orchestrator-agent.md` at *"lines 40, 128, 384 and 790"* as four instances of one *find-the-full-version-here* idiom. **`:40` carries its quotation** and resolves on the quoted text. The other three carried **no quotation and no named anchor**, and [[DEC-0040]] §7 classified them **`UNRESOLVED — LOCATOR ONLY`**.

Each is given its durable identity below — **stable path + stable named section + verbatim quotation** — **re-derived by `C5` directly from the file** at `main` @ `f88e5ca84bc510adb7f9717e2e20296c8830b2d8`, not inherited from any prior reading.

| Historical / stale locator | Durable identity — **this is now the semantic identity** | Convenience locator at the `C5` base |
|---|---|---|
| `:128` | §*Source of Truth*, **opening paragraph**: *"Os documentos em `/context` são a fonte da verdade. Índice operacional completo: `docs/product/context-index.md`."* | `:130` |
| `:384` | §*Agent Interaction Model*, **opening paragraph**, closing sentence: *"Catálogo em `docs/agents/README.md`."* | `:386` |
| `:790` | §*Output Format* › §*Decision sequencing*, **the closing line beneath that subsection's `Regras:` list**: *"Protocolo completo: `docs/agents/agent-onboarding-orchestration.md`."* | `:804` |

**The drift is cumulative, and the arithmetic is stated so this note reconciles on its own terms.** `C2`'s `+2` is not the whole of it: [[DEC-0040]] §7 discloses that `C4` added a further `+12` below `:686`, so **`:128` and `:384` moved by `+2` while `:790` moved by `+14`** — which is why the third row reads `:804` and not `:802`. **No third edit is implied and no further drift is introduced**; the two shifts are simply not the same size, and a reader checking the table against `+2` alone would otherwise be right to think it wrong.

**A reader who has never seen the historical line positions can establish all three from the section name and the quotation alone.** That is the test D15 sets, and meeting it is what closes the debt.

### How the record reads from here

> **The named section and the quoted text govern. The number is a convenience** ([[DEC-0040]] D15).

The three old numbers remain in the header and in D2 **exactly as written** and are now to be read as **`HISTORICAL / STALE LOCATOR`** — recorded, never the identity.

### D2's argument is confirmed, not reopened

Re-derivation confirms each of the three propositions is what D2 said it was: a **purely nominal** *find-the-full-version-here* pointer — a noun phrase, a preposition and a path, with **no verb of incorporation** — so D2's *a fortiori* comparison against the pointer at `:167` holds exactly as landed, and the contrast with the one instance that does carry a verb of adherence is undisturbed. **No conclusion of D1–D6 depends on any line number.**

**Not repaired here, because nothing is broken.** The `:167` citation is **rescued by quotation** in §*Scope*, §2 and D2 (its convenience locator at this base is `:169`); the range at `:152–167`, `agent-registry.md`:5–7 and `README.md`:101 are outside the routed four and are not touched. [[DEC-0035]] §9's reading note cites the same `:128` **with** its quotation and is likewise rescued rather than repaired — and [[DEC-0035]] is not amended by this unit in any event.

### Explicit non-effects

This note **does not**: change any classification · promote or demote any artifact · resolve, reopen or renumber any `OD-*` item · create any citation obligation for any other record ([[DEC-0040]] D15 *"creates no general citation framework"* and imposes no retroactive obligation) · edit any file under `docs/agents/**` · authorize any execution of any kind.

*Related: [[DEC-0040]] D15 (evidence-reference durability), §7 (the verified drift finding and the Limb-A routing), §9; [[DEC-0035]] §3.3 (FROZEN admits a clearly-marked additive forward-status note), §4 P4; [[DEC-0041]] §7 (the authorizing record for this note and the prospective control that succeeds it).*
