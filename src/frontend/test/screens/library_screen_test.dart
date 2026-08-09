import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/data/liked_store.dart';
import 'package:liberated_beats/data/offline_media_store.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/providers/liked_provider.dart';
import 'package:liberated_beats/screens/library_screen.dart';
import 'package:provider/provider.dart';
import 'package:sembast/sembast_memory.dart';

import '../fakes.dart';

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

  Future<void> pumpLibrary(WidgetTester tester, LikedProvider liked) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<LikedProvider>.value(
        value: liked,
        child: const MaterialApp(home: Scaffold(body: LibraryScreen())),
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
}
