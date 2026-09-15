import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/calendar_sync/calendar_service.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/features/settings/application/app_settings.dart';
import 'package:planfit/features/settings/application/settings_controller.dart';
import 'package:planfit/features/settings/presentation/settings_screen.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:planfit/l10n/app_localizations_ko.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Same stub-the-controller approach as `settings_screen_test.dart` — see its
/// doc for why only `build()` is replaced.
class _FakeSettingsController extends SettingsController {
  _FakeSettingsController(this._initial);
  final AppSettings _initial;

  @override
  AppSettings build() => _initial;
}

/// Access is granted, and there is still no calendar to sync into.
///
/// That pairing is the whole point: on iOS it is what a first-time setup
/// actually does. The platform's calendar store is built before the grant and
/// has not picked it up by the time the next read runs, so the grant reports
/// success and the read is refused anyway.
class _GrantsThenFailsCalendar extends CalendarService {
  @override
  Future<bool> requestAccess() async => true;

  @override
  Future<String?> resolveTargetCalendarId() async => null;
}

/// The sync toggles had a branch for "access is granted but there is nowhere
/// to sync into" from the start, and it did the right thing — left the switch
/// off rather than claiming sync was on with no target. It just did it
/// without a word, so tapping the switch looked like the app ignoring the
/// tap. These pin that the branch now says something.
void main() {
  final l10n = AppL10nKo();

  // Without this SharedPreferences.getInstance() waits on a platform
  // channel that never answers under flutter_test, and the whole file
  // hangs rather than failing.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Takes the fakes directly rather than a list of overrides: Riverpod does
  /// not export the type of an override by name, so a `List<Override>`
  /// parameter will not compile from outside the package.
  Future<void> pumpScreen(
    WidgetTester tester, {
    CalendarService? calendar,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsControllerProvider.overrideWith(
            () => _FakeSettingsController(const AppSettings()),
          ),
          if (calendar != null)
            calendarServiceProvider.overrideWithValue(calendar),
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

  /// Lets `showAutoDismissSnackBar`'s own timer fire before the test ends.
  /// That helper arms a Timer for the SnackBar's full duration (see
  /// snackbar_x.dart for why it hand-rolls one), and the test binding fails
  /// any test that finishes with a Timer still pending.
  Future<void> drainSnackBarTimer(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 5));

  /// The switch sitting in the same row as [title]. Found by walking up from
  /// the label rather than indexing into `find.byType(Switch)`, so inserting
  /// another switch row above this one doesn't silently retarget the test.
  Finder switchFor(String title) => find.descendant(
    of: find.ancestor(of: find.text(title), matching: find.byType(Row)).last,
    matching: find.byType(Switch),
  );

  testWidgets('the calendar toggle explains itself when there is nowhere to '
      'sync into, instead of springing back in silence', (tester) async {
    await pumpScreen(tester, calendar: _GrantsThenFailsCalendar());

    await tester.tap(switchFor(l10n.settingsCalendarSync));
    // This screen never settles, so pump a couple of frames rather than
    // waiting for quiet — the same reason settings_screen_test.dart does.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(l10n.settingsSyncSetupFailed), findsOneWidget);
    await drainSnackBarTimer(tester);
  });

  testWidgets('it is not the permission-denied message — access was granted, '
      'and telling the user to go allow it would send them somewhere with '
      'nothing to do', (tester) async {
    await pumpScreen(tester, calendar: _GrantsThenFailsCalendar());

    await tester.tap(switchFor(l10n.settingsCalendarSync));
    // This screen never settles, so pump a couple of frames rather than
    // waiting for quiet — the same reason settings_screen_test.dart does.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(l10n.settingsPermissionDeniedMessage), findsNothing);
    await drainSnackBarTimer(tester);
  });

  testWidgets('the switch stays off — saying so must not come at the cost of '
      'claiming sync is on with no target', (tester) async {
    await pumpScreen(tester, calendar: _GrantsThenFailsCalendar());

    await tester.tap(switchFor(l10n.settingsCalendarSync));
    // This screen never settles, so pump a couple of frames rather than
    // waiting for quiet — the same reason settings_screen_test.dart does.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      tester.widget<Switch>(switchFor(l10n.settingsCalendarSync)).value,
      isFalse,
    );
    await drainSnackBarTimer(tester);
  });

  // The reminders half of this change is deliberately not covered here.
  // Its row is behind `if (Platform.isIOS)` — dart:io, not
  // `Theme.of(context).platform` — so it never builds on a macOS test host
  // and no override reaches it. A test written against it would find
  // nothing and pass without asserting anything, which is worse than an
  // acknowledged gap. The code path is the same shape as the calendar one
  // above: the same helper, called from the same kind of null branch.
}
