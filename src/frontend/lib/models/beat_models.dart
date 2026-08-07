import 'package:flutter/material.dart';

/// A single song. Artwork falls back to [color] when [thumbnailUrl] is
/// missing or not a real url.
class Beat {
  final int id;

  // which server this came from, ids are only unique per server so use [key]
  final String sourceId;

  final String title;
  final String artist;
  final String thumbnailUrl;
  final Duration duration;
  final Gradient color;

  /// Streaming url, null for sample data (which can not be played).
  final String? audioUrl;

  const Beat({
    required this.id,
    this.sourceId = 'sample',
    required this.title,
    required this.artist,
    this.thumbnailUrl = '',
    required this.duration,
    required this.color,
    this.audioUrl,
  });

  String get key => '$sourceId:$id';

  bool get isPlayable => audioUrl != null && audioUrl!.isNotEmpty;
}

class BeatMix {
  final int id;

  // which server this came from, ids are only unique per server so use [key]
  final String sourceId;

  final String title;
  final String thumbnailUrl;
  final int trackCount;
  final List<Beat>? beats;

  const BeatMix({
    required this.id,
    this.sourceId = 'sample',
    required this.title,
    required this.thumbnailUrl,
    required this.trackCount,
    required this.beats,
  });

  String get key => '$sourceId:$id';
}

class SearchResult {
  final Beat? beat;
  final BeatMix? beatMix;

  SearchResult({this.beat, this.beatMix});
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

const List<Beat> sampleTracks = [
  Beat(
    id: 1,
    title: 'Resonance',
    artist: 'Home',
    duration: Duration(seconds: 218),
    color: _g0,
  ),
  Beat(
    id: 2,
    title: 'Midnight City',
    artist: 'M83',
    duration: Duration(seconds: 243),
    color: _g1,
  ),
  Beat(
    id: 3,
    title: 'Let It Happen',
    artist: 'Tame Impala',
    duration: Duration(seconds: 467),
    color: _g2,
  ),
  Beat(
    id: 4,
    title: 'Electric Feel',
    artist: 'MGMT',
    duration: Duration(seconds: 231),
    color: _g3,
  ),
  Beat(
    id: 5,
    title: 'Crystalised',
    artist: 'The xx',
    duration: Duration(seconds: 214),
    color: _g4,
  ),
  Beat(
    id: 6,
    title: 'Do I Wanna Know?',
    artist: 'Arctic Monkeys',
    duration: Duration(seconds: 272),
    color: _g5,
  ),
  Beat(
    id: 7,
    title: 'Feels Like We Only Go Backwards',
    artist: 'Tame Impala',
    duration: Duration(seconds: 193),
    color: _g6,
  ),
  Beat(
    id: 8,
    title: 'Heat Waves',
    artist: 'Glass Animals',
    duration: Duration(seconds: 238),
    color: _g7,
  ),
];

const List<BeatMix> samplePlaylists = [
  BeatMix(id: 1, title: 'Late Night Drives', thumbnailUrl: "https://picsum.photos/200/300", trackCount: 24, beats: []),
  BeatMix(id: 2, title: 'Indie Focus', thumbnailUrl: "https://picsum.photos/200/300", trackCount: 18, beats: []),
  BeatMix(id: 3, title: 'Chillwave Essentials', thumbnailUrl: "https://picsum.photos/200/300", trackCount: 32, beats: []),
  BeatMix(id: 4, title: 'Workout Mix', thumbnailUrl: "https://picsum.photos/200/300", trackCount: 15, beats: []),
  BeatMix(id: 5, title: 'Study Beats', thumbnailUrl: "https://picsum.photos/200/300", trackCount: 41, beats: []),
  BeatMix(id: 6, title: 'Weekend Vibes', thumbnailUrl: "https://picsum.photos/200/300", trackCount: 27, beats: []),
];
