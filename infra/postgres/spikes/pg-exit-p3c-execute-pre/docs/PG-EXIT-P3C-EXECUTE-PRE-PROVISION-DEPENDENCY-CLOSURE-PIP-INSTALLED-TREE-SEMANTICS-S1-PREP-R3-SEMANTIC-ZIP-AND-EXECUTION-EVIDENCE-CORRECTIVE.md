# PG-EXIT · P3C · EXECUTE-PRE · PIP-INSTALLED-TREE-SEMANTICS · S1-PREP-R3

**Unit:** `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R3-SEMANTIC-ZIP-AND-EXECUTION-EVIDENCE-CORRECTIVE`
**Type:** source-preparation corrective — **PREPARED, NOT EXECUTED**.
**Authored:** 2026-08-06 · NOXUND Product Orchestrator.
**Authority:** Product Lead authorization (this gate only).

## 1. Disposition

```
PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R3-PASS-SOURCE-CORRECTED-NOT-EXECUTED
```

Recommendation:

```
PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R3
```

The corrected inspector source and its contracts/evidence are prepared and internally consistent.
Nothing was executed, imported, compiled, byte-compiled or AST-parsed; no package/archive body was
opened; no path map, isolation, collector, Docker, network, database or later gate began.

## 2. Corrected R2 disposition

```
PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R2-HOLD-SEMANTIC-ZIP-AND-EXECUTION-EVIDENCE-CONTRACT-FAILED
INSPECTOR-SOURCE-REVIEW-R2 = REJECTED-FALSE-GREEN-AND-INCOMPLETE-PARSER
```

No governance scope breach is recorded for S1-PREP-R2. The R2 evidence bundle is identity-valid; its
inspector source was not authorized for execution. S1-PREP-R2 and its repository document are
preserved unchanged.

## 3. R2 direct-review identities (verified now on disk)

| subject | size | SHA-256 |
|---|---|---|
| R2 ZIP | `55395` | `cc83bf0e219426a0dec30f26afdc3e4f6450825bd66db3f283f683b7fa540d21` |
| R2 repository document | `11062` | `dc92f0991e831dddb8fb49d489c5ada092288a71bd1c4b76383c9b700f249eeb` |
| R2 inspector | `69166` (1493 lines) | `a88c1646b026192a26c6d3a1fcc07d93ab7f164c78089a3254c0d20711c09e23` |
| R2 root SHA256SUMS | `1749` | `74b2de572d8497faf2b8357746e9523b3ed1e339595a1052398d5fe9e988ac0b` |

manifest replay `17/17` · regular files `18` · ZIP directory entries `4` · JSON files `12`.
The R2 inspector, repository document and root SHA256SUMS were re-hashed this session and match the
authorized identities exactly.

## 4. Preserved R5 and RBF states

- `PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R5 = ACCEPTED-DESIGN-ONLY`
  (`…DESIGN-R5-PASS-ABI-NAMESPACE-AND-FREEZE-EVIDENCE-BOUND-NOT-EXECUTED`; ZIP `f1571bf4…`, doc
  `995531b0…`, SHA256SUMS `4b36a14f…`, manifest 22/22).
- **R5-BN-01** — PAX implementation bytes remain UNACCEPTED until C1-COLLECTOR-PREP source review + test vectors. R3's TAR reader requires exact POSIX ustar and HOLDs on PAX / GNU long-name, consistent with this.
- **R5-BN-02**, **R5-BN-03** — carried forward unchanged.
- **RBF-15** — `PIP-INSTALLED-TREE-METADATA-SEMANTICS-UNPROVEN` — kept **OPEN**; static inspection alone must not close it.
- **RBF-04** — `ENTRYPOINT-RUNTIME-BEHAVIOR-UNPROVEN` — kept **OPEN**; out of S1 scope.

## 5. R3 inspector identity

| field | value |
|---|---|
| path | `inspector/pip-installed-tree-source-inspector-s1-r3.py` |
| size | `76107` |
| lines | `1612` |
| SHA-256 | `b435c1b8a37dca2bee389adbe4840bca5b070309ccfa4b1f19149c9d00f17a89` |
| imports | standard library only (`argparse, csv, hashlib, io, json, lzma, os, posixpath, stat, sys, tokenize, unicodedata` + deferred `zlib`); no `tarfile`/`zipfile`/`ast`/`subprocess` |

`INSPECTOR-SOURCE-REVIEW-R3 = PASS (PREPARED, NOT EXECUTED)`, established by direct byte-level review
in this session (full read of all 1612 lines; not compiled/imported/AST-parsed).

## 6. Exact input-contract identities

| contract | SHA-256 | note |
|---|---|---|
| `S1-SUBJECT-MANIFEST.json` | `d41618d9932b95f4cee41da3efa33f235bd9de63d2c3163f648318e870fb6e1c` | byte-identical to accepted R2 |
| `S1-QUESTION-CONTRACT.tsv` | `c85e29436dfe50694685bb1e106a9009a3e9b5fb958e2d132fc4a328f17ba69d` | byte-identical to accepted R2 |
| `S1-QUESTION-RULES.json` | `4d5a1cb57ca910c980470fbf659c74af9713da9ebc5b04e6537ad9602c0a7eed` | corrected rules (bound as a source constant in the inspector) |

## 7. Execution-subject-path-map schema (Correction H)

`contracts/S1-EXECUTION-SUBJECT-PATH-MAP-SCHEMA.json` — schema for the **future**
`S1-EXECUTION-SUBJECT-PATH-MAP.json` consumed via `--subject-path-map`. It binds exactly six
execution paths for **one** selected platform while preserving every immutable subject identity
(`subject_id, logical_package, version, architecture, size, sha256, archive_format`) from the
manifest. Validation: 6 unique paths; `platform_family == Linux`; each subject opened once, no-follow,
regular file; cross-subject `(st_dev, st_ino)` unique; each re-hashed to equal the manifest identity;
HOLD if the Linux read-only no-follow contract cannot be established. **R3 creates no map and mounts
nothing.**

## 8. Linux / no-follow future execution boundary

Selected for R3 source compatibility: `execution platform family = Linux`, `safe open = O_NOFOLLOW`,
`subjects = read-only regular files`. S1-EXECUTE must additionally bind the exact CPython 3.11
interpreter byte identity. If S1-EXECUTE cannot establish this Linux contract, it returns HOLD.

## 9. One-open pre/post hash model (Correction G)

`OpenSubject` performs a single no-follow open per subject, hashes **before** parse, parses through the
same descriptor, rewinds, hashes **after** parse and requires the post digest and length to equal the
pre values; it also requires `(st_dev, st_ino, st_size, st_mtime_ns)` unchanged across parse. Any
mutation → `HOLD-SUBJECT-IDENTITY-MISMATCH`.

## 10. Cross-subject underlying-identity rejection

A shared `identity_registry` records `(st_dev, st_ino)` for all six opened subjects; a duplicate
underlying file identity → `HOLD-DUP-UNDERLYING-IDENTITY`.

## 11. Semantic-rule contract identity

`contracts/S1-QUESTION-RULES.json` (`4d5a1cb5…`): 64 rules, 64 unique ids, every `default_outcome`
= `DYNAMIC-UNKNOWN`, every rule carries a `reasoning_rule_id`. Predicate vocabulary is restricted to
four wheel-evidence types (`wheel_record_reconciled`, `wheel_data_relocation_absent`,
`wheel_entry_points_present`, `wheel_entry_points_absent`); no pip-cooccurrence predicate exists.

## 12. Enforced permitted-subject/member boundaries (Corrections B, L)

`_validate_citation` requires every citation to carry nonempty `subject`, `archive_member`,
`member_sha256`, `normalized_path`, `line_or_record_range`, **and** a `subject` within the rule's
`permitted_evidence_subjects`; otherwise `HOLD-CITATION-BOUNDARY`. Occurrences are keyed by
`(subject, container, normalized source path, member SHA-256, token position)` with no cross-subject or
cross-file aggregation.

## 13. Conservative pip-codepath policy (Corrections A, M)

`pip-codepath-map.tsv` is an occurrence inventory only. Containing-definition is produced by an exact
`tokenize` INDENT/DEDENT state machine (method column `TOKENIZE-INDENT-DEDENT`). Every row is tagged
`semantic_status = CANDIDATE-EVIDENCE-ONLY-NOT-SEMANTIC-PROOF`. No occurrence can independently produce
a semantic disposition; token co-occurrence never proves a call relationship, control flow, install
behavior, output bytes/ordering, or metadata creation/omission.

## 14. Questions forced to DYNAMIC-UNKNOWN

The five questions named by Correction A are forced UNKNOWN via `ambiguity_conditions`:
`RECORD-01, RECORD-05, INSTALLER-05, REQUESTED-PSY-03, REQUESTED-TE-03`. In total **59 of 64**
questions resolve `DYNAMIC-UNKNOWN`; only **5** can produce a non-UNKNOWN static outcome —
`WOP-01, WOP-02, WOP-04, SCRIPTS-01, SCRIPTS-02`.

## 15. WOP member and RECORD reconciliation (Correction C)

- **WOP-01** may be `STATICALLY-SUPPORTED` only when the complete member inventory for both wheels is preserved and reconciled.
- **WOP-02** produces one row per original wheel member in `wheel-record-inventory.tsv`:
  `subject, wheel_path, record_row (or explicit absence), raw_record_path, normalized_record_path, digest_field, member_sha256, relocation_class, reconciliation_disposition`. A parsed RECORD file alone is not sufficient.

## 16. `.data` relocation model (Correction C/WOP-04)

Each original member is classified `DATA-RELOCATION-APPLIES:<scheme>` /
`DATA-RELOCATION-DOES-NOT-APPLY` against the exact `<distribution>-<version>.data/<scheme>/...`
mapping; WOP-04 is supported only when reconciliation holds and no `.data` tree is present.

## 17. Entry-point parsing model (Correction C/SCRIPTS-01/02)

`entry_points.txt` is fully parsed into `wheel-entry-points.tsv`
(`subject_id, section, entry_name, target, extras, source_line`). Presence of the file is not proof
of a declared entry point; absence is concluded only from a complete wheel inventory + complete
entry-point parse.

## 18. Wheel metadata output models (Correction D)

`wheel-metadata-inventory.tsv` (`subject_id, normalized_path, size, sha256, encoding,
line_or_record_count, metadata_kind, parse_disposition`) plus `wheel-record-inventory.tsv` and
`wheel-entry-points.tsv`. `METADATA`, `WHEEL`, original `RECORD` and `entry_points.txt` are completely
parsed when present; RECORD paths are subject to the full archive-path policy (malformed CSV,
duplicate/absolute/traversal/backslash/control/invalid-Unicode/normalization/case collisions rejected).
Original-wheel absence of generated installation metadata is never represented as post-install absence.

## 19. Complete ZIP byte-coverage model (Correction E)

`reconcile_and_read_zip` binds every byte from offset 0 through the EOCD via interval tiling
(`local-header`, `data`, `central-directory`, `eocd` intervals must tile `[0, file_size)` with zero
prefix/gap/overlap/trailing). EOCD bounds exact; single-disk only; archive/entry comments rejected;
`cd_offset + cd_size == eocd_offset`. Local↔central raw filename bytes, method, flags, CRC and sizes
reconciled; strict UTF-8 name decoding (no replacement).

## 20. External-attribute and special-file policy (Correction E)

Create-system and external attributes are parsed; Unix symlink/special modes
(`0o120000/0o140000/0o010000/0o020000/0o060000`) → `HOLD-ZIP-UNSAFE-MEMBER`. Directory entries require
directory type, zero compressed and zero uncompressed payload, zero CRC.

## 21. Strict DEFLATE terminal checks (Correction E)

For method 8: `decompressobj(-15)`, then require decoder `eof`, `unused_data == b""`,
`unconsumed_tail == b""`, exact compressed-byte consumption, exact uncompressed size, and exact CRC-32;
any failure → `HOLD-ZIP-DEFLATE-TERMINAL` / `HOLD-ZIP-RECONCILE`.

## 22. Strict TAR/XZ corrections (Correction F)

Exact USTAR magic (`ustar\0`) + version (`00`); strict nonnegative octal fields (no sign/whitespace/
suffix); base-256 rejected; explicit XZ `memlimit = 512 MiB`; complete XZ consumption
(`eof`, no `unused_data`, no trailing compressed bytes); complete TAR termination (two zero blocks, no
data after); **separate collision namespaces per `control.tar.xz` / `data.tar.xz`**; shared per-subject
byte/member ceilings preserved.

## 23. Exact semantic-core output schema (Correction I)

Semantic core = exactly 11 covered files + `SHA256SUMS`:
`subject-binding.json, outer-archive-inventory.tsv, nested-member-inventory.tsv,
source-member-inventory.tsv, wheel-metadata-inventory.tsv, wheel-record-inventory.tsv,
wheel-entry-points.tsv, pip-codepath-map.tsv, semantic-question-results.tsv,
unresolved-dynamic-behavior.json, source-inspection-result.json` (+ `SHA256SUMS`, 11 manifest
entries, excludes itself). The inspector generates **no** `stdout.log`/`stderr.log`/`exit-code.txt`,
and `source-inspection-result.json` sets `process_exit_status_not_claimed = true`.

## 24. Future wrapper-envelope schema (Correction J)

`contracts/S1-EXECUTION-ENVELOPE-SCHEMA.json` — a separately authorized S1-EXECUTE wrapper owns
`stdout.log, stderr.log, exit-code.txt, core-bundle-binding.json, execution-result.json` (+
`SHA256SUMS`, 5 manifest entries, excludes itself). A semantic core is accepted only when process exit
is zero, no signal/timeout occurred, the exact core exists, its manifest replays, and
`execution-result.json` declares PASS. A core manifest alone is never proof of successful execution.

## 25. Anchored output-write model (Correction K)

`commit_core` creates the output root exclusively, opens it as a directory descriptor, and writes only
allowlisted basenames relative to that descriptor (`openat`, `O_NOFOLLOW`, `O_EXCL`); path separators
in an output name → RED. Complete write loops; fsync every file; fsync the directory; reread through
the anchored descriptor and reproduce size + SHA-256. No `realpath()` write authority.

## 26. Incomplete-core interpretation policy (Correction K/N)

A commit-time failure returns nonzero, preserves the incomplete root, and never retries/overwrites/
deletes; the future execution envelope must mark it non-PASS regardless of any partial `SHA256SUMS`.

## 27. Exception and HOLD/RED model (Correction N)

All technical/parser/schema/output failures → dedicated nonzero HOLD. RED (`90`) is reserved
exclusively for a directly detected authorization/scope violation (output basename containing a path
separator). A final `except Exception` → `HOLD-INTERNAL-UNCLASSIFIED (99)`. The inspector writes no
failure bundle; actual non-PASS stdout/stderr/exit belong to the future wrapper envelope.

## 28. Source-review checklist result

`evidence/inspector-source-review-checklist-r3.md`: Corrections A–N each **PASS** by direct source
review; standard-library-only imports confirmed; prohibited-API/subprocess scan matched only
comment/string markers; conservative-resolver audit confirms exactly five statically resolvable
questions and five forced-UNKNOWN questions.

## 29. Preparation-root inventory

Root: `C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-s1-prep-r3` — **22 files**
(1 inspector + 10 contracts + 10 evidence + `SHA256SUMS`), matching the authorized structure exactly;
no other path created.

```
inspector/pip-installed-tree-source-inspector-s1-r3.py        76107
contracts/S1-SUBJECT-MANIFEST.json                             4678
contracts/S1-QUESTION-CONTRACT.tsv                             9459
contracts/S1-QUESTION-RULES.json                              31244
contracts/S1-OUTPUT-SCHEMA.json                                3551
contracts/S1-EXECUTION-ENVELOPE-SCHEMA.json                    1866
contracts/S1-EXECUTION-SUBJECT-PATH-MAP-SCHEMA.json            2389
contracts/S1-PARSER-CONTRACT.json                              7001
contracts/S1-PATH-POLICY.json                                  3032
contracts/S1-BOUNDS.json                                       1923
contracts/S1-ERROR-MODEL.json                                  3688
evidence/r2-direct-review-binding-r3.json                      1706
evidence/r5-acceptance-binding-r3.json                         2143
evidence/prior-evidence-bindings-r3.json                       3608
evidence/source-correction-ledger-r3.tsv                       3587
evidence/semantic-rule-audit-r3.tsv                            8242
evidence/zip-byte-coverage-contract-r3.json                    2555
evidence/inspector-source-review-checklist-r3.md               4869
evidence/inspector-prep-result-r3.json                         5494
evidence/metadata-limitations-r3.json                          4072
evidence/EVIDENCE-CONTEXT.md                                   5519
SHA256SUMS                                                     2189
```

## 30. Preparation-root SHA256SUMS identity and replay

`SHA256SUMS` — size `2189`, SHA-256 `b909f4c2d5affebb7dffd50629f742e068aea9c3de6b5eaf55ee77959eeca758`,
**21 entries** (excludes itself), replay **21/21 OK**.

## 31. Repository-output identity

This document:
`infra/postgres/spikes/pg-exit-p3c-execute-pre/docs/PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R3-SEMANTIC-ZIP-AND-EXECUTION-EVIDENCE-CORRECTIVE.md`.
It did not exist before this gate (no HOLD trigger) and was created here. `docs/result` untouched.

## 32. Source / main / evidence / body / archive / memory states — before and after

| item | before | after |
|---|---|---|
| main HEAD | `4873ac713397cf47642d39b1ef17e48a9301511d` | `4873ac713397cf47642d39b1ef17e48a9301511d` |
| spike HEAD | `4873ac713397cf47642d39b1ef17e48a9301511d` | `4873ac713397cf47642d39b1ef17e48a9301511d` |
| R3 prep root | PRESENT-PARTIAL (18/22) | FINALIZED (22/22; manifest 21/21) |
| R3 repo document | ABSENT | CREATED (this file) |
| R1 / R2 roots + documents | PRESERVED | UNCHANGED |
| R1–R5 design roots + documents, lock root, governance closeouts, parser/canary evidence, acquisition/ARTIFACT-INSPECT evidence | PRESERVED | UNCHANGED |
| every `.deb`/`.whl` body, image archive, known `.rar` | path-presence + `lstat` type only | UNCHANGED (never opened) |
| project memory | PRESERVED | UNMODIFIED |

## 33–39. Confirmations

- **33** No existing file changed — only four new files were created in the R3 root (the four missing finalization files) plus this repository document; the 18 pre-existing R3 files were adopted after direct byte verification and left untouched.
- **34** Nothing staged; no commit; no PR.
- **35** No inspector was executed, imported, compiled, byte-compiled or AST-parsed (read as bytes/text only).
- **36** No package or archive body (`.deb`/`.whl`/image/`.rar`) was opened, listed, hashed or parsed.
- **37** No path map, isolation, collector, Docker, network, database or later gate began.
- **38** No temporary, placeholder, sidecar, cache, bytecode or backup path was created; only final authorized paths were written.
- **39** The known `.rar` was checked by path presence only.

## 40. Exact next recommendation

```
PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R3
```

On acceptance, separately authorize (in order): **S1-EXECUTE** (bind the exact CPython 3.11
interpreter byte identity + a six-entry Linux `S1-EXECUTION-SUBJECT-PATH-MAP.json`; isolated spike
branch), then ISOLATION-PREP, C1-COLLECTOR-PREP, BUILDER-CONTEXT-PREP, then C1 execution. RBF-15 and
RBF-04 remain OPEN and can be closed only by C1 dynamic observation.

Preparation stops at S1-PREP-R3.
