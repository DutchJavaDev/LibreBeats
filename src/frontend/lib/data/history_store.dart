import 'dart:convert';

import 'package:liberated_beats/config/helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/beat_models.dart';

/// Saves the play history (last 10 played beats, newest first) to
/// shared_preferences so it survives an app restart.
class HistoryStore {
  static const _historyKey = 'librebeats_play_history';

  Future<List<Beat>> load() async {
    final prefs = SharedPreferencesAsync();
    final raw = await prefs.getString(_historyKey);
    if (raw == null) return [];

    try {
      final json = jsonDecode(raw) as List<dynamic>;
      return [for (final b in json) beatFromJson(b)];
    } catch (_) {
      return []; // corrupt history, just start over
    }
  }

  Future<void> save(List<Beat> beats) async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString(
        _historyKey, jsonEncode([for (final b in beats) beatToJson(b)]));
  }

  Future<void> clear() async {
    final prefs = SharedPreferencesAsync();
    await prefs.remove(_historyKey);
  }
}
