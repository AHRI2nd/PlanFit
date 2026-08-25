import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/features/settings/application/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults to ThemeMode.system when nothing is persisted yet', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(settingsControllerProvider).themeMode,
      ThemeMode.system,
    );
  });

  test('round-trips a persisted choice through a fresh container', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container
        .read(settingsControllerProvider.notifier)
        .setThemeMode(ThemeMode.dark);

    final restarted = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(restarted.dispose);
    expect(
      restarted.read(settingsControllerProvider).themeMode,
      ThemeMode.dark,
    );
  });

  test(
    'an out-of-range stored index (corrupted prefs, or a restore from a '
    'different app version) falls back to system instead of crashing '
    'the app on launch',
    () async {
      // 99 is not a valid ThemeMode.values index — indexing straight into
      // ThemeMode.values with this would throw a RangeError out of build(),
      // crashing on every single launch until app data is cleared.
      SharedPreferences.setMockInitialValues({'settings.themeMode': 99});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(settingsControllerProvider).themeMode,
        ThemeMode.system,
      );
    },
  );

  test('a negative stored index also falls back to system', () async {
    SharedPreferences.setMockInitialValues({'settings.themeMode': -1});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(settingsControllerProvider).themeMode,
      ThemeMode.system,
    );
  });
}
