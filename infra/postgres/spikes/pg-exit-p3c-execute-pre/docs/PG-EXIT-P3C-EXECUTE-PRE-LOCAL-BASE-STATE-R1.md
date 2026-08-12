# PG-EXIT-P3C-EXECUTE-PRE local base state R1

**Authorized unit:** `PG-EXIT-P3C-EXECUTE-PRE-PROVISION-LOCAL-BASE-STATE-R1`  
**Decision:** **COMPLETE for local identity inspection only**  
**Classification:** `BASE-LOCAL-VERIFIED`  
**Inspection date:** 2026-08-01

This result verifies only the local identity and platform metadata of the
accepted PostgreSQL base. It does not prove the installed Debian package
inventory and is not an authorization to begin BASE-INVENTORY or any later
stage.

## 1. Source preflight

| Field | Observed value |
|---|---|
| Repository top-level | `C:/Adeptlabs/noxund-p3c-execute-pre` |
| Worktree | `C:/Adeptlabs/noxund-p3c-execute-pre` |
| Branch | `spike/pg-exit-p3c-execute-pre` |
| HEAD | `4873ac713397cf47642d39b1ef17e48a9301511d` |
| Required HEAD match | Yes |
| Tracked differences | None |
| Staged differences | None |
| R1 output existed before creation | No |
| Pre-existing physical subtree files | 50 |
| Git-visible untracked subtree files | 49 |
| Ignored subtree files | One: `infra/postgres/spikes/pg-exit-p3c-execute-pre/.gitignore` |
| Unexpected outside-subtree paths | None beyond the accepted `.rar` exception |

The known review artifact remained present at:

`C:/Adeptlabs/noxund-p3c-execute-pre/infra/postgres/spikes/pg-exit-p3c-execute-pre.rar`

Only its path-level presence was checked. Its contents and bytes were not
opened, read, hashed, moved, modified, deleted, or used as input.

## 2. Immutability baselines

The canonical inventory of the 50 pre-existing subtree files used path-sorted,
UTF-8, LF-terminated records containing normalized relative path, byte size, and
lowercase file SHA-256.

| Identity | Before value |
|---|---|
| Canonical input bytes | 7,498 |
| Canonical inventory SHA-256 | `66a944f5840e2673a5784d105e38951077d31d48fe2a6954fd037af7e80965a4` |
| Worktree index SHA-256 | `6f327337c0628851280ee55ca155c77055ce70ed5b7d290b1a5b2000527c3e23` |
| Git configuration SHA-256 | `1aad29c263bf7c37b4b707ac44d1f18c835338bcf462377691515af31d6e3948` |
| Canonical refs SHA-256 | `f16d9d4d2cc5727598a86746bcb49df206b4e4152b2ac269685a0c42c515ae37` |
| Canonical stash-list SHA-256 | `3801e75cd8863e20d367674bd147e11ba06736b740e5f2e5c4cfdb4ce0cd2f2f` |

Binding document identities before R1:

| Document | Size | SHA-256 |
|---|---:|---|
| `PG-EXIT-P3C-EXECUTE-PRE-LOCAL-BASE-STATE.md` | 7,986 | `501a41b00e63c78799774ab37bfe3439a7c166ef542732012cf7fb993e193c77` |
| `PG-EXIT-P3C-EXECUTE-PRE-ACQUIRE-PRE.md` | 21,410 | `abddd6c06eb23ee978c1978121afb2c3bd3f9b08fb8b861177063393e379588f` |
| `PG-EXIT-P3C-EXECUTE-PRE-PROVISION.md` | 23,169 | `fb9a4bef5f96db8707bf4943dea0e1a997a1a9faf4b00303939769c079971168` |

The main worktree was `main` at
`4873ac713397cf47642d39b1ef17e48a9301511d`. The preservation result was 16,642
bytes with SHA-256
`b0235e698de990146779ee46047635d4dc017e8e0b7d87779ed6ca0c4ba495db`.

## 3. Binding accepted identity

No network metadata was resolved in R1. The accepted evidence remained:

| Field | Accepted value |
|---|---|
| Registry reference | `postgres:15.18-bookworm@sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51` |
| Registry index digest | `sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51` |
| `linux/amd64` child manifest | `sha256:fafb7480959eeeb7f1e43b479e642ffef2aa0f067242a1954ab41f2d764e2786` |
| Platform | `linux/amd64` |

## 4. Docker context and daemon identity

| Field | Observed value |
|---|---|
| Docker context | `desktop-linux` |
| Context check exit code | 0 |
| Daemon available | Yes |
| Docker Desktop | 4.84.0 (234817) |
| Docker client/server version | 29.6.2 / 29.6.2 |
| Client/server API | 1.55 / 1.55 |
| Server minimum API | 1.40 |
| Engine commit | `3d80467` |
| Engine OS | `linux` |
| Engine architecture | `amd64` |
| `docker info` architecture | `x86_64`, equivalent to accepted `amd64` |
| Kernel | `6.18.33.2-microsoft-standard-WSL2` |
| Storage driver | `overlayfs` |
| containerd | v2.2.5, commit `e53c7c1516c3b2bff98eb76f1f4117477e6f4e66` |
| runc | 1.3.6, commit `v1.3.6-0-g491b69ba` |
| Docker Compose | v5.3.1 |
| Docker buildx | v0.35.0-desktop.2, commit `b554ce1decd8b509893b1e7c6227eabfb923d094` |
| Local image records reported by daemon | 4 |
| Local containers reported by daemon | 0 |

No sensitive daemon name, proxy, credential, or configuration value is included.
The Docker context was not changed.

## 5. Local image-list evidence

The local image list contained exactly one PostgreSQL row associated with the
accepted locator:

| Field | Observed value |
|---|---|
| Repository | `postgres` |
| Tag | `15.18-bookworm` |
| Digest | `sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51` |
| Local list ID | `sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51` |
| Created-at display | `2026-07-13 22:36:49 -0300 -03` |
| Human-readable list size | `613MB` |
| Exact accepted-digest rows | 1 |
| Exact mutable-tag rows | 1 |
| Unique IDs across digest and tag locators | 1 |
| Conflicting tag rows | 0 |

The tag was not used as proof by itself. Its row independently carried the
accepted digest and resolved to the same sole local identity.

## 6. Exact-reference local inspection

Inspection of the exact accepted reference succeeded with exit code 0.
Inspection of the sole locator image ID returned the same fields.

| Field | Observed value |
|---|---|
| Local image/config-store ID | `sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51` |
| Matching local image count | 1 |
| RepoDigest | `postgres@sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51` |
| RepoTag | `postgres:15.18-bookworm` |
| Image OS | `linux` |
| Image architecture | `amd64` |
| Exact image size | 153,007,182 bytes |
| Created | `2026-07-14T01:36:49.492774343Z` |
| Last tag time | `2026-07-30T13:10:54.851015928Z` |
| RootFS type | `layers` |
| RootFS diff-ID count | 14 |
| Local descriptor media type | `application/vnd.oci.image.index.v1+json` |
| Local descriptor digest | `sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51` |
| Local descriptor size | 10,344 bytes |

The corrected direct evaluation of live local metadata returned:

| Derived field | Value |
|---|---|
| Exact RepoDigest match count | 1 |
| Exact digest-row count | 1 |
| Tag-conflict count | 0 |
| Unique local-ID count | 1 |
| Inspected image-object count | 1 |
| Direct verification predicate | `true` |

The local containerd image store exposes the OCI index digest as both its local
image record ID and Descriptor digest. It does not expose the accepted child
manifest digest as the top-level Descriptor in this inspection. The selected
local image nevertheless reports `linux/amd64`, and no local field contradicts
the previously accepted unique `linux/amd64` child binding.

### 6.1 RootFS diff IDs

1. `sha256:81f823b9617547261c907396f63f770deaa554748ff739bedfa650e3bb74595a`
2. `sha256:2f7e78695afaf6c12905992ac1b30f8be0dfd144193df4dc9740879169b61970`
3. `sha256:6b2da9c67fdf28b0a7731ad1934685f7d1eecf6e86d600444c12952030a31db9`
4. `sha256:72f5cabfdbe5655af6ecb56035fbd910b4de61938d7203c69a4184c4f6b0d5ba`
5. `sha256:bf99f0cb5284733d86488314ebec9ecd9389cec84c51bd5d390c63ae11f33bce`
6. `sha256:c091c2c0f66f038f7baef4140e92da38c76d70cc8b49f7594da9f17376f51cb9`
7. `sha256:7fc41e439e4aa616c572bb58bac8ee0cb5cad870fef2059c63ece9d8c414bede`
8. `sha256:3ef2565afa7d278fb11d284eaa727e9e1e5af8a36ef334c1805deaf13f3b4a4a`
9. `sha256:b84717a8c152b40a00e7a0e7475421bb08c06ecb53de12a5f584057838722c8d`
10. `sha256:591c9c6a3f19b324f921528d7b5550b6d2a2cc3d5a63c95bdbe0ce474aa06be0`
11. `sha256:0589a075161de2827865819f167a679dce21f67c5757f1f5e74827d8a44ad5ec`
12. `sha256:97e907b058afb783ecc30db22e9f757bb97bbd6202697c70e00d02a32acc918a`
13. `sha256:d953d441123a8648491c30808c7401fa770fcc401d6ab6967a7f0945bba0ec23`
14. `sha256:d961aecd3ae67d7684f7b10130e42798ff02de2277d985aa96c9485231ce3833`

No layer content was opened or inspected.

## 7. Classification evaluation

| Binding predicate | Result |
|---|---|
| Daemon available | PASS |
| Context exactly `desktop-linux` | PASS |
| Accepted RepoDigest exists locally | PASS |
| Exactly one expected local image identity | PASS |
| Image OS exactly `linux` | PASS |
| Image architecture exactly `amd64` | PASS |
| Mutable tag conflicts with accepted digest | No |
| Multiple conflicting IDs claim locator | No |
| Local metadata contradicts accepted index/platform | No |

**Classification: `BASE-LOCAL-VERIFIED`.**

Evaluation integrity note: an initial PowerShell aggregation counter incorrectly
reported zero accepted RepoDigest matches because of its candidate-array
expression. It was not accepted as evidence. A corrected local-only, read-only
inspection derived the RepoDigest predicate directly from live Docker JSON and
returned exactly one match, one image object, one ID, and zero conflicts. No
Docker object was created or changed by either read-only evaluation.

This classification proves local identity and platform only. It does not prove
package contents, package versions, libpq/tool versions, or runtime behavior.

## 8. Comparison with accepted registry evidence

| Property | Accepted | Local | Result |
|---|---|---|---|
| OCI index digest | `sha256:b0c5bab0...8ad51` | Descriptor and RepoDigest `sha256:b0c5bab0...8ad51` | MATCH |
| Descriptor media type | OCI image index | `application/vnd.oci.image.index.v1+json` | MATCH |
| Index metadata size | 10,344 | 10,344 | MATCH |
| Target OS | `linux` | `linux` | MATCH |
| Target architecture | `amd64` | `amd64` | MATCH |
| Unique local identity | Exactly one required | One | MATCH |
| `linux/amd64` child manifest | `sha256:fafb7480...e2786` | Not surfaced as top-level local Descriptor | NO CONTRADICTION; not independently re-resolved |

No network query was made to repeat or extend the accepted registry evidence.

## 9. PVD-01

**PVD-01 remains OPEN and is now the next stage-ordering constraint.**

`BASE-LOCAL-VERIFIED` does not reveal the installed Debian package database.
Package names, versions, architectures, package status, and relevant native
libraries remain unknown. No package content or filesystem layer was inspected.
No Debian closure is claimed resolved.

A separately authorized BASE-INVENTORY unit is required before dependency
closure or body acquisition can be approved.

## 10. RBF status

| Finding | Status after R1 |
|---|---|
| RBF-01 — no offline runtime exists | OPEN |
| RBF-02 — dependency closure and hashes incomplete | OPEN |
| RBF-03 — invalid Compose command syntax | RESOLVED previously; unchanged |
| RBF-04 — possible image acquisition/client image absence | OPEN overall; server-base local identity narrowed to VERIFIED, client image still absent |
| RBF-05 — subtree `.gitignore` ignored | OPEN; unchanged |
| RBF-06 — comments-only requirements permits no-op success | OPEN; unchanged |
| PVD-01 — exact base package inventory required | OPEN |

No OPEN finding was corrected by this read-only unit.

## 11. Next gate

The exact recommended next gate is:

`PG-EXIT-P3C-EXECUTE-PRE-PROVISION-BASE-INVENTORY`

A new Product Lead GO is required. That later unit may define a tightly bounded
method to inspect the exact installed package database without contacting
PostgreSQL or running the harness. This R1 unit does not start it.

ACQUIRE-BASE is not recommended because the accepted base identity is already
verified locally. No dependency acquisition, BUILD, INSPECT, INTEGRATE,
REVIEW-BUNDLE, or harness correction is authorized.

## 12. Non-operation statement

No network request occurred. No Docker Hub, registry, auth service, PyPI,
Debian, package repository, PostgreSQL, Supabase, or other remote endpoint was
contacted.

No image was pulled, built, tagged, saved, loaded, imported, exported, removed,
or mutated. No container was created, started, stopped, executed, or removed.
No image layer or package content was inspected. No wheel, `.deb`, package, or
wheelhouse was acquired. No Compose resource command, bootstrap, harness,
fixture, test, trace, fault injection, staging, commit, fetch, push, publication,
or later provisioning unit occurred.
