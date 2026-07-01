import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liberated_beats/data/beat_repository.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/supabase_config.dart';
import 'data/beatmix_repository.dart';
import 'providers/catalog_provider.dart';
import 'providers/player_provider.dart';

Future<void> main() async {
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

  runApp(
    MultiProvider(
      providers: [
        Provider<BeatMixRepository>.value(value: beatMixRepository),
        Provider<BeatRepository>.value(value: beatRepository),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider(create: (_) => CatalogProvider(beatMixRepository, beatRepository)),
      ],
      child: const LiberatedBeatsApp(),
    ),
  );
}


Future<void> supabaseInitialize() async {
    // Connect to Supabase only when real credentials are set, so the app still
  // runs on placeholder config (the repository just serves fake data).
  if (SupabaseConfig.isConfigured) {
    var supabase = await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );

    var response = await supabase.client.auth.signInWithPassword(password: "libre@beats.com", email: "libre@beats.com"); // Remove this line

    if (response.user != null) {
      PrintLog("User signed in successfully: ${response.user!.email}");
    } else {
      PrintLog("Sign-in failed: ${response.toString()}");
    }
  }
}

Future<void> setupAudioService() async {
  
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