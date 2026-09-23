-- Dead-letter queue for failed audiopipe ingest jobs
SELECT pgmq.create('audiopipe-dlq');
