import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/features/settings/application/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'a fresh install seeds the default holiday country from '
    "languageOverride, not just the device's own OS locale — regression "
    'test: defaultHolidayCountryCode() used to only ever read '
    'PlatformDispatcher.instance.locale, so a user whose phone is set to '
    'English but who immediately overrides the in-app language to '
    'Japanese would still get US holidays seeded as the "auto" default, '
    'silently disagreeing with the language they actually chose',
    () async {
      SharedPreferences.setMockInitialValues({
        'settings.languageOverride': 'ja',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(settingsControllerProvider).holidayCountryCodes,
        {'JP'},
      );
    },
  );

  test(
    'with no languageOverride persisted, the seed falls back to the '
    "device's own OS locale exactly as before — the test environment's "
    "own default locale isn't Korean or Japanese, so this should land on "
    'the US fallback',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(settingsControllerProvider).holidayCountryCodes,
        {'US'},
      );
    },
  );
}
