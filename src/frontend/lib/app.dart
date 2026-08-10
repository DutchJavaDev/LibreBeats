import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/theme_provider.dart';
import 'screens/main_scaffold.dart';
import 'theme/app_theme.dart';

class LiberatedBeatsApp extends StatelessWidget {
  const LiberatedBeatsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    return MaterialApp(
      title: 'Liberated Beats',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeController.mode,
      home: const MainScaffold(),
    );
  }
}
