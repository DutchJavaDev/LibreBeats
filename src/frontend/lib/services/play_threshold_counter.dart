import 'dart:math';

/// Decides when a listen-through counts as a play: 30 seconds listened or
/// half the track, whichever comes first. Listened time is accumulated from
/// position deltas, so paused time and seek jumps do not count, skipping a
/// track before the threshold never counts it, and seeking back cannot
/// double-count within one listen-through.
class PlayThresholdCounter {
  /// The flat 30 second rule, tracks longer than a minute count here.
  static const capMs = 30000;

  /// Position ticks arrive a few hundred ms apart; a bigger jump is a seek
  /// or a track change, not listened audio.
  static const maxTickGapMs = 2000;

  int _listenedMs = 0;
  int _lastPositionMs = 0;
  bool _counted = false;

  /// A new listen-through starts: track change, repeat-one loop, the queue
  /// running out. [positionMs] anchors the delta for the next tick.
  void reset({int positionMs = 0}) {
    _listenedMs = 0;
    _lastPositionMs = positionMs;
    _counted = false;
  }

  /// Feed one position tick. Returns true exactly once per listen-through,
  /// at the moment the threshold is crossed. [totalMs] <= 0 means the
  /// duration is unknown, which falls back to the flat 30 second rule.
  bool onTick(int positionMs, int totalMs) {
    final delta = positionMs - _lastPositionMs;
    // always anchor on the new position, a rejected jump must not make the
    // tick after it look huge too
    _lastPositionMs = positionMs;

    // paused is delta 0, a seek forward is too big, a seek back or a loop
    // wrap is negative: none of those are listened audio
    if (delta > 0 && delta <= maxTickGapMs) _listenedMs += delta;

    if (_counted) return false;

    final thresholdMs = totalMs > 0 ? min(capMs, totalMs ~/ 2) : capMs;
    if (_listenedMs >= thresholdMs) {
      _counted = true;
      return true;
    }
    return false;
  }
}
