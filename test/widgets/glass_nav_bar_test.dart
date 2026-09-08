import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/design/glass/glass_nav_bar.dart';
import 'package:planfit/design/glass/glass_surface.dart';
import 'package:planfit/design/theme/app_theme.dart';

/// Regression test: [GlassNavBar]'s own bottom padding used to multiply
/// `MediaQuery.viewPaddingOf(context).bottom` by `0.0`, making a device's
/// gesture-navigation inset have zero effect on the floating pill's
/// clearance from the screen's bottom edge — dead code present since the
/// very first commit, not a later regression.
void main() {
  Future<EdgeInsets> pillPadding(WidgetTester tester, double bottomInset) async {
    // 1.0 so the FakeViewPadding physical-pixel value below equals the
    // logical value MediaQuery.viewPaddingOf ultimately resolves to.
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    // `MediaQuery.viewPaddingOf` reads `viewPadding` specifically — distinct
    // from `padding` (which `resizeToAvoidBottomInset` can shrink) and the
    // one GlassNavBar actually reads.
    tester.view.viewPadding = FakeViewPadding(bottom: bottomInset);
    addTearDown(tester.view.resetViewPadding);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          bottomNavigationBar: GlassNavBar(
            items: const [
              GlassNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
              ),
            ],
            currentIndex: 0,
            accent: Colors.blue,
            onTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final padding = tester.widget<Padding>(
      find
          .ancestor(of: find.byType(GlassSurface), matching: find.byType(Padding))
          .first,
    );
    return padding.padding.resolve(TextDirection.ltr);
  }

  testWidgets(
    "the floating pill's bottom clearance grows with the device's own "
    "gesture-navigation inset instead of ignoring it",
    (tester) async {
      final withInset = await pillPadding(tester, 48);
      final withoutInset = await pillPadding(tester, 0);

      expect(withInset.bottom, withoutInset.bottom + 48);
    },
  );
}
