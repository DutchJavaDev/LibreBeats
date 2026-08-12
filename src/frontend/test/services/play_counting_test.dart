import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/services/audio_playback_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes.dart';

Beat _longBeat(int id, [String? title]) => Beat(
      id: id,
      sourceId: 'srv',
      title: title ?? 'Beat $id',
      artist: 'artist',
      duration: const Duration(seconds: 100),
      color: sampleTracks.first.color,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a play is counted once, with the owning mix, at the threshold', () {
    // headless: the constructor only subscribes to streams, and
    // updateProgress falls back to beat.duration for the total
    final service = AudioPlaybackService();
    final counted = <(Beat, BeatMix?)>[];
    service.setPlayCountedCallback((beat, mix) => counted.add((beat, mix)));

    final beat = _longBeat(1);
    final owningMix = mix('srv', 7, 'Focus', [beat]);
    service.debugSetNowPlaying(beat, mix: owningMix);

    // 100s track: min(30s, 50s) = 30s of listened time
    for (var s = 1; s <= 29; s++) {
      service.updateProgress(Duration(seconds: s));
    }
    expect(counted, isEmpty);

    service.updateProgress(const Duration(seconds: 30));
    expect(counted, hasLength(1));
    expect(counted.single.$1.key, beat.key);
    expect(counted.single.$2!.key, owningMix.key);

    // playing on does not count again
    for (var s = 31; s <= 100; s++) {
      service.updateProgress(Duration(seconds: s));
    }
    expect(counted, hasLength(1));
  });

  test('a track change resets the counter, solo playback has no mix', () {
    final service = AudioPlaybackService();
    final counted = <(Beat, BeatMix?)>[];
    service.setPlayCountedCallback((beat, mix) => counted.add((beat, mix)));

    service.debugSetNowPlaying(_longBeat(1), mix: mix('srv', 7));
    for (var s = 1; s <= 20; s++) {
      service.updateProgress(Duration(seconds: s));
    }
    expect(counted, isEmpty); // skipped away before the threshold

    service.debugSetNowPlaying(_longBeat(2), mix: null);
    for (var s = 1; s <= 30; s++) {
      service.updateProgress(Duration(seconds: s));
    }
    expect(counted, hasLength(1));
    expect(counted.single.$1.id, 2);
    expect(counted.single.$2, isNull);
  });

  test('an unknown duration counts at the flat 30 seconds', () {
    final service = AudioPlaybackService();
    final counted = <int>[];
    service.setPlayCountedCallback((_, __) => counted.add(1));

    // duration zero: updateProgress normally bails out, counting must not
    final noLength = Beat(
      id: 1,
      sourceId: 'srv',
      title: 'endless',
      artist: 'artist',
      duration: Duration.zero,
      color: sampleTracks.first.color,
    );
    service.debugSetNowPlaying(noLength);
    for (var s = 1; s <= 29; s++) {
      service.updateProgress(Duration(seconds: s));
    }
    expect(counted, isEmpty);
    service.updateProgress(const Duration(seconds: 30));
    expect(counted, hasLength(1));
  });
}
