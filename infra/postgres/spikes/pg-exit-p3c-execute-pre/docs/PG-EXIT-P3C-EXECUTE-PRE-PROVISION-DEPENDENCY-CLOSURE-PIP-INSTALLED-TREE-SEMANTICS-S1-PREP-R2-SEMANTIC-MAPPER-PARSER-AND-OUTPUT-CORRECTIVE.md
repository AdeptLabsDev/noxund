# PG-EXIT · P3C · EXECUTE-PRE · DEPENDENCY-CLOSURE · PIP-INSTALLED-TREE-SEMANTICS · S1-PREP-R2 (SEMANTIC-MAPPER-PARSER-AND-OUTPUT-CORRECTIVE)

**Unit:** `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R2-SEMANTIC-MAPPER-PARSER-AND-OUTPUT-CORRECTIVE`
**Authored:** 2026-08-04 · NOXUND Product Orchestrator
**Disposition:** `PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R2-PASS-SOURCE-CORRECTED-NOT-EXECUTED`
**Recommendation:** `PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R2`

Source-preparation **corrective** only. Nothing was executed. No package or wheel body was opened.
`RBF-15` remains **OPEN**.

---

## 1. Corrected R1 disposition

R1 was HELD after direct Product review:
- `PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R1-HOLD-SEMANTIC-MAPPER-PARSER-AND-OUTPUT-CONTRACT-FAILED`
- `INSPECTOR-SOURCE-REVIEW-R1 = REJECTED-FALSE-GREEN`
- No governance scope breach for R1. The R1 bundle is identity-valid; its inspector source is not authorized for execution.

## 2. R1 direct-review identities (verified now on disk; R1 preserved unchanged)

| item | value |
|---|---|
| R1 ZIP | size `37488` · sha `22c8cc96c8621f37f1d0240c402878d8605e671ebd8a6108fe46259107db53cb` |
| R1 repo document | size `9414` · sha `af5274719a8d5cf7382bebfad176aba30cde6824ecbda514bce9b7c0694b94eb` |
| R1 inspector | size `50307` · lines `1089` · sha `bd27aa71d81f9701b01442e087636b2af984b763056f1d565dd37ec4932c7fc2` |
| R1 root SHA256SUMS | size `1339` · sha `8ddbde7f7a7ad4a3372acdfade274ce45cd57d2694328db0f1aa2277cb87cf7d` |
| manifest replay | `13/13` · regular files `14` · ZIP dir entries `4` · JSON files `9` |

## 3. Preserved R5 and RBF states

`PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R5 = ACCEPTED-DESIGN-ONLY`. **OPEN:** `RBF-15` (metadata semantics unproven; static inspection alone must not close it) and `RBF-04`. R5-BN-01/02/03 recorded, not acted on. **Unauthorized (unchanged):** S1-EXECUTE, ISOLATION-PREP, C1-COLLECTOR-PREP, BUILDER-CONTEXT-PREP, C1 EXECUTION, BUILD-PREP.

## 4. R2 inspector identity

`inspector/pip-installed-tree-source-inspector-s1-r2.py` — size **69166** · lines **1493** · sha **`a88c1646b026192a26c6d3a1fcc07d93ab7f164c78089a3254c0d20711c09e23`**. Standard-library only; not executed/imported/compiled/AST-parsed.

## 5. Exact input-contract hash bindings (Correction A)

Bound as source constants and enforced (full SHA-256, not just cardinality):
- subject manifest `d41618d9932b95f4cee41da3efa33f235bd9de63d2c3163f648318e870fb6e1c`
- question contract `c85e29436dfe50694685bb1e106a9009a3e9b5fb958e2d132fc4a328f17ba69d`
- question rules `5e0a3a61189bad3c02904b020d2c158c6669687a08a06b3cae90289ec0da456e`

Finite input-byte limits are bound and enforced before decoding each contract.

## 6. Six-subject allowlist + 64-question validation

Exactly six subject IDs required (`S1-01-python3-pip … S1-06-typing-extensions-wheel`), each with exact subject_id/kind/logical_package/version/architecture/size/sha256/archive-format; rejects duplicate ID, duplicate normalized path, duplicate underlying identity, unknown/missing subject, changed kind/format, extra manifest field, manifest identity mismatch. Question contract: **64** IDs / question text / category / resolution source / pre-disposition / **9** categories; rejects any changed/missing/duplicated/additional question; identity is the full SHA-256.

## 7. One-open subject identity (Correction B)

`lstat` → require regular file → reject symlink/junction/reparse/special → `O_NOFOLLOW` open once → identity+size from the descriptor → **hash through that descriptor** → rewind → **parse through the same descriptor** → post-parse `fstat` → require unchanged identity+size. Never hashes one opening and parses another. `HOLD-NOFOLLOW-UNAVAILABLE` if safe no-follow cannot be established.

## 8. Question-rule contract + 64/64 coverage (Correction C)

`contracts/S1-QUESTION-RULES.json` — **64 rules, 64 unique IDs, exact coverage** vs the question contract (0 missing / 0 extra), 64 unique reasoning-rule IDs, every `default_outcome = DYNAMIC-UNKNOWN`. Each rule binds permitted evidence subjects, permitted archive members, positive/contradiction/NOT-APPLICABLE predicates, ambiguity conditions, default outcome and a reasoning-rule ID. Prohibits single-identifier resolution, shared-generic-marker resolution, wrong-distribution markers, setuptools/wheel-as-pip without an exact call/path relationship, treating occurrence as control-flow proof, and treating absence as evidence unless the inventory is complete.

## 9. Static-proof, codepath, metadata, result & residual models (Corrections D–F)

- **Codepath (D):** full occurrence table — every relevant occurrence with subject, member, member SHA-256, normalized path, token kind, identifier/literal, containing definition, exact start/end line+col and a bounded supporting range; later occurrences never discarded; `pip-codepath-map.tsv` is actual occurrences + question-rule association, not a predefined marker list; token analysis never claims control flow.
- **Wheel metadata / RECORD (E):** exact bytes + SHA-256 + size + encoding, complete bounded parse; original RECORD via stdlib `csv` preserving row/path/digest/size/duplicate-normalized; entry-point presence/absence from the complete inventory; `.data` detected as `<distribution>-<version>.data/`; distribution-specific; original-wheel absence is never post-install proof.
- **Results (F):** one row per question with question_id, category, resolution_source, outcome, evidence_class, citation_count, canonical citations JSON, reasoning_rule_id and residual/ambiguity reason; every non-UNKNOWN carries ≥1 complete citation (subject + member + member SHA-256 + normalized path + line/record range); `unresolved-dynamic-behavior.json` records a reason per unresolved question.

## 10. Corrected parsers (Corrections G–J)

- **Path (G):** rejects NUL/backslash/TAB/CR/LF/other control/surrogate/non-reversible-Unicode/absolute/drive/traversal/over-length; duplicate + type + case + NFC collisions across files, directories and directory/file pairs; explicit root-alias (`.`/empty only as a permitted zero-size root directory header, recorded `(root)`, never a regular member); all TSV cells free of TAB/CR/LF.
- **`ar` (H):** strict ASCII; pad byte **read and validated** (newline) after every odd-sized member; `debian-binary` size `4` and bytes `2.0\n`; exact three-member order; zero overlap; zero trailing.
- **Nested XZ/TAR (I):** direct 512-byte TAR reader over a bounded xz decompressor; **shared** per-subject member count (≤20000 across both), decompressed bytes (≤256 MiB across both) and text bytes; per-stream ratio ≤200:1; complete compressed consumption; no concatenated/trailing xz; two-zero-block terminator and **no bytes after it**; GNU long-name/long-link, PAX extended/global, sparse and link/special typeflags **HOLD** (never transparently consumed); padding read and verified zero.
- **Wheel ZIP (J):** direct EOCD/central/local reconciliation (file size, CD start/end, zero prefixed data, zero unaccounted trailing, name+method local↔central match, member count vs EOCD, duplicate raw/normalized, comment policy, directory zero payload) + raw zlib inflate with CRC-32 via complete reads; `zipfile` not used, so no transparent behavior can mask a disagreement; any stdlib limitation is HOLD, never a silent pass.

## 11. Output commit, non-PASS policy, exception model, output schema (Corrections K–N)

- **Commit (K):** the success output root stays absent until all subjects are inspected, all questions resolved/UNKNOWN, all bytes prepared, names equal the exact set, and counts/bounds validated; then create exclusively, write each file with a complete write loop + fsync, reread and reproduce size+SHA-256, write `SHA256SUMS` last, reread+reproduce the manifest, require exactly 12 covered files/entries, and return zero only after on-disk reproduction. Output-byte limit includes the manifest.
- **Non-PASS (L):** no pre-validation failure bundle; pre-commit failures leave the output root **absent**; a mid-commit failure preserves the partial root (no completeness `SHA256SUMS`, no retry/overwrite/delete). A future S1-EXECUTE wrapper preserves real process stdout/stderr/exit for non-PASS runs.
- **Exceptions (M):** all technical/parser/decoding/filesystem/archive/schema/bounds failures are dedicated HOLD codes; a final `except Exception` returns `HOLD-INTERNAL-UNCLASSIFIED` (99); `RED` (90) is reserved for a detected write-outside-root scope breach only.
- **Schema (N):** 12 covered outputs + `SHA256SUMS` (manifest excludes itself), no missing/extra; `source-inspection-result.json` records `S1 = REQUIRED-BUT-INSUFFICIENT-ALONE`, `RBF-15 = OPEN`, `static_evidence_is_not_observed_behavior = true`; a PASS may contain `DYNAMIC-UNKNOWN`.

## 12. Source-review checklist result

`INSPECTOR-SOURCE-REVIEW-R2 = PASS (PREPARED, NOT EXECUTED)` — imports (stdlib only), prohibited-API scan (comments/docstrings only), and every A–N correction verified in source (`evidence/inspector-source-review-checklist-r2.md`).

## 13. Preparation-root inventory + manifest

Root `C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-s1-prep-r2` — 3 subdirs, **17 covered files** (1 inspector + 8 contracts + 8 evidence) + `SHA256SUMS`. `SHA256SUMS` size **1749** · sha **`74b2de572d8497faf2b8357746e9523b3ed1e339595a1052398d5fe9e988ac0b`** · replay **17/17 OK**. No other path; no pycache/tmp/bak/sidecar/bytecode.

## 14. Source / preservation state (before == after)

| item | before | after |
|---|---|---|
| main HEAD | `4873ac713397cf47642d39b1ef17e48a9301511d` | unchanged |
| spike HEAD | `4873ac713397cf47642d39b1ef17e48a9301511d` | unchanged |
| staged / commit / PR | none | none |
| R2 prep root | ABSENT | CREATED |
| R2 repo output file | ABSENT (no HOLD) | CREATED (this file) |
| S1-PREP-R1 root + document; designs R1–R5; lock; governance; parser/canary; acquisition/ARTIFACT-INSPECT; every `.deb`/`.whl`; image archive; `.rar`; memory | preserved | unchanged |

Confirmations: no existing file changed; nothing staged/committed; no PR; neither inspector executed/imported/compiled/AST-parsed; no `.deb`/`.whl`/image/`.rar` body opened/listed/hashed/parsed; known `.rar` path-presence only; no isolation/collector/Docker/network/database/later gate began; no temporary/unauthorized path created; `docs/result` untouched; project memory unmodified; the copied subject manifest and question contract are byte-identical to their accepted R1 identities; the lock was contextual evidence only (not copied into a build context; pip not executed).

## 15. Next

`PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R2`. On acceptance, separately authorize in order: **S1-EXECUTE** (bind exact CPython 3.11 interpreter byte identity; isolated spike branch) → ISOLATION-PREP → C1-COLLECTOR-PREP → BUILDER-CONTEXT-PREP → C1 execution. `RBF-15` can be closed only by C1 dynamic observation.

*Stop after S1-PREP-R2.*
