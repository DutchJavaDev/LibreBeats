-- 1. Schema Setup
CREATE EXTENSION IF NOT EXISTS pgmq;
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

CREATE TABLE IF NOT EXISTS Librebeats.RawBeat (
    Id SERIAL PRIMARY KEY,
    Source TEXT NOT NULL,
    AudioLocation TEXT NOT NULL,
    ThumbnailLocation TEXT NOT NULL,
    DownloadCount INT NOT NULL DEFAULT 0,--?????????????????????
    CreatedAtUtc TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    Durration INTEGER NOT NULL,
    CONSTRAINT unique_source UNIQUE (Source),
    CONSTRAINT unique_audio_location UNIQUE (AudioLocation),
    CONSTRAINT unique_thumbnail_location UNIQUE (ThumbnailLocation)

);

ALTER TABLE Librebeats.RawBeat ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS Librebeats.Beat (
    Id SERIAL PRIMARY KEY,
    RawBeatId SERIAL NOT NULL REFERENCES Librebeats.RawBeat(Id) ON DELETE CASCADE,
    Title TEXT NOT NULL,
    Artist TEXT NOT NULL,
    Tags TEXT NOT NULL,
    StreamingUrl TEXT NOT NULL,
    ThumbnailUrl TEXT NOT NULL,
    CONSTRAINT unique_streaming_url UNIQUE (StreamingUrl),
    CONSTRAINT unique_thumbnail_url UNIQUE (ThumbnailUrl)
);

ALTER TABLE Librebeats.Beat ENABLE ROW LEVEL SECURITY;

-- ONLY authenticated users can access songs
CREATE POLICY "Authenticated users can access all songs" ON Librebeats.Beat
    FOR SELECT
    TO authenticated
    USING (true);


CREATE TABLE IF NOT EXISTS Librebeats.AudioOutputLog (
    Id SERIAL PRIMARY KEY,
    Title TEXT NOT NULL,
    ProgressState INT NOT NULL,
    Output TEXT NULL,
    ErrorOutput TEXT,
    StartedAtUtc TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    FinishedAtUtc TIMESTAMP WITH TIME ZONE
);

ALTER TABLE Librebeats.AudioOutputLog ENABLE ROW LEVEL SECURITY;

-- Only service role can access the AudioOutputLog table
CREATE POLICY "Authenticated users can access AudioOutputLog" ON Librebeats.AudioOutputLog
    FOR SELECT
    TO authenticated
    USING (true);


-- Index for foreign key performance
CREATE INDEX IF NOT EXISTS idx_beat_rawbeat_id ON Librebeats.Beat(RawBeatId);


-- Ensure future tables inherit grants
ALTER DEFAULT PRIVILEGES IN SCHEMA Librebeats GRANT ALL ON TABLES TO service_role;