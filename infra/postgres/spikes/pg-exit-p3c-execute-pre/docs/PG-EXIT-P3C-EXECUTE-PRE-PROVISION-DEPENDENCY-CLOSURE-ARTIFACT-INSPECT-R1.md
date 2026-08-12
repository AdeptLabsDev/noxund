# PG Exit P3C Execute Pre - Dependency Closure Artifact Inspect R1

## Decision

ARTIFACT-INSPECT-R1-PASS-BODIES-AND-CLOSURE-VERIFIED

## Binding identities

- Worktree: C:/Adeptlabs/noxund-p3c-execute-pre
- Branch: spike/pg-exit-p3c-execute-pre
- HEAD: 4873ac713397cf47642d39b1ef17e48a9301511d
- Pre-existing subtree: 58 files; 324689 bytes; canonical input 6383 bytes; SHA-256 a0de6d40d930be782860cc52fdce2f1df3d9d326018d6be9839cb40acbecc7d4.
- Acquisition evidence: 52 files; 8613251 bytes; SHA256SUMS 20c16bdc52010f2455a3797b17f1f42e436d413dd4b32af7283e16cfa51888a5; replay PASS.
- Bodies before inspection: 21/21 exact identity PASS.

## Inspection results

- Network attempts: 0.
- Debian ar archives: 19; pass: 19.
- Compression: xz/xz.
- Control identity comparisons: PASS.
- Dependency revalidation: PASS.
- Maintainer scripts: 31; blocking/unknown: 0; risk counts: {"EXPECTED-BUILD-SANDBOX-ACTION": 27, "REQUIRES-EXACT-BUILD-POLICY": 4}.
- Debian data members: 2222; regular members: 1854; regular payload bytes: 33150453.
- md5sums packages: 19; mismatches: 0; missing references: 0.
- Base file collisions: 0.
- Inter-package conflicting non-directory collisions: 0.
- Protected path result: BODY-PROVEN-ZERO-PROTECTED-PATH-COLLISION.
- Wheel ZIP archives: 2; pass: 2.
- Wheel members: 92; RECORD rows: 92.
- WHEEL result: py3-none-any and Root-Is-Purelib true for both wheels.
- METADATA active edges: [{"requirement": "typing-extensions>=4.6; python_version < \"3.13\"", "source": "psycopg", "target": "typing-extensions"}].
- Native payload scan: PURE-PYTHON-NO-BUNDLED-NATIVE-RUNTIME.
- RECORD validation: PASS.
- Wheel closure: EXACT-PURE-WHEEL-CLOSURE-BODY-PROVEN.

## Inspected manifest

- Path: derived/dependency-manifest.inspected-r1.json
- Size: 140990
- SHA-256: cefabe85adcd9521f857bc2ce06ea3b05b90bf651dc20da4e48ab00e95a38432
- Canonical payload bytes: 103399
- Canonical payload SHA-256: 2657dba7d758320ce4528424f1cf527cdeff0972af8f4db9b38d4ca05c9a9c53

## Findings

- RBF-01: OPEN
- RBF-02: RBF-02-RESOLVED-EXACT-WHEEL-BODIES-AND-CLOSURE-INSPECTED
- RBF-03: RESOLVED
- RBF-04: OPEN
- RBF-05: OPEN
- RBF-06: OPEN
- RBF-07: RUNTIME-VALIDATION-OPEN
- RBF-08: OPEN
- RBF-09: RBF-09-RESOLVED-EXACT-DEBIAN-CLOSURE-BODIES-INSPECTED
- RBF-10: RBF-10-RESOLVED-AUTHORITATIVE-PURE-WHEEL-CLOSURE-INSPECTED
- RBF-11: OPEN
- RBF-12: RBF-12-RESOLVED-BODY-PROVEN-ZERO-PROTECTED-PATH-COLLISION
- RBF-13: OPEN-NONBLOCKING

New findings: none.

## Evidence

- External path: C:/Adeptlabs/noxund-p3c-dependency-closure-artifact-inspect-r1
- SHA256SUMS entries: 109
- SHA256SUMS SHA-256: dc07f3b54954a1005c85804a74096c642f3bb9eb53df1c4d9591a5900372cf8c
- Prior acquisition/R1/R2/R3/R9 evidence remained unchanged.
- All acquired bodies remained unchanged.

## Next gate

PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-BUILD-DESIGN-R1

The next gate did not begin. BUILD remains unauthorized.

## Scope

No network request occurred. No package or wheel member was executed, imported, installed, or extracted to its installation path. No Docker, image build, database, runner, harness, fixture, migration, or test operation occurred. Nothing was staged or committed. The known .rar was checked by path only and remained untouched. RET-ACQ-R1-01 remains nonblocking and no prior evidence was modified.
