# PG-EXIT-P3C-EXECUTE-PRE - BASE-CONFIG-INSPECT-R3-PARSER-PREP-R6-CLOSURE-EVIDENCE-CORRECTIVE

Status: PASS (closure-evidence corrected source bound, NOT executed)
Date: 2026-08-03
Mode: parser-preparation correction and static audit only. No parser execution, no Python
(import/compile/`python -c`), no Docker, no archive open/parse, no GNU tar, no network. The
preserved R1 canary archive was not touched. Static review used read-only text tooling only.

## 1. Decision

The Product Lead rejected R5 for canary execution pending one narrow closure-evidence
correction and accepted the R5 optional-attestation policy in principle (do not redesign it).
R6 propagates all selected-runtime measurements, derives totals from records, inventories every
index sibling, validates absent-attestation descriptor structure, and reports precise attestation
and full-index closure states.

## 2. Source identities

- R5 (reproduced): base-config-inspect-r3-r5.py - 96027 bytes, 1909 lines,
  sha256 7eb81b5ec972f392a3d7bef225fd3c71204020b9c29015770e00371df0920e77 (matches binding);
  bundle SHA256SUMS 54f99059... (16/16). Preserved unchanged.
- R6 (corrected): parser/base-config-inspect-r3-r6.py - 107499 bytes, 2091 lines,
  sha256 ca4c567167b942ed2779423aa56916af377cd9b1f1a6c626282cc709040b88d1 (UTF-8, no BOM, LF-only,
  final LF). Copy of R5 with only closure-evidence edits; dead BlobRecord/_blob_from_measured
  removed.

## 3. Corrective bundle

C:/Adeptlabs/noxund-p3c-base-config-inspect-r3-parser-prep-r6 (created empty this gate).
17 files: 4 parser + 12 evidence + root-level SHA256SUMS. SHA256SUMS at the bundle root, covers
the other 16 files, written last; every entry reproduces (16/16 OK). SHA256SUMS identity
8559ec1993966b7674980f0fc35737e683874444d88d44820e7a2d9e392f3dad.

## 4. Corrections implemented (all 9)

1. Selected-runtime measurements: bind_repodigest_and_select returns index_measured (nested-index
   form) + manifest_measured + search_space (no discarded `_`); build_selected_runtime_chain
   assembles ordered (chain_sequence, role, Measured) for index/manifest/config/layers.
2. Complete blob ledger: blob-ledger-r6.tsv rows for every selected-runtime blob (index when
   applicable / manifest / config / each layer) + attestation rows; selected-runtime rows are
   independently sufficient to reproduce the selected-runtime blob count.
3. Record-derived totals: compute_closure_totals derives all 11 totals from records (no arithmetic
   constants); a zero exit requires selected_runtime_descriptors_referenced == blobs_present ==
   blobs_verified == measurements_in_ledger (asserted, EXIT_TRUST_CHAIN_VIOLATION otherwise).
4. Index-sibling inventory: every search-space descriptor classified (SELECTED-RUNTIME-IMAGE /
   ATTESTATION / UNSELECTED-PLATFORM-IMAGE / UNSUPPORTED-OR-UNCLASSIFIED); unsupported/unclassified
   is fatal; unselected platform images are visible and force full_index_closure NOT-VERIFIED;
   output derived/index-sibling-inventory-r6.json.
5. Absent-descriptor structure: validate_attestation_descriptor validates object/digest/media/
   size(int,>=0,<=MAX)/platform/annotations before the present/absent branch; a malformed
   descriptor is fatal even when the blob is absent.
6. Precise attestation closure states: NO-ATTESTATION-DESCRIPTORS-REFERENCED /
   ATTESTATION-MANIFEST-CLOSURE-INCOMPLETE-REFERENCED-BLOB-ABSENT /
   ATTESTATION-MANIFESTS-VERIFIED-CHILD-CLOSURE-UNVERIFIED; ATTESTATION-CLOSURE-VERIFIED is never
   emitted (children not verified).
7. Full-index closure: VERIFIED only when there are no reasons; else NOT-VERIFIED with exact
   reasons (absent attestation / attestation child unverified / unselected platform). For the known
   canary archive the reason is ATTESTATION-MANIFEST-REFERENCED-BUT-ABSENT-IN-LOCAL-SAVE.
8. Result semantics: parser-result-r6 separately states selected_runtime_closure=VERIFIED,
   attestation_manifest_closure=<state>, attestation_child_closure=UNVERIFIED, full_index_closure=
   NOT-VERIFIED + reasons; selected-runtime verification never implies the full index.
9. archive-validation-r6.json: selected-runtime chain + per-descriptor measurements + sibling
   inventory summary + attestation states + full-index reasons + record-derived totals; no
   hard-coded offset counts.

## 5. Static audit results (12-point, no execution)

Every selected-runtime measurement (RepoDigest index, manifest, config, each layer) reaches the
blob ledger; totals derived only from records; every sibling classified; malformed absent
descriptors fatal; absent attestations not observed / not verified; present contradictions fatal;
attestation closure never complete while child closure unverified; full index closure never
verified while any descriptor/child unverified; all R4 filesystem/fixed-point controls unchanged;
one zero-exit path. Prohibited executable primitives all zero; 15 imports; write primitive
open(path,"xb") at line 483. Dead BlobRecord/_blob_from_measured removed.

## 6. Preservation and findings

- R1-R5 parser-prep bundles, both canary bundles, and the R1 canary archive (158927360 /
  35fde2ce...) preserved unchanged (archive not opened; no cleanup authorized). Prior evidence and
  project memory unchanged. Nothing staged or committed. Known .rar checked by path presence only.
- OPEN: RBF-01/04/05/06/07(runtime)/08/11/13(nonblocking)/14/15. Recorded: GOV-R2-01/GOV-R2-02/
  GOV-PARSER-PREP-01/GOV-CANARY-DEV-01/GOV-CANARY-DEV-02. No finding closed or narrowed.

## 7. Disposition

BASE-CONFIG-R3-PARSER-PREP-R6-PASS-CLOSURE-EVIDENCE-BOUND-NOT-EXECUTED

Next recommendation (NOT started): PRODUCT-LEAD-DIRECT-SOURCE-REVIEW-R6

Execution requires a separate Product Lead gate binding parser sha256
ca4c567167b942ed2779423aa56916af377cd9b1f1a6c626282cc709040b88d1.
