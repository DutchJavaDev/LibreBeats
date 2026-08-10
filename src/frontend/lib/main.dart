import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:liberated_beats/data/beat_repository.dart';
import 'package:liberated_beats/data/liked_store.dart';
import 'package:liberated_beats/data/offline_media_store.dart';
import 'package:liberated_beats/data/server_registry.dart';
import 'package:liberated_beats/providers/background_audio_provider.dart';
import 'package:liberated_beats/providers/liked_provider.dart';
import 'package:liberated_beats/providers/theme_provider.dart';
import 'package:liberated_beats/services/audio_playback_service.dart';
import 'package:liberated_beats/services/beat_download_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // dark unless the user chose otherwise; also styles the system chrome
  final themeController = ThemeController();
  await themeController.load(await SharedPreferences.getInstance());

  final serverRegistry = ServerRegistry();
  final audioPlaybackService = AudioPlaybackService();

  // first run seed comes from --dart-define=LIBREBEATS_SEED_URLS / _KEYS,
  // after that servers are managed in settings
  await serverRegistry.load(seed: _seedServersFromEnvironment());

  // dont await, LibreProvider waits for this before fetching
  serverRegistry.connectAll();

  // awaited so the platform side is bound before the app starts playing
  await setupAudioService(audioPlaybackService);

  final beatMixRepository = BeatMixRepository(serverRegistry);
  final beatRepository = BeatRepository(serverRegistry);

  final likedProvider = LikedProvider(
      LikedStore(), OfflineMediaStore(), BackgroundMediaDownloader());
  // loads the liked list, cleans the offline dir and retries unfinished
  // downloads, no need to hold up startup for it
  unawaited(likedProvider.init());

  // downloaded liked beats play from disk wherever they get tapped, the
  // liked screen, home history, search. Resolved per play, so un-liking
  // just makes the beat stream again.
  audioPlaybackService.localSourceResolver =
      (beat) => likedProvider.localAudioFor(beat.key);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeController>.value(value: themeController),
        ChangeNotifierProvider<ServerRegistry>.value(value: serverRegistry),
        Provider<BeatMixRepository>.value(value: beatMixRepository),
        Provider<BeatRepository>.value(value: beatRepository),
        Provider<AudioPlaybackService>.value(value: audioPlaybackService),
        ChangeNotifierProvider(
            create: (_) => BackgroundAudioProvider(audioPlaybackService)),
        ChangeNotifierProvider(
            create: (_) => LibreProvider(
                serverRegistry, beatMixRepository, beatRepository)),
        ChangeNotifierProvider<LikedProvider>.value(value: likedProvider),
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
        androidNotificationChannelId: 'com.librebeats.audio',
        androidNotificationChannelName: 'LibreBeats playback',
        androidNotificationOngoing: true,
        preloadArtwork: true,
      ));
}
