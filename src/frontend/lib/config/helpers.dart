import 'dart:convert';

import 'package:duration/duration.dart';
import 'package:flutter/foundation.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/models/store_models.dart';

typedef VoidCallbackUpdateProgress = void Function(double, Beat);

// ignore: non_constant_identifier_names
void PrintLog(Object? object) {
  if (kDebugMode) {
    print("[LIBRE-BEATS]: $object");
  } else {
    // Write to a log file or send to a logging service in production
  }
}

Map<String, dynamic> playStateToJson(PlayState? state) => {
      'current_beat': beatToJson(state?.currentPlayingBeat),
      'current_duration': state?.currentDuration.toString(),
      'current_beat_mix': beatMixToJson(state?.currentBeatMix),
      'current_queue': state?.currentQueue.map((b) => beatToJson(b)).toList()
    };

// same field names as the catalog cache, plus the source server
Map<String, dynamic> beatToJson(Beat? b) => {
      'id': b?.id,
      'sourceid': b?.sourceId,
      'title': b?.title,
      'artist': b?.artist,
      'thumbnailurl': b?.thumbnailUrl,
      'streamingurl': b?.audioUrl,
      'duration': b?.duration.inSeconds,
      'mixtitle': b?.mixTitle,
    };

Map<String, dynamic> beatMixToJson(BeatMix? b) => {
      'id': b?.id,
      'sourceid': b?.sourceId,
      'title': b?.title,
      'thumbnailurl': b?.thumbnailUrl,
      'trackcount': b?.trackCount,
      'beats': b?.beats!.map((b) => beatToJson(b)).toList()
    };

Beat beatFromJson(dynamic rawJson) => Beat(
      id: rawJson['id'],
      sourceId: rawJson['sourceid'] as String? ?? 'sample',
      title: rawJson['title'] as String,
      artist: rawJson['artist'] as String? ?? '',
      thumbnailUrl: rawJson['thumbnailurl'] as String? ?? '',
      duration: Duration(seconds: rawJson['duration'] as int? ?? 0),
      color:
          gradientForKey('${rawJson['sourceid'] ?? 'sample'}:${rawJson['id']}'),
      audioUrl: rawJson['streamingurl'] as String?,
      // entries saved before the subtitle rule have no mix title
      mixTitle: rawJson['mixtitle'] as String?,
    );

BeatMix beatMixFromJson(dynamic rawJson) => BeatMix(
    id: rawJson['id'],
    title: rawJson['title'] as String,
    thumbnailUrl: rawJson['thumbnailurl'] as String? ?? '',
    trackCount: rawJson['trackcount'] as int,
    beats: (jsonDecode(rawJson['beats']) as Iterable)
        .map((b) => beatFromJson(b))
        .toList());

PlayState playStateFromJson(dynamic rawJson) => PlayState(
    currentPlayingBeat: beatFromJson(rawJson['current_beat']),
    currentDuration: parseTime(rawJson['current_duration']),
    currentBeatMix: beatMixFromJsonState(rawJson['current_beat_mix']),
    currentQueue: (rawJson['current_queue'] as List<dynamic>)
        .map((b) => beatFromJson(b))
        .toList());

BeatMix beatMixFromJsonState(dynamic rawJson) => BeatMix(
    id: rawJson['id'] ?? -5,
    title: rawJson['title'] ?? '',
    thumbnailUrl: rawJson['thumbnailurl'] as String? ?? '',
    trackCount: rawJson['trackcount'] ?? -5,
    beats: ((rawJson['beats'] ?? []) as Iterable)
        .map((b) => beatFromJson(b))
        .toList());
