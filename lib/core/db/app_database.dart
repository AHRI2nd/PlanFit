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
  int get schemaVersion => 16;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndexes();
    },
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
      if (from < 16) {
        await _createIndexes();
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

  /// Indexes on the columns every windowed/lookup query (`watchBetween`,
  /// `findByOsEventId`, `seriesFrom`, etc. — see `EventDao`/`TodoDao`) filters
  /// or sorts by, so those stay fast as an installation's history grows over
  /// years instead of degrading into a full-table scan. `IF NOT EXISTS` makes
  /// this idempotent, since it's called from both `onCreate` (fresh installs
  /// already got these columns via `createAll`) and the `from < 16` upgrade
  /// step (existing installs).
  Future<void> _createIndexes() async {
    for (final stmt in const [
      'CREATE INDEX IF NOT EXISTS idx_events_start_at ON events (start_at)',
      'CREATE INDEX IF NOT EXISTS idx_events_end_at ON events (end_at)',
      'CREATE INDEX IF NOT EXISTS idx_events_recurrence_group_id '
          'ON events (recurrence_group_id)',
      'CREATE INDEX IF NOT EXISTS idx_events_os_event_id '
          'ON events (os_event_id)',
      'CREATE INDEX IF NOT EXISTS idx_events_import_source '
          'ON events (import_source_calendar_id, import_source_event_id)',
      'CREATE INDEX IF NOT EXISTS idx_todo_items_slot_start '
          'ON todo_items (slot_start)',
      'CREATE INDEX IF NOT EXISTS idx_todo_items_recurrence_group_id '
          'ON todo_items (recurrence_group_id)',
      'CREATE INDEX IF NOT EXISTS idx_todo_items_os_reminder_id '
          'ON todo_items (os_reminder_id)',
    ]) {
      await customStatement(stmt);
    }
  }

  static QueryExecutor _open() => driftDatabase(name: 'planfit');
}
