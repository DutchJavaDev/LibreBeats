import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/data/server_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

// connector that just flips the status, no network
ServerConnector fakeConnector(
    {Set<String> failing = const {}, List<String>? log}) {
  return (server) async {
    log?.add(server.url);
    server.status = failing.contains(server.url)
        ? ServerStatus.failed
        : ServerStatus.healthy;
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('parseSeedList zips urls and keys', () {
    expect(ServerRegistry.parseSeedList('https://a,https://b', 'k1,k2'),
        [('https://a', 'k1'), ('https://b', 'k2')]);
    expect(ServerRegistry.parseSeedList(' https://a , https://b ', ' k1 , k2 '),
        [('https://a', 'k1'), ('https://b', 'k2')]);
    // unmatched extras get dropped
    expect(ServerRegistry.parseSeedList('https://a,https://b', 'k1'),
        [('https://a', 'k1')]);
    expect(ServerRegistry.parseSeedList('', ''), isEmpty);
    expect(ServerRegistry.parseSeedList('https://a', ''), isEmpty);
  });

  test('seed is used on first run and persisted', () async {
    final registry = ServerRegistry(connector: fakeConnector());
    await registry.load(seed: const [('https://a.example.com', 'k1')]);
    expect(registry.servers.single.url, 'https://a.example.com');

    // new registry, no seed, should come from prefs
    final second = ServerRegistry(connector: fakeConnector());
    await second.load();
    expect(second.servers.single.url, 'https://a.example.com');
  });

  test('persisted servers win over the seed', () async {
    final first = ServerRegistry(connector: fakeConnector());
    await first.load(seed: const [('https://persisted.example.com', 'k1')]);

    final second = ServerRegistry(connector: fakeConnector());
    await second.load(seed: const [('https://seed.example.com', 'k2')]);
    expect(second.servers.single.url, 'https://persisted.example.com');
  });

  test('connectAll signs in everything, only once', () async {
    final log = <String>[];
    final registry = ServerRegistry(connector: fakeConnector(log: log));
    await registry.load(seed: const [('https://a', 'k1'), ('https://b', 'k2')]);

    await registry.connectAll();
    await registry.connectAll();

    expect(log, ['https://a', 'https://b']);
    expect(registry.healthy, hasLength(2));
  });

  test('failed sign in is not healthy', () async {
    final registry =
        ServerRegistry(connector: fakeConnector(failing: {'https://b'}));
    await registry.load(seed: const [('https://a', 'k1'), ('https://b', 'k2')]);
    await registry.connectAll();

    expect(registry.healthy.map((s) => s.url), ['https://a']);
    expect(registry.servers[1].status, ServerStatus.failed);
  });

  test('addServer keeps a working server and persists it', () async {
    final registry = ServerRegistry(connector: fakeConnector());
    await registry.load();

    expect(await registry.addServer('https://new.example.com', 'k'), isTrue);
    expect(registry.healthy, hasLength(1));

    final reloaded = ServerRegistry(connector: fakeConnector());
    await reloaded.load();
    expect(reloaded.servers.single.url, 'https://new.example.com');
  });

  test('addServer drops a server that cant sign in', () async {
    final registry = ServerRegistry(
        connector: fakeConnector(failing: {'https://bad.example.com'}));
    await registry.load();

    expect(await registry.addServer('https://bad.example.com', 'k'), isFalse);
    expect(registry.servers, isEmpty);
  });

  test('addServer rejects duplicate urls', () async {
    final registry = ServerRegistry(connector: fakeConnector());
    await registry.load(seed: const [('https://a', 'k1')]);

    expect(await registry.addServer('https://a', 'other'), isFalse);
    expect(registry.servers, hasLength(1));
  });

  test('removeServer persists', () async {
    final registry = ServerRegistry(connector: fakeConnector());
    await registry.load(seed: const [('https://a', 'k1')]);

    await registry.removeServer(registry.servers.first);
    expect(registry.servers, isEmpty);

    final reloaded = ServerRegistry(connector: fakeConnector());
    await reloaded.load();
    expect(reloaded.servers, isEmpty);
  });

  test('reconnect retries a single server', () async {
    final failing = {'https://a'};
    final registry = ServerRegistry(connector: fakeConnector(failing: failing));
    await registry.load(seed: const [('https://a', 'k1')]);
    await registry.connectAll();
    expect(registry.healthy, isEmpty);

    failing.clear(); // server came back
    await registry.reconnect(registry.servers.first);
    expect(registry.healthy, hasLength(1));
  });

  test('markFailed and reconnectFailed', () async {
    final log = <String>[];
    final registry = ServerRegistry(connector: fakeConnector(log: log));
    await registry.load(seed: const [('https://a', 'k1'), ('https://b', 'k2')]);
    await registry.connectAll();
    log.clear();

    var notified = false;
    registry.addListener(() => notified = true);

    registry.markFailed(registry.servers.first);
    expect(registry.healthy, hasLength(1));
    expect(notified, isTrue);

    await registry.reconnectFailed();
    expect(log, ['https://a']); // b was healthy, untouched
    expect(registry.healthy, hasLength(2));
  });
}
