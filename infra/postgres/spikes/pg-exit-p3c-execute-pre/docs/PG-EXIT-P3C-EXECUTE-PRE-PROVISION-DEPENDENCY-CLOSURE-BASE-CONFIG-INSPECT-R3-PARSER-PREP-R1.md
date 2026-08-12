# PG-EXIT-P3C-EXECUTE-PRE - BASE-CONFIG-INSPECT-R3-PARSER-PREP-R1

Status: PASS (source bound, NOT executed)
Date: 2026-08-02
Mode: parser preparation and static audit only. No parser execution, no Python, no GNU
tar, no Docker, no network. Read-only against all preserved state; one external evidence
root and this one repository document were created.

Authoritative upstream state (unchanged by this gate):
- BASE-CONFIG-INSPECT-R2 PASS remains rejected.
- POSTHOC-AUDIT-HOLD-REINSPECTION-REQUIRED is authoritative.
- GOV-R2-01 (unauthorized GNU tar parser) and GOV-R2-02 (extraction boundary unproven)
  remain recorded.
- RBF-01, RBF-04, RBF-05, RBF-06, RBF-07 (runtime), RBF-08, RBF-11, RBF-13 (nonblocking),
  RBF-14, RBF-15 remain OPEN. None closed or narrowed here.

## 1. Objective

Create, bind, and statically audit the exact Python standard-library parser that a later,
separately authorized R3 execution gate may run against a re-saved
postgres:15.18-bookworm docker-save archive. Execution requires a new Product Lead gate
binding the exact parser SHA-256.

## 2. Parser identity (bound, not executed)

- Path (external prep root): parser/base-config-inspect-r3.py
- SHA-256: 1608b49b5493eb5eedc6423911a8c2f283c7683dfefce3815ebec24a4c824a3b
- Size: 42752 bytes
- Line count: 921
- Encoding: UTF-8, no BOM, LF-only, final LF
- Readable plain source; no encoded/compressed payload; no generated fragment;
  no self-modification.

## 3. External parser-prep root

Root: C:/Adeptlabs/noxund-p3c-base-config-inspect-r3-parser-prep-r1 (created empty this gate)

Structure (15 files, 70188 bytes):
- parser/base-config-inspect-r3.py
- parser/PARSER-CONTRACT.json
- parser/OUTPUT-SCHEMA.json
- parser/PATH-POLICY.json
- evidence/binding-reproduction-r1.json
- evidence/parser-source-inventory-r1.json
- evidence/import-audit-r1.json
- evidence/prohibited-primitive-audit-r1.json
- evidence/filesystem-effects-audit-r1.json
- evidence/archive-semantics-audit-r1.json
- evidence/output-contract-audit-r1.json
- evidence/parser-prep-result-r1.json
- evidence/metadata-limitations-r1.json
- evidence/EVIDENCE-CONTEXT.md
- evidence/SHA256SUMS

evidence/SHA256SUMS covers the other 14 files and was written last; every entry reproduces.
SHA256SUMS identity: 59bf560e3fd41cfd0f8cd8b31b8745069a01f375d63a70450fe8db7738f0b77a

## 4. CLI contract

Exactly nine named arguments, no positional inference, no environment path input, no
current-directory discovery, allow_abbrev disabled, unknown argument rejected (exit 2):
--archive, --docker-version-json, --image-inspect-json, --output-root,
--expected-archive-size, --expected-archive-sha256, --expected-repodigest,
--expected-os, --expected-architecture.

## 5. Readable and writable roots

Readable: only the three exact host paths (--archive via read-only tarfile;
--docker-version-json; --image-inspect-json). No recursive read of repo, user profile,
Docker store, or another evidence directory.

Writable: only beneath the exact empty --output-root. The parser rejects a nonexistent,
symlink, reparse-point, nonempty, archive-overlapping, or git-worktree output root, and
paths that escape via normalization. The parser never deletes, renames, or cleans the
output root; cleanup is a later orchestrator responsibility.

## 6. Import audit

17 imports, all on the standard-library allowlist, each with a documented purpose
(argparse, csv, dataclasses, gzip, bz2, lzma, hashlib, io, json, os, pathlib, posixpath,
re, stat, sys, tarfile, typing). The allowlisted module struct is deliberately omitted
(not imported merely because allowed). Imports outside the allowlist: 0. Prohibited
imports (executable): 0.

## 7. Prohibited-primitive audit (executable counts all zero)

- prohibited import: 0
- dynamic code (eval, exec, builtin compile, __import__): 0
- subprocess / shell / os.system / os.popen: 0
- network (socket, urllib, http): 0
- Docker primitive: 0
- deletion / rename / move: 0
- symlink / hardlink / device creation: 0
- chmod / chown: 0
- tarfile extract / extractall: 0

All textual occurrences of forbidden tokens are confined to the module docstring security
contract (lines 9, 25-28) and two non-executable analysis sites: re.compile at line 93
(regex compiler from allowlisted re, not the builtin compile) and the entrypoint text
scan for the shell keyword exec at lines 636-637 (not Python exec). The only archive read
API used is tarfile.extractfile (lines 312, 386, 402, 412, 502), which returns a file
object and never writes image members to disk.

## 8. Filesystem-effects audit

Single write primitive: builtin open in mode 'xb' (exclusive-create; never overwrites) at
line 232. Reads: open 'rb' at 268 and 804. Directory creation: os.makedirs(exist_ok=False)
under output-root at 734. Manifest walk: os.walk over output-root at 894. Zero deletion,
rename, link, or permission-change primitives. Zero image members written to disk.

## 9. Archive and merged-filesystem model

- Outer tar: read-only enumeration, member-name safety (reject NUL, absolute, drive,
  traversal, duplicate normalized paths), selected members must be regular files.
- OCI: validate oci-layout 1.0.0; follow the nested index once; select exactly one
  linux/amd64 image manifest; distinguish attestation manifests (kept as inventory only);
  resolve config and ordered layers; content-addressable verify every selected blob;
  reject ambiguous image selection.
- Layers: streamed decompression (gzip/bz2/lzma; zstd intentionally unsupported -> HOLD);
  DiffID computed over the decompressed stream and compared to config rootfs.diff_ids; no
  full layer materialized; no full rootfs extracted.
- Merged filesystem: ordered resolution for the WATCHED_PATHS allowlist only; supports
  replacement, deletion whiteouts, opaque-directory whiteouts, file/dir replacement,
  symlink and hardlink metadata, duplicates, PAX names, ./ normalization; image symlinks
  are never followed onto the host.
- Account: strict /etc/passwd (7 fields) and /etc/group (4 fields) parsing with duplicate
  and malformed detection; not inferred from image history. RBF-14 resolves only from the
  merged files.
- Entrypoint: preserved only if a resolved regular text file; observations classified
  STATICALLY-OBSERVED / DYNAMIC-BEHAVIOR-UNPROVEN / NOT-APPLICABLE / UNRESOLVED; no
  runtime success is ever claimed.

## 10. Output contract and atomicity

Bounded output tree beneath --output-root (raw/docker/*, raw/rootfs/*, derived/*,
SHA256SUMS). Each file written exactly once via exclusive-create; no overwrite;
SHA256SUMS written last after all evidence is complete; any failure returns nonzero
before manifest creation and leaves partial state truthfully (no fabricated SHA256SUMS);
output root must be empty before parsing; no temporary directory in the final contract.

## 11. Dispositions

Distinct nonzero exit classes exist for identity mismatch, unsafe outer archive,
unsupported archive representation, ambiguous image selection, config contradiction,
missing blob, blob digest mismatch, unsupported compression, DiffID mismatch, unsafe
layer member, unresolved merged path, malformed account metadata, entrypoint ambiguity,
output-root violation, and partial evidence. An unknown condition maps to a nonzero
internal class and never becomes PASS.

## 12. Preflight reproduction (all matched)

- Spike HEAD 4873ac713397cf47642d39b1ef17e48a9301511d, branch spike/pg-exit-p3c-execute-pre.
- Main HEAD 4873ac713397cf47642d39b1ef17e48a9301511d, branch main, zero tracked/staged diff.
- Spike-subtree (infra/postgres/spikes/pg-exit-p3c-execute-pre): 61 files, 375585 bytes,
  60 untracked, 1 ignored; canonical identity before
  1c9d97d5cec8b91a2aacb6feadda1a0dcce5b993668fc61e4eed62c89c9578a5.
- Known .rar (infra/postgres/spikes/pg-exit-p3c-execute-pre.rar): 55017 bytes, SHA-256
  f5ef19bb80ffbf09274bfc54ec47717bfc3a8c03c10d3f5107b29e5c9fd5305d; out of subtree scope;
  untouched.
- 03 design doc 16642 bytes b0235e698de990146779ee46047635d4dc017e8e0b7d87779ed6ca0c4ba495db.
- Memory MEMORY.md 8974/3cb72433..., pivot 33870/834b56d3... (read-only reproduction).
- Surviving evidence docker-version.json 1145/9de6b5fa..., image-inspect.json 3068/f470c026...
- Absences preserved: R1 tar, r2-parse.tmp, R2 result artifact.

## 13. Disposition

BASE-CONFIG-R3-PARSER-PREP-R1-PASS-SOURCE-BOUND-NOT-EXECUTED

Next recommendation (NOT started):
PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-BASE-CONFIG-INSPECT-R3-RESAVE-AND-EXECUTE-BOUND-PARSER-R1

That later gate must re-save the image and bind parser SHA-256
1608b49b5493eb5eedc6423911a8c2f283c7683dfefce3815ebec24a4c824a3b before any execution.
