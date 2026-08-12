import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/data/play_stats_store.dart';
import 'package:liberated_beats/providers/play_stats_provider.dart';
import 'package:sembast/sembast_memory.dart';

import '../fakes.dart';

Future<PlayStatsStore> memStore() async => PlayStatsStore(
    database: await newDatabaseFactoryMemory().openDatabase('stats.db'));

void main() {
  test('recordPlay updates both top lists and notifies', () async {
    final provider = PlayStatsProvider(await memStore());
    var notified = 0;
    provider.addListener(() => notified++);

    final b = beat('srv', 1, 'Alpha');
    await provider.recordPlay(b, mix('srv', 9, 'Nine', [b]));

    expect(provider.topBeats.single.beat.key, b.key);
    expect(provider.topBeats.single.plays, 1);
    expect(provider.topMixes.single.title, 'Nine');
    expect(provider.topMixes.single.distinctSongs, 1);
    expect(notified, greaterThan(0));
  });

  test('a solo play touches no mix', () async {
    final provider = PlayStatsProvider(await memStore());

    await provider.recordPlay(beat('srv', 1), null);

    expect(provider.topBeats, hasLength(1));
    expect(provider.topMixes, isEmpty);
  });

  test('init hydrates what an earlier run counted', () async {
    final store = await memStore();
    await store.recordBeatPlay(beat('srv', 1, 'Alpha'));
    await store.recordBeatPlay(beat('srv', 1, 'Alpha'));

    // same database, fresh provider: the app restarted
    final provider = PlayStatsProvider(store);
    expect(provider.topBeats, isEmpty);

    await provider.init();
    expect(provider.topBeats.single.plays, 2);
  });
}
