import 'package:liberated_beats/data/beatmix_repository.dart';
import 'package:liberated_beats/data/server_registry.dart';
import 'package:liberated_beats/models/beat_models.dart';

class FakeBeatMixRepository extends BeatMixRepository {
  FakeBeatMixRepository(super.registry);

  final Map<String, List<BeatMix>> responses = {};
  final Set<String> failing = {};
  int fetchCount = 0;

  @override
  Future<List<BeatMix>> fetchMenuFromServer(ServerConnection server) async {
    fetchCount++;
    if (failing.contains(server.url)) throw Exception('server down');
    return List.of(responses[server.url] ?? const []);
  }
}

BeatMix mix(String sourceId, int id, [String? title]) => BeatMix(
      id: id,
      sourceId: sourceId,
      title: title ?? 'Mix $id',
      thumbnailUrl: '',
      trackCount: 0,
      beats: const [],
    );
