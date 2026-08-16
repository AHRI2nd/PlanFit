import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/sync_status.dart';
import 'package:planfit/core/db/todo_row_x.dart';

void main() {
  TodoRow todo({String? additionalReminderMinutes}) {
    return TodoRow(
      id: 't1',
      eventId: null,
      title: 't1',
      slotStart: DateTime(2026, 1, 1, 9),
      slotEnd: null,
      hasTime: true,
      isDone: false,
      sortOrder: 0,
      priority: 0,
      tags: null,
      notify: true,
      additionalReminderMinutes: additionalReminderMinutes,
      isPinned: false,
      recurrenceRule: null,
      recurrenceGroupId: null,
      reminderSyncStatus: SyncStatus.pendingPush,
      createdAt: DateTime(2020),
    );
  }

  group('TodoAlertX.reminderOffsets', () {
    test('is just the implicit due-time offset when there are no extras', () {
      expect(todo().reminderOffsets, [0]);
    });

    test('combines the due-time offset with the parsed extras, sorted', () {
      expect(todo(additionalReminderMinutes: '1440,60').reminderOffsets, [
        0,
        60,
        1440,
      ]);
    });

    test('dedupes when an extra repeats the due-time offset', () {
      expect(todo(additionalReminderMinutes: '0,0').reminderOffsets, [0]);
    });

    test('ignores malformed entries in the extras string', () {
      expect(todo(additionalReminderMinutes: '5,,abc, 10 ').reminderOffsets, [
        0,
        5,
        10,
      ]);
    });

    test('treats an empty extras string the same as null', () {
      expect(todo(additionalReminderMinutes: '').reminderOffsets, [0]);
    });
  });
}
