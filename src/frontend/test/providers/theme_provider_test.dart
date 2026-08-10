import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to dark when nothing is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = ThemeController();
    await controller.load(await SharedPreferences.getInstance());

    expect(controller.mode, ThemeMode.dark);
    expect(controller.resolvedBrightness, Brightness.dark);
    controller.dispose();
  });

  test('unknown stored values also mean dark', () async {
    SharedPreferences.setMockInitialValues(
        {ThemeController.prefKey: 'lavender'});
    final controller = ThemeController();
    await controller.load(await SharedPreferences.getInstance());

    expect(controller.mode, ThemeMode.dark);
    controller.dispose();
  });

  test('loads a stored light or system choice', () async {
    SharedPreferences.setMockInitialValues({ThemeController.prefKey: 'light'});
    final light = ThemeController();
    await light.load(await SharedPreferences.getInstance());
    expect(light.mode, ThemeMode.light);
    expect(light.resolvedBrightness, Brightness.light);
    light.dispose();

    SharedPreferences.setMockInitialValues({ThemeController.prefKey: 'system'});
    final system = ThemeController();
    await system.load(await SharedPreferences.getInstance());
    expect(system.mode, ThemeMode.system);
    system.dispose();
  });

  test('setMode notifies and persists every choice', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = ThemeController();
    await controller.load(prefs);

    var notified = 0;
    controller.addListener(() => notified++);

    await controller.setMode(ThemeMode.light);
    expect(controller.mode, ThemeMode.light);
    expect(prefs.getString(ThemeController.prefKey), 'light');

    await controller.setMode(ThemeMode.system);
    expect(prefs.getString(ThemeController.prefKey), 'system');

    await controller.setMode(ThemeMode.dark);
    expect(prefs.getString(ThemeController.prefKey), 'dark');
    expect(notified, 3);

    // setting the same mode again stays quiet
    await controller.setMode(ThemeMode.dark);
    expect(notified, 3);
    controller.dispose();
  });
}
