import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/beat_models.dart';

class CachedServerCatalog {
  CachedServerCatalog({required this.fetchedAt, required this.mixes});

  final DateTime fetchedAt;
  final List<BeatMix> mixes;
}

/// Saves the per server results + fetch time to shared_preferences so the
/// 20 minute cache survives an app restart (persistent mode).
class CatalogCacheStore {
  static const _cacheKey = 'librebeats_catalog_cache';
  static const _modeKey = 'librebeats_cache_persistent';

  Future<bool> loadPersistentMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_modeKey) ?? true;
  }

  Future<void> savePersistentMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_modeKey, value);
  }

  Future<Map<String, CachedServerCatalog>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return {};

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return json
          .map((url, entry) => MapEntry(url, _entryFromJson(url, entry)));
    } catch (_) {
      return {}; // corrupt cache, just start over
    }
  }

  Future<void> save(Map<String, CachedServerCatalog> cache) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _cacheKey,
        jsonEncode(cache.map((url, e) => MapEntry(url, {
              'fetchedAt': e.fetchedAt.toIso8601String(),
              'mixes': [for (final m in e.mixes) _mixToJson(m)],
            }))));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }

  // ---------------------------------------------------------------------------
  CachedServerCatalog _entryFromJson(String url, dynamic entry) =>
      CachedServerCatalog(
        fetchedAt: DateTime.parse(entry['fetchedAt'] as String),
        mixes: [
          for (final m in entry['mixes'] as List<dynamic>) _mixFromJson(url, m)
        ],
      );

  Map<String, dynamic> _mixToJson(BeatMix m) => {
        'id': m.id,
        'title': m.title,
        'thumbnailurl': m.thumbnailUrl,
        'trackcount': m.trackCount,
        'beats': [
          for (final b in m.beats ?? const <Beat>[])
            {
              'id': b.id,
              'title': b.title,
              'artist': b.artist,
              'thumbnailurl': b.thumbnailUrl,
              'streamingurl': b.audioUrl,
              'duration': b.duration.inSeconds,
            }
        ],
      };

  BeatMix _mixFromJson(String sourceId, dynamic json) => BeatMix(
        id: json['id'] as int,
        sourceId: sourceId,
        title: json['title'] as String,
        thumbnailUrl: json['thumbnailurl'] as String? ?? '',
        trackCount: json['trackcount'] as int? ?? 0,
        beats: [
          for (final b in json['beats'] as List<dynamic>)
            Beat(
              id: b['id'] as int,
              sourceId: sourceId,
              title: b['title'] as String,
              artist: b['artist'] as String? ?? '',
              thumbnailUrl: b['thumbnailurl'] as String? ?? '',
              duration: Duration(seconds: b['duration'] as int? ?? 0),
              color: sampleTracks.first.color,
              audioUrl: b['streamingurl'] as String?,
            )
        ],
      );
  // ---------------------------------------------------------------------------
}
