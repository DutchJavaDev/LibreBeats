-- 1. Schema Setup
CREATE SCHEMA IF NOT EXISTS Librebeats;

-- 4. Internal Table
CREATE TABLE IF NOT EXISTS Librebeats.Migrations(
    Id SERIAL PRIMARY KEY,
    FileName TEXT NOT NULL,
    Content TEXT NOT NULL,
    RunOn TIMESTAMP NOT NULL DEFAULT now()
);

-- Enable RLS: With no policies, it is accessible ONLY by service_role
ALTER TABLE Librebeats.Migrations ENABLE ROW LEVEL SECURITY;

-- 5. Final Grants
-- GRANT USAGE ON SCHEMA librebeats, pgmq_public, pgmq TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA Librebeats TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA Librebeats TO service_role;

-- Create the audio processing queue
SELECT * FROM pgmq.create('audiopipe-input');

-- Example insert into the queue
-- SELECT * FROM pgmq.send('audiopipe-input', '{"key": "path/to/audio/file.mp3", "metadata": {"artist": "Artist Name", "album": "Album Name"}}', 0);

CREATE TABLE IF NOT EXISTS Librebeats.Audio (
    Id SERIAL PRIMARY KEY,
    SourceId TEXT NOT NULL,
    SourceName TEXT NOT NULL,
    StorageLocation TEXT,
    ThumbnailLocation TEXT,
    DownloadCount INT NOT NULL DEFAULT 0,
    CreatedAtUtc TIMESTAMP NOT NULL DEFAULT NOW()
);

ALTER TABLE Librebeats.Audio ENABLE ROW LEVEL SECURITY;

-- ONLY authenticated users can access all the Audio table
CREATE POLICY "Authenticated users can access all audio" ON Librebeats.Audio
    FOR SELECT
    TO authenticated
    USING (true);

CREATE TABLE IF NOT EXISTS Librebeats.YtdlpOutputLog (
    Id INT PRIMARY KEY,
    Title TEXT NOT NULL,
    ProgressState INT NOT NULL,
    OutputBase64 TEXT NOT NULL,
    ErrorOutputBase64 TEXT,
    StartedAtUtc TIMESTAMP NOT NULL DEFAULT NOW(),
    FinishedAtUtc TIMESTAMP
);

ALTER TABLE Librebeats.YtdlpOutputLog ENABLE ROW LEVEL SECURITY;

-- Only service role can access the YtdlpOutputLog table
CREATE POLICY "Service role can access YtdlpOutputLog" ON Librebeats.YtdlpOutputLog
    FOR SELECT
    TO authenticated
    USING (true);
