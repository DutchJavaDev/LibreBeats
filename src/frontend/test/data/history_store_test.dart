import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/data/history_store.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  final store = HistoryStore();

  List<Beat> sampleHistory() => [
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
        Beat(
          id: 7,
          sourceId: 'https://b',
          title: 'Other song',
          artist: 'Other artist',
          duration: const Duration(seconds: 95),
          color: sampleTracks.first.color,
          audioUrl: 'https://b/stream.mp3',
        ),
      ];

  test('save and load round trip keeps everything in order', () async {
    await store.save(sampleHistory());
    final loaded = await store.load();

    expect(loaded, hasLength(2));

    final b = loaded.first;
    expect(b.key, 'https://a:7');
    expect(b.title, 'Song');
    expect(b.artist, 'Artist');
    expect(b.thumbnailUrl, 'https://a/thumb.jpg');
    expect(b.audioUrl, 'https://a/stream.mp3');
    expect(b.duration, const Duration(seconds: 120));
    expect(b.isPlayable, isTrue);

    // same id on another server stays a distinct entry
    expect(loaded.last.key, 'https://b:7');
  });

  test('empty or corrupt history loads as empty', () async {
    expect(await store.load(), isEmpty);

    SharedPreferences.setMockInitialValues(
        {'librebeats_play_history': 'not json {'});
    expect(await store.load(), isEmpty);
  });

  test('clear wipes the stored history', () async {
    await store.save(sampleHistory());
    expect(await store.load(), isNotEmpty);

    await store.clear();
    expect(await store.load(), isEmpty);
  });
}
