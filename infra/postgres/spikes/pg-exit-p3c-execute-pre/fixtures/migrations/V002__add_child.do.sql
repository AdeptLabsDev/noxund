-- V002 — add a dependent table (predecessor = V001).
-- One DO block, runs as noxund_owner.
DO $noxund_v002$
BEGIN
    CREATE TABLE noxund_app_spike.track (
        id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        artist_id bigint NOT NULL REFERENCES noxund_app_spike.artist (id),
        title     text NOT NULL
    );
    CREATE INDEX track_artist_idx ON noxund_app_spike.track (artist_id);
END
$noxund_v002$;
