import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:planfit/core/backup/auto_backup_service.dart';
import 'package:planfit/core/backup/backup_service.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/features/schedule/data/event_repository_impl.dart';
import 'package:planfit/features/schedule/domain/ports.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auto_backup_service_test.mocks.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.dir);
  final Directory dir;

  @override
  Future<String?> getApplicationSupportPath() async => dir.path;
}

@GenerateMocks([NotificationPort, CalendarPort])
void main() {
  late Directory rootDir;
  late AppDatabase db;
  late BackupService backupService;
  late AutoBackupService autoBackupService;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    rootDir = Directory.systemTemp.createTempSync('planfit_auto_backup_test');
    PathProviderPlatform.instance = _FakePathProvider(rootDir);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    db = AppDatabase(NativeDatabase.memory());
    final notifications = MockNotificationPort();
    when(notifications.scheduleForEvent(any)).thenAnswer((_) async {});
    when(notifications.cancelForEvent(any)).thenAnswer((_) async {});
    final calendar = MockCalendarPort();
    when(calendar.isEnabled).thenReturn(false);

    backupService = BackupService(
      eventRepository: EventRepositoryImpl(
        dao: db.eventDao,
        notifications: notifications,
        calendar: calendar,
      ),
      todoDao: db.todoDao,
      notifications: notifications,
    );
    autoBackupService = AutoBackupService(
      backupService: backupService,
      prefs: prefs,
    );
  });

  tearDown(() async {
    await db.close();
    rootDir.deleteSync(recursive: true);
  });

  test('writes a backup the first time it runs', () async {
    expect(await autoBackupService.listBackups(), isEmpty);

    await autoBackupService.runIfDue(now: DateTime(2026, 1, 1));

    final files = await autoBackupService.listBackups();
    expect(files, hasLength(1));
    expect(await files.single.readAsString(), contains('"schemaVersion"'));
  });

  test('does not write again before minInterval has passed', () async {
    await autoBackupService.runIfDue(now: DateTime(2026, 1, 1, 0, 0));
    await autoBackupService.runIfDue(
      now: DateTime(2026, 1, 1, 0, 0).add(const Duration(hours: 1)),
    );

    expect(await autoBackupService.listBackups(), hasLength(1));
  });

  test('writes another backup once minInterval has passed', () async {
    await autoBackupService.runIfDue(now: DateTime(2026, 1, 1));
    await autoBackupService.runIfDue(
      now: DateTime(2026, 1, 1).add(AutoBackupService.minInterval),
    );

    expect(await autoBackupService.listBackups(), hasLength(2));
  });

  test('prunes down to maxRetained, keeping the newest', () async {
    var now = DateTime(2026, 1, 1);
    for (var i = 0; i < AutoBackupService.maxRetained + 3; i++) {
      await autoBackupService.runIfDue(now: now);
      now = now.add(AutoBackupService.minInterval);
    }

    final files = await autoBackupService.listBackups();
    expect(files, hasLength(AutoBackupService.maxRetained));
  });

  test('listBackups returns newest first', () async {
    final first = DateTime(2026, 1, 1);
    final second = first.add(AutoBackupService.minInterval);
    await autoBackupService.runIfDue(now: first);
    await autoBackupService.runIfDue(now: second);

    final files = await autoBackupService.listBackups();
    expect(files.first.path.contains('2026-01-02'), isTrue);
  });
}
