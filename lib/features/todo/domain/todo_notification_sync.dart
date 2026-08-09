import '../../../core/db/app_database.dart';
import '../../schedule/domain/ports.dart';

/// Schedules or cancels [row]'s due-time alert based on its current state —
/// shared by [TodoController] (every write that could change eligibility)
/// and [BackupService] (a restored to-do needs the exact same judgment).
/// `NotificationService.scheduleForTodo` itself judges whether `slotStart`
/// is still in the future and inside the near-term scheduling window; this
/// only decides whether to ask it to schedule at all.
Future<void> syncTodoNotification(NotificationPort notifications, TodoRow row) {
  if (row.notify && row.hasTime && !row.isDone) {
    return notifications.scheduleForTodo(row);
  }
  return notifications.cancelForTodo(row.id);
}
