import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/design/glass/glass_nav_bar.dart';

/// [navBarClearance] is read from *inside* a screen's body, but the value it
/// has to produce describes a bar that lives in the Scaffold's
/// `bottomNavigationBar` slot — and those two places see different
/// MediaQueries. `Scaffold` strips the bottom padding from its body slot when
/// `extendBody: true`, so a body-side `MediaQuery.viewPaddingOf(context)`
/// reports 0 no matter what the device's gesture/button-nav inset actually
/// is, while [GlassNavBar] in the bar slot reads the real value and sizes
/// itself with it.
///
/// Getting this wrong shorts every list on Android by exactly the device
/// inset — caught on an emulator with gesture navigation (24) as the settings
/// list's last card still crossing under the bar despite "full" clearance.
void main() {
  Future<({double body, double bar})> clearances(
    WidgetTester tester,
    double inset,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.viewPadding = FakeViewPadding(bottom: inset);
    tester.view.padding = FakeViewPadding(bottom: inset);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetPadding);

    late double fromBody;
    late double fromBar;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          extendBody: true,
          body: Builder(
            builder: (context) {
              fromBody = navBarClearance(context);
              return const SizedBox.expand();
            },
          ),
          bottomNavigationBar: Builder(
            builder: (context) {
              fromBar = navBarClearance(context);
              return const SizedBox(height: 80);
            },
          ),
        ),
      ),
    );
    return (body: fromBody, bar: fromBar);
  }

  testWidgets('reports the same clearance from a screen body as from the '
      "bar's own slot, even though Scaffold strips the body's bottom "
      'inset', (tester) async {
    final measured = await clearances(tester, 24);

    expect(
      measured.body,
      measured.bar,
      reason:
          'a list in the body must reserve the height the bar actually '
          'occupies, not a short one computed from a stripped MediaQuery',
    );
  });

  testWidgets("grows with the device's own navigation inset", (tester) async {
    final gesture = await clearances(tester, 24);
    final threeButton = await clearances(tester, 48);
    final none = await clearances(tester, 0);

    expect(gesture.body, none.body + 24);
    expect(threeButton.body, none.body + 48);
  });
}
