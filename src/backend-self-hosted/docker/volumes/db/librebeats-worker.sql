-- NOTE: change to your own passwords for production environments
\set pgpass `echo "$POSTGRES_PASSWORD"`

-- the migration runner grants this role its privileges in "4 librebeats_worker.sql",
-- here it only needs to exist with a login so the audio service can connect
CREATE ROLE librebeats_worker LOGIN PASSWORD :'pgpass';
