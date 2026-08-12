# PG-EXIT-P3C-EXECUTE-PRE — PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R3 (EXECUTABLE-CONTRACT-CORRECTIVE)

**Gate:** `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R3-EXECUTABLE-CONTRACT-CORRECTIVE`
**Type:** corrective **design-only** — no execution, no inspector/collector/seccomp code, no Docker, no BUILD-PREP.
**RBF target:** `RBF-15` (remains **OPEN**).
**Authored:** 2026-08-04 · NOXUND Product Orchestrator.
**Design root:** `C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-design-r3` (out-of-repo; authoritative evidence + `SHA256SUMS`).

---

## 1. Disposition
```
PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R3-PASS-EXECUTABLE-CONTRACT-BOUND-NOT-EXECUTED
```
Recommend: `PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R3`

## 2. R2 direct-review identities
R2 held: `PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R2-HOLD-DIRECT-REVIEW-CONTRACT-STILL-INCOMPLETE`; bundle identity-valid and preserved unchanged.

| item | value |
|---|---|
| R2 ZIP SHA-256 | `9a6950e249d0a85eeec2bb0fe1f469686df2f8a7c81ce4ed130f08e78fa0ce3a` |
| R2 repository document SHA-256 | `2cfc06277f1e9d211ad8ac1501809f9349e273198d8d4f4a5ba0ecd94fb30a90` (verified now ✓) |
| R2 root SHA256SUMS SHA-256 | `fc7c607e24bd09785f498ba6a9d28d5ed107e61aff1c7ffbfd9daf431c86f8c3` (verified now ✓) |
| replay | `17/17` |

## 3. Accepted lock binding
`R2-CORRECTION-02 — RESOLVED-BY-ACCEPTED-LOCK-R1`. Source `…/lock-r1/lock/wheels.requirements.txt`; `199` bytes; SHA-256 `d0c09ac6d392dd1a4393e97bdedf542e7db3122670478839da9f5f0b92a7ca62`; 2 lines; UTF-8/no-BOM/LF-only/final-LF (verified now ✓). Bound by-reference; not modified/recreated. Future canary path `/context/locks/wheels.requirements.txt`.

## 4. Complete Debian package closure (Correction A)
Retracts "four packages provision CPython". Authoritative inventory: acquisition manifest (`ACQUIRE-R1-COMPLETE-BODIES-VERIFIED-UNINSPECTED`, verified_bodies=21). Builder = accepted base (17 BASE-SATISFIED) **+ 19 acquired `.deb`** (values transcribed; **no `.deb` opened/rehashed**):

| package | version | arch | size | sha256 | class |
|---|---|---|---|---|---|
| python3.11 | 3.11.2-6+deb12u8 | amd64 | 574236 | `cd7b10c2…b5de` | FINAL-RUNTIME |
| python3.11-minimal | 3.11.2-6+deb12u8 | amd64 | 2064968 | `4aba533f…ccee` | FINAL-RUNTIME |
| libpython3.11-minimal | 3.11.2-6+deb12u8 | amd64 | 817740 | `f3beaa03…e6f9` | FINAL-RUNTIME |
| libpython3.11-stdlib | 3.11.2-6+deb12u8 | amd64 | 1798560 | `890b3540…28ca` | FINAL-RUNTIME |
| python3 | 3.11.2-1+b1 | amd64 | 26300 | `33f6dafb…3b74` | BUILD-ONLY |
| python3-minimal | 3.11.2-1+b1 | amd64 | 26312 | `30f96186…9faa` | BUILD-ONLY |
| libpython3-stdlib | 3.11.2-1+b1 | amd64 | 9312 | `4e58891d…786e` | BUILD-ONLY |
| python3-pip | 23.0.1+dfsg-1 | all | 1324972 | `d8024ede…4291` | BUILD-ONLY |
| python3-pkg-resources | 66.1.1-1+deb12u2 | all | 296604 | `25dfb378…e30f` | BUILD-ONLY |
| python3-setuptools | 66.1.1-1+deb12u2 | all | 521580 | `96f934b8…838f` | BUILD-ONLY |
| python3-wheel | 0.38.4-2 | all | 30808 | `623a8f7c…73f9` | BUILD-ONLY |
| python3-distutils | 3.11.2-3 | all | 130936 | `a620b555…4318` | BUILD-ONLY |
| python3-lib2to3 | 3.11.2-3 | all | 76284 | `4e7f5e01…6a51` | BUILD-ONLY |
| libexpat1 | 2.5.0-1+deb12u2 | amd64 | 99888 | `2255e62f…dbc8` | FINAL-RUNTIME |
| libnsl2 | 1.3.0-2 | amd64 | 39480 | `c0d83437…d6f8` | FINAL-RUNTIME |
| libtirpc3 | 1.3.3+ds-1 | amd64 | 85192 | `2a46d5a5…e1c7` | FINAL-RUNTIME |
| libtirpc-common | 1.3.3+ds-1 | all | 14048 | `3e3ef129…3af85` | FINAL-RUNTIME |
| media-types | 10.0.0 | all | 26136 | `aaa46dcb…55dd` | INSTALL-FINAL-RUNTIME |
| ca-certificates | 20230311+deb12u1 | all | 155260 | `0d5f444f…2bed` | BUILD-ONLY |

Install payload (not builder closure): psycopg-3.2.9 (202705/`01a8dad…d3b6`), typing_extensions-4.16.0 (45571/`481caa4…c2e8`). Full hashes in `evidence/complete-debian-closure-contract-r3.json`.

## 5. Exact builder subject
Base bound only as `postgres:15.18-bookworm@sha256:b0c5bab0…8ad51`. Ephemeral builder = base + 19-body closure. Future identity proofs defined for interpreter/stdlib/pip/pkg-resources/setuptools/wheel/dpkg-DB/pip-module-tree/wheelhouse/lock. Not created in R3.

## 6. No-socket isolation model (Correction B)
`N1 — NO-SOCKET-PROCESS-POLICY`; state `N1-DESIGNED-AWAITING-ISOLATION-PREP`. seccomp `SCMP_ACT_KILL_PROCESS` on: `socket, socketpair, connect, bind, listen, accept, accept4, sendto, sendmsg, recvfrom, recvmsg, shutdown, getsockname, getpeername, setsockopt, getsockopt`. seccomp acts on syscall numbers, **not** on dereferenced sockaddr; no "getaddrinfo-driven syscall" enforcement rule. **No AF_UNIX exception**; any socket requirement → HOLD + new Product decision.

## 7. Inherited-FD and stdin model
fd0 CLOSED (stdin closed); fd1 → `/canary/pip-output/stdout.log`; fd2 → `/canary/pip-output/stderr.log`; **all fd>2 CLOSED**; no inherited socket FD. Empty network namespace, loopback down, `no_new_privs`, seccomp installed before interpreter `execve`; SIGSYS kill → nonzero exit recorded in `exit-record.json`.

## 8. Complete execution identity (Correction C)
UID 0, GID 0, supplementary groups `[]`, umask `0022`, cwd `/canary/home`; mounts: read-only root; writable roots with bound uid/gid/mode (staged target 0755, HOME 0700, TMPDIR 0700, pip-output 0755); `/evidence` collector-only (not pip-writable). **umask is represented in `invocation.json` and the metadata reconciliation.** Any configured-vs-observed difference → HOLD.

## 9. Exact argv / environment / cwd / umask
```
/usr/bin/python3.11 -I -s -m pip install
  --no-index --find-links /context/wheels --no-deps --only-binary=:all: --require-hashes
  --no-build-isolation --no-compile --ignore-installed --no-cache-dir --disable-pip-version-check
  --requirement /context/locks/wheels.requirements.txt
  --target /opt/noxund-wheel-root/usr/local/lib/python3.11/dist-packages
  --report /canary/pip-output/pip-report.json
```
cwd `/canary/home`; umask `0022`. Env: `PIP_CONFIG_FILE=/dev/null`, `PIP_NO_CACHE_DIR=1`, `PIP_DISABLE_PIP_VERSION_CHECK=1`, `PYTHONNOUSERSITE=1`, `HOME=/canary/home`, `TMPDIR=/canary/tmp`, `XDG_CACHE_HOME`/`XDG_CONFIG_HOME` bounded, `LC_ALL=LANG=C.UTF-8`, `TZ=UTC`, `SOURCE_DATE_EPOCH=1783993009`, `PSYCOPG_IMPL=python`.

## 10. PIP-C1-CMD-02
```
PIP-C1-CMD-02 — REPORT-PATH-MOVED-TO-PIP-OUTPUT-ROOT
```
Report `/evidence/pip-report.json` → `/canary/pip-output/pip-report.json` (collector-only root can no longer receive the report). Accepted lock argument and all other tokens preserved. Any later token/env change → new Product decision.

## 11. Pip-writable roots
Staged target; `/canary/home` (HOME); `/canary/tmp` (TMPDIR, XDG under it); `/canary/pip-output` (stdout.log, stderr.log, pip-report.json, exit-record.json).

## 12. Collector-only roots
`/evidence` — collector may not write until pip exits and pip-writable roots are frozen.

## 13. Exact phase boundary (Correction D)
1 create+inventory initial pip-writable roots → 2 freeze collector output → 3 invoke pip once → 4 capture exit → 5 prevent further pip-writable mutation (freeze) → 6 inventory complete final state → 7 collector writes final evidence → 8 reproduce pip-output bytes with source+dest hashes → 9 never include collector evidence in the pip-writable diff. **Observed filesystem = complete state immediately after pip exit and before collector evidence generation.** Enforceable via capability/mount gating.

## 14. Collector sequencing (Correction F)
`C1-COLLECTOR-PREP` (prepare+review, hash-bound) and `C1-COLLECTOR-EXECUTE` (within a separately authorized C1 workflow). Collector must not import installed project packages or pip. S1-PREP does not implicitly authorize the collector. Neither authorized in R3.

## 15. Staged-tree representation (Correction G)
Deterministic **PAX** archive `/evidence/staged-tree-pre-normalization.tar`: byte-wise member ordering; raw path encoding; duplicate/case-collision → HOLD; PAX headers only when ustar limits exceeded (recorded); observed mode/uid/gid/mtime/uname/gname without normalization; device/sparse/symlink/hardlink policies; bounded content streaming; producer = reviewed hash-bound collector. **No normalization — unrepresentable value → HOLD.** Independent member inventory + byte-level reproduction vs after-inventory.

## 16. Pre/post-normalization identity model
`pre_normalization` (state `OBSERVED`) and `post_normalization` (state `NOT-APPLIED-IN-C1`, never fabricated), each with byte-size/SHA-256/mode/uid/gid/mtime/path-type/link-target. umask-attributed mode bits.

## 17. Non-self-referential evidence manifest (Correction H)
Future C1 bundle = **18 files**; `SHA256SUMS` written **last**; **17 manifest entries**; `SHA256SUMS` excluded from itself; its own SHA-256 recorded in the C1 result + orchestration evidence (never inside itself).

## 18. Producer attribution (Correction I)
`pip-report.json` = pip; `stdout.log`/`stderr.log` = pip byte streams captured by the launcher (pip does **not** create the files); `exit-record.json` = launcher; all reconciliation/inventory = reviewed collector.

## 19. Exact preparatory sequence (Correction J)
C1 authorized only after separate acceptance of: (1) S1-PREP, (2) S1-EXECUTE, (3) ISOLATION-PREP, (4) C1-COLLECTOR-PREP, (5) exact builder-context preparation, (6) direct review of every prepared executable artifact and policy. **None authorized in R3.**

## 20. C1 PASS/HOLD boundary
PASS requires all of §4–§18 exactness plus: exactly two approved requirements/candidates; zero dependency expansion; N1 guard active; phase boundary enforced; deterministic TAR reproducible; complete reconciliation; zero unexplained path/`.pyc`/unexpected script/cache/config/temp residue; non-self-referential 18-file bundle; `unresolved-observations.json` empty. Any missing/ambiguous/nonreproducible evidence, identity mismatch, discovered socket requirement, or unrepresentable TAR value → HOLD.

## 21. RBF-15 closure boundary
R3/S1-alone cannot close RBF-15. Closure requires: S1 accepted; C1 exits zero; evidence reproduces; every path reconciled; Product Lead directly reviews preserved evidence. **RBF-15 OPEN.**

## 22. Design-root identity and replay
`C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-design-r3`; `SHA256SUMS` (18 files); replay via `sha256sum -c SHA256SUMS`. Verified on disk.

## 23. Repository output identity
```
infra/postgres/spikes/pg-exit-p3c-execute-pre/docs/PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R3-EXECUTABLE-CONTRACT-CORRECTIVE.md
```
Was **ABSENT** before this gate (no HOLD). `docs/result` neither created nor modified.

## 24. Source / main / evidence / archive / memory states

| subject | before | after |
|---|---|---|
| `main` HEAD | `4873ac7…511d` | `4873ac7…511d` (unchanged) |
| spike HEAD | `4873ac7…511d` | `4873ac7…511d` (unchanged) |
| R1/R2 designs + lock root | present | UNCHANGED (R2 doc `2cfc0627…`, R2 SHA256SUMS `fc7c607e…`, lock `d0c09ac6…` re-verified) |
| R3 repo output doc | ABSENT | CREATED (this file) |
| R3 design root | ABSENT | CREATED (18 files + SHA256SUMS) |
| preserved `.rar` | exists, regular file, not symlink | UNCHANGED (path-presence + lstat file-type only) |
| project memory | intact | UNMODIFIED |

## 25–29. Confirmations
- **25/26.** No existing file changed; nothing staged or committed; no PR.
- **27.** No package/wheel/image/RAR body opened/listed/hashed/parsed (acquisition manifest read as authoritative inventory only); no inspector/collector/seccomp code authored; no pip/dpkg/Python package execution; no Docker; no network; no PostgreSQL/Supabase; no tests/migrations/harness; no later gate.
- **28.** No temporary/placeholder/backup/sidecar/unauthorized path created (design root = exactly the authorized set).
- **29.** Known `.rar` (`noxund-p3c-base-config-inspect-r7-execute-canary-r4.rar`) checked by path presence + `lstat` file-type only; contents neither read nor hashed. `docs/result` untouched; project memory unmodified.

## 30. Exact next recommendation
```
PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R3
```
On acceptance, separately authorize in order: S1-PREP → S1-EXECUTE → ISOLATION-PREP → C1-COLLECTOR-PREP → exact builder-context preparation → direct review of every prepared executable artifact/policy → C1 execution. **RBF-15 remains OPEN.**

**Stopped after the R3 design-only corrective unit.**
