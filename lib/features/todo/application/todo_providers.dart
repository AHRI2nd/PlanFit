import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../../core/di.dart';
import '../../../core/notifications/notification_window.dart';
import '../../schedule/application/schedule_providers.dart';
import '../../schedule/domain/recurrence.dart';
import '../domain/todo_notification_sync.dart';
import '../domain/todo_priority.dart';

/// To-dos whose slot falls on the given day, grouped-ready (already ordered by
/// slot then manual order by the DAO).
final todosForDayProvider = StreamProvider.family<List<TodoRow>, DateTime>((
  ref,
  day,
) {
  final start = dateOnly(day);
  final end = start.add(const Duration(days: 1));
  return ref.watch(todoDaoProvider).watchBetween(start, end);
});

/// To-dos in the week containing [anyDayInWeek] (per the week-start setting)
/// — the home screen's weekly stats card.
final todosForWeekProvider = StreamProvider.family<List<TodoRow>, DateTime>((
  ref,
  anyDayInWeek,
) {
  final start = startOfWeek(
    anyDayInWeek,
    startWeekday: ref.watch(weekStartWeekdayProvider),
  );
  final end = start.add(const Duration(days: 7));
  return ref.watch(todoDaoProvider).watchBetween(start, end);
});

/// A to-do's checklist — the detail sheet's live source, also used by
/// [HourlyTodoList] to show a "2/3" subtask-progress badge inline.
final todoSubtasksProvider =
    StreamProvider.family<List<TodoSubtaskRow>, String>((ref, todoId) {
      return ref.watch(todoDaoProvider).watchSubtasks(todoId);
    });

/// The smart list screen's "기한 지남" (overdue) tab.
final overdueTodosProvider = StreamProvider<List<TodoRow>>((ref) {
  return ref.watch(todoDaoProvider).watchOverdue(DateTime.now());
});

/// The smart list screen's "우선순위 높음" (high priority) tab.
final highPriorityTodosProvider = StreamProvider<List<TodoRow>>((ref) {
  return ref.watch(todoDaoProvider).watchByMinPriority(TodoPriority.high.value);
});

/// The smart list screen's "고정됨" (pinned) tab.
final pinnedTodosProvider = StreamProvider<List<TodoRow>>((ref) {
  return ref.watch(todoDaoProvider).watchPinned();
});

/// The smart list screen's tag picker source.
final todoTagsProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(todoDaoProvider).allTags();
});

/// The smart list screen's "태그별" (by tag) tab, once a tag is picked.
final todosByTagProvider = StreamProvider.family<List<TodoRow>, String>((
  ref,
  tag,
) {
  return ref.watch(todoDaoProvider).watchByTag(tag);
});

/// A removed to-do bundled with its checklist. [TodoSubtasks.todoId] cascades
/// on delete (see tables.dart), so a plain delete silently takes the
/// subtasks with it — undo needs them captured *before* that delete so
/// [TodoController.restore] can bring both back, not just the bare row
/// (the to-do equivalent of the data-loss bug #37 fixed for events).
typedef RemovedTodo = ({TodoRow todo, List<TodoSubtaskRow> subtasks});

/// Thin write-side controller for to-dos. Kept separate from events because a
/// to-do is a lightweight checkbox, not something that syncs to the OS calendar.
class TodoController {
  TodoController(this._ref);
  final Ref _ref;

  static const _uuid = Uuid();

  /// Adds a to-do. When [frequency] isn't `none`, materializes one row per
  /// occurrence (capped at [RecurrenceExpansion.maxOccurrences]) sharing a
  /// `recurrenceGroupId` — the same pre-generated-rows approach events use,
  /// rather than expanding an RRULE at query time.
  Future<void> add({
    required String title,
    required DateTime slotStart,
    bool hasTime = true,
    RecurrenceFrequency frequency = RecurrenceFrequency.none,
    DateTime? recurrenceUntil,
    int priority = 0,
    String? tags,
    // Defaults to "on" exactly when there's an actual moment to fire at —
    // picking a time is treated as opting into a reminder for it, the same
    // way TodoDao.updateSlotStart's own doc frames "picking a time" as an
    // opt-in signal. Explicit false (e.g. a quick-add without any UI
    // control shown yet) always wins.
    bool? notify,
  }) async {
    final dao = _ref.read(todoDaoProvider);
    final effectiveNotify = notify ?? hasTime;
    if (frequency == RecurrenceFrequency.none) {
      final id = _uuid.v4();
      await dao.upsert(
        TodoItemsCompanion(
          id: Value(id),
          title: Value(title),
          slotStart: Value(slotStart),
          hasTime: Value(hasTime),
          priority: Value(priority),
          tags: Value(tags),
          notify: Value(effectiveNotify),
        ),
      );
      if (effectiveNotify) await _syncNotification(id);
      return;
    }

    final groupId = _uuid.v4();
    final until = recurrenceUntil ?? slotStart.add(const Duration(days: 365));
    final occurrences = RecurrenceExpansion.occurrences(
      start: slotStart,
      end: slotStart,
      frequency: frequency,
      until: until,
    );
    final rule = RecurrenceExpansion.toRruleString(frequency, until: until);
    final ids = <String>[];
    // Same all-or-nothing guarantee as the event repository's recurring
    // save: a mid-loop failure shouldn't leave a partially materialized
    // series of to-dos behind.
    await dao.transaction(() async {
      for (final occ in occurrences) {
        final id = _uuid.v4();
        ids.add(id);
        await dao.upsert(
          TodoItemsCompanion(
            id: Value(id),
            title: Value(title),
            slotStart: Value(occ.$1),
            hasTime: Value(hasTime),
            priority: Value(priority),
            tags: Value(tags),
            notify: Value(effectiveNotify),
            recurrenceRule: Value(rule),
            recurrenceGroupId: Value(groupId),
          ),
        );
      }
    });
    // Only the near-term ones actually get scheduled — same
    // notificationSchedulingWindow reasoning as events, so a long recurring
    // series can't blow through iOS's ~64 pending-notification cap (see
    // refillNotifications for how the rest catch up later).
    if (effectiveNotify) {
      for (final id in ids) {
        await _syncNotification(id);
      }
    }
  }

  Future<void> toggle(String id, bool done) async {
    await _ref.read(todoDaoProvider).setDone(id, done);
    await _syncNotification(id);
  }

  Future<void> updateTime(String id, DateTime slotStart) async {
    await _ref.read(todoDaoProvider).updateSlotStart(id, slotStart);
    await _syncNotification(id);
  }

  Future<void> clearTime(String id) async {
    await _ref.read(todoDaoProvider).clearTime(id);
    await _syncNotification(id);
  }

  Future<void> setPriority(String id, int priority) =>
      _ref.read(todoDaoProvider).setPriority(id, priority);

  Future<void> setTags(String id, String? tags) =>
      _ref.read(todoDaoProvider).setTags(id, tags);

  Future<void> setNotify(String id, bool notify) async {
    await _ref.read(todoDaoProvider).setNotify(id, notify);
    await _syncNotification(id);
  }

  /// Persists a manual drag reorder within [current] (the exact list the UI
  /// was showing, in its pre-drag order) by rewriting [TodoItems.sortOrder]
  /// for every item whose position actually changed. [oldIndex]/[newIndex]
  /// are `ReorderableListView.onReorderItem`'s callback values — unlike the
  /// older, now-deprecated `onReorder`, [newIndex] there is already the
  /// target index in the post-removal list, so a plain removeAt+insert is
  /// all that's needed.
  ///
  /// Deliberately scoped to a single [hasTime] bucket by the caller (see
  /// [HourlyTodoList]'s "no time" section): [TodoDao.watchBetween] sorts
  /// timed items by [TodoItems.slotStart] first, so reordering across that
  /// boundary would just be silently undone by the next rebuild — only the
  /// no-time bucket has no other sort key ahead of [TodoItems.sortOrder].
  Future<void> reorder(
    List<TodoRow> current,
    int oldIndex,
    int newIndex,
  ) async {
    final items = List<TodoRow>.from(current);
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);

    final dao = _ref.read(todoDaoProvider);
    for (var i = 0; i < items.length; i++) {
      if (items[i].sortOrder != i) {
        await dao.setSortOrder(items[i].id, i);
      }
    }
  }

  Future<void> setPinned(String id, bool pinned) =>
      _ref.read(todoDaoProvider).setPinned(id, pinned);

  Future<void> setAdditionalReminders(String id, Set<int> minutes) async {
    final joined = minutes.isEmpty
        ? null
        : (minutes.toList()..sort()).join(',');
    await _ref.read(todoDaoProvider).setAdditionalReminders(id, joined);
    await _syncNotification(id);
  }

  Future<void> updateTitle(String id, String title) async {
    await _ref
        .read(todoDaoProvider)
        .upsert(TodoItemsCompanion(id: Value(id), title: Value(title)));
    // Re-schedules with the new title if it was already scheduled — a
    // stale title in a pending notification would otherwise linger until
    // it fires.
    await _syncNotification(id);
  }

  /// Schedules or cancels [id]'s due-time alert based on its current
  /// `notify`/`hasTime`/`isDone` — `NotificationService.scheduleForTodo`
  /// itself judges whether `slotStart` is still in the future and inside
  /// `notificationSchedulingWindow`.
  Future<void> _syncNotification(String id) async {
    final row = await _ref.read(todoDaoProvider).findById(id);
    if (row == null) return;
    await syncTodoNotification(_ref.read(notificationPortProvider), row);
  }

  /// Widest possible reminder lead time (see
  /// `NotificationService.reminderOffsetOptions`) — added to the query
  /// window below so a to-do whose *slot* sits just past
  /// [notificationSchedulingWindow], but whose earliest reminder (slot minus
  /// lead time) actually falls inside it, still gets picked up. Mirrors
  /// `CalendarReconciler._maxLeadTime`.
  static const _maxLeadTime = Duration(days: 1);

  /// (Re)schedules due-time alerts for to-dos whose slot has rolled inside
  /// [notificationSchedulingWindow] since they were last synced — the to-do
  /// equivalent of `CalendarReconciler`'s event-notification refill.
  /// `scheduleForTodo` itself judges each of a to-do's reminder offsets on
  /// its own, so this just needs to give it a chance to run again for
  /// anything nearby. Safe to call on every foreground resume: scheduling an
  /// already-scheduled id is a harmless no-op.
  Future<void> refillNotifications() async {
    final dao = _ref.read(todoDaoProvider);
    final notifications = _ref.read(notificationPortProvider);
    final now = DateTime.now();
    final windowEnd = now.add(notificationSchedulingWindow);
    final candidates = await dao.between(now, windowEnd.add(_maxLeadTime));
    for (final row in candidates) {
      if (!row.notify || !row.hasTime || row.isDone) continue;
      await notifications.scheduleForTodo(row);
    }
  }

  /// Permanently deletes completed to-dos whose [TodoRow.completedAt] is
  /// older than [retention] — the settings > "완료된 할 일 자동 정리"
  /// background sweep (see app.dart's foreground-resume hook). Off by
  /// default (a null retention in settings never calls this at all); once
  /// on, this is a genuine hard delete with no undo, unlike every other
  /// removal path in this file — an automatic background sweep has no
  /// gesture to hang a SnackBar's undo action off of, so it only ever
  /// touches to-dos the user has *already* checked off and left alone for
  /// the whole configured window. Subtasks cascade via the FK (see
  /// tables.dart). Returns how many were removed, for tests.
  Future<int> pruneCompleted(Duration retention) async {
    final dao = _ref.read(todoDaoProvider);
    final cutoff = DateTime.now().subtract(retention);
    final stale = await dao.completedBefore(cutoff);
    final notifications = _ref.read(notificationPortProvider);
    for (final row in stale) {
      await dao.deleteById(row.id);
      await notifications.cancelForTodo(row.id);
    }
    return stale.length;
  }

  Future<void> addSubtask(String todoId, String title) => _ref
      .read(todoDaoProvider)
      .upsertSubtask(
        TodoSubtasksCompanion(
          id: Value(_uuid.v4()),
          todoId: Value(todoId),
          title: Value(title),
        ),
      );

  Future<void> toggleSubtask(String id, bool done) =>
      _ref.read(todoDaoProvider).setSubtaskDone(id, done);

  Future<void> removeSubtask(String id) =>
      _ref.read(todoDaoProvider).deleteSubtask(id);

  Future<RemovedTodo> _removeWithSubtasks(TodoRow row) async {
    final dao = _ref.read(todoDaoProvider);
    final subtasks = await dao.watchSubtasks(row.id).first;
    await dao.deleteById(row.id);
    await _ref.read(notificationPortProvider).cancelForTodo(row.id);
    return (todo: row, subtasks: subtasks);
  }

  /// Deletes [id] (re-reading it first so the captured snapshot — and its
  /// subtasks, see [RemovedTodo] — reflects what's actually in the DB, not
  /// whatever possibly-stale row the caller has in hand). Returns what was
  /// removed so the caller can offer an undo via [restore].
  Future<List<RemovedTodo>> remove(String id) async {
    final dao = _ref.read(todoDaoProvider);
    final row = await dao.findById(id);
    if (row == null) return const [];
    return [await _removeWithSubtasks(row)];
  }

  /// Deletes just [todo], or — for a to-do that's part of a recurring series
  /// — every occurrence in that series from [todo]'s own slot onward.
  /// Returns every row (with its subtasks) actually removed, so the caller
  /// can offer an undo that restores all of them (see [restore]) rather than
  /// just the one tapped.
  Future<List<RemovedTodo>> removeSeriesFrom(TodoRow todo) async {
    final groupId = todo.recurrenceGroupId;
    if (groupId == null) {
      return remove(todo.id);
    }
    final dao = _ref.read(todoDaoProvider);
    final rows = await dao.seriesFrom(groupId, todo.slotStart);
    final bundles = <RemovedTodo>[];
    for (final row in rows) {
      bundles.add(await _removeWithSubtasks(row));
    }
    return bundles;
  }

  /// Re-inserts [removed]'s to-do and every one of its subtasks exactly as
  /// they were — the undo counterpart to [remove]/[removeSeriesFrom],
  /// mirroring `EventRepository.restoreEvent`.
  Future<void> restore(RemovedTodo removed) async {
    final dao = _ref.read(todoDaoProvider);
    final todo = removed.todo;
    await dao.upsert(
      TodoItemsCompanion(
        id: Value(todo.id),
        eventId: Value(todo.eventId),
        title: Value(todo.title),
        slotStart: Value(todo.slotStart),
        slotEnd: Value(todo.slotEnd),
        hasTime: Value(todo.hasTime),
        isDone: Value(todo.isDone),
        completedAt: Value(todo.completedAt),
        isPinned: Value(todo.isPinned),
        sortOrder: Value(todo.sortOrder),
        priority: Value(todo.priority),
        tags: Value(todo.tags),
        notify: Value(todo.notify),
        additionalReminderMinutes: Value(todo.additionalReminderMinutes),
        recurrenceRule: Value(todo.recurrenceRule),
        recurrenceGroupId: Value(todo.recurrenceGroupId),
        createdAt: Value(todo.createdAt),
      ),
    );
    for (final s in removed.subtasks) {
      await dao.upsertSubtask(
        TodoSubtasksCompanion(
          id: Value(s.id),
          todoId: Value(s.todoId),
          title: Value(s.title),
          isDone: Value(s.isDone),
          sortOrder: Value(s.sortOrder),
          createdAt: Value(s.createdAt),
        ),
      );
    }
    await _syncNotification(todo.id);
  }
}

final todoControllerProvider = Provider<TodoController>(TodoController.new);
