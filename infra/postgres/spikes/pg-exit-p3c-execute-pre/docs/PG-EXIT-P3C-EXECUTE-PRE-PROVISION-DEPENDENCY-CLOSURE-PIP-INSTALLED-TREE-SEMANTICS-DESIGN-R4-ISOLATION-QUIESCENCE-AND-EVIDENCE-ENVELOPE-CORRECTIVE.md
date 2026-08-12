# PG-EXIT-P3C-EXECUTE-PRE — PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R4 (ISOLATION-QUIESCENCE-AND-EVIDENCE-ENVELOPE-CORRECTIVE)

**Gate:** `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R4-ISOLATION-QUIESCENCE-AND-EVIDENCE-ENVELOPE-CORRECTIVE`
**Type:** corrective **design-only** — no executable artifact/inspector/collector/launcher/seccomp/Docker/container.
**RBF target:** `RBF-15` (remains **OPEN**).
**Authored:** 2026-08-04 · NOXUND Product Orchestrator.
**Design root:** `C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-design-r4` (out-of-repo; authoritative evidence + `SHA256SUMS`).

---

## 1. Disposition
```
PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R4-PASS-ISOLATION-QUIESCENCE-AND-EVIDENCE-ENVELOPE-BOUND-NOT-EXECUTED
```
Recommend: `PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R4`

## 2. R3 direct-review identities
R3 held `…R3-HOLD-EXECUTION-ISOLATION-AND-EVIDENCE-ENVELOPE-INCOMPLETE`; bundle identity-valid, preserved unchanged, no scope breach recorded.

| item | value |
|---|---|
| ZIP size | `32030` |
| ZIP SHA-256 | `8bdc3bec1e6b6d30ed7ed5a9668f351a742d6ab7c0cf4de291cd8c0311119e55` |
| repo-document size | `12530` (verified now ✓) |
| repo-document SHA-256 | `5b5029463cf8ea69a49274f53978656ad012faa7ffc3004b2f71629291b63006` (verified now ✓) |
| root SHA256SUMS SHA-256 | `58a883f80e327f57287c5f2640c4061d9e4ba3889ab3a6be6a212e65d5ef0d06` (verified now ✓) |
| replay | `18/18` |

## 3. Accepted R3 components (directional)
Accepted lock binding; 19-body Debian closure; pinned PostgreSQL base; exact argv+env; `PIP-C1-CMD-01`; `PIP-C1-CMD-02`; N1 direction; pip-writable/collector separation; pre/post-normalization separation; launcher/pip/collector producer distinction; separate S1/isolation/collector/builder prep gates; RBF-15 OPEN. **The complete R3 executable contract is NOT represented as accepted.**

## 4. Exact R9 / base-satisfied binding (Correction A)
Authoritative R9 inventory = `C:/Adeptlabs/noxund-p3c-base-inventory-r3/raw/rootfs/var/lib/dpkg/status`; size `137573`; SHA-256 `1f66ea22910e06b72e97ad6a953ef908f867e982c34a902be8da7d2f92b55c20` (**matches the acquisition-manifest recorded value**). **Exactly 17 BASE-SATISFIED records, 17 distinct, no duplicate** (no `e.g.` list): debconf 1.5.82, dpkg 1.21.23, libbz2-1.0 1.0.8-5+b1, libc6 2.36-9+deb12u14, libcrypt1 1:4.4.33-2, libdb5.3 5.3.28+dfsg2-1, libffi8 3.4.4-1, libgssapi-krb5-2 1.20.1-2+deb12u5, liblzma5 5.4.1-1+deb12u1, libncursesw6 6.4-4, libreadline8 8.2-1.3, libsqlite3-0 3.40.1-2+deb12u2, libssl3 3.0.20-1~deb12u2, libtinfo6 6.4-4, libuuid1 2.38.1-5+deb12u3, openssl 3.0.20-1~deb12u2, zlib1g 1:1.2.13.dfsg-1. Each with relationship satisfied + R9 stanza-SHA ownership evidence in `evidence/exact-base-satisfied-binding-r4.json`. **No package body or image archive opened** (dpkg status is a plain-text DB). HOLD clause not triggered.

## 5. Complete child capability boundary (Correction B)
pip child: UID 0, GID 0, supplementary groups empty; **capability bounding/permitted/effective/inheritable/ambient all empty**; `no_new_privs=1`; dedicated mount, PID, cgroup, and empty network namespaces; loopback down. Supervisor retains only namespace/mount-creation+freeze capabilities, **never inherited** by the child. Any nonzero child capability or inherited capability → HOLD.

## 6. Exact pip-visible mount namespace (Correction C)
Read-only base root; writable staged target/`/canary/home`/`/canary/tmp`/`/canary/pip-output`; read-only wheelhouse + lock dir. **`/evidence`, host paths, Docker socket, SSH agent/socket, secrets are ABSENT from the pip child mount namespace** — not mode-restricted. Collector/supervisor may see `/evidence` in a separate namespace. Unix modes alone are not the `/evidence` isolation boundary.

## 7. Exact seccomp architecture (Correction D)
`linux/amd64`; `SCMP_ARCH_X86_64` only; any additional/unexpected arch fails closed (default kill).

## 8. Exact prohibited syscall set
`socket, socketpair, connect, bind, listen, accept, accept4, sendto, sendmsg, sendmmsg, recvfrom, recvmsg, recvmmsg, shutdown, getsockname, getpeername, setsockopt, getsockopt` → `SCMP_ACT_KILL_PROCESS`. No AF_UNIX exception.

## 9. io_uring and compat-ABI disposition
`socketcall` is not a valid x86_64 syscall (i386/compat only) → covered by ABI rejection. Compat i386 (`SCMP_ARCH_X86`) and x32 (`SCMP_ARCH_X32`) execution killed by registering only `SCMP_ARCH_X86_64`. `io_uring_setup`/`io_uring_enter`/`io_uring_register` → KILL. This prevents an alternate socket-I/O route from being represented as unobserved. Unresolvable syscall name during ISOLATION-PREP → preparation HOLD.

## 10. Timeout and retry policy (Correction E)
`C1 pip invocation count = 1`; `retry = 0`; `timeout = 300 monotonic seconds`. On timeout: mark C1 HOLD; terminate the complete cgroup; reap every process; preserve partial stdout/stderr/report/exit/process-tree; no retry; no input/policy change.

## 11. PID namespace and cgroup model (Correction F)
Supervisor = PID-namespace init or child subreaper; pip child in dedicated PID namespace + dedicated cgroup; reaping/enumeration via PID ns + `cgroup.procs`.

## 12. Process-tree quiescence contract
After main pip exit: record wait status → reap zombies → enumerate cgroup/PID ns → require zero live descendants → zero un-reaped descendants → close launcher writable FDs → require no FD/mapping over pip-writable roots → only then freeze. **Any live descendant → HOLD; containment kill ≠ PASS.** Evidence: process tree before/at-exit/after-reap, cgroup population, namespace IDs, descendant exit statuses, timeout state, quiescence result.

## 13. Writable-FD and mapping closure
Close launcher log/report FDs; verify no writable FD remains; verify no writable mapping remains over any pip-writable root before freeze; remaining writable FD/mapping → HOLD.

## 14. Exact freeze boundary (Correction G)
Close launcher FDs → bind-remount/freeze every pip-writable root read-only → verify freeze from supervisor namespace → verify no writable FD/mapping → record mount identities + RO flags → only then final inventory. **Observed state = after main exit, after complete process-tree quiescence, after launcher exit-record completion, after writable-FD closure, and before collector-generated evidence** (the phrase "immediately after pip exit" is not used without these qualifiers).

## 15. Launcher-observed execution record (Correction H)
`exit-record.json` records **observed** argv-hash, env-hash, cwd, umask, UID, GID, groups, capability sets, namespace IDs, seccomp mode + accepted profile identity, inherited FD table, stdin state, mount-policy identity, main PID, process-tree/cgroup state, start + monotonic end times, timeout status, exit code, terminating signal, quiescence result, freeze result. `invocation.json` distinguishes `configured` vs `launcher_observed`; any mismatch → HOLD.

## 16. Core bundle schema (Correction I)
Core C1 bundle = **18 files**; core `SHA256SUMS` = **17 entries**, excludes itself, written last; the core bundle does not claim its own final manifest identity.

## 17. Orchestration-evidence envelope schema
```
orchestration-evidence/
  c1-canary-result.json            # core disposition + core manifest identity
  core-bundle-binding.json         # exact SHA-256 of core SHA256SUMS
  process-isolation-and-quiescence.json  # launcher/supervisor evidence
  SHA256SUMS                       # 3 entries, excludes itself
```
The orchestration-evidence manifest SHA-256 is returned in the structured Orchestrator response and is not placed inside its own covered files.

## 18. Non-self-referential manifest chain
Core SHA256SUMS self-hash → recorded in the envelope (`core-bundle-binding.json`), not in the core bundle. Envelope SHA256SUMS self-hash → returned in the Orchestrator response only. **All core and envelope self-reference removed.**

## 19. Complete filesystem metadata inventory (Correction J)
Per path: raw path bytes (or exact reversible representation), normalized relative path, type, mode, UID, GID, size, mtime seconds, mtime nanoseconds, device ID, inode, link count, symlink target, sparse extent state, xattr inventory+hashes, ACL state, file-capability state, regular-file SHA-256.

## 20. Hardlink/xattr/ACL/capability policy
Future C1 PASS accepts **only regular files and directories**. Any symlink, hardlink relationship, FIFO, socket, device node, sparse file, xattr, ACL, file capability, or non-UTF-8 path → HOLD unless a later Product decision adds a representation policy. **Hardlink absence proven via device, inode and link-count evidence.**

## 21. Exact PAX serialization contract (Correction K)
POSIX.1-2001 PAX; no global header; UTF-8 valid normalized relative POSIX paths; member ordering by UTF-8 byte sequence; per-member PAX headers only for `path`/nanosecond `mtime`; PAX keys lexicographic; canonical decimal mtime with exactly nine fractional digits when ns≠0; no `atime`/`ctime`; deterministic extended-header names; zero-filled padding; numeric UID/GID authority; empty `uname`/`gname`; regular bytes copied exactly; directory size zero; no silent truncation/normalization. Collector-prep binds the exact serialization implementation + test vectors. Unrepresentable value → HOLD.

## 22. C1 PASS/HOLD boundary
PASS requires all of §4–§21 exactness plus exactly two approved requirements/candidates, zero dependency expansion, complete reconciliation, zero unexplained path/`.pyc`/unexpected script/cache/config/temp residue, empty unresolved-observations. Any missing/ambiguous/nonreproducible evidence, configured-vs-observed mismatch, discovered socket requirement, live descendant, remaining writable FD/mapping, timeout, or unrepresentable value → HOLD.

## 23. Preparatory sequence (Correction L)
C1 execution requires separate acceptance of: (1) S1-PREP, (2) S1-EXECUTE, (3) ISOLATION-PREP, (4) C1-COLLECTOR-PREP, (5) BUILDER-CONTEXT-PREP, (6) direct source review + identity binding for inspector/supervisor-launcher/seccomp profile/collector/builder context, (7) C1 execution authorization. **None authorized in R4.**

## 24. RBF-15 closure boundary
R4/S1-alone cannot close RBF-15. Closure requires S1 accepted; C1 exits zero with confirmed quiescence+freeze; evidence reproduces; every path reconciled; Product Lead directly reviews preserved evidence. **RBF-15 OPEN.**

## 25. Design-root identity and manifest replay
`C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-design-r4`; `SHA256SUMS` (21 files); replay via `sha256sum -c SHA256SUMS`. Verified on disk.

## 26. Repository output identity
```
infra/postgres/spikes/pg-exit-p3c-execute-pre/docs/PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R4-ISOLATION-QUIESCENCE-AND-EVIDENCE-ENVELOPE-CORRECTIVE.md
```
Was **ABSENT** before this gate (no HOLD). `docs/result` neither created nor modified.

## 27. Source / main / evidence / archive / memory states

| subject | before | after |
|---|---|---|
| `main` HEAD | `4873ac7…511d` | `4873ac7…511d` (unchanged) |
| spike HEAD | `4873ac7…511d` | `4873ac7…511d` (unchanged) |
| R1/R2/R3 designs + lock root | present | UNCHANGED (R3 doc `5b502946…`, R3 SHA256SUMS `58a883f8…`, lock `d0c09ac6…` re-verified) |
| R4 repo output doc | ABSENT | CREATED (this file) |
| R4 design root | ABSENT | CREATED (21 files + SHA256SUMS) |
| preserved `.rar` | exists, regular file, not symlink | UNCHANGED (path-presence + lstat file-type only) |
| project memory | intact | UNMODIFIED |

## 28–32. Confirmations
- **28/29.** No existing file changed; nothing staged or committed; no PR.
- **30.** No package/wheel/image/RAR body opened/listed/hashed/parsed (R9 dpkg-status is a plain-text DB, read for the base-satisfied binding + hashed as authorized by Correction A; acquisition manifest read as authoritative inventory); no inspector/launcher/supervisor/seccomp/collector code authored/executed; no pip/dpkg/package execution; no Docker; no network; no PostgreSQL/Supabase; no tests/migrations/harness; no later gate.
- **31.** No temporary/placeholder/sidecar/backup/unauthorized path created (design root = exactly the authorized set).
- **32.** Known `.rar` (`noxund-p3c-base-config-inspect-r7-execute-canary-r4.rar`) checked by path presence + `lstat` file-type only; contents neither read nor hashed. `docs/result` untouched; project memory unmodified.

## 33. Exact next recommendation
```
PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R4
```
On acceptance, separately authorize in order: S1-PREP → S1-EXECUTE → ISOLATION-PREP → C1-COLLECTOR-PREP → BUILDER-CONTEXT-PREP → direct source review + identity binding (inspector/supervisor-launcher/seccomp/collector/builder-context) → C1 execution. **RBF-15 remains OPEN.**

**Stopped after the R4 design-only corrective unit.**
