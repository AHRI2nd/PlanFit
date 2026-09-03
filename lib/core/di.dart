import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/schedule/data/event_repository_impl.dart';
import '../features/schedule/domain/event_repository.dart';
import '../features/schedule/domain/ports.dart';
import 'backup/auto_backup_service.dart';
import 'backup/backup_service.dart';
import 'backup/ics_export_service.dart';
import 'calendar_sync/calendar_import_service.dart';
import 'calendar_sync/calendar_reconciler.dart';
import 'calendar_sync/calendar_service.dart';
import 'calendar_sync/holiday_calendar_service.dart';
import 'db/app_database.dart';
import 'db/daos/event_dao.dart';
import 'db/daos/event_template_dao.dart';
import 'db/daos/sync_log_dao.dart';
import 'db/daos/todo_dao.dart';
import 'notifications/notification_service.dart';
import 'reminders_sync/reminders_reconciler.dart';
import 'reminders_sync/reminders_service.dart';
import 'sync_prefs.dart';

/// Infrastructure wiring. Kept as plain providers (no codegen) so the object
/// graph reads top-to-bottom in one place.

/// Overridden in `main()` once the async load completes.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

/// The real, currently-running build's version — `pubspec.yaml`'s
/// `version:` baked in at build time, read via the platform's own bundle
/// metadata rather than duplicated as a literal anywhere in Dart. The
/// settings screen's About section used to hard-code this as a plain
/// string, which silently went stale (still read "1.0.0" after the app was
/// actually bumped to 1.0.1) since nothing tied it to the real value.
final appPackageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final eventDaoProvider = Provider<EventDao>(
  (ref) => ref.watch(appDatabaseProvider).eventDao,
);
final todoDaoProvider = Provider<TodoDao>(
  (ref) => ref.watch(appDatabaseProvider).todoDao,
);
final syncLogDaoProvider = Provider<SyncLogDao>(
  (ref) => ref.watch(appDatabaseProvider).syncLogDao,
);
final eventTemplateDaoProvider = Provider<EventTemplateDao>(
  (ref) => ref.watch(appDatabaseProvider).eventTemplateDao,
);

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final calendarServiceProvider = Provider<CalendarService>((ref) {
  return CalendarService();
});

/// The port the repository sees. It's the same [CalendarService] instance, so
/// toggling sync in settings takes effect immediately.
final calendarPortProvider = Provider<CalendarPort>(
  (ref) => ref.watch(calendarServiceProvider),
);

final notificationPortProvider = Provider<NotificationPort>(
  (ref) => ref.watch(notificationServiceProvider),
);

final remindersServiceProvider = Provider<RemindersService>((ref) {
  return RemindersService();
});

/// The port [TodoController] sees. Same instance as [remindersServiceProvider],
/// so toggling sync in settings takes effect immediately.
final remindersPortProvider = Provider<RemindersPort>(
  (ref) => ref.watch(remindersServiceProvider),
);

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepositoryImpl(
    dao: ref.watch(eventDaoProvider),
    notifications: ref.watch(notificationPortProvider),
    calendar: ref.watch(calendarPortProvider),
  );
});

final calendarReconcilerProvider = Provider<CalendarReconciler>((ref) {
  return CalendarReconciler(
    service: ref.watch(calendarServiceProvider),
    eventDao: ref.watch(eventDaoProvider),
    syncLogDao: ref.watch(syncLogDaoProvider),
    notifications: ref.watch(notificationPortProvider),
    calendarImportService: ref.watch(calendarImportServiceProvider),
  );
});

final remindersReconcilerProvider = Provider<RemindersReconciler>((ref) {
  return RemindersReconciler(
    service: ref.watch(remindersServiceProvider),
    todoDao: ref.watch(todoDaoProvider),
    syncLogDao: ref.watch(syncLogDaoProvider),
    notifications: ref.watch(notificationPortProvider),
  );
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    eventRepository: ref.watch(eventRepositoryProvider),
    todoDao: ref.watch(todoDaoProvider),
    notifications: ref.watch(notificationPortProvider),
  );
});

final icsExportServiceProvider = Provider<IcsExportService>((ref) {
  return IcsExportService(eventRepository: ref.watch(eventRepositoryProvider));
});

final autoBackupServiceProvider = Provider<AutoBackupService>((ref) {
  return AutoBackupService(
    backupService: ref.watch(backupServiceProvider),
    prefs: ref.watch(sharedPreferencesProvider),
  );
});

final calendarImportServiceProvider = Provider<CalendarImportService>((ref) {
  return CalendarImportService(
    calendarService: ref.watch(calendarServiceProvider),
    eventDao: ref.watch(eventDaoProvider),
  );
});

final holidayCalendarServiceProvider = Provider<HolidayCalendarService>((ref) {
  return HolidayCalendarService(eventDao: ref.watch(eventDaoProvider));
});

/// When [CalendarReconciler] last completed a successful device-calendar
/// sync pass. Seeded from [SyncPrefs] on first read; app.dart calls
/// [LastCalendarSyncAt.record] (state + persisted value together) after
/// every successful reconcile while sync is on, so it survives restarts and
/// stays live without re-reading prefs on every rebuild.
class LastCalendarSyncAt extends Notifier<DateTime?> {
  @override
  DateTime? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final iso = prefs.getString(SyncPrefs.lastCalendarSyncAt);
    return iso == null ? null : DateTime.tryParse(iso);
  }

  Future<void> record(DateTime at) async {
    state = at;
    await ref
        .read(sharedPreferencesProvider)
        .setString(SyncPrefs.lastCalendarSyncAt, at.toIso8601String());
  }
}

final lastCalendarSyncAtProvider =
    NotifierProvider<LastCalendarSyncAt, DateTime?>(LastCalendarSyncAt.new);
