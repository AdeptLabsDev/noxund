# PG-EXIT-P3C-EXECUTE-PRE Dependency Closure ACQUIRE-PRE R1

## 1. Decision

Primary disposition: `ACQUIRE-PRE-HOLD`.

The metadata gate fixed the snapshot identities, verified accepted Debian signatures and Release/index hash chains, fixed the CPython candidate, matched the binding Psycopg identity, and produced finite wheel candidates. It did not produce a body allowlist because three fail-closed predicates remain unresolved:

- `media-types | mime-support` has two eligible Debian alternatives and no Product Lead selection.
- Signed binary Package indexes do not expose package file lists, so collision analysis against protected libpq and PostgreSQL paths is incomplete.
- `typing-extensions==4.16.0` is recommended from the finite eligible set but is not Product Lead approved.

No package or wheel body is authorized by this document.

## 2. Source and scope

- Worktree: `C:/Adeptlabs/noxund-p3c-execute-pre`
- Branch: `spike/pg-exit-p3c-execute-pre`
- HEAD: `4873ac713397cf47642d39b1ef17e48a9301511d`
- Unit: `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-ACQUIRE-PRE-R1`
- External evidence: `C:/Adeptlabs/noxund-p3c-dependency-closure-acquire-pre-r1`

Preflight matched 54 physical subtree files, 53 Git-visible untracked files, one ignored subtree `.gitignore`, 272638 bytes, 5739 canonical input bytes, and canonical SHA-256 `296ef7e348c61688e506a8c0359aa6389db8d147d3988071ca9e03fabf066f86`. Tracked and staged diffs were zero.

## 3. Network response inventory

Contacted domains: `snapshot.debian.org`, `ftp-master.debian.org`, `pypi.org`, and `files.pythonhosted.org`. Every request was metadata-only.

| # | Classification | Status | Bytes | SHA-256 | Evidence path |
|---:|---|---:|---:|---|---|
| 1 | DEBIAN-SNAPSHOT-LISTING | 200 | 10501 | `c64152853acf78649c224423e0aa48848e55d58677102c8aa0a3df3d8a99019a` | `raw/debian/debian-snapshot-listing-2026-07.html` |
| 2 | DEBIAN-SECURITY-SNAPSHOT-LISTING | 200 | 18030 | `832acf5bd8294c720a73437d40033c9e2dacfe536335b6ec0145346a1b0897a5` | `raw/debian/debian-security-snapshot-listing-2026-07.html` |
| 3 | DEBIAN-KEY-INDEX | 200 | 10718 | `b271f4c351a3b54f6a6be9667bb834809d12ee514055b903ccb06839d274e3e0` | `raw/trust/debian-archive-keys.html` |
| 4 | DEBIAN-PUBLIC-SIGNING-KEY | 200 | 11861 | `c2a9a16fde95e037bafd0fa6b7e31f41b4ff1e85851de5558f19a2a2f0e955e2` | `raw/trust/archive-key-12.asc` |
| 5 | DEBIAN-PUBLIC-SIGNING-KEY | 200 | 11873 | `74f81645b4e3156d1e9a88c8dd9259271b89c7099d64af89a2a6996b592faa1f` | `raw/trust/archive-key-12-security.asc` |
| 6 | DEBIAN-PUBLIC-SIGNING-KEY | 200 | 461 | `521e9f6a9f9b92ee8d5ce74345e8cfd04028dae9db6f571259d584b293549824` | `raw/trust/release-12.asc` |
| 7 | PYPI-RELEASE-JSON | 200 | 6094 | `a46e32a00431b531a9f0fa95cd2e325c0bd8c07823ef5c369cb475dec53dbdc7` | `raw/pypi/psycopg-3.2.9.json` |
| 8 | PYPI-SIMPLE-JSON | 200 | 62162 | `803dbe33521a0055b937b1693d05a40fc3e3d9ec337421d51646138e0e00fec6` | `raw/pypi/psycopg-simple.json` |
| 9 | PYPI-PROJECT-JSON | 200 | 97612 | `2e567d7ca1b1c70a8e8f23b7204a8bd51b0bacd39e2fe53b33b153cff255ac68` | `raw/pypi/typing-extensions-project.json` |
| 10 | PYPI-SIMPLE-JSON | 200 | 65818 | `256ad708c8c27a7f248420f60bc2e47bf3c3f96a8081e06c4498bec606e1485b` | `raw/pypi/typing-extensions-simple.json` |
| 11 | DEBIAN-INRELEASE | 200 | 151075 | `77737fa4b34f2693e982cc9ee35736816c35a7778fc2d326cc1bbf5b301fe1aa` | `raw/debian/debian-20260713T202617Z-bookworm-InRelease` |
| 12 | DEBIAN-PACKAGE-INDEX-COMPRESSED | 200 | 8790396 | `9e0b5aabb2465b3d2e7a7fe27f9913846277833f7a2826e7767acccff5b588c5` | `raw/debian/debian-20260713T202617Z-bookworm-main-binary-amd64-Packages.xz` |
| 13 | DEBIAN-PACKAGE-INDEX-COMPRESSED | 200 | 4231936 | `743228b0bd99db92c91c5c133952cea0ff0c93a2b5b47a058973f3cab40d6481` | `raw/debian/debian-20260713T202617Z-bookworm-main-binary-all-Packages.xz` |
| 14 | DEBIAN-INRELEASE | 200 | 47954 | `920f9625fd87d3a85aab2a6febf4676f6cae30d883e37ea8c7fcd0cc903ed9d9` | `raw/debian/debian_security-20260713T191802Z-bookworm-security-InRelease` |
| 15 | DEBIAN-PACKAGE-INDEX-COMPRESSED | 200 | 316092 | `4c748fd3024b63ab82acf84ef893d6879541485522f98b7a7361e1f1dd464d5b` | `raw/debian/debian_security-20260713T191802Z-bookworm-security-main-binary-amd64-Packages.xz` |
| 16 | DEBIAN-PACKAGE-INDEX-COMPRESSED | 200 | 124992 | `c4be85784b0a8da843544a8c932d713cc22101a7d5b5f77ae207eb4625d56787` | `raw/debian/debian_security-20260713T191802Z-bookworm-security-main-binary-all-Packages.xz` |
| 17 | PYPI-CORE-METADATA | 200 | 4538 | `9b2a745b662478d264d842af579ba44ea5660a0f40324e52ca2f18bdaf9478e1` | `raw/pypi/psycopg-3.2.9-py3-none-any.whl.metadata` |
| 18 | PYPI-RELEASE-JSON | 200 | 5116 | `0a3d6e000ff69abee86ee9441e821abf98b8e884d9a8fa294ecc75b91b094091` | `raw/pypi/typing-extensions-4.6.0.json` |
| 19 | PYPI-RELEASE-JSON | 200 | 5116 | `1daaf2e63e9ffcf007077e02f2ddcc1102546c52cde2ac13f902d3bcff1757e3` | `raw/pypi/typing-extensions-4.6.1.json` |
| 20 | PYPI-RELEASE-JSON | 200 | 5116 | `76a6e00aa7c30b6f99288ee14395acf114fe4cedd8ae2ff0f9feba66164b21b4` | `raw/pypi/typing-extensions-4.6.2.json` |
| 21 | PYPI-RELEASE-JSON | 200 | 5116 | `ab0084f0de8baf6e9b8e0ba5d440bb7fb87646e538fe3cccfb54ec933fec800e` | `raw/pypi/typing-extensions-4.6.3.json` |
| 22 | PYPI-RELEASE-JSON | 200 | 5402 | `cddbaedb77c20b2d73b6d97cb01310d9a39eace80bfed38d69daf1b90431c839` | `raw/pypi/typing-extensions-4.7.0.json` |
| 23 | PYPI-RELEASE-JSON | 200 | 5402 | `b165097154f0aa6c0a527951712776b61957e4ee664a725296fd67213a61ea9e` | `raw/pypi/typing-extensions-4.7.1.json` |
| 24 | PYPI-RELEASE-JSON | 200 | 5298 | `1cd498f59a54f9d60a13ea122e7b3f3d953bdab2020452c666fe0717dee517c5` | `raw/pypi/typing-extensions-4.8.0.json` |
| 25 | PYPI-RELEASE-JSON | 200 | 5298 | `1cb619da6b6856ce1e7af3bd47c6f8610006be88a592b080c45d181af26c015d` | `raw/pypi/typing-extensions-4.9.0.json` |
| 26 | PYPI-RELEASE-JSON | 200 | 5304 | `a452019d7b3b215312804cd45dc29ff03f0e0e7ebdea9eadd9872a8f6c60143b` | `raw/pypi/typing-extensions-4.10.0.json` |
| 27 | PYPI-RELEASE-JSON | 200 | 5327 | `dc1fcac4291cef8254755369b225d9da8a6d32810760b33663cee2881220f8f7` | `raw/pypi/typing-extensions-4.11.0.json` |
| 28 | PYPI-RELEASE-JSON | 200 | 5368 | `0db4c5dce294d2abc81c1a6ae2eb047ce5c09f66dce58f35525ac0f0b874d9a1` | `raw/pypi/typing-extensions-4.12.0.json` |
| 29 | PYPI-RELEASE-JSON | 200 | 5368 | `0430b6d2853c83bb0e4f49e9b9bcdd999548baa331be73a9a7b27895d54d635f` | `raw/pypi/typing-extensions-4.12.1.json` |
| 30 | PYPI-RELEASE-JSON | 200 | 5368 | `c5900b4532b93c4c4df1f92ebda717dfa953dbbe3cc900d8fb303ce66c8a82ee` | `raw/pypi/typing-extensions-4.12.2.json` |
| 31 | PYPI-RELEASE-JSON | 200 | 5321 | `1b062525f5f66569d346dbd416ff53d8c15f035d38befd90b191862973b91035` | `raw/pypi/typing-extensions-4.13.0.json` |
| 32 | PYPI-RELEASE-JSON | 200 | 5321 | `301aba9a6dcdf9c917a7d34c750ee78a5e8ecc184534003af53959ef564e00e5` | `raw/pypi/typing-extensions-4.13.1.json` |
| 33 | PYPI-RELEASE-JSON | 200 | 5321 | `a3f978920e65335f87bc920c1d42ebfbb76f523b382553f88bc8aa39bddb4a5f` | `raw/pypi/typing-extensions-4.13.2.json` |
| 34 | PYPI-RELEASE-JSON | 200 | 5322 | `256d6d2ae7e4fc8f602ff11a225ecddab9c36bddf15d3a94bdc23b4ba91b666c` | `raw/pypi/typing-extensions-4.14.0.json` |
| 35 | PYPI-RELEASE-JSON | 200 | 5322 | `a2e299574cfe80ea00b556c17d7c7de4ebad275a40d6acbbc7c5b01dddad892f` | `raw/pypi/typing-extensions-4.14.1.json` |
| 36 | PYPI-RELEASE-JSON | 200 | 5590 | `e97e0b1087254aa1c7e8b2074c3796124dfd7d26e0f54ffcdc3a975b53047938` | `raw/pypi/typing-extensions-4.15.0.json` |
| 37 | PYPI-RELEASE-JSON | 200 | 5631 | `2140da00d62dde967f52d0be0ae28444f1d6a3fe603f52c83c23988c32122d5a` | `raw/pypi/typing-extensions-4.16.0.json` |
| 38 | PYPI-CORE-METADATA | 200 | 3310 | `b05084ca1d50879865178d9fff9fabeab61bdfb1f361bfbde95421ffc8f9be46` | `raw/pypi/typing_extensions-4.16.0-py3-none-any.whl.metadata` |
| 39 | DEBIAN-PUBLIC-SIGNING-KEY | 200 | 11861 | `6f1d277429dd7ffedcc6f8688a7ad9a458859b1139ffa026d1eeaadcbffb0da7` | `raw/trust/archive-key-13.asc` |
| 40 | DEBIAN-PUBLIC-SIGNING-KEY | 200 | 11873 | `844c07d242db37f283afab9d5531270a0550841e90f9f1a9c3bd599722b808b7` | `raw/trust/archive-key-13-security.asc` |
| 41 | DEBIAN-PUBLIC-SIGNING-KEY | 200 | 1384 | `4d097bb93f83d731f475c5b92a0c2fcf108cfce1d4932792fca72d00b48d198b` | `raw/trust/release-13.asc` |
| 42 | DEBIAN-PUBLIC-PROCESSING-KEY-IDENTIFICATION-ONLY | 200 | 1725 | `ac6ab0d225fce023eaa56f07ea93765f0ada1aa3cc20444bf9d2f8d92032cc19` | `raw/trust/debian-archive-processing-2022.asc` |
| 43 | DEBIAN-PUBLIC-PROCESSING-KEY-IDENTIFICATION-ONLY | 200 | 1749 | `f12fdc859969a9210515e97e1bcc9c19bfb73d950b82157a5778c06c1a802563` | `raw/trust/debian-security-archive-processing-2022.asc` |
| 44 | DEBIAN-KEY-DIRECTORY-INDEX | 200 | 11576 | `15c4e9e1ea57e1c8cf5be5da553dd97eff294617f7aec8ca61501b6a0cc86c09` | `raw/trust/debian-key-directory-index.html` |

Response count: 44. No redirect left an authorized official domain family. No response body had a prohibited package-body suffix.

## 4. Snapshot resolution

| Archive | Requested timestamp | Effective timestamp | Previous import | Next import | Disposition |
|---|---|---|---|---|---|
| debian | `2026-07-14T01:36:49.492774343Z` | `2026-07-13T20:26:17Z` | `20260713T143636Z` | `20260714T022128Z` | `RESOLVED-TO-PREVIOUS-IMPORT` |
| debian-security | `2026-07-14T01:36:49.492774343Z` | `2026-07-13T19:18:02Z` | `20260713T190736Z` | `20260714T140257Z` | `RESOLVED-TO-PREVIOUS-IMPORT` |

The effective timestamp and immutable snapshot URL, not the requested cutoff, are the proposed identities.

DCD-R1-NOTE-01: `RESOLVED-BY-ACQUIRE-PRE-CONTRACT`.

## 5. Debian trust chain

| Trust role | Source | Primary fingerprint | Additional fingerprint(s) |
|---|---|---|---|
| APT-TRUST | `raw/trust/archive-key-12.asc` | `B8B80B5B623EAB6AD8775C45B7C5D7D6350947F8` | `4CB50190207B4758A3F73A796ED0E7B82643E131` |
| APT-TRUST | `raw/trust/archive-key-12-security.asc` | `05AB90340C0C5E797F44A8C8254CF3B5AEC0A8F0` | `B0CAB9266E8C3929798B3EEEBDE6D2B9216EC7A8` |
| APT-TRUST | `raw/trust/release-12.asc` | `4D64FEC119C2029067D6E791F8D2585B8783D481` | `NONE` |
| APT-TRUST | `raw/trust/archive-key-13.asc` | `04B54C3CDCA79751B16BC6B5225629DF75B188BD` | `B8E5F13176D2A7A75220028078DBA3BC47EF2265` |
| APT-TRUST | `raw/trust/archive-key-13-security.asc` | `5E04A1E3223A19A20706E20F9904613D4CCE68C6` | `89C87ACEA5DD6B8E6A7068808E9F831205B4BA95` |
| APT-TRUST | `raw/trust/release-13.asc` | `41587F7DB8C774BCCF131416762F67A0B2C39DE4` | `NONE` |
| IDENTIFICATION-ONLY-NOT-APT-TRUST | `raw/trust/debian-archive-processing-2022.asc` | `F38AA24EB85F09F9923CA4949BF6A82061CCB921` | `NONE` |
| IDENTIFICATION-ONLY-NOT-APT-TRUST | `raw/trust/debian-security-archive-processing-2022.asc` | `0624E959E0209B869917FB26A3ADB4776A5D187D` | `NONE` |

Verifier: Git-for-Windows `gpgv (GnuPG) 2.4.9`.

- `raw/debian/debian-20260713T202617Z-bookworm-InRelease`: `SIGNATURE-VERIFIED-ACCEPTED-KEY`; verifier exit `0`; accepted signing fingerprint(s): `4CB50190207B4758A3F73A796ED0E7B82643E131`.
- `raw/debian/debian_security-20260713T191802Z-bookworm-security-InRelease`: `SIGNATURE-VERIFIED-ACCEPTED-KEY-ADDITIONAL-UNKNOWN-SIGNATURE-REJECTED`; verifier exit `2`; accepted signing fingerprint(s): `B0CAB9266E8C3929798B3EEEBDE6D2B9216EC7A8`.
  Additional unknown signature: `54404762BBB6E853`; rejected and not used as a trust anchor.

The processing keys were captured only to identify the additional signer and were not accepted for APT trust.

## 6. Release dates and Valid-Until

| Archive | Release Date | Valid-Until | Classification |
|---|---|---|---|
| debian | `Sat, 11 Jul 2026 10:16:37 UTC` | `ABSENT` | `VALID-UNTIL-ABSENT` |
| debian-security | `Mon, 13 Jul 2026 19:17:34 UTC` | `Mon, 20 Jul 2026 19:17:34 UTC` | `VALID-UNTIL-EXPIRED-HISTORICAL-SNAPSHOT` |

Expired historical metadata is eligible only because the immutable snapshot is fixed, an exact accepted key verifies the Release payload, consumed indexes reproduce signed Release hashes, no mutable alias is used, expiration is explicit, and body acquisition still requires later Product Lead approval. No APT validity check was disabled.

DCD-R1-NOTE-02: `RESOLVED-BY-ACQUIRE-PRE-CONTRACT`.

## 7. Signed package indexes

| Suite | Architecture | Compressed bytes / SHA-256 | Decompressed bytes / SHA-256 | Chain |
|---|---|---|---|---|
| bookworm | amd64 | 8790396 / `9e0b5aabb2465b3d2e7a7fe27f9913846277833f7a2826e7767acccff5b588c5` | 50060337 / `515e692f2c4121c6fcec444ef100cc18f79a991910615f3a88c8b7becfc94d2f` | `RELEASE-HASH-CHAIN-VERIFIED` |
| bookworm | all | 4231936 / `743228b0bd99db92c91c5c133952cea0ff0c93a2b5b47a058973f3cab40d6481` | 22526615 / `bc442eb8e8251796e139748da1872c050e2d1e93f55655100357f2e68364caf5` | `RELEASE-HASH-CHAIN-VERIFIED` |
| bookworm-security | amd64 | 316092 / `4c748fd3024b63ab82acf84ef893d6879541485522f98b7a7361e1f1dd464d5b` | 2071803 / `0fba2b2df73079772dafcc4bd7bfc240e3f76ff98a970fb1a95c54690251a8e7` | `RELEASE-HASH-CHAIN-VERIFIED` |
| bookworm-security | all | 124992 / `c4be85784b0a8da843544a8c932d713cc22101a7d5b5f77ae207eb4625d56787` | 868998 / `866500eaa8630ad4e7e4d9d07832a744ffd8444cf0d9a9253f26fac8481a803c` | `RELEASE-HASH-CHAIN-VERIFIED` |

Every compressed and decompressed index identity matched its signed Release SHA256 table. No package-pool body was requested.

## 8. CPython and Debian closure proposal

- Exact CPython candidate: `python3.11=3.11.2-6+deb12u8` (`amd64`).
- Interpreter full version for wheel markers: `3.11.2`.
- Nodes: KEEP-BASE 17; INSTALL-FINAL 8; INSTALL-BUILD-ONLY 10.
- `Recommends`, `Suggests`, and `Enhances` were not promoted.
- Development headers, compilers, source builds, venv, and ensurepip packages were rejected.

### 8.1 Final-runtime proposal

| Package | Version | Architecture |
|---|---|---|
| libexpat1 | `2.5.0-1+deb12u2` | amd64 |
| libnsl2 | `1.3.0-2` | amd64 |
| libpython3.11-minimal | `3.11.2-6+deb12u8` | amd64 |
| libpython3.11-stdlib | `3.11.2-6+deb12u8` | amd64 |
| libtirpc-common | `1.3.3+ds-1` | all |
| libtirpc3 | `1.3.3+ds-1` | amd64 |
| python3.11 | `3.11.2-6+deb12u8` | amd64 |
| python3.11-minimal | `3.11.2-6+deb12u8` | amd64 |

### 8.2 Build-only proposal

| Package | Version | Architecture |
|---|---|---|
| ca-certificates | `20230311+deb12u1` | all |
| libpython3-stdlib | `3.11.2-1+b1` | amd64 |
| python3 | `3.11.2-1+b1` | amd64 |
| python3-distutils | `3.11.2-3` | all |
| python3-lib2to3 | `3.11.2-3` | all |
| python3-minimal | `3.11.2-1+b1` | amd64 |
| python3-pip | `23.0.1+dfsg-1` | all |
| python3-pkg-resources | `66.1.1-1+deb12u2` | all |
| python3-setuptools | `66.1.1-1+deb12u2` | all |
| python3-wheel | `0.38.4-2` | all |

### 8.3 Base-satisfied proposal

| Package | Exact R9 version | Architecture |
|---|---|---|
| debconf | `1.5.82` | all |
| dpkg | `1.21.23` | amd64 |
| libbz2-1.0 | `1.0.8-5+b1` | amd64 |
| libc6 | `2.36-9+deb12u14` | amd64 |
| libcrypt1 | `1:4.4.33-2` | amd64 |
| libdb5.3 | `5.3.28+dfsg2-1` | amd64 |
| libffi8 | `3.4.4-1` | amd64 |
| libgssapi-krb5-2 | `1.20.1-2+deb12u5` | amd64 |
| liblzma5 | `5.4.1-1+deb12u1` | amd64 |
| libncursesw6 | `6.4-4` | amd64 |
| libreadline8 | `8.2-1.3` | amd64 |
| libsqlite3-0 | `3.40.1-2+deb12u2` | amd64 |
| libssl3 | `3.0.20-1~deb12u2` | amd64 |
| libtinfo6 | `6.4-4` | amd64 |
| libuuid1 | `2.38.1-5+deb12u3` | amd64 |
| openssl | `3.0.20-1~deb12u2` | amd64 |
| zlib1g | `1:1.2.13.dfsg-1` | amd64 |

### 8.4 Ambiguity

Both `media-types=10.0.0` and `mime-support=3.66` satisfy `media-types | mime-support`. Repository order, lexical order, and resolver defaults are prohibited selection mechanisms. Both candidates remain `UNRESOLVED`.

## 9. Protected drift

- Protected-package additions, removals, upgrades, or downgrades selected: zero.
- Second libpq lineage selected: no.
- Applicable Breaks/Conflicts/Replaces against the protected package set: zero.
- Protected relationship disposition: `PASS-ZERO-DRIFT`.
- Protected file collision disposition: `UNRESOLVED-BINARY-PACKAGE-INDEXES-DO-NOT-CONTAIN-FILE-LISTS`.
- Overall: `HOLD-PROTECTED-FILE-COLLISION-ANALYSIS-INCOMPLETE`.

The protected paths include libpq `libpq.so.5`/`libpq.so.5.18` and the accepted `psql`, `pg_dump`, `pg_restore`, and PostgreSQL 15 binary paths. Signed Debian Contents metadata or separately authorized body inspection is required to prove absence of ownership collisions.

## 10. Psycopg official metadata

- Filename: `psycopg-3.2.9-py3-none-any.whl`
- Size: 202705 bytes
- SHA-256: `01a8dadccdaac2123c916208c96e06631641c0566b22005493f09663c7a8d3b6`
- Requires-Python: `>=3.8`
- Yanked: `false`
- Tags: `py3-none-any`.
- Core metadata sidecar SHA-256: `9b2a745b662478d264d842af579ba44ea5660a0f40324e52ca2f18bdaf9478e1` (advertised hash matched).
- Binding filename, size, and SHA-256 matched exactly.
- Selected extras: none. `psycopg-c` and `psycopg-binary` are inactive and prohibited.

### 10.1 Complete known Requires-Dist

- `backports.zoneinfo>=0.2.0; python_version < "3.9"` -> marker result `FALSE`
- `typing-extensions>=4.6; python_version < "3.13"` -> marker result `TRUE`
- `tzdata; sys_platform == "win32"` -> marker result `FALSE`
- `psycopg-c==3.2.9; implementation_name != "pypy" and extra == "c"` -> marker result `FALSE`
- `psycopg-binary==3.2.9; implementation_name != "pypy" and extra == "binary"` -> marker result `FALSE`
- `psycopg-pool; extra == "pool"` -> marker result `FALSE`
- `anyio>=4.0; extra == "test"` -> marker result `FALSE`
- `mypy>=1.14; extra == "test"` -> marker result `FALSE`
- `pproxy>=2.7; extra == "test"` -> marker result `FALSE`
- `pytest>=6.2.5; extra == "test"` -> marker result `FALSE`
- `pytest-cov>=3.0; extra == "test"` -> marker result `FALSE`
- `pytest-randomly>=3.5; extra == "test"` -> marker result `FALSE`
- `ast-comments>=1.1.2; extra == "dev"` -> marker result `FALSE`
- `black>=24.1.0; extra == "dev"` -> marker result `FALSE`
- `codespell>=2.2; extra == "dev"` -> marker result `FALSE`
- `dnspython>=2.1; extra == "dev"` -> marker result `FALSE`
- `flake8>=4.0; extra == "dev"` -> marker result `FALSE`
- `isort[colors]>=6.0; extra == "dev"` -> marker result `FALSE`
- `isort-psycopg; extra == "dev"` -> marker result `FALSE`
- `mypy>=1.14; extra == "dev"` -> marker result `FALSE`
- `pre-commit>=4.0.1; extra == "dev"` -> marker result `FALSE`
- `types-setuptools>=57.4; extra == "dev"` -> marker result `FALSE`
- `types-shapely>=2.0; extra == "dev"` -> marker result `FALSE`
- `wheel>=0.37; extra == "dev"` -> marker result `FALSE`
- `Sphinx>=5.0; extra == "docs"` -> marker result `FALSE`
- `furo==2022.6.21; extra == "docs"` -> marker result `FALSE`
- `sphinx-autobuild>=2021.3.14; extra == "docs"` -> marker result `FALSE`
- `sphinx-autodoc-typehints>=1.12; extra == "docs"` -> marker result `FALSE`

The only active requirement is `typing-extensions>=4.6; python_version < "3.13"`.

## 11. Fixed marker environment

- `dependency_groups` = `[]`
- `extra` = `""`
- `extras` = `[]`
- `implementation_name` = `"cpython"`
- `implementation_version` = `"3.11.2"`
- `os_name` = `"posix"`
- `platform_machine` = `"x86_64"`
- `platform_python_implementation` = `"CPython"`
- `platform_release` = `"NOT-REQUIRED-BY-CAPTURED-METADATA"`
- `platform_system` = `"Linux"`
- `platform_version` = `"NOT-REQUIRED-BY-CAPTURED-METADATA"`
- `python_full_version` = `"3.11.2"`
- `python_version` = `"3.11"`
- `sys_platform` = `"linux"`

No captured active marker depended on the kernel release or kernel version fields.

## 12. typing-extensions candidates

| Version | Wheel | Bytes | SHA-256 | Requires-Python |
|---|---|---:|---|---|
| 4.6.0 | `typing_extensions-4.6.0-py3-none-any.whl` | 30680 | `6ad00b63f849b7dcc313b70b6b304ed67b2b2963b3098a33efe18056b1a9a223` | `>=3.7` |
| 4.6.1 | `typing_extensions-4.6.1-py3-none-any.whl` | 31091 | `6bac751f4789b135c43228e72de18637e9a6c29d12777023a703fd1a6858469f` | `>=3.7` |
| 4.6.2 | `typing_extensions-4.6.2-py3-none-any.whl` | 31131 | `3a8b36f13dd5fdc5d1b16fe317f5668545de77fa0b8e02006381fd49d731ab98` | `>=3.7` |
| 4.6.3 | `typing_extensions-4.6.3-py3-none-any.whl` | 31329 | `88a4153d8505aabbb4e13aacb7c486c2b4a33ca3b3f807914a9b4c844c471c26` | `>=3.7` |
| 4.7.0 | `typing_extensions-4.7.0-py3-none-any.whl` | 33023 | `5d8c9dac95c27d20df12fb1d97b9793ab8b2af8a3a525e68c80e21060c161771` | `>=3.7` |
| 4.7.1 | `typing_extensions-4.7.1-py3-none-any.whl` | 33232 | `440d5dd3af93b060174bf433bccd69b0babc3b15b1a8dca43789fd7f61514b36` | `>=3.7` |
| 4.8.0 | `typing_extensions-4.8.0-py3-none-any.whl` | 31584 | `8f92fc8806f9a6b641eaa5318da32b44d401efaac0f6678c9bc448ba3605faa0` | `>=3.8` |
| 4.9.0 | `typing_extensions-4.9.0-py3-none-any.whl` | 32750 | `af72aea155e91adfc61c3ae9e0e342dbc0cba726d6cba4b6c72c1f34e47291cd` | `>=3.8` |
| 4.10.0 | `typing_extensions-4.10.0-py3-none-any.whl` | 33926 | `69b1a937c3a517342112fb4c6df7e72fc39a38e7891a5730ed4985b5214b5475` | `>=3.8` |
| 4.11.0 | `typing_extensions-4.11.0-py3-none-any.whl` | 34698 | `c1f94d72897edaf4ce775bb7558d5b79d8126906a14ea5ed1635921406c0387a` | `>=3.8` |
| 4.12.0 | `typing_extensions-4.12.0-py3-none-any.whl` | 37104 | `b349c66bea9016ac22978d800cfff206d5f9816951f12a7d0ec5578b0a819594` | `>=3.8` |
| 4.12.1 | `typing_extensions-4.12.1-py3-none-any.whl` | 37250 | `6024b58b69089e5a89c347397254e35f1bf02a907728ec7fee9bf0fe837d203a` | `>=3.8` |
| 4.12.2 | `typing_extensions-4.12.2-py3-none-any.whl` | 37438 | `04e5ca0351e0f3f85c6853954072df659d0d13fac324d0072316b67d7794700d` | `>=3.8` |
| 4.13.0 | `typing_extensions-4.13.0-py3-none-any.whl` | 45683 | `c8dd92cc0d6425a97c18fbb9d1954e5ff92c1ca881a309c45f06ebc0b79058e5` | `>=3.8` |
| 4.13.1 | `typing_extensions-4.13.1-py3-none-any.whl` | 45739 | `4b6cf02909eb5495cfbc3f6e8fd49217e6cc7944e145cdda8caa3734777f9e69` | `>=3.8` |
| 4.13.2 | `typing_extensions-4.13.2-py3-none-any.whl` | 45806 | `a439e7c04b49fec3e5d3e2beaa21755cadbbdc391694e28ccdd36ca4a1408f8c` | `>=3.8` |
| 4.14.0 | `typing_extensions-4.14.0-py3-none-any.whl` | 43839 | `a1514509136dd0b477638fc68d6a91497af5076466ad0fa6c338e44e359944af` | `>=3.9` |
| 4.14.1 | `typing_extensions-4.14.1-py3-none-any.whl` | 43906 | `d1e1e3b58374dc93031d6eda2420a48ea44a36c2b4766a4fdeb3710755731d76` | `>=3.9` |
| 4.15.0 | `typing_extensions-4.15.0-py3-none-any.whl` | 44614 | `f0fa19c6845758ab08074a0cfa8b7aecb71c999ca73d62883bc25cc018c4e548` | `>=3.9` |
| 4.16.0 | `typing_extensions-4.16.0-py3-none-any.whl` | 45571 | `481caa481374e813c1b176ada14e97f1f67a4539ce9cfeb3f350d78d6370c2e8` | `>=3.9` |

Minimum stable satisfying candidate: `4.6.0`.
Highest stable at capture: `4.16.0`.
Recommendation: `typing-extensions==4.16.0` because it is the highest stable pure wheel in the fixed metadata boundary and exposes no active dependencies. This is a recommendation, not approval.

## 13. Recursive wheel proposal

- `psycopg==3.2.9` -> `typing-extensions==4.16.0` under the fixed marker environment.
- Both nodes are `FINAL-RUNTIME`, `UNACQUIRED`, and `UNINSPECTED`.
- Source distributions selected: zero.
- Native wheels selected: zero.
- Binary Psycopg implementations selected: zero.
- Wheel body `METADATA` remains authoritative only after a separately authorized body inspection.

## 14. Proposed dependency manifest

- Path: `derived/dependency-manifest.proposed.json`.
- File size: 104091 bytes.
- File SHA-256: `e9e8161e308d1ba6fb686aa4ab9835c27867b814dab271b5fa8f46ceca9ba5c1`.
- Canonical manifest-payload input: 73061 bytes.
- Canonical manifest-payload SHA-256: `7d2bd2e54c9e48947ef76fdfff49254caf74df77684a5ea1ef5a6bf8e9783b58`.
- Artifact records: 37.
- All proposed artifact bodies remain `UNACQUIRED`; all body inspections remain `UNINSPECTED`; BUILD is `NOT-BEGUN`.

## 15. Metadata limitations and findings

- RBF-01: `OPEN`
- RBF-02: `OPEN`
- RBF-03: `RESOLVED`
- RBF-04: `OPEN`
- RBF-05: `OPEN`
- RBF-06: `OPEN`
- RBF-07: `DESIGN-DECIDED-ACCEPT-18.4-RUNTIME-VALIDATION-OPEN`
- RBF-08: `OPEN`
- RBF-09: `OPEN-NARROWED-SNAPSHOT-IDENTITIES-VERIFIED-DEBIAN-ALTERNATIVE-UNRESOLVED`
- RBF-10: `OPEN-NARROWED-FINITE-WHEEL-CANDIDATES-EXACT-SELECTION-UNAPPROVED`
- RBF-11: `OPEN`
- RBF-12: `OPEN-PROTECTED-FILE-COLLISION-METADATA-UNAVAILABLE`

New distinct finding: `RBF-12 OPEN-PROTECTED-FILE-COLLISION-METADATA-UNAVAILABLE`.

The Debian Security payload has an accepted Bookworm Security signature and one additional unknown signature. The unknown signature was rejected and is not a trust anchor. Package maintainer scripts, triggers, conffiles, archive members, RECORD files, and package file ownership remain uninspected because bodies were not acquired.

## 16. External evidence identity

- Regular evidence files: 74.
- Total bytes: 90226443.
- `EVIDENCE-CONTEXT.md`: 3878 bytes; SHA-256 `6c485dd4f3159253494e55e89fc49cb5ceff27d419e62b4047d1a843c8705273`.
- `SHA256SUMS`: 7995 bytes; SHA-256 `6d912ddcbc34e9ba99629a678e328a5657169d5531d2e2ad7e3ae4da897edcb7`; 73 entries reproduced.

## 17. Next gate

Recommend exactly:

`PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-ACQUIRE-PRE-R2-CONTENTS-PROTECTED-PATHS`

That gate should remain metadata-only, authorize the exact signed Debian Contents indexes needed for protected-path collision analysis, and require an explicit Product Lead decision for `media-types | mime-support` and the exact typing-extensions candidate. It must not acquire package bodies or begin BUILD.

## 18. Non-activity statement

No `.deb`, `.udeb`, wheel, sdist, image, source archive, VCS object, or other prohibited artifact body was acquired. No Docker operation, package installation, package-manager execution, image build, database access, runner, harness, fixture, migration, or test operation occurred. No existing repository or external-evidence file was modified. Nothing was staged or committed. No later gate began.
