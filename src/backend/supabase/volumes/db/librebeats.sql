-- Source https://github.com/orgs/supabase/discussions/41729#discussion-9312472

-- Create pgmq_public schema early so PostgREST can validate it exists
-- The wrapper functions will be created later in the migration
CREATE SCHEMA IF NOT EXISTS pgmq_public;

-- NOTE: pgmq, pg_cron, and pg_net extensions are enabled in roles.sql
-- All three require superuser privileges for installation
-- The pgmq_public schema is also created in roles.sql so PostgREST can validate it exists
-- This is based on guidance from: https://github.com/orgs/supabase/discussions/32969#discussioncomment-13512379

-- Grant usage on schemas to service_role
GRANT USAGE ON SCHEMA pgmq_public TO service_role;
GRANT USAGE ON SCHEMA pgmq TO service_role;

-- Wrapper functions in pgmq_public schema (following Supabase recommended pattern)

CREATE OR REPLACE FUNCTION pgmq_public.pop(queue_name text)
RETURNS SETOF pgmq.message_record
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM pgmq.pop(queue_name := queue_name);
END;
$$;

COMMENT ON FUNCTION pgmq_public.pop(queue_name text) IS
'Retrieves and locks the next message from the specified queue.';

CREATE OR REPLACE FUNCTION pgmq_public.send(queue_name text, message jsonb, sleep_seconds integer DEFAULT 0)
RETURNS SETOF bigint
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM pgmq.send(queue_name := queue_name, msg := message, delay := sleep_seconds);
END;
$$;

COMMENT ON FUNCTION pgmq_public.send(queue_name text, message jsonb, sleep_seconds integer) IS
'Sends a message to the specified queue, optionally delaying its availability by a number of seconds.';

CREATE OR REPLACE FUNCTION pgmq_public.read(queue_name text, sleep_seconds integer, n integer)
RETURNS SETOF pgmq.message_record
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM pgmq.read(queue_name := queue_name, vt := sleep_seconds, qty := n);
END;
$$;

COMMENT ON FUNCTION pgmq_public.read(queue_name text, sleep_seconds integer, n integer) IS
'Reads up to "n" messages from the specified queue with an optional "sleep_seconds" (visibility timeout).';

CREATE OR REPLACE FUNCTION pgmq_public.archive(queue_name text, message_id bigint)
RETURNS boolean
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    RETURN pgmq.archive(queue_name := queue_name, msg_id := message_id);
END;
$$;

COMMENT ON FUNCTION pgmq_public.archive(queue_name text, message_id bigint) IS
'Archives a message by moving it from the queue to a permanent archive.';

CREATE OR REPLACE FUNCTION pgmq_public.delete(queue_name text, message_id bigint)
RETURNS boolean
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    RETURN pgmq.delete(queue_name := queue_name, msg_id := message_id);
END;
$$;

COMMENT ON FUNCTION pgmq_public.delete(queue_name text, message_id bigint) IS
'Permanently deletes a message from the specified queue.';

-- Grant EXECUTE on wrapper functions to service_role
GRANT EXECUTE ON FUNCTION
    pgmq_public.pop(text),
    pgmq_public.send(text, jsonb, integer),
    pgmq_public.archive(text, bigint),
    pgmq_public.delete(text, bigint),
    pgmq_public.read(text, integer, integer)
TO service_role;

-- Grant table privileges for service_role on pgmq schema
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA pgmq TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA pgmq GRANT ALL PRIVILEGES ON TABLES TO service_role;

-- Grant usage and access to sequences
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA pgmq TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA pgmq GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO service_role;

GRANT USAGE ON SCHEMA pgmq_public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA pgmq_public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA pgmq_public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA pgmq_public TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA pgmq_public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA pgmq_public GRANT ALL ON ROUTINES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA pgmq_public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
