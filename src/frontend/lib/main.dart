import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:liberated_beats/data/beat_repository.dart';
import 'package:liberated_beats/data/server_registry.dart';
import 'package:liberated_beats/providers/background_audio_provider.dart';
import 'package:liberated_beats/services/audio_playback_service.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/beatmix_repository.dart';
import 'providers/catalog_provider.dart';

Future<void> main() async {
  if (kDebugMode) {
    CachedNetworkImage.logLevel = CacheManagerLogLevel.debug;
  } else {
    // Log to file?
    CachedNetworkImage.logLevel = CacheManagerLogLevel.warning;
  }

  WidgetsFlutterBinding.ensureInitialized();

  // fonts are bundled in assets/google_fonts, no runtime download
  GoogleFonts.config.allowRuntimeFetching = false;

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
  ));

  final serverRegistry = ServerRegistry();
  final audioPlaybackService = AudioPlaybackService();

  // prefs load and the audio service bind are independent, run them together.
  // first run seed comes from --dart-define=LIBREBEATS_SEED_URLS / _KEYS,
  // after that servers are managed in settings
  if (kDebugMode) {
    await Future.wait([
      serverRegistry.load(seed: _seedServersFromEnvironment()),
    ]);
  }
  // dont await, LibreProvider waits for this before fetching
  serverRegistry.connectAll();
  setupAudioService(audioPlaybackService);

  final beatMixRepository = BeatMixRepository(serverRegistry);
  final beatRepository = BeatRepository(serverRegistry);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ServerRegistry>.value(value: serverRegistry),
        Provider<BeatMixRepository>.value(value: beatMixRepository),
        Provider<BeatRepository>.value(value: beatRepository),
        Provider<AudioPlaybackService>.value(value: audioPlaybackService),
        ChangeNotifierProvider(
            create: (_) => BackgroundAudioProvider(audioPlaybackService)),
        ChangeNotifierProvider(
            create: (_) => LibreProvider(
                serverRegistry, beatMixRepository, beatRepository)),
      ],
      child: const LiberatedBeatsApp(),
    ),
  );
}

List<(String, String)> _seedServersFromEnvironment() {
  const urls = String.fromEnvironment('LIBREBEATS_SEED_URLS');
  const keys = String.fromEnvironment('LIBREBEATS_SEED_KEYS');
  return ServerRegistry.parseSeedList(urls, keys);
}

Future<void> setupAudioService(BaseAudioHandler audioPlayback) async {
  await AudioService.init(
      builder: () => audioPlayback,
      config: const AudioServiceConfig(
        androidNotificationOngoing: true,
        preloadArtwork: true,
      ));
}
