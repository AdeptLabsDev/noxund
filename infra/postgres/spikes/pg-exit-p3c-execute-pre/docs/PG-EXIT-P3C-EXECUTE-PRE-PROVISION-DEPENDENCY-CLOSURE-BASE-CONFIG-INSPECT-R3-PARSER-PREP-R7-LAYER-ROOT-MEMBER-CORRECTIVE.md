# PG-EXIT-P3C-EXECUTE-PRE - BASE-CONFIG-INSPECT-R3-PARSER-PREP-R7-LAYER-ROOT-MEMBER-CORRECTIVE

Status: PASS (layer-root-member corrected source bound, NOT executed)
Date: 2026-08-04
Mode: narrow parser-preparation correction and static audit only. No parser execution, no Python
(import/compile/`python -c`), no Docker, no archive open/parse, no GNU tar, no network. The
preserved R1 canary archive was not touched. Static review used read-only text tooling only.

## 1. Decision

The R6 R3 canary exited UNSAFE-LAYER-MEMBER ("empty normalized member: '.'") because a real
docker image save layer tar contains a '.' root-directory header that generic normalization
rejected (CANARY-OBS-03). The Product Lead authorized one narrow correction: accept the legitimate
layer-root directory header only inside scan_layer, without weakening generic normalization.

## 2. Source identities

- R6 (reproduced): base-config-inspect-r3-r6.py - 107499 bytes, 2091 lines,
  sha256 ca4c567167b942ed2779423aa56916af377cd9b1f1a6c626282cc709040b88d1 (matches binding);
  bundle SHA256SUMS 8559ec19... (16/16). Preserved unchanged.
- R7 (corrected): parser/base-config-inspect-r3-r7.py - 113406 bytes, 2177 lines,
  sha256 ffe7f7ed6bbe773fb67c0abc6221b35ee3e869f647780d1c503e4a13e45c3500 (UTF-8, no BOM, LF-only,
  final LF). Copy of R6 with only the layer-root exception + r6->r7 output names + bounded
  root-header evidence.

## 3. Corrective bundle

C:/Adeptlabs/noxund-p3c-base-config-inspect-r3-parser-prep-r7 (created empty this gate).
17 files: 4 parser + 12 evidence + root-level SHA256SUMS. SHA256SUMS at the bundle root, covers
the other 16 files, written last; every entry reproduces (16/16 OK). SHA256SUMS identity
c0d51bef5688bb403507cf4b1af92ac1b3f5a1c485dcea5e06be5b2f754d69d9.

## 4. The narrow correction

- Correction 1 (scope): is_layer_root_name() is used ONLY by scan_layer, before
  canonical_member_name(entry.name, "inner"). canonical_member_name and every other normalizer
  (outer, config, abs_norm, virtual link, whiteout target, output-root) are UNCHANGED and still
  reject a normalized empty path.
- Correction 2 (grammar): a root alias is a nonempty non-NUL non-absolute non-drive name whose
  '/'-split yields only '' or '.' components with at least one exact '.'; '.', './', '././',
  './/./' qualify; '', '/', '..', './foo', '.hidden', '.wh.foo', 'C:/x' do not.
- Correction 3 (type safety): a root-alias name is acceptable only for a zero-size directory
  header; a root-like regular/symlink/hardlink or nonzero-size member raises EXIT_UNSAFE_LAYER_MEMBER
  (char/block/fifo/socket/unknown already rejected by the global special-member reject).
- Correction 4 (scan behavior): counted toward the per-layer and total member bounds (incremented
  and checked before the root check), recorded, and skipped - not added to seen/overlay/tracked, no
  whiteout, no descendant invalidation; continue.
- Correction 5 (duplicates): multiple root headers are bounded no-ops, each recorded (raw name +
  count); they never enter seen (not duplicate normalized paths) and never bypass member/type/size
  bounds.
- Correction 6 (evidence): bounded root-header accounting in fixed-point-resolution-r7 /
  resource-budget-r7 / metadata-limitations-r7 (total, per-layer-sequence, distinct raw names <= 64,
  zero-size-dir flag), with an explicit statement that root metadata does not establish RBF-14.
- Correction 8 (preserve R6): every R6 closure-evidence control and every R4 fixed-point/filesystem
  control is unchanged; only derived output names are versioned r6 -> r7.

## 5. Canonical-normalization regression (static, 14 rows)

'.'/'./' /'././' directory size-0 headers accepted and skipped; '.' regular/symlink/hardlink and
'.' nonzero-size directory fatal; ''/'/'/'../'/'./../x' rejected; './foo' -> 'foo'; '.hidden' and
'.wh.foo' and './.wh.foo' preserved unchanged. Traced statically (not executed) in
canonical-normalization-regression-audit-r7.json.

## 6. Static audit results (12-point, no execution)

'.' directory headers no longer reach the generic empty-normalized-path rejection; only layer
directory root aliases receive the exception; generic canonical_member_name still rejects empty
paths; absolute/drive/NUL/traversal remain rejected; root-like non-directories remain fatal; root
headers remain within member and reprocessing bounds and never enter overlay/seen/whiteout/
descendant logic; ordinary dotfiles and whiteouts are unaffected; all R6 closure controls and all
R4 fixed-point/filesystem controls remain present; one EXIT_OK return; no output claims root
metadata as a required identity. Prohibited executable primitives all zero; 15 imports; write
primitive open(path,"xb") at line 504.

## 7. Preservation and findings

- Parser-prep R1-R6 bundles, all three canary bundles, and the R1 canary archive (158927360 /
  35fde2ce...) preserved unchanged (archive not opened; no cleanup authorized). Prior evidence and
  project memory unchanged. Nothing staged or committed. Known .rar checked by path presence only.
- CANARY-OBS-03 remains OPEN until a separately authorized canary proves the exact archive passes.
  R6-BN-01/02/03 preserved. OPEN: RBF-01/04/05/06/07(runtime)/08/11/13(nonblocking)/14/15. Recorded:
  GOV-R2-01/GOV-R2-02/GOV-PARSER-PREP-01/GOV-CANARY-DEV-01/GOV-CANARY-DEV-02. No finding closed.

## 8. Disposition

BASE-CONFIG-R3-PARSER-PREP-R7-PASS-LAYER-ROOT-MEMBER-BOUND-NOT-EXECUTED

Next recommendation (NOT started): PRODUCT-LEAD-DIRECT-SOURCE-REVIEW-R7

Execution requires a separate Product Lead gate binding parser sha256
ffe7f7ed6bbe773fb67c0abc6221b35ee3e869f647780d1c503e4a13e45c3500.
