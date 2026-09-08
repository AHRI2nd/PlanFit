import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:planfit/app.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/core/onboarding_prefs.dart';
import 'package:planfit/core/time/timezone_setup.dart';
import 'package:planfit/features/settings/application/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// End-to-end smoke test on a real device/simulator — exercises the actual
/// app wiring (real DB, real providers, real router) instead of the mocked
/// repositories widget tests use. Mirrors main.dart's bootstrap, with one
/// deliberate difference: onboarding and the one-time notification-
/// permission prompt are pre-marked done in SharedPreferences before the
/// first frame, so the test lands straight on the shell instead of a native
/// permission dialog integration_test can't drive (that dialog sits outside
/// the Flutter view hierarchy). Onboarding/permission flows themselves are
/// already covered separately by test/widgets/onboarding_screen_test.dart.
///
/// Run with: `flutter test integration_test/app_test.dart -d <device-id>`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('creating an event from the schedule tab shows it in day view',
      (tester) async {
    await initializeDateFormatting();
    await TimezoneSetup.init();
    await LiquidGlassWidgets.initialize();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingPrefs.completed, true);
    await prefs.setBool(OnboardingPrefs.notificationPrompted, true);

    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    await container.read(notificationServiceProvider).init();
    container.read(settingsControllerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: LiquidGlassWidgets.wrap(child: const PlanFitApp()),
      ),
    );
    await tester.pumpAndSettle();

    // Onboarding already marked complete above, so the router should have
    // landed directly on the home tab.
    expect(find.text('플랜핏'), findsNothing); // sanity: not still splash-y
    // On the real iOS Liquid Glass tab bar (GlassTabBar.bottom, only used on
    // a physical iOS/simulator run — widget tests never exercise this path
    // since Platform.isIOS is false there), each tab's label is genuinely
    // rendered twice: once in an always-present "unselected" base row, once
    // in a magnified "selected" overlay row that tracks the sliding
    // indicator pill (ExcludeSemantics'd, so it doesn't double-announce —
    // see liquid_glass_widgets' tab_bar_bottom_layout.dart, `childUnselected`
    // vs `selectedTabBuilder`). A bare findsOneWidget here doesn't hold on
    // that path.
    expect(find.text('시간표'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('시간표').first);
    await tester.pumpAndSettle();

    // find.byIcon(Icons.add) is ambiguous now — day_view.dart alone grew two
    // more inline add affordances (an empty-hour hint, a no-time bucket row)
    // since this test was written, plus this screen's own FAB, so it's the
    // FAB specifically (the one that opens the full event editor) that's
    // wanted here.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    const title = 'Integration test event';
    await tester.enterText(find.byType(TextField).first, title);
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text(title), findsOneWidget);
  });
}
