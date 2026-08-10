import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/services/audio_playback_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records pauses instead of touching the (headless) audio player, the
/// sleep timer only needs the pause hook.
class _TestPlayback extends AudioPlaybackService {
  int pauseCalls = 0;

  @override
  Future<void> pause() async {
    pauseCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('duration timer pauses playback when it runs out', () async {
    final service = _TestPlayback();
    var changes = 0;
    service.setSleepChangedCallback(() => changes++);

    service.setSleepTimer(const Duration(milliseconds: 40));
    expect(service.sleepUntil, isNotNull);
    expect(service.sleepDuration, const Duration(milliseconds: 40));
    expect(changes, 1);

    await Future.delayed(const Duration(milliseconds: 150));

    expect(service.pauseCalls, 1);
    expect(service.sleepUntil, isNull);
    expect(service.sleepDuration, isNull);
    expect(service.sleepEndOfTrack, isFalse);
    expect(changes, 2);
  });

  test('null disarms a running timer before it fires', () async {
    final service = _TestPlayback();
    service.setSleepTimer(const Duration(milliseconds: 40));
    service.setSleepTimer(null);

    await Future.delayed(const Duration(milliseconds: 150));

    expect(service.pauseCalls, 0);
    expect(service.sleepUntil, isNull);
  });

  test('end of track replaces a duration timer and vice versa', () {
    final service = _TestPlayback();

    service.setSleepTimer(const Duration(minutes: 15));
    service.setSleepEndOfTrack();
    expect(service.sleepEndOfTrack, isTrue);
    expect(service.sleepUntil, isNull);
    expect(service.sleepDuration, isNull);

    service.setSleepTimer(const Duration(minutes: 30));
    expect(service.sleepEndOfTrack, isFalse);
    expect(service.sleepDuration, const Duration(minutes: 30));
  });

  test('a manual skip clears an end-of-track sleep', () async {
    final service = _TestPlayback();
    service.setSleepEndOfTrack();
    expect(service.sleepEndOfTrack, isTrue);

    // empty queue: hasNext is false, but someone awake means no more sleep
    await service.skipToNext();
    expect(service.sleepEndOfTrack, isFalse);
    expect(service.pauseCalls, 0);
  });
}
