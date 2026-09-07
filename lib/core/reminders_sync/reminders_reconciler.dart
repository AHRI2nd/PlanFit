import 'package:drift/drift.dart';

import '../../features/schedule/domain/ports.dart';
import '../../features/todo/domain/todo_notification_sync.dart';
import '../db/app_database.dart';
import '../db/daos/sync_log_dao.dart';
import '../db/daos/todo_dao.dart';
import '../db/sync_status.dart';
import 'reminders_service.dart';

/// Reconciles PlanFit's to-dos with the OS reminders list (iOS only) on app
/// foreground — the to-do equivalent of `CalendarReconciler`.
///
/// Unlike events, a to-do's local write paths ([TodoController]) push to
/// Reminders immediately on every relevant edit rather than waiting for the
/// next reconcile (see `TodoController._syncReminder`). That means a
/// `synced` row landing here with values that disagree with EventKit is
/// always a genuine edit made in the Reminders app, never a race with a
/// pending local write — so this skips `CalendarReconciler`'s
/// locally-edited-since-last-sync conflict check entirely and always treats
/// a mismatch as "pulled" (last-write-wins toward Reminders). Simpler, and
/// correct given the different write strategy.
///
/// At reconciliation time:
///   * a synced row whose OS reminder is **gone** → deleted in Reminders.
///   * a synced row whose OS values **differ** → edited in Reminders; pull
///     those values back.
/// It also (re)pushes anything still [SyncStatus.pendingPush] (e.g.
/// created/edited while sync was off).
///
/// The pull/delete step only ever runs against a *confirmed* read of the
/// Reminders list — [RemindersService.fetchReminders] returning `null`
/// (Reminders access revoked, or the list itself deleted) skips it entirely
/// rather than treating an unconfirmed result as "the list is genuinely
/// empty, delete everything that isn't in it".
///
/// Every branch is idempotent, so running it repeatedly is safe.
class RemindersReconciler {
  RemindersReconciler({
    required this._service,
    required this._todoDao,
    required this._syncLogDao,
    required this._notifications,
  });

  final RemindersService _service;
  final TodoDao _todoDao;
  final SyncLogDao _syncLogDao;
  final NotificationPort _notifications;

  /// Same overlapping-`resumed`-events guard as `CalendarReconciler._reconciling`
  /// — see that field's doc for why.
  bool _reconciling = false;

  Future<int> reconcile({DateTime? now}) async {
    if (_reconciling) return 0;
    _reconciling = true;
    try {
      return await _reconcile(now);
    } finally {
      _reconciling = false;
    }
  }

  Future<int> _reconcile(DateTime? now) async {
    if (!_service.isEnabled) return 0;
    final at = now ?? DateTime.now();
    var changes = 0;

    // 1) Push anything still waiting (created/edited while sync was off, or
    //    a failed earlier push).
    for (final row in await _todoDao.needingReminderPush()) {
      final osId = await _service.pushTodo(row);
      if (osId != null) {
        await _todoDao.patch(
          row.id,
          TodoItemsCompanion(
            osReminderId: Value(osId),
            osReminderListId: Value(_service.targetListId),
            osReminderLastKnownModified: Value(at),
            reminderSyncStatus: const Value(SyncStatus.synced),
          ),
        );
        changes++;
      }
    }

    // 2) Pull edits/deletes made in the Reminders app for to-dos we own.
    //
    // `null` (as opposed to an empty list) means the list's real contents
    // couldn't be confirmed — Reminders access revoked, or the list itself
    // deleted from the Reminders app (see fetchReminders' own doc; EventKit
    // doesn't distinguish the two). Skipping this whole step in that case is
    // deliberate: treating an *unconfirmed* empty result as ground truth
    // used to delete every synced to-do the moment permission was revoked,
    // even though none of the underlying reminders had actually gone
    // anywhere. Nothing here is lost by skipping — a genuine deletion made
    // in the Reminders app while access is (or later becomes) unavailable
    // simply gets picked up on the next reconcile that can actually see the
    // list again.
    final remoteReminders = await _service.fetchReminders();
    if (remoteReminders == null) return changes;
    final remoteById = {for (final r in remoteReminders) r.osReminderId: r};

    for (final row in await _todoDao.linkedToReminders()) {
      final osId = row.osReminderId;
      if (osId == null || row.reminderSyncStatus != SyncStatus.synced) {
        continue;
      }

      final remote = remoteById[osId];
      if (remote == null) {
        await _notifications.cancelForTodo(row.id);
        await _todoDao.deleteById(row.id);
        await _log(row.title, SyncResolution.deletedRemotely, '미리알림 앱에서 삭제됨');
        changes++;
        continue;
      }

      if (!_matches(row, remote)) {
        await _todoDao.patch(row.id, _pullCompanion(row, remote, at));
        final updated = await _todoDao.findById(row.id);
        if (updated != null) {
          await syncTodoNotification(_notifications, updated);
        }
        await _log(remote.title, SyncResolution.pulled, '미리알림 앱에서 업데이트됨');
        changes++;
      }
    }

    return changes;
  }

  /// Whether the stored row already agrees with the OS reminder on the
  /// fields we sync. Due dates are compared to the minute to tolerate
  /// sub-minute rounding in the platform layer.
  bool _matches(TodoRow row, OsReminder r) {
    return row.title == r.title &&
        row.isDone == r.isCompleted &&
        _sameDueDate(row.hasTime ? row.slotStart : null, r.dueDate);
  }

  bool _sameDueDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.difference(b).inMinutes.abs() < 1;
  }

  TodoItemsCompanion _pullCompanion(TodoRow row, OsReminder r, DateTime at) {
    // A reminder with no due date (created bare in the Reminders app, or
    // its date cleared there) moves the to-do into its existing day's
    // "no time" bucket rather than losing which day it belongs to — same
    // normalize-to-midnight treatment as `TodoDao.clearTime`, so the
    // no-time bucket's manual drag reorder isn't silently broken by a
    // leftover time-of-day on `slotStart` (see that method's doc).
    final slotStart =
        r.dueDate ??
        DateTime(row.slotStart.year, row.slotStart.month, row.slotStart.day);
    return TodoItemsCompanion(
      title: Value(r.title),
      isDone: Value(r.isCompleted),
      completedAt: Value(r.isCompleted ? at : null),
      hasTime: Value(r.dueDate != null),
      slotStart: Value(slotStart),
      osReminderLastKnownModified: Value(at),
      reminderSyncStatus: const Value(SyncStatus.synced),
    );
  }

  Future<void> _log(String? title, SyncResolution resolution, String detail) {
    return _syncLogDao.add(
      SyncLogsCompanion(
        eventTitle: Value(title),
        resolution: Value(resolution),
        detail: Value(detail),
      ),
    );
  }
}
