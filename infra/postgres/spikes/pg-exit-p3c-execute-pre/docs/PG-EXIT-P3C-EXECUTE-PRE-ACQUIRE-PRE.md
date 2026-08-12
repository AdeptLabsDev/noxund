# PG-EXIT-P3C-EXECUTE-PRE acquisition preflight

**Authorized unit:** `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-ACQUIRE-PRE`  
**Decision:** **HOLD — local image state unresolved**  
**Architecture:** Candidate A remains binding  
**Inspection date:** 2026-08-01 UTC

This result is metadata-only. It is not an authorization to download an artifact
body, pull or build an image, create a container, install a package, connect to
PostgreSQL, or begin any later provisioning stage.

## 1. Source and preflight identity

| Field | Observed value |
|---|---|
| Worktree | `C:/Adeptlabs/noxund-p3c-execute-pre` |
| Repository top-level | `C:/Adeptlabs/noxund-p3c-execute-pre` |
| Branch | `spike/pg-exit-p3c-execute-pre` |
| HEAD | `4873ac713397cf47642d39b1ef17e48a9301511d` |
| Required HEAD match | Yes |
| Tracked working-tree differences | None |
| Staged differences | None |
| Physical files in authorized subtree before this result | 48 |
| Git-visible untracked files in subtree before this result | 47 |
| Ignored files in subtree | One: `infra/postgres/spikes/pg-exit-p3c-execute-pre/.gitignore` |
| Authorized output existed before creation | No |
| Unexpected path outside subtree | None beyond the accepted `.rar` exception |

The only untracked path outside the authorized subtree was the accepted
path-level exception:

`C:/Adeptlabs/noxund-p3c-execute-pre/infra/postgres/spikes/pg-exit-p3c-execute-pre.rar`

Its presence was confirmed. Its contents and file bytes were not opened, hashed,
modified, moved, included, or treated as provisioning input.

The canonical content identity of the 48 pre-existing subtree files was computed
in memory from path-sorted UTF-8 lines of relative path, byte size, and lowercase
SHA-256. The canonical input was 7,172 bytes and its SHA-256 was:

`8a7df40bb6cb948835d29a79d879d7d07a0b8c182511a2adb41328ea31288f70`

The main worktree remained on `main` at the same HEAD. Its preservation result
was 16,642 bytes with SHA-256
`b0235e698de990146779ee46047635d4dc017e8e0b7d87779ed6ca0c4ba495db`.

## 2. Binding architecture

Candidate A remains selected:

- accepted PostgreSQL 15.18 Bookworm image as the client-image base;
- target platform `linux/amd64`;
- Debian 12 Bookworm;
- CPython 3.11 with `cp311` ABI;
- pure-Python `psycopg==3.2.9`;
- system libpq;
- one immutable runtime containing Python, libpq, `psql`, `pg_dump`, and
  `pg_restore`;
- no Docker socket, runtime package installation, published database port, or
  executable-gate egress.

No official metadata result proved Candidate A impossible, so Candidates B and
C are not reopened.

## 3. Local Docker and daemon state

| Check | Result |
|---|---|
| Docker client | 29.6.2, API 1.55, Windows/amd64, context `desktop-linux` |
| Docker Compose | v5.3.1 |
| Docker buildx | v0.35.0-desktop.2, commit `b554ce1decd8b509893b1e7c6227eabfb923d094` |
| Docker daemon | Unavailable; named pipe `dockerDesktopLinuxEngine` absent |
| Daemon OS/architecture | Unknown |
| Exact image inspection | Failed read-only with exit code 1 because daemon was unavailable |
| Exact image-filtered listing | Failed read-only with exit code 1 because daemon was unavailable |
| Local image ID/config digest | Unknown |
| Local RepoDigests | Unknown |
| Local tags/platform/created metadata | Unknown |

No attempt was made to start, restart, or configure Docker Desktop or the daemon.

**Base local-state classification:**
`BASE-LOCAL-UNKNOWN-DAEMON-UNAVAILABLE`.

This is Outcome C. Local presence or absence cannot be inferred from the empty
client response. It is HOLD and is not permission to pull the image.

## 4. PostgreSQL registry metadata

Accepted immutable reference:

`postgres:15.18-bookworm@sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51`

The official registry returned this digest as an OCI image index:

| Field | Value |
|---|---|
| Index media type | `application/vnd.oci.image.index.v1+json` |
| Schema version | 2 |
| Index byte size | 10,344 |
| Index response SHA-256 | `b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51` |
| `Docker-Content-Digest` | `sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51` |
| Platform descriptors | 16 |
| Matching `linux/amd64` descriptors | Exactly one |

### 4.1 Exact linux/amd64 child

| Field | Value |
|---|---|
| Child digest | `sha256:fafb7480959eeeb7f1e43b479e642ffef2aa0f067242a1954ab41f2d764e2786` |
| Descriptor/response size | 3,640 bytes |
| Media type | `application/vnd.oci.image.manifest.v1+json` |
| OS | `linux` |
| Architecture | `amd64` |
| Child `Docker-Content-Digest` | `sha256:fafb7480959eeeb7f1e43b479e642ffef2aa0f067242a1954ab41f2d764e2786` |
| Base annotation | `debian:bookworm-slim@sha256:63a496b5d3b99214b39f5ed70eb71a61e590a77979c79cbee4faf991f8c0783e` |
| Created annotation | `2026-07-14T01:36:19Z` |
| Source revision | `4f9ced003ba58a854656ba150d146243d27ae3ac` |
| Version annotation | `15.18-bookworm` |

The official metadata still binds the accepted index to exactly one
`linux/amd64` platform manifest. No registry identity mismatch was found.

### 4.2 Config descriptor

The config blob was not downloaded. Only its descriptor in the child manifest
was observed:

| Media type | Digest | Declared size |
|---|---|---:|
| `application/vnd.oci.image.config.v1+json` | `sha256:14cd37850629c85ffa07818ca9a02568289a360aded79d54aee9401cb684667f` | 10,138 |

### 4.3 Layer descriptors

No layer was downloaded. The manifest declared 14 layers totaling 152,983,060
compressed bytes:

| # | Media type | Digest | Declared size |
|---:|---|---|---:|
| 1 | `application/vnd.oci.image.layer.v1.tar+gzip` | `sha256:597c6c618d36213af657a6a8444a5d87801f9a219682b206ad21ccb8f3e57bbd` | 28,232,643 |
| 2 | `application/vnd.oci.image.layer.v1.tar+gzip` | `sha256:cb16e7f6fed3dd1778a0f100c959940780a5ace2c0a4b1355111e85723e27dc5` | 1,167 |
| 3 | `application/vnd.oci.image.layer.v1.tar+gzip` | `sha256:e884dd10cff7696c07d4061ea7bc3dfa290d562ba0c070461a4efac25159281d` | 4,534,208 |
| 4 | `application/vnd.oci.image.layer.v1.tar+gzip` | `sha256:cd6c2306c2c04523f973e672227ed9505dea137f6f3a0a4b14c950adb49348bb` | 1,249,495 |
| 5 | `application/vnd.oci.image.layer.v1.tar+gzip` | `sha256:d650fb15677a27d4c09c657a613fb154392388dca6f73a00edbde7b989289cff` | 8,066,504 |
| 6 | `application/vnd.oci.image.layer.v1.tar+gzip` | `sha256:824a4a14323be77b8c6f686717ed4c335d961431d02de7bc591b433157e81811` | 1,196,438 |
| 7 | `application/vnd.oci.image.layer.v1.tar+gzip` | `sha256:c3bdb817fc34272f81c9590a47b961180b7afb1d0ae3c4797b1464821e20311a` | 116 |
| 8 | `application/vnd.oci.image.layer.v1.tar+gzip` | `sha256:c82ec0ad17f9cfbbe7d7f387210af888945012e425bad620f9936f19588258f1` | 3,140 |
| 9 | `application/vnd.oci.image.layer.v1.tar+gzip` | `sha256:6f9c19ad3e2c6ae603f305253195b394666ec7ad5993e4d07c9368edd0f1a68f` | 109,682,988 |
| 10 | `application/vnd.oci.image.layer.v1.tar+gzip` | `sha256:c833a0efd3c9f55ccd042dad1876fab5f1bd30ac912e10cab7cd2584e25a8df0` | 9,773 |
| 11 | `application/vnd.oci.image.layer.v1.tar+gzip` | `sha256:d1b70ddf3fbb473eba76fc9a3428fb2aff1629c3cfe93f426d0e846fa0c0c05d` | 128 |
| 12 | `application/vnd.oci.image.layer.v1.tar+gzip` | `sha256:e813a43dbb579ad5f1e35c38d3448e868609811b98db6dec0a84bd9e61682242` | 167 |
| 13 | `application/vnd.oci.image.layer.v1.tar+gzip` | `sha256:18cc48df0e79e2f85f45a8d4193f64907d94b1b93240f66fdbc1491604ea9797` | 6,108 |
| 14 | `application/vnd.oci.image.layer.v1.tar+gzip` | `sha256:aef53f7ba71d010a33ee4661feaad40396b56c33c90d9cfaead7c1a9af0429e1` | 185 |

## 5. Psycopg 3.2.9 metadata

Official PyPI metadata identifies exactly one pure-Python wheel:

| Field | Value |
|---|---|
| Distribution | `psycopg` |
| Normalized version | `3.2.9` |
| Filename | `psycopg-3.2.9-py3-none-any.whl` |
| Python tag | `py3` |
| ABI tag | `none` |
| Platform tag | `any` |
| Requires-Python | `>=3.8` |
| Byte size | 202,705 |
| SHA-256 | `01a8dadccdaac2123c916208c96e06631641c0566b22005493f09663c7a8d3b6` |
| Official URL | `https://files.pythonhosted.org/packages/44/b0/a73c195a56eb6b92e937a5ca58521a5c3346fb233345adc80fd3e2f542e2/psycopg-3.2.9-py3-none-any.whl` |
| Uploaded | `2025-05-13T16:06:26.584938Z` |
| Yanked | No |

The wheel was not downloaded.

The official PEP 658 METADATA sidecar was fetched independently as permitted
metadata:

| Field | Value |
|---|---|
| URL suffix | `psycopg-3.2.9-py3-none-any.whl.metadata` |
| Byte size | 4,538 |
| SHA-256 | `9b2a745b662478d264d842af579ba44ea5660a0f40324e52ca2f18bdaf9478e1` |
| PyPI-declared core-metadata SHA-256 match | Yes |
| Metadata-Version | 2.4 |

### 5.1 Conditional dependency evaluation

Target environment: CPython 3.11, Linux, `amd64`, no extras.

| Requirement | Evaluation | Disposition |
|---|---|---|
| `backports.zoneinfo>=0.2.0; python_version < "3.9"` | False for Python 3.11 | Excluded |
| `typing-extensions>=4.6; python_version < "3.13"` | True for Python 3.11 | Required but exact artifact unresolved |
| `tzdata; sys_platform == "win32"` | False for Linux | Excluded |
| `psycopg-c==3.2.9; extra == "c"` | No `c` extra | Excluded |
| `psycopg-binary==3.2.9; extra == "binary"` | No `binary` extra; architecture forbids it | Excluded |
| `psycopg-pool; extra == "pool"` | No `pool` extra | Excluded |
| Test/dev/docs extra dependencies | No matching extra | Excluded |

The Psycopg marker set is fully evaluable from official metadata. The exact
`typing-extensions` version, wheel filename, size, URL, and SHA-256 were not in
scope for this Psycopg-only query and remain unresolved. Consequently the future
wheel allowlist is HOLD and is not complete.

### 5.2 Source distribution

An sdist is present but rejected for Candidate A:

| Field | Value |
|---|---|
| Filename | `psycopg-3.2.9.tar.gz` |
| Byte size | 158,122 |
| SHA-256 | `2fbb46fcd17bc81f993f28c47f1ebea38d66ae97cc2dbc3cad73b37cefbff700` |
| Official URL | `https://files.pythonhosted.org/packages/27/4a/93a6ab570a8d1a4ad171a1f4256e205ce48d828781312c0bbaff36380ecb/psycopg-3.2.9.tar.gz` |

It was not downloaded and must not enter the future executable allowlist.

## 6. Debian Bookworm metadata

The official Bookworm metadata observed during this unit describes:

| Field | Value |
|---|---|
| Origin/label | Debian / Debian |
| Suite | `oldstable` |
| Version | `12.15` |
| Codename | `bookworm` |
| Date | `Sat, 11 Jul 2026 10:16:37 UTC` |
| Acquire-By-Hash | `yes` |
| Architectures | `all amd64 arm64 armel armhf i386 mips64el mipsel ppc64el s390x` |
| Components | `main contrib non-free-firmware non-free` |

The observed `main/binary-amd64/Packages.gz` metadata body was 12,084,798 bytes
with SHA-256
`6777ea16514725f9427f48c240d92e0a6b8496138e37a1491d8597e66774e309`.
Its size and hash exactly matched the entry signed into the observed InRelease.
It expanded in memory to 50,060,337 bytes. No `.deb` was requested.

### 6.1 Observed seed package records

These are informational candidates from a mutable repository view. They are not
a frozen closure and are not approved acquisition items.

| Package | Version | Arch | Filename | Size | SHA-256 | Direct dependency metadata |
|---|---|---|---|---:|---|---|
| `python3.11` | `3.11.2-6+deb12u8` | amd64 | `pool/main/p/python3.11/python3.11_3.11.2-6+deb12u8_amd64.deb` | 574,236 | `cd7b10c24281416a6acb22cd23ed7391c7dddd4a3d4d4a63d37faa786639b5de` | `python3.11-minimal (= 3.11.2-6+deb12u8), libpython3.11-stdlib (= 3.11.2-6+deb12u8), media-types | mime-support` |
| `python3.11-venv` | `3.11.2-6+deb12u8` | amd64 | `pool/main/p/python3.11/python3.11-venv_3.11.2-6+deb12u8_amd64.deb` | 5,888 | `1391d405ac12a1bbdd75d36a738ec410e5b01f9e065cc38974d9976a37b59c99` | `python3.11, python3-pip-whl, python3-setuptools-whl, python3.11-distutils` |
| `python3-pip` | `23.0.1+dfsg-1` | all | `pool/main/p/python-pip/python3-pip_23.0.1+dfsg-1_all.deb` | 1,324,972 | `d8024ededc6c7fe941ca96aabebdcf2d846fd130eae9d66aad1aa32a84454291` | `ca-certificates, python3-distutils, python3-setuptools, python3-wheel, python3:any` |
| `python3-setuptools` | `66.1.1-1+deb12u2` | all | `pool/main/s/setuptools/python3-setuptools_66.1.1-1+deb12u2_all.deb` | 521,580 | `96f934b8dbe4367c4cf9e4c740aa5c85f9a9ac8875a16556c8677fb342c7838f` | `python3-pkg-resources, python3-distutils, python3:any` |
| `python3-wheel` | `0.38.4-2` | all | `pool/main/w/wheel/python3-wheel_0.38.4-2_all.deb` | 30,808 | `623a8f7c70ba713b0d8d5a321f157405861f0a0b1a652edad2cda5f70f5773f9` | `python3-distutils, python3:any` |

The metadata family exposes exact version, architecture, filename, size,
SHA-256, Depends and Pre-Depends fields. Recursive closure calculation is
possible only after a fixed snapshot and exact base inventory are available.

### 6.2 Snapshot-selection rule

No floating endpoint or “latest” state may be an acquisition authority. A future
accepted snapshot must:

1. use an exact UTC timestamp under official `snapshot.debian.org`;
2. contain a Bookworm InRelease/Release and `main` indexes for `amd64` and `all`;
3. record and verify the InRelease/Release identity and every index size/hash;
4. use timestamped snapshot URLs and immutable by-hash/index identities;
5. be selected only after comparing its package set with the exact accepted
   base-image package database;
6. fail if the snapshot would introduce an undeclared upgrade, downgrade,
   conflict, or missing native dependency.

The observed 12.15 metadata is a candidate package-state family, not a selected
snapshot. The exact timestamp is unresolved pending local base state and
PVD-01.

## 7. PVD-01 analysis

**PVD-01 — OPEN and stage-ordering-blocking.**

Repository metadata cannot establish what is already installed in the accepted
base image. Final closure approval requires the base image's exact package
database, including package name, version, architecture, status, and relevant
native libraries.

Without that inventory, the preflight cannot determine:

- which Python/native packages are already present;
- which package bodies would actually be required;
- version conflicts or implicit upgrades/downgrades;
- the minimal final runtime closure;
- whether build-only packages can be excluded from the final image.

A later `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-BASE-INVENTORY` unit is required after
the exact base is locally verified. It may inspect the package database without
contacting PostgreSQL or running the harness. It cannot begin while local image
state remains unknown.

PVD-01 is not a rejection of Candidate A.

## 8. Contacted endpoint inventory

All requests were GET, used official primary-source TLS domains, had no
redirects, and retained response bodies only in process memory. The registry
bearer token was not printed or persisted.

| # | Exact URL | TLS domain | Status | Content type | Bytes | Response SHA-256 | UTC timestamp | Redirect chain |
|---:|---|---|---:|---|---:|---|---|---|
| 1 | `https://registry-1.docker.io/v2/library/postgres/manifests/sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51` | `registry-1.docker.io` | 401 | `application/json` | 159 | `2391f6e1875d9d43990c563021e165c281ec0d7684274502f9e26fb923cd256c` | `2026-08-01T22:25:06.604Z` | none |
| 2 | `https://auth.docker.io/token?service=registry.docker.io&scope=repository%3Alibrary%2Fpostgres%3Apull` | `auth.docker.io` | 200 | `application/json` | 5,414 | `a943d9a110a1817fc7ee691a9820d85fd618abb3edbf78d067cab0c100dd5817` | `2026-08-01T22:25:07.258Z` | none |
| 3 | `https://registry-1.docker.io/v2/library/postgres/manifests/sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51` | `registry-1.docker.io` | 200 | `application/vnd.oci.image.index.v1+json` | 10,344 | `b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51` | `2026-08-01T22:25:07.460Z` | none |
| 4 | `https://registry-1.docker.io/v2/library/postgres/manifests/sha256:fafb7480959eeeb7f1e43b479e642ffef2aa0f067242a1954ab41f2d764e2786` | `registry-1.docker.io` | 200 | `application/vnd.oci.image.manifest.v1+json` | 3,640 | `fafb7480959eeeb7f1e43b479e642ffef2aa0f067242a1954ab41f2d764e2786` | `2026-08-01T22:25:07.670Z` | none |
| 5 | `https://pypi.org/pypi/psycopg/3.2.9/json` | `pypi.org` | 200 | `application/json` | 6,094 | `a46e32a00431b531a9f0fa95cd2e325c0bd8c07823ef5c369cb475dec53dbdc7` | `2026-08-01T22:25:07.864Z` | none |
| 6 | `https://deb.debian.org/debian/dists/bookworm/InRelease` | `deb.debian.org` | 200 | not supplied | 151,075 | `77737fa4b34f2693e982cc9ee35736816c35a7778fc2d326cc1bbf5b301fe1aa` | `2026-08-01T22:25:08.421Z` | none |
| 7 | `https://deb.debian.org/debian/dists/bookworm/main/binary-amd64/Packages.gz` | `deb.debian.org` | 200 | `application/x-gzip` | 12,084,798 | `6777ea16514725f9427f48c240d92e0a6b8496138e37a1491d8597e66774e309` | `2026-08-01T22:25:08.570Z` | none |
| 8 | `https://files.pythonhosted.org/packages/44/b0/a73c195a56eb6b92e937a5ca58521a5c3346fb233345adc80fd3e2f542e2/psycopg-3.2.9-py3-none-any.whl.metadata` | `files.pythonhosted.org` | 200 | `binary/octet-stream` | 4,538 | `9b2a745b662478d264d842af579ba44ea5660a0f40324e52ca2f18bdaf9478e1` | `2026-08-01T22:25:58.992Z` | none |

The 401 registry challenge and ephemeral token response are included for a
complete contact record. The token value itself was discarded and is absent
from this document.

## 9. Draft acquisition allowlist

This section is evidence for a future decision, not an executable allowlist or
an acquisition authorization.

### 9.1 Resolved immutable items

| Item | Immutable identity | Size | Status |
|---|---|---:|---|
| PostgreSQL OCI index | `postgres:15.18-bookworm@sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51` | 10,344-byte manifest metadata; layers not acquired | Registry identity verified; local state unknown |
| PostgreSQL linux/amd64 manifest | `sha256:fafb7480959eeeb7f1e43b479e642ffef2aa0f067242a1954ab41f2d764e2786` | 3,640-byte manifest metadata | Platform binding verified |
| Psycopg pure wheel | `psycopg-3.2.9-py3-none-any.whl`, SHA-256 `01a8dadccdaac2123c916208c96e06631641c0566b22005493f09663c7a8d3b6` | 202,705 | Resolved candidate; not downloaded |
| Psycopg PEP 658 metadata | SHA-256 `9b2a745b662478d264d842af579ba44ea5660a0f40324e52ca2f18bdaf9478e1` | 4,538 | Metadata verified |

The sdist is immutably identified but explicitly rejected and is not an
allowlist item.

### 9.2 Unresolved items

- Whether the accepted PostgreSQL reference exists locally.
- Local image ID/config digest, RepoDigests, tags, platform, and local created
  metadata.
- Exact installed package database and native-library inventory of the base.
- Exact frozen Debian snapshot timestamp and immutable snapshot endpoints.
- Recursive Debian `amd64`/`all` closure and all required `.deb` artifacts.
- Classification of packages already present versus packages to add.
- Exact `typing-extensions>=4.6` version and wheel identity.
- Final hash-locked Python requirements closure.
- Runtime numeric UID/GID.
- Dockerfile, build-input inventory, derived image ID, and OCI archive identity,
  which do not yet exist.

No unresolved item is admitted into a future executable allowlist.

## 10. Finding status

| Finding | Status after this unit |
|---|---|
| RBF-01 — no offline runtime exists | OPEN |
| RBF-02 — dependency closure and hashes incomplete | OPEN; Psycopg is identified, but `typing-extensions` and Debian closure are unresolved |
| RBF-03 — invalid Compose command syntax | RESOLVED previously; unchanged |
| RBF-04 — client image absent / base local state unresolved | OPEN |
| RBF-05 — subtree `.gitignore` ignored | OPEN; unchanged |
| RBF-06 — comments-only requirements file permits no-op success | OPEN; unchanged |
| PVD-01 — closure depends on exact base package inventory | OPEN and stage-ordering-blocking |

No OPEN finding is claimed resolved.

## 11. Decision and next gate

**Unit decision: HOLD — local image state unresolved.**

Registry identity is verified, but the daemon was unavailable, so this unit
cannot distinguish local presence from absence and cannot choose between
`BASE-INVENTORY` and `ACQUIRE-BASE`.

The next exact recommended gate is:

`PG-EXIT-P3C-EXECUTE-PRE-PROVISION-ACQUIRE-PRE-R1`

That gate should be authorized only after an operator has made the Docker daemon
available outside this unit. It should repeat only read-only local inspection of
the exact accepted reference and then select:

- `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-BASE-INVENTORY` if locally verified; or
- `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-ACQUIRE-BASE` if locally absent.

It must return RED if local identity conflicts with the accepted registry or
`linux/amd64` binding. Dependency-body acquisition must not be recommended until
local base state is established.

## 12. Non-acquisition statement

No wheel, source distribution, `.deb`, OCI config blob, OCI layer, image, package,
container, database content, bootstrap artifact, harness output, fixture output,
or protocol trace was acquired or executed.

Only the explicitly permitted OCI manifest/index responses, registry auth
metadata, PyPI JSON, PEP 658 METADATA, Debian InRelease, and Debian Packages
metadata were read into process memory. No metadata response was retained outside
this authorized document.

No pull, build, create, run, save, load, package installation, database contact,
Compose resource operation, staging, commit, fetch, push, publication, or later
provisioning stage occurred.
