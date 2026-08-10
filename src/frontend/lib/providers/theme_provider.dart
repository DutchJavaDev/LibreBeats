import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// Owns the theme mode: dark (the default when nothing is stored), light,
/// or follow-the-system. Persisted on device and applied to the system
/// chrome (status/navigation bar) so the OS edges match the active scheme.
class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  static const prefKey = 'librebeats.themeMode';

  ThemeController() {
    WidgetsBinding.instance.addObserver(this);
  }

  SharedPreferences? _prefs;

  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;

  /// The brightness the app actually shows right now.
  Brightness get resolvedBrightness => switch (_mode) {
        ThemeMode.dark => Brightness.dark,
        ThemeMode.light => Brightness.light,
        ThemeMode.system =>
          WidgetsBinding.instance.platformDispatcher.platformBrightness,
      };

  /// Reads the stored choice. Anything unknown or missing means dark.
  Future<void> load(SharedPreferences prefs) async {
    _prefs = prefs;
    _mode = switch (prefs.getString(prefKey)) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    applySystemChrome();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    applySystemChrome();
    notifyListeners();
    await _prefs?.setString(
        prefKey,
        switch (mode) {
          ThemeMode.dark => 'dark',
          ThemeMode.light => 'light',
          ThemeMode.system => 'system',
        });
  }

  // In system mode the OS can flip brightness under us: MaterialApp follows
  // on its own, the system chrome does not.
  @override
  void didChangePlatformBrightness() {
    if (_mode == ThemeMode.system) {
      applySystemChrome();
      notifyListeners();
    }
  }

  void applySystemChrome() {
    final dark = resolvedBrightness == Brightness.dark;
    final scheme = dark ? AppTheme.darkScheme : AppTheme.lightScheme;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      // icon brightness is the inverse of the surface it sits on
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: scheme.surfaceContainerLowest,
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
    ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
