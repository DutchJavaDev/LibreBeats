# LibreBeats

> “Why did Spotify increase their price again …. How does Spotify work …. LibreBeats …” — how this project came to be.

**LibreBeats** is a self-hosted music streaming platform: a Spotify-style client you run yourself, backed by your own catalog and infrastructure instead of a commercial subscription.

The Flutter app tagline: *“Owning a music streaming service is a dream for many, dream arrived.”*

## Table of contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Project structure](#project-structure)
- [Frontend](#frontend-srcfrontend)
- [Backend](#backend-srcbackend)
- [Testing](#testing)
- [Getting started](#getting-started)
- [Roadmap](#roadmap)
- [License & upstream](#license--upstream)

## Overview

| Part | Path | Role |
|------|------|------|
| **Frontend** | [`src/frontend`](src/frontend) | Cross-platform Flutter app (Home, Search, Library, Settings, player UI) |
| **Backend** | [`src/backend`](src/backend) | Self-hosted [Supabase](https://supabase.com/docs/guides/self-hosting/docker) + Go services for SQL migrations and audio ingest |

**Current state:** The UI is largely built with mock data and a simulated player. The backend can ingest YouTube URLs into Postgres and Supabase Storage via a queue worker, but the app is not yet wired to Supabase or real playback.

### Prerequisites

| Tool | Used for |
|------|----------|
| [Flutter](https://docs.flutter.dev/get-started/install) SDK `^3.10.7` | Mobile/desktop client |
| [Docker](https://docs.docker.com/get-docker/) & Docker Compose | Self-hosted Supabase stack |
| [Go](https://go.dev/dl/) `1.25+` | Migration and audio services (build + unit tests) |
| Bash | `src/backend/*.sh` helper scripts (Linux/macOS/WSL) |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Flutter app (src/frontend)                                 │
│  Home · Search · Library · Settings · mini player           │
│  Provider state · mock library today                        │
└───────────────────────────┬─────────────────────────────────┘
                            │  planned: supabase_flutter, just_audio
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Self-hosted Supabase (src/backend/supabase)                │
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

1. **Ingest** — URLs are enqueued on `audiopipe-input`; the Go **audio** worker downloads via **yt-dlp**, uploads to Storage, and writes catalog rows.
2. **Catalog** — Authenticated clients read `Beat` and `BeatMix` records (streaming URLs, metadata).
3. **Play** — The Flutter app streams from those URLs (optional offline cache via planned `sqflite` / local storage).
4. **Personal library** — User playlists and optional external music servers (Settings UI references Navidrome/Jellyfin-style endpoints as placeholders).

## Project structure

```
LibreBeats/
├── README.md
└── src/
    ├── frontend/
    │   └── lib/
    │       ├── main.dart              # App shell, navigation, providers
    │       ├── init.dart              # App bootstrap (Supabase TBD)
    │       ├── data/models.dart
    │       ├── providers/             # LibraryProvider, PlayerProvider
    │       ├── screens/
    │       └── widgets/
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
| **Home** | Last played, suggestions, recent playlists |
| **Search** | Search songs and playlists (in-memory mock data today) |
| **Library** | Playlists and playlist detail |
| **Settings** | Music servers, local storage, about |

**Key dependencies:** `provider`, `just_audio`, `just_audio_background`, `supabase_flutter`, `sqflite`, `cached_network_image`, `http` — see [`pubspec.yaml`](src/frontend/pubspec.yaml).

**Implementation status:**

- `LibraryProvider` — hardcoded songs, playlists, and sample servers.
- `PlayerProvider` — simulated playback (timers), not real audio yet.
- `init.dart` — empty; Supabase not initialized.
- `main.dart` — background audio notification channel configured for future use.

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

Backend Go services have **unit tests** that do not require Docker, Postgres, or yt-dlp.

```bash
# Migration helpers + script naming
cd src/backend/supabase/service/migration
go test ./...

# Pipeline parsing, file utilities, env guards, models
cd src/backend/supabase/service/audio
go test ./...
```

| Package | What is tested |
|---------|----------------|
| `migration` | Migration filename ID parsing, “migrations table missing” detection, `scripts/` naming convention |
| `audio` | Queue JSON URL parsing, playlist URL detection, directory/file helpers, archive lookup, `ProgressState`, required env panics |

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
flutter run
```

## Roadmap

| Area | Target | Current |
|------|--------|---------|
| Playback | Stream from Storage / signed URLs | Simulated player |
| Catalog | Read `Beat` / `BeatMix` from Supabase | Mock data in app |
| Auth | Supabase Auth in Flutter | Not wired |
| Music servers | LibreBeats / Navidrome / Jellyfin | Settings UI + fake status checks |
| Ingest | Queue YouTube URLs → catalog | Worker with VT + DLQ; app not connected |
| Tests | CI + integration tests for DB/queue | Go unit tests only |

Audio worker env (optional): `QUEUE_VISIBILITY_TIMEOUT_SEC` (default 600), `QUEUE_MAX_READ_COUNT` (default 5), `QUEUE_DLQ_NAME` (default `audiopipe-dlq`). Container `restart: unless-stopped`.

## License & upstream

- Supabase self-host files: upstream licensing and docs in [`src/backend/supabase/README.md`](src/backend/supabase/README.md).
- Other components (Flutter, yt-dlp, Go modules, etc.) carry their own licenses — check each dependency before distribution.
