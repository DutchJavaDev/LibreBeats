-- 1. Schema Setup
CREATE SCHEMA IF NOT EXISTS pgmq_public;
CREATE SCHEMA IF NOT EXISTS librebeats;


-- -- Source https://github.com/orgs/supabase/discussions/41729#discussion-9312472
-- 2. WRAPPER FUNCTIONS
-- Note the addition of SECURITY DEFINER and explicit search_path
CREATE OR REPLACE FUNCTION pgmq_public.pop(queue_name text)
RETURNS SETOF pgmq.message_record LANGUAGE plpgsql
SECURITY DEFINER SET search_path = pgmq, pgmq_public AS $$
BEGIN
    RETURN QUERY SELECT * FROM pgmq.pop(queue_name := queue_name);
END; $$;
COMMENT ON FUNCTION pgmq_public.pop(queue_name text) IS
'Retrieves and locks the next message from the specified queue.';


CREATE OR REPLACE FUNCTION pgmq_public.send(queue_name text, message jsonb, sleep_seconds integer DEFAULT 0)
RETURNS SETOF bigint LANGUAGE plpgsql
SECURITY DEFINER SET search_path = pgmq, pgmq_public AS $$
BEGIN
    RETURN QUERY SELECT * FROM pgmq.send(queue_name := queue_name, msg := message, delay := sleep_seconds);
END; $$;
COMMENT ON FUNCTION pgmq_public.send(queue_name text, message jsonb, sleep_seconds integer) IS
'Sends a message to the specified queue, optionally delaying its availability by a number of seconds.';

CREATE OR REPLACE FUNCTION pgmq_public.read(queue_name text, sleep_seconds integer, n integer)
RETURNS SETOF pgmq.message_record LANGUAGE plpgsql
SECURITY DEFINER SET search_path = pgmq, pgmq_public AS $$
BEGIN
    RETURN QUERY SELECT * FROM pgmq.read(queue_name := queue_name, vt := sleep_seconds, qty := n);
END; $$;
COMMENT ON FUNCTION pgmq_public.read(queue_name text, sleep_seconds integer, n integer) IS
'Reads up to "n" messages from the specified queue with an optional "sleep_seconds" (visibility timeout).';

CREATE OR REPLACE FUNCTION pgmq_public.archive(queue_name text, message_id bigint)
RETURNS boolean LANGUAGE plpgsql
SECURITY DEFINER SET search_path = pgmq, pgmq_public AS $$
BEGIN
    RETURN pgmq.archive(queue_name := queue_name, msg_id := message_id);
END; $$;
COMMENT ON FUNCTION pgmq_public.archive(queue_name text, message_id bigint) IS
'Archives a message by moving it from the queue to a permanent archive.';

CREATE OR REPLACE FUNCTION pgmq_public.delete(queue_name text, message_id bigint)
RETURNS boolean LANGUAGE plpgsql
SECURITY DEFINER SET search_path = pgmq, pgmq_public AS $$
BEGIN
    RETURN pgmq.delete(queue_name := queue_name, msg_id := message_id);
END; $$;
COMMENT ON FUNCTION pgmq_public.delete(queue_name text, message_id bigint) IS
'Deletes a message from the specified queue.';

CREATE OR REPLACE FUNCTION pgmq_public.create_queue(queue_name text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pgmq, pgmq_public
AS $$
BEGIN
    -- This calls the extension's internal create function
    PERFORM pgmq.create(queue_name := queue_name);
END;
$$;
COMMENT ON FUNCTION pgmq_public.create_queue(queue_name text) IS
'Creates a new message queue with the specified name.';

-- Grant access to the service role
GRANT EXECUTE ON FUNCTION pgmq_public.create_queue(text) TO service_role;

-- 3. Permission Cleanup
-- Grant EXECUTE to service_role only
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pgmq_public TO service_role;

-- 4. Internal Table
CREATE TABLE IF NOT EXISTS librebeats.migrations (
    id serial PRIMARY KEY,
    file_name text NOT NULL,
    content text NOT NULL,
    run_on timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS: With no policies, it is accessible ONLY by service_role
ALTER TABLE librebeats.migrations ENABLE ROW LEVEL SECURITY;

-- 5. Final Grants
GRANT USAGE ON SCHEMA librebeats, pgmq_public, pgmq TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA librebeats TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA librebeats TO service_role;
