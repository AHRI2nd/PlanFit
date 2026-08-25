import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/event_row_x.dart';
import 'package:planfit/core/db/sync_status.dart';

void main() {
  EventRow row({
    int reminderMinutesBefore = 0,
    String? additionalReminderMinutes,
  }) {
    final start = DateTime(2026, 1, 1, 9);
    return EventRow(
      id: 'e1',
      title: 'e1',
      memo: null,
      startAt: start,
      endAt: start.add(const Duration(hours: 1)),
      isAllDay: false,
      notify: true,
      reminderMinutesBefore: reminderMinutesBefore,
      additionalReminderMinutes: additionalReminderMinutes,
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

  group('EventAlertX.reminderOffsets', () {
    test('is just the primary offset when there are no extras', () {
      expect(row(reminderMinutesBefore: 10).reminderOffsets, [10]);
    });

    test('combines the primary offset with the parsed extras, sorted', () {
      expect(
        row(
          reminderMinutesBefore: 10,
          additionalReminderMinutes: '1440,60',
        ).reminderOffsets,
        [10, 60, 1440],
      );
    });

    test('dedupes when an extra repeats the primary offset', () {
      expect(
        row(
          reminderMinutesBefore: 60,
          additionalReminderMinutes: '60,60',
        ).reminderOffsets,
        [60],
      );
    });

    test('ignores malformed entries in the extras string', () {
      expect(
        row(
          reminderMinutesBefore: 0,
          additionalReminderMinutes: '5,,abc, 10 ',
        ).reminderOffsets,
        [0, 5, 10],
      );
    });

    test('treats an empty extras string the same as null', () {
      expect(
        row(
          reminderMinutesBefore: 30,
          additionalReminderMinutes: '',
        ).reminderOffsets,
        [30],
      );
    });
  });
}
