import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

/// One liked beat. Carries a full metadata snapshot so it stays playable
/// after its server is removed. Paths are relative to the app support dir,
/// absolute paths go stale on iOS (container id changes between updates).
class LikedBeat {
  final int id;
  final String sourceId;
  final String title;
  final String artist;
  final String thumbnailUrl; // remote
  final String streamingUrl; // remote
  final Duration duration;
  final DateTime likedAt;
  final String state; // pending | done | failed
  final String audioPath; // relative
  final String artPath; // relative

  /// The mix the beat came from when it was liked, null for standalone
  /// likes and records from before the subtitle rule.
  final String? mixTitle;

  const LikedBeat({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    required this.streamingUrl,
    required this.duration,
    required this.likedAt,
    required this.state,
    required this.audioPath,
    required this.artPath,
    this.mixTitle,
  });

  String get key => '$sourceId:$id';

  bool get downloaded => state == 'done';

  LikedBeat withState(String state) => LikedBeat(
        id: id,
        sourceId: sourceId,
        title: title,
        artist: artist,
        thumbnailUrl: thumbnailUrl,
        streamingUrl: streamingUrl,
        duration: duration,
        likedAt: likedAt,
        state: state,
        audioPath: audioPath,
        artPath: artPath,
        mixTitle: mixTitle,
      );

  // same field names as the catalog cache where they overlap
  Map<String, Object?> toJson() => {
        'id': id,
        'sourceid': sourceId,
        'title': title,
        'artist': artist,
        'thumbnailurl': thumbnailUrl,
        'streamingurl': streamingUrl,
        'duration': duration.inSeconds,
        'likedat': likedAt.toIso8601String(),
        'state': state,
        'audiopath': audioPath,
        'artpath': artPath,
        'mixtitle': mixTitle,
      };

  static LikedBeat fromJson(Map<String, Object?> json) => LikedBeat(
        id: json['id'] as int,
        sourceId: json['sourceid'] as String? ?? 'sample',
        title: json['title'] as String? ?? '',
        artist: json['artist'] as String? ?? '',
        thumbnailUrl: json['thumbnailurl'] as String? ?? '',
        streamingUrl: json['streamingurl'] as String? ?? '',
        duration: Duration(seconds: json['duration'] as int? ?? 0),
        likedAt: DateTime.tryParse(json['likedat'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        state: json['state'] as String? ?? 'pending',
        audioPath: json['audiopath'] as String? ?? '',
        artPath: json['artpath'] as String? ?? '',
        mixTitle: json['mixtitle'] as String?,
      );
}

/// A liked beatmix: the mix metadata plus a snapshot of its beats, each
/// with its own download state. The snapshot keeps the mix playable after
/// its server is gone. Beats here do not show up in Liked Songs.
class LikedMix {
  final int id;
  final String sourceId;
  final String title;
  final String thumbnailUrl; // remote
  final String artPath; // relative, the mix cover on disk
  final DateTime likedAt;
  final List<LikedBeat> beats;

  const LikedMix({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.thumbnailUrl,
    required this.artPath,
    required this.likedAt,
    required this.beats,
  });

  String get key => '$sourceId:$id';

  int get downloadedCount => beats.where((b) => b.downloaded).length;

  bool get complete => beats.every((b) => b.downloaded);

  LikedMix withBeats(List<LikedBeat> beats) => LikedMix(
        id: id,
        sourceId: sourceId,
        title: title,
        thumbnailUrl: thumbnailUrl,
        artPath: artPath,
        likedAt: likedAt,
        beats: beats,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'sourceid': sourceId,
        'title': title,
        'thumbnailurl': thumbnailUrl,
        'artpath': artPath,
        'likedat': likedAt.toIso8601String(),
        'beats': [for (final b in beats) b.toJson()],
      };

  static LikedMix fromJson(Map<String, Object?> json) => LikedMix(
        id: json['id'] as int,
        sourceId: json['sourceid'] as String? ?? 'sample',
        title: json['title'] as String? ?? '',
        thumbnailUrl: json['thumbnailurl'] as String? ?? '',
        artPath: json['artpath'] as String? ?? '',
        likedAt: DateTime.tryParse(json['likedat'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        beats: [
          for (final b in (json['beats'] as List<dynamic>? ?? []))
            LikedBeat.fromJson((b as Map).cast<String, Object?>())
        ],
      );
}

/// Liked beats and beatmixes on disk, a sembast database in the app
/// support dir.
class LikedStore {
  LikedStore({Database? database}) : _database = database;

  Database? _database;
  static final _records = stringMapStoreFactory.store('liked');
  static final _mixes = stringMapStoreFactory.store('likedmix');

  Future<Database> _db() async {
    if (_database != null) return _database!;
    final dir = await getApplicationSupportDirectory();
    _database = await databaseFactoryIo.openDatabase(
        '${dir.path}/librebeats_liked.db');
    return _database!;
  }

  /// Newest like first.
  Future<List<LikedBeat>> all() async {
    final rows = await _records.find(await _db(),
        finder: Finder(sortOrders: [SortOrder('likedat', false)]));
    return [for (final r in rows) LikedBeat.fromJson(r.value)];
  }

  Future<LikedBeat?> find(String key) async {
    final row = await _records.record(key).get(await _db());
    return row == null ? null : LikedBeat.fromJson(row);
  }

  Future<void> put(LikedBeat beat) async {
    await _records.record(beat.key).put(await _db(), beat.toJson());
  }

  Future<void> remove(String key) async {
    await _records.record(key).delete(await _db());
  }

  /// Newest liked mix first.
  Future<List<LikedMix>> allMixes() async {
    final rows = await _mixes.find(await _db(),
        finder: Finder(sortOrders: [SortOrder('likedat', false)]));
    return [for (final r in rows) LikedMix.fromJson(r.value)];
  }

  Future<LikedMix?> findMix(String key) async {
    final row = await _mixes.record(key).get(await _db());
    return row == null ? null : LikedMix.fromJson(row);
  }

  Future<void> putMix(LikedMix mix) async {
    await _mixes.record(mix.key).put(await _db(), mix.toJson());
  }

  Future<void> removeMix(String key) async {
    await _mixes.record(key).delete(await _db());
  }

  Future<void> clear() async {
    final db = await _db();
    await _records.delete(db);
    await _mixes.delete(db);
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
