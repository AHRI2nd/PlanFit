import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:path_provider/path_provider.dart';

import '../db/app_database.dart';
import '../db/daos/todo_dao.dart';
import '../db/sync_status.dart';
import '../../features/schedule/domain/event_repository.dart';
import '../../features/schedule/domain/ports.dart';
import '../../features/todo/domain/todo_notification_sync.dart';

/// What an import found and did — surfaced to the user so a restore never
/// feels like it silently did (or didn't do) something.
class BackupImportSummary {
  const BackupImportSummary({
    required this.eventCount,
    required this.todoCount,
  });
  final int eventCount;
  final int todoCount;
}

/// Exports/imports the full local database (events + to-dos) as a single
/// JSON file — the only way a user can move their schedule to a new device or
/// recover it after losing this one, since PlanFit is otherwise fully local.
///
/// OS-calendar linkage and sync status are deliberately dropped on export:
/// those ids only mean something on the device/calendar that created them,
/// and are reset on import so the calendar reconciler re-pushes cleanly
/// (see [EventRepository.restoreEvent]).
class BackupService {
  BackupService({
    required this.eventRepository,
    required this.todoDao,
    required this.notifications,
  });

  final EventRepository eventRepository;
  final TodoDao todoDao;
  final NotificationPort notifications;

  static const int _schemaVersion = 1;

  /// Serializes the full database to a JSON string — the same content
  /// [exportToFile] writes out, exposed separately so [AutoBackupService]
  /// can write it to its own rolling-retention location instead of the
  /// share-sheet temp file.
  Future<String> buildJson() async {
    final events = await eventRepository.allEvents();
    final todos = await todoDao.all();
    final subtasks = await todoDao.allSubtasks();

    final json = <String, dynamic>{
      'schemaVersion': _schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'events': events.map(_eventToJson).toList(),
      'todos': todos.map(_todoToJson).toList(),
      'todoSubtasks': subtasks.map(_subtaskToJson).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(json);
  }

  /// Serializes the full database and writes it to a temp file, returning
  /// the file so the caller can hand it to a share sheet.
  Future<File> exportToFile() async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final file = File('${dir.path}/planfit-backup-$stamp.json');
    await file.writeAsString(await buildJson());
    return file;
  }

  /// Reads a previously-exported file and restores every event/to-do into
  /// the local database. Existing rows with the same id are overwritten —
  /// re-importing the same backup is safe to repeat.
  Future<BackupImportSummary> importFromFile(String path) async {
    final raw = await File(path).readAsString();
    final json = jsonDecode(raw) as Map<String, dynamic>;

    final eventsJson = (json['events'] as List?) ?? const [];
    final todosJson = (json['todos'] as List?) ?? const [];
    final subtasksJson = (json['todoSubtasks'] as List?) ?? const [];

    final knownEventIds = <String>{};
    for (final e in eventsJson) {
      final row = _eventFromJson(e as Map<String, dynamic>);
      await eventRepository.restoreEvent(row);
      knownEventIds.add(row.id);
    }
    final knownTodoIds = <String>{};
    for (final t in todosJson) {
      final companion = _todoFromCompanion(
        t as Map<String, dynamic>,
        knownEventIds,
      );
      await todoDao.upsert(companion);
      knownTodoIds.add(companion.id.value);
      final restored = await todoDao.findById(companion.id.value);
      if (restored != null) {
        await syncTodoNotification(notifications, restored);
      }
    }
    // Guards against a hand-edited or corrupted backup referencing a to-do
    // that never made it into todosJson — same defensive dropping
    // knownEventIds does above for a to-do's dangling eventId.
    for (final s in subtasksJson) {
      final j = s as Map<String, dynamic>;
      final todoId = j['todoId'] as String?;
      if (todoId == null || !knownTodoIds.contains(todoId)) continue;
      await todoDao.upsertSubtask(_subtaskFromJson(j));
    }

    return BackupImportSummary(
      eventCount: eventsJson.length,
      todoCount: todosJson.length,
    );
  }

  Map<String, dynamic> _eventToJson(EventRow e) => {
    'id': e.id,
    'title': e.title,
    'memo': e.memo,
    'location': e.location,
    'startAt': e.startAt.toUtc().toIso8601String(),
    'endAt': e.endAt.toUtc().toIso8601String(),
    'isAllDay': e.isAllDay,
    'colorTag': e.colorTag,
    'notify': e.notify,
    'reminderMinutesBefore': e.reminderMinutesBefore,
    'additionalReminderMinutes': e.additionalReminderMinutes,
    'recurrenceRule': e.recurrenceRule,
    'recurrenceGroupId': e.recurrenceGroupId,
    'createdAt': e.createdAt.toUtc().toIso8601String(),
  };

  EventRow _eventFromJson(Map<String, dynamic> j) => EventRow(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    memo: j['memo'] as String?,
    location: j['location'] as String?,
    startAt: DateTime.parse(j['startAt'] as String),
    endAt: DateTime.parse(j['endAt'] as String),
    isAllDay: j['isAllDay'] as bool? ?? false,
    colorTag: j['colorTag'] as String?,
    notify: j['notify'] as bool? ?? true,
    reminderMinutesBefore: j['reminderMinutesBefore'] as int? ?? 0,
    additionalReminderMinutes: j['additionalReminderMinutes'] as String?,
    recurrenceRule: j['recurrenceRule'] as String?,
    recurrenceGroupId: j['recurrenceGroupId'] as String?,
    osCalendarId: null,
    osEventId: null,
    osLastKnownModified: null,
    syncStatus: SyncStatus.pendingPush,
    importSourceCalendarId: null,
    importSourceEventId: null,
    createdAt:
        DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
    updatedAt: DateTime.now(),
  );

  Map<String, dynamic> _todoToJson(TodoRow t) => {
    'id': t.id,
    'eventId': t.eventId,
    'title': t.title,
    'slotStart': t.slotStart.toUtc().toIso8601String(),
    'slotEnd': t.slotEnd?.toUtc().toIso8601String(),
    'hasTime': t.hasTime,
    'isDone': t.isDone,
    'completedAt': t.completedAt?.toUtc().toIso8601String(),
    'isPinned': t.isPinned,
    'sortOrder': t.sortOrder,
    'priority': t.priority,
    'tags': t.tags,
    'notify': t.notify,
    'additionalReminderMinutes': t.additionalReminderMinutes,
    'recurrenceRule': t.recurrenceRule,
    'recurrenceGroupId': t.recurrenceGroupId,
    'createdAt': t.createdAt.toUtc().toIso8601String(),
  };

  Map<String, dynamic> _subtaskToJson(TodoSubtaskRow s) => {
    'id': s.id,
    'todoId': s.todoId,
    'title': s.title,
    'isDone': s.isDone,
    'sortOrder': s.sortOrder,
    'createdAt': s.createdAt.toUtc().toIso8601String(),
  };

  TodoSubtasksCompanion _subtaskFromJson(Map<String, dynamic> j) =>
      TodoSubtasksCompanion(
        id: Value(j['id'] as String),
        todoId: Value(j['todoId'] as String),
        title: Value(j['title'] as String? ?? ''),
        isDone: Value(j['isDone'] as bool? ?? false),
        sortOrder: Value(j['sortOrder'] as int? ?? 0),
        createdAt: Value(
          DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
        ),
      );

  /// [knownEventIds] are the ids already restored earlier in the same
  /// import (events always land first — see [importFromFile]), so a to-do's
  /// [eventId] only needs dropping when its parent genuinely isn't coming
  /// back, not on every import.
  TodoItemsCompanion _todoFromCompanion(
    Map<String, dynamic> j,
    Set<String> knownEventIds,
  ) {
    final eventId = j['eventId'] as String?;
    return TodoItemsCompanion(
      id: Value(j['id'] as String),
      eventId: Value(
        eventId != null && knownEventIds.contains(eventId) ? eventId : null,
      ),
      title: Value(j['title'] as String? ?? ''),
      slotStart: Value(DateTime.parse(j['slotStart'] as String)),
      slotEnd: Value(
        j['slotEnd'] != null ? DateTime.parse(j['slotEnd'] as String) : null,
      ),
      hasTime: Value(j['hasTime'] as bool? ?? true),
      isDone: Value(j['isDone'] as bool? ?? false),
      completedAt: Value(
        j['completedAt'] != null
            ? DateTime.parse(j['completedAt'] as String)
            : null,
      ),
      isPinned: Value(j['isPinned'] as bool? ?? false),
      sortOrder: Value(j['sortOrder'] as int? ?? 0),
      priority: Value(j['priority'] as int? ?? 0),
      tags: Value(j['tags'] as String?),
      notify: Value(j['notify'] as bool? ?? false),
      additionalReminderMinutes: Value(
        j['additionalReminderMinutes'] as String?,
      ),
      recurrenceRule: Value(j['recurrenceRule'] as String?),
      recurrenceGroupId: Value(j['recurrenceGroupId'] as String?),
      createdAt: Value(
        DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      ),
    );
  }
}
