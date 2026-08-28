import 'package:flutter/foundation.dart';
import 'package:liberated_beats/config/helpers.dart';
import 'package:liberated_beats/data/base_repository.dart';
import 'package:liberated_beats/data/server_registry.dart';

import '../models/beat_models.dart';

/// Single point of access to the BeatMix catalog.
class BeatMixRepository extends BaseRepository {
  BeatMixRepository(super.registry);

  // Live title search on the beatmix table of every healthy server, beats
  // embedded so the results can play right away. Same shape the menu
  // function queries, the cache is not touched.
  Future<List<BeatMix>> findByTitle(String query) async {
    final mixes = <BeatMix>[];

    await Future.wait(registry.healthy.map((server) async {
      try {
        final rows = await server.client!
            .schema('librebeats')
            .from('beatmix')
            .select(
                'id, title, thumbnailurl, beatmixbeat (beat:beat (id, title, artist, thumbnailurl, streamingurl, rawbeat:rawbeat!beat_rawbeatid_fkey (duration)))')
            .ilike('title', '%$query%')
            .timeout(const Duration(seconds: 10));
        mixes.addAll(rows
            .map((row) => beatMixFromRow(row, server.url))
            .whereType<BeatMix>());
      } catch (e) {
        PrintLog('beatmix search failed for ${server.host}: $e');
        registry.markFailed(server);
      }
    }));

    return mixes;
  }

  // Fetch all mixes from one server via the menu edge function,
  // throws on failure so the caller can mark the server as failed
  Future<List<BeatMix>> fetchMenuFromServer(ServerConnection server) async {
    final response = await server.client!.functions
        .invoke('menu')
        .timeout(const Duration(seconds: 10));

    if (response.status != 200) {
      throw Exception('menu returned ${response.status} from ${server.host}');
    }

    return beatMixesFromMenu(response.data, server.url);
  }

  // ---------------------------------------------------------------------------
  // 200 with a body the app cannot use is the server talking nonsense, not
  // the server being down: decode what is there instead of failing the server
  @visibleForTesting
  static List<BeatMix> beatMixesFromMenu(dynamic body, String sourceId) {
    final data = body is Map ? body['data'] : null;
    if (data is! List) {
      PrintLog('menu payload had no data list');
      return const [];
    }
    return data
        .map((mix) => beatMixFromJson(mix, sourceId))
        .whereType<BeatMix>()
        .toList();
  }

  // one bad row must not sink the whole result, decode what parses and skip
  // the rest
  @visibleForTesting
  static BeatMix? beatMixFromRow(dynamic row, String sourceId) {
    try {
      final mixTitle = row['title']?.toString() ?? '';
      final beats = ((row['beatmixbeat'] as List<dynamic>?) ?? [])
          .map((junction) => junction['beat'])
          .whereType<Map<String, dynamic>>()
          .map<Beat?>((b) {
            try {
              // the rawbeat embed comes as a map or a one-element list
              // depending on how the relationship is spelled, accept both
              final rawbeat = b['rawbeat'];
              final embed = rawbeat is List ? rawbeat.firstOrNull : rawbeat;
              return Beat(
                id: int.parse(b['id'].toString()),
                sourceId: sourceId,
                title: b['title']?.toString() ?? '',
                artist: b['artist']?.toString() ?? '',
                thumbnailUrl: b['thumbnailurl']?.toString() ?? '',
                duration: Duration(
                    seconds: int.tryParse('${embed?['duration']}') ?? 0),
                color: gradientForKey('$sourceId:${b['id']}'),
                audioUrl: b['streamingurl']?.toString(),
                mixTitle: mixTitle,
              );
            } catch (e) {
              PrintLog('skipping malformed beat row: $e');
              return null;
            }
          })
          .whereType<Beat>()
          .toList();

      return BeatMix(
        id: int.parse(row['id'].toString()),
        sourceId: sourceId,
        title: mixTitle,
        thumbnailUrl: row['thumbnailurl']?.toString() ?? '',
        trackCount: beats.length,
        beats: beats,
      );
    } catch (e) {
      PrintLog('skipping malformed beatmix row: $e');
      return null;
    }
  }

  @visibleForTesting
  static BeatMix? beatMixFromJson(dynamic json, String sourceId) {
    try {
      final mixTitle = json['title']?.toString() ?? '';
      final beats = ((json['beats'] as List<dynamic>?) ?? [])
          .map((beat) => beatFromJson(beat, sourceId, mixTitle))
          .whereType<Beat>()
          .toList();

      return BeatMix(
        id: int.parse(json['id'].toString()),
        sourceId: sourceId,
        title: mixTitle,
        thumbnailUrl: json['thumbnailurl']?.toString() ?? '',
        trackCount: int.tryParse('${json['count']}') ?? beats.length,
        beats: beats,
      );
    } catch (e) {
      PrintLog('skipping malformed beatmix row: $e');
      return null;
    }
  }

  @visibleForTesting
  static Beat? beatFromJson(dynamic json, String sourceId, String mixTitle) {
    try {
      return Beat(
        id: int.parse(json['id'].toString()),
        sourceId: sourceId,
        title: json['title']?.toString() ?? '',
        artist: json['artist']?.toString() ?? '',
        thumbnailUrl: json['thumbnailurl']?.toString() ?? '',
        duration: Duration(seconds: int.tryParse('${json['duration']}') ?? 0),
        color: gradientForKey('$sourceId:${json['id']}'),
        audioUrl: json['streamingurl']?.toString(),
        mixTitle: mixTitle,
      );
    } catch (e) {
      PrintLog('skipping malformed beat row: $e');
      return null;
    }
  }
  // ---------------------------------------------------------------------------
}
