import 'package:liberated_beats/data/base_repository.dart';
import 'package:liberated_beats/main.dart';
import 'package:liberated_beats/models/beat_models.dart';

/// Single point of access to the Beat catalog.
class BeatRepository extends BaseRepository {
    Future<List<Beat>> findByTitle(String query) async {
    final rows = await client!.schema('librebeats').from('beat').select('id, title, artist, thumbnailurl, streamingurl, rawbeat!beat_rawbeatid_fkey (duration)').ilike("title", "%$query%");
    PrintLog('Found beats: ${rows.length} for that contains "$query"');
    return rows.map(_beatFromRow).toList();
  }

  // ---------------------------------------------------------------------------
  Beat _beatFromRow(Map<String, dynamic> row) => Beat(
        id:  int.parse(row['id'].toString()),
        title: row['title'] as String,
        artist: row['artist'] as String,
        album: row['thumbnailurl'] as String? ?? '',
        duration: Duration(seconds: row['rawbeat']['duration'] ?? 0),
        color: sampleTracks.first.color,
        audioUrl: row['streamingurl'] as String?,
      );
  // ---------------------------------------------------------------------------
}