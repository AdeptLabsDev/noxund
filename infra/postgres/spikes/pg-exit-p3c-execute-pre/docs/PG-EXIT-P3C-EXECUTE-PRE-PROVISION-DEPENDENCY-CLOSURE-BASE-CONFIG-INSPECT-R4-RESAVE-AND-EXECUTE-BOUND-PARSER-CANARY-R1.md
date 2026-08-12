# PG-EXIT-P3C-EXECUTE-PRE - BASE-CONFIG-INSPECT-R4-RESAVE-AND-EXECUTE-BOUND-PARSER-CANARY-R1

Status: HOLD (parser nonzero exit; archive and evidence preserved)
Date: 2026-08-03
Mode: one bounded canary execution only. Read-only Docker (version/inspect/save), one image
save, one parser execution. No pull, no load, no container, no build, no network, no database,
no GNU tar, no tests. The parser was executed exactly once as `python <script> <args>`.

## 1. Decision and disposition

The Product Lead authorized one bounded canary execution of the bound R4 parser. The parser
exited nonzero. Per the authorization, the archive and complete (empty) partial output are
preserved, nothing was cleaned or rerun, and the result is:

BASE-CONFIG-R4-CANARY-HOLD-PARSER-NONZERO

No base-configuration finding is closed by this canary.

## 2. Source, parser and contracts

- Worktree C:/Adeptlabs/noxund-p3c-execute-pre; branch spike/pg-exit-p3c-execute-pre;
  spike HEAD 4873ac713397cf47642d39b1ef17e48a9301511d; main HEAD identical, zero tracked/staged
  differences.
- Parser base-config-inspect-r3-r4.py - 84494 bytes, 1729 lines,
  sha256 756942efc5e541a0c09f113d65044c556b60a3c62b2bf9d69c1649f44e17cf39 (UTF-8, no BOM,
  LF-only, final LF); reproduced before and after execution (unchanged).
- PARSER-CONTRACT.json 2558069d..., OUTPUT-SCHEMA.json 33fe1df5..., PATH-POLICY.json 739fec10...,
  root SHA256SUMS 56a6908e... (19/19). Bundle unmodified.

## 3. Environment

- Python C:/Users/Miguel/AppData/Local/Programs/Python/Python311/python - Python 3.11.9,
  standard library only.
- Docker client 29.6.2 / server 29.6.2 (Docker Desktop 4.84.0), server linux/amd64.
- Timeout: GNU coreutils timeout 8.32, 1500s wall-clock (<= 30 min). Elapsed 1s. Not timed out.

## 4. Image and archive

- Exact image postgres:15.18-bookworm@sha256:b0c5bab0...; Id sha256:b0c5bab0...;
  RepoDigests ["postgres@sha256:b0c5bab0..."]; RepoTags ["postgres:15.18-bookworm"];
  Os linux; Architecture amd64. Digest match proven; existed locally; no pull/load.
- Docker command count 3, one each of `docker version`, `docker image inspect`, `docker image
  save`.
- Archive image-save-r4-canary.tar - 158927360 bytes,
  sha256 35fde2ceeb68cbc544e7b8f1832af2670bc27e1471a1b5fca7f754ca495ee494 (byte-identical to the
  earlier BASE-INVENTORY archive). Regular file; single save; preserved unchanged after execution.

## 5. Parser execution and result

- Invocation count 1; no automatic retry.
- Exit code 10; disposition IDENTITY-MISMATCH; reason "expected RepoDigest absent from
  image-inspect"; diagnostic null; stdout empty.
- Validation reached before failure: archive identity; output-root Option A prep; outer-tar +
  oci-layout + index.json; RepoDigest->manifest binding (amd64 selected); config CAS load.
- Failure predicate: check_platform_config exact-string RepoDigest membership.

## 6. CANARY-OBS-01 (canary observation, not closed)

R4 check_platform_config requires --expected-repodigest to be a verbatim member of the
image-inspect RepoDigests. Docker records RepoDigests in the untagged `repo@digest` form
(`postgres@sha256:b0c5...`), while the authorized --expected-repodigest used the
`repo:tag@digest` form (`postgres:15.18-bookworm@sha256:b0c5...`). The tagged form is not a
member, so the parser exited 10 before layer validation, fixed-point resolution or evidence
production. This is a canary falsification data point, not a project failure. Fixed-point,
interpreter chain, promoted/uncertain helpers, and the postgres account were NOT reached.

## 7. Output

Zero output files; failure preceded the write phase (any_output_created False). output/ is the
complete (empty) preserved output. No output/SHA256SUMS produced; manifest replay NOT-APPLICABLE.
Orchestration evidence lives under
C:/Adeptlabs/noxund-p3c-base-config-inspect-r4-execute-canary-r1/orchestration-evidence
(14 files incl SHA256SUMS, self-identity ef59879a..., 13/13 reproduced).

## 8. Binding evidence limitations

- CANARY-NOTE-01: the parser verifies the RepoDigest index and selected image manifest, but its
  blob ledger does not preserve measured rows for both descriptors. The saved archive remains the
  authoritative recovery input.
- CANARY-NOTE-02: Pass-A uncompressed bounds are evaluated from the completed stream measurement,
  and fixed-point reprocessing is bounded using compressed-byte accounting. (Not exercised this
  run - failure preceded Pass-A layer streaming.)
- CANARY-NOTE-03: entrypoint runtime control flow and privilege transition remain
  ENTRYPOINT-RUNTIME-BEHAVIOR-UNPROVEN. No regex observation may be promoted to runtime proof.

## 9. Governance deviations (disclosed, not self-closed)

- GOV-CANARY-DEV-01: one `python -c` was used to parse the fresh docker inspect JSON for
  OS/arch/Id, which the Python-execution-boundary section prohibits. It was a read-only parse of
  orchestrator-captured output; it did not touch the bound parser (never executed via -c,
  imported, or compiled), the image, bound/prior evidence, or any output. Remediation: stopped
  inline Python, re-verified via grep, executed the parser exactly once as `python <script>
  <args>`.
- GOV-CANARY-DEV-02: three empty `.stderr` sidecar files were created during the Docker captures
  (not in the authorized structure) and then removed by literal path after verifying each was an
  ordinary empty regular file. Final orchestration-evidence matches the authorized 14-file
  structure exactly.

## 10. Preservation and findings

- Archive preserved; cleanup requires a separate later Product Lead authorization after direct
  evidence review.
- Parser-prep R1/R2/R3/R4 roots, prior evidence, and project memory unchanged. Nothing staged or
  committed. Known .rar checked by path presence only.
- OPEN: RBF-01/04/05/06/07(runtime)/08/11/13(nonblocking)/14/15. Recorded: GOV-R2-01/GOV-R2-02/
  GOV-PARSER-PREP-01/GOV-CANARY-DEV-01/GOV-CANARY-DEV-02. No finding closed or narrowed.

## 11. Next recommendation

PRODUCT-LEAD-REVIEW-CANARY-OBS-01-REPODIGEST-FORM - decide whether to (a) re-authorize a single
canary re-run with --expected-repodigest in the repo@digest form
(postgres@sha256:b0c5bab0...), or (b) authorize a parser-correction gate that accepts both
RepoDigest forms. The saved archive is preserved for recovery. This is a canary HOLD; it is not
authorization to delete the archive or resume BUILD-PREP.
