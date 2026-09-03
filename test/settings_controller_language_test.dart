import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/features/settings/application/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults to null (follow system) when nothing is persisted yet', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(settingsControllerProvider).languageOverride,
      isNull,
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
        .setLanguageOverride('ja');
    expect(
      container.read(settingsControllerProvider).languageOverride,
      'ja',
    );

    final restarted = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(restarted.dispose);
    expect(
      restarted.read(settingsControllerProvider).languageOverride,
      'ja',
    );
  });

  test('setting it back to null reverts to following the system locale', () async {
    SharedPreferences.setMockInitialValues({
      'settings.languageOverride': 'en',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    expect(
      container.read(settingsControllerProvider).languageOverride,
      'en',
    );

    await container
        .read(settingsControllerProvider.notifier)
        .setLanguageOverride(null);
    expect(
      container.read(settingsControllerProvider).languageOverride,
      isNull,
    );

    final restarted = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(restarted.dispose);
    expect(
      restarted.read(settingsControllerProvider).languageOverride,
      isNull,
    );
  });
}
