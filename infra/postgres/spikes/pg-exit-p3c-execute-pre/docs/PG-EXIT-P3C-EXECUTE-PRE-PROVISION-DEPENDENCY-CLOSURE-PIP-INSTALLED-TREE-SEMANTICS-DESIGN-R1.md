# PG-EXIT-P3C-EXECUTE-PRE — PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R1

**Gate:** `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R1`
**Type:** design and evidence preparation only — **no execution, no BUILD-PREP**.
**RBF target:** `RBF-15 — PIP-INSTALLED-TREE-METADATA-SEMANTICS-UNPROVEN` (remains **OPEN**).
**Authored:** 2026-08-04 · NOXUND Product Orchestrator.
**Design root:** `C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-design-r1` (out-of-repo; authoritative evidence + `SHA256SUMS`).

---

## 1. Disposition

```
PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R1-PASS-PLAN-BOUND-NOT-EXECUTED
```

Recommend:

```
PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R1
```

---

## 2. R2 governance-repair acceptance binding

The Product Lead **ACCEPTS** the R2 governance repair:

```
BASE-CONFIG-R7-CANARY-R4-PRODUCT-ACCEPTANCE-CLOSEOUT-R2-GOVERNANCE-REPAIR-PASS
```

Recorded note (does **not** reverse the accepted R2 repair):

```
R2-BN-01 — NEGATIVE-PROCESS-CLAIMS-ARE-ATTESTED, NOT-FORENSICALLY-RECONSTRUCTIBLE-FROM-FINAL-BUNDLE
```

---

## 3. Preserved technical and governance states

**Kept in force:**
- `BASE-CONFIG-R7-CANARY-R4-ACCEPTED-FOR-EXACT-IMAGE`
- `CANARY-OBS-03 — RESOLVED-FOR-EXACT-ARCHIVE`
- `RBF-14-RESOLVED-EXACT-MERGED-POSTGRES-ACCOUNT-EVIDENCE`

**Kept open:**
- `RBF-04 — ENTRYPOINT-RUNTIME-BEHAVIOR-UNPROVEN`
- `RBF-15 — PIP-INSTALLED-TREE-METADATA-SEMANTICS-UNPROVEN`

**Kept open as historical governance findings:**
- `GOV-CLOSEOUT-DEV-01`
- `GOV-CLOSEOUT-DEV-02`

---

## 4. Exact pip, related Debian package and wheel identities

Transcribed from the authorization; **no archive body opened, read or hashed** to produce this section.

### CPython
| field | value |
|---|---|
| implementation | CPython |
| major/minor | `3.11` |
| exact builder interpreter target | `/usr/bin/python3.11` |
| approved Debian runtime revision | `3.11.2-6+deb12u8` (where applicable) |

### pip
| field | value |
|---|---|
| Debian package | `python3-pip` |
| version | `23.0.1+dfsg-1` |
| architecture | `all` |
| body size | `1324972` |
| body SHA-256 | `d8024ededc6c7fe941ca96aabebdcf2d846fd130eae9d66aad1aa32a84454291` |

### Related build-only tooling
| package | version | body SHA-256 |
|---|---|---|
| `python3-pkg-resources` | `66.1.1-1+deb12u2` | `25dfb378939ccdf27e7382adf44c168f86e22f9f1a8e6e3a2ec526431ed5e30f` |
| `python3-setuptools` | `66.1.1-1+deb12u2` | `96f934b8dbe4367c4cf9e4c740aa5c85f9a9ac8875a16556c8677fb342c7838f` |
| `python3-wheel` | `0.38.4-2` | `623a8f7c70ba713b0d8d5a321f157405861f0a0b1a652edad2cda5f70f5773f9` |

> Do not infer these packages participate in a specific metadata write until source inspection or the canary establishes it.

### Wheels
| distribution | filename | size | SHA-256 |
|---|---|---|---|
| psycopg | `psycopg-3.2.9-py3-none-any.whl` | `202705` | `01a8dadccdaac2123c916208c96e06631641c0566b22005493f09663c7a8d3b6` |
| typing-extensions | `typing_extensions-4.16.0-py3-none-any.whl` | `45571` | `481caa481374e813c1b176ada14e97f1f67a4539ce9cfeb3f350d78d6370c2e8` |

### Installation target
```
/opt/noxund-wheel-root/usr/local/lib/python3.11/dist-packages
```

### Determinism input
```
SOURCE_DATE_EPOCH=1783993009
```
> pip is **not** claimed to normalize installed timestamps to this value. Timestamp normalization is a separately-controlled post-install tree operation (Layer 4).

---

## 5. Existing command-model reproduction

Preserved accepted command class — **no option silently added, removed or reinterpreted**:

```
/usr/bin/python3.11 -I -s -m pip
```

Semantic options:
- `--no-index`
- one exact local `--find-links` directory
- `--no-deps`
- `--only-binary=:all:`
- `--require-hashes`
- `--no-build-isolation`
- `--no-compile`
- `--ignore-installed`
- no cache
- no version check
- no user site
- no pip configuration
- one exact empty target directory

Any proposed exact command change must be listed as an **OPEN Product decision**. (None proposed in R1.)

---

## 6. Architecture comparison

| id | candidate | disposition |
|---|---|---|
| S1 | static exact-pip source inspection only | `REQUIRED-BUT-INSUFFICIENT-ALONE` |
| C1 | dedicated exact-environment offline semantics canary | `SELECTED-CANDIDATE` |
| C2 | host Python or host pip probe | `REJECT` |
| C3 | defer discovery to the final BUILD | `REJECT` |
| C4 | custom wheel installer | `REJECT-PRESERVE-PRIOR-DECISION` |

## 7. Selected source-inspection architecture

**S1 — static exact-pip source inspection only** → `REQUIRED-BUT-INSUFFICIENT-ALONE`. Establishes
implementation intent and code paths; cannot by itself prove the complete observed installed tree.
Detailed plan: `evidence/pip-source-inspection-plan-r1.json`.

## 8. Selected exact-environment canary architecture

**C1 — dedicated exact-environment offline semantics canary** → `SELECTED-CANDIDATE`. Uses the exact
accepted CPython, Debian pip implementation, two wheels, lock and target model in a separately
authorized disposable builder environment. **Must stop after producing and preserving the staged
installed tree and evidence; must not produce or tag the final client image.** Detailed plan:
`evidence/exact-environment-canary-plan-r1.json`.

## 9. Rejection of host-pip and defer-to-BUILD candidates

- **C2 (host pip) — REJECT:** host implementation, patch level, Debian modifications, filesystem
  behavior and installation scheme are not the accepted builder subject.
- **C3 (defer to BUILD) — REJECT:** BUILD-PREP needs a positive runtime-tree policy before BUILD while
  installed-tree paths are unknown; deferring discovery creates a circular acceptance dependency.
- **C4 (custom installer) — REJECT-PRESERVE-PRIOR-DECISION:** introduces a new trusted implementation
  of wheel relocation, script generation and RECORD semantics.

---

## 10. Semantic-question matrix

Every question carries an explicit **`UNKNOWN-BEFORE-INSPECTION`** disposition. Full matrix:
`evidence/semantic-question-matrix-r1.tsv` (categories: wheel-origin-paths, record, installer,
requested, direct-url, generated-scripts, bytecode, residue, filesystem-metadata). No presence,
absence, bytes, or behavior is predeclared.

## 11. Wheel-origin path model

For every original wheel member: original wheel-relative path; original RECORD row; installation-scheme
destination; whether `.data` relocation applies; whether bytes are unchanged; whether mode changes;
whether the installed RECORD path changes; whether the member is absent after installation and why.
Modeled per-path in `evidence/installed-tree-reconciliation-contract-r1.json`.

## 12. Installed RECORD reconciliation contract

Do **not** assume original wheel RECORD and installed RECORD are byte-identical. Contract covers pip
rewrite determination, installed path, row-order, path representation, hash algorithm/encoding, size
representation, self-row treatment, generated-metadata treatment, relocated-member treatment, and the
three completeness invariants (every installed regular file represented; no dangling rows; no
unrepresented paths). Any violation forces canary **HOLD**. See
`evidence/installed-tree-reconciliation-contract-r1.json`.

## 13. INSTALLER contract

Presence/absence; exact path; exact bytes; RECORD representation; provenance from the exact pip
implementation. **Bytes are not predeclared as `pip\n` without evidence.**
See `evidence/generated-metadata-contract-r1.json`.

## 14. REQUESTED contract

Determined **independently for both distributions**: presence/absence; exact bytes; reason for creation
or omission; RECORD representation. **Not inferred from lock membership.**

## 15. direct_url.json contract

Determined **independently for both distributions**: presence/absence; exact bytes; URL type and
redaction; archive hash representation; whether `--find-links` selection is treated as a direct URL;
RECORD representation. **Neither presence nor absence assumed.**

## 16. Generated-script contract

Entry-point declarations (both wheels); whether pip generates any script; destination; exact bytes and
shebang; mode; RECORD representation. **Expected absence must be proven from both wheel metadata and
observed output.**

## 17. Bytecode, cache, report and temporary-residue contracts

- **Bytecode:** `--no-compile` → zero `.pyc`; no independent bytecode; no `__pycache__` remains.
- **Cache:** zero cache residue.
- **Report:** pip report preserved **outside** the staged runtime tree.
- **Temporary residue:** zero temporary/partial file after a zero exit; zero installer provenance
  outside approved dist-info metadata. Any hit forces **HOLD**.

## 18. Filesystem-metadata layer separation

Four explicit layers: (1) pip-emitted; (2) wheel-inherited; (3) target-filesystem-imposed;
(4) post-install-policy-normalized. **Post-install owner/mode/timestamp normalization is NOT attributed
to pip.** `SOURCE_DATE_EPOCH` belongs to Layer 4.

---

## 19. Source-inspection evidence plan

`evidence/pip-source-inspection-plan-r1.json` — reads only exact approved Debian/wheel bodies; bounded,
reviewed, standard-library-only inspector; does not import/execute/AST-parse or extract into an
executable path; hashes every inspected member; maps each semantic question to exact pip code paths;
records unresolved dynamic behavior for the canary. **Designed only — not prepared or executed here.**

## 20. Canary environment and invocation plan

`evidence/exact-environment-canary-plan-r1.json` — exact accepted base-image digest; exact package and
wheel bodies; no network / resolver / mutable repo / host-python / host-pip / secrets / SSH / Docker
socket; closed stdin; explicit timeout; one pip invocation; no retry; initially empty target; complete
before/after inventory; preserved stdout/stderr/exit-code/report; no cleanup before Product review; no
final-client image; no database/runner/harness/fixture/migration/test. **Execution requires separate
Product Lead authorization.**

## 21. Canary evidence schema

`evidence/canary-evidence-schema-r1.json` — bundle layout (identities, invocation, before/after
inventories, logs, exit code, report, reconciliation, classification, allowlist, SHA256SUMS) and
per-record inventory fields.

## 22. Exact PASS / HOLD criteria

**PASS** requires all of: exact interpreter/pip identities; exact wheels/lock; zero network attempt;
zero resolver decision; zero source build; zero native wheel; zero unexpected distribution; zero path
outside authorized builder/evidence roots; complete observed tree inventory; complete installed RECORD
reconciliation; explicit classification of every generated metadata path; zero `.pyc`; zero unexpected
generated script; zero cache residue; zero unexplained temporary residue; exact report preservation
outside the staged runtime tree; a positive final-copy allowlist derived only from reconciled observed
records.

**HOLD** on any unknown or unexplained path.

## 23. RBF-15 closure boundary

This design gate **must not** close RBF-15. Static inspection alone **must not** close RBF-15. RBF-15
may close **only** after: (1) exact source inspection accepted; (2) exact offline canary exits zero;
(3) complete observed evidence reproduces; (4) every installed-tree path reconciled; (5) Product Lead
directly reviews the preserved canary evidence. See `evidence/rbf15-closure-boundary-r1.json`.

---

## 24. Design-root identity and manifest replay

**Design root:** `C:/Adeptlabs/noxund-p3c-pip-installed-tree-semantics-design-r1`
**Authoritative manifest:** `SHA256SUMS` (13 evidence files). Replay:
`sha256sum -c SHA256SUMS` or `Get-FileHash evidence/* -Algorithm SHA256`.

| file | sha256 |
|---|---|
| evidence/binding-reproduction-r1.json | `c6c3a7284ec743faf1c6ee143c4bc053457f9c8c96d363f326e5f5842fc6eaef` |
| evidence/subject-identities-r1.json | `a3f4b190286655a525de12e7ef8c9c9f853f5a77be47cad5d63f47af46d1cadc` |
| evidence/architecture-comparison-r1.json | `213b0a12a28450f1c03ed7f598607501f5cda3eafd69fc7488487803cc978bf5` |
| evidence/semantic-question-matrix-r1.tsv | `c85e29436dfe50694685bb1e106a9009a3e9b5fb958e2d132fc4a328f17ba69d` |
| evidence/installed-tree-reconciliation-contract-r1.json | `50ba7c6800bdace66043e28e500ed8587ef1c72d6108782f64f940bc0f4ee7c0` |
| evidence/generated-metadata-contract-r1.json | `45c77745944fc17f34b967852af13051398a08ba862275da48ac7a84b9331ff3` |
| evidence/pip-source-inspection-plan-r1.json | `ffcd240119def2a8a9c3254df9b3056c99ce396bf0b97bbfbacda06813a53393` |
| evidence/exact-environment-canary-plan-r1.json | `82e164907ab7bf6b8b52dbca0423ebc2a3fe911635357da171b76b5daa5c0c22` |
| evidence/canary-evidence-schema-r1.json | `fa3a99b9e68a4a5fa88e72ff82a3fd8790629e6169ea14f04b1ff95f5783f6c1` |
| evidence/rbf15-closure-boundary-r1.json | `7b1b098a4a78008e11eb809c8804c92fc7590e3dee471932978eb16e74eb4495` |
| evidence/pip-semantics-design-result-r1.json | `cbd549e79b6ba6a14206ce8d4d1909fac4340f7ed52e166443bdd70131d0a8ae` |
| evidence/metadata-limitations-r1.json | `989d702d648f00683e13e70f8c504c5cd8be88dc3c677425830452a4deebecb7` |
| evidence/EVIDENCE-CONTEXT.md | `57cca9950eaf9ab0744360be0d3d35fd56921bca77817b8a11f7030446d27b4f` |

## 25. Repository output identity

This document is the single authorized repository output:
```
infra/postgres/spikes/pg-exit-p3c-execute-pre/docs/PG-EXIT-P3C-EXECUTE-PRE-PROVISION-DEPENDENCY-CLOSURE-PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R1.md
```
It was **ABSENT** before this gate (no HOLD). `docs/result` was neither created nor modified.

## 26. Source / main / evidence / archive / memory states

| subject | before | after |
|---|---|---|
| `main` HEAD | `4873ac7` | `4873ac7` (unchanged) |
| `source` (origin AdeptLabsDev/noxund) | `4873ac7` | `4873ac7` (unchanged) |
| working tree | clean except untracked `docs/result/` | + one new untracked authorized doc; nothing staged/committed |
| repo output file | ABSENT | CREATED (this file) |
| design root | ABSENT | CREATED (13 evidence files + SHA256SUMS) |
| preserved `.rar` | exists, regular file, not symlink | UNCHANGED (path-presence + lstat file-type only) |
| project memory | intact | UNMODIFIED |

## 27–31. Confirmations

- **27.** No existing file was changed (only new authorized paths created).
- **28.** Nothing was staged or committed; no PR created.
- **29.** No archive body, pip, Docker, network, database/Supabase, or later gate was accessed.
- **30.** No temporary, placeholder, sidecar, backup or unauthorized path was created.
- **31.** The known `.rar` (`noxund-p3c-base-config-inspect-r7-execute-canary-r4.rar`) was checked by
  path presence + lstat file-type only; its contents were neither read nor hashed.

## 32. Exact next recommendation

```
PRODUCT-LEAD-REVIEW-PIP-INSTALLED-TREE-SEMANTICS-DESIGN-R1
```
On acceptance: separately authorize **S1** (static exact-pip source inspection), then separately
authorize the **C1** offline canary execution. RBF-15 remains **OPEN** until both complete and the
Product Lead directly reviews the preserved canary evidence.

**Stopped after the design-only R1 unit.**
