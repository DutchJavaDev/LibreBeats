import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/data/beat_repository.dart';
import 'package:liberated_beats/data/beatmix_repository.dart';
import 'package:liberated_beats/data/server_registry.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/providers/catalog_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const serverA = 'https://a.example.com';
  const serverB = 'https://b.example.com';

  late ServerRegistry registry;
  late FakeBeatMixRepository repo;
  late LibreProvider provider;

  Future<void> setup(
      {Duration cacheTtl = const Duration(milliseconds: 60)}) async {
    SharedPreferences.setMockInitialValues({});
    registry =
        ServerRegistry(connector: (s) async => s.status = ServerStatus.healthy);
    await registry.load(seed: const [(serverA, 'k1'), (serverB, 'k2')]);

    repo = FakeBeatMixRepository(registry);
    repo.responses[serverA] = [mix(serverA, 1, 'Chill'), mix(serverA, 2)];
    repo.responses[serverB] = [mix(serverB, 1, 'Rock'), mix(serverB, 3)];

    provider = LibreProvider(
      registry,
      repo,
      BeatRepository(registry),
      cacheTtl: cacheTtl,
      dripInterval: const Duration(milliseconds: 1),
    );
  }

  test('merges mixes from all servers', () async {
    await setup();
    await provider.ensureCatalog();

    expect(provider.beatMixes.map((m) => m.key).toSet(),
        {'$serverA:1', '$serverA:2', '$serverB:1', '$serverB:3'});
    expect(provider.isFetching, isFalse);
  });

  test('drips the tiles in one by one', () async {
    await setup();

    final lengths = <int>[];
    provider.addListener(() => lengths.add(provider.beatMixes.length));

    await provider.ensureCatalog();

    // one insert per notify, so every count 1..4 should show up
    expect(lengths.toSet().containsAll({1, 2, 3, 4}), isTrue);
  });

  test('same id from two servers does not collide', () async {
    await setup();
    await provider.ensureCatalog();

    expect(provider.beatMixes.where((m) => m.id == 1), hasLength(2));
  });

  test('no refetch while the cache is fresh', () async {
    await setup(cacheTtl: const Duration(minutes: 20));
    await provider.ensureCatalog();
    final fetches = repo.fetchCount;

    await provider.ensureCatalog();
    expect(repo.fetchCount, fetches);
  });

  test('refetches after the ttl and swaps silently', () async {
    await setup(cacheTtl: const Duration(milliseconds: 30));
    await provider.ensureCatalog();

    repo.responses[serverA] = [mix(serverA, 9, 'Fresh')];
    repo.responses[serverB] = [];
    await Future.delayed(const Duration(milliseconds: 40));

    final lengths = <int>[];
    provider.addListener(() => lengths.add(provider.beatMixes.length));

    await provider.ensureCatalog();

    expect(provider.beatMixes.map((m) => m.key), ['$serverA:9']);
    // the old list should never get swapped for an empty one
    expect(lengths, isNot(contains(0)));
  });

  test('failing server is skipped and marked failed', () async {
    await setup();
    repo.failing.add(serverB);

    await provider.ensureCatalog();

    expect(provider.beatMixes.map((m) => m.sourceId).toSet(), {serverA});
    expect(registry.servers.firstWhere((s) => s.url == serverB).status,
        ServerStatus.failed);
  });

  test('all servers down on first load, next visit retries', () async {
    await setup(cacheTtl: const Duration(minutes: 20));
    repo.failing.addAll([serverA, serverB]);

    await provider.ensureCatalog();
    expect(provider.beatMixes, isEmpty);

    // an empty first load never counts as fresh
    repo.failing.clear();
    await provider.ensureCatalog();
    expect(provider.beatMixes, hasLength(4));
  });

  test('all servers down on refresh keeps the stale list', () async {
    await setup(cacheTtl: const Duration(milliseconds: 30));
    await provider.ensureCatalog();
    final before = provider.beatMixes.map((m) => m.key).toSet();

    repo.failing.addAll([serverA, serverB]);
    await Future.delayed(const Duration(milliseconds: 40));
    await provider.ensureCatalog();

    expect(provider.beatMixes.map((m) => m.key).toSet(), before);
  });

  test('failed server comes back on a later refresh', () async {
    await setup(cacheTtl: const Duration(milliseconds: 30));
    repo.failing.add(serverB);
    await provider.ensureCatalog();
    expect(provider.beatMixes.map((m) => m.sourceId).toSet(), {serverA});

    repo.failing.clear();
    await Future.delayed(const Duration(milliseconds: 40));
    await provider.ensureCatalog();

    expect(
        provider.beatMixes.map((m) => m.sourceId).toSet(), {serverA, serverB});
  });

  test('findAllByTitle filters the cached mixes', () async {
    await setup();
    await provider.ensureCatalog();

    var results = await provider.findAllByTitle('chi').first;
    expect(results.single.beatMix?.title, 'Chill');

    results = await provider.findAllByTitle('zzz').first;
    expect(results, isEmpty);
  });
}
