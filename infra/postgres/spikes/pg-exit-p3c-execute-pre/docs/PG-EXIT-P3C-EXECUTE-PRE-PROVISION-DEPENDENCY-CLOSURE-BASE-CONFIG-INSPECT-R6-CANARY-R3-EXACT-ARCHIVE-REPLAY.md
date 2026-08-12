# PG-EXIT-P3C-EXECUTE-PRE - BASE-CONFIG-INSPECT-R6-CANARY-R3-EXACT-ARCHIVE-REPLAY

Status: HOLD (parser nonzero exit; archive and evidence preserved)
Date: 2026-08-03
Mode: one parser-only canary replay against the exact preserved nested-index archive. NO Docker.
The bound R6 parser was executed exactly once (as `python <script> <args>`) with the canonical
Docker repo@digest form. No pull/inspect/load/save, no container, no network, no database, no GNU
tar, no `python -c`, no sidecars outside the authorized structure.

## 1. Decision and disposition

The Product Lead authorized one parser-only canary replay of R6 against the preserved archive.
The parser exited nonzero. Per the authorization the archive, the complete R3 canary root (empty
output), and partial output are preserved; nothing was cleaned or rerun. Result:

BASE-CONFIG-R6-CANARY-R3-HOLD-PARSER-NONZERO

No base-configuration finding is closed.

## 2. Source, parser and contracts

- Worktree C:/Adeptlabs/noxund-p3c-execute-pre; branch spike/pg-exit-p3c-execute-pre;
  spike HEAD 4873ac713397cf47642d39b1ef17e48a9301511d; main HEAD identical, zero tracked/staged
  differences.
- Parser base-config-inspect-r3-r6.py - 107499 bytes, 2091 lines,
  sha256 ca4c567167b942ed2779423aa56916af377cd9b1f1a6c626282cc709040b88d1 (UTF-8, no BOM, LF-only,
  final LF); reproduced before and after (unchanged).
- Bundle SHA256SUMS 8559ec19... (16 entries, 16/16, no unexpected/modified file);
  PARSER-CONTRACT.json 6335f77d..., OUTPUT-SCHEMA.json 757b2005..., PATH-POLICY.json 202a5234...

## 3. Inputs

- Python C:/Users/Miguel/AppData/Local/Programs/Python/Python311/python - Python 3.11.9.
- Preserved archive image-save-r4-canary.tar - 158927360 bytes,
  sha256 35fde2ceeb68cbc544e7b8f1832af2670bc27e1471a1b5fca7f754ca495ee494; regular file; reproduced
  before and after; opened read-only through the parser only; not copied/moved/renamed/recompressed/
  replaced/deleted.
- Bound docker-version.json (1145 / 9de6b5fa...) and image-inspect.json (3068 / f470c026...);
  reproduced before and after.
- Canonical --expected-repodigest postgres@sha256:b0c5bab0...
- Timeout: GNU coreutils timeout 8.32, 1500s wall-clock (<= 30 min). Elapsed ~3s. Not timed out.

## 4. Parser execution and result

- Invocation count 1; no automatic retry.
- Exit code 19; disposition UNSAFE-LAYER-MEMBER; diagnostic null; stdout empty.
- Reason: "empty normalized member: '.'".
- Validation reached before failure: archive identity; output-root Option A prep; outer-tar +
  oci-layout + index.json; RepoDigest -> nested image index binding (index_measured captured in
  memory); amd64 image manifest selection; config CAS; check_platform_config PASSED; attestation
  classification + absent-record (0cc14c21 REFERENCED-BUT-ABSENT, non-blocking); index-sibling
  inventory; per-layer Pass-A CAS + size + DiffID; selected-runtime 4-way totals equality.
- NOT reached: fixed-point convergence; interpreter chain; promoted helpers; postgres account
  extraction; entrypoint analysis; write phase (no output produced; output/ empty).

## 5. CANARY-OBS-03 (new canary observation, not closed)

canonical_member_name('inner') raises EXIT_UNSAFE_LAYER_MEMBER "empty normalized member" for a
layer member that normalizes to empty - the '.' (or './') root-directory entry that real
docker image save layer tars contain. It is raised in scan_layer during the fixed-point layer
rescan (the filesystem scanner is unchanged since R4), which blocks the entire filesystem fixed
point and account extraction on the exact preserved archive. This is fail-closed but incompatible
with a normal save; it is a falsification data point, not a project failure.

## 6. R6 closure-evidence signal: POSITIVE

Exit 19 is raised in the layer scanner, which runs only AFTER the R6 closure-evidence corrections
executed successfully: nested-index binding with an in-memory repodigest-index measurement, config
CAS, check_platform_config (canonical RepoDigest PASSED), attestation absent-non-blocking,
index-sibling inventory, per-layer Pass-A validation, and the selected-runtime 4-way totals
equality. The R6 corrections did not fail; the blocker is the pre-existing layer scanner.

## 7. Binding notes status

- R6-BN-01: DEFERRED-NOT-FALSIFIED. The nested-index branch was exercised (index_measured computed
  in memory; proven by reaching check_platform_config/attestation/sibling/Pass-A), but the persisted
  repodigest-index measurement requires a successful run. The direct-manifest branch is NOT treated
  as approved.
- R6-BN-02: N/A this run (no archive-validation-r6.json produced).
- R6-BN-03: N/A this run (the nested index has only a selected amd64 image and an absent
  attestation; no unselected platform sibling; no inventory persisted).

## 8. R1 governance-deviation recurrence (required clean result)

- GOV-CANARY-DEV-01 (`python -c`): NO. All parsing used grep / the read tool.
- GOV-CANARY-DEV-02 (`.stderr`/sidecars): NO. Parser stderr -> authorized parser-stderr.txt; exit
  captured via the wrapper's own stdout; no file created outside the authorized structure.

## 9. Output and evidence

Zero output files (pre-write abort); output/ is the complete (empty) preserved output; no
output/SHA256SUMS; manifest replay NOT-APPLICABLE (24 expected). Orchestration evidence lives under
C:/Adeptlabs/noxund-p3c-base-config-inspect-r6-execute-canary-r3/orchestration-evidence (14 files
incl SHA256SUMS, self-identity 288bd5eb..., 13/13 reproduced). No re-saved archive.

## 10. Preservation and findings

Archive preserved (no cleanup authorized). Parser-prep R1-R6 bundles, both canary bundles, prior
evidence, and project memory unchanged. Nothing staged or committed. Known .rar checked by path
presence only. OPEN: RBF-01/04/05/06/07(runtime)/08/11/13(nonblocking)/14/15. Recorded: GOV-R2-01/
GOV-R2-02/GOV-PARSER-PREP-01/GOV-CANARY-DEV-01/GOV-CANARY-DEV-02. Binding limitations R6-BN-01/02/03
preserved. No finding closed or narrowed.

## 11. Next recommendation

PRODUCT-LEAD-REVIEW-CANARY-OBS-03-LAYER-ROOT-MEMBER - authorize a parser-correction gate to treat a
layer member that normalizes to empty (the '.' / './' root-directory entry) as the layer root and
skip it (it is not a tracked path), while keeping absolute/drive/NUL/traversal rejection; then
re-run the canary. The saved archive is preserved for recovery. This is a canary HOLD; it does not
authorize archive cleanup, commit, PR, BUILD-PREP, pip-semantics inspection, or any later execution.
