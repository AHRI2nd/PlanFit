import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/features/schedule/application/schedule_fab_position.dart';
import 'package:planfit/features/schedule/presentation/draggable_add_button.dart';
import 'package:planfit/features/schedule/presentation/month_view/month_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The add button floats in a Stack over the schedule view, and its own class
/// doc promises it can never be parked over a navigation control. That held
/// while every such control sat above the Stack — the header, the
/// day/week/month switcher. The month view's calendar/timeline switcher broke
/// it by being drawn *inside* the view: on an Android emulator in landscape
/// the button came to rest against the switcher's right end, in the same
/// accent colour so the two read as one shape, and a tap on the overlap
/// opened the event editor instead of changing tab.
///
/// These pin the reserved strip that keeps it off.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Parks the button at the very top of its range and reports where it
  /// landed. `verticalFraction: 0` is the worst case for a control drawn at
  /// the top of the region, which is the whole point of the inset.
  Future<Rect> pumpParkedAtTop(
    WidgetTester tester, {
    required double topInset,
    Size region = const Size(400, 300),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          scheduleFabPositionProvider.overrideWith(
            () => _FixedFabPosition(
              const ScheduleFabPosition(
                side: ScheduleFabSide.right,
                verticalFraction: 0,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: region.width,
                height: region.height,
                child: Stack(
                  children: [
                    DraggableAddButton(topInset: topInset, onPressed: () {}),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final region0 = tester.getRect(find.byType(DraggableAddButton));
    final button = tester.getRect(find.byType(FloatingActionButton));
    // Reported relative to the region's own top-left, which is what the
    // inset is measured from.
    return button.translate(-region0.left, -region0.top);
  }

  testWidgets('with no inset the button parks just inside the top edge — the '
      'behaviour every other schedule view still has', (tester) async {
    final r = await pumpParkedAtTop(tester, topInset: 0);

    expect(r.top, closeTo(DraggableAddButton.edgeInset, 0.5));
  });

  testWidgets('an inset pushes the parked button below it, so a control drawn '
      'at the top of the region stays uncovered', (tester) async {
    final r = await pumpParkedAtTop(tester, topInset: kMonthTabBarHeight);

    expect(
      r.top,
      closeTo(DraggableAddButton.edgeInset + kMonthTabBarHeight, 0.5),
    );
    expect(
      r.top,
      greaterThanOrEqualTo(kMonthTabBarHeight),
      reason: 'the reserved strip is the switcher; the button must clear it',
    );
  });

  testWidgets('the strip is the month switcher\'s own height, not a number '
      'picked to look right — the two have to move together', (tester) async {
    final without = await pumpParkedAtTop(tester, topInset: 0);
    final with_ = await pumpParkedAtTop(tester, topInset: kMonthTabBarHeight);

    expect(with_.top - without.top, closeTo(kMonthTabBarHeight, 0.5));
  });

  testWidgets('a region too short to honour the inset still yields a usable '
      'rect rather than an inverted one', (tester) async {
    // Shorter than inset + strip + button + nav bar clearance combined.
    final r = await pumpParkedAtTop(
      tester,
      topInset: kMonthTabBarHeight,
      region: const Size(400, 80),
    );

    expect(r.top.isFinite, isTrue);
    expect(tester.takeException(), isNull);
  });
}

class _FixedFabPosition extends ScheduleFabPositionController {
  _FixedFabPosition(this._value);
  final ScheduleFabPosition _value;

  @override
  ScheduleFabPosition build() => _value;
}
