import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to dark when nothing is stored', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final controller = ThemeController();
    await controller.load(SharedPreferencesAsync());

    expect(controller.mode, ThemeMode.dark);
    expect(controller.resolvedBrightness, Brightness.dark);
    controller.dispose();
  });

  test('unknown stored values also mean dark', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData(
            {ThemeController.prefKey: 'lavender'});
    final controller = ThemeController();
    await controller.load(SharedPreferencesAsync());

    expect(controller.mode, ThemeMode.dark);
    controller.dispose();
  });

  test('loads a stored light or system choice', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData(
            {ThemeController.prefKey: 'light'});
    final light = ThemeController();
    await light.load(SharedPreferencesAsync());
    expect(light.mode, ThemeMode.light);
    expect(light.resolvedBrightness, Brightness.light);
    light.dispose();

    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData(
            {ThemeController.prefKey: 'system'});
    final system = ThemeController();
    await system.load(SharedPreferencesAsync());
    expect(system.mode, ThemeMode.system);
    system.dispose();
  });

  test('setMode notifies and persists every choice', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final prefs = SharedPreferencesAsync();
    final controller = ThemeController();
    await controller.load(prefs);

    var notified = 0;
    controller.addListener(() => notified++);

    await controller.setMode(ThemeMode.light);
    expect(controller.mode, ThemeMode.light);
    expect(await prefs.getString(ThemeController.prefKey), 'light');

    await controller.setMode(ThemeMode.system);
    expect(await prefs.getString(ThemeController.prefKey), 'system');

    await controller.setMode(ThemeMode.dark);
    expect(await prefs.getString(ThemeController.prefKey), 'dark');
    expect(notified, 3);

    // setting the same mode again stays quiet
    await controller.setMode(ThemeMode.dark);
    expect(notified, 3);
    controller.dispose();
  });
}
