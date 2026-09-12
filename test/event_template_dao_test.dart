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

  EventTemplatesCompanion template({
    required String id,
    required String name,
    required DateTime createdAt,
    String title = '',
  }) {
    return EventTemplatesCompanion.insert(
      id: id,
      name: name,
      title: Value(title),
      createdAt: Value(createdAt),
    );
  }

  test('upsert then all() round-trips every field, oldest createdAt first', () async {
    await db.eventTemplateDao.upsert(
      template(
        id: 't2',
        name: 'Standup',
        createdAt: DateTime(2026, 3, 2),
        title: 'Daily standup',
      ),
    );
    await db.eventTemplateDao.upsert(
      template(id: 't1', name: 'Gym', createdAt: DateTime(2026, 3, 1)),
    );

    final all = await db.eventTemplateDao.all();
    expect(all.map((t) => t.id), ['t1', 't2']);
    expect(all[1].name, 'Standup');
    expect(all[1].title, 'Daily standup');
  });

  test(
    'upsert with an existing id updates that row in place rather than '
    'inserting a duplicate',
    () async {
      await db.eventTemplateDao.upsert(
        template(id: 't1', name: 'Gym', createdAt: DateTime(2026, 3, 1)),
      );
      await db.eventTemplateDao.upsert(
        template(
          id: 't1',
          name: 'Gym (renamed)',
          createdAt: DateTime(2026, 3, 1),
        ),
      );

      final all = await db.eventTemplateDao.all();
      expect(all, hasLength(1));
      expect(all.single.name, 'Gym (renamed)');
    },
  );

  test('deleteById removes only the matching row', () async {
    await db.eventTemplateDao.upsert(
      template(id: 't1', name: 'Gym', createdAt: DateTime(2026, 3, 1)),
    );
    await db.eventTemplateDao.upsert(
      template(id: 't2', name: 'Standup', createdAt: DateTime(2026, 3, 2)),
    );

    await db.eventTemplateDao.deleteById('t1');

    final all = await db.eventTemplateDao.all();
    expect(all.map((t) => t.id), ['t2']);
  });

  test('watchAll() emits the current set after each write', () async {
    final emissions = <int>[];
    final sub = db.eventTemplateDao.watchAll().listen(
      (rows) => emissions.add(rows.length),
    );
    addTearDown(sub.cancel);

    await pumpEventQueue();
    await db.eventTemplateDao.upsert(
      template(id: 't1', name: 'Gym', createdAt: DateTime(2026, 3, 1)),
    );
    await pumpEventQueue();

    expect(emissions, [0, 1]);
  });
}
