# LibreBeats: Supabase CLI project

The Supabase CLI counterpart to [`../backend-self-hosted`](../backend-self-hosted). It holds the same `librebeats` schema and the `menu` edge function, managed by the CLI so it can be deployed to any Supabase project, hosted or self-hosted.

The Go services don't run here. There is no ingest, and nothing in this folder assumes a running audio worker. A worker can run elsewhere and connect to this project's database and storage. Its requirements are in [Audio worker](#audio-worker).

```
deploy.sh / deploy.ps1           deploy to the linked project (needs supabase login)
deploy-no-login.sh / .ps1        deploy from environment variables
revert.sh / revert.ps1           tear the deployment down (needs supabase login)
revert-no-login.sh / .ps1        tear down from environment variables
revert.sql                       teardown SQL run by the revert scripts
supabase/
├── config.toml                  local stack, and the settings config push sends
├── migrations/                  five migrations, see below
└── functions/menu/              the catalog API the app calls
```

The self-hosted stack's `docker/volumes/functions/` holds `main` and `hello`, not `menu`. There is no `main` router in this project. The self-hosted router has one global JWT switch (`FUNCTIONS_VERIFY_JWT`), while here `verify_jwt` is set per function in `config.toml`. `hello` was a sample and isn't carried over.

## Migrations

| File | Contents | Safe to run on a database the Go runner already migrated |
|---|---|---|
| `20260807000000_initial.sql` | pgmq, `librebeats` schema, tables, RLS, grants, default privileges | No. `CREATE POLICY` and `CREATE INDEX` are not guarded. |
| `20260807000001_audiopipe_dlq.sql` | creates the `audiopipe-dlq` queue | Not verified. `pgmq.create` is not guarded here. |
| `20260807000002_storage_buckets.sql` | `audio-files` and `image-files` buckets | Yes. `ON CONFLICT DO NOTHING`. |
| `20260807000003_seed_libre_user.sql` | seeds the listener user | Yes. Returns early if the email exists. See the warning below. |
| `20260807000004_librebeats_worker.sql` | `librebeats_worker` role, its grants and RLS policies | No. The role is created only if missing, but `CREATE POLICY` is not guarded. |

Each file has a numbered counterpart with the same name in `../backend-self-hosted/docker/service/migration/scripts/` (`0 initial.sql` to `4 librebeats_worker.sql`). See [Adding a migration](#adding-a-migration).

### Seeded listener user

`20260807000003_seed_libre_user.sql` creates the `listner@librebeats.com` auth user with a password written in plain text in the file. That password is public. Anyone who can reach the project's Auth endpoint can sign in as this user on any project where the migration has run. On a real project, change the password or disable the user through Auth. Don't edit the migration after it has been applied.

## Local development

Needs Docker. From this folder:

```bash
supabase start            # local stack, applies all migrations
supabase db reset         # wipes and re-applies everything, see the known issue below
supabase functions serve menu
supabase stop             # keeps data; --no-backup deletes it
```

Enabled in `config.toml`: the API, Postgres, Auth, Storage (with the S3 protocol and vector storage), the edge runtime and Studio. Disabled: Realtime, the local mail catcher, analytics, the connection pooler and storage analytics buckets.

**Known issue:** `[db.seed]` has `sql_paths = ["./seed.sql"]`, but there is no `supabase/seed.sql`. `supabase db reset` is expected to fail on the missing file until the entry is removed or the file is added.

### Environment references

These `env(...)` references in `config.toml` are not commented out. Set them before use. Whether the CLI fails on an unset one is not checked here.

- `OPENAI_API_KEY` (`[studio]`)
- `S3_HOST`, `S3_REGION`, `S3_ACCESS_KEY`, `S3_SECRET_KEY` (`[experimental]`)
- `SUPABASE_AUTH_SMS_TWILIO_AUTH_TOKEN` (`[auth.sms.twilio]`, provider disabled)
- `SUPABASE_AUTH_EXTERNAL_APPLE_SECRET` (`[auth.external.apple]`, provider disabled)

## Audio worker

The worker is the Go audio service in `../backend-self-hosted/docker/service/audio`. It reads these variables at startup:

| Variable | Required | Notes |
|---|---|---|
| `POSTGRES_BACKEND_URL` | yes | Postgres connection string for the worker's role |
| `STORAGE_URL` | yes | Storage API URL |
| `STORAGE_KEY` | yes | Storage API key |
| `AUDIO_BUCKET_ID` | yes | `audio-files` in the self-hosted compose file |
| `IMAGE_BUCKET_ID` | yes | `image-files` in the self-hosted compose file |
| `QUEUE_NAME` | yes | letters, digits, `_` and `-` only |
| `QUEUE_DLQ_NAME` | no | default `audiopipe-dlq` |
| `QUEUE_VISIBILITY_TIMEOUT_SEC` | no | default `600` |
| `QUEUE_MAX_READ_COUNT` | no | default `5` |

The migration creates `librebeats_worker` as `NOLOGIN` and sets no password. The self-hosted init script (`../backend-self-hosted/docker/volumes/db/librebeats-worker.sql`) gives it `LOGIN` and a password. If the worker connects to this project, you have to give the role `LOGIN` and a password yourself, and keep that password out of the repository.

## Deploying

A deployment runs three pushes in order: `db push` (migrations, buckets, listener user), `config push` (exposed API schemas and auth settings), and `functions deploy menu`. Each script stops at the first failure.

Re-running is safe for the schema. `db push` skips migrations already recorded in `supabase_migrations.schema_migrations`. `config push` and `functions deploy` run every time and overwrite the remote settings and function.

With a logged-in CLI:

```bash
supabase login
supabase link --project-ref <ref>
./deploy.sh
```

On Windows, `.\deploy.ps1`. To skip the link, pass the ref: `./deploy.sh <ref>` or `.\deploy.ps1 -ProjectRef <ref>`.

Without login (CI, or a machine that never ran `supabase login`):

```bash
SUPABASE_DB_URL='postgresql://...' \
SUPABASE_ACCESS_TOKEN='sbp_...' \
SUPABASE_PROJECT_REF='<ref>' \
./deploy-no-login.sh
```

```powershell
$env:SUPABASE_DB_URL = 'postgresql://...'
$env:SUPABASE_ACCESS_TOKEN = 'sbp_...'
$env:SUPABASE_PROJECT_REF = '<ref>'
.\deploy-no-login.ps1
```

- `SUPABASE_DB_URL` is required. URL-encode the password in it.
- `SUPABASE_ACCESS_TOKEN` and `SUPABASE_PROJECT_REF` must both be set for the config push and function deploy. Without them, the script only applies migrations.
- `SUPABASE_DB_PUSH_BIN` is read by `deploy.sh` and `deploy.ps1` only. It sets the binary used for `db push`. Every other step, including the `-no-login` scripts, runs `supabase` from `PATH`.

Gotchas:

- The auth settings in `config.toml` are pushed as they are. They allow sign-up without email confirmation: `[auth] enable_signup = true`, `[auth.email] enable_signup = true` and `[auth.email] enable_confirmations = false`. The app has no registration flow, and the root `AGENTS.md` says Auth is for existing accounts only. Set both `enable_signup` values to `false` before deploying to a real project.
- The repository doesn't pin a CLI version. If `supabase link` or `db push` misbehaves with your CLI version, point `SUPABASE_DB_PUSH_BIN` at a binary that works. This only applies to `deploy.sh` and `deploy.ps1`.

### Data API access

After a deploy, signed-in users can read `beat`, `beatmix`, `beatmixbeat` and `rawbeat`, and nothing else. The grants and RLS policies in the initial migration set this. `audiooutputlog` and `migrations` have no grants for `authenticated`, and `anon` gets no grants on the schema.

`config.toml` exposes the `librebeats` schema through `api.schemas`. Clients have to name it: `.schema('librebeats')` in supabase-js, or an `Accept-Profile: librebeats` header on raw REST.

## Menu function

`supabase/functions/menu/index.ts`, with `[functions.menu] verify_jwt = true` in `config.toml`. It is the catalog API the app calls.

- **Caller:** the request needs a signed-in user's JWT. The handler is wrapped with `withSupabase({ auth: "user" })`, so the queries run as that user and RLS applies. The `authenticated` SELECT policies use `USING (true)`, so the function sees every row of the four tables.
- **Query:** all `beatmix` rows, each with its `beat`s through `beatmixbeat`, and each beat's `rawbeat.duration`. It does not filter on `Beat.Published` or `BeatMix.Beatable`. Unpublished beats and non-beatable mixes are returned.
- **Success (HTTP 200):** `{"data": [{"id", "title", "thumbnailurl", "beats": [{"id", "title", "artist", "thumbnailurl", "streamingurl", "duration"}], "count"}]}`. `duration` is `null` when the beat has no `rawbeat` row. `count` is the number of junction rows.
- **Errors:** any thrown error returns HTTP 500 with `{"error": "<message>"}`, and the message is passed to the caller. The handler does not check the HTTP method and does not handle a JWT rejected by the platform.
- **Runtime:** `config.toml` sets `[edge_runtime] deno_version = 2`. The function imports from `jsr:@supabase/functions-js` and `jsr:@supabase/server@^1`, so it needs network access to JSR when it is served or deployed. The scripts don't run Deno directly.

## Reverting

Removes the `librebeats` schema, the pgmq extension and its queues, both buckets with their files, the listener user, the migration history rows and, when a ref is given, the `menu` function. Destructive, with no undo.

```bash
SUPABASE_DB_URL='postgresql://...' ./revert.sh           # logged in, linked project
SUPABASE_DB_URL='postgresql://...' ./revert-no-login.sh  # also needs SUPABASE_ACCESS_TOKEN and SUPABASE_PROJECT_REF
```

On Windows: `.\revert.ps1 [-ProjectRef <ref>]` and `.\revert-no-login.ps1`.

- `SUPABASE_DB_URL` is always required. The teardown runs as SQL, and the CLI can't run SQL over a login session. The scripts use `psql`, or the `postgres:17-alpine` container if `psql` isn't installed.
- `revert.sh` and `revert.ps1` take the ref from the argument, or from `supabase/.temp/project-ref`. Deleting the function and resetting the exposed API schemas need `SUPABASE_ACCESS_TOKEN` and a ref. `revert-no-login.*` need both `SUPABASE_ACCESS_TOKEN` and `SUPABASE_PROJECT_REF`.
- **Known gap:** `revert.sql` does not drop the `librebeats_worker` role, which migration 000004 creates. It is a cluster-level role, so it remains after teardown. Remove it by hand if you need it gone.

On the local stack, `supabase db reset` does the same job.

## Baselining

The CLI records applied migrations in `supabase_migrations.schema_migrations`. It does not know about `librebeats.migrations`, which the Go runner uses.

On an instance the Go runner has already migrated, `db push` fails at 000000 (the unguarded policies and indexes already exist) and at 000004 (the policies already exist). Mark the migrations as applied first:

```bash
supabase migration repair --status applied 20260807000000 --db-url "postgresql://..."
supabase migration repair --status applied 20260807000001 --db-url "postgresql://..."
supabase migration repair --status applied 20260807000002 --db-url "postgresql://..."
supabase migration repair --status applied 20260807000003 --db-url "postgresql://..."
supabase migration repair --status applied 20260807000004 --db-url "postgresql://..."
```

Mark all five when the Go runner applied all five scripts. 000002 and 000003 do nothing harmful if they are left unmarked. Fresh instances don't need this.

## Adding a migration

```bash
supabase migration new <description>
```

This creates a timestamped file in `supabase/migrations/`. Fill it in, then add a numbered copy in `../backend-self-hosted/docker/service/migration/scripts/`. The two schemas must stay in sync.

The Go runner only applies scripts whose numeric prefix is higher than the highest id in `Librebeats.Migrations` (currently 4). It ignores the CLI timestamp. Name the copy with the next number, for example `5 <name>.sql`.

Follow the initial migration for new tables: enable RLS, and add the grants and policies they need. Never edit a migration that has been applied.
