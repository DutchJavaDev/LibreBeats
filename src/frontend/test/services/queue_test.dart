import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/providers/background_audio_provider.dart';
import 'package:liberated_beats/services/audio_playback_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes.dart';

Beat _playable(int id) => Beat(
      id: id,
      sourceId: 'srv',
      title: 'Beat $id',
      artist: 'artist',
      duration: const Duration(seconds: 90),
      color: sampleTracks.first.color,
      audioUrl: 'https://srv/audio/$id.opus',
    );

/// Records jumps instead of touching the (headless) audio player.
class _RecordingPlayback extends AudioPlaybackService {
  final jumps = <int>[];

  @override
  Future<void> skipToQueueItem(int index) async {
    jumps.add(index);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    // the first load in a process boots just_audio lazily, which drops an
    // orphan MissingPluginException into whichever test runs first. Trip
    // it here in a guarded zone instead.
    await runZonedGuarded(() async {
      await AudioPlaybackService().setBeatSource(_playable(0));
      await Future<void>.delayed(Duration.zero);
    }, (_, __) {});
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('setBeatMix keeps the queue in player order, unplayable beats out',
      () async {
    final service = AudioPlaybackService();

    // beat(2) from the fakes has no audioUrl and gets skipped. The
    // headless load fails, the bookkeeping happens before it does.
    final loaded = await service.setBeatMix(
        mix('srv', 1, 'Mix 1', [_playable(1), beat('srv', 2), _playable(3)]),
        null);

    expect(loaded, isFalse);
    expect([for (final b in service.queueBeats) b.id], [1, 3]);
    // queue copies carry the owning mix for subtitles
    expect(service.queueBeats.first.mixTitle, 'Mix 1');
  });

  test('setBeatSource resets the queue to the single beat', () async {
    final service = AudioPlaybackService();
    await service.setBeatMix(
        mix('srv', 1, 'Mix 1', [_playable(1), _playable(2)]), null);

    await service.setBeatSource(_playable(9));

    expect([for (final b in service.queueBeats) b.id], [9]);
  });

  test('an out of range jump is a safe no-op that still wakes the sleeper',
      () async {
    final service = AudioPlaybackService();
    service.setSleepEndOfTrack();

    await service.skipToQueueItem(0); // empty queue
    await service.skipToQueueItem(-1);

    expect(service.sleepEndOfTrack, isFalse);
  });

  test('the provider forwards the jump and notifies', () async {
    final playback = _RecordingPlayback();
    final provider = BackgroundAudioProvider(playback);
    var notified = 0;
    provider.addListener(() => notified++);

    await provider.skipToQueueItem(3);

    expect(playback.jumps, [3]);
    expect(notified, 1);
  });
}
