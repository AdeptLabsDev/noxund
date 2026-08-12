"""fault_injection — deterministic process-death points for group G.

IMPLEMENTED, NOT EXECUTED. The runner calls ``fault_hook(point)`` at three
boundaries. ``make_kill_hook(target)`` returns a hook that, when the target
boundary is reached, terminates the process abruptly WITHOUT sending COMMIT, so
the server auto-rolls-back the in-progress transaction (no committed DDL, no
history row, no head advance). The kill is only armed under the execute gate;
this module triggers nothing on import.
"""
from __future__ import annotations

import os
from enum import Enum
from typing import Callable


class FaultPoint(Enum):
    BEFORE_ARTIFACT = "before_artifact"
    AFTER_DDL_BEFORE_LEDGER = "after_ddl_before_ledger"
    AFTER_LEDGER_BEFORE_COMMIT = "after_ledger_before_commit"


def make_kill_hook(target: FaultPoint) -> Callable[[FaultPoint], None]:
    """Return a fault hook that abruptly terminates the process at `target`.

    Uses os._exit(137) so no Python/atexit/COMMIT runs and the socket drops —
    the server then rolls the transaction back. The future gate runs the runner
    in a subprocess and observes the DB state afterward.
    """
    def _hook(point: FaultPoint) -> None:
        if point is target:
            # Abrupt: skip finalizers, drop the connection, never COMMIT.
            os._exit(137)
    return _hook


def no_fault(_point: FaultPoint) -> None:
    return None
