import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/features/todo/domain/todo_reschedule.dart';

void main() {
  test(
    'bulk move preserves clocks and overnight duration and skips stale targets',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.todoDao.upsert(
        TodoItemsCompanion.insert(
          id: 'timed',
          slotStart: DateTime(2030, 1, 1, 23, 30),
          slotEnd: Value(DateTime(2030, 1, 2, 1)),
        ),
      );
      await db.todoDao.upsert(
        TodoItemsCompanion.insert(
          id: 'untimed',
          slotStart: DateTime(2030),
          hasTime: const Value(false),
        ),
      );
      await db.todoDao.upsert(
        TodoItemsCompanion.insert(
          id: 'done',
          slotStart: DateTime(2030),
          isDone: const Value(true),
        ),
      );
      final service = TodoRescheduler(
        dao: db.todoDao,
        synchronize: (_) async {},
      );
      final result = await service.move({
        'timed',
        'untimed',
        'done',
        'missing',
      }, DateTime(2030, 2, 2));
      final timed = (await db.todoDao.findById('timed'))!;
      expect(timed.slotStart, DateTime(2030, 2, 2, 23, 30));
      expect(timed.slotEnd, DateTime(2030, 2, 3, 1));
      final untimed = (await db.todoDao.findById('untimed'))!;
      expect(untimed.slotStart, DateTime(2030, 2, 2));
      expect(untimed.hasTime, isFalse);
      expect(result.moves, hasLength(2));
      expect(result.skippedIds, {'done', 'missing'});
    },
  );
  test('a failed bulk write rolls back every placement', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    for (final id in ['a', 'b']) {
      await db.todoDao.upsert(
        TodoItemsCompanion.insert(id: id, slotStart: DateTime(2030)),
      );
    }
    await db.customStatement(
      "CREATE TRIGGER fail_move BEFORE UPDATE OF slot_start ON todo_items WHEN NEW.id = 'b' BEGIN SELECT RAISE(ABORT, 'failure'); END",
    );
    final service = TodoRescheduler(dao: db.todoDao, synchronize: (_) async {});
    await expectLater(
      service.move({'a', 'b'}, DateTime(2030, 2, 2)),
      throwsA(anything),
    );
    expect((await db.todoDao.findById('a'))!.slotStart, DateTime(2030));
  });
  test('undo restores placement while preserving a later title edit', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.todoDao.upsert(
      TodoItemsCompanion.insert(id: 'a', slotStart: DateTime(2030)),
    );
    final service = TodoRescheduler(dao: db.todoDao, synchronize: (_) async {});
    final moved = await service.move({'a'}, DateTime(2030, 2, 2));
    await db.todoDao.patch(
      'a',
      const TodoItemsCompanion(title: Value('Later title')),
    );
    final undone = await service.undo(moved.moves);
    final row = (await db.todoDao.findById('a'))!;
    expect(row.slotStart, DateTime(2030));
    expect(row.title, 'Later title');
    expect(undone.moves, hasLength(1));
  });
  test(
    'undo skips independently moved items and deferred sync is reported',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.todoDao.upsert(
        TodoItemsCompanion.insert(id: 'a', slotStart: DateTime(2030)),
      );
      final service = TodoRescheduler(
        dao: db.todoDao,
        synchronize: (_) async => throw Exception('offline'),
      );
      final moved = await service.move({'a'}, DateTime(2030, 2, 2));
      expect(moved.deferredIds, {'a'});
      await db.todoDao.updateSlotStart('a', DateTime(2030, 3, 3));
      final undone = await service.undo(moved.moves);
      expect(undone.skippedIds, {'a'});
      expect((await db.todoDao.findById('a'))!.slotStart, DateTime(2030, 3, 3));
    },
  );
}
