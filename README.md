# LibreBeats

> “Why did Spotify increase their price again …. How does Spotify work …. LibreBeats …” — how this project came to be.

**LibreBeats** is a self-hosted music streaming platform: a Spotify-style client you run yourself, backed by your own catalog and infrastructure instead of a commercial subscription.

## Overview

The project is split in two:

- [`src/frontend`](src/frontend): cross platform Flutter app (Home, Search, Library, Liked, Settings + mini/full player UI)
- [`src/backend`](src/backend): self-hosted [Supabase](https://supabase.com/docs/guides/self-hosting/docker) plus Go services for SQL migrations and audio ingest

**Current state:** the app streams real audio from one or more self hosted Supabase backends. Search, beatmix browsing, background playback and multi-server management (QR code add in Settings, 20 minute catalog cache) all work. Home, Library and Liked still run on sample data. On the backend a queue worker ingests YouTube URLs into Postgres and Supabase Storage. More frontend detail in [`src/frontend/README.md`](src/frontend/README.md).

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) SDK, Dart `>=3.0.0 <4.0.0`
- [Docker](https://docs.docker.com/get-docker/) with Docker Compose for the Supabase stack
- [Go](https://go.dev/dl/) `1.25+` for the migration and audio services
- Bash for the `src/backend/*.sh` helper scripts (Linux/macOS/WSL)

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
│  Self-hosted Supabase (src/backend/supabase), 1..n of these │
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
    │   │   ├── providers/             # BackgroundAudioProvider, LibreProvider (catalog + cache)
    │   │   ├── services/              # AudioPlaybackService (just_audio + audio_service)
    │   │   ├── data/                  # ServerRegistry + beat/beatmix repositories
    │   │   ├── screens/               # main_scaffold, home, search, library, liked, settings
    │   │   └── widgets/               # mini/full player, tiles, QR server scanner
    │   └── test/                  # Flutter unit + widget tests
    └── backend/
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
```

## Frontend (`src/frontend`)

Flutter app with a dark, Spotify-like shell.

| Screen | Purpose |
|--------|---------|
| **Home** | Greeting, quick-picks grid of recently played beats, track list |
| **Search** | Title search + "Browse Playlists" grid merging beatmixes from all registered servers |
| **Library** | Filter chips, Liked Songs entry, playlist list (sample data) |
| **Liked** | Liked Songs hero header + track list (sample data) |
| **Settings** | Server management (add via QR scan, status dots, remove) + grouped setting cards |

Most declared packages are in real use by now: `provider`, `supabase_flutter`, `just_audio` + `audio_service`, `cached_network_image`, `mobile_scanner`, `shared_preferences` and `google_fonts`. Only `path_provider` is still waiting for the download feature, see [`pubspec.yaml`](src/frontend/pubspec.yaml).

Where it stands: real streaming (single beats and beatmix queues) with media notifications and background playback. Servers are added via QR code in settings and persisted on device, the search grid merges every server's beatmixes and caches them for 20 minutes. Home, Library and Liked still run on sample data, and the settings toggles don't persist yet. Full details, config and the feature table live in [`src/frontend/README.md`](src/frontend/README.md).

## Backend (`src/backend`)

### Supabase stack

[`src/backend/supabase`](src/backend/supabase) is the official **self-hosted Supabase** Docker Compose setup. See [Self-Hosting with Docker](https://supabase.com/docs/guides/self-hosting/docker).

- Configure via `.env` (copied from `.env.example` on first `build.sh`).
- `variables.sh` sets `PROJECT_DIR`, `BUILD_DIRECTORY`, and `GENERATE_KEYS` (runs `utils/generate-keys.sh` when `true`).

### Go services

| Service | Package path | Responsibility |
|---------|----------------|----------------|
| **migration** | `service/migration` | Applies numbered SQL in `scripts/`; records runs in `Librebeats.Migrations` |
| **audio** | `service/audio` | Consumes `audiopipe-input` (PGMQ), runs yt-dlp, uploads to Storage, writes `Beat` / `BeatMix` |

### Database schema (`Librebeats`)

Defined in [`0 initial.sql`](src/backend/supabase/service/migration/scripts/0%20initial.sql):

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

## Testing

Both the Go services and the Flutter app have unit tests, none of them need Docker, Postgres, yt-dlp or a device.

```bash
# Migration helpers + script naming
cd src/backend/supabase/service/migration
go test ./...

# Pipeline parsing, file utilities, env guards, models
cd src/backend/supabase/service/audio
go test ./...

# Frontend unit + widget tests
cd src/frontend
flutter test
```

| Package | What is tested |
|---------|----------------|
| `migration` | Migration filename ID parsing, “migrations table missing” detection, `scripts/` naming convention |
| `audio` | Queue JSON URL parsing, playlist URL detection, directory/file helpers, archive lookup, `ProgressState`, required env panics |
| `frontend` | Models, ServerRegistry (persistence/reconnect), catalog provider (merge/drip/cache/failures), QR payload parsing, add-server dialog, BeatTile, settings servers card |

Integration tests against a live Supabase stack are not included yet.

## Getting started

### Backend

From [`src/backend`](src/backend). Edit [`variables.sh`](src/backend/variables.sh) if needed (default build output: `~/librebeats/Herman`).

```bash
./build.sh   # Copy compose tree, build migration image (+ optional key generation)
./run.sh     # Build audio image, docker compose up -d
./stop.sh    # docker compose down
```

After startup, use Studio and API URLs from your `.env` / `SUPABASE_PUBLIC_URL`.

> **Production:** Default Supabase self-host settings are not production-safe. Rotate secrets, review CORS, and read [security notes](src/backend/supabase/README.md) before exposing the stack.

### Frontend

```bash
cd src/frontend
flutter pub get
flutter run \
  --dart-define=LIBREBEATS_DEV_EMAIL=you@example.com \
  --dart-define=LIBREBEATS_DEV_PASSWORD=yourpassword \
  --dart-define=LIBREBEATS_SEED_URLS=https://your-server.example.com \
  --dart-define=LIBREBEATS_SEED_KEYS=sb_publishable_yourkey
```

The dart-defines hold the dev login and the first-run server seed, so nothing sensitive lives in source. After the first run servers are managed in settings. More in [`src/frontend/README.md`](src/frontend/README.md).

## Roadmap

| Area | Target | Current |
|------|--------|---------|
| Playback | Stream from Storage / signed URLs | Done, with background playback + media notification |
| Catalog | Read `Beat` / `BeatMix` from Supabase | Done, menu edge function merged across servers with a 20 min cache |
| Auth | Supabase Auth in Flutter | Wired for existing users, can't register (jet) |
| Music servers | LibreBeats / Navidrome / Jellyfin | Multiple LibreBeats servers via QR in settings, Navidrome/Jellyfin not started |
| Ingest | Queue YouTube URLs → catalog | Worker with VT + DLQ; app not connected |
| Tests | CI + integration tests for DB/queue | Go + Flutter unit/widget tests |

Audio worker env (optional): `QUEUE_VISIBILITY_TIMEOUT_SEC` (default 600), `QUEUE_MAX_READ_COUNT` (default 5), `QUEUE_DLQ_NAME` (default `audiopipe-dlq`). Container `restart: unless-stopped`.

## License & upstream

- Supabase self-host files: upstream licensing and docs in [`src/backend/supabase/README.md`](src/backend/supabase/README.md).
- Other components (Flutter, yt-dlp, Go modules, etc.) carry their own licenses, check each dependency before distribution.
