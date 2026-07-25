"""SG-8 E2E integration bootstrap — the ONLY module that imports the psycopg driver.

Driver isolation (U2B): the deterministic core imports NOTHING from here —
``postgres_sg8.py`` and ``sg8_coordinator.py`` stay driver-free. This module is used
only by the SG-8 E2E suite (``tests_integration``) and the ``sg8-integration-local``
workflow, and it talks ONLY to a DISPOSABLE local Supabase on loopback.

Contract:
  * DBURL is HARD-PINNED to 127.0.0.1:54322 (the local dev stack) and re-asserted at
    connect time — a non-loopback URL refuses to connect;
  * ``postgres/postgres`` is the Supabase CLI's fixed LOCAL dev credential (not a secret);
  * NO ``supabase link``, NO access token, NO Environment, NO secret, NO remote host;
  * one DEDICATED connection per execution/test; the caller (a ``PostgresSg8Store`` or the
    test) owns it EXCLUSIVELY and closes it explicitly.
"""

from __future__ import annotations

import psycopg  # the injected DB driver — imported here and NOWHERE in the core

DBURL = "postgresql://postgres:postgres@127.0.0.1:54322/postgres"
_LOOPBACK_PREFIX = "postgresql://postgres:postgres@127.0.0.1:54322/"


def connect_local() -> "psycopg.Connection":
    """Open ONE dedicated loopback connection to the disposable local stack.

    Autocommit stays False (the store owns explicit commit/rollback). The caller closes
    it explicitly. Refuses any non-loopback DBURL fail-closed.
    """
    if not DBURL.startswith(_LOOPBACK_PREFIX):
        raise RuntimeError("DBURL must be loopback 127.0.0.1:54322 — refusing to connect")
    return psycopg.connect(DBURL)
