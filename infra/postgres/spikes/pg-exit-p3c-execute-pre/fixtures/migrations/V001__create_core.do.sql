-- V001 — create core application tables.
-- Exactly ONE server-accepted command (a single plpgsql DO block). Executed by
-- the runner under SET LOCAL ROLE noxund_owner, so all objects are owned by
-- noxund_owner. Multi-operation migration expressed inside one DO block.
DO $noxund_v001$
BEGIN
    CREATE TABLE noxund_app_spike.artist (
        id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        name       text NOT NULL,
        created_at timestamptz NOT NULL DEFAULT pg_catalog.clock_timestamp()
    );
    CREATE INDEX artist_name_idx ON noxund_app_spike.artist (name);
END
$noxund_v001$;
