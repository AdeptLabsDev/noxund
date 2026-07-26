"""Driver-agnostic PostgreSQL persistence adapter for the SG-8 durable session.

U1 of DATA-SG8-001 stage 3 part 2, revised by DEC-0025 (LLM decoupling). This module
persists the SG-8 durable state (``sg8_sessions`` / ``sg8_resolution_snapshots`` /
``sg8_round_executions`` / ``sg8_round_report_evidence``) behind a small port
(``Sg8Store``) that the offline runner (``sg8_runner``) drives. It:

* imports **no** database driver (accepts an injected PEP-249-like connection);
* reads **no** environment variable and knows **no** URL / password / Environment / secret;
* does **not** connect to any database (that is the E2E, against a local disposable Supabase);
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

Provider-neutral by contract (DEC-0025): the SG-8 authoritative path is entirely
deterministic and depends on **no** LLM, remote model or external provider. Each round
persists a **deterministic compute provenance** (``Sg8ComputeProvenance``) whose fields
name the versioned engine + artifacts/config that actually determine the result — never
a provider, model or prompt. Both Round 1 and Round 2 carry the SAME provenance (same
engine, same versioned artifacts, same ``compute_manifest_hash``); a manifest divergence
is a FAIL, independently of the digests. This adapter only **validates the format** of
the manifest hash (:func:`_require_manifest_hash`) and persists the value — the canonical
**derivation** of the manifest belongs to the wiring layer that owns the artifact
identities (``sg8_coordinator.canonical_compute_manifest``).

It reuses the connection abstraction (``CursorLike``) of ``postgres_entity_resolution``
and the ``Sg8State`` enum of ``sg8_runner``.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any, Mapping, Protocol, Sequence

from .postgres_entity_resolution import CursorLike
from .sg8_runner import Sg8State


# ---------------------------------------------------------------------------
# Injected transaction-owning connection (no driver import; caller provides it).
# ---------------------------------------------------------------------------
class Sg8Connection(Protocol):
    """A PEP-249-like connection whose transaction boundary is owned EXCLUSIVELY by the
    store for the store's lifetime.

    The adapter never constructs this; the E2E injects a real driver connection (or, in
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
    """A CHECK was violated (binding shape, terminal-state/verdict, round number,
    manifest-hash format, …)."""


class Sg8NotNullViolation(Sg8PersistenceError):
    """A NOT NULL column was omitted (e.g., a round missing its compute provenance)."""


class Sg8IntegrityGuardViolation(Sg8PersistenceError):
    """A trigger-enforced invariant was violated — the state machine, terminality,
    append-only immutability or the PASS gate (all raised by the schema with SQLSTATE
    ``restrict_violation`` / 23001)."""


class Sg8ContractViolation(Sg8PersistenceError):
    """A caller argument violated the adapter contract before any SQL was issued."""


# SQLSTATE → domain-exception mapping (driver-agnostic).
_SQLSTATE_NOT_NULL = "23502"
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
  compute_engine_name, compute_engine_version, compute_manifest_hash
)
values (%s, %s, %s, %s, %s, %s, %s, %s)
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
class Sg8ComputeProvenance:
    """Deterministic compute provenance of ONE round (DEC-0025), with fields named
    exactly as the schema columns (no provider/model/prompt, no persistence adapter, no
    free-form params).

    * ``engine_name`` / ``engine_version`` — the versioned deterministic engine that
      produced the round (the pipeline composition), never a model id. Persisted as
      columns AND folded into the manifest, so the PASS gate can compare them explicitly
      (defense-in-depth) on top of the manifest equality;
    * ``manifest_hash`` — the ``compute_manifest_hash``: the **cryptographic SHA-256**
      (64 lowercase hex) of the canonical set of ALL computational determinants (manifest
      format version + engine identity + pipeline/resolver/rule/rubric/opportunity
      versions + hashes). Its **derivation** belongs to the component that owns those
      identities (``sg8_coordinator.canonical_compute_manifest``); this store only
      **validates the format** (:func:`_require_manifest_hash`) and persists the value.
      It contains NO credential, timestamp, execution UUID, local path or unstable datum,
      and NO persistence-adapter identity (persistence does not participate in the compute).

    Round 1 and Round 2 carry the SAME provenance (same engine, same manifest); the schema
    PASS gate refuses ``passed`` when the two rounds' ``compute_engine_name`` /
    ``compute_engine_version`` / ``compute_manifest_hash`` differ, even if the digests
    coincidentally match."""

    engine_name: str
    engine_version: str
    manifest_hash: str


# ---------------------------------------------------------------------------
# The port (implemented by PostgresSg8Store; the E2E may inject a fake).
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
        provenance: Sg8ComputeProvenance,
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
        provenance: Sg8ComputeProvenance,
    ) -> None:
        _nonblank(round_execution_id, "round_execution_id")
        _nonblank(sg8_session_id, "sg8_session_id")
        _nonblank(source_collection_run_id, "source_collection_run_id")
        _nonblank(resolution_snapshot_id, "resolution_snapshot_id")
        if round_number not in (1, 2):
            raise Sg8ContractViolation("round_number must be 1 or 2")
        # DETERMINISTIC compute provenance is MANDATORY and SYMMETRIC across rounds
        # (DEC-0025), enforced fail-closed BEFORE any SQL: complete, non-blank engine
        # identity with a real SHA-256 compute_manifest_hash. The schema (0008) is the
        # authoritative backstop for the SAME contract (NOT NULL + format CHECK) — this is
        # not a second FSM, only the earliest fail-closed boundary. There is NO provider,
        # model or prompt: the SG-8 authoritative path depends on no external engine.
        _validate_compute_provenance(provenance)
        # Round 2 reuses the SAME source_collection_run_id + resolution_snapshot_id (and,
        # via evidence, the same reports) AND the SAME compute provenance as Round 1 — the
        # caller passes them; the schema's composite FKs + PASS gate manifest-equality prove it.
        prov = _compute_provenance_columns(provenance)
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
        # complete, digest-consistent AND manifest-consistent proof — this adapter does
        # not (and must not) re-check it.
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
        if code == _SQLSTATE_NOT_NULL:
            return Sg8NotNullViolation("SG-8 NOT NULL invariant violated")
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
# A SHA-256 rendered as 64 lowercase hex chars — the ONLY accepted shape for the
# compute_manifest_hash.
_MANIFEST_HASH_RE = re.compile(r"^[0-9a-f]{64}$")


def _nonblank(value: str, field: str) -> None:
    if not isinstance(value, str) or not value.strip():
        raise Sg8ContractViolation(f"{field} must be non-blank")


def _require_manifest_hash(value: str, field: str) -> None:
    # STRUCTURAL validation only: proves the value IS a well-formed SHA-256 digest, never
    # that it is the RIGHT one. The derivation (canonical manifest of the versioned
    # artifacts) is the wiring layer's (see ``sg8_coordinator.canonical_compute_manifest``);
    # the E2E recomputes and compares.
    if not isinstance(value, str) or _MANIFEST_HASH_RE.match(value) is None:
        raise Sg8ContractViolation(
            f"{field} must be a SHA-256 as 64 lowercase hex chars (never a version token)"
        )


def _validate_compute_provenance(provenance: Sg8ComputeProvenance | None) -> None:
    """Mandatory, symmetric deterministic-provenance contract enforced BEFORE any SQL
    (DEC-0025).

    BOTH rounds require complete provenance: the engine identity fields non-blank and
    ``manifest_hash`` a real SHA-256 (64 lowercase hex). There is no provider/model/prompt,
    no persistence adapter, no free-form params, and no per-round asymmetry — Round 1 and
    Round 2 carry the SAME provenance.

    This mirrors — never replaces — the schema's authoritative NOT NULL columns +
    ``sg8_round_executions_manifest_hash_format_chk`` + the PASS-gate engine/manifest equality.
    """
    if provenance is None:
        raise Sg8ContractViolation("compute provenance is required for every round")
    _nonblank(provenance.engine_name, "provenance.engine_name")
    _nonblank(provenance.engine_version, "provenance.engine_version")
    _require_manifest_hash(provenance.manifest_hash, "provenance.manifest_hash")


def _sqlstate(exc: BaseException) -> str | None:
    # psycopg3 exposes ``sqlstate``; psycopg2 exposes ``pgcode`` — both, no driver import.
    code = getattr(exc, "sqlstate", None)
    if code is None:
        code = getattr(exc, "pgcode", None)
    return None if code is None else str(code)


def _compute_provenance_columns(
    provenance: Sg8ComputeProvenance,
) -> tuple[Any, Any, Any]:
    """Map the deterministic provenance to the 3 compute_* columns (DEC-0025).

    Column order matches the INSERT: compute_engine_name, compute_engine_version,
    compute_manifest_hash. Field names map 1:1 to the columns. The non-blank / format
    invariants are enforced by :func:`_validate_compute_provenance` (adapter) and by the
    schema CHECKs (authoritative) — not duplicated here.
    """

    return (
        provenance.engine_name,
        provenance.engine_version,
        provenance.manifest_hash,
    )
