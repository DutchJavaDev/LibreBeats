# LibreBeats — Backend

Self hosted [Supabase](https://supabase.com/docs/guides/self-hosting/docker) with two Go services on top: **migration** sets up the `librebeats` schema, **audio** turns YouTube urls into streamable beats. The app talks to all of it through Kong: Auth, PostgREST, Storage and the `menu` edge function.

## Quick start

```bash
./setup.sh   # Bootstrap a self-hosted Supabase project on Linux (Debian/Ubuntu or RHEL/CentOS/Fedora).
./run.sh     # Manage the self-hosted Supabase docker compose stack.
./reset.sh   # Removes the selfhosted instance
./update.sh  # Update an existing self-hosted Supabase deployment in place.
```

Bash scripts, so Linux/macOS/WSL Studio ends up behind Kong at `http://localhost:8000`, dashboard login is in `.env`.

Before the first run:

- `setup.sh` is a fresh install.
- Then `run.sh start`
- the audio image needs a `cookies.txt` (yt-dlp cookies file, git-ignored). Export one from your browser to `service/audio/cookies.txt` before building, the image build fails without it. The image builds from the copy in the build dir, so if that already exists run `./copy.sh` after adding the file.

### How deployment works

Docker compose never runs from the repo. Use `setup.sh --project-dir` to specify the directory in which the selfhosted version will run and operate, make sure its empty and does not contain an `.env` file.

`.env` is seeded from [`.env.example`](.env.example). The placeholder keys in the template are not valid JWTs, the stack only works once `setup.hs` has minted real ones. The key script only updates `.env` when run in an actual terminal, piped runs print the keys and skip the file.

## What runs

Stock Supabase self host (Postgres, Kong, Auth, PostgREST, Realtime, Storage + imgproxy, Studio, edge runtime, logs) plus the two services in the same compose file:

| Service | Container | Runs |
|---|---|---|
| `migrations` | `supabase-migrations` | Once, after the db is healthy: applies SQL from `service/migration/scripts` |
| `audio` | `supabase-audio` | Forever (`restart: unless-stopped`), starts after migrations completed |

Host ports: Kong on `8000`/`8443` (the API the app talks to), Postgres via supavisor on `5432` (session) and `6543` (transaction pooling), analytics on `4000`.

## Migration service (`service/migration`)

One-shot Go binary. Connects with `POSTGRES_BACKEND_URL`, looks up the last applied migration in `librebeats.migrations` and applies every script in `scripts/` with a higher number, all in one transaction, so a broken script rolls back the whole batch. Applied files get recorded in the tracking table, full SQL text included.

Scripts are named `<number> <description>.sql`, the space after the number is how the id gets parsed:

```
scripts/
├── 0 initial.sql           # Pgmq + librebeats schema, all tables, RLS, the audiopipe-input queue
├── 1 audiopipe_dlq.sql     # The audiopipe-dlq dead letter queue for failed messages
├── 2 storage_buckets.sql   # Creates the public storage buckets for storing files
├── 3 seeb_libre_user.sql   # Create the default user for purely listining (limited rights)
├── 4 librebeats_worker.sql # Creates a service account for the audio service
```

Adding one: new `.sql` file in `scripts/`, numbered above the highest `id` in `librebeats.migrations` (that means `4` or higher right now, see [Known quirks](#known-quirks)), then rebuild the image (`docker compose build migrations` from the build dir), the scripts are baked in at build time. Two more rules: nothing but migrations may live in `scripts/` (a stray file aborts the run), and a migration that adds a table has to bring its own grants and policies, the default-privileges block in `0 initial.sql` targets the wrong role so new tables get nothing automatically.

## Audio service (`service/audio`)

An endless consume loop over the pgmq queue `audiopipe-input`. Message shape:

```json
{"url": "https://www.youtube.com/watch?v=..."}
```

Per message:

1. claim one message with `pgmq.read` and a visibility timeout (default 600s), empty queue means sleep 5s and poll again
2. single video or playlist (`playlist?` in the url)
3. yt-dlp into a per-run scratch dir, audio extracted to opus, thumbnail converted to jpg
4. upload to Storage with upsert: the opus to `audio-files`, the thumbnail to `image-files` (both buckets get created public on first start, mime restricted)
5. catalog rows: `rawbeat` then `beat`, playlists get-or-create a `beatmix` by title and link every track through `beatmixbeat`
6. success deletes the message, a failure leaves it for the visibility timeout to bring back. Poison messages (bad json, no url, empty playlist) and messages that failed `QUEUE_MAX_READ_COUNT` times go to `audiopipe-dlq`, wrapped with the original message, read count and error.

Failures land in `librebeats.audiooutputlog` with the yt-dlp output. Successful runs write nothing there, the `donwloading`/`completed` states exist but are never used.

Clients have no pgmq access, feed the queue from the Studio SQL editor:

```sql
select pgmq.send('audiopipe-input', '{"url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}'::jsonb);
```

Env vars, all set in the compose file. The worker panics at startup when a required one is missing:

| Variable | Default | Purpose |
|---|---|---|
| `POSTGRES_BACKEND_URL` | required | Postgres connection string (queue + catalog writes) |
| `QUEUE_NAME` | required, deployed as `audiopipe-input` | Input queue |
| `QUEUE_DLQ_NAME` | `audiopipe-dlq` | Dead letter queue |
| `QUEUE_VISIBILITY_TIMEOUT_SEC` | `600` | Claim duration, doubles as the retry delay |
| `QUEUE_MAX_READ_COUNT` | `5` | Attempts before a message is dead-lettered |
| `STORAGE_URL` | required, deployed as `http://kong:8000/storage/v1` | Storage API |
| `STORAGE_KEY` | required, deployed as the service role key | Storage auth |
| `AUDIO_BUCKET_ID` | required, deployed as `audio-files` | Bucket for opus files |
| `IMAGE_BUCKET_ID` | required, deployed as `image-files` | Bucket for thumbnails |

## Database schema (`librebeats`)

Created by `0 initial.sql`. The SQL spells the names CamelCase but nothing is quoted, so Postgres folds it all to lowercase, the names below are the real ones. Authenticated users can only ever SELECT, all writing happens through the Go services which connect straight to Postgres as `postgres`. `anon` gets nothing.

| Table | Purpose | Authenticated access |
|---|---|---|
| `rawbeat` | Staging: source url, storage locations, duration | SELECT (only exists so `menu` can join duration) |
| `beat` | Track metadata + streaming/thumbnail urls | SELECT |
| `beatmix` | Playlist/mix metadata | SELECT |
| `beatmixbeat` | Beat ↔ mix junction | SELECT |
| `audiooutputlog` | Ingest failure log | none (backend only) |
| `migrations` | Applied migration tracking | none (backend only) |

The pgmq queues `audiopipe-input` and `audiopipe-dlq` sit next to it, only reachable for the admin roles the backend and Studio use.

## Edge functions (`volumes/functions`)

Served by the edge runtime from the mounted `volumes/functions` folder (the copy in the build dir, see above).

- `main`: the router every request passes through. Only verifies JWTs when `FUNCTIONS_VERIFY_JWT=true` (default false, and it is global, there is no per-function setting)
- `menu`: the one the app calls. Needs a signed-in user, returns every beatmix with its beats embedded (id, title, artist, urls, duration) in one query. This is the whole catalog API of the app.
- `hello`: the stock sample function

## Testing

```bash
cd service/migration && go test ./...
cd service/audio && go test ./...
```

No Docker, Postgres or yt-dlp needed. Covered: migration filename parsing and the missing-table detection, queue config defaults and validation, DLQ payload wrapping, url parsing and playlist detection, file helpers, the required-env panics and the progress state strings. Integration tests against a live stack are not included yet.

## Known quirks / bugs I need to resolve

- the migration skip check compares file numbers against the tracking table's identity column, which starts at 1 while the files start at 0. A file numbered `2` may or may not run, `3` is the first number that is guaranteed to. Numbering above the count of applied rows keeps you safe.
- migration files are processed in lexical order, `10 x.sql` sorts before `2 y.sql`. Zero-pad when it gets that far.
- a failed migration run still exits 0, compose calls that "completed successfully" and starts the audio service anyway. Check the `supabase-migrations` logs after deploying a new script.
- re-enqueueing an already ingested url doesn't dedupe: the storage upserts absorb the files but the catalog insert hits the unique constraints, so the message fails every attempt (re-downloading each time) and ends in the DLQ. Same when a playlist dies halfway, the committed tracks block the retry and the beatmix stays partial.
- playlist detection is literally `playlist?` in the url. A `watch?v=…&list=…` link goes down the single-video path, but yt-dlp (no `--no-playlist` flag) still downloads the whole playlist and the single-track code chokes on the result.
- a yt-dlp download archive file is created at startup while the `--download-archive` flag is commented out, so it is never written.
- `beat` rows get the video title as both title and artist. A beatmix whose thumbnail upload fails gets the literal string `404` as thumbnail url.
- the `audiooutputlog` progress states include the typo `donwloading`, enforced by a CHECK constraint, so it has to stay misspelled.
- `menu` doesn't filter on `beat.published` or `beatmix.beatable`, those flags are decoration for now.

## Production

The Supabase defaults are not production safe. Rotate every secret in `.env`, review CORS and put a proxy in front.