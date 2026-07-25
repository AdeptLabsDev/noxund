"""Driver-agnostic PostgreSQL persistence adapter for the SG-8 durable session.

U1 of DATA-SG8-001 stage 3 part 2. This module persists the SG-8 durable state
(``sg8_sessions`` / ``sg8_resolution_snapshots`` / ``sg8_round_executions`` /
``sg8_round_report_evidence``) behind a small port (``Sg8Store``) that the offline
runner (``sg8_runner``) will drive in stage-3 part-2 U2. It:

* imports **no** database driver (accepts an injected PEP-249-like connection);
* reads **no** environment variable and knows **no** URL / password / Environment / secret;
* does **not** connect to any database (that is U2, against a local disposable Supabase);
* owns explicit, **fail-closed transactions** — every write commits on success and rolls
  back integrally on any error;
* uses **exclusively parameterized** SQL (``%s`` / ``%s::jsonb``) — no id, state, hash or
  content is ever interpolated into the SQL text;
* NEVER updates or deletes a snapshot, round or evidence row (append-only);
* does NOT re-implement the SG-8 state machine or its rules. The finite-state machine,
  terminality, binding, append-only and the PASS gate live in the runner
  (``sg8_runner.Sg8Session``) and — authoritatively — in the schema
  (``20260620000008``). This adapter only issues the write the caller asks for and
  converts the database's own violations into explicit domain exceptions, preserving
  the original cause.

It reuses the connection abstraction (``CursorLike``) of ``postgres_entity_resolution``
and the ``Sg8State`` enum of ``sg8_runner``. The Round-1 LLM provenance is carried by a
dedicated value object (``Sg8RoundProvenance``) whose fields are named EXACTLY like the
schema columns — the runner's ``LlmProvenance`` is deliberately NOT reused here because
its ``prompt_version`` is a version token, not the cryptographic ``llm_prompt_hash`` the
schema stores (a version must never occupy a hash column). U2 builds ``Sg8RoundProvenance``
from the runner's provenance plus the real prompt hash.
"""

from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass, field
from typing import Any, Mapping, Protocol, Sequence

from .postgres_entity_resolution import CursorLike
from .sg8_runner import Sg8State


# ---------------------------------------------------------------------------
# Injected transaction-owning connection (no driver import; caller provides it).
# ---------------------------------------------------------------------------
class Sg8Connection(Protocol):
    """A PEP-249-like connection whose transaction boundary is owned EXCLUSIVELY by the
    store for the store's lifetime.

    The adapter never constructs this; U2 injects a real driver connection (or, in
    tests, a recording fake) and hands over EXCLUSIVE ownership: while a
    ``PostgresSg8Store`` holds it, the injector must not run its own statements or
    transactions on it. Because ownership is exclusive, the store terminates every
    transaction it opens — writes ``commit``/``rollback`` as a unit, and reads
    ``rollback`` their read-only transaction — leaving the connection reusable without
    ever discarding a caller's transactional work (there is none to discard). This is
    the deliberate counterpart to ``postgres_entity_resolution``'s caller-owned model:
    the SG-8 store needs atomic freeze/binding, so it owns the boundary.
    """

    def cursor(self) -> CursorLike: ...

    def commit(self) -> None: ...

    def rollback(self) -> None: ...


# ---------------------------------------------------------------------------
# Domain exceptions — the database's own violations, surfaced explicitly.
# ---------------------------------------------------------------------------
class Sg8PersistenceError(RuntimeError):
    """Base persistence error. The message is safe (excludes SQL values); the original
    database error is preserved as ``__cause__`` for diagnosis."""


class Sg8ForeignKeyViolation(Sg8PersistenceError):
    """A composite/plain FK was violated (e.g., report/snapshot/dataset divergence)."""


class Sg8UniqueViolation(Sg8PersistenceError):
    """A uniqueness invariant was violated (duplicate round or duplicate evidence)."""


class Sg8CheckViolation(Sg8PersistenceError):
    """A CHECK was violated (binding shape, terminal-state/verdict, round number, …)."""


class Sg8IntegrityGuardViolation(Sg8PersistenceError):
    """A trigger-enforced invariant was violated — the state machine, terminality,
    append-only immutability or the PASS gate (all raised by the schema with SQLSTATE
    ``restrict_violation`` / 23001)."""


class Sg8ContractViolation(Sg8PersistenceError):
    """A caller argument violated the adapter contract before any SQL was issued."""


# SQLSTATE → domain-exception mapping (driver-agnostic).
_SQLSTATE_FK = "23503"
_SQLSTATE_UNIQUE = "23505"
_SQLSTATE_CHECK = "23514"
_SQLSTATE_RESTRICT = "23001"


# ---------------------------------------------------------------------------
# Parameterized SQL (static text; every id/state/hash/content is a %s parameter).
# ---------------------------------------------------------------------------
# WRITES ---------------------------------------------------------------------
_INSERT_SESSION = """
insert into public.sg8_sessions (id, source_collection_run_id)
values (%s, %s)
""".strip()

_SET_STATUS = """
update public.sg8_sessions set status = %s where id = %s
""".strip()

_INSERT_SNAPSHOT = """
insert into public.sg8_resolution_snapshots (
  id, sg8_session_id, source_collection_run_id,
  resolver_version, resolver_hash, fact_count, content_hash
)
values (%s, %s, %s, %s, %s, %s, %s)
""".strip()

_BIND_REPORTS = """
update public.sg8_sessions
   set report_id_1 = %s, report_id_2 = %s, status = %s
 where id = %s
""".strip()

_INSERT_ROUND = """
insert into public.sg8_round_executions (
  id, sg8_session_id, round_number, source_collection_run_id, resolution_snapshot_id,
  llm_provider, llm_model, llm_model_version, llm_prompt_hash, llm_params_json, llm_adapter_version
)
values (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s::jsonb, %s)
""".strip()

_INSERT_EVIDENCE = """
insert into public.sg8_round_report_evidence (
  round_execution_id, sg8_session_id, report_id, canonical_digest
)
values (%s, %s, %s, %s)
""".strip()

_MARK_TERMINAL = """
update public.sg8_sessions
   set status = %s, terminal_at = now(), verdict_reason = %s
 where id = %s
""".strip()

# READS (state needed for replay + comparison) -------------------------------
_READ_SESSION = """
select status, source_collection_run_id, report_id_1, report_id_2, verdict_reason
from public.sg8_sessions where id = %s
""".strip()

_READ_SNAPSHOT = """
select id, source_collection_run_id, resolver_version, resolver_hash, fact_count, content_hash
from public.sg8_resolution_snapshots where sg8_session_id = %s
""".strip()

_READ_ROUND_ID = """
select id from public.sg8_round_executions
where sg8_session_id = %s and round_number = %s
""".strip()

_READ_ROUND_EVIDENCE = """
select report_id, canonical_digest
from public.sg8_round_report_evidence where round_execution_id = %s
""".strip()


# ---------------------------------------------------------------------------
# Read result shapes.
# ---------------------------------------------------------------------------
@dataclass(frozen=True, slots=True)
class Sg8SessionState:
    status: str
    source_collection_run_id: str
    report_id_1: str | None
    report_id_2: str | None
    verdict_reason: str | None


@dataclass(frozen=True, slots=True)
class Sg8SnapshotState:
    resolution_snapshot_id: str
    source_collection_run_id: str
    resolver_version: str
    resolver_hash: str
    fact_count: int
    content_hash: str


@dataclass(frozen=True, slots=True)
class Sg8RoundProvenance:
    """§5.3 LLM provenance of a Round-1 execution, with fields named EXACTLY as the
    schema columns (no repurposing).

    ``prompt_hash`` MUST be the **cryptographic SHA-256** of the exact prompt bytes sent
    to the provider — 64 lowercase hex chars — never a version token, template name, id,
    metadata or any surrogate. The **derivation** (hashing the real prompt bytes) belongs
    to the component that OWNS those bytes (the upstream runner, wired in U2 E2E); it may
    use :func:`canonical_prompt_sha256` for the canonical serialization. The store only
    **validates the format** (:func:`_require_sha256_hex`) before the first SQL and
    persists the value. ``adapter_version`` is the adapter's own version.

    The five identity fields (provider, model, model_version, prompt_hash,
    adapter_version) are mandatory for Round 1; ``params`` is optional context. None of
    these is persisted for Round 2 (zero-LLM)."""

    provider: str
    model: str
    model_version: str
    prompt_hash: str
    adapter_version: str
    params: Mapping[str, Any] = field(default_factory=dict)


# ---------------------------------------------------------------------------
# The port (implemented by PostgresSg8Store; U2 may inject a fake).
# ---------------------------------------------------------------------------
class Sg8Store(Protocol):
    def open_session(self, sg8_session_id: str, source_collection_run_id: str) -> None: ...
    def mark_awaiting_review(self, sg8_session_id: str) -> None: ...
    def mark_resolved(self, sg8_session_id: str) -> None: ...
    def freeze_snapshot(
        self,
        sg8_session_id: str,
        *,
        source_collection_run_id: str,
        resolution_snapshot_id: str,
        resolver_version: str,
        resolver_hash: str,
        fact_count: int,
        content_hash: str,
    ) -> None: ...
    def bind_reports(
        self, sg8_session_id: str, *, report_run_id_1: str, report_run_id_2: str
    ) -> None: ...
    def append_round(
        self,
        *,
        round_execution_id: str,
        sg8_session_id: str,
        round_number: int,
        source_collection_run_id: str,
        resolution_snapshot_id: str,
        provenance: Sg8RoundProvenance | None = None,
    ) -> None: ...
    def append_evidence(
        self,
        *,
        round_execution_id: str,
        sg8_session_id: str,
        report_run_id: str,
        canonical_digest: str,
    ) -> None: ...
    def mark_passed(self, sg8_session_id: str, *, verdict_reason: str) -> None: ...
    def mark_failed(self, sg8_session_id: str, *, verdict_reason: str) -> None: ...
    def read_session_state(self, sg8_session_id: str) -> Sg8SessionState | None: ...
    def read_snapshot_state(self, sg8_session_id: str) -> Sg8SnapshotState | None: ...
    def read_round_execution_id(self, sg8_session_id: str, round_number: int) -> str | None: ...
    def read_round_evidence(self, round_execution_id: str) -> Mapping[str, str]: ...


# ---------------------------------------------------------------------------
# The Postgres adapter.
# ---------------------------------------------------------------------------
class PostgresSg8Store:
    """Concrete ``Sg8Store`` over an injected transaction-owning connection.

    Writes are grouped into explicit, fail-closed transactions: multi-statement
    operations (freeze = insert snapshot + advance; binding = one atomic update)
    commit as a unit or roll back entirely. The database enforces the FSM,
    terminality, append-only and the PASS gate; this adapter only translates the
    caller's intent into parameterized SQL and the database's violations into
    domain exceptions.
    """

    def __init__(self, connection: Sg8Connection) -> None:
        self._connection = connection

    # -- lifecycle writes (each a fail-closed transaction) --------------------
    def open_session(self, sg8_session_id: str, source_collection_run_id: str) -> None:
        _nonblank(sg8_session_id, "sg8_session_id")
        _nonblank(source_collection_run_id, "source_collection_run_id")
        # NOTE: the INSERT sets ONLY id + source_collection_run_id — status defaults to
        # session_open and every other column to NULL. The adapter cannot express a
        # session born bound or terminal; the INSERT-guard trigger is the authority.
        self._write([(_INSERT_SESSION, (sg8_session_id, source_collection_run_id))])

    def mark_awaiting_review(self, sg8_session_id: str) -> None:
        _nonblank(sg8_session_id, "sg8_session_id")
        self._write([(_SET_STATUS, (Sg8State.R1_AWAITING_REVIEW.value, sg8_session_id))])

    def mark_resolved(self, sg8_session_id: str) -> None:
        _nonblank(sg8_session_id, "sg8_session_id")
        self._write([(_SET_STATUS, (Sg8State.R1_RESOLVED.value, sg8_session_id))])

    def freeze_snapshot(
        self,
        sg8_session_id: str,
        *,
        source_collection_run_id: str,
        resolution_snapshot_id: str,
        resolver_version: str,
        resolver_hash: str,
        fact_count: int,
        content_hash: str,
    ) -> None:
        _nonblank(sg8_session_id, "sg8_session_id")
        _nonblank(source_collection_run_id, "source_collection_run_id")
        _nonblank(resolution_snapshot_id, "resolution_snapshot_id")
        _nonblank(resolver_version, "resolver_version")
        _nonblank(resolver_hash, "resolver_hash")
        _nonblank(content_hash, "content_hash")
        if not isinstance(fact_count, int) or fact_count < 0:
            raise Sg8ContractViolation("fact_count must be a non-negative integer")
        # Snapshot is frozen BEFORE compute, atomically with the state advance: both
        # statements share one transaction — insert the frozen snapshot, then advance
        # the session to r1_snapshot_frozen. Any failure rolls back both.
        self._write(
            [
                (
                    _INSERT_SNAPSHOT,
                    (
                        resolution_snapshot_id,
                        sg8_session_id,
                        source_collection_run_id,
                        resolver_version,
                        resolver_hash,
                        fact_count,
                        content_hash,
                    ),
                ),
                (_SET_STATUS, (Sg8State.R1_SNAPSHOT_FROZEN.value, sg8_session_id)),
            ]
        )

    def bind_reports(
        self, sg8_session_id: str, *, report_run_id_1: str, report_run_id_2: str
    ) -> None:
        _nonblank(sg8_session_id, "sg8_session_id")
        _nonblank(report_run_id_1, "report_run_id_1")
        _nonblank(report_run_id_2, "report_run_id_2")
        # The two reports are bound ATOMICALLY in a single UPDATE that also advances the
        # session to r1_computed. Partial/identical/foreign bindings are rejected by the
        # schema (both-or-neither / distinct / composite FK / required-post-compute).
        self._write(
            [
                (
                    _BIND_REPORTS,
                    (report_run_id_1, report_run_id_2, Sg8State.R1_COMPUTED.value, sg8_session_id),
                )
            ]
        )

    def append_round(
        self,
        *,
        round_execution_id: str,
        sg8_session_id: str,
        round_number: int,
        source_collection_run_id: str,
        resolution_snapshot_id: str,
        provenance: Sg8RoundProvenance | None = None,
    ) -> None:
        _nonblank(round_execution_id, "round_execution_id")
        _nonblank(sg8_session_id, "sg8_session_id")
        _nonblank(source_collection_run_id, "source_collection_run_id")
        _nonblank(resolution_snapshot_id, "resolution_snapshot_id")
        if round_number not in (1, 2):
            raise Sg8ContractViolation("round_number must be 1 or 2")
        # SYMMETRIC per-round provenance contract, enforced fail-closed BEFORE any SQL
        # (U2A Gates 1+2): Round 1 requires complete, non-blank identity provenance with a
        # real SHA-256 prompt_hash; Round 2 must be zero-LLM (no provenance). The schema
        # (0008) is the authoritative backstop for the SAME contract — this is not a second
        # FSM, only the earliest fail-closed boundary.
        _validate_round_provenance(round_number, provenance)
        # Round 2 reuses the SAME source_collection_run_id + resolution_snapshot_id (and,
        # via evidence, the same reports) as Round 1 — the caller passes them; the schema's
        # composite FKs prove it.
        prov = _provenance_columns(provenance)
        self._write(
            [
                (
                    _INSERT_ROUND,
                    (
                        round_execution_id,
                        sg8_session_id,
                        round_number,
                        source_collection_run_id,
                        resolution_snapshot_id,
                        *prov,
                    ),
                )
            ]
        )

    def append_evidence(
        self,
        *,
        round_execution_id: str,
        sg8_session_id: str,
        report_run_id: str,
        canonical_digest: str,
    ) -> None:
        _nonblank(round_execution_id, "round_execution_id")
        _nonblank(sg8_session_id, "sg8_session_id")
        _nonblank(report_run_id, "report_run_id")
        _nonblank(canonical_digest, "canonical_digest")
        # Evidence is append-only and partitioned by round_execution_id. Membership
        # (report_id is one of the two frozen reports) and uniqueness are the schema's.
        self._write(
            [
                (
                    _INSERT_EVIDENCE,
                    (round_execution_id, sg8_session_id, report_run_id, canonical_digest),
                )
            ]
        )

    def mark_passed(self, sg8_session_id: str, *, verdict_reason: str) -> None:
        # PASS is issued only after every round + evidence is persisted (the runner's
        # sequence). The schema's PASS gate independently refuses 'passed' without the
        # complete, digest-consistent proof — this adapter does not (and must not) re-check it.
        self._mark_terminal(sg8_session_id, Sg8State.PASSED, verdict_reason)

    def mark_failed(self, sg8_session_id: str, *, verdict_reason: str) -> None:
        self._mark_terminal(sg8_session_id, Sg8State.FAILED, verdict_reason)

    def _mark_terminal(
        self, sg8_session_id: str, state: Sg8State, verdict_reason: str
    ) -> None:
        _nonblank(sg8_session_id, "sg8_session_id")
        _nonblank(verdict_reason, "verdict_reason")
        self._write([(_MARK_TERMINAL, (state.value, verdict_reason, sg8_session_id))])

    # -- reads (state for replay + comparison) --------------------------------
    def read_session_state(self, sg8_session_id: str) -> Sg8SessionState | None:
        row = self._read_one(_READ_SESSION, (sg8_session_id,))
        if row is None:
            return None
        if len(row) != 5:
            raise Sg8PersistenceError("session query returned an invalid shape")
        return Sg8SessionState(
            status=str(row[0]),
            source_collection_run_id=str(row[1]),
            report_id_1=None if row[2] is None else str(row[2]),
            report_id_2=None if row[3] is None else str(row[3]),
            verdict_reason=None if row[4] is None else str(row[4]),
        )

    def read_snapshot_state(self, sg8_session_id: str) -> Sg8SnapshotState | None:
        row = self._read_one(_READ_SNAPSHOT, (sg8_session_id,))
        if row is None:
            return None
        if len(row) != 6:
            raise Sg8PersistenceError("snapshot query returned an invalid shape")
        return Sg8SnapshotState(
            resolution_snapshot_id=str(row[0]),
            source_collection_run_id=str(row[1]),
            resolver_version=str(row[2]),
            resolver_hash=str(row[3]),
            fact_count=int(row[4]),
            content_hash=str(row[5]),
        )

    def read_round_execution_id(self, sg8_session_id: str, round_number: int) -> str | None:
        if round_number not in (1, 2):
            raise Sg8ContractViolation("round_number must be 1 or 2")
        row = self._read_one(_READ_ROUND_ID, (sg8_session_id, round_number))
        return None if row is None else str(row[0])

    def read_round_evidence(self, round_execution_id: str) -> Mapping[str, str]:
        _nonblank(round_execution_id, "round_execution_id")
        cursor = self._connection.cursor()
        try:
            cursor.execute(_READ_ROUND_EVIDENCE, (round_execution_id,))
            rows = cursor.fetchall()
            self._end_read()  # terminate the read-only txn; connection left reusable
        except Exception as exc:  # noqa: BLE001 — mapped to a domain error below
            self._safe_rollback()
            raise self._map_error(exc) from exc
        finally:
            cursor.close()
        evidence: dict[str, str] = {}
        for row in rows:
            if len(row) != 2:
                raise Sg8PersistenceError("evidence query returned an invalid shape")
            evidence[str(row[0])] = str(row[1])
        return evidence

    # -- transactional core ---------------------------------------------------
    def _write(self, statements: Sequence[tuple[str, tuple[Any, ...]]]) -> None:
        cursor = self._connection.cursor()
        try:
            for sql, params in statements:
                cursor.execute(sql, params)
            self._connection.commit()
        except Exception as exc:  # noqa: BLE001 — every DB error becomes a domain error
            self._safe_rollback()
            raise self._map_error(exc) from exc
        finally:
            cursor.close()

    def _read_one(self, sql: str, params: tuple[Any, ...]) -> Sequence[Any] | None:
        cursor = self._connection.cursor()
        try:
            cursor.execute(sql, params)
            row = cursor.fetchone()
            self._end_read()  # terminate the read-only txn; connection left reusable
            return row
        except Exception as exc:  # noqa: BLE001
            self._safe_rollback()
            raise self._map_error(exc) from exc
        finally:
            cursor.close()

    def _end_read(self) -> None:
        # A read mutates nothing; rolling back its (exclusively-owned) transaction ends it
        # cleanly and leaves the connection reusable, discarding no data work. A failure to
        # terminate means the connection is broken — surfaced (mapped) rather than hidden.
        self._connection.rollback()

    def _safe_rollback(self) -> None:
        try:
            self._connection.rollback()
        except Exception:  # noqa: BLE001 — a rollback failure must not mask the cause
            pass

    @staticmethod
    def _map_error(exc: BaseException) -> Sg8PersistenceError:
        # Already a domain error (e.g., a shape check): propagate unchanged.
        if isinstance(exc, Sg8PersistenceError):
            return exc
        code = _sqlstate(exc)
        if code == _SQLSTATE_FK:
            return Sg8ForeignKeyViolation("SG-8 foreign-key invariant violated")
        if code == _SQLSTATE_UNIQUE:
            return Sg8UniqueViolation("SG-8 uniqueness invariant violated")
        if code == _SQLSTATE_CHECK:
            return Sg8CheckViolation("SG-8 check invariant violated")
        if code == _SQLSTATE_RESTRICT:
            return Sg8IntegrityGuardViolation(
                "SG-8 trigger invariant violated (state machine / terminality / "
                "append-only / PASS gate)"
            )
        return Sg8PersistenceError("SG-8 persistence failed")


# ---------------------------------------------------------------------------
# Helpers.
# ---------------------------------------------------------------------------
# A SHA-256 rendered as 64 lowercase hex chars — the ONLY accepted shape for a prompt hash.
_SHA256_HEX_RE = re.compile(r"^[0-9a-f]{64}$")


def _nonblank(value: str, field: str) -> None:
    if not isinstance(value, str) or not value.strip():
        raise Sg8ContractViolation(f"{field} must be non-blank")


def _require_sha256_hex(value: str, field: str) -> None:
    # STRUCTURAL validation only: proves the value IS a well-formed SHA-256 digest, never
    # that it is the RIGHT one. The derivation (hashing the real prompt bytes) is upstream's
    # (see ``canonical_prompt_sha256``); U2 integration recomputes and compares.
    if not isinstance(value, str) or _SHA256_HEX_RE.match(value) is None:
        raise Sg8ContractViolation(
            f"{field} must be a SHA-256 as 64 lowercase hex chars (never a version token)"
        )


def _validate_round_provenance(
    round_number: int, provenance: Sg8RoundProvenance | None
) -> None:
    """Symmetric, fail-closed provenance contract enforced BEFORE any SQL (U2A Gates 1+2).

    * Round 2 → ``provenance`` MUST be ``None`` (zero-LLM).
    * Round 1 → ``provenance`` MUST be present with the five identity fields non-blank and
      ``prompt_hash`` a real SHA-256 (64 lowercase hex). ``params`` is optional context but,
      when given, must be a mapping.

    This mirrors — never replaces — the schema's authoritative CHECKs
    (``sg8_round_executions_provenance_by_round_chk`` / ``…_prompt_hash_format_chk``).
    """
    if round_number == 2:
        if provenance is not None:
            raise Sg8ContractViolation("Round 2 must be zero-LLM: no provenance permitted")
        return
    # round_number == 1
    if provenance is None:
        raise Sg8ContractViolation("Round 1 requires complete LLM provenance")
    _nonblank(provenance.provider, "provenance.provider")
    _nonblank(provenance.model, "provenance.model")
    _nonblank(provenance.model_version, "provenance.model_version")
    _nonblank(provenance.adapter_version, "provenance.adapter_version")
    _require_sha256_hex(provenance.prompt_hash, "provenance.prompt_hash")
    if not isinstance(provenance.params, Mapping):
        raise Sg8ContractViolation("provenance.params must be a mapping")


def canonical_prompt_sha256(prompt: bytes) -> str:
    """Canonical §5.3 derivation of ``llm_prompt_hash`` for the OWNER of the prompt bytes.

    The upstream component that holds the prompt (the runner, wired in U2 E2E) calls this
    to populate ``Sg8RoundProvenance.prompt_hash``; ``PostgresSg8Store`` NEVER calls it —
    the store only validates the resulting FORMAT and persists the value. U2 integration
    tests recompute via this same function over the captured prompt and compare the digest
    byte-for-byte with the persisted one.

    Canonical serialization: the input is the EXACT bytes sent to the provider. A caller
    holding a ``str`` MUST encode it as UTF-8 (no BOM, no normalization) itself — this
    function refuses anything but ``bytes`` so the encoding decision is explicit at the call
    site and never implicit here. The digest is ``sha256(prompt)`` as 64 lowercase hex chars;
    identical bytes ⇒ identical digest, any byte change ⇒ a different digest.
    """
    if not isinstance(prompt, (bytes, bytearray)):
        raise Sg8ContractViolation(
            "prompt must be the exact raw bytes sent to the provider (encode str as UTF-8 upstream)"
        )
    return hashlib.sha256(bytes(prompt)).hexdigest()


def _sqlstate(exc: BaseException) -> str | None:
    # psycopg3 exposes ``sqlstate``; psycopg2 exposes ``pgcode`` — both, no driver import.
    code = getattr(exc, "sqlstate", None)
    if code is None:
        code = getattr(exc, "pgcode", None)
    return None if code is None else str(code)


def _provenance_columns(
    provenance: Sg8RoundProvenance | None,
) -> tuple[Any, Any, Any, Any, Any, Any]:
    """Map §5.3 provenance to the 6 llm_* columns; ``None`` → all NULL (Round-2 zero-LLM).

    Column order matches the INSERT: llm_provider, llm_model, llm_model_version,
    llm_prompt_hash, llm_params_json, llm_adapter_version. Field names map 1:1 to the
    columns (``prompt_hash`` → ``llm_prompt_hash``, ``adapter_version`` → ``llm_adapter_version``),
    with NO repurposing of a version into a hash column. All-or-nothing / non-blank is
    enforced by the schema CHECK — not duplicated here.
    """

    if provenance is None:
        return (None, None, None, None, None, None)
    params: Mapping[str, Any] = provenance.params if isinstance(provenance.params, Mapping) else {}
    return (
        provenance.provider,
        provenance.model,
        provenance.model_version,
        provenance.prompt_hash,
        json.dumps(params, ensure_ascii=False, separators=(",", ":"), sort_keys=True),
        provenance.adapter_version,
    )
