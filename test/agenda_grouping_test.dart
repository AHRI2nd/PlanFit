import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/sync_status.dart';
import 'package:planfit/features/schedule/domain/agenda_grouping.dart';

void main() {
  EventRow event({
    required String id,
    required DateTime startAt,
    DateTime? endAt,
    String title = '',
  }) {
    return EventRow(
      id: id,
      title: title,
      memo: null,
      location: null,
      startAt: startAt,
      endAt: endAt ?? startAt.add(const Duration(hours: 1)),
      isAllDay: false,
      colorTag: null,
      notify: true,
      reminderMinutesBefore: 0,
      additionalReminderMinutes: null,
      recurrenceRule: null,
      recurrenceGroupId: null,
      osCalendarId: null,
      osEventId: null,
      osLastKnownModified: null,
      syncStatus: SyncStatus.pendingPush,
      importSourceCalendarId: null,
      importSourceEventId: null,
      createdAt: DateTime(2020),
      updatedAt: DateTime(2020),
    );
  }

  TodoRow todo({
    required String id,
    required DateTime slotStart,
    bool hasTime = true,
  }) {
    return TodoRow(
      id: id,
      eventId: null,
      title: id,
      slotStart: slotStart,
      slotEnd: null,
      hasTime: hasTime,
      isDone: false,
      sortOrder: 0,
      priority: 0,
      tags: null,
      notify: false,
      isPinned: false,
      recurrenceRule: null,
      recurrenceGroupId: null,
      reminderSyncStatus: SyncStatus.pendingPush,
      createdAt: DateTime(2020),
    );
  }

  group('groupAgendaEntriesByDay', () {
    test('merges events and to-dos together, sorted by time within a day', () {
      final groups = groupAgendaEntriesByDay(
        [event(id: 'e1', startAt: DateTime(2026, 3, 10, 14))],
        [todo(id: 't1', slotStart: DateTime(2026, 3, 10, 9))],
      );

      expect(groups, hasLength(1));
      expect(groups.single.$1, DateTime(2026, 3, 10));
      final entries = groups.single.$2;
      expect(entries, hasLength(2));
      expect(entries[0], isA<AgendaTodoEntry>());
      expect(entries[1], isA<AgendaEventEntry>());
    });

    test(
      'a no-time to-do (slotStart pinned to midnight) sorts first in its day',
      () {
        final groups = groupAgendaEntriesByDay(
          [event(id: 'e1', startAt: DateTime(2026, 3, 10, 1))],
          [todo(id: 't1', slotStart: DateTime(2026, 3, 10), hasTime: false)],
        );

        final entries = groups.single.$2;
        expect(entries[0], isA<AgendaTodoEntry>());
        expect((entries[0] as AgendaTodoEntry).todo.id, 't1');
      },
    );

    test('returns an empty list for no events and no to-dos', () {
      expect(groupAgendaEntriesByDay(const [], const []), isEmpty);
    });

    test('days are sorted ascending regardless of input order', () {
      final groups = groupAgendaEntriesByDay(
        [event(id: 'e1', startAt: DateTime(2026, 5, 1, 9))],
        [todo(id: 't1', slotStart: DateTime(2026, 1, 1, 9))],
      );

      expect(groups.map((g) => g.$1), [
        DateTime(2026, 1, 1),
        DateTime(2026, 5, 1),
      ]);
    });

    test('many same-sortKey entries keep their original (insertion) order '
        'instead of being reshuffled — regression test: a plain List.sort is '
        'only stable below a small size threshold, above which Dart switches '
        'to an unstable dual-pivot quicksort, so a day with enough identical-'
        'time entries (e.g. several no-time to-dos, all pinned to midnight) '
        'could have their relative order silently shuffled on every rebuild '
        'even though nothing about the data changed. 40 was verified by '
        'direct experiment to actually reorder pre-fix; smaller counts '
        "(<=32) happen not to, which is exactly why this needs to be big "
        'enough to catch it rather than assumed from a handful of entries', () {
      final noTimeTodos = [
        for (var i = 0; i < 40; i++)
          todo(
            id: 't${i.toString().padLeft(2, '0')}',
            slotStart: DateTime(2026, 3, 10),
            hasTime: false,
          ),
      ];

      final groups = groupAgendaEntriesByDay(const [], noTimeTodos);

      final ids = groups.single.$2
          .map((e) => (e as AgendaTodoEntry).todo.id)
          .toList();
      expect(ids, noTimeTodos.map((t) => t.id).toList());
    });

    test('a multi-day event appears in every day group it spans, not just its '
        'start day — regression test: it used to appear once, under its '
        'start day only, so a 3-day trip vanished from this list entirely on '
        'day 2 and day 3 even though month/week already showed it running', () {
      final trip = event(
        id: 'trip',
        startAt: DateTime(2026, 3, 10, 9),
        endAt: DateTime(2026, 3, 12, 17),
      );

      final groups = groupAgendaEntriesByDay([trip], const []);

      expect(groups.map((g) => g.$1), [
        DateTime(2026, 3, 10),
        DateTime(2026, 3, 11),
        DateTime(2026, 3, 12),
      ]);
      for (final (_, entries) in groups) {
        expect((entries.single as AgendaEventEntry).event.id, 'trip');
      }
    });
  });
}
