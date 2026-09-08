// Round-4 settings/holiday-sync audit: syncCountry (driven by app.dart's
// background resume-sync, a genuinely slow network fetch) and
// unsubscribeCountry (driven the moment the user deselects a country in
// Settings) used to have no mutual exclusion. An in-flight sync -- already
// committed to a feed it fetched *before* the user's deselection -- could
// finish its upsert step *after* unsubscribeCountry's delete and silently
// resurrect the very rows the user just removed, with no later resume-sync
// able to clean it up (the country is no longer selected, so nothing
// revisits it). Fixed by serializing both through
// HolidayCalendarService._writeQueue -- same pattern (and same underlying
// SerialQueue) as CalendarImportService's fix for the analogous calendar-
// mirror race.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/calendar_sync/holiday_calendar_service.dart';
import 'package:planfit/core/db/app_database.dart';

import 'holiday_calendar_service_race_test.mocks.dart';

const _feedWithOne =
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
  late HolidayCalendarService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    client = MockClient();
    service = HolidayCalendarService(eventDao: db.eventDao, httpClient: client);
  });

  tearDown(() => db.close());

  test(
    'an in-flight syncCountry pass no longer resurrects rows that '
    'unsubscribeCountry deletes concurrently — the two are now serialized '
    'against each other',
    () async {
      // Seed one already-mirrored row, as if a prior resume-sync already
      // pulled it in while the country was still selected.
      when(client.get(any)).thenAnswer((_) async => http.Response(_feedWithOne, 200));
      await service.syncCountry('KR');
      expect(await db.eventDao.all(), hasLength(1));

      // Now simulate app.dart's background resume-sync firing on
      // AppLifecycleState.resumed and starting a new syncCountry('KR') pass
      // -- but its network fetch hasn't returned yet (a real, non-instant
      // await in production).
      final gate = Completer<http.Response>();
      when(client.get(any)).thenAnswer((_) => gate.future);
      final inFlightResumeSync = service.syncCountry('KR');

      // While that's still suspended awaiting the network, the user opens
      // Settings and deselects KR — exactly what
      // SettingsController.setHolidayCountrySelected('KR', false) does.
      // Deliberately NOT awaited yet: on fixed code this is queued strictly
      // behind the in-flight sync, so awaiting it now (before completing
      // `gate`) would deadlock.
      final unsubscribe = service.unsubscribeCountry('KR');

      // The network call finally resolves with the same feed it started
      // with (nothing changed upstream — the user only flipped a
      // PlanFit-side setting).
      gate.complete(http.Response(_feedWithOne, 200));
      await inFlightResumeSync;
      await unsubscribe;

      // Pre-fix: the row the user just removed by deselecting KR comes
      // back, resurrected by the resume-sync that raced it. Fixed:
      // unsubscribeCountry is strictly ordered after the in-flight sync, so
      // its delete is the final word regardless of network timing.
      final rows = await db.eventDao.all();
      expect(
        rows,
        isEmpty,
        reason:
            'FAILS on pre-fix code: syncCountry and unsubscribeCountry have '
            'no mutual exclusion, so the in-flight sync silently re-inserts '
            'the just-removed row',
      );
    },
  );
}
