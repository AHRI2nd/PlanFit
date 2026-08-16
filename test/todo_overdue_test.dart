import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/sync_status.dart';
import 'package:planfit/features/todo/domain/todo_overdue.dart';

void main() {
  TodoRow todo({
    required DateTime slotStart,
    bool hasTime = true,
    bool isDone = false,
  }) {
    return TodoRow(
      id: 't1',
      eventId: null,
      title: 't1',
      slotStart: slotStart,
      slotEnd: null,
      hasTime: hasTime,
      isDone: isDone,
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

  final now = DateTime(2026, 3, 10, 12);

  group('isTodoOverdue', () {
    test('a timed, not-done to-do whose slot has passed is overdue', () {
      final t = todo(slotStart: now.subtract(const Duration(hours: 1)));
      expect(isTodoOverdue(t, now), isTrue);
    });

    test('a timed, not-done to-do still in the future is not overdue', () {
      final t = todo(slotStart: now.add(const Duration(hours: 1)));
      expect(isTodoOverdue(t, now), isFalse);
    });

    test('a done to-do is never overdue, even if its slot has passed', () {
      final t = todo(
        slotStart: now.subtract(const Duration(hours: 1)),
        isDone: true,
      );
      expect(isTodoOverdue(t, now), isFalse);
    });

    test('a no-time to-do is never overdue, even if its day has passed', () {
      final t = todo(
        slotStart: now.subtract(const Duration(days: 1)),
        hasTime: false,
      );
      expect(isTodoOverdue(t, now), isFalse);
    });
  });
}
