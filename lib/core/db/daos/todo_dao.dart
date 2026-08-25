import 'package:drift/drift.dart';

import '../../../features/todo/domain/todo_tag_match.dart';
import '../app_database.dart';
import '../sync_status.dart';
import '../tables.dart';

part 'todo_dao.g.dart';

@DriftAccessor(tables: [TodoItems, TodoSubtasks])
class TodoDao extends DatabaseAccessor<AppDatabase> with _$TodoDaoMixin {
  TodoDao(super.db);

  /// To-dos whose slot starts within [from, to). No-time to-dos (see
  /// [TodoItems.hasTime]) sort first as a group — they belong to the day but
  /// not to any particular hour in it — then the rest by slot, then manual
  /// sort order.
  Stream<List<TodoRow>> watchBetween(DateTime from, DateTime to) {
    return (select(todoItems)
          ..where(
            (t) =>
                t.slotStart.isBiggerOrEqualValue(from) &
                t.slotStart.isSmallerThanValue(to),
          )
          ..orderBy([
            (t) => OrderingTerm(expression: t.hasTime),
            (t) => OrderingTerm(expression: t.slotStart),
            (t) => OrderingTerm(expression: t.sortOrder),
          ]))
        .watch();
  }

  Future<List<TodoRow>> between(DateTime from, DateTime to) {
    return (select(todoItems)..where(
          (t) =>
              t.slotStart.isBiggerOrEqualValue(from) &
              t.slotStart.isSmallerThanValue(to),
        ))
        .get();
  }

  Future<void> upsert(TodoItemsCompanion companion) =>
      into(todoItems).insertOnConflictUpdate(companion);

  /// Every to-do, for a full-database export.
  Future<List<TodoRow>> all() => select(todoItems).get();

  Future<TodoRow?> findById(String id) =>
      (select(todoItems)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Partial update of an existing row (e.g. writing back OS-reminder
  /// linkage without re-supplying every required column) — the to-do
  /// equivalent of `EventDao.patch`.
  Future<void> patch(String id, TodoItemsCompanion companion) =>
      (update(todoItems)..where((t) => t.id.equals(id))).write(companion);

  /// To-dos created/edited locally that still need pushing to the OS
  /// reminders list — the to-do equivalent of `EventDao.needingPush`.
  Future<List<TodoRow>> needingReminderPush() {
    return (select(todoItems)..where(
          (t) => t.reminderSyncStatus.equalsValue(SyncStatus.pendingPush),
        ))
        .get();
  }

  /// The local row linked to one OS reminder, if any — used by the
  /// reconciler to decide update vs. detach when pulling changes back.
  Future<TodoRow?> findByOsReminderId(String osReminderId) => (select(
    todoItems,
  )..where((t) => t.osReminderId.equals(osReminderId))).getSingleOrNull();

  /// Every to-do currently linked to an OS reminder — the reconciler's pull
  /// scan. Unlike events (windowed by date), to-dos have no natural time
  /// bound to scan within, and a personal to-do list is small enough that
  /// scanning every linked row on each foreground resume is cheap.
  Future<List<TodoRow>> linkedToReminders() {
    return (select(todoItems)..where((t) => t.osReminderId.isNotNull())).get();
  }

  Future<void> setDone(String id, bool done) =>
      (update(todoItems)..where((t) => t.id.equals(id))).write(
        TodoItemsCompanion(
          isDone: Value(done),
          completedAt: Value(done ? DateTime.now() : null),
        ),
      );

  /// Sets a concrete time — implicitly turns a no-time to-do back into a
  /// timed one, since picking a time is exactly how a user opts back in.
  Future<void> updateSlotStart(String id, DateTime slotStart) =>
      (update(todoItems)..where((t) => t.id.equals(id))).write(
        TodoItemsCompanion(
          slotStart: Value(slotStart),
          hasTime: const Value(true),
        ),
      );

  /// Clears the time-of-day, keeping the to-do on the same day but moving it
  /// into that day's "no time" group — and normalizes [TodoItems.slotStart]
  /// down to that day's midnight rather than leaving whatever clock time it
  /// had before. [watchBetween]'s ORDER BY sorts by `hasTime`, then
  /// `slotStart`, then `sortOrder`: without this, two no-time to-dos that
  /// happened to have different slotStart clock times (e.g. one cleared from
  /// 9am, one from 2pm) would keep those as an invisible sort key ahead of
  /// `sortOrder`, silently breaking manual drag reorder within that day's
  /// no-time bucket.
  Future<void> clearTime(String id) async {
    final existing = await findById(id);
    if (existing == null) return;
    final day = DateTime(
      existing.slotStart.year,
      existing.slotStart.month,
      existing.slotStart.day,
    );
    await (update(todoItems)..where((t) => t.id.equals(id))).write(
      TodoItemsCompanion(hasTime: const Value(false), slotStart: Value(day)),
    );
  }

  Future<void> deleteById(String id) =>
      (delete(todoItems)..where((t) => t.id.equals(id))).go();

  /// Occurrences of a recurring series starting at or after [fromSlot] — the
  /// to-do equivalent of `EventDao.seriesFrom`. Read before
  /// [deleteSeriesFrom] wipes them, so a bulk delete can still be undone.
  Future<List<TodoRow>> seriesFrom(String groupId, DateTime fromSlot) {
    return (select(todoItems)..where(
          (t) =>
              t.recurrenceGroupId.equals(groupId) &
              t.slotStart.isBiggerOrEqualValue(fromSlot),
        ))
        .get();
  }

  /// Deletes every occurrence in [groupId]'s series from [fromSlot] onward —
  /// the to-do equivalent of `EventDao.seriesFrom` deletion.
  Future<void> deleteSeriesFrom(String groupId, DateTime fromSlot) =>
      (delete(todoItems)..where(
            (t) =>
                t.recurrenceGroupId.equals(groupId) &
                t.slotStart.isBiggerOrEqualValue(fromSlot),
          ))
          .go();

  /// Case-insensitive substring search over title, most recent slot first —
  /// the to-do equivalent of `EventDao.search` (to-dos have no memo field).
  Future<List<TodoRow>> search(String query) {
    final pattern = '%$query%';
    return (select(todoItems)
          ..where((t) => t.title.like(pattern))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.slotStart, mode: OrderingMode.desc),
          ])
          ..limit(100))
        .get();
  }

  Future<void> setPriority(String id, int priority) =>
      (update(todoItems)..where((t) => t.id.equals(id))).write(
        TodoItemsCompanion(priority: Value(priority)),
      );

  Future<void> setTags(String id, String? tags) =>
      (update(todoItems)..where((t) => t.id.equals(id))).write(
        TodoItemsCompanion(tags: Value(tags)),
      );

  Future<void> setNotify(String id, bool notify) =>
      (update(todoItems)..where((t) => t.id.equals(id))).write(
        TodoItemsCompanion(notify: Value(notify)),
      );

  Future<void> setAdditionalReminders(String id, String? minutes) =>
      (update(todoItems)..where((t) => t.id.equals(id))).write(
        TodoItemsCompanion(additionalReminderMinutes: Value(minutes)),
      );

  Future<void> setSortOrder(String id, int sortOrder) =>
      (update(todoItems)..where((t) => t.id.equals(id))).write(
        TodoItemsCompanion(sortOrder: Value(sortOrder)),
      );

  Future<void> setPinned(String id, bool pinned) =>
      (update(todoItems)..where((t) => t.id.equals(id))).write(
        TodoItemsCompanion(isPinned: Value(pinned)),
      );

  /// Not-done pinned to-dos, soonest slot first — the smart list's "고정됨"
  /// tab.
  Stream<List<TodoRow>> watchPinned() {
    return (select(todoItems)
          ..where((t) => t.isPinned.equals(true) & t.isDone.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.slotStart)]))
        .watch();
  }

  /// Completed to-dos whose [TodoItems.completedAt] is older than [cutoff] —
  /// the settings > "완료된 할 일 자동 정리" auto-prune candidates (see
  /// `TodoController.pruneCompleted`).
  Future<List<TodoRow>> completedBefore(DateTime cutoff) {
    return (select(todoItems)..where(
          (t) =>
              t.isDone.equals(true) & t.completedAt.isSmallerThanValue(cutoff),
        ))
        .get();
  }

  /// A to-do's checklist, in manual sort order — the detail sheet's source
  /// of truth, live-updating as items are added/toggled/removed elsewhere.
  Stream<List<TodoSubtaskRow>> watchSubtasks(String todoId) {
    return (select(todoSubtasks)
          ..where((s) => s.todoId.equals(todoId))
          ..orderBy([(s) => OrderingTerm(expression: s.sortOrder)]))
        .watch();
  }

  /// Every subtask across every to-do, for a full-database export/import —
  /// the to-do equivalent of `EventDao.all`.
  Future<List<TodoSubtaskRow>> allSubtasks() => select(todoSubtasks).get();

  Future<void> upsertSubtask(TodoSubtasksCompanion companion) =>
      into(todoSubtasks).insertOnConflictUpdate(companion);

  Future<void> setSubtaskDone(String id, bool done) =>
      (update(todoSubtasks)..where((s) => s.id.equals(id))).write(
        TodoSubtasksCompanion(isDone: Value(done)),
      );

  Future<void> deleteSubtask(String id) =>
      (delete(todoSubtasks)..where((s) => s.id.equals(id))).go();

  /// Not-done, timed to-dos whose slot has already passed [asOf] — the
  /// "overdue" smart list, and the day/home screens' overdue highlight. Not
  /// re-evaluated as time itself passes (only when something in the DB
  /// changes, like any watch query) — same accepted staleness as the rest
  /// of the app's "as of last write" reactivity, not worth a ticking timer.
  Stream<List<TodoRow>> watchOverdue(DateTime asOf) {
    return (select(todoItems)
          ..where(
            (t) =>
                t.hasTime.equals(true) &
                t.isDone.equals(false) &
                t.slotStart.isSmallerThanValue(asOf),
          )
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.slotStart, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Not-done to-dos at or above [minPriority] (see `TodoPriority`), soonest
  /// first — the "high priority" smart list.
  Stream<List<TodoRow>> watchByMinPriority(int minPriority) {
    return (select(todoItems)
          ..where(
            (t) =>
                t.priority.isBiggerOrEqualValue(minPriority) &
                t.isDone.equals(false),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.slotStart)]))
        .watch();
  }

  /// Every distinct tag currently in use across every to-do, alphabetical —
  /// the smart list's "by tag" picker source. A plain [Future]: tags don't
  /// change often enough to warrant a live stream here, unlike the
  /// per-to-do [watchByTag] results themselves.
  Future<List<String>> allTags() async {
    final rows = await (select(
      todoItems,
    )..where((t) => t.tags.isNotNull())).get();
    final tags = <String>{};
    for (final row in rows) {
      for (final tag in (row.tags ?? '').split(',')) {
        final trimmed = tag.trim();
        if (trimmed.isNotEmpty) tags.add(trimmed);
      }
    }
    final sorted = tags.toList()..sort();
    return sorted;
  }

  /// Not-done to-dos carrying exactly [tag] among their comma-separated
  /// [TodoItems.tags], soonest first. Filtered in Dart rather than a SQL
  /// `LIKE` — matching a whole comma-delimited segment (not a substring, so
  /// tag "업무" doesn't also match a to-do tagged "영업무") is simpler to get
  /// right this way, and to-do counts here are small enough that it's cheap.
  Stream<List<TodoRow>> watchByTag(String tag) {
    return (select(todoItems)
          ..where((t) => t.tags.isNotNull() & t.isDone.equals(false)))
        .watch()
        .map((rows) {
          final matches = rows.where((r) => todoHasTag(r, tag)).toList();
          matches.sort((a, b) => a.slotStart.compareTo(b.slotStart));
          return matches;
        });
  }
}
