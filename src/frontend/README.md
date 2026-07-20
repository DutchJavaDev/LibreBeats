# Liberated Beats — Flutter Recreation Guide

A complete, file-by-file specification for rebuilding the **Liberated Beats** music-player app in Flutter from scratch. Everything below is derived directly from the source in `flutter/lib/`. Following this document will reproduce the app pixel-for-pixel and behaviour-for-behaviour.

> **Important context before you start.** This app is a **UI prototype with fully simulated playback**. There is no real audio engine wired up: all playback state (current track, play/pause, progress, shuffle, repeat, volume) lives in a single in-memory `ChangeNotifier`. Several audio packages are declared in `pubspec.yaml` but are **not imported or used anywhere** in the code. All "album art" is a coloured gradient with the title's first letter drawn on top — there are no image assets. Keep this in mind; the guide flags every such gap so you can recreate it exactly or extend it intentionally.

---

## 1. Project Overview

| Property | Value |
|---|---|
| App name (pubspec `name`) | `liberated_beats` |
| Display title (`MaterialApp.title`) | `Liberated Beats` |
| Description | An open source music player — Liberated Beats. |
| Version | `0.1.0+1` |
| `publish_to` | `none` (not intended for pub.dev) |
| Dart SDK constraint | `>=3.0.0 <4.0.0` (requires Dart 3 — uses records & switch expressions) |
| UI toolkit | Flutter, Material 3 (`useMaterial3: true`) |
| Theme | Dark only (`ThemeData.dark`) |
| State management | `provider` (`ChangeNotifierProvider` + `ChangeNotifier`) |
| Fonts | Google Fonts — **Plus Jakarta Sans** throughout |
| Navigation | Single `MaterialApp`, no named routes; tab switching via `IndexedStack` |
| Orientation | Locked to portrait |
| Brand/primary color | `#1ED760` (Spotify-style green) |
| Background color | `#121212` (near-black) |

The visual language is a clear homage to Spotify: dark surfaces, a green accent, rounded album tiles, a mini-player docked above a bottom navigation bar, and a draggable full-screen "now playing" sheet.

---

## 2. File Structure

The entire app lives under `flutter/`. Only `lib/` and `pubspec.yaml` exist in source — there are **no** platform folders (`android/`, `ios/`, `web/`), no `assets/` folder on disk (despite being referenced), no `analysis_options.yaml`, and no `README`. When recreating, run `flutter create .` in the project root to generate the platform scaffolding, then drop in the files below.

```
flutter/
├── pubspec.yaml                      # Package + dependency manifest
└── lib/
    ├── main.dart                     # Entry point: bindings, system chrome, runApp
    ├── app.dart                      # MaterialApp + full ThemeData definition
    ├── models/
    │   └── track.dart                # Track, Album, Playlist models + sample data + gradient palette
    ├── providers/
    │   └── player_provider.dart      # PlayerProvider (ChangeNotifier) + RepeatMode enum
    ├── screens/
    │   ├── main_scaffold.dart        # Bottom nav + IndexedStack host + MiniPlayer
    │   ├── home_screen.dart          # Greeting, quick-picks grid, albums row, track list
    │   ├── search_screen.dart        # Search field, live filtering, category grid
    │   ├── library_screen.dart       # Filter chips, Liked Songs entry, playlist list
    │   ├── liked_screen.dart         # Liked Songs hero header + track list
    │   └── settings_screen.dart      # Profile header + grouped setting cards
    └── widgets/
        ├── mini_player.dart          # Docked compact player above nav bar
        ├── full_player.dart          # Full-screen "now playing" bottom sheet
        ├── album_card.dart           # Album tile with hover play button
        └── track_tile.dart           # Reusable list row for a track
```

**Recommended build order when recreating:** `pubspec.yaml` → `models/track.dart` → `providers/player_provider.dart` → `widgets/*` → `screens/*` → `app.dart` → `main.dart`. This satisfies dependencies bottom-up (models and provider have no internal deps; widgets depend on those; screens depend on widgets; app/main tie it together).

---

## 3. Dependencies

From `pubspec.yaml`. The table marks which packages are **actually used** in the current code versus declared-but-unused scaffolding for future audio work.

| Package | Version | Purpose | Used in code? |
|---|---|---|---|
| `flutter` | sdk | Core framework | ✅ Everywhere |
| `google_fonts` | `^6.2.1` | Loads **Plus Jakarta Sans** for the global text theme and nav-bar labels | ✅ `app.dart` |
| `provider` | `^6.1.2` | State management — `ChangeNotifierProvider`, `context.watch`, `context.read` | ✅ `main.dart`, screens, players |
| `shared_preferences` | `^2.2.3` | Intended for persisting settings/likes | ❌ Not imported |
| `just_audio` | `^0.9.39` | Intended audio playback engine | ✅ imported/Everywhere |
| `audio_service` | `^0.18.15` | Intended background audio / lock-screen controls | ✅ imported/Everywhere |
| `cached_network_image` | `^3.3.1` | Intended for loading album artwork from URLs | ✅ imported/Everywhere |
| `path_provider` | `^2.1.3` | Intended for local file/download paths | ❌ Not imported |

**Dev dependencies**

| Package | Version | Purpose |
|---|---|---|
| `flutter_test` | sdk | Test framework (no tests present) |
| `flutter_lints` | `^3.0.0` | Recommended lint rule set |

**Flutter config block**

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/images/
```

> ⚠️ `assets/images/` is declared but **does not exist on disk** and no code references any image asset. To reproduce the project exactly you may create an empty `assets/images/` folder (Flutter requires referenced asset dirs to exist, or the build warns). The app renders all artwork as gradients, so no images are needed for visual parity.

To recreate `pubspec.yaml` verbatim:

```yaml
name: liberated_beats
description: An open source music player — Liberated Beats.
publish_to: none
version: 0.1.0+1

environment:
  sdk: ">=3.0.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  google_fonts: ^6.2.1
  provider: ^6.1.2
  shared_preferences: ^2.2.3
  just_audio: ^0.9.39
  audio_service: ^0.18.15
  cached_network_image: ^3.3.1
  path_provider: ^2.1.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/images/
```

---

## 4. Entry Points

### 4.1 `lib/main.dart`

The `main()` function does four things in order, then runs the app:

1. `WidgetsFlutterBinding.ensureInitialized()` — required before calling platform channels (`SystemChrome`).
2. `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])` — locks the app to upright portrait only.
3. `SystemChrome.setSystemUIOverlayStyle(...)` with:
   - `statusBarColor: Colors.transparent`
   - `statusBarIconBrightness: Brightness.light` (light icons for the dark UI)
   - `systemNavigationBarColor: Colors.black`
4. `runApp(...)` wrapping the app in a `MultiProvider`:

```dart
runApp(
  MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => PlayerProvider()),
    ],
    child: const LiberatedBeatsApp(),
  ),
);
```

A single `PlayerProvider` is created at the root and shared across the whole widget tree. `MultiProvider` is used even though there is only one provider (room for growth).

### 4.2 `lib/app.dart`

Defines `LiberatedBeatsApp`, a `StatelessWidget` returning a `MaterialApp`:

- `title: 'Liberated Beats'`
- `debugShowCheckedModeBanner: false`
- `theme: _buildTheme()`
- `home: const MainScaffold()` (no routes table — navigation is tab-based)

#### `_buildTheme()` — exact specification

Starts from `ThemeData.dark(useMaterial3: true)` and `.copyWith(...)`:

**`colorScheme` (`ColorScheme.dark`)**

| Role | Color |
|---|---|
| `primary` | `Color(0xFF1ED760)` |
| `onPrimary` | `Colors.black` |
| `secondary` | `Color(0xFF282828)` |
| `onSecondary` | `Colors.white` |
| `surface` | `Color(0xFF121212)` |
| `onSurface` | `Colors.white` |
| `surfaceContainerHighest` | `Color(0xFF282828)` |
| `outline` | `Color(0x1AFFFFFF)` (white at ~10% opacity) |

**Other theme properties**

- `scaffoldBackgroundColor: Color(0xFF121212)`
- **`navigationBarTheme`** (`NavigationBarThemeData`):
  - `backgroundColor: Colors.black`
  - `indicatorColor: Color(0xFF1ED760).withOpacity(0.18)` — translucent green pill behind the selected icon
  - `labelTextStyle`: resolves per state via `WidgetStateProperty`. Uses `GoogleFonts.plusJakartaSans`, `fontSize: 10`; selected → `FontWeight.w700` + color `#1ED760`; unselected → `FontWeight.w500` + color `#A7A7A7`.
  - `iconTheme`: resolves per state. Selected → `#1ED760`; unselected → `#A7A7A7`; `size: 24` always.
  - `surfaceTintColor: Colors.transparent`, `elevation: 0`
- **`textTheme`**: `GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(bodyColor: Colors.white, displayColor: Colors.white)` — every text style uses Plus Jakarta Sans, white.
- **`switchTheme`** (`SwitchThemeData`):
  - `thumbColor`: always `Colors.white`
  - `trackColor`: selected → `#1ED760`; unselected → `#3E3E3E`
- **`dividerTheme`**: `color: Color(0x1AFFFFFF)`, `thickness: 1`, `space: 0`

---

## 5. Models — `lib/models/track.dart`

Three immutable data classes (`const` constructors), a private gradient palette, and three top-level sample data lists.

### 5.1 `Track`

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` | ✅ | Unique key (`t1`…`t8`); used for active-track comparison |
| `title` | `String` | ✅ | Song title; first character is drawn as the "art" |
| `artist` | `String` | ✅ | Artist name |
| `album` | `String` | ✅ | Album title; matched by string in home screen |
| `duration` | `Duration` | ✅ | Track length; drives progress math & time labels |
| `color` | `Gradient` | ✅ | The track's gradient swatch (used as artwork) |
| `addedDate` | `String?` | ❌ | Human-readable date string (e.g. `Jun 1, 2026`); not shown in UI currently |
| `audioUrl` | `String?` | ❌ | Reserved for a real audio source; **never set** in sample data, never read |

### 5.2 `Album`

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` | ✅ | `a1`…`a6` |
| `title` | `String` | ✅ | Album title |
| `artist` | `String` | ✅ | Artist name |
| `year` | `int` | ✅ | Release year (shown as `year · artist`) |
| `color` | `Gradient` | ✅ | Gradient swatch for the album tile |

### 5.3 `Playlist`

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` | ✅ | `pl1`…`pl6` |
| `name` | `String` | ✅ | Playlist name |
| `owner` | `String` | ✅ | Always `'You'` in sample data |
| `trackCount` | `int` | ✅ | Song count (shown as `Playlist · N songs`) |

### 5.4 Gradient palette

Eight shared `const LinearGradient`s, each two colors, all `begin: Alignment.topLeft, end: Alignment.bottomRight`:

| Name | Start | End | Hue |
|---|---|---|---|
| `_g0` | `#1DB954` | `#158A3E` | Green |
| `_g1` | `#E91429` | `#A00C1C` | Red |
| `_g2` | `#509BF5` | `#2D6EC7` | Blue |
| `_g3` | `#FF6437` | `#C73D1B` | Orange |
| `_g4` | `#AF2896` | `#7A1C6A` | Magenta |
| `_g5` | `#E8C32E` | `#B89118` | Gold |
| `_g6` | `#148A08` | `#0A5204` | Dark green |
| `_g7` | `#BC5900` | `#8A4000` | Amber/brown |

### 5.5 `sampleTracks` (8 entries)

| id | title | artist | album | duration | gradient | addedDate |
|---|---|---|---|---|---|---|
| t1 | Resonance | Home | Odyssey | 218s (3:38) | `_g0` | Jun 1, 2026 |
| t2 | Midnight City | M83 | Hurry Up, We're Dreaming | 243s (4:03) | `_g1` | May 28, 2026 |
| t3 | Let It Happen | Tame Impala | Currents | 467s (7:47) | `_g2` | May 20, 2026 |
| t4 | Electric Feel | MGMT | Oracular Spectacular | 231s (3:51) | `_g3` | May 15, 2026 |
| t5 | Crystalised | The xx | xx | 214s (3:34) | `_g4` | May 10, 2026 |
| t6 | Do I Wanna Know? | Arctic Monkeys | AM | 272s (4:32) | `_g5` | May 5, 2026 |
| t7 | Feels Like We Only Go Backwards | Tame Impala | Lonerism | 193s (3:13) | `_g6` | Apr 28, 2026 |
| t8 | Heat Waves | Glass Animals | Dreamland | 238s (3:58) | `_g7` | Apr 20, 2026 |

(All `audioUrl` fields are left null.)

### 5.6 `sampleAlbums` (6 entries)

| id | title | artist | year | gradient |
|---|---|---|---|---|
| a1 | Odyssey | Home | 2014 | `_g0` |
| a2 | Currents | Tame Impala | 2015 | `_g2` |
| a3 | AM | Arctic Monkeys | 2013 | `_g5` |
| a4 | Dreamland | Glass Animals | 2020 | `_g7` |
| a5 | xx | The xx | 2009 | `_g4` |
| a6 | Lonerism | Tame Impala | 2012 | `_g6` |

### 5.7 `samplePlaylists` (6 entries)

| id | name | owner | trackCount |
|---|---|---|---|
| pl1 | Late Night Drives | You | 24 |
| pl2 | Indie Focus | You | 18 |
| pl3 | Chillwave Essentials | You | 32 |
| pl4 | Workout Mix | You | 15 |
| pl5 | Study Beats | You | 41 |
| pl6 | Weekend Vibes | You | 27 |

---

## 6. `PlayerProvider` — `lib/providers/player_provider.dart`

A `ChangeNotifier` holding all playback state. Defined at the bottom of the file is the enum `RepeatMode { off, all, one }`.

### 6.1 State fields & getters

| Private field | Type | Initial | Public getter | Notes |
|---|---|---|---|---|
| `_currentTrack` | `Track?` | `null` | `currentTrack` | Null when nothing has been played yet |
| `_isPlaying` | `bool` | `false` | `isPlaying` | Play/pause state |
| `_progress` | `double` | `0.0` | `progress` | Normalized 0.0–1.0 position |
| `_shuffle` | `bool` | `false` | `shuffle` | Shuffle toggle (visual only) |
| `_repeatMode` | `RepeatMode` | `RepeatMode.off` | `repeatMode` | off / all / one |
| `_volume` | `double` | `0.7` | `volume` | Normalized 0.0–1.0 |

**Computed getter `elapsed` → `Duration`:** returns `Duration.zero` if no current track, otherwise `currentTrack.duration * progress` (scales the total duration by the normalized progress). Used by the full player to show elapsed time.

### 6.2 Methods (exact behaviour)

Every mutating method calls `notifyListeners()` at the end unless noted.

- **`playTrack(Track track)`** — If the tapped track is already current (`_currentTrack?.id == track.id`), it delegates to `togglePlay()` and returns (so tapping the playing track pauses/resumes it). Otherwise sets `_currentTrack = track`, resets `_progress = 0`, sets `_isPlaying = true`, notifies.

- **`togglePlay()`** — Flips `_isPlaying`, notifies.

- **`seek(double value)`** — Sets `_progress = value.clamp(0.0, 1.0)`, notifies. Called by the full player's progress slider.

- **`nextTrack(List<Track> tracks)`** — Returns immediately if `_currentTrack == null` or `tracks.isEmpty`. Otherwise finds the current index, computes `next = (idx + 1) % tracks.length` (wraps around), sets that track, resets progress, sets playing true, notifies. **Note:** the UI currently calls this with an empty list (see §8.1/§8.2), so it is effectively a no-op until wired to a real list.

- **`prevTrack(List<Track> tracks)`** — Returns if null/empty. **If `_progress > 0.05`**, it just resets `_progress = 0` and notifies (i.e. "restart current track") rather than going back. Otherwise computes `prev = (idx - 1 + tracks.length) % tracks.length` (wraps), sets it, resets progress, plays, notifies. Same empty-list caveat as `nextTrack`.

- **`toggleShuffle()`** — Flips `_shuffle`, notifies.

- **`cycleRepeat()`** — Cycles the repeat mode with a Dart 3 switch expression in the order `off → all → one → off`. Notifies.

- **`setVolume(double v)`** — Sets `_volume = v.clamp(0.0, 1.0)`, notifies.

- **`tick(Duration delta)`** — Intended to be driven by a ticker/audio callback to advance progress. Returns if not playing or no track. Computes `totalMs = duration.inMilliseconds`; returns if zero. Advances `_progress` by `delta.inMilliseconds / totalMs`, clamped 0–1. If `_progress >= 1.0`, resets to 0 and sets `_isPlaying = false` (track "ends"). Notifies. **Note:** nothing in the current codebase ever calls `tick()` — there is no `Ticker`/`Timer` — so progress only changes when the user drags a slider. To make playback feel live, add a periodic timer that calls `tick()`.

---

## 7. Screens

All screens are reached through the bottom navigation and kept alive simultaneously via `IndexedStack` (state preserved when switching tabs). Five of six screens use a `CustomScrollView` with slivers; only the host scaffold differs.

### 7.1 `main_scaffold.dart` — `MainScaffold` (Stateful)

The app shell.

- State: `int _selectedIndex = 0`.
- `static const _screens = [HomeScreen(), SearchScreen(), LibraryScreen(), LikedScreen(), SettingsScreen()]`.
- `Scaffold`:
  - `backgroundColor: Color(0xFF121212)`
  - `body: IndexedStack(index: _selectedIndex, children: _screens)` — keeps every screen mounted; preserves scroll position and field state across tab switches.
  - `bottomNavigationBar`: a `Column(mainAxisSize: min)` stacking **`MiniPlayer`** above a Material 3 **`NavigationBar`**.
- `NavigationBar`: `selectedIndex: _selectedIndex`, `onDestinationSelected: (i) => setState(...)`, with five `NavigationDestination`s:

| Index | Label | Unselected icon | Selected icon |
|---|---|---|---|
| 0 | Home | `home_outlined` | `home` |
| 1 | Search | `search` | *(none — reuses `search`)* |
| 2 | Library | `library_music_outlined` | `library_music` |
| 3 | Liked | `favorite_border` | `favorite` |
| 4 | Settings | `settings_outlined` | `settings` |

### 7.2 `home_screen.dart` — `HomeScreen` (Stateless)

Reads `context.watch<PlayerProvider>()`. Has a `_greeting` getter: hour `< 12` → "Good morning", `< 17` → "Good afternoon", else "Good evening".

A `CustomScrollView` with these slivers in order:

1. **Header `SliverToBoxAdapter`** — a `Container` with a top-to-bottom `LinearGradient` from `#1A3A2A` → `#121212`, padded by `MediaQuery.padding.top + 16` on top (status-bar inset) plus 16 sides / 24 bottom. Inside, a left-aligned `Column`:
   - Greeting text, `fontSize: 24`, `FontWeight.w800`, white.
   - A **quick-picks `GridView.builder`**: `shrinkWrap: true`, `NeverScrollableScrollPhysics`, 2 columns, 8px spacing, `childAspectRatio: 3.5`, `itemCount: sampleTracks.length.clamp(0, 6)` (first 6 tracks). Each cell is a `Material` whose color is white at **0.2** opacity when that track is active else **0.1**, with an `InkWell` (`onTap: player.playTrack(t)`) wrapping a `Row`: a 48×48 gradient square (left corners rounded 6) showing the title's first letter, an `Expanded` title (`fontSize 12`, `w600`, max 2 lines, ellipsis), and trailing spacing.
2. **"Recently played" header** (`SliverToBoxAdapter`) — a `Row` spaced between a `Recently played` title (16/`w700`/white) and a `Show all` link (12/`w600`/`#A7A7A7`).
3. **Horizontal albums row** (`SliverToBoxAdapter`) — a `SizedBox(height: 196)` containing a horizontal `ListView.separated` (12px separators, 16px horizontal padding) over `sampleAlbums`. Each item is a 140-wide `AlbumCard`. Its `onPlay` finds the first track whose `album` equals the album's `title` (falling back to `sampleTracks[0]`) and plays it.
4. **"Liked songs" header** (`SliverToBoxAdapter`) — same Row pattern as #2.
5. **Track list `SliverList`** — a `SliverChildBuilderDelegate` over all `sampleTracks`, each a `TrackTile` with `isActive`/`isPlaying` derived from the provider and `onTap: player.playTrack(...)`.
6. **Trailing spacer** — `SliverToBoxAdapter(SizedBox(height: 16))`.

### 7.3 `search_screen.dart` — `SearchScreen` (Stateful)

Top-level `const _categories`: a list of 12 `(String, Color)` **records** (Dart 3 tuples):

| Label | Color | Label | Color |
|---|---|---|---|
| Podcasts | `#1DB954` | Indie | `#148A08` |
| Live Events | `#E91429` | Rock | `#BC5900` |
| Made For You | `#509BF5` | Pop | `#1DB954` |
| New Releases | `#FF6437` | Jazz | `#E91429` |
| Hip-Hop | `#AF2896` | Classical | `#509BF5` |
| Electronic | `#E8C32E` | R&B | `#FF6437` |

State: a `TextEditingController _controller` (disposed in `dispose()`) and `String _query`. Reads the provider. `filtered` = empty list when `_query` is empty, otherwise `sampleTracks` where the lowercased `title` **or** `artist` contains the lowercased query.

`CustomScrollView` slivers:

1. **Header** — `Search` title (24/`w800`) and a `TextField`: `onChanged` sets `_query` via `setState`; text style **black** `w500`; `InputDecoration` with hint `Artists, songs, or podcasts` (black54), a black54 `search` prefix icon, `filled` white background, 12 vertical content padding, and a borderless `OutlineInputBorder` radius 10.
2. **Conditional results:**
   - If `_query` non-empty **and** `filtered` empty → a centered `No results for "<query>"` message (`#A7A7A7`, 32px padding).
   - If `_query` non-empty **and** results exist → a `SliverList` of `TrackTile`s over `filtered`.
3. **When `_query` is empty** (spread `...[`):
   - A `Browse categories` header (16/`w700`/white).
   - A `SliverPadding` (16 horizontal) wrapping a `SliverGrid.count`: 2 columns, 12px spacing both axes, `childAspectRatio: 2.0`. Each category is a `ClipRRect` (radius 12) over a `Material` colored by the record's color, with an `InkWell` (empty `onTap`) and top-left-aligned label text (white, bold, 14).
4. **Trailing spacer** — `SizedBox(height: 16)`.

### 7.4 `library_screen.dart` — `LibraryScreen` (Stateless)

No provider usage. `CustomScrollView` slivers:

1. **Header** — `Row` between `Your Library` (24/`w800`/white) and a circular `IconButton` (`Icons.add`, white) styled with a white-`0.1` background. Top padding uses the status-bar inset.
2. **Filter chips** — a horizontal `SingleChildScrollView` of four `FilterChip`s built from `['Playlists', 'Albums', 'Artists', 'Downloaded']`. Each: `selected: false`, empty `onSelected`, `backgroundColor: #282828`, label white 12/`w600`, `RoundedRectangleBorder` radius 20, `side: BorderSide.none`, 8px right padding.
3. **Liked Songs entry** (`SliverToBoxAdapter`) — a `ListTile` with a 56×56 rounded (10) leading box using gradient `#450AF5` → `#C4EFD9` and a white `favorite` icon (24); title `Liked Songs` (white/`w600`/14); subtitle `Playlist · 847 songs` (`#A7A7A7`/12); empty `onTap`.
4. **Playlist list** (`SliverList`) over `samplePlaylists` — each a `ListTile` with a 56×56 rounded box colored `#282828` and a `queue_music` icon (`#A7A7A7`/24); title = playlist name; subtitle = `Playlist · {trackCount} songs`.
5. **Trailing spacer** — `SizedBox(height: 16)`.

### 7.5 `liked_screen.dart` — `LikedScreen` (Stateless)

Reads the provider. `CustomScrollView` slivers:

1. **Hero header** (`SliverToBoxAdapter`) — a `Container` with a top→bottom gradient `#450AF5` → `#121212`, status-bar-inset top padding. Centered `Column`:
   - A 160×160 rounded-16 box, gradient `#450AF5` → `#C4EFD9` (topLeft→bottomRight), with a drop shadow (`black` 0.5, blur 32, offset (0,16)) and a centered white `favorite` icon size 72.
   - `Liked Songs` title (22/`w800`/white), 4px gap, `847 songs` subtitle (13/`#A7A7A7`).
   - A `Row`: an `OutlinedButton.icon` "Shuffle" (white foreground, white-`0x4D` border, rounded 20, empty `onPressed`), a `Spacer`, and a green `FloatingActionButton` (`#1ED760` bg, black foreground, elevation 4, `play_arrow` 32) whose `onPressed` calls `player.playTrack(sampleTracks[0])`.
2. **Track list** (`SliverList`) of `TrackTile`s over all `sampleTracks`, wired to the provider like elsewhere.
3. **Trailing spacer** — `SizedBox(height: 16)`.

### 7.6 `settings_screen.dart` — `SettingsScreen` (Stateful)

Holds eight independent toggle booleans:

| Field | Default |
|---|---|
| `_normalizeVolume` | `true` |
| `_gaplessPlayback` | `true` |
| `_wifiOnly` | `true` |
| `_newReleases` | `true` |
| `_playlistUpdates` | `false` |
| `_darkMode` | `true` |
| `_mobileData` | `true` |
| `_privateSession` | `false` |

Three private builder helpers:

- **`_sectionHeader(title)`** — uppercased label, `fontSize 11`, `w700`, `letterSpacing 1.2`, color `#1ED760`, padded `16,20,16,6`.
- **`_settingToggle({icon, label, subtitle?, value, onChanged})`** — a `ListTile` with a 38×38 circular `#282828` leading box holding the icon (18, `#A7A7A7`), title (14/`w500`/white), optional subtitle (12/`#A7A7A7`), and a trailing `Switch`.
- **`_settingNav({icon, label, value})`** — same leading box; title + `value` subtitle; trailing `chevron_right` (`#A7A7A7`); empty `onTap`.
- **`_card(children)`** — a `Container` (horizontal margin 12, color `#181818`, radius 16) wrapping a `Column`. It interleaves a `Divider` (`indent: 70`, `height: 1`, color `#1AFFFFFF`) between every child except after the last, using an `expand`/`sync*` generator.

The `CustomScrollView` then lays out:

1. **Profile header** — gradient `#1A1A2E` → `#121212` container; a 60×60 circular gradient avatar (`#1DB954`→`#158A3E`) showing `L`; `libre_user` (18/bold/white) and `Free plan · local library` (13/`#A7A7A7`).
2. **AUDIO** card: Normalize volume (toggle, subtitle "Keep volume consistent across tracks"), Audio quality (nav → "Very high (320 kbps)"), Gapless playback (toggle, "Play tracks without silence"), Equalizer (nav → "Flat (default)").
3. **DOWNLOADS** card: Download over Wi-Fi only (toggle), Download quality (nav → "High (160 kbps)"), Storage location (nav → "/sdcard/Music/LiberatedBeats").
4. **NOTIFICATIONS** card: New releases (toggle, "Artists you follow"), Playlist updates (toggle, "Collaborative playlists").
5. **DISPLAY** card: Dark mode (toggle), Language (nav → "English (US)").
6. **PRIVACY & NETWORK** card: Stream over mobile data (toggle), Private session (toggle, "Your listening won't update history"), Privacy policy (nav → "View our data practices").
7. **ABOUT** card: Version (nav → "Liberated Beats 0.1.0 (open source)"), Licenses (nav → "Third-party open source licenses").
8. **Log out** — a standalone `#181818` rounded-16 card with a 38×38 circular leading box tinted `#26E8453C` (red at ~15%), a red `logout` icon and red `Log out` label (both `#E8453C`); empty `onTap`.
9. **Trailing spacer** — `SizedBox(height: 16)`.

Each `Switch`'s `onChanged` flips its field via `setState`. None of these settings are persisted (no `shared_preferences` usage).

---

## 8. Widgets

### 8.1 `mini_player.dart` — `MiniPlayer` (Stateless)

Reads `context.watch<PlayerProvider>()`. If `currentTrack == null`, returns `SizedBox.shrink()` (the player is invisible until something plays). Otherwise:

- A `GestureDetector` whose `onTap` opens the full player via `showModalBottomSheet`: `isScrollControlled: true`, `backgroundColor: Colors.transparent`, and a builder returning `ChangeNotifierProvider.value(value: player, child: const FullPlayer())` so the sheet shares the same provider instance.
- The body is a `Container` (`#1A1A1A`, radius 12, margin h8/v4) with a `Column(min)`:
  - A `LinearProgressIndicator` clipped to the top corners (radius 12), `value: player.progress`, background white-`0.15`, value color `#1ED760`, `minHeight: 3`.
  - A padded `Row`: a 42×42 gradient art square with the title's first letter; an `Expanded` `Column` with title (13/`w600`/white, ellipsis) and artist (12/`#A7A7A7`, ellipsis); a play/pause `IconButton` (`player.togglePlay`, size 26, compact); and a `skip_next` `IconButton`.

> ⚠️ **Known quirk to reproduce faithfully:** the `skip_next` button's `onPressed` is `() => player.nextTrack(<expression that always yields []>)`. The argument is a convoluted ternary (`player.currentTrack != null ? context.read<PlayerProvider>() == player ? [] : [] : []`) that evaluates to an empty list in all cases, so `nextTrack` returns immediately and skipping does nothing. To make it work, pass a real track list (e.g. `sampleTracks`).

### 8.2 `full_player.dart` — `FullPlayer` (Stateful)

The full-screen "now playing" sheet, opened from the mini player. Local state: `bool _liked = false`. A `_format(Duration)` helper renders `m:ss` where minutes are `inMinutes.remainder(60)`.

Reads the provider; if `currentTrack == null` returns `SizedBox.shrink()`. Returns a `DraggableScrollableSheet` (`initialChildSize: 1.0`, `minChildSize: 0.5`, `maxChildSize: 1.0`) whose child is a `Container` (`#121212`, top corners rounded 20) holding a `Stack`:

- **Color wash** — `Positioned.fill` with `Opacity(0.3)` over a container filled with the track's gradient (top corners rounded 20). Gives each track a tinted backdrop.
- **Content** — `SafeArea` → `Padding(horizontal: 24)` → `Column`:
  1. A 40×4 rounded grabber handle (white-`0.3`).
  2. **Header `Row`**: a `keyboard_arrow_down` close button (`Navigator.pop`); a center `Column` with `Playing from` (11, white-`0.6`) over the album name (13/`w700`/white); a `more_horiz` button (empty).
  3. **Artwork** — an `AnimatedScale` (`scale: isPlaying ? 1.0 : 0.92`, 400ms, `Curves.easeOutBack`) around a full-width 280-tall gradient box (radius 16, heavy shadow) with the title's first letter at `fontSize 100`, `w900`, white. The art subtly shrinks when paused.
  4. **Title + like `Row`**: an `Expanded` `Column` with title (22/`w800`, ellipsis) and artist (14/`#A7A7A7`); a like `IconButton` toggling `_liked` (`favorite`/`favorite_border`), green `#1ED760` when liked else `#A7A7A7`.
  5. **Progress `Slider`** — wrapped in a `SliderTheme`: active track white, inactive white-`0.2`, white thumb (radius 6), overlay radius 14, `trackHeight: 3`. `value: player.progress`, `onChanged: player.seek`.
  6. **Time row** — elapsed (`_format(player.elapsed)`) and total (`_format(track.duration)`), both 12/`#A7A7A7`.
  7. **Transport controls `Row`** (spaceBetween): shuffle (`player.toggleShuffle`, green when on); `skip_previous` (size 40, calls `player.prevTrack([])`); a 64×64 white circular play/pause button (`player.togglePlay`, black icon 34); `skip_next` (size 40, `player.nextTrack([])`); repeat (`player.cycleRepeat`, icon is `repeat_one` when mode is `one` else `repeat`, colored green when mode ≠ off).
  8. **Volume `Row`** — a `volume_down` icon, an `Expanded` themed `Slider` (`value: player.volume`, `onChanged: player.setVolume`, white track/thumb radius 5), a `volume_up` icon.
  9. **Bottom row** (spaceEvenly): two `TextButton.icon`s — "Share" (`share_outlined`) and "Queue" (`queue_music_outlined`), both `#A7A7A7`, empty handlers.

> ⚠️ Same quirk as the mini player: `prevTrack([])` and `nextTrack([])` are called with empty lists, so skip controls are inert. The like state is local to the sheet and resets each time it reopens.

### 8.3 `album_card.dart` — `AlbumCard` (Stateful)

Props: `final Album album`, `final VoidCallback onPlay`. State has an unused `bool _hovered = false` (intended for desktop/web hover but never read).

A `GestureDetector` (`onTap: widget.onPlay`) over a `Container` (`#181818`, radius 10, padding 12) with a left-aligned `Column`:

- A `Stack`:
  - An `AspectRatio(1)` gradient square (radius 8, shadow black-`0.4` blur 12 offset (0,6)) centered on the title's first letter (`w900`, 36, white).
  - A `Positioned` (bottom 6, right 6) green play button: a `Material` (`#1ED760`, `CircleBorder`, elevation 4) with an `InkWell` (`onTap: widget.onPlay`) wrapping a 36×36 `play_arrow` (black, 22).
- 8px gap, the album title (13/`w700`/white, 1 line, ellipsis), 2px gap, and `{year} · {artist}` (11/`#A7A7A7`, 1 line, ellipsis).

### 8.4 `track_tile.dart` — `TrackTile` (Stateless)

Props: `final Track track`, `final bool isActive`, `final bool isPlaying`, `final VoidCallback onTap`. A `_format(Duration)` helper returns `m:ss` where minutes are `d.inMinutes` (total minutes, **not** `remainder`) and seconds are `inSeconds.remainder(60)` zero-padded.

A `ListTile` (`onTap: onTap`, padding h16/v4):

- **Leading** `Stack`: a 48×48 gradient square (radius 8) with the title's first letter (bold, white). If `isActive`, a `Positioned.fill` black-`0.45` overlay (radius 8) shows a centered `pause`/`play_arrow` icon (white, 22) depending on `isPlaying`.
- **Title**: track title, 14/`w600`, colored `#1ED760` when active else white, 1 line, ellipsis.
- **Subtitle**: artist, 12/`#A7A7A7`, ellipsis.
- **Trailing** `Row(min)`: the formatted duration (13/`#A7A7A7`), 4px gap, a `more_vert` icon (`#A7A7A7`, 18).

---

## 9. Design Tokens

Every color used in the app, with hex (and ARGB where opacity matters) and where it appears.

### 9.1 Core palette

| Token | Hex / ARGB | Usage |
|---|---|---|
| Brand green | `#1ED760` | Primary accent: active nav, active track title, play buttons, FAB, sliders' "on" states, section headers, switches-on |
| Background | `#121212` | App/scaffold background, surface, full-player background, gradient end-stops |
| Surface raised | `#282828` | Secondary color; chip backgrounds, settings icon circles, playlist tiles |
| Card surface | `#181818` | Album cards, settings cards, log-out card |
| Mini-player surface | `#1A1A1A` | Mini-player container |
| Secondary text | `#A7A7A7` | Subtitles, inactive icons/labels, "Show all" links, hints helpers |
| Switch track off | `#3E3E3E` | Unselected `Switch` track |
| Pure black | `#000000` | System nav bar, `onPrimary`, nav-bar bg, play-icon-on-green |
| Pure white | `#FFFFFF` | Primary text, active icons in some places, slider tracks/thumbs |
| Danger red | `#E8453C` | Log-out icon & label |

### 9.2 Opacity-based tokens (white over dark)

| ARGB | Approx. | Usage |
|---|---|---|
| `0x1AFFFFFF` | white 10% | `outline`, dividers |
| `0x4DFFFFFF` | white 30% | "Shuffle" outlined-button border, full-player handle |
| white `withOpacity(0.1)` | 10% | Home quick-pick (inactive), Library add-button bg |
| white `withOpacity(0.15)` | 15% | Mini-player progress track bg |
| white `withOpacity(0.2)` | 20% | Home quick-pick (active), full-player slider inactive track |
| white `withOpacity(0.45)` | 45% | Active track-tile art overlay |
| `Color(0xFF1ED760).withOpacity(0.18)` | green 18% | Nav-bar selection indicator |
| `0x26E8453C` | red ~15% | Log-out icon circle background |

### 9.3 Gradients

| Gradient | Stops | Direction | Where |
|---|---|---|---|
| Track/Album `_g0` | `#1DB954` → `#158A3E` | TL→BR | t1 / a1, settings avatar |
| `_g1` | `#E91429` → `#A00C1C` | TL→BR | t2 |
| `_g2` | `#509BF5` → `#2D6EC7` | TL→BR | t3 / a2 |
| `_g3` | `#FF6437` → `#C73D1B` | TL→BR | t4 |
| `_g4` | `#AF2896` → `#7A1C6A` | TL→BR | t5 / a5 |
| `_g5` | `#E8C32E` → `#B89118` | TL→BR | t6 / a3 |
| `_g6` | `#148A08` → `#0A5204` | TL→BR | t7 / a6 |
| `_g7` | `#BC5900` → `#8A4000` | TL→BR | t8 / a4 |
| Home header | `#1A3A2A` → `#121212` | top→bottom | Home greeting backdrop |
| Liked hero | `#450AF5` → `#121212` | top→bottom | Liked screen header |
| Liked art | `#450AF5` → `#C4EFD9` | TL→BR | Liked Songs art (library tile + liked hero) |
| Settings header | `#1A1A2E` → `#121212` | top→bottom | Settings profile backdrop |

### 9.4 Typography

- Font family: **Plus Jakarta Sans** (via `google_fonts`), applied globally through `textTheme` and explicitly on nav-bar labels.
- Notable sizes/weights: screen titles **24 / w800**; section titles **16 / w700**; settings section headers **11 / w700 / letterSpacing 1.2**; track/list titles **14 / w600**; subtitles & metadata **11–13**; nav-bar labels **10**; full-player title **22 / w800**; album-art letter **36 / w900** (card) and **100 / w900** (full player).

### 9.5 Shape & spacing conventions

- Corner radii: small art 6–8, cards/tiles 10–12, hero art & full-player top 16–20.
- Standard horizontal page padding: 16 (24 inside the full player).
- Status-bar inset handled per-screen with `MediaQuery.of(context).padding.top + 16` on header containers.
- Material 3 components (`NavigationBar`, `FilterChip`, `Switch`, `Slider`) themed centrally in `app.dart`.

---

## 10. Recreation Checklist & Notes

To rebuild from zero:

1. `flutter create liberated_beats`, then replace `pubspec.yaml` with §3 and run `flutter pub get`.
2. Create `assets/images/` (empty) so the declared asset path resolves.
3. Add files in the order given in §2 (models → provider → widgets → screens → app → main).
4. Use Material 3 and the exact `ColorScheme`/themes from §4.2.
5. Reproduce the sample data tables in §5 exactly (ids matter — active-track logic compares `id`).

**Behavioural gaps to decide on (faithful copy vs. real app):**

- **No real audio.** `just_audio`/`audio_service` are unused. To play sound, instantiate an audio player, set `audioUrl`, and drive `PlayerProvider` from its position stream (calling `tick()` or setting `_progress` directly).
- **Progress is static.** `tick()` is never invoked. Add a `Timer.periodic` (e.g. every 200ms) calling `player.tick(...)` while playing to animate the bars.
- **Skip buttons are inert.** `nextTrack`/`prevTrack` receive empty lists in both players (the mini player's argument is dead-code that always yields `[]`). Pass `sampleTracks` (or the active queue) to enable skipping.
- **Nothing persists.** Settings toggles, likes, and volume reset on restart. Wire `shared_preferences` if persistence is desired.
- **No artwork.** All art is gradient + first letter. Integrate `cached_network_image` against `audioUrl`/an artwork URL for real covers.
- **Static counts.** "847 songs" and playlist counts are hardcoded sample values.

Reproducing the file exactly will give you a polished, navigable, Spotify-like front end; the list above is what stands between it and a functioning player.
```
