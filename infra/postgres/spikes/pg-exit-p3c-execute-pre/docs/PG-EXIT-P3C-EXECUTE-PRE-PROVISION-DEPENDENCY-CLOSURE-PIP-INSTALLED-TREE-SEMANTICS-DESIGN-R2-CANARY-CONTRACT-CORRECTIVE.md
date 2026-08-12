# PG-EXIT-P3C-EXECUTE-PRE — PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R2 (CANARY-CONTRACT-CORRECTIVE)

**Gate:** `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R2-CANARY-CONTRACT-CORRECTIVE`
**Type:** corrective design and evidence preparation only — **no execution, no BUILD-PREP**.
**RBF target:** `RBF-15 — PIP-INSTALLED-TREE-METADATA-SEMANTICS-UNPROVEN` (remains **OPEN**).
**Authored:** 2026-08-04 · NOXUND Product Orchestrator.
**Design root:** `C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-design-r2` (out-of-repo; authoritative evidence + `SHA256SUMS`).

---

## 1. Disposition

```
PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R2-HOLD
```

**Cause:** Correction 2 requires binding one exact **existing** two-entry requirements lock body. No
such host body exists (only a *planned, unmaterialized* container path). Per Correction 2, this returns
HOLD. **No lock was invented or modified.** Corrections 1 and 3–12 are fully **DESIGNED-BOUND**.

Recommend: `PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R2`

## 2. Corrected R1 disposition

R1 HELD as directed:
```
PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R1-HOLD-CANARY-CONTRACT-INTERNALLY-INCOMPLETE
```
Architecture remains directionally accepted: S1 `REQUIRED-BUT-INSUFFICIENT-ALONE`, C1 `SELECTED-CANDIDATE`, C2/C3 `REJECT`, C4 `REJECT-PRESERVE-PRIOR-DECISION`.

## 3. R1 ZIP, document and manifest bindings

| item | value |
|---|---|
| R1 ZIP SHA-256 | `58145752ff72e53bc701a6752ada0c0be7c6c05e8c72c4cd5f910466cb50af29` |
| R1 repository-document SHA-256 (attested) | `d9a4e2d5efb01f95b5543c9ef47f1d9f6f428b86f9c7c43a9f57d55d885aa952` |
| R1 repository-document SHA-256 (observed now) | `d9a4e2d5efb01f95b5543c9ef47f1d9f6f428b86f9c7c43a9f57d55d885aa952` ✓ match |
| R1 evidence replay | `13/13` |
| semantic questions | `64` |
| duplicate question IDs | `0` |
| non-UNKNOWN pre-inspection dispositions | `0` |

R1 design root and repository document preserved **unchanged**.

## 4. Preserved technical, RBF and governance states

In force: `BASE-CONFIG-R7-CANARY-R4-ACCEPTED-FOR-EXACT-IMAGE`, `CANARY-OBS-03 — RESOLVED-FOR-EXACT-ARCHIVE`, `RBF-14-RESOLVED-EXACT-MERGED-POSTGRES-ACCOUNT-EVIDENCE`.
Open: `RBF-04`, `RBF-15`. Historical-open: `GOV-CLOSEOUT-DEV-01`, `GOV-CLOSEOUT-DEV-02`. Recorded: `R2-BN-01`.

## 5. Exact invocation argv (Correction 1)

```
/usr/bin/python3.11 -I -s -m pip install
  --no-index
  --find-links /context/wheels
  --no-deps
  --only-binary=:all:
  --require-hashes
  --no-build-isolation
  --no-compile
  --ignore-installed
  --no-cache-dir
  --disable-pip-version-check
  --requirement /context/locks/wheels.requirements.txt
  --target /opt/noxund-wheel-root/usr/local/lib/python3.11/dist-packages
  --report /evidence/pip-report.json
```
Corrects the build-prep draft, which omitted `install`, `--find-links`, `--requirement` (long form) and `--report`.

## 6. Exact environment (Correction 1)

`PIP_CONFIG_FILE=/dev/null`, `PIP_NO_CACHE_DIR=1`, `PIP_DISABLE_PIP_VERSION_CHECK=1`,
`PYTHONNOUSERSITE=1`, `HOME=/canary/home`, `TMPDIR=/canary/tmp`, `XDG_CACHE_HOME=/canary/tmp/xdg-cache`,
`XDG_CONFIG_HOME=/canary/tmp/xdg-config`, `LC_ALL=C.UTF-8`, `LANG=C.UTF-8`, `TZ=UTC`,
`SOURCE_DATE_EPOCH=1783993009`, `PSYCOPG_IMPL=python`.
`SOURCE_DATE_EPOCH` does **not** change pip-produced timestamps; `PSYCOPG_IMPL` is recorded, not exercised at install.

## 7. PIP-C1-CMD-01 decision

```
PIP-C1-CMD-01 — ADD-REPORT-OPTION-EXPLICITLY-ACCEPTED-FOR-CANARY
```
Deliberate C1 command-model change (not a silent reinterpretation). Report path is outside the staged runtime tree and inside the evidence root (`/evidence/pip-report.json`).

## 8. Exact lock identity and semantics (Correction 2 — HOLD)

**Disposition:** `R2-LOCK-BINDING-HOLD-LOCK-BODY-ABSENT`. Required semantics: exactly two hashed pins
(`psycopg==3.2.9` + approved wheel hash; `typing-extensions==4.16.0` + approved wheel hash), rejecting
ranges/extras/URLs/editable/recursive-includes/env-substitution/index-config/additional-hashes/additional-requirements.
Exhaustive read-only text search found **no discrete two-entry lock body**; the lock exists only as the
build-prep-declared container path `/context/locks/wheels.requirements.txt` (unmaterialized). The
multi-entry `services/data-engine/requirements-*.txt` files are rejected; JSON dependency manifests are
not requirements locks. Unblock options (all require separate authorization): materialize an exact lock
body, bind-by-reference the declared path, or supply an existing lock body path.

## 9. Allowed candidate-selection model (Correction 3)

Removed `package_resolver=none` / `zero resolver decision`. Bound: zero dependency expansion; zero
transitive/index/network/fallback candidate discovery; exactly two root requirements → exactly two
approved local wheels; each requirement → exactly one approved candidate; no ranking ambiguity; no
upgrade/replacement/reuse. A normal internal candidate-selection code path is not a failure; any
selection outside the two-entry mapping is. Observable via `pip-report.json`.

## 10. Forbidden resolver behavior

Any dependency expansion, transitive discovery, index/network candidate, fallback candidate, extra
distribution, upgrade/replacement, or ranking ambiguity → failure.

## 11. Exact builder subject (Correction 4)

Base bound **only** as `postgres:15.18-bookworm@sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51`.
Unpinned `debian:bookworm-slim` is **not** an alternative base (retracts the R1 reference). Ephemeral
builder derived from the pinned PostgreSQL image, provisioned only with the four approved Debian bodies
+ two approved wheels. Future identity proofs defined for interpreter, imported pip, dpkg DB, pip
module-tree, wheelhouse and lock. This gate does not create that environment.

## 12. Network-attempt observability (Correction 5)

Selected: **seccomp `SCMP_ACT_KILL_PROCESS`** on `AF_INET`/`AF_INET6`/`AF_PACKET`/`AF_NETLINK` socket
creation and connect-family syscalls, composed with an **empty network namespace** (loopback down).
Prohibited attempt → SIGSYS kill → nonzero exit + audit record; the canary cannot exit zero after an
attempt. `AF_UNIX` local IPC permitted only if required, to enumerated paths. State:
`SECCOMP-KILL-SELECTED-DESIGN-BOUND` (supersedes build-prep `NETWORK-ATTEMPT-DETECTION-UNAVAILABLE`).
`NETWORK-ATTEMPT-DETECTION-UNRESOLVED` **not** preserved (mechanism selected). No silent downgrade to
"request did not succeed." Profile authored/reviewed/hash-bound in a separate isolation-prep step.

## 13. Writable-namespace model (Correction 6)

Selected **W1**: read-only root filesystem; enumerated writable roots = staged target, `/evidence`,
`/canary/tmp`, `/canary/home`. Writes elsewhere impossible (EROFS). `HOME`/`TMPDIR`/cache/config bound
to exact authorized paths. W2 full-writable before/after diff retained as supplementary evidence.

## 14. Cache/config/temp-residue proof model

`--no-cache-dir`+`PIP_NO_CACHE_DIR` and confinement to `/canary/tmp` → zero cache; `PIP_CONFIG_FILE=/dev/null`
→ zero config; unexplained temp residue → HOLD; read-only root → zero unauthorized output path. Proven
by `writable-namespace-diff.tsv`.

## 15. Staged-tree preservation model (Correction 7)

Immutable uncompressed `/evidence/staged-tree-pre-normalization.tar` with POSIX path/type/mode/UID/GID/mtime/link
metadata; path-safety validation; duplicate + case-collision detection; member inventory; root-manifest
entry; exact SHA-256; no cleanup before review; reproducible against `after-filesystem-inventory.tsv`.

## 16. Explicit pre/post identity model (Correction 8)

Separate `pre_normalization` (state=`OBSERVED`) and `post_normalization` (state=`NOT-APPLIED-IN-C1`),
each with byte size/SHA-256/mode/UID/GID/mtime/path-type/link-target. Post-normalization values are
never fabricated in C1.

## 17. RECORD completeness model (Correction 9)

Distinguishes: regular files (row required), RECORD self-row (empty digest/size ok), directories (no
row), symlinks/nonregular (explicit policy, no silent regular-file invariant), generated files,
relocated members, absent source members, dangling rows, duplicate normalized paths, case-colliding
paths. Future PASS requires every observed path classified even when RECORD is N/A.

## 18. S1-PREP / S1-EXECUTE sequencing + inspector safety (Correction 10)

**S1-PREP** (prepare + review inspector) and **S1-EXECUTE** (run once) — both require separate
authorization (not granted here). Inspector: parse `ar`/nested data members + wheel ZIPs; reject
traversal/absolute/drive/links/duplicates/unsupported forms; enforce count/compressed/uncompressed/text
bounds; inventory + hash every member; never place on an executable path; never import/compile/AST-parse/execute;
map all 64 questions.

## 19. Revised C1 evidence schema (Correction 11)

18-file bundle: `identities.json`, `lock-binding.json`, `invocation.json`,
`isolation-and-network-policy.json`, `before-filesystem-inventory.tsv`, `after-filesystem-inventory.tsv`,
`writable-namespace-diff.tsv`, `stdout.log`, `stderr.log`, `exit-code.txt`, `pip-report.json`,
`staged-tree-pre-normalization.tar`, `staged-tree-member-inventory.tsv`,
`installed-record-reconciliation.json`, `generated-metadata-classification.json`,
`final-copy-allowlist.json`, `unresolved-observations.json`, `SHA256SUMS`. Producer attribution
(pip vs reviewed collector) is stated.

## 20. Exact C1 PASS/HOLD boundary (Correction 12)

PASS requires all of: exact base/interpreter/pip/Debian-bodies/wheels/lock; exact tokenized argv+env;
report at bound path; exactly two approved requirements+candidates; zero dependency expansion; zero
unauthorized candidate; network guard active; complete writable-namespace evidence; complete preserved
staged tree; complete reconciliation; zero unexplained path; zero `.pyc`; zero unexpected script; zero
cache/config/temp residue; zero unknown remaining. Any missing/ambiguous/nonreproducible evidence → HOLD.

## 21. RBF-15 closure boundary

R2 and static inspection alone cannot close RBF-15. Closure requires all five: S1 accepted; C1 exits
zero; evidence reproduces; every path reconciled; Product Lead directly reviews preserved evidence.
R2 adds preconditions: Correction-2 lock bound, isolation-prep accepted, S1-PREP accepted. **RBF-15 OPEN.**

## 22. Design-root identity and manifest replay

**Design root:** `C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-design-r2` · **manifest:** `SHA256SUMS` (17 files). Replay via `sha256sum -c SHA256SUMS` or `Get-FileHash evidence/* -Algorithm SHA256`.

| file | sha256 |
|---|---|
| evidence/r1-review-binding-r2.json | `216600f6bc69a18753e4f0be2972e51aa80c982d866d39e58702731bb25861ba` |
| evidence/correction-ledger-r2.tsv | `f345304b8eb88a8a9df7fbaf37c5bb870cac223e15a5e5b22df2237c2c652212` |
| evidence/exact-invocation-contract-r2.json | `f72987e143a8e964964132b8b1ff46e20f96b8579c803f2f7bd0e7b250d36a6d` |
| evidence/exact-lock-binding-r2.json | `c831a69047634903427b5a297c21507a603f27f6ff18683dc14f33ad5f9d7dee` |
| evidence/resolver-semantics-r2.json | `6105b2861ac6918431066393b86d3646d8b929f5b62178c3eeb282624e8e9fd9` |
| evidence/exact-builder-subject-r2.json | `01c8a87c4e1f8c2b3041f338bf558e84ab7946ba12ce83bc9f7628b98726f47b` |
| evidence/network-attempt-observability-r2.json | `6433e18e9991a201bdb782b30235b597e0769042c6a2f386c2daea652d2f681b` |
| evidence/writable-namespace-contract-r2.json | `43b33e7349291841e49b9e93d6f29695280a61e96cdfe51f73398b7803cbf39f` |
| evidence/staged-tree-preservation-contract-r2.json | `8fe0f139228e56ed7b8e596b1c1f71dd93ee3ea879905e4a8aa3c60bd4faca68` |
| evidence/installed-tree-reconciliation-contract-r2.json | `4de84706de9cd1d9d12ca329d5a686a441d2d18d746d7a9784470742469f5da3` |
| evidence/s1-prep-and-execute-plan-r2.json | `d16fa2405fcaf51ff79ac822c2174239696c0f139b4317e39d5c6a1303ac71d2` |
| evidence/c1-evidence-schema-r2.json | `c0cc85538f014d4a4d60f7eb184ef46dc8934cfcee27ed001b98e66d80e5699f` |
| evidence/c1-pass-hold-boundary-r2.json | `6a3622340cd472da783a0e7669fc152ea96c2de8a58861080f3425a8234326d7` |
| evidence/rbf15-closure-boundary-r2.json | `b290adaca133a0b6a0c0731b31e6b5258724c28c2f7333575e9180f761334bf0` |
| evidence/pip-semantics-design-result-r2.json | `78cda1c91fcbd4489c7637335961ea024aef8dbffc220c8bb5badb0095c6f852` |
| evidence/metadata-limitations-r2.json | `a9d4f53987ca9845c8abbb7ff3b01330203c3b0607275471d1d6136a7e88f18d` |
| evidence/EVIDENCE-CONTEXT.md | `d98c68ff1b8c80f0b05b3ed8641a5be630a793464b03ece91656cbb3f1d67bd0` |

## 23. Repository output identity

Single authorized repository output:
```
infra/postgres/spikes/pg-exit-p3c-execute-pre/docs/PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R2-CANARY-CONTRACT-CORRECTIVE.md
```
Was **ABSENT** before this gate (no HOLD). `docs/result` neither created nor modified.

## 24. Source / main / evidence / archive / memory states

| subject | before | after |
|---|---|---|
| `main` HEAD | `4873ac7` | `4873ac7` (unchanged) |
| `source` (origin AdeptLabsDev/noxund) | `4873ac7` | `4873ac7` (unchanged) |
| R1 design root | present | UNCHANGED |
| R1 repo document | present, `d9a4e2d5…` | UNCHANGED (verified) |
| R2 repo output file | ABSENT | CREATED (this file) |
| R2 design root | ABSENT | CREATED (17 files + SHA256SUMS) |
| preserved `.rar` | exists, regular file, not symlink | UNCHANGED (path-presence + lstat file-type only) |
| project memory | intact | UNMODIFIED |

## 25–30. Confirmations

- **25/26.** No existing file changed; nothing staged or committed; no PR.
- **27/28.** No `.deb`/wheel/image/`.rar` body opened/listed/hashed/parsed; no inspector; no pip; no
  dpkg; no Docker; no network; no PostgreSQL/Supabase; no tests/migrations/harness; no later gate.
- **29.** No temporary, placeholder, sidecar, backup or unauthorized path created (design root = exactly the authorized set).
- **30.** Known `.rar` (`noxund-p3c-base-config-inspect-r7-execute-canary-r4.rar`) checked by path
  presence + lstat file-type only; contents neither read nor hashed. `docs/result` untouched; project memory unmodified.

## 31. Exact next recommendation

```
PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R2
```
Resolve Correction-2 lock (authorize lock-materialization **or** binding-by-reference), then re-run the
corrective unit to flip C2 HOLD → DESIGNED-BOUND; only then separately authorize S1-PREP, isolation-prep,
and finally C1 execution. **RBF-15 remains OPEN.**

**Stopped after the corrective design-only R2 unit.**
