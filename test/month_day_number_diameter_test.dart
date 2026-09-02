import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/features/schedule/application/schedule_providers.dart';
import 'package:planfit/features/schedule/presentation/month_view/month_view.dart';

// Typical column width on a phone-sized screen: (device width - 2*gutter)/7
// — see MonthView.build's own `columnWidth` computation.
const _typicalColumnWidth = 52.0;

void main() {
  test(
    'never overlaps the collapsed dot/bar summary sitting just below it, at '
    'any rowHeight in the drag range — regression test for a too-short '
    "MonthCalendarRowHeight.min leaving the fixed circle's own bottom edge "
    'too close to the marker underneath it',
    () {
      for (
        var rowHeight = MonthCalendarRowHeight.min;
        rowHeight <= MonthCalendarRowHeight.max;
        rowHeight += 2
      ) {
        final available =
            rowHeight -
            monthMarkerTop(
              rowHeight: rowHeight,
              columnWidth: _typicalColumnWidth,
            ) -
            monthMarkerBottomPad;
        expect(
          available,
          greaterThanOrEqualTo(monthCollapsedDotSize),
          reason: 'at rowHeight $rowHeight',
        );
      }
    },
  );

  test('never exceeds the column width, even on an unusually narrow one', () {
    final diameter = monthDayNumberDiameter(columnWidth: 20);
    expect(diameter, lessThan(20));
  });

  test('never shrinks below a legible floor, even on a narrow column', () {
    final diameter = monthDayNumberDiameter(columnWidth: 26);
    expect(diameter, greaterThanOrEqualTo(16.0));
  });

  test(
    'stays at its full target size on any normal phone-width column',
    () {
      final diameter = monthDayNumberDiameter(columnWidth: _typicalColumnWidth);
      expect(diameter, 24.0);
    },
  );
}
