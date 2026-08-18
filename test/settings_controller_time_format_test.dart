import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/features/settings/application/app_settings.dart';
import 'package:planfit/features/settings/application/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('both default to system, then set() + a fresh container (app '
      'restart) reads each persisted choice back independently', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);

    expect(
      container.read(settingsControllerProvider).dialTimeFormatPreference,
      TimeFormatPreference.system,
    );
    expect(
      container.read(settingsControllerProvider).displayTimeFormatPreference,
      TimeFormatPreference.system,
    );

    await container
        .read(settingsControllerProvider.notifier)
        .setDialTimeFormatPreference(TimeFormatPreference.h24);
    // Setting the dial's preference must not touch the display preference —
    // the two are meant to be fully independent (see AppSettings' doc).
    expect(
      container.read(settingsControllerProvider).dialTimeFormatPreference,
      TimeFormatPreference.h24,
    );
    expect(
      container.read(settingsControllerProvider).displayTimeFormatPreference,
      TimeFormatPreference.system,
    );

    await container
        .read(settingsControllerProvider.notifier)
        .setDisplayTimeFormatPreference(TimeFormatPreference.h12);
    expect(
      container.read(settingsControllerProvider).dialTimeFormatPreference,
      TimeFormatPreference.h24,
    );
    expect(
      container.read(settingsControllerProvider).displayTimeFormatPreference,
      TimeFormatPreference.h12,
    );

    final restarted = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(restarted.dispose);
    expect(
      restarted.read(settingsControllerProvider).dialTimeFormatPreference,
      TimeFormatPreference.h24,
    );
    expect(
      restarted.read(settingsControllerProvider).displayTimeFormatPreference,
      TimeFormatPreference.h12,
    );
  });
}
