import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/daos/event_dao.dart';
import 'package:planfit/core/db/sync_status.dart';
import 'package:planfit/features/schedule/data/event_repository_impl.dart';
import 'package:planfit/features/schedule/domain/event_input.dart';
import 'package:planfit/features/schedule/domain/ports.dart';
import 'package:planfit/features/schedule/domain/recurrence.dart';

import 'event_repository_test.mocks.dart';

@GenerateMocks([EventDao, NotificationPort, CalendarPort])
void main() {
  late MockEventDao dao;
  late MockNotificationPort notifications;
  late MockCalendarPort calendar;
  late EventRepositoryImpl repo;

  /// Builds a stored row as it would exist after a prior save — [id] is
  /// looked up via `dao.findById` to distinguish create vs. edit.
  EventRow row({
    required String id,
    String title = 'Existing',
    String? memo,
    required DateTime startAt,
    required DateTime endAt,
    bool notify = true,
    int reminderMinutesBefore = 0,
    String? colorTag,
    String? recurrenceRule,
    String? recurrenceGroupId,
    String? osEventId,
    String? osCalendarId,
    String? importSourceCalendarId,
    SyncStatus syncStatus = SyncStatus.pendingPush,
  }) {
    final now = DateTime(2020);
    return EventRow(
      id: id,
      title: title,
      memo: memo,
      startAt: startAt,
      endAt: endAt,
      isAllDay: false,
      notify: notify,
      reminderMinutesBefore: reminderMinutesBefore,
      colorTag: colorTag,
      recurrenceRule: recurrenceRule,
      recurrenceGroupId: recurrenceGroupId,
      osCalendarId: osCalendarId,
      osEventId: osEventId,
      osLastKnownModified: null,
      syncStatus: syncStatus,
      importSourceCalendarId: importSourceCalendarId,
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() {
    dao = MockEventDao();
    notifications = MockNotificationPort();
    calendar = MockCalendarPort();
    repo = EventRepositoryImpl(
      dao: dao,
      notifications: notifications,
      calendar: calendar,
    );
    when(calendar.isEnabled).thenReturn(false);
    // upsert/patch just need to succeed; findById below is what the
    // repository re-reads after each write, so that's the source of truth
    // for what the "saved" row looks like in each test.
    when(dao.upsert(any)).thenAnswer((_) async {});
    when(dao.patch(any, any)).thenAnswer((_) async {});
    when(dao.deleteById(any)).thenAnswer((_) async {});
    // The mock doesn't have a real transaction to run — just invoke the
    // wrapped action directly so recurring-save/delete-series tests still
    // exercise it. Mockito stubs generic methods per concrete type
    // argument, so both instantiations actually used need their own stub.
    when(dao.transaction<EventRow>(any)).thenAnswer(
      (invocation) =>
          (invocation.positionalArguments[0] as Future<EventRow> Function())(),
    );
    when(dao.transaction<void>(any)).thenAnswer(
      (invocation) =>
          (invocation.positionalArguments[0] as Future<void> Function())(),
    );
  });

  group('save — new one-off event', () {
    test(
      'upserts once and schedules a notification for a future start',
      () async {
        final start = DateTime.now().add(const Duration(hours: 2));
        final end = start.add(const Duration(hours: 1));
        when(dao.findById('e1')).thenAnswer(
          (_) async =>
              row(id: 'e1', title: 'Meeting', startAt: start, endAt: end),
        );

        final result = await repo.save(
          EventInput(id: 'e1', title: 'Meeting', startAt: start, endAt: end),
        );

        expect(result.id, 'e1');
        final captured = verify(dao.upsert(captureAny)).captured;
        expect(captured, hasLength(1));
        final companion = captured.single as EventsCompanion;
        expect(companion.id.value, 'e1');
        expect(companion.title.value, 'Meeting');
        expect(companion.recurrenceGroupId.value, isNull);
        verify(notifications.scheduleForEvent(any)).called(1);
        verifyNever(notifications.cancelForEvent(any));
        verifyNever(calendar.pushEvent(any));
      },
    );

    test('cancels rather than schedules when notify is false', () async {
      final start = DateTime.now().add(const Duration(hours: 2));
      final end = start.add(const Duration(hours: 1));
      when(dao.findById('e2')).thenAnswer(
        (_) async => row(id: 'e2', notify: false, startAt: start, endAt: end),
      );

      await repo.save(
        EventInput(
          id: 'e2',
          title: 'Quiet',
          startAt: start,
          endAt: end,
          notify: false,
        ),
      );

      verifyNever(notifications.scheduleForEvent(any));
      verify(notifications.cancelForEvent('e2')).called(1);
    });

    test('still calls scheduleForEvent when the alert time has passed — '
        'scheduleForEvent itself judges each reminder offset', () async {
      // Starts in the future, but a huge lead time pushes the alert into
      // the past.
      final start = DateTime.now().add(const Duration(minutes: 5));
      final end = start.add(const Duration(hours: 1));
      when(dao.findById('e3')).thenAnswer(
        (_) async => row(
          id: 'e3',
          startAt: start,
          endAt: end,
          reminderMinutesBefore: 1440,
        ),
      );

      await repo.save(
        EventInput(
          id: 'e3',
          title: 'Too late',
          startAt: start,
          endAt: end,
          reminderMinutesBefore: 1440,
        ),
      );

      verify(notifications.scheduleForEvent(any)).called(1);
      verifyNever(notifications.cancelForEvent(any));
    });

    test(
      'still calls scheduleForEvent for a start beyond the notification '
      'window — scheduleForEvent itself judges each reminder offset',
      () async {
        final start = DateTime.now().add(const Duration(days: 90));
        final end = start.add(const Duration(hours: 1));
        when(
          dao.findById('e5'),
        ).thenAnswer((_) async => row(id: 'e5', startAt: start, endAt: end));

        await repo.save(
          EventInput(id: 'e5', title: 'Far future', startAt: start, endAt: end),
        );

        verify(notifications.scheduleForEvent(any)).called(1);
        verifyNever(notifications.cancelForEvent(any));
      },
    );
  });

  group('save — editing an existing occurrence', () {
    test(
      'preserves recurrenceGroupId and recurrenceRule from the stored row',
      () async {
        final start = DateTime.now().add(const Duration(hours: 2));
        final end = start.add(const Duration(hours: 1));
        final existing = row(
          id: 'e4',
          title: 'Old title',
          startAt: start,
          endAt: end,
          recurrenceGroupId: 'group-1',
          recurrenceRule: 'FREQ=WEEKLY;UNTIL=20261231T000000Z',
        );
        // findById is called twice: once to detect "existing", once to re-read
        // after the upsert. Both should reflect the same stored occurrence.
        when(dao.findById('e4')).thenAnswer((_) async => existing);

        await repo.save(
          EventInput(
            id: 'e4',
            title: 'New title',
            startAt: start,
            endAt: end,
            // A plain edit never carries recurrence fields from the UI.
          ),
        );

        final companion =
            verify(dao.upsert(captureAny)).captured.single as EventsCompanion;
        expect(companion.title.value, 'New title');
        expect(companion.recurrenceGroupId.value, 'group-1');
        expect(
          companion.recurrenceRule.value,
          'FREQ=WEEKLY;UNTIL=20261231T000000Z',
        );
      },
    );
  });

  group('save — new recurring event', () {
    test('materializes one row per occurrence sharing a group id, first '
        'occurrence keeps the input id', () async {
      final start = DateTime(2026, 8, 3, 9); // a Monday
      final end = start.add(const Duration(hours: 1));
      final until = DateTime(2026, 8, 17); // three Mondays: 3, 10, 17 Aug

      // Each occurrence gets a freshly-generated id, so findById can't be
      // stubbed per-id up front. Fake it with a tiny in-memory store fed by
      // whatever upsert() actually receives — mirrors what a real DB read-
      // after-write would return, including for the initial "is this new?"
      // check (empty store ⇒ every id is new).
      final store = <String, EventRow>{};
      when(
        dao.findById(any),
      ).thenAnswer((inv) async => store[inv.positionalArguments[0] as String]);
      when(dao.upsert(any)).thenAnswer((inv) async {
        final c = inv.positionalArguments[0] as EventsCompanion;
        store[c.id.value] = row(
          id: c.id.value,
          title: c.title.value,
          startAt: c.startAt.value,
          endAt: c.endAt.value,
          recurrenceRule: c.recurrenceRule.value,
          recurrenceGroupId: c.recurrenceGroupId.value,
          syncStatus: c.syncStatus.value,
        );
      });

      await repo.save(
        EventInput(
          id: 'series-1',
          title: 'Standup',
          startAt: start,
          endAt: end,
          recurrenceFrequency: RecurrenceFrequency.weekly,
          recurrenceUntil: until,
        ),
      );

      final captured = verify(
        dao.upsert(captureAny),
      ).captured.cast<EventsCompanion>();
      expect(captured, hasLength(3));
      expect(captured.first.id.value, 'series-1');
      final groupIds = captured.map((c) => c.recurrenceGroupId.value).toSet();
      expect(groupIds, hasLength(1));
      expect(groupIds.single, isNotNull);
      final starts = captured.map((c) => c.startAt.value.day).toList();
      expect(starts, [3, 10, 17]);
    });

    test('a byWeekdays selection materializes every selected weekday, '
        'and the RRULE carries BYDAY', () async {
      final start = DateTime(2026, 8, 3, 9); // a Monday
      final end = start.add(const Duration(hours: 1));
      final until = DateTime(2026, 8, 9); // Mon 3 .. Sun 9, one full week

      final store = <String, EventRow>{};
      when(
        dao.findById(any),
      ).thenAnswer((inv) async => store[inv.positionalArguments[0] as String]);
      when(dao.upsert(any)).thenAnswer((inv) async {
        final c = inv.positionalArguments[0] as EventsCompanion;
        store[c.id.value] = row(
          id: c.id.value,
          title: c.title.value,
          startAt: c.startAt.value,
          endAt: c.endAt.value,
          recurrenceRule: c.recurrenceRule.value,
          recurrenceGroupId: c.recurrenceGroupId.value,
          syncStatus: c.syncStatus.value,
        );
      });

      await repo.save(
        EventInput(
          id: 'series-2',
          title: 'Gym',
          startAt: start,
          endAt: end,
          recurrenceFrequency: RecurrenceFrequency.weekly,
          recurrenceUntil: until,
          recurrenceByWeekdays: {
            DateTime.monday,
            DateTime.wednesday,
            DateTime.friday,
          },
        ),
      );

      final captured = verify(
        dao.upsert(captureAny),
      ).captured.cast<EventsCompanion>();
      final starts = captured.map((c) => c.startAt.value.day).toList();
      expect(starts, [3, 5, 7]); // Mon 3, Wed 5, Fri 7
      expect(captured.first.recurrenceRule.value, contains('BYDAY=MO,WE,FR'));
    });

    test('a recurrenceCount selection materializes exactly that many rows, '
        'and the RRULE carries COUNT', () async {
      final start = DateTime(2026, 8, 3, 9); // a Monday
      final end = start.add(const Duration(hours: 1));

      final store = <String, EventRow>{};
      when(
        dao.findById(any),
      ).thenAnswer((inv) async => store[inv.positionalArguments[0] as String]);
      when(dao.upsert(any)).thenAnswer((inv) async {
        final c = inv.positionalArguments[0] as EventsCompanion;
        store[c.id.value] = row(
          id: c.id.value,
          title: c.title.value,
          startAt: c.startAt.value,
          endAt: c.endAt.value,
          recurrenceRule: c.recurrenceRule.value,
          recurrenceGroupId: c.recurrenceGroupId.value,
          syncStatus: c.syncStatus.value,
        );
      });

      await repo.save(
        EventInput(
          id: 'series-3',
          title: 'Standup',
          startAt: start,
          endAt: end,
          recurrenceFrequency: RecurrenceFrequency.weekly,
          recurrenceCount: 4,
        ),
      );

      final captured = verify(
        dao.upsert(captureAny),
      ).captured.cast<EventsCompanion>();
      expect(captured, hasLength(4));
      expect(captured.first.recurrenceRule.value, contains('COUNT=4'));
    });
  });

  group('saveSeriesFrom', () {
    test('falls back to a plain save when the event has no series', () async {
      final start = DateTime.now().add(const Duration(hours: 2));
      final end = start.add(const Duration(hours: 1));
      final existing = row(id: 'solo', startAt: start, endAt: end);
      when(dao.findById('solo')).thenAnswer((_) async => existing);

      await repo.saveSeriesFrom(
        'solo',
        EventInput(id: 'solo', title: 'Renamed', startAt: start, endAt: end),
      );

      verify(dao.upsert(any)).called(1);
      verifyNever(dao.seriesFrom(any, any));
    });

    test(
      'falls back to a plain save when the event no longer exists',
      () async {
        final start = DateTime.now().add(const Duration(hours: 2));
        final end = start.add(const Duration(hours: 1));
        // findById('missing') is called twice by the plain-save fallback:
        // once by saveSeriesFrom (returns null, triggering the fallback to
        // save()), then again by save()/_saveSingle re-reading after the
        // upsert (needs a row, as if the DB had just written it).
        var upserted = false;
        when(dao.upsert(any)).thenAnswer((_) async => upserted = true);
        when(dao.findById('missing')).thenAnswer(
          (_) async => upserted
              ? row(id: 'missing', title: 'New', startAt: start, endAt: end)
              : null,
        );

        await repo.saveSeriesFrom(
          'missing',
          EventInput(id: 'missing', title: 'New', startAt: start, endAt: end),
        );

        verify(dao.upsert(any)).called(1);
        verifyNever(dao.seriesFrom(any, any));
      },
    );

    test('applies the title and time-of-day shift to this and every future '
        'occurrence, keeping each one\'s own date', () async {
      // Three weekly occurrences at 9:00, edited from the second one on.
      final occ1Start = DateTime(2026, 8, 3, 9); // Monday — untouched
      final occ2Start = DateTime(2026, 8, 10, 9); // edited: 9:00 -> 10:00
      final occ3Start = DateTime(2026, 8, 17, 9); // future: shifts too

      final store = <String, EventRow>{
        'occ-1': row(
          id: 'occ-1',
          title: 'Standup',
          startAt: occ1Start,
          endAt: occ1Start.add(const Duration(hours: 1)),
          recurrenceGroupId: 'group-x',
          recurrenceRule: 'FREQ=WEEKLY;UNTIL=20261231T000000Z',
        ),
        'occ-2': row(
          id: 'occ-2',
          title: 'Standup',
          startAt: occ2Start,
          endAt: occ2Start.add(const Duration(hours: 1)),
          recurrenceGroupId: 'group-x',
          recurrenceRule: 'FREQ=WEEKLY;UNTIL=20261231T000000Z',
        ),
        'occ-3': row(
          id: 'occ-3',
          title: 'Standup',
          startAt: occ3Start,
          endAt: occ3Start.add(const Duration(hours: 1)),
          recurrenceGroupId: 'group-x',
          recurrenceRule: 'FREQ=WEEKLY;UNTIL=20261231T000000Z',
        ),
      };
      when(
        dao.findById(any),
      ).thenAnswer((inv) async => store[inv.positionalArguments[0] as String]);
      when(dao.upsert(any)).thenAnswer((inv) async {
        final c = inv.positionalArguments[0] as EventsCompanion;
        final prior = store[c.id.value]!;
        store[c.id.value] = row(
          id: c.id.value,
          title: c.title.value,
          startAt: c.startAt.value,
          endAt: c.endAt.value,
          recurrenceGroupId: c.recurrenceGroupId.value,
          recurrenceRule: c.recurrenceRule.value,
          syncStatus: c.syncStatus.value,
          osEventId: prior.osEventId,
        );
      });
      when(
        dao.seriesFrom('group-x', occ2Start),
      ).thenAnswer((_) async => [store['occ-2']!, store['occ-3']!]);

      final newStart = DateTime(2026, 8, 10, 10); // occ-2, moved to 10:00
      final newEnd = newStart.add(const Duration(minutes: 30));
      await repo.saveSeriesFrom(
        'occ-2',
        EventInput(
          id: 'occ-2',
          title: 'Standup (renamed)',
          startAt: newStart,
          endAt: newEnd,
        ),
      );

      // occ-1 (before the edited occurrence) is untouched.
      expect(store['occ-1']!.title, 'Standup');
      expect(store['occ-1']!.startAt, occ1Start);

      // occ-2 and occ-3 got the new title and the 9:00->10:00 shift, each on
      // its own original date, with the new (30 min) duration.
      expect(store['occ-2']!.title, 'Standup (renamed)');
      expect(store['occ-2']!.startAt, DateTime(2026, 8, 10, 10));
      expect(store['occ-2']!.endAt, DateTime(2026, 8, 10, 10, 30));

      expect(store['occ-3']!.title, 'Standup (renamed)');
      expect(store['occ-3']!.startAt, DateTime(2026, 8, 17, 10));
      expect(store['occ-3']!.endAt, DateTime(2026, 8, 17, 10, 30));
    });

    test(
      'a date change on the occurrence being edited is honored exactly, '
      'not silently reverted to its original date — future occurrences '
      'still keep their own date (only the time-of-day delta carries)',
      () async {
        final occ2Start = DateTime(2026, 8, 10, 9); // edited: moved a day
        final occ3Start = DateTime(2026, 8, 17, 9); // future, untouched date

        final store = <String, EventRow>{
          'occ-2': row(
            id: 'occ-2',
            title: 'Standup',
            startAt: occ2Start,
            endAt: occ2Start.add(const Duration(hours: 1)),
            recurrenceGroupId: 'group-x',
            recurrenceRule: 'FREQ=WEEKLY;UNTIL=20261231T000000Z',
          ),
          'occ-3': row(
            id: 'occ-3',
            title: 'Standup',
            startAt: occ3Start,
            endAt: occ3Start.add(const Duration(hours: 1)),
            recurrenceGroupId: 'group-x',
            recurrenceRule: 'FREQ=WEEKLY;UNTIL=20261231T000000Z',
          ),
        };
        when(dao.findById(any)).thenAnswer(
          (inv) async => store[inv.positionalArguments[0] as String],
        );
        when(dao.upsert(any)).thenAnswer((inv) async {
          final c = inv.positionalArguments[0] as EventsCompanion;
          final prior = store[c.id.value]!;
          store[c.id.value] = row(
            id: c.id.value,
            title: c.title.value,
            startAt: c.startAt.value,
            endAt: c.endAt.value,
            recurrenceGroupId: c.recurrenceGroupId.value,
            recurrenceRule: c.recurrenceRule.value,
            syncStatus: c.syncStatus.value,
            osEventId: prior.osEventId,
          );
        });
        when(
          dao.seriesFrom('group-x', occ2Start),
        ).thenAnswer((_) async => [store['occ-2']!, store['occ-3']!]);

        // Same time-of-day (9:00), but moved from Aug 10 to Aug 11.
        final newStart = DateTime(2026, 8, 11, 9);
        final newEnd = newStart.add(const Duration(hours: 1));
        await repo.saveSeriesFrom(
          'occ-2',
          EventInput(
            id: 'occ-2',
            title: 'Standup',
            startAt: newStart,
            endAt: newEnd,
          ),
        );

        // The edited occurrence gets exactly the date the user set — not
        // silently reverted to Aug 10 because the time-of-day delta was 0.
        expect(store['occ-2']!.startAt, DateTime(2026, 8, 11, 9));
        expect(store['occ-2']!.endAt, DateTime(2026, 8, 11, 10));

        // occ-3 is genuinely in the future (not the occurrence being
        // edited): it keeps its own Aug 17 date, since the time-of-day
        // delta between the edit and the original occ-2 time is zero.
        expect(store['occ-3']!.startAt, DateTime(2026, 8, 17, 9));
      },
    );
  });

  group('save — OS calendar push', () {
    test(
      'never pushes a row mirrored from a subscribed/holiday calendar, even '
      'when saved directly (not through the "mirrored events are read-only" '
      'UI gate) — regression test: Day view\'s drag-to-reschedule calls '
      'save() straight from a gesture handler, bypassing that gate '
      'entirely, and used to create a duplicate device-calendar event for '
      'every dragged holiday/mirrored event',
      () async {
        final start = DateTime.now().add(const Duration(hours: 2));
        final end = start.add(const Duration(hours: 1));
        final mirrored = row(
          id: 'e5d',
          startAt: start,
          endAt: end,
          importSourceCalendarId: 'ko.south_korea#holiday@group.v.calendar.google.com',
          syncStatus: SyncStatus.synced,
        );
        when(dao.findById('e5d')).thenAnswer((_) async => mirrored);
        when(calendar.isEnabled).thenReturn(true);

        await repo.save(
          EventInput(
            id: 'e5d',
            title: 'Dragged',
            startAt: start.add(const Duration(hours: 1)),
            endAt: end.add(const Duration(hours: 1)),
          ),
        );

        verifyNever(calendar.pushEvent(any));
      },
    );

    test('pushes and patches osEventId when sync is enabled', () async {
      final start = DateTime.now().add(const Duration(hours: 2));
      final end = start.add(const Duration(hours: 1));
      final saved = row(id: 'e5', startAt: start, endAt: end);
      final synced = row(
        id: 'e5',
        startAt: start,
        endAt: end,
        osEventId: 'os-123',
        syncStatus: SyncStatus.synced,
      );
      // First read (post-upsert, pre-push) returns pendingPush; second read
      // (post-patch) returns the synced row — mirrors the two DB round trips
      // in EventRepositoryImpl._saveSingle.
      when(dao.findById('e5')).thenAnswer((_) async => saved);
      when(calendar.isEnabled).thenReturn(true);
      when(calendar.pushEvent(any)).thenAnswer((_) async => 'os-123');

      // Re-stub findById to return the synced version after patch() runs.
      var patchCalled = false;
      when(dao.patch('e5', any)).thenAnswer((_) async {
        patchCalled = true;
      });
      when(
        dao.findById('e5'),
      ).thenAnswer((_) async => patchCalled ? synced : saved);

      final result = await repo.save(
        EventInput(id: 'e5', title: 'Synced event', startAt: start, endAt: end),
      );

      verify(calendar.pushEvent(any)).called(1);
      final patchCompanion =
          verify(dao.patch('e5', captureAny)).captured.single
              as EventsCompanion;
      expect(patchCompanion.osEventId.value, 'os-123');
      expect(patchCompanion.syncStatus.value, SyncStatus.synced);
      expect(result.osEventId, 'os-123');
    });

    test(
      'a calendar push failure does not surface — the local save still '
      'succeeds and the row stays pendingPush for the reconciler to retry',
      () async {
        final start = DateTime.now().add(const Duration(hours: 2));
        final end = start.add(const Duration(hours: 1));
        final saved = row(id: 'e5b', startAt: start, endAt: end);
        when(dao.findById('e5b')).thenAnswer((_) async => saved);
        when(calendar.isEnabled).thenReturn(true);
        when(
          calendar.pushEvent(any),
        ).thenThrow(Exception('calendar unavailable'));

        final result = await repo.save(
          EventInput(
            id: 'e5b',
            title: 'Push fails',
            startAt: start,
            endAt: end,
          ),
        );

        expect(result.id, 'e5b');
        verifyNever(dao.patch(any, any));
        final captured =
            verify(dao.upsert(captureAny)).captured.single as EventsCompanion;
        expect(captured.syncStatus.value, SyncStatus.pendingPush);
      },
    );

    test(
      'editing an event auto-imported from the device calendar pushes an '
      'update against its existing osEventId rather than dropping it — '
      "the row's osCalendarId (never set by PlanFit's own push path) is "
      'what marks it as auto-imported, and only carries an osEventId if a '
      'prior sync already linked it to a live OS event',
      () async {
        final start = DateTime.now().add(const Duration(hours: 2));
        final end = start.add(const Duration(hours: 1));
        // As CalendarReconciler._importNewEvent originally wrote it, before
        // this edit: osCalendarId set (the auto-import marker), osEventId
        // already linking it to a real OS event.
        final existing = row(
          id: 'e5c',
          startAt: start,
          endAt: end,
          osCalendarId: 'os-cal-1',
          osEventId: 'os-999',
          syncStatus: SyncStatus.synced,
        );
        when(dao.findById('e5c')).thenAnswer((_) async => existing);
        when(calendar.isEnabled).thenReturn(true);
        when(calendar.pushEvent(any)).thenAnswer((_) async => 'os-999');

        await repo.save(
          EventInput(
            id: 'e5c',
            title: 'Edited after auto-import',
            startAt: start,
            endAt: end,
          ),
        );

        // CalendarService.pushEvent only updates in place — instead of
        // creating a duplicate OS event — when the row it's handed still
        // carries its existing osEventId. This is the repository's half of
        // that contract: an edit must not drop it.
        final pushed =
            verify(calendar.pushEvent(captureAny)).captured.single
                as EventRow;
        expect(pushed.osEventId, 'os-999');
      },
    );
  });

  group('delete', () {
    test('cancels notification, deletes from calendar, then the row', () async {
      final existing = row(
        id: 'e6',
        startAt: DateTime.now(),
        endAt: DateTime.now().add(const Duration(hours: 1)),
        osEventId: 'os-9',
      );
      when(dao.findById('e6')).thenAnswer((_) async => existing);
      when(calendar.isEnabled).thenReturn(true);
      when(calendar.deleteEvent(any)).thenAnswer((_) async {});

      await repo.delete('e6');

      verify(notifications.cancelForEvent('e6')).called(1);
      verify(calendar.deleteEvent(existing)).called(1);
      verify(dao.deleteById('e6')).called(1);
    });

    test('no-ops when the event no longer exists', () async {
      when(dao.findById('missing')).thenAnswer((_) async => null);

      await repo.delete('missing');

      verifyNever(notifications.cancelForEvent(any));
      verifyNever(dao.deleteById(any));
    });

    test('still deletes the local row even when the calendar-side delete '
        'throws (e.g. the OS event was already removed externally)', () async {
      final existing = row(
        id: 'e6b',
        startAt: DateTime.now(),
        endAt: DateTime.now().add(const Duration(hours: 1)),
        osEventId: 'os-gone',
      );
      when(dao.findById('e6b')).thenAnswer((_) async => existing);
      when(calendar.isEnabled).thenReturn(true);
      when(calendar.deleteEvent(any)).thenThrow(Exception('not found'));

      await repo.delete('e6b');

      verify(notifications.cancelForEvent('e6b')).called(1);
      verify(dao.deleteById('e6b')).called(1);
    });
  });

  group('deleteSeriesFrom', () {
    test(
      'falls back to a single delete when the event has no series',
      () async {
        final existing = row(
          id: 'solo',
          startAt: DateTime.now(),
          endAt: DateTime.now().add(const Duration(hours: 1)),
        );
        when(dao.findById('solo')).thenAnswer((_) async => existing);

        await repo.deleteSeriesFrom('solo');

        verify(dao.deleteById('solo')).called(1);
        verifyNever(dao.seriesFrom(any, any));
      },
    );

    test('deletes every occurrence from the target forward', () async {
      final start = DateTime(2026, 8, 3, 9);
      final target = row(
        id: 'occ-2',
        startAt: start.add(const Duration(days: 7)),
        endAt: start.add(const Duration(days: 7, hours: 1)),
        recurrenceGroupId: 'group-x',
      );
      final rest = [
        target,
        row(
          id: 'occ-3',
          startAt: start.add(const Duration(days: 14)),
          endAt: start.add(const Duration(days: 14, hours: 1)),
          recurrenceGroupId: 'group-x',
        ),
      ];
      when(dao.findById('occ-2')).thenAnswer((_) async => target);
      when(dao.findById('occ-3')).thenAnswer((_) async => rest[1]);
      when(
        dao.seriesFrom('group-x', target.startAt),
      ).thenAnswer((_) async => rest);

      await repo.deleteSeriesFrom('occ-2');

      verify(dao.deleteById('occ-2')).called(1);
      verify(dao.deleteById('occ-3')).called(1);
    });
  });

  group('restoreEvent', () {
    test(
      'clears OS-calendar linkage and re-arms a future notification',
      () async {
        final start = DateTime.now().add(const Duration(hours: 2));
        final backedUp = row(
          id: 'restored-1',
          title: 'From backup',
          startAt: start,
          endAt: start.add(const Duration(hours: 1)),
          recurrenceGroupId: 'group-9',
          recurrenceRule: 'FREQ=WEEKLY;UNTIL=20261231T000000Z',
          osEventId: 'stale-os-id',
        );
        when(dao.findById('restored-1')).thenAnswer((_) async => backedUp);

        await repo.restoreEvent(backedUp);

        final companion =
            verify(dao.upsert(captureAny)).captured.single as EventsCompanion;
        expect(companion.osEventId.value, null);
        expect(companion.osCalendarId.value, null);
        expect(companion.syncStatus.value, SyncStatus.pendingPush);
        expect(companion.recurrenceGroupId.value, 'group-9');
        verify(notifications.scheduleForEvent(any)).called(1);
      },
    );

    test('still calls scheduleForEvent when the restored event already passed '
        '— scheduleForEvent itself judges each reminder offset', () async {
      final past = DateTime.now().subtract(const Duration(days: 1));
      final backedUp = row(
        id: 'restored-2',
        startAt: past,
        endAt: past.add(const Duration(hours: 1)),
      );
      when(dao.findById('restored-2')).thenAnswer((_) async => backedUp);

      await repo.restoreEvent(backedUp);

      verify(notifications.scheduleForEvent(any)).called(1);
      verifyNever(notifications.cancelForEvent(any));
    });

    test(
      'cancels the notification when the restored event has notify off',
      () async {
        final start = DateTime.now().add(const Duration(hours: 2));
        final backedUp = row(
          id: 'restored-3',
          notify: false,
          startAt: start,
          endAt: start.add(const Duration(hours: 1)),
        );
        when(dao.findById('restored-3')).thenAnswer((_) async => backedUp);

        await repo.restoreEvent(backedUp);

        verifyNever(notifications.scheduleForEvent(any));
        verify(notifications.cancelForEvent('restored-3')).called(1);
      },
    );
  });

  group('restoreEvents', () {
    test(
      'writes every row inside one transaction, not one per row',
      () async {
        final start = DateTime.now().add(const Duration(hours: 2));
        final rows = [
          row(id: 'batch-1', startAt: start, endAt: start.add(const Duration(hours: 1))),
          row(id: 'batch-2', startAt: start, endAt: start.add(const Duration(hours: 1))),
          row(id: 'batch-3', startAt: start, endAt: start.add(const Duration(hours: 1))),
        ];
        for (final r in rows) {
          when(dao.findById(r.id)).thenAnswer((_) async => r);
        }

        await repo.restoreEvents(rows);

        // A single call wrapping all three writes -- not the three separate
        // transactions a naive per-row loop would produce.
        verify(dao.transaction<void>(any)).called(1);
        verify(dao.upsert(any)).called(3);
      },
    );

    test('applies side effects for every row after the transaction, even '
        'though the writes are batched', () async {
      final start = DateTime.now().add(const Duration(hours: 2));
      final notifyOn = row(
        id: 'batch-notify-on',
        notify: true,
        startAt: start,
        endAt: start.add(const Duration(hours: 1)),
      );
      final notifyOff = row(
        id: 'batch-notify-off',
        notify: false,
        startAt: start,
        endAt: start.add(const Duration(hours: 1)),
      );
      when(dao.findById('batch-notify-on')).thenAnswer((_) async => notifyOn);
      when(
        dao.findById('batch-notify-off'),
      ).thenAnswer((_) async => notifyOff);

      await repo.restoreEvents([notifyOn, notifyOff]);

      verify(notifications.scheduleForEvent(any)).called(1);
      verify(notifications.cancelForEvent('batch-notify-off')).called(1);
    });

    test('an empty list is a no-op — no transaction, no side effects', () async {
      await repo.restoreEvents(const []);

      verifyNever(dao.transaction<void>(any));
      verifyNever(dao.upsert(any));
      verifyNever(notifications.scheduleForEvent(any));
    });
  });
}
