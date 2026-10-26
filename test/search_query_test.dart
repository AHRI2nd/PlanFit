import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/search/search_options.dart';

void main() {
  test('filters old event matches before limiting recent results', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    for (var i = 0; i < 105; i++) {
      await db.eventDao.upsert(EventsCompanion.insert(
        id: '$i', title: const Value('meeting'),
        startAt: DateTime(2030, 1, 1).add(Duration(days: i)),
        endAt: DateTime(2030, 1, 2).add(Duration(days: i)),
        colorTag: Value(i == 0 ? '#112233' : 'amber'),
      ));
    }
    final rows = await db.eventDao.search('meeting',
      options: const SearchOptions(colorTag: '#112233'));
    expect(rows.map((e) => e.id), ['0']);
  });
  test('tags use trimmed whole tokens and dates filter todos', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    for (final entry in {'a': '  work  , other', 'b': 'homework'}.entries) {
      await db.todoDao.upsert(TodoItemsCompanion.insert(
        id: entry.key, title: const Value('task'),
        slotStart: DateTime(2030, 1, 1), tags: Value(entry.value),
      ));
    }
    final rows = await db.todoDao.search('task',
      options: SearchOptions(tag: 'work', from: DateTime(2030), to: DateTime(2030, 1, 2)));
    expect(rows.map((t) => t.id), ['a']);
  });
}
