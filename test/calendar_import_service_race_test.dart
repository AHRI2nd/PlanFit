// Round-4 settings/calendar-sync audit: unsubscribing a mirrored calendar
// (CalendarImportService.removeMirroredCalendar, called from
// SettingsController.setCalendarSubscribed) used to have no mutual exclusion
// against a concurrent CalendarReconciler.syncMirroredCalendars pass for the
// same calendar. If the reconciler's in-flight sync (already committed to a
// snapshot of subscribedCalendarIds taken before the user's toggle) finished
// *after* removeMirroredCalendar, it silently re-inserted the very rows the
// user just asked to remove -- a leak of mirrored data surviving
// unsubscription with no further reconcile pass able to clean it up (since
// the calendar is no longer in subscribedCalendarIds at all going forward).
// Fixed by serializing both through CalendarImportService._writeQueue.
import 'dart:async';

import 'package:device_calendar_plus/device_calendar_plus.dart' as dc;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/calendar_sync/calendar_import_service.dart';
import 'package:planfit/core/calendar_sync/calendar_service.dart';
import 'package:planfit/core/db/app_database.dart';

import 'calendar_import_service_race_test.mocks.dart';

@GenerateMocks([CalendarService])
void main() {
  late AppDatabase db;
  late MockCalendarService service;
  late CalendarImportService importService;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service = MockCalendarService();
    importService = CalendarImportService(
      calendarService: service,
      eventDao: db.eventDao,
    );
    when(service.allCalendars()).thenAnswer(
      (_) async => [
        const dc.Calendar(id: 'work-cal', name: 'Work', readOnly: true),
      ],
    );
  });

  tearDown(() => db.close());

  dc.Event osEvent(String instanceId, DateTime start) => dc.Event(
    eventId: 'series-$instanceId',
    instanceId: instanceId,
    calendarId: 'work-cal',
    title: 'Standup',
    startDate: start,
    endDate: start.add(const Duration(hours: 1)),
    isAllDay: false,
    availability: dc.EventAvailability.busy,
    status: dc.EventStatus.none,
    isRecurring: false,
  );

  test(
    'an in-flight syncMirroredCalendars pass no longer resurrects rows that '
    'removeMirroredCalendar deletes concurrently — the two are now '
    'serialized against each other',
    () async {
      final from = DateTime(2026, 1, 1);
      final to = DateTime(2027, 1, 1);

      // Seed one already-mirrored row, as if a prior reconcile pass already
      // pulled it in while the user was subscribed.
      when(
        service.listEvents('work-cal', from: from, to: to),
      ).thenAnswer((_) async => [osEvent('occ-1', DateTime(2026, 5, 1, 9))]);
      await importService.syncMirroredCalendars({
        'work-cal',
      }, from: from, to: to);
      expect(await db.eventDao.all(), hasLength(1));

      // Now simulate CalendarReconciler.reconcile() firing on
      // AppLifecycleState.resumed and starting a new syncMirroredCalendars
      // pass for 'work-cal' -- but its platform-channel listEvents() call
      // hasn't returned yet (a real, non-instant await in production).
      final gate = Completer<List<dc.Event>>();
      when(
        service.listEvents('work-cal', from: from, to: to),
      ).thenAnswer((_) => gate.future);

      final inFlightReconcilerSync = importService.syncMirroredCalendars({
        'work-cal',
      }, from: from, to: to);

      // While that's still suspended awaiting listEvents(), the user opens
      // Settings > Calendar Import and flips the subscription off. This is
      // exactly what SettingsController.setCalendarSubscribed(id, false)
      // does after persisting the new (now-empty) subscribedCalendarIds set.
      // Deliberately NOT awaited here: on pre-fix code (no serialization)
      // this call runs concurrently and finishes almost immediately; on
      // fixed code it's instead queued strictly behind the in-flight sync,
      // so awaiting it now (before completing `gate` below) would deadlock
      // — the whole point of the fix is that it can't start until the sync
      // above finishes, and the sync above can't finish until `gate`
      // completes.
      final unsubscribe = importService.removeMirroredCalendar('work-cal');

      // The reconciler's platform call finally resolves with the same
      // occurrence it started with (nothing changed at the OS level -- the
      // user only flipped a PlanFit-side setting, the device calendar itself
      // is untouched).
      gate.complete([osEvent('occ-1', DateTime(2026, 5, 1, 9))]);
      await inFlightReconcilerSync;
      await unsubscribe;

      // Pre-fix: the row the user just removed by unsubscribing comes back,
      // resurrected by the reconcile pass that raced it (worse, no future
      // reconcile will clean this up either, since 'work-cal' is no longer
      // in subscribedCalendarIds going forward). Fixed: removeMirroredCalendar
      // is strictly ordered after the in-flight sync, so its delete is the
      // final word regardless of how the platform-channel timing falls.
      final rows = await db.eventDao.all();
      expect(
        rows,
        isEmpty,
        reason:
            'FAILS on pre-fix code: syncMirroredCalendars and '
            'removeMirroredCalendar have no mutual exclusion, so the '
            'in-flight sync silently re-inserts the just-removed row',
      );
    },
  );
}
