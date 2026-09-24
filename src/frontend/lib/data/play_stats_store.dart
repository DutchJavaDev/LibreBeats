import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

import '../models/beat_models.dart';

/// All-time play count for one beat. Carries a full metadata snapshot so
/// the On repeat row stays renderable and playable like a history entry,
/// refreshed on every counted play so it cannot go stale.
class BeatPlayStat {
  final Beat beat;
  final int plays;
  final DateTime lastPlayedAt;

  const BeatPlayStat({
    required this.beat,
    required this.plays,
    required this.lastPlayedAt,
  });

  // same field names as the history store where they overlap
  Map<String, Object?> toJson() => {
        'id': beat.id,
        'sourceid': beat.sourceId,
        'title': beat.title,
        'artist': beat.artist,
        'thumbnailurl': beat.thumbnailUrl,
        'streamingurl': beat.audioUrl,
        'duration': beat.duration.inSeconds,
        'mixtitle': beat.mixTitle,
        'plays': plays,
        'lastplayedat': lastPlayedAt.toIso8601String(),
      };

  static BeatPlayStat fromJson(Map<String, Object?> json) => BeatPlayStat(
        beat: Beat(
          id: json['id'] as int,
          sourceId: json['sourceid'] as String? ?? 'sample',
          title: json['title'] as String? ?? '',
          artist: json['artist'] as String? ?? '',
          thumbnailUrl: json['thumbnailurl'] as String? ?? '',
          duration: Duration(seconds: json['duration'] as int? ?? 0),
          color: gradientForKey('${json['sourceid'] ?? 'sample'}:${json['id']}'),
          audioUrl: json['streamingurl'] as String?,
          mixTitle: json['mixtitle'] as String?,
        ),
        plays: json['plays'] as int? ?? 0,
        lastPlayedAt: DateTime.tryParse(json['lastplayedat'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// All-time play count for one beatmix plus the distinct beats ever counted
/// from it, for the "X plays · Y songs" line on Heavy rotation.
class MixPlayStat {
  final int id;
  final String sourceId;
  final String title;
  final String thumbnailUrl;
  final int trackCount;
  final int plays;
  final List<String> beatKeys;
  final DateTime lastPlayedAt;

  const MixPlayStat({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.thumbnailUrl,
    required this.trackCount,
    required this.plays,
    required this.beatKeys,
    required this.lastPlayedAt,
  });

  String get key => '$sourceId:$id';

  int get distinctSongs => beatKeys.length;

  /// A displayable mix for [BrowseMixCard]; beats stay null, tapping the
  /// card looks the live mix up in the catalog.
  BeatMix toBeatMix() => BeatMix(
        id: id,
        sourceId: sourceId,
        title: title,
        thumbnailUrl: thumbnailUrl,
        trackCount: trackCount,
        beats: null,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'sourceid': sourceId,
        'title': title,
        'thumbnailurl': thumbnailUrl,
        'trackcount': trackCount,
        'plays': plays,
        'beatkeys': beatKeys,
        'lastplayedat': lastPlayedAt.toIso8601String(),
      };

  static MixPlayStat fromJson(Map<String, Object?> json) => MixPlayStat(
        id: json['id'] as int,
        sourceId: json['sourceid'] as String? ?? 'sample',
        title: json['title'] as String? ?? '',
        thumbnailUrl: json['thumbnailurl'] as String? ?? '',
        trackCount: json['trackcount'] as int? ?? 0,
        plays: json['plays'] as int? ?? 0,
        beatKeys: [
          for (final k in (json['beatkeys'] as List<dynamic>? ?? [])) '$k'
        ],
        lastPlayedAt: DateTime.tryParse(json['lastplayedat'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// All-time play counts on disk, a sembast database in the app support dir.
/// One record per beat and per mix, so storage stays bounded by the size of
/// the catalog actually listened to.
class PlayStatsStore {
  PlayStatsStore({Database? database}) : _database = database;

  Database? _database;
  static final _beats = stringMapStoreFactory.store('playbeat');
  static final _mixes = stringMapStoreFactory.store('playmix');

  Future<Database> _db() async {
    if (_database != null) return _database!;
    final dir = await getApplicationSupportDirectory();
    _database = await databaseFactoryIo.openDatabase(
        '${dir.path}/librebeats_play_stats.db');
    return _database!;
  }

  /// Counts one play of [beat]: plays + 1, metadata snapshot refreshed.
  Future<void> recordBeatPlay(Beat beat, {DateTime? at}) async {
    final db = await _db();
    final record = _beats.record(beat.key);
    final existing = await record.get(db);
    final plays = existing == null ? 0 : existing['plays'] as int? ?? 0;
    await record.put(
        db,
        BeatPlayStat(
          beat: beat,
          plays: plays + 1,
          lastPlayedAt: at ?? DateTime.now(),
        ).toJson());
  }

  /// Counts one play attributed to [mix]: plays + 1, [beat]'s key added to
  /// the distinct-songs set when it is new.
  Future<void> recordMixPlay(BeatMix mix, Beat beat, {DateTime? at}) async {
    final db = await _db();
    final record = _mixes.record(mix.key);
    final existing =
        await record.get(db).then((r) => r == null ? null : MixPlayStat.fromJson(r));
    final beatKeys = [...?existing?.beatKeys];
    if (!beatKeys.contains(beat.key)) beatKeys.add(beat.key);
    await record.put(
        db,
        MixPlayStat(
          id: mix.id,
          sourceId: mix.sourceId,
          title: mix.title,
          thumbnailUrl: mix.thumbnailUrl,
          trackCount: mix.trackCount,
          plays: (existing?.plays ?? 0) + 1,
          beatKeys: beatKeys,
          lastPlayedAt: at ?? DateTime.now(),
        ).toJson());
  }

  /// Most played first, most recently played breaks ties.
  Future<List<BeatPlayStat>> topBeats({int limit = 10}) async {
    final rows = await _beats.find(await _db(),
        finder: Finder(
            sortOrders: [SortOrder('plays', false), SortOrder('lastplayedat', false)],
            limit: limit));
    return [for (final r in rows) BeatPlayStat.fromJson(r.value)];
  }

  /// Most played first, most recently played breaks ties.
  Future<List<MixPlayStat>> topMixes({int limit = 10}) async {
    final rows = await _mixes.find(await _db(),
        finder: Finder(
            sortOrders: [SortOrder('plays', false), SortOrder('lastplayedat', false)],
            limit: limit));
    return [for (final r in rows) MixPlayStat.fromJson(r.value)];
  }

  Future<void> clear() async {
    final db = await _db();
    await _beats.delete(db);
    await _mixes.delete(db);
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
