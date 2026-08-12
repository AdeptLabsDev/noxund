# PG-EXIT · P3C · EXECUTE-PRE · PIP-INSTALLED-TREE-SEMANTICS · S1-PREP-R5 (CLEAN-ROOM)

**Unit:** `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R5-WHEEL-METADATA-RECORD-AND-SEMANTIC-PROOF-CORRECTIVE`
**Type:** clean-room source-preparation corrective — **PREPARED, NOT EXECUTED**.
**Authored:** 2026-08-06 · NOXUND Product Orchestrator.

## 1. Disposition

```
PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R5-PASS-WHEEL-METADATA-RECORD-AND-SEMANTIC-PROOF-CORRECTED-NOT-EXECUTED
```

Recommendation:

```
PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R5
```

## 2. Corrected R4 disposition

```
PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R4-HOLD-WHEEL-EXTRA-METADATA-RECORD-AND-SEMANTIC-PROOF-FAILED
INSPECTOR-SOURCE-REVIEW-R4 = REJECTED-FALSE-GREEN
```

R4 bundle identity-valid; its inspector source and synthetic-validation plan are not accepted. R4 root and repository document preserved unchanged.

## 3. R4 direct-review identities

| subject | size | SHA-256 |
|---|---|---|
| R4 ZIP | `80514` | `527c95fc9862e8f07e8f796320ca217ecb480ebf6ab8d9c9fb4d863c1cf7bd27` |
| R4 repository document | `17589` | `25c851f3c4d3aab664265faec581d2d9d08eb3463ee32cd75fdeaec75a651aed` |
| R4 inspector | `95652` (1992 lines) | `8557498cc8d177a97b69b988deff88d932c13858f9183cc61ff3a03e9eaafe4b` |
| R4 root SHA256SUMS | `2519` | `1132ca25cd4e0a5295f563894f6bd5a47d06e3d633467b7e4b901895935660e2` |

manifest replay `24/24` · regular files `25` · directory entries incl root `4` · valid JSON `18`.

## 4. Proof both R5 paths were absent before writing

Before any read or write, both were checked and found **ABSENT**: `C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-s1-prep-r5` (no directory, no `.zip`/`.rar` sibling) and this repository document. No preexisting R5 file existed; none was adopted.

## 5. Exact R5 inspector identity

| field | value |
|---|---|
| path | `inspector/pip-installed-tree-source-inspector-s1-r5.py` |
| size | `106393` |
| lines | `2248` |
| SHA-256 | `d510f50669b5f3feacba3fe1956266832ef1461c3446fb99e41c17a36691a351` |
| imports | standard library only (`argparse, base64, binascii, csv, hashlib, io, json, lzma, os, posixpath, stat, sys, tokenize, unicodedata` + deferred `zlib`); no `tarfile`/`zipfile`/`ast`/`subprocess`/`re` |

`INSPECTOR-SOURCE-REVIEW-R5 = PASS (PREPARED, NOT EXECUTED)` — direct byte-level review; not compiled/imported/AST-parsed.

## 6. External-type policy (Correction A)

`_classify_external_type` is authoritative. Unix create-system requires `S_IFREG` (regular) or `S_IFDIR` (directory); zero/incomplete/ambiguous file-type bits → `HOLD-ZIP-EXTERNAL-TYPE`; the R4 `S_IFMT==0` trailing-slash fallback is **removed**; symlink/FIFO/socket/char/block rejected. DOS create-system parses the complete attribute byte, rejects the volume-label bit (`0x08`), requires the directory bit (`0x10`) for directories and an unambiguous regular disposition otherwise. A trailing slash may only **confirm** an attribute-derived directory. No global filename-based fallback.

## 7. Decoded ZIP extra-field model (Correction B)

`0x5455` (extended timestamp): flags byte, per-flag 4-byte mtime/atime/ctime (LOCAL) or mtime-only (CENTRAL); unknown flag bits and length not implied by flags → `HOLD-ZIP-EXTRA-DECODE`; complete consumption required. `0x7875` (Unix uid/gid): `version==1`, uid size+value, gid size+value, complete consumption. Malformed/ambiguous/partial → `HOLD-ZIP-EXTRA-DECODE`. `wheel-zip-extra-fields.tsv` gains `decoded_fields` and `reconciliation_disposition` columns.

## 8. Local/central extra-field reconciliation (Correction B)

Exact presence policy per id: `LOCAL-ONLY` / `CENTRAL-ONLY` / `BOTH-RECONCILED`. Reconciliation is never skipped for an allowlisted id: `0x5455` requires equal flags and equal shared mtime; `0x7875` requires full local==central where both present. A shared-field mismatch → `HOLD-ZIP-EXTRA-RECONCILE`.

## 9. Exact dist-info binding (Correction C)

Exactly one dist-info directory; its `<name>-<version>` stem is bound to the manifest by PEP 503 name normalization equality and exact version equality → `HOLD-DISTINFO-IDENTITY` on mismatch.

## 10. METADATA field and identity policy (Correction C)

Both `METADATA` and `WHEEL` required. METADATA: supported `Metadata-Version`; exactly one `Name` and `Version`; `PEP503(Name)==PEP503(manifest package)` and `Version==manifest version` → `HOLD-WHEEL-METADATA-IDENTITY`; field-name syntax validated; all occurrences and continuation ranges preserved to `wheel-header-fields.tsv`; malformed continuation / control chars → `HOLD-WHEEL-HEADER-PARSE`.

## 11. WHEEL field and value policy (Correction C)

Supported `Wheel-Version` (major 1); exactly one `Root-Is-Purelib ∈ {true,false}`; every `Tag` is exactly three non-empty `-`-separated components; `Build` (when present) begins with a digit; `Generator` preserved. Malformed/ambiguous → `HOLD-WHEEL-HEADER-PARSE`. `wheel-metadata-inventory.tsv` distinguishes `INVENTORIED / DECODED / HEADER-PARSED / SEMANTICALLY-VALIDATED`; decoding alone is never labelled parsing.

## 12. Canonical RECORD CSV/digest/size model (Correction D)

Strict CSV: blank physical rows, quoting, leading/trailing whitespace and rows without exactly three comma fields → `HOLD-WHEEL-RECORD-RECONCILE`. Digest: exactly `sha256=<canonical URL-safe base64 without padding>` — only URL-safe alphabet, reject `+`/`/`, reject padding, decode to exactly 32 bytes, re-encode and require canonical round-trip equality. Size: non-self rows require nonempty ASCII decimal (no sign/whitespace/leading-zero) compared to the exact member byte size. Raw physical row and all three raw fields preserved. Coverage: every regular member exactly one row; exactly one empty self-row; no dangling; no missing; no directory listed in RECORD. Malformed syntax HOLDs; a semantic mismatch makes `wheel_record_fully_reconciled` false (WOP-02 → DYNAMIC-UNKNOWN).

## 13. Per-member origin and relocation output (Correction E)

`wheel-member-origin-and-relocation.tsv` — one row per member **including directories**: `subject_id, structural_inventory_line, normalized_wheel_path, member_type, original_member_sha256, original_member_byte_size, data_root_identity, relocation_scheme, relocation_classification, classification_disposition`. The semantic core grows to 14 covered files.

## 14. WOP-01 proof and exact citation lines (Correction E/G)

`wheel_structural_inventory_complete` — STATICALLY-SUPPORTED only when every structural member has exactly one origin row (`origin_row_count == member_count`). Its citation identifies the actual output filename `wheel-member-origin-and-relocation.tsv` and the exact per-subject first/last output line (header at line 1, data from line 2); no synthetic `1-entry_count` range.

## 15. WOP-02 proof and directory N/A model (Correction E)

`wheel_record_fully_reconciled` — SUPPORTED only when every applicable regular member is fully reconciled. Directory members carry `RECORD-NOT-APPLICABLE-DIRECTORY` so the answer covers **every** original wheel member. Citation = `wheel-record-inventory.tsv` per-subject line range.

## 16. WOP-04 per-member proof (Correction E)

`wheel_data_relocation_classified` — SUPPORTED only when every member has exactly one relocation-classification row, counted and reconciled against the complete structural inventory (`origin_row_count == member_count`); never true merely because ZIP parsing completed. Citation = `wheel-member-origin-and-relocation.tsv` per-subject line range.

## 17. Corrected distribution-specific SCRIPTS rules (Correction F)

`SCRIPTS-01` evaluates **only** `S1-05-psycopg-wheel`; `SCRIPTS-02` evaluates **only** `S1-06-typing-extensions-wheel`. Each has `permitted_evidence_subjects` = the single relevant wheel; one wheel's state can never determine or block the other's answer.

## 18. Strict entry-point grammar (Correction F)

`_parse_entry_points`: entry must occur inside a non-empty section; section/entry names satisfy `[A-Za-z0-9._-]+`; target must be a valid `module[:object]` of Python identifiers; extras a valid comma-separated identifier list; stray brackets, duplicate section/name pairs and unsupported continuation lines → `HOLD-ENTRY-POINTS-PARSE`. Absence is cited from the structural inventory of the relevant wheel only.

## 19. Exact citation-output line model (Correction G)

Citation-bearing TSVs are sorted by `(subject, …)` so per-subject rows are contiguous; `_subject_line_ranges` computes stable first/last lines with the header offset and a contiguity guard. Each citation carries `output_filename, first_output_line, last_output_line, subject, archive_sha256, evidence_kind, archive_member`. Before any non-UNKNOWN result, `_validate_citation` reproduces that every cited row exists, its subject column equals the citation subject, the archive identity matches, and the subject/member are within the rule boundary → `HOLD-CITATION-REPRODUCE` / `HOLD-CITATION-BOUNDARY`. Per-subject member counts are never used as global line numbers.

## 20. Complete USTAR reserved-field policy (Correction H)

`parse_nested_tar` requires bytes `500:512` all zero (`HOLD-TAR-RESERVED-FIELD`), a canonical checksum (`_tar_checksum_canonical`: 6 octal digits + NUL + space), strict octal on mode/uid/gid/size/mtime/checksum/devmajor/devminor, and NUL-padding on name/prefix/uname/gname/linkname.

## 21. Method-specific ZIP flags and version policy (Correction I)

`_method_flag_mask`: stored (method 0) permits only the UTF-8 flag (deflate-option bits rejected); deflate (method 8) permits the deflate-option bits + UTF-8; all unspecified bits rejected even when local and central agree (`HOLD-ZIP-FLAG-UNSUPPORTED`); `local_flags == central_flags`. Version: version-made-by host ∈ `{0,3}` and version-needed ∈ `{10,20}`, else `HOLD-ZIP-VERSION-UNSUPPORTED`.

## 22. Updated semantic-core schema and counts

14 covered core files + `SHA256SUMS` (14 manifest entries; excludes itself), adding `wheel-member-origin-and-relocation.tsv`. No `stdout.log`/`stderr.log`/`exit-code.txt`; `source-inspection-result.json` sets `process_exit_status_not_claimed = true`. `commit_core` requires exactly 14 covered files and 14 manifest entries.

## 23. Corrected synthetic-validation plan and case count (Correction J)

`contracts/S1-PARSER-SYNTHETIC-VALIDATION-PLAN.json` — **33 cases** including Unix `S_IFMT==0` with trailing slash, DOS volume-label, `0x5455`/`0x7875` malformed and one-sided/inconsistent, METADATA Name/Version/unsupported-version, WHEEL Root-Is-Purelib/Wheel-Version/Tag/Build, dist-info identity, RECORD blank/quote/non-URL-safe/padding/noncanonical/signed-size, directory + WOP-02 N/A, missing relocation row, bad citation range, distribution-specific scripts (both directions), malformed target/extras, nonzero USTAR reserved bytes, stored deflate flags, plus a positive control. Each binds fixture spec, mutation, expected exit/semantic outcome, core-root state, wrapper-envelope state, falsified property and replay requirement. **No fixture created or executed in R5.**

## 24. HOLD/RED model

All technical/parser/schema/output/header/record/metadata/path-map failures → dedicated nonzero HOLD (78 unique exit codes). RED (`90`) reserved exclusively for a directly detected authorization/scope violation (output basename with a path separator). Final `except Exception` → `HOLD-INTERNAL-UNCLASSIFIED (99)`. No failure bundle.

## 25. Source-review checklist result

`evidence/inspector-source-review-checklist-r5.md`: Corrections A–J each **PASS** by direct source review; standard-library-only; conservative-resolver audit confirms exactly five statically resolvable questions (SCRIPTS split per distribution) and five forced-UNKNOWN pip-cooccurrence questions.

## 26. Preparation-root inventory

Root: `C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-s1-prep-r5` — **26 files** (1 inspector + 13 contracts + 11 evidence + `SHA256SUMS`), **4 directories** (root + inspector + contracts + evidence), matching the authorized structure exactly; no other path created.

## 27. Preparation-root SHA256SUMS identity and replay

`SHA256SUMS` — size `2630`, SHA-256 `64e741a30154f9521c7ee5dc3f0368f1283ac22fa98365688ad32938e06811ad`, **25 entries** (excludes itself), replay **25/25 OK**.

## 28. Repository-document size and SHA-256

This document — see the accompanying orchestrator return for its exact byte size and SHA-256 (computed after write). `docs/result` untouched.

## 29. Source / main / evidence / body / archive / memory states

| item | before | after |
|---|---|---|
| main HEAD | `4873ac713397cf47642d39b1ef17e48a9301511d` | `4873ac713397cf47642d39b1ef17e48a9301511d` |
| spike HEAD | `4873ac713397cf47642d39b1ef17e48a9301511d` | `4873ac713397cf47642d39b1ef17e48a9301511d` |
| R5 prep root | ABSENT | CREATED (26 files; manifest 25/25) |
| R5 repo document | ABSENT | CREATED (this file) |
| R1 / R2 / R3 / R4 roots + documents | PRESERVED | UNCHANGED |
| design R1–R5, lock, governance closeouts, acquisition/ARTIFACT-INSPECT evidence | PRESERVED | UNCHANGED |
| every `.deb`/`.whl` body, image archive, known `.rar` | path-presence + `lstat` type only | UNCHANGED (never opened) |
| project memory | PRESERVED | UNMODIFIED |

## 30–37. Confirmations

- **30** No preexisting R5 file was adopted — both R5 paths were absent; all 26 root files + this document authored under this authorization (manifest and question contract reproduced byte-identical to accepted identities).
- **31** No existing file changed — R5 created only new paths; R1–R4 and all repository files untouched.
- **32** Nothing staged; no commit; no PR.
- **33** No inspector or synthetic fixture was executed, imported, compiled, byte-compiled or AST-parsed (read as bytes/text only).
- **34** No real package/wheel/image/RAR body was opened, listed, hashed or parsed.
- **35** No subject-path map, parser-validation preparation/execution, isolation, collector, builder-context, Docker, network, database or later gate began; no synthetic fixture created.
- **36** No temporary, backup, sidecar, cache or placeholder path was created; only final authorized paths were written.
- **37** The known `.rar` was checked by path presence only.

## 38. Exact next recommendation

```
PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R5
```

On acceptance, the next eligible gate is only **PARSER-VALIDATION-PREP-R1** (prepare deterministic synthetic fixtures + a runner; do not execute), then **PARSER-VALIDATION-EXECUTE-R1** (execute the accepted inspector against the accepted fixtures), then **S1-EXECUTE** (bind the exact CPython 3.11 interpreter byte identity + a six-entry Linux `S1-EXECUTION-SUBJECT-PATH-MAP.json` + `--subject-path-map-sha256`; isolated spike branch), then ISOLATION-PREP, C1-COLLECTOR-PREP, BUILDER-CONTEXT-PREP, C1. S1-EXECUTE against the six real bodies remains unauthorized until both parser-validation gates are accepted. RBF-15 and RBF-04 remain OPEN.

Preparation stops at S1-PREP-R5.
