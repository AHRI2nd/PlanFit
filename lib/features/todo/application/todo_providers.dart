import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/date_math.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/sync_status.dart';
import '../../../core/di.dart';
import '../../../core/notifications/notification_window.dart';
import '../../../core/riverpod_x.dart';
import '../../../core/serial_queue.dart';
import '../../schedule/application/schedule_providers.dart';
import '../../schedule/domain/recurrence.dart';
import '../domain/todo_notification_sync.dart';
import '../domain/todo_priority.dart';

/// To-dos whose slot falls on the given day, grouped-ready (already ordered by
/// slot then manual order by the DAO).
final todosForDayProvider = StreamProvider.autoDispose
    .family<List<TodoRow>, DateTime>((ref, day) {
      ref.keepAliveFor(kDataProviderCacheGrace);
      final start = dateOnly(day);
      final end = addCalendarDays(start, 1);
      return ref.watch(todoDaoProvider).watchBetween(start, end);
    });

/// To-dos in the week containing [anyDayInWeek] (per the week-start setting)
/// — the home screen's weekly stats card.
final todosForWeekProvider = StreamProvider.autoDispose
    .family<List<TodoRow>, DateTime>((ref, anyDayInWeek) {
      ref.keepAliveFor(kDataProviderCacheGrace);
      final start = startOfWeek(
        anyDayInWeek,
        startWeekday: ref.watch(weekStartWeekdayProvider),
      );
      final end = addCalendarDays(start, 7);
      return ref.watch(todoDaoProvider).watchBetween(start, end);
    });

/// To-dos in the month containing [monthAnchor] — used for the month grid's
/// day markers (see `calendar_dot.dart`). Mirrors `eventsForMonthProvider`'s
/// own window exactly, [monthAnchor] already normalized to (year, month)
/// by the caller included — see that provider's own doc for why.
final todosForMonthProvider = StreamProvider.autoDispose
    .family<List<TodoRow>, DateTime>((ref, monthAnchor) {
      ref.keepAliveFor(kDataProviderCacheGrace);
      final start = DateTime(monthAnchor.year, monthAnchor.month, 1);
      final end = DateTime(monthAnchor.year, monthAnchor.month + 1, 1);
      return ref.watch(todoDaoProvider).watchBetween(start, end);
    });

/// To-dos across the year of [year] — used for the year heat view's day
/// markers. Mirrors `eventsForYearProvider`'s own window exactly.
final todosForYearProvider = StreamProvider.autoDispose
    .family<List<TodoRow>, int>((ref, year) {
      ref.keepAliveFor(kDataProviderCacheGrace);
      final start = DateTime(year, 1, 1);
      final end = DateTime(year + 1, 1, 1);
      return ref.watch(todoDaoProvider).watchBetween(start, end);
    });

/// To-dos for the agenda view's merged, time-sorted list — mirrors
/// `eventsForAgendaProvider`'s own window (a week back, 180 days forward
/// from [anchor]) exactly, so both providers' streams cover the same days.
/// Deliberately unfiltered by [TodoRow.isDone] (unlike the dot-marker
/// providers above, which filter at their call site) — the agenda list
/// still shows a completed to-do, struck through, rather than making it
/// vanish.
final todosForAgendaProvider = StreamProvider.autoDispose
    .family<List<TodoRow>, DateTime>((ref, anchor) {
      ref.keepAliveFor(kDataProviderCacheGrace);
      final start = addCalendarDays(dateOnly(anchor), -7);
      final end = addCalendarDays(dateOnly(anchor), 180);
      return ref.watch(todoDaoProvider).watchBetween(start, end);
    });

/// A to-do's checklist — the detail sheet's live source, also used by
/// [HourlyTodoList] to show a "2/3" subtask-progress badge inline.
///
/// `.autoDispose`: [HourlyTodoList] and the smart-list screen watch this
/// once per *rendered row*, keyed by [todoId] — unlike the date-bucketed
/// providers below, there's no way to normalize that key down to a handful
/// of cache slots. Without `.autoDispose` every to-do ever scrolled past
/// this session would leave behind a permanently-open Drift `.watch()`
/// subscription (and, since Drift invalidates per-table rather than per-row,
/// a stray subtask edit anywhere would re-run every one of them) — plain
/// `.autoDispose` tears each down the moment its row scrolls off/its sheet
/// closes, which is the right trade here since a re-open just re-queries.
final todoSubtasksProvider = StreamProvider.autoDispose
    .family<List<TodoSubtaskRow>, String>((ref, todoId) {
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
final todosByTagProvider = StreamProvider.autoDispose
    .family<List<TodoRow>, String>((ref, tag) {
      ref.keepAliveFor(kDataProviderCacheGrace);
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

  /// Serializes [reorder] calls — see that method's own doc for why a bare
  /// fire-and-forget `onReorderItem` callback needs this.
  final _reorderQueue = SerialQueue();

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
    // No-time to-dos must all share the same slotStart clock time (midnight)
    // within a day — see TodoDao.clearTime's doc for why: watchBetween's
    // ORDER BY sorts by slotStart ahead of sortOrder, so leaving whatever
    // clock time the (unused) time picker happened to show would silently
    // break manual drag reorder for that day's no-time bucket.
    final effectiveSlotStart = hasTime ? slotStart : dateOnly(slotStart);
    if (frequency == RecurrenceFrequency.none) {
      final id = _uuid.v4();
      await dao.upsert(
        TodoItemsCompanion(
          id: Value(id),
          title: Value(title),
          slotStart: Value(effectiveSlotStart),
          hasTime: Value(hasTime),
          priority: Value(priority),
          tags: Value(tags),
          notify: Value(effectiveNotify),
        ),
      );
      if (effectiveNotify) await _syncNotification(id);
      await _syncReminder(id);
      if (tags != null && tags.isNotEmpty) _ref.invalidate(todoTagsProvider);
      return;
    }

    final groupId = _uuid.v4();
    final until =
        recurrenceUntil ??
        RecurrenceExpansion.defaultUntil(effectiveSlotStart, frequency);
    final occurrences = RecurrenceExpansion.occurrences(
      start: effectiveSlotStart,
      end: effectiveSlotStart,
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
    for (final id in ids) {
      await _syncReminder(id);
    }
    if (tags != null && tags.isNotEmpty) _ref.invalidate(todoTagsProvider);
  }

  Future<void> toggle(String id, bool done) async {
    await _ref.read(todoDaoProvider).setDone(id, done);
    await _syncNotification(id);
    await _syncReminder(id);
  }

  Future<void> updateTime(String id, DateTime slotStart) async {
    await _ref.read(todoDaoProvider).updateSlotStart(id, slotStart);
    await _syncNotification(id);
    await _syncReminder(id);
  }

  Future<void> clearTime(String id) async {
    await _ref.read(todoDaoProvider).clearTime(id);
    await _syncNotification(id);
    await _syncReminder(id);
  }

  Future<void> setPriority(String id, int priority) =>
      _ref.read(todoDaoProvider).setPriority(id, priority);

  Future<void> setTags(String id, String? tags) async {
    await _ref.read(todoDaoProvider).setTags(id, tags);
    // todoTagsProvider is a plain FutureProvider (see its own doc: tags
    // don't change often enough to warrant a live stream) — meaning it
    // otherwise computes once and never refreshes for the rest of the
    // session. Without this, a brand-new tag typed here never appeared in
    // the tag picker until the app was restarted, and a tag whose only
    // to-do stopped using it kept showing a chip that now always resolves
    // to an empty list.
    _ref.invalidate(todoTagsProvider);
  }

  Future<void> setNotify(String id, bool notify) async {
    await _ref.read(todoDaoProvider).setNotify(id, notify);
    await _syncNotification(id);
  }

  /// Persists a manual drag reorder within [current] (the exact list the UI
  /// was showing, in its pre-drag order) by rewriting [TodoItems.sortOrder]
  /// for every item to its new index. [oldIndex]/[newIndex] are
  /// `ReorderableListView.onReorderItem`'s callback values — unlike the
  /// older, now-deprecated `onReorder`, [newIndex] there is already the
  /// target index in the post-removal list, so a plain removeAt+insert is
  /// all that's needed.
  ///
  /// `onReorderItem`'s own signature is a bare, non-awaited
  /// `void Function(int, int)`, so nothing stops the UI from firing a
  /// second drag before this call's writes (several sequential `await`s)
  /// finish and the widget rebuilds with fresh data — each call's own
  /// [current] can be a snapshot from *before* an in-flight call's writes
  /// land. Two fixes work together to keep that race from corrupting
  /// [TodoItems.sortOrder]:
  ///
  /// 1. [_reorderQueue] serializes the write loops themselves, so two
  ///    overlapping calls' `setSortOrder` writes can never interleave
  ///    step-by-step — whichever call's loop starts second only starts once
  ///    the first's has *fully* finished, not concurrently with it.
  /// 2. Every item's `sortOrder` is written unconditionally, not only the
  ///    ones that differ from [TodoRow.sortOrder] in the (possibly stale)
  ///    [current] snapshot. Skipping "unchanged" items used to let an
  ///    already-stale call leave the *previous* call's leftover value in
  ///    place for an item its own comparison mistakenly thought needed no
  ///    write — even fully serialized, that stale skip alone was enough to
  ///    reproduce a genuine duplicate `sortOrder` between two items
  ///    (confirmed via a targeted test constructing exactly that
  ///    before/after pair). Writing every position every time means
  ///    whichever call runs last always leaves the full list in one
  ///    complete, internally consistent 0..n-1 assignment — never a mix of
  ///    two different calls' partial views.
  ///
  /// Deliberately scoped to a single [hasTime] bucket by the caller (see
  /// [HourlyTodoList]'s "no time" section): [TodoDao.watchBetween] sorts
  /// timed items by [TodoItems.slotStart] first, so reordering across that
  /// boundary would just be silently undone by the next rebuild — only the
  /// no-time bucket has no other sort key ahead of [TodoItems.sortOrder].
  Future<void> reorder(List<TodoRow> current, int oldIndex, int newIndex) =>
      _reorderQueue.run(() async {
        final items = List<TodoRow>.from(current);
        final moved = items.removeAt(oldIndex);
        items.insert(newIndex, moved);

        final dao = _ref.read(todoDaoProvider);
        for (var i = 0; i < items.length; i++) {
          await dao.setSortOrder(items[i].id, i);
        }
      });

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
    // `upsert` (insertOnConflictUpdate) validates its companion as if for a
    // fresh insert, so a title-only companion missing e.g. `slotStart`
    // throws `InvalidDataException` before ever reaching the database —
    // `patch` is the correct partial-update path (see TodoDao.patch, and
    // every sibling setter in this class: setTags/setPriority/etc.).
    await _ref
        .read(todoDaoProvider)
        .patch(id, TodoItemsCompanion(title: Value(title)));
    // Re-schedules with the new title if it was already scheduled — a
    // stale title in a pending notification would otherwise linger until
    // it fires.
    await _syncNotification(id);
    await _syncReminder(id);
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

  /// Pushes [id]'s current title/due date/done state to the OS reminders
  /// list when sync is on — the to-do equivalent of [_syncNotification],
  /// called from the same write paths. Best-effort and immediate (unlike
  /// events' calendar push, which the caller awaits inline too — see
  /// `EventRepositoryImpl._applySideEffects`): a failure here must not
  /// surface as a save failure, since the local write already succeeded and
  /// `RemindersReconciler` retries anything left `pendingPush` on the next
  /// foreground resume.
  ///
  /// `RemindersReconciler`'s own doc leans on an invariant this method must
  /// uphold: a `synced` row it later finds disagreeing with EventKit is
  /// always a genuine Reminders-app edit, never a race with a pending local
  /// write — because a local edit always either lands `synced` (this push
  /// succeeded) or gets put back to `pendingPush` (it didn't). Before this
  /// fix, a failed push on a row that was *already* `synced` (e.g. a second
  /// edit, with access revoked or the linked list deleted in between) left
  /// `reminderSyncStatus` untouched at its old `synced` value instead — not
  /// just stalling the retry forever, but making the next reconcile treat
  /// this edit as if it never happened: it would see the row "disagreeing"
  /// with the stale EventKit values and pull those old values back over the
  /// user's actual edit, silently discarding it.
  Future<void> _syncReminder(String id) async {
    final reminders = _ref.read(remindersPortProvider);
    if (!reminders.isEnabled) return;
    final dao = _ref.read(todoDaoProvider);
    final row = await dao.findById(id);
    if (row == null) return;
    // Only a row that was already `synced` needs an explicit revert below —
    // a fresh row (or one already `pendingPush` for some other reason)
    // starts there and a failed push simply leaves it as-is.
    final wasSynced = row.reminderSyncStatus == SyncStatus.synced;
    try {
      final osId = await reminders.pushTodo(row);
      if (osId != null) {
        await dao.patch(
          id,
          TodoItemsCompanion(
            osReminderId: Value(osId),
            reminderSyncStatus: const Value(SyncStatus.synced),
          ),
        );
      } else if (wasSynced) {
        await dao.patch(
          id,
          const TodoItemsCompanion(
            reminderSyncStatus: Value(SyncStatus.pendingPush),
          ),
        );
      }
    } on Exception {
      if (wasSynced) {
        await dao.patch(
          id,
          const TodoItemsCompanion(
            reminderSyncStatus: Value(SyncStatus.pendingPush),
          ),
        );
      }
      // Else: already pendingPush (e.g. a fresh row's first push failing) —
      // nothing to revert, the reconciler will retry it either way.
    }
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
  ///
  /// [candidates] is a single DB snapshot taken once, up front — but this
  /// loop then `await`s one real platform-channel call per candidate, and a
  /// concurrent edit (marking one done, turning its `notify` off, deleting
  /// it) landing while an *earlier* candidate's own call is still in flight
  /// used to be invisible to the rest of this loop: it kept using its
  /// stale, pre-edit copy of that row for the rest of the pass, silently
  /// re-arming/resurrecting a reminder the concurrent edit had just
  /// cancelled. Re-fetching each row's live state immediately before
  /// actually scheduling it — as late as possible before the call that
  /// matters — closes that window; unlike `NotificationService.refillEvents`
  /// (which has no DAO of its own to re-check against), this controller
  /// already sits right next to one.
  Future<void> refillNotifications() async {
    final dao = _ref.read(todoDaoProvider);
    final notifications = _ref.read(notificationPortProvider);
    final now = DateTime.now();
    final windowEnd = now.add(notificationSchedulingWindow);
    final candidates = await dao.between(now, windowEnd.add(_maxLeadTime));
    for (final row in candidates) {
      if (!row.notify || !row.hasTime || row.isDone) continue;
      final live = await dao.findById(row.id);
      if (live == null || !live.notify || !live.hasTime || live.isDone) {
        continue;
      }
      await notifications.scheduleForTodo(live);
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
    final reminders = _ref.read(remindersPortProvider);
    var anyTagged = false;
    for (final row in stale) {
      await dao.deleteById(row.id);
      await notifications.cancelForTodo(row.id);
      try {
        await reminders.deleteTodo(row);
      } on Exception {
        // Best-effort, same reasoning as _removeWithSubtasks.
      }
      if ((row.tags ?? '').isNotEmpty) anyTagged = true;
    }
    // See setTags' own doc on todoTagsProvider.
    if (anyTagged) _ref.invalidate(todoTagsProvider);
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
    // Best-effort, same reasoning as EventRepository.delete()'s calendar
    // delete: the local delete already succeeded, so a Reminders-side
    // failure must not surface as a delete failure.
    try {
      await _ref.read(remindersPortProvider).deleteTodo(row);
    } on Exception {
      // Nothing to reconcile after this — the row is gone either way.
    }
    // See setTags' own doc on todoTagsProvider — a deleted to-do can have
    // been the last one using a given tag, which should stop showing up
    // as a (now permanently empty) chip in the picker.
    if ((row.tags ?? '').isNotEmpty) _ref.invalidate(todoTagsProvider);
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
    // Not carried over from `todo` — same reasoning as
    // `EventRepository.restoreEvent`'s OS-calendar linkage: the old
    // `osReminderId` is already gone (deleted alongside the row — see
    // `_removeWithSubtasks`), so this pushes a fresh reminder rather than
    // risk patching a stale/wrong one. `upsert` above already omits
    // `osReminderId`/`reminderSyncStatus`, so the fresh row lands with the
    // table defaults (null / pendingPush) exactly as if newly created.
    await _syncReminder(todo.id);
    // See setTags' own doc on todoTagsProvider — undoing a delete can bring
    // a tag's only remaining to-do back.
    if ((todo.tags ?? '').isNotEmpty) _ref.invalidate(todoTagsProvider);
  }
}

final todoControllerProvider = Provider<TodoController>(TodoController.new);
