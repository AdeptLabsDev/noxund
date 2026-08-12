# PG Exit P3C Execute Pre - Dependency Closure Acquire R1

## 1. Decision

ACQUIRE-R1-COMPLETE-BODIES-VERIFIED-UNINSPECTED

Exactly 21 manifest-listed bodies were allowlisted. Verified acquisition totals are 21 overall, 19 Debian .deb bodies, and 2 wheels. All remain UNINSPECTED and BUILD remains NOT-BEGUN.

## 2. Source and binding evidence

- Worktree: C:/Adeptlabs/noxund-p3c-execute-pre
- Branch: spike/pg-exit-p3c-execute-pre
- HEAD: 4873ac713397cf47642d39b1ef17e48a9301511d
- Pre-existing subtree: 57 files, 314557 bytes, canonical input 6240 bytes, SHA-256 bb7236afcd542af359a0bd60a7e4667802fe37de717386b645c9a67a052defb9.
- R1 evidence: 74 files, 90226443 bytes, SHA256SUMS 6d912ddcbc34e9ba99629a678e328a5657169d5531d2e2ad7e3ae4da897edcb7; reproduced PASS.
- R2 evidence: 13 files, 225246 bytes, SHA256SUMS e88a8102a84d409582e51143854db03cac91af76c65996eacf21c715651ba95d; reproduced PASS.
- R3 evidence: 18 files, 45912187 bytes, canonical SHA-256 8fc01384b9e86706de5275a3a737c289276a5794118f7b1d14f8614c35b0fcb3, SHA256SUMS 5dccd36a55c974cac085a0efc02a3e1a452558d42bf775bc0249f25e055a33e1; reproduced PASS.
- R3 proposed manifest: 121235 bytes, SHA-256 37e0e50ed29c46d6ba4f2ac3b5bed2eb8b3ef738ea774ef8397329e4cc6f4fce; canonical payload 86945 bytes, SHA-256 bac227265430e9734a5a454ba24a6a88e20d6cd865589dbacd0956d748b4505a.
- R3 closure: 17 BASE-R9, 19 DEBIAN-MAIN, zero DEBIAN-SECURITY, zero unknown; 17 KEEP-BASE, 9 INSTALL-FINAL-RUNTIME, 10 INSTALL-BUILD-ONLY.

## 3. Network and acquisition boundary

Contacted domains: files.pythonhosted.org, snapshot.debian.org.

Only the exact URLs carried by the accepted R3 manifest were requested. Debian URLs used the immutable 20260713T202617Z snapshot. Wheel URLs used their preserved files.pythonhosted.org identities. No index, metadata endpoint, mutable mirror, key server, PyPI page, package manager, Docker service, database, or registry was contacted.

Transfers used binary streaming to .partial files while counting bytes and hashing SHA-256. Successful files were flushed, closed, atomically renamed, and independently rehashed. Bodies were not decoded, listed, parsed, extracted, executed, or installed.

## 4. Complete allowlist

01. debian | ca-certificates | 20230311+deb12u1 | all | ca-certificates_20230311+deb12u1_all.deb | 155260 | 0d5f444f594e48c1e16a41d8fc628a09b24c658916a1274025c2330f2a802bed
02. debian | libexpat1 | 2.5.0-1+deb12u2 | amd64 | libexpat1_2.5.0-1+deb12u2_amd64.deb | 99888 | 2255e62fc22a86d2c544b8a3f516da9aee19383ad5742722ab4ce7f66a30dbc8
03. debian | libnsl2 | 1.3.0-2 | amd64 | libnsl2_1.3.0-2_amd64.deb | 39480 | c0d83437fdb016cb289436f49f28a36be44b3e8f1f2498c7e3a095f709c0d6f8
04. debian | libpython3-stdlib | 3.11.2-1+b1 | amd64 | libpython3-stdlib_3.11.2-1+b1_amd64.deb | 9312 | 4e58891d5c951a1e360ed9eaa814413cb5e84deadce3f08e801ac680434c786e
05. debian | libpython3.11-minimal | 3.11.2-6+deb12u8 | amd64 | libpython3.11-minimal_3.11.2-6+deb12u8_amd64.deb | 817740 | f3beaa03994ffedacf73c43a0843d53b062d347115d8af65bee2034552a4e6f9
06. debian | libpython3.11-stdlib | 3.11.2-6+deb12u8 | amd64 | libpython3.11-stdlib_3.11.2-6+deb12u8_amd64.deb | 1798560 | 890b3540dad8a1ccc0deeca025db735bcc82629a76adacbe3b50fcc06ed528ca
07. debian | libtirpc-common | 1.3.3+ds-1 | all | libtirpc-common_1.3.3+ds-1_all.deb | 14048 | 3e3ef129b4bf61513144236e15e1b4ec57fa5ae3dc8a72137abdbefb7a63af85
08. debian | libtirpc3 | 1.3.3+ds-1 | amd64 | libtirpc3_1.3.3+ds-1_amd64.deb | 85192 | 2a46d5a5e9486da11ffeff5740931740d6deae4f92cd6098df060dc5dff1e1c7
09. debian | media-types | 10.0.0 | all | media-types_10.0.0_all.deb | 26136 | aaa46dcb3b39948ae2e0fdb72cfcb2f48c0b59f19785a3da8045c05eb19955dd
10. debian | python3 | 3.11.2-1+b1 | amd64 | python3_3.11.2-1+b1_amd64.deb | 26300 | 33f6dafbd1a6902d9063172ec7dbd4b2225e12009e0d7ec5c933a72c2f5f3b74
11. debian | python3-distutils | 3.11.2-3 | all | python3-distutils_3.11.2-3_all.deb | 130936 | a620b555f301860a08e30534c7e6f7d79818e5e1977bfec39a612e7003074318
12. debian | python3-lib2to3 | 3.11.2-3 | all | python3-lib2to3_3.11.2-3_all.deb | 76284 | 4e7f5e01e49a0622d10db3d0995666a6ead6a369cd127a996e9a4f9e91696a51
13. debian | python3-minimal | 3.11.2-1+b1 | amd64 | python3-minimal_3.11.2-1+b1_amd64.deb | 26312 | 30f9618670e686d781afbfc713eb0830c29d2819e9cb2a0488800dad6bb99faa
14. debian | python3-pip | 23.0.1+dfsg-1 | all | python3-pip_23.0.1+dfsg-1_all.deb | 1324972 | d8024ededc6c7fe941ca96aabebdcf2d846fd130eae9d66aad1aa32a84454291
15. debian | python3-pkg-resources | 66.1.1-1+deb12u2 | all | python3-pkg-resources_66.1.1-1+deb12u2_all.deb | 296604 | 25dfb378939ccdf27e7382adf44c168f86e22f9f1a8e6e3a2ec526431ed5e30f
16. debian | python3-setuptools | 66.1.1-1+deb12u2 | all | python3-setuptools_66.1.1-1+deb12u2_all.deb | 521580 | 96f934b8dbe4367c4cf9e4c740aa5c85f9a9ac8875a16556c8677fb342c7838f
17. debian | python3-wheel | 0.38.4-2 | all | python3-wheel_0.38.4-2_all.deb | 30808 | 623a8f7c70ba713b0d8d5a321f157405861f0a0b1a652edad2cda5f70f5773f9
18. debian | python3.11 | 3.11.2-6+deb12u8 | amd64 | python3.11_3.11.2-6+deb12u8_amd64.deb | 574236 | cd7b10c24281416a6acb22cd23ed7391c7dddd4a3d4d4a63d37faa786639b5de
19. debian | python3.11-minimal | 3.11.2-6+deb12u8 | amd64 | python3.11-minimal_3.11.2-6+deb12u8_amd64.deb | 2064968 | 4aba533f7cc5e7b93b7ff24482840e96813f5bcde9cce028395b65a0d799ccee
20. wheel | psycopg | 3.2.9 | py3-none-any | psycopg-3.2.9-py3-none-any.whl | 202705 | 01a8dadccdaac2123c916208c96e06631641c0566b22005493f09663c7a8d3b6
21. wheel | typing-extensions | 4.16.0 | py3-none-any | typing_extensions-4.16.0-py3-none-any.whl | 45571 | 481caa481374e813c1b176ada14e97f1f67a4539ce9cfeb3f350d78d6370c2e8

## 5. Transfer results

01. debian:ca-certificates:20230311+deb12u1:all | attempts=2 | ACQUIRED-VERIFIED | PASS
02. debian:libexpat1:2.5.0-1+deb12u2:amd64 | attempts=1 | ACQUIRED-VERIFIED | PASS
03. debian:libnsl2:1.3.0-2:amd64 | attempts=1 | ACQUIRED-VERIFIED | PASS
04. debian:libpython3-stdlib:3.11.2-1+b1:amd64 | attempts=1 | ACQUIRED-VERIFIED | PASS
05. debian:libpython3.11-minimal:3.11.2-6+deb12u8:amd64 | attempts=1 | ACQUIRED-VERIFIED | PASS
06. debian:libpython3.11-stdlib:3.11.2-6+deb12u8:amd64 | attempts=1 | ACQUIRED-VERIFIED | PASS
07. debian:libtirpc-common:1.3.3+ds-1:all | attempts=1 | ACQUIRED-VERIFIED | PASS
08. debian:libtirpc3:1.3.3+ds-1:amd64 | attempts=1 | ACQUIRED-VERIFIED | PASS
09. debian:media-types:10.0.0:all | attempts=1 | ACQUIRED-VERIFIED | PASS
10. debian:python3:3.11.2-1+b1:amd64 | attempts=1 | ACQUIRED-VERIFIED | PASS
11. debian:python3-distutils:3.11.2-3:all | attempts=1 | ACQUIRED-VERIFIED | PASS
12. debian:python3-lib2to3:3.11.2-3:all | attempts=1 | ACQUIRED-VERIFIED | PASS
13. debian:python3-minimal:3.11.2-1+b1:amd64 | attempts=1 | ACQUIRED-VERIFIED | PASS
14. debian:python3-pip:23.0.1+dfsg-1:all | attempts=1 | ACQUIRED-VERIFIED | PASS
15. debian:python3-pkg-resources:66.1.1-1+deb12u2:all | attempts=1 | ACQUIRED-VERIFIED | PASS
16. debian:python3-setuptools:66.1.1-1+deb12u2:all | attempts=1 | ACQUIRED-VERIFIED | PASS
17. debian:python3-wheel:0.38.4-2:all | attempts=1 | ACQUIRED-VERIFIED | PASS
18. debian:python3.11:3.11.2-6+deb12u8:amd64 | attempts=1 | ACQUIRED-VERIFIED | PASS
19. debian:python3.11-minimal:3.11.2-6+deb12u8:amd64 | attempts=1 | ACQUIRED-VERIFIED | PASS
20. wheel:psycopg:3.2.9:py3-none-any | attempts=1 | ACQUIRED-VERIFIED | PASS
21. wheel:typing-extensions:4.16.0:py3-none-any | attempts=1 | ACQUIRED-VERIFIED | PASS

- Total attempts: 22.
- Failed or unacquired: 0.
- Unexpected artifacts: 0.
- Remaining .partial files: 0.
- Inspection state: UNINSPECTED.
- Build state: NOT-BEGUN.

## 6. Evidence identities

- acquisition-allowlist-r1.json: 28783 bytes; SHA-256 a62f7213001218acb0ae8f17ae1408b983775e74392d52520bae2b67114e6e03.
- transfer-ledger-r1.jsonl: 27546 bytes; SHA-256 898ca112e2866b69651cd34e5c75094db4d47e1bc49818d8544fa057acb945d2.
- body-inventory-r1.tsv: 12467 bytes; SHA-256 309f5d1b6f7053439288a63600b84099cc84dd837ddd8b286c1da408268874fe.
- acquisition-result-r1.json: 879 bytes; SHA-256 a3b68f019c314930cca16870eadbf0da84437198e3ae6e8cbd704d18a0869d3e.
- dependency-manifest.acquired-r1.json: 129718 bytes; SHA-256 0105661f55b6b59bc87465434a3231a44950518936c509f55e2e7b8354625c52.
- Acquired-manifest canonical payload: 94334 bytes; SHA-256 e7acd191cde883e65448200e0538a4877ce5f87e917aa974e00f2681a0de4c37.
- metadata-limitations-r1.json: 702 bytes; SHA-256 85ee10f93d126750aba182ccb7794d9aed42f67e56c4fc1ee2642eb8bbe478c9.
- External SHA256SUMS: 5421 bytes; 51 entries; SHA-256 20c16bdc52010f2455a3797b17f1f42e436d413dd4b32af7283e16cfa51888a5.

## 7. Secret review

PASS. The review was restricted to URLs, selected response headers, generated evidence, and local paths. No credential-bearing header was retained, no body content was inspected, and no real secret was found.

## 8. Findings

- RBF-01 OPEN.
- RBF-02 RBF-02-OPEN-NARROWED-EXACT-WHEEL-BODIES-ACQUIRED-UNINSPECTED.
- RBF-03 RESOLVED.
- RBF-04 OPEN.
- RBF-05 OPEN.
- RBF-06 OPEN.
- RBF-07 design-decided with runtime validation open.
- RBF-08 OPEN.
- RBF-09 RBF-09-OPEN-NARROWED-EXACT-DEBIAN-BODIES-ACQUIRED-UNINSPECTED.
- RBF-10 RBF-10-OPEN-NARROWED-EXACT-WHEEL-BODIES-ACQUIRED-UNINSPECTED.
- RBF-11 OPEN.
- RBF-12 RBF-12-OPEN-NARROWED-METADATA-ZERO-COLLISION-BODIES-UNINSPECTED.
- RBF-13 OPEN, nonblocking.

## 9. Limitations and next gate

All bodies remain UNINSPECTED. Archive structure, Debian control metadata, complete file inventories, wheel METADATA/WHEEL/RECORD, protected-path non-collision, and recursive closure are not proven by acquisition.

Exact next-gate recommendation: PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-ARTIFACT-INSPECT-R1

That gate did not begin. BUILD remains unauthorized.

## 10. Scope confirmation

No existing repository document or R1/R2/R3 evidence file was modified. Nothing was staged or committed. No non-allowlisted body was acquired. No body was inspected, extracted, executed, or installed. No Docker, image build, database, runner, harness, fixture, migration, or test operation occurred. The known .rar was checked by path only and remained untouched.
