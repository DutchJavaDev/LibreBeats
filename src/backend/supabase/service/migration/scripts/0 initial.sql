-- 1. Enable PGMQ extension
CREATE EXTENSION IF NOT EXISTS pgmq;

-- 2. Create custom schema
CREATE SCHEMA IF NOT EXISTS Librebeats;

-- Grant USAGE only to authenticated and service_role (anon never gets in)
GRANT USAGE ON SCHEMA Librebeats TO authenticated, service_role;

-- 3. Migration tracking table (service_role only)
CREATE TABLE IF NOT EXISTS Librebeats.Migrations (
    Id INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    MigrationFileId INT NOT NULL,
    FileName TEXT NOT NULL,
    Content TEXT NOT NULL,
    RunOn TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
ALTER TABLE Librebeats.Migrations ENABLE ROW LEVEL SECURITY;
-- only service_role can access (bypass RLS)

-- 4. PGMQ queue – service_role only
SELECT * FROM pgmq.create('audiopipe-input');
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pgmq TO service_role;

-- 5. RawBeat table – service_role only (internal staging)
CREATE TABLE IF NOT EXISTS Librebeats.RawBeat (
    Id INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    Source TEXT NOT NULL,
    AudioLocation TEXT NOT NULL,
    ThumbnailLocation TEXT NOT NULL,
    DownloadCount INT NOT NULL DEFAULT 0,
    CreatedAtUtc TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    Duration INTEGER NOT NULL,
    CONSTRAINT unique_source UNIQUE (Source),
    CONSTRAINT unique_audio_location UNIQUE (AudioLocation),
    CONSTRAINT unique_thumbnail_location UNIQUE (ThumbnailLocation)
);
ALTER TABLE Librebeats.RawBeat ENABLE ROW LEVEL SECURITY;
-- only service_role

-- Needed to fetch duration from RawBeat for Beat creation, but no other access
GRANT SELECT ON librebeats.rawbeat TO authenticated;

-- SELECT policy for authenticated users (no INSERT/UPDATE/DELETE)
CREATE POLICY "authenticated_select_rawbeat" ON Librebeats.RawBeat
    FOR SELECT TO authenticated USING (true);

-- 6. Beat table – authenticated can SELECT only
CREATE TABLE IF NOT EXISTS Librebeats.Beat (
    Id INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    RawBeatId INTEGER NOT NULL REFERENCES Librebeats.RawBeat(Id) ON DELETE CASCADE,
    Title TEXT NOT NULL,
    Artist TEXT NOT NULL,
    Tags TEXT NOT NULL,
    StreamingUrl TEXT NOT NULL,
    ThumbnailUrl TEXT NOT NULL,
    Published BOOLEAN NOT NULL DEFAULT TRUE,   -- optional visibility control
    CONSTRAINT unique_streaming_url UNIQUE (StreamingUrl),
    CONSTRAINT unique_thumbnail_url UNIQUE (ThumbnailUrl)
);
ALTER TABLE Librebeats.Beat ENABLE ROW LEVEL SECURITY;

-- SELECT policy for authenticated users (no INSERT/UPDATE/DELETE)
CREATE POLICY "authenticated_select_beat" ON Librebeats.Beat
    FOR SELECT TO authenticated USING (true);

-- Indexes
CREATE INDEX idx_beat_rawbeat_id ON Librebeats.Beat(RawBeatId);
CREATE INDEX idx_beat_title ON Librebeats.Beat(Title);
CREATE INDEX idx_beat_artist ON Librebeats.Beat(Artist);
-- Full-text search on tags
CREATE INDEX idx_beat_tags_fts ON Librebeats.Beat USING GIN (to_tsvector('english', Tags));

-- 7. AudioOutputLog – service_role only (no authenticated access)
CREATE TABLE IF NOT EXISTS Librebeats.AudioOutputLog (
    Id INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    Title TEXT NOT NULL,
    ProgressState TEXT NOT NULL CHECK (ProgressState IN ('failed','created','donwloading','completed')),
    Output TEXT NULL,
    ErrorOutput TEXT,
    StartedAtUtc TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    FinishedAtUtc TIMESTAMP WITH TIME ZONE
);
ALTER TABLE Librebeats.AudioOutputLog ENABLE ROW LEVEL SECURITY;
-- only service_role

-- 8. BeatMix – authenticated can SELECT only
CREATE TABLE IF NOT EXISTS Librebeats.BeatMix (
    Id INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    Title TEXT NOT NULL,
    ThumbnailUrl TEXT NOT NULL,
    Beatable BOOLEAN NOT NULL DEFAULT TRUE,
    CreatedOn TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_beatmix_title UNIQUE (Title)
);
ALTER TABLE Librebeats.BeatMix ENABLE ROW LEVEL SECURITY;

CREATE POLICY "authenticated_select_beatmix" ON Librebeats.BeatMix
    FOR SELECT TO authenticated USING (true);

CREATE INDEX idx_beatmix_title ON Librebeats.BeatMix(Title);

-- 9. Junction table – authenticated can SELECT only
CREATE TABLE IF NOT EXISTS Librebeats.BeatMixBeat (
    BeatId INTEGER NOT NULL REFERENCES Librebeats.Beat(Id) ON DELETE CASCADE,
    BeatMixId INTEGER NOT NULL REFERENCES Librebeats.BeatMix(Id) ON DELETE CASCADE,
    PRIMARY KEY (BeatId, BeatMixId)
);
ALTER TABLE Librebeats.BeatMixBeat ENABLE ROW LEVEL SECURITY;

CREATE POLICY "authenticated_select_beatmixbeat" ON Librebeats.BeatMixBeat
    FOR SELECT TO authenticated USING (true);

CREATE INDEX idx_beatmixbeat_beatmixid ON Librebeats.BeatMixBeat (BeatMixId);
CREATE INDEX idx_beatmixbeat_beatid ON Librebeats.BeatMixBeat (BeatId);

-- 10. Remove all default privileges that would grant INSERT/UPDATE/DELETE to authenticated
-- First, reset defaults for the schema
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA Librebeats REVOKE ALL ON TABLES FROM authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA Librebeats REVOKE ALL ON SEQUENCES FROM authenticated;

-- Then explicitly grant only SELECT on future tables (if any) to authenticated
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA Librebeats GRANT SELECT ON TABLES TO authenticated;
-- No sequence grants needed for SELECT only

-- Ensure service_role retains full control (bypasses RLS anyway, but keep grants for clarity)
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA Librebeats GRANT ALL ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA Librebeats GRANT ALL ON SEQUENCES TO service_role;
