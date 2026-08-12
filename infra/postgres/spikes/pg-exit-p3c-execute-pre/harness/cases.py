"""cases — typed loader for the authoritative expected-outcome matrix.

IMPLEMENTED, NOT EXECUTED. ``expected_matrix.json`` is the single source of
truth. This module parses & validates it into ``TestCase`` objects and exposes
lookups by group/id and fixture-path resolution. It performs NO database or
process side effects.
"""
from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Optional

HERE = Path(__file__).resolve().parent
SPIKE_ROOT = HERE.parent
MATRIX = HERE / "expected_matrix.json"

VALID_GROUPS = {"A", "B", "C", "D", "E", "F", "G"}
VALID_CLASSIFICATIONS = {"PASS", "REJECT", "ACCEPTED_TM_A_LIMITATION", "CONTROL"}


@dataclass(frozen=True)
class TestCase:
    id: str
    group: str
    threat: str
    actor_role: str
    action: dict
    expected_exit_code: Optional[int]
    expected_sqlstate: Optional[str]
    expected_transaction_state: str
    expected_object_state: str
    expected_history_state: str
    expected_head_state: str
    expected_owner: str
    expected_pid_xid: str
    classification: str
    reject_if: str
    raw: dict

    def fixture_path(self) -> Optional[Path]:
        fx = self.action.get("fixture")
        return (SPIKE_ROOT / "fixtures" / fx) if fx else None

    def fixture_paths(self) -> list[Path]:
        out: list[Path] = []
        for fx in self.action.get("fixtures", []) or []:
            out.append(SPIKE_ROOT / "fixtures" / fx)
        p = self.fixture_path()
        if p:
            out.append(p)
        return out


def load_cases(matrix_path: str | Path = MATRIX) -> list[TestCase]:
    doc = json.loads(Path(matrix_path).read_text(encoding="utf-8"))
    cases: list[TestCase] = []
    seen: set[str] = set()
    for c in doc["cases"]:
        _require(c, "id"); _require(c, "group"); _require(c, "classification")
        if c["id"] in seen:
            raise ValueError(f"duplicate test id {c['id']}")
        seen.add(c["id"])
        if c["group"] not in VALID_GROUPS:
            raise ValueError(f"{c['id']}: bad group {c['group']}")
        if c["classification"] not in VALID_CLASSIFICATIONS:
            raise ValueError(f"{c['id']}: bad classification {c['classification']}")
        cases.append(TestCase(
            id=c["id"], group=c["group"], threat=c["threat"],
            actor_role=c["actor_role"], action=c["action"],
            expected_exit_code=c.get("expected_exit_code"),
            expected_sqlstate=c.get("expected_sqlstate"),
            expected_transaction_state=c.get("expected_transaction_state", ""),
            expected_object_state=c.get("expected_object_state", ""),
            expected_history_state=c.get("expected_history_state", ""),
            expected_head_state=c.get("expected_head_state", ""),
            expected_owner=c.get("expected_owner", ""),
            expected_pid_xid=c.get("expected_pid_xid", ""),
            classification=c["classification"],
            reject_if=c.get("reject_if", ""),
            raw=c,
        ))
    return cases


def _require(c: dict, key: str) -> Any:
    if key not in c:
        raise ValueError(f"case missing required key {key!r}: {c.get('id', '?')}")
    return c[key]


def by_group(cases: list[TestCase]) -> dict[str, list[TestCase]]:
    out: dict[str, list[TestCase]] = {g: [] for g in sorted(VALID_GROUPS)}
    for c in cases:
        out[c.group].append(c)
    return out


def validate_fixtures(cases: list[TestCase]) -> list[str]:
    """Return a list of missing-fixture problems (empty == all present)."""
    problems: list[str] = []
    for c in cases:
        for p in c.fixture_paths():
            if not p.exists():
                problems.append(f"{c.id}: missing fixture {p}")
    return problems


if __name__ == "__main__":
    cs = load_cases()
    groups = by_group(cs)
    print("IMPLEMENTED, NOT EXECUTED — matrix static validation only")
    print(f"cases: {len(cs)}  by group: " + ", ".join(f"{g}={len(v)}" for g, v in groups.items()))
    problems = validate_fixtures(cs)
    if problems:
        print("MISSING FIXTURES:")
        for p in problems:
            print("  " + p)
    else:
        print("all referenced fixtures present")
