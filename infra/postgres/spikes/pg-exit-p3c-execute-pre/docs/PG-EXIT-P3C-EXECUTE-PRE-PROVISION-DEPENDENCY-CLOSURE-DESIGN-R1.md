# PG-EXIT-P3C-EXECUTE-PRE - Dependency Closure Design R1

Unit: PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-DESIGN-R1

Decision: DEPENDENCY-CLOSURE-DESIGN-ACCEPT-SNAPSHOT-WHEELHOUSE

Scope: design only. This document is not authorization to acquire an artifact,
run a resolver or installer, build an image, create a container, or execute the
runner or harness.

## 1. Decision

Select closure architecture C1:

- Debian source model D1: exact official Debian snapshot metadata and package
  artifacts for Bookworm and `linux/amd64`.
- Python installation model P1: build-stage-only pip operating against an
  exact, local, hash-locked, wheel-only directory, followed by an allowlisted
  runtime-tree copy into a clean final stage.
- CPython contract: major/minor 3.11. The exact Debian package version and
  recursive package closure remain `TO-BE-RESOLVED-BY-ACQUIRE-PRE`.
- Psycopg contract: pure Python `psycopg==3.2.9`, forced with
  `PSYCOPG_IMPL=python`.
- Native client contract: retain the accepted system
  `libpq5=18.4-1.pgdg12+1` and PostgreSQL CLI tools 15.18 without package or
  file drift.
- Executable contract: no runtime pip, package installation, source build,
  package-index access, or egress.

This disposition establishes a bounded method, not an exact acquired closure.
The exact Debian snapshot timestamps, CPython patch/package revision, Debian
artifact set, exact `typing-extensions` version, and any additional active
wheel dependencies remain unresolved until separately authorized gates.

The exact next gate is:

`PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-ACQUIRE-PRE-R1`

It must be metadata-only.

## 2. Binding contracts and accepted evidence

### 2.1 Base identity

- Image identity:
  `sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51`
- Platform: `linux/amd64`.
- Operating system: Debian 12.15 / Bookworm.
- PVD-01: `PVD-01-CLOSED-FOR-BASE-INVENTORY`.

The authoritative R9 inventory is the only base-satisfied package input. A
package name inferred from an image tag, current repository, or documentation
does not replace that inventory.

### 2.2 PostgreSQL and libpq identity

Protected installed package identities are:

- `postgresql-15=15.18-1.pgdg12+1` `amd64`;
- `postgresql-client-15=15.18-1.pgdg12+1` `amd64`;
- `postgresql-client-common=291.pgdg12+1`;
- `postgresql-common=291.pgdg12+1`;
- `libpq5=18.4-1.pgdg12+1` `amd64`.

Protected runtime identities include:

- SONAME `libpq.so.5`;
- observed package-owned file
  `/usr/lib/x86_64-linux-gnu/libpq.so.5.18`;
- `psql`, `pg_dump`, and `pg_restore` from PostgreSQL client 15.18;
- target PostgreSQL server exactly 15.18.

There may be no second libpq lineage. No future Python closure may add, remove,
upgrade, downgrade, replace, divert, or shadow a protected PostgreSQL or libpq
package or file.

The selected libpq disposition remains:

`RBF-07-DESIGN-DECIDED-ACCEPT-18.4-RUNTIME-VALIDATION-OPEN`

RBF-08 remains OPEN because exact runtime loading and PostgreSQL 15.18
interoperability have not been executed.

### 2.3 Python and Psycopg identity

- Python implementation: CPython.
- Python major/minor: 3.11.
- Exact patch and Debian package revisions: unresolved.
- Psycopg distribution: `psycopg==3.2.9` without extras.
- Required implementation selector: `PSYCOPG_IMPL=python`.
- Forbidden distributions: `psycopg_c`, `psycopg_binary`, and any renamed or
  vendored equivalent.
- Required native client: the protected system libpq 18.4.
- Runtime pip, setuptools, wheel, ensurepip, installer entry points, and Python
  package-index configuration: forbidden in the final runtime unless a future
  Product Lead decision explicitly changes this contract.

Earlier official metadata identified:

- `psycopg-3.2.9-py3-none-any.whl`;
- size `202705` bytes;
- SHA-256
  `01a8dadccdaac2123c916208c96e06631641c0566b22005493f09663c7a8d3b6`;
- active CPython 3.11 requirement `typing-extensions>=4.6`.

These are metadata observations. They do not prove that the wheel body exists
locally, that its body matches the metadata, or that `typing-extensions` is the
complete transitive closure.

### 2.4 Static standard-library surface

Static source inspection, without executing Python, found direct use of these
standard-library modules:

- `argparse`;
- `dataclasses`;
- `enum`;
- `hashlib`;
- `json`;
- `os`;
- `pathlib`;
- `re`;
- `subprocess`;
- `sys`;
- `threading`;
- `time`;
- `typing`;
- `__future__`.

The final standard-library boundary is not limited to this direct list.
ACQUIRE-PRE must bind the complete Debian CPython standard-library package
closure. Artifact inspection must additionally inventory Psycopg imports and
data files. Final image inspection must prove that every direct and transitive
runtime import is supplied by the approved CPython or wheel closure.

## 3. Debian Python source model

### 3.1 D1 - official Debian snapshot packages - selected

D1 is selected. Future Debian artifacts must come from exact official Debian
snapshot states, not a moving suite or mirror view.

ACQUIRE-PRE must select and freeze an exact timestamp for each required
official archive family, such as the main Debian archive and, only when needed,
the Debian security archive. Snapshot timestamps are recorded separately per
archive because their import times need not be identical. The selected state
must identify Bookworm, the required component set, binary architecture
`amd64`, and architecture-independent package metadata.

The metadata boundary must include:

- exact snapshot timestamp and immutable snapshot URL per archive;
- exact `InRelease`, or exact `Release` plus detached signature, identity;
- accepted Debian archive signing-key fingerprint and key-file identity;
- `Release` SHA-256 entries for every consumed package index;
- exact compressed and decompressed package-index identities;
- exact package stanza identity for every selected and base-satisfying
  candidate;
- package name, version, architecture, filename, byte size, and SHA-256;
- all dependency, conflict, replacement, `Provides`, `Essential`, and
  `Multi-Arch` fields used by resolution.

The Product Lead must approve the exact snapshot timestamps before package-body
acquisition. A timestamp chosen after artifact selection, a timestamp alias,
or the latest state before an unrecorded time is invalid.

### 3.2 D2 - current mutable Debian repository - rejected

D2 is rejected. A suite name such as `bookworm`, a CDN endpoint, or a current
mirror response can change without changing the design input. TLS transport
does not make repository state immutable. D2 would permit identical commands
to resolve different package versions and hashes.

A current repository response may inform ACQUIRE-PRE only if that response is
captured as metadata and leads to an independently frozen official snapshot.
It may not be the acquisition or build source.

### 3.3 D3 - standalone CPython distribution - rejected

D3 is rejected for this unit because it would add a separately produced native
runtime, provenance system, libc/OpenSSL/ffi/zlib closure, update channel, and
loader analysis. It can duplicate libraries already governed by Debian and can
weaken package-file ownership evidence. No accepted standalone CPython producer
or immutable artifact identity currently exists.

### 3.4 D4 - source-built CPython - rejected

D4 is rejected because it introduces compilers, headers, build tools, source
archives, configure choices, build-time feature discovery, and additional
OpenSSL, ffi, zlib, ncurses, sqlite, and loader decisions. It materially
increases the supply-chain and reproducibility surface without a runner
requirement that Debian CPython cannot satisfy.

## 4. Debian dependency-resolution model

### 4.1 Resolver inputs

The future resolver consumes only:

1. the accepted R9 installed-package inventory and package-file ownership;
2. the approved immutable Debian snapshot metadata chain;
3. exact seed roles approved for CPython 3.11 final runtime and build tooling;
4. the protected-package and protected-file set in this document;
5. a fixed target tuple: Debian Bookworm, `linux`, `amd64`, native architecture
   `amd64`, and no foreign architecture unless separately approved;
6. an explicit policy for optional relationships and alternatives.

It must not inspect host packages, a mutable package cache, Docker state, or a
live repository to fill a missing edge.

### 4.2 Relationship handling

The resolver must parse Debian control syntax losslessly and evaluate:

- `Pre-Depends` recursively and before dependent unpack/configure order;
- `Depends` recursively;
- architecture qualifiers and package architecture eligibility;
- version operators with Debian version-comparison semantics;
- alternatives as ordered syntax but not as implicit authorization;
- virtual packages and versioned or unversioned `Provides`;
- `Essential` status from exact package records;
- `Multi-Arch` values and architecture-qualified relationships;
- `Breaks`, `Conflicts`, `Replaces`, and file-ownership overlap;
- packages already installed in the accepted base;
- dependency cycles and configure-order implications.

`Recommends`, `Suggests`, and `Enhances` do not enter the closure by default.
If a runtime capability needs one, it must become an explicit seed with a
recorded justification and Product Lead approval.

### 4.3 Base-satisfied rule

A relationship is `BASE-SATISFIED` only when all of these are true:

- an exact R9 package record exists;
- its status is `install ok installed`;
- its architecture or `Multi-Arch` semantics satisfy the relationship;
- its exact version satisfies the Debian version constraint;
- a virtual relationship is satisfied by an exact recorded `Provides` entry,
  including a sufficient provided version when the relationship is versioned;
- no selected package conflicts with, breaks, replaces, or requires changing
  that base identity;
- required files are not scheduled to be overwritten by a different package.

Package-name coincidence is insufficient. `Essential: yes` is not permission
to assume an unobserved package exists. A package installed in an unexpected
status is not base-satisfied.

### 4.4 Alternatives and virtual packages

The resolver may accept an alternative group only when one eligible choice is
uniquely selected by these rules:

1. an exact base-satisfied concrete package is preferred if it causes no
   protected drift;
2. otherwise an explicitly Product Lead-approved concrete package may be used;
3. a virtual provider may be used only when exactly one approved provider and
   provider version satisfy the relation;
4. package-index order, mirror order, resolver preference, or lexical order may
   not resolve ambiguity.

Two eligible unapproved alternatives, multiple virtual providers, an
unversioned provider for a versioned dependency, or a provider that changes a
protected identity is HOLD.

### 4.5 Package actions and ordering

The resolved graph must emit a complete action plan containing only:

- `KEEP-BASE` for exact base-satisfied packages;
- `INSTALL-FINAL` for approved final-runtime packages;
- `INSTALL-BUILD-ONLY` for approved builder-only packages.

Any `REMOVE`, `PURGE`, `UPGRADE`, `DOWNGRADE`, `REPLACE`, `DIVERT`, or implicit
architecture addition is rejected. The plan must encode pre-unpack,
unpack, configure, trigger, and verification phases consistently with
`Pre-Depends`, `Depends`, and package cycles.

### 4.6 Maintainer scripts, triggers, conffiles, and services

Artifact inspection must enumerate and hash every Debian package control
member, including `preinst`, `postinst`, `prerm`, `postrm`, triggers, conffiles,
and configuration templates. Missing expected control metadata is HOLD.

BUILD may run maintainer scripts only under its separate authorization and only
with:

- no network;
- noninteractive configuration;
- a fail-closed policy denying service starts;
- no host mounts, secrets, database, or Docker socket;
- exact command, environment, order, exit-code, stdout, and redacted stderr
  evidence;
- a clean ephemeral builder state;
- explicit post-build verification of triggers and package status.

An interactive prompt, service-start attempt that is not denied, unexpected
daemon creation, undeclared file write outside declared package paths, conffile
conflict, diversion, or trigger failure rejects the build. Conffile selection
must be predetermined; no prompt default may make the decision.

## 5. Protected base contract

The protected package set includes at minimum:

- `libpq5`;
- `postgresql-15`;
- `postgresql-client-15`;
- `postgresql-client-common`;
- `postgresql-common`;
- `libc6`;
- installed OpenSSL runtime packages identified by R9;
- every base package that owns a protected file or satisfies a selected Python
  dependency.

Protected files include at minimum:

- `/usr/lib/x86_64-linux-gnu/libpq.so.5`;
- `/usr/lib/x86_64-linux-gnu/libpq.so.5.18`;
- `/usr/bin/psql`;
- `/usr/bin/pg_dump`;
- `/usr/bin/pg_restore`;
- `/usr/lib/postgresql/15/bin/psql`;
- `/usr/lib/postgresql/15/bin/pg_dump`;
- `/usr/lib/postgresql/15/bin/pg_restore`;
- `/usr/lib/postgresql/15/bin/postgres`;
- every R9-owned library reached by the approved libpq and CLI dependency
  closure.

Before Python provisioning, BUILD must reproduce package versions,
architectures, statuses, ownership metadata, file sizes, and file hashes for
the protected set. It must reproduce them again after final assembly.

The build fails if:

- a protected package identity differs;
- an added package declares `Breaks`, `Conflicts`, or `Replaces` against a
  protected package;
- an added package owns or overwrites a protected path;
- the loader search path or environment shadows the accepted libpq;
- another `libpq.so`, `libpq.so.5`, Psycopg native module, or bundled client
  library appears;
- a PostgreSQL CLI file or its owning package changes.

## 6. Python runtime package classification model

No exact Debian Python package list is approved by this document. ACQUIRE-PRE
must classify every candidate into exactly one role.

| Package role | Current classification | Decision rule |
|---|---|---|
| CPython 3.11 interpreter/minimal interpreter | UNRESOLVED | FINAL-RUNTIME only after exact snapshot package and closure approval |
| CPython 3.11 standard library | UNRESOLVED | FINAL-RUNTIME when required by direct or transitive imports |
| CPython shared runtime library | UNRESOLVED | FINAL-RUNTIME only when exact interpreter package metadata requires it |
| Native Python runtime dependency | UNRESOLVED | BASE-SATISFIED when exact R9 identity satisfies it; otherwise FINAL-RUNTIME |
| `python3.11-venv` and ensurepip payload | UNRESOLVED | BUILD-ONLY when required to provide the approved installer; otherwise REJECTED |
| pip | UNRESOLVED | BUILD-ONLY at an exact Debian package identity; REJECTED in final runtime |
| setuptools | UNRESOLVED | BUILD-ONLY only if exact installer metadata requires it; otherwise REJECTED |
| wheel tooling | UNRESOLVED | BUILD-ONLY only if exact installer metadata requires it; otherwise REJECTED |
| compiler and Python development headers | REJECTED | Source builds and native Psycopg builds are forbidden |
| sdist build backend dependencies | REJECTED | All Python application artifacts must be approved wheels |
| ca-certificates and OpenSSL | BASE-SATISFIED or UNRESOLVED | Reuse exact R9 identities; no upgrade is implicit |

The minimum final package set is the transitive `Pre-Depends` and `Depends`
closure of the approved CPython runtime seeds after exact base satisfaction.
It excludes recommended and build-only packages unless explicitly promoted by
a reviewed runtime need.

The final image must prove all required direct standard-library imports and
Psycopg transitive imports. An import failure does not authorize adding a
package during inspection or execution; it returns HOLD to closure design.

## 7. Build-only and final-runtime separation

### 7.1 P1 - build-stage pip and allowlisted runtime copy - selected

The selected future build has bounded stages:

1. `python-runtime-base`: starts from the accepted PostgreSQL base and installs
   only the approved `FINAL-RUNTIME` Debian package set from local, verified
   `.deb` files with networking disabled.
2. `wheel-builder`: starts from `python-runtime-base`, adds only approved
   `BUILD-ONLY` Debian packages, and uses the approved pip identity against the
   local wheel directory.
3. `final-client`: starts from the independently reproduced
   `python-runtime-base` identity and receives only the manifest-approved
   installed wheel tree and application runtime configuration.

The final stage must not copy a builder virtual environment wholesale. It must
copy only paths listed by the approved installed-wheel inventory. No wheel
directory, pip cache, package-index configuration, installer executable,
activation script, build report, compiler output, or temporary file crosses
the stage boundary.

The inherited Debian package tools in the accepted base are not newly
authorized runtime installation paths. At execution the container is non-root,
the root filesystem is read-only, no package artifacts or indexes are mounted,
and the network is internal-only with no egress. Any executable-gate path that
invokes apt, dpkg, pip, ensurepip, or another installer is a gate failure.

### 7.2 P2 - final-stage pip followed by removal - rejected

P2 is rejected because removing an installer after use is difficult to prove
complete. Modules, entry points, caches, configuration, `dist-info`, bytecode,
and transitive installer dependencies may remain. It also mixes runtime and
build mutation in the final stage.

### 7.3 P3 - custom direct wheel installer - rejected

P3 is rejected because it would create a new trusted installer that must
implement wheel layout, `.data` relocation, scripts, shebang handling,
permissions, metadata, and `RECORD` semantics. The additional custom code and
validation surface is not justified for pure wheels already supported by a
hash-pinned pip build stage.

### 7.4 P4 - pip retained in final image - rejected

P4 is rejected because it violates the no-runtime-installer contract, expands
the mutation and supply-chain surface, and creates a false path for runtime
network or local-package fallback.

## 8. Authoritative wheel closure and marker resolution

### 8.1 Fixed marker environment

Every PEP 508 marker is evaluated against one recorded target environment:

- `python_version`: `3.11`;
- `python_full_version`: exact CPython patch selected by ACQUIRE-PRE;
- `implementation_name`: `cpython`;
- `platform_python_implementation`: `CPython`;
- `os_name`: `posix`;
- `sys_platform`: `linux`;
- `platform_system`: `Linux`;
- `platform_machine`: `x86_64`;
- requested extras: empty;
- dependency groups: empty;
- all other marker variables: exact approved values or HOLD.

An unknown variable, unavailable exact value, invalid marker, implementation-
dependent fallback, or conflicting evaluation is HOLD. Marker evaluation may
not execute wheel code.

### 8.2 Recursive process

For the exact Psycopg wheel and every newly selected dependency wheel, the
future process must:

1. bind official project/version metadata to an exact response identity;
2. select one exact non-yanked wheel candidate under Product Lead approval;
3. reject every sdist and VCS or local-directory requirement;
4. validate filename normalization, version, `Requires-Python`, and all wheel
   compatibility tags;
5. require a pure-wheel contract and reject native extension members;
6. acquire only the separately approved body;
7. verify exact body size and SHA-256 before opening it;
8. inspect `METADATA`, `WHEEL`, and `RECORD` without executing code;
9. record every `Requires-Dist` exactly as stored in `METADATA`;
10. evaluate every marker against the fixed environment;
11. add every active dependency edge to the proposed closure;
12. repeat until no unresolved active edge remains;
13. compare body metadata with earlier index/sidecar metadata and fail on any
    mismatch;
14. require a Product Lead-approved exact artifact for every node.

Wheel-body `METADATA` is authoritative for dependency declarations only after
body hash verification. PyPI JSON, Simple API metadata, and separately served
core metadata are pre-acquisition evidence, not substitutes for body
inspection.

### 8.3 `typing-extensions>=4.6` selection

The version range must not be passed to a future BUILD resolver and must not
silently mean latest. ACQUIRE-PRE must enumerate every stable, non-yanked,
pure-wheel candidate visible in its captured official metadata boundary that:

- satisfies `>=4.6` and every other active constraint;
- supports the exact CPython 3.11 target;
- has an acceptable `Requires-Python` value;
- has exact official filename, size, tags, URL, and SHA-256 metadata;
- introduces no unresolved or forbidden active dependency.

ACQUIRE-PRE must present that finite candidate set and one reasoned candidate,
but the Product Lead must approve one exact version and filename in the later
acquisition allowlist. No resolver preference, upload recency, or lexical sort
is approval. After body acquisition, wheel `METADATA` and `RECORD` must confirm
the selection before it can enter BUILD.

### 8.4 Wheel rejection rules

Reject:

- `.tar.gz`, `.zip`, or any source distribution;
- editable, VCS, URL-unpinned, or local-directory dependencies;
- `psycopg-c`, `psycopg-binary`, `[c]`, or `[binary]`;
- a wheel with `.so`, `.pyd`, `.dylib`, executable native payload, or an ELF,
  PE, or Mach-O member unless a future Product Lead decision explicitly
  changes the pure-wheel contract;
- incompatible Python, ABI, or platform tags;
- missing, duplicate, malformed, or unhashable `METADATA`, `WHEEL`, or
  `RECORD`;
- a `RECORD` mismatch, unlisted member, unsafe path, duplicate normalized path,
  symlink, device entry, or archive escape;
- an unknown extra or marker context;
- a dependency not already represented by exact approved metadata.

## 9. Wheel installation contract

The future BUILD may use pip only in `wheel-builder`, at the exact Debian
package identity approved as `BUILD-ONLY`.

Required semantic options are:

- no index;
- one exact local wheel directory `/opt/noxund/build-input/wheelhouse`;
- hash checking required for every requirement;
- binary distributions only;
- dependency resolution disabled because the complete closure is already
  explicit;
- no source build or build isolation;
- no implicit upgrade or installed-package reuse;
- no bytecode compilation;
- deterministic target `/opt/noxund/stage/site-packages`;
- an installation report written only to build evidence.

The approved lock is a requirements-format file with exactly one normalized
`name==version` record and one SHA-256 for the single approved wheel file per
distribution. Direct network URLs, alternate hashes, ranges, extras, editable
entries, includes outside the approved input tree, and environment-derived
options are forbidden.

The wheel directory must contain exactly the manifest-listed wheels. Extra
files, missing files, duplicate normalized project names, or filename/hash
mismatches fail before pip is invoked.

Installation output rules are:

- UTF-8 path names must be safe, normalized relative paths;
- no absolute path, `..`, duplicate destination, symlink, device, or special
  file;
- directories use approved non-writable runtime modes;
- ordinary modules and metadata use approved non-executable modes;
- executable bits are retained only for an explicitly approved script;
- owner/group are the fixed final root-owned identities selected by BUILD;
- setuid, setgid, and world-writable bits are forbidden;
- `.pyc` files are excluded and `PYTHONDONTWRITEBYTECODE=1` is enforced at
  runtime;
- all copied file timestamps are normalized to one manifest-recorded
  `SOURCE_DATE_EPOCH`, selected before BUILD;
- no installer-generated script is accepted unless named in the manifest;
- original wheel `RECORD` hashes are verified before installation;
- installed `RECORD` paths, sizes, and hashes are reconciled with the staged
  tree, with permitted installer metadata differences explicitly recorded;
- the final-stage copy is driven by a path allowlist derived from that
  reconciled inventory.

Final image inspection must prove that pip, setuptools, wheel, ensurepip
payloads, wheel bodies, pip cache, installer configuration, and builder reports
are absent from the final runtime. It must also prove that only the approved
site-packages path is added to `sys.path` and that user-site and ambient
`PYTHONPATH` are disabled.

## 10. Artifact manifest

The future closure uses one file named `dependency-manifest.json`. This design
defines its schema but does not create an instance with unresolved values.

Top-level fields:

- `schema_version`;
- `unit`;
- `target`;
- `base_image`;
- `snapshot_sources`;
- `marker_environment`;
- `protected_packages`;
- `protected_files`;
- `artifacts`;
- `dependency_edges`;
- `build_only_copy_exclusions`;
- `source_date_epoch`;
- `closure_disposition`.

Every artifact record contains:

- `ecosystem`: `debian`, `python-wheel`, or `base`;
- `logical_package`;
- `exact_version`;
- `filename`;
- `architecture` or `python_tags`, `abi_tags`, and `platform_tags`;
- `byte_size`;
- `sha256`;
- `immutable_source_identity`;
- `repository_or_index_metadata_identity`;
- `package_stanza_or_core_metadata_identity`;
- `dependency_edge_ids`;
- `role`: `BASE-SATISFIED`, `FINAL-RUNTIME`, or `BUILD-ONLY`;
- `acquisition_state`;
- `inspection_state`;
- `build_state`;
- `local_path` only after authorized acquisition;
- `disposition` and reason.

Every dependency-edge record contains:

- source artifact ID;
- relationship type;
- raw declaration;
- parsed name, version constraint, architecture qualifier, marker, and extra;
- target artifact ID;
- satisfaction mode;
- evaluator version and disposition.

Canonical serialization rules are:

- UTF-8 without BOM;
- ASCII structural characters and JSON escaping for non-ASCII data;
- LF line endings and one final LF;
- object keys ordered ordinally;
- artifacts sorted by ecosystem, normalized package name, exact version,
  architecture/tags, and filename;
- dependency edges sorted by source ID, relationship type, raw declaration,
  and target ID;
- set-valued arrays deduplicated and ordinally sorted;
- ordered evidence arrays retain sequence and declare that property;
- decimal integers only, no floating-point numbers;
- explicit strings instead of implicit null for unresolved state;
- no timestamp except a recorded evidence or acquisition field whose value is
  excluded from dependency selection.

The aggregate dependency-manifest SHA-256 is the lowercase SHA-256 of the exact
serialized bytes including the final LF. Any semantic change changes the
manifest identity.

## 11. Metadata chain of custody

### 11.1 Debian

The required chain is:

1. official TLS endpoint and exact response evidence;
2. exact snapshot archive and timestamp;
3. signed `InRelease`, or `Release` plus detached signature;
4. approved signing-key fingerprint and key-file SHA-256;
5. verified Release signature;
6. Release SHA-256 entry for the consumed package index;
7. compressed package-index body hash and decompressed canonical hash;
8. exact package stanza hash;
9. stanza filename, size, and SHA-256 for the `.deb`;
10. later acquired `.deb` byte size and SHA-256;
11. later inspected control metadata and data-member inventory;
12. build action and final installed-package/file inventory.

A trusted signed index identifies an artifact but does not prove that a later
local file matches it. Both metadata-chain verification and body hashing are
required.

### 11.2 PyPI and wheels

The required chain is:

1. official PyPI project/version or Simple API response identity;
2. response URL, TLS domain, status, content type, bytes, SHA-256, timestamp,
   and redirect chain;
3. normalized project and exact release identity;
4. wheel filename, tags, size, URL, yanked state, `Requires-Python`, upload
   time, and SHA-256;
5. separately served core-metadata identity when officially available;
6. later acquired wheel byte size and SHA-256;
7. wheel structural validation;
8. exact body `METADATA`, `WHEEL`, and `RECORD` identities;
9. evaluated dependency edges and approved lock entry;
10. builder installation report and staged-file inventory;
11. final image Python distribution and file inventory.

Index metadata and sidecar core metadata are selection evidence. Only the
verified wheel body proves the artifact contents used by BUILD.

### 11.3 Build and final image

The build chain binds:

- accepted base image identity;
- R9 base inventory digest;
- dependency-manifest identity;
- Debian and wheel acquisition manifests;
- inspected artifact inventory identities;
- Dockerfile and complete build-context identities;
- builder and build-platform identity;
- no-network build evidence;
- staged runtime-tree inventory;
- final local image ID/config digest;
- optional OCI archive SHA-256 when separately authorized;
- final image inspection evidence.

No repository digest is claimed for a local-only image unless publication or a
content-addressed registry artifact is separately authorized and observed.

## 12. Complete closure architecture comparison

Scores use `BEST`, `ACCEPTABLE`, `WEAK`, or `REJECT` for this threat model.

| Criterion | C1 snapshot + builder wheelhouse | C2 pip in final | C3 standalone CPython | C4 source-built CPython |
|---|---|---|---|---|
| Reproducibility | BEST | ACCEPTABLE | WEAK until producer fixed | WEAK due build variability |
| Immutable identity | BEST after manifests | ACCEPTABLE for inputs | WEAK, no accepted artifact | ACCEPTABLE only with large source closure |
| Offline suitability | BEST | ACCEPTABLE | ACCEPTABLE | WEAK |
| Least dependency | BEST | WEAK | WEAK | REJECT |
| Final runtime size | ACCEPTABLE | WEAK | ACCEPTABLE | VARIABLE |
| Final attack surface | BEST | REJECT, installer retained | WEAK, duplicate native lineage | WEAK, custom native build |
| Native-library collision | BEST, system libpq retained | ACCEPTABLE | WEAK | WEAK |
| Inspection quality | BEST, Debian + wheel ownership | ACCEPTABLE | WEAK, producer-specific | WEAK, custom provenance |
| Fail-closed behavior | BEST | WEAK | ACCEPTABLE | WEAK |
| Maintenance burden | ACCEPTABLE | ACCEPTABLE | WEAK | REJECT |
| System libpq 18.4 compatibility | BEST | ACCEPTABLE | UNRESOLVED | UNRESOLVED |
| PostgreSQL tools 15.18 compatibility | BEST | ACCEPTABLE | ACCEPTABLE | ACCEPTABLE |
| No-runtime-pip compliance | BEST | REJECT | ACCEPTABLE | ACCEPTABLE |
| Windows host to Linux build | BEST, artifacts stay Linux-native | ACCEPTABLE | ACCEPTABLE | WEAK |
| Future CI suitability | BEST | WEAK | ACCEPTABLE | WEAK |

C1 is selected because it preserves Debian ownership and the accepted native
library lineage while isolating installer tooling from the final image. C2 is
rejected because runtime pip is an unnecessary mutation path. C3 is rejected
because no accepted standalone provenance and native closure exist. C4 is
rejected because compiler and feature-detection inputs exceed the least-
dependency boundary.

## 13. Fail-closed resolver and build rules

The future workflow fails closed on any of the following:

- missing, malformed, unsigned, expired-without-approved-snapshot-policy, or
  unchained repository metadata;
- missing signing-key identity or signature failure;
- mutable repository or index state used as an acquisition identity;
- absent package stanza, filename, size, SHA-256, or dependency field;
- ambiguous Debian alternative or virtual provider;
- Debian version conflict or unsupported architecture;
- unresolved `Pre-Depends`, `Depends`, `Multi-Arch`, `Provides`, `Breaks`,
  `Conflicts`, or `Replaces` condition;
- base package treated as satisfying a relation without exact R9 proof;
- package removal, upgrade, downgrade, replacement, diversion, or foreign-
  architecture activation;
- protected-package or protected-file drift;
- second libpq or loader shadowing;
- interactive maintainer script, unauthorized service start, failed trigger,
  or unresolved conffile decision;
- missing or ambiguous PyPI metadata;
- invalid or unknown PEP 508 marker value;
- unexpected active `Requires-Dist`;
- unresolved `typing-extensions` exact version;
- sdist, native Psycopg wheel, incompatible wheel tag, unsafe wheel member, or
  unsupported Wheel-Version;
- artifact filename, size, or SHA-256 mismatch;
- wheel `METADATA`, `WHEEL`, or `RECORD` mismatch;
- network, index, cache, VCS, local-directory, source-build, or installer
  fallback;
- undeclared Debian package, wheel, build input, or final-runtime file;
- pip dependency resolution during BUILD;
- builder tool, wheel body, cache, package-index configuration, or installer
  residue in the final image;
- non-deterministic timestamp, owner, group, mode, path, bytecode, or script;
- final import, implementation, libpq, CLI, package, or image observation that
  differs from the approved manifest;
- any unknown result represented as success.

No failure authorizes automatic selection of a substitute artifact.

## 14. Future ACQUIRE-PRE boundary

The exact next unit is metadata-only. It may retrieve and retain only official
metadata bodies needed to propose a finite acquisition allowlist.

### 14.1 Debian metadata permitted

- snapshot timestamp listings;
- exact snapshot `InRelease`, `Release`, and signature metadata;
- official archive signing-key identity metadata;
- exact Bookworm package indexes for required components and architectures;
- package stanzas and dependency fields;
- snapshot and repository endpoint response evidence.

It must not retrieve a `.deb` body, source package, image layer, or source
archive.

### 14.2 Python metadata permitted

- official PyPI project/version JSON;
- official Simple API project metadata;
- officially served core metadata when available separately from the wheel;
- filename, version, tags, size, hash, yanked state, upload time, and
  `Requires-Python` metadata;
- exact response and redirect evidence.

It must not retrieve a wheel, sdist, source archive, VCS object, or package
body.

### 14.3 Sufficient metadata before body acquisition

ACQUIRE-PRE may recommend a body-acquisition allowlist only after it produces:

- Product Lead-selectable exact snapshot timestamps;
- a verified signed Debian metadata chain to every proposed package stanza;
- a unique recursive Debian solution against the R9 base;
- explicit base-satisfied, final-runtime, and build-only classifications;
- a zero-drift protected-package comparison;
- exact proposed `.deb` filenames, versions, architectures, sizes, and
  SHA-256 values;
- one fixed marker environment including the exact CPython patch candidate;
- exact Psycopg wheel metadata matching the binding filename, size, and hash;
- a finite, explicit set of eligible `typing-extensions` candidates and a
  reasoned exact recommendation;
- recursively proposed wheel dependencies from officially exposed metadata;
- exact wheel filenames, versions, tags, sizes, SHA-256 values, and source
  endpoints;
- a proposed canonical dependency manifest marked `UNACQUIRED` and
  `UNINSPECTED` for every body;
- a complete list of metadata limitations that wheel or `.deb` body inspection
  must resolve.

If official metadata cannot expose an active wheel dependency before body
acquisition, ACQUIRE-PRE must identify a staged acquisition sequence. It may
recommend acquiring only the already identified wheel first, followed by a
separate inspection and another metadata-only decision. It may not guess the
rest of the closure.

## 15. Future acquisition assertions

A later, separately authorized acquisition unit must:

- allowlist every exact endpoint and artifact before transfer;
- acquire only manifest-listed `.deb` and `.whl` bodies;
- reject redirects outside approved official domains;
- record command, timestamp, status, content type, byte count, SHA-256, and
  final local path;
- verify every body against the approved metadata identity;
- quarantine and reject a mismatched or unexpected body;
- retain no package-manager or pip cache as an acquisition source;
- perform no installation, build, container creation, or database access.

## 16. Future artifact-inspection assertions

A later inspection unit must inspect bodies without executing their contents.

For every `.deb`, it must prove:

- archive structure and control/data member integrity;
- package, version, architecture, dependencies, conflicts, replacements,
  `Provides`, `Essential`, and `Multi-Arch` match approved metadata;
- complete file inventory and hashes;
- maintainer-script, trigger, conffile, and service-unit inventory;
- no protected-file overwrite or second-libpq payload;
- exact dependency graph remains uniquely solvable.

For every wheel, it must prove:

- safe ZIP structure and exact member inventory;
- filename tags agree with `WHEEL` tags;
- `METADATA` project, version, `Requires-Python`, and every `Requires-Dist`;
- marker evaluation against the fixed environment;
- `RECORD` covers and hashes every required member;
- pure Python payload with no native module or bundled libpq;
- no unsafe script, path, symlink, duplicate, or special member;
- the recursive closure and approved lock remain complete.

Any body-metadata difference returns HOLD to metadata design. Inspection does
not silently expand acquisition scope.

## 17. Future BUILD assertions

The separately authorized BUILD must prove:

- exact accepted base image and `linux/amd64`;
- network disabled for every stage;
- no registry, Debian repository, PyPI, VCS, or undeclared cache access;
- all inputs match the approved manifest before use;
- Debian actions equal the approved keep/install plan;
- protected identities reproduce before and after provisioning;
- build-only tools exist only in `wheel-builder`;
- pip runs only with the approved offline, hash-locked, wheel-only,
  no-dependency semantics;
- staged wheel files and installed metadata reconcile exactly;
- final copy contains only allowlisted files;
- no build secret, Docker socket, host package path, or ambient installer
  configuration enters the build;
- final filesystem metadata obeys timestamp, owner, group, mode, and bytecode
  policy;
- resulting image ID/config digest and complete file/package inventories are
  recorded;
- no database, runner, harness, fixture, migration, or protocol test executes.

## 18. Future final-image inspection assertions

The separately authorized INSPECT unit must observe, not infer:

- final image ID/config digest and platform;
- Debian 12.15 identity;
- exact CPython 3.11 patch, ABI, prefix, and standard-library inventory;
- exact Debian final package inventory and zero protected drift;
- Psycopg exactly 3.2.9;
- `PSYCOPG_IMPL=python` and pure implementation selection;
- exact accepted libpq 18.4 package, real path, SONAME, and file hash;
- no second libpq or loader override;
- `psql`, `pg_dump`, and `pg_restore` exactly 15.18;
- exact installed wheel distributions and file inventories;
- successful validation of all wheel installed `RECORD` entries;
- required standard-library and Psycopg imports under controlled import paths;
- no `psycopg_c` or `psycopg_binary`;
- no pip, setuptools, wheel, ensurepip payload, pip cache, wheelhouse,
  package-index configuration, or installer entry point in the final stage;
- no undeclared final-runtime file;
- non-root runtime identity, read-only-root contract, no Docker socket, and no
  executable-gate egress path.

Image inspection does not close RBF-08. Exact libpq loading and PostgreSQL 15.18
interoperability remain for the separately authorized runtime-validation gate.

## 19. Findings

Existing findings remain:

- RBF-01 OPEN: the approved offline runtime does not yet exist.
- RBF-02 OPEN: exact wheel closure and acquired hashes are not yet complete.
- RBF-03 RESOLVED previously.
- RBF-04 OPEN: final client image does not yet exist.
- RBF-05 OPEN: subtree `.gitignore` remains ignored and requires an explicit
  future commit decision.
- RBF-06 OPEN: comments-only `runner/requirements.txt` remains an unsafe no-op
  sentinel and must be replaced or removed under a later authorized gate.
- RBF-07 DESIGN-DECIDED-ACCEPT-18.4-RUNTIME-VALIDATION-OPEN.
- RBF-08 OPEN: exact libpq runtime linkage and PostgreSQL 15 interoperability
  remain unproven.

New findings:

- RBF-09 OPEN - immutable Debian snapshot and exact CPython closure unresolved.
  Exact archive timestamps, signing identities, CPython patch/package revision,
  Debian package graph, and artifact identities require ACQUIRE-PRE metadata.
- RBF-10 OPEN - authoritative pure-wheel closure unresolved. The exact
  `typing-extensions` artifact and any further active dependency must be fixed
  from official metadata and then confirmed from acquired wheel `METADATA`.
- RBF-11 OPEN - build-only tooling exclusion and final-runtime residue
  unproven. The design isolates installer tooling, but BUILD and INSPECT must
  prove that no installer, cache, configuration, or undeclared file reaches the
  final runtime.

This design closes no existing runtime or acquisition finding.

## 20. Official documentation consulted

Read-only official documentation consulted on 2026-08-02:

- Debian snapshot service and timestamped archive model:
  `https://snapshot.debian.org/`
- Debian Policy package relationships, alternatives, version constraints,
  virtual packages, and conflicts:
  `https://www.debian.org/doc/debian-policy/ch-relationships.html`
- Debian Policy maintainer scripts and installation ordering:
  `https://www.debian.org/doc/debian-policy/ch-maintainerscripts.html`
- Python dependency specifiers and PEP 508 marker semantics:
  `https://packaging.python.org/en/latest/specifications/dependency-specifiers/`
- Python wheel format, tags, `METADATA`, `WHEEL`, and `RECORD`:
  `https://packaging.python.org/en/latest/specifications/binary-distribution-format/`
- Python platform compatibility tags:
  `https://packaging.python.org/en/latest/specifications/platform-compatibility-tags/`
- Installed-project `RECORD` semantics:
  `https://packaging.python.org/en/latest/specifications/recording-installed-packages/`
- PyPI Simple Repository API metadata model:
  `https://packaging.python.org/en/latest/specifications/simple-repository-api/`
- pip secure installs and hash-checking mode:
  `https://pip.pypa.io/en/stable/topics/secure-installs/`
- pip install offline, target, tag, no-dependency, no-bytecode, hash, and
  binary-only options:
  `https://pip.pypa.io/en/stable/cli/pip_install/`
- Psycopg pure Python installation and system-libpq requirement:
  `https://www.psycopg.org/psycopg3/docs/basic/install.html`

No package, wheel, sdist, image, source archive, or other artifact body was
retrieved.

## 21. Exact next gate

Recommend exactly:

`PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-ACQUIRE-PRE-R1`

That gate must remain metadata-only and must satisfy Section 14. It must not
acquire `.deb`, wheel, sdist, image, or source bodies; access Docker or a
database; run Python, pip, apt, or dpkg; build an image; or begin integration.

## 22. Authorization boundary

This unit performed design and read-only documentation/source inspection only.
It did not modify any prior document or external evidence. It did not acquire
an artifact body, access Docker, create a container, install a package, execute
Python, pip, apt, dpkg, runner, harness, fixture, migration, or test, access a
database, stage or commit, fetch, push, publish, or begin a later gate.

BUILD remains unauthorized.
