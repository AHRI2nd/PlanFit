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
/// [setHolidayCountrySelected]/[addCustomHolidayCalendarUrl]/
/// [removeCustomHolidayCalendarUrl] on the notifier, so this stubs just
/// those three (plus [build] to seed a fixed starting state) instead of
/// pulling in SettingsController's real `build()`, which reaches through
/// calendarServiceProvider/remindersServiceProvider/notificationServiceProvider
/// — real platform-backed services this test has no reason to construct.
class _FakeSettingsController extends SettingsController {
  _FakeSettingsController(
    this._initial, {
    this.onSetCountrySelected,
    this.onAddCustomUrl,
    this.onRemoveCustomUrl,
  });

  final AppSettings _initial;
  final Future<void> Function(String countryCode, bool selected)?
  onSetCountrySelected;
  final Future<void> Function(String url)? onAddCustomUrl;
  final Future<void> Function(String url)? onRemoveCustomUrl;

  @override
  AppSettings build() => _initial;

  @override
  Future<void> setHolidayCountrySelected(
    String countryCode,
    bool selected,
  ) async {
    if (onSetCountrySelected != null) {
      await onSetCountrySelected!(countryCode, selected);
      return;
    }
    final next = Set<String>.from(state.holidayCountryCodes);
    if (selected) {
      next.add(countryCode);
    } else {
      next.remove(countryCode);
    }
    state = state.copyWith(holidayCountryCodes: next);
  }

  @override
  Future<void> addCustomHolidayCalendarUrl(String url) async {
    if (onAddCustomUrl != null) {
      await onAddCustomUrl!(url);
      return;
    }
    final next = Set<String>.from(state.customHolidayCalendarUrls)..add(url);
    state = state.copyWith(customHolidayCalendarUrls: next);
  }

  @override
  Future<void> removeCustomHolidayCalendarUrl(String url) async {
    if (onRemoveCustomUrl != null) {
      await onRemoveCustomUrl!(url);
      return;
    }
    final next = Set<String>.from(state.customHolidayCalendarUrls)
      ..remove(url);
    state = state.copyWith(customHolidayCalendarUrls: next);
  }
}

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    required AppSettings initial,
    Future<void> Function(String, bool)? onSetCountrySelected,
    Future<void> Function(String)? onAddCustomUrl,
    Future<void> Function(String)? onRemoveCustomUrl,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsControllerProvider.overrideWith(
            () => _FakeSettingsController(
              initial,
              onSetCountrySelected: onSetCountrySelected,
              onAddCustomUrl: onAddCustomUrl,
              onRemoveCustomUrl: onRemoveCustomUrl,
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

  CheckboxListTile checkboxFor(WidgetTester tester, String countryName) =>
      tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, countryName),
      );

  testWidgets('every selected country shows checked, others do not', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      initial: const AppSettings(holidayCountryCodes: {'KR', 'JP'}),
    );

    expect(checkboxFor(tester, '대한민국').value, isTrue);
    expect(checkboxFor(tester, '일본').value, isTrue);
    expect(checkboxFor(tester, '미국').value, isFalse);
  });

  testWidgets('checking an unselected country selects it (adds, not '
      'replaces, the existing selection)', (tester) async {
    (String, bool)? called;
    await pumpScreen(
      tester,
      initial: const AppSettings(holidayCountryCodes: {'KR'}),
      onSetCountrySelected: (code, selected) async =>
          called = (code, selected),
    );

    await tester.tap(find.widgetWithText(CheckboxListTile, '일본'));
    await tester.pump();

    expect(called, ('JP', true));
  });

  testWidgets('unchecking a selected country deselects it', (tester) async {
    (String, bool)? called;
    await pumpScreen(
      tester,
      initial: const AppSettings(holidayCountryCodes: {'KR', 'JP'}),
      onSetCountrySelected: (code, selected) async =>
          called = (code, selected),
    );

    await tester.tap(find.widgetWithText(CheckboxListTile, '대한민국'));
    await tester.pump();

    expect(called, ('KR', false));
  });

  testWidgets(
    'a sync failure while checking a country shows a snackbar, not a crash',
    (tester) async {
      await pumpScreen(
        tester,
        initial: const AppSettings(holidayCountryCodes: {'KR'}),
        onSetCountrySelected: (_, _) async =>
            throw HolidayCalendarSyncException('network down'),
      );

      await tester.tap(find.widgetWithText(CheckboxListTile, '일본'));
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

  testWidgets(
    'every added custom URL is listed, alongside country selections — '
    'the two are independent, not either/or',
    (tester) async {
      await pumpScreen(
        tester,
        initial: const AppSettings(
          holidayCountryCodes: {'KR'},
          customHolidayCalendarUrls: {'https://example.com/calendar.ics'},
        ),
      );

      expect(find.text('https://example.com/calendar.ics'), findsOneWidget);
      expect(checkboxFor(tester, '대한민국').value, isTrue);
    },
  );

  testWidgets('tapping the remove icon on a custom URL removes just that one', (
    tester,
  ) async {
    String? removed;
    await pumpScreen(
      tester,
      initial: const AppSettings(
        customHolidayCalendarUrls: {
          'https://example.com/a.ics',
          'https://example.com/b.ics',
        },
      ),
      onRemoveCustomUrl: (url) async => removed = url,
    );

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'https://example.com/a.ics'),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pump();

    expect(removed, 'https://example.com/a.ics');
  });

  testWidgets(
    'submitting an invalid URL in the custom-calendar dialog shows a '
    'validation snackbar and never calls the controller',
    (tester) async {
      bool called = false;
      await pumpScreen(
        tester,
        initial: const AppSettings(),
        onAddCustomUrl: (_) async => called = true,
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

  testWidgets('submitting a valid URL calls addCustomHolidayCalendarUrl', (
    tester,
  ) async {
    String? submitted;
    await pumpScreen(
      tester,
      initial: const AppSettings(),
      onAddCustomUrl: (url) async => submitted = url,
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
  });
}
