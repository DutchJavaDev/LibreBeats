import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/providers/background_audio_provider.dart';
import 'package:liberated_beats/screens/home_screen.dart';
import 'package:liberated_beats/services/audio_playback_service.dart';
import 'package:liberated_beats/theme/app_theme.dart';
import 'package:liberated_beats/widgets/lb_brand.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpHome(WidgetTester tester) async {
    // tall surface so every sliver section actually builds
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // the real service stays idle in tests: no audio platform is touched
    // until something plays, and nothing here is playable
    final provider = BackgroundAudioProvider(AudioPlaybackService());
    await tester.pumpWidget(
      ChangeNotifierProvider<BackgroundAudioProvider>.value(
        value: provider,
        child: MaterialApp(
            theme: AppTheme.dark, home: const Scaffold(body: HomeScreen())),
      ),
    );
  }

  testWidgets('renders the three mocked sections from const sample data',
      (tester) async {
    await pumpHome(tester);

    expect(find.text('On repeat'), findsOneWidget);
    expect(find.text('Heavy rotation'), findsOneWidget);
    expect(find.text('From your servers'), findsOneWidget);
    // every mocked section is marked as sample data
    expect(find.byType(PreviewChip), findsNWidgets(3));

    // most listened rows show mix subtitles and play counts
    expect(find.text('Low Tide'), findsOneWidget);
    expect(find.text('Deep Focus'), findsWidgets);
    expect(find.text('31 plays'), findsOneWidget);

    // the server updates: new playlists + the health digest
    expect(find.text('3 new beatmixes'), findsOneWidget);
    expect(find.text('All 3 servers healthy'), findsOneWidget);
  });

  testWidgets('history stays hidden while there is nothing played',
      (tester) async {
    await pumpHome(tester);

    expect(find.text('History'), findsNothing);
    // greeting and rule are always there
    expect(find.byType(BrandRule), findsOneWidget);
  });
}
