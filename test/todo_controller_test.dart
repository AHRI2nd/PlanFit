import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/features/schedule/domain/ports.dart';
import 'package:planfit/features/todo/application/todo_providers.dart';

import 'todo_controller_test.mocks.dart';

@GenerateMocks([NotificationPort])
void main() {
  late AppDatabase db;
  late MockNotificationPort notifications;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    notifications = MockNotificationPort();
    when(notifications.scheduleForTodo(any)).thenAnswer((_) async {});
    when(notifications.cancelForTodo(any)).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        notificationPortProvider.overrideWithValue(notifications),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  TodoController controller() => container.read(todoControllerProvider);

  group('add', () {
    test(
      'schedules a notification when hasTime and notify default on',
      () async {
        final slot = DateTime.now().add(const Duration(hours: 2));
        await controller().add(title: 'Call dentist', slotStart: slot);

        final row = (await db.todoDao.all()).single;
        expect(row.notify, isTrue);
        verify(notifications.scheduleForTodo(row)).called(1);
        verifyNever(notifications.cancelForTodo(any));
      },
    );

    test('does not schedule when hasTime is false', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'Someday', slotStart: slot, hasTime: false);

      final row = (await db.todoDao.all()).single;
      expect(row.notify, isFalse);
      verifyNever(notifications.scheduleForTodo(any));
    });

    test(
      'an explicit notify: false overrides the hasTime-based default',
      () async {
        final slot = DateTime.now().add(const Duration(hours: 2));
        await controller().add(
          title: 'Quiet reminder',
          slotStart: slot,
          notify: false,
        );

        final row = (await db.todoDao.all()).single;
        expect(row.notify, isFalse);
        verifyNever(notifications.scheduleForTodo(any));
      },
    );
  });

  group('toggle', () {
    test('marking done cancels the notification', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'Call dentist', slotStart: slot);
      final row = (await db.todoDao.all()).single;
      clearInteractions(notifications);

      await controller().toggle(row.id, true);

      verify(notifications.cancelForTodo(row.id)).called(1);
      verifyNever(notifications.scheduleForTodo(any));
    });

    test('un-marking a still-future done to-do re-schedules it', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'Call dentist', slotStart: slot);
      final row = (await db.todoDao.all()).single;
      await controller().toggle(row.id, true);
      clearInteractions(notifications);

      await controller().toggle(row.id, false);

      verify(notifications.scheduleForTodo(any)).called(1);
    });
  });

  group('setNotify', () {
    test('turning notify off cancels an already-scheduled to-do', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'Call dentist', slotStart: slot);
      final row = (await db.todoDao.all()).single;
      clearInteractions(notifications);

      await controller().setNotify(row.id, false);

      final updated = await db.todoDao.findById(row.id);
      expect(updated?.notify, isFalse);
      verify(notifications.cancelForTodo(row.id)).called(1);
    });
  });

  group('setPinned', () {
    test('persists the pinned flag', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'Call dentist', slotStart: slot);
      final row = (await db.todoDao.all()).single;

      await controller().setPinned(row.id, true);

      final updated = await db.todoDao.findById(row.id);
      expect(updated?.isPinned, isTrue);
    });

    test('unpinning clears the flag', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'Call dentist', slotStart: slot);
      final row = (await db.todoDao.all()).single;
      await controller().setPinned(row.id, true);

      await controller().setPinned(row.id, false);

      final updated = await db.todoDao.findById(row.id);
      expect(updated?.isPinned, isFalse);
    });
  });

  group('setAdditionalReminders', () {
    test('persists the joined offsets and re-syncs the notification', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'Call dentist', slotStart: slot);
      final row = (await db.todoDao.all()).single;
      clearInteractions(notifications);

      await controller().setAdditionalReminders(row.id, {60, 1440});

      final updated = await db.todoDao.findById(row.id);
      expect(updated?.additionalReminderMinutes, '60,1440');
      verify(notifications.scheduleForTodo(any)).called(1);
    });

    test('an empty set clears the column back to null', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'Call dentist', slotStart: slot);
      final row = (await db.todoDao.all()).single;
      await controller().setAdditionalReminders(row.id, {60});

      await controller().setAdditionalReminders(row.id, {});

      final updated = await db.todoDao.findById(row.id);
      expect(updated?.additionalReminderMinutes, isNull);
    });
  });

  group('reorder', () {
    test(
      'moving the first item to the end rewrites sortOrder for all three',
      () async {
        final slot = DateTime.now().add(const Duration(hours: 2));
        await controller().add(title: 'A', slotStart: slot, hasTime: false);
        await controller().add(title: 'B', slotStart: slot, hasTime: false);
        await controller().add(title: 'C', slotStart: slot, hasTime: false);
        final rows = await db.todoDao.all();
        final a = rows.firstWhere((r) => r.title == 'A');
        final b = rows.firstWhere((r) => r.title == 'B');
        final c = rows.firstWhere((r) => r.title == 'C');

        // onReorderItem semantics: dragging index 0 to the end of a
        // 3-item list reports newIndex 2 (already adjusted, unlike the
        // deprecated onReorder).
        await controller().reorder([a, b, c], 0, 2);

        final updatedB = await db.todoDao.findById(b.id);
        final updatedC = await db.todoDao.findById(c.id);
        final updatedA = await db.todoDao.findById(a.id);
        expect(updatedB?.sortOrder, 0);
        expect(updatedC?.sortOrder, 1);
        expect(updatedA?.sortOrder, 2);
      },
    );

    test('the new order is reflected by a fresh query afterward', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'A', slotStart: slot, hasTime: false);
      await controller().add(title: 'B', slotStart: slot, hasTime: false);
      final rows = await db.todoDao.all();
      final a = rows.firstWhere((r) => r.title == 'A');
      final b = rows.firstWhere((r) => r.title == 'B');

      await controller().reorder([a, b], 0, 1);

      final start = DateTime(slot.year, slot.month, slot.day);
      final requeried = await db.todoDao.between(
        start,
        start.add(const Duration(days: 1)),
      );
      final byId = {for (final r in requeried) r.id: r};
      expect(byId[b.id]?.sortOrder, lessThan(byId[a.id]!.sortOrder));
    });
  });

  group('pruneCompleted', () {
    test(
      'deletes a completed to-do older than retention, cancels its notification',
      () async {
        final slot = DateTime.now().subtract(const Duration(days: 10));
        await db.todoDao.upsert(
          TodoItemsCompanion.insert(
            id: 'old-done',
            title: const Value('Old task'),
            slotStart: slot,
            isDone: const Value(true),
            completedAt: Value(
              DateTime.now().subtract(const Duration(days: 8)),
            ),
          ),
        );
        clearInteractions(notifications);

        final count = await controller().pruneCompleted(
          const Duration(days: 7),
        );

        expect(count, 1);
        expect(await db.todoDao.findById('old-done'), isNull);
        verify(notifications.cancelForTodo('old-done')).called(1);
      },
    );

    test('leaves a recently-completed to-do alone', () async {
      final slot = DateTime.now();
      await db.todoDao.upsert(
        TodoItemsCompanion.insert(
          id: 'recent-done',
          title: const Value('Recent task'),
          slotStart: slot,
          isDone: const Value(true),
          completedAt: Value(DateTime.now().subtract(const Duration(hours: 1))),
        ),
      );

      final count = await controller().pruneCompleted(const Duration(days: 7));

      expect(count, 0);
      expect(await db.todoDao.findById('recent-done'), isNotNull);
    });

    test('leaves a not-done to-do alone regardless of age', () async {
      final slot = DateTime.now().subtract(const Duration(days: 30));
      await controller().add(title: 'Still open', slotStart: slot);

      final count = await controller().pruneCompleted(const Duration(days: 7));

      expect(count, 0);
    });
  });

  group('remove / restore', () {
    test('remove cancels the notification', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'Call dentist', slotStart: slot);
      final row = (await db.todoDao.all()).single;
      clearInteractions(notifications);

      await controller().remove(row.id);

      verify(notifications.cancelForTodo(row.id)).called(1);
    });

    test('restore re-schedules a notify-on to-do', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'Call dentist', slotStart: slot);
      final row = (await db.todoDao.all()).single;
      final removed = await controller().remove(row.id);
      clearInteractions(notifications);

      await controller().restore(removed.single);

      verify(notifications.scheduleForTodo(any)).called(1);
    });

    test('restore preserves additionalReminderMinutes', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'Call dentist', slotStart: slot);
      final row = (await db.todoDao.all()).single;
      await controller().setAdditionalReminders(row.id, {60});
      final removed = await controller().remove(row.id);

      await controller().restore(removed.single);

      final restored = await db.todoDao.findById(row.id);
      expect(restored?.additionalReminderMinutes, '60');
    });

    test('restore preserves isPinned', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'Call dentist', slotStart: slot);
      final row = (await db.todoDao.all()).single;
      await controller().setPinned(row.id, true);
      final removed = await controller().remove(row.id);

      await controller().restore(removed.single);

      final restored = await db.todoDao.findById(row.id);
      expect(restored?.isPinned, isTrue);
    });
  });

  group('refillNotifications', () {
    test('schedules notify-on to-dos inside the window', () async {
      final slot = DateTime.now().add(const Duration(days: 1));
      await controller().add(title: 'Water plants', slotStart: slot);
      clearInteractions(notifications);

      await controller().refillNotifications();

      verify(notifications.scheduleForTodo(any)).called(1);
    });

    test(
      'skips a done to-do even if it is notify-on and in the window',
      () async {
        final slot = DateTime.now().add(const Duration(days: 1));
        await controller().add(title: 'Water plants', slotStart: slot);
        final row = (await db.todoDao.all()).single;
        await controller().toggle(row.id, true);
        clearInteractions(notifications);

        await controller().refillNotifications();

        verifyNever(notifications.scheduleForTodo(any));
      },
    );
  });
}
