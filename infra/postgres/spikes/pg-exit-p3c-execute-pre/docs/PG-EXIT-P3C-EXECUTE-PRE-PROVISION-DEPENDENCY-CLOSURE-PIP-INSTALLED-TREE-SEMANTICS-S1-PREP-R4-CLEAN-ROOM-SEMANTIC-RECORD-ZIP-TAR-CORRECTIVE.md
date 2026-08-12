# PG-EXIT · P3C · EXECUTE-PRE · PIP-INSTALLED-TREE-SEMANTICS · S1-PREP-R4 (CLEAN-ROOM)

**Unit:** `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R4-CLEAN-ROOM-SEMANTIC-RECORD-ZIP-TAR-CORRECTIVE`
**Type:** clean-room source-preparation corrective — **PREPARED, NOT EXECUTED**.
**Authored:** 2026-08-06 · NOXUND Product Orchestrator.

## 1. Disposition

```
PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R4-PASS-CLEAN-ROOM-SOURCE-CORRECTED-NOT-EXECUTED
```

Recommendation:

```
PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R4
```

## 2. Corrected R3 disposition

```
PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R3-HOLD-PREEXISTING-PROVENANCE-SEMANTIC-AND-PARSER-CONTRACT-FAILED
INSPECTOR-SOURCE-REVIEW-R3 = REJECTED-FALSE-GREEN
```

The R3 final bundle is identity-valid; its source is not authorized for execution. R3 root and repository document are preserved unchanged.

## 3. R3 direct-review identities (bound from the authorization)

| subject | size | SHA-256 |
|---|---|---|
| R3 ZIP | `66627` | `1954d22673d430332cc2914497014c9e39e851d51208d9a8c0b9e547f89511fe` |
| R3 repository document | `18055` | `aff38fd36995d9ad061b9148d40c687fc77c32d8b5bd6ab8550d6819e643dea6` |
| R3 inspector | `76107` (1612 lines) | `b435c1b8a37dca2bee389adbe4840bca5b070309ccfa4b1f19149c9d00f17a89` |
| R3 root SHA256SUMS | `2189` | `b909f4c2d5affebb7dffd50629f742e068aea9c3de6b5eaf55ee77959eeca758` |

manifest replay `21/21` · regular files `22` · directories `4` · JSON files `15`.

## 4. R3 provenance disposition

```
GOV-S1-PREP-R3-01 = OPEN-PREEXISTING-PARTIAL-ROOT-PROVENANCE-UNPROVEN
S1-R3-EVIDENCE-01  = RESOLVED-BY-DIRECT-REVIEW
```

No governance scope breach is conclusively recorded. Root cause: the R3 preparation root existed as a partial prior attempt (18 of 22 files) whose provenance could not be attested in the finalizing session. **R4 remedy:** clean-room re-authoring — both R4 paths required absent, every file authored fresh, no R4 file adopted.

## 5. Proof the R4 root and repository output were absent before writing

Before any read or write, both were checked and found **ABSENT**: `C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-s1-prep-r4` (no directory, no `.zip`/`.rar` sibling) and this repository document. No preexisting R4 file existed; therefore none was adopted.

## 6. Complete list of files authored by this gate

**Preparation root `C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-s1-prep-r4` — 25 files:**

```
inspector/pip-installed-tree-source-inspector-s1-r4.py    (authored)
contracts/S1-SUBJECT-MANIFEST.json                        (reproduced byte-identical to accepted d41618d9…)
contracts/S1-QUESTION-CONTRACT.tsv                        (reproduced byte-identical to accepted c85e2943…)
contracts/S1-QUESTION-RULES.json                          (authored)
contracts/S1-OUTPUT-SCHEMA.json                           (authored)
contracts/S1-EXECUTION-ENVELOPE-SCHEMA.json               (authored)
contracts/S1-EXECUTION-SUBJECT-PATH-MAP-SCHEMA.json       (authored)
contracts/S1-PARSER-CONTRACT.json                         (authored)
contracts/S1-PARSER-SYNTHETIC-VALIDATION-PLAN.json        (authored)
contracts/S1-SEMANTIC-CITATION-SCHEMA.json                (authored)
contracts/S1-PATH-POLICY.json                             (authored)
contracts/S1-BOUNDS.json                                  (authored)
contracts/S1-ERROR-MODEL.json                             (authored)
evidence/r3-direct-review-binding-r4.json                 (authored)
evidence/r3-provenance-disposition-r4.json                (authored)
evidence/r5-acceptance-binding-r4.json                    (authored)
evidence/prior-evidence-bindings-r4.json                  (authored)
evidence/source-correction-ledger-r4.tsv                  (authored)
evidence/semantic-rule-audit-r4.tsv                       (authored)
evidence/zip-tar-record-review-r4.json                    (authored)
evidence/inspector-source-review-checklist-r4.md          (authored)
evidence/inspector-prep-result-r4.json                    (authored)
evidence/metadata-limitations-r4.json                     (authored)
evidence/EVIDENCE-CONTEXT.md                              (authored)
SHA256SUMS                                                (authored)
```

**Plus this repository document (§31).** No other path was created.

## 7. R4 inspector identity

| field | value |
|---|---|
| path | `inspector/pip-installed-tree-source-inspector-s1-r4.py` |
| size | `95652` |
| lines | `1992` |
| SHA-256 | `8557498cc8d177a97b69b988deff88d932c13858f9183cc61ff3a03e9eaafe4b` |
| imports | standard library only (`argparse, base64, binascii, csv, hashlib, io, json, lzma, os, posixpath, stat, sys, tokenize, unicodedata` + deferred `zlib`); no `tarfile`/`zipfile`/`ast`/`subprocess` |

`INSPECTOR-SOURCE-REVIEW-R4 = PASS (PREPARED, NOT EXECUTED)` — direct byte-level review; not compiled/imported/AST-parsed.

## 8. Exact ZIP flag reconciliation (Correction A)

`reconcile_and_read_zip` requires `local_flags == central_flags` (whole word), a separate explicit UTF-8-bit equality check, and equality of method, CRC, comp_size, uncomp_size, raw filename bytes, and reconciliation of local + central extra fields. Any disagreement → `HOLD-ZIP-FLAG-MISMATCH` (flags) / `HOLD-ZIP-RECONCILE` (others) / `HOLD-ZIP-EXTRA-RECONCILE` (extras).

## 9. External-type classification (Correction B)

`_classify_external_type` binds create-system and full external attributes, derives file type and mode (Unix `S_IFMT` or DOS directory bit), and requires: regular entries → regular type; directory entries → directory type; directory name ends `/`; directory payload and CRC zero. A trailing slash alone is **not** sufficient. Symlink/FIFO/socket/device/special → `HOLD-ZIP-UNSAFE-MEMBER`; unsupported create-system or ambiguous mode → `HOLD-ZIP-EXTERNAL-TYPE` (Unix mode `0` falls back only to the accepted wheel artifact-format binding `{regular, directory}`).

## 10. Extra-field evidence model (Correction C)

`_parse_extra` + `_reconcile_extra` parse **both** local and central extras into `wheel-zip-extra-fields.tsv` (`subject_id, member, location{LOCAL|CENTRAL}, header_id, byte_size, payload_sha256, parse_disposition`). Duplicate ids within a field, malformed boundaries and non-allowlisted ids → HOLD. Local/central payload equality is required for all ids **except** `0x5455`/`0x7875` (extended-timestamp / Unix uid-gid), which legitimately differ — the ambiguity is resolved by explicit definition, not a HOLD.

## 11. XZ/TAR trailing-buffer closure (Correction D)

`XzDecompressReader.finalize()` first inspects the already-buffered bytes and requires the buffer **empty** before requesting any further input, then drains the decoder to exact XZ EOF requiring every subsequently produced byte count to be zero, no `unused_data`, and no trailing compressed source byte. Any decompressed byte after the two zero blocks → `HOLD-TAR-TRAILING-BYTES`. It does not rely on `_pump()` returning true before inspecting an already-populated buffer.

## 12. Complete TAR numeric/string-field validation (Correction E)

`_tar_octal_strict` applies strict nonnegative octal validation to **mode, uid, gid, size, mtime, checksum, devmajor, devminor** (sign / leading whitespace / embedded suffix / invalid octal rejected; base-256 → `HOLD-TAR-UNSUPPORTED-HEADER`; other malformed → `HOLD-TAR-NUMERIC-FIELD`). `_tar_string_nul_padded` enforces the exact NUL-padding policy on name/prefix/uname/gname/linkname (`HOLD-TAR-STRING-FIELD`). The `./` root alias is tracked in its own single-slot namespace; a repeated root alias → `HOLD-TAR-ROOT-ALIAS-REPEAT`.

## 13. WHEEL/METADATA parse model (Correction F)

`_parse_headers` is a bounded RFC822-style header parser with continuation-line handling; UTF-8 decode success alone is **not** "parsed". `METADATA` requires single `Metadata-Version`/`Name`/`Version`; `WHEEL` requires single `Wheel-Version` and ≥1 `Tag`. Every field is preserved to `wheel-header-fields.tsv` (`subject_id, source_path, kind, field_name, occurrence_index, value, line_range`). Malformed/ambiguous → `HOLD-WHEEL-HEADER-PARSE`.

## 14. Exact RECORD row/digest/size/self-row model (Correction G)

`_reconcile_record` + `_decode_record_digest` produce a 16-column `wheel-record-inventory.tsv`: `subject_id, wheel_member_path, record_row, escaped_original_raw_row, raw_path_field, normalized_path_field, digest_field, size_field, actual_member_sha256, actual_member_byte_size, digest_algorithm, decoded_expected_digest_hex, digest_match_disposition, size_match_disposition, relocation_classification, final_reconciliation_disposition`. Requires valid CSV, exactly three fields, supported digest algorithm (`sha256`), valid URL-safe base64, digest matching the actual member bytes, declared size matching the actual size, exactly one empty-digest/size self-row, no row for a missing member, no row referencing a nonexistent member. `size_field` is preserved. Format errors → `HOLD-WHEEL-RECORD-RECONCILE`; a semantic mismatch makes `wheel_record_fully_reconciled` false (WOP-02 → DYNAMIC-UNKNOWN), never a claimed complete reconciliation.

## 15. WOP-01 proof model (Correction H)

`wheel_structural_inventory_complete` — STATICALLY-SUPPORTED only when the complete direct ZIP byte reconciliation succeeded and the full member inventory (regular + directory) is preserved. Citation kind `ARCHIVE-STRUCTURE`: whole-wheel archive SHA-256 + `nested-member-inventory` row range. Distinct predicate from WOP-02.

## 16. WOP-02 proof model (Correction H)

`wheel_record_fully_reconciled` — STATICALLY-SUPPORTED only when every regular member has an exact reconciled original RECORD row (digest + size match) with the exact raw row preserved. Citation kind `WHEEL-RECORD`: RECORD member SHA-256 + row range.

## 17. Corrected WOP-04 model (Correction H)

`wheel_data_relocation_classified` is a **positive/STATICALLY-SUPPORTED** predicate: every original member carries exactly one relocation classification. It is never represented as STATICALLY-CONTRADICTED merely because no `.data` tree exists. Both `<distribution>-<version>.data` and `<distribution>-<version>.data/` are detected after normalization. Citation kind `ARCHIVE-STRUCTURE`.

## 18. Strict entry-point model (Correction H)

`_parse_entry_points` rejects an entry outside a section, an empty section, an empty entry name, an empty target, a duplicate section/name pair, and malformed extras (`HOLD-ENTRY-POINTS-PARSE`). `wheel_entry_points_present` (≥1 valid entry) cites `WHEEL-ENTRY-POINTS`; `wheel_entry_points_absent` cites the complete ZIP structural inventory (`ARCHIVE-STRUCTURE`), **not** RECORD.

## 19. Subject and archive-member boundary enforcement (Correction I)

`load_rules` validates each predicate subject is in the rule's `permitted_evidence_subjects` at load time. `resolve_question` re-validates predicate subjects before evaluation. `_validate_citation` enforces the citation's `subject` ∈ `permitted_evidence_subjects` **and** `archive_member` matches a `permitted_archive_members` glob (`_member_matches`). Any violation → `HOLD-CITATION-BOUNDARY`.

## 20. Citation evidence-kind schema (Correction I)

`contracts/S1-SEMANTIC-CITATION-SCHEMA.json` and the inspector's `CITATION_KINDS` define mandatory identity fields per kind: `ARCHIVE-STRUCTURE` (subject, archive_member, **archive_sha256**, inventory_row_range), `WHEEL-RECORD` (…, member_sha256, record_row_range), `WHEEL-ENTRY-POINTS` (…, member_sha256, source_line_range), `WHEEL-HEADER-METADATA` (…, member_sha256, header_line_range), `SOURCE-OCCURRENCE` (…, member_sha256, source_line_range, token_position). An archive-structure conclusion cites the whole-archive SHA-256 plus an inventory row range and never fabricates a content SHA-256 for a directory.

## 21. Exact path-map and path-map-hash validation (Correction J)

New required CLI argument `--subject-path-map-sha256 <64-HEX>`. `load_path_map` hashes the map bytes and requires them to equal the wrapper-authorized identity **before** parsing (`HOLD-SUBJECT-PATH-MAP-HASH`). It then requires exactly `{platform_family=Linux, safe_open=O_NOFOLLOW, subjects_read_only_regular_files=true, subjects}`, exactly six entries `{subject_id, execution_path, sha256}` with the exact subject IDs, absolute Linux `execution_path`, unique paths, and mandatory per-entry `sha256` equal to the manifest identity; no extra semantic field.

## 22. Updated semantic-core schema (Correction K)

13 covered core files + `SHA256SUMS` (13 manifest entries; excludes itself), adding `wheel-header-fields.tsv` and `wheel-zip-extra-fields.tsv`. No `stdout.log`/`stderr.log`/`exit-code.txt`; `source-inspection-result.json` sets `process_exit_status_not_claimed = true`. `commit_core` validates exactly 13 covered files and 13 manifest entries.

## 23. Synthetic parser-validation plan (Correction L)

`contracts/S1-PARSER-SYNTHETIC-VALIDATION-PLAN.json` defines 33 adversarial, non-production cases (differing local/central flags; regular type with trailing slash; special external type; malformed/duplicate extras; ZIP interval gap/overlap; DEFLATE trailing data; TAR bytes buffered after the two zero blocks; malformed UID/GID/mtime/device fields; repeated TAR root alias; malformed RECORD digest; incorrect RECORD size; missing/malformed RECORD self-row; malformed WHEEL/METADATA headers; entry point outside a section; duplicate entry point; path-map hash mismatch). **No synthetic archive body was created or executed in R4.** A separate parser-validation gate must pass before S1-EXECUTE.

## 24. HOLD/RED model

All technical/parser/schema/output/header/record/path-map failures → dedicated nonzero HOLD (71 unique exit codes). RED (`90`) is reserved exclusively for a directly detected authorization/scope violation (an output basename containing a path separator). A final `except Exception` → `HOLD-INTERNAL-UNCLASSIFIED (99)`. The inspector writes no failure bundle.

## 25. Source-review checklist result

`evidence/inspector-source-review-checklist-r4.md`: Corrections A–L each **PASS** by direct source review; standard-library-only imports confirmed; prohibited-API/subprocess scan matched only comment/string markers; conservative-resolver audit confirms exactly five statically resolvable questions and five forced-UNKNOWN pip-cooccurrence questions.

## 26. Preparation-root inventory

Root: `C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-s1-prep-r4` — **25 files** (1 inspector + 12 contracts + 11 evidence + `SHA256SUMS`), **4 directories** (root + inspector + contracts + evidence), matching the authorized structure exactly; no other path created.

## 27. Preparation-root SHA256SUMS identity and replay

`SHA256SUMS` — size `2519`, SHA-256 `1132ca25cd4e0a5295f563894f6bd5a47d06e3d633467b7e4b901895935660e2`, **24 entries** (excludes itself), replay **24/24 OK**.

## 28. Repository-document size and SHA-256

This document — see the accompanying orchestrator return for its exact byte size and SHA-256 (computed after write). `docs/result` untouched.

## 29. Source / main / evidence / body / archive / memory states — before and after

| item | before | after |
|---|---|---|
| main HEAD | `4873ac713397cf47642d39b1ef17e48a9301511d` | `4873ac713397cf47642d39b1ef17e48a9301511d` |
| spike HEAD | `4873ac713397cf47642d39b1ef17e48a9301511d` | `4873ac713397cf47642d39b1ef17e48a9301511d` |
| R4 prep root | ABSENT | CREATED (25 files; manifest 24/24) |
| R4 repo document | ABSENT | CREATED (this file) |
| R1 / R2 / R3 roots + documents | PRESERVED | UNCHANGED |
| design R1–R5, lock, governance closeouts, parser/canary, acquisition/ARTIFACT-INSPECT evidence | PRESERVED | UNCHANGED |
| every `.deb`/`.whl` body, image archive, known `.rar` | path-presence + `lstat` type only | UNCHANGED (never opened) |
| project memory | PRESERVED | UNMODIFIED |

## 30–37. Confirmations

- **30** No preexisting R4 file was adopted — both R4 paths were absent; all 25 root files + this document were authored under this authorization (manifest and question contract reproduced byte-identical to accepted identities).
- **31** No existing file changed — R4 created only new paths; R1/R2/R3 and all repository files untouched.
- **32** Nothing staged; no commit; no PR.
- **33** No inspector or synthetic fixture was executed, imported, compiled, byte-compiled or AST-parsed (read as bytes/text only).
- **34** No package or archive body (`.deb`/`.whl`/image/`.rar`) was opened, listed, hashed or parsed.
- **35** No path map, parser validation, isolation, collector, builder-context, Docker, network, database or later gate began; no synthetic archive fixture was created.
- **36** No temporary, placeholder, sidecar, cache, bytecode or backup path was created; only final authorized paths were written.
- **37** The known `.rar` was checked by path presence only.

## 38. Exact next recommendation

```
PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R4
```

On acceptance, separately authorize (in order): **PARSER-VALIDATION** (synthetic fixtures per `S1-PARSER-SYNTHETIC-VALIDATION-PLAN.json`), then **S1-EXECUTE** (bind the exact CPython 3.11 interpreter byte identity + a six-entry Linux `S1-EXECUTION-SUBJECT-PATH-MAP.json` + `--subject-path-map-sha256`; isolated spike branch), then ISOLATION-PREP, C1-COLLECTOR-PREP, BUILDER-CONTEXT-PREP, then C1 execution. RBF-15 and RBF-04 remain OPEN.

Preparation stops at the clean-room R4 source-preparation unit.
