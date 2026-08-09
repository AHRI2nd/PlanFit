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

  group('groupEventsByDay', () {
    test('groups events under the calendar day of their startAt', () {
      final groups = groupEventsByDay([
        event(id: 'e1', startAt: DateTime(2026, 3, 10, 9), title: 'Standup'),
        event(id: 'e2', startAt: DateTime(2026, 3, 11, 14), title: 'Dentist'),
      ]);

      expect(groups.map((g) => g.$1), [
        DateTime(2026, 3, 10),
        DateTime(2026, 3, 11),
      ]);
      expect(groups[0].$2.map((e) => e.id), ['e1']);
      expect(groups[1].$2.map((e) => e.id), ['e2']);
    });

    test('sorts days ascending regardless of input order', () {
      final groups = groupEventsByDay([
        event(id: 'later', startAt: DateTime(2026, 5, 1, 9)),
        event(id: 'earlier', startAt: DateTime(2026, 1, 1, 9)),
      ]);

      expect(groups.map((g) => g.$1), [
        DateTime(2026, 1, 1),
        DateTime(2026, 5, 1),
      ]);
    });

    test('sorts events within a day by startAt', () {
      final groups = groupEventsByDay([
        event(id: 'afternoon', startAt: DateTime(2026, 3, 10, 15)),
        event(id: 'morning', startAt: DateTime(2026, 3, 10, 9)),
      ]);

      expect(groups.single.$2.map((e) => e.id), ['morning', 'afternoon']);
    });

    test('a multi-day event appears once, under its start day only', () {
      final groups = groupEventsByDay([
        event(
          id: 'trip',
          startAt: DateTime(2026, 3, 10, 9),
          endAt: DateTime(2026, 3, 13, 9),
        ),
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.$1, DateTime(2026, 3, 10));
    });

    test('returns an empty list for no events', () {
      expect(groupEventsByDay(const []), isEmpty);
    });
  });
}
