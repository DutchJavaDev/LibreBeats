import 'package:liberated_beats/data/base_repository.dart';
import 'package:liberated_beats/main.dart';
import '../models/beat_models.dart';

/// Single point of access to the BeatMix catalog.
class BeatMixRepository extends BaseRepository {

  Future<List<BeatMix>> findByTitle(String query) async {
    final rows = await client!.schema('librebeats')
                              .from('beatmix')
                              .select('id, title, thumbnailurl, beatmixbeat:beatmixbeat(count)')
                              .ilike("title", "%${query}%");
    PrintLog('Found beatmixes: ${rows.length} for that contains "$query"');

    var beatMixes = rows.map(_beatMixFromRow).toList();

    for (var beatMix in beatMixes) {
      final trackRows = await client!.schema('librebeats')
                                    .from('beatmixbeat')
                                    .select('beat:beat(id, title, artist, thumbnailurl, streamingurl, rawbeat!beat_rawbeatid_fkey(duration))')
                                    .eq('beatmixid', beatMix.id);
      final tracks = trackRows.map((row) => _beatFromRow(row['beat'])).toList();

      PrintLog('Found ${tracks.length} tracks for beatmix "${beatMix.title}"');
      beatMix.beats!.addAll(tracks);
    }

    return beatMixes;
  }

  // get all beatmixes
  Future<List<BeatMix>> getAll() async {
    final rows = await client!.schema('librebeats')
                              .from('beatmix')
                              .select('id, title, thumbnailurl, beatmixbeat:beatmixbeat(count)');
    PrintLog('Found beatmixes: ${rows.length}');

    var beatMixes = rows.map(_beatMixFromRow).toList();

    for (var beatMix in beatMixes) {
      final trackRows = await client!.schema('librebeats')
                                    .from('beatmixbeat')
                                    .select('beat:beat(id, title, artist, thumbnailurl, streamingurl, rawbeat!beat_rawbeatid_fkey(duration))')
                                    .eq('beatmixid', beatMix.id);
      final tracks = trackRows.map((row) => _beatFromRow(row['beat'])).toList();

      PrintLog('Found ${tracks.length} tracks for beatmix "${beatMix.title}"');
      beatMix.beats!.addAll(tracks);
    }

    return beatMixes;
  }

  // ---------------------------------------------------------------------------
  BeatMix _beatMixFromRow(Map<String, dynamic> row) => BeatMix(
        id:  int.parse(row['id'].toString()),
        title: row['title'] as String,
        thumbnailUrl: row['thumbnailurl'] as String,
        trackCount:  row['beatmixbeat'][0]['count'],
        beats: [],
      );

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
