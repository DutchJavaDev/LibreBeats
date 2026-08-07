import 'package:liberated_beats/data/base_repository.dart';
import 'package:liberated_beats/data/server_registry.dart';

import '../models/beat_models.dart';

/// Single point of access to the BeatMix catalog.
class BeatMixRepository extends BaseRepository {
  BeatMixRepository(super.registry);

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
  BeatMix _beatMixFromJson(dynamic json, String sourceId) {
    final beats = ((json['beats'] as List<dynamic>?) ?? [])
        .map((beat) => _beatFromJson(beat, sourceId))
        .toList();

    return BeatMix(
      id: int.parse(json['id'].toString()),
      sourceId: sourceId,
      title: json['title'] as String,
      thumbnailUrl: json['thumbnailurl'] as String,
      trackCount: int.tryParse('${json['count']}') ?? beats.length,
      beats: beats,
    );
  }

  Beat _beatFromJson(dynamic json, String sourceId) => Beat(
        id: int.parse(json['id'].toString()),
        sourceId: sourceId,
        title: json['title'] as String,
        artist: json['artist'] as String,
        thumbnailUrl: json['thumbnailurl'] as String? ?? '',
        duration: Duration(seconds: json['duration'] ?? 0),
        color: sampleTracks.first.color,
        audioUrl: json['streamingurl'] as String?,
      );
  // ---------------------------------------------------------------------------
}
