import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/sync_status.dart';
import 'package:planfit/features/todo/domain/todo_ordering.dart';

/// Pinning used to do nothing to where a to-do sat — it added an icon and a
/// smart-list tab of its own, so a pinned item due next month stayed buried
/// under everything sooner. These pin the order the cross-day lists (the
/// home screen's 할 일 list, every smart-list tab) now use.
void main() {
  final now = DateTime(2026, 3, 10, 12);

  TodoRow todo(
    String id, {
    required DateTime slot,
    bool pinned = false,
    bool hasTime = true,
    bool done = false,
  }) => TodoRow(
    id: id,
    eventId: null,
    title: id,
    slotStart: slot,
    slotEnd: null,
    hasTime: hasTime,
    isDone: done,
    completedAt: null,
    sortOrder: 0,
    priority: 0,
    tags: null,
    notify: false,
    additionalReminderMinutes: null,
    isPinned: pinned,
    recurrenceRule: null,
    recurrenceGroupId: null,
    osReminderId: null,
    osReminderListId: null,
    osReminderLastKnownModified: null,
    reminderSyncStatus: SyncStatus.pendingPush,
    createdAt: now,
  );

  List<String> order(List<TodoRow> rows) =>
      orderCrossDayTodos(rows, now: now).map((t) => t.id).toList();

  test('pinned first, then overdue, then the rest — each by time', () {
    final rows = [
      todo('rest-late', slot: DateTime(2026, 3, 20, 9)),
      todo('overdue-late', slot: DateTime(2026, 3, 10, 11)),
      todo('pinned-late', slot: DateTime(2026, 4, 1, 9), pinned: true),
      todo('rest-early', slot: DateTime(2026, 3, 11, 9)),
      todo('overdue-early', slot: DateTime(2026, 3, 1, 9)),
      todo('pinned-early', slot: DateTime(2026, 3, 12, 9), pinned: true),
    ];

    expect(order(rows), [
      'pinned-early',
      'pinned-late',
      'overdue-early',
      'overdue-late',
      'rest-early',
      'rest-late',
    ]);
  });

  test('a pinned to-do outranks an overdue one even when the overdue one is '
      'far older — pinning is the user saying "keep this in front of me", '
      'and it would mean nothing if a backlog could bury it', () {
    final rows = [
      todo('ancient-overdue', slot: DateTime(2020, 1, 1, 9)),
      todo('pinned', slot: DateTime(2030, 1, 1, 9), pinned: true),
    ];

    expect(order(rows), ['pinned', 'ancient-overdue']);
  });

  test('a pinned to-do that is also overdue still sits in the pinned group, '
      'not counted twice', () {
    final rows = [
      todo('overdue', slot: DateTime(2026, 3, 9, 9)),
      todo('pinned-overdue', slot: DateTime(2026, 3, 8, 9), pinned: true),
    ];

    expect(order(rows), ['pinned-overdue', 'overdue']);
  });

  test('a no-time to-do is never overdue, however old its day — it ranks '
      'with the rest, matching isTodoOverdue', () {
    final rows = [
      todo('timed-overdue', slot: DateTime(2026, 3, 9, 9)),
      todo('no-time-old', slot: DateTime(2020, 1, 1), hasTime: false),
    ];

    expect(order(rows), ['timed-overdue', 'no-time-old']);
  });

  test('a done to-do is never overdue either, so a past one sorts with the '
      'rest rather than jumping the queue', () {
    final rows = [
      todo('not-done-overdue', slot: DateTime(2026, 3, 9, 10)),
      todo('done-older', slot: DateTime(2026, 3, 8, 9), done: true),
    ];

    expect(order(rows), ['not-done-overdue', 'done-older']);
  });

  test('ties keep their incoming order, so the list cannot reshuffle itself '
      "between rebuilds — a whole day's no-time to-dos all share midnight", () {
    final midnight = DateTime(2026, 3, 20);
    final rows = [
      for (final id in ['a', 'b', 'c', 'd'])
        todo(id, slot: midnight, hasTime: false),
    ];

    expect(order(rows), ['a', 'b', 'c', 'd']);
    expect(order(rows.reversed.toList()), ['d', 'c', 'b', 'a']);
  });

  test('an empty list stays empty', () {
    expect(orderCrossDayTodos(const [], now: now), isEmpty);
  });
}
