# Liberated Beats — Flutter Frontend

The cross platform Flutter client for **LibreBeats**, a dark-first music player with its own sound-bar design language, streaming from one or more self hosted [Supabase](../backend-self-hosted/) backends.

> Status: search, streaming playback (background included), media notifications and beatmix browsing all work against real servers. Liking works for songs and whole playlists, both get downloaded and play from disk. Home shows your play history, your most played songs and mixes (counted on device) and a server health digest, Library lists your liked playlists. See [Feature status](#feature-status).

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
│   ├── catalog_provider.dart          # LibreProvider, the merged beatmix catalog + cache
│   ├── liked_provider.dart            # liked songs and mixes, downloads, plays-from-disk lookup
│   └── play_stats_provider.dart       # most played songs/mixes for the home screen
├── services/
│   ├── audio_playback_service.dart    # BaseAudioHandler over just_audio
│   ├── beat_download_service.dart     # background_downloader behind a small interface
│   └── play_threshold_counter.dart    # when a listen-through counts as a play
├── data/
│   ├── server_registry.dart           # multi-server registry: connections, health checks, persistence
│   ├── catalog_cache_store.dart       # disk store for per-server results + fetch timers
│   ├── history_store.dart             # disk store for the play history
│   ├── liked_store.dart               # sembast db for liked songs and liked mixes
│   ├── play_stats_store.dart          # sembast db for all-time play counts
│   ├── offline_media_store.dart       # the offline folder: paths, sizes, orphan sweep
│   ├── base_repository.dart           # repository base, access to the registry
│   ├── beat_repository.dart           # live beat title search
│   └── beatmix_repository.dart        # menu edge function fetch + live mix title search
├── screens/
│   ├── main_scaffold.dart             # Bottom nav + IndexedStack host + MiniPlayer
│   ├── home_screen.dart               # Greeting, history, most played, server health
│   ├── search_screen.dart             # Sticky search header, sectioned results, browse grid
│   ├── library_screen.dart            # Liked Songs entry + the liked playlists
│   ├── liked_screen.dart              # Liked hero + the real liked list, plays from disk
│   └── settings_screen.dart           # Servers, storage and about
└── widgets/
    ├── mini_player.dart               # Docked compact player above the nav bar
    ├── full_player.dart               # Full-screen "now playing" sheet
    ├── beat_tile.dart                 # Reusable beat list row (heart + download glyph)
    ├── beatmix_view.dart              # Full-screen mix view: cover, counts, actions, tracks
    ├── browse_mix_card.dart           # Cover card for the browse grid
    ├── add_server_scan.dart           # QR scanner for adding servers (+ manual fallback dialog)
    ├── servers_section.dart           # Expandable server management card in settings
    ├── search_result_tile.dart        # SearchTile rows for song/playlist results + matchSpans
    └── widget_builder.dart            # image helper, the mix dialog, shared like/format helpers
```

## Domain models (`lib/models/beat_models.dart`)

- `Beat`: id, sourceId, title, artist, thumbnailUrl, duration, a gradient fallback color and an optional `audioUrl` (the streaming url, null in sample data which makes those unplayable, `playBeat` skips them)
- `BeatMix`: a playlist/mix with its beats embedded, plus thumbnailUrl and trackCount
- `SearchResult`: holds either a beat or a beatmix, cached beats also remember which playlists they sit in
- `SearchOutcome`: a result list plus where it came from, cache or live servers, and how old the cache is

Ids are only unique per server, so both `Beat` and `BeatMix` carry a `sourceId` (the server url) and expose `key` (`"sourceId:id"`). Active-track highlighting, play/pause toggling and the audio queue tags all use `key`.

The file also keeps the eight gradient palette and the `sampleTracks` / `samplePlaylists` data still used by the Library screen.

## Playback

### `AudioPlaybackService` (`lib/services/audio_playback_service.dart`)

A real `BaseAudioHandler` (with `SeekHandler`) around a `just_audio` `AudioPlayer`:

- `setBeatSource(beat)` plays a single beat, `setBeatMix(mix, initialBeat)` builds the whole queue and starts at the tapped one. Both wait for the source to load and return false when a server is down or a url is dead, so the UI never says "playing" over nothing. Beats without a stream url (sample data) get skipped.
- the queue itself is just_audio's job: tracks advance on their own, repeat one/all loop natively, and when the whole queue runs out playback rewinds and pauses
- the playing flag follows the player's `playingStream`. Pauses from the notification, a headset or losing audio focus all land there too, so the UI stays in sync. The system sends explicit play/pause commands, so those handlers don't toggle.
- an `audio_session` music session pauses when headphones unplug or a call comes in (resumes after the call), and ducks volume when the OS asks
- every track that starts playing lands in `recentBeats`: newest first, max 10, replaying something moves it back to the top. Saved through `HistoryStore` so it survives a restart.
- a **play is counted** once a track has been listened to for 30 seconds or half its length, whichever comes first (`PlayThresholdCounter` accumulates position deltas, so paused time and seeks don't count and a listen-through counts exactly once; repeat-one loops count per loop). Counted plays go out through `setPlayCountedCallback` to `PlayStatsProvider`, which persists them in `PlayStatsStore` (sembast, one record per song and per mix) and feeds the home screen's On repeat and Heavy rotation sections.
- progress comes from the player's `positionStream`, `playbackEventStream` is piped into `playbackState` for the notification controls, and `AudioService.init` in `main.dart` runs before `runApp`

### `BackgroundAudioProvider` (`lib/providers/background_audio_provider.dart`)

A thin `ChangeNotifier` facade the widgets watch. Exposes `currentBeat`, `isPlaying`, `progress`, `elapsed`, `shuffle`, `repeatMode`, `volume` and `recentBeats`, and registers itself with the service so position ticks and history changes reach the UI. `playBeat(beat)` plays solo, `playBeatMix(mix, beat)` starts queue playback, both toggle play/pause when the tapped beat is already the current one instead of restarting it.

## Catalog & data access

### Multi-server sources (`lib/data/server_registry.dart`)

`ServerRegistry` (a `ChangeNotifier`) owns the list of Supabase sources. Each `ServerConnection` tracks its url, publishable key, signed-in client, health (connecting / healthy / failed) and an optional login override. Servers added via Settings are validated by an actual sign-in and persisted with `shared_preferences`. On startup the persisted list is reloaded and reconnected, the dart-define seed covers fresh installs.

Opening the home tab (and returning to the app on it) re-verifies the whole fleet with `checkHealth`: one tiny authenticated select per healthy server, while failed servers (and ones that never signed in) get a fresh sign-in attempt — which also repairs a session the server has revoked. Checks are throttled to once a minute and each server's check is capped by a timeout so one hung request can't wedge the whole thing. Healthy servers that stopped answering get flagged, recovered ones rejoin, and `lastCheckedAt` feeds the "Last checked" line on the home screen's health digest.

Sign-in uses the default login (set under Settings → Servers → Default login, persisted on device) unless a server has its own override, set from the server detail sheet or delivered by a QR code that includes logins. No account ships in the app itself.

### Repositories (`lib/data/`)

- `BaseRepository`: thin base that gives repositories the registry and an `isConnected` flag
- `BeatRepository.findByTitle`: title search over `librebeats.beat` on every healthy server, runs when the cache has no match
- `BeatMixRepository`: fetches all mixes (beats embedded) from one server via its `menu` edge function with a 10s timeout, plus the same live title search for the beatmix table

### `LibreProvider` (`lib/providers/catalog_provider.dart`)

Owns the merged catalog. Every server has its own 20 minute timer, and `ensureCatalog()` (runs when the search tab opens) only refetches the ones whose timer ran out:

- cold start with nothing cached: fetch every healthy server in parallel and drip the shuffled results into the grid one tile at a time (200ms apart)
- still fresh: serve the cache instantly, no loading state
- expired: keep showing the current grid, refetch just those servers in the background (failed ones get a reconnect attempt first) and swap the merged list in silently. A server that fails keeps its stale entry.

The cache has two modes, switched from the search screen header (choice persisted). Disk, the default, stores each server's results + fetch time through `CatalogCacheStore` so a restart reads them back and the timers keep counting across runs. In-memory keeps everything per run and wipes the disk copy when selected.

While the search tab is on screen and the app is foregrounded, a watcher checks every 30s and refreshes expired servers on its own, with a dismissible "Playlists were updated" banner. Everywhere else refreshing stays lazy and happens on the next visit.

`findAllByTitle(query)` searches the cached catalog first (mix titles and the beats inside them) and only queries the servers live when the cache finds nothing. Results come back as a `SearchOutcome`: cached beats remember which playlists they came from (tapping one queues that playlist), and the screen shows where results came from and how fresh the cache is.

## Liked beats & offline

The heart in the full player likes the current beat. The record lands in a small [sembast](https://pub.dev/packages/sembast) database right away ([`liked_store.dart`](lib/data/liked_store.dart)), then audio and thumbnail download in the background into `<app support>/offline/` and playback switches to the file on disk. Records keep a full metadata snapshot plus relative file paths, so liked beats keep playing after their server is removed (and relative because absolute paths go stale on iOS). Un-liking removes the record and both files.

Whole beatmixes work the same way: the heart in the beatmix dialog likes the mix, downloads its cover and every beat, and puts it in the Library. Liked mixes are their own thing, their beats do not show up in Liked Songs. Files are shared by identity, a beat liked on its own and inside a liked mix exists once on disk and only gets deleted when the last like pointing at it goes. Long pressing a mix in the Library removes it behind a confirm.

On startup [`LikedProvider`](lib/providers/liked_provider.dart) reloads everything, sweeps files nothing points at anymore, and retries downloads that failed or never finished. The offline folder stays out of backups: Android has `allowBackup=false` anyway, iOS gets the do-not-back-up attribute through a small `librebeats/backup` channel in the Runner.

## Screens

| Screen | Data source | Notes |
|---|---|---|
| **Home** | `recentBeats` + `PlayStatsProvider` + `ServerRegistry` + `lib/sample/` | Greeting with the brand rule + a History row that scrolls sideways: the last 10 played beats, newest first, persisted on device. **On repeat** ranks your top 10 most played songs (real on-device counts, a play is 30s or half the track) as tappable rows, **Heavy rotation** your most played mixes with "plays · songs played" counts and tap-through to the catalog mix — both show a "Listen to songs/playlists to see this update" hint until something counted. **From your servers** opens with a real health digest (fleet status + last checked, refreshed on visiting the tab); the update cards below it are still mocked samples from [`lib/sample/home_sample_data.dart`](lib/sample/home_sample_data.dart), each marked with a Preview chip. |
| **Search** | All servers via `LibreProvider` | Sticky pinned header. Search fires on submit, not per keystroke. Results come sectioned (songs, playlists) as uniform rows with the match tinted green, liked/downloaded glyphs, and a freshness line at the bottom. Songs from a cached playlist play inside it, skip walks the list. Clearing the field restores the browse grid: sharp square covers with the title below, a heart badge on mixes already in the library, still shuffled per refresh with the drip-in. Tapping a beatmix opens the full-screen mix view: cover, counts, shuffle/heart/play row (synced with the player, download progress when liked) and the track list with the playing beat highlighted. |
| **Library** | `LikedProvider` | The Liked Songs entry (real count, jumps to the Liked tab) and the liked playlists: cover from disk, download progress while a mix is still fetching. Tap opens the mix view, long press removes behind a confirm. A Shuffle all pill plays everything downloaded across the playlists as one queue, shuffle mode on. |
| **Liked** | `LikedProvider` | The real liked list, newest first, the header counts songs and total playtime. Play and Shuffle queue the whole list, rows carry the unlike heart (undo in a snackbar) and the on-disk glyph. |
| **Settings** | `ServerRegistry` + `LikedProvider` + `ThemeController` | Appearance (Dark / Light / System, dark default, persisted), servers, storage, about. The Servers card is expandable: collapsed a problem-first summary ("1 unreachable · 11 connected"), expanded the fleet grouped by status with the error and its age on unreachable rows, Add/Share pills, an amber Retry all and the default login, filter field past 8 servers. The detail sheet has retry, copyable url/key, a login override and remove-behind-confirm. Storage shows what the downloads take on disk with a usage bar and a clear-everything action that states its numbers before deleting. About is the app identity row (tap copies the version) and licenses. |

The `MiniPlayer` docks above the nav bar once something plays and opens the `FullPlayer` sheet: artwork with a paused-scale animation, seek slider (seeks on release), shuffle/repeat, volume, skip previous/next against the current queue, a **sleep timer** (15/30/45 min, 1 h, or end of track — playback pauses when it runs out, the label counts down while armed; session-only), and a **queue view**: a tall sheet with the whole queue in the order it will actually play (the shuffled walk when shuffle is on), scrolled to the current song. Tapping a row jumps the player there without rebuilding or reshuffling anything, the current row toggles play/pause.

## Dependencies

| Package | Used for |
|---|---|
| `provider` | State management (`MultiProvider`, `context.watch/read`) |
| `supabase_flutter` | Auth, PostgREST queries, Edge Function calls |
| `just_audio` | Audio engine (sources, queues, shuffle/loop, position stream) |
| `audio_service` | Background playback + media notification (`BaseAudioHandler`) |
| `audio_session` | Audio focus: pause on unplugged headphones and calls, ducking |
| `cached_network_image` | Thumbnail/artwork loading with caching |
| `mobile_scanner` | QR scanning in the Add server flow |
| `qr_flutter` | Rendering the Share-servers QR code |
| `google_fonts` | Plus Jakarta Sans across the whole theme (bundled in `assets/google_fonts/`, runtime fetching disabled) |
| `shared_preferences` | Persistence: server list, logins, catalog cache, play history |
| `sembast` | The liked-beats database (pure Dart, tests run it in memory) |
| `background_downloader` | Downloads liked beats, keeps going when the app gets backgrounded |
| `path_provider` | The offline media folder in app support |

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

> Keep `env.json` out of git (it is in `.gitignore`). Values baked in this way do end up in that build's binary, so treat dev builds accordingly. Point the seed values at your own self-hosted stack from [`src/backend-self-hosted`](../backend-self-hosted/).

## App icon

All launcher icons come from one 1024px image, `assets/images/librebeats-icon-1024.png`. They are generated with [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons), the config sits in `pubspec.yaml`. After changing the base image run:

```bash
dart run flutter_launcher_icons
```

That takes care of Android (including adaptive icons), iOS (alpha stripped, the App Store wants that), web (favicon, PWA icons, manifest colors), Windows and macOS. Linux has no icon slot in the project, there the icon is set in the `.desktop` entry when packaging. One thing to keep in mind for adaptive icons: launchers mask them to a circle, so keep the artwork roughly in the center two thirds of the image.

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
| Search for beats | Working, cached catalog first, live server query when that finds nothing |
| Supabase auth | Partial, sign-in only (default login + per-server overrides), no registration |
| Play history (last 10, on Home) | Working, persisted on device |
| Play counts (On repeat / Heavy rotation on Home) | Working, counted on device (30s or half the track), all-time, persisted |
| Server health digest (on Home) | Working, probed on visiting the tab, throttled to once a minute |
| Home screen | Working — greeting, history, On repeat + Heavy rotation from real play counts, server health digest; the per-server update cards are still mocked previews |
| Theme (dark default, light + system optional) | Working, icon-derived tokens, persisted in Settings → Appearance |
| Sleep timer (full player) | Working, duration or end-of-track, session-only |
| Queue view (full player) | Working, playback order incl. the shuffle walk, tap to jump without reshuffling |
| Liked beats (heart in the full player) | Working, persisted + downloaded for offline playback (Android, see quirks) |
| Liked beatmixes (heart in the mix dialog) | Working, whole mix downloaded, listed in Library, long press removes |
| Library screen | Real liked playlists + Liked entry + Shuffle all over the downloads, filter chips still inert |
| Playlists (user-owned) | Not implemented |

### Known quirks

- Live search only kicks in when the cache has zero matches, so partial cached hits can hide newer server content until the next refresh.
- Offline playback is Android-first: iOS AVPlayer cannot decode the opus files the backend produces (streamed or local), so iOS needs an AAC/M4A rendition server-side or a different player backend before liked playback works there.

## Testing

```bash
cd src/frontend
flutter test
```

Tests run offline, no device or camera needed. Server connectivity is faked through the registry's `connector` and the provider takes small `cacheTtl`/`dripInterval` values in tests.

Covered so far: the models (key identity across servers, playability), ServerRegistry (persistence, add/remove, reconnect logic, the health check: probe vs sign-in, recovery, the throttle), CatalogCacheStore and HistoryStore (round trips, corrupt data), PlayThresholdCounter (the 30s / half-track rule, seeks, pauses, repeat-one) and the service's play counting, PlayStatsStore and PlayStatsProvider (round trips, ranking, distinct songs per mix, restart hydration), LibreProvider (multi-server merge, drip loading, cache ttl, failure recovery, the visible-page watcher, the two-phase search with playlist provenance), LikedStore and LikedProvider (download lifecycle, shared files between songs and mixes, unlike-while-downloading, restart recovery, the orphan sweep, clearAll), match highlighting, the row-heart undo flow, the QR payload parser, the manual add-server dialog, BeatTile, the browse grid, the home screen sections (empty and populated), the library screen, the queue (the ordering function, the service's queue bookkeeping and the sheet itself) and the settings servers + storage sections.

Not covered yet: MiniPlayer, FullPlayer and BackgroundAudioProvider (need an abstraction over just_audio's platform channels first) and the scanner screen itself (camera).

## Design language

The theme is derived entirely from the launcher icon and lives in [`lib/theme/`](lib/theme): `app_theme.dart` holds the dark (default) and light `ColorScheme`s plus every component theme, `lb_tokens.dart` a `ThemeExtension` with the brand tokens (now-playing green, brand gradient, title rule, emblem bars, warning/success, artwork placeholder) and the radius scale (8 artwork / 12 cards / 16 heroes / pill buttons). Dark mode: page `#0E0E0E`, cards `#171717` with a mint hairline outline, text in icon-mint `#EDFFF4`, greens `#1EC85C`/`#24E068`. Light mode mirrors it on mint-tinted whites; the choice (Dark / Light / System, dark default) sits in Settings → Appearance and persists.

The identity is the icon's five sound bars, expressed through the shared widgets in [`lb_brand.dart`](lib/widgets/lb_brand.dart): a gradient `BrandRule` under every screen title, `SectionHeader` (bar glyph + sentence case) for every section, a `PlayingBarsIndicator` equalizer plus a green edge bar marking the playing row (titles stay mint), the five-bar `LbEmblem` wherever the old design used Spotify's purple, and `GradientPillButton` for primary actions. Screens pull everything from `Theme.of(context)` — no hardcoded hex outside `theme/`. Subtitles app-wide show the owning beatmix (`Beat.mixTitle`, artist fallback). Artwork falls back to a two-color gradient palette when images are unavailable. Navigation is a five-tab `NavigationBar` (Home, Search, Library, Liked, Settings) with a gradient underline on the active tab, over an `IndexedStack`, so each tab keeps its scroll position.
