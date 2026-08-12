# PG-EXIT · P3C · PIP-INSTALLED-TREE-SEMANTICS · PARSER-VALIDATION-DESIGN-R1

**Unit:** `PIP-INSTALLED-TREE-SEMANTICS-PARSER-VALIDATION-DESIGN-R1-IDENTITY-PRESERVING-COMPONENT-HARNESS`
**Type:** DESIGN ONLY — no fixtures, no runner, no inspector execution, no real-body access, no R9 modification.
**Authored:** 2026-08-07 · NOXUND Product Orchestrator.

## 1. Disposition

```
PIP-INSTALLED-TREE-SEMANTICS-PARSER-VALIDATION-DESIGN-R1-PASS-IDENTITY-PRESERVING-COMPONENT-HARNESS-DESIGNED-NOT-EXECUTED
```

```
AUTHOR-SELF-CHECK-PARSER-VALIDATION-DESIGN-R1 = COMPLETE-NON-AUTHORITATIVE
```

Recommendation:

```
PRODUCT-LEAD-REVIEW-PARSER-VALIDATION-DESIGN-R1
```

PREP is **not** recommended yet.

## 2. R9 state recorded

```
PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R9 = HOLD-PARSER-VALIDATION-EXECUTION-CONTRACT-INFEASIBLE
INSPECTOR-SOURCE-REVIEW-R9 = ACCEPTED-STATIC-SOURCE-ONLY
R9-PRODUCTION-INSPECTOR = FROZEN-AT-697bdfc341ceddb6c7da4b20567cfbe0923285952c1c43ade192538f5c1c097a
R9-VALIDATION-EXECUTION-MODEL = REJECTED-SYNTHETIC-FIXTURES-CANNOT-PASS-PRODUCTION-SUBJECT-IDENTITY-GATE
R9-VALIDATION-CASE-COVERAGE = ACCEPTED-104-OF-104-AS-ADVERSARIAL-CATALOG
```
Also preserved as accepted: R9 contract-hash closure, current-unit-reference closure, metadata-output coherence, WOP-01 raw-path proof, mandatory RECORD, wheel-metadata minimum. The R9 identity contract is **not** weakened.

## 3. The blocker and the redesign

The accepted production inspector binds `SUBJECT_MANIFEST_SHA256 = d41618d9…`; `load_subject_manifest`/`load_path_map` and `run()`'s per-subject size + `hash_pre`/`verify_post` require every opened subject to match its immutable manifest identity. A mutated synthetic fixture can therefore never reach the parser through the production CLI, so the 104-case synthetic **end-to-end** execution model is infeasible.

The redesign is an **external identity-preserving component harness** (for a later, separately-authorized EXECUTE gate) that: (1) hashes the exact R9 source and requires `697bdfc3…097a`; (2) loads it as a module WITHOUT invoking `main()`/`run()` (the `__main__` guard); (3) performs ZERO mutation of globals/constants/functions/code objects; (4) calls the exact production parser/helper functions directly against deterministic synthetic inputs; (5) records exact returned values/rows/`InspectorHold` codes; (6) never treats component testing as a CLI-identity bypass. `run()` stays reserved for the real-body S1-EXECUTE gate and for identity-negative tests.

## 4. Why this preserves the identity contract

Every parser/helper function (`reconcile_and_read_zip`, `inspect_wheel_metadata`, `_parse_*`, `_reconcile_record`, `parse_nested_tar`, `read_ar_members`, `build_origin_rows`, `resolve_question`, `_validate_citation`, …) is **identity-free**: it consumes its raw-bytes / context arguments directly. The identity gate is a separate, earlier step in `run()`. Calling a parser with synthetic bytes is a legitimate component test, **not** a bypass and **not** a mutation. Consequently **every** case has `production_global_mutation_required = false` and `production_identity_bypass_required = false`. See `IDENTITY-BOUNDARY-ANALYSIS-R1.md` and `IMPORT-SAFETY-REVIEW-R1.md`.

## 5. Case mapping (104/104)

`CASE-EXECUTION-MAPPING-R1.tsv` has exactly one row per case with all 11 required fields. Its case-id set matches the R9 plan **104/104 (0 missing, 0 extra)**. Layers: **PURE-PARSER 73, COMPONENT-CHAIN 19, SEMANTIC-RESOLVER 11, PRODUCTION-CLI-IDENTITY-NEGATIVE 1**. Dispositions: COMPONENT-OBSERVABLE 92, SEMANTIC-OBSERVABLE 11, IDENTITY-NEGATIVE-OBSERVABLE 1. Zero cases require production global mutation or identity bypass; zero DEFERRED-PRODUCTION-E2E; zero untestable. `PATHMAP-HASH-MISMATCH` is the single identity-negative (fail-closed) case, kept separate from parser coverage.

## 6. Evidence split and acceptance accounting

`OBSERVATION-MODEL-R1.json` separates **component observation** (returned value / rows / state / exact HOLD code — the real evidence) from **future-E2E expectation** (the legacy `expected_core_root_state`/`expected_wrapper_envelope_state`, INFORMATIVE only). ACCEPT cases are observable at component level only up to parser-accept; their identical-to-real-subject core/envelope is deferred to S1-EXECUTE. `ACCEPTANCE-ACCOUNTING-R1.json` requires a future result to report `component_cases_passed`, `component_cases_failed`, `cli_identity_negative_cases_passed`, `deferred_production_e2e_cases`, `untestable_cases` separately, and forbids a headline `104/104 PASS` unless all 104 were genuinely and directly observed.

## 7. Design root inventory + identities

Root: `C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-parser-validation-design-r1` — **8 design artifacts + SHA256SUMS** (text only; no runner, no binary fixture, no ZIP/TAR/XZ fixture, no subject-path map). `SHA256SUMS` size `771`, SHA-256 `0267177d0082cf891c3daeef35ca20dce95d3280b9f752ebf03ba1f9de64de10`, 8 entries, replay **8/8 OK**. 3/3 JSON well-formed.

## 8. Repository-document size and SHA-256

This document — see the accompanying orchestrator return for its exact byte size and SHA-256 (computed after write). `docs/result` untouched.

## 9. Preservation / prohibitions

R9 source (`697bdfc3…097a`) and contracts UNMODIFIED; main + spike HEAD `4873ac713397cf47642d39b1ef17e48a9301511d` unchanged; nothing staged/committed; no PR. No inspector executed/imported/compiled/AST-parsed; no fixture; no runner; no real `.deb`/`.whl`/image/`.rar` body opened/listed/hashed/parsed; no subject-path map; no PARSER-VALIDATION-PREP/EXECUTE; no S1-EXECUTE; no isolation/collector/builder-context; no Docker/network/PostgreSQL/Supabase; no BUILD-PREP; project memory unmodified; no temporary/backup/cache/sidecar/placeholder path under any authorized root. (Two ephemeral OS-`/tmp` scratch files were used for a read-only case-id comparison and deleted immediately; no authorized root or work-tree path was touched.)

## 10. Exact next recommendation

```
PRODUCT-LEAD-REVIEW-PARSER-VALIDATION-DESIGN-R1
```
Do not recommend PREP yet. `RBF-15`, `RBF-04`, `GOV-S1-PREP-R3-01` remain OPEN. Stop after design.
