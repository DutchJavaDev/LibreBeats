# LibreBeats — Supabase CLI project

The [Supabase CLI](https://supabase.com/docs/guides/local-development) counterpart to [`../backend-self-hosted`](../backend-self-hosted): the same `librebeats` schema and the `menu` edge function, but managed by the CLI so the whole thing can be deployed to any Supabase instance, hosted or self hosted. The Go services (migration runner, audio worker) are not part of this, those only exist in `backend-self-hosted`.

```
deploy.sh / .ps1              # deploy to the linked project (needs supabase login)
deploy-no-login.sh / .ps1     # same, driven by env vars instead of a login
revert.sh / .ps1              # tear the deployment down again (needs supabase login)
revert-no-login.sh / .ps1     # same without login
revert.sql                    # the actual teardown sql the revert scripts run
supabase/
├── config.toml               # local stack + what config push sends to a project
├── migrations/
│   ├── 20260807000000_initial.sql        # = "0 initial.sql" in backend-self-hosted
│   ├── 20260807000001_audiopipe_dlq.sql  # = "1 audiopipe_dlq.sql"
│   ├── 20260807000002_storage_buckets.sql
│   └── 20260807000003_seed_libre_user.sql
└── functions/
    └── menu/                 # the catalog api the app calls
```

The `main` router from the self hosted setup isn't here on purpose, the CLI runtime routes by itself and the router's one job (the global `FUNCTIONS_VERIFY_JWT` flag) is handled per function in `config.toml` (`[functions.menu] verify_jwt = true`). `hello` was a sample, dropped.

## Local development

Needs Docker. From this folder:

```bash
supabase start            # local stack, applies all migrations
supabase db reset         # wipe + re-apply migrations from scratch
supabase functions serve menu
supabase stop             # data survives, --no-backup wipes it
```

Only the containers the app actually needs are enabled: Postgres, PostgREST, Auth, Storage, edge runtime, Studio. Realtime, the mail catcher and analytics are turned off in `config.toml`, flip the `enabled` back if you ever need one (analytics is the expensive one, start is a lot faster without it).

## Deploying

A deployment is three pushes: `db push` (migrations, including the buckets and the seeded listener user), `config push` (exposed api schemas, auth settings) and `functions deploy menu`. The scripts run all three and stop at the first failure. Everything is idempotent, running them against an up to date project does nothing.

With a logged in cli:

```bash
supabase login
supabase link --project-ref <ref>
./deploy.sh
```

`.\deploy.ps1` on Windows. Pass a ref to skip the link: `./deploy.sh <ref>` or `.\deploy.ps1 -ProjectRef <ref>`.

Without login, for CI or a machine that never ran `supabase login`:

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

The connection string is under Connect in the dashboard (session pooler, port 5432), url-encode the password. The access token comes from Account → Access Tokens. Leave token and ref away and the script only pushes migrations, which is fine for the self hosted stack because that's all the cli can do there anyway (functions there are copied files, see `copy.sh` in `backend-self-hosted`).

Two things to know:

- `config push` sends the whole config.toml, auth settings included. With the current values that means signups auto confirm and email confirmation is off, wanted for dev, check the diff it prints if the project matters.
- cli versions are currently a mess: `link` only works on 2.111.0 ([supabase/cli#6115](https://github.com/supabase/cli/issues/6115)) while `db push` against newly created projects only works on 2.112.0. Both are installed via scoop, switch with `scoop reset supabase@<version>`, or set `SUPABASE_DB_PUSH_BIN` to the 2.112.0 exe so the deploy scripts do it for you.

After a deploy the Data API serves exactly `beat`, `beatmix`, `beatmixbeat` and `rawbeat` to signed in users, nothing to configure, that's just the grants from the initial migration (`audiooutputlog` and `migrations` have none, `anon` gets nothing at all). Clients have to name the schema: `.schema('librebeats')` in supabase-js, `Accept-Profile: librebeats` on raw REST.

## Reverting

Takes everything out again: the `librebeats` schema, the pgmq extension with its queues, both buckets including files, the listener user, the migration history rows and (given a ref) the `menu` function. Destructive, there is no undo.

```bash
SUPABASE_DB_URL='postgresql://...' ./revert.sh          # logged in, linked project
SUPABASE_DB_URL='postgresql://...' ./revert-no-login.sh # + SUPABASE_ACCESS_TOKEN and SUPABASE_PROJECT_REF
```

Same on Windows with `revert.ps1` / `revert-no-login.ps1`. `SUPABASE_DB_URL` is always required, dropping schemas is sql and the cli has no way to run sql over a login session, so the teardown (`revert.sql`) goes through psql, or a `postgres:17-alpine` container when psql isn't installed. With an access token set the exposed api schemas get reset too. For the local stack don't bother, `supabase db reset` is the same thing.

## Baselining

The cli tracks applied migrations in `supabase_migrations.schema_migrations` and knows nothing about the Go runner's `librebeats.migrations`. Pushing to an instance the Go service already migrated fails on the existing objects, mark the already applied ones once:

```bash
supabase migration repair --status applied 20260807000000 --db-url "postgresql://..."
supabase migration repair --status applied 20260807000001 --db-url "postgresql://..."
```

Fresh instances don't need this.

## Adding a migration

```bash
supabase migration new <description>
```

gives a timestamped file in `supabase/migrations/`, fill it with sql and deploy. The timestamps fix the numbering quirks of the self hosted runner (lexical order, the off-by-one), but as long as both systems are in use every new migration also needs a numbered copy in `backend-self-hosted/supabase/service/migration/scripts/`, and the old rule still applies there: a migration that adds a table brings its own grants and policies.
