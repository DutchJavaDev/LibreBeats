import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/theme/app_theme.dart';
import 'package:liberated_beats/widgets/beat_tile.dart';
import 'package:liberated_beats/widgets/lb_brand.dart';
import 'package:liberated_beats/widgets/widget_builder.dart';

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
      {Beat? tileBeat,
      bool isActive = false,
      bool isPlaying = false,
      VoidCallback? onTap,
      bool? liked,
      VoidCallback? onLike,
      bool downloaded = false}) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: BeatTile(
          beat: tileBeat ?? beat,
          isActive: isActive,
          isPlaying: isPlaying,
          onTap: onTap ?? () {},
          liked: liked,
          onLike: onLike,
          downloaded: downloaded,
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

  testWidgets('subtitle prefers the owning playlist over the artist',
      (tester) async {
    await tester
        .pumpWidget(host(tileBeat: beat.copyWith(mixTitle: 'Deep Focus')));

    expect(find.text('Deep Focus'), findsOneWidget);
    expect(find.text('Test Artist'), findsNothing);
  });

  testWidgets('inactive tile has a mint title and no equalizer',
      (tester) async {
    await tester.pumpWidget(host());

    final style = tester.widget<Text>(find.text('Test Song')).style;
    expect(style?.color, AppTheme.darkScheme.onSurface);
    expect(style?.fontWeight, FontWeight.w600);
    expect(find.byType(PlayingBarsIndicator), findsNothing);
  });

  testWidgets('active tile gets the equalizer and a heavier title',
      (tester) async {
    await tester.pumpWidget(host(isActive: true, isPlaying: true));

    final style = tester.widget<Text>(find.text('Test Song')).style;
    // still mint, the active cue is the edge bar + equalizer, not a tint
    expect(style?.color, AppTheme.darkScheme.onSurface);
    expect(style?.fontWeight, FontWeight.w700);
    expect(find.byType(PlayingBarsIndicator), findsOneWidget);

    await tester.pumpWidget(host(isActive: true, isPlaying: false));
    expect(find.byType(PlayingBarsIndicator), findsOneWidget);
  });

  testWidgets('tap hits onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(host(onTap: () => tapped = true));

    await tester.tap(find.byType(BeatTile));
    expect(tapped, isTrue);
  });

  testWidgets('no heart by default, outline when unliked, filled when liked',
      (tester) async {
    await tester.pumpWidget(host());
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.byIcon(Icons.favorite), findsNothing);

    await tester.pumpWidget(host(liked: false));
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);

    await tester.pumpWidget(host(liked: true));
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });

  testWidgets('heart tap hits onLike, not onTap', (tester) async {
    var likes = 0;
    var tapped = false;
    await tester.pumpWidget(host(
        liked: false, onLike: () => likes++, onTap: () => tapped = true));

    await tester.tap(find.byIcon(Icons.favorite_border));
    expect(likes, 1);
    expect(tapped, isFalse);
  });

  testWidgets('download glyph shows next to the duration', (tester) async {
    await tester.pumpWidget(host(downloaded: true));
    expect(find.byIcon(Icons.download_done), findsOneWidget);
  });

  test('formatTotalDuration switches to hours past 60 minutes', () {
    expect(formatTotalDuration(Duration.zero), '0m');
    expect(formatTotalDuration(const Duration(minutes: 48)), '48m');
    expect(formatTotalDuration(const Duration(minutes: 60)), '1h 0m');
    expect(formatTotalDuration(const Duration(minutes: 108)), '1h 48m');
  });
}
