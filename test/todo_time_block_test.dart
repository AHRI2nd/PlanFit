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
    expect(() => TodoTimeBlock(DateTime(2030), DateTime(2030)), throwsArgumentError);
  });
  test('moves overnight intervals, queries overlap and clears the end', () async {
    await db.todoDao.upsert(TodoItemsCompanion.insert(id: 'a', slotStart: DateTime(2030, 1, 1, 23),
      slotEnd: Value(DateTime(2030, 1, 2, 1))));
    expect((await db.todoDao.between(DateTime(2030, 1, 2), DateTime(2030, 1, 3))).single.id, 'a');
    await db.todoDao.updateSlotDate('a', DateTime(2030, 2, 2));
    expect((await db.todoDao.findById('a'))!.slotEnd, DateTime(2030, 2, 3, 1));
    await db.todoDao.updateSlotStart('a', DateTime(2030, 2, 2, 22));
    expect((await db.todoDao.findById('a'))!.slotEnd, DateTime(2030, 2, 3));
    expect(await db.todoDao.between(DateTime(2030, 2, 3), DateTime(2030, 2, 4)), isEmpty);
    await db.todoDao.clearTime('a');
    final row = (await db.todoDao.findById('a'))!;
    expect(row.slotEnd, isNull); expect(row.hasTime, false);
  });
  test('local save is reported even if platform synchronization fails', () async {
    await db.todoDao.upsert(TodoItemsCompanion.insert(id: 'a', slotStart: DateTime(2030)));
    final writer = TodoTimeBlockWriter(dao: db.todoDao, synchronize: (_) async => throw StateError('offline'));
    final result = await writer.save('a', TodoTimeBlock(DateTime(2030, 1, 1, 9), DateTime(2030, 1, 1, 10)));
    expect(result.saved, true); expect(result.deferred, true);
    expect((await db.eventDao.all()), isEmpty);
    await db.todoDao.setDone('a', true);
    expect(() => writer.save('a', TodoTimeBlock(DateTime(2030), DateTime(2030, 1, 2))), throwsStateError);
  });
}
