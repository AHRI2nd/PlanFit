import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/sync_status.dart';
import 'package:planfit/features/schedule/domain/event_span.dart';

void main() {
  EventRow row({required DateTime startAt, required DateTime endAt}) {
    return EventRow(
      id: 'e1',
      title: 'Event',
      memo: null,
      startAt: startAt,
      endAt: endAt,
      isAllDay: true,
      notify: false,
      reminderMinutesBefore: 0,
      colorTag: null,
      recurrenceRule: null,
      recurrenceGroupId: null,
      osCalendarId: null,
      osEventId: null,
      osLastKnownModified: null,
      syncStatus: SyncStatus.pendingPush,
      createdAt: DateTime(2020),
      updatedAt: DateTime(2020),
    );
  }

  group('eventDaysInRange', () {
    test('a single-day event returns just that one day', () {
      final e = row(
        startAt: DateTime(2026, 3, 10),
        endAt: DateTime(2026, 3, 11),
      );
      final days = eventDaysInRange(
        e,
        DateTime(2026, 3, 1),
        DateTime(2026, 4, 1),
      );
      expect(days, [DateTime(2026, 3, 10)]);
    });

    test('a 3-day event returns all 3 days it spans', () {
      final e = row(
        startAt: DateTime(2026, 3, 10),
        endAt: DateTime(2026, 3, 13),
      );
      final days = eventDaysInRange(
        e,
        DateTime(2026, 3, 1),
        DateTime(2026, 4, 1),
      );
      expect(days, [
        DateTime(2026, 3, 10),
        DateTime(2026, 3, 11),
        DateTime(2026, 3, 12),
      ]);
    });

    test('clips to the given range when the event starts before it', () {
      final e = row(
        startAt: DateTime(2026, 2, 27),
        endAt: DateTime(2026, 3, 3),
      );
      final days = eventDaysInRange(
        e,
        DateTime(2026, 3, 1),
        DateTime(2026, 4, 1),
      );
      expect(days, [DateTime(2026, 3, 1), DateTime(2026, 3, 2)]);
    });

    test('clips to the given range when the event ends after it', () {
      final e = row(
        startAt: DateTime(2026, 3, 30),
        endAt: DateTime(2026, 4, 3),
      );
      final days = eventDaysInRange(
        e,
        DateTime(2026, 3, 1),
        DateTime(2026, 4, 1),
      );
      expect(days, [DateTime(2026, 3, 30), DateTime(2026, 3, 31)]);
    });

    test('an event ending exactly at a day boundary does not spill into it',
        () {
      // Exclusive end — mirrors EventDao's half-open overlap convention.
      final e = row(
        startAt: DateTime(2026, 3, 10),
        endAt: DateTime(2026, 3, 12),
      );
      final days = eventDaysInRange(
        e,
        DateTime(2026, 3, 1),
        DateTime(2026, 4, 1),
      );
      expect(days, [DateTime(2026, 3, 10), DateTime(2026, 3, 11)]);
    });
  });
}
