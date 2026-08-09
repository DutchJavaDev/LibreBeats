import 'dart:io';

import 'package:flutter/services.dart';
import 'package:liberated_beats/config/helpers.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:path_provider/path_provider.dart';

/// The offline media folder: <app support>/offline/tracks + offline/art.
/// App support because Documents gets backed up (Apple rejects re-downloadable
/// media there) and the cache dir can be wiped by the OS. The folder itself is
/// excluded from backup, see the android xml rules and the ios channel below.
class OfflineMediaStore {
  OfflineMediaStore({Future<String> Function()? rootProvider})
      : _rootProvider = rootProvider;

  static const tracksDir = 'offline/tracks';
  static const artDir = 'offline/art';

  final Future<String> Function()? _rootProvider;
  String? _root;

  /// App support dir, resolved once. Callers build absolute paths with it.
  Future<String> root() async {
    if (_root != null) return _root!;
    final provider = _rootProvider;
    _root = provider != null
        ? await provider()
        : (await getApplicationSupportDirectory()).path;
    return _root!;
  }

  Future<void> ensureDirs() async {
    final base = await root();
    await Directory('$base/$tracksDir').create(recursive: true);
    await Directory('$base/$artDir').create(recursive: true);
    await _excludeFromIosBackup('$base/offline');
  }

  // ios needs the do-not-back-up attribute set from native code, handled by
  // a tiny channel in the Runner. Reapplied every start, the flag can reset.
  Future<void> _excludeFromIosBackup(String path) async {
    if (!Platform.isIOS) return;
    try {
      await const MethodChannel('librebeats/backup')
          .invokeMethod('exclude', path);
    } catch (e) {
      PrintLog('backup exclusion failed: $e');
    }
  }

  String audioRelPath(Beat beat) => '$tracksDir/${_stem(beat)}.opus';

  String artRelPath(Beat beat) => '$artDir/${_stem(beat)}.jpg';

  // the mix cover, prefixed so it can never collide with a beat's art
  String mixArtRelPath(BeatMix mix) =>
      '$artDir/mix_${_fnv1a(mix.sourceId)}_${mix.id}.jpg';

  // server url + id, the url hashed because it makes a terrible filename
  String _stem(Beat beat) => '${_fnv1a(beat.sourceId)}_${beat.id}';

  Future<String> absolute(String relPath) async => '${await root()}/$relPath';

  Future<bool> exists(String relPath) async =>
      File(await absolute(relPath)).exists();

  Future<void> delete(String relPath) async {
    final file = File(await absolute(relPath));
    if (await file.exists()) await file.delete();
  }

  /// Total size in bytes of everything in the offline folders.
  Future<int> usedBytes() async {
    final base = await root();
    var total = 0;
    for (final dir in [tracksDir, artDir]) {
      final directory = Directory('$base/$dir');
      if (!await directory.exists()) continue;
      await for (final entry in directory.list()) {
        if (entry is File) total += await entry.length();
      }
    }
    return total;
  }

  /// Deletes files nothing points at anymore. [keep] holds relative paths.
  Future<int> sweep(Set<String> keep) async {
    final base = await root();
    var removed = 0;
    for (final dir in [tracksDir, artDir]) {
      final directory = Directory('$base/$dir');
      if (!await directory.exists()) continue;
      await for (final entry in directory.list()) {
        if (entry is! File) continue;
        final name = entry.uri.pathSegments.last;
        if (!keep.contains('$dir/$name')) {
          await entry.delete();
          removed++;
        }
      }
    }
    return removed;
  }

  // stable across runs and platforms, String.hashCode is neither
  static String _fnv1a(String input) {
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
