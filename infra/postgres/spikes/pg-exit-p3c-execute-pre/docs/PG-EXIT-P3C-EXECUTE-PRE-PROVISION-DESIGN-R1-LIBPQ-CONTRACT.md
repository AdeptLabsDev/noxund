# PG-EXIT-P3C-EXECUTE-PRE - Provision Design R1 Libpq Contract

## 1. Decision

- Unit: `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DESIGN-R1-LIBPQ-CONTRACT`
- Design disposition: `LIBPQ-CONTRACT-ACCEPT-18.4`
- Selected contract: retain the accepted immutable PostgreSQL 15.18 Bookworm
  base and accept its exact system `libpq5=18.4-1.pgdg12+1` package for the
  pure Python `psycopg==3.2.9` runtime.
- Psycopg implementation: `python`, forced by `PSYCOPG_IMPL=python`.
- PostgreSQL CLI identity: `psql`, `pg_dump`, and `pg_restore` remain exactly
  version 15.18.
- Server identity: PostgreSQL server remains exactly 15.18.
- Runtime status: conditional and unproven. This design is not READY FOR BUILD
  or READY FOR EXECUTION.
- Next gate: `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-DESIGN-R1`.

This decision accepts an exact client-library contract. It does not infer
runtime linkage, protocol negotiation, or application behavior from package
metadata.

## 2. Binding R9 findings

The accepted R9 inventory establishes:

- PVD-01: `PVD-01-CLOSED-FOR-BASE-INVENTORY`.
- Accepted image ID: `sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51`.
- Platform: `linux/amd64`.
- OS: Debian 12.15 / Bookworm.
- `postgresql-15=15.18-1.pgdg12+1`.
- `postgresql-client-15=15.18-1.pgdg12+1`.
- `postgresql-client-common=291.pgdg12+1`.
- `postgresql-common=291.pgdg12+1`.
- `libpq5=18.4-1.pgdg12+1`.
- `libpq5:amd64.list` owns
  `/usr/lib/x86_64-linux-gnu/libpq.so.5` and
  `/usr/lib/x86_64-linux-gnu/libpq.so.5.18`.
- No libpq 15 runtime package was observed.
- No Python, pip, or venv package was observed.
- Dynamic linkage remains `RUNTIME-UNPROVEN`.
- The stopped inventory container and its anonymous volume were removed.
- BUILD remains unauthorized.

The accepted dependency inventory also shows that
`postgresql-client-15=15.18-1.pgdg12+1` declares `libpq5 (>= 15.18)`, not an
exact-major equality. The installed 18.4 package satisfies that package
relation. Package satisfaction is not proof that the CLI binaries load or
behave correctly with that library.

## 3. Contract drift versus runtime incompatibility

RBF-07 proved contract drift: the earlier design expected libpq 15/15.18, but
the immutable base contains libpq 18.4. It did not prove runtime
incompatibility.

The following claims remain distinct:

| Claim type | Current evidence | Disposition |
|---|---|---|
| Protocol compatibility | PostgreSQL protocol 3.0 is the backward-compatible default; server 15 supports protocol 3.0 | Supported by design; runtime negotiation must be observed |
| C ABI and SONAME | The package owns `libpq.so.5` and `libpq.so.5.18` | Exact SONAME identity known; loaded symbols and path remain unproven |
| Package identity | `libpq5=18.4-1.pgdg12+1` is installed | Proven by R9 package inventory |
| CLI identity | PostgreSQL CLI packages are 15.18 | Proven only at package-metadata level |
| Runtime linkage | Which library Psycopg and each CLI process loads | Unproven; RBF-08 |
| Application behavior | Extended query, transaction, cancellation, and error behavior against server 15.18 | Unproven; future runtime validation required |

No one row is accepted as proof of another.

## 4. Runner API-surface inventory

Static inspection covered `runner/pq_transport.py`, `runner/runner.py`,
`runner/session_state.py`, and the Python harness. No Python module was
imported or executed.

| Capability | Classification | Static evidence and boundary |
|---|---|---|
| Connection creation | REQUIRED | `pq.PGconn.connect()` creates one synchronous low-level connection |
| Extended-query execution | REQUIRED | Every runner statement uses `PGconn.exec_params()`, including zero-parameter artifact submission |
| Explicit transaction control | REQUIRED | `BEGIN`, `COMMIT`, and `ROLLBACK` are sent through `exec_params()` |
| SQLSTATE retrieval | REQUIRED | `PGresult.error_field(pq.DiagnosticField.SQLSTATE)` |
| Libpq result status | REQUIRED | `PGresult.status` and `pq.ExecStatus` |
| Command tag | REQUIRED | `PGresult.command_status` |
| Backend PID | REQUIRED | `PGconn.backend_pid`, cross-checked with `pg_backend_pid()` |
| Transaction status | REQUIRED | `PGconn.transaction_status` and `pq.TransactionStatus.INTRANS` |
| Parameter binding | REQUIRED | Text parameters and Python `None` -> SQL NULL are passed to `exec_params()` |
| Text result handling | REQUIRED | `ntuples`, `nfields`, and `get_value()` are decoded as UTF-8 text |
| Binary parameters/results | NOT USED | No binary format request or binary result decoder is present |
| Protocol trace | REQUIRED FOR DECLARED A08/A09 EVIDENCE | `trace()`, `set_trace_flags()`, and `untrace()` |
| Error handling | REQUIRED | Connection and result errors are captured; SQLSTATE is retained |
| Notice handling | NOT USED | No notice processor or notice callback is referenced |
| Cancellation API | NOT USED | No `cancel`, `get_cancel`, or `cancel_conn` call is present; process-death hooks use `os._exit(137)` instead |
| COPY API | NOT USED BY RUNNER | No Psycopg/libpq COPY call is present; D11 separately invokes CLI `pg_dump` |
| Pipeline mode | NOT USED | No pipeline API is referenced |
| Large-object API | NOT USED | No `lo_*`, `PQfn`, or Psycopg large-object API is referenced |
| High-level cursor path | CONTROL ONLY | A09 uses `psycopg.connect()`, `cursor()`, and parameterless `execute()` as a simple-query control |

The current surface uses long-established libpq functions and protocol 3.0
messages. Static inspection found no runner call that depends on a
PostgreSQL-15-only libpq behavior and no PostgreSQL-18-only application
feature. Cancellation remains a required future interoperability control even
though the current runner does not call it.

## 5. Candidate comparison

Scores use 1 = weakest and 5 = strongest for this threat model. A score is a
design comparison, not executable acceptance.

| Criterion | L18 | L15 | PB | CR split runtime |
|---|---:|---:|---:|---:|
| 1. Deterministic reproducibility | 5 | 3 | 4 | 2 |
| 2. Immutable identity | 5 | 4 | 4 | 3 |
| 3. Offline-build suitability | 5 | 3 | 4 | 2 |
| 4. Package and supply-chain surface | 5 | 2 | 2 | 1 |
| 5. Security-patch posture | 5 | 4 | 4 | 3 |
| 6. Compatibility with server 15.18 | 4 | 5 | 4 | 4 |
| 7. Compatibility with pure Psycopg 3.2.9 | 5 | 5 | 2 | 4 |
| 8. Compatibility with CLI tools 15.18 | 4 | 5 | 3 | 3 |
| 9. Runtime observability | 5 | 4 | 3 | 3 |
| 10. Ability to fail closed | 5 | 4 | 4 | 3 |
| 11. Loader/shared-library collision risk | 4 | 2 | 2 | 1 |
| 12. Operational complexity | 5 | 2 | 3 | 1 |
| 13. Future maintenance burden | 4 | 2 | 3 | 1 |
| 14. Fit with accepted threat model | 5 | 3 | 3 | 2 |
| 15. Fit with no-runtime-pip contract | 5 | 5 | 5 | 5 |
| Total | 71 | 53 | 50 | 35 |

### 5.1 Candidate L18 - accept exact system libpq 18.4

L18 reuses an already inventoried package and library from the accepted base.
It introduces no additional libpq artifact, loader path, package downgrade, or
second OpenSSL/libpq trust boundary. Psycopg 3.2.8 added support for PostgreSQL
18 libpq, so the selected 3.2.9 includes that support. Pure Python Psycopg uses
the system client library via `ctypes` and can be forced fail-closed with
`PSYCOPG_IMPL=python`.

L18 is selected because its remaining uncertainty can be bounded by exact
image inspection and runtime assertions. It does not permit PostgreSQL 18-only
protocol features or application behavior.

### 5.2 Candidate L15 - acquire and pin libpq 15.18

L15 would require an exact official PGDG Bookworm `linux/amd64` libpq 15.18
artifact or a separately approved source-built artifact, plus its complete
native dependency closure and hashes. No such artifact is acquired or approved
in this unit.

Replacing libpq5 18.4 risks a package downgrade and conflict with the immutable
base. Coexistence would require a private loader directory and process-specific
loader controls. Either form adds acquisition, collision, and maintenance
surface. The accepted package metadata does not require the CLI tool major to
equal the libpq major; it requires `libpq5 >= 15.18`. Therefore L15 has no
package-level necessity established by current evidence.

L15 and L18 were released in the same PostgreSQL security update family. L15
is not rejected as insecure, but pinning the older major creates an additional
future patch and provenance stream without a demonstrated application need.

### 5.3 Candidate PB - Psycopg binary distribution

PB would bundle the libpq and related native libraries selected by the binary
wheel while the PostgreSQL CLI tools continue using the system library. This
duplicates libpq and potentially OpenSSL in one client image, separates
Psycopg's client identity from the CLI identity, and increases verification
surface. The exact binary wheel, bundled libpq, wheel availability, and hashes
are not acquired here.

PB also contradicts the accepted pure-Python/system-libpq boundary and the
least-dependency rationale. It is not selected.

### 5.4 Candidate CR - bounded split runtime

The bounded CR considered here is a single image with a privately installed
libpq 15.18 used only by the Python process and the base system libpq 18.4 used
only by the PostgreSQL 15.18 CLI tools. Its proposed boundary would require:

- CPython 3.11 and pure `psycopg==3.2.9` under a Python-only loader wrapper;
- private exact libpq 15.18 artifacts under `/opt/noxund/libpq15`;
- sanitized CLI environments that cannot inherit the private loader path;
- separate hashes and runtime-link proofs for both libpq instances; and
- harness changes to maintain the process boundary.

This is not materially better than L18. It has the acquisition cost of L15,
the duplication risk of PB, and the loader-collision risk of both. It is not
selected and no path or artifact is authorized.

## 6. Protocol-compatibility analysis

PostgreSQL 18 libpq retains protocol 3.0 as its backward-compatible default.
PostgreSQL server 15 supports protocol 3.0. `PQexecParams` sends a single
extended-query command and accepts separately bound text or NULL parameters.
These properties match the runner's transport contract.

PostgreSQL 18 adds protocol 3.2 negotiation and controls, but this design does
not opt into them. The future runtime gate must require observed protocol 3.0
against server 15.18 and reject any request for a PostgreSQL 18-only protocol
or connection feature.

The following protocol behaviors must be proven later:

- Parse, Bind, Execute, and Sync for the exact artifact submission;
- no simple Query message for the artifact;
- server rejection of a multi-command `PQexecParams` artifact;
- text parameter binding, including SQL NULL;
- SQLSTATE and command-tag fidelity;
- ReadyForQuery/transaction-state transitions for success and error;
- cancellation of an isolated long-running statement with the expected
  cancellation SQLSTATE and a usable or intentionally closed connection state.

## 7. ABI and SONAME analysis

The accepted package exposes `libpq.so.5` with concrete file
`libpq.so.5.18`. The stable SONAME allows existing dynamically linked clients
to request the same ABI name, but SONAME equality is not proof that a specific
process loaded the expected file or that every needed symbol resolves.

Pure Python Psycopg uses `ctypes` rather than compiling a local extension.
This removes compile-time header skew but makes loader-path validation
essential. Future evidence must prove the loaded real path, device/inode or
equivalent immutable file identity, file SHA-256, ELF SONAME, and observed
libpq version. The same check is required separately for each CLI tool.

No C server-extension ABI claim is relevant. Server extension ABI rules and
client libpq ABI are not interchangeable.

## 8. Package-version analysis

The selected exact package contract is:

| Component | Exact contract |
|---|---|
| Base image | `sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51` |
| Platform | `linux/amd64` |
| OS | Debian 12.15 / Bookworm |
| PostgreSQL server package | `postgresql-15=15.18-1.pgdg12+1` |
| PostgreSQL client package | `postgresql-client-15=15.18-1.pgdg12+1` |
| Client common package | `postgresql-client-common=291.pgdg12+1` |
| Common package | `postgresql-common=291.pgdg12+1` |
| System libpq package | `libpq5=18.4-1.pgdg12+1` |
| Libpq SONAME | `libpq.so.5` |
| Concrete observed library path | `/usr/lib/x86_64-linux-gnu/libpq.so.5.18` |
| Python | CPython 3.11; exact Debian package closure remains unresolved |
| Psycopg | pure Python `psycopg==3.2.9` |
| Implementation selector | `PSYCOPG_IMPL=python` |

No floating package version, implicit system upgrade, or alternate libpq is
permitted. Exact file and package hashes remain inputs to the later dependency
closure and build evidence.

## 9. Psycopg implementation analysis

Official Psycopg documentation distinguishes three implementations:

- `python` loads the system libpq through `ctypes`;
- `c` builds a local C extension against system headers/libraries; and
- `binary` bundles required native libraries.

The selected contract permits only `python`. `PSYCOPG_IMPL=python` must be set
in the final image and executable environment. Import must fail if that
implementation is unavailable. Future inspection must observe:

- distribution version exactly `3.2.9`;
- `psycopg.pq.__impl__ == "python"`;
- `psycopg.pq.version() == 180004`;
- no installed `psycopg_c` or `psycopg_binary` distribution;
- no bundled libpq under the Python environment; and
- the loaded system library identity described in Section 7.

The comment in `runner/pq_transport.py` that says "from psycopg[binary]" is not
runtime evidence and is inconsistent with the binding pure-Python design. It
must not be used to select a package. Correction of implementation files is
outside this design-only unit.

## 10. PostgreSQL CLI-tool analysis

The CLI binary version and the loaded client library are separate identities.
The contract requires:

- `psql --version` -> exactly 15.18;
- `pg_dump --version` -> exactly 15.18;
- `pg_restore --version` -> exactly 15.18;
- package ownership -> `postgresql-client-15=15.18-1.pgdg12+1`; and
- loaded libpq -> exact accepted system libpq 18.4, proven independently for
  each tool.

Official PostgreSQL 15 documentation states that pg_dump can dump older
servers but refuses servers newer than its own major. The target server and
pg_dump are both 15.18, so no cross-major dump case is accepted. D11 must use a
fresh target and validate the complete logical backup/restore contract.

The current harness statically invokes `pg_dump`; the binding provisioning
architecture also requires `pg_restore`. Neither invocation was executed in
this unit.

## 11. Security analysis

PostgreSQL 18.4 and 15.18 were released together on 2026-05-14 and are the
fixed versions for the same security update family. Both fix the client-side
`PQfn`/large-object issue identified as CVE-2026-6477. Therefore accepting exact
18.4 does not introduce a known downgrade relative to exact 15.18 at this
snapshot.

Security conclusions are bounded:

- Exact 18.4 is accepted; floating 18.x is not.
- The runner does not use `PQfn` or large-object APIs.
- Large-object APIs are prohibited for the runner unless separately designed
  and reviewed.
- The future D11 gate must establish whether the disposable spike contains
  large objects before allowing a backup path that could exercise large-object
  handling.
- Protocol 3.2, OAuth, `sslkeylogfile`, and other PostgreSQL 18-only client
  features are prohibited for this runner unless separately authorized.
- Pinning libpq 15 would not be a current security improvement; it would add a
  second patch-acquisition obligation.
- Accepting 18.4 does not broaden network, credential, role, SQL, or container
  authority. The existing threat model remains binding.

No general vulnerability scan was performed.

## 12. Supply-chain and offline-closure analysis

L18 minimizes future acquired bytes because the accepted base already contains
the exact libpq package and owned library. The later dependency closure still
must resolve CPython 3.11, venv/bootstrap build tooling, pure Psycopg 3.2.9, and
every active conditional dependency from official immutable sources.

The closure must:

- bind every Debian and wheel filename, version, architecture/tag, size, hash,
  source, and dependency edge;
- prove the base-provided libpq files rather than reacquire them;
- use no package index or network during BUILD;
- install no package during the executable gate;
- exclude `psycopg_binary` and `psycopg_c`;
- fail if any undeclared artifact is required; and
- preserve one final immutable client runtime containing Python, pure
  Psycopg, libpq, psql, pg_dump, and pg_restore.

L15, PB, and CR would each add at least one native artifact lineage and a
second linkage proof. Their additional surface is not justified by a static
incompatibility.

## 13. Exact selected contract

`LIBPQ-CONTRACT-ACCEPT-18.4` means all of the following are binding:

1. Retain the accepted immutable base, platform, and OS.
2. Retain PostgreSQL CLI packages at exact 15.18 revisions.
3. Retain `libpq5=18.4-1.pgdg12+1` and `libpq.so.5` as the only permitted
   runtime libpq lineage.
4. Provision CPython 3.11 through a separately approved offline closure.
5. Install only pure Python `psycopg==3.2.9` from an exact hash-locked wheel.
6. Force `PSYCOPG_IMPL=python`; import failure is a gate failure.
7. Prohibit runtime pip/package installation and executable-gate egress.
8. Prohibit PostgreSQL 18-only protocol/application features.
9. Require image inspection and runtime validation before integration or
   executable acceptance.
10. Treat any unknown version, path, hash, implementation, protocol, result,
    or transaction state as REJECT/HOLD under the future gate.

## 14. Prohibited assumptions

The following assumptions are explicitly invalid:

- CLI major 15 implies loaded libpq major 15.
- `libpq.so.5` alone proves the concrete loaded file.
- An installed package proves runtime loading.
- Protocol compatibility proves application correctness.
- Psycopg import success proves the `python` implementation was selected.
- `pq.version()` alone proves the library path or file hash.
- A mutable tag proves the immutable image identity.
- Current official documentation proves the exact acquired wheel contents.
- Package metadata proves executable versions.
- A later successful connection permits PostgreSQL 18-only features.
- The current runner comment mentioning `psycopg[binary]` overrides this
  contract.

## 15. Future build assertions

The separately authorized offline BUILD must fail unless:

- the accepted base image ID matches exactly;
- the build uses `linux/amd64` and no network;
- the accepted base package inventory is an input to closure resolution;
- no libpq package is added, removed, upgraded, or downgraded;
- no private libpq copy is introduced;
- CPython and wheel artifacts match the approved local hash inventories;
- only `psycopg==3.2.9` is installed, without `[c]` or `[binary]` extras;
- `PSYCOPG_IMPL=python` is embedded in the intended runtime contract;
- no package manager or pip action remains in the executable command;
- the final filesystem inventory contains the expected libpq path and no
  competing libpq under the Python environment; and
- all build inputs and resulting image identities are recorded.

These are future assertions, not commands and not authorization to build.

## 16. Future image-inspection assertions

The separately authorized no-network INSPECT unit must observe and record:

- exact image ID/config digest and `linux/amd64` platform;
- Debian 12.15 identity;
- exact installed package records for PostgreSQL 15.18 tools and libpq5 18.4;
- CPython 3.11 exact version and ABI;
- Psycopg distribution exactly 3.2.9;
- `PSYCOPG_IMPL=python` and `psycopg.pq.__impl__ == "python"`;
- `psycopg.pq.version() == 180004`;
- absence of `psycopg_c` and `psycopg_binary`;
- exact SHA-256 and ELF SONAME of the accepted libpq file;
- loader resolution for Python, psql, pg_dump, and pg_restore;
- CLI versions exactly 15.18;
- absence of a second libpq, unexpected loader override, Docker socket,
  package-index runtime path, and runtime package installer; and
- a fail-closed comparison against the approved build identity.

INSPECT may prove image composition. It may not claim server interoperability.

## 17. Future runtime-validation assertions

The separately authorized runtime gate must use only the disposable target and
must require all observations below. A missing observation is a failure.

### Identity and negotiation

- `psycopg.__version__` is exactly 3.2.9.
- `psycopg.pq.__impl__` is exactly `python`.
- `psycopg.pq.version()` is exactly 180004.
- the loaded libpq real path and file hash match the inspected accepted system
  library.
- psql, pg_dump, and pg_restore each report exactly 15.18 and load the accepted
  libpq.
- server version number and text identify exactly PostgreSQL 15.18.
- negotiated protocol is exactly 3.0; no 3.2-only feature is requested.

### Required transport behavior

- connection succeeds only to the exact guarded Compose service, port, DB,
  project, and bootstrap marker;
- `PQexecParams` produces Parse, Bind, Execute, and Sync for the exact artifact;
- zero-parameter extended execution remains extended;
- multi-command artifact Parse is rejected;
- text parameters and SQL NULL bind correctly;
- result status, command tag, row count, fields, and text values are exact;
- SQLSTATE is obtained from the result diagnostic field;
- backend PID matches SQL observation;
- transaction status transitions through IDLE, INTRANS, INERROR when induced,
  and final IDLE after successful COMMIT;
- explicit BEGIN/COMMIT/ROLLBACK preserve one connection/PID/top-level XID;
- final COMMIT returns successful result status and command tag `COMMIT`;
- cancellation of an isolated long-running statement is dispatched, yields the
  expected cancellation error/SQLSTATE, and leaves the observed connection in
  the contractually expected state;
- error reporting preserves SQLSTATE without converting mismatch or missing
  data into success; and
- connection close/backend-gone evidence reproduces without reconnect.

### Feature prohibitions and application behavior

- no runner call uses COPY, pipeline, large-object, `PQfn`, OAuth, or protocol
  3.2-only behavior;
- the current migration matrix uses no PostgreSQL 18-only server syntax or
  semantics;
- extended-query, transaction, concurrency, process-death, and D11 logical
  backup/restore properties pass their exact validators;
- psql/pg_dump/pg_restore behavior is validated against server 15.18; and
- any unknown, exception, missing field, version drift, linkage drift, or
  protocol drift fails the gate.

These assertions deliberately leave RBF-08 open until observed.

## 18. RBF-07 disposition

RBF-07 becomes:

`RBF-07-DESIGN-DECIDED-ACCEPT-18.4-RUNTIME-VALIDATION-OPEN`

The package-metadata drift is resolved at design level by accepting the exact
18.4 system package. Runtime validation is not complete.

## 19. New finding

`RBF-08 - exact libpq runtime linkage and PostgreSQL 15 interoperability unproven`

RBF-08 remains OPEN until separately authorized image inspection and runtime
validation prove exact library loading, protocol 3.0 negotiation, CLI linkage,
and all required runner behaviors against PostgreSQL server 15.18.

Other findings remain:

- RBF-01 OPEN.
- RBF-02 OPEN.
- RBF-03 RESOLVED previously.
- RBF-04 OPEN for the client image.
- RBF-05 OPEN.
- RBF-06 OPEN.

## 20. Exact next gate

Recommend exactly:

`PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-DESIGN-R1`

That gate must remain design-only. It may define the exact CPython 3.11 Debian
closure, pure Psycopg 3.2.9 wheel closure, conditional dependencies, immutable
source rules, and build-time fail-closed installation model. It must not
acquire artifacts, build an image, create a container, or contact a database.

No later gate begins from this document.

## 21. DOC-R9-01

`DOC-R9-01 - encoding/separator hygiene pending before commit`

The binding R9 repository summary contains four literal `?` separator
characters. Their identity is preserved. This note does not change the file,
does not reopen PVD-01, and is not a technical evidence blocker. Correction
requires a separate authorized unit before commit.

## 22. Official documentation consulted

Read-only documentation consultation on 2026-08-02 used only official primary
sources and acquired no package, wheel, image, or other artifact body:

- Psycopg installation and implementation model:
  `https://www.psycopg.org/psycopg3/docs/basic/install.html`
- Psycopg low-level pq API, implementation selector, and loaded version:
  `https://www.psycopg.org/psycopg3/docs/api/pq.html`
- Psycopg release notes, including PostgreSQL 18 libpq support in 3.2.8:
  `https://www.psycopg.org/psycopg3/docs/news.html`
- PostgreSQL 18 libpq command execution:
  `https://www.postgresql.org/docs/18/libpq-exec.html`
- PostgreSQL 18 connection/protocol/status functions:
  `https://www.postgresql.org/docs/18/libpq-status.html`
- PostgreSQL protocol overview:
  `https://www.postgresql.org/docs/18/protocol-overview.html`
- PostgreSQL 18 cancellation API:
  `https://www.postgresql.org/docs/18/libpq-cancel.html`
- PostgreSQL 15 pg_dump compatibility:
  `https://www.postgresql.org/docs/15/app-pgdump.html`
- PostgreSQL 18.4 and 15.18 release notes:
  `https://www.postgresql.org/docs/release/18.4/` and
  `https://www.postgresql.org/docs/release/15.18/`
- PostgreSQL CVE-2026-6477 record:
  `https://www.postgresql.org/support/security/CVE-2026-6477/`

## 23. Authorization boundary

No implementation or runtime activity occurred. This unit did not modify the
runner, harness, R9 summary, external evidence, Compose, requirements, image,
package, Git index, ref, branch, stash, or configuration.

This document does not authorize Docker access, package or wheel acquisition,
image pull/build, container creation/execution, PostgreSQL access, Supabase
access, runner/harness/test execution, dependency closure resolution, staging,
commit, fetch, push, publication, or any later gate.
