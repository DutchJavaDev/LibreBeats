# Liberated Beats — Flutter Frontend

The cross platform Flutter client for **LibreBeats**, a dark Spotify style music player that streams from one or more self hosted [Supabase](../backend/) backends.

> Status: search, streaming playback (background included), media notifications and beatmix browsing all work against real servers. Home, Library and Liked still render sample data. See [Feature status](#feature-status).

## Quick start

```bash
cd src/frontend
flutter pub get
flutter run \
  --dart-define=LIBREBEATS_SEED_URLS=https://your-server.example.com \
  --dart-define=LIBREBEATS_SEED_KEYS=sb_publishable_yourkey
```

The seed defines register your first server(s) on a fresh install, after that servers are managed in Settings and persist on device. No login ships in the app: set the default login under Settings → Servers on first run, or bake one into your local build with a git-ignored `env.json` (`flutter run --dart-define-from-file=env.json`). See [Configuration](#configuration).

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
                └───────────►  Supabase server(s)  ◄──┘
```

Repositories reach the servers through `ServerRegistry`, so everything above it works against one or many backends without caring. All of it is wired up in [`main.dart`](lib/main.dart) with a single `MultiProvider`.

### Startup (`lib/main.dart`)

Locks portrait orientation and sets the system chrome, loads the persisted server list (seeded from dart-defines on a fresh install) and kicks off the sign-ins in the background, sets up the audio service for background playback, then runs the app with everything registered in the `MultiProvider`.

## File structure

```
lib/
├── main.dart                          # Entry: server seed, audio service, MultiProvider
├── app.dart                           # MaterialApp + Material 3 dark theme
├── config/
│   └── helpers.dart                   # PrintLog + shared typedefs
├── models/
│   └── beat_models.dart               # Beat, BeatMix, SearchResult + gradient palette + sample data
├── providers/
│   ├── background_audio_provider.dart # playback state facade for the UI
│   └── catalog_provider.dart          # LibreProvider, the merged beatmix catalog + cache
├── services/
│   └── audio_playback_service.dart    # BaseAudioHandler over just_audio
├── data/
│   ├── server_registry.dart           # multi-server registry: connections, health, persistence
│   ├── catalog_cache_store.dart       # disk store for per-server results + fetch timers
│   ├── base_repository.dart           # repository base, access to the registry
│   ├── beat_repository.dart           # beat queries (findByTitle)
│   └── beatmix_repository.dart        # per-server menu edge function fetch
├── screens/
│   ├── main_scaffold.dart             # Bottom nav + IndexedStack host + MiniPlayer
│   ├── home_screen.dart               # Greeting, recents grid, track list
│   ├── search_screen.dart             # Sticky search header, live results, beatmix browse grid
│   ├── library_screen.dart            # Filter chips, Liked entry, playlists (sample data)
│   ├── liked_screen.dart              # Liked hero + track list (sample data)
│   └── settings_screen.dart           # Servers section + about
└── widgets/
    ├── mini_player.dart               # Docked compact player above the nav bar
    ├── full_player.dart               # Full-screen "now playing" sheet
    ├── beat_tile.dart                 # Reusable beat list row
    ├── add_server_scan.dart           # QR scanner for adding servers (+ manual fallback dialog)
    ├── servers_section.dart           # Expandable server management card in settings
    ├── search_result_tile.dart        # SearchTile, renders a beat row or a beatmix card
    └── widget_builder.dart            # createCachedNetworkImage helper + BeatMix full-screen dialog
```

## Domain models (`lib/models/beat_models.dart`)

- `Beat`: id, sourceId, title, artist, thumbnailUrl, duration, a gradient fallback color and an optional `audioUrl` (the streaming url, null in sample data which makes those unplayable, `playBeat` skips them)
- `BeatMix`: a playlist/mix with its beats embedded, plus thumbnailUrl and trackCount
- `SearchResult`: holds either a beat or a beatmix for mixed search results

Ids are only unique per server, so both `Beat` and `BeatMix` carry a `sourceId` (the server url) and expose `key` (`"sourceId:id"`). Active-track highlighting, play/pause toggling and the audio queue tags all use `key`.

The file also keeps the eight gradient palette and the `sampleTracks` / `samplePlaylists` data used by the Liked and Library screens.

## Playback

### `AudioPlaybackService` (`lib/services/audio_playback_service.dart`)

A real `BaseAudioHandler` (with `SeekHandler`) around a `just_audio` `AudioPlayer`:

- `setBeatSource(beat)` plays a single beat and publishes a `MediaItem` for the system notification
- `setBeatMix(mix, initialBeat)` builds the whole queue and starts at the tapped beat, skip/shuffle/loop all work on this queue
- progress comes from the player's `positionStream`, end of track is handled per loop mode (stop, repeat one, or skip next) and finished tracks land in `recentBeats`
- `playbackEventStream` is piped into `playbackState` so the media notification gets its controls, `AudioService.init` in `main.dart` enables background playback

### `BackgroundAudioProvider` (`lib/providers/background_audio_provider.dart`)

A thin `ChangeNotifier` facade the widgets watch. Exposes `currentBeat`, `isPlaying`, `progress`, `elapsed`, `shuffle`, `repeatMode`, `volume` and `recentBeats`, and registers itself as the service's progress callback so every position tick reaches the UI. `playBeat(beat)` toggles play/pause when the same beat is tapped again, `playBeatMix(mix, beat)` starts queue playback.

## Catalog & data access

### Multi-server sources (`lib/data/server_registry.dart`)

`ServerRegistry` (a `ChangeNotifier`) owns the list of Supabase sources. Each `ServerConnection` tracks its url, publishable key, signed-in client, health (connecting / healthy / failed) and an optional login override. Servers added via Settings are validated by an actual sign-in and persisted with `shared_preferences`. On startup the persisted list is reloaded and reconnected, the dart-define seed covers fresh installs.

Sign-in uses the default login (set under Settings → Servers → Default login, persisted on device) unless a server has its own override, set from the server detail sheet or delivered by a QR code that includes logins. No account ships in the app itself.

### Repositories (`lib/data/`)

- `BaseRepository`: thin base that gives repositories the registry and an `isConnected` flag
- `BeatRepository.findByTitle`: title search over `librebeats.beat`, the live query is currently commented out so beat search returns nothing
- `BeatMixRepository.fetchMenuFromServer`: fetches all mixes (beats embedded) from one server via its `menu` edge function with a 10s timeout, throws on failure so the caller can mark the server failed

### `LibreProvider` (`lib/providers/catalog_provider.dart`)

Owns the merged catalog. Every server has its own 20 minute timer, and `ensureCatalog()` (runs when the search tab opens) only refetches the ones whose timer ran out:

- cold start with nothing cached: fetch every healthy server in parallel and drip the shuffled results into the grid one tile at a time (200ms apart)
- still fresh: serve the cache instantly, no loading state
- expired: keep showing the current grid, refetch just those servers in the background (failed ones get a reconnect attempt first) and swap the merged list in silently. A server that fails keeps its stale entry.

The cache has two modes, switched from the search screen header (choice persisted). Disk, the default, stores each server's results + fetch time through `CatalogCacheStore` so a restart reads them back and the timers keep counting across runs. In-memory keeps everything per run and wipes the disk copy when selected.

While the search tab is on screen and the app is foregrounded, a watcher checks every 30s and refreshes expired servers on its own, with a dismissible "Playlists were updated" banner. Everywhere else refreshing stays lazy and happens on the next visit.

`findAllByTitle(query)` merges beat + beatmix title matches into a stream, beatmixes are filtered from the cached list.

## Screens

| Screen | Data source | Notes |
|---|---|---|
| **Home** | `recentBeats` | Quick-picks grid and track list show recently played beats, mostly empty on a fresh launch. |
| **Search** | All servers via `LibreProvider` | Sticky pinned header. Search fires on submit, not per keystroke. Clearing the field restores the browse grid, a randomized merge of every server's mixes that drips in tile by tile on first visit and comes from the cache afterwards. Tapping a beatmix opens a full-screen track list dialog with play/shuffle. |
| **Library** | `samplePlaylists` | Static prototype: inert filter chips, hardcoded "847 songs" Liked entry. |
| **Liked** | `sampleTracks` | Static hero + sample track list, nothing here is playable (no audioUrl). |
| **Settings** | `ServerRegistry` | Just servers and about, the prototype cards are gone until their features exist. The Servers card is expandable: collapsed it shows a one line fleet summary ("11 of 12 connected" + worst-status dot), expanded it groups servers by status with problems on top, gets a filter field past 8 servers, and has Add (QR scan, single or bulk), Share (the fleet as a QR), Retry all and the editable Default login. Tapping a server opens a detail sheet with retry, a per-server login override and remove-behind-confirmation. About shows the version and a working licenses page. |

The `MiniPlayer` docks above the nav bar once something plays and opens the `FullPlayer` sheet: artwork with a paused-scale animation, seek slider (seeks on release), shuffle/repeat, volume, and skip previous/next against the current queue.

## Dependencies

| Package | Used for |
|---|---|
| `provider` | State management (`MultiProvider`, `context.watch/read`) |
| `supabase_flutter` | Auth, PostgREST queries, Edge Function calls |
| `just_audio` | Audio engine (sources, queues, shuffle/loop, position stream) |
| `audio_service` | Background playback + media notification (`BaseAudioHandler`) |
| `cached_network_image` | Thumbnail/artwork loading with caching |
| `mobile_scanner` | QR scanning in the Add server flow |
| `qr_flutter` | Rendering the Share-servers QR code |
| `google_fonts` | Plus Jakarta Sans across the whole theme (bundled in `assets/google_fonts/`, runtime fetching disabled) |
| `shared_preferences` | Persisting the server list added via Settings |
| `path_provider` | Declared for the planned download feature, not used yet |

## Configuration

Servers are managed at runtime from **Settings → Servers** and persisted with `shared_preferences`. Adding servers scans a QR code whose payload is JSON — a single server or a list:

```json
{"url": "https://your-server.example.com", "key": "sb_publishable_…"}
```

```json
[{"url": "https://a.example.com", "key": "…"}, {"url": "https://b.example.com", "key": "…"}]
```

Entries can optionally carry `"email"` and `"password"` for servers that use their own account. The Share action in settings renders your current server list in that same format, with an "Include logins" toggle so another device picks up the whole fleet, credentials included, with one scan (the passwords are in the QR in plain text, hence the toggle). Manual url/key entry is available as a fallback on the scanner screen.

On a fresh install [`main.dart`](lib/main.dart) can also seed servers from the `LIBREBEATS_SEED_URLS` / `LIBREBEATS_SEED_KEYS` dart-defines.

Sign-in credentials: **no login ships in the app.** On first run the servers section shows "Not set" until you save a default login (Settings → Servers → Default login), or until logins arrive via a QR scan. Per-server overrides live in the detail sheet (Login button). Everything is stored in `shared_preferences` on the device.

For local development you can bake a login into your own builds with a git-ignored `env.json`:

```json
{
  "LIBREBEATS_DEV_EMAIL": "you@example.com",
  "LIBREBEATS_DEV_PASSWORD": "yourpassword"
}
```

```bash
flutter run --dart-define-from-file=env.json
```

> Keep `env.json` out of git (it is in `.gitignore`). Values baked in this way do end up in that build's binary, so treat dev builds accordingly. Point the seed values at your own self-hosted stack from [`src/backend`](../backend/).

## Feature status

| Area | State |
|---|---|
| Streaming playback (single beat + beatmix queue) | Working |
| Background audio + media notification | Working |
| Skip / shuffle / repeat / seek / volume | Working, queue based |
| Beatmix browse + full-screen track dialog | Working, menu edge function per server |
| Multi-server sources (add/remove in settings, health dots) | Working, persisted, bulk QR add/share, per-server retry |
| Catalog cache (20 min per-server timer, silent refresh) | Working, disk or in-memory, toggle on search |
| Search for beatmixes | Working, filters the cached merged catalog |
| Search for beats | Partial, query commented out, returns nothing |
| Supabase auth | Partial, sign-in only (default login + per-server overrides), no registration |
| Home screen | Partial, shows recently played only |
| Library / Liked screens | Sample data only |
| Likes / playlists (user-owned) | Not implemented |
| Offline downloads | Not implemented, `path_provider` unused |

### Known quirks

- The beatmix dialog's track tiles can't highlight the actively playing beat (no state hookup inside the dialog).
- Search by title only sees the cached catalog, content newer than the cache window shows up after the next refresh.
- The media notification's album label is a placeholder (`"x0x"`).

## Testing

```bash
cd src/frontend
flutter test
```

Tests run offline, no device or camera needed. Server connectivity is faked through the registry's `connector` and the provider takes small `cacheTtl`/`dripInterval` values in tests.

Covered so far: the models (key identity across servers, playability), ServerRegistry (persistence, add/remove, reconnect logic), CatalogCacheStore (round trips, corrupt data), LibreProvider (multi-server merge, drip loading, cache ttl, failure recovery, the visible-page watcher), the QR payload parser, the manual add-server dialog, BeatTile and the settings servers section.

Not covered yet: MiniPlayer, FullPlayer and BackgroundAudioProvider (need an abstraction over just_audio's platform channels first) and the scanner screen itself (camera).

## Design language

Dark-only Material 3 theme defined in [`app.dart`](lib/app.dart): background `#121212`, raised surfaces `#282828`/`#181818`, brand green `#1ED760` for active states, secondary text `#A7A7A7`, Plus Jakarta Sans everywhere. Artwork falls back to a two-color gradient palette when images are unavailable. Navigation is a five-tab `NavigationBar` (Home, Search, Library, Liked, Settings) over an `IndexedStack`, so each tab keeps its scroll position.
