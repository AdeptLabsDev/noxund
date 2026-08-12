# PG-EXIT-P3C-EXECUTE-PRE provisioning architecture

**Unit:** PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DESIGN  
**Decision:** COMPLETE for design only; all acquisition and runtime findings remain
OPEN. This document is not an execution authorization.

## 1. Decision summary

Select **Candidate A — PostgreSQL image as base**.

The future client image will be built offline from the already accepted
PostgreSQL 15.18 Bookworm registry image identity. It will add an exact Debian
CPython 3.11 package closure and a hash-locked pure-Python Psycopg 3.2.9 wheel
closure. The pure-Python Psycopg distribution will use the image's system
libpq 15 rather than bundling a second libpq through `psycopg_binary`.

This choice keeps the runner, libpq, `psql`, `pg_dump` and `pg_restore` in one
immutable trusted runtime. It preserves the one-client-process P3C model,
simplifies D11 evidence correlation, avoids a Docker socket, and avoids adding
an inter-container orchestration protocol to the harness.

No artifact was acquired and no digest or hash was invented. Unknown acquired
values are marked `TO-BE-RESOLVED-BY-ACQUIRE`.

## 2. Binding constraints and current evidence

The following remain binding:

- TM-A and the accepted role/ledger design are unchanged.
- Executable-gate networking is internal-only with no egress and no published
  database port.
- No package installation, package-index access or image pull may occur during
  the executable gate.
- Both server and client images must already exist locally.
- Every Compose materialization must be fail-closed against pulls.
- No Docker socket may be available to the client.
- Source and secrets are read-only; evidence is the only read-write mount.
- No password may enter argv, logs, evidence, trace data or exception text.
- The project and PostgreSQL target must be validated before any connection.
- No local-only image may be described as having a repository digest unless it
  actually has one.

Read-only local design inventory on 2026-08-01:

- Host: Windows 11, AMD64; this is not the target container platform.
- Docker CLI: 29.6.2.
- Docker Compose: 5.3.1.
- Docker buildx: 0.35.0-desktop.2.
- Docker daemon: unavailable during design inspection.
- Exact PostgreSQL server image local availability: UNKNOWN,
  `TO-BE-RESOLVED-BY-ACQUIRE`.
- Repository wheelhouse/offline artifact cache: absent.
- Metadata-only network endpoints consulted: none.

The unexpected pre-existing `pg-exit-p3c-execute-pre.rar` worktree entry was
observed but not read, modified or included in this design.

## 3. Candidate comparison

| Property | A — PostgreSQL base | B — Python base | C — separated runtimes |
|---|---|---|---|
| Base trust | Reuses the accepted PostgreSQL 15.18 Bookworm digest | Requires approval of an additional Python base digest | Requires approval of at least two runtime identities |
| OS family | Debian 12 Bookworm from the accepted base | Must select an exact Python-image OS variant | Potentially two OS/package closures |
| Python | Offline Debian CPython 3.11 closure added | Already present, but exact image ABI still must be proven | Present only in runner image |
| libpq | Uses the base image's system libpq 15 | Must acquire exact PostgreSQL client/native packages | Split between runner binding and tools image unless duplicated |
| Client tools | `psql`, `pg_dump` and `pg_restore` originate with PostgreSQL 15.18 base and are inspected | Exact PostgreSQL 15.18 tools and native dependency closure must be added | Tools are isolated but require cross-runtime coordination |
| Psycopg model | Pure `psycopg==3.2.9` wheel uses system libpq | Pure wheel can use installed libpq; client packages still required | Runner image requires its own compatible libpq |
| D11 | One client runtime creates the dump, restores into a fresh target DB and records correlated evidence | Same behavior is possible after adding all tools | Without Docker socket, an external orchestrator must sequence images and shared evidence |
| Secrets | One read-only secret mount and one pgpass contract | Same | Secrets must be made consistently available to two images |
| Evidence | One process/runtime identity and one evidence mount | Same | Requires cross-image correlation, tool identity and handoff evidence |
| Trusted surface | One derived image; added Python/deb/wheel closure | One derived image; added PostgreSQL package closure and repository trust | Two images, two closures and an orchestration boundary |
| Offline complexity | Acquire exact Python Debian closure plus Python wheels | Acquire exact PostgreSQL 15 packages/native closure plus wheels | Acquire/build/inspect two images and define a safe handoff |
| Primary risk | Debian Python closure may be larger than expected | PostgreSQL 15.18 package sourcing may diverge from the server image | Architectural change can invalidate current harness assumptions |

### Selection rationale

Candidate A best preserves the P3C executable-test requirements:

1. The accepted PostgreSQL base already establishes the OS family and tool
   lineage.
2. `psql`, `pg_dump`, `pg_restore` and system libpq remain aligned with the
   PostgreSQL 15.18 family, subject to INSPECT proof.
3. Pure Psycopg avoids the hidden/bundled libpq introduced by
   `psycopg_binary`.
4. D11 can run from one client container against the primary disposable
   database and a separately created fresh target database without controlling
   Docker.
5. One client image, one evidence writer and one secret contract minimize the
   trusted surface compared with Candidate C.

Candidate B is rejected because obtaining exact PostgreSQL 15.18 client tools
and their native closure becomes the dominant reproducibility problem.
Candidate C is rejected because the no-Docker-socket rule would force an
external multi-container sequencing contract and corresponding harness changes.

## 4. Exact target platform and ABI contract

| Dimension | Contract |
|---|---|
| Target platform | `linux/amd64` only |
| OS family | Debian GNU/Linux 12 Bookworm, inherited from the accepted PostgreSQL base |
| Base registry identity | `postgres:15.18-bookworm@sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51` |
| Platform-manifest digest | `TO-BE-RESOLVED-BY-ACQUIRE` and proven to be the `linux/amd64` child of the accepted registry index |
| Python implementation | CPython 3.11 |
| Python ABI | `cp311` |
| Exact Python patch/package revisions | `TO-BE-RESOLVED-BY-ACQUIRE` |
| Python installation | Offline Debian packages into the image; application dependencies installed into `/opt/noxund/venv` during BUILD |
| Psycopg distribution | Pure-Python `psycopg==3.2.9`; do not select `psycopg_binary` |
| Psycopg wheel policy | Official PyPI wheel compatible with Python 3.11; expected pure-wheel class is `py3-none-any`, exact filename and hash `TO-BE-RESOLVED-BY-ACQUIRE` |
| libpq | System libpq major 15 inherited from the accepted base; exact runtime version must be 15.18 under INSPECT |
| PostgreSQL tools | `psql`, `pg_dump` and `pg_restore` must each report 15.18 under INSPECT |
| Server compatibility | Client libpq/tools major and exact tool version 15.18 against PostgreSQL server 15.18 |
| Locale/timezone | Preserve the accepted UTF-8/C.UTF-8 and UTC execution contract |
| Runtime user | Non-root numeric UID/GID selected and recorded during INTEGRATE; exact value `TO-BE-RESOLVED-BY-ACQUIRE` |

The BUILD definition must not select packages by floating repository state.
ACQUIRE must pin the Debian snapshot/release identity from which every `.deb`
originates.

## 5. Dependency-closure model

### 5.1 Debian package closure

The seed requirement is CPython 3.11 plus venv support. ACQUIRE must resolve the
complete recursive Debian Bookworm `linux/amd64` closure needed to create and
run `/opt/noxund/venv`. The closure includes the interpreter, standard library,
venv/bootstrap tooling and every native library not already proven present in
the accepted base.

Exact package names, versions, filenames and hashes are
`TO-BE-RESOLVED-BY-ACQUIRE`. The acquisition result must distinguish:

- packages already supplied byte-identically by the base;
- packages newly installed into the client image;
- transitive native libraries;
- packages used only during BUILD;
- packages retained in the final runtime.

The future BUILD must consume local `.deb` files only. A missing dependency or
attempt to reach a Debian repository is a hard failure.

### 5.2 Python wheel closure

The seed Python requirement is `psycopg==3.2.9` without the `binary` extra.
ACQUIRE must inspect official wheel METADATA for CPython 3.11 and resolve every
active conditional dependency, including `typing_extensions` if its marker
applies. Exact dependency versions, filenames and hashes are
`TO-BE-RESOLVED-BY-ACQUIRE`.

The lock must contain one exact entry per installed distribution and enough
hashes to accept only the acquired local files. BUILD must enforce equivalents
of:

- `--no-index`;
- `--require-hashes`;
- `--only-binary=:all:`;
- a wheelhouse path containing only declared artifacts.

Those options are requirements, not an authorization to run pip now. No pip
binary or installation path may be invoked during the executable gate.

### 5.3 Completeness proof

ACQUIRE must emit two path-sorted inventories:

1. Debian package closure: package, version, architecture, filename, size,
   SHA-256, source and dependency edges.
2. Python wheel closure: distribution, normalized version, wheel filename,
   Python/ABI/platform tags, size, SHA-256, source and evaluated dependency
   markers.

BUILD must prove that every installed package/wheel appears in those
inventories and that no undeclared network or filesystem source was used.
INSPECT must independently report the final installed package and Python
distribution inventories.

## 6. Immutable client-image identity model

### 6.1 Registry-provided base

The base is identified by the accepted registry reference:

`postgres:15.18-bookworm@sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51`

ACQUIRE must verify the registry index digest, its `linux/amd64` platform
manifest, the local image ID/config digest after acquisition and the exact
`RepoDigests` entry. A Compose reference alone is not evidence of availability.

### 6.2 Local-only derived image

No publication is assumed or authorized. The derived image therefore has no
repository digest unless a later authorization actually creates one.

The approved local-only identity tuple will be:

- fixed human reference: `noxund/pg-exit-p3c-client:p3c-provision-v1`;
- Dockerfile SHA-256;
- canonical build-input inventory SHA-256;
- accepted base registry digest;
- Debian closure inventory SHA-256;
- wheel closure inventory SHA-256;
- build command/flags record and builder identity;
- resulting local image ID/config digest,
  `NOT-YET-CREATED — RECORD-BY-BUILD`;
- exported OCI archive SHA-256,
  `NOT-YET-CREATED — RECORD-BY-BUILD`;
- inspection-evidence SHA-256,
  `NOT-YET-CREATED — RECORD-BY-INSPECT`.

The canonical build-input digest uses UTF-8, LF-terminated, ordinally
path-sorted lines containing relative path, byte size and lowercase SHA-256.

Future Compose integration will reference the fixed local tag with
`pull_policy: never`. Before any Compose command, preflight must resolve that tag
locally and compare its exact image ID/config digest with the independently
approved identity tuple. Missing tag, multiple unexpected tags, wrong platform,
wrong ID or any need to pull is HOLD. The tag is only a locator; the approved
image ID/config digest is the local identity.

## 7. PostgreSQL server-image acquisition contract

The server identity remains:

`postgres:15.18-bookworm@sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51`

Current local availability is UNKNOWN because the Docker daemon was unavailable
during design. ACQUIRE must:

1. Query local image metadata without pulling.
2. If the exact registry reference is absent, stop unless the ACQUIRE GO
   explicitly authorizes its pull.
3. If pulling is authorized, pull only the exact digest reference.
4. Verify registry index digest and the exact `linux/amd64` platform manifest.
5. Record local image ID/config digest, `RepoDigests`, OS, architecture, creation
   metadata, acquisition exit code and timestamp.
6. Fail if local metadata does not bind the accepted digest to `linux/amd64`.
7. Preserve `pull_policy: never` in Compose.
8. Require `--pull never` in any later resource-creating command.

The client build may use this same locally verified base only after ACQUIRE
acceptance. BUILD must not pull or resolve a different base.

## 8. Stage-separated authorization plan

Every stage requires a new Product Lead GO.

### 8.1 PG-EXIT-P3C-EXECUTE-PRE-PROVISION-ACQUIRE

May authorize only explicitly named official artifact downloads and exact image
pulls. It creates provenance and local artifact inventories.

Required boundaries:

- Network endpoints and artifact identities are allowlisted in the GO.
- Image pulls use exact registry digests.
- Debian and PyPI metadata/artifact sources are official primary sources.
- No image build, container creation/execution, database connection, bootstrap
  or harness execution.
- Output includes all artifact bytes, hashes, TLS domains, commands and exit
  codes.
- Any missing closure member, redirect to an unapproved mirror or hash mismatch
  is HOLD/RED as defined by that unit.

### 8.2 PG-EXIT-P3C-EXECUTE-PRE-PROVISION-BUILD

May authorize an offline build from the accepted ACQUIRE directory.

Required boundaries:

- Network disabled for every build step.
- No registry/package-index access and no undeclared host cache.
- Base image must already be local and match the accepted ID.
- Every `.deb` and wheel must match the acquired inventories.
- The build fails if any undeclared artifact is required.
- No database, bootstrap or harness execution.
- Output records Dockerfile/build-input hashes, builder identity, build logs
  after redaction, local image ID/config digest and OCI archive SHA-256.

### 8.3 PG-EXIT-P3C-EXECUTE-PRE-PROVISION-INSPECT

May authorize one disposable no-network client container solely for executable
image inspection. This stage explicitly creates and executes a container and
therefore cannot be folded into BUILD or implied by design approval.

It may inspect only:

- Python version and ABI;
- Psycopg version and implementation selection;
- loaded libpq version;
- `psql`, `pg_dump` and `pg_restore` versions;
- OS/platform and effective UID/GID;
- installed Debian and Python distribution inventories;
- absence of package-index configuration and Docker socket.

It must not create/contact PostgreSQL, run bootstrap, import/run the harness,
execute fixtures, migrations, tracing or fault injection. The container runs
with no network and no secrets.

### 8.4 PG-EXIT-P3C-EXECUTE-PRE-PROVISION-INTEGRATE

May authorize source-only changes to:

- Compose client service;
- real hash-locked dependency file;
- Debian/wheel provenance manifests;
- image-identity manifest;
- source/secret/evidence mounts;
- project/target/image preflight guards;
- secure pgpass/bootstrap secret plumbing.

It must not invoke Docker, Compose, the database or harness.

RBF-06 must be resolved here by either replacing
`runner/requirements.txt` with the actual reviewed hash lock or removing/
renaming it when an alternative approved mechanism is used. A comments-only
file must not remain at the executable path.

### 8.5 PG-EXIT-P3C-EXECUTE-PRE-PROVISION-REVIEW-BUNDLE

May create only an external immutable review bundle containing:

- acquisition provenance and hashes;
- Debian and wheel closure inventories;
- Dockerfile/build definition and canonical input digest;
- base/server/client image identities;
- OCI archive identity;
- inspection evidence;
- dependency lock and image-identity manifest;
- Compose/integration delta;
- secret-scan output and redaction report.

It must not commit, publish or execute the harness. Technical provisioning
acceptance remains HOLD until Product Lead / Co-Leader review that bundle.

## 9. Artifact provenance schema

Every acquired wheel, Debian package or image record must contain:

| Field | Requirement |
|---|---|
| `artifact_kind` | `wheel`, `deb`, `registry_index` or `platform_manifest` |
| `filename_or_reference` | Exact filename or immutable image reference |
| `name` | Distribution/package/repository name |
| `version` | Exact version/revision |
| `architecture` | Exact Debian architecture or OCI platform |
| `python_tag` / `abi_tag` / `platform_tag` | Required for wheels; explicit N/A otherwise |
| `upstream_project` | Official producer |
| `source_url` | Final official HTTPS URL or registry reference |
| `tls_domain` | Exact contacted TLS domain |
| `redirect_chain` | Every redirect; third-party substitution is forbidden |
| `byte_size` | Exact downloaded size |
| `sha256_or_digest` | File SHA-256 or registry digest |
| `acquired_at_utc` | UTC timestamp |
| `acquisition_command` | Redacted exact command |
| `command_exit_code` | Exact integer |
| `local_path_or_image_id` | Final local artifact path or local image identity |
| `dependency_edges` | Declared/resolved dependencies |
| `license_metadata` | Recorded for review |
| `disposition` | Accepted, rejected or quarantined |

Permitted future primary-source families must be explicitly allowlisted by
ACQUIRE. Expected families are the official Docker Registry/Docker Hub
`library/postgres` source, official Debian snapshot infrastructure and official
PyPI metadata/file infrastructure. Exact TLS endpoints and redirects are
`TO-BE-RESOLVED-BY-ACQUIRE`; third-party mirrors are not interchangeable.

## 10. Secret and mount architecture

Future client-container paths are fixed as follows:

| Purpose | Container path | Mode |
|---|---|---|
| Reviewed source subtree | `/workspace/pg-exit-p3c-execute-pre` | read-only |
| Secret directory | `/run/secrets/noxund` | read-only |
| PostgreSQL pgpass file | `/run/secrets/noxund/pgpass` | read-only, mode 0600 |
| Bootstrap role-password files | `/run/secrets/noxund/noxund_migrator_password` and `/run/secrets/noxund/noxund_app_password` | read-only |
| Admin password file | `/run/secrets/noxund/postgres_password` | read-only |
| Evidence output | `/evidence` | read-write |
| Offline build inputs | not mounted at executable runtime | N/A |
| Docker socket | absent | forbidden |

Additional requirements:

- No host network; only the internal Compose network.
- No published database port.
- `PGHOST` exactly `postgres`, `PGPORT` exactly `5432` and `PGDATABASE`
  exactly `noxund_p3c_spike`.
- `COMPOSE_PROJECT_NAME` and explicit `--project` value match
  `^noxund-p3c-[0-9]+$`.
- Password lookup uses the mounted pgpass/secret-file mechanism; passwords
  never appear in argv or URI/key-value DSNs.
- Subprocess evidence records redacted executable, non-secret arguments, exit
  code and redacted stderr/stdout.
- Exceptions are redacted before serialization, including URI DSNs, keyword
  conninfo and secret paths/content.
- Client receives no ambient PGHOST/PGPORT/PGDATABASE override.
- Before the first DB connection, image ID, project, host, port and database
  checks must pass. Server version and the disposable bootstrap marker are
  checked immediately after the trusted bootstrap connection and before any
  migration case.

D11 uses the same client runtime and tools. It writes a logical backup beneath
`/evidence/d11`, restores into a separately created fresh target database in
the disposable PostgreSQL service, validates the restored state and drops that
target only under the later authorized teardown contract. It needs no Docker
socket and no second tools image.

## 11. Failure behavior

All future stages are fail-closed:

- Missing/changed artifact, size, hash, dependency edge or provenance field:
  HOLD before the next stage.
- Unapproved endpoint, mirror substitution or redirect: RED/stop under the
  future acquisition authorization.
- Registry digest/platform mismatch: RED/stop.
- Required image absent without explicit pull authority: HOLD.
- Build network access, undeclared cache hit or undeclared package: RED/stop.
- Build needs an unavailable artifact: HOLD; do not fetch during BUILD.
- Local client tag resolves to an unapproved image ID: HOLD before Compose.
- INSPECT version/ABI/tool mismatch: REJECT/HOLD; do not integrate.
- Any secret in argv/log/evidence: RED.
- Compose syntax or mount/target guard mismatch: HOLD.
- Unknown observation must never be converted into executable acceptance.
- No stage cleans or overwrites evidence after a failure unless separately
  authorized.

## 12. Remaining unknown values

| Value | Resolution stage |
|---|---|
| Exact `linux/amd64` platform manifest digest for the accepted PostgreSQL index | `TO-BE-RESOLVED-BY-ACQUIRE` |
| Current local availability and local ID of the server image | `TO-BE-RESOLVED-BY-ACQUIRE` |
| Debian snapshot/release identity | `TO-BE-RESOLVED-BY-ACQUIRE` |
| Exact CPython 3.11 patch and Debian package revisions | `TO-BE-RESOLVED-BY-ACQUIRE` |
| Complete Debian `.deb` filenames, edges, sizes and hashes | `TO-BE-RESOLVED-BY-ACQUIRE` |
| Exact Psycopg wheel filename/hash | `TO-BE-RESOLVED-BY-ACQUIRE` |
| Active conditional Python dependencies and exact wheel hashes | `TO-BE-RESOLVED-BY-ACQUIRE` |
| Exact official TLS endpoints and redirect chains | `TO-BE-RESOLVED-BY-ACQUIRE` |
| Client Dockerfile/build-input digest | `NOT-YET-CREATED — RECORD-BY-BUILD` |
| Derived local image ID/config digest | `NOT-YET-CREATED — RECORD-BY-BUILD` |
| OCI archive SHA-256 | `NOT-YET-CREATED — RECORD-BY-BUILD` |
| Inspection evidence and its SHA-256 | `NOT-YET-CREATED — RECORD-BY-INSPECT` |
| Runtime numeric UID/GID | `TO-BE-RESOLVED-BY-ACQUIRE` |

Unknowns are not permission to acquire or infer values during design.

## 13. RBF disposition

- **RBF-01 OPEN:** no offline runtime exists.
- **RBF-02 OPEN:** dependency closure and hashes are absent.
- **RBF-03 RESOLVED previously:** invalid command was removed; this unit does
  not reopen or modify that result.
- **RBF-04 OPEN:** client image is absent; server local availability is unknown.
- **RBF-05 OPEN:** subtree `.gitignore` remains ignored.
- **RBF-06 OPEN:** comments-only `runner/requirements.txt` can produce a
  successful no-op and is not a fail-closed sentinel.

No OPEN finding is claimed resolved by this design.

## 14. Authorization boundary

This document authorizes nothing beyond architecture design.

It does not authorize downloads, artifact bodies, image pulls, builds,
containers, executable inspection, Docker/Compose resource operations, package
installation, wheelhouse creation, database access, bootstrap, harness
correction/execution, tests, fixtures, tracing, fault injection, staging,
commit, publication or modification of any other file.

The next permitted action requires a new explicit Product Lead GO for
`PG-EXIT-P3C-EXECUTE-PRE-PROVISION-ACQUIRE`. BUILD, INSPECT, INTEGRATE,
REVIEW-BUNDLE and harness correction each require their own later GO.
