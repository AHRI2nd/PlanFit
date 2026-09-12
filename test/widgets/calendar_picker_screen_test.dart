import 'package:device_calendar_plus/device_calendar_plus.dart' show Calendar;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/features/settings/application/app_settings.dart';
import 'package:planfit/features/settings/application/settings_controller.dart';
import 'package:planfit/features/settings/presentation/calendar_picker_screen.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSettingsController extends SettingsController {
  _FakeSettingsController(this._initial);
  final AppSettings _initial;

  @override
  AppSettings build() => _initial;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpScreen(
    WidgetTester tester, {
    required List<Calendar> calendars,
    String? targetCalendarId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsControllerProvider.overrideWith(
            () => _FakeSettingsController(
              AppSettings(targetCalendarId: targetCalendarId),
            ),
          ),
          writableCalendarsProvider.overrideWith((ref) async => calendars),
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
          home: const CalendarPickerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists every writable calendar, checking the current target', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      calendars: const [
        Calendar(id: 'c1', name: 'PlanFit', readOnly: false),
        Calendar(id: 'c2', name: 'Work', readOnly: false, accountName: 'me@x.com'),
      ],
      targetCalendarId: 'c2',
    );

    expect(find.text('PlanFit'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('me@x.com'), findsOneWidget);
    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, 'Work')).trailing,
      isA<Icon>(),
    );
    expect(
      tester
          .widget<ListTile>(find.widgetWithText(ListTile, 'PlanFit'))
          .trailing,
      isNull,
    );
  });

  testWidgets('shows an empty-state message when there is nothing writable', (
    tester,
  ) async {
    await pumpScreen(tester, calendars: const []);

    expect(find.byType(ListTile), findsNothing);
    expect(find.text('PlanFit'), findsNothing);
  });
}
