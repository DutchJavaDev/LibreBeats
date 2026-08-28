import 'package:flutter/foundation.dart';
import 'package:liberated_beats/config/helpers.dart';
import 'package:liberated_beats/data/base_repository.dart';
import 'package:liberated_beats/models/beat_models.dart';

/// Single point of access to the Beat catalog.
class BeatRepository extends BaseRepository {
  BeatRepository(super.registry);

  // Live title search on the beat table of every healthy server.
  Future<List<Beat>> findByTitle(String query) async {
    final beats = <Beat>[];

    await Future.wait(registry.healthy.map((server) async {
      try {
        final rows = await server.client!
            .schema('librebeats')
            .from('beat')
            .select(
                'id, title, artist, thumbnailurl, streamingurl, rawbeat!beat_rawbeatid_fkey (duration)')
            .ilike('title', '%$query%')
            .timeout(const Duration(seconds: 10));
        beats.addAll(
            rows.map((row) => beatFromRow(row, server.url)).whereType<Beat>());
      } catch (e) {
        PrintLog('beat search failed for ${server.host}: $e');
        registry.markFailed(server);
      }
    }));

    return beats;
  }

  // ---------------------------------------------------------------------------
  // one bad row must not sink the whole result, decode what parses and skip
  // the rest
  @visibleForTesting
  static Beat? beatFromRow(dynamic row, String sourceId) {
    try {
      return Beat(
        id: int.parse(row['id'].toString()),
        sourceId: sourceId,
        title: row['title']?.toString() ?? '',
        artist: row['artist']?.toString() ?? '',
        thumbnailUrl: row['thumbnailurl']?.toString() ?? '',
        duration: Duration(seconds: embeddedDuration(row['rawbeat'])),
        color: gradientForKey('$sourceId:${row['id']}'),
        audioUrl: row['streamingurl']?.toString(),
      );
    } catch (e) {
      PrintLog('skipping malformed beat row: $e');
      return null;
    }
  }

  // PostgREST sends the rawbeat embed as a map or a one-element list
  // depending on how the relationship is spelled, accept both
  @visibleForTesting
  static int embeddedDuration(dynamic rawbeat) {
    final entry = rawbeat is List ? rawbeat.firstOrNull : rawbeat;
    return int.tryParse('${entry?['duration']}') ?? 0;
  }
  // ---------------------------------------------------------------------------
}
