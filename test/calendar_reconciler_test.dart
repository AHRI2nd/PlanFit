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
    when(notifications.refillEvents(any)).thenAnswer((_) async {});
    // Mirrors the real CalendarService.resolveTargetCalendarId(), which
    // just returns the already-configured id with no async work once one
    // exists — every test below sets targetCalendarId directly (or leaves
    // it null) rather than exercising the create-a-calendar path.
    when(
      service.resolveTargetCalendarId(),
    ).thenAnswer((_) async => service.targetCalendarId);
    // No subscribed calendars by default — most tests aren't about mirroring.
    when(service.subscribedCalendarIds).thenReturn(<String>{});
    // Off by default — most tests aren't about auto-import.
    when(service.autoImportEnabled).thenReturn(false);
    // No stuck calendar-deletion tombstones by default — most tests aren't
    // about that retry/exclusion path.
    when(dao.pendingCalendarDeletionIds()).thenAnswer((_) async => <String>{});
  });

  group('concurrency guard', () {
    test('a reconcile() call started while one is already running is a '
        'no-op, not a second overlapping run', () async {
      when(service.isEnabled).thenReturn(false);
      final now = DateTime(2026, 1, 1);
      when(dao.between(any, any)).thenAnswer((_) async => []);

      // Not awaited between the two calls — this is exactly the shape of
      // two AppLifecycleState.resumed events firing in quick succession
      // (see CalendarReconciler._reconciling's doc).
      final first = reconciler.reconcile(now: now);
      final second = reconciler.reconcile(now: now);

      expect(await second, 0);
      expect(await first, 0);
      // Proves the second call short-circuited before doing any work,
      // rather than running the whole reconcile pass a second time
      // concurrently.
      verify(dao.between(any, any)).called(1);
    });

    test(
      'a later call succeeds normally once the first has finished',
      () async {
        when(service.isEnabled).thenReturn(false);
        final now = DateTime(2026, 1, 1);
        when(dao.between(any, any)).thenAnswer((_) async => []);

        await reconciler.reconcile(now: now);
        await reconciler.reconcile(now: now);

        verify(dao.between(any, any)).called(2);
      },
    );
  });

  group('notification refill', () {
    test('runs even when calendar sync is disabled', () async {
      when(service.isEnabled).thenReturn(false);
      final now = DateTime(2026, 1, 1);
      final inWindow = row(
        id: 'e1',
        startAt: now.add(const Duration(days: 30)),
      );
      when(dao.between(any, any)).thenAnswer((_) async => [inWindow]);

      await reconciler.reconcile(now: now);

      verify(notifications.refillEvents([inWindow])).called(1);
      // Sync being off means the push/pull branches never touch the
      // calendar-linked DAO calls they'd otherwise make.
      verifyNever(dao.needingPush());
    });

    test(
      'still passes a candidate near the edge of the window through to '
      'refillEvents — refillEvents itself judges each reminder offset',
      () async {
        when(service.isEnabled).thenReturn(false);
        final now = DateTime(2026, 1, 1);
        final farOut = row(
          id: 'e2',
          startAt: now.add(const Duration(days: 90)),
        );
        when(dao.between(any, any)).thenAnswer((_) async => [farOut]);

        await reconciler.reconcile(now: now);

        verify(notifications.refillEvents([farOut])).called(1);
      },
    );

    test(
      'excludes an event with notifications turned off from the batch',
      () async {
        when(service.isEnabled).thenReturn(false);
        final now = DateTime(2026, 1, 1);
        final silent = row(
          id: 'e3',
          startAt: now.add(const Duration(days: 10)),
          notify: false,
        );
        when(dao.between(any, any)).thenAnswer((_) async => [silent]);

        await reconciler.reconcile(now: now);

        // Filtering by notify is the reconciler's own job (refillEvents has no
        // way to tell "off" apart from "on with zero offsets selected") — the
        // batch it hands off is empty, not skipped entirely, since the refill
        // still needs to run for whatever *other* candidates exist.
        verify(notifications.refillEvents([])).called(1);
      },
    );

    test('still passes a candidate whose primary alert has already passed '
        'through to refillEvents — refillEvents itself judges each reminder '
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

      verify(notifications.refillEvents([alreadyAlerted])).called(1);
    });
  });

  group('subscribed-calendar mirroring', () {
    test('runs even when calendar push-sync is disabled', () async {
      when(service.isEnabled).thenReturn(false);
      when(service.subscribedCalendarIds).thenReturn({'work-cal'});
      final now = DateTime(2026, 1, 1);
      when(dao.between(any, any)).thenAnswer((_) async => []);
      when(
        calendarImportService.syncMirroredCalendars(
          {'work-cal'},
          from: anyNamed('from'),
          to: anyNamed('to'),
        ),
      ).thenAnswer((_) async {});

      await reconciler.reconcile(now: now);

      verify(
        calendarImportService.syncMirroredCalendars(
          {'work-cal'},
          from: anyNamed('from'),
          to: anyNamed('to'),
        ),
      ).called(1);
    });

    test('is skipped entirely when nothing is subscribed', () async {
      when(service.isEnabled).thenReturn(false);
      when(dao.between(any, any)).thenAnswer((_) async => []);

      await reconciler.reconcile(now: DateTime(2026, 1, 1));

      verifyNever(
        calendarImportService.syncMirroredCalendars(
          any,
          from: anyNamed('from'),
          to: anyNamed('to'),
        ),
      );
    });
  });

  group('per-item failure isolation', () {
    // Regression coverage: any of these steps used to let one item's
    // exception `rethrow` straight out of the whole reconcile pass,
    // aborting every other item still waiting in the same loop (and every
    // later step) until whatever caused it happened to clear up on its own.
    test('one event failing to push does not block another event in the same '
        'push batch, or the pull/auto-import steps that follow', () async {
      when(service.isEnabled).thenReturn(true);
      when(service.targetCalendarId).thenReturn('cal-1');
      when(service.autoImportEnabled).thenReturn(true);
      when(service.writableCalendars()).thenAnswer((_) async => []);
      final now = DateTime(2026, 1, 1);
      final failing = row(
        id: 'fail',
        startAt: now.add(const Duration(days: 1)),
      );
      final ok = row(id: 'ok', startAt: now.add(const Duration(days: 2)));
      when(dao.needingPush()).thenAnswer((_) async => [failing, ok]);
      when(service.pushEvent(failing)).thenThrow(Exception('boom'));
      when(service.pushEvent(ok)).thenAnswer((_) async => 'os-ok');
      when(dao.patch(any, any)).thenAnswer((_) async {});
      when(dao.between(any, any)).thenAnswer((_) async => []);
      when(
        service.listEvents('cal-1', from: anyNamed('from'), to: anyNamed('to')),
      ).thenAnswer((_) async => []);
      when(syncLogDao.add(any)).thenAnswer((_) async {});

      final changes = await reconciler.reconcile(now: now);

      // The failing row never got patched; the other one still did.
      verifyNever(dao.patch('fail', any));
      verify(dao.patch('ok', any)).called(1);
      expect(changes, 1);
      // dao.between is called once for the notification refill's own
      // window query and once more for the pull step's [from, to] query —
      // both still ran afterward, rather than the push failure aborting
      // the whole pass before reaching them. The auto-import scan ran too.
      verify(dao.between(any, any)).called(2);
      verify(
        service.listEvents('cal-1', from: anyNamed('from'), to: anyNamed('to')),
      ).called(1);
      // The failure itself was logged, not silently swallowed.
      final logged = verify(syncLogDao.add(captureAny)).captured;
      expect(
        logged.any(
          (c) =>
              (c as SyncLogsCompanion).resolution.value ==
              SyncResolution.failed,
        ),
        isTrue,
      );
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

    test(
      'cancels the notification when the OS event was deleted externally',
      () async {
        when(service.isEnabled).thenReturn(true);
        when(service.targetCalendarId).thenReturn('cal-1');
        final now = DateTime(2026, 1, 1);
        final linked = row(
          id: 'e10',
          startAt: now.add(const Duration(days: 5)),
          osEventId: 'os-1',
          syncStatus: SyncStatus.synced,
        );
        when(dao.needingPush()).thenAnswer((_) async => []);
        when(dao.between(any, any)).thenAnswer((_) async => [linked]);
        // Genuinely gone from the calendar — not just missing from a
        // too-narrow query window (see the far-future test below).
        when(
          service.listEvents('cal-1', from: DateTime(2000), to: DateTime(2100)),
        ).thenAnswer((_) async => []);
        when(dao.deleteById(any)).thenAnswer((_) async {});
        when(syncLogDao.add(any)).thenAnswer((_) async {});

        await reconciler.reconcile(now: now);

        verify(notifications.cancelForEvent('e10')).called(1);
        verify(dao.deleteById('e10')).called(1);
      },
    );

    test('reschedules the notification at the new time when the OS event was '
        'edited externally', () async {
      when(service.isEnabled).thenReturn(true);
      when(service.targetCalendarId).thenReturn('cal-1');
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
      when(
        service.listEvents('cal-1', from: DateTime(2000), to: DateTime(2100)),
      ).thenAnswer((_) async => [osEvent(eventId: 'os-2', start: newStart)]);
      when(dao.patch(any, any)).thenAnswer((_) async {});
      when(dao.findById('e11')).thenAnswer((_) async => pulled);
      when(syncLogDao.add(any)).thenAnswer((_) async {});

      await reconciler.reconcile(now: now);

      verify(notifications.scheduleForEvent(pulled)).called(1);
      verifyNever(notifications.cancelForEvent('e11'));
    });

    test('still finds (and pulls, rather than treats as deleted) an event '
        "moved outside this reconcile's own [from, to] window — regression "
        'test: the batched replacement for a plain fetchEvent() call must '
        'query a bound wide enough to still find it by id, not just '
        '[from, to]', () async {
      when(service.isEnabled).thenReturn(true);
      when(service.targetCalendarId).thenReturn('cal-1');
      final now = DateTime(2026, 1, 1);
      final oldStart = now.add(const Duration(days: 5));
      // Well outside reconcile()'s default 90-day lookAhead — the exact
      // shape of bug this test guards against: mistaking "moved far away"
      // for "deleted".
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
      when(
        service.listEvents('cal-1', from: DateTime(2000), to: DateTime(2100)),
      ).thenAnswer(
        (_) async => [osEvent(eventId: 'os-3', start: farFutureStart)],
      );
      when(dao.patch(any, any)).thenAnswer((_) async {});
      when(dao.findById('e12')).thenAnswer((_) async => pulled);
      when(syncLogDao.add(any)).thenAnswer((_) async {});

      await reconciler.reconcile(now: now);

      verify(
        service.listEvents('cal-1', from: DateTime(2000), to: DateTime(2100)),
      ).called(1);
      verify(notifications.scheduleForEvent(pulled)).called(1);
      verifyNever(notifications.cancelForEvent('e12'));
      verifyNever(dao.deleteById(any));
    });

    test('leaves every synced row untouched when no target calendar can be '
        'resolved at all — regression test: this must not read "couldn\'t '
        'check" as "everything in it was deleted"', () async {
      when(service.isEnabled).thenReturn(true);
      // No target calendar available — resolveTargetCalendarId() (per the
      // shared setUp() default) then resolves to null too.
      when(service.targetCalendarId).thenReturn(null);
      final now = DateTime(2026, 1, 1);
      final linked = row(
        id: 'e13',
        startAt: now.add(const Duration(days: 5)),
        osEventId: 'os-4',
        syncStatus: SyncStatus.synced,
      );
      when(dao.needingPush()).thenAnswer((_) async => []);
      when(dao.between(any, any)).thenAnswer((_) async => [linked]);

      final changes = await reconciler.reconcile(now: now);

      expect(changes, 0);
      verifyNever(dao.deleteById(any));
      verifyNever(dao.patch(any, any));
      verifyNever(notifications.cancelForEvent(any));
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

      verifyNever(
        service.listEvents(any, from: anyNamed('from'), to: anyNamed('to')),
      );
      verifyNever(dao.upsert(any));
    });

    test('on — an event added directly in the target calendar is imported as '
        'a new PlanFit event, notifications off', () async {
      when(service.isEnabled).thenReturn(true);
      when(service.autoImportEnabled).thenReturn(true);
      when(service.targetCalendarId).thenReturn('cal-1');
      when(
        service.writableCalendars(),
      ).thenAnswer((_) async => <dc.Calendar>[]);
      final now = DateTime(2026, 1, 1);
      final start = now.add(const Duration(days: 2));
      when(dao.needingPush()).thenAnswer((_) async => []);
      when(dao.between(any, any)).thenAnswer((_) async => []);
      when(
        service.listEvents('cal-1', from: anyNamed('from'), to: anyNamed('to')),
      ).thenAnswer((_) async => [osEvent(eventId: 'os-new', start: start)]);
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
    });

    test('on — the imported event is tagged with the target calendar\'s own '
        'OS color, not left to fall back to the generic gradient', () async {
      when(service.isEnabled).thenReturn(true);
      when(service.autoImportEnabled).thenReturn(true);
      when(service.targetCalendarId).thenReturn('cal-1');
      when(service.writableCalendars()).thenAnswer(
        (_) async => [
          const dc.Calendar(
            id: 'cal-1',
            name: 'PlanFit',
            colorHex: '#4B5FD6',
            readOnly: false,
          ),
        ],
      );
      final now = DateTime(2026, 1, 1);
      final start = now.add(const Duration(days: 2));
      when(dao.needingPush()).thenAnswer((_) async => []);
      when(dao.between(any, any)).thenAnswer((_) async => []);
      when(
        service.listEvents('cal-1', from: anyNamed('from'), to: anyNamed('to')),
      ).thenAnswer((_) async => [osEvent(eventId: 'os-new', start: start)]);
      when(dao.upsert(any)).thenAnswer((_) async {});
      when(syncLogDao.add(any)).thenAnswer((_) async {});

      await reconciler.reconcile(now: now);

      final captured =
          verify(dao.upsert(captureAny)).captured.single as EventsCompanion;
      expect(captured.colorTag.value, '#4B5FD6');
    });

    test(
      'on — an OS event already linked to a local row is not re-imported',
      () async {
        when(service.isEnabled).thenReturn(true);
        when(service.autoImportEnabled).thenReturn(true);
        when(service.targetCalendarId).thenReturn('cal-1');
        when(
          service.writableCalendars(),
        ).thenAnswer((_) async => <dc.Calendar>[]);
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
        // Covers both step 2's own batched lookup (see the "pulling
        // changes" group above) and step 3's calendar scan below — both
        // call listEvents('cal-1', ...), just with different bounds.
        when(
          service.listEvents(
            'cal-1',
            from: anyNamed('from'),
            to: anyNamed('to'),
          ),
        ).thenAnswer(
          (_) async => [
            osEvent(
              eventId: 'os-existing',
              start: start,
              title: existing.title,
            ),
          ],
        );

        final changes = await reconciler.reconcile(now: now);

        expect(changes, 0);
        verifyNever(dao.upsert(any));
      },
    );

    test('on — an event added directly to the device\'s primary calendar '
        '(not the PlanFit target calendar) is imported too', () async {
      when(service.isEnabled).thenReturn(true);
      when(service.autoImportEnabled).thenReturn(true);
      when(service.targetCalendarId).thenReturn('cal-planfit');
      when(service.writableCalendars()).thenAnswer(
        (_) async => [
          const dc.Calendar(
            id: 'cal-default',
            name: 'Calendar',
            colorHex: '#EA4335',
            readOnly: false,
            isPrimary: true,
          ),
        ],
      );
      final now = DateTime(2026, 1, 1);
      final start = now.add(const Duration(days: 2));
      when(dao.needingPush()).thenAnswer((_) async => []);
      when(dao.between(any, any)).thenAnswer((_) async => []);
      when(
        service.listEvents(
          'cal-planfit',
          from: anyNamed('from'),
          to: anyNamed('to'),
        ),
      ).thenAnswer((_) async => []);
      when(
        service.listEvents(
          'cal-default',
          from: anyNamed('from'),
          to: anyNamed('to'),
        ),
      ).thenAnswer(
        (_) async => [
          osEvent(eventId: 'os-default', start: start, title: '밥먹기'),
        ],
      );
      when(dao.upsert(any)).thenAnswer((_) async {});
      when(syncLogDao.add(any)).thenAnswer((_) async {});

      final changes = await reconciler.reconcile(now: now);

      expect(changes, 1);
      final captured =
          verify(dao.upsert(captureAny)).captured.single as EventsCompanion;
      expect(captured.title.value, '밥먹기');
      expect(captured.osEventId.value, 'os-default');
      expect(captured.osCalendarId.value, 'cal-1');
      // Tagged with the primary calendar's own color, not left null to
      // fall back to the generic time-of-day gradient.
      expect(captured.colorTag.value, '#EA4335');
    });

    test('on — a primary calendar the user already subscribed to is not '
        'double-scanned by auto-import', () async {
      when(service.isEnabled).thenReturn(true);
      when(service.autoImportEnabled).thenReturn(true);
      when(service.targetCalendarId).thenReturn('cal-planfit');
      when(service.subscribedCalendarIds).thenReturn({'cal-default'});
      when(service.writableCalendars()).thenAnswer(
        (_) async => [
          const dc.Calendar(
            id: 'cal-default',
            name: 'Calendar',
            readOnly: false,
            isPrimary: true,
          ),
        ],
      );
      final now = DateTime(2026, 1, 1);
      when(dao.needingPush()).thenAnswer((_) async => []);
      when(dao.between(any, any)).thenAnswer((_) async => []);
      when(
        calendarImportService.syncMirroredCalendars(
          {'cal-default'},
          from: anyNamed('from'),
          to: anyNamed('to'),
        ),
      ).thenAnswer((_) async {});
      when(
        service.listEvents(
          'cal-planfit',
          from: anyNamed('from'),
          to: anyNamed('to'),
        ),
      ).thenAnswer((_) async => []);

      await reconciler.reconcile(now: now);

      verifyNever(
        service.listEvents(
          'cal-default',
          from: anyNamed('from'),
          to: anyNamed('to'),
        ),
      );
    });

    test(
      'on — an OS event still pending confirmation of an earlier delete is '
      'not resurrected, even though nothing links to it locally — '
      'regression test: the local row that used to carry this osEventId is '
      'already gone by the time this scan runs, so without the pending-'
      'deletion tombstone this looked exactly like a brand-new event',
      () async {
        when(service.isEnabled).thenReturn(true);
        when(service.autoImportEnabled).thenReturn(true);
        when(service.targetCalendarId).thenReturn('cal-1');
        when(
          service.writableCalendars(),
        ).thenAnswer((_) async => <dc.Calendar>[]);
        when(
          dao.pendingCalendarDeletionIds(),
        ).thenAnswer((_) async => {'os-stuck'});
        when(
          service.deleteEventById('os-stuck'),
        ).thenThrow(Exception('still unreachable'));
        final now = DateTime(2026, 1, 1);
        final start = now.add(const Duration(days: 2));
        when(dao.needingPush()).thenAnswer((_) async => []);
        when(dao.between(any, any)).thenAnswer((_) async => []);
        when(
          service.listEvents(
            'cal-1',
            from: anyNamed('from'),
            to: anyNamed('to'),
          ),
        ).thenAnswer((_) async => [osEvent(eventId: 'os-stuck', start: start)]);

        final changes = await reconciler.reconcile(now: now);

        expect(changes, 0);
        verifyNever(dao.upsert(any));
        verifyNever(dao.clearPendingCalendarDeletion(any));
      },
    );

    test('retries a pending calendar deletion every reconcile pass and clears '
        'its tombstone once the OS event is confirmed actually gone', () async {
      when(service.isEnabled).thenReturn(true);
      when(dao.needingPush()).thenAnswer((_) async => []);
      when(dao.between(any, any)).thenAnswer((_) async => []);
      when(
        dao.pendingCalendarDeletionIds(),
      ).thenAnswer((_) async => {'os-retry'});
      when(service.deleteEventById('os-retry')).thenAnswer((_) async {});
      when(
        dao.clearPendingCalendarDeletion('os-retry'),
      ).thenAnswer((_) async {});

      await reconciler.reconcile(now: DateTime(2026, 1, 1));

      verify(service.deleteEventById('os-retry')).called(1);
      verify(dao.clearPendingCalendarDeletion('os-retry')).called(1);
    });
  });
}
