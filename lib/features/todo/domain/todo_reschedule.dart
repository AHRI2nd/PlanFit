import 'package:drift/drift.dart' show Value;
import '../../../core/date_math.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/daos/todo_dao.dart';
import '../../../core/db/sync_status.dart';
import '../../../core/serial_queue.dart';

class TodoPlacement {
  const TodoPlacement(this.start, this.end, this.hasTime);
  factory TodoPlacement.of(TodoRow row) => TodoPlacement(row.slotStart, row.slotEnd, row.hasTime);
  final DateTime start;
  final DateTime? end;
  final bool hasTime;
  bool matches(TodoRow row) => start == row.slotStart && end == row.slotEnd && hasTime == row.hasTime;
  TodoItemsCompanion get patch => TodoItemsCompanion(slotStart: Value(start),
    slotEnd: Value(end), hasTime: Value(hasTime),
    reminderSyncStatus: const Value(SyncStatus.pendingPush));
  TodoPlacement onDay(DateTime day) {
    final moved = hasTime ? DateTime(day.year, day.month, day.day, start.hour,
      start.minute, start.second, start.millisecond, start.microsecond)
      : DateTime(day.year, day.month, day.day);
    if (end != null && !end!.isAfter(start)) throw StateError('Invalid todo interval');
    return TodoPlacement(moved,
      !hasTime || end == null ? null : shiftTimeOfDay(moved, calendarDuration(start, end!)), hasTime);
  }
}
class TodoMove {
  const TodoMove(this.id, this.before, this.after);
  final String id;
  final TodoPlacement before;
  final TodoPlacement after;
}
class TodoRescheduleResult {
  TodoRescheduleResult(Iterable<TodoMove> moves, Iterable<String> skipped, Iterable<String> deferred)
    : moves = List.unmodifiable(moves), skippedIds = Set.unmodifiable(skipped),
      deferredIds = Set.unmodifiable(deferred);
  final List<TodoMove> moves;
  final Set<String> skippedIds;
  final Set<String> deferredIds;
}

/// Serializes placement writes and their platform work, without holding SQL
/// transactions open across notification or EventKit calls.
class TodoRescheduler {
  TodoRescheduler({required this.dao, required this.synchronize});
  final TodoDao dao;
  final Future<void> Function(String id) synchronize;
  final _queue = SerialQueue();

  Future<TodoRescheduleResult> move(Iterable<String> ids, DateTime day) {
    final selected = ids.toSet();
    return _queue.run(() async {
      final moves = <TodoMove>[];
      final skipped = <String>{};
      await dao.transaction(() async {
        for (final id in selected) {
          final row = await dao.findById(id);
          if (row == null || row.isDone) { skipped.add(id); continue; }
          final before = TodoPlacement.of(row);
          final after = before.onDay(day);
          if (after.matches(row)) { skipped.add(id); continue; }
          await dao.patch(id, after.patch);
          moves.add(TodoMove(id, before, after));
        }
      });
      return _publish(moves, skipped);
    });
  }

  Future<TodoRescheduleResult> undo(Iterable<TodoMove> changes) {
    final snapshot = changes.toList(growable: false);
    return _queue.run(() async {
      final restored = <TodoMove>[];
      final skipped = <String>{};
      await dao.transaction(() async {
        for (final move in snapshot) {
          final current = await dao.findById(move.id);
          if (current == null || current.isDone || !move.after.matches(current)) {
            skipped.add(move.id); continue;
          }
          await dao.patch(move.id, move.before.patch);
          restored.add(TodoMove(move.id, move.after, move.before));
        }
      });
      return _publish(restored, skipped);
    });
  }

  Future<TodoRescheduleResult> _publish(List<TodoMove> moves, Set<String> skipped) async {
    final deferred = <String>{};
    for (final move in moves) {
      try { await synchronize(move.id); } catch (_) { deferred.add(move.id); }
    }
    return TodoRescheduleResult(moves, skipped, deferred);
  }
}
