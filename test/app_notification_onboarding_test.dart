import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/app.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/core/notifications/notification_service.dart';
import 'package:planfit/core/onboarding_prefs.dart';
import 'package:planfit/core/sync_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CountingNotificationService extends NotificationService {
  var requestPermissionCalls = 0;

  @override
  Future<bool> requestPermission() async {
    requestPermissionCalls++;
    return true;
  }
}

void main() {
  testWidgets(
    'a deferred notification request remains deferred after app restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        OnboardingPrefs.completed: true,
        OnboardingPrefs.notificationDeferred: true,
        SyncPrefs.holidayLegacySourcesMigrated: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final notifications = _CountingNotificationService();

      Future<void> mountApp() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              appDatabaseProvider.overrideWithValue(database),
              notificationServiceProvider.overrideWithValue(notifications),
            ],
            child: const PlanFitApp(),
          ),
        );
        await tester.pump();
      }

      await mountApp();
      expect(prefs.getBool(OnboardingPrefs.completed), isTrue);
      expect(prefs.getBool(OnboardingPrefs.notificationDeferred), isTrue);
      expect(notifications.requestPermissionCalls, 0);

      // Recreate the root widget with the same persisted preferences, as a
      // process restart does. The fallback in PlanFitApp must honor defer.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await mountApp();

      expect(notifications.requestPermissionCalls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets('a previously prompted install does not request again', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      OnboardingPrefs.completed: true,
      OnboardingPrefs.notificationPrompted: true,
      SyncPrefs.holidayLegacySourcesMigrated: true,
    });
    final prefs = await SharedPreferences.getInstance();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final notifications = _CountingNotificationService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(database),
          notificationServiceProvider.overrideWithValue(notifications),
        ],
        child: const PlanFitApp(),
      ),
    );
    await tester.pump();

    expect(notifications.requestPermissionCalls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
