# PG-EXIT-P3C-EXECUTE-PRE ? Base Inventory R9 NTFS ADS Recovery

## Decision

- Unit: `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-BASE-INVENTORY-R9-NTFS-ADS-RECOVERY`
- Result: `COMPLETE`
- PVD-01: `PVD-01-CLOSED-FOR-BASE-INVENTORY`
- RBF-07: `RBF-07-OPEN-PACKAGE-METADATA-DRIFT-CONFIRMED`
- Branch: `spike/pg-exit-p3c-execute-pre`
- HEAD: `4873ac713397cf47642d39b1ef17e48a9301511d`

## Base and lifecycle identity

- Accepted image: `sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51`
- Source container: `noxund-p3c-base-inventory-r3-4873ac7`
- Container ID: `9abe992d37baf11b13b342e90acfc75df1c9579542f2198033d04a35ba850a62`
- Anonymous volume: `6359b5d7fb160be7a87df34d1f79f43b632acfa439e47fe5efaa8231835db8fa`
- The container remained `created` and was never started.
- The authorized cleanup completed with exit code 0.
- The container is absent by name and ID; the anonymous volume is absent; the empty baseline volume set was restored.

## NTFS ADS recovery

The original Windows materialization placed 373 colon-qualified dpkg metadata members into NTFS alternate data streams. Those ADS remain historical and non-authoritative.

Exactly one binary, non-executing Docker archive copy captured `/var/lib/dpkg/info/.` to an uncompressed tar without extraction:

- Archive: `raw/dpkg-info-r9.tar`
- Size: 4,482,048 bytes
- SHA-256: `e506b84b5ddb4ec71d4192f8dda34143bcfa98c2b7bb861c32118a240ff0f80c`
- Members: 666 total; 665 regular; 1 directory
- Architecture-qualified members: 373
- `.list` members: 144
- Package-to-`.list` reconciliation: 144 matched; 0 missing; 0 ambiguous; 0 unclaimed
- Archive extraction: none

`libpq5:amd64.list` is a regular member of 2,122 bytes with SHA-256 `96f12463dd3574e0e6035b7a35bddbbc2cd0ee5e53e622045849c710f5230de9`.

## Authoritative layering

- Package records: `derived/installed-packages-r8.tsv`
- Dependency edges: `derived/package-dependencies-r8.tsv`
- Dpkg-info source: `raw/dpkg-info-r9.tar`
- Archive member inventory: `derived/dpkg-info-archive-members-r9.tsv`
- Ownership: `derived/relevant-file-ownership-r9.tsv`
- Parser validation: `derived/parser-validation-r9.json` ? `PARSER-R9-PASS`
- Secret review: `derived/archive-secret-scan-r9.json` ? PASS

The rejected R7 TSVs, rejected R8 ownership and superseded R8 provisional summary remain immutable historical evidence and are included in the final manifest.

## Package findings

- Package records: 144, all `install ok installed`
- PostgreSQL server: `postgresql-15 15.18-1.pgdg12+1 amd64`
- PostgreSQL client: `postgresql-client-15 15.18-1.pgdg12+1 amd64`
- System libpq: `libpq5 18.4-1.pgdg12+1 amd64`
- Python packages: none indicated
- pip packages: none indicated
- venv packages: none indicated
- Debian: 12.15 / Bookworm

Package-file ownership indicates that `libpq5:amd64.list` owns:

- `/usr/lib/x86_64-linux-gnu/libpq.so.5`
- `/usr/lib/x86_64-linux-gnu/libpq.so.5.18`

Dynamic runtime linkage remains `RUNTIME-UNPROVEN`.

## Candidate A implication

Candidate A expected system libpq 15/15.18. Authoritative package and ownership metadata instead indicate libpq 18.4, and no libpq 15 runtime package was observed. This closes the inventory question but blocks silent continuation into BUILD.

## Evidence identity

- Category A/B payload: 442 files; 7,585,337 bytes
- Canonical payload input: 50,361 bytes
- Canonical payload SHA-256: `4f23c9ff955e23cad89244e32ee2ba97aec1ff199cb2b4a7dcc38bc9166894d7`
- Source inventory SHA-256: `61c81ea24f9c0a5dc3565649d03cec8a694a54827f24817a1f479d74fbc76326`
- Pre-cleanup attestation SHA-256: `5f7ab3690e88799ed0f85db9ba657fb038f6917e35aa8c06229e58139b863e7b`
- Cleanup result SHA-256: `f75d1327751ebb4966b101ea0f7712ea1977c2c7244cb8ea4de98a23cedf7576`
- Evidence context SHA-256: `9b4f908131c965920014bc3f9e51323c1807ea0a92f0e2fa2fc1f8de43a591ee`
- SHA256SUMS SHA-256: `5e0b48febde8c3d23a737bb4b90a916f24d6f02e81f321124327085c6fadc9c3`
- Final external evidence: 447 regular files; 7,743,907 bytes

## Open findings and next gate

- RBF-01: OPEN
- RBF-02: OPEN
- RBF-03: RESOLVED
- RBF-04: OPEN for client image
- RBF-05: OPEN
- RBF-06: OPEN
- RBF-07: OPEN ? package-metadata drift confirmed

Recommended next gate: `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DESIGN-R1-LIBPQ-CONTRACT`.

That gate must remain design-only and decide whether Candidate A pins libpq 15, deliberately accepts and revalidates libpq 18, or selects another bounded runtime strategy.

No network, image mutation, container execution, package acquisition, database operation, bootstrap, harness, fixture or test execution occurred. Nothing was staged or committed.
