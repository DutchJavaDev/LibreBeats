import 'package:liberated_beats/data/beat_repository.dart';
import 'package:liberated_beats/data/beatmix_repository.dart';
import 'package:liberated_beats/data/server_registry.dart';
import 'package:liberated_beats/models/beat_models.dart';

class FakeBeatMixRepository extends BeatMixRepository {
  FakeBeatMixRepository(super.registry);

  final Map<String, List<BeatMix>> responses = {};
  final Set<String> failing = {};
  int fetchCount = 0;

  // canned live search results, filtered by title like the real query
  final List<BeatMix> searchResults = [];
  int searchCount = 0;

  @override
  Future<List<BeatMix>> fetchMenuFromServer(ServerConnection server) async {
    fetchCount++;
    if (failing.contains(server.url)) throw Exception('server down');
    return List.of(responses[server.url] ?? const []);
  }

  @override
  Future<List<BeatMix>> findByTitle(String query) async {
    searchCount++;
    final q = query.toLowerCase();
    return searchResults
        .where((m) => m.title.toLowerCase().contains(q))
        .toList();
  }
}

class FakeBeatRepository extends BeatRepository {
  FakeBeatRepository(super.registry);

  // canned live search results, filtered by title like the real query
  final List<Beat> searchResults = [];
  int searchCount = 0;

  @override
  Future<List<Beat>> findByTitle(String query) async {
    searchCount++;
    final q = query.toLowerCase();
    return searchResults
        .where((b) => b.title.toLowerCase().contains(q))
        .toList();
  }
}

BeatMix mix(String sourceId, int id,
        [String? title, List<Beat> beats = const []]) =>
    BeatMix(
      id: id,
      sourceId: sourceId,
      title: title ?? 'Mix $id',
      thumbnailUrl: '',
      trackCount: beats.length,
      beats: beats,
    );

Beat beat(String sourceId, int id, [String? title]) => Beat(
      id: id,
      sourceId: sourceId,
      title: title ?? 'Beat $id',
      artist: 'artist',
      duration: const Duration(seconds: 1),
      color: sampleTracks.first.color,
    );
