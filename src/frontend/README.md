# Liberated Beats — Flutter Frontend

The cross-platform Flutter client for **LibreBeats**: a dark, Spotify-style music player wired to a self-hosted [Supabase](../backend/) backend for catalog search and real audio streaming (background playback included).

> **Status:** transitioning from UI prototype to real client. Search, streaming playback, media notifications, and playlist (BeatMix) browsing work against Supabase. Home, Library, Liked, and Settings still render sample/static data. See [Feature status](#feature-status).

## Quick start

```bash
cd src/frontend
flutter pub get
flutter run \
  --dart-define=LIBREBEATS_DEV_EMAIL=you@example.com \
  --dart-define=LIBREBEATS_DEV_PASSWORD=yourpassword \
  --dart-define=LIBREBEATS_SEED_URLS=https://your-server.example.com \
  --dart-define=LIBREBEATS_SEED_KEYS=sb_publishable_yourkey
```

The dev account signs in to every server (development-only assumption); the seed defines register your first server(s) on a fresh install — after that, servers are managed in **Settings → Servers** and persist on-device. See [Configuration](#configuration).

## Architecture

The app is layered: UI → providers (state) → service/repositories → Supabase / just_audio.

```
┌───────────────────────────────────────────────────────────┐
│  Screens & widgets                                        │
│  main_scaffold (IndexedStack tabs) · mini/full player     │
└───────────────┬───────────────────────────┬───────────────┘
                │ watch/read                │
┌───────────────▼───────────┐ ┌─────────────▼──────────────┐
│  BackgroundAudioProvider  │ │  LibreProvider (catalog)   │
│  playback state for UI    │ │  search + beatmix loading  │
└───────────────┬───────────┘ └─────────────┬──────────────┘
                │                           │
┌───────────────▼───────────┐ ┌─────────────▼──────────────┐
│  AudioPlaybackService     │ │  BeatRepository            │
│  BaseAudioHandler         │ │  BeatMixRepository         │
│  (audio_service +         │ │  (extend BaseRepository)   │
│   just_audio)             │ └─────────────┬──────────────┘
└───────────────┬───────────┘               │
                │ streams audio from        │ PostgREST (`librebeats`
                │ `streamingurl`            │ schema) + `menu` Edge Function
                └───────────►  Supabase  ◄──┘
```

All five providers are registered in [`main.dart`](lib/main.dart) via a single `MultiProvider`: the two repositories and the `AudioPlaybackService` as plain `Provider.value`s, plus the two `ChangeNotifier`s that depend on them.

### Startup sequence (`lib/main.dart`)

1. Configure `cached_network_image` logging (debug vs. release).
2. `WidgetsFlutterBinding.ensureInitialized()`, lock portrait orientation, set system UI overlay (transparent status bar, black nav bar).
3. Register Supabase clients with `BaseRepository.addSupabaseClient(url, key)` — each client signs in with password auth (registration is not supported yet).
4. Construct repositories + `AudioPlaybackService`, then `AudioService.init(...)` so playback survives backgrounding and shows a media notification.
5. `runApp` with the `MultiProvider` described above.

## File structure

```
lib/
├── main.dart                          # Entry: bindings, Supabase clients, AudioService.init, MultiProvider
├── app.dart                           # MaterialApp + Material 3 dark theme (Plus Jakarta Sans, #1ED760 accent)
├── config/
│   ├── supabase_config.dart           # SupabaseConfig url/anonKey + isConfigured flag
│   └── helpers.dart                   # VoidCallbackUpdateProgress typedef
├── models/
│   └── beat_models.dart               # Beat, Album, BeatMix, SearchResult + gradient palette + sample data
├── providers/
│   ├── background_audio_provider.dart # BackgroundAudioProvider — playback state facade for the UI
│   └── catalog_provider.dart          # LibreProvider — search + beatmix catalog
├── services/
│   └── audio_playback_service.dart    # AudioPlaybackService — BaseAudioHandler over just_audio
├── data/
│   ├── server_registry.dart           # Multi-server registry: connections, health, persistence
│   ├── base_repository.dart           # Repository base — access to the ServerRegistry
│   ├── beat_repository.dart           # Beat queries (findByTitle)
│   └── beatmix_repository.dart        # Per-server `menu` Edge Function fetch
├── screens/
│   ├── main_scaffold.dart             # Bottom nav + IndexedStack host + MiniPlayer
│   ├── home_screen.dart               # Greeting, recents grid, albums row, track list
│   ├── search_screen.dart             # Sticky search header, live results, beatmix browse grid
│   ├── library_screen.dart            # Filter chips, Liked entry, playlists (sample data)
│   ├── liked_screen.dart              # Liked hero + track list (sample data)
│   └── settings_screen.dart           # Grouped setting cards (static, not persisted)
└── widgets/
    ├── mini_player.dart               # Docked compact player above the nav bar
    ├── full_player.dart               # Full-screen "now playing" sheet
    ├── album_card.dart                # Album tile with play button
    ├── track_tile.dart                # Reusable track list row
    ├── search_result_tile.dart        # SearchTile — renders a Beat row or BeatMix card
    └── widget_builder.dart            # createCachedNetworkImage helper + BeatMix full-screen dialog
```

## Domain models (`lib/models/beat_models.dart`)

| Model | Key fields | Notes |
|---|---|---|
| `Beat` | `int id`, `title`, `artist`, `album`, `duration`, `Gradient color`, `audioUrl?` | A track. `album` currently carries the **thumbnail URL** from the backend; `audioUrl` is the streaming URL. `color` is a gradient fallback behind the artwork. |
| `BeatMix` | `int id`, `title`, `thumbnailUrl`, `trackCount`, `List<Beat>? beats` | A playlist/mix with its tracks embedded. |
| `Album` | `id`, `title`, `artist`, `year`, `color` | Only used by the Home albums row (currently always empty from the provider). |
| `SearchResult` | `Beat? beat`, `BeatMix? beatMix` | Union type for mixed search results. |

The file also keeps an eight-gradient palette and `sampleTracks` / `sampleAlbums` / `samplePlaylists` sample data, still used by the Liked and Library screens and as artwork fallback colors.

## Playback

### `AudioPlaybackService` (`lib/services/audio_playback_service.dart`)

A real `BaseAudioHandler` (with `SeekHandler`) around a `just_audio` `AudioPlayer`:

- **Single beat** — `setBeatSource(beat)` sets a `UriAudioSource` from `beat.audioUrl` and publishes a `MediaItem` for the system notification.
- **BeatMix queue** — `setBeatMix(mix, initialBeat)` builds `MediaItem`s + audio sources for every beat in the mix and hands them to `setAudioSources` with the tapped beat as the initial index. Skip next/previous, shuffle, and loop modes operate on this queue.
- **Progress** — driven by the player's `positionStream`; end-of-track is detected and handled per loop mode (stop, repeat one, or skip next on repeat all). Finished tracks are appended to `recentBeats`.
- **System integration** — `playbackEventStream` is piped into `playbackState`, so the media notification shows skip/play/pause/stop controls; `AudioService.init` in `main.dart` enables background playback.

### `BackgroundAudioProvider` (`lib/providers/background_audio_provider.dart`)

A thin `ChangeNotifier` facade the widgets watch. Exposes `currentBeat`, `isPlaying`, `progress`, `elapsed`, `shuffle`, `repeatMode` (just_audio's `LoopMode`), `volume`, and `recentBeats`. Registers itself as the service's progress callback so every position tick notifies the UI. `playBeat(beat)` toggles play/pause when the same beat is tapped again; `playBeatMix(mix, beat)` starts queue playback.

## Catalog & data access

### Multi-server sources (`lib/data/server_registry.dart`)

`ServerRegistry` (a `ChangeNotifier`) owns the list of Supabase sources. Each `ServerConnection` tracks its URL, publishable key, signed-in client, and health (`connecting / healthy / failed`). Servers added via Settings are validated by an actual sign-in and persisted with `shared_preferences`; on startup the persisted list is reloaded and reconnected (a dev seed pair in `main.dart` covers fresh installs). Sign-in uses a single **development-only** shared account for every server.

### Repositories (`lib/data/`)

- **`BaseRepository`** — thin base giving repositories access to the registry (`registry.healthy`) and an `isConnected` flag.
- **`BeatRepository.findByTitle(query)`** — title search over `librebeats.beat`. *The live query is currently commented out, so beat search returns no rows.*
- **`BeatMixRepository.fetchMenuFromServer(server)`** — fetches all mixes (with embedded beats) from **one** server via its `menu` Edge Function, with a 10s timeout; throws on failure so the caller can mark the server failed. Results are tagged with the server URL (`sourceId`).

### `LibreProvider` (`lib/providers/catalog_provider.dart`)

Owns the merged catalog and its **20-minute cache**. `ensureCatalog()` (triggered when the Search tab is opened):

- **First load** — waits for startup sign-ins, fetches every healthy server in parallel, and drips the shuffled results into the visible grid one tile at a time (200ms apart).
- **While fresh** — serves the cache instantly, no loading state.
- **After the TTL** — keeps showing the stale grid, retries previously failed servers, refetches in the background, and swaps the list in silently (stale results are kept if every server fails).

`findAllByTitle(query)` merges beat + beatmix title matches into a `Stream<List<SearchResult>>` (beatmixes filter the cached list). `albums` is currently always empty.

### Beat/BeatMix identity across servers

Row ids are only unique per server, so both models carry a `sourceId` (the server URL) and expose `key` (`"sourceId:id"`). All identity checks — active-track highlighting, play/pause toggling, and the audio queue's source tags — use `key`.

## Screens

| Screen | Data source | Notes |
|---|---|---|
| **Home** | `recentBeats` + `LibreProvider.albums` | Quick-picks grid and track list show recently played beats — mostly empty on a fresh launch. Albums row is empty (provider returns `[]`). |
| **Search** | All servers via `LibreProvider` | Sticky pinned header. Search fires on **submit** (`onEditingComplete`), not per keystroke; clearing the field restores the "Browse Playlists" grid — a randomized merge of every server's mixes that drips in tile-by-tile on first visit and serves the 20-min cache afterwards. Tapping a beatmix opens a full-screen track-list dialog (`widget_builder.dart`) with play/shuffle. |
| **Library** | `samplePlaylists` | Static prototype: inert filter chips, hardcoded "847 songs" Liked entry. |
| **Liked** | `sampleTracks` | Static hero + sample track list; the FAB plays `sampleTracks[0]` (no real `audioUrl`, so it won't produce audio). |
| **Settings** | `ServerRegistry` + local `setState` | The Servers card lists every source with a live status dot (green/amber/red), remove buttons, and an "Add server" dialog (URL + publishable key, validated by signing in). Other toggles work visually but don't persist; log-out is inert. |

**Players:** the `MiniPlayer` docks above the nav bar once something plays (progress bar, play/pause, skip next) and opens the `FullPlayer` sheet — artwork with paused-scale animation, seek slider (seeks on drag end), shuffle/repeat, volume, and working skip previous/next against the current queue.

## Dependencies

| Package | Used for |
|---|---|
| `provider` | State management (`MultiProvider`, `context.watch/read`) |
| `supabase_flutter` | Auth, PostgREST queries, Edge Function calls |
| `just_audio` | Audio engine (sources, queues, shuffle/loop, position stream) |
| `audio_service` | Background playback + media notification (`BaseAudioHandler`) |
| `cached_network_image` | Thumbnail/artwork loading with caching |
| `google_fonts` | Plus Jakarta Sans across the whole theme |
| `shared_preferences` | Persisting the server list added via Settings |
| `path_provider` | Declared for planned downloads — **not yet imported** |

## Configuration

Servers are managed at runtime from **Settings → Servers** and persisted with `shared_preferences`. On a fresh install, [`main.dart`](lib/main.dart) seeds servers from the `LIBREBEATS_SEED_URLS` / `LIBREBEATS_SEED_KEYS` dart-defines; every server signs in with the shared dev account from `LIBREBEATS_DEV_EMAIL` / `LIBREBEATS_DEV_PASSWORD` (see [Quick start](#quick-start)). No credentials live in source. [`config/supabase_config.dart`](lib/config/supabase_config.dart) is now unused legacy.

> ⚠️ **Do not commit real credentials.** Values passed via `--dart-define` stay out of git; keep it that way. Point the seed values at your own self-hosted stack from [`src/backend`](../backend/).

## Feature status

| Area | State |
|---|---|
| Streaming playback (single beat + beatmix queue) | Working |
| Background audio + media notification | Working |
| Skip / shuffle / repeat / seek / volume | Working (queue-based) |
| Beatmix browse + full-screen track dialog | Working (`menu` Edge Function per server) |
| Multi-server sources (add/remove in Settings, health dots) | Working — persisted via `shared_preferences` |
| Catalog cache (20-min TTL, silent background refresh) | Working |
| Search — beatmixes | Working (in-memory filter over cached merged catalog) |
| Search — beats | Partial — query commented out; returns nothing |
| Supabase auth | Partial — sign-in only, hardcoded account; no registration/UI |
| Home screen | Partial — recents-driven; albums row empty |
| Library / Liked screens | Sample data only |
| Settings persistence | Visual only (`shared_preferences` unused) |
| Likes / playlists (user-owned) | Not implemented |
| Offline downloads | Not implemented (`path_provider` unused) |

### Known quirks

- `Beat.album` doubles as the thumbnail URL — a dedicated `thumbnailUrl` field would be clearer.
- `AlbumCard` loads a placeholder image from `picsum.photos` instead of real album art.
- The beatmix dialog's track tiles can't highlight the actively playing beat (no state hookup inside the dialog).
- Search-by-title over beatmixes only sees the cached catalog — content newer than the 20-minute cache window needs a TTL refresh to appear.
- `MediaItem.artUri` is built from `beat.album` and the album label is a placeholder (`"x0x"`).

## Design language

Dark-only Material 3 theme defined in [`app.dart`](lib/app.dart): background `#121212`, raised surfaces `#282828`/`#181818`, brand green `#1ED760` for active states, secondary text `#A7A7A7`, Plus Jakarta Sans everywhere. Artwork falls back to a two-color gradient palette when images are unavailable. Navigation is a five-tab `NavigationBar` (Home, Search, Library, Liked, Settings) over an `IndexedStack`, so each tab keeps its scroll position.
