import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/features/todo/application/todo_providers.dart';

import 'todo_controller_test.mocks.dart';

/// iOS holds at most 64 pending local notifications per app and silently
/// drops whatever doesn't fit. `notificationSchedulingWindow` alone does not
/// prevent that — it bounds how far ahead alerts are scheduled, not how many
/// land inside the window — so a dense enough schedule overflows it.
///
/// Overflow is worse than it first looks. A dropped alert never comes back
/// in `pendingNotificationRequests()`, so the refill passes read it as
/// missing and re-request it on every foreground resume, for an alert the OS
/// drops again every time: an unbounded, permanently futile round trip per
/// resume, with the OS rather than the app deciding which alerts survive.
///
/// These pin the budgets that replaced that, on the to-do side (the event
/// side's ranking is covered in notification_service_test.dart).
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

  /// [count] notifiable to-dos, each an hour further out than the last, all
  /// comfortably inside the scheduling window.
  Future<void> seed(int count) async {
    final base = DateTime.now().add(const Duration(days: 1));
    for (var i = 0; i < count; i++) {
      await controller().add(
        title: 'todo-$i',
        slotStart: base.add(Duration(hours: i)),
      );
    }
    clearInteractions(notifications);
  }

  test('schedules no more than the budget, however many to-dos are due '
      'inside the window', () async {
    await seed(TodoController.maxPendingTodoAlerts + 15);

    await controller().refillNotifications();

    verify(
      notifications.scheduleForTodo(any),
    ).called(TodoController.maxPendingTodoAlerts);
  });

  test('keeps the soonest to-dos rather than whichever the query happened '
      'to return first', () async {
    await seed(TodoController.maxPendingTodoAlerts + 5);

    final scheduled = <TodoRow>[];
    when(notifications.scheduleForTodo(any)).thenAnswer((inv) async {
      scheduled.add(inv.positionalArguments.first as TodoRow);
    });

    await controller().refillNotifications();

    final all = await db.todoDao.all()
      ..sort((a, b) => a.slotStart.compareTo(b.slotStart));
    expect(
      scheduled.map((t) => t.id).toSet(),
      all.take(TodoController.maxPendingTodoAlerts).map((t) => t.id).toSet(),
      reason: 'a reminder for tomorrow matters more than one for next month',
    );
  });

  test('cancels the ones past the budget instead of leaving them pending — '
      'an earlier pass with fewer to-dos in the window may well have '
      'scheduled them, and a stale pending alert spends one of the very '
      'slots the budget exists to protect', () async {
    const overflow = 7;
    await seed(TodoController.maxPendingTodoAlerts + overflow);

    await controller().refillNotifications();

    verify(notifications.cancelForTodo(any)).called(overflow);
  });

  test(
    'leaves every to-do scheduled when the window holds fewer than the '
    'budget — the cap must not cost anything for an ordinary schedule',
    () async {
      await seed(TodoController.maxPendingTodoAlerts - 3);

      await controller().refillNotifications();

      verify(
        notifications.scheduleForTodo(any),
      ).called(TodoController.maxPendingTodoAlerts - 3);
      verifyNever(notifications.cancelForTodo(any));
    },
  );
}
