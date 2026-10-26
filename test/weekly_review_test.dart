import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/db/app_database.dart';

void main() {
  test('weekly planned and actual completions use different dates', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final start = DateTime(2030, 1, 7), end = DateTime(2030, 1, 14);
    await db.todoDao.upsert(TodoItemsCompanion.insert(id: 'late', slotStart: DateTime(2030, 1, 1),
      isDone: const Value(true), completedAt: Value(start)));
    await db.todoDao.upsert(TodoItemsCompanion.insert(id: 'unknown', slotStart: start,
      isDone: const Value(true)));
    await db.todoDao.upsert(TodoItemsCompanion.insert(id: 'undone', slotStart: start,
      completedAt: Value(start)));
    expect((await db.todoDao.watchScheduledBetween(start, end).first).map((r) => r.id).toSet(), {'unknown', 'undone'});
    expect((await db.todoDao.watchCompletedBetween(start, end).first).map((r) => r.id), ['late']);
    await db.todoDao.deleteById('late');
    expect(await db.todoDao.watchCompletedBetween(start, end).first, isEmpty);
  });
}
