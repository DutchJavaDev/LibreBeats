# LibreBeats

> “Why did Spotify increase their price again …. How does Spotify work …. LibreBeats …” — how this project came to be.

**LibreBeats** is a self-hosted music streaming platform: a Spotify-style client you run yourself, backed by your own catalog and infrastructure instead of a commercial subscription.

## Overview

The project is split in three:

- [`src/frontend`](src/frontend): cross platform Flutter app (Home, Search, Library, Liked, Settings + mini/full player UI)
- [`src/backend-self-hosted`](src/backend-self-hosted): self-hosted [Supabase](https://supabase.com/docs/guides/self-hosting/docker) plus Go services for SQL migrations and audio ingest
- [`src/backend`](src/backend): [Supabase CLI](https://supabase.com/docs/guides/local-development) project with the same migrations and the `menu` edge function, for pushing to a running Supabase instance. The Go services don't work there, so no ingest

**Current state:** the app streams real audio from one or more Supabase backends, self hosted or deployed to supabase.com from the CLI project. Search, beatmix browsing, background playback and multi-server management (QR code add in Settings, 20 minute catalog cache) all work. Songs and whole playlists can be liked, they get downloaded and play offline (Android). Home shows your last 10 played beats, the Library holds your liked playlists. On the backend a queue worker ingests YouTube URLs into Postgres and Supabase Storage. More frontend detail in [`src/frontend/README.md`](src/frontend/README.md).

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) SDK, Dart `>=3.0.0 <4.0.0`
- [Docker](https://docs.docker.com/get-docker/) with Docker Compose for the Supabase stack
- [Go](https://go.dev/dl/) `1.25+` for the migration and audio services
- Bash for the `src/backend-self-hosted/*.sh` helper scripts (Linux/macOS/WSL)
- [Supabase CLI](https://supabase.com/docs/guides/local-development) for `src/backend` (local stack + deploys)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Flutter app (src/frontend)                                 │
│  Home · Search · Library · Liked · Settings · player        │
│  Provider state · streaming playback · multi-server catalog │
└───────────────────────────┬─────────────────────────────────┘
                            │  Working: Supabase auth (no register, existing accounts only) +
                            │  real audio (search, playback, background) against one or more servers
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Supabase backend, 1..n of these: the self-hosted stack     │
│  (src/backend-self-hosted) or any instance deployed from    │
│  the CLI project (src/backend)                              │
│  Auth · PostgREST · Storage · Realtime · Studio · Kong      │
└───────────────────────────┬─────────────────────────────────┘
                            │
         ┌──────────────────┼──────────────────┐
         ▼                  ▼                  ▼
   PostgreSQL          Supabase Storage    PGMQ queue
   Librebeats schema   (audio + thumbs)    audiopipe-input
         ▲                  ▲                  │
         │                  │                  ▼
         │                  │         Go audio service (yt-dlp)
         │                  └──────────────────┘
         │
         Go migration service (SQL scripts on startup)
```

### Intended flow

1. Ingest: URLs get enqueued on `audiopipe-input`, the Go audio worker downloads them with yt-dlp, uploads to Storage and writes the catalog rows.
2. Catalog: clients fetch `BeatMix` records (with their beats embedded) from every registered server via the `menu` edge function, merged and cached in the app.
3. Play: the app streams straight from the catalog urls (offline cache still planned).
4. Personal library: user playlists and external music servers. Multiple LibreBeats servers can be added in settings with a QR scan, Navidrome/Jellyfin not started.

## Project structure

```
LibreBeats/
├── README.md
└── src/
    ├── frontend/
    │   ├── README.md              # Frontend docs: architecture, config, testing
    │   ├── lib/
    │   │   ├── main.dart              # Entry point: server seed, audio service, providers
    │   │   ├── app.dart               # MaterialApp + Material 3 dark theme
    │   │   ├── config/                # helpers
    │   │   ├── models/                # Beat/BeatMix/SearchResult models + sample data
    │   │   ├── providers/             # BackgroundAudioProvider, LibreProvider, LikedProvider
    │   │   ├── services/              # AudioPlaybackService (just_audio + audio_service)
    │   │   ├── data/                  # ServerRegistry, repositories, disk stores (cache, history, liked, offline files)
    │   │   ├── screens/               # main_scaffold, home, search, library, liked, settings
    │   │   └── widgets/               # mini/full player, tiles, QR server scanner
    │   └── test/                  # Flutter unit + widget tests
    ├── backend-self-hosted/
        ├── README.md                  # Backend docs: scripts, services, schema, quirks
        ├── build.sh                   # Build Supabase + custom images
        ├── run.sh                     # Start stack
        ├── stop.sh                    # docker compose down
        ├── variables.sh               # PROJECT_DIR, BUILD_DIRECTORY, …
        └── supabase/
            ├── docker-compose.yml
            └── service/
                ├── migration/
                │   ├── migration.go
                │   ├── migration_helpers.go
                │   ├── migration_test.go
                │   └── scripts/
                │       └── 0 initial.sql
                └── audio/
                    ├── main.go          # Queue consumer loop
                    ├── pipeline.go      # Queue message / URL helpers
                    ├── database.go      # Beat catalog writes
                    ├── queue.go         # PGMQ pop
                    ├── storage.go       # Supabase Storage uploads
                    ├── sourceHelper.go  # yt-dlp integration
                    └── *_test.go        # Unit tests
    └── backend/
        ├── README.md                  # CLI project docs: local stack, deploys, reverts
        ├── deploy.sh / .ps1           # deploy to the linked project
        ├── deploy-no-login.sh / .ps1  # same, env var driven (CI, servers)
        ├── revert.sh / .ps1           # tear a deployment down (+ no-login variants)
        ├── revert.sql                 # the teardown sql
        └── supabase/
            ├── config.toml            # local stack + what config push sends
            ├── migrations/            # initial, dlq, storage buckets, listener user
            └── functions/menu/        # the catalog api
```

## Frontend (`src/frontend`)

Flutter app with a dark, Spotify-like shell.

| Screen | Purpose |
|--------|---------|
| **Home** | Greeting + horizontal history row (last 10 played, persisted) |
| **Search** | Title search (sectioned results, match highlighted) + browse grid merging beatmixes from all registered servers |
| **Library** | Liked Songs entry + your liked playlists, long press removes |
| **Liked** | The liked songs with total playtime, plays as one queue, everything on disk |
| **Settings** | Server management (add via QR scan, health grouping, remove), offline storage usage + about |

Every declared package is in real use by now: `provider`, `supabase_flutter`, `just_audio` + `audio_service` + `audio_session`, `cached_network_image`, `mobile_scanner`, `shared_preferences`, `google_fonts`, and since the liked feature also `sembast`, `background_downloader` and `path_provider`, see [`pubspec.yaml`](src/frontend/pubspec.yaml).

Where it stands: real streaming (single beats and beatmix queues) with media notifications and background playback, playback pauses when headphones unplug or a call comes in. Servers are added via QR code in settings and persisted on device, the search grid merges every server's beatmixes and caches them for 20 minutes, Home keeps a persistent history of the last 10 plays. Songs and whole playlists can be liked, they get downloaded and keep playing offline, even after their server is removed (Android, the opus files don't play on iOS). Full details, config and the feature table live in [`src/frontend/README.md`](src/frontend/README.md).

## Backend (`src/backend-self-hosted`)

More backend detail in [`src/backend-self-hosted/README.md`](src/backend-self-hosted/README.md): the deploy scripts, how the build directory works, both services and their quirks.

### Supabase stack

[`src/backend-self-hosted/supabase`](src/backend-self-hosted/supabase) is the official **self-hosted Supabase** Docker Compose setup. See [Self-Hosting with Docker](https://supabase.com/docs/guides/self-hosting/docker).

- Configure via `.env` (copied from `.env.example` on first `build.sh`).
- `variables.sh` sets `PROJECT_DIR`, `BUILD_DIRECTORY`, and `GENERATE_KEYS` (runs `utils/generate-keys.sh` when `true`).

### Go services

| Service | Package path | Responsibility |
|---------|----------------|----------------|
| **migration** | `service/migration` | Applies numbered SQL in `scripts/`; records runs in `Librebeats.Migrations` |
| **audio** | `service/audio` | Consumes `audiopipe-input` (PGMQ), runs yt-dlp, uploads to Storage, writes `Beat` / `BeatMix` |

### Database schema (`Librebeats`)

Defined in [`0 initial.sql`](src/backend-self-hosted/supabase/service/migration/scripts/0%20initial.sql):

| Table | Purpose | Client access |
|-------|---------|----------------|
| `RawBeat` | Staging: source URL, storage keys, duration | Service role only |
| `Beat` | Published track metadata + streaming URLs | Authenticated **SELECT** |
| `BeatMix` | Playlist / mix metadata | Authenticated **SELECT** |
| `BeatMixBeat` | Beat ↔ mix junction | Authenticated **SELECT** |
| `AudioOutputLog` | Ingest / processing log | Service role only |
| `Migrations` | Applied migration tracking | Service role only |

**PGMQ** queues: `audiopipe-input` (work), `audiopipe-dlq` (failed jobs) — message shape `{ "url": "https://..." }`. The audio worker uses **visibility timeout** (`pgmq.read`); messages are only deleted on success (`pgmq.delete`). Transient failures retry until `QUEUE_MAX_READ_COUNT`; poison or exhausted messages move to the DLQ.

### Audio pipeline

1. Poll PGMQ for a URL message.
2. Detect single video vs playlist (`playlist?` in URL).
3. Download with **yt-dlp** (Opus + thumbnails).
4. Upload to Supabase Storage buckets.
5. Insert `RawBeat` → `Beat`; for playlists, `BeatMix` + `BeatMixBeat`.

## Backend (`src/backend`)

The same backend as a Supabase CLI project: the migrations (schema, queues, storage buckets and a seeded listener user) plus the `menu` edge function, deployable to any Supabase instance, the hosted free tier works fine. The big difference with the self hosted stack is that the Go programs don't work here. A hosted project has nowhere to run your own containers, `db push` does what the migration runner did and the audio worker has no place to live, so no ingest.

- `supabase start` gives a trimmed local dev stack (realtime, analytics and the mail catcher are turned off)
- `deploy.sh` / `deploy.ps1` push everything to the linked project, the `deploy-no-login` variants do the same driven by env vars for CI or servers that never ran `supabase login`
- `revert.sh` / `revert.ps1` (+ no-login variants) take a deployment out again, listener user and buckets included

How to use the scripts, the current cli version mess and baselining instances the Go runner already migrated is all in [`src/backend/README.md`](src/backend/README.md).

## Testing

Both the Go services and the Flutter app have unit tests, none of them need Docker, Postgres, yt-dlp or a device.

```bash
# Migration helpers + script naming
cd src/backend-self-hosted/supabase/service/migration
go test ./...

# Pipeline parsing, file utilities, env guards, models
cd src/backend-self-hosted/supabase/service/audio
go test ./...

# Frontend unit + widget tests
cd src/frontend
flutter test
```

| Package | What is tested |
|---------|----------------|
| `migration` | Migration filename ID parsing, “migrations table missing” detection, `scripts/` naming convention |
| `audio` | Queue JSON URL parsing, playlist URL detection, directory/file helpers, archive lookup, `ProgressState`, required env panics |
| `frontend` | Models, ServerRegistry (persistence/reconnect), catalog provider (merge/drip/cache/failures/search), liked store + provider (downloads, shared files, sweep), disk stores, QR payload parsing, add-server dialog, BeatTile, browse grid, library, settings servers + storage cards |

Integration tests against a live Supabase stack are not included yet.

## Getting started

### Backend, self hosted

From [`src/backend-self-hosted`](src/backend-self-hosted). Edit [`variables.sh`](src/backend-self-hosted/variables.sh) if needed (default build output: `~/librebeats/Herman`).

```bash
./build.sh   # Copy compose tree, build migration image (+ optional key generation)
./run.sh     # Build audio image, docker compose up -d
./stop.sh    # docker compose down
```

After startup, use Studio and API URLs from your `.env` / `SUPABASE_PUBLIC_URL`.

### Backend, hosted Supabase project

From [`src/backend`](src/backend), deploys schema, buckets, listener user and the `menu` function to a project on supabase.com (the free tier is enough):

```bash
supabase login
supabase link --project-ref <ref>
./deploy.sh
```

No ingest this way (the audio worker only exists in the self-hosted stack), fill the catalog through the SQL editor or point the app at a self-hosted server as well. Details and the no-login variant in [`src/backend/README.md`](src/backend/README.md).

> **Production:** Default Supabase self-host settings are not production-safe. Rotate secrets, review CORS, and read [security notes](src/backend-self-hosted/supabase/README.md) before exposing the stack.

### Frontend

```bash
cd src/frontend
flutter pub get
flutter run \
  --dart-define=LIBREBEATS_SEED_URLS=https://your-server.example.com \
  --dart-define=LIBREBEATS_SEED_KEYS=sb_publishable_yourkey
```

The dart-defines hold the first-run server seed. No login ships in the app: the sign-in account is set up in settings on first run (a default login plus per-server overrides), can arrive via a QR scan, or can be baked into local dev builds with a git-ignored `env.json`. More in [`src/frontend/README.md`](src/frontend/README.md).

## Roadmap

| Area | Target | Current |
|------|--------|---------|
| Playback | Stream from Storage / signed URLs | Done, with background playback + media notification |
| Catalog | Read `Beat` / `BeatMix` from Supabase | Done, menu edge function merged across servers with a 20 min cache |
| Auth | Supabase Auth in Flutter | Wired for existing users, can't register (jet) |
| Music servers | LibreBeats / Navidrome / Jellyfin | Multiple LibreBeats servers via QR in settings, Navidrome/Jellyfin not started |
| Likes + offline | Download what you like, play without a server | Done for songs and playlists on Android, iOS blocked on opus playback |
| Ingest | Queue YouTube URLs → catalog | Worker with VT + DLQ; app not connected |
| Tests | CI + integration tests for DB/queue | Go + Flutter unit/widget tests |

Audio worker env (optional): `QUEUE_VISIBILITY_TIMEOUT_SEC` (default 600), `QUEUE_MAX_READ_COUNT` (default 5), `QUEUE_DLQ_NAME` (default `audiopipe-dlq`). Container `restart: unless-stopped`.

## License & upstream

- Supabase self-host files: upstream licensing and docs in [`src/backend-self-hosted/supabase/README.md`](src/backend-self-hosted/supabase/README.md).
- Other components (Flutter, yt-dlp, Go modules, etc.) carry their own licenses, check each dependency before distribution.
