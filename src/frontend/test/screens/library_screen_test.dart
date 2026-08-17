import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/data/liked_store.dart';
import 'package:liberated_beats/data/offline_media_store.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/providers/background_audio_provider.dart';
import 'package:liberated_beats/providers/liked_provider.dart';
import 'package:liberated_beats/screens/library_screen.dart';
import 'package:liberated_beats/services/audio_playback_service.dart';
import 'package:liberated_beats/theme/app_theme.dart';
import 'package:liberated_beats/widgets/lb_brand.dart';
import 'package:provider/provider.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes.dart';

/// Records the queue instead of touching the (headless) audio player.
class _RecordingPlayback extends AudioPlaybackService {
  BeatMix? mixSet;
  Beat? startSet;
  bool? shuffleSet;

  @override
  Future<bool> setBeatMix(BeatMix? mix, Beat? initalBeat) async {
    mixSet = mix;
    startSet = initalBeat;
    return true;
  }

  @override
  Future<bool> togglePlay() async => true;

  @override
  void setShuffleModeEnabled(bool shuffle) {
    shuffleSet = shuffle;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Beat beat(int id) => Beat(
        id: id,
        sourceId: 'https://a.example.com',
        title: 'Beat $id',
        artist: 'artist',
        thumbnailUrl: 'https://a.example.com/art/$id.jpg',
        duration: const Duration(seconds: 90),
        color: sampleTracks.first.color,
        audioUrl: 'https://a.example.com/audio/$id.opus',
      );

  BeatMix mixOf(int id, List<Beat> beats) => BeatMix(
        id: id,
        sourceId: 'https://a.example.com',
        title: 'Mix $id',
        thumbnailUrl: 'https://a.example.com/mixart/$id.jpg',
        trackCount: beats.length,
        beats: beats,
      );

  Future<LikedProvider> makeLikedProvider(Directory temp) async {
    final provider = LikedProvider(
      LikedStore(
          database: await newDatabaseFactoryMemory().openDatabase('liked.db')),
      OfflineMediaStore(rootProvider: () async => temp.path),
      FakeDownloader(temp.path),
    );
    await provider.init();
    return provider;
  }

  Future<void> pumpLibrary(WidgetTester tester, LikedProvider liked,
      {BackgroundAudioProvider? player}) async {
    final app = MaterialApp(
        theme: AppTheme.dark, home: const Scaffold(body: LibraryScreen()));
    await tester.pumpWidget(
      ChangeNotifierProvider<LikedProvider>.value(
        value: liked,
        child: player == null
            ? app
            : ChangeNotifierProvider<BackgroundAudioProvider>.value(
                value: player, child: app),
      ),
    );
  }

  testWidgets('empty library points at search', (tester) async {
    final (temp, liked) = (await tester.runAsync(() async {
      final temp = await Directory.systemTemp.createTemp('library_empty');
      return (temp, await makeLikedProvider(temp));
    }))!;
    addTearDown(() => temp.delete(recursive: true));

    await pumpLibrary(tester, liked);

    expect(
        find.text('No liked playlists yet, tap the heart on a playlist in search'),
        findsOneWidget);
  });

  testWidgets('liked mixes show up, long press removes behind a confirm',
      (tester) async {
    final (temp, liked) = (await tester.runAsync(() async {
      final temp = await Directory.systemTemp.createTemp('library_mix');
      final liked = await makeLikedProvider(temp);
      await liked.toggleLikeMix(mixOf(1, [beat(1), beat(2)]));
      return (temp, liked);
    }))!;
    addTearDown(() => temp.delete(recursive: true));

    await pumpLibrary(tester, liked);

    expect(find.text('Mix 1'), findsOneWidget);
    expect(find.text('Playlist · 2 songs'), findsOneWidget);

    // cancel keeps it
    await tester.longPress(find.text('Mix 1'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Mix 1?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Mix 1'), findsOneWidget);

    // confirming removes the record right away (file cleanup is real io,
    // covered by the provider tests)
    await tester.longPress(find.text('Mix 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('Mix 1'), findsNothing);
    expect(liked.likedMixes, isEmpty);
  });

  testWidgets('shuffle all pill sits dimmed until something is on disk',
      (tester) async {
    final (temp, liked) = (await tester.runAsync(() async {
      final temp = await Directory.systemTemp.createTemp('library_shuffle');
      return (temp, await makeLikedProvider(temp));
    }))!;
    addTearDown(() => temp.delete(recursive: true));

    await pumpLibrary(tester, liked);

    // there, but inert while nothing is downloaded
    expect(find.text('Shuffle all'), findsOneWidget);
    var pill =
        tester.widget<GradientPillButton>(find.byType(GradientPillButton));
    expect(pill.onPressed, isNull);

    await tester.runAsync(() => liked.toggleLikeMix(mixOf(1, [beat(1)])));
    await tester.pump();

    pill = tester.widget<GradientPillButton>(find.byType(GradientPillButton));
    expect(pill.onPressed, isNotNull);
  });

  testWidgets('tapping shuffle all queues the merged downloaded tracks',
      (tester) async {
    final (temp, liked, playback) = (await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      final temp = await Directory.systemTemp.createTemp('library_tap');
      final liked = await makeLikedProvider(temp);
      await liked.toggleLikeMix(mixOf(1, [beat(1), beat(2)]));
      // beat 2 sits in both mixes, the queue should carry it once
      await liked.toggleLikeMix(mixOf(2, [beat(2), beat(3)]));
      return (temp, liked, _RecordingPlayback());
    }))!;
    addTearDown(() => temp.delete(recursive: true));

    final player = BackgroundAudioProvider(playback);
    await pumpLibrary(tester, liked, player: player);
    await tester.tap(find.text('Shuffle all'));
    await tester.pump();

    final queued = playback.mixSet!;
    expect(queued.sourceId, shuffleAllSourceId);
    expect(queued.beats, hasLength(3));
    expect({for (final b in queued.beats!) b.key}, {
      'https://a.example.com:1',
      'https://a.example.com:2',
      'https://a.example.com:3',
    });
    expect(playback.startSet, isNotNull);
    expect(queued.beats!.map((b) => b.key), contains(playback.startSet!.key));
    // and shuffle mode went on
    expect(player.shuffle, isTrue);
    expect(playback.shuffleSet, isTrue);
  });
}
