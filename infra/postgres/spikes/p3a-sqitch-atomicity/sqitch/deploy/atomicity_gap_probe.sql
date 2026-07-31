-- Deploy noxund_p3a_spike:atomicity_gap_probe to pg
BEGIN;
CREATE TABLE spike.atomicity_gap_probe(id integer PRIMARY KEY);
COMMIT;
