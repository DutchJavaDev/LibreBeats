-- Least-privilege role for the audio worker. Created NOLOGIN here so the same
-- script is safe everywhere, the self-hosted db init script gives it LOGIN and
-- a password, on hosted supabase.com the role just sits there inert.
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'librebeats_worker') THEN
        CREATE ROLE librebeats_worker NOLOGIN;
    END IF;
END
$$;

GRANT USAGE ON SCHEMA Librebeats TO librebeats_worker;
-- the worker inserts, upserts (DO UPDATE needs UPDATE) and reads, never deletes
GRANT SELECT, INSERT, UPDATE ON Librebeats.RawBeat, Librebeats.Beat, Librebeats.BeatMix, Librebeats.BeatMixBeat, Librebeats.AudioOutputLog TO librebeats_worker;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA Librebeats TO librebeats_worker;

-- pgmq's functions are SECURITY INVOKER, so besides EXECUTE the worker needs
-- the queue tables themselves (read locks + updates, delete, send inserts)
GRANT USAGE ON SCHEMA pgmq TO librebeats_worker;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pgmq TO librebeats_worker;
GRANT SELECT ON pgmq.meta TO librebeats_worker;
GRANT SELECT, INSERT, UPDATE, DELETE ON pgmq."q_audiopipe-input", pgmq."a_audiopipe-input", pgmq."q_audiopipe-dlq", pgmq."a_audiopipe-dlq" TO librebeats_worker;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA pgmq TO librebeats_worker;

-- RLS is enabled on every librebeats table (0 initial.sql), explicit policies
-- instead of BYPASSRLS so the role's reach stays visible in one place
CREATE POLICY "worker_all_rawbeat" ON Librebeats.RawBeat FOR ALL TO librebeats_worker USING (true) WITH CHECK (true);
CREATE POLICY "worker_all_beat" ON Librebeats.Beat FOR ALL TO librebeats_worker USING (true) WITH CHECK (true);
CREATE POLICY "worker_all_beatmix" ON Librebeats.BeatMix FOR ALL TO librebeats_worker USING (true) WITH CHECK (true);
CREATE POLICY "worker_all_beatmixbeat" ON Librebeats.BeatMixBeat FOR ALL TO librebeats_worker USING (true) WITH CHECK (true);
CREATE POLICY "worker_all_audiooutputlog" ON Librebeats.AudioOutputLog FOR ALL TO librebeats_worker USING (true) WITH CHECK (true);
