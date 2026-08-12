# PG-EXIT-P3C-EXECUTE-PRE - BASE-CONFIG-INSPECT-R3-PARSER-PREP-R5-ATTESTATION-POLICY-CORRECTIVE

Status: PASS (attestation-policy corrected source bound, NOT executed)
Date: 2026-08-03
Mode: parser-preparation correction and static audit only. No parser execution, no Python
(import/compile/`python -c`), no Docker, no archive creation/parsing, no GNU tar, no network.
The preserved R1 canary archive was not touched. Static review used read-only text tooling only.

## 1. Decision

The R2 canary exited MISSING-BLOB (CANARY-OBS-02) because the strict verify path rejected a
sibling attestation-manifest descriptor whose blob is absent from a normal `docker image save`.
The Product Lead authorized exactly one parser-preparation correction. R5 separates the strict
selected-runtime closure from optional-when-absent attestation handling.

## 2. Source identities

- R4 (reproduced): base-config-inspect-r3-r4.py - 84494 bytes, 1729 lines,
  sha256 756942efc5e541a0c09f113d65044c556b60a3c62b2bf9d69c1649f44e17cf39 (matches binding);
  bundle SHA256SUMS 56a6908e... (19/19). Preserved unchanged.
- R5 (corrected): parser/base-config-inspect-r3-r5.py - 96027 bytes, 1909 lines,
  sha256 7eb81b5ec972f392a3d7bef225fd3c71204020b9c29015770e00371df0920e77 (UTF-8, no BOM, LF-only,
  final LF). Byte-for-byte copy of R4 with ONLY attestation-policy + ledger + result edits.

## 3. Corrective bundle

C:/Adeptlabs/noxund-p3c-base-config-inspect-r3-parser-prep-r5 (created empty this gate).
17 files: 4 parser + 12 evidence + root-level SHA256SUMS. SHA256SUMS at the BUNDLE ROOT, covers
the other 16 files, written last; every entry reproduces (16/16 OK). SHA256SUMS identity
54f9905926a578c5057404e8028e0b3497f0b03c7d807d5be7f67480e3ef32ec.

## 4. Selected-runtime closure (strict, unchanged from R4)

index -> selected linux/amd64 image-manifest descriptor + blob -> config descriptor + blob ->
every layer descriptor + blob -> complete ordered DiffID. Each selected descriptor requires a
permitted media type, valid sha256 descriptor, exact descriptor-size match, exact CAS digest
match, blob present, and an unambiguous selected role. A missing selected-runtime manifest/config/
layer blob remains fatal (EXIT_MISSING_BLOB at verify_descriptor line 553 / run layer loop line
1659). Attestation handling never weakens this.

## 5. Attestation policy

- Classification (classify_attestation): a descriptor receives attestation treatment ONLY when the
  index metadata says platform.architecture=unknown, platform.os=unknown, or annotation
  vnd.docker.reference.type=attestation-manifest; the exact reason is recorded. A normal platform
  image manifest returns None and is never given optional treatment (a None-classified descriptor
  routed to the policy raises TRUST-CHAIN-VIOLATION).
- Present blob (Case A): strictly verify media/size/CAS/JSON/schema; present-but-invalid remains
  fatal; never downgraded to an optional absence. Record PRESENT, manifest_verified=true,
  child_closure_verified=false.
- Absent blob (Case B): the strict verify path (which raises MISSING-BLOB) is NOT called; record
  REFERENCED-BUT-ABSENT-IN-LOCAL-SAVE, manifest_verified=false, selected_runtime_dependency=false,
  blocking=false, with NO fabricated observed values (explicit null) and the preserved descriptor
  facts (digest, declared size, media type, platform, annotations, classification reason).

## 6. Ledgers, totals and result semantics

- derived/attestation-ledger-r5.tsv - 18 fields per attestation descriptor.
- derived/blob-ledger-r5.tsv - categories selected-runtime / attestation-present / attestation-
  absent; an absent attestation is never digest_match/size_match/manifest_verified=true.
- blob_totals separately report selected runtime descriptors, selected runtime blobs verified,
  attestation descriptors referenced, attestation manifests present+verified, attestation manifests
  absent, attestation child closures verified.
- parser-result-r5.json: selected_runtime_closure=VERIFIED; attestation_closure=
  INCOMPLETE-REFERENCED-BLOB-ABSENT when absent; full_index_closure is NOT VERIFIED while any
  attestation is absent; immutable_base_predicates=PASS; entrypoint runtime UNPROVEN; manifest
  reproduction required; no bare PASS.

## 7. Static audit results (10-point, no execution)

1. Missing selected-runtime manifest/config/layer remains fatal. 2. Optional absence applies only
to attestation-classified descriptors. 3. A present attestation mismatch remains fatal. 4. An
absent attestation is not observed / not verified. 5. Absent attestations do not increment verified
blob counts. 6. Selected-runtime closure is verified independently. 7. No result claims full index
closure while an attestation is absent. 8. The exact absent attestation descriptor stays visible in
final evidence. 9. All prior R4 fixed-point and filesystem controls are unchanged. 10. There
remains a single zero-exit path (return EXIT_OK at line 1721) after all selected-runtime and
filesystem predicates. Prohibited executable primitives all zero; 15 imports; write primitive
open(path,"xb") at line 462.

## 8. Preservation and findings

- R1/R2/R3/R4 parser-prep bundles and R1/R2 canary bundles preserved unchanged; the R1 canary
  archive (158927360 / 35fde2ce...) preserved (no cleanup authorized here). Prior evidence and
  project memory unchanged. Nothing staged or committed. Known .rar checked by path presence only.
- OPEN: RBF-01/04/05/06/07(runtime)/08/11/13(nonblocking)/14/15. Recorded: GOV-R2-01/GOV-R2-02/
  GOV-PARSER-PREP-01/GOV-CANARY-DEV-01/GOV-CANARY-DEV-02. Neither R1 canary deviation recurred in
  R2. No finding closed or narrowed. RBF-04/14/15 not closed.

## 9. Disposition

BASE-CONFIG-R3-PARSER-PREP-R5-PASS-ATTESTATION-POLICY-BOUND-NOT-EXECUTED

Next recommendation (NOT started): PRODUCT-LEAD-DIRECT-SOURCE-REVIEW-R5

Execution requires a separate Product Lead gate binding parser sha256
7eb81b5ec972f392a3d7bef225fd3c71204020b9c29015770e00371df0920e77.
