# LibreBeats backend

Self hosted [Supabase](https://supabase.com/docs/guides/self-hosting/docker) with two Go services on top. **migration** sets up the `librebeats` schema and **audio** turns YouTube urls into streamable beats. The app talks to the stack through the API gateway (Envoy by default, Kong if you switch): Auth, PostgREST, Storage and the `menu` edge function.

## Quick start

Run the installer from this checkout (`src/backend-self-hosted/docker`) on the `librebeats` branch. It builds a separate deployment directory:

```bash
cd src/backend-self-hosted/docker
sh setup.sh --public-url https://beats.example.com --proxy host --cookies ~/yt-dlp-cookies.txt
#   --proxy host    nginx already runs on this server (hosting-with-existing-nginx.md)
#   --proxy docker  the bundled nginx-certbot container (hosting-with-docker-nginx.md)

cd supabase-project
sh update.sh --check   # preflight: must pass before the first start
sh run.sh start        # the upstream Supabase stack
```

Bash scripts, for Linux, macOS or WSL. The gateway listens on `127.0.0.1:8000` in host mode, so nothing is exposed until your proxy forwards to it.

The audio image needs `service/audio/cookies.txt`, a yt-dlp cookies file in Netscape format that is git-ignored. Setup checks the file and copies it from `--cookies`; it aborts if the file is not Netscape format (JSON and CSV exports are rejected). The preflight checks the file the same way.

Export it from a browser with a "cookies.txt" extension, such as "Get cookies.txt LOCALLY". The first line must be `# Netscape HTTP Cookie File`, and each cookie is one line of seven tab-separated fields.

### How the deployment is built

`setup.sh` takes the Supabase release recorded in `.supabase-version` (latest `self-hosted/v*` tag unless `--ref` is given), then adds the LibreBeats layer:

- `docker-compose.yml`, `volumes/db/jwt.sql`, the Caddy and nginx templates and `CONFIG.md` are LibreBeats versions of Supabase files.
- `service/`, `volumes/functions/menu/`, `volumes/db/librebeats-worker.sql`, the tooling (`update.sh`, `reset.sh`, `librebeats-lib.sh`) and `librebeats/` are LibreBeats-owned.

The file list lives in `librebeats-lib.sh` (`LB_PATHS`). `.librebeats-version` records the LibreBeats commit that was installed, and `.librebeats/` keeps the installed copies that the next update merges against.

`.env` is seeded from the upstream `.env.example`. The key scripts replace the placeholder secrets. They only update `.env` when run in a terminal, so setup and reset run them with the output discarded.

### Updating, resetting, adopting

| Command | What it does |
|---|---|
| `sh update.sh --check` | Preflight only. Changes nothing. |
| `sh update.sh --dry-run` | Shows what an update would change. |
| `sh update.sh` | Merges the new Supabase release and syncs the LibreBeats layer from the `librebeats` branch. Your `.env`, `docker-compose.override.yml`, cookies and data are never written. Conflicts exit with 2. |
| `sh update.sh --rebuild` | As above, and rebuilds and recreates the `audio` and `migrations` images when their source files changed. |
| `sh update.sh --nginx-snippet` | Prints the host nginx server block for the current domain. |
| `sh update.sh --adopt` | Converts a deployment made by an earlier `setup.sh` into a managed one. |
| `sh reset.sh` | Archives the deployment, deletes the database, storage, snippets and secrets, and rebuilds it from the recorded versions. The Let's Encrypt volume is kept unless `--purge-certs`. |

The update reads the `librebeats` branch on the repository, so commit and push LibreBeats changes before updating. Override with `--librebeats-url` or `--librebeats-ref`.

Put your own compose changes in `docker-compose.override.yml`, not in `docker-compose.yml`. The LibreBeats copy of that file is replaced when the layer changes.

## Examples

Every command runs from the directory shown. Use `sh setup.sh --help` and `sh update.sh --help` for the full option lists.

### Export the cookies file

The audio worker needs a Netscape-format cookies file. In a browser, use an
extension such as "Get cookies.txt LOCALLY" while logged in to YouTube and
export the cookies for `youtube.com`. Check the first line before you use it:

```bash
head -n1 cookies.txt
# expected: # Netscape HTTP Cookie File
```

Setup refuses JSON, CSV and any other format.

### Install with the host nginx (scenario A)

```bash
cd LibreBeats/src/backend-self-hosted/docker
sh setup.sh -p ~/librebeats-prod \
    --public-url https://beats.example.com \
    --proxy host \
    --proxy-domain beats.example.com \
    --cookies ./cookies.txt
```

The gateway binds to `127.0.0.1:8000`. Add the server block from
`sh update.sh --nginx-snippet` to your nginx (see
[hosting-with-existing-nginx.md](hosting-with-existing-nginx.md)).

### Install with the bundled nginx (scenario B)

```bash
cd LibreBeats/src/backend-self-hosted/docker
sh setup.sh -p ~/librebeats-prod \
    --public-url https://beats.example.com \
    --proxy docker \
    --proxy-domain beats.example.com \
    --certbot-email you@example.org \
    --cookies ./cookies.txt
```

Ports 80 and 443 must be free. Use a real mailbox for `--certbot-email`;
`@example.com` is rejected.

### Pin a release or use the default branch

```bash
sh setup.sh ... --ref self-hosted/v0.8.1   # a specific Supabase release
sh setup.sh ... --head                     # Supabase's default branch
```

Without either flag, setup uses the newest `self-hosted/v*` tag.

### Preflight and start

```bash
cd ~/librebeats-prod
sh update.sh --check
```

Passing output ends with `preflight: ok (host proxy)`. A failing check lists
each problem and exits non-zero, for example:

```
FAIL: service/audio/cookies.txt is missing. Copy your yt-dlp cookies file there (it is git-ignored).
FAIL: PGRST_DB_SCHEMAS must include librebeats, or the app's catalog queries fail
preflight: 2 problem(s) found
```

Once it passes, start the stack:

```bash
sh run.sh start
sh run.sh status
```

### Check the public endpoint

```bash
curl -fsS https://beats.example.com/auth/v1/health
```

### Print the host nginx server block

```bash
sh update.sh --nginx-snippet
```

It prints the block with `PROXY_DOMAIN` filled in. Merge it into your
configuration, then `sudo nginx -t && sudo systemctl reload nginx`.

### Update

```bash
sh update.sh --dry-run          # show what would change, write nothing
sh update.sh --rebuild          # apply it, rebuild the audio/migration images if their files changed
sh run.sh recreate              # only needed when compose or env settings changed
```

If the update changes a file under `service/audio` or `service/migration`, the
image needs a rebuild. Docker never rebuilds a local image on start or recreate.
Without `--rebuild`, the update prints the commands to run by hand. With it, the
update builds the affected images and restarts them.

Pin the release or the LibreBeats branch explicitly when needed. Pass them on
the command line; the update records them in `.librebeats-version` itself, so
do not edit that file by hand:

```bash
sh update.sh --to self-hosted/v0.8.2
sh update.sh --librebeats-ref feature/hybrid-nh          # a branch
sh update.sh --librebeats-ref 1125e8261a9186a39d9fbf7614a62660620a54c1   # or a commit
```

The update fails with `Could not fetch branch ...` when the name does not exist
on the remote. Check the names with `git ls-remote --heads <repo-url>`.

If the update exits with code 2, a file has conflict markers. Edit it, remove
the `<<<<<<<`, `=======` and `>>>>>>>` lines, then run `sh update.sh --check`.

### Convert a deployment from the earlier setup

```bash
sh update.sh --adopt --dry-run  # lists the files that would be replaced
sh update.sh --adopt
```

Adopt backs up the deployment first and rolls back if the compose structure would change.

### Reset

```bash
sh reset.sh                     # asks you to type "reset"
sh reset.sh --yes               # no prompt
sh reset.sh --yes --purge-certs # also delete the Let's Encrypt volumes (scenario B)
```

The archive goes to `backups/reset-<timestamp>.tgz`. Reset generates new
secrets and an empty database, and keeps the URLs, proxy mode and cookies file.

### Download a track on Windows, the same way the audio service does

`docker/tools/ytdlp-audio.ps1` runs yt-dlp with the audio service's options.
It needs yt-dlp, ffmpeg and deno on PATH and a Netscape-format cookies file:

```powershell
cd src\backend-self-hosted\docker\tools
.\ytdlp-audio.ps1 -Url "https://www.youtube.com/watch?v=dQw4w9WgXcQ" -Cookies "$HOME\cookies.txt"
.\ytdlp-audio.ps1 -Url "https://www.youtube.com/playlist?list=PLxxxx" -Cookies .\cookies.txt -OutDir D:\beats
```

Files land in a `run_<time>` folder under `-OutDir`, with the same `ids.txt`,
`names.txt`, `duration.txt` and `tags.txt` the service writes. A playlist is
downloaded one track at a time, each in its own numbered folder.

### Troubleshoot `HTTP Error 403: Forbidden` in the audio service

Run these from the deployment directory. They don't download anything.

```bash
# 1. Versions inside the image. The image currently ships yt-dlp 2026.10.26 and deno 2.7.4.
docker compose run --rm --no-deps --entrypoint sh audio -c 'yt-dlp --version; deno --version | head -n1'

# 2. Metadata only, with the same cookies the service uses.
docker compose run --rm --no-deps --entrypoint sh audio \
    -c 'yt-dlp --cookies /app/cookies.txt --simulate -F "https://www.youtube.com/watch?v=jNQXAC9IVRw"'
```

- If step 2 fails with 403 on the info request, YouTube is refusing the server's
  IP address. Updating yt-dlp won't change that. Options: download from a home
  connection and upload the files, route through a residential proxy, or try a
  different cookies file from a spare account.
- If step 2 lists formats but the download still fails with 403, yt-dlp is out of
  date. Set `YTDLP_VERSION` in `service/audio/Dockerfile` to the newest tag from
  `github.com/yt-dlp/yt-dlp/releases`, then rebuild: `docker compose build audio && sh run.sh recreate audio`.
- If deno is far behind, rebuild the audio image on a newer Alpine base.
- A server outside a home network has to use cookies. Without them YouTube answers
  "Sign in to confirm you're not a bot". Export a fresh cookies file when downloads
  start failing.
- The service and `tools/ytdlp-audio.ps1` only download the audio stream
  (`-f "ba/b"`). That skips the video streams entirely.
- With cookies, yt-dlp adds the `web_embedded` client to its defaults. For some
  tracks that client returns media that needs a GVS PO token; without one the
  download gets a 403. The service and the CLI script exclude it with
  `--extractor-args=youtube:player_js_variant=tv;player_client=default,-web_embedded`.
  The separator has to be a semicolon. With a comma, yt-dlp reads the exclusion as
  part of the previous value and ignores it. If `Downloading web embedded client
  config` shows up in the log, the exclusion isn't applied.

### Read the secrets and connect the app

```bash
sh run.sh secrets               # publishable key and passwords; do not paste the output anywhere
```

### Run the tests

```bash
cd src/backend-self-hosted/docker
sh tests/test-librebeats.sh
```

The tests need `git`, `jq`, `openssl`, `tar` and `node`. They stub Docker, so
no containers are started. The last line reports `passed: N  failed: 0`.

## Connecting the app

The Flutter app reaches this stack the same way it reaches a hosted Supabase
project: a base URL plus a publishable key. In `.env` those are
`SUPABASE_PUBLIC_URL` (your reverse-proxied domain) and
`SUPABASE_PUBLISHABLE_KEY` (minted by `setup.sh`; read it back with
`sh run.sh secrets`).

Copy `../frontend/env.json.example` to `../frontend/env.json` and fill in:

```json
{
  "LIBREBEATS_SEED_URLS": "https://beats.example.com",
  "LIBREBEATS_SEED_KEYS": "sb_publishable_yourkey",
  "LIBREBEATS_DEV_EMAIL": "you@example.com",
  "LIBREBEATS_DEV_PASSWORD": "yourpassword"
}
```

There is no registration flow, so the login must already exist. The migration
service seeds one listening account (`3 seed_libre_user.sql`); use its email
and password, or any other account you have created. See `../frontend/README.md`
for the full seed format and the Settings → Servers screen for adding more.

## What runs

Stock Supabase self host (Postgres, the API gateway, Auth, PostgREST, Realtime, Storage with imgproxy, Studio, the edge runtime, logs) plus the two services in the same compose file:

| Service | Container | Runs |
|---|---|---|
| `migrations` | `supabase-migrations` | Once, after the db is healthy: applies SQL from `service/migration/scripts` |
| `audio` | `supabase-audio` | Forever (`restart: unless-stopped`), starts after migrations completed |

Host ports: the gateway on `8000` (Envoy by default; with the Kong override Kong also listens on `8443`), Postgres via supavisor on `5432` (session) and `6543` (transaction pooling), analytics on `4000`. In host-proxy mode the installer binds the gateway to `127.0.0.1:8000`.

## Migration service (`service/migration`)

One-shot Go binary. Connects with `POSTGRES_BACKEND_URL`, looks up the last applied migration in `librebeats.migrations` and applies every script in `scripts/` with a higher number, all in one transaction, so a broken script rolls back the whole batch. Applied files get recorded in the tracking table, full SQL text included.

Scripts are named `<number> <description>.sql`, the space after the number is how the id gets parsed:

```
scripts/
├── 0 initial.sql           # pgmq + librebeats schema, all tables, RLS, the audiopipe-input queue
├── 1 audiopipe_dlq.sql     # the audiopipe-dlq dead letter queue
├── 2 storage_buckets.sql   # the public storage buckets
├── 3 seed_libre_user.sql   # the default listening account (limited rights)
├── 4 librebeats_worker.sql # the service account the audio worker connects as
├── 6 fix_public_urls.sql   # repairs stored urls that repeated the bucket name
```

Number `5` was never used. The next script has to be above the number of
scripts already applied (see `librebeats.migrations`), so use `7` or higher for
anything new.

To add one, put a `.sql` file in `scripts/` and rebuild the migrations image,
because the scripts are copied in at build time:

```sh
docker compose build migrations && sh run.sh recreate migrations
```

Nothing but migrations may live in `scripts/`; a stray file aborts the run. A
migration that adds a table has to bring its own grants and policies, because the
default-privileges block in `0 initial.sql` targets the wrong role.

Each script runs in one transaction with the others that are still pending. If
one fails, none of them are recorded, the container exits with status 1, and the
audio service does not start.

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
6. success deletes the message, a failure leaves it for the visibility timeout to bring back. Poison messages (bad json, no url, empty playlist) and messages that failed `QUEUE_MAX_READ_COUNT` times go to `audiopipe-dlq`, wrapped with the original message, read count and error. A single video that YouTube reports as private, removed, terminated or unavailable goes straight to the DLQ without retries. In a playlist that track is skipped and the rest of the playlist continues (the skip is logged, and it doesn't count as a failure).

The urls written to `beat` and `beatmix` have one form:
`STORAGE_PUBLIC_URL/storage/v1/object/public/<bucket>/<file>?download=true`.
Upload keys already include the bucket name, and the builder strips it first
(migration 6 repaired rows written before that).

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
| `STORAGE_URL` | required, deployed as `http://kong:8000/storage/v1` | Storage API. The `kong` name is an alias for whichever gateway is running. |
| `STORAGE_PUBLIC_URL` | required, deployed as `SUPABASE_PUBLIC_URL` | Public base URL used to build the streaming/thumbnail URLs persisted in the catalog |
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

Served by the edge runtime from the mounted `volumes/functions` folder of the deployment.

- `main`: the router every request passes through. Only verifies JWTs when `FUNCTIONS_VERIFY_JWT=true` (default false, and it is global, there is no per-function setting)
- `menu`: the one the app calls. Needs a signed-in user, returns every beatmix with its beats embedded (id, title, artist, urls, duration) in one query. This is the whole catalog API of the app.
- `hello`: the stock sample function

## Testing

```bash
cd service/migration && go test ./...
cd service/audio && go test ./...
cd docker && sh tests/test-librebeats.sh   # installer, preflight, update, adopt, reset (needs git, jq, openssl, node)
```

No Docker, Postgres or yt-dlp needed. The Go tests cover migration filename parsing and missing-table detection, queue config defaults and validation, DLQ payload wrapping, url parsing and playlist detection, the public storage url builder, the yt-dlp argument lists (including the format selector and the client exclusion), the unavailable-track messages, file helpers, the required-env panics and the progress state strings. Integration tests against a live stack are not included yet.

## Known quirks

- the migration skip check compares file numbers against the tracking table's identity column, which starts at 1 while the files start at 0. A file numbered `2` may or may not run, `3` is the first number that is guaranteed to. Numbering above the count of applied rows keeps you safe.
- migration files are processed in lexical order, `10 x.sql` sorts before `2 y.sql`. Zero-pad when it gets that far.
- re-enqueueing an already ingested url doesn't dedupe: the storage upserts absorb the files but the catalog insert hits the unique constraints, so the message fails every attempt (re-downloading each time) and ends in the DLQ. Same when a playlist dies halfway, the committed tracks block the retry and the beatmix stays partial.
- playlist detection is literally `playlist?` in the url. A `watch?v=…&list=…` link goes down the single-video path, but yt-dlp (no `--no-playlist` flag) still downloads the whole playlist and the single-track code chokes on the result.
- a yt-dlp download archive file is created at startup while the `--download-archive` flag is commented out, so it is never written.
- `beat` rows get the video title as both title and artist. A beatmix whose thumbnail upload fails gets the literal string `404` as thumbnail url.
- the `audiooutputlog` progress states include the typo `donwloading`, enforced by a CHECK constraint, so it has to stay misspelled.
- `menu` doesn't filter on `beat.published` or `beatmix.beatable`, those flags are decoration for now.

## Production

The Supabase defaults are not production safe. Rotate every secret in `.env`, review CORS and put a proxy in front.

If the host already runs nginx (or another reverse proxy) with SSL, don't use the Docker proxy overrides — see [hosting-with-existing-nginx.md](hosting-with-existing-nginx.md).