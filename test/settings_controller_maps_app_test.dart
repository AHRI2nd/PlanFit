import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/features/settings/application/app_settings.dart';
import 'package:planfit/features/settings/application/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults to system, then set() + a fresh container (app restart) '
      'reads the persisted choice back', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(settingsControllerProvider).mapsAppPreference,
      MapsAppPreference.system,
    );

    await container
        .read(settingsControllerProvider.notifier)
        .setMapsAppPreference(MapsAppPreference.googleMaps);
    expect(
      container.read(settingsControllerProvider).mapsAppPreference,
      MapsAppPreference.googleMaps,
    );

    final restarted = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(restarted.dispose);
    expect(
      restarted.read(settingsControllerProvider).mapsAppPreference,
      MapsAppPreference.googleMaps,
    );
  });
}
