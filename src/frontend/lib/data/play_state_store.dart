// Tracks the current beat, beatmix and volumne when changed
// On app startup it will load the last played beat at the last played position

import 'dart:convert';

import 'package:liberated_beats/config/helpers.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlayStateStore {

  static const _playStateKey = 'librebeats_play_state';

  final _saveIntervalMs = 100;

  Beat? _lastPlayedBeat;
  Beat? get lastPlayedBeat => _lastPlayedBeat;
  
  List<Beat?> _lastKnowQueue = [];
  List<Beat?> get lastKnowQueue => _lastKnowQueue;

  BeatMix? _lastPlayedBeatMix;
  BeatMix? get lastPlayedBeatMix => _lastPlayedBeatMix;

  double? _lastPlayedBeatElapsed;
  double? get lastPlayedBeatElapsed => _lastPlayedBeatElapsed;

  Future<void> load() async {    
    final pref = SharedPreferencesAsync();

    final hasKey = await pref.containsKey(_playStateKey);

    if(!hasKey)
    {
      // Nothing has been saved / first launch
      return;      
    }

    final rawState = jsonDecode(await pref.getString(_playStateKey) ?? "");

    PrintLog(rawState);

    _lastPlayedBeat = _beatFromJson(jsonDecode(rawState["last_beat"]));

    //_lastKnowQueue = jsonDecode(rawState["last_beat_queue"]) as List<Beat?>;

    //_lastPlayedBeatMix = jsonDecode(rawState["last_know_beat_mix"]) as BeatMix?;

    _lastPlayedBeatElapsed = double.parse(rawState["last_beat_elapsed"]);
  }

  Future<void> updateElapsed(double newElapsed, {bool force = false}) async
  {
    _lastPlayedBeatElapsed = newElapsed;

    if(force)
    {
      await _updateStore(_lastPlayedBeat, _lastPlayedBeatElapsed, _lastKnowQueue, _lastPlayedBeatMix);
      return;
    }
    // We don't want to be writting every second to disk.
  }

  Future<void> setLastPlayedBeatAndBeatMix(Beat? beat, double? elapsed, List<Beat?> queue, BeatMix? beatMix) async
  {
    _lastPlayedBeat = beat;
    _lastKnowQueue = queue;
    _lastPlayedBeatElapsed = elapsed;
    _lastPlayedBeatMix = beatMix;
    
    await _updateStore(beat, elapsed, queue, beatMix);
  }

  Future<void> _updateStore(Beat? beat, double? elapsed, List<Beat?> queue, BeatMix? beatMix) async {

    final _queue = queue.map((beat) => _beatToJson(beat)).toList();

    Map<String, String> state = {
      "last_beat": jsonEncode(_beatToJson(beat)),
      "last_beat_elapsed": elapsed.toString(),
      "last_beat_queue": jsonEncode(_queue),
      //"last_know_beat_mix": jsonEncode(beatMix)
    };

    final pref = SharedPreferencesAsync();

    await pref.setString(_playStateKey, jsonEncode(state));
  }

    // same field names as the catalog cache, plus the source server
  Map<String, dynamic> _beatToJson(Beat? b) => {
        'id': b!.id,
        'sourceid': b.sourceId,
        'title': b.title,
        'artist': b.artist,
        'thumbnailurl': b.thumbnailUrl,
        'streamingurl': b.audioUrl,
        'duration': b.duration.inSeconds,
        'mixtitle': b.mixTitle,
      };

  Beat _beatFromJson(dynamic json) => Beat(
        id: json['id'] as int,
        sourceId: json['sourceid'] as String? ?? 'sample',
        title: json['title'] as String,
        artist: json['artist'] as String? ?? '',
        thumbnailUrl: json['thumbnailurl'] as String? ?? '',
        duration: Duration(seconds: json['duration'] as int? ?? 0),
        color: gradientForKey('${json['sourceid'] ?? 'sample'}:${json['id']}'),
        audioUrl: json['streamingurl'] as String?,
        // entries saved before the subtitle rule have no mix title
        mixTitle: json['mixtitle'] as String?,
      );
}