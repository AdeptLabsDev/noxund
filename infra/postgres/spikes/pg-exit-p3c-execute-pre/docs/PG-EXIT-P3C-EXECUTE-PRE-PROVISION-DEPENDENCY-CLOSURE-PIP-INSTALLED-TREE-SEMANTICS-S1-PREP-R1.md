# PG-EXIT · P3C · EXECUTE-PRE · DEPENDENCY-CLOSURE · PIP-INSTALLED-TREE-SEMANTICS · S1-PREP-R1

**Unit:** `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R1`
**Authored:** 2026-08-04 · NOXUND Product Orchestrator
**Disposition:** `PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R1-PASS-SOURCE-PREPARED-NOT-EXECUTED`
**Recommendation:** `PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R1`

This unit **prepares** one bounded static **source inspector** for the pip installed-tree
semantics question, plus its contracts and direct-review evidence. Nothing was executed.
No package or wheel body was opened. `RBF-15` remains **OPEN**.

---

## 1. What was authorized vs. produced

Authorized: preparation and direct-review evidence for the bounded static source inspector.
**Not** authorized: executing the inspector, or opening any package/wheel body.

Produced (outside the repo, Product-controlled prep root
`C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-s1-prep-r1`):

```
inspector/pip-installed-tree-source-inspector-s1-r1.py   50307 B · 1089 lines · sha256 bd27aa71d81f9701b01442e087636b2af984b763056f1d565dd37ec4932c7fc2
contracts/S1-SUBJECT-MANIFEST.json
contracts/S1-QUESTION-CONTRACT.tsv                       sha256 c85e29436dfe50694685bb1e106a9009a3e9b5fb958e2d132fc4a328f17ba69d
contracts/S1-OUTPUT-SCHEMA.json
contracts/S1-PARSER-CONTRACT.json
contracts/S1-PATH-POLICY.json
contracts/S1-BOUNDS.json
evidence/r5-acceptance-binding-r1.json
evidence/prior-evidence-bindings-r1.json
evidence/inspector-source-review-checklist-r1.md
evidence/inspector-prep-result-r1.json
evidence/metadata-limitations-r1.json
evidence/EVIDENCE-CONTEXT.md
SHA256SUMS                                               size 1339 · sha256 8ddbde7f7a7ad4a3372acdfade274ce45cd57d2694328db0f1aa2277cb87cf7d · replay 13/13 OK
```

This repository document is the single authorized repository output.

---

## 2. R5 acceptance and direct-review binding (verified now on disk)

`PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R5 = ACCEPTED-DESIGN-ONLY` — no governance scope breach.

| item | size | SHA-256 |
|---|---|---|
| R5 ZIP | 31435 | `f1571bf4798057e3cc8793260a694b5b915de24b19c03abdf8a801a4da6bbbbc` |
| R5 repository document | 13811 | `995531b033fcadf59bbc59a4404fc9c8498ad2914e7c129c260a481bf4e31ae1` |
| R5 root SHA256SUMS | 2430 | `4b36a14f16396b2660aaab4a83c3243bee53ae199a7b6159a524752b80f68351` |

manifest replay `22/22`; evidence files `22`; total regular files `23`; directories `2`; JSON files `20`.

**R5 binding notes (recorded, not acted on):** R5-BN-01 (PAX impl bytes unaccepted until C1-COLLECTOR-PREP),
R5-BN-02 (ISOLATION-PREP must bind procfs/cgroupfs + supervisor-not-in-child-cgroup + reproduce BPF),
R5-BN-03 (negative process/preservation claims attested, not forensically reconstructable). None of these
were begun.

---

## 3. Preserved / unauthorized states

- **OPEN:** `RBF-15 — PIP-INSTALLED-TREE-METADATA-SEMANTICS-UNPROVEN`. Static inspection alone must not close it. (`RBF-04` also remains OPEN, out of S1 scope.)
- **Unauthorized (unchanged):** `S1-EXECUTE`, `ISOLATION-PREP`, `C1-COLLECTOR-PREP`, `BUILDER-CONTEXT-PREP`, `C1 EXECUTION`, `BUILD-PREP`.

---

## 4. Exact six-subject binding

Identities transcribed from **accepted textual evidence** (`dependency-manifest.inspected-r1.json`);
**no body was opened, listed, hashed or parsed**. Bodies confirmed present by `lstat`-equivalent metadata + size only.

| # | subject | version · arch | size | SHA-256 |
|---|---|---|---|---|
| 1 | python3-pip | 23.0.1+dfsg-1 · all | 1324972 | `d8024ededc6c7fe941ca96aabebdcf2d846fd130eae9d66aad1aa32a84454291` |
| 2 | python3-pkg-resources | 66.1.1-1+deb12u2 · all | 296604 | `25dfb378939ccdf27e7382adf44c168f86e22f9f1a8e6e3a2ec526431ed5e30f` |
| 3 | python3-setuptools | 66.1.1-1+deb12u2 · all | 521580 | `96f934b8dbe4367c4cf9e4c740aa5c85f9a9ac8875a16556c8677fb342c7838f` |
| 4 | python3-wheel | 0.38.4-2 · all | 30808 | `623a8f7c70ba713b0d8d5a321f157405861f0a0b1a652edad2cda5f70f5773f9` |
| 5 | psycopg-3.2.9-py3-none-any.whl | 3.2.9 | 202705 | `01a8dadccdaac2123c916208c96e06631641c0566b22005493f09663c7a8d3b6` |
| 6 | typing_extensions-4.16.0-py3-none-any.whl | 4.16.0 | 45571 | `481caa481374e813c1b176ada14e97f1f67a4539ce9cfeb3f350d78d6370c2e8` |

Subject-manifest: `contracts/S1-SUBJECT-MANIFEST.json` — exactly 6 subjects, each with exact size, SHA-256 and archive-format.
The full 19-body builder closure remains separately accepted but is **not** an S1 source-inspection subject.

---

## 5. Prior artifact-format evidence used without body access

Bound from `ARTIFACT-INSPECT-R1` textual derivatives only:

- **.deb** = Unix `ar`, global magic `!<arch>\n`, exactly `debian-binary` + `control.tar.xz` + `data.tar.xz`
  (proven for S1 sequences 14–17 in `deb-ar-structure-r1.tsv`); nested tar codec **xz**;
  proven nested member types = directory + regular only (`deb-data-members-r1.tsv`, empty link targets).
- **wheel** = ZIP; `wheel-archive-structure-r1.tsv` (psycopg 87 members / typing-extensions 5 members;
  zip_test PASS; 0 duplicate/encrypted/unsafe); `wheel-member-inventory-r1.tsv` all `member_type=regular`,
  compression stored/deflated.

Expected outer + nested archive formats were fully bindable from accepted textual evidence → **no HOLD**.

---

## 6. Semantic-question contract

`contracts/S1-QUESTION-CONTRACT.tsv` is a **byte-identical copy** of
`semantic-question-matrix-r1.tsv` (SHA-256 `c85e29436dfe50694685bb1e106a9009a3e9b5fb958e2d132fc4a328f17ba69d`).
Reproduction: **64 questions**, **9 categories**
(wheel-origin-paths 8, record 12, installer 5, requested 8, direct-url 12, generated-scripts 7,
bytecode 3, residue 5, filesystem-metadata 4), **0 duplicate IDs**, every pre-inspection disposition
`UNKNOWN-BEFORE-INSPECTION`.

---

## 7. Inspector — contracts summary

- **Standard-library only** (`argparse, hashlib, io, json, lzma, os, posixpath, sys, tarfile, tokenize, unicodedata, zipfile`);
  no subprocess/shell/network; no `compile`/`exec`/`eval`/`__import__`; no `ast`; no extraction; no package import.
- **CLI (future):** `<CPython-3.11> -I -s pip-installed-tree-source-inspector-s1-r1.py --subject-manifest … --question-contract … --output-root …`.
- **`ar` parser:** magic, 60-byte headers, `` `\n `` trailer, bounded decimal, checked size arithmetic,
  even padding, zero overlap, zero trailing, ≤16 members; HOLD on GNU long-name/BSD ext/symtab/unknown/dup/overlap/trailing.
- **Nested TAR:** stdlib streaming over xz only; no `extract`/`extractall`; bounded counts/bytes/ratio/path;
  reject absolute/`..`/drive/NUL, duplicate + case-collision, symlink/hardlink/FIFO/socket/device/sparse, unsupported PAX.
- **Wheel ZIP:** `zipfile` without extraction; size+SHA-256 bound first; bounded counts/sizes/ratio; CRC via complete reads;
  reject encrypted/unsupported/unsafe/dup/case/symlink-special.
- **Source:** `tokenize.detect_encoding` + tokenize only; never compile/import/AST; record module path, member SHA-256,
  line count, encoding; definitions/references via bounded token analysis with preserved line ranges.
- **64-question mapping:** outcomes `STATICALLY-SUPPORTED | STATICALLY-CONTRADICTED | DYNAMIC-UNKNOWN | NOT-APPLICABLE`;
  every non-UNKNOWN carries subject + member + SHA-256 + normalized path + line/record range + reasoning rule;
  static evidence tagged `STATIC-SOURCE`, never represented as observed C1 behavior.
- **Bounds:** compiled-in constants mirrored by `S1-BOUNDS.json`; each exceeded bound returns a dedicated nonzero HOLD code.
- **Output bundle (future):** 12 covered files + `SHA256SUMS` written last, excludes itself, each output once,
  exclusive creation, no overwrite, no partial-as-PASS; result preserves `S1 = REQUIRED-BUT-INSUFFICIENT-ALONE` and `RBF-15 = OPEN`.

**Direct review:** `INSPECTOR-SOURCE-REVIEW-R1 = PASS (PREPARED, NOT EXECUTED)` (see `evidence/inspector-source-review-checklist-r1.md`).

---

## 8. Source / preservation state (before == after)

| item | before | after |
|---|---|---|
| main HEAD | `4873ac713397cf47642d39b1ef17e48a9301511d` | unchanged |
| spike HEAD | `4873ac713397cf47642d39b1ef17e48a9301511d` | unchanged |
| staged / committed | none | none |
| PR | none | none |
| prep root | ABSENT | CREATED |
| repo output file | ABSENT (no HOLD) | CREATED (this file) |
| designs R1–R5 · lock · governance · parser/canary · acquisition/ARTIFACT-INSPECT · bodies · image archive · `.rar` · memory | preserved | unchanged |

Confirmations: no existing file changed; nothing staged or committed; no inspector execution/import/compile/AST;
no `.deb`/`.whl`/image/`.rar` body opened, listed, hashed or parsed; known `.rar` checked by path-presence only;
no isolation/collector/Docker/network/database/later gate began; no temporary or unauthorized path created;
`docs/result` untouched; project memory unmodified; the lock was treated as contextual evidence only (not copied into any build context; pip not executed).

---

## 9. Next

`PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-SEMANTICS-S1-PREP-R1`. On acceptance, separately authorize in order:
**S1-EXECUTE** (bind exact CPython 3.11 interpreter byte identity; isolated spike branch), then ISOLATION-PREP,
C1-COLLECTOR-PREP, BUILDER-CONTEXT-PREP, then C1 execution. `RBF-15` can be closed only by C1 dynamic observation.

*Stop after S1-PREP-R1.*
