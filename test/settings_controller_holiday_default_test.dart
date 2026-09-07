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

  test(
    "switching the in-app language, as the user's very first settings "
    "change, still updates the still-unconfirmed holiday-country seed to "
    'match — regression test: build() seeds holidayCountryCodes once from '
    "whichever language was active *then*, but _persistNow writes the "
    'full state on every change, so the very first settings write of any '
    'kind (here: the language switch itself) used to permanently lock in '
    "the seed computed from the *old* language before this change ever "
    'took effect',
    () async {
      // Fresh install, no languageOverride yet — build() seeds 'US' from
      // the test environment's own default locale.
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

      await container
          .read(settingsControllerProvider.notifier)
          .setLanguageOverride('ko');

      expect(
        container.read(settingsControllerProvider).holidayCountryCodes,
        {'KR'},
        reason:
            'the seed should follow the language the user just switched '
            'to, not stay locked on the stale pre-switch default',
      );
      // And it's genuinely persisted, not just the in-memory state —
      // a fresh controller reading the same prefs afterward should agree.
      final reloaded = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(reloaded.dispose);
      expect(
        reloaded.read(settingsControllerProvider).holidayCountryCodes,
        {'KR'},
      );
    },
  );

  test(
    'an already-explicit holiday-country choice is never silently '
    'overwritten by a later language change',
    () async {
      SharedPreferences.setMockInitialValues({
        'settings.holidayCountryCodes': ['US'],
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container
          .read(settingsControllerProvider.notifier)
          .setLanguageOverride('ko');

      expect(
        container.read(settingsControllerProvider).holidayCountryCodes,
        {'US'},
        reason:
            'an explicit prior choice must survive a later language change',
      );
    },
  );
}
