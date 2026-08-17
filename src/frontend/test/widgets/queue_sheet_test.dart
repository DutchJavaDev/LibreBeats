import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/data/liked_store.dart';
import 'package:liberated_beats/data/offline_media_store.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/providers/background_audio_provider.dart';
import 'package:liberated_beats/providers/liked_provider.dart';
import 'package:liberated_beats/services/audio_playback_service.dart';
import 'package:liberated_beats/theme/app_theme.dart';
import 'package:liberated_beats/widgets/lb_brand.dart';
import 'package:liberated_beats/widgets/queue_sheet.dart';
import 'package:provider/provider.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes.dart';

/// Records jumps and toggles instead of touching the (headless) player,
/// shuffle state comes canned.
class _RecordingPlayback extends AudioPlaybackService {
  final jumps = <int>[];
  int toggles = 0;
  List<int> cannedShuffleIndices = const [];
  bool cannedShuffleEnabled = false;

  @override
  List<int> get shuffleIndices => cannedShuffleIndices;

  @override
  bool get shuffleEnabled => cannedShuffleEnabled;

  @override
  Future<void> skipToQueueItem(int index) async {
    jumps.add(index);
  }

  @override
  Future<bool> togglePlay() async {
    toggles++;
    return true;
  }
}

Beat _playable(int id) => Beat(
      id: id,
      sourceId: 'https://a.example.com',
      title: 'Beat $id',
      artist: 'artist',
      thumbnailUrl: 'https://a.example.com/art/$id.jpg',
      duration: const Duration(seconds: 90),
      color: sampleTracks.first.color,
      audioUrl: 'https://a.example.com/audio/$id.opus',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

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

  Future<void> pumpAndOpen(WidgetTester tester, _RecordingPlayback playback,
      LikedProvider liked, List<Beat> queue, Beat current) async {
    final player = BackgroundAudioProvider(playback);
    // the provider only learns the current beat through a progress tick
    playback.debugSetNowPlaying(current, queue: queue);
    playback.updateProgress(Duration.zero);

    await tester.pumpWidget(
      ChangeNotifierProvider<LikedProvider>.value(
        value: liked,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showQueueSheet(context, player),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  double rowY(WidgetTester tester, String title) =>
      tester.getTopLeft(find.text(title)).dy;

  testWidgets('plain order, count, one highlight, no hearts', (tester) async {
    final (temp, liked) = (await tester.runAsync(() async {
      final temp = await Directory.systemTemp.createTemp('queue_plain');
      return (temp, await makeLikedProvider(temp));
    }))!;
    addTearDown(() => temp.delete(recursive: true));

    final beats = [_playable(1), _playable(2), _playable(3)];
    final playback = _RecordingPlayback();
    await pumpAndOpen(tester, playback, liked, beats, beats[1]);

    expect(find.text('Queue'), findsOneWidget);
    expect(find.text('3 songs'), findsOneWidget);
    expect(rowY(tester, 'Beat 1'), lessThan(rowY(tester, 'Beat 2')));
    expect(rowY(tester, 'Beat 2'), lessThan(rowY(tester, 'Beat 3')));
    // only the current row carries the equalizer, no hearts anywhere
    expect(find.byType(PlayingBarsIndicator), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });

  testWidgets('shuffle on shows the traversal order', (tester) async {
    final (temp, liked) = (await tester.runAsync(() async {
      final temp = await Directory.systemTemp.createTemp('queue_shuffled');
      return (temp, await makeLikedProvider(temp));
    }))!;
    addTearDown(() => temp.delete(recursive: true));

    final beats = [_playable(1), _playable(2), _playable(3)];
    final playback = _RecordingPlayback()
      ..cannedShuffleEnabled = true
      ..cannedShuffleIndices = [2, 0, 1];
    await pumpAndOpen(tester, playback, liked, beats, beats[0]);

    expect(rowY(tester, 'Beat 3'), lessThan(rowY(tester, 'Beat 1')));
    expect(rowY(tester, 'Beat 1'), lessThan(rowY(tester, 'Beat 2')));
    expect(find.byType(PlayingBarsIndicator), findsOneWidget);
  });

  testWidgets('tapping a row jumps by absolute index and starts playback',
      (tester) async {
    final (temp, liked) = (await tester.runAsync(() async {
      final temp = await Directory.systemTemp.createTemp('queue_jump');
      return (temp, await makeLikedProvider(temp));
    }))!;
    addTearDown(() => temp.delete(recursive: true));

    final beats = [_playable(1), _playable(2), _playable(3)];
    final playback = _RecordingPlayback()
      ..cannedShuffleEnabled = true
      ..cannedShuffleIndices = [2, 0, 1];
    await pumpAndOpen(tester, playback, liked, beats, beats[0]);

    // top row is Beat 3, absolute player index 2
    await tester.tap(find.text('Beat 3'));
    await tester.pumpAndSettle();

    expect(playback.jumps, [2]);
    // the recording player reports not playing, so the tap also plays
    expect(playback.toggles, 1);
    // the sheet stays open
    expect(find.text('Queue'), findsOneWidget);
  });

  testWidgets('tapping the current row only toggles play', (tester) async {
    final (temp, liked) = (await tester.runAsync(() async {
      final temp = await Directory.systemTemp.createTemp('queue_current');
      return (temp, await makeLikedProvider(temp));
    }))!;
    addTearDown(() => temp.delete(recursive: true));

    final beats = [_playable(1), _playable(2)];
    final playback = _RecordingPlayback();
    await pumpAndOpen(tester, playback, liked, beats, beats[0]);

    await tester.tap(find.text('Beat 1'));
    await tester.pumpAndSettle();

    expect(playback.jumps, isEmpty);
    expect(playback.toggles, 1);
    expect(find.text('Queue'), findsOneWidget);
  });

  testWidgets('downloaded songs carry the glyph', (tester) async {
    final (temp, liked) = (await tester.runAsync(() async {
      final temp = await Directory.systemTemp.createTemp('queue_glyph');
      final liked = await makeLikedProvider(temp);
      await liked.toggleLike(_playable(1));
      return (temp, liked);
    }))!;
    addTearDown(() => temp.delete(recursive: true));

    final beats = [_playable(1), _playable(2)];
    final playback = _RecordingPlayback();
    await pumpAndOpen(tester, playback, liked, beats, beats[0]);

    expect(find.byIcon(Icons.download_done), findsOneWidget);
  });

  testWidgets('opening auto-scrolls to a current song deep in the queue',
      (tester) async {
    final (temp, liked) = (await tester.runAsync(() async {
      final temp = await Directory.systemTemp.createTemp('queue_scroll');
      return (temp, await makeLikedProvider(temp));
    }))!;
    addTearDown(() => temp.delete(recursive: true));

    final beats = [for (var i = 1; i <= 30; i++) _playable(i)];
    final playback = _RecordingPlayback();
    await pumpAndOpen(tester, playback, liked, beats, beats[20]);

    // the list jumped, the head is culled and the current song visible
    expect(find.text('Beat 1'), findsNothing);
    expect(find.text('Beat 21'), findsOneWidget);
  });
}
