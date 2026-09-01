import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/calendar_sync/holiday_calendar_service.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/features/settings/application/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_controller_holiday_color_test.mocks.dart';

const _feed =
    'BEGIN:VCALENDAR\r\n'
    'VERSION:2.0\r\n'
    'BEGIN:VEVENT\r\n'
    'UID:new-year@holiday\r\n'
    'SUMMARY:New Year\r\n'
    'DTSTART;VALUE=DATE:20260101\r\n'
    'DTEND;VALUE=DATE:20260102\r\n'
    'END:VEVENT\r\n'
    'END:VCALENDAR';

@GenerateMocks([http.Client])
void main() {
  late AppDatabase db;
  late MockClient client;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    client = MockClient();
  });

  tearDown(() => db.close());

  http.Response ok(String body) => http.Response(body, 200);

  /// A fresh container over [prefs] — used both for a test's initial
  /// container and, in the round-trip test, a second "app restarted"
  /// container over the very same (already-mutated) `prefs` instance.
  ProviderContainer containerOver(SharedPreferences prefs) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        holidayCalendarServiceProvider.overrideWithValue(
          HolidayCalendarService(eventDao: db.eventDao, httpClient: client),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// [initialPrefs] seeds `SharedPreferences` directly (not through the
  /// controller's own methods) — the fast, network-free way to set up "a
  /// country/URL is already selected" without a real sync call happening
  /// just to get the test into its starting state.
  Future<ProviderContainer> makeContainer(
    Map<String, Object> initialPrefs,
  ) async {
    SharedPreferences.setMockInitialValues(initialPrefs);
    return containerOver(await SharedPreferences.getInstance());
  }

  group('setHolidayCountryColor', () {
    test(
      'setting a color for an unselected country just persists it — no '
      'network call, since there is nothing mirrored yet to repaint',
      () async {
        final container = await makeContainer({});

        await container
            .read(settingsControllerProvider.notifier)
            .setHolidayCountryColor('KR', colorHex: '#3388CC');

        expect(container.read(settingsControllerProvider).holidaySourceColors, {
          'holiday:country:KR': '#3388CC',
        });
        verifyNever(client.get(any));
      },
    );

    test(
      'setting a color for an already-selected country re-syncs it, so '
      'the already-mirrored event picks up the new color immediately',
      () async {
        when(client.get(any)).thenAnswer((_) async => ok(_feed));
        final container = await makeContainer({
          'settings.holidayCalendarEnabled': true,
          'settings.holidayCountryCodes': ['KR'],
        });

        await container
            .read(settingsControllerProvider.notifier)
            .setHolidayCountryColor('KR', colorHex: '#3388CC');

        final rows = await db.eventDao.all();
        expect(rows.single.colorTag, '#3388CC');
        expect(container.read(settingsControllerProvider).holidaySourceColors, {
          'holiday:country:KR': '#3388CC',
        });
      },
    );

    test('clearing a color (colorHex: null) removes the override and re-syncs '
        'back to the default color', () async {
      when(client.get(any)).thenAnswer((_) async => ok(_feed));
      final container = await makeContainer({
        'settings.holidayCalendarEnabled': true,
        'settings.holidayCountryCodes': ['KR'],
      });
      await container
          .read(settingsControllerProvider.notifier)
          .setHolidayCountryColor('KR', colorHex: '#3388CC');

      await container
          .read(settingsControllerProvider.notifier)
          .setHolidayCountryColor('KR');

      final rows = await db.eventDao.all();
      expect(rows.single.colorTag, HolidayCalendarService.defaultColorHex);
      expect(
        container.read(settingsControllerProvider).holidaySourceColors,
        isEmpty,
      );
    });

    test('a sync failure leaves the color setting unchanged, same "sync before '
        'persisting" ordering as setHolidayCountrySelected', () async {
      when(client.get(any)).thenAnswer((_) async => http.Response('', 500));
      final container = await makeContainer({
        'settings.holidayCalendarEnabled': true,
        'settings.holidayCountryCodes': ['KR'],
      });

      await expectLater(
        container
            .read(settingsControllerProvider.notifier)
            .setHolidayCountryColor('KR', colorHex: '#3388CC'),
        throwsA(isA<HolidayCalendarSyncException>()),
      );

      expect(
        container.read(settingsControllerProvider).holidaySourceColors,
        isEmpty,
      );
    });

    test('round-trips a persisted color through a fresh container', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = containerOver(prefs);
      await container
          .read(settingsControllerProvider.notifier)
          .setHolidayCountryColor('KR', colorHex: '#3388CC');

      final resumed = containerOver(prefs);

      expect(resumed.read(settingsControllerProvider).holidaySourceColors, {
        'holiday:country:KR': '#3388CC',
      });
    });
  });

  group('setCustomHolidayColor', () {
    test(
      'setting a color for an already-selected custom URL re-syncs it',
      () async {
        when(client.get(any)).thenAnswer((_) async => ok(_feed));
        final container = await makeContainer({
          'settings.holidayCalendarEnabled': true,
          'settings.customHolidayCalendarUrls': ['https://example.com/x.ics'],
        });

        await container
            .read(settingsControllerProvider.notifier)
            .setCustomHolidayColor(
              'https://example.com/x.ics',
              colorHex: '#00AA55',
            );

        final rows = await db.eventDao.all();
        expect(rows.single.colorTag, '#00AA55');
        expect(container.read(settingsControllerProvider).holidaySourceColors, {
          'holiday:custom:https://example.com/x.ics': '#00AA55',
        });
      },
    );
  });
}
