import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/beat_models.dart';

/// Saves the play history (last 10 played beats, newest first) to
/// shared_preferences so it survives an app restart.
class HistoryStore {
  static const _historyKey = 'librebeats_play_history';

  Future<List<Beat>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return [];

    try {
      final json = jsonDecode(raw) as List<dynamic>;
      return [for (final b in json) _beatFromJson(b)];
    } catch (_) {
      return []; // corrupt history, just start over
    }
  }

  Future<void> save(List<Beat> beats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _historyKey, jsonEncode([for (final b in beats) _beatToJson(b)]));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  // same field names as the catalog cache, plus the source server
  Map<String, dynamic> _beatToJson(Beat b) => {
        'id': b.id,
        'sourceid': b.sourceId,
        'title': b.title,
        'artist': b.artist,
        'thumbnailurl': b.thumbnailUrl,
        'streamingurl': b.audioUrl,
        'duration': b.duration.inSeconds,
        'mixtitle': b.mixTitle,
      };

  Beat _beatFromJson(dynamic json) => Beat(
        id: json['id'] as int,
        sourceId: json['sourceid'] as String? ?? 'sample',
        title: json['title'] as String,
        artist: json['artist'] as String? ?? '',
        thumbnailUrl: json['thumbnailurl'] as String? ?? '',
        duration: Duration(seconds: json['duration'] as int? ?? 0),
        color: sampleTracks.first.color,
        audioUrl: json['streamingurl'] as String?,
        // entries saved before the subtitle rule have no mix title
        mixTitle: json['mixtitle'] as String?,
      );
}
