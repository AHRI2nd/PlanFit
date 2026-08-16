import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import '../db/app_database.dart';
import '../../features/schedule/domain/ports.dart';

/// Wraps the hand-written iOS EventKit reminders channel (see
/// ios/Runner/RemindersPlugin.swift — no existing Flutter plugin talks to
/// EKReminder; `device_calendar_plus` only covers EKEvent) and implements
/// the [RemindersPort] the to-do controller drives. iOS-only by
/// construction: every method is a harmless no-op on Android/web, since
/// there's no OS reminders concept to sync with there.
class RemindersService implements RemindersPort {
  RemindersService({this.enabled = false, this.targetListId});

  static const _channel = MethodChannel('com.arisair.planfit/reminders');

  static bool get _supported => !kIsWeb && Platform.isIOS;

  /// Whether to-do/reminders sync is on. Flipped from settings.
  bool enabled;

  /// The reminders list to-dos are written to; resolved lazily if unset.
  String? targetListId;

  @override
  bool get isEnabled => enabled && _supported;

  Future<bool> requestAccess() async {
    if (!_supported) return false;
    final granted = await _channel.invokeMethod<bool>('requestAccess');
    return granted ?? false;
  }

  Future<String?>? _resolving;

  /// Resolves where PlanFit writes to-dos — same single-flight-guarded
  /// find-or-create semantics as `CalendarService.resolveTargetCalendarId`
  /// (a dedicated "PlanFit" reminders list, reused across reinstalls since
  /// it lives in EventKit outside the app's own storage, created at most
  /// once even under concurrent callers).
  Future<String?> resolveTargetListId() {
    if (targetListId != null) return Future.value(targetListId);
    if (!_supported) return Future.value(null);
    return _resolving ??= _channel
        .invokeMethod<String>('resolveTargetListId')
        .then((id) {
          targetListId = id;
          return id;
        })
        .whenComplete(() => _resolving = null);
  }

  // --- RemindersPort ---

  @override
  Future<String?> pushTodo(TodoRow todo) async {
    if (!_supported) return null;
    final listId = await resolveTargetListId();
    if (listId == null) return null;
    return _channel.invokeMethod<String>('pushTodo', {
      'listId': listId,
      'osReminderId': todo.osReminderId,
      'title': todo.title,
      'isCompleted': todo.isDone,
      'dueDateMillis': todo.hasTime
          ? todo.slotStart.millisecondsSinceEpoch
          : null,
    });
  }

  @override
  Future<void> deleteTodo(TodoRow todo) async {
    if (!_supported) return;
    final osId = todo.osReminderId;
    if (osId == null) return;
    await _channel.invokeMethod('deleteTodo', {'osReminderId': osId});
  }

  /// Reads every reminder currently in PlanFit's list back — used by
  /// [RemindersReconciler] to detect edits/deletions made in the Reminders
  /// app.
  Future<List<OsReminder>> fetchReminders() async {
    if (!_supported) return const [];
    final listId = await resolveTargetListId();
    if (listId == null) return const [];
    final raw = await _channel.invokeMethod<List<Object?>>('fetchReminders', {
      'listId': listId,
    });
    if (raw == null) return const [];
    return raw.cast<Map<Object?, Object?>>().map(OsReminder._fromMap).toList();
  }
}

/// One reminder read back from EventKit — see
/// `RemindersPlugin.swift`'s `fetchReminders`.
class OsReminder {
  const OsReminder({
    required this.osReminderId,
    required this.title,
    required this.isCompleted,
    this.dueDate,
  });

  final String osReminderId;
  final String title;
  final bool isCompleted;

  /// Null when the reminder has no due date set (EventKit allows a bare
  /// checklist item with no date) — maps to a to-do with [TodoRow.hasTime]
  /// false.
  final DateTime? dueDate;

  static OsReminder _fromMap(Map<Object?, Object?> m) {
    DateTime? millisToDate(Object? v) =>
        v == null ? null : DateTime.fromMillisecondsSinceEpoch(v as int);
    return OsReminder(
      osReminderId: m['osReminderId'] as String,
      title: m['title'] as String? ?? '',
      isCompleted: m['isCompleted'] as bool? ?? false,
      dueDate: millisToDate(m['dueDateMillis']),
    );
  }
}
