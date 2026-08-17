import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/data/liked_store.dart';
import 'package:liberated_beats/data/offline_media_store.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/providers/liked_provider.dart';
import 'package:sembast/sembast_memory.dart';

import '../fakes.dart';

void main() {
  late Directory temp;
  late LikedStore store;
  late OfflineMediaStore files;
  late FakeDownloader downloader;
  late LikedProvider provider;

  Beat beat(int id, {String source = 'https://a.example.com'}) => Beat(
        id: id,
        sourceId: source,
        title: 'Beat $id',
        artist: 'artist',
        thumbnailUrl: 'https://a.example.com/art/$id.jpg',
        duration: const Duration(seconds: 90),
        color: sampleTracks.first.color,
        audioUrl: 'https://a.example.com/audio/$id.opus',
      );

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('liked_test');
    store = LikedStore(
        database: await newDatabaseFactoryMemory().openDatabase('liked.db'));
    files = OfflineMediaStore(rootProvider: () async => temp.path);
    downloader = FakeDownloader(temp.path);
    provider = LikedProvider(store, files, downloader);
    await provider.init();
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  test('like stores the record and downloads audio + art', () async {
    await provider.toggleLike(beat(1));

    final record = provider.liked.single;
    expect(record.state, 'done');
    expect(provider.isLiked(record.key), isTrue);
    expect(downloader.fetchCount, 2);
    expect(File('${temp.path}/${record.audioPath}').existsSync(), isTrue);
    expect(File('${temp.path}/${record.artPath}').existsSync(), isTrue);
  });

  test('unlike removes the record and both files', () async {
    await provider.toggleLike(beat(1));
    final record = provider.liked.single;

    await provider.toggleLike(beat(1));

    expect(provider.liked, isEmpty);
    expect(provider.isLiked('https://a.example.com:1'), isFalse);
    expect(File('${temp.path}/${record.audioPath}').existsSync(), isFalse);
    expect(File('${temp.path}/${record.artPath}').existsSync(), isFalse);
  });

  test('failed download keeps the like, init retries it', () async {
    downloader.failing = true;
    await provider.toggleLike(beat(1));
    expect(provider.liked.single.state, 'failed');

    // "restart": same db, downloads work again
    downloader.failing = false;
    final second = LikedProvider(store, files, downloader);
    await second.init();

    expect(second.liked.single.state, 'done');
  });

  test('unlike while the download runs does not resurrect the record',
      () async {
    downloader.gate = Completer<void>();
    final like = provider.toggleLike(beat(1));
    // the record is in before the download finishes
    while (provider.liked.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(provider.liked, hasLength(1));

    await provider.toggleLike(beat(1)); // unlike immediately
    downloader.gate!.complete();
    downloader.gate = null;
    await like;

    expect(provider.liked, isEmpty);
    expect(await store.all(), isEmpty);
    final tracks = Directory('${temp.path}/${OfflineMediaStore.tracksDir}');
    expect(tracks.listSync().whereType<File>(), isEmpty);
  });

  test('beats keep remote urls, the resolver points at the file', () async {
    await provider.toggleLike(beat(1));
    final record = provider.liked.single;

    // remote urls stay the identity so history never stores a device path
    final playable = provider.beatFor(record);
    expect(playable.audioUrl, 'https://a.example.com/audio/1.opus');
    expect(playable.thumbnailUrl, 'https://a.example.com/art/1.jpg');
    expect(playable.localArtPath, '${temp.path}/${record.artPath}');

    // the player asks per play and gets the downloaded file
    expect(provider.localAudioFor(record.key),
        '${temp.path}/${record.audioPath}');
  });

  test('resolver goes null when not downloaded, unliked or file gone',
      () async {
    downloader.failing = true;
    await provider.toggleLike(beat(1));
    expect(provider.localAudioFor('https://a.example.com:1'), isNull);

    downloader.failing = false;
    await provider.toggleLike(beat(2));
    final record = provider.liked.firstWhere((b) => b.id == 2);
    expect(provider.localAudioFor(record.key), isNotNull);

    // file vanishes from under a done record
    File('${temp.path}/${record.audioPath}').deleteSync();
    expect(provider.localAudioFor(record.key), isNull);

    // never liked at all
    expect(provider.localAudioFor('https://a.example.com:99'), isNull);
  });

  test('liked list survives a restart, newest first', () async {
    await provider.toggleLike(beat(1));
    await provider.toggleLike(beat(2));

    final second = LikedProvider(store, files, downloader);
    await second.init();

    expect([for (final b in second.liked) b.id], [2, 1]);
  });

  test('init sweeps orphan files and re-downloads missing ones', () async {
    await provider.toggleLike(beat(1));
    final record = provider.liked.single;

    // an orphan nothing points at, and the liked file goes missing
    final orphan = File('${temp.path}/${OfflineMediaStore.tracksDir}/zz.opus');
    await orphan.writeAsString('stray');
    File('${temp.path}/${record.audioPath}').deleteSync();

    final second = LikedProvider(store, files, downloader);
    await second.init();

    expect(orphan.existsSync(), isFalse);
    expect(second.liked.single.state, 'done');
    expect(File('${temp.path}/${record.audioPath}').existsSync(), isTrue);
  });

  test('likedDuration follows likes and unlikes', () async {
    expect(provider.likedDuration, Duration.zero);

    // the beat helper makes 90 second songs
    await provider.toggleLike(beat(1));
    await provider.toggleLike(beat(2));
    expect(provider.likedDuration, const Duration(seconds: 180));

    await provider.toggleLike(beat(1));
    expect(provider.likedDuration, const Duration(seconds: 90));
  });

  test('offlineBytes tracks what is actually on disk', () async {
    expect(provider.offlineBytes, 0);

    // the fake writes two 11 byte marker files (audio + art)
    await provider.toggleLike(beat(1));
    expect(provider.offlineBytes, 22);

    await provider.toggleLike(beat(1));
    expect(provider.offlineBytes, 0);
  });

  test('clearAll wipes records, files and the byte count', () async {
    await provider.toggleLike(beat(1));
    await provider.toggleLike(beat(2));

    await provider.clearAll();

    expect(provider.liked, isEmpty);
    expect(provider.offlineBytes, 0);
    expect(await store.all(), isEmpty);
    final tracks = Directory('${temp.path}/${OfflineMediaStore.tracksDir}');
    expect(tracks.listSync().whereType<File>(), isEmpty);
  });

  test('beats from different servers never collide on disk', () async {
    await provider.toggleLike(beat(1, source: 'https://a.example.com'));
    await provider.toggleLike(beat(1, source: 'https://b.example.com'));

    expect(provider.liked, hasLength(2));
    final paths = {for (final b in provider.liked) b.audioPath};
    expect(paths, hasLength(2));
  });

  BeatMix mixOf(int id, List<Beat> beats) => BeatMix(
        id: id,
        sourceId: 'https://a.example.com',
        title: 'Mix $id',
        thumbnailUrl: 'https://a.example.com/mixart/$id.jpg',
        trackCount: beats.length,
        beats: beats,
      );

  test('liking a mix downloads the cover and every beat', () async {
    await provider.toggleLikeMix(mixOf(1, [beat(1), beat(2)]));

    final record = provider.likedMixes.single;
    expect(record.complete, isTrue);
    // cover + two beats worth of audio and art
    expect(downloader.fetchCount, 5);
    expect(File('${temp.path}/${record.artPath}').existsSync(), isTrue);
    for (final b in record.beats) {
      expect(File('${temp.path}/${b.audioPath}').existsSync(), isTrue);
    }
    // mix beats stay out of the liked songs list
    expect(provider.liked, isEmpty);
    expect(provider.isLiked('https://a.example.com:1'), isFalse);
    expect(provider.isMixLiked('https://a.example.com:1'), isTrue);
  });

  test('a beat shared with the mix is downloaded once, owned until last like',
      () async {
    await provider.toggleLike(beat(1));
    expect(downloader.fetchCount, 2);

    // beat 1 is already on disk, only the cover and beat 2 get fetched
    await provider.toggleLikeMix(mixOf(1, [beat(1), beat(2)]));
    expect(downloader.fetchCount, 5);

    final mixRecord = provider.likedMixes.single;
    final shared = mixRecord.beats.firstWhere((b) => b.id == 1);
    final own = mixRecord.beats.firstWhere((b) => b.id == 2);

    // un-liking the mix keeps the individually liked beat's files
    await provider.toggleLikeMix(mixOf(1, [beat(1), beat(2)]));
    expect(File('${temp.path}/${shared.audioPath}').existsSync(), isTrue);
    expect(File('${temp.path}/${own.audioPath}').existsSync(), isFalse);
    expect(File('${temp.path}/${mixRecord.artPath}').existsSync(), isFalse);

    // and the individual unlike removes the last owner
    await provider.toggleLike(beat(1));
    expect(File('${temp.path}/${shared.audioPath}').existsSync(), isFalse);
  });

  test('unliking the individual beat keeps the mix copy playable', () async {
    await provider.toggleLike(beat(1));
    await provider.toggleLikeMix(mixOf(1, [beat(1)]));

    await provider.toggleLike(beat(1)); // unlike the individual one

    expect(provider.liked, isEmpty);
    final mixBeat = provider.likedMixes.single.beats.single;
    expect(File('${temp.path}/${mixBeat.audioPath}').existsSync(), isTrue);
    expect(provider.localAudioFor('https://a.example.com:1'),
        '${temp.path}/${mixBeat.audioPath}');
  });

  test('mixes survive a restart and keep resolving to disk', () async {
    await provider.toggleLikeMix(mixOf(1, [beat(1)]));

    final second = LikedProvider(store, files, downloader);
    await second.init();

    expect(second.likedMixes.single.title, 'Mix 1');
    expect(second.likedMixes.single.complete, isTrue);
    expect(second.localAudioFor('https://a.example.com:1'), isNotNull);
    expect(second.mixArtFor(second.likedMixes.single), isNotNull);
  });

  test('maintenance re-downloads a mix beat whose file vanished', () async {
    await provider.toggleLikeMix(mixOf(1, [beat(1), beat(2)]));
    final gone = provider.likedMixes.single.beats.first;
    File('${temp.path}/${gone.audioPath}').deleteSync();

    final second = LikedProvider(store, files, downloader);
    await second.init();

    expect(second.likedMixes.single.complete, isTrue);
    expect(File('${temp.path}/${gone.audioPath}').existsSync(), isTrue);
  });

  test('clearAll wipes mixes along with everything else', () async {
    await provider.toggleLike(beat(1));
    await provider.toggleLikeMix(mixOf(1, [beat(2)]));

    await provider.clearAll();

    expect(provider.liked, isEmpty);
    expect(provider.likedMixes, isEmpty);
    expect(provider.offlineBytes, 0);
    expect(await store.allMixes(), isEmpty);
  });

  test('shuffleAllMix merges the mixes deduped, liked songs stay out',
      () async {
    await provider.toggleLike(beat(9));
    await provider.toggleLikeMix(mixOf(1, [beat(1), beat(2)]));
    // beat 2 sits in both mixes, it should show up once
    await provider.toggleLikeMix(mixOf(2, [beat(2), beat(3)]));

    final merged = provider.shuffleAllMix()!;
    expect(merged.sourceId, shuffleAllSourceId);
    expect(merged.id, 0);
    expect(merged.trackCount, 3);
    expect({for (final b in merged.beats!) b.key}, {
      'https://a.example.com:1',
      'https://a.example.com:2',
      'https://a.example.com:3',
    });
  });

  test('shuffleAllMix only takes tracks that are on disk', () async {
    await provider.toggleLikeMix(mixOf(1, [beat(1)]));
    downloader.failing = true;
    await provider.toggleLikeMix(mixOf(2, [beat(2)]));

    final merged = provider.shuffleAllMix()!;
    expect({for (final b in merged.beats!) b.key},
        {'https://a.example.com:1'});
    expect(provider.hasDownloadedMixBeats, isTrue);
  });

  test('shuffleAllMix is null when nothing is downloaded', () async {
    expect(provider.shuffleAllMix(), isNull);
    expect(provider.hasDownloadedMixBeats, isFalse);

    downloader.failing = true;
    await provider.toggleLikeMix(mixOf(1, [beat(1)]));
    expect(provider.shuffleAllMix(), isNull);
    expect(provider.hasDownloadedMixBeats, isFalse);

    // individually liked songs are not part of the merged queue
    downloader.failing = false;
    await provider.toggleLike(beat(2));
    expect(provider.shuffleAllMix(), isNull);
    expect(provider.hasDownloadedMixBeats, isFalse);
  });

  test('shuffleAllMix keeps playlist order, newest liked first', () async {
    await provider.toggleLikeMix(mixOf(1, [beat(1), beat(2)]));
    await provider.toggleLikeMix(mixOf(2, [beat(2), beat(3)]));

    // mix 2 was liked last so its beats lead, beat 2 keeps its first spot
    final merged = provider.shuffleAllMix()!;
    expect([for (final b in merged.beats!) b.id], [2, 3, 1]);
  });
}
