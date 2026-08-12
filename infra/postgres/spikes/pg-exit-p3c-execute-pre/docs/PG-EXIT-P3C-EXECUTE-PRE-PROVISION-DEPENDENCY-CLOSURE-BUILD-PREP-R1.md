# PG Exit P3C Execute Pre - Dependency Closure Build Prep R1

## 1. Decision

BUILD-PREP-R1-HOLD-BASE-CONFIG-INSPECTION-REQUIRED

The BUILD-PREP preflight and all binding reproductions passed. Preparation then
stopped fail-closed before context creation because accepted evidence does not
bind every inherited base-image configuration field required for a safe final
Dockerfile.

No build context, Dockerfile, artifact copy, lock, policy script, context
manifest, context aggregate, or future build command was created.

## 2. Source and preflight

- Worktree: C:/Adeptlabs/noxund-p3c-execute-pre.
- Branch: spike/pg-exit-p3c-execute-pre.
- HEAD: 4873ac713397cf47642d39b1ef17e48a9301511d.
- Physical spike-subtree files: 60.
- Git-visible untracked files: 59.
- Ignored files: one .gitignore.
- Tracked differences: zero.
- Staged differences: zero.
- Spike-subtree bytes: 366818.
- Canonical input bytes: 6682.
- Canonical SHA-256:
  8f6f72fd374c9a5c852214c2e7b8c95f24d4a475048f46659dce4218349142d0.

The authorized repository output and external BUILD-PREP root were absent
before the unit.

## 3. Binding evidence reproduction

The BUILD-DESIGN document reproduced at 38817 bytes, 768 lines, SHA-256
ca4cd85c279f1a1c940a813361e62d1f2917765aeafd7c37cbb31e5361d095a2,
and Git blob 75c6a70e0803667f0c674ce471c5ec4670af4d74.

The inspected manifest reproduced at 140990 bytes and SHA-256
cefabe85adcd9521f857bc2ce06ea3b05b90bf651dc20da4e48ab00e95a38432.
Its canonical payload remains 103399 bytes with SHA-256
2657dba7d758320ce4528424f1cf527cdeff0972af8f4db9b38d4ca05c9a9c53.
All 21 inspection states remain INSPECTED-PASS; all 21 build states remain
NOT-BEGUN.

Manifest replay results:

- R9 base inventory: 446/446.
- ACQUIRE-PRE R1: 73/73.
- ACQUIRE-PRE R2: 12/12.
- ACQUIRE-PRE R3: 17/17.
- ACQUIRE R1: 51/51.
- ARTIFACT-INSPECT R1: 109/109.

All 19 Debian bodies and both wheel bodies remain ordinary verified source
files. Zero .partial or unexpected body exists. No source body was copied.

## 4. Accepted base-configuration evidence

The preserved source record is:

- Path:
  C:/Adeptlabs/noxund-p3c-base-inventory-r3/raw/image-inspect.json.
- Size: 3612 bytes.
- SHA-256:
  73aa0fe930e43e23fe9b19cd529299c301f09b9d3b67acedfefea3aab786c7a1.

It proves:

- image digest and linux/amd64;
- PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/lib/postgresql/15/bin;
- entrypoint docker-entrypoint.sh;
- command postgres;
- null User;
- null labels;
- PGDATA=/var/lib/postgresql/data; and
- volume /var/lib/postgresql/data.

These fields are classified PRESERVE-EXACTLY: the accepted PATH, entrypoint,
command, labels, volume, and PostgreSQL data-directory contract.

## 5. Blocking base-configuration fields

The accepted record is filtered and does not bind:

- numeric UID/GID;
- supplementary groups;
- Home;
- WorkingDir;
- ExposedPorts;
- StopSignal; or
- the complete inherited image Healthcheck configuration.

User remains unresolved because a null image User does not prove the intended
final runtime identity or the entrypoint privilege transition.

These fields are classified UNRESOLVED-BLOCKING-BUILD-PREP.

The proposed values PATH=/usr/bin:/bin and HOME=/nonexistent were not
materialized. Their compatibility with the inherited entrypoint, command, and
runtime identity has not been proven. RBF-04 and RBF-14 remain OPEN.

## 6. Context and Dockerfile disposition

External root:

C:/Adeptlabs/noxund-p3c-dependency-closure-build-prep-r1

Planned context path:

C:/Adeptlabs/noxund-p3c-dependency-closure-build-prep-r1/context

The external root contains only finalized HOLD evidence. The context path is
absent.

- Context files: zero.
- Copied bodies: zero of 21.
- Dockerfile: not created.
- Debian lock: not created.
- Wheel lock: not created.
- Package-order context policy: not created.
- Maintainer-script context policy: not created.
- Protected-invariant context policy: not created.
- Runtime-tree context policy: not created.
- Policy scripts: not created.
- CONTEXT-MANIFEST.tsv: not created.
- CONTEXT-MANIFEST.sha256: not created.
- Context aggregate: not calculated.
- Future build command: not emitted.

This prevents a speculative Dockerfile from being represented as approved.

## 7. Prepared HOLD evidence

The evidence records the accepted, non-executed design boundaries:

- binding-reproduction-r1.json;
- source-copy-ledger-r1.tsv, header only;
- build-context-inventory-r1.tsv, header only;
- build-context-policy-r1.json;
- dockerfile-analysis-r1.json;
- base-config-contract-r1.json;
- debian-install-plan-r1.json;
- maintainer-script-policy-r1.json;
- wheel-install-policy-r1.json;
- runtime-tree-copy-policy-r1.json;
- protected-invariant-policy-r1.json;
- future-build-command-r1.json;
- build-prep-result-r1.json;
- metadata-limitations-r1.json;
- EVIDENCE-CONTEXT.md; and
- SHA256SUMS.

There are 16 evidence files totaling 75498 bytes. SHA256SUMS has 15 entries,
is 1424 bytes, and has SHA-256
dcdc91aa03ddb3f79daf448456950a802c8d2de89e2d836dae5a6b3a9a29258d.
All 15 entries reproduce.

## 8. Debian and maintainer-script preparation

The evidence preserves the exact nine FINAL-RUNTIME and ten BUILD-ONLY package
orders from BUILD-DESIGN. It records explicit local dpkg phases, no resolver,
no APT, no body glob, exact Pre-Depends barriers, deferred exact triggers,
noninteractive debconf, fail-closed conffiles, and no compensating removals.

The maintainer-script evidence binds all 31 accepted scripts by package,
member, phase, size, SHA-256, interpreter, command classes, environment,
filesystem-write classes, trigger behavior, service behavior, interaction
behavior, and failure policy.

Exact decisions remain:

- ca-certificates config: required only with exact default-certificate
  selection and no host certificate input;
- ca-certificates postinst: required only for the allowlisted certificate
  writes with no unapproved hook;
- ca-certificates postrm: prohibited; and
- python3 preinst: first-install only, with only the exact inspected legacy
  symlink condition and no recursive deletion.

These are evidence-bound proposals, not materialized context controls.

## 9. Installer-generated metadata limitation

The wheel bodies prove their source members and original RECORD entries. They
do not prove the exact installed-tree behavior of the approved pip invocation.

Unresolved generated or rewritten paths include:

- rewritten RECORD;
- INSTALLER;
- REQUESTED;
- direct_url.json;
- generated scripts; and
- the final self-consistent RECORD treatment after exclusions.

Bytecode is intended absent through --no-compile; temporary files, reports,
cache, and installer provenance are intended absent. These are not promoted to
an exact positive final-copy allowlist without additional accepted evidence.

New finding:

RBF-15-OPEN-PIP-INSTALLED-TREE-METADATA-SEMANTICS-UNPROVEN

This is independent of, and secondary to, the primary base-configuration
blocker.

## 10. Sandbox claim classification

No sandbox or Dockerfile was materialized.

- Network prevention:
  PLANNED-NETWORK-ACCESS-PREVENTION-NOT-MATERIALIZED.
- Socket-attempt detection:
  NETWORK-ATTEMPT-DETECTION-UNAVAILABLE.
- Service prevention:
  EXACT-POLICY-RC.D-DENIAL-PLANNED-NOT-MATERIALIZED.
- Filesystem control:
  complete before/after path, type, size, SHA-256, mode, uid, gid, and timestamp
  reconciliation is planned but not materialized.
- Interactive control:
  closed stdin, noninteractive environment, timeout, and nonzero-exit failure
  are planned but not materialized.

No planned control is reported as implemented proof.

## 11. Findings

Preserved OPEN:

- RBF-01;
- RBF-04;
- RBF-05;
- RBF-06;
- RBF-07 runtime validation;
- RBF-08;
- RBF-11;
- RBF-13 nonblocking; and
- RBF-14.

Preserved RESOLVED:

- RBF-02;
- RBF-03;
- RBF-09;
- RBF-10; and
- RBF-12.

New:

- RBF-15-OPEN-PIP-INSTALLED-TREE-METADATA-SEMANTICS-UNPROVEN.

## 12. Exact next gate

Recommend exactly:

PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-BASE-CONFIG-INSPECT-R1

That gate must inspect the exact immutable base configuration read-only and bind
all missing inherited fields without starting a container or executing the
image.

BUILD, BUILD-PREP continuation, and installer-semantics inspection were not
begun.

## 13. Activity and immutability

No existing repository document, prior evidence file, or acquired body was
modified. Nothing was staged or committed.

No network, Docker, image-store, pull, package installation, dpkg, maintainer
script, pip, wheel installation, image build, container, database, runner,
harness, fixture, migration, or test operation occurred.

The known .rar was checked by path only and remained untouched.
docs/result/0005-result.md remained absent and was not recreated.
