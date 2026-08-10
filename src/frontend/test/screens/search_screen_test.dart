import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/data/beat_repository.dart';
import 'package:liberated_beats/data/beatmix_repository.dart';
import 'package:liberated_beats/data/liked_store.dart';
import 'package:liberated_beats/data/offline_media_store.dart';
import 'package:liberated_beats/data/server_registry.dart';
import 'package:liberated_beats/providers/catalog_provider.dart';
import 'package:liberated_beats/providers/liked_provider.dart';
import 'package:liberated_beats/screens/search_screen.dart';
import 'package:liberated_beats/theme/app_theme.dart';
import 'package:liberated_beats/widgets/browse_mix_card.dart';
import 'package:provider/provider.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes.dart';

void main() {
  testWidgets('cache mode toggle switches disk/memory', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final registry =
        ServerRegistry(connector: (s) async => s.status = ServerStatus.healthy);
    await registry.load();
    final provider = LibreProvider(
        registry, BeatMixRepository(registry), BeatRepository(registry));

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
          theme: AppTheme.dark, home: const Scaffold(body: SearchScreen())),
    ));

    expect(find.text('Cache: disk'), findsOneWidget);

    await tester.tap(find.text('Cache: disk'));
    await tester.pumpAndSettle();

    expect(provider.persistentCache, isFalse);
    expect(find.text('Cache: memory'), findsOneWidget);

    // the choice itself is persisted too
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('librebeats_cache_persistent'), isFalse);
  });

  testWidgets('update banner shows after an auto refresh, X dismisses it',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final registry =
        ServerRegistry(connector: (s) async => s.status = ServerStatus.healthy);
    await registry.load(seed: const [('https://a.example.com', 'k1')]);

    final repo = FakeBeatMixRepository(registry);
    repo.responses['https://a.example.com'] = [mix('https://a.example.com', 1)];

    final provider = LibreProvider(
      registry,
      repo,
      BeatRepository(registry),
      cacheTtl: const Duration(milliseconds: 30),
      dripInterval: const Duration(milliseconds: 1),
      watchInterval: const Duration(milliseconds: 10),
    );

    // pump while the catalog is still empty, then drive the watcher with
    // real time. the query keeps the grid empty afterwards, rendering the
    // beatmix tiles here would need the whole audio stack.
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
          theme: AppTheme.dark, home: const Scaffold(body: SearchScreen())),
    ));

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await provider.ensureCatalog();
      provider.setSearchVisible(true);
      await Future.delayed(const Duration(milliseconds: 80));
      provider.setSearchVisible(false);
    });
    expect(provider.updateNotice, isTrue);
    await tester.pumpAndSettle();

    expect(find.text('Playlists were updated'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Playlists were updated'), findsNothing);
  });

  testWidgets('browse grid shows playlist cards with a counted header',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final registry =
        ServerRegistry(connector: (s) async => s.status = ServerStatus.healthy);
    await registry.load(seed: const [('https://a.example.com', 'k1')]);

    final repo = FakeBeatMixRepository(registry);
    repo.responses['https://a.example.com'] = [
      mix('https://a.example.com', 1, 'Chill'),
      mix('https://a.example.com', 2, 'Focus'),
    ];
    final provider = LibreProvider(
      registry,
      repo,
      BeatRepository(registry),
      dripInterval: const Duration(milliseconds: 1),
    );
    final liked = LikedProvider(
      LikedStore(
          database: await newDatabaseFactoryMemory().openDatabase('liked.db')),
      OfflineMediaStore(rootProvider: () async => 'unused'),
      FakeDownloader('unused'),
    );

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<LibreProvider>.value(value: provider),
        ChangeNotifierProvider<LikedProvider>.value(value: liked),
      ],
      child: MaterialApp(
          theme: AppTheme.dark, home: const Scaffold(body: SearchScreen())),
    ));

    // drip timers are real, run the load outside the fake async zone
    await tester.runAsync(() => provider.ensureCatalog());
    await tester.pumpAndSettle();

    // header title and its count are separate texts now
    expect(find.text('Browse playlists'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byType(BrowseMixCard), findsNWidgets(2));
    expect(find.text('Chill'), findsOneWidget);
    expect(find.text('Focus'), findsOneWidget);
  });
}
