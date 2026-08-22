#!/usr/bin/env python3
"""Canonical quality entrypoint for `services/data-engine`.

    python services/data-engine/run_quality_checks.py

This file is the ONE place the data-engine quality assertions live. A
developer and CI invoke exactly this artifact, so there is no second
implementation in workflow YAML to drift from (DEC-0042 D9; PHASE-D D3).

--------------------------------------------------------------------------
WHAT THIS COVERS - AND, EXACTLY, WHAT IT DOES NOT
--------------------------------------------------------------------------
DEC-0042 D10 is the quality-gate honesty rule: a name broader than its
mechanism is a defect, not a convenience. So, literally:

  COVERED - three limbs, all stdlib-only, all deterministic:
    1. `suite`  - the data-engine unit suite, run TWICE in independent
                  child processes; every run must report exactly
                  EXPECTED_SUITE_TESTS and exit 0.
    2. `repro`  - the P5-REPRO-01 reproducibility harness, run TWICE in
                  independent child processes; every run must report
                  exactly EXPECTED_REPRO_TESTS and exit 0.
    3. `digest` - the pipeline digest computed TWICE over the golden
                  snapshot; the two must be byte-identical AND equal the
                  locked GOLDEN_DIGEST constant.

  NOT COVERED, and none of it may be inferred from a green run:
    * NO lint and NO static analysis. `pyproject.toml` declares a
      `[tool.ruff]` section, nothing installs or runs ruff, and adopting
      one is a D4 adjudication this file does not pre-empt.
    * NO type checking. No Python type checker is installed or configured.
    * NO integration tests. `tests_integration/` is NOT discovered here;
      it needs a live database and is out of scope for a default local
      developer command.
    * NO collection-driver contract. Proving `import psycopg` at its
      hash-pinned version requires `pip install` into the environment.
      That limb stays CI-only ON PURPOSE - see COLLECTION DRIVER CONTRACT
      below - because making it the developer default would materially
      alter a local environment that this file otherwise never touches.
    * NO database, NO network, NO secret, NO cloud, NO credential. The
      suites use in-memory doubles by design. Nothing here connects to,
      reads from or writes to any external system, and nothing here
      re-arms any collection or apply path (DEC-0033 section 8).

--------------------------------------------------------------------------
WHY THIS FILE EXISTS AT ALL - the defect it repairs
--------------------------------------------------------------------------
The golden-digest limb needs BOTH `src` (for `noxund_data_engine`) and
`tests` (for `test_repro_harness`) on the import path. That was previously
expressed only as a workflow environment value, `PYTHONPATH: src:tests`,
whose `:` separator is POSIX-only. Run verbatim on Windows it fails with
`ModuleNotFoundError: No module named 'test_repro_harness'`; the CI job
itself was correct, because CI runs on Linux, but no Windows developer
could run the documented command.

This file removes the question rather than documenting two answers:
**it establishes its own import path internally**, from its own location,
using `os.pathsep` for the child processes it spawns. There is no
`PYTHONPATH` for a developer to set, no separator for a developer to know,
and no working directory for a developer to be in. The canonical
invocation is OS-neutral and identical everywhere.

It likewise sets `PYTHONDONTWRITEBYTECODE` for itself and for every child
process, so running it leaves no `__pycache__` behind.

--------------------------------------------------------------------------
COLLECTION DRIVER CONTRACT - a deliberate, documented CI-only exception
--------------------------------------------------------------------------
`.github/workflows/data-engine-tests.yml` carries a third job that installs
the collection runtime driver from `requirements-collect.txt` under
`--require-hashes --only-binary=:all:` and asserts the resolved
`psycopg.__version__` equals the pin. It is ENVIRONMENT-SPECIFIC: its whole
purpose is to prove that a real install of a pinned wheel imports, which
cannot be asserted without performing that install.

It is therefore NOT consolidated into this file and NOT run by default.
That is an accepted limitation, recorded rather than hidden
(DEC-0042 D17 condition 4). A developer who needs it runs the same install
line the workflow runs; the pins live only in `requirements-collect.txt`,
so there is still exactly one source of truth for them.

--------------------------------------------------------------------------
EXIT STATUS
--------------------------------------------------------------------------
0 - every selected limb passed.
1 - at least one limb failed. Every failure is fail-closed: a non-zero
    child exit, a discovered-test count that is not exactly the expected
    one, a non-reproducible digest or a digest that drifted from the
    locked constant each fail the run. An under-discovery regression that
    silently ran fewer tests still exits 0 under `unittest`, which is
    precisely why the counts are asserted here rather than trusted.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

# --------------------------------------------------------------------------
# Locked expectations. Changing one of these numbers is a deliberate act:
# it re-baselines a fail-closed guarantee and belongs in a commit that says
# so, not in a drive-by edit.
# --------------------------------------------------------------------------

#: Exact test count the full unit suite must discover and run.
#: 18 resolver + 19 channel-filter + 28 scoring + 37 opportunity
#: + 13 channel-collection + 39 video-collection + 21 repro-harness
#: + 24 sg8-runner + 50 sg8-postgres-adapter + 27 sg8-coordinator.
EXPECTED_SUITE_TESTS = 276

#: Exact test count the P5-REPRO-01 harness must discover and run.
EXPECTED_REPRO_TESTS = 21

#: Independent executions required of each unittest limb. Two runs in
#: SEPARATE PROCESSES, never two passes inside one interpreter - a
#: same-process repeat would share module state and prove far less.
DETERMINISM_RUNS = 2

#: This package root - `services/data-engine`. Resolved from THIS file, so
#: the entrypoint works from any working directory on any platform.
PACKAGE_ROOT = Path(__file__).resolve().parent
SRC_DIR = PACKAGE_ROOT / "src"
TESTS_DIR = PACKAGE_ROOT / "tests"

_RAN_RE = re.compile(r"^Ran (\d+) tests? in ", re.MULTILINE)


def _child_env() -> dict:
    """Environment for a child process: import path owned by this file.

    `os.pathsep` is `;` on Windows and `:` on POSIX, so the caller never
    has to know which - this is the cross-platform repair, in one line.
    Any inherited PYTHONPATH is PREPENDED to rather than replaced, so a
    developer with their own entries keeps them.
    """
    env = os.environ.copy()
    owned = [str(SRC_DIR), str(TESTS_DIR)]
    inherited = env.get("PYTHONPATH", "")
    if inherited:
        owned.append(inherited)
    env["PYTHONPATH"] = os.pathsep.join(owned)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    return env


def _run_unittest(pattern: str, expected: int, label: str) -> bool:
    """Run one unittest limb `DETERMINISM_RUNS` times, fail-closed.

    Each attempt is an INDEPENDENT child process. An attempt passes only
    if the process exits 0 AND the summary reports exactly `expected`
    tests. Both conditions are required; neither implies the other.
    """
    ok = True
    for attempt in range(1, DETERMINISM_RUNS + 1):
        proc = subprocess.run(
            [
                sys.executable,
                "-B",
                "-m",
                "unittest",
                "discover",
                # `-s` only, deliberately NO `-t`: with no explicit
                # top-level directory unittest sets it equal to the start
                # directory, so test modules import as top-level names
                # (`test_repro_harness`), exactly as they do today.
                # `tests/` carries no `__init__.py`, so naming a wider
                # top-level directory would break discovery outright.
                "-s",
                str(TESTS_DIR),
                "-p",
                pattern,
                "-v",
            ],
            cwd=str(PACKAGE_ROOT),
            env=_child_env(),
            capture_output=True,
            text=True,
        )
        output = (proc.stdout or "") + (proc.stderr or "")

        if proc.returncode != 0:
            print(output)
            print(
                f"::error::{label} FAILED on attempt {attempt}/{DETERMINISM_RUNS} "
                f"(unittest exit {proc.returncode})."
            )
            ok = False
            continue

        match = _RAN_RE.search(output)
        actual = int(match.group(1)) if match else None
        if actual != expected:
            print(output)
            got = f"Ran {actual} tests" if actual is not None else "<no summary line>"
            print(
                f"::error::{label} attempt {attempt}/{DETERMINISM_RUNS}: expected "
                f"exactly {expected} tests, got '{got}' (discovery regression)."
            )
            ok = False
            continue

        print(f"  attempt {attempt}/{DETERMINISM_RUNS}: {actual}/{expected} OK")

    if ok:
        print(
            f"OK - {label}: {expected}/{expected} across {DETERMINISM_RUNS} "
            f"independent processes."
        )
    return ok


def check_suite() -> bool:
    """Limb 1 - the full data-engine unit suite."""
    print(f"== suite: full unit suite, x{DETERMINISM_RUNS} ==")
    return _run_unittest("test_*.py", EXPECTED_SUITE_TESTS, "data-engine unit suite")


def check_repro() -> bool:
    """Limb 2 - the P5-REPRO-01 reproducibility harness."""
    print(f"== repro: P5-REPRO-01 harness, x{DETERMINISM_RUNS} ==")
    return _run_unittest(
        "test_repro_harness.py", EXPECTED_REPRO_TESTS, "P5-REPRO-01 repro harness"
    )


def check_digest() -> bool:
    """Limb 3 - the golden pipeline digest.

    Computed twice in THIS process over the golden snapshot, matching the
    semantics the workflow one-liner had. Two assertions, both required:
    the two computations are byte-identical (determinism), and the value
    equals the locked constant (no silent numeric drift).
    """
    print("== digest: pipeline digest over the golden snapshot ==")

    # Import path owned here too, so `python run_quality_checks.py digest`
    # needs no PYTHONPATH and no particular working directory.
    for entry in (str(SRC_DIR), str(TESTS_DIR)):
        if entry not in sys.path:
            sys.path.insert(0, entry)

    import test_repro_harness as t  # noqa: E402 - path established above
    from noxund_data_engine.pipeline import (  # noqa: E402 - same reason
        pipeline_digest,
        run_pipeline,
    )

    first = pipeline_digest(run_pipeline(t.golden_snapshot()))
    second = pipeline_digest(run_pipeline(t.golden_snapshot()))
    locked = t.GOLDEN_DIGEST

    print(f"  digest#1 {first}")
    print(f"  digest#2 {second}")
    print(f"  golden   {locked}")

    if first != second:
        print(
            "::error::pipeline_digest is not byte-identical across 2 computations "
            f"({first} != {second})."
        )
        return False
    if first != locked:
        print(
            "::error::pipeline_digest drifted from the locked GOLDEN_DIGEST "
            f"({first} != {locked})."
        )
        return False

    print("OK - digest byte-identical x2 and equal to the locked GOLDEN_DIGEST.")
    return True


#: Limb name -> callable. `all` runs every one of them, in this order, and
#: does NOT stop at the first failure: a developer should see every broken
#: limb in one run rather than rediscovering them one at a time.
LIMBS = {
    "suite": check_suite,
    "repro": check_repro,
    "digest": check_digest,
}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        prog="run_quality_checks.py",
        description=(
            "Canonical data-engine quality entrypoint: unit suite, repro "
            "harness and golden digest. Stdlib-only; no lint, no type check, "
            "no integration tests, no database, no network."
        ),
        epilog=(
            "The collection-driver contract is deliberately NOT run here: it "
            "requires a hash-pinned pip install and stays CI-only. See the "
            "module docstring."
        ),
    )
    parser.add_argument(
        "limb",
        nargs="?",
        default="all",
        choices=("all",) + tuple(LIMBS),
        help="which limb to run (default: all).",
    )
    args = parser.parse_args(argv)

    # Belt and braces with the child environment: this process leaves no
    # `__pycache__` either, so a developer's tree is unchanged by a run.
    sys.dont_write_bytecode = True

    selected = list(LIMBS) if args.limb == "all" else [args.limb]

    results = {}
    for name in selected:
        results[name] = LIMBS[name]()
        print()

    failed = [name for name, passed in results.items() if not passed]
    if failed:
        print(f"FAILED limbs: {', '.join(failed)}")
        return 1

    print(f"PASSED limbs: {', '.join(selected)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
