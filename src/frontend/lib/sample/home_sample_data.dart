import 'package:flutter/material.dart';

import '../models/beat_models.dart';

/// Hardcoded sample data for the mocked home sections (most listened, top
/// playlists, server updates). Deliberately in its own `sample/` folder:
/// nothing in providers/ or data/ may import this, only the home screen
/// does. Every beat has `audioUrl: null`, so nothing here can ever reach
/// playback, and empty thumbnail urls keep it off the network — artwork
/// falls back to the gradients below.

class SampleRankedBeat {
  final Beat beat;
  final int plays;
  const SampleRankedBeat(this.beat, this.plays);
}

class SampleRankedMix {
  final BeatMix mix;
  final int plays;
  const SampleRankedMix(this.mix, this.plays);
}

enum SampleUpdateKind { newPlaylist, healthDigest }

class SampleServerUpdate {
  final String host;
  final String message;
  final String timeAgo;
  final SampleUpdateKind kind;

  const SampleServerUpdate({
    required this.host,
    required this.message,
    required this.timeAgo,
    required this.kind,
  });
}

// mock artwork colors, unrelated to the brand palette on purpose so the
// fake covers read as covers, not UI
const _teal = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF2A6E62), Color(0xFF1B4A42)],
);
const _indigo = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF3A4E8C), Color(0xFF27355F)],
);
const _rust = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF8C4A3A), Color(0xFF5F3227)],
);
const _plum = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF8C3A5E), Color(0xFF5F2740)],
);
const _olive = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF6E5A2A), Color(0xFF4A3D1C)],
);

const sampleMostListened = <SampleRankedBeat>[
  SampleRankedBeat(
    Beat(
      id: 9001,
      title: 'Low Tide',
      artist: 'Marlowe',
      mixTitle: 'Deep Focus',
      duration: Duration(seconds: 252),
      color: _olive,
    ),
    31,
  ),
  SampleRankedBeat(
    Beat(
      id: 9002,
      title: 'Midnight Drive',
      artist: 'Nova',
      mixTitle: 'Evening Beats',
      duration: Duration(seconds: 236),
      color: _teal,
    ),
    27,
  ),
  SampleRankedBeat(
    Beat(
      id: 9003,
      title: 'Paper Lanterns',
      artist: 'Juno Park',
      mixTitle: 'Rainy Tapes',
      duration: Duration(seconds: 168),
      color: _plum,
    ),
    19,
  ),
];

const sampleTopMixes = <SampleRankedMix>[
  SampleRankedMix(
    BeatMix(id: 9101, title: 'Deep Focus', thumbnailUrl: '', trackCount: 18, beats: []),
    42,
  ),
  SampleRankedMix(
    BeatMix(id: 9102, title: 'Evening Beats', thumbnailUrl: '', trackCount: 24, beats: []),
    28,
  ),
  SampleRankedMix(
    BeatMix(id: 9103, title: 'Morning Run', thumbnailUrl: '', trackCount: 31, beats: []),
    16,
  ),
  SampleRankedMix(
    BeatMix(id: 9104, title: 'Rainy Tapes', thumbnailUrl: '', trackCount: 12, beats: []),
    11,
  ),
];

const sampleServerUpdates = <SampleServerUpdate>[
  SampleServerUpdate(
    host: 'herman.example.com',
    message: '3 new beatmixes',
    timeAgo: '2h ago',
    kind: SampleUpdateKind.newPlaylist,
  ),
  SampleServerUpdate(
    host: 'nas.local',
    message: 'New playlist: Deep Focus',
    timeAgo: '1d ago',
    kind: SampleUpdateKind.newPlaylist,
  ),
  SampleServerUpdate(
    host: '',
    message: 'All 3 servers healthy',
    timeAgo: 'Last checked 5m ago',
    kind: SampleUpdateKind.healthDigest,
  ),
];

/// The mock cover gradients, keyed by mix id, for the top-mixes row.
const sampleMixArt = <int, LinearGradient>{
  9101: _indigo,
  9102: _rust,
  9103: _teal,
  9104: _plum,
};
