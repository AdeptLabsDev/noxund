# PG-EXIT · P3C · EXECUTE-PRE · PIP-INSTALLED-TREE-SEMANTICS · S1-PREP-R8

**Unit:** `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R8-RULES-HASH-VALIDATION-PLAN-AND-WHEEL-METADATA-GRAMMAR-CORRECTIVE`
**Type:** source-preparation corrective — **PREPARED, NOT EXECUTED**.
**Authored:** 2026-08-07 · NOXUND Product Orchestrator.

## 1. Disposition

```
PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R8-PASS-SOURCE-PREPARED-AWAITING-INDEPENDENT-PRODUCT-REVIEW
```

```
AUTHOR-SELF-CHECK-R8 = COMPLETE-NON-AUTHORITATIVE
```

Recommendation:

```
PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R8
```

A preparation PASS means only that all authorized files were authored, structural self-checks completed, and the unit is ready for **independent Product review**. It is **not** `INSPECTOR-SOURCE-REVIEW-R8 = PASS`. Do not recommend parser-validation preparation yet.

## 2. Authoritative history carried into R8 (preserved, unchanged)

```
PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R5 = HOLD-RECORD-ZIP-VERSION-AND-VALIDATION-PLAN-CONTRACT-FAILED
PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R6 = RED-UNAUTHORIZED-PROJECT-MEMORY-MUTATION
R6-GOVERNANCE-REPAIR-R1                 = ACCEPTED-UNAUTHORIZED-MEMORY-MUTATIONS-EXACTLY-REVERTED
R6-CORRECTION-4                         = RESOLVED-BY-PRODUCT-INFOZIP-PRESENCE-POLICY-RULING
PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R7 = HOLD-RULES-HASH-VALIDATION-PLAN-AND-WHEEL-METADATA-GRAMMAR-FAILED
INSPECTOR-SOURCE-REVIEW-R7              = REJECTED-INTERNAL-BINDING-AND-STANDARDS-FALSE-GREENS
R7-BUNDLE-INTEGRITY                     = ACCEPTED
R7-HISTORICAL-CASE-COVERAGE             = ACCEPTED-64-OF-64-PRESERVED
R7-VALIDATION-PLAN                      = REJECTED-ACTUAL-93-NOT-94
GOV-S1-PREP-R3-01                       = OPEN-PREEXISTING-PARTIAL-ROOT-PROVENANCE-UNPROVEN
RBF-15 = OPEN   ·   RBF-04 = OPEN
```

No Orchestrator preparation PASS is inherited as a source acceptance. R8 performs **zero** project-memory writes.

## 3. R7 direct identities (bound)

| subject | size | SHA-256 |
|---|---|---|
| R7 repository document | `11586` | `26704a97f11bf7dade70bd1e8233b8c2ec220ca57763d825c2e3e23489844a3d` |
| R7 inspector | `117278` (2458 lines) | `c8bf2f65843ef5d41f691d31841f1225e5be6fb1b8aed41b2f6495ad3dfca9da` |
| R7 root SHA256SUMS | `2767` (replay 26/26) | `fee3ec54d0969a9c331facd7200eab8e6be6203b3d38788cbd4ff3ca0413d608` |
| Product-review ZIP (packaging evidence only) | `90252` | `0f84343ddaec472c3e9e7fe9579813e0e3b2a5a452f090f22f4ba8c623e537d9` |

## 4. Proof both R8 paths were absent before writing

Before any read or write, both were checked **ABSENT**: `C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-s1-prep-r8` (no directory, no sibling) and this repository document. No preexisting R8 artifact was adopted.

## 5. The two R7 fatal defects, fixed

- **Internal binding (Correction A).** The R7 inspector kept the stale R5 constant `QUESTION_RULES_SHA256 = 35c63e91…` while the actual R7 rules hashed to `5858e022…`, so `load_rules()` compared the real rules against the stale constant and deterministically reached `HOLD-RULES-CONTRACT` on R7's own rules. R8 sets the constant to the **actual R8 rules hash** and proves complete closure.
- **Validation-plan integrity (Corrections B/H).** R7 declared `case_count = 94` but actually contained **93** cases / **29** new; the coverage ledger reached 94 only by counting a non-case `SUMMARY` row. R8 makes `declared == len(cases) == unique == 100` programmatically checkable, with the coverage ledger carrying exactly 100 case rows.

## 6. Contract-hash closure (Correction A)

```
actual contracts/S1-QUESTION-RULES.json  = 5ac01cdeb2eedcf7617d4e258eec5a09d3d807402cff53101c0809b9a8c62fb5
inspector QUESTION_RULES_SHA256          = 5ac01cdeb2eedcf7617d4e258eec5a09d3d807402cff53101c0809b9a8c62fb5
S1-PARSER-CONTRACT question_rules_sha256 = 5ac01cdeb2eedcf7617d4e258eec5a09d3d807402cff53101c0809b9a8c62fb5
prior-evidence-bindings-r8               = 5ac01cdeb2eedcf7617d4e258eec5a09d3d807402cff53101c0809b9a8c62fb5
=> ALL FOUR EQUAL.  Stale 35c63e91… (R5) and 5858e022… (R7) appear ONLY as explicitly-historical labels.
```
Full matrix: `evidence/contract-hash-closure-r8.json`.

## 7. Validation-plan integrity (Corrections B/H)

`declared case_count == len(cases) == unique case IDs == 100`; a SUMMARY row is metadata, not a case. Counts: `historical R4∪R5 = 64` (R4=33, R5=33, shared 2 = `TAR-DATA-AFTER-EOF`, `PATHMAP-HASH-MISMATCH`) · `R7-new = 29` · `retained R7 = 93` · `R8-new = 7` · `final = 100` · `unexplained removed = 0`. The coverage ledger (`validation-plan-coverage-ledger-r8.tsv`) has **exactly 100 case rows** — R4=33, R5=33, NEW-R8=7, OUTCOME-CORRECTED-BY-PRODUCT=1, PRESERVED-SEMANTICALLY=92. Integrity record: `evidence/validation-plan-integrity-r8.json`.

## 8. The R8 corrections

- **C** RECORD exact value preservation: `_canonical_b64_digest` no longer strips; the self-row requires **literal** `digest==""` and `size==""` (quoted whitespace is nonempty → HOLD). New cases `RECORD-DIGEST-QUOTED-WHITESPACE`, `RECORD-SELF-ROW-QUOTED-WHITESPACE`.
- **D** WHEEL Tag: each `Tag:` header carries **one expanded triple** with single-token components; a dot-compressed set inside a component → `HOLD-WHEEL-HEADER-PARSE`. The historical `WHEEL-TAG-COMPRESSED-SET-VALID` is **outcome-corrected** ACCEPT→HOLD (`HISTORICAL-CASE-OUTCOME-CORRECTED-BY-PRODUCT-WHEEL-SPEC-RULING`; ID preserved, not renamed/removed). New positive case `WHEEL-MULTI-EXPANDED-TAGS-VALID`.
- **E** Core Metadata versions `{1.0,1.1,1.2,2.1,2.2,2.3,2.4,2.5}`; `2.0` removed. New cases `METADATA-VERSION-2.0-INVALID`, `METADATA-VERSION-2.5-VALID`; 2.5-only fields inventoried, never static proof.
- **F** WHEEL field space **closed** (unknown WHEEL field → HOLD; new case `WHEEL-UNKNOWN-FIELD`); METADATA enforces a bounded singleton subset only, others `INVENTORIED-NOT-SEMANTICALLY-VALIDATED`.
- **G** ZIP creator spec version must be `>= version-needed` and `>= method minimum`. New case `ZIP-MADEBY-CREATOR-BELOW-NEEDED`.
- **I** author self-check `COMPLETE-NON-AUTHORITATIVE`.

## 9. R8 inspector identity

| field | value |
|---|---|
| path | `inspector/pip-installed-tree-source-inspector-s1-r8.py` |
| size | `118405` |
| lines | `2470` |
| SHA-256 | `ddbc42cd77c0ba7abeb5c24dc895a28ebf0a79103aeba4706504db3268de3493` |
| imports | standard library only; no `tarfile`/`zipfile`/`ast`/`subprocess`/`re` |

## 10. Byte-identical carry-forward + question rules

- Subject manifest `contracts/S1-SUBJECT-MANIFEST.json` — **byte-identical** `d41618d9932b95f4cee41da3efa33f235bd9de63d2c3163f648318e870fb6e1c`.
- Question contract `contracts/S1-QUESTION-CONTRACT.tsv` — **byte-identical** `c85e29436dfe50694685bb1e106a9009a3e9b5fb958e2d132fc4a328f17ba69d`.
- Question rules `contracts/S1-QUESTION-RULES.json` — current R8 identity `5ac01cdeb2eedcf7617d4e258eec5a09d3d807402cff53101c0809b9a8c62fb5` (unit token bumped to R8; rule semantics unchanged), equal to the inspector constant and both bindings.

## 11. Preparation-root inventory

Root: `C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-s1-prep-r8` — **28 manifest-covered files** (1 inspector + 14 contracts + 13 evidence) + `SHA256SUMS`, **4 directories**, matching the authorized structure exactly. No other path created.

## 12. SHA256SUMS identity and replay

`SHA256SUMS` — size `2951`, SHA-256 `e7d9f5f6e5ce57a3a3d325935facda60bde38810ce79ffe0fe3c927c1cf69877`, **28 entries** (excludes itself), replay **28/28 OK**. 21/21 JSON files validated well-formed (the inspector was **not** parsed/compiled).

## 13. Repository-document size and SHA-256

This document — see the accompanying orchestrator return for its exact byte size and SHA-256 (computed after write). `docs/result` untouched.

## 14. Source / main / spike / body / memory states

| item | state |
|---|---|
| main HEAD | `4873ac713397cf47642d39b1ef17e48a9301511d` (unchanged) |
| spike HEAD (`spike/pg-exit-p3c-execute-pre`) | `4873ac713397cf47642d39b1ef17e48a9301511d` (unchanged) |
| R8 prep root | ABSENT → CREATED (28 files + SHA256SUMS; replay 28/28) |
| R8 repository document | ABSENT → CREATED (this file) |
| R1–R5, R7 roots + documents; aborted-R6 (no root) | PRESERVED / UNCHANGED |
| design bundles, lock, governance/acquisition/ARTIFACT-INSPECT evidence | PRESERVED / UNCHANGED |
| every `.deb`/`.whl` body, image archive, known `.rar` | UNCHANGED (never opened/listed/hashed/parsed) |
| project memory | UNMODIFIED (zero writes this session) |

## 15. Prohibition confirmations

No project-memory write / index / durable-state note; no automatic end-of-session memory write; no inspector executed/imported/compiled/byte-compiled/AST-parsed; no synthetic fixture created/executed; no real `.deb`/`.whl`/image/`.rar` body opened/listed/hashed/parsed; no subject-path map; no PARSER-VALIDATION-PREP/EXECUTE; no S1-EXECUTE; no isolation/collector/builder-context; no Docker/network/PostgreSQL/Supabase; no BUILD-PREP; nothing staged/committed; no PR; no temp/backup/cache/sidecar/placeholder path; `docs/result` untouched.

## 16. Exact next recommendation

```
PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R8
```

On acceptance, the next eligible gate is only **PARSER-VALIDATION-PREP-R1**, then **PARSER-VALIDATION-EXECUTE-R1** (execute the accepted inspector against the accepted fixtures across the 100-case plan), then **S1-EXECUTE** against the six real bodies (isolated spike branch). All remain **NOT AUTHORIZED**; `BUILD-PREP = HOLD`. `RBF-15`, `RBF-04`, `GOV-S1-PREP-R3-01` remain OPEN. Preparation stops at S1-PREP-R8.
