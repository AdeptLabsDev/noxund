-- P3B V2 — the synthetic probe. Nothing real from the NOXUND schema.
-- This is the change whose DDL must be atomic with its flyway_schema_history row.
CREATE TABLE spike.flyway_atomicity_gap_probe (
  id integer PRIMARY KEY
);
