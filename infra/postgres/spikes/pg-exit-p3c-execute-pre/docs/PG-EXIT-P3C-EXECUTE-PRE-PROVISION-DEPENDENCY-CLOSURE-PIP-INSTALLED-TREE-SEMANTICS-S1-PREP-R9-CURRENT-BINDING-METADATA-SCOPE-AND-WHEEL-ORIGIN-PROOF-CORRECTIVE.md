# PG-EXIT · P3C · EXECUTE-PRE · PIP-INSTALLED-TREE-SEMANTICS · S1-PREP-R9

**Unit:** `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R9-CURRENT-BINDING-METADATA-SCOPE-AND-WHEEL-ORIGIN-PROOF-CORRECTIVE`
**Type:** source-preparation corrective — **PREPARED, NOT EXECUTED**.
**Authored:** 2026-08-07 · NOXUND Product Orchestrator.

## 1. Disposition

```
PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R9-PASS-SOURCE-PREPARED-AWAITING-INDEPENDENT-PRODUCT-REVIEW
```

```
AUTHOR-SELF-CHECK-R9 = COMPLETE-NON-AUTHORITATIVE
```

Recommendation:

```
PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R9
```

A preparation PASS means only that all authorized files were authored, structural self-checks completed, and the unit is ready for **independent Product review**. It is **not** `INSPECTOR-SOURCE-REVIEW-R9 = PASS`. The Product Lead remains the sole source-acceptance authority. Do not recommend parser-validation preparation yet.

## 2. Authoritative history carried into R9 (preserved, unchanged)

```
S1-PREP-R5 = HOLD-RECORD-ZIP-VERSION-AND-VALIDATION-PLAN-CONTRACT-FAILED
S1-PREP-R6 = RED-UNAUTHORIZED-PROJECT-MEMORY-MUTATION
R6-GOVERNANCE-REPAIR-R1 = ACCEPTED-UNAUTHORIZED-MEMORY-MUTATIONS-EXACTLY-REVERTED
R6-CORRECTION-4 = RESOLVED-BY-PRODUCT-INFOZIP-PRESENCE-POLICY-RULING
S1-PREP-R7 = HOLD-RULES-HASH-VALIDATION-PLAN-AND-WHEEL-METADATA-GRAMMAR-FAILED
S1-PREP-R8 = HOLD-CURRENT-UNIT-BINDINGS-METADATA-SCOPE-AND-WHEEL-ORIGIN-PROOF-FAILED
INSPECTOR-SOURCE-REVIEW-R8 = REJECTED-CONTRACT-COHERENCE-AND-STATIC-PROOF-GAPS
GOV-S1-PREP-R3-01 = OPEN-PREEXISTING-PARTIAL-ROOT-PROVENANCE-UNPROVEN
RBF-15 = OPEN   ·   RBF-04 = OPEN
```

Accepted R8 facts preserved (not regressed): `R8-BUNDLE-INTEGRITY`, `R8-QUESTION-RULES-HASH-CLOSURE`, `R8-VALIDATION-PLAN-CARDINALITY = 100/100`, `R8-R7-CASE-PRESERVATION = 93/93`, `R8-HISTORICAL-R4-R5-COVERAGE = 64/64`, WHEEL-Tag-expansion, Core-Metadata 2.0/2.5, ZIP creator-version, RECORD quoted-whitespace. No Orchestrator preparation PASS is inherited as source acceptance. R9 performs **zero** project-memory writes.

## 3. R8 direct identities (bound)

| subject | size | SHA-256 |
|---|---|---|
| R8 Product-review ZIP | `95492` | `3b93b0d28f65c7d2741f4ed9bed3159a00334f076c720126eb09362b833e3453` |
| R8 repository document | `9668` | `feb9274ac58293737c242086e66fb38cec5fef7d69af46fd628b18422a18143e` |
| R8 inspector | `118405` (2470 lines) | `ddbc42cd77c0ba7abeb5c24dc895a28ebf0a79103aeba4706504db3268de3493` |
| R8 root SHA256SUMS | `2951` (replay 28/28) | `e7d9f5f6e5ce57a3a3d325935facda60bde38810ce79ffe0fe3c927c1cf69877` |

## 4. Proof both R9 paths were absent before writing

Before any read or write, both were checked **ABSENT**: `C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-s1-prep-r9` (no directory, no sibling) and this repository document. No preexisting R9 artifact was adopted.

## 5. The six R8 defects, fixed

- **A — current-unit reference closure** (R8-CONTRACT-01 + R8-CONTRACT-02). The validation plan kept current R7 metadata (`r7_state`, `"R7 creates…"`, gate `"R7 (source)"`) and a `coverage_rule` pointing at a **nonexistent** `evidence/validation-plan-coverage-ledger-r7.tsv`; the extra-field policy `inspector_binding` pointed at the **R7** inspector. R9 makes every current binding reference R9 artifacts; historical references are explicitly `HISTORICAL-NON-RUNTIME-BINDING` (`evidence/current-unit-reference-closure-r9.json`).
- **B — one coherent metadata disposition model** (R8-METADATA-01). R8 marked the whole METADATA member `SEMANTICALLY-VALIDATED` after validating only a subset, with three incoherent ladders. R9 uses one model: member ladder `{INVENTORIED, DECODED, BOUNDED-SEMANTIC-VALIDATION (METADATA), SEMANTICALLY-VALIDATED-CLOSED-FIELD-SET (WHEEL)}`; a new field-level `wheel-header-fields.tsv.semantic_disposition ∈ {IDENTITY-SEMANTICS-VALIDATED, BOUNDED-MULTIPLICITY-VALIDATED, PRESERVED-OUT-OF-S1-SCOPE-NON-PROOF}`. Exact enum equality across inspector + `S1-OUTPUT-SCHEMA` + `S1-PARSER-CONTRACT` + `S1-WHEEL-METADATA-POLICY` (`evidence/metadata-output-coherence-r9.json`); an out-of-scope field never supports a static S1 predicate.
- **C — WOP-01 original path** (R8-SEMANTIC-01). The origin TSV now carries BOTH `original_raw_wheel_path` (directly observed reconciled raw filename bytes; a directory keeps its trailing `/`) and `normalized_wheel_path`. WOP-01 is STATICALLY-SUPPORTED only when every structural member has one origin row carrying its raw path; WOP-04 still uses the normalized path.
- **D — mandatory RECORD** (R8-WHEEL-01). A wholly absent `dist-info/RECORD` now fails closed → `HOLD-WHEEL-RECORD-RECONCILE`. The syntax-vs-semantic distinction remains inside an existing RECORD.
- **E — wheel-context metadata minimum** (R8-WHEEL-02). Two distinct sets: GENERAL `{1.0,1.1,1.2,2.1,2.2,2.3,2.4,2.5}` and WHEEL-ACCEPTED `{1.1,1.2,2.1,2.2,2.3,2.4,2.5}`. Inside a wheel, `Metadata-Version: 1.0` → `HOLD-WHEEL-METADATA-IDENTITY` (wheel-context-specific; 1.0 not relabelled globally illegal).
- **F — preserve accepted R8 work.** No regression across the accepted R8 facts.

## 6. Contract-hash closure (H_R9)

```
actual contracts/S1-QUESTION-RULES.json  = 46bbf004d495b364a2c7e52d983a8645fd286eb1afd7afb34f35ed5af597dde5
inspector QUESTION_RULES_SHA256          = 46bbf004d495b364a2c7e52d983a8645fd286eb1afd7afb34f35ed5af597dde5
S1-PARSER-CONTRACT question_rules_sha256 = 46bbf004d495b364a2c7e52d983a8645fd286eb1afd7afb34f35ed5af597dde5
prior-evidence-bindings-r9               = 46bbf004d495b364a2c7e52d983a8645fd286eb1afd7afb34f35ed5af597dde5
=> ALL FOUR EQUAL. Historical 35c63e91…(R5)/5858e022…(R7)/5ac01cde…(R8) are historical-only. (evidence/contract-hash-closure-r9.json)
```
The current value is the genuine hash of the R9 rules bytes — not copied from R8.

## 7. Validation-plan integrity (104 cases)

`declared case_count == len(cases) == unique case IDs == coverage-ledger case rows == 104`. Counts: `100` retained R8 IDs (containing 64 historical R4/R5 + 29 R7-new + 7 R8-new) + `4` new R9 IDs (`WOP01-DIRECTORY-RAW-PATH-PRESERVED`, `WHEEL-RECORD-MISSING`, `WHEEL-METADATA-VERSION-1.0-INVALID`, `METADATA-OUT-OF-S1-SCOPE-FIELD-NONPROOF`); zero removed/renamed; all 100 R8 IDs `PRESERVED-SEMANTICALLY` (no R9 outcome corrections directed). `evidence/validation-plan-integrity-r9.json` + `evidence/validation-plan-coverage-ledger-r9.tsv`.

## 8. R9 inspector identity

| field | value |
|---|---|
| path | `inspector/pip-installed-tree-source-inspector-s1-r9.py` |
| size | `120398` |
| lines | `2495` |
| SHA-256 | `697bdfc341ceddb6c7da4b20567cfbe0923285952c1c43ade192538f5c1c097a` |
| imports | standard library only; no `tarfile`/`zipfile`/`ast`/`subprocess`/`re` |

## 9. Byte-identical carry-forward + question rules

- Subject manifest `contracts/S1-SUBJECT-MANIFEST.json` — byte-identical `d41618d9932b95f4cee41da3efa33f235bd9de63d2c3163f648318e870fb6e1c`.
- Question contract `contracts/S1-QUESTION-CONTRACT.tsv` — byte-identical `c85e29436dfe50694685bb1e106a9009a3e9b5fb958e2d132fc4a328f17ba69d`.
- Question rules `contracts/S1-QUESTION-RULES.json` — current R9 identity `46bbf004d495b364a2c7e52d983a8645fd286eb1afd7afb34f35ed5af597dde5` (unit token bumped to R9; rule semantics unchanged), equal to the inspector constant and both bindings.

## 10. Preparation-root inventory

Root — **29 manifest-covered files** (1 inspector + 14 contracts + 14 evidence) + `SHA256SUMS`, **4 directories**, matching the authorized structure exactly. No other path created.

## 11. SHA256SUMS identity and replay

`SHA256SUMS` — size `3054`, SHA-256 `19d5359d25528356666ef06b3852d211198f03ff51d4ea9971ad302db08ea272`, **29 entries** (excludes itself), replay **29/29 OK**. 22/22 JSON files validated well-formed (the inspector was **not** parsed/compiled).

## 12. Repository-document size and SHA-256

This document — see the accompanying orchestrator return for its exact byte size and SHA-256 (computed after write). `docs/result` untouched.

## 13. Source / main / spike / body / memory states

| item | state |
|---|---|
| main HEAD | `4873ac713397cf47642d39b1ef17e48a9301511d` (unchanged) |
| spike HEAD (`spike/pg-exit-p3c-execute-pre`) | `4873ac713397cf47642d39b1ef17e48a9301511d` (unchanged) |
| R9 prep root + repository document | ABSENT → CREATED (29 files + SHA256SUMS; replay 29/29) |
| R1–R5, R7, R8 roots + documents; aborted-R6 (no root) | PRESERVED / UNCHANGED |
| design bundles, lock, governance/acquisition/ARTIFACT-INSPECT evidence | PRESERVED / UNCHANGED |
| every `.deb`/`.whl` body, image archive, known `.rar` | UNCHANGED (never opened/listed/hashed/parsed) |
| project memory | UNMODIFIED (zero writes this session) |

## 14. Prohibition confirmations

No project-memory write / index / durable-state note; no automatic end-of-session memory write; no inspector executed/imported/compiled/byte-compiled/AST-parsed; no synthetic fixture created/executed; no real `.deb`/`.whl`/image/`.rar` body opened/listed/hashed/parsed; no subject-path map; no PARSER-VALIDATION-PREP/EXECUTE; no S1-EXECUTE; no isolation/collector/builder-context; no Docker/network/PostgreSQL/Supabase; no BUILD-PREP; nothing staged/committed; no PR; no temp/backup/cache/sidecar/placeholder path; `docs/result` untouched.

## 15. Exact next recommendation

```
PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R9
```

On acceptance, the next eligible gate is only **PARSER-VALIDATION-PREP-R1**, then **PARSER-VALIDATION-EXECUTE-R1** (execute the accepted inspector against the accepted fixtures across the 104-case plan), then **S1-EXECUTE** against the six real bodies (isolated spike branch). All remain **NOT AUTHORIZED**; `BUILD-PREP = HOLD`. `RBF-15`, `RBF-04`, `GOV-S1-PREP-R3-01` remain OPEN. Preparation stops at S1-PREP-R9.
