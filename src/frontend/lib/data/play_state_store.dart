// Tracks the current beat, beatmix and volumne when changed
// On app startup it will load the last played beat at the last played position

import 'dart:convert';

import 'package:liberated_beats/config/helpers.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/models/store_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlayStateStore {
  static const _playStateKey = 'librebeats_play_state';

  static PlayStateStore? _playStoreInstance;

  PlayState? _playState;

  PlayStateStore._internal();

  Beat? _lastPlayedBeat;
  Beat? get lastPlayedBeat => _lastPlayedBeat;

  List<Beat?> _lastKnowQueue = [];
  List<Beat?> get lastKnowQueue => _lastKnowQueue;

  BeatMix? _lastPlayedBeatMix;
  BeatMix? get lastPlayedBeatMix => _lastPlayedBeatMix;

  Duration? _lastPlayedBeatElapsedDuration;
  Duration? get lastPlayedBeatElapsedDuration =>
      _lastPlayedBeatElapsedDuration ?? Duration.zero;

  double? _lastKnowVolume = 0.25;
  double? get lastKnowVolume => _lastKnowVolume;

  Future<void> _load() async {
    final pref = SharedPreferencesAsync();

    final hasKey = await pref.containsKey(_playStateKey);

    if (!hasKey) {
      // Nothing has been saved / first launch
      _playState = PlayState(
          currentPlayingBeat: null,
          currentDuration: Duration.zero,
          currentBeatMix: null,
          currentQueue: [],
          currentVolume: _lastKnowVolume);
      return;
    }

    final rawState = jsonDecode(await pref.getString(_playStateKey) ?? "")
        as Map<String, dynamic>;

    _playState = playStateFromJson(rawState);

    if (_playState != null && _playState!.currentPlayingBeat != null) {
      _lastPlayedBeat = _playState!.currentPlayingBeat;
      _lastPlayedBeatElapsedDuration = _playState!.currentDuration;
      _lastKnowQueue = _playState!.currentQueue;
      _lastPlayedBeatMix = _playState!.currentBeatMix;
      _lastKnowVolume = _playState!.currentVolume;
    } else {
      _playState = PlayState(
          currentPlayingBeat: null,
          currentDuration: Duration.zero,
          currentBeatMix: null,
          currentQueue: [],
          currentVolume: _lastKnowVolume);
    }
  }

  Future<void> updateElapsed(Duration newElapsed, {bool force = false}) async {
    _lastPlayedBeatElapsedDuration = newElapsed;

    if (force) {
      PrintLog("Saving elapsed time: $newElapsed");
      await _updateStore(_lastPlayedBeat, _lastPlayedBeatElapsedDuration,
          _lastKnowQueue, _lastKnowVolume, _lastPlayedBeatMix);
      return;
    }
  }

  Future<void> updateVolume(double newVolume) async {
    _lastKnowVolume = newVolume;

    await _updateStore(_lastPlayedBeat, _lastPlayedBeatElapsedDuration,
        _lastKnowQueue, _lastKnowVolume, _lastPlayedBeatMix);
  }

  Future<void> setLastPlayedBeatAndBeatMix(Beat? beat,
      Duration? elapsedDuration, List<Beat?> queue, BeatMix? beatMix) async {
    _lastPlayedBeat = beat;
    _lastKnowQueue = queue;
    _lastPlayedBeatElapsedDuration = elapsedDuration;
    _lastPlayedBeatMix = beatMix;

    await _updateStore(beat, elapsedDuration, queue, _lastKnowVolume, beatMix);
  }

  Future<void> _updateStore(Beat? beat, Duration? elapsedDuration,
      List<Beat?> queue, double? volume, BeatMix? beatMix) async {
    _playState!.currentPlayingBeat = beat;
    _playState!.currentDuration = elapsedDuration ?? Duration.zero;
    _playState!.currentBeatMix = beatMix;
    _playState!.currentQueue = queue;
    _playState!.currentVolume = _lastKnowVolume;

    final pref = SharedPreferencesAsync();

    final playState = playStateToJson(_playState);

    await pref.setString(_playStateKey, jsonEncode(playState));
  }

  static Future<PlayStateStore> instance() async {
    if (_playStoreInstance != null) {
      return _playStoreInstance!;
    }

    _playStoreInstance = PlayStateStore._internal();

    await _playStoreInstance!._load();

    return _playStoreInstance!;
  }
}
