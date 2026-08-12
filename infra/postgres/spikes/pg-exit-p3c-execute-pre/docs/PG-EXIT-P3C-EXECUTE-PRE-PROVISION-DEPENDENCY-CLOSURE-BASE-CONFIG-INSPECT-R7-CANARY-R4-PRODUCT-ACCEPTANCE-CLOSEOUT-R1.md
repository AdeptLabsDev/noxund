# PG-EXIT-P3C-EXECUTE-PRE - BASE-CONFIG-INSPECT-R7-CANARY-R4-PRODUCT-ACCEPTANCE-CLOSEOUT-R1

Status: PASS (Product acceptance closeout; evidence-only)
Date: 2026-08-04
Mode: evidence-only Product acceptance closeout. No parser, Docker, archive, network, database,
build, test, staging, commit, cleanup or later-gate execution. No `python -c`. Project memory not
modified. Read-only re-verification of bound identities only.

## 1. Product Lead decision

BASE-CONFIG-R7-CANARY-R4-ACCEPTED-FOR-EXACT-IMAGE. The direct Product review reproduced a 39-file
ZIP (SHA-256 693d603d21b048fd6f4e8cc0b2c49cbdc37f3ec67e8ea5d5dca30c0b82b6e17f; 24 parser-output +
15 orchestration-evidence; zero unsafe ZIP path / symlink / duplicate member; exact R7
OUTPUT-SCHEMA inventory; output manifest f6c465cc... 23/23; orchestration manifest 2d180f14...
14/14; output inventory 24/24 size + SHA-256).

## 2. Orchestrator local re-verification (read-only)

- Parser base-config-inspect-r3-r7.py - 113406 bytes, 2177 lines,
  sha256 ffe7f7ed6bbe773fb67c0abc6221b35ee3e869f647780d1c503e4a13e45c3500 (match).
- R7 bundle SHA256SUMS c0d51bef... 16/16.
- Canary output manifest f6c465cc... 23/23.
- Orchestration-evidence manifest 2d180f14... 14/14.
- Output inventory 24/24 reproduced (0 mismatches).
- Preserved archive 35fde2ce... / 158927360 unchanged (not opened).

## 3. Accepted exact-image result

selected_runtime_closure = VERIFIED; immutable_base_predicates = PASS; entrypoint_runtime_behavior
= ENTRYPOINT-RUNTIME-BEHAVIOR-UNPROVEN; attestation_manifest_closure =
ATTESTATION-MANIFEST-CLOSURE-INCOMPLETE-REFERENCED-BLOB-ABSENT; attestation_child_closure =
UNVERIFIED; full_index_closure = NOT-VERIFIED. Acceptance applies ONLY to
postgres@sha256:b0c5bab0... and archive size 158927360 / sha256 35fde2ce...; NOT broadened to
another image, digest, archive representation or the direct-manifest path.

## 4. Selected-runtime ledger acceptance

1 repodigest-index + 1 image-manifest + 1 config + 14 layers = 17 rows, all VERIFIED /
size_match True / digest_match True / selected_runtime_dependency True; four-way totals
17 == 17 == 17 == 17.

## 5. Attestation and full-index limitations

Attestation 0cc14c21 = REFERENCED-BUT-ABSENT-IN-LOCAL-SAVE (observed null; manifest_verified False;
non-blocking). Index siblings: 1 selected + 7 unselected platform + 8 attestation; 0 unsupported.
full_index_closure NOT-VERIFIED (reasons: absent attestation, attestation child unverified,
unselected platform unverified). Trust-chain authority: selected_runtime_measurements +
blob-ledger-r7.tsv + record-derived totals + descriptor digest/size matches.

## 6. CANARY-OBS-03 closure

CANARY-OBS-03 - RESOLVED-FOR-EXACT-ARCHIVE. Root alias observed '.'; cumulative processing count 2
across 2 fixed-point rescans; count by layer sequence {"0": 2}; every accepted header a zero-size
directory; no root-like non-directory encountered; no empty/'/' path in overlay, tracked paths,
referenced identities, interpreter paths or helper paths; alias-name evidence not saturated.
Cumulative processing count (2) != unique physical archive-header count.

## 7. RBF-14 closure

RBF-14-RESOLVED-EXACT-MERGED-POSTGRES-ACCOUNT-EVIDENCE. postgres uid 999, primary gid 999, group
postgres, supplementary ssl-cert:101, home /var/lib/postgresql, shell /bin/bash; 0 malformed
records; 0 duplicate postgres names/uids; 0 duplicate primary/supplementary group names/gids
affecting postgres; PGDATA /var/lib/postgresql/data is a directory uid/gid 999/999. Proves exact
merged account + PGDATA identity facts; does NOT prove the entrypoint runtime privilege transition.

## 8. Preserved findings

- RBF-04 OPEN (ENTRYPOINT-RUNTIME-BEHAVIOR-UNPROVEN). R7-BN-03: entrypoint static observation labels
  are non-authoritative (final_exec / server_start_behavior may match an internal '-exec' line);
  they may not prove branch selection, effective runtime UID, privilege transition, final command
  execution or runtime success.
- RBF-15 OPEN (pip installed-tree metadata semantics unproven; not inspected here).
- R7-BN-04: raw/docker JSON outputs are normalized evidence renderings, not necessarily
  byte-identical to CAS blobs; the exact retained-byte guarantee applies to passwd, group and
  entrypoint only.
- R6-BN-01/02/03 and R7-BN-01/02 satisfied. RBF-01/05/06/07(runtime)/08/11/13(nonblocking) OPEN.

## 9. Preservation and process

Archive preserved (cleanup requires a separate Product Lead authorization after this closeout is
accepted). Parser-prep R1-R7 bundles, all canary bundles, prior evidence and project memory
unchanged. Nothing staged or committed. Known .rar checked by path presence only. Closeout root
C:/Adeptlabs/noxund-p3c-base-config-inspect-r7-canary-r4-product-acceptance-closeout-r1 (12 files;
SHA256SUMS f340f7c5..., 11/11). Process note GOV-CLOSEOUT-NOTE-01: one transient placeholder file
was created and immediately removed inside the evidence dir during authoring (no persisted data;
final dir exactly the authorized files); disclosed for transparency.

## 10. Disposition

BASE-CONFIG-R7-CANARY-R4-PRODUCT-ACCEPTANCE-CLOSEOUT-R1-PASS

Next recommendation: PRODUCT-LEAD-REVIEW-BASE-CONFIG-CLOSEOUT-R1
