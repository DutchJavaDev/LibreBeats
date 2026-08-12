import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/data/play_stats_store.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:sembast/sembast_memory.dart';

Beat _beat(int id, {String? title, String? audioUrl}) => Beat(
      id: id,
      sourceId: 'https://a',
      title: title ?? 'Beat $id',
      artist: 'artist $id',
      thumbnailUrl: 'https://a/art/$id.jpg',
      duration: const Duration(seconds: 120),
      color: sampleTracks.first.color,
      audioUrl: audioUrl ?? 'https://a/audio/$id.opus',
      mixTitle: 'Mix of $id',
    );

BeatMix _mix(int id, {String? title, int trackCount = 5}) => BeatMix(
      id: id,
      sourceId: 'https://a',
      title: title ?? 'Mix $id',
      thumbnailUrl: 'https://a/mixart/$id.jpg',
      trackCount: trackCount,
      beats: null,
    );

void main() {
  Future<(PlayStatsStore, Database)> open() async {
    final db = await newDatabaseFactoryMemory().openDatabase('stats.db');
    return (PlayStatsStore(database: db), db);
  }

  test('a counted beat round-trips with its full playable snapshot', () async {
    final (store, _) = await open();
    await store.recordBeatPlay(_beat(1));

    final stats = await store.topBeats();
    expect(stats, hasLength(1));
    final stat = stats.single;
    expect(stat.plays, 1);
    expect(stat.beat.key, 'https://a:1');
    expect(stat.beat.title, 'Beat 1');
    expect(stat.beat.artist, 'artist 1');
    expect(stat.beat.thumbnailUrl, 'https://a/art/1.jpg');
    expect(stat.beat.duration, const Duration(seconds: 120));
    expect(stat.beat.mixTitle, 'Mix of 1');
    // the row on home must be tappable-to-play like a history entry
    expect(stat.beat.audioUrl, 'https://a/audio/1.opus');
    expect(stat.beat.isPlayable, isTrue);
  });

  test('replays increment and refresh the snapshot and timestamp', () async {
    final (store, _) = await open();
    final first = DateTime(2026, 1, 1);
    final second = DateTime(2026, 2, 2);

    await store.recordBeatPlay(_beat(1, title: 'Old title'), at: first);
    await store.recordBeatPlay(_beat(1, title: 'New title'), at: second);

    final stat = (await store.topBeats()).single;
    expect(stat.plays, 2);
    expect(stat.beat.title, 'New title'); // snapshot refreshed, not stale
    expect(stat.lastPlayedAt, second);
  });

  test('mix plays count every play but each song only once', () async {
    final (store, _) = await open();
    final m = _mix(9);

    await store.recordMixPlay(m, _beat(1));
    await store.recordMixPlay(m, _beat(1)); // same song again
    await store.recordMixPlay(m, _beat(2));

    final stat = (await store.topMixes()).single;
    expect(stat.plays, 3);
    expect(stat.distinctSongs, 2);
    expect(stat.title, 'Mix 9');
    expect(stat.trackCount, 5);
    expect(stat.toBeatMix().key, 'https://a:9');
  });

  test('top lists sort by plays, last played breaks ties, limit caps',
      () async {
    final (store, _) = await open();
    final older = DateTime(2026, 1, 1);
    final newer = DateTime(2026, 2, 2);

    await store.recordBeatPlay(_beat(1), at: older); // 1 play, old
    await store.recordBeatPlay(_beat(2), at: newer); // 1 play, new
    await store.recordBeatPlay(_beat(3), at: older); // 2 plays
    await store.recordBeatPlay(_beat(3), at: older);

    final top = await store.topBeats();
    expect([for (final s in top) s.beat.id], [3, 2, 1]);

    expect(await store.topBeats(limit: 2), hasLength(2));
  });

  test('records with missing fields load with fallbacks', () async {
    final (store, db) = await open();
    // a record written by an older version of the app
    await stringMapStoreFactory
        .store('playbeat')
        .record('https://a:1')
        .put(db, {'id': 1, 'title': 'Sparse'});

    final stat = (await store.topBeats()).single;
    expect(stat.beat.title, 'Sparse');
    expect(stat.beat.artist, '');
    expect(stat.plays, 0);
    expect(stat.beat.isPlayable, isFalse);
    expect(stat.lastPlayedAt, DateTime.fromMillisecondsSinceEpoch(0));
  });

  test('clear drops both stores', () async {
    final (store, _) = await open();
    await store.recordBeatPlay(_beat(1));
    await store.recordMixPlay(_mix(9), _beat(1));

    await store.clear();

    expect(await store.topBeats(), isEmpty);
    expect(await store.topMixes(), isEmpty);
  });
}
