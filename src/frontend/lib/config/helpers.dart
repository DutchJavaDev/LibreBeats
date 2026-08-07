import 'package:flutter/foundation.dart';
import 'package:liberated_beats/models/beat_models.dart';

typedef VoidCallbackUpdateProgress = void Function(double, Beat);

// ignore: non_constant_identifier_names
void PrintLog(Object? object) {
  if (kDebugMode) {
    print("[LIBRE-BEATS]: $object");
  } else {
    // Write to a log file or send to a logging service in production
  }
}
