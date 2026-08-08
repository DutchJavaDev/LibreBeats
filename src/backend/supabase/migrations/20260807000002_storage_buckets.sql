-- Buckets for the audio pipeline, same settings the audio service creates at runtime.
-- Safe to rerun and to run where the service already made them.
INSERT INTO storage.buckets (id, name, public, allowed_mime_types)
VALUES
  ('audio-files', 'audio-files', true, ARRAY['audio/ogg']),
  ('image-files', 'image-files', true, ARRAY['image/jpeg'])
ON CONFLICT (id) DO NOTHING;
