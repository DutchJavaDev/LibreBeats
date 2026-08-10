import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/data/history_store.dart';
import 'package:liberated_beats/data/liked_store.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Beat beat({String? mixTitle}) => Beat(
        id: 1,
        sourceId: 'https://a',
        title: 'Song',
        artist: 'Artist',
        duration: const Duration(seconds: 120),
        color: sampleTracks.first.color,
        audioUrl: 'https://a/stream.mp3',
        mixTitle: mixTitle,
      );

  test('subtitle prefers the owning mix and falls back to the artist', () {
    expect(beat().subtitle, 'Artist');
    expect(beat(mixTitle: 'Deep Focus').subtitle, 'Deep Focus');
  });

  test('subtitle never repeats the beat title', () {
    // the ingest stores the title as artist too — with no mix known the
    // line goes empty instead of echoing the title
    final echo = Beat(
      id: 2,
      sourceId: 'https://a',
      title: 'Song',
      artist: 'Song',
      duration: const Duration(seconds: 90),
      color: sampleTracks.first.color,
    );
    expect(echo.subtitle, isEmpty);
    // a known mix still wins over the echoing artist
    expect(echo.copyWith(mixTitle: 'Deep Focus').subtitle, 'Deep Focus');
  });

  test('copyWith stamps a mix title without touching the rest', () {
    final stamped = beat().copyWith(mixTitle: 'Deep Focus');
    expect(stamped.mixTitle, 'Deep Focus');
    expect(stamped.key, beat().key);
    expect(stamped.title, 'Song');
    expect(stamped.audioUrl, 'https://a/stream.mp3');
  });

  test('history round-trips the mix title, legacy entries fall back', () async {
    SharedPreferences.setMockInitialValues({});
    final store = HistoryStore();

    await store.save([beat(mixTitle: 'Deep Focus'), beat()]);
    final loaded = await store.load();

    expect(loaded.first.mixTitle, 'Deep Focus');
    expect(loaded.first.subtitle, 'Deep Focus');
    // saved without a mix, keeps working as before
    expect(loaded.last.mixTitle, isNull);
    expect(loaded.last.subtitle, 'Artist');
  });

  test('liked record round-trips the mix title', () {
    final record = LikedBeat(
      id: 1,
      sourceId: 'https://a',
      title: 'Song',
      artist: 'Artist',
      thumbnailUrl: '',
      streamingUrl: 'https://a/stream.mp3',
      duration: const Duration(seconds: 120),
      likedAt: DateTime(2026, 8, 9),
      state: 'pending',
      audioPath: 'tracks/x',
      artPath: 'art/x',
      mixTitle: 'Deep Focus',
    );

    final restored = LikedBeat.fromJson(record.toJson());
    expect(restored.mixTitle, 'Deep Focus');
    // state flips keep the snapshot intact
    expect(restored.withState('done').mixTitle, 'Deep Focus');
  });

  test('liked records from before the subtitle rule stay readable', () {
    // a stored map without the mixtitle key, as old installs have it
    final restored = LikedBeat.fromJson({
      'id': 1,
      'sourceid': 'https://a',
      'title': 'Song',
      'artist': 'Artist',
      'thumbnailurl': '',
      'streamingurl': 'https://a/stream.mp3',
      'duration': 120,
      'likedat': '2026-08-09T00:00:00.000',
      'state': 'done',
      'audiopath': 'tracks/x',
      'artpath': 'art/x',
    });

    expect(restored.mixTitle, isNull);
    expect(restored.title, 'Song');
  });
}
