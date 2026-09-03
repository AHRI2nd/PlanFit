import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:planfit/core/backup/backup_service.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/features/schedule/data/event_repository_impl.dart';
import 'package:planfit/features/schedule/domain/event_input.dart';
import 'package:planfit/features/schedule/domain/ports.dart';

import 'backup_service_test.mocks.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.dir);
  final Directory dir;

  @override
  Future<String?> getTemporaryPath() async => dir.path;
}

@GenerateMocks([NotificationPort, CalendarPort])
void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('planfit_backup_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
    // Each test intentionally opens two separate in-memory AppDatabases
    // (source + destination) to simulate a device-to-device restore.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
  });

  AppDatabase newDb() => AppDatabase(NativeDatabase.memory());

  MockCalendarPort disabledCalendar() {
    final calendar = MockCalendarPort();
    when(calendar.isEnabled).thenReturn(false);
    return calendar;
  }

  test('round-trips a todo\'s createdAt and its link to its event', () async {
    final sourceDb = newDb();
    final notifications = MockNotificationPort();
    when(notifications.scheduleForEvent(any)).thenAnswer((_) async {});
    when(notifications.cancelForEvent(any)).thenAnswer((_) async {});

    final eventRepo = EventRepositoryImpl(
      dao: sourceDb.eventDao,
      notifications: notifications,
      calendar: disabledCalendar(),
    );

    final event = await eventRepo.save(
      EventInput(
        id: 'ev1',
        title: 'Standup',
        startAt: DateTime.now().add(const Duration(days: 1)),
        endAt: DateTime.now().add(const Duration(days: 1, hours: 1)),
      ),
    );

    final todoCreatedAt = DateTime.utc(2024, 3, 5, 8);
    await sourceDb.todoDao.upsert(
      TodoItemsCompanion.insert(
        id: 'todo1',
        title: const Value('Prep slides'),
        slotStart: event.startAt,
        eventId: Value(event.id),
        createdAt: Value(todoCreatedAt),
      ),
    );

    final sourceBackup = BackupService(
      eventRepository: eventRepo,
      todoDao: sourceDb.todoDao,
      notifications: notifications,
    );
    final file = await sourceBackup.exportToFile();

    // Restore into a completely separate, empty database — mirrors a
    // real device-to-device restore.
    final destDb = newDb();
    final destEventRepo = EventRepositoryImpl(
      dao: destDb.eventDao,
      notifications: notifications,
      calendar: disabledCalendar(),
    );
    final destBackup = BackupService(
      eventRepository: destEventRepo,
      todoDao: destDb.todoDao,
      notifications: notifications,
    );
    final summary = await destBackup.importFromFile(file.path);

    expect(summary.eventCount, 1);
    expect(summary.todoCount, 1);

    final restoredTodo = (await destDb.todoDao.all()).single;
    // drift round-trips DateTimes through a local, not UTC-flagged, value —
    // compare the actual instant rather than relying on DateTime.== (which
    // also checks the isUtc flag).
    expect(restoredTodo.createdAt.isAtSameMomentAs(todoCreatedAt), isTrue);
    expect(restoredTodo.eventId, 'ev1');

    await sourceDb.close();
    await destDb.close();
  });

  test('round-trips an event\'s location', () async {
    final sourceDb = newDb();
    final notifications = MockNotificationPort();
    when(notifications.scheduleForEvent(any)).thenAnswer((_) async {});
    when(notifications.cancelForEvent(any)).thenAnswer((_) async {});

    final eventRepo = EventRepositoryImpl(
      dao: sourceDb.eventDao,
      notifications: notifications,
      calendar: disabledCalendar(),
    );
    await eventRepo.save(
      EventInput(
        id: 'ev-loc',
        title: 'Coffee',
        location: 'Blue Bottle, Seoul',
        startAt: DateTime.now().add(const Duration(days: 1)),
        endAt: DateTime.now().add(const Duration(days: 1, hours: 1)),
      ),
    );

    final sourceBackup = BackupService(
      eventRepository: eventRepo,
      todoDao: sourceDb.todoDao,
      notifications: notifications,
    );
    final file = await sourceBackup.exportToFile();

    final destDb = newDb();
    final destEventRepo = EventRepositoryImpl(
      dao: destDb.eventDao,
      notifications: notifications,
      calendar: disabledCalendar(),
    );
    final destBackup = BackupService(
      eventRepository: destEventRepo,
      todoDao: destDb.todoDao,
      notifications: notifications,
    );
    await destBackup.importFromFile(file.path);

    final restored = (await destDb.eventDao.all()).single;
    expect(restored.location, 'Blue Bottle, Seoul');

    await sourceDb.close();
    await destDb.close();
  });

  test('round-trips an event\'s additional reminder offsets', () async {
    final sourceDb = newDb();
    final notifications = MockNotificationPort();
    when(notifications.scheduleForEvent(any)).thenAnswer((_) async {});
    when(notifications.cancelForEvent(any)).thenAnswer((_) async {});

    final eventRepo = EventRepositoryImpl(
      dao: sourceDb.eventDao,
      notifications: notifications,
      calendar: disabledCalendar(),
    );
    await eventRepo.save(
      EventInput(
        id: 'ev-reminders',
        title: 'Dentist',
        reminderMinutesBefore: 10,
        additionalReminderMinutes: const [60, 1440],
        startAt: DateTime.now().add(const Duration(days: 1)),
        endAt: DateTime.now().add(const Duration(days: 1, hours: 1)),
      ),
    );

    final sourceBackup = BackupService(
      eventRepository: eventRepo,
      todoDao: sourceDb.todoDao,
      notifications: notifications,
    );
    final file = await sourceBackup.exportToFile();

    final destDb = newDb();
    final destEventRepo = EventRepositoryImpl(
      dao: destDb.eventDao,
      notifications: notifications,
      calendar: disabledCalendar(),
    );
    final destBackup = BackupService(
      eventRepository: destEventRepo,
      todoDao: destDb.todoDao,
      notifications: notifications,
    );
    await destBackup.importFromFile(file.path);

    final restored = (await destDb.eventDao.all()).single;
    expect(restored.reminderMinutesBefore, 10);
    expect(restored.additionalReminderMinutes, '60,1440');

    await sourceDb.close();
    await destDb.close();
  });

  test('round-trips a todo\'s priority, tags, additional reminders, pinned '
      'flag, and subtasks', () async {
    final sourceDb = newDb();
    final notifications = MockNotificationPort();
    when(notifications.scheduleForEvent(any)).thenAnswer((_) async {});
    when(notifications.cancelForEvent(any)).thenAnswer((_) async {});

    await sourceDb.todoDao.upsert(
      TodoItemsCompanion.insert(
        id: 'todo-rich',
        title: const Value('Ship the release'),
        slotStart: DateTime(2026, 3, 10, 9),
        priority: const Value(3),
        tags: const Value('업무,급함'),
        additionalReminderMinutes: const Value('60,1440'),
        isPinned: const Value(true),
      ),
    );
    await sourceDb.todoDao.upsertSubtask(
      TodoSubtasksCompanion.insert(
        id: 'sub1',
        todoId: 'todo-rich',
        title: const Value('Write changelog'),
        isDone: const Value(true),
      ),
    );
    await sourceDb.todoDao.upsertSubtask(
      TodoSubtasksCompanion.insert(
        id: 'sub2',
        todoId: 'todo-rich',
        title: const Value('Tag the release'),
      ),
    );

    final eventRepo = EventRepositoryImpl(
      dao: sourceDb.eventDao,
      notifications: notifications,
      calendar: disabledCalendar(),
    );
    final sourceBackup = BackupService(
      eventRepository: eventRepo,
      todoDao: sourceDb.todoDao,
      notifications: notifications,
    );
    final file = await sourceBackup.exportToFile();

    final destDb = newDb();
    final destEventRepo = EventRepositoryImpl(
      dao: destDb.eventDao,
      notifications: notifications,
      calendar: disabledCalendar(),
    );
    final destBackup = BackupService(
      eventRepository: destEventRepo,
      todoDao: destDb.todoDao,
      notifications: notifications,
    );
    await destBackup.importFromFile(file.path);

    final restoredTodo = (await destDb.todoDao.all()).single;
    expect(restoredTodo.priority, 3);
    expect(restoredTodo.tags, '업무,급함');
    expect(restoredTodo.additionalReminderMinutes, '60,1440');
    expect(restoredTodo.isPinned, isTrue);

    final restoredSubtasks = await destDb.todoDao
        .watchSubtasks('todo-rich')
        .first;
    expect(restoredSubtasks, hasLength(2));
    expect(
      restoredSubtasks.map((s) => (s.title, s.isDone)),
      containsAll([('Write changelog', true), ('Tag the release', false)]),
    );

    await sourceDb.close();
    await destDb.close();
  });

  test(
    'excludes events mirrored from a subscribed calendar (holidays '
    'included) from the export — they are re-derived from their source, '
    'not this device\'s data to carry around, and previously came back '
    'from a restore looking PlanFit-owned and got pushed to the device '
    'calendar',
    () async {
      final sourceDb = newDb();
      final notifications = MockNotificationPort();
      when(notifications.scheduleForEvent(any)).thenAnswer((_) async {});
      when(notifications.cancelForEvent(any)).thenAnswer((_) async {});

      final eventRepo = EventRepositoryImpl(
        dao: sourceDb.eventDao,
        notifications: notifications,
        calendar: disabledCalendar(),
      );
      await eventRepo.save(
        EventInput(
          id: 'own-event',
          title: 'My own plan',
          startAt: DateTime.now().add(const Duration(days: 1)),
          endAt: DateTime.now().add(const Duration(days: 1, hours: 1)),
        ),
      );
      // A holiday-mirror row, written the way CalendarImportService does:
      // straight through EventDao, never through EventRepository.save.
      await sourceDb.eventDao.upsert(
        EventsCompanion.insert(
          id: 'holiday-event',
          title: const Value('추석'),
          startAt: DateTime.now().add(const Duration(days: 2)),
          endAt: DateTime.now().add(const Duration(days: 3)),
          isAllDay: const Value(true),
          notify: const Value(false),
          importSourceCalendarId: const Value(
            'ko.south_korea#holiday@group.v.calendar.google.com',
          ),
          importSourceEventId: const Value('holiday-src-1'),
        ),
      );

      final backup = BackupService(
        eventRepository: eventRepo,
        todoDao: sourceDb.todoDao,
        notifications: notifications,
      );
      final json = jsonDecode(await backup.buildJson()) as Map<String, dynamic>;
      final exportedIds = (json['events'] as List)
          .map((e) => (e as Map<String, dynamic>)['id'])
          .toSet();

      expect(exportedIds, {'own-event'});

      await sourceDb.close();
    },
  );

  test(
    'drops the eventId link when the parent event is missing from the backup',
    () async {
      final sourceDb = newDb();
      final notifications = MockNotificationPort();
      when(notifications.scheduleForEvent(any)).thenAnswer((_) async {});
      when(notifications.cancelForEvent(any)).thenAnswer((_) async {});

      final eventRepo = EventRepositoryImpl(
        dao: sourceDb.eventDao,
        notifications: notifications,
        calendar: disabledCalendar(),
      );
      // A real, currently-linked todo — the FK on TodoItems.eventId (enforced
      // via PRAGMA foreign_keys = ON, see AppDatabase's beforeOpen) means this
      // is the only way to legitimately get a todo with an eventId set.
      await eventRepo.save(
        EventInput(
          id: 'ev-linked',
          title: 'Parent event',
          startAt: DateTime.now().add(const Duration(days: 1)),
          endAt: DateTime.now().add(const Duration(days: 1, hours: 1)),
        ),
      );
      await sourceDb.todoDao.upsert(
        TodoItemsCompanion.insert(
          id: 'todo2',
          title: const Value('Orphaned'),
          slotStart: DateTime.now(),
          eventId: const Value('ev-linked'),
        ),
      );

      final backup = BackupService(
        eventRepository: eventRepo,
        todoDao: sourceDb.todoDao,
        notifications: notifications,
      );
      final file = await backup.exportToFile();

      // Simulate the parent event not making it into this particular backup
      // (a partial or hand-edited file, or one from before this fix) —
      // exactly the dangling reference `_todoFromCompanion` is meant to catch,
      // without needing a DB state that FK enforcement itself now forbids.
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      json['events'] = <dynamic>[];
      await file.writeAsString(jsonEncode(json));

      final destDb = newDb();
      final destEventRepo = EventRepositoryImpl(
        dao: destDb.eventDao,
        notifications: notifications,
        calendar: disabledCalendar(),
      );
      final destBackup = BackupService(
        eventRepository: destEventRepo,
        todoDao: destDb.todoDao,
        notifications: notifications,
      );
      await destBackup.importFromFile(file.path);

      final restoredTodo = (await destDb.todoDao.all()).single;
      expect(restoredTodo.eventId, isNull);

      await sourceDb.close();
      await destDb.close();
    },
  );
}
