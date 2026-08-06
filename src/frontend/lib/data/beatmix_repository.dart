import 'package:liberated_beats/data/base_repository.dart';
import 'package:liberated_beats/data/server_registry.dart';

import '../models/beat_models.dart';

/// Fetches BeatMix catalogs from individual servers via their `menu` Edge
/// Function. Merging, ordering, and the 20-minute cache live in LibreProvider.
class BeatMixRepository extends BaseRepository {
  BeatMixRepository(super.registry);

  /// Fetches every mix (with embedded beats) from a single [server]. Throws on
  /// any failure — including the 10s timeout — so the caller can mark the
  /// server as failed and move on.
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
        album: json['thumbnailurl'] as String,
        duration: Duration(seconds: json['duration'] ?? 0),
        color: sampleTracks.first.color,
        audioUrl: json['streamingurl'] as String?,
      );
  // ---------------------------------------------------------------------------
}
