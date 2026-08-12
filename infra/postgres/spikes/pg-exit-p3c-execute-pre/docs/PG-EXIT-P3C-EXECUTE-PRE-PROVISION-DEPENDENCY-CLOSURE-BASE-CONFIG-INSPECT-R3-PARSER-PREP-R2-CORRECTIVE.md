# PG-EXIT-P3C-EXECUTE-PRE - BASE-CONFIG-INSPECT-R3-PARSER-PREP-R2-CORRECTIVE

Status: PASS (corrected source bound, NOT executed)
Date: 2026-08-03
Mode: corrective parser preparation and static audit only. No parser execution, no Python,
no compile, no GNU tar, no Docker, no network. Static review used read-only text tooling
only; the parser was not used to audit itself.

## 1. Decision

The Product Lead REJECTED the R1 parser for execution. This gate authorizes exactly one
corrective preparation. The R1 parser and its evidence are preserved unchanged as
historical rejected input.

## 2. Source identities

- R1 (rejected, reproduced): base-config-inspect-r3.py - 42752 bytes, 921 lines,
  sha256 1608b49b5493eb5eedc6423911a8c2f283c7683dfefce3815ebec24a4c824a3b.
- R2 (corrected): parser/base-config-inspect-r3-r2.py - 50644 bytes, 1045 lines,
  sha256 ed439c9e0f2ada55a9d29cb4c3be7adf9f1c88fb45f2bff8d1ed0934b2696d4c,
  UTF-8, no BOM, LF-only, final LF.

## 3. Corrective root

C:/Adeptlabs/noxund-p3c-base-config-inspect-r3-parser-prep-r2 (created empty this gate).
19 files / 83778 bytes; exactly the authorized structure. SHA256SUMS covers the other 18
files, written last; every entry reproduces. SHA256SUMS identity
c95ac25444183f854a96583c4a7d00b8a42bbb28137eeca1d1e3eba5e876df64.

## 4. Corrections implemented (all 16)

1. Canonical path normalization: canonical_member_name(scope) strips only repeated ./
   prefixes, preserves .wh.* and dotfiles, rejects absolute/drive/NUL/traversal, and uses
   scope-specific exits. Static examples: ./foo->foo; .wh.foo->.wh.foo; ./.wh.foo->.wh.foo;
   .hidden->.hidden; ../foo, C:/foo, /foo -> reject.
2. Complete OCI trust chain: verify_descriptor CAS+size+media for every followed
   descriptor (nested index, image manifest, config, attestation manifests). Members are
   verified by content, not trusted by digest-in-path.
3. Platform/config binding: descriptor platform, config os/arch, expected os/arch, and
   image-inspect os/arch must be a single value; schema versions validated; unsupported
   nested-index shape rejected.
4. Descriptor-size enforcement: observed_size != descriptor_size is nonzero; blob ledger
   carries an explicit size_match field.
5. Outer-archive safety: special members rejected globally; bounded maxima for member
   count and index/manifest/config/descriptor/total-JSON bytes; duplicate required members
   nonzero.
6. Layer-media policy: only approved media-type -> compression pairs; magic must agree;
   zstd/unknown is nonzero; no acceptance by magic sniffing alone.
7. Unsafe/duplicate layer members: unsafe member raises EXIT_UNSAFE_LAYER_MEMBER
   immediately (no counter-continue); duplicate normalized path within a layer is rejected
   as ambiguous (documented fail-closed, not last-wins).
8. Ancestor/whiteout semantics: ancestors tracked; deletion and opaque whiteouts and
   non-directory ancestor replacement invalidate tracked descendants.
9. Virtual link resolution: resolve_symlinks within the image namespace only; loop and
   depth (40) guarded; never followed to host; both link and resolved-target identity kept.
10. Dynamic required-path derivation: entrypoint, Cmd server binary, and helpers resolved
    via config Entrypoint/Cmd and inherited PATH; helpers promoted only on static evidence.
11. Required final predicates: passwd, group, entrypoint, interpreter, gosu, server binary,
    and PGDATA directory must all resolve before a zero exit.
12. Strict account parsing: strict utf-8 decode; zero malformed; unique postgres
    account/uid/primary group; else nonzero (no PASS on recorded flags).
13. Entrypoint analysis: comment lines excluded; each claim is line-referenced or
    UNRESOLVED; no runtime success claimed.
14. Exact-byte preservation: retained raw bytes written verbatim; file sha256 equals the
    merged-member content sha256; analysis decode is separate and strict.
15. Evidence atomicity: no PASS literal before the manifest; parser-result states
    PARSER-PREDICATES-PASS-MANIFEST-REQUIRED; SHA256SUMS written last; a write-phase error
    after any evidence file returns EXIT_PARTIAL_EVIDENCE (not INTERNAL).
16. Output-contract consistency: PARSER-CONTRACT/OUTPUT-SCHEMA/PATH-POLICY updated to match
    the enforced source exactly.

## 5. Static audit results

- Executable prohibited primitives all zero: prohibited imports, eval/exec/builtin-compile,
  dynamic import, subprocess/shell, network, Docker, delete/rename/move,
  symlink/hardlink/device, chmod/chown, tarfile extract/extractall.
- Single write primitive: open(path,"xb") exclusive-create (line 262); reads rb at 294/933;
  tarfile.open read-only at 856 (outer) and 497 (inner streaming); extractfile x5.
- PASS-path proof: the only return EXIT_OK (line 929) is reachable only after archive
  identity, outer member safety+bounds, RepoDigest binding + amd64 selection, config
  CAS+media, platform/config agreement, per-layer CAS+size+DiffID, layer scan
  (unsafe/duplicate raise), resolve_required (all required paths), strict account
  fail-closed, and entrypoint analysis. No PASS path bypasses a required predicate.
- EXIT_PARTIAL_EVIDENCE reachable (line 927). Unsafe layer members cannot continue toward
  PASS (canonical_member_name raises during iteration at 190; duplicate raises at 502).
- No literal "disposition": "PASS" exists in the source; only
  PARSER-PREDICATES-PASS-MANIFEST-REQUIRED.

## 6. Preservation and preflight

- R1 root preserved: 15 files, SHA256SUMS 59bf560e... unchanged.
- Spike/main HEAD 4873ac713397cf47642d39b1ef17e48a9301511d.
- Spike-subtree before (incl R1 doc): 62 files, 384229 bytes, identity
  6d19f451a20fcc898f292be96d934b4590a94967208ca69a644599f5fd8da42b.
- Known .rar: checked by PATH PRESENCE only; not opened/read/sized/hashed
  (GOV-PARSER-PREP-01 not repeated).
- Memory, surviving evidence, 03 design doc reproduced read-only; absences preserved.

## 7. Findings

RBF-01/04/05/06/07(runtime)/08/11/13(nonblocking)/14/15 remain OPEN. GOV-R2-01 and
GOV-R2-02 remain recorded. No finding closed or narrowed. No new finding.

## 8. Disposition

BASE-CONFIG-R3-PARSER-PREP-R2-PASS-CORRECTED-SOURCE-BOUND-NOT-EXECUTED

Next recommendation (NOT started): PRODUCT-LEAD-DIRECT-SOURCE-REVIEW-R2

No image save or parser execution is authorized. Execution requires a separate Product Lead
gate binding parser sha256
ed439c9e0f2ada55a9d29cb4c3be7adf9f1c88fb45f2bff8d1ed0934b2696d4c.
