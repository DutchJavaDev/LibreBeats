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
        mixes.addAll(rows.map((row) => _beatMixFromRow(row, server.url)));
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

    final List<dynamic> data = response.data['data'];
    return data.map((mix) => _beatMixFromJson(mix, server.url)).toList();
  }

  // ---------------------------------------------------------------------------
  BeatMix _beatMixFromRow(Map<String, dynamic> row, String sourceId) {
    final mixTitle = row['title'] as String;
    final beats = ((row['beatmixbeat'] as List<dynamic>?) ?? [])
        .map((junction) => junction['beat'])
        .whereType<Map<String, dynamic>>()
        .map((b) => Beat(
              id: int.parse(b['id'].toString()),
              sourceId: sourceId,
              title: b['title'] as String,
              artist: b['artist'] as String,
              thumbnailUrl: b['thumbnailurl'] as String? ?? '',
              duration: Duration(seconds: b['rawbeat']?['duration'] ?? 0),
              color: sampleTracks.first.color,
              audioUrl: b['streamingurl'] as String?,
              mixTitle: mixTitle,
            ))
        .toList();

    return BeatMix(
      id: int.parse(row['id'].toString()),
      sourceId: sourceId,
      title: row['title'] as String,
      thumbnailUrl: row['thumbnailurl'] as String? ?? '',
      trackCount: beats.length,
      beats: beats,
    );
  }

  BeatMix _beatMixFromJson(dynamic json, String sourceId) {
    final mixTitle = json['title'] as String;
    final beats = ((json['beats'] as List<dynamic>?) ?? [])
        .map((beat) => _beatFromJson(beat, sourceId, mixTitle))
        .toList();

    return BeatMix(
      id: int.parse(json['id'].toString()),
      sourceId: sourceId,
      title: mixTitle,
      thumbnailUrl: json['thumbnailurl'] as String,
      trackCount: int.tryParse('${json['count']}') ?? beats.length,
      beats: beats,
    );
  }

  Beat _beatFromJson(dynamic json, String sourceId, String mixTitle) => Beat(
        id: int.parse(json['id'].toString()),
        sourceId: sourceId,
        title: json['title'] as String,
        artist: json['artist'] as String,
        thumbnailUrl: json['thumbnailurl'] as String? ?? '',
        duration: Duration(seconds: json['duration'] ?? 0),
        color: sampleTracks.first.color,
        audioUrl: json['streamingurl'] as String?,
        mixTitle: mixTitle,
      );
  // ---------------------------------------------------------------------------
}
