# PG-EXIT-P3C-EXECUTE-PRE - BASE-CONFIG-INSPECT-R4-CANARY-R2-CANONICAL-REPODIGEST-REPLAY

Status: HOLD (parser nonzero exit; archive and evidence preserved)
Date: 2026-08-03
Mode: one parser-only canary replay. NO Docker. The bound R4 parser was executed exactly once
(as `python <script> <args>`) against the preserved R1 canary archive, using the canonical
Docker `repo@digest` RepoDigest form. No pull/load/inspect/save, no container, no network, no
database, no GNU tar, no tests. No `python -c`; no `.stderr`/temporary sidecars.

## 1. Decision and disposition

The Product Lead authorized one parser-only canary replay with the canonical RepoDigest form.
The parser exited nonzero. Per the authorization, the archive and the complete R2 root (with
empty output) are preserved; nothing was cleaned or rerun. Result:

BASE-CONFIG-R4-CANARY-R2-HOLD-PARSER-NONZERO

No base-configuration finding is closed by this replay.

## 2. Source, parser and contracts

- Worktree C:/Adeptlabs/noxund-p3c-execute-pre; branch spike/pg-exit-p3c-execute-pre;
  spike HEAD 4873ac713397cf47642d39b1ef17e48a9301511d; main HEAD identical, zero tracked/staged
  differences.
- Parser base-config-inspect-r3-r4.py - 84494 bytes, 1729 lines,
  sha256 756942efc5e541a0c09f113d65044c556b60a3c62b2bf9d69c1649f44e17cf39 (UTF-8, no BOM,
  LF-only, final LF); reproduced before and after (unchanged).
- PARSER-CONTRACT.json 2558069d..., OUTPUT-SCHEMA.json 33fe1df5..., PATH-POLICY.json 739fec10...,
  root SHA256SUMS 56a6908e... (19/19). Bundle unmodified.

## 3. Inputs

- Python C:/Users/Miguel/AppData/Local/Programs/Python/Python311/python - Python 3.11.9, stdlib.
- Preserved R1 archive image-save-r4-canary.tar - 158927360 bytes,
  sha256 35fde2ceeb68cbc544e7b8f1832af2670bc27e1471a1b5fca7f754ca495ee494; regular file; reproduced
  before and after; opened read-only through the parser only; not copied/renamed/moved/recompressed/
  deleted.
- Bound docker-version.json (1145 / 9de6b5fa...) and image-inspect.json (3068 / f470c026...);
  reproduced before and after; evidence root not modified.
- Canonical --expected-repodigest:
  postgres@sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51.
- Timeout: GNU coreutils timeout 8.32, 1500s wall-clock (<= 30 min). Elapsed ~0s. Not timed out.

## 4. Parser execution and result

- Invocation count 1; no automatic retry.
- Exit code 15; disposition MISSING-BLOB; diagnostic null; stdout empty.
- Reason: "attestation: blob absent
  0cc14c2171adb31a3b202cea1f374704740a078f3b41e01687bed559c3571c52".
- Validation reached before failure: archive identity; output-root Option A prep; outer-tar +
  oci-layout + index.json; RepoDigest -> nested image index binding (CAS); amd64 image manifest
  selection; config CAS load; check_platform_config (os/arch/RepoDigest/DiffID agreement) PASSED.
- NOT reached: layer blob validation; DiffID; bounded fixed point; interpreter chain; promoted
  helpers; postgres account extraction; entrypoint analysis; write phase.

## 5. CANARY-OBS-01 resolved

With the canonical repo@digest form, check_platform_config PASSED. The R1 exit-10 was purely the
--expected-repodigest input representation (repo:tag@digest vs repo@digest). Root cause confirmed;
the image platform and content digest were never contradictory.

## 6. CANARY-OBS-02 (new canary observation, not closed)

The nested image index (RepoDigest b0c5bab0...) references an attestation manifest
(digest 0cc14c21...) whose blob is not present in the docker image save archive. The R4 parser
verifies every inventoried attestation manifest blob (CAS presence) and fail-closed with
MISSING-BLOB. Attestation blobs are typically not stored locally for a normally-pulled image, so
`docker image save` writes the reference without the blob. This is fail-closed (correct posture)
but incompatible with a normal save of postgres:15.18-bookworm. It is consistent with CANARY-NOTE-01
(attestation child closure not verified / measured rows not preserved). It is a falsification data
point, not a project failure.

## 7. Output and evidence

Zero output files; failure preceded the write phase (any_output_created False). output/ is the
complete (empty) preserved output; no output/SHA256SUMS produced; manifest replay NOT-APPLICABLE.
Orchestration evidence lives under
C:/Adeptlabs/noxund-p3c-base-config-inspect-r4-execute-canary-r2/orchestration-evidence (13 files
incl SHA256SUMS, self-identity 135f2f18..., 12/12 reproduced). The R2 canary root has no re-saved
archive (the R1 archive is reused and preserved).

## 8. R1 governance-deviation recurrence (required clean result)

- GOV-CANARY-DEV-01 (`python -c`) recurrence: NO. All JSON parsing used grep / the read tool.
- GOV-CANARY-DEV-02 (`.stderr`/temp sidecars) recurrence: NO. Parser stderr went only to the
  authorized parser-stderr.txt; the exit code was captured via the wrapper's own stdout; no file
  was created outside the authorized structure.

## 9. Preservation and findings

- Archive preserved; cleanup requires a separate later Product Lead authorization after direct
  evidence review.
- Parser-prep R1/R2/R3/R4 bundles, prior evidence, and project memory unchanged. Nothing staged or
  committed. Known .rar checked by path presence only.
- OPEN: RBF-01/04/05/06/07(runtime)/08/11/13(nonblocking)/14/15. Recorded: GOV-R2-01/GOV-R2-02/
  GOV-PARSER-PREP-01/GOV-CANARY-DEV-01/GOV-CANARY-DEV-02. No finding closed or narrowed. RBF-04/14/15
  not closed.

## 10. Next recommendation

PRODUCT-LEAD-REVIEW-CANARY-OBS-02-ATTESTATION-BLOB-ABSENCE - decide whether to authorize a
parser-correction gate that treats an attestation manifest blob as optional when it is absent from
a local save (verify + measure only when present; label unverifiable attestations without failing),
consistent with CANARY-NOTE-01; or another handling. CANARY-OBS-01 is resolved. The saved archive is
preserved for recovery. This is a canary HOLD; it is not authorization to delete the archive or
resume BUILD-PREP.
