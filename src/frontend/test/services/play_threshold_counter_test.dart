import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/services/play_threshold_counter.dart';

void main() {
  /// Drives 1-second ticks from [fromS] to [toS] and returns the positions
  /// (in seconds) where the counter fired.
  List<int> tick(PlayThresholdCounter counter, int fromS, int toS, int totalS) {
    final fired = <int>[];
    for (var s = fromS; s <= toS; s++) {
      if (counter.onTick(s * 1000, totalS * 1000)) fired.add(s);
    }
    return fired;
  }

  test('a long track counts once at 30 seconds', () {
    final counter = PlayThresholdCounter();
    expect(tick(counter, 1, 240, 240), [30]);
  });

  test('a short track counts at half its duration', () {
    final counter = PlayThresholdCounter();
    expect(tick(counter, 1, 40, 40), [20]);
  });

  test('unknown duration falls back to the flat 30 second rule', () {
    final counter = PlayThresholdCounter();
    expect(tick(counter, 1, 60, 0), [30]);
  });

  test('skipping away before the threshold never counts', () {
    final counter = PlayThresholdCounter();
    expect(tick(counter, 1, 20, 240), isEmpty);

    // next track: only its own listened time may count
    counter.reset();
    expect(tick(counter, 1, 29, 240), isEmpty);
    expect(tick(counter, 30, 30, 240), [30]);
  });

  test('a seek forward does not count as listened time', () {
    final counter = PlayThresholdCounter();
    expect(tick(counter, 1, 10, 600), isEmpty); // 10s listened

    // jump to 500s: the gap is rejected, only real ticks accumulate after
    expect(tick(counter, 500, 518, 600), isEmpty); // 10 + 18 = 28s
    expect(tick(counter, 519, 520, 600), [520]); // crosses 30s listened
  });

  test('seeking back after counting cannot double-count', () {
    final counter = PlayThresholdCounter();
    expect(tick(counter, 1, 35, 240), [30]);

    // rewind to the start and listen through again, same listen-through
    expect(tick(counter, 1, 120, 240), isEmpty);
  });

  test('paused ticks accumulate nothing', () {
    final counter = PlayThresholdCounter();
    tick(counter, 1, 29, 240);
    // paused: the position repeats, delta 0
    for (var i = 0; i < 100; i++) {
      expect(counter.onTick(29000, 240000), isFalse);
    }
    expect(tick(counter, 30, 30, 240), [30]);
  });

  test('reset starts a new listen-through that counts again', () {
    final counter = PlayThresholdCounter();
    expect(tick(counter, 1, 240, 240), [30]);

    // repeat-one looped back to the start
    counter.reset();
    expect(tick(counter, 1, 240, 240), [30]);
  });

  test('a stale tick from the old track after a reset is swallowed', () {
    final counter = PlayThresholdCounter();
    tick(counter, 1, 200, 240);
    counter.reset();

    // one last position of the old track arrives after the track change:
    // a giant jump, rejected, and it must not poison the ticks after it
    expect(counter.onTick(200000, 240000), isFalse);
    expect(tick(counter, 1, 30, 240), isEmpty); // 1s tick is a negative delta
    expect(tick(counter, 31, 31, 240), [31]); // 30s listened, one tick late
  });
}
