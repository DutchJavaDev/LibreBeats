import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/data/catalog_cache_store.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  final store = CatalogCacheStore();

  Map<String, CachedServerCatalog> sampleCache() => {
        'https://a': CachedServerCatalog(
          fetchedAt: DateTime(2026, 8, 7, 12),
          mixes: [
            BeatMix(
              id: 1,
              sourceId: 'https://a',
              title: 'Mix',
              thumbnailUrl: 't.jpg',
              trackCount: 1,
              beats: [
                Beat(
                  id: 7,
                  sourceId: 'https://a',
                  title: 'Song',
                  artist: 'Artist',
                  thumbnailUrl: 'https://a/thumb.jpg',
                  duration: const Duration(seconds: 120),
                  color: sampleTracks.first.color,
                  audioUrl: 'https://a/stream.mp3',
                ),
              ],
            ),
          ],
        ),
      };

  test('save and load round trip keeps everything', () async {
    await store.save(sampleCache());
    final loaded = await store.load();

    final entry = loaded['https://a']!;
    expect(entry.fetchedAt, DateTime(2026, 8, 7, 12));

    final m = entry.mixes.single;
    expect(m.key, 'https://a:1');
    expect(m.title, 'Mix');
    expect(m.thumbnailUrl, 't.jpg');
    expect(m.trackCount, 1);

    final b = m.beats!.single;
    expect(b.key, 'https://a:7');
    expect(b.title, 'Song');
    expect(b.artist, 'Artist');
    expect(b.thumbnailUrl, 'https://a/thumb.jpg');
    expect(b.audioUrl, 'https://a/stream.mp3');
    expect(b.duration, const Duration(seconds: 120));
    expect(b.isPlayable, isTrue);
  });

  test('empty or corrupt cache loads as empty', () async {
    expect(await store.load(), isEmpty);

    SharedPreferences.setMockInitialValues(
        {'librebeats_catalog_cache': 'not json {'});
    expect(await store.load(), isEmpty);
  });

  test('clear wipes the stored cache', () async {
    await store.save(sampleCache());
    expect(await store.load(), isNotEmpty);

    await store.clear();
    expect(await store.load(), isEmpty);
  });

  test('persistent mode defaults to true and round trips', () async {
    expect(await store.loadPersistentMode(), isTrue);

    await store.savePersistentMode(false);
    expect(await store.loadPersistentMode(), isFalse);
  });
}
