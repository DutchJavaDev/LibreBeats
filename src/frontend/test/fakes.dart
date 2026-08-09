import 'dart:async';
import 'dart:io';

import 'package:liberated_beats/data/beat_repository.dart';
import 'package:liberated_beats/data/beatmix_repository.dart';
import 'package:liberated_beats/data/server_registry.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/services/beat_download_service.dart';

class FakeBeatMixRepository extends BeatMixRepository {
  FakeBeatMixRepository(super.registry);

  final Map<String, List<BeatMix>> responses = {};
  final Set<String> failing = {};
  int fetchCount = 0;

  // canned live search results, filtered by title like the real query
  final List<BeatMix> searchResults = [];
  int searchCount = 0;

  @override
  Future<List<BeatMix>> fetchMenuFromServer(ServerConnection server) async {
    fetchCount++;
    if (failing.contains(server.url)) throw Exception('server down');
    return List.of(responses[server.url] ?? const []);
  }

  @override
  Future<List<BeatMix>> findByTitle(String query) async {
    searchCount++;
    final q = query.toLowerCase();
    return searchResults
        .where((m) => m.title.toLowerCase().contains(q))
        .toList();
  }
}

class FakeBeatRepository extends BeatRepository {
  FakeBeatRepository(super.registry);

  // canned live search results, filtered by title like the real query
  final List<Beat> searchResults = [];
  int searchCount = 0;

  @override
  Future<List<Beat>> findByTitle(String query) async {
    searchCount++;
    final q = query.toLowerCase();
    return searchResults
        .where((b) => b.title.toLowerCase().contains(q))
        .toList();
  }
}

/// Writes a marker file where the real downloader would place it.
class FakeDownloader implements MediaDownloader {
  FakeDownloader(this.root);

  final String root;
  bool failing = false;
  int fetchCount = 0;
  Completer<void>? gate; // when set, fetches wait on it

  @override
  Future<bool> fetch(String url, String directory, String filename) async {
    fetchCount++;
    if (gate != null) await gate!.future;
    if (failing) return false;
    final file = File('$root/$directory/$filename');
    await file.parent.create(recursive: true);
    await file.writeAsString('audio-bytes');
    return true;
  }
}

BeatMix mix(String sourceId, int id,
        [String? title, List<Beat> beats = const []]) =>
    BeatMix(
      id: id,
      sourceId: sourceId,
      title: title ?? 'Mix $id',
      thumbnailUrl: '',
      trackCount: beats.length,
      beats: beats,
    );

Beat beat(String sourceId, int id, [String? title]) => Beat(
      id: id,
      sourceId: sourceId,
      title: title ?? 'Beat $id',
      artist: 'artist',
      duration: const Duration(seconds: 1),
      color: sampleTracks.first.color,
    );
