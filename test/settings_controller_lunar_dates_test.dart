import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/features/settings/application/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults to true when nothing is persisted yet', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(settingsControllerProvider).showLunarDates, isTrue);
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
        .setShowLunarDates(false);
    expect(
      container.read(settingsControllerProvider).showLunarDates,
      isFalse,
    );

    final restarted = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(restarted.dispose);
    expect(
      restarted.read(settingsControllerProvider).showLunarDates,
      isFalse,
    );
  });
}
