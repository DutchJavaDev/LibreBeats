// Tracks the current beat, beatmix and volumne when changed
// On app startup it will load the last played beat at the last played position

import 'dart:convert';

import 'package:liberated_beats/config/helpers.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duration/duration.dart';

class PlayStateStore {
  static const _playStateKey = 'librebeats_play_state';
  static const _lastBeatKey = 'librebeats_last_beat';
  static const _lastBeatQueueKey = 'librebeats_last_beat_queue';
  static const _lastKnowBeatMixKey = 'librebeats_last_know_beat_mix';
  static const _lastBeatElapsedDurationKey =
      'librebeats_last_beat_elapsed_duration';
  
  static PlayStateStore? _playStoreInstance = null;

  PlayStateStore._(){}
  PlayStateStore._internal(){}

  Beat? _lastPlayedBeat;
  Beat? get lastPlayedBeat => _lastPlayedBeat;

  List<Beat?> _lastKnowQueue = [];
  List<Beat?> get lastKnowQueue => _lastKnowQueue;

  BeatMix? _lastPlayedBeatMix;
  BeatMix? get lastPlayedBeatMix => _lastPlayedBeatMix;

  Duration? _lastPlayedBeatElapsedDuration;
  Duration? get lastPlayedBeatElapsedDuration =>
      _lastPlayedBeatElapsedDuration ?? Duration.zero;

  Future<void> _load() async {
    final pref = SharedPreferencesAsync();

    final hasKey = await pref.containsKey(_playStateKey);

    if (!hasKey) {
      // Nothing has been saved / first launch
      return;
    }

    final rawState = jsonDecode(await pref.getString(_playStateKey) ?? "")
        as Map<String, dynamic>;

    if (rawState[_lastBeatKey] != null && jsonDecode(rawState[_lastBeatKey])['id'] is int) {
      
      PrintLog(rawState);

      _lastPlayedBeat = beatFromJson(jsonDecode(rawState[_lastBeatKey]));

      _lastKnowQueue = (jsonDecode(rawState[_lastBeatQueueKey]) as Iterable)!
          .map((b) => beatFromJson(b))
          .toList();

      final _rbeatMix = jsonDecode(rawState[_lastKnowBeatMixKey]);

      if(_rbeatMix['id'] != null)
      {
        _lastPlayedBeatMix = beatMixFromJson(_rbeatMix);
      }

      _lastPlayedBeatElapsedDuration =
          parseTime(rawState[_lastBeatElapsedDurationKey] as String);
    }
  }

  Future<void> updateElapsed(Duration newElapsed, {bool force = false}) async {
    _lastPlayedBeatElapsedDuration = newElapsed;

    if (force) {
      PrintLog("Saving elapsed time: ${newElapsed}");
      await _updateStore(_lastPlayedBeat, _lastPlayedBeatElapsedDuration,
          _lastKnowQueue, _lastPlayedBeatMix);
      return;
    }
    // We don't want to be writting every second to disk.
  }

  Future<void> setLastPlayedBeatAndBeatMix(Beat? beat,
      Duration? elapsedDuration, List<Beat?> queue, BeatMix? beatMix) async {
    _lastPlayedBeat = beat;
    _lastKnowQueue = queue;
    _lastPlayedBeatElapsedDuration = elapsedDuration;
    _lastPlayedBeatMix = beatMix;

    await _updateStore(beat, elapsedDuration, queue, beatMix);
  }

  Future<void> _updateStore(Beat? beat, Duration? elapsedDuration,
      List<Beat?>? queue, BeatMix? beatMix) async {
    Map<String, String> state = {
      _lastBeatKey: jsonEncode(beatToJson(beat)),
      _lastBeatElapsedDurationKey: elapsedDuration.toString(),
      _lastBeatQueueKey:
          jsonEncode(queue?.map((beat) => beatToJson(beat!)).toList()),
      _lastKnowBeatMixKey: jsonEncode(beatMixToJson(beatMix))
    };

    final pref = SharedPreferencesAsync();

    await pref.setString(_playStateKey, jsonEncode(state));
  }

  static Future<PlayStateStore> instance() async {

    if(_playStoreInstance != null)
    {
      return _playStoreInstance!;
    }

    _playStoreInstance = PlayStateStore._internal();

    await _playStoreInstance!._load();

    return _playStoreInstance!;
  }
}
