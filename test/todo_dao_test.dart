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

  test(
    'watchAll emits every to-do, including completed and future items',
    () async {
      final now = DateTime(2026, 3, 10, 12);
      await db.todoDao.upsert(
        TodoItemsCompanion.insert(
          id: 'future',
          title: const Value('Future'),
          slotStart: now.add(const Duration(days: 10)),
        ),
      );
      await db.todoDao.upsert(
        TodoItemsCompanion.insert(
          id: 'completed',
          title: const Value('Completed'),
          slotStart: now.subtract(const Duration(days: 1)),
          isDone: const Value(true),
          completedAt: Value(now),
        ),
      );

      final rows = await db.todoDao.watchAll().first;

      expect(rows.map((todo) => todo.id).toSet(), {'future', 'completed'});
    },
  );
  test('earlier unfinished includes untimed past items but not done or future', () async {
    for (final id in ['past', 'done', 'future']) {
      await db.todoDao.upsert(TodoItemsCompanion.insert(id: id,
        slotStart: id == 'future' ? DateTime(2030, 2) : DateTime(2030),
        hasTime: const Value(false), isDone: Value(id == 'done')));
    }
    final rows = await db.todoDao.watchEarlierUnfinished(DateTime(2030, 1, 2)).first;
    expect(rows.map((row) => row.id), ['past']);
  });

}
