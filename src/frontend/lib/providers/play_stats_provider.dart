import 'package:flutter/foundation.dart';

import '../data/play_stats_store.dart';
import '../models/beat_models.dart';

/// The all-time play counts behind the home screen's On repeat and Heavy
/// rotation sections. The audio service reports a counted play through
/// [recordPlay] (wired as a callback in main.dart), the store keeps it on
/// disk, and the top lists here are what the UI watches.
class PlayStatsProvider extends ChangeNotifier {
  PlayStatsProvider(this._store);

  final PlayStatsStore _store;

  static const _topLimit = 10;

  List<BeatPlayStat> _topBeats = const [];
  List<MixPlayStat> _topMixes = const [];

  /// Most played beats, at most 10, empty until something counted.
  List<BeatPlayStat> get topBeats => _topBeats;

  /// Most played mixes, at most 10, empty until something counted.
  List<MixPlayStat> get topMixes => _topMixes;

  /// Hydrates the top lists from disk on startup.
  Future<void> init() async {
    await _refresh();
  }

  /// One counted play: [beat] always counts, [mix] counts too when the
  /// play happened inside a mix queue.
  Future<void> recordPlay(Beat beat, BeatMix? mix) async {
    await _store.recordBeatPlay(beat);
    // the shuffle-all queue is synthetic, keep it out of heavy rotation
    if (mix != null && mix.sourceId != shuffleAllSourceId) {
      await _store.recordMixPlay(mix, beat);
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    _topBeats = await _store.topBeats(limit: _topLimit);
    _topMixes = await _store.topMixes(limit: _topLimit);
    notifyListeners();
  }
}
