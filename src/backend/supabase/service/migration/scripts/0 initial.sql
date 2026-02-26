-- 1. Schema Setup
CREATE SCHEMA IF NOT EXISTS librebeats;

-- 4. Internal Table
CREATE TABLE IF NOT EXISTS Librebeats.Migrations(
    Id serial PRIMARY KEY,
    FileName text NOT NULL,
    Content text NOT NULL,
    RunOn timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS: With no policies, it is accessible ONLY by service_role
ALTER TABLE Librebeats.Migrations ENABLE ROW LEVEL SECURITY;

-- 5. Final Grants
-- GRANT USAGE ON SCHEMA librebeats, pgmq_public, pgmq TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA librebeats TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA librebeats TO service_role;

-- Create the audio processing queue
SELECT * FROM pgmq.create('audiopipe-input');

-- Example insert into the queue
-- SELECT * FROM pgmq.send('audiopipe-input', '{"key": "path/to/audio/file.mp3", "metadata": {"artist": "Artist Name", "album": "Album Name"}}', 0);

CREATE TABLE IF NOT EXISTS Librebeats.Audio (
    Id serial PRIMARY KEY,
    SourceId TEXT NOT NULL,
    SourceName TEXT NOT NULL,
    StorageLocation TEXT,
    ThumbnailLocation TEXT,
    DownloadCount INT NOT NULL DEFAULT 0,
    CreatedAtUtc TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS Librebeats.YtdlpOutputLog (
    Id INT PRIMARY KEY,
    AudioId serial,
    Title TEXT NOT NULL,
    ProgressState INT NOT NULL,
    OutputLogBase64 TEXT,
    ErrorOutputLogBase64 TEXT,
    CreatedAtUtc TIMESTAMP NOT NULL DEFAULT NOW(),
    FinishedAtUtc TIMESTAMP
);


