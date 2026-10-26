import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/di.dart';
import 'settings_controller.dart';

enum IntegrationFeature {
  notifications,
  exactAlarms,
  calendar,
  reminders,
  backup,
}

enum IntegrationState {
  off,
  needsPermission,
  needsTarget,
  ready,
  pending,
  unavailable,
  failed,
}

class IntegrationHealth {
  const IntegrationHealth(
    this.feature,
    this.state, {
    this.pendingCount = 0,
    this.lastPass,
  });
  final IntegrationFeature feature;
  final IntegrationState state;
  final int pendingCount;
  final DateTime? lastPass;
}

final _databaseChanges = StreamProvider.autoDispose<void>(
  (ref) => ref.watch(appDatabaseProvider).tableUpdates().map((_) {}),
);
final _backupChanges = StreamProvider.autoDispose<void>(
  (ref) => ref.watch(autoBackupServiceProvider).changes,
);

final integrationHealthProvider =
    FutureProvider.autoDispose<List<IntegrationHealth>>((ref) async {
      ref.watch(_databaseChanges);
      ref.watch(_backupChanges);
      final settings = ref.watch(settingsControllerProvider);
      final calendar = ref.watch(calendarServiceProvider);
      final reminders = ref.watch(remindersServiceProvider);
      final events = ref.watch(eventDaoProvider);
      final todos = ref.watch(todoDaoProvider);
      final backup = ref.watch(autoBackupServiceProvider);
      final lastCalendar = ref.watch(lastCalendarSyncAtProvider);
      final lastReminders = ref.watch(lastRemindersSyncAtProvider);
      Future<IntegrationHealth> guarded(
        IntegrationFeature feature,
        Future<IntegrationHealth> Function() read,
      ) async {
        try {
          return await read();
        } catch (_) {
          return IntegrationHealth(feature, IntegrationState.failed);
        }
      }

      return Future.wait([
        guarded(IntegrationFeature.notifications, () async {
          final status = await Permission.notification.status;
          return IntegrationHealth(
            IntegrationFeature.notifications,
            status.isGranted || status.isProvisional
                ? IntegrationState.ready
                : IntegrationState.needsPermission,
          );
        }),
        if (Platform.isAndroid)
          guarded(
            IntegrationFeature.exactAlarms,
            () async => IntegrationHealth(
              IntegrationFeature.exactAlarms,
              await Permission.scheduleExactAlarm.isGranted
                  ? IntegrationState.ready
                  : IntegrationState.needsPermission,
            ),
          ),
        guarded(IntegrationFeature.calendar, () async {
          if (!settings.calendarSyncEnabled) {
            return const IntegrationHealth(
              IntegrationFeature.calendar,
              IntegrationState.off,
            );
          }
          if (!await calendar.hasFullAccess()) {
            return const IntegrationHealth(
              IntegrationFeature.calendar,
              IntegrationState.needsPermission,
            );
          }
          final targets = await calendar.writableCalendars();
          if (targets.isEmpty ||
              (settings.targetCalendarId != null &&
                  !targets.any(
                    (target) => target.id == settings.targetCalendarId,
                  ))) {
            return const IntegrationHealth(
              IntegrationFeature.calendar,
              IntegrationState.needsTarget,
            );
          }
          final pending =
              (await events.needingPush()).length +
              (await events.pendingCalendarDeletionIds()).length;
          return IntegrationHealth(
            IntegrationFeature.calendar,
            pending > 0 ? IntegrationState.pending : IntegrationState.ready,
            pendingCount: pending,
            lastPass: lastCalendar,
          );
        }),
        guarded(IntegrationFeature.reminders, () async {
          if (!Platform.isIOS) {
            return const IntegrationHealth(
              IntegrationFeature.reminders,
              IntegrationState.unavailable,
            );
          }
          if (!settings.remindersSyncEnabled) {
            return const IntegrationHealth(
              IntegrationFeature.reminders,
              IntegrationState.off,
            );
          }
          if (!await Permission.reminders.isGranted) {
            return const IntegrationHealth(
              IntegrationFeature.reminders,
              IntegrationState.needsPermission,
            );
          }
          if (!await reminders.hasExistingTarget()) {
            return const IntegrationHealth(
              IntegrationFeature.reminders,
              IntegrationState.needsTarget,
            );
          }
          final pending =
              (await todos.needingReminderPush()).length +
              (await todos.pendingReminderDeletionIds()).length;
          return IntegrationHealth(
            IntegrationFeature.reminders,
            pending > 0 ? IntegrationState.pending : IntegrationState.ready,
            pendingCount: pending,
            lastPass: lastReminders,
          );
        }),
        guarded(
          IntegrationFeature.backup,
          () async => IntegrationHealth(
            IntegrationFeature.backup,
            backup.lastError != null
                ? IntegrationState.failed
                : backup.lastRunAt == null
                ? IntegrationState.pending
                : IntegrationState.ready,
            lastPass: backup.lastRunAt,
          ),
        ),
      ]);
    });
