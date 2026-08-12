"""manifest — client-held (TRUSTED under TM-A) migration manifest & checksums.

IMPLEMENTED, NOT EXECUTED. The manifest binds each version to its artifact file,
expected SHA-256 (of the exact artifact bytes) and expected predecessor. The
runner verifies the on-disk artifact bytes against the manifest before executing
anything, and passes version/checksum/prev to ``record_migration``.
"""
from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Optional


@dataclass(frozen=True)
class MigrationEntry:
    version: str
    file: str
    prev_version: Optional[str]
    sha256: str


class ManifestError(RuntimeError):
    pass


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_manifest(manifest_path: str | Path) -> list[MigrationEntry]:
    p = Path(manifest_path)
    doc = json.loads(p.read_text(encoding="utf-8"))
    out: list[MigrationEntry] = []
    for m in doc["migrations"]:
        out.append(MigrationEntry(
            version=m["version"],
            file=m["file"],
            prev_version=m.get("prev_version"),
            sha256=m["sha256"],
        ))
    return out


def verify_artifact(entry: MigrationEntry, migrations_dir: str | Path) -> str:
    """Return the artifact text after confirming its bytes match the manifest."""
    path = Path(migrations_dir) / entry.file
    raw = path.read_bytes()
    actual = sha256_hex(raw)
    if actual != entry.sha256:
        raise ManifestError(
            f"checksum mismatch for {entry.version}: manifest={entry.sha256} actual={actual}")
    return raw.decode("utf-8")
