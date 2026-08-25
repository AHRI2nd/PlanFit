import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  const expectedIndexes = [
    'idx_events_start_at',
    'idx_events_end_at',
    'idx_events_recurrence_group_id',
    'idx_events_os_event_id',
    'idx_events_import_source',
    'idx_todo_items_slot_start',
    'idx_todo_items_recurrence_group_id',
    'idx_todo_items_os_reminder_id',
  ];

  Future<Set<String>> indexNames(AppDatabase db) async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  test('a fresh install (onCreate) gets every performance index', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final names = await indexNames(db);
    for (final name in expectedIndexes) {
      expect(names, contains(name), reason: '$name missing after onCreate');
    }
  });

  test('upgrading from schema v15 (pre-index) creates every index without '
      'touching existing data', () async {
    // Build a v15 database by hand (the columns v15 already has), then
    // open it through AppDatabase at the current schema version so its
    // real onUpgrade path runs — the same path an existing install goes
    // through after this update ships.
    final raw = sqlite3.sqlite3.openInMemory();
    raw.execute('''
        CREATE TABLE events (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL DEFAULT '',
          memo TEXT NULL,
          location TEXT NULL,
          start_at INTEGER NOT NULL,
          end_at INTEGER NOT NULL,
          is_all_day INTEGER NOT NULL DEFAULT 0,
          color_tag TEXT NULL,
          notify INTEGER NOT NULL DEFAULT 1,
          reminder_minutes_before INTEGER NOT NULL DEFAULT 0,
          additional_reminder_minutes TEXT NULL,
          recurrence_rule TEXT NULL,
          recurrence_group_id TEXT NULL,
          os_calendar_id TEXT NULL,
          os_event_id TEXT NULL,
          os_last_known_modified INTEGER NULL,
          sync_status TEXT NOT NULL DEFAULT 'pendingPush',
          import_source_calendar_id TEXT NULL,
          import_source_event_id TEXT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
    raw.execute('''
        CREATE TABLE todo_items (
          id TEXT NOT NULL PRIMARY KEY,
          event_id TEXT NULL,
          title TEXT NOT NULL DEFAULT '',
          slot_start INTEGER NOT NULL,
          slot_end INTEGER NULL,
          has_time INTEGER NOT NULL DEFAULT 1,
          is_done INTEGER NOT NULL DEFAULT 0,
          completed_at INTEGER NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          priority INTEGER NOT NULL DEFAULT 0,
          tags TEXT NULL,
          notify INTEGER NOT NULL DEFAULT 0,
          additional_reminder_minutes TEXT NULL,
          recurrence_rule TEXT NULL,
          recurrence_group_id TEXT NULL,
          is_pinned INTEGER NOT NULL DEFAULT 0,
          os_reminder_id TEXT NULL,
          os_reminder_list_id TEXT NULL,
          os_reminder_last_known_modified INTEGER NULL,
          reminder_sync_status TEXT NOT NULL DEFAULT 'pendingPush',
          created_at INTEGER NOT NULL
        )
      ''');
    raw.execute(
      'CREATE TABLE todo_subtasks ('
      'id TEXT NOT NULL PRIMARY KEY, todo_id TEXT NOT NULL, '
      "title TEXT NOT NULL DEFAULT '', is_done INTEGER NOT NULL DEFAULT 0, "
      'sort_order INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL)',
    );
    raw.execute(
      'CREATE TABLE event_templates ('
      "id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, title TEXT NOT NULL DEFAULT '', "
      'memo TEXT NULL, duration_minutes INTEGER NOT NULL DEFAULT 60, '
      'is_all_day INTEGER NOT NULL DEFAULT 0, color_tag TEXT NULL, '
      'notify INTEGER NOT NULL DEFAULT 1, reminder_minutes_before INTEGER NOT NULL DEFAULT 0, '
      'created_at INTEGER NOT NULL)',
    );
    raw.execute(
      'CREATE TABLE sync_logs ('
      'id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, at INTEGER NOT NULL, '
      'event_title TEXT NULL, resolution TEXT NOT NULL, detail TEXT NULL)',
    );
    raw.execute(
      "INSERT INTO events (id, start_at, end_at, created_at, updated_at) "
      "VALUES ('keep-me', 0, 3600, 0, 0)",
    );
    raw.userVersion = 15;

    final db = AppDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    // Touching the database forces drift to run its migration.
    final events = await db.eventDao.all();
    expect(events, hasLength(1));
    expect(events.single.id, 'keep-me');

    final names = await indexNames(db);
    for (final name in expectedIndexes) {
      expect(
        names,
        contains(name),
        reason: '$name missing after v15->v16 upgrade',
      );
    }
  });
}
