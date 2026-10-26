import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/features/todo/domain/todo_time_block.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());
  test('rejects invalid intervals', () {
    expect(
      () => TodoTimeBlock(DateTime(2030), DateTime(2030)),
      throwsArgumentError,
    );
  });
  test(
    'moves overnight intervals, queries overlap and clears the end',
    () async {
      await db.todoDao.upsert(
        TodoItemsCompanion.insert(
          id: 'a',
          slotStart: DateTime(2030, 1, 1, 23),
          slotEnd: Value(DateTime(2030, 1, 2, 1)),
        ),
      );
      expect(
        (await db.todoDao.between(
          DateTime(2030, 1, 2),
          DateTime(2030, 1, 3),
        )).single.id,
        'a',
      );
      await db.todoDao.updateSlotDate('a', DateTime(2030, 2, 2));
      expect(
        (await db.todoDao.findById('a'))!.slotEnd,
        DateTime(2030, 2, 3, 1),
      );
      await db.todoDao.updateSlotStart('a', DateTime(2030, 2, 2, 22));
      expect((await db.todoDao.findById('a'))!.slotEnd, DateTime(2030, 2, 3));
      expect(
        await db.todoDao.between(DateTime(2030, 2, 3), DateTime(2030, 2, 4)),
        isEmpty,
      );
      await db.todoDao.clearTime('a');
      final row = (await db.todoDao.findById('a'))!;
      expect(row.slotEnd, isNull);
      expect(row.hasTime, false);
    },
  );
  test(
    'local save is reported even if platform synchronization fails',
    () async {
      await db.todoDao.upsert(
        TodoItemsCompanion.insert(id: 'a', slotStart: DateTime(2030)),
      );
      final writer = TodoTimeBlockWriter(
        dao: db.todoDao,
        synchronize: (_) async => throw StateError('offline'),
      );
      final result = await writer.save(
        'a',
        TodoTimeBlock(DateTime(2030, 1, 1, 9), DateTime(2030, 1, 1, 10)),
      );
      expect(result.saved, true);
      expect(result.deferred, true);
      expect((await db.eventDao.all()), isEmpty);
      await db.todoDao.setDone('a', true);
      expect(
        () => writer.save(
          'a',
          TodoTimeBlock(DateTime(2030), DateTime(2030, 1, 2)),
        ),
        throwsStateError,
      );
    },
  );
  test('availability merges busy intervals and allows adjacent ranges', () {
    final day = DateTime(2030, 1, 7);
    final work = TodoTimeBlock(
      DateTime(2030, 1, 7, 9),
      DateTime(2030, 1, 7, 12),
    );
    final slots = availableTimeBlocks(
      work: work,
      duration: const Duration(hours: 1),
      busy: [
        TodoTimeBlock(DateTime(2030, 1, 7, 10), DateTime(2030, 1, 7, 11)),
        TodoTimeBlock(day, DateTime(2030, 1, 7, 9)),
      ],
    );
    expect(slots.map((s) => s.start.hour), [9, 11]);
  });
  test(
    'apply rechecks conflicts including changes after acknowledgement',
    () async {
      await db.todoDao.upsert(
        TodoItemsCompanion.insert(id: 'a', slotStart: DateTime(2030)),
      );
      await db.eventDao.upsert(
        EventsCompanion.insert(
          id: 'busy',
          title: const Value('Meeting'),
          startAt: DateTime(2030, 1, 1, 9),
          endAt: DateTime(2030, 1, 1, 10),
        ),
      );
      final writer = TodoTimeBlockWriter(
        dao: db.todoDao,
        synchronize: (_) async {},
      );
      final block = TodoTimeBlock(
        DateTime(2030, 1, 1, 9),
        DateTime(2030, 1, 1, 10),
      );
      final first = await writer.save('a', block);
      expect(first.saved, false);
      expect(first.conflicts.single.title, 'Meeting');
      expect((await db.todoDao.findById('a'))!.slotEnd, isNull);
      await db.eventDao.patch(
        'busy',
        EventsCompanion(endAt: Value(DateTime(2030, 1, 1, 11))),
      );
      final second = await writer.save(
        'a',
        block,
        acknowledgedConflicts: first.conflicts.map((c) => c.token).toSet(),
      );
      expect(second.saved, false);
      final third = await writer.save(
        'a',
        block,
        acknowledgedConflicts: second.conflicts.map((c) => c.token).toSet(),
      );
      expect(third.saved, true);
    },
  );
}
