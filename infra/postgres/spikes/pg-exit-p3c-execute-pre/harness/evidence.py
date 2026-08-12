"""evidence — evidence-capture schema with secret redaction.

IMPLEMENTED, NOT EXECUTED. Defines the machine-readable evidence record a future
run emits per test. Never includes passwords, connection strings or private
environment values: ``redact`` scrubs them defensively before serialization.
"""
from __future__ import annotations

import hashlib
import json
import re
from dataclasses import asdict, dataclass, field
from typing import Any, Optional

_SECRET_KEY = re.compile(r"(pass(word)?|secret|pgpassword|conninfo|dsn|token|pwd)", re.I)
_CONNINFO = re.compile(r"(password|host|user|dbname|port)\s*=\s*\S+", re.I)


def redact(value: Any) -> Any:
    if isinstance(value, dict):
        out = {}
        for k, v in value.items():
            if _SECRET_KEY.search(str(k)):
                out[k] = "***REDACTED***"
            else:
                out[k] = redact(v)
        return out
    if isinstance(value, list):
        return [redact(v) for v in value]
    if isinstance(value, str):
        return _CONNINFO.sub(lambda m: m.group(0).split("=")[0] + "=***REDACTED***", value)
    return value


def sha256_hex_of_file(path: str) -> Optional[str]:
    try:
        with open(path, "rb") as fh:
            return hashlib.sha256(fh.read()).hexdigest()
    except OSError:
        return None


@dataclass
class EvidenceRecord:
    test_id: str
    classification_expected: str
    pg_version: str = ""
    client_version: str = ""
    image_ref: str = ""
    image_digest: str = ""
    branch: str = ""
    commit: str = ""
    artifact_hash: Optional[str] = None
    trace_hash: Optional[str] = None
    exit_code: Optional[int] = None
    sqlstate: Optional[str] = None
    transaction_status: Optional[str] = None
    backend_pid: Optional[int] = None
    top_xid: Optional[str] = None
    object_inventory: list = field(default_factory=list)
    acl_role_inventory: dict = field(default_factory=dict)
    head_row: Optional[dict] = None
    history_rows: list = field(default_factory=list)
    object_owners: dict = field(default_factory=dict)
    teardown_result: Optional[str] = None
    outcome_observed: str = "NOT_EXECUTED"  # never 'PASS' until a real run sets it

    def to_json(self) -> str:
        return json.dumps(redact(asdict(self)), indent=2, sort_keys=True)
