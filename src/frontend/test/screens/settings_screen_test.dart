import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/data/liked_store.dart';
import 'package:liberated_beats/data/offline_media_store.dart';
import 'package:liberated_beats/data/server_registry.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/providers/liked_provider.dart';
import 'package:liberated_beats/providers/theme_provider.dart';
import 'package:liberated_beats/screens/settings_screen.dart';
import 'package:liberated_beats/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes.dart';

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

  Future<ServerRegistry> pumpSettings(WidgetTester tester,
      {List<(String, String)> seed = const [],
      Set<String>? failing,
      LikedProvider? liked}) async {
    // tall surface: the appearance card pushed storage/about further down
    // and lazy slivers never build below the fold
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fails = failing ?? {};
    final registry = ServerRegistry(connector: (server) async {
      server.status = fails.contains(server.url)
          ? ServerStatus.failed
          : ServerStatus.healthy;
    });
    await registry.load(seed: seed);
    await registry.connectAll();

    final likedProvider = liked ??
        LikedProvider(
          LikedStore(
              database:
                  await newDatabaseFactoryMemory().openDatabase('liked.db')),
          OfflineMediaStore(rootProvider: () async => Directory.systemTemp.path),
          FakeDownloader(Directory.systemTemp.path),
        );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ServerRegistry>.value(value: registry),
          ChangeNotifierProvider<LikedProvider>.value(value: likedProvider),
          ChangeNotifierProvider<ThemeController>(
              create: (_) => ThemeController()),
        ],
        // the scaffold hosts the snackbar after clearing downloads
        child: MaterialApp(
            theme: AppTheme.dark,
            home: const Scaffold(body: SettingsScreen())),
      ),
    );
    return registry;
  }

  testWidgets('appearance card offers all modes and switches them',
      (tester) async {
    final controller = ThemeController();
    await controller.load(await SharedPreferences.getInstance());
    final registry = ServerRegistry(
        connector: (server) async => server.status = ServerStatus.healthy);
    await registry.load();
    final liked = LikedProvider(
      LikedStore(
          database: await newDatabaseFactoryMemory().openDatabase('liked.db')),
      OfflineMediaStore(rootProvider: () async => Directory.systemTemp.path),
      FakeDownloader(Directory.systemTemp.path),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ServerRegistry>.value(value: registry),
          ChangeNotifierProvider<LikedProvider>.value(value: liked),
          ChangeNotifierProvider<ThemeController>.value(value: controller),
        ],
        child: MaterialApp(
            theme: AppTheme.dark,
            home: const Scaffold(body: SettingsScreen())),
      ),
    );

    // dark is the default when nothing is stored
    expect(controller.mode, ThemeMode.dark);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);

    await tester.tap(find.text('Light'));
    await tester.pump();
    expect(controller.mode, ThemeMode.light);

    // the choice lands in shared_preferences
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ThemeController.prefKey), 'light');
  });

  testWidgets('collapsed summary shows the fleet state, no rows', (tester) async {
    final registry = await pumpSettings(tester, seed: const [
      ('https://a.example.com', 'k1'),
      ('https://b.example.com', 'k2'),
    ], failing: {
      'https://b.example.com'
    });

    // without a default login the summary nudges towards setting one
    expect(find.text('No default login set'), findsOneWidget);

    await registry.setDefaultCredentials('me@example.com', 'pw');
    await tester.pump();
    // problems first and colored, no arithmetic needed
    expect(find.textContaining('1 unreachable', findRichText: true),
        findsOneWidget);
    expect(find.textContaining('1 connected', findRichText: true),
        findsOneWidget);
    // servers stay hidden until expanded
    expect(find.text('a.example.com'), findsNothing);
    expect(find.text('b.example.com'), findsNothing);
  });

  testWidgets('expanding groups servers with problems on top', (tester) async {
    await pumpSettings(tester, seed: const [
      ('https://a.example.com', 'k1'),
      ('https://b.example.com', 'k2'),
    ], failing: {
      'https://b.example.com'
    });

    await tester.tap(find.text('Servers').last);
    await tester.pumpAndSettle();

    expect(find.text('UNREACHABLE · 1'), findsOneWidget);
    expect(find.text('CONNECTED · 1'), findsOneWidget);
    // failed server is listed above the healthy one
    expect(tester.getTopLeft(find.text('b.example.com')).dy,
        lessThan(tester.getTopLeft(find.text('a.example.com')).dy));
  });

  testWidgets('retry all reconnects failed servers', (tester) async {
    final failing = {'https://b.example.com'};
    final registry = await pumpSettings(tester, seed: const [
      ('https://a.example.com', 'k1'),
      ('https://b.example.com', 'k2'),
    ], failing: failing);

    await tester.tap(find.text('Servers').last);
    await tester.pumpAndSettle();

    failing.clear(); // server came back
    await tester.tap(find.text('Retry all'));
    await tester.pumpAndSettle();

    expect(registry.healthy, hasLength(2));
    expect(find.text('UNREACHABLE · 1'), findsNothing);
  });

  testWidgets('about row copies the version', (tester) async {
    await pumpSettings(tester);

    expect(find.text('Liberated Beats'), findsOneWidget);
    await tester.tap(find.text('Liberated Beats'));
    await tester.pump();

    expect(find.text('Version copied'), findsOneWidget);
  });

  testWidgets('remove goes through the detail sheet with confirm',
      (tester) async {
    final registry = await pumpSettings(tester,
        seed: const [('https://a.example.com', 'k1')]);

    await tester.tap(find.text('Servers').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('a.example.com'));
    await tester.pumpAndSettle();

    // detail sheet shows the full url
    expect(find.text('https://a.example.com'), findsOneWidget);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    // cancel first, nothing happens
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(registry.servers, hasLength(1));

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last); // confirm
    await tester.pumpAndSettle();

    expect(registry.servers, isEmpty);
  });

  testWidgets('default login can be edited from the servers section',
      (tester) async {
    final registry = await pumpSettings(tester,
        seed: const [('https://a.example.com', 'k1')]);

    await tester.tap(find.text('Servers').last);
    await tester.pumpAndSettle();
    // nothing baked in, the section nudges towards setting it up
    expect(find.text('Not set, servers need this to sign in'), findsOneWidget);

    await tester.tap(find.text('Default login'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'me@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'hunter2');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(registry.defaultEmail, 'me@example.com');
    expect(registry.defaultPassword, 'hunter2');
    expect(find.text('me@example.com'), findsOneWidget);
  });

  testWidgets('filter shows up for long lists and narrows them',
      (tester) async {
    await pumpSettings(tester, seed: [
      for (var i = 1; i <= 9; i++) ('https://server$i.example.com', 'k$i'),
    ]);

    await tester.tap(find.text('Servers').last);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('server3.example.com'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'server3');
    await tester.pumpAndSettle();

    expect(find.text('server3.example.com'), findsOneWidget);
    expect(find.text('server5.example.com'), findsNothing);
  });

  testWidgets('storage card shows what the liked downloads take up',
      (tester) async {
    // real file io needs runAsync, it never completes in the fake async zone
    final (temp, liked) = (await tester.runAsync(() async {
      final temp = await Directory.systemTemp.createTemp('settings_storage');
      return (temp, await makeLikedProvider(temp));
    }))!;
    addTearDown(() => temp.delete(recursive: true));

    await pumpSettings(tester, liked: liked);
    expect(find.text('0.0 MB'), findsOneWidget);
    expect(find.text('Nothing downloaded yet'), findsOneWidget);
    // nothing to clear, the destructive row stays hidden
    expect(find.text('Clear liked downloads'), findsNothing);

    // fake downloader writes two 11 byte files per liked beat
    await tester.runAsync(() => liked.toggleLike(Beat(
          id: 1,
          sourceId: 'https://a.example.com',
          title: 'Beat 1',
          artist: 'artist',
          thumbnailUrl: 'https://a.example.com/art/1.jpg',
          duration: const Duration(seconds: 90),
          color: sampleTracks.first.color,
          audioUrl: 'https://a.example.com/audio/1.opus',
        )));
    await tester.pump();

    expect(find.text('0.0 MB'), findsOneWidget);
    expect(
        find.textContaining('1 of 1', findRichText: true), findsOneWidget);
    expect(find.text('Clear liked downloads'), findsOneWidget);
  });

  testWidgets('clearing liked downloads asks first, cancel keeps everything',
      (tester) async {
    final (temp, liked) = (await tester.runAsync(() async {
      final temp = await Directory.systemTemp.createTemp('settings_clear');
      final liked = await makeLikedProvider(temp);
      await liked.toggleLike(Beat(
        id: 1,
        sourceId: 'https://a.example.com',
        title: 'Beat 1',
        artist: 'artist',
        thumbnailUrl: 'https://a.example.com/art/1.jpg',
        duration: const Duration(seconds: 90),
        color: sampleTracks.first.color,
        audioUrl: 'https://a.example.com/audio/1.opus',
      ));
      return (temp, liked);
    }))!;
    addTearDown(() => temp.delete(recursive: true));

    await pumpSettings(tester, liked: liked);
    expect(
        find.textContaining('1 of 1', findRichText: true), findsOneWidget);

    // cancel changes nothing
    await tester.tap(find.text('Clear liked downloads'));
    await tester.pumpAndSettle();
    expect(find.text('Delete 0.0 MB?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('1 of 1', findRichText: true), findsOneWidget);

    // confirming empties the liked list (the file deletion itself is real io
    // and covered by the provider's clearAll test)
    await tester.tap(find.text('Clear liked downloads'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete downloads'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing downloaded yet'), findsOneWidget);
    expect(find.text('Clear liked downloads'), findsNothing);
    expect(liked.liked, isEmpty);
  });

  test('formatBytes switches to GB at 1 GB', () {
    expect(SettingsScreen.formatBytes(0), '0.0 MB');
    expect(SettingsScreen.formatBytes(52428800), '50.0 MB'); // 50 MB
    expect(SettingsScreen.formatBytes(1073741823), '1024.0 MB'); // just under
    expect(SettingsScreen.formatBytes(1073741824), '1.00 GB'); // exactly 1 GB
    expect(SettingsScreen.formatBytes(1610612736), '1.50 GB');
  });
}
