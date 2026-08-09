import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/data/liked_store.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  LikedBeat liked(String sourceId, int id,
          {DateTime? at, String state = 'pending'}) =>
      LikedBeat(
        id: id,
        sourceId: sourceId,
        title: 'Beat $id',
        artist: 'artist',
        thumbnailUrl: 'https://a.example.com/art/$id.jpg',
        streamingUrl: 'https://a.example.com/audio/$id.opus',
        duration: const Duration(seconds: 90),
        likedAt: at ?? DateTime(2026, 8, id + 1),
        state: state,
        audioPath: 'offline/tracks/aa_$id.opus',
        artPath: 'offline/art/aa_$id.jpg',
      );

  Future<LikedStore> store() async => LikedStore(
      database: await newDatabaseFactoryMemory().openDatabase('liked.db'));

  test('round trips every field', () async {
    final s = await store();
    final beat = liked('https://a.example.com', 7, state: 'done');
    await s.put(beat);

    final back = (await s.find(beat.key))!;
    expect(back.key, beat.key);
    expect(back.title, 'Beat 7');
    expect(back.artist, 'artist');
    expect(back.thumbnailUrl, beat.thumbnailUrl);
    expect(back.streamingUrl, beat.streamingUrl);
    expect(back.duration, const Duration(seconds: 90));
    expect(back.likedAt, beat.likedAt);
    expect(back.state, 'done');
    expect(back.audioPath, beat.audioPath);
    expect(back.artPath, beat.artPath);
  });

  test('all() returns newest like first', () async {
    final s = await store();
    await s.put(liked('a', 1, at: DateTime(2026, 8, 1)));
    await s.put(liked('a', 2, at: DateTime(2026, 8, 3)));
    await s.put(liked('a', 3, at: DateTime(2026, 8, 2)));

    expect([for (final b in await s.all()) b.id], [2, 3, 1]);
  });

  test('put with the same key overwrites', () async {
    final s = await store();
    await s.put(liked('a', 1));
    await s.put(liked('a', 1).withState('done'));

    expect((await s.all()).single.state, 'done');
  });

  test('remove deletes the record, missing keys are fine', () async {
    final s = await store();
    await s.put(liked('a', 1));
    await s.remove('a:1');
    await s.remove('a:1');

    expect(await s.all(), isEmpty);
    expect(await s.find('a:1'), isNull);
  });
}
