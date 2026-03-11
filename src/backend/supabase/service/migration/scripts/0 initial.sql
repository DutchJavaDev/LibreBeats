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

CREATE TABLE IF NOT EXISTS Librebeats.Audio (
    Id SERIAL PRIMARY KEY,
    AudioLocation TEXT NOT NULL,
    ThumbnailLocation TEXT NOT NULL,
    DownloadCount INT NOT NULL DEFAULT 0,
    CreatedAtUtc TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

ALTER TABLE Librebeats.Audio ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS Librebeats.Song (
    Id SERIAL PRIMARY KEY,
    AudioId SERIAL NOT NULL REFERENCES Librebeats.Audio(Id) ON DELETE CASCADE,
    Title TEXT NOT NULL,
    Artist TEXT NOT NULL,
    Album TEXT NOT NULL,
    Tags TEXT NOT NULL,
    StreamingUrl TEXT NOT NULL,
    ThumbnailUrl TEXT NOT NULL,
);

ALTER TABLE Librebeats.Song ENABLE ROW LEVEL SECURITY;

-- ONLY authenticated users can access songs
CREATE POLICY "Authenticated users can access all songs" ON Librebeats.Song
    FOR SELECT
    TO authenticated
    USING (true);


CREATE TABLE IF NOT EXISTS Librebeats.YtdlpOutputLog (
    Id INT PRIMARY KEY,
    Title TEXT NOT NULL,
    ProgressState INT NOT NULL,
    OutputBase64 TEXT NOT NULL,
    ErrorOutputBase64 TEXT,
    StartedAtUtc TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    FinishedAtUtc TIMESTAMP WITH TIME ZONE
);

ALTER TABLE Librebeats.YtdlpOutputLog ENABLE ROW LEVEL SECURITY;

-- Only service role can access the YtdlpOutputLog table
CREATE POLICY "Authenticated users can access YtdlpOutputLog" ON Librebeats.YtdlpOutputLog
    FOR SELECT
    TO authenticated
    USING (true);
