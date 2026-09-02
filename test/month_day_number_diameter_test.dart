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
    'stays the same fixed diameter at both ends of the row-height drag '
    'range, instead of stretching into an oval the way sizing off rowHeight '
    'alone used to',
    () {
      final atMin = monthDayNumberDiameter(
        rowHeight: MonthCalendarRowHeight.min,
        columnWidth: _typicalColumnWidth,
      );
      final atMax = monthDayNumberDiameter(
        rowHeight: MonthCalendarRowHeight.max,
        columnWidth: _typicalColumnWidth,
      );
      expect(atMin, atMax);
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
    'shrinks below its usual fixed size on a narrower column, rather than '
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
