# PG-EXIT · P3C · EXECUTE-PRE · PIP-INSTALLED-TREE-SEMANTICS · S1-PREP-R7

**Unit:** `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R7-RECORD-ZIP-VERSION-VALIDATION-PLAN-AND-EXTRA-POLICY-CORRECTIVE`
**Type:** source-preparation corrective — **PREPARED, NOT EXECUTED**.
**Authored:** 2026-08-07 · NOXUND Product Orchestrator.

## 1. Disposition

```
PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R7-PASS-SOURCE-PREPARED-AWAITING-INDEPENDENT-PRODUCT-REVIEW
```

```
AUTHOR-SELF-CHECK-R7 = COMPLETE-NON-AUTHORITATIVE
```

Recommendation:

```
PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R7
```

A preparation PASS means only that all authorized files were authored, structural self-checks completed, and the unit is ready for **independent Product review**. It does **not** mean the inspector source is accepted. This is not `INSPECTOR-SOURCE-REVIEW-R7 = PASS`. Do not recommend parser-validation preparation yet.

## 2. Governance state carried into R7

```
PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R5 = HOLD-RECORD-ZIP-VERSION-AND-VALIDATION-PLAN-CONTRACT-FAILED
INSPECTOR-SOURCE-REVIEW-R5              = REJECTED-FALSE-GREEN
R5-BUNDLE-INTEGRITY                     = ACCEPTED
PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R6 = RED-UNAUTHORIZED-PROJECT-MEMORY-MUTATION   (historical; NOT rewritten to PASS)
R6-GOVERNANCE-REPAIR-R1                 = ACCEPTED-UNAUTHORIZED-MEMORY-MUTATIONS-EXACTLY-REVERTED
GOV-S1-PREP-R6-01                       = RESOLVED-EXACT-UNAUTHORIZED-MEMORY-MUTATIONS-REVERTED
GOV-S1-PREP-R6-02                       = RESOLVED-PRIOR-SESSION-REPORT-REJECTED-AND-STATE-INDEPENDENTLY-REESTABLISHED
R6-CORRECTION-4                         = RESOLVED-BY-PRODUCT-INFOZIP-PRESENCE-POLICY-RULING
RBF-15 = OPEN   ·   RBF-04 = OPEN
```

The aborted R6 unit produced **no** source root; it was RED'd for an unauthorized project-memory mutation and governance-repaired. R7 does not recreate the R6 path and performs **zero** project-memory writes. No historical Orchestrator source-review PASS is inherited or defended.

## 3. Proof both R7 paths were absent before writing

Before any read or write, both were checked and found **ABSENT**: `C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-s1-prep-r7` (no directory, no `.zip`/`.rar`/tmp/bak/sidecar/cache/placeholder sibling) and this repository document. No preexisting R7 artifact was adopted.

## 4. R5 direct identities (bound, verified)

| subject | size | SHA-256 |
|---|---|---|
| R5 ZIP | `82256` | `e6b3274365f79178b9605cc518726f10fc8dc4906a96c8c8dc83062814f78755` |
| R5 repository document | `15099` | `cc8e329d7cf956dd8510febdbe56b0fd810e29fed5af0f70abab3dfbaa5e16a8` |
| R5 inspector | `106393` (2248 lines) | `d510f50669b5f3feacba3fe1956266832ef1461c3446fb99e41c17a36691a351` |
| R5 root SHA256SUMS | `2630` | `64e741a30154f9521c7ee5dc3f0368f1283ac22fa98365688ad32938e06811ad` |

## 5. Architecture

The R5 architecture is carried forward as a **permitted historical structural reference** (external-type authority; direct ZIP/XZ/USTAR readers; citation/output/path-map/envelope/error models; standard-library only, no `zipfile`/`tarfile`/`ast`/`subprocess`/`re`). R7 applies the mandated corrections surgically. This is **not** presented as an independent clean-room reimplementation.

## 6. The ten R7 corrections

1. **RECORD real strict CSV** — `csv.reader([line], strict=True)` decodes; a structural RFC 4180 quote audit (`_record_quote_audit`) rejects unclosed/multiline and yields per-cell quoted flags; blank / `!=3` fields / unquoted surrounding whitespace HOLD; quoted comma supported; the exact physical row is preserved. `split(",")` for RECORD is removed.
2. **RECORD syntax vs semantic** — malformed digest/size SYNTAX (unsupported algorithm, non-URL-safe char, explicit padding, invalid/noncanonical base64, decoded length `!= 32`, signed/whitespace/noncanonical size, malformed self-row) → `HOLD-WHEEL-RECORD-RECONCILE`; only a syntactically-canonical digest/size that disagrees with the member → semantic mismatch (WOP-02 `DYNAMIC-UNKNOWN`).
3. **ZIP version reconciliation** — local version-needed `==` central version-needed; method-minimum version (stored `>= 10`, DEFLATE `>= 20`); both `version-made-by` bytes bound (host `∈ {0,3}` **and** creator/spec version `∈ {10,20}`); any unsupported/inconsistent version → `HOLD-ZIP-VERSION-UNSUPPORTED`.
4. **ZIP extra-field presence policy** — the Product **Info-ZIP ruling** bound verbatim (`contracts/S1-ZIP-EXTRA-FIELD-POLICY.json`): `0x5455` {ABSENT ok; LOCAL-ONLY ok only if local flags bit0 `== 0`; CENTRAL-ONLY HOLD; BOTH accept only after exact reconciliation}; `0x7875` {ABSENT ok; LOCAL-ONLY ok with version 1 and UIDSize/GIDSize `∈ [1,4]`; CENTRAL-ONLY and BOTH HOLD — any central `0x7875` HOLDs}. New code `HOLD-ZIP-EXTRA-PRESENCE (61)`.
5. **WHEEL exact grammar** — Wheel-Version numeric-dotted canonical, supported major `== 1`; Tag exactly three `-`-components, each a compressed dot-separated set of ASCII `[A-Za-z0-9_]` tokens; Build singleton digit-led ASCII alphanumeric; ASCII header field names; explicit singleton vs repeatable for WHEEL and METADATA (no ambiguous bucket).
6. **Validation-plan coverage** — the plan is the **union of all 64 R4/R5 case IDs plus 30 new R7 cases = 94** (`> 64`); zero R4/R5 case removed or renamed.
7. **Per-case bindings** — every case object carries all eight fields (`case_id`, `deterministic_fixture_specification`, `exact_mutation`, `expected_exit_code_or_semantic_outcome`, `expected_core_root_state`, `expected_wrapper_envelope_state`, `falsified_property`, `replay_requirement`).
8. **Retained falsification classes** — all older adversarial classes retained via the 64-ID union.
9. **DOS external attributes** — all bits parsed; reserved/unsupported (`0x40`/`0x80`) and volume-label rejected; the directory bit is the authoritative discriminator; the trailing slash only confirms the derived type.
10. **Author self-check non-authoritative** — returns `AUTHOR-SELF-CHECK-R7 = COMPLETE-NON-AUTHORITATIVE`; never a self-graded source-review PASS.

## 7. Info-ZIP presence-policy ruling (Correction 4, bound verbatim)

- **`0x5455` Extended Timestamp:** ABSENT = ACCEPT; LOCAL-ONLY = ACCEPT only when local flags bit 0 `== 0`; CENTRAL-ONLY = REJECT; BOTH = ACCEPT only after exact reconciliation (central flags `==` local flags; central carries ModTime iff bit 0 set and byte-identical; AcTime/CrTime never in central; bits 3–7 zero; complete consumption).
- **`0x7875` New-Unix:** ABSENT = ACCEPT; LOCAL-ONLY = ACCEPT (version 1, UIDSize/GIDSize `∈ [1,4]`, complete consumption, zero trailing); CENTRAL-ONLY = REJECT; BOTH = REJECT — an encountered central `0x7875` MUST HOLD. No invented central reconciliation model.

The ruling is not researched, broadened, reinterpreted, or replaced. Extra-field id support does not expand beyond `0x5455`/`0x7875`.

## 8. Validation-plan coverage ledger (summary)

`R4 case IDs = 33` · `R5 case IDs = 33` · `shared = 2` (`TAR-DATA-AFTER-EOF`, `PATHMAP-HASH-MISMATCH`) · `union = 64` · `new R7 = 30` · `total = 94 (> 64)`. Every R4 and R5 id → **PRESENT IN R7**; every new id → **NEW**; **zero unexplained removed cases**. Five R4/R5 RECORD cases were tightened from SEMANTIC to a SYNTAX HOLD by Correction 2, and `ZIP-EXTRA-ONE-SIDED` had its disposition corrected to the Info-ZIP ruling (0x7875 BOTH → HOLD), with genuine one-sided coverage added (`ZIP-7875-LOCAL-ONLY-ACCEPT`, `ZIP-7875-CENTRAL-ONLY`). Full per-id disposition: `evidence/validation-plan-coverage-ledger-r7.tsv`.

## 9. R7 inspector identity

| field | value |
|---|---|
| path | `inspector/pip-installed-tree-source-inspector-s1-r7.py` |
| size | `117278` |
| lines | `2458` |
| SHA-256 | `c8bf2f65843ef5d41f691d31841f1225e5be6fb1b8aed41b2f6495ad3dfca9da` |
| imports | standard library only (`argparse, base64, binascii, csv, hashlib, io, json, lzma, os, posixpath, stat, sys, tokenize, unicodedata` + deferred `zlib`); no `tarfile`/`zipfile`/`ast`/`subprocess`/`re` |

## 10. Byte-identical carry-forward + question rules

- Subject manifest — `contracts/S1-SUBJECT-MANIFEST.json` — **byte-identical** to the accepted identity `d41618d9932b95f4cee41da3efa33f235bd9de63d2c3163f648318e870fb6e1c`.
- Question contract — `contracts/S1-QUESTION-CONTRACT.tsv` — **byte-identical** to `c85e29436dfe50694685bb1e106a9009a3e9b5fb958e2d132fc4a328f17ba69d`.
- Question rules — `contracts/S1-QUESTION-RULES.json` — corrected (unit token bumped to R7; rule semantics unchanged) → `5858e02291ab70dd2c20c8c59f4d5ca2c79a20efbfe7d0b8d65c6b696eaafb0c`; the parser contract's `question_rules_sha256` binding was updated to match.

## 11. Preparation-root inventory

Root: `C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-s1-prep-r7` — **26 files** (1 inspector + 14 contracts + 11 evidence) + `SHA256SUMS`, **4 directories** (root + inspector + contracts + evidence). One more contract than R5: the new `S1-ZIP-EXTRA-FIELD-POLICY.json`. No other path created.

## 12. SHA256SUMS identity and replay

`SHA256SUMS` — size `2767`, SHA-256 `fee3ec54d0969a9c331facd7200eab8e6be6203b3d38788cbd4ff3ca0413d608`, **26 entries** (excludes itself), replay **26/26 OK**. All 19 JSON contracts/evidence files validated well-formed (the inspector was **not** parsed/compiled).

## 13. Repository-document size and SHA-256

This document — see the accompanying orchestrator return for its exact byte size and SHA-256 (computed after write). `docs/result` untouched.

## 14. Source / main / spike / body / memory states

| item | state |
|---|---|
| main HEAD | `4873ac713397cf47642d39b1ef17e48a9301511d` (unchanged) |
| spike HEAD (`spike/pg-exit-p3c-execute-pre`) | `4873ac713397cf47642d39b1ef17e48a9301511d` (unchanged) |
| R7 prep root | ABSENT → CREATED (26 files + SHA256SUMS; replay 26/26) |
| R7 repository document | ABSENT → CREATED (this file) |
| R1–R5 roots + documents; aborted-R6 (no root) | PRESERVED / UNCHANGED |
| design bundles, lock, governance/acquisition/ARTIFACT-INSPECT evidence | PRESERVED / UNCHANGED |
| every `.deb`/`.whl` body, image archive, known `.rar` | UNCHANGED (never opened/listed/hashed/parsed) |
| project memory | UNMODIFIED (zero writes this session) |

## 15. Prohibition confirmations

No project-memory write / index / durable-state note; no automatic end-of-session memory write; no inspector executed/imported/compiled/byte-compiled/AST-parsed; no synthetic fixture created/executed; no real `.deb`/`.whl`/image/`.rar` body opened/listed/hashed/parsed; no subject-path map; no PARSER-VALIDATION-PREP/EXECUTE; no S1-EXECUTE; no isolation/collector/builder-context; no Docker/network/PostgreSQL/Supabase; no BUILD-PREP; nothing staged/committed; no PR; no temp/backup/cache/sidecar/placeholder path; `docs/result` untouched.

## 16. Exact next recommendation

```
PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R7
```

On acceptance, the next eligible gate is only **PARSER-VALIDATION-PREP-R1** (prepare deterministic synthetic fixtures + a runner; do not execute), then **PARSER-VALIDATION-EXECUTE-R1** (execute the accepted inspector against the accepted fixtures across the 94-case plan), then **S1-EXECUTE** against the six real bodies (isolated spike branch; interpreter identity + six-entry path map + `--subject-path-map-sha256`), then ISOLATION-PREP, C1-COLLECTOR-PREP, BUILDER-CONTEXT-PREP, C1. All remain **NOT AUTHORIZED**; `BUILD-PREP = HOLD`. `RBF-15` and `RBF-04` remain OPEN. Preparation stops at S1-PREP-R7.
