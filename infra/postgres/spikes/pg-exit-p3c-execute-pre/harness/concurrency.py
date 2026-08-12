"""concurrency — group D concurrent-append harness (two sessions).

IMPLEMENTED, NOT EXECUTED. Two noxund_migrator sessions race to append a child
of the same head. Session A takes the singleton head FOR UPDATE (inside
record_migration) and holds the transaction; Session B blocks there, and after A
commits, B re-reads the advanced head and is rejected (P0001) — or, if B somehow
reached the insert, is rejected by UNIQUE (23505). Exactly one child commits.

The result proves linearity is enforced by the singleton FOR UPDATE, independent
of any client advisory lock (``use_advisory``) and independent of the advisory
key each caller chooses (``keys``).
"""
from __future__ import annotations

import sys
import threading
import time
from dataclasses import dataclass
from typing import Optional

sys.path.insert(0, __file__.rsplit("/", 2)[0] + "/runner")  # allow importing runner/*
from pq_transport import PQConn, execute_gate_authorized  # noqa: E402

CANONICAL_KEY = 4826110931533660001


@dataclass
class SideResult:
    committed: bool
    ordinal: Optional[str]
    sqlstate: Optional[str]
    error: str = ""


@dataclass
class RaceResult:
    a: SideResult
    b: SideResult

    @property
    def exactly_one_committed(self) -> bool:
        return self.a.committed ^ self.b.committed


def concurrent_append(conninfo: str, a: dict, b: dict, prev: Optional[str],
                      *, use_advisory: bool = True,
                      keys: tuple[int, int] = (CANONICAL_KEY, CANONICAL_KEY)) -> RaceResult:
    res: dict[str, SideResult] = {}
    a_has_lock = threading.Event()

    def _append(tag: str, spec: dict, key: int, gate: Optional[threading.Event],
                wait_for: Optional[threading.Event], hold: float) -> None:
        c = PQConn(conninfo)
        try:
            c.exec_params("BEGIN ISOLATION LEVEL READ COMMITTED")
            if use_advisory:
                c.exec_params(f"SELECT pg_catalog.pg_advisory_xact_lock({key})")
            if wait_for is not None:
                wait_for.wait(timeout=10)
            out = c.exec_params(
                "SELECT (noxund_migration_meta.record_migration($1,$2,$3)).ordinal",
                [spec["version"], spec["checksum"], prev])
            # record_migration acquired the head FOR UPDATE; signal the peer.
            if gate is not None:
                gate.set()
            if hold:
                time.sleep(hold)
            if out.sqlstate:
                res[tag] = SideResult(False, None, out.sqlstate,
                                      out.error_message.strip())
                c.exec_params("ROLLBACK")
            else:
                ordinal = out.rows[0][0] if out.rows else None
                c.exec_params("COMMIT")
                res[tag] = SideResult(True, ordinal, None)
        except Exception as exc:  # fail-closed
            if c.is_live():
                try:
                    c.exec_params("ROLLBACK")
                except Exception:
                    pass
            res[tag] = SideResult(False, None, None, f"{type(exc).__name__}: {exc}")
        finally:
            c.close()

    ta = threading.Thread(target=_append, args=("a", a, keys[0], a_has_lock, None, 0.5))
    tb = threading.Thread(target=_append, args=("b", b, keys[1], None, a_has_lock, 0.0))
    ta.start(); tb.start(); ta.join(); tb.join()
    return RaceResult(res.get("a", SideResult(False, None, None, "no result")),
                      res.get("b", SideResult(False, None, None, "no result")))


if __name__ == "__main__":
    if not execute_gate_authorized():
        print("IMPLEMENTED, NOT EXECUTED — concurrency harness is inert without the execute gate.",
              file=sys.stderr)
        raise SystemExit(2)
    print("execute gate present; invoke via harness/run_pre_gate.py", file=sys.stderr)
