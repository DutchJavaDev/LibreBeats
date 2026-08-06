import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liberated_beats/data/beat_repository.dart';
import 'package:liberated_beats/data/server_registry.dart';
import 'package:liberated_beats/providers/background_audio_provider.dart';
import 'package:liberated_beats/services/audio_playback_service.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/beatmix_repository.dart';
import 'providers/catalog_provider.dart';

Future<void> main() async {

  if(kDebugMode)
  {
    CachedNetworkImage.logLevel = CacheManagerLogLevel.debug;    
  }
  else
  {
    // Log to file?
    CachedNetworkImage.logLevel = CacheManagerLogLevel.warning;
  }

  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
  ));

  final serverRegistry = ServerRegistry();
  // Loads servers persisted from Settings; on a fresh install, seeds from
  // --dart-define (comma-separated, zipped pairwise):
  //   --dart-define=LIBREBEATS_SEED_URLS=https://a.example.com,https://b.example.com
  //   --dart-define=LIBREBEATS_SEED_KEYS=sb_publishable_aaa,sb_publishable_bbb
  // Servers can also be added at runtime via Settings → Servers.
  await serverRegistry.load(seed: _seedServersFromEnvironment());
  // Sign-ins run in the background; LibreProvider awaits them before fetching.
  serverRegistry.connectAll();

  final beatMixRepository = BeatMixRepository(serverRegistry);
  final beatRepository = BeatRepository(serverRegistry);
  final audioPlaybackService = AudioPlaybackService();

  await setupAudioService(audioPlaybackService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ServerRegistry>.value(value: serverRegistry),
        Provider<BeatMixRepository>.value(value: beatMixRepository),
        Provider<BeatRepository>.value(value: beatRepository),
        Provider<AudioPlaybackService>.value(value: audioPlaybackService),
        ChangeNotifierProvider(create: (_) => BackgroundAudioProvider(audioPlaybackService)),
        ChangeNotifierProvider(
            create: (_) => LibreProvider(
                serverRegistry, beatMixRepository, beatRepository)),
      ],
      child: const LiberatedBeatsApp(),
    ),
  );
}

/// Zips LIBREBEATS_SEED_URLS / LIBREBEATS_SEED_KEYS (comma-separated
/// dart-defines) into (url, key) pairs for the first-run server seed.
List<(String, String)> _seedServersFromEnvironment() {
  const urls = String.fromEnvironment('LIBREBEATS_SEED_URLS');
  const keys = String.fromEnvironment('LIBREBEATS_SEED_KEYS');
  if (urls.isEmpty || keys.isEmpty) return const [];

  final urlList = urls.split(',');
  final keyList = keys.split(',');
  final count = urlList.length < keyList.length ? urlList.length : keyList.length;

  return [
    for (var i = 0; i < count; i++) (urlList[i].trim(), keyList[i].trim()),
  ];
}

Future<void> setupAudioService(BaseAudioHandler audioPlayback) async {
  await AudioService.init(
    builder: () => audioPlayback,
    config: const AudioServiceConfig(
      androidNotificationOngoing: true,
      preloadArtwork: true,
    ));
}

// ignore: non_constant_identifier_names
void PrintLog(Object? object) {
  if(kDebugMode)
  {
    print("[LIBRE-BEATS]: $object");    
  }
  else
  {
    // Write to a log file or send to a logging service in production
  }
}