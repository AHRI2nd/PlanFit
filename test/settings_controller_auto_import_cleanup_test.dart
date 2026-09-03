import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/sync_status.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/features/schedule/domain/ports.dart';
import 'package:planfit/features/settings/application/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_controller_auto_import_cleanup_test.mocks.dart';

/// Covers turning [SettingsController.setAutoImportCalendarEnabled] off:
/// every row [CalendarReconciler] previously auto-imported straight from the
/// device calendar must disappear from PlanFit's local DB, without touching
/// anything the user (or a subscribed-calendar mirror) actually owns.
@GenerateMocks([NotificationPort])
void main() {
  late AppDatabase db;
  late MockNotificationPort notifications;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    notifications = MockNotificationPort();
    when(notifications.cancelForEvent(any)).thenAnswer((_) async {});
  });

  tearDown(() => db.close());

  Future<ProviderContainer> makeContainer({
    required bool autoImportEnabled,
  }) async {
    SharedPreferences.setMockInitialValues({
      'settings.calendarSyncEnabled': true,
      'settings.autoImportCalendarEnabled': autoImportEnabled,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        notificationPortProvider.overrideWithValue(notifications),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  EventsCompanion autoImportedEvent(String id) => EventsCompanion.insert(
    id: id,
    title: Value(id),
    startAt: DateTime(2026, 3, 10, 9),
    endAt: DateTime(2026, 3, 10, 10),
    osCalendarId: const Value('device-cal-1'),
    osEventId: Value('os-$id'),
    syncStatus: const Value(SyncStatus.synced),
  );

  test(
    'turning auto-import off deletes every row it previously pulled in',
    () async {
      await db.eventDao.upsert(autoImportedEvent('a1'));
      await db.eventDao.upsert(autoImportedEvent('a2'));
      final container = await makeContainer(autoImportEnabled: true);

      await container
          .read(settingsControllerProvider.notifier)
          .setAutoImportCalendarEnabled(false);

      expect(await db.eventDao.all(), isEmpty);
      expect(
        container.read(settingsControllerProvider).autoImportCalendarEnabled,
        isFalse,
      );
      verify(notifications.cancelForEvent('a1')).called(1);
      verify(notifications.cancelForEvent('a2')).called(1);
    },
  );

  test(
    'still deletes every row even when cancelling one notification throws '
    '— regression test: a transient platform-channel error used to abort '
    'the whole cleanup before the delete ran, since only the OS-calendar '
    'push side of this codebase\'s best-effort pattern was applied here, '
    'not the notification side',
    () async {
      await db.eventDao.upsert(autoImportedEvent('a1'));
      await db.eventDao.upsert(autoImportedEvent('a2'));
      when(
        notifications.cancelForEvent('a1'),
      ).thenThrow(Exception('platform channel unavailable'));
      final container = await makeContainer(autoImportEnabled: true);

      await container
          .read(settingsControllerProvider.notifier)
          .setAutoImportCalendarEnabled(false);

      expect(await db.eventDao.all(), isEmpty);
    },
  );

  test(
    'leaves a PlanFit-owned event and a subscribed-calendar mirror row '
    'alone — only rows with osCalendarId set (and no import-source id) are '
    'auto-imported',
    () async {
      await db.eventDao.upsert(autoImportedEvent('auto1'));
      await db.eventDao.upsert(
        EventsCompanion.insert(
          id: 'own',
          title: const Value('My own event'),
          startAt: DateTime(2026, 3, 10, 9),
          endAt: DateTime(2026, 3, 10, 10),
          osEventId: const Value('os-own'),
          syncStatus: const Value(SyncStatus.pendingPush),
        ),
      );
      await db.eventDao.upsert(
        EventsCompanion.insert(
          id: 'mirror',
          title: const Value('Family calendar birthday'),
          startAt: DateTime(2026, 3, 10, 9),
          endAt: DateTime(2026, 3, 10, 10),
          importSourceCalendarId: const Value('family-cal'),
          importSourceEventId: const Value('src-1'),
          syncStatus: const Value(SyncStatus.synced),
        ),
      );
      final container = await makeContainer(autoImportEnabled: true);

      await container
          .read(settingsControllerProvider.notifier)
          .setAutoImportCalendarEnabled(false);

      final remaining = (await db.eventDao.all()).map((e) => e.id).toSet();
      expect(remaining, {'own', 'mirror'});
      verify(notifications.cancelForEvent('auto1')).called(1);
      verifyNever(notifications.cancelForEvent('own'));
      verifyNever(notifications.cancelForEvent('mirror'));
    },
  );

  test('turning auto-import on does not touch existing rows', () async {
    await db.eventDao.upsert(autoImportedEvent('a1'));
    final container = await makeContainer(autoImportEnabled: false);

    await container
        .read(settingsControllerProvider.notifier)
        .setAutoImportCalendarEnabled(true);

    expect(await db.eventDao.all(), hasLength(1));
    verifyNever(notifications.cancelForEvent(any));
  });
}
