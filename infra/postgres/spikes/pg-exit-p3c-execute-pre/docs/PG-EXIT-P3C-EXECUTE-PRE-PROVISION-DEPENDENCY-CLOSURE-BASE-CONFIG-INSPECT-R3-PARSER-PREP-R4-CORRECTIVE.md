# PG-EXIT-P3C-EXECUTE-PRE - BASE-CONFIG-INSPECT-R3-PARSER-PREP-R4-CORRECTIVE

Status: PASS (corrected source bound, NOT executed)
Date: 2026-08-03
Mode: corrective parser preparation and static audit only. No parser execution, no Python,
no import, no compile, no ast-parse, no GNU tar, no Docker, no network. Static review used
read-only text tooling only; the parser was not used to audit itself.

## 1. Decision

The Product Lead REJECTED the R3 parser for execution. This gate authorizes exactly one
corrective preparation, R4. The R1, R2 and R3 parser-prep roots, all prior repository
documents, surviving base-inspection evidence, and project memory are preserved unchanged.

## 2. Source identities

- R3 (rejected, reproduced): base-config-inspect-r3-r3.py - 74832 bytes, 1529 lines,
  sha256 90696198ea670b96195c6490567d0b6e0f8b7bee347833524daf670decab68c1 (matches the Product
  Lead binding); bundle manifest c25b4f86f1ac95d061966f1bf9464d61e2e8e6996a74b522c5fdb6a40d9fc6b0,
  18/18 reproduced.
- R4 (corrected): parser/base-config-inspect-r3-r4.py - 84494 bytes, 1729 lines,
  sha256 756942efc5e541a0c09f113d65044c556b60a3c62b2bf9d69c1649f44e17cf39,
  UTF-8, no BOM, LF-only, final LF, zero CR bytes.

## 3. Corrective bundle

C:/Adeptlabs/noxund-p3c-base-config-inspect-r3-parser-prep-r4 (created empty this gate).
20 files: 4 parser + 15 evidence + root-level SHA256SUMS. SHA256SUMS is at the BUNDLE ROOT
(not inside evidence/), covers the other 19 files, written last; every entry reproduces
(19/19 OK). SHA256SUMS identity 56a6908ed7241365f75df8e91825f1b776b7ac50d98c609390787b145139057d.

## 4. Corrections implemented (all 10)

1. FULL required-path fixed point: every generation resolves and expands from entrypoint,
   Cmd/server, /etc/passwd, /etc/group, PGDATA, the shebang interpreter, the /usr/bin/env named
   interpreter, and every promoted helper, collecting all newly referenced symlink/hardlink
   targets + ancestors and rescanning while the tracked set expands. enforce_required only
   VERIFIES the fixed point and rejects any post-convergence untracked reference; it never
   first-discovers a required path.
2. Interpreter discovery INSIDE the fixed point: as soon as exact entrypoint bytes exist the
   shebang is parsed and the primary interpreter plus /usr/bin/env named-interpreter PATH
   candidates are tracked and rescanned. A `#!/usr/bin/env bash` entrypoint no longer fails for
   lack of /usr/bin/env in the seed. Per-round interpreter records are emitted.
3. Complete link closure for entrypoint, server, interpreter chain, passwd, group, PGDATA and
   every promoted helper each generation; after convergence no required resolution produces a
   previously unseen reference.
4. Directory replacement by ANY non-directory (regular/symlink/hardlink/special) invalidates
   existing descendants; recreating the ancestor as a directory does not resurrect them; only an
   explicit later member recreates a descendant. Static scenarios A/B/C traced (not executed).
5. Global inner special-member policy: char/block/fifo/socket/unknown members raise
   EXIT_UNSAFE_LAYER_MEMBER before any tracked check; only regular/dir/symlink/hardlink/whiteout
   are modeled.
6. Helper discovery matches code: a conservative bounded command-context analyzer with heredoc
   start/end tracking and payload suppression, comment removal, command-separator splitting,
   wrapper/assignment skipping; COMMAND-POSITION promotion only; UNCERTAIN-NOT-PROMOTED recorded
   separately; command substitution/backticks/eval are not parsed and never claimed. Source,
   contract and evidence use identical terminology.
7. Entrypoint evidence disposition: image_config_binding (STATICALLY-ESTABLISHED) is separated
   from runtime_behavior (ENTRYPOINT-RUNTIME-BEHAVIOR-UNPROVEN; complete branch behavior not
   established; privilege transition UNPROVEN, RBF-04 OPEN). A zero exit coexists with the
   unproven runtime disposition; client options label privilege-drop/initialization UNRESOLVED;
   all concrete helper references needed for filesystem identity are resolved.
8. Partial-output tracking: any_written and any_output_created are set immediately after the
   exclusive open succeeds and before writing bytes; directory creation is marked as partial
   output; any failure after output maps to EXIT_PARTIAL_EVIDENCE with the original code/reason
   nested.
9. Inner-layer resource bounds: explicit finite limits for per-layer members, total members,
   compressed layer size (validated as an int within bound before hashing), uncompressed bytes
   per layer, total Pass-A uncompressed, total reprocessed bytes across all rounds, tracked
   paths, discovered references, promoted helpers, and output evidence bytes; each breach returns
   a distinct bounded-resource disposition (34-39 / 27).
10. Result and manifest semantics: parser-result-r4.json distinguishes immutable_base_predicates
    = PASS, entrypoint_runtime_behavior = ENTRYPOINT-RUNTIME-BEHAVIOR-UNPROVEN, evidence_manifest
    = MANIFEST-REPRODUCTION-REQUIRED; bare_pass_emitted = false; gate PASS is Orchestrator-only.

## 5. Static audit results (10-point, no execution)

1. Interpreter paths are discovered inside the fixed point (resolve_fixed_point).
2. Every required-path class contributes references before convergence.
3. Helper link targets feed back into tracked paths.
4. Symlink replacement permanently invalidates old descendants (scenarios A/B/C).
5. Unsupported inner special members cannot be ignored (global reject).
6. Heredoc/helper-discovery claims match the implementation and terminology.
7. Every output-path creation activates partial-output classification.
8. Every layer and resolution loop has explicit resource bounds.
9. No zero-exit path permits an unresolved required filesystem identity (single return EXIT_OK
   at line 1596, reachable only after all predicates + a complete write phase).
10. No output or contract claims complete runtime privilege proof.

Prohibited executable primitives are all zero (eval/exec/builtin-compile/dynamic-import/
subprocess/os.system/os.popen/network/docker/shutil/tempfile/pickle/marshal/ctypes/bz2/lzma/
tarfile.extract/extractall/delete/rename/symlink/chmod/chown). 15 imports, each with an
executable use; bz2/lzma removed. Single write primitive: open(path,"xb") at line 415.

## 6. Preservation and preflight

- R1 root preserved: 15 files, SHA256SUMS 59bf560e... unchanged.
- R2 root preserved: 19 files, SHA256SUMS c95ac254... unchanged.
- R3 root preserved: 19 files, SHA256SUMS c25b4f86... unchanged; R3 parser + bundle manifest
  reproduced and confirmed against the Product Lead binding.
- Spike/main HEAD 4873ac713397cf47642d39b1ef17e48a9301511d.
- Spike subtree before this R4 doc: 64 files, 399213 bytes, identity
  d8440527add5df9bc307f6d3d95363a4ac24be33778d02a22c731c8b20449850 (untracked working tree).
- Known .rar: checked by PATH PRESENCE only; not opened/read/sized/hashed/listed.
- Project memory not modified; nothing staged or committed.

## 7. Findings

POSTHOC-AUDIT-HOLD on BASE-CONFIG-INSPECT-R2 remains in force. GOV-R2-01 / GOV-R2-02 remain
recorded. RBF-04 / RBF-14 / RBF-15 remain OPEN. No finding closed or narrowed. No new finding.
Runtime correctness of the R4 parser is UNPROVEN (neither PASS nor REJECT) and deferred.

## 8. Disposition

BASE-CONFIG-R3-PARSER-PREP-R4-PASS-CORRECTED-SOURCE-BOUND-NOT-EXECUTED

Next recommendation (NOT started): PRODUCT-LEAD-DIRECT-SOURCE-REVIEW-R4

No image save or parser execution is authorized. Execution requires a separate Product Lead
gate binding parser sha256
756942efc5e541a0c09f113d65044c556b60a3c62b2bf9d69c1649f44e17cf39.
