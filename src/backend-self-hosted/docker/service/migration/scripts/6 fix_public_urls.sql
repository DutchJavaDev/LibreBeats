-- Upload keys come back as "<bucket>/<file>", and the public URL builder added
-- the bucket name again, so rows were written with .../public/audio-files/audio-files/...
-- (and the same for image-files). Rewrite those rows to a single bucket segment.
-- Only rows that still have the doubled segment match, so re-running is a no-op.

UPDATE Librebeats.Beat
SET StreamingUrl = REPLACE(StreamingUrl, '/object/public/audio-files/audio-files/', '/object/public/audio-files/'),
    ThumbnailUrl = REPLACE(ThumbnailUrl, '/object/public/image-files/image-files/', '/object/public/image-files/')
WHERE StreamingUrl LIKE '%/object/public/audio-files/audio-files/%'
   OR ThumbnailUrl LIKE '%/object/public/image-files/image-files/%';

UPDATE Librebeats.BeatMix
SET ThumbnailUrl = REPLACE(ThumbnailUrl, '/object/public/image-files/image-files/', '/object/public/image-files/')
WHERE ThumbnailUrl LIKE '%/object/public/image-files/image-files/%';
