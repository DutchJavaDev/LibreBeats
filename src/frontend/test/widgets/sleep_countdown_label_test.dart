import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/widgets/full_player.dart';

void main() {
  test('idle and end-of-track wording', () {
    expect(sleepCountdownLabel(remaining: null, endOfTrack: false), 'Sleep');
    expect(sleepCountdownLabel(remaining: null, endOfTrack: true),
        'Sleep · end of track');
  });

  test('counts down with seconds, hours only when needed', () {
    expect(
        sleepCountdownLabel(
            remaining: const Duration(minutes: 14, seconds: 32),
            endOfTrack: false),
        'Sleep · 14:32');
    expect(
        sleepCountdownLabel(
            remaining: const Duration(seconds: 9), endOfTrack: false),
        'Sleep · 0:09');
    expect(
        sleepCountdownLabel(remaining: const Duration(hours: 1), endOfTrack: false),
        'Sleep · 1:00:00');
    expect(
        sleepCountdownLabel(
            remaining: const Duration(hours: 1, minutes: 5, seconds: 3),
            endOfTrack: false),
        'Sleep · 1:05:03');
    expect(sleepCountdownLabel(remaining: Duration.zero, endOfTrack: false),
        'Sleep · 0:00');
  });
}
