import 'package:liberated_beats/data/base_repository.dart';
import 'package:liberated_beats/main.dart';
import '../models/beat_models.dart';

/// Single point of access to the BeatMix catalog.
class BeatMixRepository extends BaseRepository {

  Future<List<BeatMix>> findByTitle(String query) async {
    final rows = await client!.schema('librebeats').from('beatmix').select('id, title, thumbnailurl, beatmixbeat:beatmixbeat(count)').ilike("title", "%${query}%");
    PrintLog('Found beatmixes: ${rows.length} for that contains "$query"');
    return rows.map(_beatMixFromRow).toList();
  }

  // ---------------------------------------------------------------------------
  BeatMix _beatMixFromRow(Map<String, dynamic> row) => BeatMix(
        id:  int.parse(row['id'].toString()),
        title: row['title'] as String,
        thumbnailUrl: row['thumbnailurl'] as String,
        trackCount:  row['beatmixbeat'][0]['count'],
      );
  // ---------------------------------------------------------------------------
}
