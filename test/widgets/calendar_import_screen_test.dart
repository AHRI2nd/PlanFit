import 'package:device_calendar_plus/device_calendar_plus.dart' show Calendar;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/features/settings/application/app_settings.dart';
import 'package:planfit/features/settings/application/settings_controller.dart';
import 'package:planfit/features/settings/presentation/calendar_import_screen.dart';
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
    Set<String> subscribed = const {},
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsControllerProvider.overrideWith(
            () => _FakeSettingsController(
              AppSettings(subscribedCalendarIds: subscribed),
            ),
          ),
          importSourceCalendarsProvider.overrideWith((ref) async => calendars),
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
          home: const CalendarImportScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'lists every importable calendar, with a subscribed one showing its own '
    'hint instead of the account name and its import button disabled',
    (tester) async {
      await pumpScreen(
        tester,
        calendars: const [
          Calendar(id: 'c1', name: 'Family', readOnly: true, accountName: 'a@x.com'),
          Calendar(id: 'c2', name: 'Holidays', readOnly: true),
        ],
        subscribed: {'c2'},
      );

      expect(find.text('Family'), findsOneWidget);
      expect(find.text('a@x.com'), findsOneWidget);
      expect(find.text('Holidays'), findsOneWidget);

      final holidaysImportButton = tester.widget<IconButton>(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Holidays'),
          matching: find.byType(IconButton),
        ),
      );
      expect(holidaysImportButton.onPressed, isNull);

      final familyImportButton = tester.widget<IconButton>(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Family'),
          matching: find.byType(IconButton),
        ),
      );
      expect(familyImportButton.onPressed, isNotNull);
    },
  );

  testWidgets('shows an empty-state message when there is nothing to import', (
    tester,
  ) async {
    await pumpScreen(tester, calendars: const []);

    expect(find.byType(ListTile), findsNothing);
  });
}
