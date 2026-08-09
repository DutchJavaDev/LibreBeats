import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/data/liked_store.dart';
import 'package:liberated_beats/data/offline_media_store.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/providers/liked_provider.dart';
import 'package:liberated_beats/widgets/widget_builder.dart';
import 'package:provider/provider.dart';
import 'package:sembast/sembast_memory.dart';

import '../fakes.dart';

void main() {
  testWidgets('unlike from a row heart offers undo, undo re-likes',
      (tester) async {
    final (temp, liked, beat) = (await tester.runAsync(() async {
      final temp = await Directory.systemTemp.createTemp('toggle_like');
      final provider = LikedProvider(
        LikedStore(
            database:
                await newDatabaseFactoryMemory().openDatabase('liked.db')),
        OfflineMediaStore(rootProvider: () async => temp.path),
        FakeDownloader(temp.path),
      );
      await provider.init();
      final b = Beat(
        id: 1,
        sourceId: 'https://a.example.com',
        title: 'Beat 1',
        artist: 'artist',
        thumbnailUrl: 'https://a.example.com/art/1.jpg',
        duration: const Duration(seconds: 90),
        color: sampleTracks.first.color,
        audioUrl: 'https://a.example.com/audio/1.opus',
      );
      await provider.toggleLike(b);
      return (temp, provider, b);
    }))!;
    addTearDown(() => temp.delete(recursive: true));

    await tester.pumpWidget(ChangeNotifierProvider<LikedProvider>.value(
      value: liked,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => toggleBeatLike(context, liked, beat),
              child: const Text('heart'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('heart'));
    await tester.pumpAndSettle();

    expect(find.text('Beat 1 removed from Liked Songs'), findsOneWidget);
    expect(liked.isLiked(beat.key), isFalse);

    // the action dismisses the snackbar and cancels its timer
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(liked.isLiked(beat.key), isTrue);
  });
}
