import 'package:liberated_beats/data/base_repository.dart';
import 'package:liberated_beats/models/beat_models.dart';

/// Single point of access to the Beat catalog.
class BeatRepository extends BaseRepository {
  BeatRepository(super.registry);

  Future<List<Beat>> findByTitle(String query) async {
    final beats = <Beat>[];

    // Live beat search — currently disabled (returns no rows). When enabled it
    // should sweep every healthy server and tag results with the server URL:
    // for (final server in registry.healthy) {
    //   try {
    //     final rows = await server.client!
    //         .schema('librebeats')
    //         .from('beat')
    //         .select(
    //             'id, title, artist, thumbnailurl, streamingurl, rawbeat!beat_rawbeatid_fkey (duration)')
    //         .ilike('title', '%$query%');
    //     beats.addAll(rows.map((row) => _beatFromRow(row, server.url)));
    //   } catch (_) {
    //     registry.markFailed(server);
    //   }
    // }

    return beats;
  }

  // ---------------------------------------------------------------------------
  // Used by the (currently disabled) live query above.
  // ignore: unused_element
  Beat _beatFromRow(Map<String, dynamic> row, String sourceId) => Beat(
        id: int.parse(row['id'].toString()),
        sourceId: sourceId,
        title: row['title'] as String,
        artist: row['artist'] as String,
        album: row['thumbnailurl'] as String? ?? '',
        duration: Duration(seconds: row['rawbeat']['duration'] ?? 0),
        color: sampleTracks.first.color,
        audioUrl: row['streamingurl'] as String?,
      );
  // ---------------------------------------------------------------------------
}
