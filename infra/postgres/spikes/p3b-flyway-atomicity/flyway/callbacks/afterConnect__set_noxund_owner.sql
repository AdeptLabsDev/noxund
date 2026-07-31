-- P3B — Flyway-13 least-privilege callback (binding correction; replaces flyway.initSql).
-- Runs after EVERY Flyway JDBC connect. noxund_migrator (NOINHERIT) assumes the
-- owner role for the session so migration objects and flyway_schema_history are
-- owned by noxund_owner. The callback has its OWN boundary: whether it sustains
-- the contract on ALL internal Flyway connections is NOT assumed — it is proven
-- executably by LP-0 (the V1 guard + ownership checks).
SET ROLE noxund_owner;
