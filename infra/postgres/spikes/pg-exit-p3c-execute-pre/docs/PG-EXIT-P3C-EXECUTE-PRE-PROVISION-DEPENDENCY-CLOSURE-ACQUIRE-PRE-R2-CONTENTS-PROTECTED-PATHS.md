# PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-ACQUIRE-PRE-R2-CONTENTS-PROTECTED-PATHS

## 1. Decision

- Decision: HOLD
- Primary disposition: ACQUIRE-PRE-R2-HOLD
- Reason: the Debian Security signature set is not fully accounted for, and the signed Security Release lacks the required main/Contents-all representation.
- Body acquisition and all later gates remain unauthorized.

## 2. Source and binding evidence

- Worktree: C:/Adeptlabs/noxund-p3c-execute-pre
- Branch: spike/pg-exit-p3c-execute-pre
- HEAD: 4873ac713397cf47642d39b1ef17e48a9301511d
- Preflight subtree: 55 files, 298323 bytes, canonical input 5886 bytes, SHA-256 044ca6c0242dfc428c43e92a98bdd6ca6d5eeb33e49ab583a290d8c0f96bcb41.
- Tracked differences: 0.
- Staged differences: 0.
- Git-visible untracked subtree files: 54.
- Ignored subtree files: one .gitignore.
- R1 evidence: 74 regular files and 90226443 bytes; all 73 SHA256SUMS entries reproduced.
- R1 SHA256SUMS: 7995 bytes; SHA-256 6d912ddcbc34e9ba99629a678e328a5657169d5531d2e2ad7e3ae4da897edcb7.

## 3. Network and response inventory

- Domains contacted: none.
- R2 network request count: 0.
- R2 response count: 0.
- Contents downloads: 0.
- Prohibited bodies acquired: 0.

The signature policy was evaluated before Contents acquisition. Its failure prevented promotion, and the missing signed Security main/Contents-all entry independently prevents the required four-tuple coverage.

## 4. Snapshot identities and signed Contents entries

Approved effective snapshots remain:

- Debian: 20260713T202617Z; immutable base URL https://snapshot.debian.org/archive/debian/20260713T202617Z/.
- Debian Security: 20260713T191802Z; immutable base URL https://snapshot.debian.org/archive/debian-security/20260713T191802Z/.

Bookworm main signed entries:

- main/Contents-amd64: 148405971 bytes; SHA-256 06dcde67f7f99d754919fb2b5efcc243e5e3f169e9c6d41cf5a36d1cb81e648f.
- main/Contents-amd64.gz: 11629145 bytes; SHA-256 7e72214b4cef520fa07fc40ff975c60bc4501eca6308cf5cd9804c00811b776b.
- main/Contents-all: 519622348 bytes; SHA-256 5b3c43c126c20842388a6740167c5482799c18ac07a53f961e54db02daa05701.
- main/Contents-all.gz: 34017224 bytes; SHA-256 cc80fbae45044eaa2eab0b7005e6cfd4bd72472d501c532d51aa26523e1ace6d.

Bookworm Security signed entries:

- main/Contents-amd64: 0 bytes; SHA-256 e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855.
- main/Contents-amd64.gz: 20 bytes; SHA-256 f61f27bd17de546264aa58f40f3aafaac7021e0ef69c17f6b1b4cd7664a037ec.
- main/Contents-all: absent from the signed Release.
- main/Contents-all.gz: absent from the signed Release.

No compressed or decompressed Contents file was acquired in R2.

## 5. Debian Security signature re-verification

Method: gpgv --status-fd 1 version 2.4.9, using an isolated temporary verification environment with explicit accepted Security keyrings and the preserved identification-only processing keys.

Signer inventory:

- Approved signature: signing subkey B0CAB9266E8C3929798B3EEEBDE6D2B9216EC7A8; primary fingerprint 05AB90340C0C5E797F44A8C8254CF3B5AEC0A8F0; result GOODSIG and VALIDSIG.
- Additional signature: signing fingerprint ED541312A33F1128F10B1C6C54404762BBB6E853; key ID 54404762BBB6E853; result ERRSIG and NO_PUBKEY.

The clear-signed payload matches the preserved R1 Release payload SHA-256 7b6ad5075bc51181cc3c8ee8dc1ab1090329a48f828db3051d6a74bba9f98b25. No BADSIG, invalid digest, approved-signer expiration or revocation error, or payload ambiguity was observed. The additional signature nevertheless remains cryptographically unresolved.

Signature disposition: SECURITY-INRELEASE-HOLD-ADDITIONAL-SIGNATURE-UNRESOLVED.

## 6. Product Lead Debian alternative

The relation media-types | mime-support is resolved exactly to:

- media-types=10.0.0 all;
- stanza SHA-256 3b56dbbd0b48c5611108689764fcaa7bc835a05b9c6247dfacb4ffa21422abda;
- filename pool/main/m/media-types/media-types_10.0.0_all.deb;
- body size 26136;
- body SHA-256 aaa46dcb3b39948ae2e0fdb72cfcb2f48c0b59f19785a3da8045c05eb19955dd;
- role INSTALL-FINAL-RUNTIME inherited by both source edges.

mime-support=3.66 is rejected because it is transitional and adds mailcap and media-types. No mime-support or mailcap node was introduced by this relation.

Updated proposed graph counts:

- KEEP-BASE: 17;
- INSTALL-FINAL-RUNTIME: 9;
- INSTALL-BUILD-ONLY: 10.

The package relationship graph is unique after the Product Lead selection. It is not body-ready because signed Contents promotion and protected-path analysis remain incomplete.

## 7. Product Lead wheel selection

The exact approved proposal is:

- project typing-extensions;
- version 4.16.0;
- filename typing_extensions-4.16.0-py3-none-any.whl;
- size 45571 bytes;
- SHA-256 481caa481374e813c1b176ada14e97f1f67a4539ce9cfeb3f350d78d6370c2e8;
- tag py3-none-any;
- Requires-Python >=3.9;
- yanked false;
- active dependencies: none.

The wheel proposal contains exactly pure Python psycopg==3.2.9 and typing-extensions==4.16.0. Both remain UNACQUIRED, UNINSPECTED, and NOT-BEGUN. PyPI was not contacted in R2.

## 8. Protected paths and collision result

- /usr/lib/x86_64-linux-gnu/libpq.so.5 (accepted R9 owner libpq5).
- /usr/lib/x86_64-linux-gnu/libpq.so.5.18 (accepted R9 owner libpq5).
- /usr/bin/psql (accepted R9 owner postgresql-client-common).
- /usr/bin/pg_dump (accepted R9 owner postgresql-client-common).
- /usr/bin/pg_restore (accepted R9 owner postgresql-client-common).
- /usr/lib/postgresql/15/bin/psql (accepted R9 owner postgresql-client-15).
- /usr/lib/postgresql/15/bin/pg_dump (accepted R9 owner postgresql-client-15).
- /usr/lib/postgresql/15/bin/pg_restore (accepted R9 owner postgresql-client-15).
- /usr/lib/postgresql/15/bin/postgres (accepted R9 owner postgresql-15).

Contents parsing was not attempted because no Contents file was acquired or promoted. Each path and the full proposed package set therefore have disposition CONTENTS-METADATA-INCOMPLETE. No proposed-package collision was observed, but zero collision was not proven. Package relationship drift against the protected set remains zero observed; body collision proof remains required later.

## 9. Manifest and evidence identities

- Proposed R2 manifest file: 110347 bytes; SHA-256 13726b6619b5f205d87086889eded2c790a3f70a6d7a2d9b4503f239147b8ff6.
- Proposed R2 manifest canonical payload: 77696 bytes; SHA-256 3c184aefd4425041be2d9e11aa810b3b041d3f8d65f3f17b4106635f72aa651d.
- External R2 evidence: 13 regular files; 225246 bytes.
- External SHA256SUMS: 1261 bytes; SHA-256 e88a8102a84d409582e51143854db03cac91af76c65996eacf21c715651ba95d; 12 entries.

All manifest body states remain UNACQUIRED and UNINSPECTED; build state remains NOT-BEGUN.

## 10. Findings

- RBF-01: OPEN.
- RBF-02: OPEN.
- RBF-03: RESOLVED.
- RBF-04: OPEN.
- RBF-05: OPEN.
- RBF-06: OPEN.
- RBF-07: design-decided; runtime validation open.
- RBF-08: OPEN.
- RBF-09: OPEN-NARROWED-EXACT-DEBIAN-PACKAGE-GRAPH-CONTENTS-AND-SIGNATURE-BLOCKED.
- RBF-10: RBF-10-OPEN-NARROWED-EXACT-WHEEL-PROPOSAL-BODIES-UNACQUIRED.
- RBF-11: OPEN.
- RBF-12: OPEN-PROTECTED-FILE-COLLISION-METADATA-UNAVAILABLE.
- DCD-R1-NOTE-01: RESOLVED-BY-ACQUIRE-PRE-CONTRACT.
- DCD-R1-NOTE-02: RESOLVED-BY-ACQUIRE-PRE-CONTRACT.

The narrower Product Lead names for RBF-09 and RBF-12 are not used because the signed Contents validation predicate did not pass.

## 11. Exact next recommendation

Recommend exactly:

PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-ACQUIRE-PRE-R3-SECURITY-SIGNATURE-CONTENTS-COVERAGE

That unit should remain metadata-only and authorize only the evidence needed to identify the additional Security signer and a Product Lead decision on the absent signed Security Contents-all representation. It must not acquire package bodies or begin BUILD.

## 12. Scope and immutability

No existing repository or R1 evidence file was modified. Nothing was staged or committed. No .deb, wheel, sdist, image, source archive, or executable artifact was acquired. No Docker, APT, dpkg, pip, package installation, image build, database, runner, harness, fixture, migration, or test operation occurred. The known .rar was checked by path only and remained untouched. No later gate began.
