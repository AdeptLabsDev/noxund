# PG-EXIT-P3C-EXECUTE-PRE - BASE-CONFIG-INSPECT-R7-CANARY-R4-LAYER-ROOT-EXACT-ARCHIVE-REPLAY

Status: CANARY PASS (evidence preserved; awaiting Product review)
Date: 2026-08-04
Mode: one parser-only canary replay against the exact preserved nested-index archive. NO Docker.
The bound R7 parser was executed exactly once (as `python <script> <args>`) with the canonical
Docker repo@digest form. No pull/inspect/load/save, no container, no network, no database, no GNU
tar, no `python -c`, no sidecars outside the authorized structure.

## 1. Decision and disposition

The Product Lead authorized one parser-only replay of R7 against the preserved archive. The
parser exited 0 and every zero-exit predicate passed. Archive and complete R4 canary root
preserved; nothing cleaned or rerun. Result:

BASE-CONFIG-R7-CANARY-R4-PASS-EVIDENCE-PRESERVED-AWAITING-PRODUCT-REVIEW

This is a canary PASS only. It closes nothing and authorizes nothing further.

## 2. Source, parser and contracts

- Worktree C:/Adeptlabs/noxund-p3c-execute-pre; branch spike/pg-exit-p3c-execute-pre;
  spike HEAD 4873ac713397cf47642d39b1ef17e48a9301511d; main HEAD identical, zero tracked/staged diffs.
- Parser base-config-inspect-r3-r7.py - 113406 bytes, 2177 lines,
  sha256 ffe7f7ed6bbe773fb67c0abc6221b35ee3e869f647780d1c503e4a13e45c3500; reproduced before/after (unchanged).
- Bundle SHA256SUMS c0d51bef... (16/16, no unexpected/modified file); PARSER-CONTRACT.json a669fc90...,
  OUTPUT-SCHEMA.json 6484849e..., PATH-POLICY.json e0e114ed...

## 3. Inputs and execution

- Python C:/Users/Miguel/AppData/Local/Programs/Python/Python311/python - Python 3.11.9.
- Preserved archive image-save-r4-canary.tar - 158927360 bytes,
  sha256 35fde2ceeb68cbc544e7b8f1832af2670bc27e1471a1b5fca7f754ca495ee494; regular file; reproduced
  before/after; opened read-only through the parser only; not copied/moved/renamed/recompressed/
  replaced/deleted.
- Bound docker-version.json (9de6b5fa...) and image-inspect.json (f470c026...); reproduced before/after.
- Canonical --expected-repodigest postgres@sha256:b0c5bab0...
- Timeout: GNU coreutils timeout 8.32, 1500s (<= 30 min). Elapsed ~10s. Not timed out.
- Invocation count 1; no retry. Exit 0; stdout+stderr empty.

## 4. Output and manifest

Exactly 24 output paths matching OUTPUT-SCHEMA-r7, including output/SHA256SUMS (23 entries, 23/23
reproduced; 0 missing, 0 unexpected). output/SHA256SUMS identity f6c465cc...

## 5. Layer-root header validation (CANARY-OBS-03 candidate resolved)

Identical root-header evidence across fixed-point-resolution-r7 / resource-budget-r7 /
metadata-limitations-r7: total_root_directory_headers_processed_across_scans = 2;
count_by_layer_sequence = {"0": 2} (sum == total); every_accepted_header_was_zero_size_directory =
true; any_root_like_non_directory_rejected = false; raw_root_alias_names_observed = ["."] (1 < 64,
no duplicates); every observed name is nonempty, relative, non-NUL, non-drive, splits only into
'' or '.' with at least one '.'. No empty path or '/' appears in merged-path-resolution keys,
referenced-file-identities, fixed-point tracked/referenced paths, helper paths, or interpreter
paths. Root ownership/mode/UID/GID were not inferred (RBF-14 not established). R7-BN-01 not
saturated; R7-BN-02 counts recorded as cumulative-over-rescans. CANARY-OBS-03 =
VALIDATED-CANDIDATE-RESOLVED-AWAITING-PRODUCT-REVIEW (not closed autonomously).

## 6. Selected-runtime closure

blob-ledger-r7.tsv selected-runtime rows: 1 repodigest-index + 1 image-manifest + 1 config + 14
layers = 17; every row selected_runtime_dependency=True, verification_status=VERIFIED,
size_match=True, digest_match=True. Four-way totals 17==17==17==17 (reproduce from the ledger).
R6-BN-01 satisfied (persisted repodigest-index measurement). Selected manifest digest fafb7480...

## 7. Index siblings, attestation and full-index closure

Index siblings: 16 total = 1 SELECTED-RUNTIME-IMAGE + 7 UNSELECTED-PLATFORM-IMAGE + 8 ATTESTATION;
0 unsupported/unclassified. Verification states: 2 VERIFIED, 7 NOT-VERIFIED, 7 NOT-OBSERVED.
R6-BN-03 exercised and satisfied. Attestation sha256:0cc14c21... =
REFERENCED-BUT-ABSENT-IN-LOCAL-SAVE (descriptor_size 841; observed null; manifest_verified False;
child_closure_verified False; selected_runtime_dependency False; blocking False) - matches binding.
Closure: selected_runtime_closure=VERIFIED; immutable_base_predicates=PASS; entrypoint runtime
UNPROVEN; evidence_manifest MANIFEST-REPRODUCTION-REQUIRED; attestation_manifest_closure=
ATTESTATION-MANIFEST-CLOSURE-INCOMPLETE-REFERENCED-BLOB-ABSENT; attestation_child_closure=UNVERIFIED;
full_index_closure=NOT-VERIFIED with reasons [ATTESTATION-MANIFEST-REFERENCED-BUT-ABSENT-IN-LOCAL-SAVE,
ATTESTATION-CHILD-CLOSURE-UNVERIFIED, UNSELECTED-PLATFORM-MANIFEST-UNVERIFIED]. R6-BN-02 satisfied
(cross-checked via measurements + ledger + record-derived totals).

## 8. Filesystem, runtime and account evidence

Fixed point: 1 generation index; new references gen0 = [/usr/bin/bash, /usr/bin/gosu, /usr/sbin/bash,
/usr/sbin/gosu], gen1 = []. Interpreter chain: /usr/bin/env (48536, 615c46b3...) -> /usr/bin/bash
(1265648, 55b89ab2...). Promoted helper: gosu (from `exec gosu postgres ...`) -> /usr/local/bin/gosu
(1769900, 52c8749d...); uncertain occurrences: none. Server: /usr/lib/postgresql/15/bin/postgres
(regular, 8945320, dd2fdcca...). PGDATA: /var/lib/postgresql/data (dir, uid/gid 999). /etc/passwd
(regular, 889, 99d10fe0...); /etc/group (regular, 474, c11da363...); entrypoint
/usr/local/bin/docker-entrypoint.sh (regular, 14577, 9c440299...). postgres account: uid 999,
primary gid 999, group postgres, home /var/lib/postgresql, shell /bin/bash, supplementary
[ssl-cert:101]; 0 duplicate supplementary names/gids; UNAMBIGUOUS; 0 malformed. RBF-04/14/15 not closed.

## 9. R1 governance-deviation recurrence

GOV-CANARY-DEV-01 (`python -c`): NO. GOV-CANARY-DEV-02 (`.stderr`/sidecars): NO.

## 10. Preservation and findings

Archive preserved (no cleanup authorized). Parser-prep R1-R7 bundles, all canary bundles, prior
evidence, and project memory unchanged. Nothing staged or committed. Known .rar checked by path
presence only. OPEN: CANARY-OBS-03 (validated candidate), RBF-01/04/05/06/07(runtime)/08/11/13(nonblocking)/
14/15. Recorded: GOV-R2-01/GOV-R2-02/GOV-PARSER-PREP-01/GOV-CANARY-DEV-01/GOV-CANARY-DEV-02. Binding
notes R6-BN-01/02/03 + R7-BN-01/02 satisfied. No finding closed or narrowed autonomously.

## 11. Next recommendation

PRODUCT-LEAD-REVIEW-R7-CANARY-R4-SUCCESS - review the preserved output evidence under
C:/Adeptlabs/noxund-p3c-base-config-inspect-r7-execute-canary-r4 and, if accepted, decide
CANARY-OBS-03 closure and the next PG-EXIT-P3C step. This canary PASS authorizes nothing else
(no archive cleanup, no commit/PR, no BUILD-PREP, no pip-semantics inspection, no later execution).
