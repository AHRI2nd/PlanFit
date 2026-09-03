import '../../../core/db/app_database.dart';
import '../../schedule/domain/ports.dart';

/// Schedules or cancels [row]'s due-time alert based on its current state —
/// shared by [TodoController] (every write that could change eligibility)
/// and [BackupService] (a restored to-do needs the exact same judgment).
/// `NotificationService.scheduleForTodo` itself judges whether `slotStart`
/// is still in the future and inside the near-term scheduling window; this
/// only decides whether to ask it to schedule at all.
///
/// Best-effort, same reasoning every other notification/calendar/reminder
/// side-effect in this codebase already documents (see e.g.
/// `EventRepositoryImpl._applySideEffects`, `TodoController._syncReminder`
/// right next to every one of this function's own callers): a transient
/// platform-channel error (a real, known failure mode of
/// `flutter_local_notifications` on some Android OEMs/versions — exact-alarm
/// permission edge cases in particular) must not surface as a failure of
/// whatever data operation triggered this call. Without this, one to-do
/// throwing partway through `BackupService.importFromFile`'s restore loop
/// showed the user a generic "복원 실패" even though the restore itself had
/// already committed successfully — the notification side-effect was the
/// only part that failed.
Future<void> syncTodoNotification(
  NotificationPort notifications,
  TodoRow row,
) async {
  try {
    if (row.notify && row.hasTime && !row.isDone) {
      await notifications.scheduleForTodo(row);
    } else {
      await notifications.cancelForTodo(row.id);
    }
  } on Exception {
    // See doc comment above.
  }
}
