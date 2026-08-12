# PG-EXIT-P3C-EXECUTE-PRE — PIP-INSTALLED-TREE-LOCK-MATERIALIZATION-R1

**Gate:** `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-PIP-INSTALLED-TREE-LOCK-MATERIALIZATION-R1`
**Type:** narrow lock-materialization only — **no execution, no BUILD-PREP, no S1, no Docker**.
**Authored:** 2026-08-04 · NOXUND Product Orchestrator.
**Materialization root:** `C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-lock-r1` (out-of-repo; authoritative source + evidence + `SHA256SUMS`).

> **Integration boundary:** the lock itself remains **outside Git** and is **not yet authorized for
> staging or integration into a build context.** This gate does not declare the full R2 design PASS.

---

## 1. Disposition

```
PIP-INSTALLED-TREE-LOCK-MATERIALIZATION-R1-PASS-EXACT-LOCK-BOUND-NOT-EXECUTED
```
Recommend: `PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-LOCK-MATERIALIZATION-R1`

## 2. Preserved R2 HOLD disposition

`PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R2-HOLD` (binding cause `R2-LOCK-BINDING-HOLD-LOCK-BODY-ABSENT`) is
preserved. This unit resolves only that lock blocker as a candidate.

## 3. PIP-LOCK-01 decision

```
PIP-LOCK-01 — MATERIALIZE-EXACT-TWO-WHEEL-HASH-LOCK
```
The lock is a **newly authorized Product-controlled build input**; it is **not** represented as a
pre-existing repository or acquisition artifact.

## 4. Materialization-root path and prior absence

`C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-lock-r1` — verified **ABSENT** before this gate (`MATROOT_EXISTS=False`), created by this gate.

## 5. Exact lock path

`C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-lock-r1/lock/wheels.requirements.txt`

## 6. Complete lock body

```text
psycopg==3.2.9 --hash=sha256:01a8dadccdaac2123c916208c96e06631641c0566b22005493f09663c7a8d3b6
typing-extensions==4.16.0 --hash=sha256:481caa481374e813c1b176ada14e97f1f67a4539ce9cfeb3f350d78d6370c2e8
```

## 7. Size, SHA-256, physical-line count

| field | value |
|---|---|
| size | `199` bytes (required `199` ✓) |
| SHA-256 | `d0c09ac6d392dd1a4393e97bdedf542e7db3122670478839da9f5f0b92a7ca62` (required match ✓) |
| physical lines | `2` |

## 8. Encoding / BOM / EOL / final-newline / trailing-whitespace

| check | result |
|---|---|
| UTF-8 | ✓ |
| BOM | ABSENT ✓ |
| EOL | LF-only (no CR) ✓ |
| final newline | PRESENT ✓ |
| trailing whitespace | ABSENT ✓ |

## 9. Parsed plain-text requirement count

`2` logical requirements (bounded plain-text inspection; no pip, no `packaging`, no `python -c`, no parser import).

## 10. Exact project/version/hash mapping

| # | project | operator | version | hash |
|---|---|---|---|---|
| 1 | `psycopg` | `==` | `3.2.9` | `sha256:01a8dadccdaac2123c916208c96e06631641c0566b22005493f09663c7a8d3b6` |
| 2 | `typing-extensions` | `==` | `4.16.0` | `sha256:481caa481374e813c1b176ada14e97f1f67a4539ce9cfeb3f350d78d6370c2e8` |

Exactly one hash per requirement; `total ==`=2, `total --hash=`=2, `total sha256:`=2.

## 11. Rejected-syntax audit

ABSENT for all: third/duplicate requirement, duplicate/alternate hash, version range,
compatible-release operator, extras, environment marker, direct URL, editable requirement, local path,
recursive `-r`/`-c`, line continuation, option line, index/extra-index config, trusted-host config,
find-links config, env-variable substitution, comment, blank line, trailing whitespace, CR, BOM.

## 12. Proof no option/include/marker/URL/additional requirement exists

Regex scans over the full decoded text: zero leading-`-` option/include lines, zero `;` markers, zero
`@`/`://` URLs, zero `[` extras, zero `~=|>=|<=|!=|>|<|,` range tokens, zero `$` substitution, zero
trailing-`\` continuation, zero `#` comments, exactly 2 content lines (no third requirement).

## 13. Future source-to-canary path mapping

- **Authoritative source:** `C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-lock-r1/lock/wheels.requirements.txt`
- **Future canary destination:** `/context/locks/wheels.requirements.txt`
- **Future pip argument:** `--requirement /context/locks/wheels.requirements.txt`

Copying/mounting into that path is **not** authorized here; the future C1 environment must reproduce the exact 199-byte identity after placement.

## 14. R2 Correction 2 candidate disposition

```
R2-CORRECTION-02 — EXACT-LOCK-MATERIALIZED-AND-BOUND
R2 LOCK BLOCKER = RESOLVED-CANDIDATE-AWAITING-PRODUCT-REVIEW
```
R2 full design is **not** declared PASS in this gate.

## 15. Root SHA256SUMS identity and replay

`SHA256SUMS` covers 6 files (lock + 5 evidence). Replay via `sha256sum -c SHA256SUMS`. Verified on disk.

| file | sha256 |
|---|---|
| lock/wheels.requirements.txt | `d0c09ac6d392dd1a4393e97bdedf542e7db3122670478839da9f5f0b92a7ca62` |
| evidence/product-lock-decision-r1.json | `eb87caf0007697bda537a70c59b239e00705a5c93f01b13e90245a9abb6ad8c1` |
| evidence/lock-byte-identity-r1.json | `0d0296c5f6f45409788fef76fc816e9af4a0a3c10b620644b413c7151c56d5c1` |
| evidence/lock-grammar-audit-r1.json | `fcccb70c74c59537fecedcb87ea5265c3bd3c909f183e78db2e1d285d2d4ac9d` |
| evidence/r2-correction2-binding-r1.json | `e5ba01f7bdea759fb758305918d9002f7eb9657fc6e6c31680ea021cdf4fbfde` |
| evidence/EVIDENCE-CONTEXT.md | `6ddf2e9141f00b8ef22daa0398ad2550eafbd8beda9261468ef43cbd54b4991e` |

## 16. Complete root inventory

```
lock/wheels.requirements.txt
evidence/product-lock-decision-r1.json
evidence/lock-byte-identity-r1.json
evidence/lock-grammar-audit-r1.json
evidence/r2-correction2-binding-r1.json
evidence/EVIDENCE-CONTEXT.md
SHA256SUMS
```
No other file or directory. No temporary/placeholder/backup/sidecar/alternate path created.

## 17. Repository output identity

```
infra/postgres/spikes/pg-exit-p3c-execute-pre/docs/PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-PIP-INSTALLED-TREE-LOCK-MATERIALIZATION-R1.md
```
Was **ABSENT** before this gate (no HOLD). `docs/result` neither created nor modified.

## 18. R1/R2 design preservation

R1 and R2 pip-semantics design roots and their repository documents preserved **unchanged** (R1 doc
re-verified `d9a4e2d5…`; R2 root/doc untouched).

## 19. Source / main / evidence / archive / memory states

| subject | before | after |
|---|---|---|
| `main` HEAD | `4873ac7…511d` | `4873ac7…511d` (unchanged) |
| spike HEAD | `4873ac7…511d` | `4873ac7…511d` (unchanged) |
| materialization root | ABSENT | CREATED (lock + 5 evidence + SHA256SUMS) |
| repo output doc | ABSENT | CREATED (this file) |
| R1/R2 design roots + docs | present | UNCHANGED |
| preserved `.rar` | exists, regular file, not symlink | UNCHANGED (path-presence + lstat file-type only) |
| project memory | intact | UNMODIFIED |

## 20–24. Confirmations

- **20.** No existing file changed (only new authorized paths created).
- **21.** Nothing staged or committed; no PR.
- **22.** No `.deb`/wheel body, no preserved image archive/`.rar` content, no pip, no inspector, no
  Docker, no network, no PostgreSQL/Supabase, no later gate accessed. Grammar audit was bounded
  plain-text only (no `python -c`, no requirements parser import, no host-pip validation).
- **23.** No temporary or unauthorized path created (root = exactly the authorized set).
- **24.** Known `.rar` (`noxund-p3c-base-config-inspect-r7-execute-canary-r4.rar`) checked by path
  presence + `lstat` file-type only; contents neither read nor hashed. Project memory unmodified.

## 25. Exact next recommendation

```
PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-LOCK-MATERIALIZATION-R1
```
On acceptance, the Product Lead may re-run the R2 corrective unit to flip Correction-2 HOLD →
`DESIGNED-BOUND` (binding this exact lock), then separately authorize S1-PREP, isolation-prep and
finally C1 execution. RBF-15 remains **OPEN**.

**Stopped after the exact lock-materialization unit.**
