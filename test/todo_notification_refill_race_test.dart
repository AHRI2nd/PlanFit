import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/features/todo/application/todo_providers.dart';

import 'todo_controller_test.mocks.dart';

/// Covers a TOCTOU race that used to exist in
/// [TodoController.refillNotifications]: `candidates` (todo_providers.dart)
/// is a single DB snapshot taken once at the top of the call, but the loop
/// then `await`s a `NotificationPort.scheduleForTodo` platform-channel call
/// per candidate. If a concurrent edit lands on a later candidate while an
/// earlier candidate's platform-channel call is still in flight, the loop
/// used to keep using its pre-edit copy of that later candidate for the
/// rest of the pass, resurrecting/re-arming a reminder the concurrent edit
/// had just turned off. Fixed by re-fetching each row's live state
/// immediately before actually scheduling it.
void main() {
  late AppDatabase db;
  late MockNotificationPort notifications;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    notifications = MockNotificationPort();
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

  test(
    'does not resurrect a reminder for a todo marked done by a concurrent '
    'edit that lands mid-loop (TOCTOU race — candidates snapshot goes stale '
    'while the loop is still awaiting earlier platform-channel calls)',
    () async {
      when(notifications.scheduleForTodo(any)).thenAnswer((_) async {});
      final slot = DateTime.now().add(const Duration(days: 1));
      await controller().add(title: 'First', slotStart: slot);
      await controller().add(title: 'Second', slotStart: slot);
      final rows = await db.todoDao.all();
      final second = rows.firstWhere((r) => r.title == 'Second');
      clearInteractions(notifications);

      // Simulate a concurrent user action (e.g. checking the to-do off)
      // completing while `refillNotifications`'s loop is still awaiting the
      // *first* candidate's `scheduleForTodo` platform-channel call — the
      // same interleaving any real `await` inside a plugin call permits.
      var editApplied = false;
      when(notifications.scheduleForTodo(any)).thenAnswer((invocation) async {
        final row = invocation.positionalArguments.single as TodoRow;
        if (row.id != second.id && !editApplied) {
          editApplied = true;
          // Marking "Second" done cancels its notification via
          // syncTodoNotification (todo_notification_sync.dart).
          await controller().toggle(second.id, true);
        }
      });

      await controller().refillNotifications();

      // "Second" was marked done *during* the refill loop, before the loop
      // ever reached it — a correct implementation must not re-schedule a
      // reminder for it. Pre-fix, it did: `candidates` (captured once,
      // before the concurrent toggle) still showed it as not-done, and
      // nothing re-checked its live state before scheduling.
      verifyNever(
        notifications.scheduleForTodo(
          argThat(predicate<TodoRow>((r) => r.id == second.id)),
        ),
      );
    },
  );
}
