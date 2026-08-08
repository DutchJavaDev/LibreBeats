-- Tears down everything the migrations created. Destructive.
-- Migration history rows are deleted by the revert scripts, not here.

-- pgmq extension takes the queues and their tables with it
drop extension if exists pgmq cascade;

drop schema if exists librebeats cascade;

-- listener user, identities go via fk cascade
delete from auth.users where email = 'listner@librebeats.com';

-- objects first, buckets reference them. newer storage versions block direct deletes
-- behind this setting, older ones just ignore it
set storage.allow_delete_query = 'true';
delete from storage.objects where bucket_id in ('audio-files', 'image-files');
delete from storage.buckets where id in ('audio-files', 'image-files');
reset storage.allow_delete_query;
