import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/clock.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/features/todo/application/todo_providers.dart';

void main() {
  test('due classification advances without a database write', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final clock = StreamController<DateTime>();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        nowTickerProvider.overrideWith((ref) => clock.stream),
      ],
    );
    container.listen(nowTickerProvider, (_, _) {});
    addTearDown(() async {
      container.dispose();
      unawaited(clock.close());
      await db.close();
    });
    await db.todoDao.upsert(
      TodoItemsCompanion.insert(
        id: 'due',
        slotStart: DateTime(2031, 1, 1, 12),
        title: const Value('Due at noon'),
      ),
    );
    clock.add(DateTime(2031, 1, 1, 11));
    await container.read(nowTickerProvider.future);
    container.listen(overdueTodosProvider, (_, _) {});
    expect(await container.read(overdueTodosProvider.future), isEmpty);
    clock.add(DateTime(2031, 1, 1, 13));
    await Future<void>.delayed(Duration.zero);
    expect(
      (await container.read(overdueTodosProvider.future)).map((t) => t.id),
      ['due'],
    );
  });
}
