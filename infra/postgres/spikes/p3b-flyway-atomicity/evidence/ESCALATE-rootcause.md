# P3B ESCALATE — LEAST-PRIVILEGE CONTRACT NOT SUPPORTED

The approved afterConnect callback (SET ROLE noxund_owner) does NOT sustain the
least-privilege identity on Flyway's schema-history (metadata) connection. Flyway
creates public.flyway_schema_history as noxund_migrator, which by contract holds no
direct CREATE on public -> 'permission denied for schema public' (SQLSTATE 42501).
Proven: owner_create_public=t, migrator_direct_create_public=f.

Honoring the contract forbids granting the migrator direct DDL privilege (no workaround),
so V1 is not applied, instrumentation is not installed, and the fatal V2 test is not reached.
Per Bloco 2/3: no postgres identity, no trigger, no V2, no workaround, no auto-rerun.
