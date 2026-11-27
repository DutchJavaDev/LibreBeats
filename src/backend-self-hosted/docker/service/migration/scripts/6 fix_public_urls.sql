-- Upload keys come back as "<bucket>/<file>", and the public URL builder added
-- the bucket name again, so rows were written with .../public/audio-files/audio-files/...
-- (and the same for image-files). Rewrite those rows to a single bucket segment.
--
-- Some doubled rows already have a correct twin (the same track ingested again
-- after the fix). Rewriting those would violate the unique URL constraints, so
-- their playlist links move to the twin and the doubled row is deleted first.
-- One statement, so it is atomic. Re-running it is a no-op.

with dup as (
  select d.id as old_id, c.id as new_id
  from librebeats.beat d
  join librebeats.beat c
    on c.id <> d.id
   and (c.streamingurl = replace(d.streamingurl, '/object/public/audio-files/audio-files/', '/object/public/audio-files/')
     or c.thumbnailurl = replace(d.thumbnailurl, '/object/public/image-files/image-files/', '/object/public/image-files/'))
  where d.streamingurl like '%/object/public/audio-files/audio-files/%'
     or d.thumbnailurl like '%/object/public/image-files/image-files/%'
),
moved as (
  insert into librebeats.beatmixbeat (beatid, beatmixid)
  select distinct dup.new_id, bmb.beatmixid
  from dup
  join librebeats.beatmixbeat bmb on bmb.beatid = dup.old_id
  on conflict do nothing
  returning 1
),
unlinked as (
  delete from librebeats.beatmixbeat where beatid in (select old_id from dup) returning 1
),
removed as (
  delete from librebeats.beat where id in (select old_id from dup) returning 1
),
fixed_beats as (
  update librebeats.beat
  set streamingurl = replace(streamingurl, '/object/public/audio-files/audio-files/', '/object/public/audio-files/'),
      thumbnailurl = replace(thumbnailurl, '/object/public/image-files/image-files/', '/object/public/image-files/')
  where (streamingurl like '%/object/public/audio-files/audio-files/%'
      or thumbnailurl like '%/object/public/image-files/image-files/%')
    and id not in (select old_id from dup)
  returning 1
),
fixed_mixes as (
  update librebeats.beatmix
  set thumbnailurl = replace(thumbnailurl, '/object/public/image-files/image-files/', '/object/public/image-files/')
  where thumbnailurl like '%/object/public/image-files/image-files/%'
  returning 1
)
select (select count(*) from moved) as links_moved,
       (select count(*) from removed) as duplicates_removed,
       (select count(*) from fixed_beats) as beats_fixed,
       (select count(*) from fixed_mixes) as mixes_fixed;
