import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/app.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/core/notifications/notification_service.dart';
import 'package:planfit/core/onboarding_prefs.dart';
import 'package:planfit/core/sync_prefs.dart';
import 'package:planfit/features/settings/application/app_settings.dart';
import 'package:planfit/features/settings/application/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestSettingsController extends SettingsController {
  @override
  AppSettings build() => const AppSettings(holidayCalendarEnabled: false);
}

class _TestNotificationService extends NotificationService {}

void main() {
  testWidgets('the app preserves the system text scale above 1.3x', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    SharedPreferences.setMockInitialValues({
      OnboardingPrefs.completed: false,
      SyncPrefs.holidayLegacySourcesMigrated: true,
    });
    final prefs = await SharedPreferences.getInstance();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(database),
          notificationServiceProvider.overrideWithValue(
            _TestNotificationService(),
          ),
          settingsControllerProvider.overrideWith(_TestSettingsController.new),
        ],
        child: const PlanFitApp(),
      ),
    );
    await tester.pump();

    final paragraph = tester.renderObject<RenderParagraph>(
      find.byType(Text).first,
    );
    expect(paragraph.textScaler.scale(10), 20);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
