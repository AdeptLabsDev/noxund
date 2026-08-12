# PG-EXIT-P3C-EXECUTE-PRE — PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R5 (ABI-NAMESPACE-AND-FREEZE-EVIDENCE-CORRECTIVE)

**Gate:** `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R5-ABI-NAMESPACE-AND-FREEZE-EVIDENCE-CORRECTIVE`
**Type:** corrective **design-only** — no inspector/launcher/supervisor/seccomp/collector/BPF/Docker/container.
**RBF target:** `RBF-15` (remains **OPEN**).
**Authored:** 2026-08-04 · NOXUND Product Orchestrator.
**Design root:** `C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-design-r5` (out-of-repo; authoritative evidence + `SHA256SUMS`).

---

## 1. Disposition
```
PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R5-PASS-ABI-NAMESPACE-AND-FREEZE-EVIDENCE-BOUND-NOT-EXECUTED
```
Recommend: `PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R5`

## 2. Corrected R4 disposition
```
PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R4-HOLD-X32-NAMESPACE-AND-FREEZE-EVIDENCE-INCOMPLETE
```
R4 bundle identity-valid, preserved unchanged, no governance scope breach.

## 3. R4 direct-review identities and replay
| item | value |
|---|---|
| ZIP size | `31091` |
| ZIP SHA-256 | `b1ef45b9494584497b15654ae260d1f1c925f1dbf980e730a1fcb5745719719f` |
| repo-document size | `12933` (verified now ✓) |
| repo-document SHA-256 | `b2857ceb8c62188b1481145aa25d74c683cf7f43c7e2a46ae5cef06b543d1d8d` (verified now ✓) |
| root SHA256SUMS size | `2263` (verified now ✓) |
| root SHA256SUMS SHA-256 | `47c569c2c28f43eef78f2f5da418c86563fec05a0899e0884303def4dd50e93b` (verified now ✓) |
| replay | `21/21` · regular files `22` · directories `2` · JSON `19` |

## 4. Accepted R4 components (directional)
Lock; 19-body Debian closure; 17-record BASE-SATISFIED presence binding; pinned base; argv+env; 1/0/300s; pip-writable↔evidence separation; quiescence requirement; regular-files+dirs-only staged tree; non-self-referential core+orchestration manifests; RBF-15 OPEN. **Complete R4 isolation contract not represented as accepted.**

## 5. Corrected x86-64 architecture check (Correction A)
Filter order: (1) load `seccomp_data.arch`; (2) require `arch == AUDIT_ARCH_X86_64` (`0xC000003E`); (3) else `SCMP_ACT_KILL_PROCESS`.

## 6. Explicit x32 syscall-bit guard
(4) load `seccomp_data.nr`; (5) require `(nr & 0x40000000) == 0`; (6) else `SCMP_ACT_KILL_PROCESS`; (7) only then evaluate the native x86-64 syscall policy. `X32_SYSCALL_BIT = 0x40000000`. Falsification cases: native prohibited socket; x32-bit-encoded number; non-x86-64 token; prohibited io_uring; permitted ordinary file syscall. **Any x32 route reaching the native default → HOLD.**

## 7. Corrected i386/x32 distinction
i386/compat → rejected by architecture mismatch; x32 → rejected by the explicit syscall-number bit guard; native x86-64 → evaluated against policy. **x32 has no distinct kernel audit-architecture value** (it shares `AUDIT_ARCH_X86_64`; the bit is the discriminator). If libseccomp is proposed at ISOLATION-PREP: bind exact version, filter-generation API, bad-arch action, generated PFC, exported BPF identity, and proof the filter contains the explicit x32-route rejection.

## 8. Child namespace-creation restrictions (Correction B)
Prohibited: `unshare`, `setns`; `clone3` prohibited (classic seccomp cannot inspect the `clone_args` pointer); `clone` with any of `CLONE_NEWNS/NEWCGROUP/NEWUTS/NEWIPC/NEWUSER/NEWPID/NEWNET/NEWTIME` (mask `0x7E020080`, scalar arg0) prohibited. Non-namespace thread creation only if separately justified + argument-filtered.

## 9. Child mount-mutation restrictions
Prohibited: `mount`, `umount2`, `pivot_root`, `chroot`, `open_tree`, `move_mount`, `fsopen`, `fsconfig`, `fsmount`, `fspick`, `mount_setattr`.

## 10. clone/clone3 policy
`clone3` → prohibited (pointer-arg, un-inspectable). `clone` → argument-filtered on the namespace-flag mask. Any unresolved syscall/flag mapping → ISOLATION-PREP HOLD.

## 11. Child-to-supervisor protection
Prohibited: `ptrace`, `process_vm_readv`, `process_vm_writev`, `pidfd_getfd`; inner launcher `PR_SET_DUMPABLE=0`; child cannot address the outer supervisor by PID.

## 12. Exact outer-supervisor topology (Correction C)
Outside the child PID namespace; owns the cgroup, namespace/mount setup, freeze and final-envelope generation; not visible through the child PID namespace; never shares writable evidence paths with the pip child; never passes capabilities or privileged FDs to the inner launcher or pip.

## 13. Exact inner-launcher topology
PID 1 in the dedicated child PID namespace; UID 0/GID 0/no groups; all five capability sets empty; `no_new_privs=1`; `PR_SET_DUMPABLE=0`; launches exactly one pip; captures stdout/stderr; records main wait status; reaps all descendants; creates the pre-freeze `main-exit-record.json`; closes writable FDs; exits.

## 14. Pip process identity and visibility boundary
Child of the inner launcher; receives the accepted seccomp policy; cannot see/address the outer supervisor by PID; cannot create/join namespaces; cannot mutate mounts; cannot use ptrace/process-vm/pidfd-getfd. Any differing topology → new Product decision.

## 15. Exact pip-output paths (Correction D)
`/canary/pip-output` = exactly `stdout.log`, `stderr.log`, `pip-report.json`, `main-exit-record.json`. Any other file → HOLD. `/evidence` absent from the pip child mount namespace.

## 16. Pre-freeze launcher-record schema
`main-exit-record.json` (inner launcher, pre-freeze) may contain only: main PID; argv/env identities; configured + launcher-observed UID/GID/groups/capabilities; cwd; umask; inherited FD state; seccomp profile identity; launcher-visible namespace identities; start/end monotonic timestamps; timeout state; main wait status; descendant wait statuses; inner-launcher quiescence result. **Must not** contain root-freeze result, final mount RO verification, final collector disposition, core manifest identity, or orchestration-envelope identity. `freeze_result` **removed** from the pre-freeze record.

## 17. Post-freeze supervisor-record schema (Correction E)
`orchestration-evidence/process-isolation-and-quiescence.json` (outer supervisor, post-freeze) contains: hash+size of `main-exit-record.json`; cgroup population before launch/at main exit/after inner-launcher exit; proof the child PID namespace has no live/unreaped process; proof the cgroup is empty; inner-launcher + descendant exit statuses; timeout + containment state; pip-writable mount identities; writable-FD closure result; writable-mapping closure result; read-only freeze result; post-freeze verification result; final quiescence disposition; hashes+sizes of the frozen pip-output files. **Sole authoritative source for freeze + final quiescence.** Containment ≠ PASS.

## 18. Exact quiescence and freeze ordering (Correction F)
16 steps: supervisor creates cgroup+namespaces → launcher records initial configured state → pip invoked once → capture main wait status → reap all descendants → write+close `main-exit-record.json` → close stdout/stderr/report FDs → launcher exits → supervisor requires cgroup+child PID ns empty → verify no surviving writable FD/mapping → freeze pip-writable roots RO → verify RO → collector inventories frozen roots → collector creates core bundle → supervisor creates envelope → manifests written last (non-self-referential). **No collector-generated file may be part of the observed pip-writable snapshot.**

## 19. Base-binding terminology correction (Correction G)
The 17 records are preserved; `package-file ownership evidence = R9 stanza SHA` → **`R9 dpkg-status stanza identity`**. A stanza SHA proves the exact status record, **not** file ownership. Where file-ownership proof is actually required, reference the separately accepted R9 ownership evidence and bind its exact source identity (not bound in R5). R9 dpkg-status source: `…/base-inventory-r3/raw/rootfs/var/lib/dpkg/status`, 137573 B, `1f66ea22…`.

## 20. Exact PAX control-record serialization (Correction H)
POSIX.1-2001 PAX + no global header; record encoding `<minimal-decimal-total-record-length><space><key>=<value><newline>` (self-including length); UTF-8 values; lexicographic keys; per-member extended header immediately precedes its target; header name `PaxHeaders/<lowercase-sha256-of-normalized-UTF8-path>`; header mode `0000000`, uid/gid `0/0`, empty uname/gname, mtime `0`; member control-name placeholder `PaxTarget/<lowercase-sha256-of-normalized-UTF8-path>` when PAX `path` required; numeric USTAR fields zero-prefixed octal only; **base-256 prohibited**; numeric overflow → HOLD; USTAR checksum with checksum field as spaces; header+payload padding zero-filled to 512-byte boundaries; termination exactly two zero blocks; bytes after → prohibited. Collector-prep binds test vectors (short path, directory, ns mtime, long path, combined path+mtime, numeric-overflow HOLD, invalid-UTF-8 HOLD). Unrepresentable → HOLD.

## 21. Updated core schema (Correction I)
Core = 18 files, 17-entry SHA256SUMS (excludes itself, written last); **`exit-record.json` → `main-exit-record.json`**. Core does not contain freeze/final-quiescence results.

## 22. Updated orchestration envelope
`orchestration-evidence/` = `c1-canary-result.json`, `core-bundle-binding.json`, `process-isolation-and-quiescence.json`, `SHA256SUMS` (3 covered entries, excludes itself); `process-isolation-and-quiescence.json` is the sole freeze/final-quiescence authority; envelope manifest hash returned in the structured response only.

## 23. Non-self-referential manifest chain
Core SHA256SUMS self-hash → recorded in the envelope; envelope SHA256SUMS self-hash → returned in the Orchestrator response only. All core and envelope self-reference removed.

## 24. ISOLATION-PREP evidence requirements (Correction J)
Prepare/preserve: supervisor/launcher source; seccomp source/profile; exact implementation+dependency identities; generated PFC/readable policy; exported BPF bytes+SHA-256; syscall-resolution ledger; architecture+x32 guard ledger; namespace/mount restriction ledger; static control-flow review; falsification-test plan; privilege-boundary plan; cgroup/PID-ns topology plan. **ISOLATION-PREP execution not authorized in R5.**

## 25. C1 PASS/HOLD boundary
PASS requires all accepted R4 bindings + §5–§22 exactness (x32 guard active; namespace/mount mutation blocked; child-to-supervisor protection; exact topology; exact pip-output; pre/post-freeze records; 16-step freeze; launcher-observed==configured; core 18/17 with `main-exit-record.json`; envelope 4/3; PAX control serialization; two-candidate selection; complete reconciliation; zero residue; empty unresolved-observations). Any x32→native, namespace/mount mutation, ptrace/process-vm/pidfd route, mismatch, non-empty cgroup/PID-ns, surviving writable FD/mapping, RO-verification failure, unrepresentable PAX value, or timeout → HOLD. Containment ≠ PASS.

## 26. Preparatory sequence
S1-PREP → S1-EXECUTE → ISOLATION-PREP → C1-COLLECTOR-PREP → BUILDER-CONTEXT-PREP → direct source review + identity binding (inspector/supervisor-launcher/seccomp/collector/builder-context) → C1 execution. **None authorized in R5.**

## 27. RBF-15 closure boundary
R5/S1-alone cannot close RBF-15. Closure requires S1 accepted; C1 exits zero with confirmed quiescence+freeze; evidence reproduces; every path reconciled; Product Lead directly reviews preserved evidence. **RBF-15 OPEN.**

## 28. Design-root identity and manifest replay
`C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-design-r5`; `SHA256SUMS` (22 files); replay via `sha256sum -c SHA256SUMS`. Verified on disk.

## 29. Repository output identity
```
infra/postgres/spikes/pg-exit-p3c-execute-pre/docs/PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R5-ABI-NAMESPACE-AND-FREEZE-EVIDENCE-CORRECTIVE.md
```
Was **ABSENT** before this gate (no HOLD). `docs/result` neither created nor modified.

## 30. Source / main / evidence / archive / memory states

| subject | before | after |
|---|---|---|
| `main` HEAD | `4873ac7…511d` | `4873ac7…511d` (unchanged) |
| spike HEAD | `4873ac7…511d` | `4873ac7…511d` (unchanged) |
| R1–R4 designs + lock root | present | UNCHANGED (R4 doc `b2857ceb…`, R4 SHA256SUMS `47c569c2…`, lock `d0c09ac6…` re-verified) |
| R5 repo output doc | ABSENT | CREATED (this file) |
| R5 design root | ABSENT | CREATED (22 files + SHA256SUMS) |
| preserved `.rar` | exists, regular file, not symlink | UNCHANGED (path-presence + lstat file-type only) |
| project memory | intact | UNMODIFIED |

## 31–35. Confirmations
- **31/32.** No existing file changed; nothing staged or committed; no PR.
- **33.** No package/wheel/image/RAR body opened/listed/hashed/parsed (R9 dpkg-status referenced as a plain-text stanza-identity source; acquisition manifest as authoritative inventory); no inspector/launcher/supervisor/seccomp/collector code; **no BPF generated or loaded**; no pip/dpkg/package execution; no Docker; no network; no PostgreSQL/Supabase; no tests/migrations/harness; no later gate.
- **34.** No temporary/placeholder/sidecar/backup/unauthorized path created (design root = exactly the authorized set).
- **35.** Known `.rar` (`noxund-p3c-base-config-inspect-r7-execute-canary-r4.rar`) checked by path presence + `lstat` file-type only; contents neither read nor hashed. `docs/result` untouched; project memory unmodified.

## 36. Exact next recommendation
```
PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R5
```
On acceptance, separately authorize in order: S1-PREP → S1-EXECUTE → ISOLATION-PREP → C1-COLLECTOR-PREP → BUILDER-CONTEXT-PREP → direct source review + identity binding → C1 execution. **RBF-15 remains OPEN.**

**Stopped after the R5 design-only corrective unit.**
