import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/event_dao.dart';
import 'daos/event_template_dao.dart';
import 'daos/sync_log_dao.dart';
import 'daos/todo_dao.dart';
import 'sync_status.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The app's single drift database. Watch-queries on the DAOs are what let the
/// day/month/year views and the home screen refresh live whenever anything
/// writes — a user edit or the background calendar reconciler alike.
@DriftDatabase(
  tables: [Events, TodoItems, TodoSubtasks, SyncLogs, EventTemplates],
  daos: [EventDao, TodoDao, SyncLogDao, EventTemplateDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 15;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(events, events.reminderMinutesBefore);
      }
      if (from < 3) {
        await m.addColumn(events, events.recurrenceGroupId);
      }
      if (from < 4) {
        await m.createTable(eventTemplates);
      }
      if (from < 5) {
        await m.addColumn(todoItems, todoItems.recurrenceRule);
        await m.addColumn(todoItems, todoItems.recurrenceGroupId);
      }
      if (from < 6) {
        await m.addColumn(events, events.location);
      }
      if (from < 7) {
        await m.addColumn(todoItems, todoItems.hasTime);
      }
      if (from < 8) {
        await m.addColumn(events, events.importSourceCalendarId);
        await m.addColumn(events, events.importSourceEventId);
      }
      if (from < 9) {
        await m.addColumn(events, events.additionalReminderMinutes);
      }
      if (from < 10) {
        await m.addColumn(todoItems, todoItems.priority);
        await m.addColumn(todoItems, todoItems.tags);
        await m.createTable(todoSubtasks);
      }
      if (from < 11) {
        await m.addColumn(todoItems, todoItems.notify);
      }
      if (from < 12) {
        await m.addColumn(todoItems, todoItems.additionalReminderMinutes);
      }
      if (from < 13) {
        await m.addColumn(todoItems, todoItems.completedAt);
      }
      if (from < 14) {
        await m.addColumn(todoItems, todoItems.isPinned);
      }
      if (from < 15) {
        await m.addColumn(todoItems, todoItems.osReminderId);
        await m.addColumn(todoItems, todoItems.osReminderListId);
        await m.addColumn(todoItems, todoItems.osReminderLastKnownModified);
        await m.addColumn(todoItems, todoItems.reminderSyncStatus);
      }
    },
    // sqlite ships FK enforcement off by default, per-connection — every
    // `.references(...)` in tables.dart (TodoItems.eventId's setNull,
    // TodoSubtasks.todoId's cascade) is otherwise silently a no-op.
    // `beforeOpen` runs on every open regardless of platform/executor,
    // unlike a one-time migration step.
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static QueryExecutor _open() => driftDatabase(name: 'planfit');
}
