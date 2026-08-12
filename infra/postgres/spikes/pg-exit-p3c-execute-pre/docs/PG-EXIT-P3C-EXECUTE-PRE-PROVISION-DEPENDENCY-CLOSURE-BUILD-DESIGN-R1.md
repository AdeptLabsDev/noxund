# PG Exit P3C Execute Pre - Dependency Closure Build Design R1

## 1. Decision

`BUILD-DESIGN-R1-ACCEPT-CLEAN-SIBLING-STAGES-OFFLINE`

Select B1, a clean sibling multi-stage architecture, with C1, a dedicated
minimal external build context. The selected design is deterministic by
contract, offline, fail-closed, and separates BUILD-PREP, BUILD,
IMAGE-INSPECT, and RUNTIME-VALIDATE.

BUILD remains unauthorized. This document defines a future build; it does not
perform one.

## 2. Accepted input identities

Source identity:

- Worktree: `C:/Adeptlabs/noxund-p3c-execute-pre`.
- Branch: `spike/pg-exit-p3c-execute-pre`.
- HEAD: `4873ac713397cf47642d39b1ef17e48a9301511d`.
- Pre-existing spike subtree: 59 regular files and 328001 bytes.
- Canonical inventory input: 6534 bytes.
- Canonical subtree SHA-256:
  `cd4e71acad61aafa229a86ca069f3efd4406e8c0f5930b2e46d362576e5be4a6`.

Artifact-inspection document:

- Size: 3312 bytes.
- Lines: 79.
- SHA-256:
  `8eff688540e3ea1ce3ab65b4daef310859721d1fe85e7f97df05cf9aa2d4061c`.
- Git blob: `d7df2577f0b92d7750d8530d3a8b1b980229cd0f`.

Artifact-inspection evidence:

- Regular files: 110.
- Total bytes: 1293569.
- Canonical input: 11058 bytes.
- Canonical SHA-256:
  `7c38f4116fade026d54bec86d4bf3c8c4e142c41ec73374e9ef7721e34f83aef`.
- SHA256SUMS entries: 109.
- SHA256SUMS SHA-256:
  `dc07f3b54954a1005c85804a74096c642f3bb9eb53df1c4d9591a5900372cf8c`.
- Replay result: 109/109, with zero missing, unexpected, or mismatched file.

Authoritative inspected manifest:

- Path: `derived/dependency-manifest.inspected-r1.json`.
- Size: 140990 bytes.
- SHA-256:
  `cefabe85adcd9521f857bc2ce06ea3b05b90bf651dc20da4e48ab00e95a38432`.
- Canonical payload: 103399 bytes.
- Canonical SHA-256:
  `2657dba7d758320ce4528424f1cf527cdeff0972af8f4db9b38d4ca05c9a9c53`.
- Inspection state: 21 `INSPECTED-PASS`.
- Build state: 21 `NOT-BEGUN`.

Base contract:

- Image:
  `postgres:15.18-bookworm@sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51`.
- Platform: `linux/amd64`.
- OS: Debian 12.15 / Bookworm.
- PostgreSQL packages remain exactly 15.18 and common packages remain exactly
  `291.pgdg12+1`.
- `libpq5` remains exactly `18.4-1.pgdg12+1`.
- Accepted SONAME is `libpq.so.5`.
- Accepted concrete library is
  `/usr/lib/x86_64-linux-gnu/libpq.so.5.18`.

Inspection results retained as binding:

- 19/19 valid Debian ar bodies.
- 19/19 exact control identities and reconciled relationships.
- 2222 Debian data members.
- Zero base-file collision.
- Zero conflicting non-directory inter-package collision.
- `BODY-PROVEN-ZERO-PROTECTED-PATH-COLLISION`.
- 31 statically inspected maintainer scripts: 27 expected sandbox actions,
  four exact-policy scripts, zero blocking, and zero unknown.
- Two pure Python wheels and 92/92 valid RECORD rows.
- `PURE-PYTHON-NO-BUNDLED-NATIVE-RUNTIME`.
- `EXACT-PURE-WHEEL-CLOSURE-BODY-PROVEN`.

`PROC-INSPECT-R1-01` remains nonblocking. Python and marker versions must
never be compared lexically. Debian relationships use Debian version
semantics. Python versions, requirements, and markers use standards-compliant
PEP 440 and PEP 508 semantics.

The Product Lead review artifact `docs/result/0005-result.md` was absent at
preflight. It is not recreated and is outside this gate.

## 3. Artifact lock and package-role boundary

The future context contains exactly these 19 Debian bodies:

| Role | Package | Version/arch | Filename | Bytes | SHA-256 |
|---|---|---|---|---:|---|
| FINAL-RUNTIME | libexpat1 | 2.5.0-1+deb12u2 amd64 | libexpat1_2.5.0-1+deb12u2_amd64.deb | 99888 | 2255e62fc22a86d2c544b8a3f516da9aee19383ad5742722ab4ce7f66a30dbc8 |
| FINAL-RUNTIME | libnsl2 | 1.3.0-2 amd64 | libnsl2_1.3.0-2_amd64.deb | 39480 | c0d83437fdb016cb289436f49f28a36be44b3e8f1f2498c7e3a095f709c0d6f8 |
| FINAL-RUNTIME | libpython3.11-minimal | 3.11.2-6+deb12u8 amd64 | libpython3.11-minimal_3.11.2-6+deb12u8_amd64.deb | 817740 | f3beaa03994ffedacf73c43a0843d53b062d347115d8af65bee2034552a4e6f9 |
| FINAL-RUNTIME | libpython3.11-stdlib | 3.11.2-6+deb12u8 amd64 | libpython3.11-stdlib_3.11.2-6+deb12u8_amd64.deb | 1798560 | 890b3540dad8a1ccc0deeca025db735bcc82629a76adacbe3b50fcc06ed528ca |
| FINAL-RUNTIME | libtirpc-common | 1.3.3+ds-1 all | libtirpc-common_1.3.3+ds-1_all.deb | 14048 | 3e3ef129b4bf61513144236e15e1b4ec57fa5ae3dc8a72137abdbefb7a63af85 |
| FINAL-RUNTIME | libtirpc3 | 1.3.3+ds-1 amd64 | libtirpc3_1.3.3+ds-1_amd64.deb | 85192 | 2a46d5a5e9486da11ffeff5740931740d6deae4f92cd6098df060dc5dff1e1c7 |
| FINAL-RUNTIME | media-types | 10.0.0 all | media-types_10.0.0_all.deb | 26136 | aaa46dcb3b39948ae2e0fdb72cfcb2f48c0b59f19785a3da8045c05eb19955dd |
| FINAL-RUNTIME | python3.11 | 3.11.2-6+deb12u8 amd64 | python3.11_3.11.2-6+deb12u8_amd64.deb | 574236 | cd7b10c24281416a6acb22cd23ed7391c7dddd4a3d4d4a63d37faa786639b5de |
| FINAL-RUNTIME | python3.11-minimal | 3.11.2-6+deb12u8 amd64 | python3.11-minimal_3.11.2-6+deb12u8_amd64.deb | 2064968 | 4aba533f7cc5e7b93b7ff24482840e96813f5bcde9cce028395b65a0d799ccee |
| BUILD-ONLY | ca-certificates | 20230311+deb12u1 all | ca-certificates_20230311+deb12u1_all.deb | 155260 | 0d5f444f594e48c1e16a41d8fc628a09b24c658916a1274025c2330f2a802bed |
| BUILD-ONLY | libpython3-stdlib | 3.11.2-1+b1 amd64 | libpython3-stdlib_3.11.2-1+b1_amd64.deb | 9312 | 4e58891d5c951a1e360ed9eaa814413cb5e84deadce3f08e801ac680434c786e |
| BUILD-ONLY | python3 | 3.11.2-1+b1 amd64 | python3_3.11.2-1+b1_amd64.deb | 26300 | 33f6dafbd1a6902d9063172ec7dbd4b2225e12009e0d7ec5c933a72c2f5f3b74 |
| BUILD-ONLY | python3-distutils | 3.11.2-3 all | python3-distutils_3.11.2-3_all.deb | 130936 | a620b555f301860a08e30534c7e6f7d79818e5e1977bfec39a612e7003074318 |
| BUILD-ONLY | python3-lib2to3 | 3.11.2-3 all | python3-lib2to3_3.11.2-3_all.deb | 76284 | 4e7f5e01e49a0622d10db3d0995666a6ead6a369cd127a996e9a4f9e91696a51 |
| BUILD-ONLY | python3-minimal | 3.11.2-1+b1 amd64 | python3-minimal_3.11.2-1+b1_amd64.deb | 26312 | 30f9618670e686d781afbfc713eb0830c29d2819e9cb2a0488800dad6bb99faa |
| BUILD-ONLY | python3-pip | 23.0.1+dfsg-1 all | python3-pip_23.0.1+dfsg-1_all.deb | 1324972 | d8024ededc6c7fe941ca96aabebdcf2d846fd130eae9d66aad1aa32a84454291 |
| BUILD-ONLY | python3-pkg-resources | 66.1.1-1+deb12u2 all | python3-pkg-resources_66.1.1-1+deb12u2_all.deb | 296604 | 25dfb378939ccdf27e7382adf44c168f86e22f9f1a8e6e3a2ec526431ed5e30f |
| BUILD-ONLY | python3-setuptools | 66.1.1-1+deb12u2 all | python3-setuptools_66.1.1-1+deb12u2_all.deb | 521580 | 96f934b8dbe4367c4cf9e4c740aa5c85f9a9ac8875a16556c8677fb342c7838f |
| BUILD-ONLY | python3-wheel | 0.38.4-2 all | python3-wheel_0.38.4-2_all.deb | 30808 | 623a8f7c70ba713b0d8d5a321f157405861f0a0b1a652edad2cda5f70f5773f9 |

The future context contains exactly these two final-runtime wheel bodies:

| Project | Version/tag | Filename | Bytes | SHA-256 |
|---|---|---|---:|---|
| psycopg | 3.2.9 py3-none-any | psycopg-3.2.9-py3-none-any.whl | 202705 | 01a8dadccdaac2123c916208c96e06631641c0566b22005493f09663c7a8d3b6 |
| typing-extensions | 4.16.0 py3-none-any | typing_extensions-4.16.0-py3-none-any.whl | 45571 | 481caa481374e813c1b176ada14e97f1f67a4539ce9cfeb3f350d78d6370c2e8 |

No body may change role. No base package body is copied. No other Debian
package, wheel, sdist, archive, or source is allowed.

## 4. Build architecture comparison

| Candidate | Reproducibility | Leakage/collision risk | Complexity | Decision |
|---|---|---|---|---|
| B1 clean sibling stages | Strong: runtime and builder start from the same digest-pinned runtime stage | Lowest: final never inherits builder packages or installer | Moderate and inspectable | SELECTED |
| B2 one stage then removal | Weak: deletion does not remove lower-layer bodies or all maintainer-script effects | High installer and package-state residue | Superficially low, operationally ambiguous | REJECTED |
| B3 copy entire virtual environment | Medium at best: interpreter paths and symlinks bind to builder layout | High: pip/setuptools metadata and scripts may leak | Medium | REJECTED |
| B4 custom wheel installer | Potentially strong only after validating custom code | Introduces a new trusted installer and wheel-semantics risk | High | REJECTED |
| B5 alternative | No materially stronger bounded alternative is established | Unresolved | Unnecessary | NOT SELECTED |

B1 wins because it makes absence claims structural. The final stage descends
from `python-runtime-base`, not from the mutated builder. Build-only packages,
pip, setuptools, wheel tooling, caches, and Debian bodies therefore cannot
enter through inheritance.

## 5. Exact stage graph

The future Dockerfile has five named stages:

```text
accepted-base
  +-> base-audit
  +-> python-runtime-base
        +-> wheel-builder
        +-> final-client
```

### 5.1 accepted-base

- `FROM --platform=linux/amd64` the exact accepted digest.
- No mutable tag-only identity.
- No pull fallback.
- No filesystem mutation.
- Assert platform, OS metadata, protected package status, and protected paths.
- Assert no second libpq and no native Psycopg.

### 5.2 base-audit

- Sibling derived from `accepted-base`; never inherited by the final image.
- Hash exact protected files and record size, mode, owner, and link target.
- Record protected package versions/status and loader configuration.
- Record full pre-provision package inventory.
- Produce a canonical protected-baseline file inside this non-final stage.
- The immutable base digest is the authority; the audit materializes its
  actual protected bytes without fabricating unavailable hashes.

### 5.3 python-runtime-base

- Derived independently from `accepted-base`.
- Receives exactly the nine FINAL-RUNTIME bodies through read-only BuildKit
  bind mounts. The bodies are never copied into an image layer.
- Uses only explicit local `dpkg` unpack/configure commands.
- Contains no build-only package and no wheel body.
- Compares protected state to `base-audit` through a read-only stage mount.
- Produces the clean parent for both `wheel-builder` and `final-client`.

### 5.4 wheel-builder

- Derived from `python-runtime-base`.
- Receives exactly the ten BUILD-ONLY bodies and two wheels through read-only
  bind mounts.
- Installs the build-only Debian closure locally and offline.
- Uses Debian pip only as an offline installer with resolution disabled.
- Creates and validates one staged wheel runtime tree.
- May contain installer tooling because no final stage inherits it.

### 5.5 final-client

- Derived from clean `python-runtime-base`, never from `wheel-builder`.
- Copies only the already validated staged runtime tree from `wheel-builder`.
- Contains no wheel body, Debian body, pip cache, installer report, index
  configuration, build policy, or builder evidence.
- Revalidates package, protected-file, wheel-tree, and image-config invariants.
- Sets a fail-closed default command; runner integration remains a later gate.

## 6. Build-context architecture

### 6.1 Candidate comparison

- C1, a dedicated minimal external context, is selected. It makes the complete
  input set enumerable before Docker receives it and avoids repository-root and
  evidence-directory contamination.
- C2, named local contexts, remains useful as a later implementation mechanism
  for read-only body mounts, but it does not replace the single canonical C1
  context identity. Host path binding and named-context CLI spelling vary more
  across Windows and Linux builders.
- C3, the repository-root context, is rejected. It would include unrelated
  untracked files and would make correctness depend on a negative
  `.dockerignore` policy.

### 6.2 Selected context contract

BUILD-PREP creates one new dedicated context at a Product Lead-authorized path.
It contains only:

- one Dockerfile;
- one exact Debian body lock;
- one exact wheel lock;
- one package-order policy;
- one maintainer-script policy;
- one protected-invariant policy;
- one runtime-tree allowlist policy;
- one deterministic context manifest; and
- the 19 Debian bodies and two wheel bodies, copied byte-for-byte from the
  acquisition store.

The context has POSIX-style relative paths only. Windows source paths are
resolved and checked on the host, then copied into fixed context-relative paths
under `artifacts/debian/` and `artifacts/wheels/`. No absolute Windows path is
embedded in the Dockerfile, locks, or image. Every regular file is inventoried
as UTF-8 path, byte size, lowercase SHA-256, logical role, normalized mode, and
source identity. Ordering is bytewise UTF-8 path order. The canonical context
serialization is LF-only TSV with fields escaped as backslash, tab, CR, and LF;
its aggregate SHA-256 is computed over the exact TSV bytes.

BUILD-PREP must fail on an unexpected directory entry, regular file, symlink,
reparse point, ADS, device, FIFO, socket, duplicate case-insensitive Windows
path, path traversal, or path whose byte identity differs from the inspected
manifest. Bodies are copied without modifying the acquisition store, then
rehashed at both source and destination. Context files use uid/gid 0:0 in the
build view, mode 0644 except the Dockerfile and policy scripts, if any, which
remain non-executable unless explicit execution is required. BUILD-PREP records
the context manifest and aggregate digest but performs no Docker operation.

## 7. Debian installation model

The selected model is an explicit Debian-native local transaction using
`dpkg --unpack` followed by bounded `dpkg --configure` phases. APT and every
implicit resolver are prohibited. Each command names exact local body paths;
there is no repository configuration, package selection, upgrade, downgrade,
removal, alternate provider, or network lookup.

Before each phase the build checks every body filename, size, and SHA-256. It
captures the dpkg status database before and after, the exact command and exit
code, pending package states, pending triggers, conffile decisions, and the
protected invariant digest. A nonzero command, unexpected package action, or
unapproved status transition stops the build. Docker layer rollback is the only
rollback: no compensating package removal is attempted.

Conffile policy is fail closed: new package conffiles use the inspected body
version when no path exists; an existing differing conffile causes failure.
Neither `--force-confnew` nor `--force-confold` is a blanket policy. Debconf is
noninteractive and accepts only exact preseeded answers listed in the policy.
`policy-rc.d` denies all service starts with the conventional denial result, and
any service action not observed and allowed by the script policy fails. Triggers
are deferred during unpack/configure barriers and then processed only when the
pending trigger set equals the inspected allowlist.

## 8. Exact package-role boundary

`python-runtime-base` receives exactly the nine FINAL-RUNTIME packages listed in
Section 3. `wheel-builder` receives exactly the ten BUILD-ONLY packages listed
there. No build-only body or package may enter `python-runtime-base` or
`final-client`. No package may change role during BUILD. Base dependencies are
satisfied only by exact accepted R9 identities and cannot be reselected.

The final package-status assertion requires all nine new runtime packages to be
`install ok installed`, all protected packages to retain their exact accepted
versions and statuses, and none of the ten build-only package names to be
installed. It additionally proves absence of pip, setuptools, wheel,
`python3-distutils`, `python3-lib2to3`, ensurepip payloads, and package-index
configuration from `final-client`.

## 9. Exact package ordering model

Order is generated from the inspected Pre-Depends and Depends graph with Debian
version comparison, never lexical comparison. Graph ambiguity, a cycle across a
required configuration barrier, or a different edge set is a failure.

The runtime phase is:

1. unpack and configure `libtirpc-common`;
2. unpack and configure `libtirpc3`;
3. unpack and configure `libnsl2`;
4. unpack and configure `media-types`;
5. unpack and configure `libexpat1`;
6. unpack and configure `libpython3.11-minimal`;
7. unpack and configure `python3.11-minimal`;
8. unpack and configure `libpython3.11-stdlib`; and
9. unpack and configure `python3.11`.

Where the verified relationship graph permits a batch, the implementation may
batch only within one numbered barrier and must preserve the same effective
order. The builder phase first unpacks and configures `python3-minimal` to
satisfy Pre-Depends, then processes, in graph order,
`libpython3-stdlib`, `python3`, `python3-lib2to3`, `python3-distutils`,
`python3-pkg-resources`, `python3-setuptools`, `python3-wheel`,
`ca-certificates`, and `python3-pip`. Each phase ends with an exact configured
set and an exact pending-trigger set. Trigger processing is a separate final
barrier.

## 10. Maintainer-script policy

All 31 inspected scripts are bound by package, script name, size, SHA-256,
interpreter, and phase. The 27 `EXPECTED-BUILD-SANDBOX-ACTION` scripts may run
only in their required Debian lifecycle phase under the command, environment,
filesystem, service, network, and interaction allowlists derived from the
inspection evidence. The four `REQUIRES-EXACT-BUILD-POLICY` scripts receive the
additional rules below. No script is trusted merely because it is Debian code.

Allowed interpreters are only the exact base shell/interpreter paths observed in
the scripts and proved present in the accepted base. PATH is fixed to
`/usr/sbin:/usr/bin:/sbin:/bin`. The environment is reduced to the exact dpkg and
debconf lifecycle variables, `DEBIAN_FRONTEND=noninteractive`, `LC_ALL=C.UTF-8`,
`LANG=C.UTF-8`, `TZ=UTC`, and policy-specific variables. Proxy variables,
credentials, SSH variables, user package paths, and loader overrides are absent.

Filesystem writes are limited to dpkg state, declared conffiles, inspected
package paths, approved trigger outputs, and script-specific paths below.
Network is disabled by the builder and any attempted socket activity is a
failure. Interactive reads are a failure. Service starts are denied by the
exact `policy-rc.d`; an attempt outside the inspected expected set is a failure.
Every required script must exit zero and produce only declared writes and
trigger transitions. `prerm` and `postrm` execution is forbidden in this clean
install because it would imply removal, rollback, or an unexpected package
transition.

### 10.1 `ca-certificates` `config`

Bind size 9868 and SHA-256
`99c9d296c5a65cf91c80795a1e3eef323624b290ed6821987f1a058cf8834484`.
Run exactly once after unpack and before `postinst`, with noninteractive debconf
answers fixed to the inspected package's default certificate set. No locally
added certificate, disabled-default delta, or host certificate directory is
accepted. Reads are limited to the package's certificate and debconf metadata;
writes are limited to the package's debconf state.

### 10.2 `ca-certificates` `postinst`

Bind size 5817 and SHA-256
`bbad2df5d3c5e3d787789275830bc5b597fe6e9218a99516947a079dcae9e262`.
Run only for `configure` after the exact config result. Permit
`update-ca-certificates` and writes only to `/etc/ssl/certs`, the generated
certificate bundle, and declared dpkg/trigger state. The certificate source is
only the installed package's allowlisted `/usr/share/ca-certificates` tree.
Hook directories must be empty of unapproved hooks; an unexpected hook is a
failure. Network and service activity are prohibited. `ca-certificates` remains
BUILD-ONLY because wheel installation is offline and the final runtime contract
does not require this newly provisioned trust bundle; the clean final sibling
therefore retains only whatever exact CA state the accepted base already had.

### 10.3 `ca-certificates` `postrm`

Bind size 1629 and SHA-256
`df6b014dfc49380007a13f89320a110bd8bf852ab01856ae2c4bf42ba4566f0e`.
It must not run. Any removal or purge phase is an unexpected package action and
fails the build rather than attempting cleanup.

### 10.4 `python3` `preinst`

Bind size 835 and SHA-256
`5ef8d9e6e33c1034202a2fdde074f425513255441677b87693dee1ea91d8472a`.
Run only for a first-time `install`, never `upgrade`. Before execution assert no
installed `python3` package, no unmanaged Python alternative, and that the
script's inspected legacy HTML cleanup target is absent or is the exact benign
symlink form anticipated by the script. Allow only the stat/readlink/removal
commands identified statically, and allow removal only of that exact legacy
symlink. Any regular file, directory tree, different link target, unexpected
argument, or additional write fails before execution. Package database and
alternatives state must match after execution except for the declared preinst
effect.

## 11. Offline wheel installation model

The wheelhouse contains exactly the two bodies in Section 3 and no directory
entry or additional file. BUILD rechecks each filename, size, and SHA-256 before
use. The lock contains exactly normalized name, exact version, and one approved
SHA-256 for each wheel; it contains no ranges, extras, URLs, recursive includes,
environment substitution, or index configuration.

In `wheel-builder`, the only installer command class is the exact Debian
`/usr/bin/python3.11 -I -s -m pip` implementation provided by the inspected
build-only closure. Its semantics are:

- `--no-index` with one fixed context-local `--find-links` directory;
- `--no-deps`, so no resolver decision occurs;
- `--only-binary=:all:` and no source build;
- `--require-hashes` against the exact two-entry lock;
- `--no-build-isolation`, `--no-compile`, `--ignore-installed`, and no
  implicit upgrade;
- no cache, no version check, no user site, and no configuration files; and
- an exact target
  `/opt/noxund-wheel-root/usr/local/lib/python3.11/dist-packages`.

The target is created empty with uid/gid 0:0 and mode 0755. The installer runs
with network disabled and a clean environment. PEP 440 and PEP 508 evaluation
uses standards-compliant numeric semantics under the fixed CPython 3.11.2,
Linux x86_64, no-extras environment. Lexical version comparison is prohibited by
PROC-INSPECT-R1-01. Any resolution, download, source-build, native-wheel, reuse,
extra dependency, or file outside the target is a failure.

## 12. Runtime-tree copy model

The staged tree is the exact contents installed under
`/opt/noxund-wheel-root/usr/local/lib/python3.11/dist-packages`. It must contain
only the allowlisted Psycopg and typing-extensions module paths and their
required:

- `psycopg-3.2.9.dist-info`; and
- `typing_extensions-4.16.0.dist-info`

metadata paths. The BUILD-PREP runtime-path policy is derived from the inspected
wheel member inventories and RECORD files; no path is invented during BUILD.

The builder generates a deterministic inventory of every staged regular file,
directory, and symlink: UTF-8 relative path, type, byte size, SHA-256, mode,
uid/gid, source wheel, and RECORD identity. Files must reconcile to installed
RECORD data, with installation-generated RECORD handling explicitly identified.
Unexpected, missing, duplicate, case-colliding, or cross-wheel paths fail.
Symlinks are prohibited unless a specific inspected member and safe relative
target were approved; the current pure wheels require none.

Before transfer, regular-file timestamps are normalized to SOURCE_DATE_EPOCH,
directories to mode 0755, ordinary files to 0644, and any approved script to
0755. Ownership becomes 0:0 in the image layer. `final-client` copies the
allowlisted tree only to
`/usr/local/lib/python3.11/dist-packages`, using the validated builder inventory
as the positive copy list. It independently rehashes the destination and
requires byte-for-byte inventory equality.

The final stage rejects pip, setuptools, wheel, ensurepip,
`python3-distutils`, `python3-lib2to3`, build-only Debian paths, wheel bodies,
pip cache, installer entry points, installation reports, index configuration,
locks, policies, temporary files, and builder evidence. A whole virtual
environment or whole builder directory is never copied.

## 13. Final runtime environment

The final image contract sets exactly:

- `PSYCOPG_IMPL=python`;
- `PYTHONNOUSERSITE=1`;
- `PYTHONDONTWRITEBYTECODE=1`;
- `PATH=/usr/bin:/bin`;
- `LANG=C.UTF-8`;
- `LC_ALL=C.UTF-8`;
- `TZ=UTC`;
- `HOME=/nonexistent`; and
- `TMPDIR=/tmp`.

The approved module path is the interpreter's normal Debian search path plus
`/usr/local/lib/python3.11/dist-packages`; no ambient `PYTHONPATH` is set.
`LD_LIBRARY_PATH`, `LD_PRELOAD`, user-site packages, native Psycopg fallback,
proxy variables, pip configuration, and runtime installer entry points are
prohibited. Loader search configuration remains the accepted base
configuration; Python provisioning may not add an ld.so fragment or another
libpq. Locale and timezone are fixed without copying host state.

## 14. Runtime identity and hardening

The final runtime reuses the accepted base's existing `postgres` identity by
name, subject to future build preflight proving its numeric uid/gid, primary
group, supplementary groups, home, and shell. This design does not invent
numeric identities. Until that proof is recorded, RBF-14 remains open.

The final image declares no additional Linux capability and is compatible with
capability drop-all, no-new-privileges, and a read-only root filesystem. Writable
state is limited to the inherited PostgreSQL data-volume contract and an
ephemeral `/tmp` tmpfs with bounded size and safe mode; any runner-specific
workspace requires a later explicit mount policy. The image contains no secret,
credential, SSH key, Docker socket, host package directory, or arbitrary host
mount. Runtime egress is denied by default and any separately authorized
database network is bounded to the later validation gate. Package installation,
privilege escalation, and writes outside declared writable paths are forbidden.

The inherited PostgreSQL volume declaration and base entrypoint/configuration
remain RBF-04 concerns and must be inspected before using this image strictly as
a client. No change to them is authorized by this design.

## 15. Protected invariant checks

BUILD-PREP produces one positive protected-invariant manifest derived from R9
and the accepted base contract. Checks occur before Python provisioning, after
the runtime Debian transaction, after the builder transaction, before runtime
tree copy, and in `final-client`.

Every check covers:

- exact versions and `install ok installed` statuses for
  `postgresql-15=15.18-1.pgdg12+1`,
  `postgresql-client-15=15.18-1.pgdg12+1`,
  `postgresql-client-common=291.pgdg12+1`,
  `postgresql-common=291.pgdg12+1`, and
  `libpq5=18.4-1.pgdg12+1`;
- exact protected-file path, type, size, SHA-256, mode, and ownership, including
  `/usr/lib/x86_64-linux-gnu/libpq.so.5.18`, the `libpq.so.5` SONAME
  resolution, and PostgreSQL 15 CLI files;
- `psql`, `pg_dump`, and `pg_restore` package/file identities, while command
  execution is reserved for later validation;
- unchanged ld.so configuration, cache inputs, and loader environment;
- no second `libpq.so*`, no alternate libpq package, and no protected-path
  overwrite;
- no `psycopg_c`, `psycopg_binary`, native extension, or bundled native
  library; and
- exact before/after package-file ownership for the complete protected set.

The base-audit stage records the authoritative before digest without changing
the base. Later stages compare their live state to that read-only digest and to
the exact policy. A mismatch is RED; a missing measurement is not success.

## 16. Determinism and provenance model

The approved `SOURCE_DATE_EPOCH` is `1783993009`, the whole-second floor of
the accepted base image creation timestamp
`2026-07-14T01:36:49.492774343Z`. BUILD-PREP records that derivation. All
created regular files and directories use that timestamp unless an immutable
base path is preserved byte-for-byte. Created files use normalized ownership
and modes from Sections 6 and 12. Image configuration uses an explicit created
timestamp when the selected builder/output mechanism supports it; otherwise the
limitation is recorded and reproducible image ID is not claimed.

Allowed build arguments are only the base digest, platform, SOURCE_DATE_EPOCH,
and exact policy/context digests, all repeated in the context manifest. The
build environment is the exact allowlist in this document. The Dockerfile,
context manifest, body lock, inspected-manifest identity, package-order policy,
script policy, runtime-copy allowlist, and protected manifest each receive a
size and SHA-256 identity.

The future build disables external cache import/export and begins with a
documented empty or specifically accepted local cache policy. It captures the
builder identity/version, command argument array, stage logs, input identities,
local image ID, config digest, layer diff IDs, history, and final filesystem
inventory. It produces a local image only, with no push. An OCI archive is not
created unless a later gate explicitly authorizes its exact destination and
identity.

This contract targets deterministic filesystem contents and deterministic image
configuration. A reproducible local image ID is claimed only after two
independent builds reproduce all inputs, layer/config bytes, and ID. A registry
digest is unavailable without publication and is never inferred from a local
image ID.

## 17. Future build-command contract

BUILD may execute only the exact BUILD-PREP-approved Dockerfile and C1 context.
The command class is a local BuildKit/buildx build with:

- exact local base digest and a preflight proving it already exists;
- `--platform=linux/amd64`;
- pull disabled and failure rather than automatic pull;
- network disabled for every stage;
- no secret mount, SSH forwarding, entitlement, host package path, or Docker
  socket inside a stage;
- exact build arguments and no undeclared environment input;
- read-only bind mounts for approved body files where the prepared Dockerfile
  uses them;
- local Docker image output with one exact temporary tag;
- no registry output or push; and
- complete stdout/stderr, exit status, builder identity, timing, and result
  identity capture.

The exact CLI argument array, builder selection, tag, Dockerfile identity,
context identity, and cache policy are fixed by BUILD-PREP and must be reviewed
before BUILD authorization. BUILD performs no version resolution and may not
alter the prepared context.

## 18. Fail-closed conditions

The future BUILD fails on any:

- missing or unexpected artifact, body, context path, or wheelhouse entry;
- filename, size, hash, context, manifest, Dockerfile, or policy mismatch;
- base-image digest/platform mismatch or local-base absence requiring a pull;
- unsupported or ambiguous Debian version, dependency, order, trigger, conffile,
  or maintainer-script decision;
- interactive prompt, network attempt, unapproved service action, command, hook,
  environment variable, or filesystem write;
- package removal, replacement, alternate-provider selection, upgrade,
  downgrade, implicit resolution, or unexpected status;
- protected-package, protected-file, loader, CLI, libpq, or ownership drift;
- wheel resolution, source build, native wheel, extra dependency, native
  Psycopg, second libpq, or bundled native library;
- builder tool, Debian BUILD-ONLY file, body, cache, report, config, evidence, or
  temporary-file leakage into the final stage;
- missing, extra, duplicate, unsafe, or undeclared final-runtime path;
- non-deterministic or unapproved ownership, mode, timestamp, configuration, or
  build argument;
- failed evidence reproduction, secret exposure, prohibited execution, or
  attempted egress; or
- unknown, absent, partial, or ambiguous result represented as success.

A failure preserves evidence, stops the gate, and never uses cleanup,
substitution, retry with changed inputs, or installer fallback to manufacture a
passing result.

## 19. Future BUILD-PREP assertions

`PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-BUILD-PREP-R1`
must, without Docker:

1. reproduce every repository, prior-evidence, acquired-body, and inspected
   manifest identity;
2. create only the authorized C1 context;
3. copy exactly 19 Debian and two wheel bodies and reproduce their hashes;
4. create the exact Dockerfile, locks, stage policies, package order,
   maintainer-script allowlists, runtime-path allowlist, and protected manifest;
5. bind all 31 scripts and the four exact-policy decisions;
6. bind the exact Debian and PEP 440/508 comparison implementations;
7. prove context path safety, Windows-to-Linux path mapping, modes, and aggregate
   identity;
8. prove exact package roles, stage inheritance, body mounts, and no context
   extras;
9. prove the local-runtime identity selection remains unresolved until numeric
   base identity inspection is authorized; and
10. emit the exact future build command without executing it.

## 20. Future BUILD assertions

`PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-BUILD-R1` must:

1. reproduce the approved BUILD-PREP context and command;
2. prove the accepted base exists locally at the exact digest and platform with
   no pull;
3. execute one offline local build with all prohibited mounts and entitlements
   absent;
4. capture every Debian transaction, script, trigger, wheel-install, tree-copy,
   and protected-check result;
5. prove the final package set, staged wheel inventory, and sibling-stage
   separation;
6. prove no network, resolver, source build, package substitution, native
   Psycopg, second libpq, or protected drift occurred;
7. capture the local image ID/config/layers without running a container; and
8. stop without inspection or runtime execution beyond build-time installation
   actions explicitly authorized by that future gate.

## 21. Future IMAGE-INSPECT assertions

`PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-IMAGE-INSPECT-R1`
must inspect without runner or database execution and prove:

- exact base ancestry, platform, image config, environment, user, entrypoint,
  command, volumes, labels, history, layers, and created timestamp;
- exact nine runtime Debian additions and absence of all ten BUILD-ONLY
  packages;
- exact Python 3.11.2 and pure-wheel filesystem identities;
- no wheel bodies, installer, resolver, cache, index configuration, builder
  evidence, native Psycopg, native wheel payload, or second libpq;
- exact protected packages, files, CLI identities, libpq path/SONAME, loader
  configuration, ownership, modes, and timestamps;
- exact runtime-tree and final filesystem inventories;
- the accepted `postgres` numeric identity and hardening contract, resolving
  RBF-14 only when evidence is complete; and
- inherited volume/entrypoint/client-image implications, without closing RBF-04
  prematurely.

## 22. Future RUNTIME-VALIDATE assertions

`PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-RUNTIME-VALIDATE-R1`
requires separate execution and database authorization. It must prove:

- CPython is exact 3.11.2 and imports only the approved module tree;
- Psycopg is exact 3.2.9 and `pq.__impl__` is `python`;
- typing-extensions is exact 4.16.0;
- loaded libpq is exact 18.4 from
  `/usr/lib/x86_64-linux-gnu/libpq.so.5.18` through SONAME
  `libpq.so.5`;
- `psql --version`, `pg_dump --version`, and `pg_restore --version` are
  exactly 15.18;
- the target PostgreSQL server is exactly 15.18;
- protocol negotiation and required extended-query, binding, SQL NULL,
  transaction, SQLSTATE, backend-PID, transaction-status, cancellation,
  notice/error, text-result, and command-tag behavior pass;
- no PostgreSQL 18-only feature, native Psycopg fallback, alternate libpq,
  ambient user site, or loader shadowing is used; and
- required security, read-only-root, tmpfs, privilege, secret, mount, and egress
  controls behave as designed.

These assertions keep RBF-07 runtime validation and RBF-08 open until actual
runtime evidence passes.

## 23. Finding dispositions

Preserved OPEN:

- RBF-01 OPEN;
- RBF-04 OPEN for the client image;
- RBF-05 OPEN;
- RBF-06 OPEN;
- RBF-07 design-decided, runtime validation OPEN;
- RBF-08 OPEN;
- RBF-11 OPEN, narrowed by the exact build architecture but awaiting final
  image inspection; and
- RBF-13 OPEN nonblocking for additional non-trust signer provenance.

Preserved RESOLVED:

- RBF-03 RESOLVED;
- RBF-02 RESOLVED-EXACT-WHEEL-BODIES-AND-CLOSURE-INSPECTED;
- RBF-09 RESOLVED-EXACT-DEBIAN-CLOSURE-BODIES-INSPECTED;
- RBF-10 RESOLVED-AUTHORITATIVE-PURE-WHEEL-CLOSURE-INSPECTED; and
- RBF-12 RESOLVED-BODY-PROVEN-ZERO-PROTECTED-PATH-COLLISION.

New finding:

- RBF-14-OPEN-EXISTING-POSTGRES-RUNTIME-UID-GID-UNPROVEN. The selected design
  reuses the base `postgres` identity but does not invent its numeric uid/gid,
  groups, home, or shell. BUILD-PREP records the required inspection assertion;
  IMAGE-INSPECT may close it only from exact image evidence.

PROC-INSPECT-R1-01 remains a nonblocking process note. All future Debian version
checks use Debian semantics, and all Python version/marker checks use
standards-compliant PEP 440/PEP 508 semantics. Lexical comparison is prohibited.

## 24. Exact future gate sequence

The separated future sequence is:

1. `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-BUILD-PREP-R1` -
   create and attest the exact context, Dockerfile, locks, and policies without
   Docker;
2. `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-BUILD-R1` -
   execute only the approved offline local build;
3. `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-IMAGE-INSPECT-R1` -
   inspect the resulting image without runner or database execution; and
4. `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-RUNTIME-VALIDATE-R1`
   - perform separately authorized Python, Psycopg, libpq, CLI, and PostgreSQL
   15.18 interoperability validation.

The exact next-gate recommendation is:

`PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-BUILD-PREP-R1`

It is not begun by this unit.

## 25. Scope and activity attestation

This unit created only this authorized design document. It created no build
context, Dockerfile outside this document, lock file, policy file, or external
evidence directory. It did not copy or modify an artifact body or prior
evidence.

No network, Docker, image-store access, pull, package installation,
package-manager execution, maintainer-script execution, Python or pip execution,
wheel installation, image build, container creation, database access, runner,
harness, fixture, migration, or test operation occurred. Nothing was staged,
committed, fetched, pushed, or published. The known `.rar` was checked by path
only and remained untouched. The Product Lead-authorized
`docs/result/0005-result.md` was absent at preflight and was not recreated. No
later gate began.
