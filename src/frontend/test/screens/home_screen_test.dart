import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/data/play_stats_store.dart';
import 'package:liberated_beats/data/server_registry.dart';
import 'package:liberated_beats/providers/background_audio_provider.dart';
import 'package:liberated_beats/providers/play_stats_provider.dart';
import 'package:liberated_beats/screens/home_screen.dart';
import 'package:liberated_beats/services/audio_playback_service.dart';
import 'package:liberated_beats/theme/app_theme.dart';
import 'package:liberated_beats/widgets/lb_brand.dart';
import 'package:provider/provider.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes.dart';

// connector that just flips the status, no network
ServerConnector _connector({Set<String> failing = const {}}) {
  return (server) async {
    server.status = failing.contains(server.url)
        ? ServerStatus.failed
        : ServerStatus.healthy;
  };
}

Future<PlayStatsStore> memStore() async => PlayStatsStore(
    database: await newDatabaseFactoryMemory().openDatabase('stats.db'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpHome(
    WidgetTester tester, {
    PlayStatsProvider? stats,
    ServerRegistry? registry,
  }) async {
    // tall surface so every sliver section actually builds
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // sembast needs real async, the widget test zone's fake clock would
    // leave its futures hanging
    final statsProvider = stats ??
        (await tester.runAsync(() async => PlayStatsProvider(await memStore())))!;
    final serverRegistry = registry ?? ServerRegistry(connector: _connector());

    // the real service stays idle in tests: no audio platform is touched
    // until something plays, and nothing here is playable
    final provider = BackgroundAudioProvider(AudioPlaybackService());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BackgroundAudioProvider>.value(
              value: provider),
          ChangeNotifierProvider<PlayStatsProvider>.value(
              value: statsProvider),
          ChangeNotifierProvider<ServerRegistry>.value(value: serverRegistry),
        ],
        child: MaterialApp(
            theme: AppTheme.dark, home: const Scaffold(body: HomeScreen())),
      ),
    );
  }

  testWidgets('play sections invite listening until something was played',
      (tester) async {
    await pumpHome(tester);

    expect(find.text('History'), findsNothing);

    // the sections stay visible with a hint instead of leaving a gap
    expect(find.text('On repeat'), findsOneWidget);
    expect(find.text('Listen to songs to see this update'), findsOneWidget);
    expect(find.text('Heavy rotation'), findsOneWidget);
    expect(
        find.text('Listen to playlists to see this update'), findsOneWidget);

    // greeting and rule are always there
    expect(find.byType(BrandRule), findsOneWidget);

    // the mocked update cards remain, each marked as a preview
    expect(find.text('From your servers'), findsOneWidget);
    expect(find.text('3 new beatmixes'), findsOneWidget);
    expect(find.text('New playlist: Deep Focus'), findsOneWidget);
    expect(find.byType(PreviewChip), findsNWidgets(2));

    // no servers registered: no health digest either
    expect(find.textContaining('healthy'), findsNothing);
  });

  testWidgets('On repeat and Heavy rotation rank real play counts',
      (tester) async {
    final alpha = beat('srv', 1, 'Alpha');
    final betaBeat = beat('srv', 2, 'Beta');
    final nine = mix('srv', 9, 'Nine', [alpha, betaBeat]);

    final stats = (await tester.runAsync(() async {
      final store = await memStore();
      await store.recordBeatPlay(alpha);
      await store.recordBeatPlay(alpha);
      await store.recordBeatPlay(alpha);
      await store.recordBeatPlay(betaBeat);
      await store.recordMixPlay(nine, alpha);
      await store.recordMixPlay(nine, alpha);
      await store.recordMixPlay(nine, betaBeat);

      final stats = PlayStatsProvider(store);
      await stats.init();
      return stats;
    }))!;
    await pumpHome(tester, stats: stats);

    expect(find.text('On repeat'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('3 plays'), findsOneWidget);
    expect(find.text('1 play'), findsOneWidget);

    // the mix line counts plays and the distinct songs actually played
    expect(find.text('Heavy rotation'), findsOneWidget);
    expect(find.text('Nine'), findsOneWidget);
    expect(find.text('3 plays · 2 songs'), findsOneWidget);

    // real data replaces the empty hints
    expect(find.textContaining('to see this update'), findsNothing);

    // real sections carry no preview chip, the two mock cards still do
    expect(find.byType(PreviewChip), findsNWidgets(2));
  });

  testWidgets('a dead On repeat row says so when tapped', (tester) async {
    final stats = (await tester.runAsync(() async {
      final store = await memStore();
      // beats from the fakes have no stream url, so playBeat refuses them
      await store.recordBeatPlay(beat('srv', 1, 'Alpha'));
      final stats = PlayStatsProvider(store);
      await stats.init();
      return stats;
    }))!;
    await pumpHome(tester, stats: stats);

    await tester.tap(find.text('Alpha'));
    await tester.pump();

    expect(find.text('Alpha is unavailable'), findsOneWidget);

    // run the snackbar's auto-dismiss down so no timer outlives the test
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });

  testWidgets('the health digest reports an all-healthy fleet',
      (tester) async {
    final registry = ServerRegistry(connector: _connector());
    await registry.load(
        seed: const [('https://a', 'k1'), ('https://b', 'k2')]);
    await registry.connectAll();

    await pumpHome(tester, registry: registry);

    expect(find.text('All 2 servers healthy'), findsOneWidget);
    expect(find.text('Last checked just now'), findsOneWidget);
  });

  testWidgets('the health digest leads with unreachable servers',
      (tester) async {
    final registry =
        ServerRegistry(connector: _connector(failing: {'https://b'}));
    await registry.load(
        seed: const [('https://a', 'k1'), ('https://b', 'k2')]);
    await registry.connectAll();

    await pumpHome(tester, registry: registry);

    expect(find.text('1 of 2 servers unreachable'), findsOneWidget);
  });
}
