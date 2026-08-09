import '../../../core/db/app_database.dart';

/// Whether [todo] is overdue as of [asOf] — a timed, not-done to-do whose
/// slot has already passed. Shared by every place that highlights overdue
/// to-dos (the day view's tile, the smart list's tile, the home screen's
/// today card) so the definition can't drift between them; matches
/// `TodoDao.watchOverdue`'s own criteria.
bool isTodoOverdue(TodoRow todo, DateTime asOf) =>
    todo.hasTime && !todo.isDone && todo.slotStart.isBefore(asOf);
