#!/usr/bin/env python3
"""Canonical quality entrypoint for `tools/governance`.

    python tools/governance/run_quality_checks.py

This file is the ONE place the governance-tooling quality assertions live.
A developer and CI invoke exactly this artifact, so there is no second
implementation in workflow YAML to drift from (DEC-0042 D9; PHASE-D D3).

--------------------------------------------------------------------------
WHAT THIS COVERS - AND, EXACTLY, WHAT IT DOES NOT
--------------------------------------------------------------------------
DEC-0042 D10 is the quality-gate honesty rule: a name broader than its
mechanism is a defect, not a convenience. So, literally:

  COVERED - one limb, stdlib-only:
    * the own-test suite of `check_reference_durability.py`, which must
      discover and run exactly EXPECTED_CHECKER_TESTS and exit 0.

  NOT COVERED, and none of it may be inferred from a green run:
    * This does NOT run the reference-durability checker ITSELF over the
      repository. That is a different act with a different meaning:
      `check` is a PROSPECTIVE check needing a pull-request base SHA, and
      `audit` is a REPORTING sweep that is explicitly never a gate. Both
      are invoked directly, and CI keeps invoking them directly, because
      they need GitHub event context this file has no business carrying
      (see WHAT STAYS OUTSIDE below).
    * NO lint, NO type checking, NO static analysis of any kind. Adopting
      one is a D4 adjudication this file does not pre-empt.
    * NO database, NO network, NO secret, NO cloud, NO credential, and no
      GitHub API call. Nothing here reads or writes any repository
      setting, ruleset, branch protection or required check.

A green run means the checker's own suite is intact at its expected size.
It means nothing about the state of the governed corpus.

--------------------------------------------------------------------------
WHY THE COUNT IS ASSERTED
--------------------------------------------------------------------------
A discovery regression that silently ran FEWER tests still exits 0 under
`unittest`. A suite that quietly shrank to zero would therefore render as
a clean green check that observes nothing - the false-confidence failure
DEC-0042 D10 exists to prevent. So the count is asserted fail-closed here,
in the checked-in artifact, rather than trusted or re-implemented in YAML.

--------------------------------------------------------------------------
WHAT STAYS OUTSIDE THIS FILE, ON PURPOSE
--------------------------------------------------------------------------
`.github/workflows/governance-checks.yml` keeps a second job that runs
`check_reference_durability.py check --base "${BASE_SHA}"` on a pull
request and `... audit --repo-root .` on a manual dispatch. Those are
GitHub platform plumbing - a pull-request base SHA and an event name -
and pushing them into package-quality code would invert the dependency for
no gain. The substantive checker logic already lives in one checked-in
file; only the event wiring is in the workflow.

--------------------------------------------------------------------------
PATHS AND BYTECODE
--------------------------------------------------------------------------
This file resolves its own directory, so the canonical invocation is
OS-neutral and works from any working directory - no `PYTHONPATH`, no
separator to know, no `cd` required. It sets `PYTHONDONTWRITEBYTECODE` for
itself and for the child process, so a run leaves no `__pycache__` behind.

--------------------------------------------------------------------------
EXIT STATUS
--------------------------------------------------------------------------
0 - the suite passed at exactly the expected size.
1 - the suite failed, or discovered a number of tests other than exactly
    EXPECTED_CHECKER_TESTS.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

#: Exact test count the checker's own suite must discover and run.
#: Changing this number re-baselines a fail-closed guarantee and belongs
#: in a commit that says so, not in a drive-by edit.
EXPECTED_CHECKER_TESTS = 40

#: This tool root - `tools/governance`. Resolved from THIS file, so the
#: entrypoint works from any working directory on any platform.
TOOL_ROOT = Path(__file__).resolve().parent
TESTS_DIR = TOOL_ROOT / "tests"

_RAN_RE = re.compile(r"^Ran (\d+) tests? in ", re.MULTILINE)


def check_checker_tests() -> bool:
    """Run the checker's own suite once, asserting the count fail-closed."""
    print("== checker-tests: own suite of check_reference_durability.py ==")

    env = os.environ.copy()
    env["PYTHONDONTWRITEBYTECODE"] = "1"

    proc = subprocess.run(
        [
            sys.executable,
            "-B",
            "-m",
            "unittest",
            "discover",
            # `-s` only, deliberately NO `-t`: with no explicit top-level
            # directory unittest sets it equal to the start directory, so
            # test modules import as top-level names, exactly as they do
            # today. `tests/` carries no `__init__.py`.
            "-s",
            str(TESTS_DIR),
            "-p",
            "test_*.py",
            "-v",
        ],
        cwd=str(TOOL_ROOT.parent.parent),
        env=env,
        capture_output=True,
        text=True,
    )
    output = (proc.stdout or "") + (proc.stderr or "")

    if proc.returncode != 0:
        print(output)
        print(f"::error::governance checker tests FAILED (unittest exit {proc.returncode}).")
        return False

    match = _RAN_RE.search(output)
    actual = int(match.group(1)) if match else None
    if actual != EXPECTED_CHECKER_TESTS:
        got = f"Ran {actual} tests" if actual is not None else "<no summary line>"
        print(output)
        print(
            f"::error::expected exactly {EXPECTED_CHECKER_TESTS} tests, got "
            f"'{got}' (discovery regression)."
        )
        return False

    print(f"OK - {actual}/{EXPECTED_CHECKER_TESTS}.")
    return True


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        prog="run_quality_checks.py",
        description=(
            "Canonical governance-tooling quality entrypoint: the "
            "reference-durability checker's own test suite, at exactly its "
            "expected size. Stdlib-only; no lint, no type check, no network."
        ),
        epilog=(
            "This does NOT run the checker over the corpus. For that, invoke "
            "check_reference_durability.py directly - `check --base <sha>` "
            "prospectively, or `audit --repo-root .` as a report."
        ),
    )
    parser.parse_args(argv)

    sys.dont_write_bytecode = True

    if not check_checker_tests():
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
