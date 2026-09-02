import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/features/schedule/application/schedule_providers.dart';
import 'package:planfit/features/schedule/presentation/month_view/month_view.dart';

const _typicalColumnWidth = 52.0;

void main() {
  test(
    'stays at the compact dot/bar summary (capacity 0) at the default row '
    'height, so dragging the split handle taller is what unlocks the list — '
    "it isn't there unasked-for from the start",
    () {
      final capacity = monthEventListCapacity(
        rowHeight: MonthCalendarRowHeight.defaultHeight,
        columnWidth: _typicalColumnWidth,
      );
      expect(capacity, 0);
    },
  );

  test('stays 0 at the shortest allowed row height — no room for a list at '
      'all there', () {
    final capacity = monthEventListCapacity(
      rowHeight: MonthCalendarRowHeight.min,
      columnWidth: _typicalColumnWidth,
    );
    expect(capacity, 0);
  });

  test(
    'unlocks a real list once the row is dragged past the default height '
    'by enough',
    () {
      final capacity = monthEventListCapacity(
        rowHeight: MonthCalendarRowHeight.max,
        columnWidth: _typicalColumnWidth,
      );
      expect(capacity, greaterThan(0));
    },
  );

  test('never returns a negative or unbounded row count', () {
    final capacity = monthEventListCapacity(
      rowHeight: MonthCalendarRowHeight.max,
      columnWidth: _typicalColumnWidth,
    );
    expect(capacity, greaterThanOrEqualTo(0));
    expect(capacity, lessThanOrEqualTo(5));
  });

  test(
    'the row budget is the real, measured row height, not a flat guess — '
    'regression test for the old flat 12.0-per-row budget leaving a chunk '
    "of the max row height's own real available space unused and "
    'undercounting how many events actually fit there',
    () {
      final capacity = monthEventListCapacity(
        rowHeight: MonthCalendarRowHeight.max,
        columnWidth: _typicalColumnWidth,
      );
      // At the max row height the old flat budget worked out to 2; the
      // real, measured row height leaves room for more than that.
      expect(capacity, greaterThan(2));
    },
  );

  test(
    "capacity grows close to 1:1 with rowHeight past the unlock threshold, "
    "not roughly half that — regression test for the day-number circle's "
    'own vertical centering silently spending half of every extra pixel a '
    'taller row gets on more blank space above the number instead of '
    'passing it down to the list',
    () {
      final at70 = monthEventListCapacity(
        rowHeight: 70,
        columnWidth: _typicalColumnWidth,
      );
      final at96 = monthEventListCapacity(
        rowHeight: MonthCalendarRowHeight.max,
        columnWidth: _typicalColumnWidth,
      );
      // A symmetric (centering) margin only ever passed ~half of a taller
      // row's growth down to the list; a fixed top margin passes down
      // essentially all of it. Real device text-measurement means this
      // can't be pinned to an exact number, but it should be nowhere near
      // as low as the "half" a centering margin would produce.
      expect(at96 - at70, greaterThanOrEqualTo(2));
    },
  );
}
