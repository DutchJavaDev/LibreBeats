import 'dart:io';

import 'package:flutter/material.dart';
import 'package:liberated_beats/config/helpers.dart';
import 'package:liberated_beats/data/liked_store.dart';
import 'package:liberated_beats/data/offline_media_store.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/services/beat_download_service.dart';

/// Liked beats and liked beatmixes: the record goes in right away (the
/// heart flips instantly), downloads follow and flip states to done.
/// Files are shared by identity, a beat liked on its own and inside a
/// liked mix exists once on disk, deletion only happens when no owner is
/// left. Everything liked keeps playing after its server is removed.
class LikedProvider extends ChangeNotifier {
  LikedProvider(this._store, this._files, this._downloader);

  final LikedStore _store;
  final OfflineMediaStore _files;
  final MediaDownloader _downloader;

  List<LikedBeat> _liked = [];
  List<LikedMix> _likedMixes = [];
  String _root = '';
  bool _loaded = false;
  int _offlineBytes = 0;

  List<LikedBeat> get liked => _liked;

  List<LikedMix> get likedMixes => _likedMixes;

  int get count => _liked.length;

  int get mixCount => _likedMixes.length;

  int get downloadedCount => _liked.where((b) => b.downloaded).length;

  /// Total playtime of the liked songs, the liked screen shows it.
  Duration get likedDuration =>
      _liked.fold(Duration.zero, (sum, b) => sum + b.duration);

  // beats and mix tracks together, what the storage card shows
  int get totalTrackCount =>
      count + _likedMixes.fold(0, (n, m) => n + m.beats.length);

  int get totalDownloadedCount =>
      downloadedCount + _likedMixes.fold(0, (n, m) => n + m.downloadedCount);

  /// Whether any liked mix has at least one track on disk, the library
  /// screen's shuffle-all pill keys off this.
  bool get hasDownloadedMixBeats =>
      _likedMixes.any((m) => m.downloadedCount > 0);

  int get pendingTrackCount => _stateCount('pending');

  int get failedTrackCount => _stateCount('failed');

  int _stateCount(String state) =>
      _liked.where((b) => b.state == state).length +
      _likedMixes.fold(
          0, (n, m) => n + m.beats.where((b) => b.state == state).length);

  /// What the downloads (audio + thumbnails) take up on disk.
  int get offlineBytes => _offlineBytes;

  bool get isLoaded => _loaded;

  bool get hasAnything => count > 0 || mixCount > 0;

  bool isLiked(String key) => _liked.any((b) => b.key == key);

  bool isMixLiked(String key) => _likedMixes.any((m) => m.key == key);

  /// Called once on startup: dirs, hydrate, then cleanup + retries.
  Future<void> init() async {
    await _files.ensureDirs();
    _root = await _files.root();
    _liked = await _store.all();
    _likedMixes = await _store.allMixes();
    _loaded = true;
    await _refreshBytes();
    await _maintenance();
  }

  LikedBeat _recordFor(Beat beat, DateTime likedAt) => LikedBeat(
        id: beat.id,
        sourceId: beat.sourceId,
        title: beat.title,
        artist: beat.artist,
        thumbnailUrl: beat.thumbnailUrl,
        streamingUrl: beat.audioUrl ?? '',
        duration: beat.duration,
        likedAt: likedAt,
        state: 'pending',
        audioPath: _files.audioRelPath(beat),
        artPath: _files.artRelPath(beat),
        mixTitle: beat.mixTitle,
      );

  Future<void> toggleLike(Beat beat) async {
    if (isLiked(beat.key)) return _unlike(beat.key);

    final record = _recordFor(beat, DateTime.now());
    await _store.put(record);
    _liked.insert(0, record);
    notifyListeners();

    await _download(record);
  }

  Future<void> toggleLikeMix(BeatMix mix) async {
    if (isMixLiked(mix.key)) return _unlikeMix(mix.key);

    final beats = mix.beats ?? const <Beat>[];
    if (beats.isEmpty) return;

    final likedAt = DateTime.now();
    final record = LikedMix(
      id: mix.id,
      sourceId: mix.sourceId,
      title: mix.title,
      thumbnailUrl: mix.thumbnailUrl,
      artPath: _files.mixArtRelPath(mix),
      likedAt: likedAt,
      beats: [
        // stamp the owning mix on beats that do not carry one yet
        for (final b in beats)
          _recordFor(
              b.mixTitle == null ? b.copyWith(mixTitle: mix.title) : b, likedAt)
      ],
    );
    await _store.putMix(record);
    _likedMixes.insert(0, record);
    notifyListeners();

    await _downloadMix(record);
  }

  // downloads audio (skipped when another owner already put it on disk)
  // and art, returns the resulting state
  Future<String> _fetchFiles(LikedBeat record) async {
    var state = 'failed';
    if (await _files.exists(record.audioPath)) {
      state = 'done';
    } else if (record.streamingUrl.startsWith('http')) {
      final ok = await _downloader.fetch(record.streamingUrl,
          OfflineMediaStore.tracksDir, record.audioPath.split('/').last);
      state = ok ? 'done' : 'failed';
    }
    // art is best effort, a missing thumbnail never fails the beat
    if (record.thumbnailUrl.startsWith('http') &&
        !await _files.exists(record.artPath)) {
      await _downloader.fetch(record.thumbnailUrl, OfflineMediaStore.artDir,
          record.artPath.split('/').last);
    }
    return state;
  }

  Future<void> _download(LikedBeat record) async {
    final state = await _fetchFiles(record);

    // un-liked while downloading: drop the files instead of resurrecting
    if (await _store.find(record.key) == null) {
      await _deleteIfUnowned(record.audioPath);
      await _deleteIfUnowned(record.artPath);
      await _refreshBytes();
      return;
    }

    final updated = record.withState(state);
    await _store.put(updated);
    final i = _liked.indexWhere((b) => b.key == record.key);
    if (i >= 0) _liked[i] = updated;
    await _refreshBytes();
  }

  Future<void> _downloadMix(LikedMix mix) async {
    // the cover, best effort
    if (mix.thumbnailUrl.startsWith('http') &&
        !await _files.exists(mix.artPath)) {
      await _downloader.fetch(mix.thumbnailUrl, OfflineMediaStore.artDir,
          mix.artPath.split('/').last);
    }

    var current = mix;
    for (final beatKey in [for (final b in mix.beats) b.key]) {
      // un-liked while downloading: clean up and stop
      final latest = await _store.findMix(mix.key);
      if (latest == null) {
        await _deleteIfUnowned(current.artPath);
        for (final b in current.beats) {
          await _deleteIfUnowned(b.audioPath);
          await _deleteIfUnowned(b.artPath);
        }
        await _refreshBytes();
        return;
      }
      current = latest;

      final beat = current.beats.firstWhere((b) => b.key == beatKey);
      if (beat.downloaded) continue;

      final state = await _fetchFiles(beat);
      current = current.withBeats([
        for (final b in current.beats)
          b.key == beatKey ? b.withState(state) : b
      ]);
      await _store.putMix(current);
      final i = _likedMixes.indexWhere((m) => m.key == current.key);
      if (i >= 0) _likedMixes[i] = current;
      await _refreshBytes(); // live progress in library and settings
    }
  }

  Future<void> _unlike(String key) async {
    final record = _liked.firstWhere((b) => b.key == key);
    await _store.remove(key);
    _liked.removeWhere((b) => b.key == key);
    notifyListeners();
    await _deleteIfUnowned(record.audioPath);
    await _deleteIfUnowned(record.artPath);
    await _refreshBytes();
  }

  Future<void> _unlikeMix(String key) async {
    final record = _likedMixes.firstWhere((m) => m.key == key);
    await _store.removeMix(key);
    _likedMixes.removeWhere((m) => m.key == key);
    notifyListeners();
    await _deleteIfUnowned(record.artPath);
    for (final b in record.beats) {
      await _deleteIfUnowned(b.audioPath);
      await _deleteIfUnowned(b.artPath);
    }
    await _refreshBytes();
  }

  // a file stays as long as any liked beat or liked mix still points at it,
  // the caller removes its own record from the lists first
  bool _ownedElsewhere(String relPath) =>
      _liked.any((b) => b.audioPath == relPath || b.artPath == relPath) ||
      _likedMixes.any((m) =>
          m.artPath == relPath ||
          m.beats.any((b) => b.audioPath == relPath || b.artPath == relPath));

  Future<void> _deleteIfUnowned(String relPath) async {
    if (!_ownedElsewhere(relPath)) await _files.delete(relPath);
  }

  /// The [Beat] for a liked record. Keeps the remote urls so history and
  /// caches never persist a device path, the downloaded file comes in
  /// through [localAudioFor] at play time.
  Beat beatFor(LikedBeat record) {
    final artFile = File('$_root/${record.artPath}');
    return Beat(
      id: record.id,
      sourceId: record.sourceId,
      title: record.title,
      artist: record.artist,
      thumbnailUrl: record.thumbnailUrl,
      localArtPath: artFile.existsSync() ? artFile.path : null,
      duration: record.duration,
      color: sampleTracks.first.color,
      audioUrl: record.streamingUrl,
      mixTitle: record.mixTitle,
    );
  }

  /// The [BeatMix] for a liked mix record, ready for the beatmix dialog.
  BeatMix mixFor(LikedMix record) => BeatMix(
        id: record.id,
        sourceId: record.sourceId,
        title: record.title,
        thumbnailUrl: record.thumbnailUrl,
        trackCount: record.beats.length,
        beats: [for (final b in record.beats) beatFor(b)],
      );

  /// One queue over every downloaded track in the liked mixes, deduped by
  /// key (a beat can sit in several mixes, one file on disk). Lives in
  /// memory only, shuffling is the player's job. Liked Songs stays out,
  /// it is its own queue. Null while nothing is on disk.
  BeatMix? shuffleAllMix() {
    final seen = <String>{};
    final beats = [
      for (final mix in _likedMixes)
        for (final b in mix.beats)
          if (b.downloaded && seen.add(b.key)) beatFor(b)
    ];
    if (beats.isEmpty) return null;
    return BeatMix(
      id: 0,
      sourceId: shuffleAllSourceId,
      title: 'All playlists',
      thumbnailUrl: '',
      trackCount: beats.length,
      beats: beats,
    );
  }

  /// The mix cover on disk, null when it is not there (yet).
  String? mixArtFor(LikedMix record) {
    final file = File('$_root/${record.artPath}');
    return file.existsSync() ? file.path : null;
  }

  /// Whether the audio for [key] is on disk, through any like.
  bool isDownloaded(String key) => localAudioFor(key) != null;

  /// The file the player should use for [key], null when nothing liked
  /// has it downloaded or the file is gone.
  String? localAudioFor(String key) {
    String? check(LikedBeat record) {
      if (!record.downloaded) return null;
      final path = '$_root/${record.audioPath}';
      return File(path).existsSync() ? path : null;
    }

    for (final record in _liked) {
      if (record.key == key) {
        final path = check(record);
        if (path != null) return path;
      }
    }
    for (final mix in _likedMixes) {
      for (final record in mix.beats) {
        if (record.key == key) {
          final path = check(record);
          if (path != null) return path;
        }
      }
    }
    return null;
  }

  /// Settings: wipe every liked beat, every liked mix and all their files.
  Future<void> clearAll() async {
    await _store.clear();
    _liked = [];
    _likedMixes = [];
    notifyListeners();
    // empty keep set, sweeps both offline folders clean
    await _files.sweep(const {});
    await _refreshBytes();
  }

  Future<void> _refreshBytes() async {
    _offlineBytes = await _files.usedBytes();
    notifyListeners();
  }

  // done records whose file vanished get re-downloaded, pending/failed ones
  // get another attempt, files no record points at get deleted
  Future<void> _maintenance() async {
    final keep = <String>{};
    final retryBeats = <LikedBeat>[];
    final retryMixes = <String>[];

    for (var record in _liked) {
      if (record.downloaded && !await _files.exists(record.audioPath)) {
        record = record.withState('pending');
        await _store.put(record);
        final i = _liked.indexWhere((b) => b.key == record.key);
        if (i >= 0) _liked[i] = record;
      }
      keep.add(record.audioPath);
      keep.add(record.artPath);
      if (!record.downloaded) retryBeats.add(record);
    }

    for (var mix in _likedMixes) {
      final beats = <LikedBeat>[];
      var changed = false;
      for (final b in mix.beats) {
        if (b.downloaded && !await _files.exists(b.audioPath)) {
          beats.add(b.withState('pending'));
          changed = true;
        } else {
          beats.add(b);
        }
        keep.add(b.audioPath);
        keep.add(b.artPath);
      }
      keep.add(mix.artPath);
      if (changed) {
        mix = mix.withBeats(beats);
        await _store.putMix(mix);
        final i = _likedMixes.indexWhere((m) => m.key == mix.key);
        if (i >= 0) _likedMixes[i] = mix;
      }
      if (!mix.complete) retryMixes.add(mix.key);
    }

    final removed = await _files.sweep(keep);
    if (removed > 0) PrintLog('offline sweep removed $removed orphan files');
    notifyListeners();

    for (final record in retryBeats) {
      await _download(record);
    }
    for (final key in retryMixes) {
      final mix = await _store.findMix(key);
      if (mix != null) await _downloadMix(mix);
    }
  }
}
