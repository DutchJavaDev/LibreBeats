import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/server_registry.dart';
import 'providers/theme_provider.dart';
import 'screens/first_run_screen.dart';
import 'screens/main_scaffold.dart';
import 'theme/app_theme.dart';

class LiberatedBeatsApp extends StatelessWidget {
  const LiberatedBeatsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    // fresh installs get the welcome screen, adding a server notifies and
    // swaps the scaffold in (registry.load ran before runApp, so the first
    // frame is right)
    final registry = context.watch<ServerRegistry>();
    return MaterialApp(
      title: 'Liberated Beats',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeController.mode,
      home: registry.servers.isEmpty
          ? const FirstRunScreen()
          : const MainScaffold(),
    );
  }
}
