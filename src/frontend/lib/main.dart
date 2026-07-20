import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liberated_beats/data/beat_repository.dart';
import 'package:liberated_beats/providers/background_audio_provider.dart';
import 'package:liberated_beats/services/audio_playback_service.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/supabase_config.dart';
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

  await supabaseInitialize();

  final beatMixRepository = BeatMixRepository();
  final beatRepository = BeatRepository();
  final audioPlaybackService = AudioPlaybackService();

  await setupAudioService(audioPlaybackService);

  runApp(
    MultiProvider(
      providers: [
        Provider<BeatMixRepository>.value(value: beatMixRepository),
        Provider<BeatRepository>.value(value: beatRepository),
        Provider<AudioPlaybackService>.value(value: audioPlaybackService),
        ChangeNotifierProvider(create: (_) => BackgroundAudioProvider(audioPlaybackService)),
        ChangeNotifierProvider(create: (_) => LibreProvider(beatMixRepository, beatRepository)),
      ],
      child: const LiberatedBeatsApp(),
    ),
  );
}


// This is only for now on dev until I have designed multi config support
Future<void> supabaseInitialize() async {
  if (SupabaseConfig.isConfigured) {
    var supabase = await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
    
    var response = await supabase.client.auth.signInWithPassword(password: "", email: ""); // Remove this line

    if (response.user != null) {
      PrintLog("User signed in successfully: ${response.user!.email}");
    } else {
      PrintLog("Sign-in failed: ${response.toString()}");
    }
  }
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
    print(object);    
  }
  else
  {
    // Write to a log file or send to a logging service in production
  }
}