"""pq_transport — libpq PQexecParams transport for the P3C runner.

IMPLEMENTED, NOT EXECUTED. Every migration statement — including the untrusted
`DO` artifact — is submitted through ``psycopg.pq.PGconn.exec_params`` (libpq
``PQexecParams``), which uses the EXTENDED query protocol with zero application
parameters and is server-restricted to "at most one command". The default
parameterless ``Cursor.execute()`` (simple protocol / multi-statement),
``ClientCursor``, ``psql``, ``PQexec`` and any statement splitter are never used.

This module is a thin, synchronous wrapper. Results and errors are checked after
every call; the transaction status and backend PID are read from libpq state.
"""
from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Optional, Sequence

from psycopg import pq  # low-level libpq binding (from psycopg[binary])


class TransportError(RuntimeError):
    """Raised when a libpq call returns a non-OK result or unexpected state."""

    def __init__(self, message: str, *, sqlstate: Optional[str] = None,
                 command_tag: Optional[str] = None) -> None:
        super().__init__(message)
        self.sqlstate = sqlstate
        self.command_tag = command_tag


@dataclass(frozen=True)
class ExecOutcome:
    status: int                 # pq.ExecStatus
    command_tag: str            # e.g. "DO", "CREATE TABLE", "COMMIT", "SELECT 1"
    sqlstate: Optional[str]     # 5-char SQLSTATE on error, else None
    error_message: str
    rows: list[list[Optional[str]]]


def _b(s: str) -> bytes:
    return s.encode("utf-8")


class PQConn:
    """One libpq connection driven entirely at the PQ level (no mixing with the
    psycopg high-level transaction manager)."""

    def __init__(self, conninfo: str) -> None:
        self._conn = pq.PGconn.connect(_b(conninfo))
        if self._conn.status != pq.ConnStatus.OK:
            msg = self._conn.error_message.decode("utf-8", "replace")
            raise TransportError(f"connection failed: {msg}")
        self._connect_pid: int = self._conn.backend_pid
        self._trace_fh = None

    # -- identity / state ---------------------------------------------------
    @property
    def backend_pid(self) -> int:
        return self._conn.backend_pid

    @property
    def connect_pid(self) -> int:
        return self._connect_pid

    @property
    def transaction_status(self) -> int:
        return self._conn.transaction_status

    def is_intrans(self) -> bool:
        return self._conn.transaction_status == pq.TransactionStatus.INTRANS

    def is_live(self) -> bool:
        return self._conn.status == pq.ConnStatus.OK

    # -- protocol trace (implemented; enabled by the future gate only) -------
    def enable_trace(self, path: str) -> None:
        self._trace_fh = open(path, "wb")
        # Suppress timestamps for a stable, hashable trace.
        self._conn.trace(self._trace_fh.fileno())
        try:
            self._conn.set_trace_flags(pq.Trace.SUPPRESS_TIMESTAMPS)
        except Exception:
            pass

    def disable_trace(self) -> None:
        try:
            self._conn.untrace()
        finally:
            if self._trace_fh is not None:
                self._trace_fh.close()
                self._trace_fh = None

    # -- execution ----------------------------------------------------------
    def exec_params(self, command: str,
                    params: Optional[Sequence[Optional[str]]] = None) -> ExecOutcome:
        """Run exactly one command via PQexecParams (extended protocol).

        A multi-statement `command` is rejected by the server at Parse — that is
        the point. `params` are text-format bind values (or None); an empty list
        still uses the extended protocol with zero parameters.
        """
        pvals: list[Optional[bytes]] = []
        if params:
            for p in params:
                pvals.append(None if p is None else _b(p))
        res = self._conn.exec_params(_b(command), pvals)
        return self._outcome(res)

    def _outcome(self, res) -> ExecOutcome:
        status = res.status
        tag = (res.command_status or b"").decode("utf-8", "replace")
        sqlstate_b = res.error_field(pq.DiagnosticField.SQLSTATE)
        sqlstate = sqlstate_b.decode("ascii") if sqlstate_b else None
        errmsg = (res.error_message or b"").decode("utf-8", "replace")
        rows: list[list[Optional[str]]] = []
        if status == pq.ExecStatus.TUPLES_OK:
            for r in range(res.ntuples):
                row: list[Optional[str]] = []
                for c in range(res.nfields):
                    v = res.get_value(r, c)
                    row.append(None if v is None else v.decode("utf-8", "replace"))
                rows.append(row)
        return ExecOutcome(status=status, command_tag=tag, sqlstate=sqlstate,
                           error_message=errmsg, rows=rows)

    def require_ok(self, out: ExecOutcome, what: str) -> ExecOutcome:
        if out.status not in (pq.ExecStatus.COMMAND_OK, pq.ExecStatus.TUPLES_OK):
            raise TransportError(f"{what} failed: {out.error_message.strip()}",
                                 sqlstate=out.sqlstate, command_tag=out.command_tag)
        return out

    def scalar(self, command: str,
               params: Optional[Sequence[Optional[str]]] = None) -> Optional[str]:
        out = self.require_ok(self.exec_params(command, params), command.split()[0])
        if not out.rows or not out.rows[0]:
            return None
        return out.rows[0][0]

    def close(self) -> None:
        try:
            self.disable_trace()
        finally:
            self._conn.finish()


def execute_gate_authorized() -> bool:
    """Hard guard shared by every runnable entrypoint."""
    return os.environ.get("NOXUND_P3C_EXECUTE_GATE") == "AUTHORIZED"
