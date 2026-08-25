import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  EventsCompanion event({
    required String id,
    required DateTime startAt,
    required DateTime endAt,
  }) {
    return EventsCompanion.insert(
      id: id,
      title: Value(id),
      startAt: startAt,
      endAt: endAt,
    );
  }

  group('EventDao.watchBetween day-boundary overlap', () {
    test(
      'an event ending exactly at midnight appears on only one day, not both',
      () async {
        // 23:00 day1 – 00:00 day2 (i.e. ends exactly on the day2/day3 window
        // boundary).
        final day1 = DateTime(2026, 3, 10);
        final day2 = DateTime(2026, 3, 11);
        final day3 = DateTime(2026, 3, 12);
        await db.eventDao.upsert(
          event(
            id: 'e1',
            startAt: day2.subtract(const Duration(hours: 1)),
            endAt: day2,
          ),
        );

        final onDay1 = await db.eventDao.between(day1, day2);
        final onDay2 = await db.eventDao.between(day2, day3);

        expect(onDay1.map((e) => e.id), ['e1']);
        expect(onDay2, isEmpty);
      },
    );

    test('an event still shows on the day it actually spans into', () async {
      final day1 = DateTime(2026, 3, 10);
      final day2 = DateTime(2026, 3, 11);
      final day3 = DateTime(2026, 3, 12);
      // 23:00 day1 – 00:30 day2 — genuinely spans the boundary by 30 min.
      await db.eventDao.upsert(
        event(
          id: 'e2',
          startAt: day2.subtract(const Duration(hours: 1)),
          endAt: day2.add(const Duration(minutes: 30)),
        ),
      );

      final onDay1 = await db.eventDao.between(day1, day2);
      final onDay2 = await db.eventDao.between(day2, day3);

      expect(onDay1.map((e) => e.id), ['e2']);
      expect(onDay2.map((e) => e.id), ['e2']);
    });
  });

  group('EventDao.watchUpcoming', () {
    test('only counts events starting at or after "from", not merely still '
        'ongoing — an already-started multi-day event must not push a '
        'genuinely upcoming one out of a capped result', () async {
      final now = DateTime(2026, 3, 10, 12);
      // Started yesterday, still ongoing (ends well after "now").
      await db.eventDao.upsert(
        event(
          id: 'ongoing-trip',
          startAt: now.subtract(const Duration(days: 1)),
          endAt: now.add(const Duration(days: 2)),
        ),
      );
      for (var i = 1; i <= 4; i++) {
        await db.eventDao.upsert(
          event(
            id: 'upcoming-$i',
            startAt: now.add(Duration(hours: i)),
            endAt: now.add(Duration(hours: i + 1)),
          ),
        );
      }

      final result = await db.eventDao.watchUpcoming(now, limit: 4).first;

      expect(result.map((e) => e.id).toList(), [
        'upcoming-1',
        'upcoming-2',
        'upcoming-3',
        'upcoming-4',
      ]);
    });
  });

  group('TodoDao.search', () {
    TodoItemsCompanion todo({required String id, required String title}) {
      return TodoItemsCompanion.insert(
        id: id,
        title: Value(title),
        slotStart: DateTime(2026, 3, 10, 9),
      );
    }

    test('matches a case-insensitive substring of the title', () async {
      await db.todoDao.upsert(todo(id: 't1', title: 'Buy groceries'));
      await db.todoDao.upsert(todo(id: 't2', title: 'Walk the dog'));

      final results = await db.todoDao.search('grocer');

      expect(results.map((t) => t.id), ['t1']);
    });

    test('returns nothing when no title matches', () async {
      await db.todoDao.upsert(todo(id: 't3', title: 'Read a book'));

      final results = await db.todoDao.search('xyz');

      expect(results, isEmpty);
    });
  });

  group('TodoDao.findById', () {
    TodoItemsCompanion todo({required String id, required String title}) {
      return TodoItemsCompanion.insert(
        id: id,
        title: Value(title),
        slotStart: DateTime(2026, 3, 10, 9),
      );
    }

    test('returns the row matching the id', () async {
      await db.todoDao.upsert(todo(id: 't1', title: 'Buy groceries'));

      final found = await db.todoDao.findById('t1');

      expect(found?.title, 'Buy groceries');
    });

    test('returns null for an id that does not exist', () async {
      final found = await db.todoDao.findById('missing');

      expect(found, isNull);
    });
  });

  group('TodoDao priority/tags', () {
    TodoItemsCompanion todo({required String id}) {
      return TodoItemsCompanion.insert(
        id: id,
        title: const Value('Ship the release'),
        slotStart: DateTime(2026, 3, 10, 9),
      );
    }

    test('defaults to priority 0 and null tags', () async {
      await db.todoDao.upsert(todo(id: 't1'));

      final found = await db.todoDao.findById('t1');

      expect(found?.priority, 0);
      expect(found?.tags, isNull);
    });

    test('setPriority persists the new value', () async {
      await db.todoDao.upsert(todo(id: 't2'));

      await db.todoDao.setPriority('t2', 3);

      expect((await db.todoDao.findById('t2'))?.priority, 3);
    });

    test('setTags persists and clears', () async {
      await db.todoDao.upsert(todo(id: 't3'));

      await db.todoDao.setTags('t3', '업무,급함');
      expect((await db.todoDao.findById('t3'))?.tags, '업무,급함');

      await db.todoDao.setTags('t3', null);
      expect((await db.todoDao.findById('t3'))?.tags, isNull);
    });
  });

  group('TodoDao smart-list queries', () {
    TodoItemsCompanion todo({
      required String id,
      required DateTime slotStart,
      bool hasTime = true,
      bool isDone = false,
      int priority = 0,
      String? tags,
    }) {
      return TodoItemsCompanion.insert(
        id: id,
        title: Value(id),
        slotStart: slotStart,
        hasTime: Value(hasTime),
        isDone: Value(isDone),
        priority: Value(priority),
        tags: Value(tags),
      );
    }

    test('watchOverdue returns only not-done, timed to-dos before asOf, '
        'newest-passed first', () async {
      final now = DateTime(2026, 3, 10, 12);
      await db.todoDao.upsert(
        todo(id: 'past1', slotStart: now.subtract(const Duration(hours: 2))),
      );
      await db.todoDao.upsert(
        todo(id: 'past2', slotStart: now.subtract(const Duration(hours: 5))),
      );
      await db.todoDao.upsert(
        todo(
          id: 'past-done',
          slotStart: now.subtract(const Duration(hours: 1)),
          isDone: true,
        ),
      );
      await db.todoDao.upsert(
        todo(
          id: 'past-no-time',
          slotStart: now.subtract(const Duration(hours: 1)),
          hasTime: false,
        ),
      );
      await db.todoDao.upsert(
        todo(id: 'future', slotStart: now.add(const Duration(hours: 1))),
      );

      final overdue = await db.todoDao.watchOverdue(now).first;

      expect(overdue.map((t) => t.id), ['past1', 'past2']);
    });

    test('watchByMinPriority returns not-done to-dos at or above the '
        'threshold, soonest first', () async {
      await db.todoDao.upsert(
        todo(id: 'high', slotStart: DateTime(2026, 3, 12), priority: 3),
      );
      await db.todoDao.upsert(
        todo(id: 'medium', slotStart: DateTime(2026, 3, 11), priority: 2),
      );
      await db.todoDao.upsert(
        todo(
          id: 'high-done',
          slotStart: DateTime(2026, 3, 10),
          priority: 3,
          isDone: true,
        ),
      );

      final highPriority = await db.todoDao.watchByMinPriority(3).first;
      expect(highPriority.map((t) => t.id), ['high']);

      final mediumAndUp = await db.todoDao.watchByMinPriority(2).first;
      expect(mediumAndUp.map((t) => t.id), ['medium', 'high']);
    });

    test('allTags returns every distinct tag, alphabetical', () async {
      await db.todoDao.upsert(
        todo(id: 't1', slotStart: DateTime(2026, 3, 10), tags: '업무,급함'),
      );
      await db.todoDao.upsert(
        todo(id: 't2', slotStart: DateTime(2026, 3, 11), tags: '개인,업무'),
      );
      await db.todoDao.upsert(todo(id: 't3', slotStart: DateTime(2026, 3, 12)));

      final tags = await db.todoDao.allTags();

      expect(tags, ['개인', '급함', '업무']);
    });

    test('watchByTag matches a whole tag segment, not a substring of another '
        'tag', () async {
      await db.todoDao.upsert(
        todo(id: 'exact', slotStart: DateTime(2026, 3, 10), tags: '업무'),
      );
      await db.todoDao.upsert(
        todo(id: 'other-tag', slotStart: DateTime(2026, 3, 11), tags: '영업무'),
      );
      await db.todoDao.upsert(
        todo(
          id: 'done',
          slotStart: DateTime(2026, 3, 12),
          tags: '업무',
          isDone: true,
        ),
      );

      final matches = await db.todoDao.watchByTag('업무').first;

      expect(matches.map((t) => t.id), ['exact']);
    });
  });

  group('TodoDao subtasks', () {
    TodoItemsCompanion todo({required String id}) {
      return TodoItemsCompanion.insert(
        id: id,
        title: const Value('Plan the trip'),
        slotStart: DateTime(2026, 3, 10, 9),
      );
    }

    TodoSubtasksCompanion subtask({
      required String id,
      required String todoId,
      required String title,
      int sortOrder = 0,
    }) {
      return TodoSubtasksCompanion.insert(
        id: id,
        todoId: todoId,
        title: Value(title),
        sortOrder: Value(sortOrder),
      );
    }

    test('watchSubtasks returns a todo\'s checklist in sort order', () async {
      await db.todoDao.upsert(todo(id: 'parent1'));
      await db.todoDao.upsertSubtask(
        subtask(id: 's2', todoId: 'parent1', title: 'Book hotel', sortOrder: 1),
      );
      await db.todoDao.upsertSubtask(
        subtask(
          id: 's1',
          todoId: 'parent1',
          title: 'Book flights',
          sortOrder: 0,
        ),
      );

      final subtasks = await db.todoDao.watchSubtasks('parent1').first;

      expect(subtasks.map((s) => s.title), ['Book flights', 'Book hotel']);
    });

    test('setSubtaskDone toggles completion', () async {
      await db.todoDao.upsert(todo(id: 'parent2'));
      await db.todoDao.upsertSubtask(
        subtask(id: 's3', todoId: 'parent2', title: 'Pack bags'),
      );

      await db.todoDao.setSubtaskDone('s3', true);

      final subtasks = await db.todoDao.watchSubtasks('parent2').first;
      expect(subtasks.single.isDone, isTrue);
    });

    test('deleteSubtask removes just that one', () async {
      await db.todoDao.upsert(todo(id: 'parent3'));
      await db.todoDao.upsertSubtask(
        subtask(id: 's4', todoId: 'parent3', title: 'Keep'),
      );
      await db.todoDao.upsertSubtask(
        subtask(id: 's5', todoId: 'parent3', title: 'Remove'),
      );

      await db.todoDao.deleteSubtask('s5');

      final subtasks = await db.todoDao.watchSubtasks('parent3').first;
      expect(subtasks.map((s) => s.title), ['Keep']);
    });

    test('deleting the parent to-do cascades to its subtasks', () async {
      await db.todoDao.upsert(todo(id: 'parent4'));
      await db.todoDao.upsertSubtask(
        subtask(
          id: 's6',
          todoId: 'parent4',
          title: 'Orphaned once parent goes',
        ),
      );

      await db.todoDao.deleteById('parent4');

      final subtasks = await db.todoDao.watchSubtasks('parent4').first;
      expect(subtasks, isEmpty);
    });

    test('allSubtasks returns every subtask across every to-do', () async {
      await db.todoDao.upsert(todo(id: 'parent5'));
      await db.todoDao.upsert(todo(id: 'parent6'));
      await db.todoDao.upsertSubtask(
        subtask(id: 's7', todoId: 'parent5', title: 'A'),
      );
      await db.todoDao.upsertSubtask(
        subtask(id: 's8', todoId: 'parent6', title: 'B'),
      );

      final all = await db.todoDao.allSubtasks();

      expect(all.map((s) => s.id).toSet(), {'s7', 's8'});
    });
  });

  group('TodoDao no-time to-dos', () {
    final day = DateTime(2026, 4, 1);

    test('watchBetween sorts no-time to-dos before timed ones on the same '
        'day', () async {
      await db.todoDao.upsert(
        TodoItemsCompanion.insert(
          id: 'timed',
          title: const Value('Standup'),
          slotStart: day.add(const Duration(hours: 9)),
        ),
      );
      await db.todoDao.upsert(
        TodoItemsCompanion.insert(
          id: 'untimed',
          title: const Value('Read'),
          slotStart: day,
          hasTime: const Value(false),
        ),
      );

      final rows = await db.todoDao.between(
        day,
        day.add(const Duration(days: 1)),
      );
      final sorted = [...rows]
        ..sort((a, b) => a.hasTime == b.hasTime ? 0 : (a.hasTime ? 1 : -1));

      expect(sorted.map((t) => t.id), ['untimed', 'timed']);
    });

    test(
      'updateSlotStart sets a real time and turns hasTime back on',
      () async {
        await db.todoDao.upsert(
          TodoItemsCompanion.insert(
            id: 'u1',
            title: const Value('Read'),
            slotStart: day,
            hasTime: const Value(false),
          ),
        );

        await db.todoDao.updateSlotStart(
          'u1',
          day.add(const Duration(hours: 14)),
        );

        final row = (await db.todoDao.between(
          day,
          day.add(const Duration(days: 1)),
        )).single;
        expect(row.hasTime, isTrue);
        expect(row.slotStart, day.add(const Duration(hours: 14)));
      },
    );

    test('clearTime turns hasTime off, keeps the date, but normalizes the '
        'time-of-day to midnight', () async {
      final start = day.add(const Duration(hours: 9));
      await db.todoDao.upsert(
        TodoItemsCompanion.insert(
          id: 'c1',
          title: const Value('Standup'),
          slotStart: start,
        ),
      );

      await db.todoDao.clearTime('c1');

      final row = (await db.todoDao.between(
        day,
        day.add(const Duration(days: 1)),
      )).single;
      expect(row.hasTime, isFalse);
      // Normalized to that day's midnight, not left at 9am — every
      // no-time to-do on the same day must share the exact same
      // slotStart, since watchBetween's ORDER BY sorts by slotStart ahead
      // of sortOrder (see TodoDao.clearTime's doc).
      expect(row.slotStart, day);
    });

    test('two no-time to-dos cleared from different original times sort by '
        'sortOrder, not by their old slotStart', () async {
      await db.todoDao.upsert(
        TodoItemsCompanion.insert(
          id: 'late',
          title: const Value('Cleared from 2pm'),
          slotStart: day.add(const Duration(hours: 14)),
          sortOrder: const Value(0),
        ),
      );
      await db.todoDao.upsert(
        TodoItemsCompanion.insert(
          id: 'early',
          title: const Value('Cleared from 9am'),
          slotStart: day.add(const Duration(hours: 9)),
          sortOrder: const Value(1),
        ),
      );
      await db.todoDao.clearTime('late');
      await db.todoDao.clearTime('early');

      final rows = await db.todoDao
          .watchBetween(day, day.add(const Duration(days: 1)))
          .first;
      expect(rows.map((r) => r.id).toList(), ['late', 'early']);
    });
  });

  group('TodoDao series delete + restore (undo mechanics)', () {
    test('seriesFrom reads exactly what deleteSeriesFrom would remove, and '
        're-upserting the captured rows fully restores them', () async {
      final day = DateTime(2026, 5, 1, 9);
      await db.todoDao.upsert(
        TodoItemsCompanion.insert(
          id: 'occ-1',
          title: const Value('Stretch'),
          slotStart: day,
          recurrenceGroupId: const Value('group-y'),
        ),
      );
      await db.todoDao.upsert(
        TodoItemsCompanion.insert(
          id: 'occ-2',
          title: const Value('Stretch'),
          slotStart: day.add(const Duration(days: 1)),
          recurrenceGroupId: const Value('group-y'),
        ),
      );

      final captured = await db.todoDao.seriesFrom('group-y', day);
      expect(captured.map((t) => t.id).toSet(), {'occ-1', 'occ-2'});

      await db.todoDao.deleteSeriesFrom('group-y', day);
      expect(
        await db.todoDao.between(day, day.add(const Duration(days: 2))),
        isEmpty,
      );

      // Undo: re-upsert every captured row exactly as TodoController.restore
      // does (all fields, not just id/title).
      for (final row in captured) {
        await db.todoDao.upsert(
          TodoItemsCompanion(
            id: Value(row.id),
            eventId: Value(row.eventId),
            title: Value(row.title),
            slotStart: Value(row.slotStart),
            slotEnd: Value(row.slotEnd),
            hasTime: Value(row.hasTime),
            isDone: Value(row.isDone),
            sortOrder: Value(row.sortOrder),
            recurrenceRule: Value(row.recurrenceRule),
            recurrenceGroupId: Value(row.recurrenceGroupId),
            createdAt: Value(row.createdAt),
          ),
        );
      }

      final restored = await db.todoDao.between(
        day,
        day.add(const Duration(days: 2)),
      );
      expect(restored.map((t) => t.id).toSet(), {'occ-1', 'occ-2'});
      expect(restored.every((t) => t.recurrenceGroupId == 'group-y'), isTrue);
    });
  });
}
