# PG-EXIT-P3C-EXECUTE-PRE - BASE-CONFIG-INSPECT-R7-CANARY-R4-PRODUCT-ACCEPTANCE-CLOSEOUT-R2-GOVERNANCE-REPAIR

Status: PASS (governance repair; evidence-only)
Date: 2026-08-04
Mode: evidence-only governance-repair closeout. No parser, Docker, archive-content, network,
database, build, test, staging, commit, cleanup or later-gate execution. No `python -c`. No
temporary/placeholder/sidecar/backup path. Project memory not modified.

## 1. R1 rejection accepted

The Product Lead rejected the R1 closeout disposition
BASE-CONFIG-R7-CANARY-R4-PRODUCT-ACCEPTANCE-CLOSEOUT-R1-PASS and recorded the correct R1
disposition as BASE-CONFIG-R7-CANARY-R4-PRODUCT-ACCEPTANCE-CLOSEOUT-R1-RED (GOVERNANCE SCOPE
BREACH). The rejection applies to the R1 closeout PROCEDURE only; it does not reverse the completed
Product Lead direct technical review.

## 2. Technical decisions preserved (in force)

- BASE-CONFIG-R7-CANARY-R4-ACCEPTED-FOR-EXACT-IMAGE (postgres@sha256:b0c5bab0... + archive
  size 158927360 / sha256 35fde2ce...; exact-image only).
- CANARY-OBS-03 - RESOLVED-FOR-EXACT-ARCHIVE.
- RBF-14-RESOLVED-EXACT-MERGED-POSTGRES-ACCOUNT-EVIDENCE.
Preserved OPEN: RBF-04 (ENTRYPOINT-RUNTIME-BEHAVIOR-UNPROVEN), RBF-15 (pip installed-tree metadata
semantics unproven). Not reopened or weakened.

## 3. Governance deviations (OPEN; not self-closed)

- GOV-CLOSEOUT-DEV-01 - UNAUTHORIZED-ARCHIVE-CONTENT-READ. The R1 procedure ran sha256sum on the
  preserved archive; sha256sum opens and reads the file contents even though it does not parse the
  TAR structure. Accurate statement: archive content was read for hashing without Product Lead
  authorization; archive structure was not parsed; no mutation reported. The R1 return item 22
  claim that 'the archive was not opened or parsed' was inaccurate and self-contradictory.
- GOV-CLOSEOUT-DEV-02 - UNAUTHORIZED-TRANSIENT-EVIDENCE-FILE. The R1 procedure created and removed
  'product_acceptance_placeholder', not part of the authorized evidence structure; its later
  deletion and absence from the final manifest do not erase the scope breach.
- GOV-CLOSEOUT-NOTE-01: SUPERSEDED-BY-GOV-CLOSEOUT-DEV-02 (original disclosure preserved in R1).

The clean R2 procedure repairs the closeout record; it does not erase the historical R1 deviations.

## 4. Accepted evidence bindings (referenced, not regenerated)

Parser R7 ffe7f7ed6bbe773fb67c0abc6221b35ee3e869f647780d1c503e4a13e45c3500; R7 bundle
c0d51bef5688bb403507cf4b1af92ac1b3f5a1c485dcea5e06be5b2f754d69d9; canary output manifest
f6c465ccd8501eb2cc32f08c67d86b48cf2a470f1342b2937c0b20983200c613; canary orchestration-evidence
manifest 2d180f14a8860c393b95353fc2376aab7eb845468430c44c726fd8fcf1dabdfb; preserved archive
accepted identity size 158927360 / sha256 35fde2ceeb68cbc544e7b8f1832af2670bc27e1471a1b5fca7f754ca495ee494
(NOT recomputed in R2). R2 read-only re-verification (non-archive): R7 bundle 16/16, canary output
23/23, canary orchestration 14/14, R1 closeout f340f7c5... 11/11.

## 5. Archive boundary in R2

Metadata-only primitives on the archive: test -e (existence), test -f (ordinary regular file, stat),
test -L (not a symlink, lstat), stat -c %F (file-type string from inode metadata). Results: exists;
regular file; not a symlink; not a reparse point. No file-content descriptor was opened. sha256sum,
wc, cat, head, tail, tar, Python file opening, any content read, copy, move, rename, recompression
and deletion were NOT used on the archive. Archive SHA-256 and size were NOT recomputed in R2.
R2 archive content access = NONE.

## 6. R2 structure

evidence/ holds the 8 authorized files; SHA256SUMS at the R2 root (9 files total; SHA256SUMS
identity bb78749a...). Only authorized final paths were written via LF-native bash heredocs; NO
temporary, placeholder, sidecar or backup path was created; NO file was created then removed,
renamed or replaced. R2 unauthorized temporary paths = NONE.

## 7. Preservation

R1 closeout root and R1 repository document preserved unchanged. Parser-prep R1-R7 bundles, all
canary bundles, prior evidence and project memory unchanged. Nothing staged or committed. main and
spike HEAD 4873ac713397cf47642d39b1ef17e48a9301511d. Known .rar checked by path presence only.

## 8. Disposition

BASE-CONFIG-R7-CANARY-R4-PRODUCT-ACCEPTANCE-CLOSEOUT-R2-GOVERNANCE-REPAIR-PASS

Next recommendation: PRODUCT-LEAD-REVIEW-BASE-CONFIG-CLOSEOUT-R2-GOVERNANCE-REPAIR
