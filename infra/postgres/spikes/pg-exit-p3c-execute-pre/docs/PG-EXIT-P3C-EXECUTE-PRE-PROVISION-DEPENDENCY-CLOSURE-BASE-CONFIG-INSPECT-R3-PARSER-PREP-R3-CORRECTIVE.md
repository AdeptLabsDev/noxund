# PG-EXIT-P3C-EXECUTE-PRE - BASE-CONFIG-INSPECT-R3-PARSER-PREP-R3-CORRECTIVE

Status: PASS (corrected source bound, NOT executed)
Date: 2026-08-03
Mode: corrective parser preparation and static audit only. No parser execution, no Python,
no import, no compile, no ast-parse, no GNU tar, no Docker, no network. Static review used
read-only text tooling only; the parser was not used to audit itself.

## 1. Decision

The Product Lead REJECTED the R2 parser for execution (identity-valid but technically
unapproved). This gate authorizes exactly one corrective preparation, R3. The R1 and R2
parsers and their evidence are preserved unchanged as immutable historical inputs.

## 2. Source identities

- R1 (rejected): base-config-inspect-r3.py - 42752 bytes, 921 lines,
  sha256 1608b49b5493eb5eedc6423911a8c2f283c7683dfefce3815ebec24a4c824a3b.
- R2 (rejected for execution, reproduced): base-config-inspect-r3-r2.py - 50644 bytes,
  1045 lines, sha256 ed439c9e0f2ada55a9d29cb4c3be7adf9f1c88fb45f2bff8d1ed0934b2696d4c
  (matches the Product Lead binding exactly).
- R3 (corrected): parser/base-config-inspect-r3-r3.py - 74832 bytes, 1529 lines,
  sha256 90696198ea670b96195c6490567d0b6e0f8b7bee347833524daf670decab68c1,
  UTF-8, no BOM, LF-only, final LF, zero CR bytes.

## 3. Corrective root

C:/Adeptlabs/noxund-p3c-base-config-inspect-r3-parser-prep-r3 (created empty this gate).
19 files; exactly the authorized structure (4 parser + 15 evidence incl SHA256SUMS). SHA256SUMS
covers the other 18 files, written last; every entry reproduces (18/18 OK). SHA256SUMS identity
c25b4f86f1ac95d061966f1bf9464d61e2e8e6996a74b522c5fdb6a40d9fc6b0.

## 4. Required architecture change - bounded multipass resolution

The parser no longer assumes every required path is known before reading the entrypoint.

- Pass A (once): archive identity, outer-tar validation, OCI descriptor trust chain, config
  and manifest validation, selected-layer CAS + descriptor-size, ordered DiffID. Archive and
  descriptor identities are FIXED thereafter.
- Pass B: initial merged-path resolution of /etc/passwd, /etc/group, PGDATA+ancestors, and the
  configured Entrypoint/Cmd candidates+ancestors; resolve the exact entrypoint bytes.
- Pass C: static dependency discovery FROM THE EXACT ENTRYPOINT BYTES - shebang interpreter
  chain, privilege-drop/init helpers, referenced helper scripts, server binary, and link
  targets+ancestors. Full-line comments, inline comments outside quotes, heredoc payloads, and
  non-command string literals are ignored. Every promotion carries source line, exact text,
  discovery reason, and classification.
- Pass D: expanded merged-path resolution by rescanning the already-validated layers with the
  expanded tracked set (overlay rebuilt from scratch each generation - never stale).
- Fixed-point rule: a newly-referenced virtual link target adds its normalized path+ancestors
  and triggers a rescan, repeating until the required set stops expanding. Bound
  MAX_RESOLUTION_ROUNDS = 8; exceeding it is EXIT_BOUND_EXCEEDED. A post-convergence closure
  predicate fails EXIT_BOUND_EXCEEDED if any required resolution references an untracked target.

## 5. Corrective requirements implemented

1. Bounded multipass + fixed point (resolve_fixed_point / rescan_layers / _expand_tracked).
2. Required interpreter predicate: nonempty valid shebang; absolute path; component-by-component
   resolution to a regular file; size+sha256 recorded; `/usr/bin/env <name>` resolves BOTH
   /usr/bin/env and the named interpreter under the inherited PATH; else EXIT_INTERPRETER_UNRESOLVED.
3. Ancestor-symlink semantics: resolve_components walks from root; an ancestor symlink rewrites
   the remaining suffix into the virtual namespace and adds the target to the tracked set;
   loop+depth guarded; escape above root rejected by normalize_virtual.
4. Hardlink semantics: virtual hardlink RESOLUTION (not mere recording); missing target/loop ->
   EXIT_HARDLINK_UNRESOLVED; final target type required.
5. Helper promotion: no optional helper tracked initially; promoted only from non-comment
   command-position tokens; each promoted helper is a required predicate (EXIT_HELPER_UNRESOLVED).
6. Entrypoint analysis: four classifications (STATICALLY-ESTABLISHED /
   STATICALLY-OBSERVED-BUT-CONTEXT-AMBIGUOUS / DYNAMIC-BEHAVIOR-UNPROVEN / UNRESOLVED); a keyword
   match is never branch proof; a required client-decision field below STATICALLY-ESTABLISHED ->
   EXIT_ANALYZER_OUT_OF_SCOPE.
7. Strict required predicates: passwd/group bytes, entrypoint, resolved path, interpreter chain,
   promoted helpers, server binary, PGDATA dir, complete parent resolution, no unresolved
   symlink/hardlink, no stale descendant - each tested by an explicit require_*/assert_* call,
   never inferred from a None-bearing tuple.
8. Evidence measurement propagation: verify_descriptor returns a Measured record; the blob
   ledger carries ACTUAL observed size/sha256; attestation child_closure_verified=false and
   children are not counted.
9. Write-phase failure: any ParserError OR non-ParserError after any write -> EXIT_PARTIAL_EVIDENCE
   with the original code/reason preserved as nested diagnostic fields.
10. Output-root ancestry: Option A - `--expected-output-parent` required; output root must be a
    direct child; symlink/reparse-point ancestor, git worktree at/above, and archive overlap are
    rejected. Enforcement is code-backed (claim matches implementation).
11. Import/codec consistency: bz2 and lzma removed; 15 imports, each with an executable use;
    gzip + uncompressed layer media only.
12. Client option model: 3 options, each carrying all 16 required fields; replacement entrypoint
    and command are NOT invented; recommendation non-authoritative.

## 6. Static audit results (10-point, no execution)

1. No zero-exit path permits an unresolved interpreter identity (require_interpreter).
2. No zero-exit path permits a promoted helper to be absent (require_helpers).
3. No zero-exit path permits a stale descendant beneath a symlink ancestor (root-anchored
   resolution + assert_no_stale_descendants).
4. Hardlinks are resolved, not merely recorded (resolve_components hardlink branch).
5. All multipass/fixed-point/recursion loops have explicit finite bounds (rounds=8, depth=40,
   members=100000), each with a nonzero exit.
6. All measured descriptor values reach the ledger (Measured record; no reconstruction).
7. Every write-phase failure after a write maps to EXIT_PARTIAL_EVIDENCE with nested diagnostics.
8. Output-root enforcement claims match the implementation (Option A).
9. Imports exactly match executable use (bz2/lzma appear only in removal prose).
10. Every client option contains the required fields.

Prohibited executable primitives are all zero (eval/exec/builtin-compile/dynamic-import/
subprocess/os.system/os.popen/network/docker/shutil/tempfile/pickle/marshal/ctypes/bz2/lzma/
tarfile.extract/extractall/delete/rename/symlink/chmod/chown). Single write primitive:
open(path,"xb") at line 385. Single return EXIT_OK at line 1416, reachable only after every
predicate above and a complete write phase ending with SHA256SUMS. No literal disposition "PASS"
is written before the manifest exists (parser-result states PARSER-PREDICATES-PASS-MANIFEST-REQUIRED).

## 7. Preservation and preflight

- R1 root preserved: 15 files, SHA256SUMS 59bf560e... unchanged.
- R2 root preserved: 19 files, SHA256SUMS c95ac254... unchanged; R2 parser identity reproduced
  and confirmed against the Product Lead binding.
- Spike/main HEAD 4873ac713397cf47642d39b1ef17e48a9301511d.
- Spike subtree before this R3 doc: 63 files, 390662 bytes, identity
  0c372be6c30b3bf926785d1e437617d8b6e048fb3d43928dd2e4b65252c68a82 (untracked working tree).
- Known .rar: checked by PATH PRESENCE only; not opened/read/sized/hashed/listed.
- Project memory not modified; nothing staged or committed.

## 8. Findings

POSTHOC-AUDIT-HOLD on BASE-CONFIG-INSPECT-R2 remains in force. GOV-R2-01 / GOV-R2-02 remain
recorded. RBF-04 / RBF-14 / RBF-15 remain OPEN. No finding closed or narrowed. No new finding.
Runtime correctness of the R3 parser is UNPROVEN (neither PASS nor REJECT) and deferred.

## 9. Disposition

BASE-CONFIG-R3-PARSER-PREP-R3-PASS-CORRECTED-SOURCE-BOUND-NOT-EXECUTED

Next recommendation (NOT started): PRODUCT-LEAD-DIRECT-SOURCE-REVIEW-R3

No image save or parser execution is authorized. Execution requires a separate Product Lead
gate binding parser sha256
90696198ea670b96195c6490567d0b6e0f8b7bee347833524daf670decab68c1.
