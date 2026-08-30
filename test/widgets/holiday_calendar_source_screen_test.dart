import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/calendar_sync/holiday_calendar_service.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/features/settings/application/app_settings.dart';
import 'package:planfit/features/settings/application/settings_controller.dart';
import 'package:planfit/features/settings/presentation/holiday_calendar_source_screen.dart';
import 'package:planfit/l10n/app_localizations.dart';

/// A settings-controller test double — the screen only ever calls
/// [setHolidayCountryCode]/[setCustomHolidayCalendarUrl] on the notifier, so
/// this stubs just those two (plus [build] to seed a fixed starting state)
/// instead of pulling in SettingsController's real `build()`, which reaches
/// through calendarServiceProvider/remindersServiceProvider/
/// notificationServiceProvider — real platform-backed services this test
/// has no reason to construct.
class _FakeSettingsController extends SettingsController {
  _FakeSettingsController(
    this._initial, {
    this.onSetCountry,
    this.onSetCustomUrl,
  });

  final AppSettings _initial;
  final Future<void> Function(String countryCode)? onSetCountry;
  final Future<void> Function(String url)? onSetCustomUrl;

  @override
  AppSettings build() => _initial;

  @override
  Future<void> setHolidayCountryCode(String countryCode) async {
    if (onSetCountry != null) {
      await onSetCountry!(countryCode);
      return;
    }
    state = state.copyWith(
      holidayCountryCode: countryCode,
      clearCustomHolidayCalendarUrl: true,
    );
  }

  @override
  Future<void> setCustomHolidayCalendarUrl(String url) async {
    if (onSetCustomUrl != null) {
      await onSetCustomUrl!(url);
      return;
    }
    state = state.copyWith(customHolidayCalendarUrl: url);
  }
}

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    required AppSettings initial,
    Future<void> Function(String)? onSetCountry,
    Future<void> Function(String)? onSetCustomUrl,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsControllerProvider.overrideWith(
            () => _FakeSettingsController(
              initial,
              onSetCountry: onSetCountry,
              onSetCustomUrl: onSetCustomUrl,
            ),
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
          home: const HolidayCalendarSourceScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the currently-selected country shows a checkmark', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      initial: const AppSettings(holidayCountryCode: 'JP'),
    );

    final jpTile = find.widgetWithText(ListTile, '일본');
    expect(jpTile, findsOneWidget);
    expect(
      find.descendant(of: jpTile, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    // Some other country isn't checked.
    final krTile = find.widgetWithText(ListTile, '대한민국');
    expect(
      find.descendant(of: krTile, matching: find.byIcon(Icons.check)),
      findsNothing,
    );
  });

  testWidgets('tapping a country calls setHolidayCountryCode', (
    tester,
  ) async {
    String? called;
    await pumpScreen(
      tester,
      initial: const AppSettings(holidayCountryCode: 'KR'),
      onSetCountry: (code) async => called = code,
    );

    await tester.tap(find.widgetWithText(ListTile, '일본'));
    await tester.pump();

    expect(called, 'JP');
  });

  testWidgets(
    'a sync failure while picking a country shows a snackbar, not a crash',
    (tester) async {
      await pumpScreen(
        tester,
        initial: const AppSettings(holidayCountryCode: 'KR'),
        onSetCountry: (_) async =>
            throw HolidayCalendarSyncException('network down'),
      );

      await tester.tap(find.widgetWithText(ListTile, '일본'));
      await tester.pump();
      await tester.pump();

      expect(find.text('공휴일 캘린더를 불러오지 못했어요'), findsOneWidget);
      // showAutoDismissSnackBar arms its own real Timer(snackBar.duration,
      // ...) (see snackbar_x.dart) — flutter_test's own invariant check
      // fails a test that ends with a pending Timer, so let it fire before
      // the test tears down (same pattern as day_view_test.dart's delete
      // flow).
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets('an active custom URL is shown and checked, not any country', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      initial: const AppSettings(
        holidayCountryCode: 'KR',
        customHolidayCalendarUrl: 'https://example.com/calendar.ics',
      ),
    );

    expect(find.text('https://example.com/calendar.ics'), findsOneWidget);
    final krTile = find.widgetWithText(ListTile, '대한민국');
    expect(
      find.descendant(of: krTile, matching: find.byIcon(Icons.check)),
      findsNothing,
    );
  });

  testWidgets(
    'submitting an invalid URL in the custom-calendar dialog shows a '
    'validation snackbar and never calls the controller',
    (tester) async {
      bool called = false;
      await pumpScreen(
        tester,
        initial: const AppSettings(),
        onSetCustomUrl: (_) async => called = true,
      );

      await tester.tap(find.text('URL로 직접 추가'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'not a url');
      await tester.tap(find.text('완료'));
      await tester.pumpAndSettle();

      expect(find.text('올바른 http/https 링크를 입력해주세요'), findsOneWidget);
      expect(called, isFalse);
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets(
    'submitting a valid URL calls setCustomHolidayCalendarUrl',
    (tester) async {
      String? submitted;
      await pumpScreen(
        tester,
        initial: const AppSettings(),
        onSetCustomUrl: (url) async => submitted = url,
      );

      await tester.tap(find.text('URL로 직접 추가'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'https://example.com/calendar.ics',
      );
      await tester.tap(find.text('완료'));
      await tester.pumpAndSettle();

      expect(submitted, 'https://example.com/calendar.ics');
    },
  );
}
