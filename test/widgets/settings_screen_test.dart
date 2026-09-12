import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/features/settings/application/app_settings.dart';
import 'package:planfit/features/settings/application/settings_controller.dart';
import 'package:planfit/features/settings/presentation/settings_screen.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// This screen (1,400+ lines) reaches calendarServiceProvider/
/// remindersServiceProvider through SettingsController's real build() the
/// same way HolidayCalendarSourceScreen's own test doc explains — stubbing
/// just build() here avoids constructing those real, platform-backed
/// services, while every mutating method (setNotificationSound, etc.) falls
/// through to the real implementation, which only touches
/// sharedPreferencesProvider.
class _FakeSettingsController extends SettingsController {
  _FakeSettingsController(this._initial);
  final AppSettings _initial;

  @override
  AppSettings build() => _initial;
}

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    AppSettings initial = const AppSettings(),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsControllerProvider.overrideWith(
            () => _FakeSettingsController(initial),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ko'),
          localizationsDelegates: const [
            AppL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppL10n.supportedLocales,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders without crashing, with every top-level section header '
      'visible', (tester) async {
    await pumpScreen(tester);

    expect(find.text('설정'), findsOneWidget);
    expect(find.text('알림'), findsOneWidget);
    expect(find.text('캘린더 연동'), findsOneWidget);
  });

  testWidgets(
    'toggling the notification-sound switch flips its own value — a plain '
    'smoke check that the switch is wired to the real controller, not a '
    'dead callback',
    (tester) async {
      await pumpScreen(
        tester,
        initial: const AppSettings(notificationSound: true),
      );

      // Notification sound is the very first switch row on the screen.
      final soundSwitch = find.byType(Switch).first;
      expect(tester.widget<Switch>(soundSwitch).value, isTrue);

      await tester.tap(soundSwitch);
      await tester.pump();

      expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
    },
  );
}
