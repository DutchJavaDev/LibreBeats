import 'package:flutter/material.dart';

/// A single song. All artwork is rendered as [color] with the title's first
/// letter drawn on top — there are no image assets in this prototype.
class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final Gradient color;

  /// Human-readable date string (e.g. `Jun 1, 2026`). Not shown in the UI yet.
  final String? addedDate;

  /// Reserved for a real audio source; never set in sample data, never read.
  final String? audioUrl;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.color,
    this.addedDate,
    this.audioUrl,
  });
}

class Album {
  final String id;
  final String title;
  final String artist;
  final int year;
  final Gradient color;

  const Album({
    required this.id,
    required this.title,
    required this.artist,
    required this.year,
    required this.color,
  });
}

class Playlist {
  final String id;
  final String name;
  final String owner;
  final int trackCount;

  const Playlist({
    required this.id,
    required this.name,
    required this.owner,
    required this.trackCount,
  });
}

// ---------------------------------------------------------------------------
// Gradient palette — eight shared two-colour gradients, all top-left → bottom-right.
// ---------------------------------------------------------------------------

const LinearGradient _g0 = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF1DB954), Color(0xFF158A3E)], // Green
);
const LinearGradient _g1 = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFE91429), Color(0xFFA00C1C)], // Red
);
const LinearGradient _g2 = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF509BF5), Color(0xFF2D6EC7)], // Blue
);
const LinearGradient _g3 = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFF6437), Color(0xFFC73D1B)], // Orange
);
const LinearGradient _g4 = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFAF2896), Color(0xFF7A1C6A)], // Magenta
);
const LinearGradient _g5 = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFE8C32E), Color(0xFFB89118)], // Gold
);
const LinearGradient _g6 = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF148A08), Color(0xFF0A5204)], // Dark green
);
const LinearGradient _g7 = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFBC5900), Color(0xFF8A4000)], // Amber/brown
);

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

const List<Track> sampleTracks = [
  Track(
    id: 't1',
    title: 'Resonance',
    artist: 'Home',
    album: 'Odyssey',
    duration: Duration(seconds: 218),
    color: _g0,
    addedDate: 'Jun 1, 2026',
  ),
  Track(
    id: 't2',
    title: 'Midnight City',
    artist: 'M83',
    album: "Hurry Up, We're Dreaming",
    duration: Duration(seconds: 243),
    color: _g1,
    addedDate: 'May 28, 2026',
  ),
  Track(
    id: 't3',
    title: 'Let It Happen',
    artist: 'Tame Impala',
    album: 'Currents',
    duration: Duration(seconds: 467),
    color: _g2,
    addedDate: 'May 20, 2026',
  ),
  Track(
    id: 't4',
    title: 'Electric Feel',
    artist: 'MGMT',
    album: 'Oracular Spectacular',
    duration: Duration(seconds: 231),
    color: _g3,
    addedDate: 'May 15, 2026',
  ),
  Track(
    id: 't5',
    title: 'Crystalised',
    artist: 'The xx',
    album: 'xx',
    duration: Duration(seconds: 214),
    color: _g4,
    addedDate: 'May 10, 2026',
  ),
  Track(
    id: 't6',
    title: 'Do I Wanna Know?',
    artist: 'Arctic Monkeys',
    album: 'AM',
    duration: Duration(seconds: 272),
    color: _g5,
    addedDate: 'May 5, 2026',
  ),
  Track(
    id: 't7',
    title: 'Feels Like We Only Go Backwards',
    artist: 'Tame Impala',
    album: 'Lonerism',
    duration: Duration(seconds: 193),
    color: _g6,
    addedDate: 'Apr 28, 2026',
  ),
  Track(
    id: 't8',
    title: 'Heat Waves',
    artist: 'Glass Animals',
    album: 'Dreamland',
    duration: Duration(seconds: 238),
    color: _g7,
    addedDate: 'Apr 20, 2026',
  ),
];

const List<Album> sampleAlbums = [
  Album(id: 'a1', title: 'Odyssey', artist: 'Home', year: 2014, color: _g0),
  Album(id: 'a2', title: 'Currents', artist: 'Tame Impala', year: 2015, color: _g2),
  Album(id: 'a3', title: 'AM', artist: 'Arctic Monkeys', year: 2013, color: _g5),
  Album(id: 'a4', title: 'Dreamland', artist: 'Glass Animals', year: 2020, color: _g7),
  Album(id: 'a5', title: 'xx', artist: 'The xx', year: 2009, color: _g4),
  Album(id: 'a6', title: 'Lonerism', artist: 'Tame Impala', year: 2012, color: _g6),
];

const List<Playlist> samplePlaylists = [
  Playlist(id: 'pl1', name: 'Late Night Drives', owner: 'You', trackCount: 24),
  Playlist(id: 'pl2', name: 'Indie Focus', owner: 'You', trackCount: 18),
  Playlist(id: 'pl3', name: 'Chillwave Essentials', owner: 'You', trackCount: 32),
  Playlist(id: 'pl4', name: 'Workout Mix', owner: 'You', trackCount: 15),
  Playlist(id: 'pl5', name: 'Study Beats', owner: 'You', trackCount: 41),
  Playlist(id: 'pl6', name: 'Weekend Vibes', owner: 'You', trackCount: 27),
];
