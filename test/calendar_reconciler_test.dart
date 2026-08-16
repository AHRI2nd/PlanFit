import 'package:device_calendar_plus/device_calendar_plus.dart' as dc;
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/calendar_sync/calendar_import_service.dart';
import 'package:planfit/core/calendar_sync/calendar_reconciler.dart';
import 'package:planfit/core/calendar_sync/calendar_service.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/daos/event_dao.dart';
import 'package:planfit/core/db/daos/sync_log_dao.dart';
import 'package:planfit/core/db/sync_status.dart';
import 'package:planfit/features/schedule/domain/ports.dart';

import 'calendar_reconciler_test.mocks.dart';

@GenerateMocks([
  CalendarService,
  EventDao,
  NotificationPort,
  SyncLogDao,
  CalendarImportService,
])
void main() {
  late MockCalendarService service;
  late MockEventDao dao;
  late MockNotificationPort notifications;
  late MockSyncLogDao syncLogDao;
  late MockCalendarImportService calendarImportService;
  late CalendarReconciler reconciler;

  EventRow row({
    required String id,
    required DateTime startAt,
    DateTime? endAt,
    bool notify = true,
    int reminderMinutesBefore = 0,
    String? osEventId,
    SyncStatus syncStatus = SyncStatus.pendingPush,
  }) {
    return EventRow(
      id: id,
      title: id,
      memo: null,
      startAt: startAt,
      endAt: endAt ?? startAt.add(const Duration(hours: 1)),
      isAllDay: false,
      notify: notify,
      reminderMinutesBefore: reminderMinutesBefore,
      colorTag: null,
      recurrenceRule: null,
      recurrenceGroupId: null,
      osCalendarId: null,
      osEventId: osEventId,
      osLastKnownModified: null,
      syncStatus: syncStatus,
      createdAt: DateTime(2020),
      updatedAt: DateTime(2020),
    );
  }

  setUp(() {
    service = MockCalendarService();
    dao = MockEventDao();
    notifications = MockNotificationPort();
    syncLogDao = MockSyncLogDao();
    calendarImportService = MockCalendarImportService();
    reconciler = CalendarReconciler(
      service: service,
      eventDao: dao,
      syncLogDao: syncLogDao,
      notifications: notifications,
      calendarImportService: calendarImportService,
    );
    when(notifications.scheduleForEvent(any)).thenAnswer((_) async {});
    when(notifications.cancelForEvent(any)).thenAnswer((_) async {});
    // No subscribed calendars by default — most tests aren't about mirroring.
    when(service.subscribedCalendarIds).thenReturn(<String>{});
    // Off by default — most tests aren't about auto-import.
    when(service.autoImportEnabled).thenReturn(false);
  });

  group('notification refill', () {
    test('runs even when calendar sync is disabled', () async {
      when(service.isEnabled).thenReturn(false);
      final now = DateTime(2026, 1, 1);
      final inWindow = row(id: 'e1', startAt: now.add(const Duration(days: 30)));
      when(dao.between(any, any)).thenAnswer((_) async => [inWindow]);

      await reconciler.reconcile(now: now);

      verify(notifications.scheduleForEvent(inWindow)).called(1);
      // Sync being off means the push/pull branches never touch the
      // calendar-linked DAO calls they'd otherwise make.
      verifyNever(dao.needingPush());
    });

    test(
        'still calls scheduleForEvent for a candidate near the edge of the '
        'window — scheduleForEvent itself judges each reminder offset',
        () async {
      when(service.isEnabled).thenReturn(false);
      final now = DateTime(2026, 1, 1);
      final farOut = row(id: 'e2', startAt: now.add(const Duration(days: 90)));
      when(dao.between(any, any)).thenAnswer((_) async => [farOut]);

      await reconciler.reconcile(now: now);

      verify(notifications.scheduleForEvent(farOut)).called(1);
    });

    test('skips an event with notifications turned off', () async {
      when(service.isEnabled).thenReturn(false);
      final now = DateTime(2026, 1, 1);
      final silent = row(
        id: 'e3',
        startAt: now.add(const Duration(days: 10)),
        notify: false,
      );
      when(dao.between(any, any)).thenAnswer((_) async => [silent]);

      await reconciler.reconcile(now: now);

      verifyNever(notifications.scheduleForEvent(any));
    });

    test(
        'still calls scheduleForEvent for a candidate whose primary alert '
        'has already passed — scheduleForEvent itself judges each reminder '
        'offset', () async {
      when(service.isEnabled).thenReturn(false);
      final now = DateTime(2026, 1, 1);
      // Starts inside the window, but a long lead time pulls the primary
      // alert into the past relative to "now".
      final alreadyAlerted = row(
        id: 'e4',
        startAt: now.add(const Duration(hours: 1)),
        reminderMinutesBefore: 1440,
      );
      when(dao.between(any, any)).thenAnswer((_) async => [alreadyAlerted]);

      await reconciler.reconcile(now: now);

      verify(notifications.scheduleForEvent(alreadyAlerted)).called(1);
    });
  });

  group('subscribed-calendar mirroring', () {
    test('runs even when calendar push-sync is disabled', () async {
      when(service.isEnabled).thenReturn(false);
      when(service.subscribedCalendarIds).thenReturn({'work-cal'});
      final now = DateTime(2026, 1, 1);
      when(dao.between(any, any)).thenAnswer((_) async => []);
      when(calendarImportService.syncMirroredCalendars(
        {'work-cal'},
        from: anyNamed('from'),
        to: anyNamed('to'),
      )).thenAnswer((_) async {});

      await reconciler.reconcile(now: now);

      verify(calendarImportService.syncMirroredCalendars(
        {'work-cal'},
        from: anyNamed('from'),
        to: anyNamed('to'),
      )).called(1);
    });

    test('is skipped entirely when nothing is subscribed', () async {
      when(service.isEnabled).thenReturn(false);
      when(dao.between(any, any)).thenAnswer((_) async => []);

      await reconciler.reconcile(now: DateTime(2026, 1, 1));

      verifyNever(calendarImportService.syncMirroredCalendars(
        any,
        from: anyNamed('from'),
        to: anyNamed('to'),
      ));
    });
  });

  group('pulling changes from the calendar app', () {
    dc.Event osEvent({
      required String eventId,
      required DateTime start,
      String title = 'Meeting',
    }) {
      return dc.Event(
        eventId: eventId,
        instanceId: eventId,
        calendarId: 'cal-1',
        title: title,
        startDate: start,
        endDate: start.add(const Duration(hours: 1)),
        isAllDay: false,
        availability: dc.EventAvailability.busy,
        status: dc.EventStatus.none,
        isRecurring: false,
      );
    }

    test('cancels the notification when the OS event was deleted externally',
        () async {
      when(service.isEnabled).thenReturn(true);
      final now = DateTime(2026, 1, 1);
      final linked = row(
        id: 'e10',
        startAt: now.add(const Duration(days: 5)),
        osEventId: 'os-1',
        syncStatus: SyncStatus.synced,
      );
      when(dao.needingPush()).thenAnswer((_) async => []);
      when(dao.between(any, any)).thenAnswer((_) async => [linked]);
      when(service.fetchEvent('os-1')).thenAnswer((_) async => null);
      when(dao.deleteById(any)).thenAnswer((_) async {});
      when(syncLogDao.add(any)).thenAnswer((_) async {});

      await reconciler.reconcile(now: now);

      verify(notifications.cancelForEvent('e10')).called(1);
      verify(dao.deleteById('e10')).called(1);
    });

    test(
        'reschedules the notification at the new time when the OS event was '
        'edited externally', () async {
      when(service.isEnabled).thenReturn(true);
      final now = DateTime(2026, 1, 1);
      final oldStart = now.add(const Duration(days: 5, hours: 9));
      final newStart = now.add(const Duration(days: 5, hours: 15));
      final linked = row(
        id: 'e11',
        startAt: oldStart,
        osEventId: 'os-2',
        syncStatus: SyncStatus.synced,
      );
      final pulled = row(
        id: 'e11',
        startAt: newStart,
        osEventId: 'os-2',
        syncStatus: SyncStatus.synced,
      );
      when(dao.needingPush()).thenAnswer((_) async => []);
      when(dao.between(any, any)).thenAnswer((_) async => [linked]);
      when(service.fetchEvent('os-2'))
          .thenAnswer((_) async => osEvent(eventId: 'os-2', start: newStart));
      when(dao.patch(any, any)).thenAnswer((_) async {});
      when(dao.findById('e11')).thenAnswer((_) async => pulled);
      when(syncLogDao.add(any)).thenAnswer((_) async {});

      await reconciler.reconcile(now: now);

      verify(notifications.scheduleForEvent(pulled)).called(1);
      verifyNever(notifications.cancelForEvent('e11'));
    });

    test(
        'still calls scheduleForEvent when the externally-edited time moved '
        'far into the future — scheduleForEvent itself judges each reminder '
        'offset against the window', () async {
      when(service.isEnabled).thenReturn(true);
      final now = DateTime(2026, 1, 1);
      final oldStart = now.add(const Duration(days: 5));
      final farFutureStart = now.add(const Duration(days: 400));
      final linked = row(
        id: 'e12',
        startAt: oldStart,
        osEventId: 'os-3',
        syncStatus: SyncStatus.synced,
      );
      final pulled = row(
        id: 'e12',
        startAt: farFutureStart,
        osEventId: 'os-3',
        syncStatus: SyncStatus.synced,
      );
      when(dao.needingPush()).thenAnswer((_) async => []);
      when(dao.between(any, any)).thenAnswer((_) async => [linked]);
      when(service.fetchEvent('os-3')).thenAnswer(
          (_) async => osEvent(eventId: 'os-3', start: farFutureStart));
      when(dao.patch(any, any)).thenAnswer((_) async {});
      when(dao.findById('e12')).thenAnswer((_) async => pulled);
      when(syncLogDao.add(any)).thenAnswer((_) async {});

      await reconciler.reconcile(now: now);

      verify(notifications.scheduleForEvent(pulled)).called(1);
      verifyNever(notifications.cancelForEvent('e12'));
    });
  });

  group('auto-import from the calendar app', () {
    dc.Event osEvent({
      required String eventId,
      required DateTime start,
      String title = 'Off-app event',
    }) {
      return dc.Event(
        eventId: eventId,
        instanceId: eventId,
        calendarId: 'cal-1',
        title: title,
        startDate: start,
        endDate: start.add(const Duration(hours: 1)),
        isAllDay: false,
        availability: dc.EventAvailability.busy,
        status: dc.EventStatus.none,
        isRecurring: false,
      );
    }

    test('off by default — an unlinked OS event is left alone', () async {
      when(service.isEnabled).thenReturn(true);
      when(service.autoImportEnabled).thenReturn(false);
      when(service.targetCalendarId).thenReturn('cal-1');
      when(dao.needingPush()).thenAnswer((_) async => []);
      when(dao.between(any, any)).thenAnswer((_) async => []);

      await reconciler.reconcile(now: DateTime(2026, 1, 1));

      verifyNever(service.listEvents(any, from: anyNamed('from'), to: anyNamed('to')));
      verifyNever(dao.upsert(any));
    });

    test(
      'on — an event added directly in the target calendar is imported as '
      'a new PlanFit event, notifications off',
      () async {
        when(service.isEnabled).thenReturn(true);
        when(service.autoImportEnabled).thenReturn(true);
        when(service.targetCalendarId).thenReturn('cal-1');
        final now = DateTime(2026, 1, 1);
        final start = now.add(const Duration(days: 2));
        when(dao.needingPush()).thenAnswer((_) async => []);
        when(dao.between(any, any)).thenAnswer((_) async => []);
        when(service.listEvents('cal-1', from: anyNamed('from'), to: anyNamed('to')))
            .thenAnswer((_) async => [osEvent(eventId: 'os-new', start: start)]);
        when(dao.upsert(any)).thenAnswer((_) async {});
        when(syncLogDao.add(any)).thenAnswer((_) async {});

        final changes = await reconciler.reconcile(now: now);

        expect(changes, 1);
        final captured =
            verify(dao.upsert(captureAny)).captured.single as EventsCompanion;
        expect(captured.title.value, 'Off-app event');
        expect(captured.osEventId.value, 'os-new');
        expect(captured.osCalendarId.value, 'cal-1');
        expect(captured.syncStatus.value, SyncStatus.synced);
        // Not created through the user, so it must not silently start
        // alerting them — same reasoning as CalendarImportService's mirror
        // rows.
        expect(captured.notify.value, isFalse);
      },
    );

    test(
      'on — an OS event already linked to a local row is not re-imported',
      () async {
        when(service.isEnabled).thenReturn(true);
        when(service.autoImportEnabled).thenReturn(true);
        when(service.targetCalendarId).thenReturn('cal-1');
        final now = DateTime(2026, 1, 1);
        final start = now.add(const Duration(days: 2));
        final existing = row(
          id: 'e-existing',
          startAt: start,
          osEventId: 'os-existing',
          syncStatus: SyncStatus.synced,
        );
        when(dao.needingPush()).thenAnswer((_) async => []);
        when(dao.between(any, any)).thenAnswer((_) async => [existing]);
        when(service.fetchEvent('os-existing')).thenAnswer(
          (_) async => osEvent(eventId: 'os-existing', start: start, title: existing.title),
        );
        when(service.listEvents('cal-1', from: anyNamed('from'), to: anyNamed('to')))
            .thenAnswer((_) async => [
                  osEvent(eventId: 'os-existing', start: start, title: existing.title),
                ]);

        final changes = await reconciler.reconcile(now: now);

        expect(changes, 0);
        verifyNever(dao.upsert(any));
      },
    );
  });
}
