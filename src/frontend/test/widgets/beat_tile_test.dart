import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/widgets/beat_tile.dart';

void main() {
  final beat = Beat(
    id: 1,
    sourceId: 'test',
    title: 'Test Song',
    artist: 'Test Artist',
    thumbnailUrl: 'not-a-url',
    duration: const Duration(seconds: 218),
    color: sampleTracks.first.color,
  );

  Widget host(
      {bool isActive = false, bool isPlaying = false, VoidCallback? onTap}) {
    return MaterialApp(
      home: Scaffold(
        body: BeatTile(
          beat: beat,
          isActive: isActive,
          isPlaying: isPlaying,
          onTap: onTap ?? () {},
        ),
      ),
    );
  }

  testWidgets('shows title, artist and duration', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('Test Song'), findsOneWidget);
    expect(find.text('Test Artist'), findsOneWidget);
    expect(find.text('3:38'), findsOneWidget);
    // thumbnailUrl holds 'not-a-url' here, should not blow up trying to load it
    expect(tester.takeException(), isNull);
  });

  testWidgets('inactive tile has a white title and no overlay', (tester) async {
    await tester.pumpWidget(host());

    expect(tester.widget<Text>(find.text('Test Song')).style?.color,
        Colors.white);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
    expect(find.byIcon(Icons.pause), findsNothing);
  });

  testWidgets('active tile is green with a play/pause overlay', (tester) async {
    await tester.pumpWidget(host(isActive: true, isPlaying: true));
    expect(tester.widget<Text>(find.text('Test Song')).style?.color,
        const Color(0xFF1ED760));
    expect(find.byIcon(Icons.pause), findsOneWidget);

    await tester.pumpWidget(host(isActive: true, isPlaying: false));
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('tap hits onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(host(onTap: () => tapped = true));

    await tester.tap(find.byType(BeatTile));
    expect(tapped, isTrue);
  });
}
