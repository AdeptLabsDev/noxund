# PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-ACQUIRE-PRE-R3-SECURITY-SIGNATURE-CONTENTS-COVERAGE

## 1. Decision

- Decision: PASS.
- Primary disposition: ACQUIRE-PRE-R3-READY-FOR-BODY-ALLOWLIST.
- BUILD, installation, and artifact inspection remain unauthorized.

## 2. Binding source and evidence

- Worktree: C:/Adeptlabs/noxund-p3c-execute-pre
- Branch: spike/pg-exit-p3c-execute-pre
- HEAD: 4873ac713397cf47642d39b1ef17e48a9301511d
- Preflight subtree: 56 files, 306513 bytes, canonical input 6057 bytes, SHA-256 72217e8c95fb4a75c1536dc30d60a37d852d3e8e03d3300c82293043074d89cf.
- Tracked differences: 0.
- Staged differences: 0.
- R1 evidence: all 73 manifest entries reproduced.
- R2 evidence: all 12 manifest entries reproduced.
- Binding R2 repository document: 8190 bytes; SHA-256 bac73c711e17eb8762785f8581ed4e850cbec5746c5c68a224ea5025b9073cff; Git blob 18fcb6fd784276600e6ee7d1a577aba265016bf1.

## 3. Network response inventory

- Contacted domain: snapshot.debian.org only.
- Requests: 2.
- Redirects: one per request, both remaining under snapshot.debian.org.
- Debian Security Contents requests: 0.
- Package, wheel, sdist, image, source archive, or executable body requests: 0.

The exact requested metadata paths were:

- https://snapshot.debian.org/archive/debian/20260713T202617Z/dists/bookworm/main/Contents-amd64.gz
- https://snapshot.debian.org/archive/debian/20260713T202617Z/dists/bookworm/main/Contents-all.gz

## 4. Debian Security trusted-signature policy

The preserved clear-signed payload is authenticated by:

- approved primary fingerprint 05AB90340C0C5E797F44A8C8254CF3B5AEC0A8F0;
- valid signing subkey B0CAB9266E8C3929798B3EEEBDE6D2B9216EC7A8;
- GOODSIG and VALIDSIG;
- no BADSIG, invalid digest, approved-signer expiration, approved-signer revocation, or payload ambiguity.

Final authentication disposition:

SECURITY-INRELEASE-PASS-TRUSTED-SIGNATURE-ADDITIONAL-UNTRUSTED-UNRESOLVED

The additional signature fingerprint ED541312A33F1128F10B1C6C54404762BBB6E853 remains ERRSIG and NO_PUBKEY. It is not an approved trust anchor, no owner is inferred, and neither cryptographic validity nor invalidity is claimed without its public key.

Additional-signature disposition:

ADDITIONAL-SIGNATURE-UNTRUSTED-UNRESOLVED-NONBLOCKING

## 5. Debian Security Contents coverage

The accepted signed Release records:

- main/Contents-amd64: 0 bytes; SHA-256 e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855.
- main/Contents-amd64.gz: 20 bytes; SHA-256 f61f27bd17de546264aa58f40f3aafaac7021e0ef69c17f6b1b4cd7664a037ec.
- main/Contents-all: absent.
- main/Contents-all.gz: absent.

Classification:

SECURITY-SNAPSHOT-SIGNED-CONTENTS-NOT-PUBLISHED

No Security Contents request was made. No unsigned substitute, mutable mirror, or alternate snapshot was used. The exact R2 graph contains zero Security-origin proposed packages. Any future Security-origin package must be classified BODY-INSPECTION-REQUIRED-BEFORE-INSTALLATION.

## 6. Debian main Contents identities

- main/Contents-amd64.gz: 11629145 bytes; SHA-256 7e72214b4cef520fa07fc40ff975c60bc4501eca6308cf5cd9804c00811b776b.
- Decompressed amd64: 148405971 bytes; SHA-256 06dcde67f7f99d754919fb2b5efcc243e5e3f169e9c6d41cf5a36d1cb81e648f.
- main/Contents-all.gz: 34017224 bytes; SHA-256 cc80fbae45044eaa2eab0b7005e6cfd4bd72472d501c532d51aa26523e1ace6d.
- Decompressed all: 519622348 bytes; SHA-256 5b3c43c126c20842388a6740167c5482799c18ac07a53f961e54db02daa05701.

Both compressed and decompressed identities exactly match the signed Release. Decompressed bytes were streamed, hashed without normalization, and not retained as separate regular files.

## 7. Contents parser

- Physical lines: 7316650.
- Non-empty entries: 7316650.
- Owner edges: 7362379.
- Malformed entries: 0.
- UTF-8 decoding errors: 0.
- Duplicate path-owner edges: 0.
- Path-order errors: 0.
- Case folding: none.
- Windows path conversion: none.
- Owner-token loss: none.

Parser disposition: PASS.

## 8. Package origins and closure

- BASE-R9: 17 packages.
- DEBIAN-MAIN: 19 proposed packages.
- DEBIAN-SECURITY: 0 proposed packages.
- Unknown origins: 0.

All proposed main packages matched at least one ownership edge in their architecture-appropriate Contents index. Exact media-types=10.0.0 all and typing-extensions==4.16.0 selections remain unchanged.

Updated graph counts remain:

- KEEP-BASE: 17.
- INSTALL-FINAL-RUNTIME: 9.
- INSTALL-BUILD-ONLY: 10.

Dependency nodes and edges are unchanged from R2.

## 9. Protected paths

- /usr/lib/x86_64-linux-gnu/libpq.so.5: owners libs/libpq5; proposed main collision: none.
- /usr/lib/x86_64-linux-gnu/libpq.so.5.18: owners none; proposed main collision: none.
- /usr/bin/psql: owners database/postgresql-client-common; proposed main collision: none.
- /usr/bin/pg_dump: owners database/postgresql-client-common; proposed main collision: none.
- /usr/bin/pg_restore: owners database/postgresql-client-common; proposed main collision: none.
- /usr/lib/postgresql/15/bin/psql: owners database/postgresql-client-15; proposed main collision: none.
- /usr/lib/postgresql/15/bin/pg_dump: owners database/postgresql-client-15; proposed main collision: none.
- /usr/lib/postgresql/15/bin/pg_restore: owners database/postgresql-client-15; proposed main collision: none.
- /usr/lib/postgresql/15/bin/postgres: owners database/postgresql-15; proposed main collision: none.

All 19 proposed Debian main packages own zero protected paths. Owner ambiguity count is zero. This is signed Contents metadata preflight, not final .deb body proof.

Main collision disposition:

NO-MAIN-PROPOSED-PACKAGE-COLLISION

Security package policy:

SECURITY-PACKAGE-BODY-INSPECTION-REQUIRED

Protected relationship drift remains ZERO-PROTECTED-PACKAGE-RELATIONSHIP-DRIFT.

## 10. Wheel proposal

The exact pure-wheel proposal remains:

- psycopg 3.2.9, psycopg-3.2.9-py3-none-any.whl, 202705 bytes, SHA-256 01a8dadccdaac2123c916208c96e06631641c0566b22005493f09663c7a8d3b6.
- typing-extensions 4.16.0, typing_extensions-4.16.0-py3-none-any.whl, 45571 bytes, SHA-256 481caa481374e813c1b176ada14e97f1f67a4539ce9cfeb3f350d78d6370c2e8.

Both remain UNACQUIRED, UNINSPECTED, and NOT-BEGUN. No native wheel or sdist is selected.

## 11. Manifest and evidence

- R3 closure: 78244 bytes; SHA-256 414da659e61d4beb16d27f65adb864188b814951af4362a9557f75d006e6d6bb.
- R3 proposed manifest: 121235 bytes; SHA-256 37e0e50ed29c46d6ba4f2ac3b5bed2eb8b3ef738ea774ef8397329e4cc6f4fce.
- Manifest canonical payload: 86945 bytes; SHA-256 bac227265430e9734a5a454ba24a6a88e20d6cd865589dbacd0956d748b4505a.
- External evidence: 18 regular files; 45912187 bytes.
- External SHA256SUMS: 1891 bytes; 17 entries; SHA-256 5dccd36a55c974cac085a0efc02a3e1a452558d42bf775bc0249f25e055a33e1.

Every external manifest entry reproduced.

## 12. Findings

- RBF-01: OPEN.
- RBF-02: OPEN.
- RBF-03: RESOLVED.
- RBF-04: OPEN.
- RBF-05: OPEN.
- RBF-06: OPEN.
- RBF-07: design-decided; runtime validation open.
- RBF-08: OPEN.
- RBF-09-OPEN-NARROWED-EXACT-DEBIAN-CLOSURE-BODIES-UNACQUIRED.
- RBF-10-OPEN-NARROWED-EXACT-WHEEL-PROPOSAL-BODIES-UNACQUIRED.
- RBF-11: OPEN.
- RBF-12-OPEN-NARROWED-MAIN-CONTENTS-ZERO-COLLISION-SECURITY-BODY-INSPECTION-REQUIRED.
- RBF-13-OPEN-NONTRUST-SIGNER-PROVENANCE-UNRESOLVED-NONBLOCKING.

RBF-12 and RBF-13 remain open.

## 13. Exact next gate

Recommend exactly:

PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-ACQUIRE-R1

That gate may acquire only exact manifest-listed .deb and .whl bodies, must verify size and SHA-256 during capture, install nothing, execute nothing, preserve bodies for a separate artifact-inspection gate, and keep BUILD unauthorized.

## 14. Scope and immutability

No existing repository, R1 evidence, or R2 evidence file changed. Nothing was staged or committed. No prohibited artifact body was acquired. No Docker, package installation, image build, database, runner, harness, fixture, migration, or test operation occurred. The known .rar was checked by path only and remained untouched. No later gate began.
