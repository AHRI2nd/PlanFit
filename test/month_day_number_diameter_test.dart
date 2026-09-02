import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/features/schedule/application/schedule_providers.dart';
import 'package:planfit/features/schedule/presentation/month_view/month_view.dart';

// Typical column width on a phone-sized screen: (device width - 2*gutter)/7
// — see MonthView.build's own `columnWidth` computation. Wide enough that
// the diameter formula's height term, not its width term, does the work in
// most of these cases.
const _typicalColumnWidth = 52.0;

void main() {
  test(
    'never overlaps the collapsed dot/bar summary sitting just below it, at '
    'any rowHeight in the drag range — regression test for the circle '
    'growing large enough at the shortest allowed row to collide with the '
    'marker underneath it',
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

  test('caps out at a single fixed diameter for the top of the drag range, '
      "instead of stretching into an oval the way sizing off rowHeight alone "
      'used to', () {
    final atMax = monthDayNumberDiameter(
      rowHeight: MonthCalendarRowHeight.max,
      columnWidth: _typicalColumnWidth,
    );
    final aboveDefault = monthDayNumberDiameter(
      rowHeight: MonthCalendarRowHeight.defaultHeight + 20,
      columnWidth: _typicalColumnWidth,
    );
    expect(atMax, aboveDefault);
  });

  test(
    'shrinks toward the shortest allowed rowHeight instead of overlapping '
    'the marker, but never below its own legible floor',
    () {
      final atMin = monthDayNumberDiameter(
        rowHeight: MonthCalendarRowHeight.min,
        columnWidth: _typicalColumnWidth,
      );
      final atMax = monthDayNumberDiameter(
        rowHeight: MonthCalendarRowHeight.max,
        columnWidth: _typicalColumnWidth,
      );
      expect(atMin, lessThan(atMax));
      expect(atMin, greaterThanOrEqualTo(20.0));
    },
  );

  test('never exceeds the column width, even at a very tall rowHeight', () {
    final diameter = monthDayNumberDiameter(
      rowHeight: MonthCalendarRowHeight.max,
      columnWidth: _typicalColumnWidth,
    );
    expect(diameter, lessThan(_typicalColumnWidth));
  });

  test(
    'shrinks below its usual size on a narrower column, rather than '
    'overflowing it',
    () {
      final narrow = monthDayNumberDiameter(
        rowHeight: MonthCalendarRowHeight.max,
        columnWidth: 30,
      );
      final typical = monthDayNumberDiameter(
        rowHeight: MonthCalendarRowHeight.max,
        columnWidth: _typicalColumnWidth,
      );
      expect(narrow, lessThan(typical));
      expect(narrow, lessThan(30));
    },
  );

  test('never shrinks below a legible floor, even at the shortest rowHeight '
      'on a narrow column', () {
    final diameter = monthDayNumberDiameter(
      rowHeight: MonthCalendarRowHeight.min,
      columnWidth: 26,
    );
    expect(diameter, greaterThanOrEqualTo(20.0));
  });
}
